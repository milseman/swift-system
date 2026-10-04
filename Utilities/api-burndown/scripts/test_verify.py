#!/usr/bin/env python3
"""Tests of verify.py's checks, each on a small fixture with a planted miss.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import copy  # noqa: E402
import datetime  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import page  # noqa: E402
import verify as vf  # noqa: E402


class Repo:
    """A scratch git repository."""

    def __init__(self, prefix):
        self.path = tempfile.mkdtemp(prefix=prefix)
        self.git("init", "-q", "-b", "main")

    def git(self, *args):
        env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null",
                   GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com", GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL="t@example.com")
        return subprocess.run(["git", "-C", self.path, *args], capture_output=True, text=True, env=env,
                              check=True).stdout.strip()

    def commit(self, files, msg="c"):
        for name, text in files.items():
            p = os.path.join(self.path, name)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", msg)
        return self.git("rev-parse", "HEAD")

    def close(self):
        shutil.rmtree(self.path)


def decl(path, state=1, kind="swift.method", kind_name="Instance Method", origin="graph", line=1, platforms=("Darwin",),
         excluded=False, flags=(), used_by=(), c_name=None, header="Swift-only", sub="Swift-only",
         how="Swift-only: its code reaches no C", c_names=(), usr=None, module="SystemPackage",
         file="Sources/System/A.swift"):
    """A burndown.json declaration, with the fields page.py and verify.py read."""
    return {"id": f"{module}|{path}|{line}", "origin": origin, "usr": usr, "module": module, "path": path,
            "title": path.rsplit(".", 1)[-1], "kind": kind, "kindName": kind_name, "decl": "", "file": file,
            "line": line, "platforms": list(platforms), "availability": "", "docSummary": "", "hiddenClass": None,
            "flags": list(flags), "renamedTo": None, "cNames": [dict({"role": "subject", "restricted": False}, **c)
                                                                for c in c_names],
            "cName": c_name, "cNameFromCode": False, "header": header, "sdkSubmodule": sub, "sdkModule": sub,
            "headerHow": how, "usedBy": [{"package": p, "sites": s} for p, s in used_by], "couldUse": 0,
            "area": "System/A", "pitches": [], "pitch": None, "state": state, "excluded": excluded}


def burndown(decls, merged=(), head="h" * 40, base="b" * 40, graph=None):
    """A burndown.json whose totals are its declarations', with its digest."""
    main = {str(s): 0 for s in vf.STATES}
    out = {str(s): 0 for s in vf.STATES}
    for u in list(decls) + list(merged):
        (out if u["excluded"] else main)[str(u["state"])] += 1
    data = {
        "schema": "api-burndown/1",
        "meta": {"generated": "2026-10-04", "baseRef": "main", "baseCommit": base, "baseSubject": "",
                 "headRef": "system-next", "headCommit": head, "headSubject": "",
                 "graph": dict({"headCommit": head, "date": "2026-10-04", "matchesHead": True, "source": "test",
                                "unitsWithoutNode": 0}, **(graph or {})),
                 "apiDelta": {"added": 0, "hidden": 0, "date": "2026-10-04", "swift": "", "path": None},
                 "pitches": {"files": [], "dirty": False, "problems": []},
                 "states": {"entries": {}, "problems": [], "unknownPitches": []},
                 "headers": {"sdkVersion": "26.0", "vocab": None, "sdk": None}, "upstream": None,
                 "tool": {"commit": head, "dirty": False}},
        "states": [{"id": s, "key": str(s), "label": str(s)} for s in vf.STATES],
        "flags": {"stub": "stub", "overload": "overload"}, "excludedFlags": ["stub"],
        "totals": {"main": main, "outside": out, "mainCount": sum(main.values()), "outsideCount": sum(out.values()),
                   "declarations": len(decls), "merged": len(merged), "flags": {}},
        "declarations": list(decls), "merged": list(merged),
        "history": {"days": [], "storeCommits": []}, "historyUnits": [],
    }
    return redigest(data)


