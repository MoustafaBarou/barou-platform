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
| Development resource boundary | Implemented |
| Production resource boundary | Implemented |
| Development workload identity federation | Implemented |
| Production workload identity federation | Implemented |
| Development WIF verification pipeline | Implemented |
| Azure platform foundation module | Planned |
| Infrastructure plan and apply pipeline | Planned |
| Containerized platform status application | Planned |
| Azure Container Registry | Planned |
| Azure Container Apps development environment | Planned |
| Azure Container Apps production environment | Planned |
| Image security scanning | Planned |
| Production approval and image promotion | Planned |
| Smoke testing and rollback | Planned |
| Approved destroy pipeline | Planned |

## Relevant Repository Structure

```text
infrastructure/azure/
├── bootstrap/
│   ├── README.md
│   ├── bootstrap-environments.sh
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

pipelines/verification/
├── README.md
└── azure-wif-dev.yml
```

Each environment is an independent Terraform root module with its own backend key, provider lock file and deployment boundary.

## Resource Boundaries

Development and production use separate Azure resource groups.

| Environment | Resource group | Region |
|---|---|---|
| Development | `rg-barou-platform-dev-neu-001` | North Europe |
| Production | `rg-barou-platform-prod-neu-001` | North Europe |
| Terraform state | `rg-barou-tfstate-neu-001` | North Europe |

The environment resource groups form the primary authorization boundaries for Azure DevOps deployments.

Development and production intentionally use separate workload identities to prevent a development pipeline from automatically receiving production permissions.

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

The storage endpoint remains network-accessible so that Microsoft-hosted Azure DevOps agents can reach it. Authentication and authorization are enforced through Microsoft Entra ID and Azure RBAC.

No access keys, client secrets or SAS tokens are stored in the repository or pipeline configuration.

## Authentication Model

### Local Development

Local Terraform commands use an authenticated Azure CLI session.

```bash
az login \
  --tenant "<tenant-id>"
```

Select the correct subscription:

```bash
az account set \
  --subscription "Azure subscription 1"
```

Set the Terraform authentication environment:

```bash
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

Azure DevOps uses Azure Resource Manager service connections with OpenID Connect workload identity federation.

| Environment | Service connection | Deployment scope |
|---|---|---|
| Development | `sc-barou-platform-dev-wif` | `rg-barou-platform-dev-neu-001` |
| Production | `sc-barou-platform-prod-wif` | `rg-barou-platform-prod-neu-001` |

Both service connections were created using:

- Automatic Microsoft Entra application registration
- Workload identity federation
- Resource-group-level deployment scope
- Separate identities for development and production
- Explicit per-pipeline authorization
- No client secrets
- No permission granted to all pipelines

Each pipeline must be explicitly authorized before it can use a service connection.

## Azure RBAC Model

The service connections use two distinct permissions.

| Identity | Role | Scope |
|---|---|---|
| Development identity | `Contributor` | Development resource group |
| Development identity | `Storage Blob Data Contributor` | Terraform state container |
| Production identity | `Contributor` | Production resource group |
| Production identity | `Storage Blob Data Contributor` | Terraform state container |

The `Contributor` role allows infrastructure resources to be managed inside the appropriate environment resource group.

The `Storage Blob Data Contributor` role provides data-plane access to the Terraform state container. It does not provide broader management access to the storage account or state resource group.

The production identity does not have Contributor access to the development resource group, and the development identity does not have Contributor access to the production resource group.

## Workload Identity Federation Flow

The development verification pipeline proves the following authentication flow:

1. Azure DevOps starts a Microsoft-hosted build agent.
2. Azure DevOps issues a short-lived OIDC token for the authorized service connection.
3. The `AzureCLI@2` task exchanges the token with Microsoft Entra ID.
4. Azure CLI verifies access to the development resource group.
5. Azure CLI verifies data-plane access to the Terraform state container.
6. Terraform initializes the AzureRM backend using OIDC.
7. Terraform validates the development configuration.
8. The temporary token expires after the pipeline execution.

No persistent credential is created or stored during this process.

## Development WIF Verification Pipeline

The verification pipeline is located at:

```text
pipelines/verification/azure-wif-dev.yml
```

It is intentionally configured with:

```yaml
trigger: none
pr: none
```

This prevents the live Azure verification from running automatically during every commit or pull request while the platform is still being built.

The pipeline is started manually from Azure DevOps and uses:

```text
sc-barou-platform-dev-wif
```

The pipeline validates:

- Azure workload identity authentication
- Active Azure subscription context
- Access to the development resource group
- Microsoft Entra data-plane access to the state container
- Terraform AzureRM backend initialization through OIDC
- Terraform configuration validation

The first successful run completed without Azure credentials, client secrets, storage keys or SAS tokens.

See [the verification pipeline runbook](../../pipelines/verification/README.md) for operating and troubleshooting instructions.

## Initialize an Environment Locally

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

## Local Validation

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

Check for whitespace errors:

```bash
git diff \
  --check
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
- No Azure credentials stored in pipeline variables
- Microsoft Entra ID authentication preferred over shared keys
- Workload identity federation preferred over client secrets
- Separate development and production identities
- Separate development and production state
- Least-privilege RBAC scoped per environment
- Explicit pipeline authorization for service connections
- Manual approval before production deployment
- Manual approval before destructive operations
- Immutable container image promotion using Git commit identifiers
- Security scanning before deployment
- State recovery through blob versioning and soft delete

## Operational Validation

Show the current Azure context:

```bash
az account show \
  --query "{Name:name,State:state}" \
  --output table
```

Verify the deployment resource groups:

```bash
az group list \
  --query "[?starts_with(name, 'rg-barou-platform-')].{Name:name,Location:location,State:properties.provisioningState}" \
  --output table
```

Verify the state storage account:

```bash
az storage account show \
  --name "stbaroutf2ad92dcc" \
  --resource-group "rg-barou-tfstate-neu-001" \
  --query "{Name:name,Location:location,SharedKeyAccess:allowSharedKeyAccess,PublicBlobAccess:allowBlobPublicAccess,TLS:minimumTlsVersion}" \
  --output table
```

Verify the state container using Microsoft Entra authentication:

```bash
az storage blob list \
  --account-name "stbaroutf2ad92dcc" \
  --container-name "tfstate" \
  --auth-mode login \
  --query "[].name" \
  --output table
```

## Known Limitations

This is a learning and portfolio environment, not a production service.

The initial implementation uses:

- A single Azure subscription
- Public Azure service endpoints protected through identity and RBAC
- Microsoft-hosted Azure DevOps agents
- Resource groups as the primary environment boundaries
- Manual execution of the live development WIF verification pipeline

Multi-subscription landing zones, private endpoints, dedicated network appliances, self-hosted Azure DevOps agents and enterprise support plans are outside the current cost target.

The current service connections have Contributor access within their environment resource groups. More granular custom roles can be introduced after the exact runtime resource operations are known.

## Next Phase

The next implementation phase introduces the reusable Terraform platform foundation module.

The planned resources include:

- Azure Container Registry Basic
- Azure Container Apps environments
- Development and production Container Apps
- User-assigned managed identities
- Azure Key Vault
- Cost-aware logging and monitoring
- Environment-specific configuration
- Infrastructure plan and apply pipelines
