# Internal DNS Role

The `internal_dns` role manages dnsmasq on `mgmt-01` for the private `lab.barouconsulting.nl` zone. It installs the service, deploys and validates its configuration, manages DNS firewall rules and restarts dnsmasq when configuration changes.

## Current Configuration

| Setting | Value |
|---|---|
| Host | `mgmt-01`, VM 106 |
| LAN address | `192.168.178.106`, static through Terraform |
| Tailscale address | `100.72.132.51` |
| Listening addresses | `127.0.0.1`, `192.168.178.106`, `100.72.132.51` |
| Upstream resolvers | `1.1.1.1`, `9.9.9.9` |
| Generated configuration | `/etc/dnsmasq.d/internal-dns.conf` |
| Desired records | `defaults/main.yml`, variable `internal_dns_records` |

| DNS name | Address | Purpose |
|---|---|---|
| `mgmt.lab.barouconsulting.nl` | `192.168.178.106` | Management host |
| `proxmox.lab.barouconsulting.nl` | `192.168.178.106` | Caddy proxy to Proxmox |
| `rancher.lab.barouconsulting.nl` | `192.168.178.106` | Caddy proxy to Rancher ingress |
| `platform.lab.barouconsulting.nl` | `192.168.178.106` | Caddy proxy to Homepage ingress |

The Gitea and Jenkins records have been removed. GitLab has no record in this configuration yet.

Application names resolve to the gateway, where Caddy selects the backend by hostname. The `mgmt` DNS record alone does not create a Caddy website.

## Resolver Paths

Tailscale Split DNS sends queries for `lab.barouconsulting.nl` to the gateway's Tailscale address. Other client queries follow the client's normal DNS policy. A subnet route is also needed to reach the LAN address returned for internal applications.

RKE2 CoreDNS forwards the internal zone to `192.168.178.106`. LAN clients must use the resolver explicitly or have their resolver configured to forward the zone. UFW permits DNS over both TCP and UDP port 53 from the configured LAN and Tailscale sources.

## Apply Configuration

From `ubuntu-dev-01`:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible mgmt_servers -m ping
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --check --diff
```

`--check` previews supported tasks; `--diff` shows expected configuration changes. The management playbook also includes the baseline, security, Tailscale and reverse-proxy roles. Review that full scope before applying it:

```bash
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --diff
```

For an already configured gateway, the following narrower command starts at the DNS role and then also runs the reverse-proxy tasks. It skips earlier baseline and Tailscale tasks, so it is not a bootstrap command:

```bash
ansible-playbook playbooks/mgmt.yml \
  --limit mgmt_servers \
  --start-at-task "internal_dns : Install internal DNS packages" \
  --diff
```

## Verify

From `ubuntu-dev-01`, query the resolver directly:

```bash
dig @192.168.178.106 mgmt.lab.barouconsulting.nl +short
dig @192.168.178.106 proxmox.lab.barouconsulting.nl +short
dig @192.168.178.106 rancher.lab.barouconsulting.nl +short
dig @192.168.178.106 platform.lab.barouconsulting.nl +short
```

Each current record should return `192.168.178.106`. Test normal client resolution separately, without `@192.168.178.106`, to check the client's DNS configuration.

On `mgmt-01`:

```bash
sudo dnsmasq --test
sudo systemctl status dnsmasq --no-pager
sudo journalctl -u dnsmasq -n 50 --no-pager
```

`systemctl` shows service state; `journalctl` shows service logs. A successful Ansible restart does not by itself verify resolution from every client.

## Operational Notes

Keep the gateway address stable and coordinate it with the router's DHCP range or reservation. This repository configures the VM's address, but does not prove the router's DHCP configuration is correct.

If the resolver is unreachable, check the VM's actual address before changing DNS records. See [Management Platform](../../../../docs/management-platform.md).

Repeated runs should leave unchanged DNS configuration untouched. Check-mode predictions can differ from actual execution; inspect the task responsible for any reported change rather than treating the recap alone as an idempotency test.
