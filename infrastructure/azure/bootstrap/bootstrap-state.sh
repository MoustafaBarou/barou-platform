#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly LOCATION="${AZURE_LOCATION:-northeurope}"
readonly RESOURCE_GROUP="${TFSTATE_RESOURCE_GROUP:-rg-barou-tfstate-neu-001}"
readonly CONTAINER_NAME="${TFSTATE_CONTAINER:-tfstate}"
readonly DELETE_LOCK_NAME="lock-tfstate-delete"
readonly BLOB_ROLE_NAME="Storage Blob Data Contributor"

trap 'echo "ERROR: Bootstrap failed near line ${LINENO}." >&2' ERR

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command is unavailable: ${command_name}" >&2
    exit 1
  fi
}

require_command az
require_command sha256sum
require_command cut

echo "Validating the active Azure CLI session..."

if ! az account show >/dev/null 2>&1; then
  echo "ERROR: No authenticated Azure CLI session was found." >&2
  echo "Run this script from an authenticated Azure Cloud Shell session." >&2
  exit 1
fi

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
SUBSCRIPTION_NAME="$(az account show --query name --output tsv)"
CURRENT_USER_OBJECT_ID="$(az ad signed-in-user show --query id --output tsv)"

if [[ -z "${SUBSCRIPTION_ID}" || -z "${CURRENT_USER_OBJECT_ID}" ]]; then
  echo "ERROR: The Azure subscription or signed-in user could not be determined." >&2
  exit 1
fi

STORAGE_SUFFIX="$(
  printf '%s' "${SUBSCRIPTION_ID}" |
    sha256sum |
    cut -c1-8
)"

readonly STORAGE_ACCOUNT="${TFSTATE_STORAGE_ACCOUNT:-stbaroutf${STORAGE_SUFFIX}}"

echo "Active subscription: ${SUBSCRIPTION_NAME}"
echo "Resource group: ${RESOURCE_GROUP}"
echo "Storage account: ${STORAGE_ACCOUNT}"
echo "Blob container: ${CONTAINER_NAME}"

echo "Registering required Azure resource providers..."

az provider register \
  --namespace Microsoft.Storage \
  --wait

az provider register \
  --namespace Microsoft.Authorization \
  --wait

echo "Creating or updating the Terraform state resource group..."

az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags \
    project="barou-platform" \
    workload="terraform-state" \
    environment="shared" \
    managed-by="bootstrap" \
  --output none

if az storage account show \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  >/dev/null 2>&1; then
  echo "Reusing existing storage account: ${STORAGE_ACCOUNT}"
else
  echo "Checking global storage account name availability..."

  NAME_AVAILABLE="$(
    az storage account check-name \
      --name "${STORAGE_ACCOUNT}" \
      --query nameAvailable \
      --output tsv
  )"

  if [[ "${NAME_AVAILABLE}" != "true" ]]; then
    echo "ERROR: Storage account name is unavailable: ${STORAGE_ACCOUNT}" >&2
    exit 1
  fi

  echo "Creating the Terraform state storage account..."

  az storage account create \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --public-network-access Enabled \
    --tags \
      project="barou-platform" \
      workload="terraform-state" \
      environment="shared" \
      managed-by="bootstrap" \
    --output none
fi

echo "Enforcing storage account security settings..."

az storage account update \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --public-network-access Enabled \
  --output none

STORAGE_ACCOUNT_ID="$(
  az storage account show \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query id \
    --output tsv
)"

ROLE_ASSIGNMENT_COUNT="$(
  az role assignment list \
    --assignee "${CURRENT_USER_OBJECT_ID}" \
    --scope "${STORAGE_ACCOUNT_ID}" \
    --query "[?roleDefinitionName=='${BLOB_ROLE_NAME}'] | length(@)" \
    --output tsv
)"

if [[ "${ROLE_ASSIGNMENT_COUNT}" == "0" ]]; then
  echo "Granting the signed-in user access to Terraform state blobs..."

  az role assignment create \
    --assignee-object-id "${CURRENT_USER_OBJECT_ID}" \
    --assignee-principal-type User \
    --role "${BLOB_ROLE_NAME}" \
    --scope "${STORAGE_ACCOUNT_ID}" \
    --output none
else
  echo "The required blob RBAC assignment already exists."
fi

echo "Creating the Terraform state container with Entra ID authentication..."

CONTAINER_CREATED="false"

for attempt in {1..18}; do
  if az storage container create \
    --name "${CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none \
    2>/dev/null; then
    CONTAINER_CREATED="true"
    break
  fi

  echo "Waiting for Azure RBAC propagation (${attempt}/18)..."
  sleep 10
done

if [[ "${CONTAINER_CREATED}" != "true" ]]; then
  echo "ERROR: The state container could not be created through Entra ID." >&2
  echo "RBAC propagation may still be in progress. Run the script again later." >&2
  exit 1
fi

echo "Enabling blob versioning and soft-delete protection..."

az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 14 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 14 \
  --output none

LOCK_COUNT="$(
  az lock list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?name=='${DELETE_LOCK_NAME}'] | length(@)" \
    --output tsv
)"

if [[ "${LOCK_COUNT}" == "0" ]]; then
  echo "Adding a CanNotDelete lock to the Terraform state resource group..."

  az lock create \
    --name "${DELETE_LOCK_NAME}" \
    --lock-type CanNotDelete \
    --resource-group "${RESOURCE_GROUP}" \
    --notes "Protects the Terraform remote-state infrastructure from accidental deletion." \
    --output none
else
  echo "The Terraform state delete lock already exists."
fi

echo
echo "Terraform remote-state bootstrap completed successfully."
echo
echo "Backend configuration values:"
echo "  resource_group_name  = \"${RESOURCE_GROUP}\""
echo "  storage_account_name = \"${STORAGE_ACCOUNT}\""
echo "  container_name       = \"${CONTAINER_NAME}\""
echo "  use_azuread_auth      = true"
