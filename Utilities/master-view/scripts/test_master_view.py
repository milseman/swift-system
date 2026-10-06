#!/usr/bin/env python3
"""Tests of the master view's data assembly and its reconciliation, on small
text fixtures. Every file a test writes is under a temporary directory it
makes and deletes; the git repositories it makes are local, with remotes
that are only names in their config (nothing is fetched or pushed).

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/master-view/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import assemble as asm  # noqa: E402
import check as chk  # noqa: E402
import page as pg  # noqa: E402
import universe as uv  # noqa: E402

# git for the fixture repositories: no user or system configuration (no hooks,
# no signing), an identity of its own, and lazy fetching off.
GIT_ENV = {"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull, "GIT_AUTHOR_NAME": "t",
           "GIT_AUTHOR_EMAIL": "t@example.invalid", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@example.invalid", "GIT_NO_LAZY_FETCH": "1"}


def run_git(path, *args):
    env = dict(os.environ, **GIT_ENV)
    subprocess.run(["git", "-C", path, *args], check=True, capture_output=True, env=env)


def make_repo(path, files, remote=None, branches=()):
    """A git repository at path with files committed on main, an origin
    remote by URL only, and branches each with one more commit."""
    os.makedirs(path)
    run_git(path, "init", "-q", "-b", "main")
    for rel, text in files.items():
        full = os.path.join(path, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(text)
    run_git(path, "add", "-A")
    run_git(path, "commit", "-q", "-m", "first")
    if remote:
        run_git(path, "remote", "add", "origin", f"https://github.com/{remote}.git")
    for b in branches:
        run_git(path, "checkout", "-q", "-b", b)
        with open(os.path.join(path, f"{b}.swift"), "w", encoding="utf-8") as f:
            f.write("import SystemPackage\n")
        run_git(path, "add", "-A")
        run_git(path, "commit", "-q", "-m", b)
        run_git(path, "checkout", "-q", "main")


class Temp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="master-view-test-")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, rel, text):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text if isinstance(text, str) else json.dumps(text))
        return path


# ---------------------------------------------------------------- universe

class UniverseTests(Temp):
    def test_github_remote(self):
        self.assertEqual(uv.github_remote("https://github.com/apple/swift-nio.git"), "apple/swift-nio")
        self.assertEqual(uv.github_remote("git@github.com:milseman/swift-system-examples.git"),
                         "milseman/swift-system-examples")
        self.assertEqual(uv.github_remote("https://github.com/swiftlang/swift-build"), "swiftlang/swift-build")
        self.assertIsNone(uv.github_remote("https://example.com/x/y.git"))

    def build(self):
        eco, adopt, ex = (os.path.join(self.tmp, d) for d in ("ecosystem", "adopters", "examples"))
        os.makedirs(eco)
        os.makedirs(adopt)
        self.write("ecosystem/scheme-main.tsv",
                   "boringssl\tmain\tgoogle/boringssl\t\n"
                   "cmark\tgfm\tswiftlang/swift-cmark\t\n"
                   "swift-nio\t2.0\tapple/swift-nio\t\n"
                   "swift-system\t1.5\tapple/swift-system\t\n"
                   "libdispatch\tmain\tswiftlang/swift-corelibs-libdispatch\t\n")
        self.write("ecosystem/org-swiftlang.json", [
            {"name": "swift-cmark", "isArchived": False, "isFork": True},
            {"name": "old-thing", "isArchived": True, "isFork": False},
            {"name": ".github", "isArchived": False, "isFork": False},
            {"name": "swiftly", "isArchived": False, "isFork": False}])
        self.write("ecosystem/org-apple.json", [
            {"name": "swift-nio", "isArchived": False, "isFork": False},
            {"name": "swift-system", "isArchived": False, "isFork": False},
            {"name": "publicsuffix-list", "isArchived": False, "isFork": True},
            {"name": ".github", "isArchived": False, "isFork": False}])
        make_repo(os.path.join(eco, "cmark"), {"Package.swift": "// manifest\n", "src/a.c": "int x;\n"},
                  remote="swiftlang/swift-cmark")
        make_repo(os.path.join(eco, "swift-nio"), {"Sources/A.swift": "import Darwin\n"}, remote="apple/swift-nio")
        make_repo(os.path.join(eco, "swiftly"), {"Sources/S.swift": "let a = 1\n"}, remote="swiftlang/swiftly")
        make_repo(os.path.join(eco, "vapor"), {"Sources/V.swift": "let v = 1\n"}, remote="vapor/vapor")
        make_repo(os.path.join(adopt, "swift-nio"), {"Sources/A.swift": "import Darwin\n"}, remote="apple/swift-nio",
                  branches=("migrate-darwin",))
        make_repo(ex, {"Package.swift": 'let tools: [(command: String, target: String)] = [\n  ("cat", "Cat"),\n'
                                        '  ("ls", "Ls"),\n]\n'}, remote="someone/swift-system-examples")
        non = self.write("non-swift.tsv", "# comment\ngoogle/boringssl\tC: a library\n")
        a = argparse.Namespace(repo=os.path.join(self.tmp, "repo"), ecosystem=eco, adopters=adopt, examples=ex,
                               non_swift=non)
        os.makedirs(a.repo)
        return uv.build(a)

    def test_clusters(self):
        rows = self.build()
        by = {(r["cluster"], r["name"]): r for r in rows}
        uc = [r["name"] for r in rows if r["cluster"] == "update-checkout"]
        self.assertEqual(uc, ["boringssl", "cmark", "swift-nio", "libdispatch"])
        self.assertEqual(by[("update-checkout", "boringssl")]["swift"], "no")      # non-swift.tsv
        self.assertEqual(by[("update-checkout", "cmark")]["swift"], "no")          # only a manifest
        self.assertEqual(by[("update-checkout", "libdispatch")]["swift"], "?")     # no clone
        nio = by[("update-checkout", "swift-nio")]
        self.assertEqual(nio["clone"], os.path.join("..", "adopters", "swift-nio"))
        self.assertIn("also", nio["note"])
        org = [r["name"] for r in rows if r["cluster"] == "swiftlang and apple"]
        # The fork update-checkout has, and swift-nio, are update-checkout's; two .github
        # repositories get their owners' names.
        self.assertEqual(sorted(org), ["apple/.github", "swiftlang/.github", "swiftly"])
        self.assertEqual([r["name"] for r in rows if r["cluster"] == "ecosystem"], ["vapor"])
        self.assertEqual([r["name"] for r in rows if r["cluster"] == "Unix tools"], ["cat", "ls"])
        ex = {r["name"]: r["note"] for r in rows if r["cluster"] == "excluded"}
        self.assertEqual(ex["old-thing"], "archived")
        self.assertEqual(ex["publicsuffix-list"], "a fork that update-checkout doesn't have")
        self.assertEqual(ex["swift-system"], "System itself")
        self.assertEqual(sum(1 for r in rows if r["cluster"] == "excluded" and r["name"] == "swift-system"), 1)

    def test_write_and_read(self):
        rows = self.build()
        path = os.path.join(self.tmp, "universe.tsv")
        uv.write(rows, path)
        back = uv.read(path)
        self.assertEqual([r["name"] for r in back], [r["name"] for r in rows])
        self.assertEqual(back[0].keys(), set(uv.COLUMNS) | set())


# ---------------------------------------------------------------- the ledger and STATUS.md

STATUS_MD = """# Status

