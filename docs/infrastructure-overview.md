# Infrastructure Overview

## Overview

Barou Platform is a self-hosted DevOps homelab running on a single HP EliteDesk.

The environment is used to build practical experience with:

- Infrastructure as Code
- Configuration management
- Linux administration
- Container platforms
- Kubernetes
- CI/CD
- GitOps
- Platform security
- Monitoring and logging
- Day-two operations

The platform is built in layers. Proxmox provides virtualization, Terraform creates the virtual machines, Ansible configures the operating systems and services, and RKE2 runs the Kubernetes workloads.

GitHub is the public source repository and portfolio. Gitea and Jenkins provide a separate self-hosted environment for learning Git hosting and CI/CD operations.

## Physical Platform

| Component | Configuration |
|---|---|
| Device | HP EliteDesk 800 G5 Mini |
| Processor | Intel Core i5-9500T |
| Memory | 16 GB |
| Storage | 256 GB SSD |
| Hypervisor | Proxmox VE |
| Proxmox address | `192.168.178.10` |
| Proxmox node | `pve` |
| Network bridge | `vmbr0` |
| Default gateway | `192.168.178.1` |

The current platform runs on one physical host. A hardware failure therefore affects the complete environment.

This is acceptable for the current learning environment, but it is not a highly available design.

## Virtual Machines

| VM ID | Hostname | IP address | Function | Resources |
|---:|---|---|---|---|
| 102 | `ubuntu-dev-01` | `192.168.178.102` | Development and management workstation | Not managed by the current Terraform module |
| 103 | `ubuntu-tf-01` | `192.168.178.103` | Terraform-managed Ubuntu automation target | 2 vCPU, 2 GB RAM |
| 104 | `gitea-01` | `192.168.178.104` | Gitea and PostgreSQL | 2 vCPU, 2 GB RAM |
| 105 | `jenkins-01` | `192.168.178.105` | Jenkins controller | 2 vCPU, 3 GB RAM |
| 106 | `mgmt-01` | `192.168.178.106` | DNS, Caddy and Tailscale routing | 1 vCPU, 1.5 GB RAM |
| 110 | `k8s-cp-01` | `192.168.178.110` | RKE2 control plane and etcd | 2 vCPU, 3 GB RAM |
| 111 | `k8s-worker-01` | `192.168.178.111` | RKE2 worker node | 2 vCPU, 2 GB RAM |

`ubuntu-dev-01` is the main administration machine. The Git repository, Terraform CLI, Ansible, kubectl, GitHub CLI and SSH configuration are available on this machine.

The other servers are managed remotely from `ubuntu-dev-01`.

## Architecture

```text
HP EliteDesk
└── Proxmox VE
    ├── ubuntu-dev-01
    │   ├── Git repository
    │   ├── Terraform
    │   ├── Ansible
    │   ├── kubectl
    │   └── SSH management
    │
    ├── ubuntu-tf-01
    │   └── Terraform-managed Ubuntu target
    │
    ├── gitea-01
    │   ├── Docker
    │   ├── Gitea
    │   └── PostgreSQL
    │
    ├── jenkins-01
    │   ├── Docker
    │   └── Jenkins
    │
    ├── mgmt-01
    │   ├── dnsmasq
    │   ├── Caddy
    │   └── Tailscale
    │
    ├── k8s-cp-01
    │   ├── RKE2 server
    │   ├── Kubernetes API
    │   └── etcd
    │
    └── k8s-worker-01
        ├── RKE2 agent
        └── Application workloads
```

## Infrastructure Management

### Terraform

Terraform manages the Proxmox virtual machines.

The configuration is stored in:

```text
infrastructure/proxmox/
```

The root configuration uses the reusable module:

```text
infrastructure/proxmox/modules/ubuntu-vm/
```

The module is responsible for:

- Cloning the Ubuntu Cloud-Init template
- Assigning the VM ID and hostname
- Configuring CPU and memory
- Connecting the VM to `vmbr0`
- Configuring network settings
- Creating the Linux user
- Injecting the SSH public key
- Enabling the QEMU guest agent
- Starting the VM

