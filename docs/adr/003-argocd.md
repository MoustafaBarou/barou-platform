```markdown
# ADR 003: Use Argo CD for GitOps

## Status

Accepted

## Context

The Kubernetes platform requires a GitOps solution for declarative application and platform deployment.

Flux CD and Argo CD were considered.

## Decision

Argo CD will be used as the primary GitOps platform.

## Reasons

Argo CD provides:

- declarative Kubernetes deployments
- Git as the desired state
- synchronization status
- drift detection
- rollback workflows
- a strong visual interface
- broad industry adoption
- useful integration with existing Git repositories

The platform already uses Git as the central workflow for Terraform and Ansible.

Argo CD extends this approach into Kubernetes.

## Desired Workflow

```text
Developer
    |
    v
Git repository
    |
    v
Pull Request
    |
    v
CI validation
    |
    v
Merge
    |
    v
Argo CD
    |
    v
Kubernetes cluster
Repository Direction

Kubernetes configuration will eventually be stored declaratively in Git.

A future repository structure may include:

kubernetes/
├── applications/
├── infrastructure/
├── clusters/
└── environments/

The exact structure will be defined when the GitOps phase begins.

Consequences

Manual changes directly in the Kubernetes cluster should gradually become the exception.

Git becomes the source of truth for managed Kubernetes resources.

Configuration drift can then be detected and corrected through Argo CD.

Troubleshooting Value

Argo CD will also be used for controlled break/fix exercises such as:

failed synchronization
invalid manifests
missing namespaces
incorrect Helm values
drift between Git and the cluster
unhealthy applications
