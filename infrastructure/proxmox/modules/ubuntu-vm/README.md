# ubuntu-vm module

Creates one Ubuntu VM on Proxmox as a full clone of the Cloud-Init template:
CPU, fixed memory (ballooning disabled), `vmbr0` network, static or DHCP IPv4,
the Cloud-Init user with its SSH key, QEMU guest agent, start on boot.

VMs are declared in `virtual_machines` in `infrastructure/proxmox/variables.tf`.

## DNS (`dns_servers`, optional)

Without `dns_servers` the guest inherits the Proxmox host's resolvers, which
include Tailscale MagicDNS (`100.100.100.100`). Containers cannot reach that
address, so Docker builds fail with "Temporary failure in name resolution".

nieuwe VM's met Docker: dns_servers = ["192.168.178.1", "1.1.1.1"]

```hcl
example-01 = {
  vm_id        = 113
  description  = "Example Docker host"
  cpu_cores    = 2
  memory_mb    = 1536
  ipv4_address = "192.168.178.113/24"
  ipv4_gateway = "192.168.178.1"
  dns_servers  = ["192.168.178.1", "1.1.1.1"]
}
```

Existing VMs deliberately do not set `dns_servers`. Adding it to a running VM
changes its Cloud-Init configuration (an in-place update that takes effect on
its next boot), so review the plan and plan a reboot before doing that.
`detective-ops-01` solves container DNS in `/etc/docker/daemon.json` instead.
