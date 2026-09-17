# Infrastructure Overview

Barou Platform runs on a single Proxmox host. Terraform provisions VMs, Ansible configures Linux and services, and RKE2 runs Kubernetes workloads. GitHub is the public source repository; GitHub Actions and Azure Pipelines provide code validation.

Gitea and Jenkins have been decommissioned. GitLab and GitLab Runner are planned and are not part of the running inventory yet. Kubernetes and the remaining services must stay running during this migration.

## Physical Platform

| Component | Configuration |
|---|---|
| Device | HP EliteDesk 800 G5 Mini |
| CPU | Intel Core i5-9500T |
| RAM | 16 GB |
| Storage | 256 GB SSD |
| Hypervisor / node | Proxmox VE / `pve` |
| Proxmox LAN address | `192.168.178.10` |
| Bridge | `vmbr0` |
| LAN / gateway | `192.168.178.0/24` / `192.168.178.1` |

A physical-host failure affects the complete lab. There is no production availability guarantee.

## Running VM Inventory

The following inventory reflects the recorded September 2026 configuration and observations. VM IDs and IP addresses are independent; a VM ID does not assign the matching IP address.

| VM ID | Host | LAN address | vCPU | Memory | Responsibility |
|---:|---|---|---:|---:|---|
| 100 | `ubuntu-dev-01` | Observed `192.168.178.101` | 2 | 4096 MiB | Administration and automation; outside the current Proxmox Terraform VM map |
| 103 | `ubuntu-tf-01` | Inventory target `192.168.178.103`; DHCP | 2 | 2048 MiB | Terraform-managed automation target |
| 106 | `mgmt-01` | Static `192.168.178.106/24` | 1 | 1536 MiB | DNS, Caddy and Tailscale subnet router |
| 110 | `k8s-cp-01` | Static `192.168.178.110/24` | 2 | 3072 MiB | RKE2 control plane and etcd |
| 111 | `k8s-worker-01` | Static `192.168.178.111/24` | 2 | 2048 MiB | RKE2 worker |

The last recorded Proxmox inventory also showed stopped VMs 101 (`ubuntu-auto-01`) and 102 (`ubuntu-auto-02`), plus stopped Cloud-Init template 9000. VM 102 is not the current development VM. VMs 104 (`gitea-01`) and 105 (`jenkins-01`) have been removed from the platform.

## Capacity

The five running VMs above have 12,800 MiB (12.5 GiB) of configured RAM in total. Proxmox itself also requires memory. Configured allocation is not the same as measured host usage or available memory.

Removing Gitea and Jenkins removed 5120 MiB (5 GiB) of configured allocation. Take fresh measurements before sizing GitLab and its runners. Account for build load, disk growth and host headroom while all remaining services are running.

On `pve`:

```bash
qm list
free -h
pvesm status
```