# 4. Platform imports

text

# 5. Sites left

**The floor** holds on no platform.

The ledger: every site ... Categories, by `Utilities/adopter-coverage/exceptions.ini`'s entries first, then by each C name against System at `system-next` @ `a3dbd4ec` and `Utilities/adopter-coverage/mapping.ini`: 3 unexplained, 2 System gap, 1 exception; 2 excluded. How each is decided is in [How](#how).

## Unexplained

| Repository | File | Lines: what | Platforms | Why |
|---|---|---|---|---|
| swift-nio | `Sources/A.swift` | 12 marker: uses getpid, 14 `Glibc` | Linux | r |

## Excluded

Not sites at all.

| Entry | Sites | Reason | Decided | Repositories |
|---|---:|---|---|---|
| E7c: SwiftPM's fixtures | 2 | Test data. | Michael | swiftpm |

## Every site

**swift-nio**, at `../adopters/swift-nio` `migrate-unix` @ `56deee84`: 4 sites, 2 of them unexplained (above).

- `Sources/B.swift` 3-4 marker: gap, here ×2, 9 `WinSDK` (Windows): **System gap**: r
- `Sources/C.swift` 7 marker: framework only (Darwin): **excluded** (E7d): x

**swiftpm**, at `../adopters/swift-package-manager` `migrate-unix` @ `efff7333`: 4 sites.

