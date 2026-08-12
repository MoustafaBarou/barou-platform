#!/usr/bin/env bash

set -euo pipefail

MAIN_BRANCH="main"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

CURRENT_BRANCH="$(git branch --show-current)"

if [[ -z "${CURRENT_BRANCH}" ]]; then
  echo "Error: detached HEAD state detected."
  exit 1
fi

if [[ "${CURRENT_BRANCH}" == "${MAIN_BRANCH}" ]]; then
  echo "Error: changes cannot be submitted directly from '${MAIN_BRANCH}'."
  echo "Create a feature branch first."
  exit 1
fi

required_commands=(
  git
  gh
)

echo "Checking required tools..."

for command in "${required_commands[@]}"; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Error: required command '${command}' is not installed or not in PATH."
    exit 1
  fi
done

if ! git diff --quiet; then
  echo "Error: unstaged tracked changes detected."
  echo "Review and stage the intended files before submitting."
  exit 1
fi

if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Error: untracked files detected."
  echo "Review and stage or remove them before submitting."
  exit 1
fi

if ! git diff --cached --quiet; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: git submit \"commit message\""
    exit 1
  fi

  COMMIT_MESSAGE="$1"

  echo
  echo "Running local validation..."

  "${REPO_ROOT}/scripts/validate.sh"

  echo
  echo "Creating commit..."

  git commit -m "${COMMIT_MESSAGE}"
else
  echo "No staged changes detected."

  if [[ "$(git rev-list --count "origin/${MAIN_BRANCH}..HEAD")" -eq 0 ]]; then
    echo "Error: no commits exist to submit."
    exit 1
  fi

  echo "Using existing commits on ${CURRENT_BRANCH}."
fi

echo
echo "Pushing ${CURRENT_BRANCH}..."

git push -u origin "${CURRENT_BRANCH}"

PR_NUMBER="$(
  gh pr list \
    --head "${CURRENT_BRANCH}" \
    --base "${MAIN_BRANCH}" \
    --state open \
    --json number \
    --jq '.[0].number // empty'
)"

if [[ -z "${PR_NUMBER}" ]]; then
  echo
  echo "Creating pull request..."

  PR_URL="$(
    gh pr create \
      --base "${MAIN_BRANCH}" \
      --head "${CURRENT_BRANCH}" \
      --fill
  )"

  echo "${PR_URL}"

  PR_NUMBER="$(
    gh pr list \
      --head "${CURRENT_BRANCH}" \
      --base "${MAIN_BRANCH}" \
      --state open \
      --json number \
      --jq '.[0].number'
  )"
else
  echo
  echo "Existing pull request #${PR_NUMBER} found."
fi

echo
echo "Enabling automatic squash merge..."

gh pr merge "${PR_NUMBER}" \
  --auto \
  --squash \
  --delete-branch

echo
echo "Watching CI checks..."

gh pr checks "${PR_NUMBER}" --watch

echo
echo "Submission completed successfully."
echo "Pull request #${PR_NUMBER} passed all CI checks."

echo
echo "Watching CI checks..."

gh pr checks "${PR_NUMBER}" --watch

echo
echo "Waiting for pull request to be merged..."

while true; do
  PR_STATE="$(
    gh pr view "${PR_NUMBER}" \
      --json state \
      --jq '.state'
  )"

  if [[ "${PR_STATE}" == "MERGED" ]]; then
    break
  fi

  if [[ "${PR_STATE}" == "CLOSED" ]]; then
    echo "Error: pull request was closed without being merged."
    exit 1
  fi

  sleep 5
done

echo
echo "Pull request #${PR_NUMBER} merged successfully."

echo
echo "Running post-merge cleanup..."

git switch "${MAIN_BRANCH}"
git pull --ff-only
git fetch --prune

if git show-ref --verify --quiet "refs/heads/${CURRENT_BRANCH}"; then
  echo "Removing local feature branch ${CURRENT_BRANCH}..."
  git branch -D "${CURRENT_BRANCH}"
fi

echo
echo "Submission and cleanup completed successfully."

git status