def redigest(data):
    data.pop("digest", None)
    data["digest"] = vf.body_digest(data)
    return data


def levels(rep, check):
    return [(lv, text) for c, lv, text in rep.lines if c == check]


def gz(path, doc):
    with gzip.open(path, "wt", encoding="utf-8") as f:
        json.dump(doc, f)
    return path


# ------------------------------------------------------------------ 2 sums

class SumsTests(unittest.TestCase):
    def data(self):
        return burndown([
            decl("A.f()", state=1),
            decl("A.g()", state=2, platforms=("Darwin", "Linux"), kind="swift.property", kind_name="Instance Property"),
            decl("A._h", state=1, excluded=True, flags=("stub",)),
            decl("B", state=1, kind="swift.struct", kind_name="Structure", c_name="foo", header="foo.h", sub="F.foo",
                 how="vocabulary", used_by=[("pkg", [["a.swift", 1, 1, "precise"]])]),
        ])

    def run_sums(self, data, pd):
        rep = vf.Report()
        vf.check_sums(rep, data, pd, "burndown.html")
        return rep

    def test_a_consistent_page_passes(self):
        data = self.data()
        rep = self.run_sums(data, page.compact(data))
        self.assertEqual({lv for lv, _ in levels(rep, 2)}, {"pass"}, levels(rep, 2))
        self.assertEqual(len(levels(rep, 2)), 3 + len(vf.VIEWS))

    def test_planted_total_fails(self):
        data = self.data()
        data["totals"]["main"]["1"] += 1
        redigest(data)
        rep = self.run_sums(data, page.compact(data))
        failed = [t for lv, t in levels(rep, 2) if lv == "fail"]
        self.assertTrue(any(t.startswith("totals:") for t in failed), failed)
        self.assertTrue(any(t.startswith("states:") for t in failed), failed)

    def test_a_row_in_no_platform_fails_the_platform_grouping(self):
        data = self.data()
        data["declarations"][0]["platforms"] = []
        redigest(data)
        failed = [t for lv, t in levels(self.run_sums(data, page.compact(data)), 2) if lv == "fail"]
        self.assertEqual(len(failed), 1, failed)
        self.assertIn("in no group", failed[0])

    def test_a_row_with_no_state_fails(self):
        data = self.data()
        pd = page.compact(data)
        pd["D"][1][0] = 7
        failed = [t for lv, t in levels(self.run_sums(data, pd), 2) if lv == "fail"]
        self.assertTrue(any(t.startswith("states:") and "no state 1-5" in t for t in failed), failed)
        self.assertTrue(any(t.startswith("kind:") and "states add up" in t for t in failed), failed)

    def test_another_burndowns_page_fails(self):
        data = self.data()
        other = copy.deepcopy(data)
        other["declarations"][0]["path"] = "A.other()"
        rep = self.run_sums(data, page.compact(redigest(other)))
        self.assertEqual(levels(rep, 2)[0][0], "fail")
        self.assertIn("embeds digest", levels(rep, 2)[0][1])

    def test_an_edited_burndown_json_fails(self):
        data = self.data()
        pd = page.compact(data)
        data["declarations"][0]["state"] = 2   # without a new digest
        self.assertIn("changed after burndown.py", levels(self.run_sums(data, pd), 2)[0][1])


# ------------------------------------------------------------------ 3 recount

def delta_entry(path, kind, kind_name, line):
    return {"status": "added", "module": "SystemPackage", "path": path, "kind": kind, "kindName": kind_name,
            "file": "Sources/System/A.swift", "line": line}


def hidden(name, scopes, kw, line, modifiers=("public",)):
    return {"module": "SystemPackage", "name": name, "scopes": list(scopes), "kw": kw, "modifiers": list(modifiers),
            "file": "Sources/System/W.swift", "line": line}


