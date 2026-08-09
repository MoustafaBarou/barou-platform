#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

TERRAFORM_DIR="${REPO_ROOT}/infrastructure/proxmox"
ANSIBLE_DIR="${REPO_ROOT}/configuration/ansible"

required_commands=(
  terraform
  ansible-playbook
  ansible-lint
)

echo "Checking required tools..."

for command in "${required_commands[@]}"; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Error: required command '${command}' is not installed or not in PATH."
    exit 1
  fi
done

echo
echo "Running Terraform validation..."

terraform -chdir="${TERRAFORM_DIR}" fmt -check -recursive

terraform -chdir="${TERRAFORM_DIR}" init \
  -backend=false \
  -input=false \
  -no-color >/dev/null

terraform -chdir="${TERRAFORM_DIR}" validate -no-color

echo
echo "Terraform validation passed."

echo
echo "Running Ansible syntax validation..."

cd "${ANSIBLE_DIR}"

ansible-playbook playbooks/bootstrap.yml --syntax-check

echo
echo "Running ansible-lint..."

ansible-lint

echo
echo "Ansible validation passed."

echo
echo "All local validation checks passed."
