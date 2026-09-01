#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

TERRAFORM_DIR="${REPO_ROOT}/infrastructure/proxmox"
ANSIBLE_DIR="${REPO_ROOT}/configuration/ansible"

usage() {
  echo "Usage: $0 [all|terraform|ansible]"
  echo
  echo "Validation targets:"
  echo "  all        Run Terraform and Ansible validation"
  echo "  terraform  Run only Terraform validation"
  echo "  ansible    Run only Ansible validation"
}

check_required_commands() {
  local command_name

  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      echo "Error: required command '${command_name}' is not installed or not in PATH."
      exit 1
    fi
  done
}

validate_terraform() {
  echo
  echo "Checking Terraform tooling..."

  check_required_commands terraform

  echo
  echo "Running Terraform formatting validation..."

  terraform \
    -chdir="${TERRAFORM_DIR}" \
    fmt \
    -check \
    -recursive

  echo
  echo "Initializing Terraform without a backend..."

  terraform \
    -chdir="${TERRAFORM_DIR}" \
    init \
    -backend=false \
    -input=false \
    -no-color >/dev/null

  echo
  echo "Running Terraform configuration validation..."

  terraform \
    -chdir="${TERRAFORM_DIR}" \
    validate \
    -no-color

  echo
  echo "Terraform validation passed."
}

validate_ansible() {
  echo
  echo "Checking Ansible tooling..."

  check_required_commands \
    ansible-playbook \
    ansible-lint

  echo
  echo "Running Ansible syntax validation..."

  (
    cd "${ANSIBLE_DIR}"
    ansible-playbook \
      playbooks/bootstrap.yml \
      --syntax-check
  )

  echo
  echo "Running ansible-lint..."

  (
    cd "${ANSIBLE_DIR}"
    ansible-lint
  )

  echo
  echo "Ansible validation passed."
}

main() {
  local target="${1:-all}"

  if [[ $# -gt 1 ]]; then
    usage
    exit 2
  fi

  case "${target}" in
    all)
      validate_terraform
      validate_ansible
      ;;

    terraform)
      validate_terraform
      ;;

    ansible)
      validate_ansible
      ;;

    -h|--help)
      usage
      ;;

    *)
      echo "Error: unknown validation target '${target}'."
      echo
      usage
      exit 2
      ;;
  esac

  echo
  echo "All requested validation checks passed."
}

main "$@"
