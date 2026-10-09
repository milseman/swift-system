#!/usr/bin/env python3
"""Tests of snapshot.py: its readers over text fixtures (Swift
declarations and scopes, STATUS.md's gap table, log names, report
sections, git's -z output), and whole snapshots of a folder of fixture
repositories made in one temporary directory:

    base/swift-system            main clone: main, system-next (two merges since
                                 the lanes branched, one Linux log), origin/main,
                                 STATUS.md, a CMakeLists.txt missing a file, and a
                                 stand-in for Utilities/lint/lint.sh
    base/lane-a                  worktree: ahead and behind, a report naming
                                 hashes, an untracked file with conflict markers
    base/lane-b                  worktree: conflicts with system-next, a merge in
                                 progress, a stale index.lock; adds the same
                                 member to Win32.Error as lane-a, in another module
    base/lane-gone               worktree whose directory was deleted
    base/merged-2                worktree of a branch system-next has merged
    base/pitch-x                 worktree on pitch/x, from origin/main
    base/swift-system-examples   main clone; worktree base/tools-a, with a log
                                 named for one of its commits
    base/adopters/pkg            adopter clone: migrate-all, MIGRATION.md
    base/adopters-unix/pkg       its worktree on migrate-unix
    base/adopters/...            a workspace report, logs-z and tools-z
    base/linux-logs/...          logs
    claude/projects/...          a transcript for lane-a

What the tests can touch: git runs with no global or system configuration
(no hooks, signing, credential helpers or remotes with URLs; nothing is
fetched or pushed). Everything is written under one temporary directory,
which tearDown deletes; the one move is of the fixture folder within it,
and the one permission change is making the stand-in scripts in it
executable. The only process signaled is the stand-in lint.sh the
snapshot itself starts, which the deadline test has it stop. Nothing
reaches the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import io  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import time  # noqa: E402
import unittest  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lanes  # noqa: E402
import snapshot  # noqa: E402

GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@example.invalid")


def git(cwd, *args):
    return subprocess.run(["git", "-C", cwd, *args], env=GIT_ENV, check=True, capture_output=True,
                          text=True).stdout


def write(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    if mode:
        os.chmod(path, mode)


def commit(repo, files, message):
    for rel, text in files.items():
        write(os.path.join(repo, rel), text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--no-verify", "-m", message)
    return git(repo, "rev-parse", "HEAD").strip()


STATUS = """# Status

# 5. Sites left

**The floor** (no site left on a platform but exceptions) holds on no platform: Darwin (3 sites left), Windows (9 sites left).

The ledger: every site. Categories, by `exceptions.ini`'s entries first, then by `mapping.ini`: 5 unexplained, 4 System gap, 1 exception; 2 excluded. How each is decided is below.

## Unexplained

| Repository | File |
|---|---|
| x | `y` |

## System gaps, by sites unblocked

| # | Gap | Lacks | Unblocks | Holds | Repositories | C names | System |
|---:|---|---|---:|---:|---|---|---|
| 1 | [sockets] | WASI, Windows | 3 (2 files) | 4 | swift-nio | `AF_INET` | x \\| y |
| 2 | [winsock] | Windows | 2 (1 file) | 2 | swift-nio, swift-certificates | `SOCKET` | System names it nowhere |
| 3 | mmap | WASI | 1 (1 file) | 1 | swift-foundation | `mmap` | z |

## Queued work

| Entry | Sites |
|---|---:|
| N1 | 3 |

# How this is computed
"""

# The stand-in for lint.sh, committed at system-next's head. It says where
# it ran (with `/` as `:`, which survives the snapshot's mapping of scratch
# paths) and what commit that checkout has, and gives fixed findings.
LINT_STUB = r"""#!/bin/sh
top=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
head=$(git -C "$top" rev-parse HEAD)
mkdir -p "$top/.build/lint"
echo "$*" >> "$top/.build/lint/calls"
where=$(printf '%s|%s' "$top" "$(pwd)" | tr / :)
if [ -n "${LINT_STUB_SLEEP:-}" ]; then sleep "$LINT_STUB_SLEEP"; fi
case " $* " in
  *" markers "*)
    printf '{"head": "%s", "findings": [{"file": "adopters/pkg/Sources/P.swift", "line": 3, "rule": "markers/stale", "level": "warning", "message": "stale", "where": "%s"}], "notes": ["markers: adopters/pkg at migrate-all (1234567890), against System %s"], "failed": []}\n' "$head" "$where" "$head" ;;
  *" conditionals "*)
    printf '{"head": "%s", "findings": [{"file": "adopters/pkg/Sources/Q.swift", "line": 7, "rule": "conditionals/mixed", "level": "warning", "message": "mixed"}], "notes": ["conditionals: adopters/pkg at migrate-all (1234567890) against its merge base with main (abc)"], "failed": []}\n' "$head" ;;
  *)
    printf '{"head": "%s", "findings": [{"file": "Prototype/Pitches/p.json", "line": 1, "rule": "pitches/prerequisite", "level": "warning", "message": "needs a type", "where": "%s", "commit": "%s"}], "notes": ["pitches: a graph"], "failed": [{"check": "api", "why": "no api-delta output for main..HEAD"}]}\n' "$head" "$where" "$head"
    echo "lint: 0 errors, 1 warnings" >&2
    exit 2 ;;
