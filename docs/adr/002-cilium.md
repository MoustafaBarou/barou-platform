```markdown
# ADR 002: Use Cilium as Kubernetes CNI

## Status

Accepted

## Context

The Kubernetes platform requires a Container Network Interface implementation.

The network layer should support both the initial homelab and future security and observability exercises.

## Decision

Cilium will be used as the Kubernetes CNI.

## Reasons

Cilium provides:

- eBPF-based networking
- Kubernetes NetworkPolicy support
- advanced network security capabilities
- strong observability options
- integration with Hubble
- modern Kubernetes networking concepts

Cilium also creates useful troubleshooting opportunities for:

- pod networking
- service connectivity
- DNS connectivity
- NetworkPolicy
- node-to-node traffic

## Consequences

The Kubernetes cluster will depend on Cilium for pod networking.

Cilium health becomes part of the cluster health model.

Operational documentation must include Cilium troubleshooting commands.

Future observability may include Hubble.

## Future Validation

After deployment, validate:

```bash
kubectl -n kube-system get pods

Cilium-specific validation commands will be added after Cilium is installed.

Security Impact

Cilium will later be used to implement explicit Kubernetes network policies instead of relying on unrestricted pod-to-pod communication.

This provides a platform for practicing zero-trust-style network segmentation inside Kubernetes.
