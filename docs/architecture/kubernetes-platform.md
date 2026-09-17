# Kubernetes Platform Architecture

The RKE2 cluster is operational. Rancher and Homepage are deployed. Argo CD and the Prometheus/Grafana/Loki stack remain planned. GitLab deployment must preserve the running cluster.

## Nodes and Components

| Host | Role | Static LAN address | vCPU | Memory |
|---|---|---|---:|---:|
| `k8s-cp-01` | RKE2 server, control plane and embedded etcd | `192.168.178.110/24` | 2 | 3072 MiB |
| `k8s-worker-01` | RKE2 agent | `192.168.178.111/24` | 2 | 2048 MiB |

Terraform provisions both VMs. Ansible manages the Linux baseline, security, firewall and RKE2 configuration. RKE2 supplies containerd; the nodes do not require Docker Engine for Kubernetes.

| Component | Function |
|---|---|
| Cilium | Pod networking and NetworkPolicy capability |
| CoreDNS | Cluster DNS and external/internal-zone forwarding |
| ingress-nginx | Hostname-based application ingress |
| Metrics Server | Resource metrics for clients such as kubectl and Homepage |
| Rancher | Kubernetes management in `cattle-system` |
| Homepage | Read-only platform dashboard in `homepage` |

NetworkPolicy capability does not imply that an application isolation policy has been deployed. Hubble is a possible future networking visibility component.

This topology has one etcd member and one worker. It is not highly available; a second VM on the same physical host would not remove the physical-host failure domain.

## Provisioning and Deployment

Terraform configuration lives under `infrastructure/proxmox/`. RKE2 configuration is applied through `configuration/ansible/playbooks/rke2.yml`.

The RKE2 playbook configures firewalls, installs the server, obtains its join token and installs the worker. Sensitive join-token handling uses `no_log`; tokens and kubeconfigs remain outside Git.

Platform manifests live under `kubernetes/platform/`. Their current application is operator-driven. GitHub Actions and Azure static CI validate code; there is no Argo CD reconciliation in place yet.

## Network Configuration

| Setting | Value |
|---|---|
| LAN | `192.168.178.0/24` |
| Gateway | `192.168.178.1` |
| Kubernetes API | `https://192.168.178.110:6443` |
| RKE2 supervisor | `192.168.178.110:9345` |
| Pod CIDR | `10.42.0.0/16` |
| Service CIDR | `10.43.0.0/16` |
| Cluster domain | `cluster.local` |
| Internal DNS forwarder | `192.168.178.106` for `lab.barouconsulting.nl` |
| Public DNS forwarders | `1.1.1.1`, `9.9.9.9` |

The CoreDNS configuration is managed by `configuration/ansible/roles/rke2_server/templates/rke2-coredns-config.yaml.j2`.

The firewall role contains scoped rules for these connections; this table is not an instruction to open the ports to every source:

| Port | Protocol | Purpose |
|---:|---|---|
| 22 | TCP | SSH administration |
| 6443 | TCP | Kubernetes API |
| 9345 | TCP | RKE2 supervisor and registration |
| 10250 | TCP | Kubelet access |
| 4240 | TCP | Cilium node health communication |
| 8472 | UDP | Cilium VXLAN |
| 80 | TCP | Worker ingress access from the management proxy |

`rke2_firewall_admin_ips` allows `.101` and `.102` to reach the control-plane API. `ubuntu-dev-01` currently uses `192.168.178.101`. Worker, pod and proxy rules have their own source restrictions.

## Application Access

DNS resolves Rancher and Homepage names to `mgmt-01` at `.106`. Caddy terminates internal HTTPS and sends HTTP requests to `.111:80`. Kubernetes Ingress rules select the appropriate Service by hostname.

| Application | URL | Namespace |
|---|---|---|
| Rancher | `https://rancher.lab.barouconsulting.nl` | `cattle-system` |
| Homepage | `https://platform.lab.barouconsulting.nl` | `homepage` |

Homepage displays Kubernetes and Proxmox information. Its retired Gitea/Jenkins widget credentials are no longer required.

## Verify Cluster Health

On `ubuntu-dev-01`:

```bash
kubectl get nodes -o wide --request-timeout=10s
kubectl get pods -A --request-timeout=10s
kubectl get ingress -A
kubectl top nodes
```

The last recorded node check reported both nodes `Ready`. A node readiness result does not prove every workload is healthy; inspect pod state and application access separately.

## Diagnose an API Timeout

Start with one layer at a time. On `ubuntu-dev-01`:

```bash
ip route get 192.168.178.110
ping -c 3 -W 2 192.168.178.110
timeout 5 bash -c 'echo > /dev/tcp/192.168.178.110/6443'
echo "Exit code: $?"
```

`ip route get` shows the selected interface and source address. Ping checks ICMP reachability. The TCP probe checks whether port 6443 can be reached; exit code `124` means the timeout expired. Successful ping does not prove the API port is allowed.

On `k8s-cp-01`:

```bash
sudo systemctl status rke2-server --no-pager
sudo ss -lntp 'sport = :6443'
sudo ufw status numbered
sudo journalctl -u rke2-server -n 50 --no-pager
```

`systemctl` checks the service; `ss` checks the listener; `ufw` shows firewall rules; `journalctl` reads recent service logs. A running RKE2 service alone is not proof that remote API access works.

The resolved administration incident had a listening API but only `.102` allowed for administrator access. The client used `.101`. Adding `.101` to the Ansible variable and applying the firewall role restored access without disabling UFW.

For a reviewed firewall change, preview from the Ansible directory, then apply without `--check`:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible-playbook playbooks/rke2-firewall.yml --limit k8s_control_plane --check --diff
```

## Next Steps

Keep the cluster running during the GitLab migration. Future work includes persistent storage, off-host etcd backups and restore testing, Argo CD, observability and application network policies. Additional nodes require a capacity review.

See [RKE2 Runbook](../runbooks/rke2.md), [Kubernetes Troubleshooting](../troubleshooting/kubernetes.md) and [Homepage](../../kubernetes/platform/homepage/README.md).