esac
echo "lint: 0 errors, 1 warnings" >&2
"""

LOG = """== 2026-10-09 09:07:32 swift:6.2-noble (arm64): swift test --scratch-path .build/linux-6.2-noble
\t Executed 3 tests, with 0 failures (0 unexpected) in 0.1 (0.1) seconds
/code/Sources/X.swift:1:2: error: something bad
  | `- error: something bad
/code/Sources/X.swift:1:2: error: something bad
\u2714 Test run with 4 tests in 1 suite passed after 0.1 seconds.
== exit status 0; log: x.log
"""

# A git without `merge-tree --write-tree` (before 2.38).
OLD_GIT = """#!/bin/sh
for a in "$@"; do
  if [ "$a" = "--write-tree" ]; then
    echo "usage: git merge-tree <base-tree> <branch1> <branch2>" >&2
    exit 129
  fi
done
exec "{git}" "$@"
"""


def load(path):
    with open(path) as f:
        return json.load(f)


def read(path):
    with open(path) as f:
        return f.read()


def manifest(root):
    """Every file and directory under root with its size, time and mode."""
    out = {}
    for d, dirs, files in os.walk(root):
        for n in dirs + files:
            p = os.path.join(d, n)
            st = os.lstat(p)
            out[os.path.relpath(p, root)] = (st.st_size if not os.path.isdir(p) else 0, st.st_mtime_ns, st.st_mode)
    return out


class Fixture:
    """Builds the folder in tmp; see the module's docstring."""

    def __init__(self, tmp):
        self.tmp = tmp
        self.base = os.path.join(tmp, "base")
        b = self.base
        self.main = main = os.path.join(b, "swift-system")
        os.makedirs(main)
        git(main, "init", "-q", "-b", "main")
        self.base_commit = commit(main, {
            "Package.swift": "// package\n",
            "Sources/System/A.swift": "let a = 1\n",
            "Sources/System/CMakeLists.txt": "add_library(SystemPackage\n  A.swift\n  M1.swift\n  M2.swift)\n",
            "Prototype/Status/STATUS.md": STATUS,
            "Utilities/lint/lint.sh": LINT_STUB}, "base")
        os.chmod(os.path.join(main, "Utilities/lint/lint.sh"), 0o755)
        git(main, "add", "--chmod=+x", "Utilities/lint/lint.sh")
        git(main, "commit", "-q", "--no-verify", "-m", "executable stub")
        git(main, "update-ref", "refs/remotes/origin/main", "main")
        git(main, "branch", "system-next")
        # The lanes, from system-next as it is now.
        for name in ("lane-a", "lane-b", "lane-gone"):
            git(main, "worktree", "add", "-q", "-b", name, os.path.join(b, name), "system-next")
        git(main, "worktree", "add", "-q", "-b", "pitch/x", os.path.join(b, "pitch-x"), "origin/main")
        a = os.path.join(b, "lane-a")
        self.lane_a_commit = commit(a, {
            "Sources/System/B.swift": "extension Win32.Error {\n  public static var codeA: Int { 1 }\n}\n\n"
                                      "public func helper() {}\n",
            "Prototype/LaneA/REPORT.md": "# Lane A\n\n## Resume here\n\n- Step 3 is next (`{base}`).\n- Then "
                                         "`{missing}`.\n\n## 1. What\n\nText.\n"}, "lane a's work")
        lb = os.path.join(b, "lane-b")
        commit(lb, {"Sources/System/A.swift": "let a = 3\n",
                    "Sources/SystemWinSocks/C.swift": "extension Win32.Error {\n  static var codeA: Int { 2 }\n}\n\n"
                                                      "public func helper() {}\n"}, "lane b's change")
        commit(os.path.join(b, "pitch-x"), {"Sources/System/P.swift": "public struct ProcessThing {}\n"}, "pitch")
        # system-next moves: a change to A.swift, then two merges.
        git(main, "checkout", "-q", "system-next")
        commit(main, {"Sources/System/A.swift": "let a = 4\n", "Sources/System/Extra.swift": "let extra = 1\n"},
               "system-next's change")
        git(main, "checkout", "-q", "-b", "merged-1")
        commit(main, {"Sources/System/M1.swift": "public func helper() {}\n"}, "merged-1's work")
        git(main, "checkout", "-q", "system-next")
        git(main, "merge", "-q", "--no-ff", "-m", "Merge branch 'merged-1' into system-next", "merged-1")
        self.merge1 = git(main, "rev-parse", "HEAD").strip()
        git(main, "branch", "-q", "-D", "merged-1")
        git(main, "worktree", "add", "-q", "-b", "merged-2", os.path.join(b, "merged-2"), "system-next")
        commit(os.path.join(b, "merged-2"), {"Sources/System/M2.swift": "let m2 = 2\n"}, "merged-2's work")
        git(main, "merge", "-q", "--no-ff", "-m", "Merge branch 'merged-2' into system-next", "merged-2")
        self.merge2 = git(main, "rev-parse", "HEAD").strip()
        # lane-b: a merge in progress and a stale lock.
        gd = git(lb, "rev-parse", "--git-dir").strip()
        self.lane_b_gitdir = gd if os.path.isabs(gd) else os.path.join(lb, gd)
        write(os.path.join(self.lane_b_gitdir, "MERGE_HEAD"), self.merge2 + "\n")
        write(os.path.join(self.lane_b_gitdir, "MERGE_MSG"), "Merge branch 'system-next' into lane-b\n")
        write(os.path.join(self.lane_b_gitdir, "index.lock"), "")
        shutil.rmtree(os.path.join(b, "lane-gone"))
        # The examples.
        ex = os.path.join(b, "swift-system-examples")
        os.makedirs(ex)
        git(ex, "init", "-q", "-b", "main")
        commit(ex, {"Package.swift": "// examples\n"}, "examples")
        git(ex, "worktree", "add", "-q", "-b", "tools-a", os.path.join(b, "tools-a"), "main")
        self.tools_a = commit(os.path.join(b, "tools-a"), {"REPORT-A.md": "# A\n\n**Resume here:** done.\n",
                                                           "Sources/A/main.swift": "print(1)\n"}, "tools-a")
        # The adopter, its worktree and the workspace.
        pkg = os.path.join(b, "adopters", "pkg")
        os.makedirs(pkg)
        git(pkg, "init", "-q", "-b", "main")
        commit(pkg, {"Package.swift": "// pkg\n"}, "upstream")
        git(pkg, "checkout", "-q", "-b", "migrate-all")
        self.pkg_commit = commit(pkg, {"MIGRATION.md": "# pkg\n\n## Resume here\n\nDone.\n",
                                       "REPORT.md": "# pkg report\n"}, "migrated")
        git(pkg, "worktree", "add", "-q", "-b", "migrate-unix", os.path.join(b, "adopters-unix", "pkg"),
            "migrate-all")
        write(os.path.join(b, "adopters", "RECOLLAPSE-Z-REPORT.md"),
              f"# Z\n\n## Resume here\n\nAll done at `{self.pkg_commit[:9]}`.\n")
        write(os.path.join(b, "adopters", "logs-z", "run.log"), "log\n")
        write(os.path.join(b, "adopters", "tools-z", "tool.txt"), "tool\n")
        # lane-a's report names a commit on its branch, one that isn't (and is
        # in the adopter), and one that's nowhere.
        rp = os.path.join(a, "Prototype/LaneA/REPORT.md")
        with open(rp) as f:
            text = f.read()
        write(rp, text.replace("{base}", self.base_commit[:7]).replace("{missing}", "deadbee1") +
              f"\nMerged in `{self.merge1[:8]}`; the adopter's `{self.pkg_commit[:7]}`.\n")
        git(a, "commit", "-q", "-am", "report")
        write(os.path.join(a, "notes.txt"), "<<<<<<< ours\nx\n=======\ny\n>>>>>>> theirs\n")
        # The Linux logs and the session.
        logs = os.path.join(b, "linux-logs")
        write(os.path.join(logs, f"system-next-{self.merge1[:7]}-test.log"), LOG)
        write(os.path.join(logs, f"lane-a-{self.base_commit[:7]}-test.log"), "\t Executed 2 tests, with 0 failures\n")
        write(os.path.join(logs, f"recollapse-z-pkg-{self.pkg_commit[:8]}-after.log"), "Test run with 1 test.\n")
        write(os.path.join(logs, f"examples-{self.tools_a[:7]}-all.log"), "\u2714 Test run with 9 tests in 2 suites "
                                                                          "passed after 0.1 seconds.\n")
        self.claude = os.path.join(tmp, "claude")
        write(os.path.join(self.claude, "projects", lanes.claude_dir_name(a), "s.jsonl"), "{}\n")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="snapshot-test-"))
        self.fx = Fixture(self.tmp)
        self.out = os.path.join(self.tmp, "out")
        self.saved_env = lanes.ENV
        lanes.ENV = dict(lanes.ENV, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")

    def tearDown(self):
        lanes.ENV = self.saved_env
        shutil.rmtree(self.tmp)

    def args(self, *extra, root=None, deadline=60):
        argv = ["--out", self.out, "--root", root or self.fx.base, "--claude", self.fx.claude,
                "--deadline", str(deadline)] + list(extra)
        return snapshot.parse_args(argv)

    def snap(self, *extra, root=None, deadline=60):
        buf = io.StringIO()
        status = snapshot.run_snapshot(self.args(*extra, root=root, deadline=deadline), stdout=buf)
        self.assertEqual(status, 0)
        return buf.getvalue()

    def section(self, name):
        return load(os.path.join(self.out, f"{name}.json"))


class TextTests(unittest.TestCase):
    def test_blank_keeps_braces_out_of_strings_and_comments(self):
        src = 'let s = "a { b"  // c { d\n/* e { /* nested } */ f } */ let r = #"g { "h" }"#\n' \
              'let m = """\n{ x\n"""\nlet i = "\\(f("{"))"\n'
        b = snapshot.blank(src)
        self.assertEqual(len(b), len(src))
        self.assertEqual(b.count("\n"), src.count("\n"))
        self.assertNotIn("{", b)
        self.assertNotIn("}", b)

    def test_declarations_and_scopes(self):
        src = """import Foo

extension Win32.Error {
  public static var codeA: Int { 1 }
  static let codeB = 2, codeC = 3
  func local() {
    let inside = 1
    struct Local { var hidden: Int }
  }
}

public struct Outer<T>: Equatable where T: Hashable {
  public init(x: Int, _ y: Int) {}
  init?(rawValue: String) {}
  subscript(index: Int) -> Int { 0 }
  subscript(row r: Int, column c: Int) -> Int { 0 }
  public enum Kind { case a, b(Int), `c` }
  static func == (lhs: Outer, rhs: Outer) -> Bool { true }
  private func secret() {}
}

private extension Outer {
  func hidden() {}
}

#if os(Windows)
public func helper(_ value: Int) -> Int { value }
#endif
class func notAType() {}
"""
        ds = snapshot.declarations(src, "Sources/System/X.swift")
        got = {(d["scope"], d["name"], d["access"]) for d in ds}
        for want in (("Win32.Error", "codeA", "public"), ("Win32.Error", "codeB", "internal"),
                     ("Win32.Error", "codeC", "internal"), ("Win32.Error", "local()", "internal"),
                     ("", "Outer", "public"), ("Outer", "init(x:_:)", "public"), ("Outer", "init(rawValue:)", "internal"),
                     ("Outer", "subscript(_:)", "internal"), ("Outer", "subscript(row:column:)", "internal"),
                     ("Outer", "Kind", "public"), ("Outer.Kind", "a", "internal"), ("Outer.Kind", "b", "internal"),
                     ("Outer.Kind", "`c`", "internal"), ("Outer", "==(lhs:rhs:)", "internal"),
                     ("Outer", "secret()", "private"), ("Outer", "hidden()", "fileprivate"),
                     ("", "helper(_:)", "public")):
            self.assertIn(want, got)
        names = {d["name"] for d in ds}
        self.assertNotIn("inside", names)      # a function's local
        self.assertNotIn("hidden", names)      # a local type's member
        self.assertNotIn("Local", names)
        self.assertIn(("", "notAType()", "internal"), got)  # `class func` is a function, not a class
        helper = next(d for d in ds if d["name"] == "helper(_:)")
        self.assertEqual((helper["module"], helper["text"]), ("Sources/System",
                                                               "public func helper(_ value: Int) -> Int { value }"))
        keys = {snapshot.decl_key(d) for d in ds}
        self.assertIn(("member", "Win32.Error", "codeA"), keys)
        self.assertIn(("top", "Sources/System", "helper(_:)"), keys)
        self.assertIn(("file", "Sources/System/X.swift", "Outer", "secret()"), keys)

    def test_parse_status(self):
        st = snapshot.parse_status(STATUS)
        self.assertEqual(st["floor"], {"Darwin": 3, "Windows": 9})
        self.assertEqual([(c["category"], c["sites"]) for c in st["categories"]],
                         [("unexplained", 5), ("System gap", 4), ("exception", 1), ("excluded", 2)])
        self.assertEqual([g["gap"] for g in st["gaps"]], ["[sockets]", "[winsock]", "mmap"])
        g = st["gaps"][0]
        self.assertEqual((g["lacks"], g["unblocks"], g["unblocksFiles"], g["holds"], g["repositories"], g["system"]),
                         (["WASI", "Windows"], 3, 2, 4, ["swift-nio"], "x | y"))
        s = st["sums"]
        self.assertEqual(s["byPlatform"]["Windows"], {"rows": 2, "unblocks": 5, "holds": 6})
        self.assertEqual(s["byPlatform"]["WASI"], {"rows": 2, "unblocks": 4, "holds": 5})
        self.assertEqual(s["windowsOnly"], {"rows": 1, "unblocks": 2, "holds": 2})
        self.assertEqual(s["lackingAnotherPlatform"], {"rows": 2, "unblocks": 4, "holds": 5})
        self.assertEqual(s["total"], {"rows": 3, "unblocks": 6, "holds": 7})

    def test_parse_log_name(self):
        pk = ["swift-log", "swift-nio", "swift-nio-imap"]
        self.assertEqual(snapshot.parse_log_name("recollapse-f-swift-log-wasi-threads-1234abc-after.log", pk),
                         {"prefix": "recollapse-f-swift-log-wasi-threads", "commit": "1234abc", "rest": "after",
                          "lane": "recollapse-f", "package": "swift-log", "variant": "wasi-threads"})
        got = snapshot.parse_log_name("eco-nio-1-swift-nio-imap-Proxy-14ad388-before.log", pk)
        self.assertEqual((got["lane"], got["package"], got["variant"]), ("eco-nio-1", "swift-nio-imap", "Proxy"))
        got = snapshot.parse_log_name("system-next-5d0b151-test.log", pk)
        self.assertEqual((got["lane"], got["commit"], got.get("package")), ("system-next", "5d0b151", None))
        self.assertEqual(snapshot.parse_log_name("no-commit-here.log", pk)["lane"], "no-commit-here")

    def test_resume_section_and_outline(self):
        lines = ["# R", "", "## Resume here", "", "- a", "### detail", "b", "## Next", "c", "```", "## not a heading",
                 "```"]
        self.assertEqual(snapshot.resume_section(lines), {"line": 3, "text": "## Resume here\n\n- a\n### detail\nb"})
        self.assertEqual([h["text"] for h in snapshot.outline(lines)], ["R", "Resume here", "detail", "Next"])
        bold = ["x", "**Resume here:** one,", "two.", "", "- item", "", "Other paragraph."]
        self.assertEqual(snapshot.resume_section(bold)["text"], "**Resume here:** one,\ntwo.\n\n- item")
        self.assertIsNone(snapshot.resume_section(["nothing"]))

    def test_hash_tokens(self):
        got = snapshot.hash_tokens(["see `5514161` and abc1234,", "again 5514161; not abc123 or xyz1234567"])
        self.assertEqual([(h["hash"], h["line"], h["count"]) for h in got], [("5514161", 1, 2), ("abc1234", 1, 1)])

    def test_git_z_readers(self):
        self.assertEqual(snapshot.name_status("R098\0a.txt\0c.txt\0A\0d e.txt\0"),
                         [{"status": "R098", "from": "a.txt", "path": "c.txt"}, {"status": "A", "path": "d e.txt"}])
        self.assertEqual(snapshot.numstat("1\t0\t\0a.txt\0c.txt\0-\t-\tbin\0002\t3\td e.txt\0"),
                         {"c.txt": (1, 0), "bin": (None, None), "d e.txt": (2, 3)})
        self.assertEqual(lanes.status_entries(" M a\0R  new\0old\0?? u\0"),
                         [{"status": " M", "path": "a"}, {"status": "R ", "path": "new", "from": "old"},
                          {"status": "??", "path": "u"}])

    def test_conflict_markers(self):
        tmp = tempfile.mkdtemp(prefix="snapshot-test-")
        try:
            p = os.path.join(tmp, "f")
            write(p, "a\n<<<<<<< ours\nb\n=======\nc\n>>>>>>> theirs\n")
            self.assertEqual(snapshot.conflict_markers(p), [2, 4, 6])
            write(p, "Title\n=======\n")  # a Markdown underline alone
            self.assertEqual(snapshot.conflict_markers(p), [])
        finally:
            shutil.rmtree(tmp)


