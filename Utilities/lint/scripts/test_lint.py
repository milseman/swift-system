#!/usr/bin/env python3
"""Tests of lint's checks over text fixtures: each rule of cmake, markers,
conditionals, pitches and api, through the functions the checks run on
what they read (git's files, api-delta's entries, the scanner's
declarations, the symbol graphs, a pitch graph), with stand-ins for System's
coverage and vocabulary. Two tests make a git repository in a temporary
directory (no global or system git configuration, so no hooks, signing or
credential helpers run); one writes pitch files and a graph there. Each
temporary directory is deleted; nothing else is written, and nothing reaches
the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lint/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lintcore  # noqa: E402,F401  (puts the other tools' scripts on the path)
import check_api  # noqa: E402
import check_cmake  # noqa: E402
import check_conditionals  # noqa: E402
import check_markers  # noqa: E402
import check_pitches  # noqa: E402

GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_AUTHOR_NAME="t",
               GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], env=GIT_ENV, check=True, capture_output=True,
                          text=True).stdout


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def rules(findings):
    return [(f.rule, f.line) for f in findings]


# ---------------------------------------------------------------- cmake

CMAKE = """#[[
Sub/InBlockComment.swift is in a block comment.
#]]
add_library(SystemPackage
  A.swift
  Gone.swift)
# Sub/B.swift in a line comment doesn't count
target_sources(SystemPackage PRIVATE
  Sub/C.swift)