**cmark**, at `../ecosystem/cmark` @ `0c8947bb`: no sites.

# How this is computed

**not a repository**, at x: 9 sites.
"""


class LedgerTests(Temp):
    def test_parse_status_md(self):
        p = asm.parse_status_md(STATUS_MD)
        self.assertEqual(p["total"], 6)
        self.assertEqual(p["byCategory"], {"unexplained": 3, "System gap": 2, "exception": 1})
        self.assertEqual(p["excluded"], 2)
        self.assertEqual(p["perRepo"], {"swift-nio": 4, "swiftpm": 4, "cmark": 0})
        self.assertEqual(p["excludedByRepo"], {"swiftpm": 2})
        self.assertEqual(p["markers"], {"swift-nio": 3, "swiftpm": 0, "cmark": 0})
        self.assertIsNone(asm.parse_status_md("# Status\n\n# 4. Platform imports\n"))

    def test_ledger_from_json(self):
        led = asm.ledger_from_json({
            "meta": {"date": "2026-10-06", "head": "abc"},
            "read": [{"repository": "swift-nio", "where": "w", "commit": "c"}],
            "notRead": [{"repository": "zlib", "why": "not cloned"}],
            "sites": [{"repository": "swift-nio", "category": "System gap", "file": "a", "line": 1},
                      {"repository": "swift-nio", "category": "excluded", "file": "b", "line": 2},
                      {"repository": "swift-nio", "category": "unexplained", "file": "c", "line": 3}]})
        self.assertEqual(led["total"], 2)
        self.assertEqual(led["excluded"], 1)
        self.assertEqual(led["byCategory"], {"System gap": 1, "unexplained": 1})
        self.assertEqual(led["notRead"], {"zlib": "not cloned"})

    def test_site_record(self):
        s = asm.site_record({"file": "f.swift", "line": 3, "module": "Glibc", "type": "import", "importKind": "whole",
                             "category": "System gap", "reason": "r", "platforms": {"Linux": "T", "Windows": "M"},
                             "names": {"b": {}, "a": {}},
                             "holders": [{"category": "System gap", "names": ["b"]},
                                         {"category": "standard library", "names": ["a"]}]})
        self.assertEqual(s["platforms"], ["Linux", "Windows"])
        self.assertEqual(s["names"], ["a", "b"])
        self.assertEqual(s["lacks"], ["b"])


# ---------------------------------------------------------------- charts and history

def day(d, codes, commit="c"):
    return {"day": d, "codes": codes, "commit": commit, "method": "scan"}


class ChartTests(Temp):
    def test_codes_chart(self):
        days = [day("2026-09-22", "11..."), day("2026-09-23", "121a."), day("2026-09-24", "31111"),
                {"day": "2026-09-25", "codes": None}]
        pts = asm.codes_chart(days, "1", ".abcde")
        self.assertEqual([p["count"] for p in pts], [2, 2, 4])
        self.assertEqual(pts[0]["scopeAdded"], 2)              # the first day is all scope
        self.assertEqual(pts[1]["scopeAdded"], 1)              # unit 3 is new
        self.assertEqual(pts[1]["moved"], {"out to 2": 1})     # unit 2 went into a draft
        self.assertEqual(pts[2]["scopeAdded"], 2)              # unit 4 from outside, unit 5 new
        self.assertEqual(pts[2]["moved"], {"in from 2": 1, "out to 3": 1})
        self.assertEqual(asm.describe_moves(pts[2]["moved"], "unpitched"),
                         {"back from a pitch draft": 1, "into pitched": 1})
        self.assertEqual(asm.describe_moves(pts[1]["moved"], "unpitched"), {"into a pitch draft": 1})
        pit = asm.codes_chart(days, "34", ".abcde")
        self.assertEqual([p["count"] for p in pit], [0, 0, 1])
        self.assertEqual(pit[2]["scopeAdded"], 0)               # pitched from not in a pitch: not scope
        self.assertEqual(asm.describe_moves(pit[2]["moved"], "pitched"), {"newly pitched": 1})

    def test_cuses_scope(self):
        rows = [{"date": "2026-10-05", "chart": "cuses", "count": 5, "scope_added": 0, "source": "s", "commit": "",
                 "detail": {"perRepo": {"a": 3, "b": 2}, "markers": {"a": 0, "b": 1}}},
                {"date": "2026-10-06", "chart": "cuses", "count": 13, "scope_added": 0, "source": "s", "commit": "",
                 "detail": {"perRepo": {"a": 5, "b": 2, "c": 6}, "markers": {"a": 4, "b": 0, "c": 1}}}]
        asm.derive_cuses(rows)
        self.assertEqual(rows[0]["scope_added"], 5)
        # c is read for the first time (6); a gained 4 markers, b lost one.
        self.assertEqual(rows[1]["scope_added"], 10)
        self.assertEqual(rows[1]["detail"]["newRepos"], ["c"])
        self.assertEqual(rows[1]["detail"]["newlyMarked"], {"a": 4})
        self.assertEqual(rows[1]["detail"]["changes"], {"a": -2})
        # Without marker counts (an older history file), only new repositories are scope.
        old = [dict(r, detail={"perRepo": r["detail"]["perRepo"]}) for r in rows]
        asm.derive_cuses(old)
        self.assertEqual(old[1]["scope_added"], 6)
        self.assertEqual(old[1]["detail"]["changes"], {"a": 2})

    def test_merge_history(self):
        old = [{"date": "2026-10-04", "chart": "unpitched", "count": 7, "scope_added": 0, "source": "run", "commit": "x"},
               {"date": "2026-10-06", "chart": "unpitched", "count": 9, "scope_added": 0, "source": "run", "commit": "y"}]
        new = [{"date": "2026-10-03", "chart": "unpitched", "count": 1, "scope_added": 1, "source": "b", "commit": "a"},
               {"date": "2026-10-04", "chart": "unpitched", "count": 8, "scope_added": 0, "source": "b", "commit": "b"},
               {"date": "2026-10-06", "chart": "unpitched", "count": 10, "scope_added": 0, "source": "run", "commit": "z"}]
        old[0]["detail"] = {"kept": 1}
        new[1]["detail"] = {"kept": 2, "filled": 3}
        new.append({"date": "2026-10-04", "chart": "pitched", "count": 0, "scope_added": 0, "source": "b", "commit": "b",
                    "detail": {"filled": 4}})
        out = {(r["date"], r["chart"]): r for r in asm.merge_history(old, new, "2026-10-06")}
        self.assertEqual(out[("2026-10-04", "unpitched")]["detail"], {"kept": 1})   # counts differ: nothing filled
        self.assertEqual(out[("2026-10-04", "pitched")]["detail"], {"filled": 4})
        self.assertEqual(out[("2026-10-03", "unpitched")]["count"], 1)   # back-filled
        self.assertEqual(out[("2026-10-04", "unpitched")]["count"], 7)   # an earlier run's point stands
        self.assertEqual(out[("2026-10-06", "unpitched")]["count"], 10)  # today's replaces today's
        path = os.path.join(self.tmp, "history.tsv")
        asm.write_history(path, list(out.values()))
        back = asm.read_history(path)
        self.assertEqual(sorted((r["date"], r["chart"], r["count"]) for r in back),
                         [("2026-10-03", "unpitched", 1), ("2026-10-04", "pitched", 0), ("2026-10-04", "unpitched", 7),
                          ("2026-10-06", "unpitched", 10)])
        # A point that counts the same gets the details it lacks.
        same = [dict(old[0], detail={"kept": 1})]
        more = [dict(new[1], count=7, detail={"kept": 2, "filled": 3})]
        got = asm.merge_history(same, more, "2026-10-06")
        self.assertEqual(got[0]["detail"], {"kept": 1, "filled": 3})


# ---------------------------------------------------------------- uses and scans

class UseTests(Temp):
    def test_owners(self):
        units = [{"id": "a", "origin": "graph", "usr": "U1"}, {"id": "b", "origin": "scan", "usr": None},
                 {"id": "c", "origin": "scan", "usr": None}, {"id": "d", "origin": "scan", "usr": None}]
        u2n = {"a": "U1", "b": "U1", "c": "scan:x", "d": "scan:x"}
        own, same = asm.owners(units, u2n, {})
        self.assertEqual(own, {"U1": "a", "scan:x": "c"})
        self.assertEqual(same, {"b": "a", "d": "c"})

    def test_type_group(self):
        delta = {"entries": [{"status": "added", "module": "M", "path": "T.f()", "file": "f", "line": 1, "group": "T"}],
                 "hiddenFromGraphs": {"added": [
                     {"module": "M", "scopes": ["T"], "name": "U", "kw": "struct", "file": "g", "line": 2},
                     {"module": "M", "scopes": [], "name": "top()", "kw": "func", "file": "h", "line": 3}]}}
        g = asm.delta_groups(delta)
        self.assertEqual(asm.type_group({"module": "M", "path": "T.f()", "file": "f", "line": 1, "kind": "swift.method"}, g), "T")
        self.assertEqual(asm.type_group({"module": "M", "path": "T.U", "file": "g", "line": 2, "kind": "swift.struct"}, g), "T.U")
        self.assertEqual(asm.type_group({"module": "M", "path": "top()", "file": "h", "line": 3, "kind": "swift.func"}, g),
                         "(top level)")

    def test_main_usage(self):
        cache = {"files": {"Sources/A.swift": {"references": [
            [1, 5, "s:main1", 0], [2, 5, "s:main1", 1 << 8], [3, 1, "s:new1", 0], [4, 1, "s:changed", 0],
            [5, 1, "s:theirs", 0]]}}}
        on_main, new_refs = asm.main_usage(cache, {"s:main1": "FilePath"}, {"s:changed": "FileDescriptor.close()"},
                                           {"s:new1", "s:changed"})
        self.assertEqual(dict(on_main), {"s:main1": [["Sources/A.swift", 1, 5]],
                                         "s:changed": [["Sources/A.swift", 4, 1]]})
        self.assertEqual(dict(new_refs), {"s:new1": 1})

    def test_parse_gaps(self):
        text = ("# Gaps\n\n| C name | Tool and option | Platforms | Note |\n|---|---|---|---|\n"
                "| `fnmatch` | `find -name`, `-path` | all | n1 |\n"
                "| `fts_open` with `FTS_LOGICAL` | `find -L`, `du -L` | all | n2 |\n"
                "| a path that ends in `/` | `find`, `du` | all | n3 |\n\nAfter.\n| x | y | z | w |\n")
        rows = asm.parse_gaps(text, {"find", "du", "ls"})
        self.assertEqual([r["tools"] for r in rows], [["find"], ["du", "find"], ["du", "find"]])
        self.assertEqual(rows[1]["names"], ["fts_open", "FTS_LOGICAL"])
        self.assertEqual(rows[2]["what"], "a path that ends in `/`")

    def test_darwin_use(self):
        clone = os.path.join(self.tmp, "eco", "pkg")
        os.makedirs(clone)
        sv = {"o/pkg": {"darwinFiles": 2, "darwinFileList": ["a.swift", "b.swift"], "commit": "c1", "scan": "library targets"}}
        runs = [{"id": "r1", "date": "2026-09-30", "systemCommit": "s1",
                 "packages": {os.path.realpath(clone): {"name": "pkg", "commit": "c1", "extraction": "index"}},
                 "queue": [{"name": "open", "kind": "covered", "packages": {"pkg": 3, "other": 1}, "files": {"pkg": ["a.swift"]}},
                           {"name": "fts_open", "kind": "gap", "packages": {"pkg": 1}, "files": {"pkg": ["b.swift"]}},
                           {"name": "read", "kind": "covered", "packages": {"other": 2}}]}]
        du = asm.darwin_use(clone, "O/pkg", sv, runs)
        self.assertEqual(du["files"], 2)
        self.assertEqual([x["name"] for x in du["names"]], ["fts_open", "open"])   # gaps first
        self.assertEqual(du["run"]["id"], "r1")
        self.assertIsNone(asm.darwin_use(os.path.join(self.tmp, "none"), "x/y", sv, runs))


# ---------------------------------------------------------------- the page and the check

def fixture_master():
    """A small, consistent master.json: two new declarations, one used by a
    migrated package at two sites; a ledger with three sites."""
    decls = []
    for i, (path, kind) in enumerate((("T", "swift.struct"), ("T.f()", "swift.method"))):
        decls.append({"id": f"M|{path}|x", "module": "SystemPackage", "path": path, "title": path, "kind": kind,
                      "kindName": "Structure" if i == 0 else "Instance Method", "area": "System/Thing", "type": "T",
                      "state": 1 if i == 0 else 2, "pitch": None if i == 0 else "p", "pitches": [], "flags": [],
                      "excluded": False, "file": "Sources/System/T.swift", "line": 10 + i, "platforms": ["Darwin"],
                      "availability": "System 199", "decl": "struct T </script>", "doc": "", "cName": None,
                      "header": None, "origin": "graph", "hiddenClass": None, "usedBy": [], "sameAs": None})
    sites = [["Sources/A.swift", 3, 7, "p", "T.f()"], ["Sources/B.swift", 9, 1, "l", "x.f() /*UI*/"]]
    decls[1]["usedBy"] = [[0, sites]]
    ledger_sites = [{"file": "Sources/A.swift", "line": 1, "module": "Glibc", "type": "import", "importKind": "whole",
                     "category": c, "reason": "r", "platforms": ["Linux"], "names": ["read"], "lacks": [], "kind": "library",
                     "text": "import Glibc"} for c in ("System gap", "unexplained", "exception")]
    pkgs = [{"name": "pkg", "cluster": "update-checkout", "source": "scheme-main.tsv", "remote": "o/pkg", "clone": "../adopters/pkg",
             "swift": "yes", "note": "", "kind": "migrated",
             "migration": {"branches": {"migrate-darwin": "c1"}, "newest": {"branch": "migrate-darwin", "commit": "c1",
                           "base": "b", "commits": 1, "subject": "s"},
                           "readAt": {"branch": "migrate-darwin", "commit": "c1", "resolution": "index", "subject": "s",
                                      "build": "indexed"}},
             "usage": {"new": [[1, sites]], "main": [{"usr": "s:m", "path": "FilePath", "changed": False,
                                                       "sites": [["Sources/A.swift", 2, 1]]}],
                       "branch": "migrate-darwin", "commit": "c1", "resolution": "index", "cache": "x", "link": None},
             "cUse": {"source": "ledger", "where": "w", "commit": "c1", "scope": None, "sites": ledger_sites,
                      "lacks": [], "byCategory": {}, "link": None}},
            {"name": "cat", "cluster": "Unix tools", "source": "swift-system-examples main", "remote": "", "clone": None,
             "swift": "yes", "note": "", "kind": "not-scanned", "migration": None, "usage": None,
             "cUse": {"source": "GAPS.md", "gaps": [{"what": "`x`", "names": ["x"], "tools": ["cat"], "where": "`cat -v`",
                                                     "platforms": "all", "note": "n"}], "commit": "e"}}]
    charts = {"unpitched": [{"date": "2026-10-06", "count": 1, "scopeAdded": 1, "detail": {}, "source": "run", "commit": "h"}],
              "pitched": [{"date": "2026-10-06", "count": 0, "scopeAdded": 0, "detail": {}, "source": "run", "commit": "h"}],
              "cuses": [{"date": "2026-10-06", "count": 3, "scopeAdded": 3, "detail": {"perRepo": {"pkg": 3}},
                         "source": "run", "commit": "h"}]}
    meta = {"generated": "2026-10-06", "head": {"ref": "system-next", "commit": "h"}, "base": {"ref": "main", "commit": "b"},
            "apiDelta": {"added": 2, "hidden": 0}, "graph": {"path": None, "commit": "h"},
            "ledger": {"total": 3, "byCategory": {"System gap": 1, "unexplained": 1, "exception": 1}, "excluded": 0},
            "survey": {}, "runs": [], "examples": {"commit": "e"}, "universe": {"counts": {}}, "problems": [],
            "typeTags": {}, "labels": {"clusters": asm.CLUSTER_LABELS, "kinds": asm.KIND_LABELS, "states": asm.STATE_LABELS,
                                       "categories": asm.CATEGORY_LABELS, "queueKinds": asm.QUEUE_KIND_LABELS}}
    m = {"schema": asm.SCHEMA, "meta": meta, "declarations": decls, "packages": pkgs, "charts": charts, "notes": {}}
    m["digest"] = asm.digest(m)
    return m


def fixture_inputs(t, master):
    delta = {"meta": {}, "entries": [{"status": "added", "module": d["module"], "path": d["path"], "file": d["file"],
                                      "line": d["line"]} for d in master["declarations"]],
             "hiddenFromGraphs": {"added": []}}
    ledger = {"meta": {}, "read": [{"repository": "pkg"}], "notRead": [],
              "sites": [{"repository": "pkg", "category": s["category"], "file": s["file"], "line": s["line"]}
                        for s in master["packages"][0]["cUse"]["sites"]] +
                       [{"repository": "pkg", "category": "excluded", "file": "z", "line": 1}]}
    status = STATUS_MD.replace("3 unexplained, 2 System gap, 1 exception; 2 excluded",
                               "1 unexplained, 1 System gap, 1 exception; 1 excluded")
    graph = {"nodes": {"s:f": {"kind": "declaration", "origin": "head"},
                       "package:pkg": {"kind": "package", "name": "pkg", "remote": "o/pkg"}},
             "links": [{"kind": "usedBy", "from": "s:f", "to": "package:pkg", "sites": [{}, {}]}]}
    gpath = os.path.join(t.tmp, "graph.json.gz")
    with gzip.open(gpath, "wt", encoding="utf-8") as f:
        json.dump(graph, f)
    rows = [{"date": "2026-10-06", "chart": k, "count": master["charts"][k][-1]["count"], "scope_added": 0,
             "source": "run", "commit": "h", "detail": {}} for k in asm.CHARTS]
    hist = os.path.join(t.tmp, "history.tsv")
    asm.write_history(hist, rows)
    uni = os.path.join(t.tmp, "universe.tsv")
    uv.write([{"name": p["name"], "cluster": p["cluster"], "source": p["source"], "clone": p["clone"] or "none",
               "remote": p["remote"], "swift": p["swift"], "note": ""} for p in master["packages"]], uni)
    return {"delta": t.write("api-delta.json", delta), "ledger": t.write("ledger.json", ledger),
            "status": t.write("STATUS.md", status), "graph": gpath, "history": hist, "universe": uni}


class PageAndCheckTests(Temp):
    def run_check(self, master, node="auto", mutate_page=None):
        inp = fixture_inputs(self, master)
        mpath = self.write("master.json", master)
        page = pg.render(master)
        if mutate_page:
            page = mutate_page(page)
        ppath = self.write("master.html", page)
        a = argparse.Namespace(master=mpath, page=ppath, delta=inp["delta"], ledger_json=inp["ledger"],
                               status_md=inp["status"], universe=inp["universe"], history=inp["history"],
                               graph=inp["graph"], node=node)
        return chk.run(a)

    def test_encode(self):
        m = fixture_master()
        pd = pg.encode(m)
        self.assertEqual(len(pd["D"]), 2)
        self.assertEqual(pd["D"][1][7], 1)                         # Darwin's bit
        self.assertEqual(pd["U"], [[1, 0, [[pd["S"].index("Sources/A.swift"), 3, 7, 0, pd["S"].index("T.f()")],
                                           [pd["S"].index("Sources/B.swift"), 9, 1, 1, pd["S"].index("x.f() /*UI*/")]]]])
        self.assertEqual(pd["P"][0]["cu"]["sites"][0][3], pg.CATEGORIES.index("System gap"))
        self.assertNotIn("</script>", pg.script_json(pd))

    def test_render_one_pass(self):
        page = pg.render(fixture_master())
        self.assertEqual(page.count('<script type="application/json" id="data">'), 1)
        self.assertIn("x.f() /*UI*/", page)                        # data that looks like a placeholder stays data
        self.assertIn("var Model", page)
        self.assertIn("default-src 'none'", page)
        self.assertEqual(chk.page_data(page)["digest"], fixture_master()["digest"])

    def test_check_passes(self):
        c = self.run_check(fixture_master())
        self.assertEqual(c.problems, [])
        self.assertTrue(any("two ways in" in p for p in c.passes))

    @unittest.skipUnless(shutil.which("node"), "node isn't installed")
    def test_check_runs_the_page_model(self):
        c = self.run_check(fixture_master())
        self.assertEqual(c.problems, [])
        self.assertTrue(any(p.startswith("page model, all:") for p in c.passes))

    def test_check_finds_a_use_missing_from_one_view(self):
        m = fixture_master()
        m["packages"][0]["usage"]["new"][0][1] = m["packages"][0]["usage"]["new"][0][1][:1]
        m["digest"] = asm.digest({k: v for k, v in m.items() if k != "digest"})
        c = self.run_check(m, node="")
        self.assertTrue(any("the two ways in" in p for p in c.problems), c.problems)

    def test_check_finds_a_wrong_ledger_total(self):
        m = fixture_master()
        m["meta"]["ledger"]["total"] = 4
        m["digest"] = asm.digest({k: v for k, v in m.items() if k != "digest"})
        c = self.run_check(m, node="")
        self.assertTrue(any(p.startswith("C uses: master.json's total") for p in c.problems), c.problems)

    def test_check_finds_a_declaration_api_delta_lacks(self):
        m = fixture_master()
        extra = dict(m["declarations"][0], path="T.g()", line=99, usedBy=[])
        inp = fixture_inputs(self, m)        # api-delta has the two declarations only
        m["declarations"].append(extra)
        m["digest"] = asm.digest({k: v for k, v in m.items() if k != "digest"})
        mpath = self.write("master.json", m)
        ppath = self.write("master.html", pg.render(m))
        a = argparse.Namespace(master=mpath, page=ppath, delta=inp["delta"], ledger_json=inp["ledger"],
                               status_md=inp["status"], universe=inp["universe"], history=inp["history"],
                               graph=inp["graph"], node="")
        c = chk.run(a)
        self.assertTrue(any(p.startswith("new API:") for p in c.problems), c.problems)

    def test_check_finds_a_network_load_and_a_stale_digest(self):
        c = self.run_check(fixture_master(), node="",
                           mutate_page=lambda p: p.replace("<body>", '<body><img src="https://example.invalid/x.png">', 1)
                           .replace(fixture_master()["digest"], "0" * 64, 1))
        self.assertTrue(any("network" in p for p in c.problems), c.problems)
        self.assertTrue(any("digest" in p for p in c.problems), c.problems)

    def test_check_finds_an_edited_master(self):
        m = fixture_master()
        m["declarations"][0]["state"] = 2     # after the digest was taken
        c = self.run_check(m, node="")
        self.assertTrue(any("edited after" in p for p in c.problems), c.problems)


if __name__ == "__main__":
    unittest.main()