The virtual machines are defined in the `virtual_machines` map in:

```text
infrastructure/proxmox/variables.tf
```

Terraform state is currently stored locally and is excluded from Git.

The Proxmox provider connects to:

```text
https://192.168.178.10:8006/
```

The environment currently accepts the self-signed Proxmox certificate through:

```hcl
insecure = true
```

This is suitable for the isolated homelab but should not be treated as a production security standard.

### Network Configuration

The Kubernetes nodes use static IP addresses configured through Terraform.

The other Terraform-managed virtual machines currently receive their addresses through DHCP. Their current addresses are referenced by Ansible, SSH and the internal platform configuration.

The current address of `ubuntu-tf-01` has been validated as:

```text
192.168.178.103/24
```

A future infrastructure change will move the remaining server addresses to an explicitly managed static configuration or documented DHCP reservations.

### State Migration

The following file records the migration of `ubuntu-tf-01` from a standalone Terraform resource to the reusable VM module:

```text
infrastructure/proxmox/moved.tf
```

The moved block preserves the existing VM in Terraform state. It prevents Terraform from treating the refactor as a request to destroy and recreate the VM.

### Ansible

Ansible configures the operating systems and platform services after Terraform creates the virtual machines.

The Ansible configuration is stored in:

```text
configuration/ansible/
```

The homelab inventory is stored in:

```text
configuration/ansible/inventories/homelab/hosts.yml
```

The inventory uses the following host groups:

| Inventory group | Purpose |
|---|---|
| `ubuntu_servers` | General Ubuntu baseline servers |
| `gitea_servers` | Gitea hosts |
| `jenkins_servers` | Jenkins hosts |
| `mgmt_servers` | Management, DNS and reverse proxy hosts |
| `k8s_control_plane` | RKE2 server nodes |
| `k8s_workers` | RKE2 agent nodes |
| `k8s_cluster` | All Kubernetes nodes |

The main Ansible roles are:

| Role | Responsibility |
|---|---|
| `common` | Packages, timezone and unattended upgrades |
| `security` | SSH hardening and host firewall |
| `docker` | Docker Engine and Docker repository |
| `gitea` | Gitea and PostgreSQL deployment |
| `jenkins` | Jenkins deployment |
| `tailscale_router` | Remote access routing |
| `internal_dns` | Internal DNS records |
| `reverse_proxy` | HTTPS and reverse proxy configuration |
| `rke2_firewall` | Required RKE2 network ports |
| `rke2_server` | RKE2 control-plane installation |
| `rke2_agent` | RKE2 worker installation |

## Platform Services

### Gitea

Gitea runs on `gitea-01` through Docker Compose.

| Setting | Value |
|---|---|
| Host | `gitea-01` |
| Internal IP | `192.168.178.104` |
| Application port | `3000/TCP` |
| Platform URL | `https://gitea.lab.barouconsulting.nl` |
| Database | PostgreSQL |
| Deployment method | Ansible and Docker Compose |

The Gitea database password is supplied to Ansible through:

```text
GITEA_DB_PASSWORD
```

The password is not stored in Git.

### Jenkins

Jenkins runs on `jenkins-01` through Docker Compose.

| Setting | Value |
|---|---|
| Host | `jenkins-01` |
| Internal IP | `192.168.178.105` |
| Application port | `8080/TCP` |
| Platform URL | `https://jenkins.lab.barouconsulting.nl` |
| Deployment method | Ansible and Docker Compose |

Jenkins is used to build practical experience with self-hosted CI/CD.

The Homepage integration will use a dedicated read-only Jenkins account and API token. The token will remain outside Git.

### Management Services

`mgmt-01` provides shared network and access services for the platform.

It runs:

- dnsmasq for internal DNS
- Caddy for HTTPS and reverse proxy
- Tailscale for remote connectivity

Internal DNS uses the zone:

```text
lab.barouconsulting.nl
```