class RecountTests(unittest.TestCase):
    def fixture(self):
        delta = {"meta": {"baseCommit": "b" * 40, "headCommit": "h" * 40},
                 "entries": [delta_entry("A.f()", "swift.method", "Instance Method", 1),
                             delta_entry("A.x", "swift.type.property", "Type Property", 2),
                             delta_entry("A.==(_:_:)", "swift.func.op", "Operator", 3)],
                 "hiddenFromGraphs": {"added": [hidden("w", ["W"], "var", 1, ("public", "static")),
                                                hidden("==(_:_:)", ["W"], "func", 2, ("public", "static"))]}}
        decls = [decl("A.f()", line=1),
                 decl("A.x", kind="swift.type.property", kind_name="Type Property", line=2),
                 decl("A.==(_:_:)", kind="swift.func.op", kind_name="Operator", line=3),
                 decl("W.w", origin="scan", kind="swift.type.property", kind_name="Type Property", line=1,
                      file="Sources/System/W.swift"),
                 decl("W.==(_:_:)", origin="scan", kind="swift.func.op", kind_name="Operator", line=2,
                      file="Sources/System/W.swift")]
        return delta, burndown(decls)

    def run_recount(self, delta, data):
        rep = vf.Report()
        vf.check_recount(rep, data, delta, page.compact(data))
        return rep

    def test_the_recount_agrees(self):
        rep = self.run_recount(*self.fixture())
        self.assertEqual({lv for lv, _ in levels(rep, 3)}, {"pass"}, levels(rep, 3))

    def test_planted_kind_fails(self):
        delta, data = self.fixture()
        data["declarations"][1].update(kind="swift.property", kindName="Instance Property")
        rep = self.run_recount(delta, redigest(data))
        got = dict((t.split(":", 1)[0], lv) for lv, t in levels(rep, 3))
        self.assertEqual(got["kinds"], "fail")
        self.assertEqual(got["kind names (the page's Kind grouping)"], "fail")
        self.assertIn("`A.x`", "\n".join(rep.details[3]))

    def test_a_missing_declaration_fails_the_total(self):
        delta, data = self.fixture()
        data["declarations"].pop()
        data = burndown(data["declarations"])
        got = dict((t.split(":", 1)[0], lv) for lv, t in levels(self.run_recount(delta, data), 3))
        self.assertEqual(got["total"], "fail")

    def test_a_declaration_that_isnt_api_deltas_fails_the_total(self):
        delta, data = self.fixture()
        data["declarations"][0]["path"] = "A.renamed()"   # the same counts by module and kind
        rep = self.run_recount(delta, redigest(data))
        got = dict((t.split(":", 1)[0], lv) for lv, t in levels(rep, 3))
        self.assertEqual(got, {"total": "fail", "modules": "pass", "kinds": "pass",
                               "kind names (the page's Kind grouping)": "pass"})
        self.assertIn("api-delta's `A.f()`", "\n".join(rep.details[3]))

    def test_a_hidden_operator_typed_as_a_method_is_a_known_error(self):
        delta, data = self.fixture()
        data["declarations"][4].update(kind="swift.type.method", kindName="Type Method")
        rep = self.run_recount(delta, redigest(data))
        got = dict((t.split(":", 1)[0], (lv, t)) for lv, t in levels(rep, 3))
        self.assertEqual(got["kinds"][0], "warn")
        self.assertIn("hidden-operator-kind", got["kinds"][1])
        self.assertEqual(got["kind names (the page's Kind grouping)"][0], "warn")

    def test_symbol_kinds_of_hidden_declarations(self):
        k = vf.symbol_kind
        self.assertEqual(k(hidden("x", [], "var", 1)), "swift.var")
        self.assertEqual(k(hidden("x", ["T"], "let", 1)), "swift.property")
        self.assertEqual(k(hidden("x", ["T"], "var", 1, ("public", "static"))), "swift.type.property")
        self.assertEqual(k(hidden("f(_:)", [], "func", 1)), "swift.func")
        self.assertEqual(k(hidden("f(_:)", ["T"], "func", 1, ("public", "class"))), "swift.type.method")
        self.assertEqual(k(hidden("~=(_:_:)", ["T"], "func", 1, ("public", "static"))), "swift.func.op")
        self.assertEqual(k(hidden("init(_:)", ["T"], "init?", 1)), "swift.init")
        self.assertEqual(k(hidden("T", [], "struct", 1)), "swift.struct")


