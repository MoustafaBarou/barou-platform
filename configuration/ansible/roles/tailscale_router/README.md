Tailscale Router Role
Purpose

The tailscale_router role configures the management gateway as a secure Tailscale subnet router for the Barou homelab.

It allows authorized Tailscale clients to reach internal homelab services without exposing those services directly to the public internet.

Responsibilities

This role manages:

Tailscale installation
Tailscale service availability
IPv4 forwarding
IPv6 forwarding
UFW routed traffic rules
Tailscale authentication state validation
Homelab subnet advertisement
Advertised Network

The management gateway advertises the following internal network:

192.168.178.0/24

This allows authorized Tailscale clients to reach devices and services inside the homelab LAN.

Network Flow

Remote workstation
|
| Tailscale
v
mgmt-01
|
| Subnet routing
v
192.168.178.0/24

Firewall

UFW remains enabled with a restrictive default policy.

The role explicitly permits routed traffic from:

tailscale0

to:

eth0

for the homelab subnet.

The default routed firewall policy is not globally opened.

IP Forwarding

The role enables:

net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

These settings allow mgmt-01 to forward traffic between the Tailscale network and the homelab LAN.

Tailscale Authentication Validation

The role validates the Tailscale backend state before advertising routes.

The expected state is:

Running

If Tailscale is not authenticated or operational, the Ansible run fails instead of continuing with an invalid subnet router configuration.

Route Advertisement

The role advertises:

192.168.178.0/24

through Tailscale.

Route approval is managed through the Tailscale control plane.

Security Design

The role follows these principles:

No public exposure of internal management services
Private remote connectivity through Tailscale
Explicit firewall forwarding rules
Infrastructure configuration managed through Ansible
Authentication state validated before route advertisement
Default-deny firewall behavior remains intact
Idempotency

The role is designed to be idempotent.

A repeated Ansible execution should complete with:

changed=0
failed=0

Usage

The role is included in:

configuration/ansible/playbooks/mgmt.yml

Example:

roles:

tailscale_router
Current State

The subnet router is operational and provides remote access to the homelab network through Tailscale.

Validated services include:

Proxmox
Gitea
Jenkins
mgmt-01
