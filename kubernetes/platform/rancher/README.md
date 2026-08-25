# Rancher

This directory contains the declarative configuration for Rancher Manager in the Barou Platform homelab.

## Purpose

Rancher provides a centralized Kubernetes management layer on top of the RKE2 platform.

The current deployment is intended for:

- Kubernetes cluster management
- RBAC and governance practice
- Multi-cluster management experiments
- RKE2 lifecycle learning
- Enterprise platform engineering practice

## Architecture

Rancher runs inside the existing RKE2 cluster.

Current topology:

- Control plane: `k8s-cp-01` (`192.168.178.110`)
- Worker: `k8s-worker-01` (`192.168.178.111`)
- Namespace: `cattle-system`
- Hostname: `rancher.lab.barouconsulting.nl`
- Replicas: `1`
- Ingress controller: RKE2 ingress-nginx
- External reverse proxy: `mgmt-01`

Rancher is intentionally scheduled on the worker node to avoid unnecessary resource contention with etcd and Kubernetes control-plane services.

## Lab vs Production

This deployment is intentionally optimized for a resource-constrained homelab.

Production Rancher environments should normally use:

- Dedicated management Kubernetes infrastructure
- Multiple Rancher replicas
- Multiple control-plane nodes
- High availability
- Production-grade load balancing
- Production certificate management
- Backup and disaster recovery procedures

The current environment uses a single Rancher replica because the platform runs on limited homelab hardware.

## Files

- `namespace.yaml` creates the `cattle-system` namespace.
- `values.yaml` contains the Rancher Helm configuration.

## Validation

Check Rancher pods:

```bash
kubectl -n cattle-system get pods -o wide
