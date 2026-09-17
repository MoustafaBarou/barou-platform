# Submit, merge and synchronize the platform

Run one VS Code task on `ubuntu-dev-01` to submit a committed feature branch,
wait for CI, merge through GitLab and GitHub, and synchronize their `main` branches.
The existing `git submit` helper calls the same coordinator.

## Prerequisites

- Open `~/terraform/barou-platform` through VS Code Remote SSH on `ubuntu-dev-01`.
- Python 3, Git, GitHub CLI (`gh`) and GitLab CLI (`glab`) must be available there.
- `origin` must refer to `MoustafaBarou/barou-platform` on GitHub.
- `gitlab` must refer to the same project path on GitLab.com.
- Existing Git credentials must permit pushing feature branches on both platforms.
- The user must be permitted to merge PRs/MRs and fast-forward GitLab `main`.
- Keep the SSH key available in the agent; this task cannot answer a key prompt.
- GitHub and GitLab `main` must start at the same commit.
- The feature branch must include that commit and contain reviewed changes.

Check CLI access without displaying tokens:

```bash
gh auth status --hostname github.com
glab auth status --hostname gitlab.com
```

This uses the existing local logins. It does not put tokens in the repository,
create CI credentials, change branch protection, or enable administrative bypasses.

## Daily use

1. Start a feature branch with `git start feat/example` or the manual Git workflow.
2. Edit, save and review the changes in VS Code.
3. Stage and commit the intended files. The VS Code task requires a clean working tree.
4. Open **Terminal > Run Task** and select **Platform: submit, merge and sync**.
5. Leave the remote VS Code session running until the task reports `Done`.

Starting this task authorizes its pushes and merges. There are no additional
confirmation prompts. An ordinary commit or push alone does not start the merge
coordinator. The normal VS Code Commit button keeps its existing behavior.

For a single keyboard shortcut, open **Preferences: Open Keyboard Shortcuts (JSON)**
and add this entry to the existing array. Preserve other entries:

```json
{
  "key": "ctrl+alt+m",
  "command": "workbench.action.tasks.runTask",
  "args": "Platform: submit, merge and sync",
  "when": "workspaceFolderCount == 1"
}
```

The shortcut runs the named task when this repository is open. This package does
not change the standard Build Task shortcut or install an extension.

The equivalent terminal command after committing is:

```bash
bash scripts/submit-change.sh
```

If the existing Git alias is configured, `git submit` does the same. To configure
it in this repository, once:

```bash
git config alias.submit '!bash scripts/submit-change.sh'
```

For the original staged-files workflow, provide a commit message:

```bash
git add path/to/reviewed-file
git submit 'feat: describe the change'
```

With staged files and a message, the helper runs `scripts/validate.sh all` before
committing. Unstaged or untracked files cause it to stop. With an already clean,
committed branch, the remote CI jobs provide validation.

## What happens

| Step | Behavior |
| --- | --- |
| Preflight | Checks branch, clean tree, expected remotes, authentication and matching `main` commits |
| Submit | Pushes the feature commit to both remotes; creates or reuses the PR and MR |
| Initial checks | Waits for the exact source commit to pass GitHub checks and GitLab CI |
| GitLab merge | Merges the MR with the expected source SHA and without squashing |
| GitHub update | Pushes the GitLab merge commit into the existing GitHub PR branch |
| GitHub checks | Waits again because GitHub's PR head is now a different commit |
| GitHub merge | Merges with an exact head-commit guard and preserves ancestry |
| Synchronize | Fast-forwards GitLab `main` to the GitHub merge commit, then updates local `main` |
| Finish | Confirms identical commit IDs and removes unchanged, merged feature branches |

GitHub must report successful `Terraform validation`, `Ansible validation` and
`Workflow automation tests` check runs. Other reported check runs must also
succeed. Repository protections continue to apply at merge time. GitLab must
report a successful pipeline for the source SHA, with successful jobs. Missing,
failed, cancelled, skipped or manual jobs are not treated as a pass.

