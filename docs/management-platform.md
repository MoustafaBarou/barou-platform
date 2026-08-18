# Management Platform# Management Platform


## Purpose


The management platform provides secure remote access to the Barou homelab without exposing internal services directly to the public internet.


It combines Terraform-managed infrastructure, Ansible configuration management, Tailscale private networking, internal DNS, and a Caddy reverse proxy.


## Architecture


```text
Remote workstation
        |
        | Tailscale
        v
    mgmt-01
    192.168.178.106
        |
        +-- Tailscale subnet router
        |
        +-- Internal DNS
        |     lab.barouconsulting.nl
        |
        +-- Caddy reverse proxy
              |
              +-- Gitea
              |   192.168.178.104:3000
              |
              +-- Jenkins
              |   192.168.178.105:8080
              |
              +-- Proxmox
                  192.168.178.10:8006
Components
mgmt-01

mgmt-01 is the dedicated management gateway for the homelab.

It is provisioned through Terraform and configured through Ansible.

Responsibilities:

Secure remote access
Tailscale subnet routing
Internal DNS resolution
HTTPS reverse proxy
Internal TLS termination
Controlled access to management services
Terraform

The management VM is defined as part of the reusable Proxmox Terraform configuration.

Current VM:

Name:        mgmt-01
VM ID:       106
LAN IP:      192.168.178.106
CPU:         1 vCPU
Memory:      1536 MB

Terraform is responsible for the infrastructure lifecycle of the VM.

Ansible

The management gateway is configured through:

configuration/ansible/playbooks/mgmt.yml

Roles:

common
security
tailscale_router
internal_dns
reverse_proxy

The playbook has been validated for idempotency.

A repeated execution completes with:

changed=0
failed=0
Tailscale Subnet Router

mgmt-01 advertises the homelab LAN:

192.168.178.0/24

IP forwarding is enabled through Ansible.

Traffic from the Tailscale interface is explicitly allowed through UFW toward the LAN interface.

This allows authorized Tailscale clients to securely reach internal services without exposing them to the internet.

Example remote connectivity:

Remote workstation
        |
        | Tailscale
        v
192.168.178.0/24
Internal DNS

dnsmasq runs on mgmt-01.

Internal DNS zone:

lab.barouconsulting.nl

Tailscale Split DNS forwards only this zone to the internal resolver.

The resolver is reachable through the Tailscale address of mgmt-01.

Internal service records:

mgmt.lab.barouconsulting.nl
gitea.lab.barouconsulting.nl
jenkins.lab.barouconsulting.nl
proxmox.lab.barouconsulting.nl

Application hostnames resolve to the management gateway so traffic passes through the reverse proxy.

Reverse Proxy

Caddy provides the HTTPS ingress layer.

External service URLs:

https://gitea.lab.barouconsulting.nl
https://jenkins.lab.barouconsulting.nl
https://proxmox.lab.barouconsulting.nl

Backend services:

Gitea:
http://192.168.178.104:3000


Jenkins:
http://192.168.178.105:8080


Proxmox:
https://192.168.178.10:8006

Users no longer need to remember backend IP addresses or application port numbers.

TLS

Caddy uses its internal certificate authority for the private homelab domain.

The public root certificate can be installed on trusted administrator workstations.

The CA private key remains on the management gateway and must never be distributed.

This provides trusted HTTPS connections for internal management services.

Firewall

UFW remains enabled with a default-deny posture.

The management gateway only permits the traffic required for its responsibilities, including:

SSH management
Tailscale routed traffic
DNS over TCP/UDP
HTTP/HTTPS ingress

The default routed policy remains restrictive.

Specific forwarding rules are managed through Ansible.

Remote Administration

The development environment is accessed through Tailscale and VS Code Remote SSH.

Example SSH alias:

Host barou-dev
    HostName <tailscale-ip>
    User moustafa
    IdentityFile ~/.ssh/id_ed25519

VS Code connects remotely to ubuntu-dev-01, while Git, Terraform, and Ansible continue to execute on the Linux control node.


## Purpose


The management platform provides secure remote access to the Barou homelab without exposing internal services directly to the public internet.


It combines Terraform-managed infrastructure, Ansible configuration management, Tailscale private networking, internal DNS, and a Caddy reverse proxy.


## Architecture


```text
Remote workstation
        |
        | Tailscale
        v
    mgmt-01
    192.168.178.106
        |
        +-- Tailscale subnet router
        |
        +-- Internal DNS
        |     lab.barouconsulting.nl
        |
        +-- Caddy reverse proxy
              |
              +-- Gitea
              |   192.168.178.104:3000
              |
              +-- Jenkins
              |   192.168.178.105:8080
              |
              +-- Proxmox
                  192.168.178.10:8006
