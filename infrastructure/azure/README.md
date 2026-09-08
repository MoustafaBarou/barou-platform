# Secure Azure Delivery Platform

This directory contains the Azure infrastructure for the Secure Azure Delivery Platform project.

The project demonstrates an enterprise-oriented delivery model using Terraform, Microsoft Entra ID, Azure DevOps and Azure-native container services while remaining suitable for a low-cost portfolio environment.

## Objectives

The platform is designed to demonstrate:

- Infrastructure as Code with Terraform
- Isolated development and production environments
- Remote Terraform state with native state locking
- Microsoft Entra ID authentication without storage keys
- Workload identity federation for Azure DevOps
- Automated infrastructure validation and deployment
- Container image build, security scanning and promotion
- Controlled production deployments with manual approval
- Smoke testing, rollback and approved infrastructure destruction
- Cost-aware Azure architecture

## Implementation Status

| Capability | Status |
|---|---|
| Azure subscription budget and alerts | Implemented |
| Secure Terraform remote state | Implemented |
| Separate development and production state | Implemented |
| Local Azure CLI authentication | Implemented |
| Azure platform foundation module | Planned |
| Azure DevOps workload identity federation | Planned |
| Infrastructure validation pipeline | Planned |
| Infrastructure deployment pipeline | Planned |
| Containerized platform status application | Planned |
| Azure Container Registry | Planned |
| Azure Container Apps development environment | Planned |
| Azure Container Apps production environment | Planned |
| Image security scanning | Planned |
| Production approval and image promotion | Planned |
| Smoke testing and rollback | Planned |
| Approved destroy pipeline | Planned |

## Directory Structure

```text
infrastructure/azure/
├── bootstrap/
│   ├── README.md
│   └── bootstrap-state.sh
├── environments/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── versions.tf
│   │   └── .terraform.lock.hcl
│   └── prod/
│       ├── backend.tf
│       ├── versions.tf
│       └── .terraform.lock.hcl
├── modules/
│   └── platform-foundation/
└── README.md
```

Each environment is an independent Terraform root module with its own backend key and provider lock file.

## Terraform State Architecture

Terraform state is stored in a dedicated Azure Storage Account.

| Setting | Value |
|---|---|
| Region | North Europe |
| Resource group | `rg-barou-tfstate-neu-001` |
| Storage account | `stbaroutf2ad92dcc` |
| Container | `tfstate` |
| Development key | `azure-secure-delivery-platform/dev.tfstate` |
| Production key | `azure-secure-delivery-platform/prod.tfstate` |
| Authentication | Microsoft Entra ID |
| Shared key access | Disabled |
| Public blob access | Disabled |
| Minimum TLS version | TLS 1.2 |
| Blob versioning | Enabled |
| Soft-delete retention | 14 days |
| Resource lock | `CanNotDelete` |

The storage endpoint remains network-accessible so that Microsoft-hosted Azure DevOps agents can reach it. Authorization is enforced through Microsoft Entra ID and Azure RBAC.

No access keys, client secrets or SAS tokens are stored in the repository.

## Authentication Model

### Local development

Local Terraform commands use an authenticated Azure CLI session.

```bash
az login \
  --tenant "<tenant-id>"
```

Select the correct subscription and set the Terraform authentication environment:

```bash
az account set \
  --subscription "Azure subscription 1"

export ARM_USE_CLI="true"

export ARM_SUBSCRIPTION_ID="$(
  az account show \
    --query id \
    --output tsv
)"

export ARM_TENANT_ID="$(
  az account show \
    --query tenantId \
    --output tsv
)"
```

These environment variables apply only to the current terminal session.

### Azure DevOps

Azure DevOps pipelines will use OpenID Connect workload identity federation.

This removes the need for long-lived client secrets. Development and production deployments will use separate service connections and authorization scopes.

## Initialize an Environment

Development:

```bash
terraform \
  -chdir=infrastructure/azure/environments/dev \
  init

terraform \
  -chdir=infrastructure/azure/environments/dev \
  validate
```

Production:

```bash
terraform \
  -chdir=infrastructure/azure/environments/prod \
  init

terraform \
  -chdir=infrastructure/azure/environments/prod \
  validate
```

## Validation

Format all Azure Terraform configuration:

```bash
terraform fmt \
  -check \
  -recursive \
  infrastructure/azure
```

Validate development:

```bash
terraform \
  -chdir=infrastructure/azure/environments/dev \
  validate
```

Validate production:

```bash
terraform \
  -chdir=infrastructure/azure/environments/prod \
  validate
```

## Cost Controls

The Azure subscription has a monthly budget of EUR 50 with multiple notification thresholds.

The planned runtime architecture uses low-cost consumption-based services and conservative scaling:

- Azure Container Apps consumption workload profile
- Minimum replicas set to zero where appropriate
- Maximum replicas limited for the portfolio workload
- Azure Container Registry Basic
- Limited log retention
- No AKS cluster
- No Azure Firewall
- No NAT Gateway
- No Application Gateway
- No private endpoints during the initial portfolio phase

Azure budgets provide notifications and do not enforce a hard spending limit. Resources must still be monitored and destroyed when they are no longer required.

## Security Principles

- No secrets committed to Git
- Microsoft Entra ID authentication preferred over shared keys
- Workload identity federation preferred over client secrets
- Separate development and production state
- Least-privilege RBAC scoped per environment
- Manual approval before production deployment
- Manual approval before destructive operations
- Immutable container image promotion using Git commit identifiers
- Security scanning before deployment
- State recovery through blob versioning and soft delete

## Known Limitations

This is a learning and portfolio environment, not a production service.

The initial implementation uses a single Azure subscription and public Azure service endpoints protected through identity and RBAC. Multi-subscription landing zones, private endpoints, dedicated network appliances and enterprise support plans are outside the current cost target.
