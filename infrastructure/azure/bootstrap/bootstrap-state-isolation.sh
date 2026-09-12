#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'echo "ERROR: State isolation bootstrap failed near line ${LINENO}." >&2' ERR

readonly EXPECTED_SUBSCRIPTION_ID="87f73c0b-752b-4fb2-8252-feac195ef886"
readonly STATE_RESOURCE_GROUP="rg-barou-tfstate-neu-001"
readonly STATE_STORAGE_ACCOUNT="stbaroutf2ad92dcc"
readonly BLOB_ROLE="Storage Blob Data Contributor"

readonly DEV_PRINCIPAL_OBJECT_ID="bf0c718e-2a13-415d-b3c5-d99797e35882"
readonly PROD_PRINCIPAL_OBJECT_ID="24d1b16b-696c-4f73-8938-b96423e44673"

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIRECTORY

echo "Validating the active subscription..."

ACTIVE_SUBSCRIPTION_ID="$(
  az account show --query id --output tsv
)"

if [[ "${ACTIVE_SUBSCRIPTION_ID}" != "${EXPECTED_SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: The active subscription does not match this platform." >&2
  exit 1
fi

echo "Validating the development and production identities..."

for principal_id in \
  "${DEV_PRINCIPAL_OBJECT_ID}" \
  "${PROD_PRINCIPAL_OBJECT_ID}"
do
  az ad sp show \
    --id "${principal_id}" \
    --output none
done

echo "Creating or verifying the environment state containers..."

for container_name in tfstate-dev tfstate-prod; do
  AZURE_LOCATION="northeurope" \
  TFSTATE_RESOURCE_GROUP="${STATE_RESOURCE_GROUP}" \
  TFSTATE_STORAGE_ACCOUNT="${STATE_STORAGE_ACCOUNT}" \
  TFSTATE_CONTAINER="${container_name}" \
    bash "${SCRIPT_DIRECTORY}/bootstrap-state.sh"
done

STORAGE_ACCOUNT_ID="$(
  az storage account show \
    --name "${STATE_STORAGE_ACCOUNT}" \
    --resource-group "${STATE_RESOURCE_GROUP}" \
    --query id \
    --output tsv
)"

if [[ -z "${STORAGE_ACCOUNT_ID}" ]]; then
  echo "ERROR: The storage account ID could not be resolved." >&2
  exit 1
fi

ensure_container_role() {
  local container_name="$1"
  local principal_id="$2"
  local container_scope
  local assignment_count

  container_scope="${STORAGE_ACCOUNT_ID}/blobServices/default/containers/${container_name}"

  assignment_count="$(
    az role assignment list \
      --assignee-object-id "${principal_id}" \
      --scope "${container_scope}" \
      --query "[?roleDefinitionName=='${BLOB_ROLE}'] | length(@)" \
      --output tsv
  )"

  if [[ "${assignment_count}" == "0" ]]; then
    echo "Assigning ${BLOB_ROLE} on ${container_name}..."

    az role assignment create \
      --assignee-object-id "${principal_id}" \
      --assignee-principal-type ServicePrincipal \
      --role "${BLOB_ROLE}" \
      --scope "${container_scope}" \
      --output none
  else
    echo "The role assignment on ${container_name} already exists."
  fi

  az role assignment list \
    --assignee-object-id "${principal_id}" \
    --scope "${container_scope}" \
    --query "[].{Principal:principalId,Role:roleDefinitionName,Scope:scope}" \
    --output table
}

ensure_container_role "tfstate-dev" "${DEV_PRINCIPAL_OBJECT_ID}"
ensure_container_role "tfstate-prod" "${PROD_PRINCIPAL_OBJECT_ID}"

echo
echo "Environment state containers and role assignments are prepared."
echo "Existing state blobs and shared-container permissions are unchanged."
echo "State migration and pipeline verification must complete before cleanup."
