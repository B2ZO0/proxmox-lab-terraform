output "vms" {
  description = "Name, ID and address of every lab VM."
  value = {
    for name, vm in proxmox_virtual_environment_vm.lab : name => {
      id   = vm.vm_id
      ip   = local.vm_ips[name]
      role = var.vms[name].role
      ssh  = "ssh ${var.admin_user}@${local.vm_ips[name]}"
    }
  }
}

output "netcockpit_url" {
  description = "NetCockpit web interface (ready a few minutes after the first boot)."
  value       = local.netcockpit_ip == "" ? "no netcockpit VM in this lab" : "http://${local.netcockpit_ip}:8088"
}

output "ansible_inventory" {
  description = "Ansible inventory of the lab: terraform output -raw ansible_inventory > inventory.ini"
  value = join("\n", concat(
    ["[lab]"],
    [for name in local.vm_names : "${name} ansible_host=${local.vm_ips[name]}"],
    ["", "[lab:vars]", "ansible_user=${var.admin_user}", ""],
    flatten([for role in distinct([for v in values(var.vms) : v.role]) : concat(
      ["[role_${role}]"],
      [for name in local.vm_names : name if var.vms[name].role == role],
      [""]
    )])
  ))
}