# ------------------------------------------------------------------ 4 sites

class SitesTests(unittest.TestCase):
    MAIN = "\n".join([
        "import SystemPackage",
        'let fd = try FileDescriptor.open("/tmp/x", .readOnly)',
        "try fd.setOwner(user: nil, group: nil)",
        "let t = Moment(seconds: 1, nanoseconds: 0)",
        "let u = FileDescriptor.Kind(rawValue: 1)",
        "",
    ])

    def setUp(self):
        self.app = Repo("verify-adopter-")
        self.app.commit({"Sources/App/Alias.swift": "typealias Moment = timespec\n"})
        self.app.git("checkout", "-q", "-b", "migrate-darwin")
        self.head = self.app.commit({"Sources/App/Main.swift": self.MAIN})

    def tearDown(self):
        self.app.close()

    def graph(self, commit=None):
        return vf.GraphView({"meta": {"headCommit": "h" * 40}, "links": [], "nodes": {
            "package:app": {"kind": "package", "name": "app", "adopted": {
                "path": self.app.path, "branch": "migrate-darwin", "commit": commit or self.head, "dir": "app"}}}})

    def run_sites(self, sites, graph=None):
        decls = [decl(path, used_by=[("app", [["Sources/App/Main.swift", ln, col, "precise"]])], line=i)
                 for i, (path, ln, col) in enumerate(sites)]
        rep = vf.Report()
        vf.check_sites(rep, burndown(decls), graph or self.graph(), None, "1", 0)
        return rep

    def test_names_on_their_lines_pass(self):
        rep = self.run_sites([("FileDescriptor.setOwner(user:group:retryOnInterrupt:)", 3, 8),
                              ("FileDescriptor.Kind.init(rawValue:)", 5, 24),
                              ("FileDescriptor.open(_:_:options:permissions:retryOnInterrupt:)", 2, 29)])
        self.assertEqual(levels(rep, 4)[0][0], "pass", levels(rep, 4))

    def test_planted_miss_fails(self):
        rep = self.run_sites([("FileDescriptor.setOwner(user:group:retryOnInterrupt:)", 2, 8)])
        self.assertEqual(levels(rep, 4)[0][0], "fail")
        self.assertIn("**miss**: `FileDescriptor.setOwner(user:group:retryOnInterrupt:)` at app: "
                      "Sources/App/Main.swift:2:8", "\n".join(rep.details[4]))

    def test_an_init_through_a_typealias_is_explained(self):
        rep = self.run_sites([("timespec.init(seconds:nanoseconds:)", 4, 9)])
        self.assertEqual(levels(rep, 4)[0][0], "pass")
        self.assertIn("init-through-alias 1", levels(rep, 4)[0][1])

    def test_a_moved_branch_is_explained_at_the_graphs_commit(self):
        old = self.head
        self.app.commit({"Sources/App/Main.swift": "// a new first line\n" + self.MAIN})
        rep = self.run_sites([("FileDescriptor.setOwner(user:group:retryOnInterrupt:)", 3, 8)], self.graph(old))
        self.assertEqual(levels(rep, 4)[0][0], "pass")
        self.assertIn("branch-moved 1", levels(rep, 4)[0][1])

    def test_split_name(self):
        self.assertEqual(vf.split_name("FilePath.Attribute.init(rawValue:)"), ("Attribute", "init"))
        self.assertEqual(vf.split_name("FileDescriptor.==(_:_:)"), ("FileDescriptor", "=="))
        self.assertEqual(vf.split_name("Signal.SIGTTIN"), ("Signal", "SIGTTIN"))
        self.assertEqual(vf.split_name("Clock...<(_:_:)"), ("Clock", "..<"))
        self.assertEqual(vf.split_name("perror(_:)"), (None, "perror"))

    def test_the_sample_is_seeded(self):
        pop = list(range(100))
        self.assertEqual(vf.sample(pop, 5, "7", "sites"), vf.sample(pop, 5, "7", "sites"))
        self.assertNotEqual(vf.sample(pop, 5, "7", "sites"), vf.sample(pop, 5, "8", "sites"))
        self.assertEqual(vf.sample(pop, None, "7", "sites"), pop)


