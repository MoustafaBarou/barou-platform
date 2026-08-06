resource "proxmox_virtual_environment_vm" "ubuntu_tf_01" {
  name      = "ubuntu-tf-01"
  node_name = "pve"
  vm_id     = 103

  description = "Ubuntu VM managed by Terraform"

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "moustafa"
    }
  }

  agent {
    enabled = true
  }

  started = true
}
