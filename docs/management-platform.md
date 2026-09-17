# Management Platform

`mgmt-01` provides internal DNS, HTTPS reverse proxying and Tailscale subnet routing for the homelab. Terraform manages the VM; Ansible manages its operating system and services.

Gitea and Jenkins have been retired. The active application routes serve Proxmox, Rancher and Homepage. GitLab routing will be added after the new platform is deployed and verified.

## Gateway Configuration

| Setting | Value |
|---|---|
| VM / Proxmox ID | `mgmt-01` / `106` |
| vCPU / memory | 1 / 1536 MiB |
| LAN address | `192.168.178.106/24`, static through Terraform |
| LAN gateway | `192.168.178.1` |
| LAN interface | `eth0` |
| Tailscale address | `100.72.132.51` |
| Advertised subnet | `192.168.178.0/24` |
| Ansible playbook / group | `playbooks/mgmt.yml` / `mgmt_servers` |

The management playbook includes `common`, `security`, `tailscale_router`, `internal_dns` and `reverse_proxy`.

## DNS and HTTPS

dnsmasq listens on loopback, the gateway LAN address and its Tailscale address. Tailscale Split DNS forwards the internal zone to this resolver. RKE2 CoreDNS forwards the same zone to its LAN address.

| DNS name | Address | Caddy destination |
|---|---|---|
| `mgmt.lab.barouconsulting.nl` | `192.168.178.106` | Host record only |
| `proxmox.lab.barouconsulting.nl` | `192.168.178.106` | `https://192.168.178.10:8006` |
| `rancher.lab.barouconsulting.nl` | `192.168.178.106` | `http://192.168.178.111:80` |
| `platform.lab.barouconsulting.nl` | `192.168.178.106` | `http://192.168.178.111:80` |

Clients first resolve a name, then connect to Caddy on `.106`. DNS is not an HTTP proxy hop. Caddy terminates HTTPS; Rancher and Homepage requests then pass through Kubernetes ingress, which selects the Service by hostname.

Caddy uses an internal CA. Distribute only its public root certificate to trusted clients. Protect the CA private key. The Proxmox backend currently skips upstream certificate verification; the two Kubernetes upstream routes use HTTP within the LAN. These are documented transport limitations.

UFW manages explicit SSH, DNS, HTTP/HTTPS and routed-traffic rules. Tailscale route approval, access policy and client route use are separate from the VM's route advertisement.

## Apply Management Changes

On `ubuntu-dev-01`:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible mgmt_servers -m ping
ansible-playbook playbooks/mgmt.yml --syntax-check
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --check --diff
```

Review all predicted changes. Check mode can skip runtime checks or predict package/download changes differently from a real run. Apply the complete playbook when its full scope is intended:

```bash
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --diff
```

For an already configured gateway, the retirement used this narrower entry point:

```bash
ansible-playbook playbooks/mgmt.yml \
  --limit mgmt_servers \
  --start-at-task "internal_dns : Install internal DNS packages" \
  --diff
```

This runs DNS tasks followed by reverse-proxy tasks, skipping earlier roles. It is not a full bootstrap or a validation of the skipped roles. The recorded retirement run completed with `ok=17`, `changed=4`, `unreachable=0`, `failed=0`: two configuration changes and two handlers.

## Verify Services

On `mgmt-01`:

```bash
sudo dnsmasq --test
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl status dnsmasq caddy --no-pager
sudo journalctl -u dnsmasq -u caddy -n 50 --no-pager
```

From `ubuntu-dev-01`:

```bash
dig @192.168.178.106 proxmox.lab.barouconsulting.nl +short
dig @192.168.178.106 rancher.lab.barouconsulting.nl +short
dig @192.168.178.106 platform.lab.barouconsulting.nl +short
```

Expect `.106`. Test application HTTPS from a client with internal DNS and Caddy CA trust configured. A successful Ansible handler is not a substitute for checking the request path.

## Diagnose an Unreachable Gateway

On `ubuntu-dev-01`, inspect the selected route, ICMP reachability and neighbor entry:

```bash
ip route get 192.168.178.106
ping -c 3 -W 2 192.168.178.106
ip neigh show 192.168.178.106
```

For a directly connected LAN address, a `FAILED` neighbor entry points to failed neighbor resolution. Check the VM's state, virtual networking and actual IP before treating this as an SSH authentication failure.

From the trusted Proxmox host console, run each command separately:

```bash
qm status 106
qm guest cmd 106 network-get-interfaces
qm config 106 | grep -E '^(name|net[0-9]+|ipconfig[0-9]+):'
qm guest exec 106 -- ip -4 route
```

The guest commands require a working QEMU guest agent. If it is unavailable, use the VM console instead.

The resolved incident showed VM 106 running with DHCP address `.105` while inventory expected `.106`. The Terraform map was changed to static `192.168.178.106/24` with gateway `.1`; the reviewed plan showed one in-place change and no additions or destructions. The guest now reports `.106`.

Coordinate `.106` with DHCP reservations or exclusions on the router to prevent duplicate allocation. The guest's live address does not prove that router configuration has been checked.

## Verify a Changed SSH Host Key

An unexpected host key must be verified through a trusted path before accepting it. From the trusted Proxmox console, obtain the VM's public-key fingerprint:

```bash
qm guest exec 106 -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Compare it with the ED25519 fingerprint reported by the SSH client. If it matches the intended VM, remove only that stale destination entry on `ubuntu-dev-01`, then reconnect and compare again:

```bash
ssh-keygen -R 192.168.178.106
ssh moustafa@192.168.178.106
```

If removal reports “not found”, there is no matching entry in that file. If SSH still reports a mismatch, inspect the exact hostname, port and known-hosts file named in the error. Keep host-key checking enabled.

## VS Code and Administration

VS Code Remote SSH connects to `ubuntu-dev-01`, where Git, Terraform and Ansible run. Its Tailscale address is `100.111.185.114`, distinct from the gateway's Tailscale address.

Run guest administration commands on the named guest, Proxmox `qm` commands on `pve`, and Ansible commands from the development VM. This distinction prevents diagnosing the wrong host or applying commands in the wrong environment.

Related role documentation: [Tailscale Router](../configuration/ansible/roles/tailscale_router/README.md), [Internal DNS](../configuration/ansible/roles/internal_dns/README.md) and [Reverse Proxy](../configuration/ansible/roles/reverse_proxy/README.md).
