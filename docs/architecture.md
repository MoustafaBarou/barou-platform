HP EliteDesk / Proxmox VE
│
├── ubuntu-dev-01
│   ├── Terraform
│   ├── Ansible
│   ├── Git / GitHub CLI
│   └── Developer automation
│
├── Infrastructure provisioned by Terraform
│
├── Docker workloads
│
├── Gitea
│   └── Self-hosted Git
│
├── Jenkins
│   └── Self-hosted CI/CD
│
└── Kubernetes platform
    ├── RKE2 control plane
    ├── RKE2 worker(s)
    │
    ├── Rancher
    │   └── Cluster management
    │
    ├── Argo CD
    │   └── GitOps
    │
    └── Observability
        ├── Prometheus
        ├── Grafana
        └── Loki

GitHub
├── Public portfolio
├── Pull requests
├── GitHub Actions
├── Required CI checks
└── Branch protection / rulesets

En op termijn eventueel:

Rancher
├── dev cluster
└── prod-lab cluster
Eén belangrijk probleem: je hardware

Op je architecture.md staat:

16 GB RAM
256 GB SSD

Met één RKE2-cluster + Rancher + Jenkins + Gitea + Prometheus + Grafana + Loki kom je snel tegen je 16 GB RAM aan. Twee clusters tegelijk plus alle tooling zou ik op deze hardware niet als vaste always-on architectuur ontwerpen.

Dus professioneel gezien zou ik documenteren:

Current hardware:
16 GB RAM

Design approach:
Workloads are introduced incrementally and resource usage is monitored.
Additional RAM may be required before running the full platform concurrently.

Ik zou niet doen alsof 16 GB probleemloos voldoende is voor de volledige eindarchitectuur.

Conclusie: de architecture is niet slecht; hij was correct voor de eerste ontwerpversie. Maar we zijn er inmiddels voorbij gegroeid. Dit is juist normaal in een levend platformproject.

Ik zou hem nu als volgende change actualiseren naar Architecture v2, voordat we fase 1 afsluiten. Dan is je GitHub-portfolio ook consistent met wat je werkelijk aan het bouwen bent.

laten we het documenteren

Ja. Dan maken we docs/architecture.md meteen actueel en portfolio-waardig.

Open:

nano docs/architecture.md

Vervang de volledige inhoud door dit:

# Architecture

## Purpose

This document describes the current and target architecture of the Barou Platform homelab.

The platform is designed as a practical DevOps learning environment focused on automation, Infrastructure as Code, configuration management, CI/CD, containerization, Kubernetes, GitOps, and observability.

The architecture is developed incrementally. Components are introduced in phases and validated before the next platform layer is added.

---

## Hardware

Current physical platform:

- HP EliteDesk 800 G5 Mini
- Intel Core i5-9500T
- 16 GB RAM
- 256 GB SSD

The current hardware is sufficient for the initial platform phases, but the complete target platform may require additional memory and storage when multiple services and Kubernetes clusters are running concurrently.

Resource usage will therefore be monitored throughout the project and the platform will be expanded when required.

---

## Engineering Principles

The platform follows these engineering principles:

- Automation First
- Infrastructure as Code
- Security by Default
- Git as the Single Source of Truth
- Reproducible Deployments
- Fail Fast
- Least Privilege
- Small and Reviewable Changes
- Documentation First
- Continuous Improvement
- Simplicity over unnecessary complexity

Repeated manual operations are evaluated for automation when they are performed more than twice.

Automation must reduce operational risk rather than remove important safety controls.

---

## Platform Layers

The target platform is divided into several logical layers.

