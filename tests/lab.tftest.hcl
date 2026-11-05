# Offline tests: the Proxmox provider is mocked, nothing is created.
mock_provider "proxmox" {
  mock_resource "proxmox_virtual_environment_file" {
    defaults = {
      id = "local:snippets/lab.yaml"
    }
  }
}

variables {
  proxmox_endpoint  = "https://pve.example:8006/"
  proxmox_api_token = "terraform@pve!lab=00000000-0000-0000-0000-000000000000"
  ssh_public_keys   = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyOnly test@example"]
}

run "default_lab" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_vm.lab) == 5
    error_message = "The default lab has 5 VMs."
  }
  assert {
    condition     = output.netcockpit_url == "http://192.168.50.10:8088"
    error_message = "NetCockpit URL is wrong."
  }
  assert {
    condition     = strcontains(output.ansible_inventory, "web01 ansible_host=192.168.50.21")
    error_message = "The Ansible inventory misses web01."
  }
  assert {
    condition     = strcontains(output.ansible_inventory, "[role_netcockpit]\nnetcockpit")
    error_message = "The Ansible inventory misses the role groups."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.lab["db01"].vm_id == 800 && proxmox_virtual_environment_vm.lab["web02"].vm_id == 804
    error_message = "VM IDs must be consecutive in name order from vm_id_start."
  }
  assert {
    condition     = strcontains(proxmox_virtual_environment_file.cloud_init["netcockpit"].source_raw[0].data, "./setup.sh --yes")
    error_message = "The netcockpit VM must install NetCockpit."
  }
  assert {
    condition     = !strcontains(proxmox_virtual_environment_file.cloud_init["web01"].source_raw[0].data, "get.docker.com")
    error_message = "Plain servers must not get Docker."
  }
  assert {
    condition     = strcontains(proxmox_virtual_environment_file.cloud_init["web01"].source_raw[0].data, "http://192.168.50.10:8088")
    error_message = "Servers should point to the lab NetCockpit."
  }
}

run "unknown_role_is_refused" {
  command = plan
  variables {
    vms = { x = { host_number = 5, role = "windows" } }
  }
  expect_failures = [var.vms]
}

run "duplicate_address_is_refused" {
  command = plan
  variables {
    vms = {
      a = { host_number = 5 }
      b = { host_number = 5 }
    }
  }
  expect_failures = [var.vms]
}

run "no_ssh_key_is_refused" {
  command = plan
  variables {
    ssh_public_keys = []
  }
  expect_failures = [var.ssh_public_keys]
}
