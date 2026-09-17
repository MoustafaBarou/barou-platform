# Developer Workflow

Development takes place through VS Code Remote SSH on `ubuntu-dev-01`. GitHub remains the public repository and pull-request platform. GitLab CI/CD is planned; it has not replaced the current GitHub workflow.

## Working Environment

| Component | Purpose |
|---|---|
| VS Code Remote SSH | Edit files and run commands on the Linux automation host |
| Git and GitHub CLI | Version control, pull requests and checks |
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

## Submit a Pull Request

The configured helper is:

```bash
git submit "docs: update platform architecture"
```

Its documented workflow validates the change, commits staged files, pushes, creates or reuses a pull request, enables automatic squash merge, waits for merge confirmation and cleans up afterward. **This helper includes merge automation.** Use the manual path if you want to inspect the PR before enabling merge.

The helper scripts under `scripts/` are authoritative. Inspect them when changing the workflow; they are not built-in Git commands.

For manual submission, after validation and staging:

```bash
git commit -m "docs: update platform architecture"
git push -u origin HEAD
```

Write the PR description in a temporary file through VS Code. Explain the problem, what changed, validation results and anything still pending:

```bash
code /tmp/barou-pr-body.md
```

After saving that file:

```bash
gh pr create --base main \
  --title "docs: update platform architecture" \
  --body-file /tmp/barou-pr-body.md
gh pr checks --watch
```

Use a title and description appropriate to the change. Do not treat “no checks reported” as a pass; inspect workflow triggers and required checks.

GitHub Actions provides Terraform and Ansible validation. Azure static CI uses the same validation script. See [CI/CD Architecture](ci-cd.md) for the separate Azure access-verification workflow.

## Merge and Finish the Branch

Review the PR and check results before merging. Once the change is ready and repository rules are satisfied:

```bash
gh pr merge --squash --delete-branch
```

A squash merge creates a new commit containing the branch's changes. It does not preserve the original feature commits as ancestors of `main`.

Confirm the PR state using its number before cleanup. Replace `PR_NUMBER` with that number:

```bash
gh pr view PR_NUMBER --json state,mergedAt,url
```

After it reports `MERGED`, and with no uncommitted work:

```bash
git switch main
git pull --ff-only
git fetch --prune
git status --short --branch
```

The configured `git cleanup` helper can perform normal post-merge cleanup. If Git refuses to delete a squash-merged local branch, first confirm the PR is merged and there are no later local-only changes. A refusal is not a reason to force-delete an unreviewed branch.

## Custom Commands

| Command | Documented purpose |
|---|---|
| `git start <branch>` | Start from an updated `main` with a clean tree |
| `git validate` | Run Terraform and Ansible validation |
| `git submit "<message>"` | Validate, commit, push, open PR, enable merge and clean up |
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

## Migration Work

The current `feat/gitlab-platform` work retires Gitea and Jenkins and prepares for GitLab. Keep implementation status accurate in PRs: the retirement has been applied in the lab, while GitLab and Runner deployment remain pending.

Do not change the Git remote or remove existing CI simply because the new platform is planned. Repository synchronization, GitLab checks, runner isolation and deployment ownership must be implemented and verified first. Kubernetes and the remaining lab services must stay running.