# ------------------------------------------------------------------ 5 C names

FOO_H = """\
/* foo_close is only in a comment */
#define FOO_FLAG 1
struct foo_s { int f_x; };
int foo_open(const char *);
"""
BAR_H = "int bar(void);\n"
SOURCE = """\
extension FileDescriptor {
  public func frob() throws(Errno) {
    try _frob().get()
  }
  internal func _frob() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_frob(self.rawValue) }
  }
}
internal func system_frob(
  _ fd: CInt
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, mocked_only_call) }
#endif
  return frob(fd)
}
"""


class CNamesTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="verify-sdk-")
        inc = os.path.join(self.dir, "sdk", "usr", "include")
        os.makedirs(inc)
        for name, text in (("foo.h", FOO_H), ("bar.h", BAR_H)):
            with open(os.path.join(inc, name), "w") as f:
                f.write(text)
        vocab = gz(os.path.join(self.dir, "vocab.json.gz"), {"note": "", "modules": 2, "vocab": {
            "F.foo": {"foo_open": [1 << 12, 1]}, "F.fwd": {"foo_s": [1 << 6, 1]}, "F.bar": {"bar": [1 << 12, 1]}}})
        self.sdk = vf.SDK(os.path.join(self.dir, "sdk"), vocab)
        self.system = Repo("verify-system-")
        self.commit = self.system.commit({"Sources/System/A.swift": SOURCE})

    def tearDown(self):
        shutil.rmtree(self.dir)
        self.system.close()

    def header_decl(self, c_name, header, sub="F.foo", how="vocabulary", path="A.f()"):
        return decl(path, c_name=c_name, header=header, sub=sub, how=how, c_names=[{"name": c_name, "code": False}])

    def run_headers(self, decls):
        rep = vf.Report()
        vf.check_cnames(rep, burndown(decls), None, self.sdk, lambda c: None, None, "1", 0)
        return levels(rep, 5)[0], rep

    def test_a_header_that_declares_its_name_passes(self):
        (lv, text), _ = self.run_headers([self.header_decl("foo_open", "foo.h")])
        self.assertEqual(lv, "pass", text)

    def test_planted_wrong_header_fails(self):
        (lv, text), rep = self.run_headers([self.header_decl("foo_open", "bar.h"),
                                            self.header_decl("foo_close", "foo.h", path="A.g()")])
        self.assertEqual(lv, "fail", text)
        details = "\n".join(rep.details[5])
        self.assertIn("bar.h doesn't declare foo_open", details)
        self.assertIn("foo.h doesn't declare foo_close", details)   # only in a comment

    def test_vocabulary_disagreements_pass_only_with_a_cause(self):
        (lv, text), _ = self.run_headers([
            self.header_decl("foo_s", "foo.h", how="definition"),           # a forward declaration elsewhere
            self.header_decl("FOO_FLAG", "foo.h", how="#define"),           # a macro the index didn't record
            self.header_decl("foo_open", "foo.h", sub="F"),                  # no: F isn't the vocabulary's module
        ])
        self.assertEqual(lv, "fail", text)
        self.assertIn("vocab-forward-declaration 1", text)
        self.assertIn("macro-not-indexed 1", text)

    def test_the_modules_header_fallback_is_a_known_error(self):
        (lv, text), _ = self.run_headers([self.header_decl("foo_open", "bar.h", how="vocabulary (module's header)")])
        self.assertEqual(lv, "warn", text)
        self.assertIn("module-header-fallback 1", text)

    def graph(self, sources):
        """A declaration `FileDescriptor.frob()` at lines 2-4, linked to C names with these sources."""
        nodes = {"s:frob": {"kind": "declaration", "origin": "head", "module": "SystemPackage",
                            "path": "FileDescriptor.frob()", "file": "Sources/System/A.swift", "start": 2, "end": 4}}
        links = []
        for name, src in sources.items():
            nodes["cname:" + name] = {"kind": "cname", "name": name}
            links.append({"kind": "wraps", "from": "s:frob", "to": "cname:" + name, "sources": src})
        return vf.GraphView({"meta": {"headCommit": self.commit}, "nodes": nodes, "links": links})

    def run_code(self, graph, c_names):
        u = decl("FileDescriptor.frob()", usr="s:frob", c_names=c_names)
        rep = vf.Report()
        walks = {}
        vf.check_cnames(rep, burndown([u]), graph, self.sdk,
                        lambda c: walks.setdefault(c, vf.SourceWalk(vf.Git(self.system.path), c)), None, "1", 0)
        return [x for x in levels(rep, 5) if x[1].startswith("code:")][0], rep

    def test_a_c_name_its_code_reaches_passes(self):
        (lv, text), _ = self.run_code(self.graph({"frob": ["code"]}), [{"name": "frob", "code": True}])
        self.assertEqual(lv, "pass", text)

    def test_planted_mock_only_c_name_fails(self):
        (lv, text), rep = self.run_code(self.graph({"frob": ["code"], "mocked_only_call": ["code"]}),
                                        [{"name": "frob", "code": True}, {"name": "mocked_only_call", "code": True}])
        self.assertEqual(lv, "fail", text)
        self.assertIn("`mocked_only_call`: no code it reaches names it", "\n".join(rep.details[5]))

    def test_a_code_mark_the_graph_disagrees_with_fails(self):
        (lv, text), rep = self.run_code(self.graph({"frob": ["code", "doc"]}), [{"name": "frob", "code": True}])
        self.assertEqual(lv, "fail", text)
        self.assertIn("the graph's link is from code+doc", "\n".join(rep.details[5]))

    def test_mock_lines_are_dropped(self):
        lines = vf.code_lines(SOURCE)
        self.assertNotIn("mocked_only_call", "\n".join(lines))
        self.assertIn("return frob(fd)", "\n".join(lines))
        self.assertEqual(len(lines), len(SOURCE.split("\n")))


