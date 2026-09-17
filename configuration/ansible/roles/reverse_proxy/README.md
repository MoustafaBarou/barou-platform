# Reverse Proxy Role

The `reverse_proxy` role configures Caddy on `mgmt-01` for internal HTTPS access to Proxmox, Rancher and Homepage. Gitea and Jenkins have been retired and their site definitions removed. No GitLab upstream is configured yet.

## Managed Services

All application DNS records resolve to `192.168.178.106`.

| Service | User-facing URL | Caddy upstream |
|---|---|---|
| Proxmox VE | `https://proxmox.lab.barouconsulting.nl` | `https://192.168.178.10:8006` |
| Rancher | `https://rancher.lab.barouconsulting.nl` | `http://192.168.178.111:80` |
| Homepage | `https://platform.lab.barouconsulting.nl` | `http://192.168.178.111:80` |

Rancher and Homepage share the Kubernetes ingress endpoint. Their HTTP hostnames select different Kubernetes Ingress routes. A plain request to the worker IP without the correct Host header may receive a default response.

## Role Files and Responsibilities

| File | Purpose |
|---|---|
| `defaults/main.yml` | `reverse_proxy_sites` and gateway settings |
| `tasks/main.yml` | Install Caddy, deploy configuration, manage service and firewall |
| `templates/Caddyfile.j2` | Generate virtual hosts and upstream configuration |
| `handlers/main.yml` | Reload Caddy when notified |

The generated configuration is `/etc/caddy/Caddyfile`. Change Ansible variables or the template, then apply the role; direct edits to the generated file will be overwritten.

The role requires a reachable management host, SSH and sudo access, working DNS, reachable backends, and available HTTP/HTTPS ports. UFW rules permit the configured LAN and Tailscale sources. Backend firewall policy is managed separately.

## TLS

Caddy uses `tls internal` for the private service names. Install its public root certificate on trusted administrator clients. Never distribute the CA private key.

The current Proxmox upstream uses `tls_insecure_skip_verify: true`. This disables certificate verification on that backend connection and is an existing lab exception. The Rancher and Homepage upstream connections use HTTP inside the LAN. Trusted backend certificates and stronger transport isolation remain improvements to make.

## Apply and Validate

Run on `ubuntu-dev-01`:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible mgmt_servers -m ping
ansible-playbook playbooks/mgmt.yml --syntax-check
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --check --diff
```

The correct inventory group is `mgmt_servers`; the playbook is `playbooks/mgmt.yml`. The playbook also manages baseline security, Tailscale and DNS. Apply after reviewing the expected changes:

```bash
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --diff
```

For the narrower DNS-and-proxy maintenance entry point on an existing gateway, see [Internal DNS](../internal_dns/README.md#apply-configuration).

On `mgmt-01`, inspect the deployed service:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl status caddy --no-pager
sudo journalctl -u caddy -n 50 --no-pager
```

From a client that trusts Caddy's CA and resolves the internal zone:

```bash
curl --connect-timeout 5 --max-time 10 -I https://proxmox.lab.barouconsulting.nl
curl --connect-timeout 5 --max-time 10 -I https://rancher.lab.barouconsulting.nl
curl --connect-timeout 5 --max-time 10 -I https://platform.lab.barouconsulting.nl
```

Check that each response comes from the intended application; redirects and authentication responses can be expected. If CA trust is not installed, use `--cacert /path/to/verified-caddy-root.crt` with a verified public root certificate.

Repeated runs should leave an unchanged Caddyfile and existing rules untouched. A successful service reload should be followed by an application request when routing changes.

## Troubleshooting

| Symptom | First check |
|---|---|
| DNS resolution failure | Query dnsmasq at `192.168.178.106` directly |
| Connection timeout | Check route, listening port and firewall |
| Certificate error | Check hostname, certificate validity and client CA trust |
| HTTP 502 | Check the configured upstream and its reachability from `mgmt-01` |
| Wrong application or ingress 404 | Check the request Host header and Kubernetes Ingress rules |

To test the Kubernetes backends from `mgmt-01`:

```bash
curl --connect-timeout 5 --max-time 10 -I \
  -H 'Host: rancher.lab.barouconsulting.nl' http://192.168.178.111
curl --connect-timeout 5 --max-time 10 -I \
  -H 'Host: platform.lab.barouconsulting.nl' http://192.168.178.111
```

For the existing Proxmox certificate exception, this diagnostic checks HTTP reachability while skipping backend certificate verification:

```bash
curl --connect-timeout 5 --max-time 10 -kI https://192.168.178.10:8006
```

It does not verify the backend's identity. Do not use it as proof that TLS trust is configured correctly.

## Adding a Service

1. Deploy and verify the backend and its resource requirements.
2. Add a DNS record pointing to the gateway.
3. Add a reviewed hostname, protocol, address and port to `reverse_proxy_sites`.
4. Preview and apply the Ansible change.
5. Verify the HTTPS route and update the inventory and service documentation.

For GitLab, hostname, TLS, Git SSH access and runner connectivity belong to the upcoming deployment design. A web reverse-proxy entry alone does not provide Git-over-SSH routing.

Related roles: `common`, `security`, `tailscale_router` and `internal_dns`. See [Management Platform](../../../../docs/management-platform.md) for the combined operating model.