Service records point to `192.168.178.106`. Caddy receives the request and forwards it to the correct backend.

| DNS name | Caddy upstream |
|---|---|
| `gitea.lab.barouconsulting.nl` | `http://192.168.178.104:3000` |
| `jenkins.lab.barouconsulting.nl` | `http://192.168.178.105:8080` |
| `proxmox.lab.barouconsulting.nl` | `https://192.168.178.10:8006` |
| `rancher.lab.barouconsulting.nl` | `http://192.168.178.111:80` |
| `platform.lab.barouconsulting.nl` | `http://192.168.178.111:80` |

Caddy uses its internal certificate authority for HTTPS inside the homelab.

### Request Flow

A request to Jenkins follows this path:

```text
Client
  ↓
Internal DNS
  ↓
jenkins.lab.barouconsulting.nl → 192.168.178.106
  ↓
Caddy on mgmt-01
  ↓
192.168.178.105:8080
  ↓
Jenkins container
```

The same pattern is used for Gitea, Proxmox, Rancher and Homepage.

## Kubernetes Platform

The Kubernetes cluster uses RKE2.

| Node | Role | IP address |
|---|---|---|
| `k8s-cp-01` | Control plane and etcd | `192.168.178.110` |
| `k8s-worker-01` | Worker | `192.168.178.111` |

The Kubernetes API is available at:

```text
https://192.168.178.110:6443
```

The RKE2 supervisor is available at:

```text
192.168.178.110:9345
```

The cluster uses:

- containerd as the container runtime
- Cilium as the CNI
- CoreDNS for cluster DNS
- ingress-nginx as the ingress controller
- Metrics Server for resource metrics
- Embedded etcd on the control-plane node

### RKE2 Deployment

The Ansible playbook is:

```text
configuration/ansible/playbooks/rke2.yml
```

The deployment order is:

1. Configure the RKE2 firewall on all nodes.
2. Install and configure the RKE2 server.
3. Read the generated node token.
4. Pass the token to the worker configuration.
5. Install and start the RKE2 agent.
6. Join the worker to the cluster.

The join token is handled with `no_log: true` and is not written to Git.

### Cluster DNS

CoreDNS resolves Kubernetes service names and forwards external queries.

Public DNS queries are forwarded to:

```text
1.1.1.1
9.9.9.9
```

Queries for the internal homelab zone are forwarded to:

```text
lab.barouconsulting.nl → 192.168.178.106
```

The CoreDNS configuration is managed through Ansible:

```text
configuration/ansible/roles/rke2_server/templates/rke2-coredns-config.yaml.j2
```

This allows pods to resolve public domains and internal platform domains.

## Kubernetes Workloads

### Rancher

Rancher runs inside the RKE2 cluster.

| Setting | Value |
|---|---|
| Namespace | `cattle-system` |
| URL | `https://rancher.lab.barouconsulting.nl` |
| Purpose | Kubernetes cluster management |
| External routing | Caddy through `mgmt-01` |
| In-cluster routing | ingress-nginx |

Rancher currently runs with one replica because the homelab has one worker node.

### Homepage

Homepage provides a central platform dashboard.

| Setting | Value |
|---|---|
| Namespace | `homepage` |
| URL | `https://platform.lab.barouconsulting.nl` |
| Scheduled node | `k8s-worker-01` |
| Deployment method | Kubernetes manifests |

The manifests are stored in:

```text
kubernetes/platform/homepage/
```

Homepage currently displays:

- Kubernetes cluster CPU and memory
- Kubernetes node CPU and memory
- Proxmox VM, LXC and resource information
- Gitea repositories, notifications, issues and pull requests
- Platform service links

Homepage uses a dedicated ServiceAccount with read-only Kubernetes RBAC permissions.

External credentials are stored in Kubernetes Secrets:

| Secret | Purpose | Status |
|---|---|---|
| `homepage-proxmox` | Proxmox API access | Deployed |
| `homepage-gitea` | Gitea API access | Deployed |
| `homepage-jenkins` | Jenkins API access | Planned |

