module "ubuntu_vm" {
  for_each = var.virtual_machines

  source = "./modules/ubuntu-vm"

  proxmox_node_name = var.proxmox_node_name
  template_vm_id    = var.template_vm_id

  vm_id          = each.value.vm_id
  vm_name        = each.key
  vm_description = each.value.description
  cpu_cores      = each.value.cpu_cores
  memory_mb      = each.value.memory_mb

  network_bridge      = var.network_bridge
  datastore_id        = var.datastore_id
  cloud_init_username = var.cloud_init_username
  ssh_public_key_path = var.ssh_public_key_path

  ipv4_address = try(each.value.ipv4_address, "dhcp")
  ipv4_gateway = try(each.value.ipv4_gateway, null)
}