The coordinator expects the ordinary branch/source-commit pipelines used by this
repository. It stops on merged-results pipelines with a different synthetic SHA.
It also stops rather than ignore pagination when more than one page of checks or
jobs would need inspection. Review the coordinator if the CI design changes.

GitLab currently runs the runner smoke test and the coordinator's regression
tests. Terraform and Ansible validation are enforced through GitHub. Moving
those validations onto the homelab GitLab runner remains a separate task.

The task changes repository references and PR/MR state. It does not run Terraform
apply, Ansible deployment playbooks or Kubernetes changes.

## Status and preflight

On a clean, committed feature branch:

```bash
python3 scripts/submit-platform.py --check
```

This fetches remote references and checks prerequisites, but does not commit,
push, create a PR/MR, or merge. It does not predict future CI results.

Display the saved operation:

```bash
python3 scripts/submit-platform.py --status
```

The record is `barou-submit.json` inside Git's common directory, normally
`.git/barou-submit.json`. It contains branch names, commit IDs and PR/MR numbers,
not authentication tokens. A local lock prevents concurrent submissions from
this clone and its linked worktrees. Do not run submissions from separate clones
at the same time or edit/push the submitted branch while the task runs.

## Recovery

GitHub and GitLab do not provide one atomic transaction. GitLab may already be
merged when a later GitHub check, permission check, or network request fails.
The task never rolls back an accepted merge or rewrites `main` to hide this.

| Situation | Action |
| --- | --- |
| Checks not registered yet | The task polls; no checks never means success |
| CI still running | The task waits up to 30 minutes per wait stage |
| Network failure or interrupted VS Code session | Run the same task again; saved request IDs and server state prevent duplicate merges |
| A job failed transiently | Retry the job in its platform, then rerun the task |
| Checks failed and code must change, before either merge | Fix and commit on the same branch, then use `python3 scripts/submit-platform.py --restart` |
| A check failed after GitLab already merged | Retry a transient job, then resume; if code changes are needed, resolve with a reviewed follow-up change |
| `main` advanced or feature history changed | The task stops. Inspect both platforms; it will not force the histories to match |
| Separate auto-merge is enabled on an existing PR/MR | Disable that setting before using this coordinator |
| Source branch gained newer commits during cleanup | It is kept for manual review |

`--restart` discards the saved operation only if neither recorded request was
merged. It requires the original feature branch and a clean tree. Existing open
requests can then be reused for the corrected commit. This is an explicit action;
the helper never silently adopts new commits into an already approved submission.

If manual recovery is needed after a merge, inspect:

```bash
git fetch --all --prune
git --no-pager log --oneline --graph --all -20
git --no-pager diff origin/main gitlab/main
python3 scripts/submit-platform.py --status
```

Preserve branches until recovery is complete. Resume is supported while the
recorded commits still match the remote history. Concurrent new work may require
a reviewed reconciliation. Do not remove the operation record to get past such
a failure without inspecting the corresponding PR and MR.

Remote feature branch cleanup uses a lease with an explicit expected commit ID
to protect against concurrent updates. This is used only for deleting the
completed feature branch, never to force-push either `main` history.

## Test the automation

```bash
python3 -B -m unittest discover -s tests -p 'test_submit_platform.py' -v
```

Tests use temporary local bare Git repositories with simulated platform API
responses. They cover successful synchronization, absent and failed checks,
changed commits, interrupted merges, rejected synchronization and concurrent
updates. They require Git and Python; no login or network is used.

These tests validate the coordinator logic. The first real submission remains
the integration test of the installed CLI versions, permissions and live APIs.
Run the preflight and inspect the prepared patch before that submission.

## References

- [VS Code tasks](https://code.visualstudio.com/docs/debugtest/tasks)
- [GitLab merge command](https://docs.gitlab.com/cli/mr/merge/)
- [GitHub merge command](https://cli.github.com/manual/gh_pr_merge)
- [GitHub check runs API](https://docs.github.com/en/rest/checks/runs)
