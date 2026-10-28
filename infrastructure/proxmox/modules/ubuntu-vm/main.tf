resource "proxmox_virtual_environment_vm" "this" {
  name      = var.vm_name
  node_name = var.proxmox_node_name
  vm_id     = var.vm_id

  description = var.vm_description

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  # Fixed memory: ballooning disabled.
  memory {
    dedicated = var.memory_mb
    floating  = 0
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore_id

    # Only set when dns_servers is given; otherwise the guest keeps inheriting
    # the Proxmox host's resolvers (current behaviour of existing VMs).
    dynamic "dns" {
      for_each = var.dns_servers == null ? [] : [var.dns_servers]

      content {
        servers = dns.value
      }
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = var.cloud_init_username

      keys = [
        trimspace(file(pathexpand(var.ssh_public_key_path)))
      ]
    }
  }

  agent {
    enabled = true
  }

  on_boot = true
  started = true
}
