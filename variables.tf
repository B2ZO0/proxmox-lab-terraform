# --- Proxmox connection ----------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://pve.lab.local:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token, user@realm!tokenid=secret. Better set it with TF_VAR_proxmox_api_token."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Accept the self-signed certificate of Proxmox."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user on the Proxmox node, used to upload cloud-init snippets."
  type        = string
  default     = "root"
}

variable "node_name" {
  description = "Proxmox node where the lab runs."
  type        = string
  default     = "pve"
}

# --- Where the VMs go -----------------------------------------------------------------------
variable "template_id" {
  description = "ID of the Debian 12 cloud-init template (see scripts/create-debian-template.sh)."
  type        = number
  default     = 9000
}

variable "vm_id_start" {
  description = "First VM ID used by the lab; VMs get consecutive IDs."
  type        = number
  default     = 800
}

variable "datastore" {
  description = "Datastore for the VM disks."
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore" {
  description = "Datastore with the 'snippets' content type enabled, for cloud-init files."
  type        = string
  default     = "local"
}

variable "bridge" {
  description = "Network bridge of the VMs."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag of the lab network, or 0 for none."
  type        = number
  default     = 0
}

# --- Lab network ----------------------------------------------------------------------------
variable "network_cidr" {
  description = "Lab network, e.g. 192.168.50.0/24. Each VM gets host_number as its address."
  type        = string
  default     = "192.168.50.0/24"
}

variable "gateway" {
  description = "Gateway of the lab network."
  type        = string
  default     = "192.168.50.1"
}

variable "dns_servers" {
  description = "DNS servers of the lab VMs."
  type        = list(string)
  default     = ["1.1.1.1", "9.9.9.9"]
}

variable "domain" {
  description = "DNS domain of the lab."
  type        = string
  default     = "lab.local"
}

# --- Access ---------------------------------------------------------------------------------
variable "admin_user" {
  description = "Admin account created on every VM (sudo, SSH key only)."
  type        = string
  default     = "admin"
}

variable "ssh_public_keys" {
  description = "SSH public keys allowed to log in as admin_user."
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Give at least one SSH public key, otherwise nobody can log in to the lab."
  }
}

variable "timezone" {
  description = "Time zone of the VMs."
  type        = string
  default     = "Europe/Paris"
}

# --- The lab --------------------------------------------------------------------------------
variable "vms" {
  description = <<-EOT
    VMs of the lab. role: "netcockpit" installs Docker and NetCockpit, "docker" installs Docker,
    "server" is a plain Debian server ready for Ansible.
  EOT
  type = map(object({
    host_number = number
    role        = optional(string, "server")
    cores       = optional(number, 1)
    memory_mb   = optional(number, 1024)
    disk_gb     = optional(number, 12)
    tags        = optional(list(string), [])
  }))
  default = {
    netcockpit = { host_number = 10, role = "netcockpit", cores = 2, memory_mb = 4096, disk_gb = 30 }
    web01      = { host_number = 21, tags = ["web"] }
    web02      = { host_number = 22, tags = ["web"] }
    db01       = { host_number = 31, memory_mb = 2048, disk_gb = 20, tags = ["db"] }
    docker01   = { host_number = 41, role = "docker", cores = 2, memory_mb = 2048, disk_gb = 30 }
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : contains(["netcockpit", "docker", "server"], v.role)])
    error_message = "role must be netcockpit, docker or server."
  }
  validation {
    condition     = length(distinct([for v in values(var.vms) : v.host_number])) == length(var.vms)
    error_message = "Two VMs have the same host_number."
  }
}

variable "start_on_boot" {
  description = "Start the lab VMs when the Proxmox node boots."
  type        = bool
  default     = false
}
