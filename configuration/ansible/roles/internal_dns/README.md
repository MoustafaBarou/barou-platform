Internal DNS Role
Purpose

The internal_dns role provides internal DNS resolution for the Barou homelab management platform.

It allows administrators to use stable internal hostnames instead of remembering IP addresses and service ports.

Responsibilities

This role manages:

dnsmasq installation
Internal DNS configuration
Internal DNS records
Upstream DNS resolvers
DNS configuration validation
DNS service availability
UFW rules for DNS traffic
DNS access from Tailscale and the homelab LAN
Internal DNS Zone

The internal DNS zone is:

lab.barouconsulting.nl

This zone is used only for internal homelab services.

DNS Records

The following records are managed:

mgmt.lab.barouconsulting.nl
gitea.lab.barouconsulting.nl
jenkins.lab.barouconsulting.nl
proxmox.lab.barouconsulting.nl

The application hostnames resolve to the management gateway so traffic passes through the reverse proxy.

Current management gateway address:

192.168.178.106

DNS Architecture

Remote workstation
|
| Tailscale
v
Split DNS
|
v
mgmt-01
dnsmasq
|
v
lab.barouconsulting.nl

Split DNS

Tailscale Split DNS is configured so that only requests for:

lab.barouconsulting.nl

are sent to the internal DNS resolver.

Normal internet DNS resolution remains unchanged.

This prevents the homelab DNS server from becoming the global resolver for remote clients.

Listening Addresses

dnsmasq listens on:

127.0.0.1
192.168.178.106
100.72.132.51

These addresses provide DNS access locally, from the homelab LAN, and from Tailscale clients.

Upstream DNS

Queries outside the internal homelab zone are forwarded to configured upstream DNS servers.

Current upstream resolvers:

1.1.1.1
9.9.9.9

Firewall

UFW explicitly permits DNS traffic over:

TCP 53
UDP 53

from:

Tailscale
Homelab LAN

The rest of the firewall policy remains restrictive.

Configuration Validation

The generated dnsmasq configuration is validated before deployment.

This prevents an invalid configuration from replacing the active DNS configuration.

Testing

Example DNS validation:

dig @127.0.0.1 gitea.lab.barouconsulting.nl +short
dig @127.0.0.1 jenkins.lab.barouconsulting.nl +short
dig @127.0.0.1 proxmox.lab.barouconsulting.nl +short
dig @127.0.0.1 mgmt.lab.barouconsulting.nl +short

Security Design

The role follows these principles:

Internal-only DNS namespace
Split DNS instead of replacing global DNS
Explicit firewall rules
Configuration validation before deployment
Infrastructure managed through Ansible
No public DNS records required for homelab services
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

internal_dns
Current State

Internal DNS is operational.

Validated records:

gitea.lab.barouconsulting.nl
jenkins.lab.barouconsulting.nl
proxmox.lab.barouconsulting.nl
mgmt.lab.barouconsulting.nl
