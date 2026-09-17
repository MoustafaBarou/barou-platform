#!/usr/bin/env python3
"""Submit one reviewed feature branch to GitLab and GitHub. Python stdlib only."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import quote

PROJECT = "MoustafaBarou/barou-platform"
GITLAB = "https://gitlab.com/" + PROJECT
MAIN = "main"
REQUIRED_GITHUB = {"Terraform validation", "Ansible validation", "Workflow automation tests"}


class Stop(RuntimeError):
    """Stop without bypassing checks or rewriting history."""


def say(message):
    print(message, flush=True)


class Commands:
    def __init__(self, root):
        self.root = Path(root)

    def call(self, *args, allowed=(0,), quiet=False):
        result = subprocess.run(
            args, cwd=self.root, text=True, capture_output=True, timeout=180,
            env={**os.environ, "GH_PROMPT_DISABLED": "1", "GIT_TERMINAL_PROMPT": "0"},
        )
        if result.returncode not in allowed:
            detail = "" if quiet else (result.stderr or result.stdout).strip()
            raise Stop(f"{args[0]} {args[1]} failed. {detail}")
        return result.stdout.strip()

    def git(self, *args):
        return self.call("git", *args)

    def github(self, endpoint):
        return json.loads(self.call("gh", "api", "--hostname", "github.com",
                                    f"repos/{PROJECT}/{endpoint}"))

    def gitlab(self, endpoint, **fields):
        args = ["glab", "api", "--hostname", "gitlab.com", "--method", "GET",
                f"projects/{quote(PROJECT, safe='')}/{endpoint}"]
        for key, value in fields.items():
            args += ["--raw-field", f"{key}={value}"]
        return json.loads(self.call(*args))

    def gh_request(self, number):
        return self.github(f"pulls/{number}")

    def gl_request(self, number):
        return self.gitlab(f"merge_requests/{number}")

    def ensure_github(self, branch, title, body):
        def find():
            return json.loads(self.call(
                "gh", "pr", "list", "--repo", PROJECT, "--head", branch,
                "--base", MAIN, "--state", "open", "--json", "number",
            ))
        prs = find()
        if not prs:
            with tempfile.TemporaryDirectory(prefix="barou-pr-") as directory:
                path = Path(directory) / "body.md"
                path.write_text(body, encoding="utf-8")
                say(self.call("gh", "pr", "create", "--repo", PROJECT,
                              "--head", branch, "--base", MAIN, "--title", title,
                              "--body-file", str(path)))
            prs = find()
        if len(prs) != 1:
            raise Stop("Expected exactly one open GitHub PR for this branch.")
        return prs[0]["number"]

    def ensure_gitlab(self, branch, title, body):
        fields = dict(state="opened", source_branch=branch, target_branch=MAIN)
        mrs = self.gitlab("merge_requests", **fields)
        if not mrs:
            say(self.call("glab", "mr", "create", "--repo", GITLAB,
                          "--source-branch", branch, "--target-branch", MAIN,
                          "--title", title, "--description", body, "--yes"))
            mrs = self.gitlab("merge_requests", **fields)
        if len(mrs) != 1:
            raise Stop("Expected exactly one open GitLab MR for this branch.")
        return mrs[0]["iid"]

    def gh_checks(self, number, sha):
        data = self.github(f"commits/{sha}/check-runs?filter=latest&per_page=100")
        if data["total_count"] > len(data["check_runs"]):
            raise Stop("More GitHub check pages exist. Review pagination before submitting.")
        checks = []
        for item in data["check_runs"]:
            if item["head_sha"] != sha:
                raise Stop("GitHub returned checks for a different commit.")
            bucket = "pending"
            if item["status"] == "completed":
                bucket = "pass" if item["conclusion"] == "success" else "fail"
            checks.append(dict(name=item["name"], bucket=bucket))
        return checks

    def merge_gitlab(self, number, sha):
        say(self.call("glab", "mr", "merge", str(number), "--repo", GITLAB,
                      "--sha", sha, "--squash=false", "--auto-merge=false", "--yes"))

    def merge_github(self, number, sha):
        say(self.call("gh", "pr", "merge", str(number), "--repo", PROJECT,
                      "--match-head-commit", sha, "--merge"))


class Submission:
    def __init__(self, commands, state_path, timeout=1800, interval=5):
        self.c = commands
        self.path = Path(state_path)
        self.timeout = timeout
        self.interval = interval
        self.state = json.loads(self.path.read_text()) if self.path.exists() else None

    def save(self):
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.state, indent=2) + "\n", encoding="utf-8")
        os.chmod(temporary, 0o600)
        temporary.replace(self.path)

    def clean(self):
        if self.c.git("status", "--porcelain"):
            raise Stop("Working tree is not clean. Save, review and commit your files first.")

    def fetch(self):
        for remote in ("origin", "gitlab"):
            self.c.git("fetch", "--quiet", remote, MAIN)

    def tip(self, remote):
        return self.c.git("rev-parse", f"{remote}/{MAIN}")

    def ancestor(self, older, newer):
        try:
            self.c.git("merge-base", "--is-ancestor", older, newer)
        except Stop:
            raise Stop("Histories diverged. Resolve this through the normal review workflow.")

    def new(self):
        self.clean()
        branch = self.c.git("branch", "--show-current")
        if not branch or branch == MAIN:
            raise Stop("Create a feature branch first; submission cannot start on main.")
        self.fetch()
        base = self.tip("origin")
        if base != self.tip("gitlab"):
            raise Stop("GitHub and GitLab main differ. Synchronize them before a new submission.")
        sha = self.c.git("rev-parse", "HEAD")
        self.ancestor(base, sha)
        if self.c.git("rev-parse", f"{base}^{{tree}}") == self.c.git("rev-parse", f"{sha}^{{tree}}"):
            raise Stop("This branch has no file changes compared with main.")
        title = self.c.git("log", "-1", "--format=%s")
        return dict(version=1, branch=branch, source_sha=sha, base_sha=base,
                    title=title, github_pr=None, gitlab_mr=None, complete=False)

    def guard_local(self):
        self.clean()
        branch = self.c.git("branch", "--show-current")
        if branch not in (self.state["branch"], MAIN):
            raise Stop(f"An unfinished submission belongs to {self.state['branch']}. Switch back to it.")
        if branch == self.state["branch"] and self.c.git("rev-parse", "HEAD") != self.state["source_sha"]:
            raise Stop("The feature branch changed after submission started. See docs/platform-submit.md.")

    def wait(self, label, predicate):
        say(label)
        deadline = time.monotonic() + self.timeout
        while True:
            if predicate():
                return
            if time.monotonic() >= deadline:
                raise Stop(f"Timed out: {label}. Inspect the PR/MR and rerun the same task.")
            time.sleep(self.interval)

    def check_github(self, sha):
        pr = self.c.gh_request(self.state["github_pr"])
        if pr.get("merged"):
            raise Stop("GitHub was merged outside this step. Rerun to reconcile the submission.")
        if pr["state"] != "open" or pr.get("draft"):
            raise Stop("GitHub PR is closed or draft. Resolve its status first.")
        if pr.get("auto_merge"):
            raise Stop("Disable the PR's separate auto-merge before using this coordinator.")
        if pr["head"]["sha"] != sha:
            raise Stop("GitHub PR head changed; refusing to merge an unverified commit.")
        checks = self.c.gh_checks(pr["number"], sha)
        if any(item.get("bucket") in ("fail", "cancel", "skipping") for item in checks):
            raise Stop("A required GitHub check failed, was cancelled or skipped. Inspect the PR.")
        return REQUIRED_GITHUB <= {item["name"] for item in checks} and all(
            item.get("bucket") == "pass" for item in checks
        )

    def check_gitlab(self, sha):
        mr = self.c.gl_request(self.state["gitlab_mr"])
        if mr["state"] != "opened" or mr.get("draft") or mr.get("work_in_progress"):
            raise Stop("GitLab MR is not open and ready. Resolve its status first.")
        if mr.get("merge_when_pipeline_succeeds"):
            raise Stop("Disable the MR's separate auto-merge before using this coordinator.")
        if mr.get("sha") != sha:
            raise Stop("GitLab MR head changed; refusing to merge an unverified commit.")
        pipeline = mr.get("head_pipeline")
        if not pipeline:
            pipelines = self.c.gitlab("pipelines", sha=sha, ref=self.state["branch"], per_page=1)
            pipeline = pipelines[0] if pipelines else None
        if not pipeline:
            return False
        if pipeline.get("sha") != sha:
            raise Stop("GitLab pipeline does not validate the exact source commit.")
        if pipeline["status"] in ("failed", "canceled", "skipped", "manual"):
            raise Stop(f"GitLab pipeline is {pipeline['status']}. Inspect or retry it in GitLab.")
        if pipeline["status"] != "success":
            return False
        jobs = self.c.gitlab(f"pipelines/{pipeline['id']}/jobs", per_page=100)
        if len(jobs) == 100:
            raise Stop("More GitLab job pages may exist. Review pagination before automating this pipeline.")
        if not jobs or any(job["status"] != "success" for job in jobs):
            raise Stop("GitLab pipeline has missing, skipped or unsuccessful jobs.")
        return True

    def ensure_requests(self):
        branch, sha = self.state["branch"], self.state["source_sha"]
        body = (
            f"{self.state['title']}\n\n"
            "Submitted through the Barou Platform VS Code task. "
            "The task verifies GitHub required checks and GitLab CI before merging, "
            "then preserves the shared Git history on both platforms.\n\n"
            f"Source commit: `{sha}`\n"
        )
        for remote, key, create in (
            ("gitlab", "gitlab_mr", self.c.ensure_gitlab),
            ("origin", "github_pr", self.c.ensure_github),
        ):
            if not self.state[key]:
                self.c.git("push", remote, f"{sha}:refs/heads/{branch}")
                self.state[key] = create(branch, self.state["title"], body)
                self.save()
        say(f"GitLab: {GITLAB}/-/merge_requests/{self.state['gitlab_mr']}")
        say(f"GitHub: https://github.com/{PROJECT}/pull/{self.state['github_pr']}")

    def merge_and_sync(self):
        source, base = self.state["source_sha"], self.state["base_sha"]
        gl_number, gh_number = self.state["gitlab_mr"], self.state["github_pr"]
        mr = self.c.gl_request(gl_number)
        if mr["state"] != "merged":
            self.wait("Waiting for GitHub checks on the feature commit...",
                      lambda: self.check_github(source))
            self.wait("Waiting for GitLab CI on the feature commit...",
                      lambda: self.check_gitlab(source))
            self.guard_local()
            self.fetch()
            if self.tip("origin") != base or self.tip("gitlab") != base:
                raise Stop("main advanced while checks ran. See recovery instructions before merging.")
            if not self.check_github(source) or not self.check_gitlab(source):
                raise Stop("Checks changed while waiting. Rerun after they finish.")
            say("Merging GitLab MR...")
            self.c.merge_gitlab(gl_number, source)
            mr = self.c.gl_request(gl_number)
            if mr["state"] != "merged":
                raise Stop("GitLab merge is not yet confirmed. Rerun to check its state.")
        if mr.get("squash_commit_sha"):
            raise Stop("GitLab was squash-merged. Preserve the branch and reconcile history manually.")
        gl_merge = mr.get("merge_commit_sha") or source
        self.fetch()
        self.ancestor(source, gl_merge)
        if self.c.git("rev-parse", f"{source}^{{tree}}") != self.c.git("rev-parse", f"{gl_merge}^{{tree}}"):
            raise Stop("The GitLab merge contains additional changes. Review them before synchronizing.")
        pr = self.c.gh_request(gh_number)
        if not pr.get("merged"):
            if pr["state"] != "open" or pr["head"]["sha"] not in (source, gl_merge):
                raise Stop("GitHub PR changed or closed during submission.")
            if self.tip("origin") != base or self.tip("gitlab") != gl_merge:
                raise Stop("A remote main advanced during submission. Review both repositories.")
            if pr["head"]["sha"] != gl_merge:
                say("Updating GitHub PR with the GitLab merge commit...")
                self.c.git("push", "origin", f"{gl_merge}:refs/heads/{self.state['branch']}")
                self.wait("Waiting for GitHub to report the updated PR head...",
                          lambda: self.c.gh_request(gh_number)["head"]["sha"] == gl_merge)
            self.wait("Waiting for GitHub checks on the merge commit...",
                      lambda: self.check_github(gl_merge))
            self.guard_local()
            say("Merging GitHub PR...")
            self.c.merge_github(gh_number, gl_merge)
            pr = self.c.gh_request(gh_number)
            if not pr.get("merged"):
                raise Stop("GitHub merge is not yet confirmed. Rerun to check its state.")
        final = pr["merge_commit_sha"]
        self.fetch()
        self.ancestor(gl_merge, final)
        if self.tip("origin") != final or self.tip("gitlab") not in (gl_merge, final):
            raise Stop("A remote main advanced. No history will be overwritten.")
        if self.c.git("rev-parse", f"{gl_merge}^{{tree}}") != self.c.git("rev-parse", f"{final}^{{tree}}"):
            raise Stop("GitHub merged additional changes. Review them before synchronizing.")
        self.guard_local()
        if self.tip("gitlab") != final:
            say("Fast-forwarding GitLab main to the GitHub merge commit...")
            self.c.git("push", "gitlab", f"{final}:refs/heads/{MAIN}")
        self.fetch()
        if self.tip("origin") != final or self.tip("gitlab") != final:
            raise Stop("Remote main references differ. Rerun to inspect the interrupted sync.")
        self.c.git("switch", MAIN)
        self.c.git("merge", "--ff-only", final)
        self.state.update(complete=True, final_sha=final)
        self.save()
        self.cleanup(source, gl_merge)
        say(f"Done. Local main, GitHub and GitLab: {final}")

    def cleanup(self, source, gl_merge):
        branch = self.state["branch"]
        for remote in ("origin", "gitlab"):
            refs = self.c.git("ls-remote", "--heads", remote, f"refs/heads/{branch}")
            if refs:
                sha = refs.split()[0]
                if sha not in (source, gl_merge):
                    say(f"Keeping {remote}/{branch}: it has newer commits.")
                    continue
                try:
                    # The lease protects deletion against concurrent branch updates.
                    self.c.git("push", f"--force-with-lease=refs/heads/{branch}:{sha}",
                               remote, f":refs/heads/{branch}")
                except Stop:
                    say(f"Keeping {remote}/{branch}: deletion was refused; review it manually.")
        refs = self.c.git("for-each-ref", "--format=%(objectname)", f"refs/heads/{branch}")
        if refs == source:
            self.ancestor(source, MAIN)
            self.c.git("update-ref", "-d", f"refs/heads/{branch}", source)
        self.c.git("fetch", "--all", "--prune", "--quiet")

    def execute(self, check=False):
        if self.state and not self.state.get("complete"):
            self.guard_local()
            say(f"Resuming submission for {self.state['branch']}.")
        else:
            self.state = self.new()
        if check:
            say(f"Preflight passed for {self.state['branch']}. No commits, pushes or merges performed.")
            return
        self.save()
        self.ensure_requests()
        self.merge_and_sync()


def verify_environment(c):
    for tool in ("git", "gh", "glab"):
        if not shutil.which(tool):
            raise Stop(f"Missing required command: {tool}")
    for remote, host in (("origin", "github.com"), ("gitlab", "gitlab.com")):
        expected = {f"git@{host}:{PROJECT}.git", f"https://{host}/{PROJECT}.git",
                    f"https://{host}/{PROJECT}"}
        if c.git("remote", "get-url", remote) not in expected:
            raise Stop(f"Remote {remote} must point to {host}/{PROJECT}.")
        if c.git("remote", "get-url", "--push", remote) not in expected:
            raise Stop(f"Remote {remote} has an unexpected push URL.")
    c.call("gh", "auth", "status", "--hostname", "github.com", quiet=True)
    c.call("glab", "auth", "status", "--hostname", "gitlab.com", quiet=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("message", nargs="?", help="Commit message for already staged files")
    parser.add_argument("--check", action="store_true", help="Preflight only; no commits/pushes/merges")
    parser.add_argument("--status", action="store_true", help="Show the locally saved submission")
    parser.add_argument("--restart", action="store_true",
                        help="Discard an unmerged submission record after fixing/rebasing the branch")
    args = parser.parse_args()
    root = Commands(Path.cwd()).git("rev-parse", "--show-toplevel")
    c = Commands(root)
    common = Path(c.git("rev-parse", "--git-common-dir"))
    if not common.is_absolute():
        common = Path(root) / common
    with (common / "barou-submit.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Stop("Another platform submission is already running.")
        submission = Submission(c, common / "barou-submit.json")
        if args.status:
            say(json.dumps(submission.state, indent=2))
            return
        verify_environment(c)
        if args.restart and submission.state and not submission.state.get("complete"):
            submission.clean()
            if c.git("branch", "--show-current") != submission.state["branch"]:
                raise Stop("Switch to the recorded feature branch before using --restart.")
            for key, get_request in (("gitlab_mr", c.gl_request), ("github_pr", c.gh_request)):
                if submission.state[key]:
                    request = get_request(submission.state[key])
                    if request.get("state") == "merged" or request.get("merged"):
                        raise Stop("Cannot restart after a merge. Rerun normally to resume synchronization.")
            if args.check:
                raise Stop("--restart cannot be combined with --check.")
            submission.state = None
            submission.path.unlink()
        active = submission.state and not submission.state.get("complete")
        if args.message and not active and not args.check:
            branch = c.git("branch", "--show-current")
            if not branch or branch == MAIN:
                raise Stop("Create a feature branch before committing.")
            if c.git("diff", "--name-only") or c.git("ls-files", "--others", "--exclude-standard"):
                raise Stop("Review and stage intended files first. Unstaged or untracked files remain.")
            if c.git("diff", "--cached", "--name-only"):
                say("Validating staged changes before committing...")
                say(c.call("bash", "scripts/validate.sh", "all"))
                c.git("commit", "-m", args.message)
        submission.execute(check=args.check)


if __name__ == "__main__":
    try:
        main()
    except (Stop, subprocess.TimeoutExpired, OSError, ValueError, KeyError) as error:
        print(f"Stopped: {error}\nRead docs/platform-submit.md; completed merges are never undone.",
              file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopped. Run the same task again to resume.", file=sys.stderr)
        sys.exit(130)