These report VM state/allocation, host memory and storage usage respectively. Consult [GitLab installation requirements](https://docs.gitlab.com/install/requirements/) for the selected deployment. GitLab placement and final resource allocations are still pending.

The development VM's root filesystem was expanded from about 14.47 GiB to 24.47 GiB using existing free LVM space. The subsequent observation showed about 9.7 GiB available and 4.47 GiB remaining in the volume group. This was a guest-filesystem change, not additional physical RAM or SSD capacity. Inspect current usage before any further resize:

```bash
df -h /
sudo vgs
```

## Terraform

| Item | Location or value |
|---|---|
| Root configuration | `infrastructure/proxmox/` |
| VM definitions | `infrastructure/proxmox/variables.tf`, `virtual_machines` |
| Reusable module | `infrastructure/proxmox/modules/ubuntu-vm/` |
| Recorded module migration | `infrastructure/proxmox/moved.tf` |
| API endpoint | `https://192.168.178.10:8006/` |
| State | Local for the Proxmox root; excluded from Git |

The module clones template 9000, sets VM identity and resources, connects the virtual NIC to `vmbr0`, configures Cloud-Init networking and the `moustafa` user, injects the public SSH key, enables the guest agent and starts the VM.

The current provider constraint is `bpg/proxmox ~> 0.111`; Terraform is constrained to `~> 1.15.0`. Provider authentication is supplied outside Git, for example through the operator's `PROXMOX_VE_API_TOKEN` environment variable. Never print or commit the token.

The provider currently uses `insecure = true`, disabling API certificate verification. This is an existing lab exception, not a production trust model.

The current state lists `ubuntu-tf-01`, `mgmt-01` and both Kubernetes VMs. Preserve module/resource addresses when refactoring unless a reviewed migration records the change. Removing a managed VM from the map can propose its destruction; always inspect the plan.

From the repository root:

```bash
terraform -chdir=infrastructure/proxmox fmt -check -recursive
terraform -chdir=infrastructure/proxmox validate
terraform -chdir=infrastructure/proxmox plan
```

Validation requires provider initialization; live plans require authentication. A plan is not an apply. Keep plan files outside Git because they can contain sensitive data.

Azure Terraform roots under `infrastructure/azure/` use their own backend and identity configuration. The Azure Storage state work does not change how the Proxmox root stores state.

## Network Addressing

`mgmt-01` and both Kubernetes nodes have static addresses configured through Terraform with gateway `192.168.178.1`. `ubuntu-tf-01` still uses DHCP in Terraform; `.103` is the Ansible inventory target, so verify the lease when diagnosing reachability.

Coordinate static addresses with DHCP exclusions or reservations on the LAN router. Router configuration is outside this Terraform and Ansible configuration and still requires verification.

The management gateway previously obtained `.105` through DHCP while inventory expected `.106`. Its live address now matches the Terraform-configured `.106`. See [Management Platform](management-platform.md) for diagnosis and host-key verification.

## Ansible

The configuration lives in `configuration/ansible/`, using `inventories/homelab/hosts.yml` and the local `ansible.cfg`. SSH host-key checking is enabled.

| Inventory group | Current targets |
|---|---|
| `ubuntu_servers` | `ubuntu-tf-01`, `mgmt-01` |
| `mgmt_servers` | `mgmt-01` |
| `k8s_control_plane` | `k8s-cp-01` |
| `k8s_workers` | `k8s-worker-01` |
| `k8s_cluster` | Control-plane and worker groups |

Roles cover the common baseline, SSH/firewall security, Docker where needed, Tailscale routing, DNS, Caddy and RKE2. The Gitea/Jenkins roles, playbooks and host groups are removed.

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible all -m ping
```

Ansible `ping` checks SSH/module execution and Python availability; it is not an ICMP ping.

## Management Services

`mgmt-01` runs dnsmasq, Caddy and Tailscale. Its Tailscale address is `100.72.132.51`; it advertises the lab subnet for approved clients. Internal DNS serves `lab.barouconsulting.nl`.

| Record | DNS address | HTTP backend |
|---|---|---|
| `mgmt.lab.barouconsulting.nl` | `192.168.178.106` | Host record; no website defined by this record |
| `proxmox.lab.barouconsulting.nl` | `192.168.178.106` | `https://192.168.178.10:8006` |
| `rancher.lab.barouconsulting.nl` | `192.168.178.106` | `http://192.168.178.111:80` |
| `platform.lab.barouconsulting.nl` | `192.168.178.106` | `http://192.168.178.111:80` |

Caddy terminates client HTTPS using its internal CA. Rancher and Homepage share a backend address but have distinct ingress hostnames. Gitea and Jenkins DNS/proxy entries have been removed and the service handlers completed successfully. Client-side resolution and application checks remain separate verification steps.

## Kubernetes Workloads

The RKE2 API is `https://192.168.178.110:6443`. The cluster uses containerd, Cilium, CoreDNS, ingress-nginx and Metrics Server. Rancher runs in `cattle-system`; Homepage runs in `homepage` on the worker.

Homepage now integrates with Kubernetes and Proxmox. Its remaining external credential Secret is `homepage-proxmox`, with `token-id` and `token-secret`. The retired widget Secrets have been deleted, and the updated Deployment rollout succeeded.

CoreDNS forwards the lab zone to `.106` and public queries to `1.1.1.1` and `9.9.9.9`. Cluster configuration and firewall details are documented in [Kubernetes Platform](architecture/kubernetes-platform.md).

```bash
kubectl get nodes -o wide --request-timeout=10s
kubectl get pods -A --request-timeout=10s
kubectl get ingress -A
kubectl top nodes
```

Both nodes reported `Ready` in the recorded check. Recheck after infrastructure changes.

## Remote Administration

From a workstation with authorized Tailscale access:

```bash
ssh moustafa@100.111.185.114
```

After reaching `ubuntu-dev-01`, manage Linux guests over their LAN addresses, for example:

```bash
ssh moustafa@192.168.178.106
ssh moustafa@192.168.178.110
```

Proxmox administration uses the authorized host account; the demonstrated session was `root@pve`. SSH aliases depend on the workstation's SSH configuration and are not automatically created by this documentation.

## Limits and Next Steps

The environment has one physical host, one management gateway, one etcd member and one worker. Persistent Kubernetes storage, off-host backup recovery, full observability and GitOps reconciliation remain incomplete. Some host addressing still depends on DHCP.

The immediate next phase is a capacity-checked GitLab/Runner deployment and validation-only pipeline. Later work includes controlled deployments, Argo CD, persistent storage, backup exercises, stronger secret handling, observability and further Azure development.

Git is the source of desired configuration. Runtime state, private variables, credentials, kubeconfigs and backups require separate protected storage and must not be committed.