# ------------------------------------------------------------------ 1 freshness

class FreshnessTests(unittest.TestCase):
    def setUp(self):
        self.sys = Repo("verify-system-")
        self.base = self.sys.commit({"f": "base\n"})
        self.sys.git("checkout", "-q", "-b", "system-next")
        self.head = self.sys.commit({"f": "head\n"})
        self.sys.git("update-ref", "refs/remotes/origin/main", self.base)
        self.app = Repo("verify-adopter-")
        self.app.git("checkout", "-q", "-b", "migrate-darwin")
        self.app_head = self.app.commit({"a": "1\n"})

    def tearDown(self):
        self.sys.close()
        self.app.close()

    def run_freshness(self, now=None, upstream=None):
        data = burndown([], head=self.head, base=self.base)
        data["meta"]["upstream"] = upstream
        delta = {"meta": {"baseCommit": self.base, "headCommit": self.head}}
        graph = vf.GraphView({"meta": {"headCommit": self.head}, "links": [], "nodes": {
            "package:app": {"kind": "package", "name": "app", "adopted": {
                "path": self.app.path, "branch": "migrate-darwin", "commit": self.app_head, "dir": "app"}}}})
        rep = vf.Report()
        vf.check_freshness(rep, data, delta, graph, vf.Git(self.sys.path), "origin/main",
                           now or datetime.datetime.now().astimezone(), 7)
        return levels(rep, 1)

    def test_current_inputs_pass(self):
        got = self.run_freshness()
        self.assertEqual({lv for lv, _ in got}, {"pass"}, got)
        self.assertEqual(len(got), 6)

    def test_moved_refs_and_an_old_fetch_warn(self):
        self.sys.commit({"f": "newer\n"})
        self.app.commit({"a": "2\n"})
        self.sys.git("checkout", "-q", "-b", "upstream", self.base)
        self.sys.git("update-ref", "refs/remotes/origin/main", self.sys.commit({"g": "upstream\n"}))
        later = datetime.datetime.now().astimezone() + datetime.timedelta(days=30)
        warns = [t for lv, t in self.run_freshness(later) if lv == "warn"]
        self.assertTrue(any(t.startswith("system-next: the page is at") and "1 commit behind" in t for t in warns),
                        warns)
        self.assertTrue(any(t.startswith("app: migrate-darwin") and "1 commit past" in t for t in warns), warns)
        self.assertTrue(any(t.startswith("main is 1 commit behind origin/main") and "over 7 days" in t
                            for t in warns), warns)

    def test_an_upstream_that_moved_after_the_page_warns(self):
        got = self.run_freshness(upstream={"ref": "origin/main", "commit": self.base, "declarations": 0})
        self.assertEqual(got[-1][0], "pass", got)
        self.sys.git("update-ref", "refs/remotes/origin/main", self.head)
        got = self.run_freshness(upstream={"ref": "origin/main", "commit": self.base, "declarations": 0})
        self.assertEqual(got[-1][0], "warn", got)
        self.assertIn("the page's upstream flags are from", got[-1][1])