class SnapshotTests(Base):
    def test_every_section(self):
        printed = self.snap()
        fx = self.fx
        index = load(os.path.join(self.out, "index.json"))
        names = [e["section"] for e in index["sections"]]
        self.assertEqual(names, [n for n in snapshot.SECTION_NAMES if n != "since-previous"])
        for e in index["sections"]:
            self.assertTrue(os.path.isfile(os.path.join(self.out, e["markdown"])))
            self.assertIn(e["markdown"], printed)
            self.assertTrue(e["what"])
        self.assertEqual(index["skipped"], [])
        self.assertIn("Nothing was skipped.", printed)
        self.assertFalse([e for e in os.listdir(self.out) if e.startswith(".scratch-")])

        env = self.section("environment")
        self.assertEqual(env["trialMerges"], "write-tree")
        self.assertFalse(env["paths"]["worktreePaths"])
        self.assertTrue(any(c["command"].startswith(f"cd {fx.base}/swift-system && Prototype/Win32/check-windows.sh")
                            for c in env["notRunHere"]))
        self.assertIn("du", env["du"])

        L = {x["name"]: x for x in self.section("lanes")["lanes"]}
        self.assertEqual(sorted(L), sorted(["swift-system", "lane-a", "lane-b", "lane-gone", "merged-2", "pitch-x",
                                            "swift-system-examples", "tools-a", "adopters/pkg", "adopters-unix/pkg",
                                            "adopters", "adopters-unix"]))
        p = L["pitch-x"]
        self.assertEqual((p["kind"], p["integration"], p["ahead"], p["behind"]), ("pitch", "origin/main", 1, 0))
        self.assertEqual((L["lane-b"]["conflicts"], L["lane-b"]["inProgress"]), (1, ["merge"]))
        self.assertIn("isn't here", L["lane-gone"]["problem"])
        self.assertEqual(L["lane-a"]["session"]["state"], "active")
        self.assertEqual(L["tools-a"]["linuxLog"]["file"], f"examples-{fx.tools_a[:7]}-all.log")
        self.assertTrue(L["tools-a"]["linuxLog"]["namesHead"])
        self.assertEqual((L["adopters/pkg"]["integration"], L["adopters/pkg"]["ahead"]), ("main", 1))

        br = {r["repository"]: r for r in self.section("branches")["repositories"]}
        pkg = br["adopters/pkg"]
        self.assertEqual(pkg["newestMigration"], "migrate-all")
        local = {b["name"]: b for b in pkg["local"]}
        self.assertTrue(local["migrate-all"]["migration"])
        self.assertEqual(local["migrate-unix"]["worktree"], os.path.join(fx.base, "adopters-unix", "pkg"))
        self.assertIn("origin/main", [b["name"] for b in br["swift-system"]["remote"]])
        self.assertTrue(any(w.get("missing") for w in br["swift-system"]["worktrees"]))

        C = {x["lane"]: x for x in self.section("commits")["lanes"]}
        self.assertEqual([c["subject"] for c in C["lane-a"]["commits"]], ["report", "lane a's work"])
        self.assertEqual(C["lane-a"]["range"], "system-next..HEAD")
        self.assertEqual([c["subject"] for c in C["adopters/pkg"]["commits"]], ["migrated", "upstream"])
        self.assertTrue(all(c["new"] for c in C["adopters/pkg"]["commits"]))

        F = {x["lane"]: x for x in self.section("changed-files")["lanes"]}
        self.assertEqual(sorted(f["path"] for f in F["lane-a"]["files"]),
                         ["Prototype/LaneA/REPORT.md", "Sources/System/B.swift"])
        self.assertEqual({d["directory"] for d in F["lane-a"]["byTopLevel"]}, {"Prototype", "Sources"})
        self.assertEqual([f["path"] for f in F["adopters/pkg"]["files"]], ["MIGRATION.md", "REPORT.md"])

        G = self.section("git-state")
        S = {x["lane"]: x for x in G["lanes"]}
        self.assertEqual(S["lane-b"]["inProgress"]["merge"]["commit"], fx.merge2)
        self.assertEqual(S["lane-b"]["inProgress"]["merge"]["subject"], "Merge branch 'merged-2' into system-next")
        self.assertEqual(S["lane-a"]["conflictMarkers"], [{"path": "notes.txt", "lines": [1, 3, 5]}])
        locks = {r["repository"]: r["locks"] for r in G["repositories"]}
        self.assertEqual([lk["path"] for lk in locks["swift-system"]], [".git/worktrees/lane-b/index.lock"])
        self.assertTrue(locks["swift-system"][0]["modified"])

        T = self.section("trial-merges")
        TL = {x["lane"]: x for x in T["lanes"]}
        self.assertEqual((TL["lane-b"]["mode"], TL["lane-b"]["files"]), ("write-tree", ["Sources/System/A.swift"]))
        self.assertEqual(TL["lane-a"]["files"], [])
        pairs = {(p["a"], p["b"]): p for g in T["pairs"] for p in g["pairs"]}
        self.assertEqual(list(pairs), [("lane-a", "lane-b")])
        self.assertEqual(pairs[("lane-a", "lane-b")]["files"], [])

        N = {(g["repository"], g["base"]): g for g in self.section("names")["groups"]}
        g = N[("swift-system", "system-next")]
        dup = {tuple(d["key"]): d for d in g["duplicates"]}
        member = dup[("member", "Win32.Error", "codeA")]
        self.assertEqual(sorted((d["lane"], d["module"]) for d in member["declarations"]),
                         [("lane-a", "Sources/System"), ("lane-b", "Sources/SystemWinSocks")])
        self.assertEqual([k["name"] for k in g["publicNames"]], ["helper()"])
        la = next(x for x in g["lanes"] if x["lane"] == "lane-a")
        self.assertEqual([c["key"] for c in la["clashesWithIntegration"]], [["top", "Sources/System", "helper()"]])

        A = {a["name"]: a for a in self.section("activity")["lanes"]}
        self.assertEqual(A["lane-a"]["newest"]["path"], "notes.txt")
        self.assertNotIn("partial", A["lane-a"])
        dirs = {d["directory"]: d for d in A["adopters"]["directories"]}
        self.assertEqual(dirs["logs-z"]["newest"]["path"], "logs-z/run.log")
        self.assertIn("tools-z", dirs)
        self.assertEqual(A["adopters"]["newestTopFile"]["path"], "RECOLLAPSE-Z-REPORT.md")

        R = {(x["lane"], r["path"]): r for x in self.section("reports")["lanes"] for r in x["reports"]}
        ra = R[("lane-a", "Prototype/LaneA/REPORT.md")]
        self.assertEqual([h["text"] for h in ra["outline"]], ["Lane A", "Resume here", "1. What"])
        self.assertIn("- Then `deadbee1`.", ra["resume"]["text"])
        H = {h["hash"]: h for h in ra["hashes"]}
        self.assertTrue(H[fx.base_commit[:7]]["onBranch"])
        self.assertFalse(H[fx.merge1[:8]]["onBranch"])
        self.assertIn("system-next", H[fx.merge1[:8]]["branches"])
        self.assertEqual(H["deadbee1"]["inRepo"], "missing")
        self.assertEqual([(e["repository"], e["branches"]) for e in H[fx.pkg_commit[:7]]["elsewhere"]],
                         [("adopters/pkg", ["migrate-all", "migrate-unix"])])
        self.assertEqual(R[("adopters/pkg", "MIGRATION.md")]["resume"]["text"], "## Resume here\n\nDone.")
        ws = R[("adopters", "RECOLLAPSE-Z-REPORT.md")]["hashes"][0]
        self.assertEqual(ws["elsewhere"][0]["repository"], "adopters/pkg")

        logs = {x["file"]: x for x in self.section("linux-logs")["logs"]}
        sn = logs[f"system-next-{fx.merge1[:7]}-test.log"]
        self.assertEqual(sn["summary"], ["Executed 3 tests, with 0 failures (0 unexpected) in 0.1 (0.1) seconds",
                                         "Test run with 4 tests in 1 suite passed after 0.1 seconds."])
        self.assertEqual((sn["errors"]["lines"], sn["errors"]["distinct"]), (3, 1))
        self.assertEqual(sn["exit"], "== exit status 0; log: x.log")
        self.assertEqual(sn["commitIn"], ["swift-system"])
        rz = logs[f"recollapse-z-pkg-{fx.pkg_commit[:8]}-after.log"]
        self.assertEqual((rz["lane"], rz["package"], rz["commitIn"]), ("recollapse-z", "pkg", ["adopters/pkg"]))

        I = {b["repository"]: b for b in self.section("integration")["branches"]}
        sysn = I["swift-system"]
        hist = {c["hash"]: c for c in sysn["history"]}
        m1, m2 = hist[fx.merge1], hist[fx.merge2]
        self.assertEqual((m1["merge"]["lane"], m1["merge"]["branch"], m1["merge"]["worktree"]),
                         ("merged-1", "gone", "gone"))
        self.assertEqual(m1["closeLogs"], [f"system-next-{fx.merge1[:7]}-test.log"])
        self.assertEqual((m2["merge"]["branch"], m2["merge"]["worktree"], m2["closeLogs"]), ("present", "present", []))
        self.assertEqual(m2["merge"]["commitsPastMerge"], 0)
        self.assertEqual(m2["stat"]["sources"]["files"], 1)
        self.assertEqual(sysn["lastLogged"]["hash"], fx.merge1)
        self.assertEqual([(c["hash"], c["touchesSources"]) for c in sysn["lastLogged"]["since"]], [(fx.merge2, True)])
        self.assertEqual(sysn["cmake"]["missing"], ["Sources/System/Extra.swift"])

        st = self.section("status")
        self.assertEqual(len(st["gaps"]), 3)
        self.assertEqual(st["lastChange"]["subject"], "base")

        lint = self.section("lint")
        system = lint["system"]
        self.assertEqual([f["rule"] for f in system["findings"]], ["pitches/prerequisite"])
        self.assertEqual(system["failed"], [{"check": "api", "why": "no api-delta output for main..HEAD"}])
        top, cwd = system["findings"][0]["where"].replace(":", "/").split("|")
        self.assertTrue(top.startswith(os.path.join(self.out, ".scratch-")), top)
        self.assertEqual(cwd, fx.base)
        self.assertEqual(system["findings"][0]["commit"], git(fx.main, "rev-parse", "system-next").strip())
        clones = {c["clone"]: c for c in lint["adopters"]["clones"]}
        self.assertEqual(clones["adopters/pkg"]["markers"]["counts"], {"markers/stale": 1})
        self.assertEqual(clones["adopters/pkg"]["conditionals"]["counts"], {"conditionals/mixed": 1})
        self.assertEqual(len(clones["adopters/pkg"]["markers"]["notes"]), 1)

        md = read(os.path.join(self.out, "lanes.md"))
        self.assertIn("| `pitch-x` | pitch/x |", md)
        self.assertIn("+1 −0 vs origin/main", md)

    def test_nothing_is_written_outside_out(self):
        tmpdir = os.path.join(self.tmp, "tmpdir")
        os.makedirs(tmpdir)
        before = manifest(self.fx.base)
        claude_before = manifest(self.fx.claude)
        objects = git(self.fx.main, "count-objects", "-v")
        saved = os.environ.get("TMPDIR")
        os.environ["TMPDIR"] = tmpdir
        tempfile.tempdir = None
        try:
            self.snap()
        finally:
            if saved is None:
                del os.environ["TMPDIR"]
            else:
                os.environ["TMPDIR"] = saved
            tempfile.tempdir = None
        self.assertEqual(manifest(self.fx.base), before)
        self.assertEqual(manifest(self.fx.claude), claude_before)
        self.assertEqual(git(self.fx.main, "count-objects", "-v"), objects)
        self.assertEqual(os.listdir(tmpdir), [])
        self.assertFalse([e for e in os.listdir(self.out) if e.startswith(".scratch-")])
        self.assertFalse(os.path.exists(os.path.join(HERE, "__pycache__")))

    def test_deadline_skips_with_commands(self):
        # The stand-in lint.sh sleeps; the deadline stops it, and the index
        # says so with the command that gets lint alone.
        lanes.ENV = dict(lanes.ENV, LINT_STUB_SLEEP="30")
        started = time.time()
        printed = self.snap(deadline=3)
        self.assertLess(time.time() - started, 3 + 8)
        index = load(os.path.join(self.out, "index.json"))
        lint_skips = [s for s in index["skipped"] if s["section"] == "lint"]
        self.assertTrue(lint_skips)
        for s in lint_skips:
            self.assertIn("--section lint", s["command"])
            self.assertIn(s["command"], printed)
        entry = next(e for e in index["sections"] if e["section"] == "lint")
        self.assertFalse(entry["complete"])
        self.assertIn("lint (incomplete)", printed)
        self.assertIn("**Incomplete**", read(os.path.join(self.out, "lint.md")))
        # The rest is there.
        self.assertTrue(self.section("lanes")["lanes"])

    def test_walk_stopped_by_the_deadline(self):
        run = snapshot.Run(self.args(deadline=60))
        run.deadline_at = time.time() - 1  # already past
        w = snapshot.Walker(run)
        w.add("lane-a", os.path.join(self.fx.base, "lane-a"))
        unread, unread_t = w.walk(2)
        self.assertEqual(unread["lane-a"], 1)
        self.assertTrue(unread_t["lane-a"])

    def test_previous_snapshot(self):
        self.snap()
        first = load(os.path.join(self.out, "index.json"))
        a = os.path.join(self.fx.base, "lane-a")
        rp = os.path.join(a, "Prototype/LaneA/REPORT.md")
        with open(rp, "a") as f:
            f.write("\n## 2. More\n\nText.\n")
        new_head = commit(a, {}, "more")
        write(os.path.join(self.fx.base, "linux-logs", f"lane-a-{new_head[:7]}-test.log"), "Test run with 3 tests.\n")
        git(self.fx.main, "worktree", "remove", "--force", os.path.join(self.fx.base, "merged-2"))
        printed = self.snap()
        self.assertIn("since-previous", printed)
        d = self.section("since-previous")
        self.assertEqual(d["previous"], first["generated"])
        moved = {m["lane"]: m for m in d["headsMoved"]}
        self.assertEqual((moved["lane-a"]["relation"], moved["lane-a"]["commits"]), ("fast-forward", 1))
        self.assertEqual([x["file"] for x in d["logsNew"]], [f"lane-a-{new_head[:7]}-test.log"])
        rep = next(r for r in d["reports"] if r["path"] == "Prototype/LaneA/REPORT.md")
        self.assertEqual((rep["change"], rep["headingsAdded"]), ("changed", ["2. More"]))
        self.assertIn("merged-2", d["lanesVanished"])
        self.assertIn("merged-2", [r["lane"] for r in d["worktreesRemoved"]])
        second = load(os.path.join(self.out, "index.json"))
        self.assertEqual((second["since"], second["sinceFrom"]), (first["generated"], "the previous snapshot's time"))

    def test_mounted_elsewhere(self):
        moved = os.path.join(self.tmp, "mnt", "folder")
        os.makedirs(os.path.dirname(moved))
        os.rename(self.fx.base, moved)
        printed = self.snap(root=moved)
        env = self.section("environment")
        paths = env["paths"]
        self.assertEqual(paths["hostRoot"], self.fx.base)
        mapped = {m["lane"] for m in paths["worktreePaths"]}
        self.assertTrue({"lane-a", "lane-b", "pitch-x", "tools-a", "merged-2"} <= mapped, mapped)
        gitdirs = {m["lane"] for m in paths["gitDirs"]}
        self.assertTrue({"adopters-unix/pkg", "lane-a", "tools-a"} <= gitdirs, gitdirs)
        self.assertEqual([m["lane"] for m in paths["failed"]], ["lane-gone"])
        self.assertIn(f"Paths: recorded under `{self.fx.base}`, seen under `{moved}`", printed)
        L = {x["name"]: x for x in self.section("lanes")["lanes"]}
        self.assertEqual(L["lane-b"]["conflicts"], 1)
        self.assertEqual(L["lane-a"]["session"]["state"], "active")
        br = {r["repository"]: r for r in self.section("branches")["repositories"]}
        mu = next(b for b in br["adopters/pkg"]["local"] if b["name"] == "migrate-unix")
        self.assertEqual(mu["worktreeSeen"], os.path.join(moved, "adopters-unix", "pkg"))

    def test_git_without_write_tree(self):
        bin_dir = os.path.join(self.tmp, "old-git")
        write(os.path.join(bin_dir, "git"), OLD_GIT.format(git=shutil.which("git")), 0o755)
        objects = git(self.fx.main, "count-objects", "-v")
        lanes.ENV = dict(lanes.ENV, PATH=bin_dir + os.pathsep + lanes.ENV.get("PATH", ""))
        saved_path = os.environ["PATH"]
        os.environ["PATH"] = bin_dir + os.pathsep + saved_path
        try:
            self.snap()
        finally:
            os.environ["PATH"] = saved_path
        self.assertEqual(self.section("environment")["trialMerges"], "trivial")
        TL = {x["lane"]: x for x in self.section("trial-merges")["lanes"]}
        self.assertEqual((TL["lane-b"]["mode"], TL["lane-b"]["files"]), ("trivial", ["Sources/System/A.swift"]))
        self.assertEqual(git(self.fx.main, "count-objects", "-v"), objects)

    def test_one_section(self):
        buf = io.StringIO()
        snapshot.run_snapshot(self.args("--section", "trial-merges"), stdout=buf)
        self.assertIn("# Trial merges", buf.getvalue())
        self.assertIn("Sources/System/A.swift", buf.getvalue())
        self.assertFalse(os.path.exists(os.path.join(self.out, "trial-merges.md")))
        buf = io.StringIO()
        snapshot.run_snapshot(self.args("--section", "activity", "--only", "lane-a", "--json"), stdout=buf)
        doc = json.loads(buf.getvalue())
        self.assertEqual((doc["section"], [a["name"] for a in doc["lanes"]]), ("activity", ["lane-a"]))
        self.assertEqual(sorted(os.listdir(self.out)), [])

    def test_refusals(self):
        with self.assertRaises(snapshot.Usage):
            snapshot.run_snapshot(snapshot.parse_args(["--out", os.path.join(self.fx.base, "snap"), "--root",
                                                       self.fx.base]))
        os.makedirs(self.out)
        write(os.path.join(self.out, "keep.txt"), "not a snapshot\n")
        with self.assertRaises(snapshot.Usage):
            self.snap()
        self.assertEqual(os.listdir(self.out), ["keep.txt"])
        with self.assertRaises(snapshot.Usage):
            snapshot.run_snapshot(self.args("--section", "since-previous"))


if __name__ == "__main__":
    unittest.main()
