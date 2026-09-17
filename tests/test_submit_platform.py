"""Exercise real Git graphs and interrupted submissions; no network or credentials."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "submit-platform.py"
SPEC = importlib.util.spec_from_file_location("submit_platform", SCRIPT)
platform = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(platform)


class FakePlatforms(platform.Commands):
    """API responses follow real commits in two local bare Git repositories."""

    def __init__(self, root, remotes):
        super().__init__(root)
        self.remotes = remotes
        self.requests = {}
        self.creations = {"gh": 0, "gl": 0}
        self.merges = {"gh": 0, "gl": 0}
        self.events = []
        self.gh_results = []
        self.gh_bucket = "pass"
        self.gl_status = "success"
        self.gl_job_status = "success"
        self.gl_pipeline_missing = False
        self.gl_bad_sha = False
        self.gh_wrong_head = False
        self.fail_after_gl_merge = False
        self.fail_after_gh_merge = False
        self.reject_final_push = False
        self.advance_before_final_push = False

    def bare(self, remote, *args):
        return self.call("git", "--git-dir", str(self.remotes[remote]), *args)

    def remote_head(self, remote, branch="main"):
        return self.bare(remote, "rev-parse", f"refs/heads/{branch}")

    def git(self, *args):
        if args[:2] == ("push", "gitlab") and args[-1].endswith(":refs/heads/main"):
            if self.advance_before_final_push:
                self.advance("gitlab")
                self.advance_before_final_push = False
            if self.reject_final_push:
                raise platform.Stop("Simulated GitLab write failure")
        return super().git(*args)

    def ensure_github(self, branch, title, body):
        self.creations["gh"] += 1
        self.requests.setdefault("gh", dict(number=7, branch=branch, state="open", merged=False,
                                           draft=False, merge_commit_sha=None))
        return 7

    def ensure_gitlab(self, branch, title, body):
        self.creations["gl"] += 1
        self.requests.setdefault("gl", dict(iid=3, branch=branch, state="opened", draft=False,
                                           sha=self.remote_head("gitlab", branch),
                                           merge_commit_sha=None, squash_commit_sha=None))
        return 3

    def gh_request(self, number):
        request = copy.deepcopy(self.requests["gh"])
        request["head"] = {"sha": self.remote_head("origin", request["branch"])}
        if self.gh_wrong_head:
            request["head"]["sha"] = "a" * 40
        return request

    def gl_request(self, number):
        request = copy.deepcopy(self.requests["gl"])
        sha = "b" * 40 if self.gl_bad_sha else request["sha"]
        request["head_pipeline"] = None if self.gl_pipeline_missing else dict(
            id=11, sha=sha, status=self.gl_status)
        return request

    def gh_checks(self, number, sha):
        self.events.append(("github-check", sha))
        if self.gh_results:
            return self.gh_results.pop(0)
        return [dict(name=name, bucket=self.gh_bucket) for name in platform.REQUIRED_GITHUB]

    def gitlab(self, endpoint, **fields):
        if endpoint == "pipelines":
            return []
        if endpoint == "pipelines/11/jobs":
            return [dict(name="runner-smoke-test", status=self.gl_job_status),
                    dict(name="workflow-tests", status=self.gl_job_status)]
        raise AssertionError(endpoint)

    def merge_commit(self, remote, branch):
        base, head = self.remote_head(remote), self.remote_head(remote, branch)
        tree = self.bare(remote, "rev-parse", f"{head}^{{tree}}")
        merge = self.bare(remote, "-c", "user.name=CI Test", "-c", "user.email=ci@example.invalid",
                          "commit-tree", tree, "-p", base, "-p", head, "-m", "Merge test request")
        self.bare(remote, "update-ref", "refs/heads/main", merge, base)
        return merge

    def merge_gitlab(self, number, sha):
        assert sha == self.requests["gl"]["sha"]
        merge = self.merge_commit("gitlab", self.requests["gl"]["branch"])
        self.merges["gl"] += 1
        self.events.append(("gitlab-merge", sha))
        self.requests["gl"].update(state="merged", merge_commit_sha=merge)
        if self.fail_after_gl_merge:
            self.fail_after_gl_merge = False
            raise platform.Stop("Simulated disconnect after GitLab accepted merge")

    def merge_github(self, number, sha):
        assert sha == self.gh_request(number)["head"]["sha"]
        merge = self.merge_commit("origin", self.requests["gh"]["branch"])
        self.merges["gh"] += 1
        self.events.append(("github-merge", sha))
        self.requests["gh"].update(state="closed", merged=True, merge_commit_sha=merge)
        if self.fail_after_gh_merge:
            self.fail_after_gh_merge = False
            raise platform.Stop("Simulated disconnect after GitHub accepted merge")

    def advance(self, remote):
        base = self.remote_head(remote)
        tree = self.bare(remote, "rev-parse", f"{base}^{{tree}}")
        commit = self.bare(remote, "-c", "user.name=CI Test", "-c", "user.email=ci@example.invalid",
                           "commit-tree", tree, "-p", base, "-m", "Concurrent update")
        self.bare(remote, "update-ref", "refs/heads/main", commit, base)
        return commit


class SubmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        directory = Path(self.temp.name)
        self.root = directory / "work"
        self.root.mkdir()
        remotes = {name: directory / f"{name}.git" for name in ("origin", "gitlab")}
        self.c = FakePlatforms(self.root, remotes)
        self.c.git("init", "-q", "-b", "main")
        self.c.git("config", "user.name", "CI Test")
        self.c.git("config", "user.email", "ci@example.invalid")
        self.c.git("config", "commit.gpgsign", "false")
        (self.root / "file.txt").write_text("base\n")
        self.c.git("add", "file.txt")
        self.c.git("commit", "-qm", "Base")
        for remote, path in remotes.items():
            self.c.call("git", "init", "--bare", "-q", str(path))
            self.c.git("remote", "add", remote, str(path))
            self.c.git("push", "-q", remote, "main")
        self.base = self.c.git("rev-parse", "HEAD")
        self.c.git("switch", "-qc", "feat/example")
        (self.root / "file.txt").write_text("feature\n")
        self.c.git("commit", "-qam", "feat: test !1 and 'quotes'")
        self.source = self.c.git("rev-parse", "HEAD")
        self.path = self.root / ".git" / "barou-submit.json"
        self.output = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)

    def execute(self, **kwargs):
        platform.Submission(self.c, self.path, timeout=0, interval=0).execute(**kwargs)

    def prepare(self):
        submission = platform.Submission(self.c, self.path, timeout=0, interval=0)
        submission.state = submission.new()
        submission.save()
        submission.ensure_requests()
        return submission

    def assert_untouched(self):
        self.assertEqual(self.c.merges, {"gh": 0, "gl": 0})
        self.assertEqual(self.c.remote_head("origin"), self.base)
        self.assertEqual(self.c.remote_head("gitlab"), self.base)

    def assert_synchronized(self):
        final = self.c.remote_head("origin")
        self.assertEqual(final, self.c.remote_head("gitlab"))
        self.assertEqual(final, self.c.git("rev-parse", "main"))
        self.assertEqual("main", self.c.git("branch", "--show-current"))
        self.assertEqual("", self.c.git("status", "--porcelain"))
        self.assertTrue(json.loads(self.path.read_text())["complete"])
        self.c.git("merge-base", "--is-ancestor", self.source, final)

    def test_normal_route_preserves_history_checks_updated_head_and_cleans_up(self):
        self.execute()
        self.assert_synchronized()
        self.assertEqual(self.c.creations, {"gh": 1, "gl": 1})
        self.assertEqual(self.c.merges, {"gh": 1, "gl": 1})
        gl_merge = self.c.requests["gl"]["merge_commit_sha"]
        self.assertIn(("github-check", self.source), self.c.events)
        self.assertIn(("github-check", gl_merge), self.c.events)
        for remote in ("origin", "gitlab"):
            self.assertEqual("", self.c.git("ls-remote", "--heads", remote, "refs/heads/feat/example"))
        self.assertEqual("", self.c.git("branch", "--list", "feat/example"))

    def test_preflight_does_not_push_create_requests_or_save_state(self):
        self.execute(check=True)
        self.assert_untouched()
        self.assertFalse(self.path.exists())
        self.assertEqual(self.c.creations, {"gh": 0, "gl": 0})

    def test_dirty_tree_stops_before_push(self):
        (self.root / "file.txt").write_text("uncommitted\n")
        with self.assertRaisesRegex(platform.Stop, "not clean"):
            self.execute()
        self.assert_untouched()

    def test_main_branch_is_not_submitted(self):
        self.c.git("switch", "main")
        with self.assertRaisesRegex(platform.Stop, "feature branch"):
            self.execute()
        self.assert_untouched()

    def test_divergent_remote_main_stops_before_requests(self):
        self.c.advance("origin")
        with self.assertRaisesRegex(platform.Stop, "main differ"):
            self.execute()
        self.assertEqual(self.c.creations, {"gh": 0, "gl": 0})

    def test_no_registered_github_checks_is_not_a_pass(self):
        self.c.gh_results = [[]]
        with self.assertRaisesRegex(platform.Stop, "Timed out"):
            self.execute()
        self.assert_untouched()

    def test_failed_github_check_blocks_both_merges(self):
        self.c.gh_bucket = "fail"
        with self.assertRaisesRegex(platform.Stop, "GitHub check failed"):
            self.execute()
        self.assert_untouched()

    def test_failed_gitlab_pipeline_blocks_both_merges(self):
        self.c.gl_status = "failed"
        with self.assertRaisesRegex(platform.Stop, "GitLab pipeline is failed"):
            self.execute()
        self.assert_untouched()

    def test_missing_gitlab_pipeline_is_not_a_pass(self):
        self.c.gl_pipeline_missing = True
        with self.assertRaisesRegex(platform.Stop, "Timed out"):
            self.execute()
        self.assert_untouched()

    def test_advanced_main_before_first_merge_stops(self):
        self.prepare()
        self.c.advance("gitlab")
        with self.assertRaisesRegex(platform.Stop, "main advanced"):
            self.execute()
        self.assertEqual(self.c.merges, {"gh": 0, "gl": 0})

    def test_second_github_check_failure_leaves_gitlab_merge_resumable(self):
        self.c.fail_after_gl_merge = True
        with self.assertRaises(platform.Stop):
            self.execute()
        self.c.gh_bucket = "fail"
        with self.assertRaisesRegex(platform.Stop, "GitHub check failed"):
            self.execute()
        self.assertEqual(self.c.remote_head("origin"), self.base)
        self.assertEqual(self.c.merges, {"gh": 0, "gl": 1})
        self.c.gh_bucket = "pass"
        self.execute()
        self.assert_synchronized()
        self.assertEqual(self.c.merges, {"gh": 1, "gl": 1})

    def test_allow_failure_job_cannot_sneak_through_successful_pipeline(self):
        self.c.gl_job_status = "failed"
        with self.assertRaisesRegex(platform.Stop, "unsuccessful jobs"):
            self.execute()
        self.assert_untouched()

    def test_gitlab_pipeline_for_different_commit_is_rejected(self):
        self.c.gl_bad_sha = True
        with self.assertRaisesRegex(platform.Stop, "exact source commit"):
            self.execute()
        self.assert_untouched()

    def test_changed_github_head_is_rejected(self):
        self.c.gh_wrong_head = True
        with self.assertRaisesRegex(platform.Stop, "head changed"):
            self.execute()
        self.assert_untouched()

    def test_resume_after_gitlab_accepted_merge_does_not_create_or_merge_twice(self):
        self.c.fail_after_gl_merge = True
        with self.assertRaisesRegex(platform.Stop, "disconnect after GitLab"):
            self.execute()
        self.execute()
        self.assert_synchronized()
        self.assertEqual(self.c.creations, {"gh": 1, "gl": 1})
        self.assertEqual(self.c.merges, {"gh": 1, "gl": 1})

    def test_resume_after_github_accepted_merge_only_finishes_sync(self):
        self.c.fail_after_gh_merge = True
        with self.assertRaisesRegex(platform.Stop, "disconnect after GitHub"):
            self.execute()
        self.execute()
        self.assert_synchronized()
        self.assertEqual(self.c.merges, {"gh": 1, "gl": 1})

    def test_rejected_final_gitlab_push_can_be_retried_without_merging_again(self):
        self.c.reject_final_push = True
        with self.assertRaisesRegex(platform.Stop, "write failure"):
            self.execute()
        self.c.reject_final_push = False
        self.execute()
        self.assert_synchronized()
        self.assertEqual(self.c.merges, {"gh": 1, "gl": 1})

    def test_new_remote_commit_at_final_push_is_not_overwritten(self):
        self.c.advance_before_final_push = True
        with self.assertRaises(platform.Stop):
            self.execute()
        self.assertNotEqual(self.c.remote_head("origin"), self.c.remote_head("gitlab"))
        self.assertFalse(json.loads(self.path.read_text())["complete"])

    def test_new_local_commit_during_resume_is_preserved(self):
        self.c.fail_after_gl_merge = True
        with self.assertRaises(platform.Stop):
            self.execute()
        (self.root / "file.txt").write_text("new local work\n")
        self.c.git("commit", "-qam", "More work")
        new_sha = self.c.git("rev-parse", "HEAD")
        with self.assertRaisesRegex(platform.Stop, "feature branch changed"):
            self.execute()
        self.assertEqual(new_sha, self.c.git("rev-parse", "HEAD"))
        self.assertEqual(self.c.merges["gh"], 0)

    def test_shell_metacharacters_are_passed_as_literal_arguments(self):
        with mock.patch.object(platform.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "ok", "")
            platform.Commands(self.root).call("echo", "!1; $(echo secret) ' quoted")
            self.assertEqual(run.call_args.args[0], ("echo", "!1; $(echo secret) ' quoted"))
            self.assertNotIn("shell", run.call_args.kwargs)


class CheckAdapterTests(unittest.TestCase):
    def setUp(self):
        self.c = platform.Commands(Path.cwd())
        self.sha = "a" * 40
        self.check = dict(name="Terraform validation", head_sha=self.sha,
                          status="completed", conclusion="success")

    def check_response(self, data):
        with mock.patch.object(self.c, "github", return_value=data) as api:
            result = self.c.gh_checks(7, self.sha)
            self.assertIn(f"commits/{self.sha}/check-runs", api.call_args.args[0])
            return result

    def test_checks_are_requested_for_the_exact_commit(self):
        result = self.check_response(dict(total_count=1, check_runs=[self.check]))
        self.assertEqual(result[0]["bucket"], "pass")

    def test_pending_checks_do_not_pass(self):
        self.check.update(status="queued", conclusion=None)
        result = self.check_response(dict(total_count=1, check_runs=[self.check]))
        self.assertEqual(result[0]["bucket"], "pending")

    def test_skipped_checks_do_not_pass(self):
        self.check["conclusion"] = "skipped"
        result = self.check_response(dict(total_count=1, check_runs=[self.check]))
        self.assertEqual(result[0]["bucket"], "fail")

    def test_checks_for_another_commit_are_rejected(self):
        self.check["head_sha"] = "b" * 40
        with self.assertRaisesRegex(platform.Stop, "different commit"):
            self.check_response(dict(total_count=1, check_runs=[self.check]))

    def test_unread_check_pages_are_not_treated_as_success(self):
        with self.assertRaisesRegex(platform.Stop, "More GitHub check pages"):
            self.check_response(dict(total_count=2, check_runs=[self.check]))


if __name__ == "__main__":
    unittest.main()