# ------------------------------------------------------------------ the command

class CommandTests(unittest.TestCase):
    def test_a_fail_exits_1_and_writes_the_report(self):
        d = tempfile.mkdtemp(prefix="verify-cmd-")
        try:
            repo = Repo("verify-system-")
            head = repo.commit({"f": "x\n"})
            data = burndown([decl("A.f()")], head=head, base=head)
            data["meta"]["apiDelta"]["path"] = os.path.join(d, "delta")
            data["totals"]["mainCount"] += 1    # planted
            redigest(data)
            os.makedirs(os.path.join(d, "delta"))
            with open(os.path.join(d, "delta", "api-delta.json"), "w") as f:
                json.dump({"meta": {"baseCommit": head, "headCommit": head}, "hiddenFromGraphs": {"added": []},
                           "entries": [delta_entry("A.f()", "swift.method", "Instance Method", 1)]}, f)
            with open(os.path.join(d, "burndown.json"), "w") as f:
                json.dump(data, f)
            blob = json.dumps(page.compact(data))
            with open(os.path.join(d, "burndown.html"), "w") as f:
                f.write(f'<script id="burndown-data" type="application/json">{blob}</script>')
            report = os.path.join(d, "verify.md")
            with open(os.devnull, "w") as null:
                stdout, sys.stdout = sys.stdout, null
                try:
                    code = vf.main(["--repo", repo.path, "--burndown", os.path.join(d, "burndown.json"),
                                    "--page", os.path.join(d, "burndown.html"), "--report", report, "--upstream", "",
                                    "--sdk", d, "--sample", "all"])
                finally:
                    sys.stdout = stdout
            self.assertEqual(code, 1)
            with open(report) as f:
                text = f.read()
            self.assertIn("| fail | 2 sums | totals:", text)
            self.assertIn("## Known causes", text)
            repo.close()
        finally:
            shutil.rmtree(d)


if __name__ == "__main__":
    unittest.main()
