# Architecture

## Purpose

This document describes the initial architecture of the Barou Platform homelab.

## Hardware

- HP EliteDesk 800 G5 Mini
- Intel Core i5-9500T
- 16 GB RAM
- 256 GB SSD

## Architecture Principles

- Automation First
- Infrastructure as Code
- Security by Default
- Keep It Simple
- Reproducible Deployments
- Git as the Single Source of Truth

## Initial Platform Design

- Proxmox VE as the hypervisor
- Ubuntu Server LTS for virtual machines
- Terraform for infrastructure provisioning
- Cloud-Init for initial VM configuration
- Ansible for configuration management
- Docker for container workloads
- K3s for Kubernetes
- GitHub Actions for CI/CD
- Argo CD for GitOps
- Prometheus, Grafana and Loki running inside Kubernetes

## Initial Virtual Machines

| Name | Purpose | vCPU | RAM | Disk | Status |
|------|---------|-----:|----:|-----:|--------|
| mgmt-01 | Management, Ansible and automation | 2 | 2 GB | 30 GB | Planned |
| k3s-cp-01 | Kubernetes control plane | 2 | 4 GB | 40 GB | Planned |
| k3s-worker-01 | Kubernetes worker node | 4 | 8 GB | 60 GB | Planned |

## Future Expansion

- Second Kubernetes worker
- Dedicated monitoring VM
- Dedicated GitHub Actions runner
- NAS for backups
- High Availability cluster

## Open Decisions

- Final network design
- Final IP address plan
- Storage layout
- VM sizing
- Backup strategy
- Secrets management