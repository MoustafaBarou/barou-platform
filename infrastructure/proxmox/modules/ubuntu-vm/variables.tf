variable "proxmox_node_name" {
  description = "Proxmox node where the virtual machine will be created."
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the Ubuntu Cloud-Init template."
  type        = number
}

variable "vm_id" {
  description = "Unique Proxmox VM ID."
  type        = number
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
}

variable "vm_description" {
  description = "Description shown in the Proxmox interface."
  type        = string
}

variable "cpu_cores" {
  description = "Number of virtual CPU cores."
  type        = number
}

variable "memory_mb" {
  description = "Amount of dedicated memory in MiB."
  type        = number
}

variable "network_bridge" {
  description = "Proxmox network bridge connected to the virtual machine."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore used for Cloud-Init."
  type        = string
}

variable "cloud_init_username" {
  description = "Username created by Cloud-Init."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key added through Cloud-Init."
  type        = string
}