Components
mgmt-01

mgmt-01 is the dedicated management gateway for the homelab.

It is provisioned through Terraform and configured through Ansible.

Responsibilities:

Secure remote access
Tailscale subnet routing
Internal DNS resolution
HTTPS reverse proxy
Internal TLS termination
Controlled access to management services
Terraform

The management VM is defined as part of the reusable Proxmox Terraform configuration.

Current VM:

Name:        mgmt-01
VM ID:       106
LAN IP:      192.168.178.106
CPU:         1 vCPU
Memory:      1536 MB

Terraform is responsible for the infrastructure lifecycle of the VM.

Ansible

The management gateway is configured through:

configuration/ansible/playbooks/mgmt.yml

Roles:

common
security
tailscale_router
internal_dns
reverse_proxy

The playbook has been validated for idempotency.

A repeated execution completes with:

changed=0
failed=0
Tailscale Subnet Router

mgmt-01 advertises the homelab LAN:

192.168.178.0/24

IP forwarding is enabled through Ansible.

Traffic from the Tailscale interface is explicitly allowed through UFW toward the LAN interface.

This allows authorized Tailscale clients to securely reach internal services without exposing them to the internet.

Example remote connectivity:

Remote workstation
        |
        | Tailscale
        v
192.168.178.0/24
Internal DNS

dnsmasq runs on mgmt-01.

Internal DNS zone:

lab.barouconsulting.nl

Tailscale Split DNS forwards only this zone to the internal resolver.

The resolver is reachable through the Tailscale address of mgmt-01.

Internal service records:

mgmt.lab.barouconsulting.nl
gitea.lab.barouconsulting.nl
jenkins.lab.barouconsulting.nl
proxmox.lab.barouconsulting.nl

Application hostnames resolve to the management gateway so traffic passes through the reverse proxy.

Reverse Proxy

Caddy provides the HTTPS ingress layer.

External service URLs:

https://gitea.lab.barouconsulting.nl
https://jenkins.lab.barouconsulting.nl
https://proxmox.lab.barouconsulting.nl

Backend services:

Gitea:
http://192.168.178.104:3000


Jenkins:
http://192.168.178.105:8080


Proxmox:
https://192.168.178.10:8006

Users no longer need to remember backend IP addresses or application port numbers.

TLS

Caddy uses its internal certificate authority for the private homelab domain.

The public root certificate can be installed on trusted administrator workstations.

The CA private key remains on the management gateway and must never be distributed.

This provides trusted HTTPS connections for internal management services.

Firewall

UFW remains enabled with a default-deny posture.

The management gateway only permits the traffic required for its responsibilities, including:

SSH management
Tailscale routed traffic
DNS over TCP/UDP
HTTP/HTTPS ingress

The default routed policy remains restrictive.

Specific forwarding rules are managed through Ansible.

Remote Administration

The development environment is accessed through Tailscale and VS Code Remote SSH.

Example SSH alias:

Host barou-dev
    HostName <tailscale-ip>
    User moustafa
    IdentityFile ~/.ssh/id_ed25519

VS Code connects remotely to ubuntu-dev-01, while Git, Terraform, and Ansible continue to execute on the Linux control node.
