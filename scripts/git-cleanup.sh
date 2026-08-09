#!/usr/bin/env bash

set -euo pipefail

MAIN_BRANCH="main"

echo "Checking working tree..."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean."
  echo "Commit, stash, or discard your changes before running cleanup."
  exit 1
fi

echo "Switching to ${MAIN_BRANCH}..."
git switch "${MAIN_BRANCH}"

echo "Updating ${MAIN_BRANCH}..."
git pull --ff-only

echo "Pruning deleted remote branches..."
git fetch --prune

echo "Removing merged local branches..."

git branch --merged "${MAIN_BRANCH}" \
  | grep -vE "^\*|^[[:space:]]*${MAIN_BRANCH}$" \
  | xargs -r git branch -d

echo
echo "Repository cleanup complete."
echo

git status
