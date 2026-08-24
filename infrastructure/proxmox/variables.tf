variable "proxmox_node_name" {
  description = "Proxmox node where virtual machines are deployed."
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "Proxmox VM ID of the Ubuntu Cloud-Init template."
  type        = number
  default     = 9000
}

variable "network_bridge" {
  description = "Proxmox network bridge connected to virtual machines."
  type        = string
  default     = "vmbr0"
}

variable "datastore_id" {
  description = "Proxmox datastore used for Cloud-Init."
  type        = string
  default     = "local-lvm"
}

variable "cloud_init_username" {
  description = "Username created by Cloud-Init."
  type        = string
  default     = "moustafa"
}

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key added to virtual machines through Cloud-Init."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "virtual_machines" {
  description = "Ubuntu virtual machines managed by Terraform."

  type = map(object({
    vm_id        = number
    description  = string
    cpu_cores    = number
    memory_mb    = number
    ipv4_address = optional(string, "dhcp")
    ipv4_gateway = optional(string)
  }))

  default = {
    ubuntu-tf-01 = {
      vm_id       = 103
      description = "Terraform-managed Ubuntu automation target"
      cpu_cores   = 2
      memory_mb   = 2048
    }

    gitea-01 = {
      vm_id       = 104
      description = "Self-hosted Git service managed by Terraform"
      cpu_cores   = 2
      memory_mb   = 2048
    }

    jenkins-01 = {
      vm_id       = 105
      description = "CI automation server managed by Terraform"
      cpu_cores   = 2
      memory_mb   = 3072
    }

    mgmt-01 = {
      vm_id       = 106
      description = "Management gateway for secure remote access and internal platform services"
      cpu_cores   = 1
      memory_mb   = 1536
    }

    k8s-cp-01 = {
      vm_id        = 110
      description  = "RKE2 Kubernetes control plane node"
      cpu_cores    = 2
      memory_mb    = 3072
      ipv4_address = "192.168.178.110/24"
      ipv4_gateway = "192.168.178.1"
    }

    k8s-worker-01 = {
      vm_id        = 111
      description  = "RKE2 Kubernetes worker node"
      cpu_cores    = 2
      memory_mb    = 2048
      ipv4_address = "192.168.178.111/24"
      ipv4_gateway = "192.168.178.1"
    }
  }
}