The secret values are created directly in Kubernetes and are not committed to Git.

## CI Validation

GitHub Actions validates repository changes.

The workflow is stored in:

```text
.github/workflows/ci.yml
```

The workflow currently performs the following checks.

### Terraform

- Formatting validation
- Provider initialization without a backend
- Configuration validation

### Ansible

- Installation of Ansible development tools
- Installation of required collections
- Playbook syntax validation
- ansible-lint

The GitHub-hosted runner does not have access to the private Proxmox network. It performs static validation but does not run:

- `terraform plan`
- `terraform apply`
- Ansible deployments
- Kubernetes deployments

Infrastructure-aware automation will require a controlled runner inside the homelab.

## Remote Access

Remote administration is provided through Tailscale.

`ubuntu-dev-01` is the main remote entry point for the homelab.

| Network interface | IP address | Purpose |
|---|---|---|
| LAN | `192.168.178.102/24` | Management from the home network |
| Tailscale | `100.111.185.114/32` | Encrypted remote management access |

The remote administration path is:

```text
Remote client
  ↓
Tailscale network
  ↓
ubuntu-dev-01
  ↓
Home network
  ↓
Platform virtual machines
```

After connecting to `ubuntu-dev-01`, the remaining virtual machines are managed through their private `192.168.178.0/24` addresses.

The Tailscale address of the remote client depends on the client device and is not part of the fixed platform configuration.

## Administration

The environment is normally managed from:

```text
ubuntu-dev-01
```

### SSH Access

The following SSH aliases are configured on `ubuntu-dev-01`:

```bash
ssh ubuntu-tf-01
ssh gitea-01
ssh jenkins-01
ssh mgmt-01
ssh k8s-cp-01
ssh k8s-worker-01
ssh proxmox
```

The aliases are stored in:

```text
~/.ssh/config
```

### Kubernetes Access

Kubernetes is managed from `ubuntu-dev-01` with kubectl.

Basic cluster validation commands:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get ingress -A
kubectl top nodes
kubectl top pods -A
```

### Ansible Access

Ansible uses the homelab inventory configured in:

```text
configuration/ansible/ansible.cfg
```

Basic connectivity validation:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible all -m ping
```

Ansible `ping` tests the inventory, SSH authentication and Python availability. It does not send an ICMP network ping.

### Terraform Access

Terraform is executed from:

```text
infrastructure/proxmox/
```

The normal validation sequence is:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

The Terraform plan must be reviewed before running `terraform apply`.

## Source of Truth

The Git repository is the source of truth for:

- Terraform configuration
- Ansible configuration
- Docker Compose templates
- Kubernetes manifests
- CI workflows
- Architecture decisions
- Infrastructure documentation
- Operational runbooks

The following data is intentionally stored outside Git:

- Terraform state
- Private Terraform variable files
- API tokens
- Passwords
- SSH private keys
- Kubeconfig credentials
- RKE2 join tokens
- Kubernetes Secret values

## Current Limitations

The current environment has the following known limitations:

- One physical Proxmox host
- One RKE2 control-plane node
- One RKE2 worker node
- One embedded etcd member
- No Kubernetes StorageClass
- No remote Terraform backend
- No external etcd snapshot storage
- Limited physical memory
- No complete observability stack
- No GitOps reconciliation
- Some server IP addresses still depend on DHCP
- Internal certificates depend on the Caddy internal CA

The platform is suitable for learning and controlled homelab use. It is not designed to provide production availability.

## Planned Improvements

The next platform improvements are:

1. Complete the Homepage integrations.
2. Add Jenkins build and job status.
3. Add Rancher health information.
4. Introduce Argo CD.
5. Add Prometheus, Grafana and Loki.
6. Configure persistent Kubernetes storage.
7. Improve etcd backup and recovery.
8. Introduce namespace security controls and NetworkPolicies.
9. Move server networking to a consistent declarative model.
10. Build Azure landing-zone-style foundations.
11. Compare self-managed RKE2 with Azure Kubernetes Service.
