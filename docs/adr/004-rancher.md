```markdown
# ADR 004: Rancher for Kubernetes Management

## Status

Accepted

## Context

The Barou Platform homelab uses RKE2 as the Kubernetes distribution.

As the platform expands, Kubernetes management should include more than direct `kubectl` administration.

The environment should provide hands-on experience with:

- Centralized cluster management
- Kubernetes governance
- RBAC
- Cluster lifecycle management
- Multi-cluster operations
- Enterprise-style Kubernetes administration

## Decision

Rancher Manager will be deployed as the Kubernetes management platform.

Rancher will run inside the existing RKE2 cluster during the current homelab phase.

The deployment will use:

- One Rancher replica
- The `cattle-system` namespace
- RKE2 ingress-nginx
- `rancher.lab.barouconsulting.nl`
- External TLS termination
- Worker-node scheduling where possible

## Version Strategy

Rancher versions must be explicitly pinned during installation and upgrades.

The initial target version is:

```text
2.14.4

This version supports the Kubernetes 1.35 version currently used by the RKE2 cluster.

Alternatives Considered
kubectl and Helm only

Direct Kubernetes administration would consume fewer resources but would not provide experience with centralized Kubernetes management and governance.

Kubernetes Dashboard

Kubernetes Dashboard provides basic visibility but does not provide the same cluster lifecycle, RBAC, governance, and multi-cluster capabilities as Rancher.

OpenShift

OpenShift provides a comprehensive enterprise Kubernetes platform but would be unnecessarily heavy for the current homelab resources and would significantly change the platform architecture.

Consequences
Positive
Centralized Kubernetes management
RKE2-native management experience
Multi-cluster capabilities
Strong enterprise learning value
Improved visibility into Kubernetes resources
Negative
Additional resource consumption
Additional platform dependency
Rancher itself becomes part of the management plane
A single replica is not highly available
Production Consideration

A production Rancher environment should normally use dedicated and highly available Kubernetes infrastructure.

The current design intentionally accepts lower availability because it is a resource-constrained homelab and learning environment.