```text
Physical Hardware
        ↓
Proxmox VE
        ↓
Virtual Machines
        ↓
Infrastructure as Code
        ↓
Configuration Management
        ↓
Container Platform
        ↓
CI/CD Platform
        ↓
Kubernetes
        ↓
Cluster Management
        ↓
GitOps
        ↓
Observability
Current Architecture

The current environment consists of:

HP EliteDesk 800 G5 Mini
        │
        └── Proxmox VE
              │
              ├── ubuntu-dev-01
              │     ├── Terraform
              │     ├── Ansible
              │     ├── Git
              │     ├── GitHub CLI
              │     ├── SSH
              │     ├── Tailscale
              │     └── Developer workflow automation
              │
              ├── ubuntu-tf-01
              │     └── Terraform-managed Ubuntu VM
              │
              └── Ubuntu Cloud-Init template
                    └── Source template for automated VM provisioning
Proxmox Virtualization Layer

Proxmox VE is the hypervisor for the homelab.

Responsibilities include:

virtual machine lifecycle management;
virtual networking;
storage management;
Cloud-Init integration;
VM templates;
resource allocation;
VM startup configuration;
QEMU guest agent integration.

The Proxmox API is used by Terraform to provision virtual machines automatically.

Infrastructure as Code

Terraform is responsible for infrastructure provisioning.

Current responsibilities:

connecting to the Proxmox API;
cloning the Ubuntu Cloud-Init template;
configuring VM resources;
configuring networking;
injecting Cloud-Init configuration;
injecting SSH public keys;
managing VM lifecycle declaratively.

Terraform configuration is stored in:

infrastructure/proxmox/

Infrastructure changes are validated through both local automation and GitHub Actions.

Terraform state is currently local and will be migrated to an appropriate remote state solution in a future phase.

Configuration Management

Ansible is responsible for operating system and server configuration after Terraform has provisioned the infrastructure.

Current responsibilities include:

package installation;
APT package cache management;
firewall configuration;
baseline Ubuntu configuration;
SSH-based remote configuration.

Current Ansible configuration is stored in:

configuration/ansible/

The current bootstrap playbook will be refactored into reusable Ansible roles.

Planned role structure:

roles/
├── common
├── security
├── docker
└── monitoring

Additional roles will be introduced as the platform grows.

Developer Workflow

The repository uses an automated local developer workflow.

Available commands:

git start <branch>
git validate
git submit "<commit message>"
git cleanup

The workflow provides:

Updated main branch
        ↓
Feature branch
        ↓
Local development
        ↓
Explicit staging
        ↓
Local validation
        ↓
Commit
        ↓
Push
        ↓
Pull request
        ↓
GitHub Actions
        ↓
Required status checks
        ↓
Automatic squash merge
        ↓
Merge verification
        ↓
Repository cleanup
        ↓
Clean main branch

Supporting scripts are stored in:

scripts/

Detailed workflow documentation is available in:

docs/developer-workflow.md
GitHub

GitHub remains the public source repository and portfolio for the project.

GitHub currently provides:

public source control;
pull requests;
GitHub Actions;
automated Terraform validation;
automated Ansible validation;
repository rulesets;
required status checks;
protected main branch;
automatic squash merge;
automatic remote branch cleanup.

Direct development on main is not part of the normal workflow.

CI/CD Architecture

The current CI layer uses GitHub Actions.

Current CI checks:

Terraform
formatting validation;
Terraform initialization without backend;
configuration validation.
Ansible
dependency installation;
collection installation;
playbook syntax validation;
ansible-lint.

Both jobs are required before a pull request can be merged into main.

The current GitHub-hosted CI runners do not receive access to the private Proxmox API.

Infrastructure-aware Terraform plans will later use a self-hosted runner inside the homelab.

Container Platform

Docker will be introduced after the Ansible role foundation is complete.

Docker will initially be used to run self-hosted platform services before Kubernetes is introduced.

Planned workloads include:

Gitea;
Jenkins;
supporting platform services.

Docker installation and configuration will be automated using Ansible.

Gitea

Gitea will provide a self-hosted Git platform inside the homelab.

Its purpose is to provide experience with operating and integrating an internal source control platform.

GitHub will remain the public portfolio and external repository.

The intended model is:

GitHub
└── Public portfolio and external source repository

Gitea
└── Self-hosted Git platform for homelab workloads
Jenkins

Jenkins will be introduced as a self-hosted CI/CD platform.

Its purpose is to provide hands-on experience with:

pipeline configuration;
agents;
credentials;
build automation;
CI/CD integrations;
self-hosted runners;
pipeline troubleshooting.

GitHub Actions will continue to provide repository-level quality gates.

Jenkins will complement GitHub Actions rather than replace it.

Kubernetes Platform

Kubernetes nodes will be provisioned using Terraform.

The Kubernetes distribution selected for the main homelab cluster is RKE2.

RKE2 was selected because it provides a production-oriented Kubernetes distribution while remaining suitable for a homelab learning environment.

The target design is:

Proxmox VE
    │
    ├── rke2-cp-01
    │     └── RKE2 control plane
    │
    └── rke2-worker-01
          └── RKE2 worker node

Additional worker nodes may be added when resources permit.

Rancher

Rancher will be deployed after the RKE2 cluster is operational.

Rancher will provide:

Kubernetes cluster management;
cluster health visibility;
lifecycle management;
RBAC;
multi-cluster management;
cluster upgrade management.

The long-term goal is to manage multiple clusters where useful.

Example:

Rancher
├── dev cluster
└── prod-lab cluster

Multiple clusters will only be introduced when the available hardware can support them without creating unnecessary resource pressure.

Argo CD

Argo CD will provide GitOps-based application delivery to Kubernetes.

Responsibilities include:

continuously comparing Git with cluster state;
detecting configuration drift;
synchronizing Kubernetes workloads;
declarative application deployment;
controlled Git-based changes.

Argo CD manages workloads running inside Kubernetes.

Rancher and Argo CD therefore have different responsibilities:

Rancher
└── Kubernetes cluster management

Argo CD
└── Kubernetes workload deployment through GitOps
Observability

The observability stack will be introduced after Rancher and Argo CD.

Planned components:

Prometheus
Grafana
Loki

Responsibilities:

Prometheus
└── Metrics collection

Grafana
└── Visualization and dashboards

Loki
└── Centralized log aggregation

These components are expected to run inside Kubernetes once sufficient platform capacity is available.

Target Architecture

The target architecture is:

HP EliteDesk 800 G5 Mini
        │
        ▼
Proxmox VE
        │
        ├── Ubuntu development / automation node
        │       ├── Terraform
        │       ├── Ansible
        │       ├── Git
        │       └── GitHub CLI
        │
        ├── Docker platform services
        │       ├── Gitea
        │       └── Jenkins
        │
        └── Kubernetes infrastructure
                │
                ├── RKE2 control plane
                ├── RKE2 worker node(s)
                │
                ├── Rancher
                │       └── Cluster management
                │
                ├── Argo CD
                │       └── GitOps
                │
                └── Observability
                        ├── Prometheus
                        ├── Grafana
                        └── Loki

GitHub remains external to the homelab:

GitHub
├── Public portfolio
├── Pull requests
├── GitHub Actions
├── Required CI checks
└── Repository governance
Network Access

Private homelab administration uses Tailscale.

Current use cases include:

remote SSH access;
remote Proxmox administration;
secure access to internal management systems.

Internal Proxmox and Ubuntu services are not exposed directly to the public Internet.

Security Model

Current security principles include:

SSH key authentication;
passphrase-protected SSH private keys;
reusable SSH agent using keychain;
protected main branch;
required CI checks;
least-privilege GitHub Actions permissions;
no Proxmox credentials on GitHub-hosted CI runners;
secrets excluded from Git;
Terraform state excluded from Git;
private infrastructure accessed through Tailscale;
firewall configuration through Ansible.

Additional security controls will be added as the platform matures.

Resource Considerations

The current host contains 16 GB RAM.

The full target platform contains multiple resource-intensive workloads:

Jenkins;
Gitea;
RKE2;
Rancher;
Prometheus;
Grafana;
Loki.

The entire platform should therefore not be assumed to run concurrently without evaluating resource consumption.

The preferred engineering approach is:

introduce services incrementally;
measure CPU, memory, and storage consumption;
optimize resource allocation;
expand physical resources where justified.

Potential future upgrades include:

additional RAM;
larger SSD storage;
additional Proxmox nodes.
Platform Roadmap

The platform is developed in the following order:

CI/CD automation
Ansible roles
Docker
Gitea + Jenkins
Kubernetes nodes via Terraform
RKE2 cluster
Rancher
Argo CD
Prometheus + Grafana + Loki

Each phase builds on the previous phase.

The objective is to understand and automate every platform layer rather than installing all components at once.

Future Expansion

Potential future improvements include:

additional Proxmox hardware;
Proxmox clustering;
additional RKE2 worker nodes;
separate development and production lab clusters;
Rancher multi-cluster management;
remote Terraform state;
infrastructure-aware self-hosted CI runners;
automated Terraform plan reporting;
controlled Terraform apply workflows;
dependency update automation;
security scanning;
secrets scanning;
infrastructure backup automation;
disaster recovery testing;
centralized DNS;
automated certificate management.
Architecture Goal

The final architecture should demonstrate the complete lifecycle of a modern platform:

Git
 ↓
CI validation
 ↓
Infrastructure as Code
 ↓
Automated provisioning
 ↓
Configuration management
 ↓
Containers
 ↓
Kubernetes
 ↓
Cluster management
 ↓
GitOps
 ↓
Observability

The goal is not simply to install tools.

The goal is to understand how each layer integrates into a secure, automated, reproducible, and maintainable DevOps platform.
