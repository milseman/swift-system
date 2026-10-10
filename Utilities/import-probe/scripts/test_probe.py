#!/usr/bin/env python3
"""Tests of import-probe's pieces over text fixtures: removing imports in
each form (strip.py), reading diagnostics and telling follow-ons apart
(diags.py), the manifests' dependencies and rewrites, version choice and
System's manifest without Samples (manifests.py), and the comparison with a
ledger (summary.py). One test makes a git repository in a temporary
directory (no global or system git configuration, so no hooks, signing or
credential helpers run) as a stand-in for SwiftPM's cache, and deletes it;
nothing else is written, nothing is built, and nothing reaches the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diags  # noqa: E402
import manifests  # noqa: E402
import strip  # noqa: E402
import summary  # noqa: E402

C_MODULES = {"Darwin", "Glibc", "Musl", "WinSDK", "ucrt", "MachO", "string_h"}


def remove(m):
    return m in C_MODULES


SOURCE = """\
//===----------------------------------------------------------------------===//
// import Darwin   (a comment: not an import)
import SystemPackage
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif os(Windows)
@_implementationOnly import WinSDK  // for HANDLE
import ucrt;
#endif
public import Foundation
import func Darwin.fopen
internal import struct Darwin.stat
@_exported @preconcurrency import Musl
@preconcurrency
import MachO
import Darwin.C
import string_h
let s = "import Glibc"
"""


class StripTests(unittest.TestCase):
    def test_every_form_is_removed_and_lines_stay(self):
        new, removed = strip.strip(SOURCE, remove)
        self.assertEqual(len(new.split("\n")), len(SOURCE.split("\n")))
        self.assertEqual([r["line"] for r in removed], [5, 7, 9, 10, 13, 14, 15, 17, 18, 19])
        self.assertEqual([r["module"] for r in removed],
                         ["Darwin", "Glibc", "WinSDK", "ucrt", "Darwin", "Darwin", "Musl", "MachO", "Darwin",
                          "string_h"])
        self.assertEqual(removed[4]["scoped"], "fopen")
        self.assertEqual(removed[5]["scoped"], "stat")
        self.assertTrue(removed[6]["exported"])
        self.assertFalse(removed[0]["exported"])
        lines = new.split("\n")
        self.assertEqual(lines[2], "import SystemPackage")
        self.assertEqual(lines[11], "public import Foundation")
        self.assertTrue(lines[4].startswith(strip.MARK))
        # The attribute line above `import MachO` goes with it.
        self.assertTrue(lines[15].startswith(strip.MARK + "@preconcurrency"))
        self.assertIn("#if canImport(Darwin)", lines[3])
        self.assertEqual(lines[19], 'let s = "import Glibc"')
        self.assertEqual(lines[1], "// import Darwin   (a comment: not an import)")

    def test_imports_lists_every_import(self):
        found = strip.imports(SOURCE)
        self.assertIn((3, "SystemPackage", None, "import SystemPackage"), found)
        self.assertIn(12, [line for line, *_ in found])

    def test_extra_modules_are_removed(self):
        class Mods:
            def group(self, m):
                return "count" if m == "Glibc" else None
        should = strip.module_matcher(Mods(), ["TSCLibc"])
        new, removed = strip.strip("import TSCLibc\nimport TSCBasic\nimport Glibc\n", should)
        self.assertEqual([r["module"] for r in removed], ["TSCLibc", "Glibc"])
        self.assertIn("import TSCBasic", new)


LOG = """\
[1/9] Compiling Probe A.swift
/w/src/pkg/Sources/Probe/A.swift:5:13: error: cannot find 'getpid' in scope
  3 |
  4 | func a() -> Int {
  5 |   let pid = getpid()
    |             `- error: cannot find 'getpid' in scope
/w/src/pkg/Sources/Probe/A.swift:5:13: error: cannot find 'getpid' in scope
/w/src/pkg/Sources/Probe/A.swift:9:11: error: cannot find 'Glibc' in scope
/w/src/pkg/Sources/Probe/A.swift:14:11: error: cannot find type 'stat' in scope
/w/src/pkg/Sources/Probe/A.swift:16:5: error: cannot convert value of type 'Int' to expected argument type 'Int32'
/w/src/pkg/Sources/Probe/A.swift:20:16: error: property 'st_size' is not available due to missing import of defining module 'Glibc' [#MemberImportVisibility]
/w/src/pkg/Sources/Probe/A.swift:24:3: error: generic parameter 'T' could not be inferred
/w/src/pkg/Sources/Probe/A.swift:26:3: error: cannot convert value of type '<<error type>>' to 'Int'
/w/src/pkg/Sources/Probe/A.swift:27:9: warning: variable 'x' was never used
/w/deps/swift-system/Sources/System/X.swift:1:1: error: not ours
error: emit-module command failed with exit code 1 (use -v to see invocation)
/code/src/pkg/Sources/Probe/B.swift:2:1: error: no such module 'CNIOLinux'
/w/src/pkg/Sources/Probe/A.swift:28:20: error: value of type 'CInterop.Stat' has no member 'st_birthtime'
"""

CODE = """\
import SystemPackage

func a() -> Int {
  let pid = getpid()
  return Int(pid)
}

func q() {
  _ = Glibc.exit(1)
}

struct Holder {
  var st: stat
  func f(_ x: Int) -> Int {
    let y = x
    g(y)
    return 0
  }
}

func h(_ s: CInterop.Stat) -> Int { Int(s.st_size) }

func other() {
  takesAny()
  // two lines below
  let z: Int = undefinedThing
  _ = z
  _ = s.st_birthtime
}
"""


class DiagnosticTests(unittest.TestCase):
    def test_parse_keeps_located_errors_once_under_the_roots(self):
        ds = diags.parse(LOG, ["/w/src/pkg", "/code/src/pkg"])
        self.assertEqual([(d["file"], d["line"]) for d in ds],
                         [("Sources/Probe/A.swift", 5), ("Sources/Probe/A.swift", 9), ("Sources/Probe/A.swift", 14),
                          ("Sources/Probe/A.swift", 16), ("Sources/Probe/A.swift", 20),
                          ("Sources/Probe/A.swift", 24), ("Sources/Probe/A.swift", 26),
                          ("Sources/Probe/B.swift", 2), ("Sources/Probe/A.swift", 28)])
        self.assertEqual(ds[4]["message"],
                         "property 'st_size' is not available due to missing import of defining module 'Glibc'")

    def test_primary_kinds(self):
        self.assertEqual(diags.primary("cannot find 'getpid' in scope"), ("value", "getpid", {}))
        self.assertEqual(diags.primary("cannot find type 'stat' in scope")[:2], ("type", "stat"))
        k, n, d = diags.primary("instance method 'withMemoryRebound(to:capacity:_:)' is not available due to missing "
                                "import of defining module 'Darwin'")
        self.assertEqual((k, n, d["module"], d["what"]), ("member", "withMemoryRebound", "Darwin", "instance method"))
        self.assertEqual(diags.primary("value of type 'stat' has no member 'st_birthtime'")[:2],
                         ("member", "st_birthtime"))
        self.assertEqual(diags.primary("no such module 'CNIOLinux'")[:2], ("module", "CNIOLinux"))
        self.assertIsNone(diags.primary("generic parameter 'T' could not be inferred"))

    def test_qualified_name(self):
        self.assertEqual(diags.qualified_name("  _ = Glibc.exit(1)", 7, "Glibc"), "exit")
        self.assertEqual(diags.qualified_name("let a = Darwin.stat()", 9, "Darwin"), "stat")
        self.assertIsNone(diags.qualified_name("nothing here", 1, "Glibc"))

    def test_follow_ons(self):
        lines = CODE.split("\n")
        found = [
            {"file": "A.swift", "line": 4, "col": 13, "message": "cannot find 'getpid' in scope"},
            {"file": "A.swift", "line": 13, "col": 11, "message": "cannot find type 'stat' in scope"},
            {"file": "A.swift", "line": 5, "col": 3, "message": "cannot convert value of type 'Int' to 'Int32'"},
            {"file": "A.swift", "line": 24, "col": 3, "message": "generic parameter 'T' could not be inferred"},
            {"file": "A.swift", "line": 26, "col": 3, "message": "cannot convert '<<error type>>' to 'Int'"},
            {"file": "A.swift", "line": 16, "col": 5, "message": "ambiguous use of 'g'"},
        ]
        prim, follow, other = diags.split(found, lambda f: lines)
        self.assertEqual([p[2] for p in prim], ["getpid", "stat"])
        # Line 5 is in a()'s body with getpid's error; line 26 has an error type.
        self.assertEqual(sorted(d["line"] for d in follow), [5, 26])
        # Line 16 is in f(_:), a declaration of its own inside Holder: not stat's.
        self.assertEqual(sorted(d["line"] for d in other), [16, 24])

    def test_decl_range(self):
        lines = CODE.split("\n")
        self.assertEqual(diags.decl_range(lines, 4), (3, 6))
        self.assertEqual(diags.decl_range(lines, 13), (13, 13))
        self.assertEqual(diags.decl_range(lines, 16), (14, 18))
        self.assertEqual(diags.decl_range(lines, 21), (21, 21))


MANIFEST = """\
// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "swift-nio",
    dependencies: [],
    targets: []
)

if Context.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.1.0")),
        .package(path: "../../swift-system"),
        // .package(url: "https://example.com/commented-out.git", from: "1.0.0"),
    ]
} else {
    package.dependencies += [
        .package(path: "../swift-atomics"),
        .package(name: "swift-collections", path: "../swift-collections"),
    ]
}
"""

SYSTEM_MANIFEST = """\
let package = Package(
  name: "swift-system",
  products: [
    .library(name: "SystemPackage", targets: ["SystemPackage"]),
    .executable(name: "system-samples", targets: ["Samples"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
  ],
  targets: [
    .target(name: "SystemPackage", path: "Sources/System"),
    .executableTarget(
      name: "Samples",
      dependencies: [
        "SystemPackage",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
    .testTarget(name: "SystemTests", dependencies: ["SystemPackage"]),
  ]
)
"""


class ManifestTests(unittest.TestCase):
    def test_dependencies(self):
        ds = manifests.dependencies(MANIFEST)
        self.assertEqual([(d["kind"], d["identity"]) for d in ds],
                         [("url", "swift-atomics"), ("url", "swift-collections"), ("path", "swift-system"),
                          ("path", "swift-atomics"), ("path", "swift-collections")])
        self.assertEqual(ds[0]["requirement"], 'from: "1.1.0"')
        self.assertEqual(ds[1]["requirement"], '.upToNextMinor(from: "1.1.0")')

    def test_rewrite(self):
        new, done = manifests.rewrite(MANIFEST, {"swift-system": "../../deps/swift-system",
                                                 "swift-atomics": "../../deps/swift-atomics"})
        self.assertIn('.package(path: "../../deps/swift-system")', new)
        self.assertEqual(new.count('.package(path: "../../deps/swift-atomics")'), 2)
        self.assertIn('.package(url: "https://github.com/apple/swift-collections.git"', new)
        self.assertIn("// .package(url: \"https://example.com/commented-out.git\"", new)
        self.assertEqual(len(done), 3)

    def test_requirements(self):
        f = manifests.allowed('from: "1.1.0"')
        self.assertTrue(f((1, 3, 1)) and not f((2, 0, 0)) and not f((1, 0, 9)))
        f = manifests.allowed('.upToNextMinor(from: "1.1.0")')
        self.assertTrue(f((1, 1, 5)) and not f((1, 2, 0)))
        f = manifests.allowed('"1.0.0"..<"1.5.0"')
        self.assertTrue(f((1, 4, 9)) and not f((1, 5, 0)))
        f = manifests.allowed('exact: "2.3.4"')
        self.assertTrue(f((2, 3, 4)) and not f((2, 3, 5)))
        self.assertEqual(manifests.allowed('branch: "main"'), "main")
        self.assertIsNone(manifests.allowed("something(else)"))

    def test_drop_samples(self):
        out = manifests.drop_samples(SYSTEM_MANIFEST)
        self.assertNotIn("Samples", out)
        self.assertNotIn("argument-parser", out)
        self.assertIn('.testTarget(name: "SystemTests"', out)
        self.assertIn(".library(name: \"SystemPackage\"", out)

    def test_traits_are_not_the_requirement(self):
        text = """
        dependencies: [
            // Disable all traits to prevent linking Foundation
            .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: []),
            .package(url: "https://github.com/apple/swift-x.git", "1.0.0"..<"2.0.0",
                     traits: [.defaults, .trait(name: "A", condition: .when(traits: ["B"]))]),  // a, b
            .package(path: "../local" /* a, b */, traits: ["T"]),
            .package(name: "swift-collections", path: "../swift-collections"),
        ]
        """
        ds = manifests.dependencies(text)
        self.assertEqual([(d["identity"], d["requirement"], d["traits"]) for d in ds],
                         [("swift-configuration", 'from: "1.0.0"', "[]"),
                          ("swift-x", '"1.0.0"..<"2.0.0"', '[.defaults, .trait(name: "A", condition: .when(traits: ["B"]))]'),
                          ("local", "", '["T"]'), ("swift-collections", "", None)])
        self.assertTrue(manifests.allowed(ds[0]["requirement"])((1, 4, 0)))
        # The text F8 couldn't read.
        f = manifests.allowed('from: "1.0.0", traits: []')
        self.assertTrue(f((1, 0, 0)) and not f((2, 0, 0)))
        new, done = manifests.rewrite(text, {"swift-configuration": "../../deps/swift-configuration",
                                             "swift-x": "../../deps/swift-x", "local": "../../deps/local"})
        self.assertIn('.package(path: "../../deps/swift-configuration", traits: []),', new)
        self.assertIn('.package(path: "../../deps/swift-x", traits: [.defaults, .trait(name: "A", '
                      'condition: .when(traits: ["B"]))]),  // a, b', new)
        self.assertIn('.package(path: "../../deps/local", traits: ["T"])', new)
        self.assertIn('.package(name: "swift-collections", path: "../swift-collections")', new)
        self.assertIn("// Disable all traits", new)
        self.assertEqual(len(done), 3)

    def test_arguments(self):
        call = '.package(url: "https://a/b,c.git", // x, y\n  .upToNextMinor(from: "1.2.0"), traits: [.x(y: [1, 2])])'
        self.assertEqual(manifests.arguments(call),
                         [("url", '"https://a/b,c.git"'), (None, '.upToNextMinor(from: "1.2.0")'),
                          ("traits", "[.x(y: [1, 2])]")])
        self.assertEqual(manifests.arguments('.package(path: """\nx\n""")'), [("path", '"""\nx\n"""')])

    def test_choose_from_a_cache(self):
        tmp = tempfile.mkdtemp(prefix="import-probe-test-")
        try:
            repo = os.path.join(tmp, "cache", "swift-atomics-1234")
            os.makedirs(repo)
            env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_AUTHOR_NAME="t",
                       GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t",
                       GIT_COMMITTER_EMAIL="t@example.invalid")

            def g(*a):
                return subprocess.run(["git", "-C", repo, *a], env=env, check=True, capture_output=True,
                                      text=True).stdout.strip()
            g("init", "-q")
            g("config", "remote.origin.url", "https://github.com/apple/swift-atomics")
            for v in ("1.0.0", "1.2.0", "2.0.0"):
                with open(os.path.join(repo, "V"), "w") as f:
                    f.write(v)
                g("add", "V")
                g("commit", "-q", "--no-verify", "-m", v)
                g("tag", v)
            clone, rev, tag = manifests.choose("https://github.com/apple/swift-atomics.git", 'from: "1.1.0"',
                                               cache=os.path.join(tmp, "cache"))
            self.assertEqual((clone, tag), (repo, "1.2.0"))
            self.assertEqual(rev, g("rev-parse", "1.2.0^{commit}"))
            pinned = g("rev-parse", "1.0.0^{commit}")
            self.assertEqual(manifests.choose("https://github.com/apple/swift-atomics", "", pin=pinned,
                                              cache=os.path.join(tmp, "cache"))[1], pinned)
            with self.assertRaises(LookupError):
                manifests.choose("https://github.com/apple/swift-atomics", 'from: "3.0.0"',
                                 cache=os.path.join(tmp, "cache"))
            with self.assertRaises(LookupError):
                manifests.choose("https://github.com/apple/swift-numerics", 'from: "1.0.0"',
                                 cache=os.path.join(tmp, "cache"))
        finally:
            shutil.rmtree(tmp)


def result_fixture():
    return {
        "meta": {"package": "pkg", "platformName": "Linux", "commit": "c0ffee", "platform": "linux"},
        "files": {"Sources/A/a.swift": "A", "Sources/A/b.swift": "A", "Sources/A/c.swift": "A",
                  "Sources/A/d.swift": "A"},
        "targets": [{"name": "A", "status": "probed", "removed": [
            {"file": "Sources/A/a.swift", "line": 3, "module": "Glibc", "text": "import Glibc", "active": True,
             "exported": False},
            {"file": "Sources/A/b.swift", "line": 4, "module": "Glibc", "text": "import Glibc", "active": True,
             "exported": False},
            {"file": "Sources/A/c.swift", "line": 5, "module": "Glibc", "text": "import Glibc", "active": False,
             "exported": False},
            {"file": "Sources/A/d.swift", "line": 6, "module": "Glibc", "text": "import Glibc", "active": True,
             "exported": False},
        ]}],
        "records": [
            {"file": "Sources/A/a.swift", "name": "getpid", "class": "covered"},
            {"file": "Sources/A/a.swift", "name": "st_size", "class": "covered"},
            {"file": "Sources/A/a.swift", "name": "TCP_INFO", "class": "gap"},
        ],
    }


LEDGER = {
    "read": [{"repository": "pkg", "commit": "c0ffee"}],
    "sites": [
        {"repository": "pkg", "file": "Sources/A/a.swift", "line": 3, "type": "import", "module": "Glibc",
         "platforms": {"Linux": "T"}, "names": {"getpid": {"Linux": [9]}, "TCP_INFO": {"Linux": [10]},
                                                 "usleep": {"Linux": [11]}},
         "answers": {"getpid": {"Linux": ["covered", "getpid", ""]},
                     "TCP_INFO": {"Linux": ["covered", "TCP_INFO", ""]}}},
        {"repository": "pkg", "file": "Sources/A/b.swift", "line": 4, "type": "import", "module": "Glibc",
         "platforms": {"Linux": "T"}, "names": {}},
        {"repository": "pkg", "file": "Sources/A/c.swift", "line": 5, "type": "import", "module": "Glibc",
         "platforms": {"Linux": "M"}, "names": {}},
        {"repository": "pkg", "file": "Benchmarks/x.swift", "line": 1, "type": "import", "module": "Glibc",
         "platforms": {"Linux": "T"}, "names": {}},
        {"repository": "pkg", "file": "Sources/A/a.swift", "line": 1, "type": "marker",
         "platforms": {"Linux": "T"}, "names": {}},
        {"repository": "pkg", "file": "Sources/A/w.swift", "line": 1, "type": "import", "module": "WinSDK",
         "platforms": {"Windows": "T"}, "names": {}},
        {"repository": "other", "file": "Sources/A/a.swift", "line": 3, "type": "import", "module": "Glibc",
         "platforms": {"Linux": "T"}, "names": {}},
    ],
}


class LedgerComparisonTests(unittest.TestCase):
    def test_compare(self):
        cmp = summary.ledger_compare(result_fixture(), LEDGER)
        self.assertTrue(cmp["sameCommit"])
        self.assertEqual(cmp["ledgerImports"], 4)
        self.assertEqual(cmp["ledgerMarkers"], 1)
        self.assertEqual(cmp["matched"], 2)
        self.assertEqual([s["file"] for s in cmp["outsideTargets"]], ["Benchmarks/x.swift"])
        self.assertEqual([s["file"] for s in cmp["inactiveForProbe"]], ["Sources/A/c.swift"])
        self.assertEqual([s["file"] for s in cmp["probeOnlyImports"]], ["Sources/A/d.swift"])
        a = next(f for f in cmp["files"] if f["file"] == "Sources/A/a.swift")
        self.assertEqual(a["both"], ["TCP_INFO", "getpid"])
        self.assertEqual(a["ledgerOnly"], ["usleep"])
        self.assertEqual(a["probeOnly"], ["st_size"])
        self.assertEqual(a["classDisagrees"], ["TCP_INFO"])
        b = next(f for f in cmp["files"] if f["file"] == "Sources/A/b.swift")
        self.assertTrue(b["removable"])
        self.assertEqual(b["otherPlatforms"], [])
        self.assertFalse(a["removable"])
        self.assertEqual(cmp["unexplained"], {})
        self.assertFalse(cmp["probeOnlyImports"][0]["shim"])

    def test_a_reexport_serves_its_module(self):
        r = result_fixture()
        r["targets"][0]["removed"][1]["exported"] = True
        r["records"].append({"file": "Sources/A/c.swift", "name": "sockaddr", "class": "covered"})
        cmp = summary.ledger_compare(r, LEDGER)
        b = next(f for f in cmp["files"] if f["file"] == "Sources/A/b.swift")
        self.assertEqual(b["probeOnly"], ["sockaddr"])
        self.assertFalse(b["removable"])
        # Without the re-export, c.swift's name is no removed import's.
        r["targets"][0]["removed"][1]["exported"] = False
        self.assertEqual(summary.ledger_compare(r, LEDGER)["unexplained"], {"A": ["sockaddr"]})

    def test_reaching_through_a_reexport_isnt_removable(self):
        r = result_fixture()
        r["reachesThrough"] = {"A": ["NIOPosix"]}
        b = next(f for f in summary.ledger_compare(r, LEDGER)["files"] if f["file"] == "Sources/A/b.swift")
        self.assertFalse(b["removable"])
        self.assertEqual(b["through"], ["NIOPosix"])

    def test_another_commit_is_flagged(self):
        led = dict(LEDGER, read=[{"repository": "pkg", "commit": "beef"}])
        self.assertFalse(summary.ledger_compare(result_fixture(), led)["sameCommit"])

    def test_a_nested_package_takes_its_directorys_sites(self):
        r = result_fixture()
        r["meta"]["nested"] = "Examples/Tool"
        led = {"read": LEDGER["read"], "sites": [dict(s, file="Examples/Tool/" + s["file"]) for s in LEDGER["sites"]]
               + [dict(LEDGER["sites"][0], file="Sources/A/a.swift")]}
        cmp = summary.ledger_compare(r, led)
        self.assertEqual(cmp["matched"], 2)
        self.assertEqual([s["file"] for s in cmp["outsideTargets"]], ["Benchmarks/x.swift"])
        self.assertEqual(cmp["ledgerImports"], 4)


class SummaryTests(unittest.TestCase):
    """SUMMARY.md's sections for --own-modules and --reexport, written into
    a temporary directory and deleted."""

    def test_sections(self):
        tmp = tempfile.mkdtemp(prefix="import-probe-test-")
        try:
            r = result_fixture()
            r["meta"].update(platformName="Linux", platform="linux", branch="b", system="5ys", date="d", seconds=1,
                             tool="t", clone="/c/pkg", nested="Examples/Tool")
            r.update(followOns=[], others=[], outside=[], baseline=None, reexporters={}, reachesThrough={})
            for x in r["records"]:
                x.update(how="", unit=x["name"])
            r["ownModules"] = {"modules": ["CShim"], "ownNames": {"Sources/A/a.swift": ["shim_answer"]},
                               "records": [{"file": "Sources/A/b.swift", "name": "getpid", "via": ["CShim"],
                                            "class": "covered", "how": "ProcessID.current"}] * 2,
                               "targets": [{"name": "A", "files": ["Sources/A/b.swift"], "through": 2, "ownNames": 1,
                                            "withoutModules": {"exit": 1, "seconds": 1},
                                            "withLibrary": {"exit": 1, "seconds": 1}}]}
            x = {"meta": dict(r["meta"], run="reexport"), "baseline": {"exit": 0, "errors": 0, "seconds": 2},
                 "demoted": [{"file": "deps/dep/Sources/Re/S.swift", "line": 3, "text": "@_exported import Glibc",
                              "active": True},
                             {"file": "deps/dep/Sources/Re/S.swift", "line": 5, "text": "@_exported import ucrt",
                              "active": False}],
                 "fixups": {"module": ["deps/dep/Sources/Re/T.swift"], "own": ["src/pkg/Sources/A/a.swift"],
                            "dependencies": []},
                 "rounds": [{"round": 1, "exit": 1, "names": 1, "targets": ["A"], "dependencyFiles": [], "seconds": 3},
                            {"round": 2, "exit": 0, "names": 0, "targets": [], "dependencyFiles": [], "seconds": 1}],
                 "records": [{"file": "Sources/A/a.swift", "line": 9, "column": 3, "name": "exit", "kind": "value",
                              "class": "covered", "how": "ProcessID.exit"}],
                 "followOns": [], "others": [], "residual": []}
            for name, doc in (("linux.json", r), ("linux-reexport.json", x)):
                with open(os.path.join(tmp, name), "w") as f:
                    json.dump(doc, f)
            with open(summary.write(tmp)) as f:
                text = f.read()
            self.assertIn("# import-probe: pkg, nested package `Examples/Tool`", text)
            self.assertIn("### Names through the package's own C modules (Linux, `--own-modules`)", text)
            self.assertIn("| `Sources/A/b.swift` | `CShim` | `getpid` ×2 |", text)
            self.assertIn("## Linux (linux): names only a re-export gives (`--reexport`)", text)
            self.assertIn("`deps/dep/Sources/Re/S.swift:3` (`@_exported import Glibc`); 1 re-export Linux doesn't "
                          "compile.", text)
            self.assertIn("| `Sources/A/a.swift` | 9 | `exit` | value | System covers it | ProcessID.exit |", text)
            # The flat file has the per-target probe's records only.
            with open(os.path.join(tmp, "import-probe.json")) as f:
                self.assertEqual(len(json.load(f)), 3)
        finally:
            shutil.rmtree(tmp)


class ReexportTextTests(unittest.TestCase):
    """reexport.py's demotion over files in a temporary directory, deleted
    after; nothing is built."""

    SOURCE = ("// @_exported import Glibc (a comment)\n"
              "#if canImport(Glibc)\n"
              "@_exported @preconcurrency import Glibc\n"
              "#elseif canImport(Darwin)\n"
              "@_exported\n"
              "import Darwin.C\n"
              "#elseif os(Windows)\n"
              "@_exported import ucrt\n"
              "#endif\n"
              "@_exported import NIOCore\n"
              "let s = \"@_exported import Glibc\"\n")

    def test_find_demote_and_fix_up(self):
        import reexport
        import platforms  # adopter-coverage's, on the path once reexport has imported probe
        tmp = tempfile.mkdtemp(prefix="import-probe-test-")
        try:
            path = os.path.join(tmp, "deps", "dep", "Sources", "Re", "System.swift")
            os.makedirs(os.path.dirname(path))
            with open(path, "w") as f:
                f.write(self.SOURCE)
            sites = reexport.find_reexports(tmp, lambda m: m in C_MODULES, "linux", platforms.model())
            self.assertEqual([(s["line"], s["import"], s["active"]) for s in sites],
                             [(3, "Glibc", True), (6, "Darwin.C", False), (8, "ucrt", False)])
            self.assertEqual(sites[0]["attrs"], "@preconcurrency")
            reexport.demote(tmp, sites)
            with open(path) as f:
                lines = f.read().split("\n")
            self.assertEqual(len(lines), len(self.SOURCE.split("\n")))
            self.assertEqual(lines[2], "@preconcurrency import Glibc")
            self.assertEqual(lines[4], "")
            self.assertEqual(lines[7], "import ucrt")
            self.assertEqual(lines[9], "@_exported import NIOCore")
            self.assertEqual(lines[0], "// @_exported import Glibc (a comment)")
            self.assertEqual(reexport.fixup_block(sites),
                             f"#if canImport(Glibc)\n@preconcurrency import Glibc {reexport.FIXUP_NOTE}\n#endif")
            mac = reexport.find_reexports(tmp, lambda m: m in C_MODULES, "macos", platforms.model())
            self.assertEqual(mac, [])
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
