variable "proxmox_node_name" {
  description = "Name of the Proxmox node where the VM will be created."
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "VM ID of the Ubuntu Cloud-Init template."
  type        = number
  default     = 9000
}

variable "vm_id" {
  description = "VM ID assigned to the new virtual machine."
  type        = number
  default     = 103
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
  default     = "ubuntu-tf-01"
}

variable "vm_description" {
  description = "Description shown in the Proxmox web interface."
  type        = string
  default     = "Ubuntu VM managed by Terraform"
}

variable "cpu_cores" {
  description = "Number of virtual CPU cores assigned to the VM."
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Amount of dedicated memory assigned to the VM in MiB."
  type        = number
  default     = 2048
}

variable "network_bridge" {
  description = "Proxmox network bridge connected to the VM."
  type        = string
  default     = "vmbr0"
}

variable "datastore_id" {
  description = "Proxmox datastore used for the Cloud-Init disk."
  type        = string
  default     = "local-lvm"
}

variable "cloud_init_username" {
  description = "Username created by Cloud-Init."
  type        = string
  default     = "moustafa"
}