"""


class CMakeTests(unittest.TestCase):
    def test_missing_and_stale(self):
        tmp = tempfile.mkdtemp(prefix="lint-test-")
        try:
            git(tmp, "init", "-q")
            for f in ("A.swift", "Sub/C.swift", "Sub/B.swift"):
                write(os.path.join(tmp, "Sources/System", f), "let x = 1\n")
            write(os.path.join(tmp, "Sources/System/CMakeLists.txt"), CMAKE)
            git(tmp, "add", "Sources/System/A.swift", "Sources/System/Sub/C.swift", "Sources/System/CMakeLists.txt")
            # Sub/B.swift stays untracked: new files count before they're committed.
            got = check_cmake.check(tmp, "Sources/System", "Sources/System/CMakeLists.txt")
            self.assertEqual([(f.rule, f.file, f.line) for f in got],
                             [("cmake/missing", "Sources/System/Sub/B.swift", 1),
                              ("cmake/stale", "Sources/System/CMakeLists.txt", 6)])
        finally:
            shutil.rmtree(tmp)

    def test_listed_skips_comments(self):
        self.assertEqual(sorted(check_cmake.listed(CMAKE)), ["A.swift", "Gone.swift", "Sub/C.swift"])


# ---------------------------------------------------------------- markers

class FakeCoverage:
    def __init__(self, covered):
        self.covered = covered

    def answer(self, name, plat, field=False):
        if (name, plat) in self.covered:
            return "covered", name, f"System's {name}"
        return "gap", name, "System names it nowhere"


SCAN = {"declarations": [
    {"access": "public", "scopes": [], "name": "FileDescriptor", "kw": "struct",
     "platforms": ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]},
    {"access": "public", "scopes": ["PThread"], "name": "Key", "kw": "struct",
     "platforms": ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI"]},
], "moduleUnsupportedPlatforms": {"SystemPackage": [], "SystemSockets": ["Windows"]}}

MARKED = """\
#if canImport(Glibc)
// SYSTEM-GAP: getloadavg
import Glibc
#endif
// SYSTEM-GAP: pipe2 on Linux
func f() {}
// SYSTEM-GAP: the C library, for this file's C arms
//SYSTEM-GAP: tight
/* SYSTEM-GAP: block */
// SYSTEM-GAP: PThread.Key on Windows
// SYSTEM-GAP: statfs
// The SYSTEM-GAP markers above are prose here: no colon.
"""


class MarkerTests(unittest.TestCase):
    def test_format(self):
        import status as st
        ok = ("// SYSTEM-GAP: getpid", "    // SYSTEM-GAP: members of sockaddr_storage",
              "import func Darwin.fopen  // SYSTEM-GAP: fopen")
        for line in ok:
            self.assertIsNone(check_markers.format_problem(line, st.IMPORT), line)
        bad = {"//SYSTEM-GAP: x": "spacing", "//  SYSTEM-GAP: x": "spacing", "// SYSTEM-GAP:x": "spacing",
               "/* SYSTEM-GAP: x */": "block", "/// SYSTEM-GAP: x": "doc", "// system-gap: x": "spelled",
               "// SYSTEM-GAP:": "no interface", "// TODO: SYSTEM-GAP: x": "text before",
               "let x = 1 // SYSTEM-GAP: y": "code"}
        for line, want in bad.items():
            got = check_markers.format_problem(line, st.IMPORT)
            self.assertIsNotNone(got, line)
            self.assertIn(want, got, line)

    def test_named_platforms(self):
        self.assertEqual(check_markers.named_platforms("pipe2 before macOS 27, on Linux and Android"),
                         {"Linux", "Android"})
        self.assertEqual(check_markers.named_platforms("getloadavg"), set())

    def test_clone_findings(self):
        cov = FakeCoverage({("getloadavg", p) for p in ("Linux", "FreeBSD", "OpenBSD")} | {("pipe2", "Linux")})
        got = check_markers.clone_findings("pkg", {"Sources/A.swift": MARKED}, "migrate-all", "c0ffee", cov,
                                           check_markers.SystemNames(SCAN))
        self.assertEqual(sorted(rules(got), key=lambda r: (r[1], r[0] != "markers/one-interface")), [
            ("markers/stale", 2),                 # getloadavg, over an import Glibc compiles
            ("markers/one-interface", 5), ("markers/stale", 5),   # pipe2 on Linux
            ("markers/one-interface", 7),         # prose
            ("markers/format", 8), ("markers/format", 9),
            ("markers/one-interface", 10),        # PThread.Key on Windows: prose to the parser
        ])
        stale = next(f for f in got if f.rule == "markers/stale" and f.line == 2)
        self.assertIn("FreeBSD, Linux, OpenBSD", stale.message)

    def test_system_api_names(self):
        names = check_markers.SystemNames(SCAN)
        self.assertEqual(names.mentioned("SystemSockets on FreeBSD (TCP_INFO)"), ["SystemSockets"])
        self.assertEqual(names.mentioned("PThread.Key on Windows; System's FileDescriptor"),
                         ["PThread.Key", "FileDescriptor"])
        self.assertNotIn("Windows", names.platforms("PThread.Key"))

    def test_module_platforms_are_where_it_declares(self):
        # SystemWinSocks builds everywhere, empty but on Windows.
        scan = {"declarations": SCAN["declarations"] + [
            {"access": "public", "scopes": [], "name": "SocketDescriptor", "kw": "struct",
             "module": "SystemWinSocks", "platforms": ["Windows"]},
        ], "moduleUnsupportedPlatforms": dict(SCAN["moduleUnsupportedPlatforms"], SystemWinSocks=[])}
        names = check_markers.SystemNames(scan)
        self.assertEqual(names.platforms("SystemWinSocks"), {"Windows"})
        self.assertEqual(names.mentioned("SystemWinSocks for WSAPoll"), ["SystemWinSocks"])
        self.assertEqual(len(names.platforms("SystemPackage")), 8)


# ---------------------------------------------------------------- conditionals

DIFF = """\
diff --git a/Sources/A.swift b/Sources/A.swift
--- a/Sources/A.swift
+++ b/Sources/A.swift
@@ -1,0 +2,5 @@
+#if os(Linux)
+let fd = try FileDescriptor.open(path, .readOnly)
+#else
+let fd = open(path, O_RDONLY)
+#endif
@@ -9 +14,2 @@
+#if DEBUG
+let d = open(path, O_RDONLY)
"""

COND = """\
import SystemPackage
#if os(Linux)
let fd = try FileDescriptor.open(path, .readOnly)
#else
let fd = open(path, O_RDONLY)
#endif
#if os(Linux)
let a = FileDescriptor.standardInput
#elseif os(Windows)
let b = FileDescriptor.standardInput
#endif
#if os(Linux)
let c = FileDescriptor.standardInput
#else
let e = open(path, O_RDONLY)
#endif
#if DEBUG
let d = open(path, O_RDONLY)
#else
let g = FileDescriptor.standardInput
#endif
"""


class Vocab:
    fields = set()

    def known(self, w, plat):
        return w in {"open", "O_RDONLY"}


class ConditionalTests(unittest.TestCase):
    def test_added_lines(self):
        self.assertEqual(check_conditionals.added_lines(DIFF), {"Sources/A.swift": {2, 3, 4, 5, 6, 14, 15}})

    def test_blocks(self):
        b = check_conditionals.blocks(COND.split("\n"))
        self.assertEqual(b[0], (2, [("os(Linux)", 3, 3), (None, 5, 5)]))
        self.assertEqual(len(b), 4)

    def test_mixed(self):
        got = check_conditionals.clone_findings(
            "pkg", {"Sources/A.swift": {2, 3, 4, 5, 6, 7, 17, 18}}, {"Sources/A.swift": COND}, Vocab(), set(),
            re.compile(r"\b(?:Glibc|Darwin)\.$"), set(), {"FileDescriptor", "SystemPackage"})
        # Line 2's block is mixed and new; line 7's has System in both arms; line 12's is mixed but not
        # new; line 17's isn't a platform conditional.
        self.assertEqual(rules(got), [("conditionals/mixed", 2)])
        self.assertIn("`#if os(Linux)` arm (`FileDescriptor`)", got[0].message)
        self.assertIn("`#else` arm (`O_RDONLY`, `open`)", got[0].message)

    def test_own_names_arent_system(self):
        got = check_conditionals.clone_findings(
            "pkg", {"Sources/A.swift": {2}}, {"Sources/A.swift": COND}, Vocab(), {"FileDescriptor"},
            re.compile(r"\b(?:Glibc|Darwin)\.$"), set(), {"FileDescriptor"})
        self.assertEqual(got, [])


# ---------------------------------------------------------------- pitches

def node(path, typ=False, **kw):
    return dict({"kind": "declaration", "origin": "head", "path": path, "isType": typ, "file": "F.swift"}, **kw)


GRAPH = {
    "meta": {"headCommit": "c0ffee"},
    "nodes": {
        "d:A": node("A", True), "d:A.f": node("A.f()"), "d:A.g": node("A.g(_:)"), "d:B": node("B", True),
        "d:X": dict(node("X", True), origin="base"),
    },
    "links": [
        {"kind": "memberOf", "from": "d:A.f", "to": "d:A"},
        {"kind": "memberOf", "from": "d:A.g", "to": "d:A"},
        {"kind": "usesInSignature", "from": "d:A.g", "to": "d:B"},
        {"kind": "usesInSignature", "from": "d:A.g", "to": "d:X"},
    ],
}


class FakeCtx:
    def __init__(self, repo, args):
        self.repo, self.head, self.args, self.notes = repo, "c0ffee", args, []

    def note(self, text):
        self.notes.append(text)


class Args:
    def __init__(self, **kw):
        self.__dict__.update(kw)


class PitchTests(unittest.TestCase):
    def test_pitches(self):
        import warnings
        warnings.simplefilter("ignore", ResourceWarning)   # pitches.py's load_pitches leaves files to the GC
        tmp = tempfile.mkdtemp(prefix="lint-test-")
        try:
            pdir = os.path.join(tmp, "Prototype", "Pitches")
            write(os.path.join(pdir, "p1.json"), json.dumps({
                "id": "p1", "title": "A", "pattern": "self-contained-type",
                "include": [{"types": ["A"], "members": True}]}, indent=1))
            write(os.path.join(pdir, "p2.json"), json.dumps({
                "id": "p2", "title": "f", "pattern": "constants", "requires": ["p9"],
                "include": [{"paths": ["A.f()", "Nope"]}]}, indent=1))
            write(os.path.join(pdir, "p3.json"), "{ not json")
            graph = os.path.join(tmp, "graph.json")
            write(graph, json.dumps(GRAPH))
            ctx = FakeCtx(tmp, Args(graph=graph, pitches=pdir))
            got = check_pitches.run(ctx)
            by = sorted((f.rule, os.path.basename(f.file)) for f in got)
            self.assertEqual(by, [("pitches/file", "p3.json"), ("pitches/missing", "p2.json"),
                                  ("pitches/overlap", "p1.json"), ("pitches/overlap", "p2.json"),
                                  ("pitches/prerequisite", "p1.json"), ("pitches/requires", "p2.json")])
            missing = next(f for f in got if f.rule == "pitches/missing")
            self.assertIn("`Nope` isn't a declaration in the graph", missing.message)
            self.assertEqual(missing.line, 12)    # the line naming "Nope"
            prereq = next(f for f in got if f.rule == "pitches/prerequisite")
            self.assertIn("needs `B`", prereq.message)
        finally:
            shutil.rmtree(tmp)


# ---------------------------------------------------------------- api

F_SWIFT = """\
extension Foo {
  /// Does it.
  ///
  /// The corresponding C function is `bar`.
  public func bar() throws -> Int { 1 }

