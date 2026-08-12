nano docs/developer-workflow.md
# Developer Workflow

This document describes the local development and CI workflow used in the `barou-platform` repository.

The goal of this workflow is to reduce repetitive manual tasks while keeping infrastructure changes safe, reviewable, and reproducible.

---

## Overview

The development workflow follows this process:

```text
Feature branch
    ↓
Local development
    ↓
Stage intended changes
    ↓
Local validation
    ↓
Commit
    ↓
Push
    ↓
Pull request
    ↓
GitHub Actions CI
    ↓
Required status checks
    ↓
Automatic squash merge
    ↓
Post-merge cleanup
    ↓
Clean and updated main branch

The workflow is built around four custom Git commands:

git start
git validate
git submit
git cleanup
Engineering Principles

The workflow follows several engineering principles:

Automation First
Infrastructure as Code
Git as the Single Source of Truth
Fail Fast
Least Privilege
Safe Defaults
Small and Reviewable Changes
Reproducible Validation
Protected Main Branch
Continuous Improvement

Repeated manual tasks should be evaluated for automation when they are performed more than twice.

Automation must reduce operational risk rather than remove necessary safety controls.

Prerequisites

The development environment currently requires:

Git
GitHub CLI
Terraform
Ansible Core
ansible-lint
pipx
SSH
ssh-agent / keychain

GitHub authentication is configured using:

SSH for Git operations
GitHub CLI authentication for GitHub API operations

The SSH private key remains protected by a passphrase.

keychain is used to reuse the unlocked SSH key across shell sessions without storing the passphrase in plain text.

Start a Feature Branch

Use:

git start feat/example-change

Example:

git start feat/ansible-roles

The command uses:

scripts/start-feature.sh

The workflow automatically:

Verifies that the working tree is clean.
Checks whether the requested branch already exists locally.
Checks whether the requested branch already exists remotely.
Switches to main.
Updates main using fast-forward only.
Prunes deleted remote branches.
Creates the requested feature branch.

Example result:

Switching to main...
Updating main...
Pruning remote branches...
Creating branch feat/ansible-roles...

Ready to work on feat/ansible-roles.
Safety

The script refuses to continue when:

uncommitted changes exist;
the requested branch already exists locally;
the requested branch already exists remotely.

This prevents accidentally creating work from an outdated or dirty repository state.

Local Validation

Use:

git validate

The command uses:

scripts/validate.sh

It can be executed from any directory inside the repository.

The validation workflow currently performs:

Terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

This verifies:

Terraform formatting;
provider initialization;
Terraform configuration validity.

The backend is deliberately disabled during validation.

Local validation must not modify infrastructure.

Ansible

The validation workflow performs:

ansible-playbook playbooks/bootstrap.yml --syntax-check
ansible-lint

This validates:

Ansible playbook syntax;
Ansible best practices;
linting rules.

Successful validation ends with:

Terraform validation passed.
Ansible validation passed.
All local validation checks passed.
Stage Changes

Files are staged explicitly before submission.

Example:

git add configuration/ansible/playbooks/bootstrap.yml

Multiple files can be staged when required:

git add \
  configuration/ansible/playbooks/bootstrap.yml \
  configuration/ansible/roles/common/

The workflow deliberately does not automatically execute:

git add .

The developer remains responsible for deciding which files belong in a commit.

This prevents accidental inclusion of unrelated or sensitive files.

Submit a Change

After staging the intended changes, use:

git submit "feat: example change"

Example:

git submit "feat: refactor Ansible into reusable roles"

The command uses:

scripts/submit-change.sh

The submission workflow automatically performs:

Required tool checks
    ↓
Local validation
    ↓
Commit
    ↓
Push
    ↓
Pull request creation
    ↓
Enable automatic squash merge
    ↓
Watch CI checks
    ↓
Wait for PR MERGED state
    ↓
Switch to main
    ↓
Pull latest main
    ↓
Prune deleted remote branches
    ↓
Delete local feature branch
    ↓
Display final repository status
Submit Safety Checks

git submit refuses to continue when:

the repository is in detached HEAD state;
the current branch is main;
required tools are missing;
tracked changes remain unstaged;
untracked files remain in the repository;
no changes or commits exist to submit;
local validation fails;
the pull request is closed without being merged.

The script therefore follows a fail-fast approach.

Pull Request Automation

When no open pull request exists for the current feature branch, git submit creates one automatically using GitHub CLI.

If a pull request already exists, the existing pull request is reused.

The pull request targets:

main

Automatic squash merge is enabled after the pull request is created.

The branch is only merged when all repository rules and required status checks have passed.

GitHub Actions CI

GitHub Actions validates every pull request targeting main.

The CI workflow is stored in:

.github/workflows/ci.yml

Current CI jobs:

Terraform validation

The Terraform job performs:

Checkout repository
Setup Terraform
Terraform format check
Terraform initialization without backend
Terraform validation
Ansible validation

The Ansible job performs:

Checkout repository
Install Ansible development tools
Install required collections
Ansible syntax validation
ansible-lint

Both jobs must succeed before a pull request can be merged.

Branch Protection

The main branch is protected using a GitHub ruleset.

The current protection includes:

Pull request required
Required status checks
Terraform validation required
Ansible validation required
Branch must be up to date before merging
Force pushes blocked
Branch deletion restricted

Direct development on main is not part of the normal workflow.

Merge Strategy

The repository uses:

Squash merge

A feature branch may contain multiple development commits, but the pull request is represented by one commit on main.

Example:

Feature branch

A ─ B ─ C

After squash merge

A ─ S

S represents the combined changes from the feature branch.

Because the original feature commit is not an ancestor of main, Git may not consider the local feature branch traditionally merged.

For that reason, submit-change.sh only force-deletes the local branch after GitHub has explicitly confirmed that the pull request state is:

MERGED

This prevents unsafe branch deletion.

Automatic Post-Merge Cleanup

After GitHub confirms that the pull request has been merged, git submit automatically:

git switch main
git pull --ff-only
git fetch --prune

The completed local feature branch is then removed.

The workflow ends with:

On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean

This means the developer can immediately start the next task.

Manual Repository Cleanup

Manual cleanup remains available using:

git cleanup

The command uses:

scripts/git-cleanup.sh

It automatically:

Verifies that the working tree is clean.
Switches to main.
Updates main using fast-forward only.
Prunes deleted remote branches.
Removes safely merged local branches.
Displays the final repository status.

This command is useful after interrupted workflows or manual operations.

SSH Key Management

Git operations use SSH authentication.

The private SSH key is stored at:

~/.ssh/id_ed25519

The private key remains passphrase protected.

The passphrase is not stored in scripts, Git, environment files, or configuration files.

keychain is used to reuse the SSH agent across login sessions.

The shell configuration initializes keychain with:

if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet id_ed25519)"
fi

The loaded SSH identities can be verified using:

ssh-add -l

After the key has been unlocked, normal Git operations should not repeatedly request the passphrase.

Daily Development Workflow

The normal workflow is intentionally small.

1. Start work
git start feat/example-change
2. Make changes

Edit the required Terraform, Ansible, documentation, or other project files.

3. Stage intended changes
git add <files>
4. Optional local validation
git validate

This is optional because git submit automatically performs validation again.

Running it manually can still be useful during development.

5. Submit
git submit "feat: describe the change"

The rest of the workflow is automated.

Example

A future Ansible role change could use:

git start feat/ansible-common-role

Make the required changes.

Stage them:

git add configuration/ansible/

Then submit:

git submit "feat: add reusable common Ansible role"

The automation then performs:

Validation
→ Commit
→ Push
→ Pull Request
→ GitHub Actions
→ Required Checks
→ Auto Merge
→ Merge Verification
→ Cleanup
→ Clean Main
What Is Deliberately Not Automated

Some operations intentionally remain explicit.

The workflow does not automatically:

stage every changed file;
store SSH private key passphrases;
commit directly to main;
bypass failed CI checks;
bypass branch protection;
force merge failed pull requests;
execute terraform apply;
expose Proxmox credentials to GitHub-hosted runners.

Automation should never bypass safety controls simply to make the workflow faster.

Current Automation Commands
Command	Purpose
git start <branch>	Start a feature branch from an updated main
git validate	Run local Terraform and Ansible quality checks
git submit "<message>"	Validate, commit, push, create PR, merge, and clean up
git cleanup	Restore the repository to a clean and updated main
CI/CD Responsibility Model

The current workflow separates responsibilities:

Terraform
Infrastructure provisioning

Ansible
Operating system configuration

Git
Source of truth

GitHub Actions
Continuous integration

GitHub Rulesets
Merge governance

GitHub CLI
Developer workflow automation

Future platform components will extend this model without replacing these responsibilities.

Future Improvements

Planned improvements include:

reusable Ansible roles;
Docker automation;
Gitea;
Jenkins;
self-hosted CI runners;
automated Terraform plans;
remote Terraform state;
Kubernetes provisioning with Terraform;
RKE2;
Rancher;
Argo CD;
Prometheus;
Grafana;
Loki;
infrastructure health checks;
dependency update automation;
security scanning;
secrets detection;
pre-commit hooks.
Workflow Goal

The intended developer experience is:

git start feat/change

Make and stage the required changes:

git add <files>

Then:

git submit "feat: describe the change"

Everything after that is handled by automated validation, CI, merge governance, and repository cleanup.

The objective is not automation for its own sake.

The objective is a workflow that is:

repeatable;
safe;
auditable;
maintainable;
easy to extend;
difficult to misuse.
