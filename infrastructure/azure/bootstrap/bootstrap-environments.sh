#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly LOCATION="${AZURE_LOCATION:-northeurope}"
readonly DEV_RESOURCE_GROUP="${DEV_RESOURCE_GROUP:-rg-barou-platform-dev-neu-001}"
readonly PROD_RESOURCE_GROUP="${PROD_RESOURCE_GROUP:-rg-barou-platform-prod-neu-001}"

trap 'echo "ERROR: Environment bootstrap failed near line ${LINENO}." >&2' ERR

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command is unavailable: ${command_name}" >&2
    exit 1
  fi
}

create_environment_resource_group() {
  local resource_group="$1"
  local environment="$2"

  echo "Creating or updating ${environment} resource group: ${resource_group}"

  az group create \
    --name "${resource_group}" \
    --location "${LOCATION}" \
    --tags \
      project="barou-platform" \
      workload="secure-delivery-platform" \
      environment="${environment}" \
      managed-by="bootstrap" \
      purpose="deployment-boundary" \
      cost-center="portfolio" \
    --output none
}

require_command az

echo "Validating the active Azure CLI session..."

if ! az account show >/dev/null 2>&1; then
  echo "ERROR: No authenticated Azure CLI session was found." >&2
  exit 1
fi

SUBSCRIPTION_NAME="$(
  az account show \
    --query name \
    --output tsv
)"

SUBSCRIPTION_STATE="$(
  az account show \
    --query state \
    --output tsv
)"

if [[ "${SUBSCRIPTION_STATE}" != "Enabled" ]]; then
  echo "ERROR: The active Azure subscription is not enabled." >&2
  exit 1
fi

echo "Active subscription: ${SUBSCRIPTION_NAME}"
echo "Azure region: ${LOCATION}"

create_environment_resource_group \
  "${DEV_RESOURCE_GROUP}" \
  "dev"

create_environment_resource_group \
  "${PROD_RESOURCE_GROUP}" \
  "prod"

echo
echo "Environment deployment boundaries:"
echo

az group list \
  --query "[?name=='${DEV_RESOURCE_GROUP}' || name=='${PROD_RESOURCE_GROUP}'].{
    Name:name,
    Location:location,
    Environment:tags.environment,
    ManagedBy:tags.\"managed-by\",
    Provisioning:properties.provisioningState
  }" \
  --output table

echo
echo "Azure environment bootstrap completed successfully."
