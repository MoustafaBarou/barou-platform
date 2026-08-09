#!/usr/bin/env bash

set -euo pipefail

MAIN_BRANCH="main"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <branch-name>"
  echo "Example: $0 feat/ansible-roles"
  exit 1
fi

BRANCH_NAME="$1"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean."
  echo "Commit, stash, or discard your changes first."
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  echo "Error: local branch '${BRANCH_NAME}' already exists."
  echo "Switch to it with:"
  echo "  git switch ${BRANCH_NAME}"
  exit 1
fi

if git ls-remote --exit-code --heads origin "${BRANCH_NAME}" >/dev/null 2>&1; then
  echo "Error: remote branch '${BRANCH_NAME}' already exists."
  echo "Fetch it first instead of creating a duplicate."
  exit 1
fi

echo "Switching to ${MAIN_BRANCH}..."
git switch "${MAIN_BRANCH}"

echo "Updating ${MAIN_BRANCH}..."
git pull --ff-only

echo "Pruning remote branches..."
git fetch --prune

echo "Creating branch ${BRANCH_NAME}..."
git switch -c "${BRANCH_NAME}"

echo
echo "Ready to work on ${BRANCH_NAME}."
