# Developer Workflow

Development takes place through VS Code Remote SSH on `ubuntu-dev-01`. GitHub hosts the public repository and validation checks. GitLab.com hosts the private project and uses the homelab runner. The platform submission task coordinates both review workflows and synchronizes their `main` branches.

## Working Environment

| Component | Purpose |
|---|---|
| VS Code Remote SSH | Edit files and run commands on the Linux automation host |
| Git, GitHub CLI and GitLab CLI | Version control, review requests, checks and synchronization |
| Python 3 | Run the platform submission coordinator |
| Terraform | Validate, plan and apply infrastructure changes |
| Ansible | Validate and configure hosts |
| kubectl | Inspect and manage the Kubernetes cluster |
| SSH agent / keychain | Reuse an unlocked passphrase-protected SSH key |

The repository is `~/terraform/barou-platform`. The development VM's current LAN address is `192.168.178.101`; its Tailscale address is `100.111.185.114`.

Run repository commands from the repository root unless instructed otherwise. Run Ansible commands from `configuration/ansible` so its `ansible.cfg`, inventory and role paths are selected.

## Start a Change

First inspect the branch and working tree:

```bash
cd ~/terraform/barou-platform
git status --short --branch
```

If work is already in progress, continue on its branch. With a clean working tree, start a new change through the configured helper:

```bash
git start feat/example-change
```

The documented helper uses `scripts/start-feature.sh` to check for existing work or a duplicate branch, update `main` with a fast-forward pull and create the feature branch.

The equivalent manual sequence, starting from a clean tree, is:

```bash
git switch main
git pull --ff-only
git switch -c feat/example-change
```

`--ff-only` updates the branch only when no merge commit is needed. Stop and inspect any failure before continuing with later commands.

## Edit and Inspect

Open the repository in the connected VS Code session:

```bash
code .
```

After saving files:

```bash
git --no-pager diff --check
git --no-pager diff --stat
git --no-pager diff
```

`--check` detects whitespace problems. `--stat` summarizes changed files. The full diff shows what the commit will change; it does not validate the behavior of those changes. `--no-pager` prints directly in the terminal.

Stage intended files explicitly, then inspect the staged diff:

```bash
git add docs/architecture.md
git --no-pager diff --cached --check
git --no-pager diff --cached
```

Use the actual paths belonging to the change. Keep private keys, API tokens, state, kubeconfigs and plan artifacts out of commits.

## Validate

Run the shared checks from the repository root:

```bash
./scripts/validate.sh all
```

The `git validate` alias also runs validation when configured. The script checks Terraform formatting and configuration with backend initialization disabled, plus Ansible syntax and linting. It does not apply infrastructure or connect to managed hosts.

For an operational Ansible change, check the relevant playbook as well. Example for the management gateway:

```bash
cd ~/terraform/barou-platform/configuration/ansible
ansible-playbook playbooks/mgmt.yml --syntax-check
ansible-playbook playbooks/mgmt.yml --limit mgmt_servers --check --diff
```

Check mode is a preview where supported. Review its scope and any limitations before applying. Inspect actual service behavior after a live change.

## Submit, Merge and Synchronize

After reviewing and committing the feature branch, run **Terminal > Run Task >
Platform: submit, merge and sync** in VS Code. The terminal equivalent is:

```bash
git submit
```

This is the manual action that authorizes submission and merging on both
platforms. It waits for GitHub validation checks and GitLab CI, merges the GitLab
MR, updates and validates the GitHub PR, merges it, then synchronizes both `main`
branches. It preserves merge history rather than squashing independently.

For the existing staged-files workflow, use a message:

```bash
git submit 'docs: update platform architecture'
```

The helper validates and commits staged files before submission. It refuses
unstaged or untracked files. An ordinary commit or push does not start the merge
coordinator.

Read [Platform submission](platform-submit.md) for prerequisites, the VS Code
shortcut, exact behavior, preflight and recovery. The same task can resume after
a network interruption. If neither platform has merged and code needs fixing,
commit the correction on the same branch and explicitly use `--restart`.

GitHub and GitLab merges are separate operations. If one has already succeeded,
the helper stops on failure and preserves its record; it never undoes that merge.
Repository rules remain enforced, and missing checks are not treated as success.

## Manual Recovery

Inspect both remote histories before resolving an interrupted synchronization:

```bash
git fetch --all --prune
git --no-pager log --oneline --graph --all -20
git --no-pager diff origin/main gitlab/main
python3 scripts/submit-platform.py --status
```

Follow the recovery instructions in [Platform submission](platform-submit.md).
Keep branches that contain unfinished work. Avoid independently squash-merging
the same change on both platforms: the coordinator requires shared ancestry.

## Custom Commands

| Command | Documented purpose |
|---|---|
| `git start <branch>` | Start from an updated `main` with a clean tree |
| `git validate` | Run Terraform and Ansible validation |
| `git submit ["<message>"]` | Commit staged files if requested; coordinate GitHub/GitLab checks, merges and synchronization |
| `git cleanup` | Update `main`, prune references and clean completed branches |

If a helper is unavailable, inspect local aliases:

```bash
git config --get-regexp '^alias\.(start|validate|submit|cleanup)$'
```

Use the documented script or manual commands rather than assuming an alias exists on a new workstation.

## SSH and Command Practice

Keep private keys passphrase-protected. Check loaded agent identities with `ssh-add -l`; do not put key passphrases in scripts or Git. Investigate changed host keys through a trusted console before updating `known_hosts`.

For Kubernetes practice, learn the full commands first:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -A -o wide
```

`-A` means all namespaces and is uppercase. `show` is not the kubectl command for listing pods. A temporary shell alias can shorten practice commands:

```bash
alias k='kubectl'
k get pods -A
```

This alias lasts for the current shell unless added to shell configuration. An alias changes typing, not network access or permissions.

## Migration Status

Gitea and Jenkins have been retired. GitLab.com and `gitlab-runner-01` are
operational; the Docker smoke pipeline passed. GitHub Actions continues to
provide Terraform and Ansible validation, and the Azure workflows remain in use.

`origin` points to GitHub and `gitlab` points to GitLab.com. The submission task
keeps their main histories aligned. GitLab Terraform and Ansible validation jobs
are a separate planned improvement. Kubernetes and the other lab services stay
running throughout repository submission.
