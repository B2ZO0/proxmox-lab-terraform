locals {
  prefix_length = split("/", var.network_cidr)[1]
  vm_names      = sort(keys(var.vms))
  vm_ids        = { for i, name in local.vm_names : name => var.vm_id_start + i }
  vm_ips        = { for name, vm in var.vms : name => cidrhost(var.network_cidr, vm.host_number) }
  netcockpit_ip = try([for name, vm in var.vms : local.vm_ips[name] if vm.role == "netcockpit"][0], "")
}

# One cloud-init file per VM: account, keys, packages, and the role
resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each = var.vms

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "lab-${each.key}.yaml"
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname        = each.key
      domain          = var.domain
      admin_user      = var.admin_user
      ssh_keys        = var.ssh_public_keys
      timezone        = var.timezone
      role            = each.value.role
      netcockpit_host = local.netcockpit_ip
    })
  }
}

resource "proxmox_virtual_environment_vm" "lab" {
  for_each = var.vms

  name        = each.key
  description = "Lab VM (${each.value.role}), managed by proxmox-lab-terraform"
  node_name   = var.node_name
  vm_id       = local.vm_ids[each.key]
  tags        = sort(distinct(concat(["lab", each.value.role], each.value.tags)))
  on_boot     = var.start_on_boot

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id == 0 ? null : var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${local.vm_ips[each.key]}/${local.prefix_length}"
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.domain
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id
  }

  lifecycle {
    # cloud-init only runs at first boot: changing the file must not recreate the VM
    ignore_changes = [initialization[0].user_data_file_id]
  }
}