  public static var baz: Foo { Foo(rawValue: _BAZ) }

  /// Qux.
  public func qux(_ x: Int) throws(Errno) { try _qux(x).get() }

  /// The corresponding C parameter of `CreateThing` is `dwFlags`.
  public var flags: Int { 0 }

  public var raw: CInterop.Thing

  public var other: CInterop.Other

  @_alwaysEmitIntoClient
  public static var fine: Foo { Foo(rawValue: _BAZ) }

  public func helper<E: Error>(_ body: () throws(E) -> Void) throws(E) { try body() }
}

extension CInterop.Other {
  /// The corresponding C field is `o_x`.
  public var x: Int { Int(o_x) }
}
"""

CONSTANTS = """\
internal var _BAZ: CInt { BAZ }
"""

SYSCALLS = """\
internal func system_qux(_ x: CInt) -> CInt { qux(x) }
internal func _qux(_ x: Int) -> Result<Void, Errno> { nothingOrErrno(system_qux(CInt(x))) }
"""


def entry(path, kind, decl, line, doc="", system="199", usr=None, scope=("@available(System 199, *)",)):
    return {"status": "added", "path": path, "title": path.split(".")[-1], "kind": kind, "decl": decl,
            "file": "Sources/System/F.swift", "line": line, "system": system, "docText": doc,
            "ownAvailability": [], "scopeAvailability": list(scope), "usr": usr or f"s:{path}", "deprecated": None}


def scanned(name, kw, line, attrs=(), modifiers=("public",), scopes=("Foo",), avail=("@available(System 199, *)",)):
    return {"file": "Sources/System/F.swift", "line": line, "kw": kw, "name": name, "attributes": list(attrs),
            "modifiers": list(modifiers), "scopes": list(scopes), "scopeKinds": ["extension"] * len(scopes),
            "access": "public", "availability": [], "scopeAvailability": list(avail), "unavailable": [],
            "underscored": False, "platforms": ["Darwin"], "signature": ""}


def symbol(usr, kind, path, frags):
    return {"identifier": {"precise": usr}, "kind": {"identifier": kind}, "pathComponents": path.split("."),
            "declarationFragments": frags}


def frag(kind, spelling, usr=None):
    f = {"kind": kind, "spelling": spelling}
    if usr:
        f["preciseIdentifier"] = usr
    return f


class ApiTests(unittest.TestCase):
    def fixture(self):
        delta = {"entries": [
            entry("Foo.bar()", "swift.method", "func bar() throws -> Int", 5,
                  doc="Does it.\n\nThe corresponding C function is `bar`."),
            entry("Foo.baz", "swift.type.property", "static var baz: Foo { get }", 7,
                  scope=("@available(System 0.0.1, *)",)),
            entry("Foo.qux(_:)", "swift.method", "func qux(_ x: Int) throws(Errno)", 10, doc="Qux."),
            entry("Foo.flags", "swift.property", "var flags: Int { get }", 13,
                  doc="The corresponding C parameter of `CreateThing` is `dwFlags`."),
            entry("Foo.raw", "swift.property", "var raw: CInterop.Thing", 15, usr="s:raw"),
            entry("Foo.other", "swift.property", "var other: CInterop.Other", 17, usr="s:other"),
            entry("Foo.fine", "swift.type.property", "static var fine: Foo { get }", 20),
            entry("Foo.helper(_:)", "swift.method", "func helper<E>(_ body: () throws(E) -> Void) throws(E) where E : Error",
                  22),
        ], "hiddenFromGraphs": {"added": []}}
        scan = {"declarations": [
            scanned("bar", "func", 5), scanned("baz", "var", 7, modifiers=("public", "static"),
                                                avail=("@available(System 0.0.1, *)",)),
            scanned("qux", "func", 10), scanned("flags", "var", 13), scanned("raw", "var", 15),
            scanned("other", "var", 17), scanned("fine", "var", 20, attrs=("@_alwaysEmitIntoClient",),
                                                  modifiers=("public", "static")),
            scanned("helper", "func", 22),
            scanned("x", "var", 28, scopes=("CInterop.Other",)),
        ]}
        source = check_api.Source(texts={"Sources/System/F.swift": F_SWIFT,
                                         "Sources/System/Internals/Constants.swift": CONSTANTS,
                                         "Sources/System/Internals/Syscalls.swift": SYSCALLS})
        graphs = check_api.Graphs(symbols=[
            symbol("s:raw", "swift.property", "Foo.raw", [frag("keyword", "var"), frag("text", " "),
                                                           frag("identifier", "raw"), frag("text", ": "),
                                                           frag("typeIdentifier", "CInterop", "s:CInterop"),
                                                           frag("text", "."),
                                                           frag("typeIdentifier", "Thing", "s:CInterop.Thing")]),
            symbol("s:other", "swift.property", "Foo.other", [frag("keyword", "var"), frag("text", ": "),
                                                               frag("typeIdentifier", "Other", "s:CInterop.Other")]),
            symbol("s:CInterop.Thing", "swift.typealias", "CInterop.Thing",
                   [frag("keyword", "typealias"), frag("text", " = "), frag("typeIdentifier", "thing", "c:@S@thing")]),
            symbol("s:CInterop.Other", "swift.typealias", "CInterop.Other",
                   [frag("keyword", "typealias"), frag("text", " = "), frag("typeIdentifier", "other", "c:@S@other")]),
        ])
        return delta, scan, source, graphs

    def test_rules(self):
        delta, scan, source, graphs = self.fixture()
        got, used = check_api.check(delta, scan, source, graphs, {})
        self.assertEqual(sorted((f.rule, f.extra["declaration"]) for f in got), [
            ("api/aeic", "Foo.baz"),
            ("api/availability", "Foo.baz"),
            ("api/c-struct-property", "Foo.raw"),
            ("api/doc-sentence", "Foo.flags"),
            ("api/doc-sentence-missing", "Foo.baz"),
            ("api/doc-sentence-missing", "Foo.fine"),
            ("api/doc-sentence-missing", "Foo.qux(_:)"),
            ("api/typed-throws", "Foo.bar()"),
        ])
        missing = next(f for f in got if f.rule == "api/doc-sentence-missing" and "qux" in f.message)
        self.assertIn("C function `qux`", missing.message)

    def test_helpers_are_per_module(self):
        # Each module has its own `_qux`; neither name is shared with the
        # other module's, so each is followed in its own module.
        other = SYSCALLS.replace("system_qux", "system_quux").replace("qux(x)", "quux(x)")
        source = check_api.Source(texts={"Sources/System/Internals/Syscalls.swift": SYSCALLS,
                                         "Sources/SystemWinSocks/Internals/WinsockSyscalls.swift": other})
        reach = check_api.Reach(source)
        self.assertEqual(reach.reach("_qux(1)", "Sources/System/F.swift"), ({"qux"}, set()))
        self.assertEqual(reach.reach("_qux(1)", "Sources/SystemWinSocks/Sockets/F.swift"), ({"quux"}, set()))
        self.assertEqual(reach.reach("_qux(1)", "Sources/SystemSockets/F.swift"), (set(), set()))

    def test_allowlist(self):
        delta, scan, source, graphs = self.fixture()
        allow = {"api/typed-throws": [("Foo.bar*", "a reason")], "api/availability": [("Foo.[b]az", "x")]}
        got, used = check_api.check(delta, scan, source, graphs, allow)
        rules_left = {f.rule for f in got}
        self.assertNotIn("api/typed-throws", rules_left)
        self.assertIn("api/availability", rules_left)   # `[` matches itself: Foo.[b]az isn't Foo.baz
        self.assertEqual(used["api/typed-throws"], 1)

    def test_load_allowlist_needs_reasons(self):
        tmp = tempfile.mkdtemp(prefix="lint-test-")
        try:
            p = os.path.join(tmp, "allow.ini")
            write(p, "[api/aeic]\nFoo.bar() = because\n")
            self.assertEqual(check_api.load_allowlist(p), {"api/aeic": [("Foo.bar()", "because")]})
            write(p, "[api/aeic]\nFoo.bar() =\n")
            with self.assertRaises(lintcore.CheckError):
                check_api.load_allowlist(p)
        finally:
            shutil.rmtree(tmp)

    def test_own_effects(self):
        self.assertEqual(check_api.own_effects("func f(_ body: () throws -> R) rethrows -> R").strip(), "rethrows")
        self.assertEqual(check_api.own_effects("init(x: Int) throws(Errno)").strip(), "throws(Errno)")
        self.assertIn("throws", check_api.own_effects("var x: Int { get throws }"))
        self.assertIsNone(check_api.own_effects("var x: Int"))
        self.assertEqual(check_api.generic_names("func f<E: Error, T>(_ x: T) throws(E)"), {"E", "T"})


if __name__ == "__main__":
    unittest.main()
