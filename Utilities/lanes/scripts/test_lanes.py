#!/usr/bin/env python3
"""Tests of lanes.py: the path encodings and report, log and resume-line
readers over text fixtures, and the whole collection over a folder of
fixture repositories made in a temporary directory: a main clone with an
integration branch and three worktrees (one ahead, one conflicting, one
whose path is gone), an adopter clone and an adopter worktree, a workspace
with a report, Linux logs, and a stand-in for ~/.claude. Then the folder is
moved, as when it's mounted somewhere else, and read again from there.

Git runs with no global or system configuration (no hooks, signing or
credential helpers). Everything is written under one temporary directory,
which is deleted; nothing reaches the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lanes  # noqa: E402

GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_AUTHOR_NAME="t",
               GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")


def git(cwd, *args):
    return subprocess.run(["git", "-C", cwd, *args], env=GIT_ENV, check=True, capture_output=True,
                          text=True).stdout


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def commit(repo, files, message):
    for rel, text in files.items():
        write(os.path.join(repo, rel), text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--no-verify", "-m", message)


REPORT = """# Lane A report

## Resume here

- Step 3 is next: the tests.

## 1. What
"""


class TextTests(unittest.TestCase):
    def test_claude_dir_name(self):
        self.assertEqual(lanes.claude_dir_name("/Users/m/development/base_dir/system-next/tooling-1"),
                         "-Users-m-development-base-dir-system-next-tooling-1")
        self.assertEqual(lanes.claude_dir_name("/a/b.c/d_e"), "-a-b-c-d-e")

    def test_is_report(self):
        for rel in ("REPORT.md", "REPORT-NET.md", "RECOLLAPSE-C-REPORT.md", "Prototype/Tooling/REPORT.md",
                    "Prototype/Status/LEDGER-REPORT.md"):
            self.assertTrue(lanes.is_report(rel), rel)
        for rel in ("README.md", "Prototype/Tooling/NOTES.md", "Prototype/A/B/REPORT2.txt", "Sources/REPORT.swift"):
            self.assertFalse(lanes.is_report(rel), rel)

    def test_resume_line(self):
        tmp = tempfile.mkdtemp(prefix="lanes-test-")
        try:
            p = os.path.join(tmp, "R.md")
            for text, want in ((REPORT, "- Step 3 is next: the tests."),
                               ("x\n**Resume here**: merge, then step 4.\n", "merge, then step 4."),
                               ("## Resume here\n\n## Next\n", None),
                               ("nothing\n", None)):
                write(p, text)
                self.assertEqual(lanes.resume_line(p), want)
        finally:
            shutil.rmtree(tmp)

    def test_suffix_candidates(self):
        self.assertEqual(lanes.suffix_candidates("/mnt/sn", "/Users/m/sn/adopters-unix/swift-nio"),
                         ["/mnt/sn/Users/m/sn/adopters-unix/swift-nio", "/mnt/sn/m/sn/adopters-unix/swift-nio",
                          "/mnt/sn/sn/adopters-unix/swift-nio", "/mnt/sn/adopters-unix/swift-nio", "/mnt/sn/swift-nio"])

    def test_linux_log(self):
        tmp = tempfile.mkdtemp(prefix="lanes-test-")
        try:
            write(os.path.join(tmp, "lane-a-1234567-test.log"),
                  "== command\n\t Executed 3 tests, with 0 failures\n\t Executed 9 tests, with 1 failure (0 unexpected)\n"
                  "✔ Test run with 4 tests in 2 suites passed after 0.1 seconds.\n")
            write(os.path.join(tmp, "lane-ab-1234567-test.log"), "not lane-a's\n")
            write(os.path.join(tmp, "recollapse-b-pkg-musl-abc.log"), "musl\n")
            got = lanes.linux_log(tmp, ["lane-a"])
            self.assertEqual(got["file"], "lane-a-1234567-test.log")
            self.assertEqual(got["summary"], ["Executed 9 tests, with 1 failure (0 unexpected)",
                                              "Test run with 4 tests in 2 suites passed after 0.1 seconds."])
            self.assertEqual(lanes.linux_log(tmp, ["pkg"], ["pkg"])["file"], "recollapse-b-pkg-musl-abc.log")
            self.assertIsNone(lanes.linux_log(tmp, ["nothing"]))
        finally:
            shutil.rmtree(tmp)


class CollectionTests(unittest.TestCase):
    """The fixture folder:

    base/swift-system            main clone; system-next and main
    base/lane-a                  worktree, branch lane-a: 1 ahead, a report, an untracked file
    base/lane-b                  worktree, branch lane-b: conflicts with system-next, a merge in progress
    base/lane-gone               worktree whose directory was deleted
    base/adopters/pkg            adopter clone on migrate-all, with REPORT.md
    base/adopters-unix/pkg       worktree of the clone, on migrate-unix
    base/adopters/RECOLLAPSE-Z-REPORT.md
    base/linux-logs/...          logs for lane-a, recollapse-z and pkg
    claude/projects/...          a transcript for lane-a, at the folder's original path
    """

    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="lanes-test-"))
        self.base = os.path.join(self.tmp, "base")
        main = os.path.join(self.base, "swift-system")
        os.makedirs(main)
        git(main, "init", "-q", "-b", "main")
        commit(main, {"Package.swift": "// package\n", "Sources/A.swift": "let a = 1\n"}, "base")
        git(main, "branch", "system-next")
        git(main, "worktree", "add", "-q", "-b", "lane-a", os.path.join(self.base, "lane-a"), "system-next")
        git(main, "worktree", "add", "-q", "-b", "lane-b", os.path.join(self.base, "lane-b"), "system-next")
        git(main, "worktree", "add", "-q", "-b", "lane-gone", os.path.join(self.base, "lane-gone"), "system-next")
        a = os.path.join(self.base, "lane-a")
        commit(a, {"Prototype/LaneA/REPORT.md": REPORT, "Sources/B.swift": "let b = 2\n"}, "lane a's work")
        write(os.path.join(a, "notes.txt"), "uncommitted\n")
        b = os.path.join(self.base, "lane-b")
        commit(b, {"Sources/A.swift": "let a = 3\n"}, "lane b's change")
        git(main, "checkout", "-q", "system-next")
        commit(main, {"Sources/A.swift": "let a = 4\n"}, "system-next's change")
        git(main, "checkout", "-q", "main")
        # A merge in progress in lane-b: MERGE_HEAD in its git directory.
        gd = git(b, "rev-parse", "--git-dir").strip()
        gd = gd if os.path.isabs(gd) else os.path.join(b, gd)
        write(os.path.join(gd, "MERGE_HEAD"), git(main, "rev-parse", "system-next"))
        shutil.rmtree(os.path.join(self.base, "lane-gone"))
        pkg = os.path.join(self.base, "adopters", "pkg")
        os.makedirs(pkg)
        git(pkg, "init", "-q", "-b", "main")
        commit(pkg, {"Package.swift": "// pkg\n"}, "upstream")
        git(pkg, "checkout", "-q", "-b", "migrate-all")
        commit(pkg, {"REPORT.md": "# pkg\n\n## Resume here\n\nDone.\n"}, "migrated")
        git(pkg, "worktree", "add", "-q", "-b", "migrate-unix", os.path.join(self.base, "adopters-unix", "pkg"),
            "migrate-all")
        write(os.path.join(self.base, "adopters", "RECOLLAPSE-Z-REPORT.md"), "# Z\n\n## Resume here\n\nAll done.\n")
        logs = os.path.join(self.base, "linux-logs")
        write(os.path.join(logs, "lane-a-abc1234-test.log"), "\t Executed 2 tests, with 0 failures\n")
        write(os.path.join(logs, "recollapse-z-pkg-def5678-test.log"), "Test run with 1 test in 1 suite passed.\n")
        self.claude = os.path.join(self.tmp, "claude")
        write(os.path.join(self.claude, "projects", lanes.claude_dir_name(os.path.join(self.base, "lane-a")),
                           "s.jsonl"), "{}\n")
        os.makedirs(os.path.join(self.claude, "projects", lanes.claude_dir_name(os.path.join(self.base, "lane-b"))))

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def args(self, root, claude=None):
        return argparse.Namespace(root=root, claude=claude or self.claude, timeout=20, deadline=45, jobs=4,
                                  no_merge_tree=False)

    def by_name(self, doc):
        return {x["name"]: x for x in doc["lanes"]}

    def check(self, doc):
        L = self.by_name(doc)
        self.assertEqual(sorted(L), ["adopters", "adopters-unix", "adopters-unix/pkg", "adopters/pkg", "lane-a",
                                     "lane-b", "lane-gone", "swift-system"])
        a = L["lane-a"]
        self.assertEqual((a["branch"], a["ahead"], a["behind"], a["uncommitted"]), ("lane-a", 1, 1, 1))
        self.assertEqual(a["conflicts"], 0)
        self.assertEqual(a["report"]["file"], "Prototype/LaneA/REPORT.md")
        self.assertEqual(a["report"]["resume"], "- Step 3 is next: the tests.")
        self.assertEqual(a["linuxLog"]["summary"], ["Executed 2 tests, with 0 failures"])
        self.assertEqual(a["session"]["state"], "active")
        b = L["lane-b"]
        self.assertEqual((b["ahead"], b["behind"], b["conflicts"], b["inProgress"]), (1, 1, 1, ["merge"]))
        self.assertIsNone(b["report"])
        self.assertEqual(b["session"]["state"], "none")
        self.assertIn("isn't here", L["lane-gone"]["problem"])
        main = L["swift-system"]
        self.assertEqual((main["branch"], main["ahead"], main["behind"], main["conflicts"]), ("main", 0, 1, 0))
        p = L["adopters/pkg"]
        self.assertEqual((p["branch"], p["report"]["resume"]), ("migrate-all", "Done."))
        self.assertNotIn("ahead", p)
        self.assertEqual(p["linuxLog"]["file"], "recollapse-z-pkg-def5678-test.log")
        self.assertEqual(L["adopters-unix/pkg"]["branch"], "migrate-unix")
        ws = L["adopters"]
        self.assertEqual((ws["report"]["file"], ws["report"]["resume"]), ("RECOLLAPSE-Z-REPORT.md", "All done."))
        self.assertEqual(ws["linuxLog"]["file"], "recollapse-z-pkg-def5678-test.log")
        md = lanes.markdown(doc)
        self.assertIn("| `lane-b` | `lane-b` |", md)
        self.assertIn("+1 −1", md)

    def test_collect(self):
        doc = lanes.collect(self.args(self.base))
        self.check(doc)
        self.assertIsNone(doc["hostRoot"])

    def test_nothing_is_written_to_the_repositories(self):
        main = os.path.join(self.base, "swift-system")
        before = git(main, "count-objects", "-v")
        lanes.collect(self.args(self.base))
        self.assertEqual(git(main, "count-objects", "-v"), before)

    def test_mounted_elsewhere(self):
        moved = os.path.join(self.tmp, "mnt", "folder")
        os.makedirs(os.path.dirname(moved))
        os.rename(self.base, moved)
        doc = lanes.collect(self.args(moved))
        self.check(doc)
        L = self.by_name(doc)
        self.assertEqual(doc["hostRoot"], self.base)
        self.assertEqual(L["lane-a"]["path"], os.path.join(moved, "lane-a"))
        self.assertEqual(L["lane-a"]["recordedPath"], os.path.join(self.base, "lane-a"))
        self.assertTrue(L["adopters-unix/pkg"]["gitDir"].startswith(moved))
        # Sessions are found by the path they were recorded at.
        self.assertEqual(L["lane-a"]["session"]["state"], "active")

    def test_unreadable_claude_is_unknown(self):
        doc = lanes.collect(self.args(self.base, claude=os.path.join(self.tmp, "no-such-claude")))
        self.assertEqual(doc["claude"], "unknown")
        self.assertEqual(self.by_name(doc)["lane-a"]["session"], {"state": "unknown"})


if __name__ == "__main__":
    unittest.main()
