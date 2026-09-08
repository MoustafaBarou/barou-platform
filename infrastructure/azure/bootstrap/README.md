# Terraform State Bootstrap

The bootstrap script creates and secures the Azure Storage resources used by the Terraform remote backend.

Terraform cannot manage its own remote backend before that backend exists. The initial state infrastructure is therefore created through a small, idempotent Azure CLI bootstrap script.

## Created Resources

| Resource | Name |
|---|---|
| Resource group | `rg-barou-tfstate-neu-001` |
| Storage account | `stbaroutf2ad92dcc` |
| Blob container | `tfstate` |
| Delete lock | `lock-tfstate-delete` |

## Security Configuration

The bootstrap applies the following controls:

- HTTPS-only traffic
- Minimum TLS version 1.2
- Public blob access disabled
- Storage shared-key authentication disabled
- Microsoft Entra ID data-plane authentication
- `Storage Blob Data Contributor` assigned to the bootstrap operator
- Blob versioning enabled
- Blob soft delete enabled for 14 days
- Container soft delete enabled for 14 days
- `CanNotDelete` lock applied to the state resource group

The storage public network endpoint remains enabled for compatibility with Microsoft-hosted Azure DevOps agents. Possession of the endpoint name does not grant access; Azure RBAC authorization is still required.

## Prerequisites

The operator requires:

- Azure CLI
- Bash
- An Azure subscription
- Permission to create resource groups and Storage Accounts
- Permission to create Azure role assignments
- Permission to create management locks
- An authenticated Microsoft Entra ID user session

The required Azure resource providers are registered automatically by the script.

## Authenticate Locally

Use interactive browser authentication:

```bash
az login \
  --tenant "<tenant-id>"
```

Select the required subscription from the interactive menu.

Set the subscription explicitly:

```bash
az account set \
  --subscription "Azure subscription 1"
```

Validate the active context:

```bash
az account show \
  --query "{Name:name,State:state,User:user.name}" \
  --output table
```

The subscription state must be `Enabled`.

Device-code authentication may be blocked by Microsoft Entra Security Defaults. Security Defaults must not be disabled to work around this restriction.

## Run the Bootstrap

From the repository root:

```bash
./infrastructure/azure/bootstrap/bootstrap-state.sh
```

The script is idempotent. Existing resources and role assignments are reused where possible.

Successful execution ends with:

```text
Terraform remote-state bootstrap completed successfully.
```

## Optional Overrides

Defaults can be overridden for a single execution:

```bash
AZURE_LOCATION="northeurope" \
TFSTATE_RESOURCE_GROUP="rg-barou-tfstate-neu-001" \
TFSTATE_CONTAINER="tfstate" \
./infrastructure/azure/bootstrap/bootstrap-state.sh
```

The Storage Account name is generated deterministically from the active subscription ID unless `TFSTATE_STORAGE_ACCOUNT` is supplied.

## Validate the Storage Account

```bash
az storage account show \
  --name "stbaroutf2ad92dcc" \
  --resource-group "rg-barou-tfstate-neu-001" \
  --query "{
    HTTPSOnly:enableHttpsTrafficOnly,
    MinimumTLS:minimumTlsVersion,
    PublicBlobAccess:allowBlobPublicAccess,
    SharedKeyAccess:allowSharedKeyAccess,
    Provisioning:provisioningState
  }" \
  --output table
```

Expected controls:

| Control | Expected value |
|---|---|
| HTTPS only | `True` |
| Minimum TLS | `TLS1_2` |
| Public blob access | `False` |
| Shared key access | `False` |
| Provisioning | `Succeeded` |

## Validate Data Protection

```bash
az storage account blob-service-properties show \
  --account-name "stbaroutf2ad92dcc" \
  --resource-group "rg-barou-tfstate-neu-001" \
  --query "{
    Versioning:isVersioningEnabled,
    BlobSoftDelete:deleteRetentionPolicy.enabled,
    BlobRetentionDays:deleteRetentionPolicy.days,
    ContainerSoftDelete:containerDeleteRetentionPolicy.enabled,
    ContainerRetentionDays:containerDeleteRetentionPolicy.days
  }" \
  --output table
```

Versioning and both soft-delete policies must be enabled. Both retention periods must be 14 days.

## Validate the State Container

```bash
az storage container show \
  --name "tfstate" \
  --account-name "stbaroutf2ad92dcc" \
  --auth-mode login \
  --query "{Name:name,PublicAccess:properties.publicAccess}" \
  --output table
```

The container must exist and must not allow public access.

## Validate the Delete Lock

```bash
az lock list \
  --resource-group "rg-barou-tfstate-neu-001" \
  --query "[].{Name:name,Level:level}" \
  --output table
```

Expected result:

```text
Name                 Level
-------------------  ------------
lock-tfstate-delete  CanNotDelete
```

## Troubleshooting

### No authenticated Azure CLI session

```text
ERROR: No authenticated Azure CLI session was found.
```

Authenticate with `az login` and verify the active subscription.

### Region is not accepting new customers

```text
RequestDisallowedByAzure
The selected region is currently not accepting new customers
```

Choose an eligible Azure region and override `AZURE_LOCATION`. Resource availability can differ per subscription.

### Waiting for RBAC propagation

```text
Waiting for Azure RBAC propagation
```

Azure role assignments can take several minutes to become effective. The script retries container creation automatically. If all retries fail, wait several minutes and run the script again.

### Authorization failure

Confirm that the operator can create role assignments and management locks. Subscription `Contributor` alone cannot grant Azure roles.

## Destruction Warning

Terraform state is required to track and safely manage deployed infrastructure. Deleting it can orphan Azure resources and make future changes unsafe.

State infrastructure must only be destroyed through an explicitly approved recovery or decommissioning procedure.

The delete lock must be removed before the resource group can be deleted:

```bash
az lock delete \
  --name "lock-tfstate-delete" \
  --resource-group "rg-barou-tfstate-neu-001"
```

The following command permanently deletes the state infrastructure:

```bash
az group delete \
  --name "rg-barou-tfstate-neu-001" \
  --yes
```

Do not run these commands during normal platform operations.
