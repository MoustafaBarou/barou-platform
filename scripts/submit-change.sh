#!/usr/bin/env bash

set -euo pipefail

MAIN_BRANCH="main"
CHECK_REGISTRATION_TIMEOUT=120
MERGE_TIMEOUT=600
POLL_INTERVAL=5

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

CURRENT_BRANCH="$(git branch --show-current)"

# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

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

# Check GitHub CLI authentication.
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated."
  echo "Run:"
  echo "  gh auth login"
  exit 1
fi

# Do not allow unstaged tracked changes.
if ! git diff --quiet; then
  echo "Error: unstaged tracked changes detected."
  echo "Review and stage the intended files before submitting."
  exit 1
fi

# Do not allow untracked files.
if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Error: untracked files detected."
  echo "Review and stage or remove them before submitting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------

if ! git diff --cached --quiet; then

  if [[ $# -lt 1 ]]; then
    echo "Usage:"
    echo "  git submit \"commit message\""
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

  echo
  echo "Refreshing remote main reference..."

  git fetch origin "${MAIN_BRANCH}" --quiet

  COMMIT_COUNT="$(
    git rev-list \
      --count \
      "origin/${MAIN_BRANCH}..HEAD"
  )"

  if [[ "${COMMIT_COUNT}" -eq 0 ]]; then
    echo "Error: no commits exist to submit."
    exit 1
  fi

  echo "Using existing commits on ${CURRENT_BRANCH}."

fi

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------

echo
echo "Pushing ${CURRENT_BRANCH}..."

git push -u origin "${CURRENT_BRANCH}"

# ---------------------------------------------------------------------------
# Pull request
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Auto merge
# ---------------------------------------------------------------------------

echo
echo "Enabling automatic squash merge..."

gh pr merge "${PR_NUMBER}" \
  --auto \
  --squash \
  --delete-branch

# ---------------------------------------------------------------------------
# Wait for CI checks to be registered
# ---------------------------------------------------------------------------

echo
echo "Waiting for CI checks to be registered..."

CHECK_WAIT_START="$(date +%s)"

while true; do

  CHECK_COUNT="$(
    gh pr view "${PR_NUMBER}" \
      --json statusCheckRollup \
      --jq '.statusCheckRollup | length' \
      2>/dev/null || echo "0"
  )"

  if [[ "${CHECK_COUNT}" -gt 0 ]]; then
    echo "CI checks registered: ${CHECK_COUNT}"
    break
  fi

  CURRENT_TIME="$(date +%s)"
  ELAPSED="$((CURRENT_TIME - CHECK_WAIT_START))"

  if [[ "${ELAPSED}" -ge "${CHECK_REGISTRATION_TIMEOUT}" ]]; then
    echo "Error: no CI checks were registered within ${CHECK_REGISTRATION_TIMEOUT} seconds."
    echo "Pull request: #${PR_NUMBER}"
    exit 1
  fi

  echo "No checks registered yet. Waiting ${POLL_INTERVAL}s..."
  sleep "${POLL_INTERVAL}"

done

# ---------------------------------------------------------------------------
# Watch CI
# ---------------------------------------------------------------------------

echo
echo "Watching CI checks..."

if ! gh pr checks "${PR_NUMBER}" --watch; then
  echo
  echo "Error: one or more CI checks failed."
  echo "Pull request #${PR_NUMBER} will not be merged automatically."
  exit 1
fi

echo
echo "All CI checks passed."

# ---------------------------------------------------------------------------
# Wait for actual merge
# ---------------------------------------------------------------------------

echo
echo "Waiting for pull request to be merged..."

MERGE_WAIT_START="$(date +%s)"

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

  CURRENT_TIME="$(date +%s)"
  ELAPSED="$((CURRENT_TIME - MERGE_WAIT_START))"

  if [[ "${ELAPSED}" -ge "${MERGE_TIMEOUT}" ]]; then
    echo "Error: pull request was not merged within ${MERGE_TIMEOUT} seconds."
    echo "Check pull request #${PR_NUMBER} manually."
    exit 1
  fi

  echo "Pull request still open. Waiting ${POLL_INTERVAL}s..."
  sleep "${POLL_INTERVAL}"

done

echo
echo "Pull request #${PR_NUMBER} merged successfully."

# ---------------------------------------------------------------------------
# Post-merge cleanup
# ---------------------------------------------------------------------------

echo
echo "Running post-merge cleanup..."

git switch "${MAIN_BRANCH}"

echo "Updating ${MAIN_BRANCH}..."

git pull --ff-only

echo "Pruning deleted remote branches..."

git fetch --prune

# Squash merges do not preserve the feature branch commits as ancestors
# of main. Git may therefore reject normal `git branch -d`.
#
# Force deletion is safe here because GitHub has already explicitly
# confirmed that the pull request state is MERGED.

if git show-ref --verify --quiet "refs/heads/${CURRENT_BRANCH}"; then
  echo "Removing local feature branch ${CURRENT_BRANCH}..."
  git branch -D "${CURRENT_BRANCH}"
fi

echo
echo "Submission and cleanup completed successfully."

echo
git status
