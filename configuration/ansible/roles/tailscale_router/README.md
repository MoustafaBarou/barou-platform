# Tailscale Router Role

The `tailscale_router` role configures `mgmt-01` as the homelab's Tailscale subnet router. Authorized clients can reach the private LAN without publicly exposing management services.

## Configuration

| Setting | Value |
|---|---|
| Gateway | `mgmt-01`, VM 106 |
| LAN interface and address | `eth0`, `192.168.178.106/24` |
| Tailscale address | `100.72.132.51` |
| Advertised subnet | `192.168.178.0/24` |
| Playbook | `configuration/ansible/playbooks/mgmt.yml` |
| Inventory group | `mgmt_servers` |

The role manages Tailscale installation and service availability, IPv4/IPv6 forwarding, explicit UFW forwarding rules, authentication-state validation and subnet advertisement. It checks for the Tailscale backend state `Running` before advertising the route.

UFW permits the configured routed traffic from `tailscale0` toward `eth0` for the homelab subnet. The default routed firewall policy remains restrictive.

The forwarding settings are:

```text
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
```

Route approval and access policy are managed in the Tailscale control plane. Advertising a route does not by itself grant every client access; clients must also use the approved route.

## DNS and Application Access

The `internal_dns` role provides Split DNS for `lab.barouconsulting.nl`. Application records resolve to the gateway's LAN address, where Caddy routes Proxmox, Rancher and Homepage requests. DNS resolution and subnet routing must both work for remote access.

Gitea and Jenkins have been retired. Their previous service routes are no longer part of the active platform. GitLab access will be documented after its deployment design is implemented.

VS Code Remote SSH can also connect directly to `ubuntu-dev-01` at its own Tailscale address, `100.111.185.114`. That is a separate entry point from the subnet router on `mgmt-01`.

## Use and Verify

From `ubuntu-dev-01`:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible mgmt_servers -m ping
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --check --diff
```

The playbook includes baseline, security, DNS and reverse-proxy configuration as well as this role. Review all expected changes before applying:

```bash
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --diff
```

On `mgmt-01`:

```bash
tailscale status
ip -4 -br address
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
sudo ufw status verbose
sudo systemctl status tailscaled --no-pager
sudo journalctl -u tailscaled -n 50 --no-pager
```

These checks inspect local state. Also test a permitted internal endpoint from an authorized remote client to verify the complete route and policy.

Check mode may skip authentication or route commands, and a package-key download may predict a change without comparing downloaded content. An actual no-change run is stronger evidence of idempotency than a check-mode recap.

## Troubleshooting

If local LAN access works but remote access fails, inspect Tailscale authentication, route approval, client routing and access policy. If LAN access also fails, first confirm the destination VM's actual address and host firewall rules.

The gateway previously received `192.168.178.105` through DHCP while inventory expected `.106`. It now uses a Terraform-configured static `.106`. Keep the LAN address, DHCP allocation and Ansible inventory consistent; do not change the inventory to follow an unexpected lease.

See [Management Platform](../../../../docs/management-platform.md) for the gateway address and host-key recovery procedure.
