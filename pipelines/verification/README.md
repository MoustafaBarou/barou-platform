# Azure Workload Identity Verification

This directory contains manually executed pipelines that verify Azure DevOps workload identity federation and Terraform backend access.

## Development Pipeline

The development verification pipeline is defined in:

```text
azure-wif-dev.yml
```

It uses the Azure DevOps service connection:

```text
sc-barou-platform-dev-wif
```

## Purpose

The pipeline verifies that Azure DevOps can authenticate to Azure without a client secret and that the development identity has the permissions required for future Terraform pipelines.

It does not create, update or delete Azure platform resources.

## Validated Access

The pipeline validates:

- OpenID Connect workload identity authentication
- The active Azure subscription context
- Access to `rg-barou-platform-dev-neu-001`
- Data-plane access to the `tfstate` blob container
- Terraform AzureRM backend initialization
- Development Terraform configuration validation

## Authentication

The `AzureCLI@2` task receives a short-lived OIDC token from Azure DevOps.

The pipeline maps the federated identity information to the Terraform AzureRM environment variables:

```text
ARM_USE_OIDC
ARM_USE_AZUREAD
ARM_CLIENT_ID
ARM_TENANT_ID
ARM_SUBSCRIPTION_ID
ARM_OIDC_TOKEN
ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID
```

These values exist only for the duration of the pipeline job.

No client secret, storage key or SAS token is required.

## Required Azure Permissions

The development workload identity requires:

| Role | Scope |
|---|---|
| `Contributor` | `rg-barou-platform-dev-neu-001` |
| `Storage Blob Data Contributor` | The `tfstate` blob container |

Contributor access to the Terraform state resource group or storage account is not required.

## Required Azure DevOps Configuration

The pipeline requires:

- An Azure Resource Manager service connection named `sc-barou-platform-dev-wif`
- Workload identity federation enabled on the service connection
- Explicit pipeline permission to use the service connection
- The Terraform Installer extension
- Access to a Microsoft-hosted Ubuntu agent

The service connection must not be configured with the global **Grant access permission to all pipelines** option.

## Run the Pipeline

In Azure DevOps:

1. Open the `Platform Engineering` project.
2. Select **Pipelines**.
3. Open the development workload identity verification pipeline.
4. Select **Run pipeline**.
5. Select the required Git branch.
6. Select **Run**.
7. Open the `Verify development workload identity` stage.
8. Review the `Verify workload identity and Terraform backend` task.

The pipeline has no CI or pull-request trigger and must be started manually.

## First-Run Authorization

The first pipeline execution may pause with the following message:

```text
This pipeline needs permission to access a resource before this run can continue.
```

Select **View**, confirm that the requested resource is `sc-barou-platform-dev-wif`, and approve the pipeline-specific permission.

After granting permission, start a new run or rerun all jobs.

## Expected Result

A successful run confirms:

- The Azure DevOps federated identity is trusted by Microsoft Entra ID.
- The service connection can authenticate without a secret.
- The identity can read the development resource group.
- The identity can access the remote Terraform state container.
- Terraform can initialize the AzureRM backend through OIDC.
- The development Terraform root module is valid.

## Troubleshooting

### Pipeline Is Waiting for Permission

Cause:

The pipeline has not yet been authorized to use the service connection.

Resolution:

1. Open the waiting pipeline job.
2. Select **View** in the permission banner.
3. Approve access to `sc-barou-platform-dev-wif`.
4. Rerun all jobs.

### OIDC Variables Are Missing

Example:

```text
Azure DevOps did not expose an OIDC token.
```

Verify that:

- The service connection uses workload identity federation.
- `addSpnToEnvironment` is enabled in the `AzureCLI@2` task.
- The pipeline references the correct service connection.
- The pipeline has permission to use the service connection.

Do not replace workload identity federation with a client secret as a troubleshooting shortcut.

### Terraform Backend Authorization Failure

Verify that the service principal has the following role:

```text
Storage Blob Data Contributor
```

The role must be assigned at the `tfstate` container scope.

Azure RBAC assignments may require several minutes to propagate.

### Development Resource Group Access Failure

Verify that the development service principal has Contributor access to:

```text
rg-barou-platform-dev-neu-001
```

Do not grant subscription-wide Contributor access to solve a resource-group authorization problem.

### Storage Key Authentication Error

The state storage account has shared key access disabled.

All blob operations must use Microsoft Entra authentication. Azure CLI commands must include:

```text
--auth-mode login
```

Terraform must use Azure AD authentication through:

```text
ARM_USE_AZUREAD=true
```

## Security Notes

- Do not print the OIDC token in pipeline logs.
- Do not store identity tokens as pipeline variables.
- Do not add client secrets to variable groups.
- Do not enable access for all pipelines.
- Do not grant subscription-wide Contributor access.
- Do not publish screenshots containing temporary tokens or sensitive account information.
- Treat pipeline YAML changes as security-sensitive code changes.

## Future Extension

A separate production verification and deployment path will use:

```text
sc-barou-platform-prod-wif
```

Production execution will require environment approvals and will remain isolated from the development identity.
