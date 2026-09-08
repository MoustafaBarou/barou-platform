terraform {
  required_version = "~> 1.15.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.178.10:8006/"
  insecure = true
}
