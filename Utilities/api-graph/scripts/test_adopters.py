#!/usr/bin/env python3
"""Tests of adopters.py's discovery and adopted sites, on git repositories
made in a temporary directory that the tests remove: each clone is read at
its newest migration branch (migrate-all, else migrate-unix, else
migrate-darwin), the examples' repository is read at main as a package of
its own, a qualifier is a type's reference only, and the examples' Sources
are read whole, every line their Darwin build skips matched by name.

Git runs with no global or system configuration (no hooks, no signing),
and the clones' remotes are URLs in their configuration only: nothing is
fetched, and nothing outside the temporary directory is written.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-graph/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adopters  # noqa: E402

GIT_ENV = {"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull, "GIT_AUTHOR_NAME": "t",
           "GIT_AUTHOR_EMAIL": "t@example.invalid", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@example.invalid", "GIT_NO_LAZY_FETCH": "1"}


def git(path, *args):
    return subprocess.run(["git", "-C", path, *args], check=True, capture_output=True, text=True,
                          env=dict(os.environ, **GIT_ENV)).stdout


def commit(path, files, message):
    for rel, text in files.items():
        full = os.path.join(path, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(text)
    git(path, "add", "-A")
    git(path, "commit", "-q", "--no-verify", "-m", message)


def make_clone(path, remote, branches=()):
    """A clone with a package manifest on main, an origin by URL only, and
    each branch (name, files) one commit past the one before it, or none
    past main when files is empty."""
    os.makedirs(path)
    git(path, "init", "-q", "-b", "main")
    commit(path, {"Package.swift": "// swift-tools-version:6.1\n"}, "upstream")
    git(path, "remote", "add", "origin", f"https://github.com/{remote}.git")
    for name, files in branches:
        git(path, "checkout", "-q", "-b", name)
        if files:
            commit(path, files, name)
    git(path, "checkout", "-q", "main")


class Matcher:
    """A lexical matcher that finds `Distinctive.thing` only."""

    def match(self, code, start, end, own):
        i = code.find("Distinctive.thing", start, end)
        return [("n:thing", i - start + 1, "qualified member")] if i >= 0 else []


class AdopterTests(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="api-graph-adopters-test-"))
        # adopters.py's own git calls inherit the environment: none of the
        # user's configuration either.
        self.saved = {k: os.environ.get(k) for k in GIT_ENV}
        os.environ.update(GIT_ENV)
        self.adopters = os.path.join(self.tmp, "adopters")
        self.repo = os.path.join(self.tmp, "swift-system")
        os.makedirs(self.repo)
        git(self.repo, "init", "-q", "-b", "main")
        commit(self.repo, {"Package.swift": "// System\n"}, "System")

    def tearDown(self):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_newest_branch_per_clone(self):
        make_clone(os.path.join(self.adopters, "unix"), "o/unix",
                   [("migrate-darwin", {"A.swift": "a\n"}), ("migrate-unix", {"B.swift": "b\n"})])
        make_clone(os.path.join(self.adopters, "all"), "o/all",
                   [("migrate-darwin", {"A.swift": "a\n"}), ("migrate-all", {"C.swift": "c\n"})])
        make_clone(os.path.join(self.adopters, "empty"), "o/empty", [("migrate-darwin", {})])
        make_clone(os.path.join(self.adopters, "none"), "o/none")
        pkgs = adopters.discover(self.adopters, None, adopters.MIGRATION_BRANCHES, self.repo)
        info = {k: v["adopters"] for k, v in pkgs.items()}
        self.assertEqual(info["unix"]["branch"], "migrate-unix")
        self.assertEqual(sorted(info["unix"]["branches"]), ["migrate-darwin", "migrate-unix"])
        self.assertEqual(info["unix"]["commits"], 2)
        self.assertEqual(info["unix"]["commit"], git(os.path.join(self.adopters, "unix"), "rev-parse",
                                                    "migrate-unix").strip())
        self.assertEqual(info["all"]["branch"], "migrate-all")
        self.assertTrue(info["all"]["migrated"])
        self.assertEqual((info["empty"]["branch"], info["empty"]["migrated"]), ("migrate-darwin", False))
        self.assertEqual((info["none"]["branch"], info["none"]["migrated"]), (None, False))
        # One branch, as --branch gives it: a clone without it isn't migrated.
        one = adopters.discover(self.adopters, None, ["migrate-darwin"], self.repo)
        self.assertEqual(one["unix"]["adopters"]["branch"], "migrate-darwin")
        self.assertEqual(one["unix"]["adopters"]["commits"], 1)
        self.assertEqual(one["all"]["adopters"]["branch"], "migrate-darwin")

    def test_examples_are_a_package(self):
        ex = os.path.join(self.tmp, "swift-system-examples")
        make_clone(ex, "someone/swift-system-examples")
        commit(ex, {"Sources/Tool/Tool.swift": "let x = 1\n"}, "a tool")
        pkgs = adopters.discover(None, None, adopters.MIGRATION_BRANCHES, self.repo, (ex, "main"))
        p = pkgs["swift-system-examples"]
        self.assertEqual(p["role"], "examples")
        self.assertEqual((p["adopters"]["branch"], p["adopters"]["base"], p["adopters"]["commits"]), ("main", None, 2))
        self.assertTrue(p["adopters"]["migrated"] and p["adopters"]["examples"])

    def sites(self, path, info, files, symbols, refs):
        """migration_sites over an index of the given references, {file: [[line, col, usr, flags]]}."""
        idx = {"status": "indexed", "build": {"status": "indexed"}, "symbols": symbols,
               "files": {f: {"module": "M", "references": refs.get(f, [])} for f in files}}
        usr_node = {u: "n:" + u for u in symbols}
        out = adopters.migration_sites("pkg", {"adopters": info}, idx, usr_node, Matcher(), adopters.Conditions())
        return {(s["file"], s["line"], s["node"]): s for s in out["sites"]}, out

    def test_qualifier_is_a_type_only(self):
        clone = os.path.join(self.adopters, "pkg")
        code = "let a = PThread.Mutex()\nlet b = ProcessID.current.rawValue\n"
        make_clone(clone, "o/pkg", [("migrate-darwin", {"Sources/P/P.swift": code})])
        info = adopters.discover(self.adopters, None, adopters.MIGRATION_BRANCHES, self.repo)["pkg"]["adopters"]
        symbols = {"PThread": {"name": "PThread", "kind": 5}, "Mutex.init": {"name": "init()", "kind": 22},
                   "Mutex": {"name": "Mutex", "kind": 6}, "ProcessID": {"name": "ProcessID", "kind": 6},
                   "current": {"name": "current", "kind": 21}, "rawValue": {"name": "rawValue", "kind": 19}}
        refs = {"Sources/P/P.swift": [[1, 9, "PThread", 0], [1, 17, "Mutex", 0], [1, 17, "Mutex.init", 0],
                                      [2, 9, "ProcessID", 0], [2, 19, "current", 0], [2, 27, "rawValue", 0]]}
        by, out = self.sites(clone, info, ["Sources/P/P.swift"], symbols, refs)
        f = "Sources/P/P.swift"
        self.assertTrue(by[(f, 1, "n:PThread")]["qualifier"])          # an enum before `.Mutex`
        self.assertTrue(by[(f, 2, "n:ProcessID")]["qualifier"])        # a struct before `.current`
        self.assertFalse(by[(f, 2, "n:current")]["qualifier"])         # a property before `.rawValue`: a use
        self.assertFalse(by[(f, 2, "n:rawValue")]["qualifier"])
        self.assertFalse(by[(f, 1, "n:Mutex")]["qualifier"])
        self.assertEqual(out["adopted"]["branch"], "migrate-darwin")
        self.assertEqual(out["adopted"]["sites"]["qualifier"], 2)
        self.assertTrue(by[(f, 2, "n:current")]["hunk"])               # the migration's hunk introduced it

    def test_examples_sources_are_read_whole(self):
        ex = os.path.join(self.tmp, "swift-system-examples")
        make_clone(ex, "someone/swift-system-examples")
        tool = "let a = Distinctive.thing\n#if os(Linux)\nlet b = Distinctive.thing\n#endif\n"
        commit(ex, {"Sources/Tool/Tool.swift": tool, "Sources/Other/Other.swift": "let c = Distinctive.thing\n",
                    "Tests/T/T.swift": "let d = Distinctive.thing\n"}, "tools")
        info = adopters.discover(None, None, adopters.MIGRATION_BRANCHES, self.repo, (ex, "main"))[
            "swift-system-examples"]["adopters"]
        # Darwin's build compiled Tool.swift (line 1 resolved by the index), not Other.swift.
        by, out = self.sites(ex, info, ["Sources/Tool/Tool.swift"], {"thing": {"name": "thing", "kind": 21}},
                             {"Sources/Tool/Tool.swift": [[1, 21, "thing", 0]]})
        self.assertEqual(sorted((k[0], k[1], s["resolution"]) for k, s in by.items()),
                         [("Sources/Other/Other.swift", 1, "lexical"), ("Sources/Tool/Tool.swift", 1, "precise"),
                          ("Sources/Tool/Tool.swift", 3, "lexical")])
        self.assertTrue(all(s["hunk"] is None and s["introduced"] for s in by.values()))
        self.assertEqual(out["hunks"], {})
        self.assertTrue(out["adopted"]["examples"])
        self.assertEqual(out["adopted"]["branch"], "main")


if __name__ == "__main__":
    unittest.main()
