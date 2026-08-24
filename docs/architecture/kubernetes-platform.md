# Kubernetes Platform Architecture

## Purpose

This document describes the Kubernetes platform architecture used in the Barou Platform homelab.

The platform is designed as a practical environment for learning Infrastructure as Code, configuration management, Kubernetes operations, GitOps, observability, security and troubleshooting.

The goal is not only to deploy Kubernetes, but to manage the complete lifecycle of the platform through code.

## Current Architecture

The Kubernetes infrastructure currently consists of two virtual machines running on Proxmox VE.

| Hostname | Role | IP Address | vCPU | Memory |
| --- | --- | --- | ---: | ---: |
| k8s-cp-01 | RKE2 Control Plane | 192.168.178.110 | 2 | 3072 MB |
| k8s-worker-01 | RKE2 Worker | 192.168.178.111 | 2 | 2048 MB |

The virtual machines are provisioned through Terraform.

The operating system baseline is configured through Ansible.

## Platform Layers

The platform is divided into multiple management layers.

### Infrastructure

Proxmox VE provides the virtualization platform.

Terraform manages the lifecycle of Kubernetes virtual machines.

Responsibilities include:

- VM provisioning
- VM resource configuration
- Cloud-Init
- networking
- SSH key deployment
- static IP configuration

### Operating System Configuration

Ansible manages the Linux configuration.

The Kubernetes nodes currently receive:

- common operating system configuration
- security hardening
- SSH configuration
- firewall configuration

Docker is intentionally not installed on the Kubernetes nodes.

RKE2 provides its own container runtime based on containerd.

### Kubernetes Distribution

RKE2 is used as the Kubernetes distribution.

The initial topology consists of:

- one RKE2 server
- one RKE2 agent

This is intentionally not a highly available cluster.

The current homelab hardware has limited resources and the environment is optimized for learning and development.

### Container Networking

Cilium is the selected Kubernetes CNI.

Cilium will provide:

- pod networking
- Kubernetes NetworkPolicy support
- eBPF-based networking
- future network observability through Hubble

### Cluster Management

Rancher will be deployed after the base RKE2 cluster is operational.

Rancher will provide centralized Kubernetes cluster management.

### GitOps

Argo CD will be used for GitOps.

Application and platform configuration will gradually move toward a declarative Git-based deployment model.

### Observability

The planned observability stack consists of:

- Prometheus
- Grafana
- Loki

Cilium Hubble may later be added for Kubernetes network visibility.

## Architecture Flow

```text
GitHub / Gitea
      |
      v
CI Validation
      |
      v
Terraform + Ansible
      |
      v
Proxmox VE
      |
      +--------------------------+
      |                          |
      v                          v
k8s-cp-01                  k8s-worker-01
RKE2 Server                RKE2 Agent
192.168.178.110             192.168.178.111
      |                          |
      +------------+-------------+
                   |
                   v
                 RKE2
                   |
                   v
                Cilium
                   |
                   v
                Rancher
                   |
                   v
                Argo CD
                   |
         +---------+---------+
         |                   |
         v                   v
     Workloads          Observability
                        Prometheus
                        Grafana
                        Loki
Network Configuration
Node Network

Homelab network:

192.168.178.0/24

Default gateway:

192.168.178.1

Control plane:

192.168.178.110

Worker:

192.168.178.111
Kubernetes Networks

Planned Pod CIDR:

10.42.0.0/16

Planned Service CIDR:

10.43.0.0/16

Cluster domain:

cluster.local
Important Ports
Port	Protocol	Purpose
22	TCP	SSH administration
6443	TCP	Kubernetes API
9345	TCP	RKE2 supervisor and node registration

Additional ports will be documented when Rancher, ingress and observability components are deployed.

Security Principles

The Kubernetes platform follows these principles:

Infrastructure as Code
configuration as code
no secrets stored in Git
SSH key authentication
restrictive firewall policies
separate control plane and worker roles
Git-based change management
idempotent Ansible configuration
controlled network exposure
documented operational procedures
Current State

Completed:

Kubernetes virtual machines provisioned through Terraform
static IP configuration managed through Terraform
Ansible inventory configured
Kubernetes node groups configured
common Linux baseline applied
security baseline applied
idempotency validated

Current result:

k8s-cp-01      changed=0 failed=0
k8s-worker-01  changed=0 failed=0
Next Steps

The next implementation steps are:

Deploy the RKE2 server
Deploy the RKE2 agent
Validate cluster health
Configure Cilium
Deploy Rancher
Deploy Argo CD
Implement GitOps workflows
Deploy Prometheus, Grafana and Loki
Add controlled failure scenarios
Document troubleshooting and recovery procedures
