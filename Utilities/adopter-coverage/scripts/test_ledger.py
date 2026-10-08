#!/usr/bin/env python3
"""Tests of the ledger of sites left (ledger.py) and of section 3's read of
markers at the newest migration branch (status.py): modules.ini's groups,
exceptions.ini's entries, each category and an unexplained site, the order
they decide in, System's answers, the gap ranking and the floor, all from
text fixtures. Two tests make a git repository of their own in a temporary
directory (with no global or system git configuration, so no hooks, signing
or credential helpers run) and delete it; nothing else is written, and
nothing reaches the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/adopter-coverage/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402
import ecosystem  # noqa: E402
import ledger  # noqa: E402
import status  # noqa: E402

MODULES = """
[count]
modules = Darwin Glibc Musl Android WASILibc WinSDK ucrt MachO unistd
patterns = *_h

[report]
modules = os XPC

[not System's]
modules = Dispatch SQLite3
"""

ENTRIES = """
[X1]
kind = exception
title = the standard library
reason = below System
decided = Michael, 2026-10-05
repositories = swift
paths = stdlib/*

[X2]
kind = excluded
title = test data
repositories = pkg
paths = Fixtures/*

[X3]
kind = undecided
title = an undecided repository
repositories = corelibs

[X4]
kind = queued
work = System
title = threads on WASI without threads
where = a report
names = pthread_*
platforms = WASI

[X5]
kind = gap
title = Mach-O
mapping = Mach-O file format

[X6]
kind = queued
work = adopter
title = a re-export
where = a report
repositories = pkg
paths = Sources/PkgLibc/*
platforms = Linux FreeBSD

[X7]
kind = queued
work = System
title = holds nothing
where = a report
platforms = Linux
"""

MAPPING = """
[config]

[fsync]
category = file I/O

[statfs]
symbols = statfs fstatfs
category = file system

[malloc]
symbols = malloc free
category = memory
swift = UnsafeMutableRawPointer.allocate(byteCount:alignment:)

[SQLite]
symbols = sqlite3_open
category = C libraries
wrap = no
note = A database library.

[Mach-O file format]
symbols = mach_header
category = dynamic loading
wrap = no
note = A file format.

[standard descriptors]
symbols = STDIN_FILENO
category = file I/O
status = covered
system = FileDescriptor: static var standardInput: FileDescriptor
"""


def decl(scope, name, signature, platforms, line, conditions=()):
    return {"file": "Sources/System/A.swift", "line": line, "module": "SystemPackage", "access": "public",
            "scopes": [scope] if scope else [], "name": name, "kw": signature.split()[1] if signature.startswith(
                "public ") else signature.split()[0], "signature": signature, "platforms": list(platforms),
            "availability": [], "unavailable": [], "conditions": list(conditions)}


SCAN = {"declarations": [
    decl("FileDescriptor", "synchronize(retryOnInterrupt:)", "public func synchronize(retryOnInterrupt: Bool = true) throws",
         ("Darwin", "Linux", "WASI"), 10),
    decl("FileDescriptor", "standardInput", "public static var standardInput: FileDescriptor",
         ("Darwin", "Linux", "Windows"), 20),
    decl("PThread", "Mutex", "public struct Mutex", ("Darwin", "Linux", "WASI"), 30, ["_runtime(_multithreaded)"]),
]}


def derived_decl(scan_decl, restricted=False):
    return {"scope": scan_decl["scopes"][0] if scan_decl["scopes"] else "", "file": scan_decl["file"],
            "line": scan_decl["line"], "platforms": scan_decl["platforms"], "restricted": restricted,
            "declaration": check.normalize_decl(scan_decl["signature"]), "availability": {}}


DERIVED = {
    "names": {
        "fsync": {"platforms": ["Darwin", "Linux", "WASI"], "partialPlatforms": [], "kinds": ["function"],
                  "declarations": [derived_decl(SCAN["declarations"][0])]},
        "pthread_mutex_lock": {"platforms": ["Darwin", "Linux", "WASI"], "partialPlatforms": [],
                               "kinds": ["function"], "declarations": [derived_decl(SCAN["declarations"][2])]},
    },
    "implementation": {"statfs": ["Linux"]},
    "fieldPlatforms": {"st_mode": ["Darwin", "Linux"]},
}


def coverage():
    cfg, entries = mapping()
    return ledger.Coverage(SCAN, DERIVED, entries)


def mapping():
    d = tempfile.mkdtemp(prefix="ledger-test-")
    try:
        path = os.path.join(d, "mapping.ini")
        with open(path, "w") as f:
            f.write(MAPPING)
        cfg, entries, problems = check.load_mapping(path)
    finally:
        shutil.rmtree(d)
    assert not problems, problems
    return cfg, entries


def site(repository="pkg", file="Sources/Pkg/A.swift", line=3, module="Glibc", group="count", platforms=None,
         names=None, kind="import", markers=None, only_under=()):
    plats = platforms if platforms is not None else {"Linux": "T"}
    return {"repository": repository, "file": file, "line": line, "type": kind, "kind": "library",
            "module": module if kind == "import" else None, "group": group,
            "importKind": "whole" if kind == "import" else None, "exported": False, "text": f"import {module}",
            "platforms": plats, "onlyUnder": list(only_under), "names": names or {}, "markers": markers or []}


def uses(*names, platforms=("Linux",)):
    return {n: {p: [5] for p in platforms} for n in names}


class ModulesTests(unittest.TestCase):
    def setUp(self):
        self.modules = ledger.Modules(MODULES)

    def test_groups_names_and_patterns(self):
        self.assertEqual(self.modules.group("Glibc"), "count")
        self.assertEqual(self.modules.group("stdlib_h"), "count")   # by the *_h pattern
        self.assertEqual(self.modules.group("os"), "report")
        self.assertEqual(self.modules.group("Dispatch"), "not System's")
        self.assertIsNone(self.modules.group("Foundation"))
        self.assertIsNone(self.modules.group("os_log"))   # names match whole, not as prefixes

    def test_import_pattern(self):
        pattern = ecosystem.import_of(self.modules.alternatives(("count",)))
        for line, module in (("import Glibc", "Glibc"), ("@preconcurrency import stdlib_h", "stdlib_h"),
                             ("internal import unistd", "unistd"), ("import struct MachO.mach_header", "MachO"),
                             ("import func Darwin.usleep", "Darwin")):
            m = pattern.match(line)
            self.assertIsNotNone(m, line)
            self.assertEqual(m.group(1), module)
        for line in ("import Foundation", "import DarwinPrivate", "import os", "import Dispatch"):
            self.assertIsNone(pattern.match(line), line)

    def test_rejects_unknown_sections_and_keys(self):
        with self.assertRaises(ValueError):
            ledger.Modules(MODULES + "\n[other]\nmodules = X\n")
        with self.assertRaises(ValueError):
            ledger.Modules(MODULES.replace("patterns = *_h", "pattern = *_h"))


class EntryTests(unittest.TestCase):
    def test_parse(self):
        es = {e.id: e for e in ledger.load_entries(ENTRIES)}
        self.assertEqual(es["X1"].kind, "exception")
        self.assertEqual(es["X1"].decided, "Michael, 2026-10-05")
        self.assertEqual(es["X5"].rules["mapping"], ["Mach-O file format"])   # one id per line, spaces kept
        self.assertTrue(es["X4"].by_name)
        self.assertFalse(es["X6"].by_name)
        self.assertFalse(es["X7"].matches_anything)   # platforms alone match nothing

    def test_validation(self):
        with self.assertRaises(ValueError):   # an exception needs who approved it
            ledger.load_entries("[E]\nkind = exception\ntitle = t\nrepositories = r\n")
        with self.assertRaises(ValueError):   # queued work needs where
            ledger.load_entries("[Q]\nkind = queued\ntitle = t\nnames = x\n")
        with self.assertRaises(ValueError):
            ledger.load_entries("[G]\nkind = gap\ntitle = t\nnames = x\nplace = y\n")
        with self.assertRaises(ValueError):
            ledger.load_entries("[G]\nkind = gap\ntitle = t\nnames = x\nplatforms = Plan9\n")
        with self.assertRaises(ValueError):
            ledger.load_entries("[G]\nkind = gap\ntitle = t\nonly-under = DEBUG\n")


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.cov = coverage()

    def test_covered_where_built(self):
        kind, unit, how = self.cov.answer("fsync", "Linux")
        self.assertEqual((kind, unit), ("covered", "[fsync]"))
        self.assertIn("FileDescriptor.synchronize", how)

    def test_gap_elsewhere_and_nowhere(self):
        kind, unit, how = self.cov.answer("fsync", "Windows")
        self.assertEqual((kind, unit), ("gap", "[fsync]"))
        self.assertIn("isn't built on Windows", how)
        kind, unit, how = self.cov.answer("getloadavg", "Linux")
        self.assertEqual((kind, unit, how), ("gap", "getloadavg", "System names it nowhere"))
        kind, unit, how = self.cov.answer("statfs", "Linux")
        self.assertEqual((kind, unit), ("gap", "[statfs]"))
        self.assertIn("implementation", how)

    def test_wasi_is_without_threads(self):
        self.assertEqual(self.cov.answer("pthread_mutex_lock", "Linux")[0], "covered")
        self.assertEqual(self.cov.answer("pthread_mutex_lock", "WASI")[0], "gap")

    def test_mapping_answers(self):
        self.assertEqual(self.cov.answer("malloc", "Linux")[0], "standard library")
        self.assertEqual(self.cov.answer("sqlite3_open", "Linux")[:2], ("not System's", "[SQLite]"))
        self.assertIn("lane verdict", self.cov.answer("sqlite3_open", "Linux")[2])
        # A hand status covers the entry where its declarations are built.
        self.assertEqual(self.cov.answer("STDIN_FILENO", "Windows")[0], "covered")
        self.assertEqual(self.cov.answer("STDIN_FILENO", "WASI")[0], "gap")

    def test_fields(self):
        self.assertEqual(self.cov.answer("st_mode", "Linux", field=True)[0], "covered")
        self.assertEqual(self.cov.answer("st_mode", "Windows", field=True)[0], "gap")


class CategoryTests(unittest.TestCase):
    def setUp(self):
        self.entries = ledger.load_entries(ENTRIES)
        self.modules = ledger.Modules(MODULES)
        self.cov = coverage()

    def categorize(self, s):
        return ledger.categorize(s, self.entries, self.cov, self.modules)

    def test_exception(self):
        s = self.categorize(site(repository="swift", file="stdlib/public/Synchronization/Mutex.swift",
                                 names=uses("getloadavg")))
        self.assertEqual((s["category"], s["holder"]), ("exception", ["X1"]))

    def test_excluded(self):
        s = self.categorize(site(file="Fixtures/Lib/a.swift", names=uses("getloadavg")))
        self.assertEqual((s["category"], s["holder"]), ("excluded", ["X2"]))

    def test_undecided_repository_and_reported_module(self):
        s = self.categorize(site(repository="corelibs", names=uses("getloadavg")))
        self.assertEqual((s["category"], s["holder"]), ("undecided", ["X3"]))
        s = self.categorize(site(module="os", group="report", platforms={"Darwin": "T"}))
        self.assertEqual((s["category"], s["holder"]), ("undecided", ["module os"]))

    def test_queued_by_name_on_its_platforms_only(self):
        s = self.categorize(site(module="WASILibc", platforms={"WASI": "T"},
                                 names=uses("pthread_mutex_lock", platforms=("WASI",))))
        self.assertEqual((s["category"], s["holder"]), ("queued", ["X4"]))
        # On Linux the same name is System's: nothing holds the site.
        s = self.categorize(site(names=uses("pthread_mutex_lock")))
        self.assertEqual(s["category"], "unexplained")

    def test_queued_whole_site(self):
        s = self.categorize(site(file="Sources/PkgLibc/libc.swift", platforms={"Linux": "T", "FreeBSD": "T"}))
        self.assertEqual((s["category"], s["holder"]), ("queued", ["X6"]))
        # A site compiled where the entry doesn't hold isn't the entry's.
        s = self.categorize(site(file="Sources/PkgLibc/libc.swift", module="WinSDK", platforms={"Windows": "T"}))
        self.assertEqual(s["category"], "unexplained")

    def test_system_gap(self):
        s = self.categorize(site(names=uses("statfs", "fsync", platforms=("Linux", "Windows")),
                                 platforms={"Linux": "T", "Windows": "M"}))
        self.assertEqual(s["category"], "System gap")
        self.assertEqual(s["holder"], ["[fsync]", "[statfs]"])
        hold = {h["holder"]: h for h in s["holders"]}
        self.assertEqual(hold["[fsync]"]["platforms"], ["Windows"])   # fsync is System's on Linux
        self.assertEqual(hold["[statfs]"]["platforms"], ["Linux", "Windows"])

    def test_hand_kept_gap_by_mapping_entry(self):
        s = self.categorize(site(module="MachO", platforms={"Darwin": "T"},
                                 names=uses("mach_header", platforms=("Darwin",))))
        self.assertEqual((s["category"], s["holder"]), ("System gap", ["X5"]))

    def test_not_systems_and_standard_library(self):
        s = self.categorize(site(names=uses("sqlite3_open")))
        self.assertEqual((s["category"], s["holder"]), ("not System's", ["[SQLite]"]))
        s = self.categorize(site(names=uses("malloc", "fsync")))
        self.assertEqual((s["category"], s["holder"]), ("standard library", ["[malloc]"]))

    def test_order(self):
        # A gap outranks queued work; queued work outranks a lane's verdict.
        s = self.categorize(site(module="WASILibc", platforms={"WASI": "T"},
                                 names=uses("pthread_mutex_lock", "getloadavg", platforms=("WASI",))))
        self.assertEqual(s["category"], "System gap")
        self.assertEqual({h["holder"] for h in s["holders"]}, {"X4", "getloadavg"})
        s = self.categorize(site(module="WASILibc", platforms={"WASI": "T"},
                                 names=uses("pthread_mutex_lock", "sqlite3_open", platforms=("WASI",))))
        self.assertEqual(s["category"], "queued")
        # A site's own entry outranks its names.
        s = self.categorize(site(repository="corelibs", names=uses("pthread_mutex_lock", platforms=("WASI",)),
                                 platforms={"WASI": "T"}))
        self.assertEqual(s["category"], "undecided")

    def test_unexplained(self):
        s = self.categorize(site(names=uses("fsync")))
        self.assertEqual(s["category"], "unexplained")
        self.assertIn("System covers every C name", s["reason"])
        s = self.categorize(site(names={}))
        self.assertEqual(s["category"], "unexplained")
        self.assertIn("no C name", s["reason"])
        s = self.categorize(site(platforms={}, names={}))
        self.assertIn("no platform", s["reason"])
        marker = {"line": 2, "text": "the raw posix_spawn path", "imported": []}
        s = self.categorize(site(kind="marker", markers=[marker]))
        self.assertEqual(s["category"], "unexplained")
        self.assertIn("names no C interface", s["reason"])

    def test_marker_names_count(self):
        marker = {"line": 2, "text": "statfs on Linux", "imported": []}
        s = self.categorize(site(kind="marker", markers=[marker], platforms={"Linux": "T", "WASI": "T"}))
        self.assertEqual((s["category"], s["holder"]), ("System gap", ["[statfs]"]))

    def test_marker_names_where_they_are_missing(self):
        # Each name is answered on the platforms the marker names right after
        # it, of those the site compiles on: fsync is System's on Linux.
        def categorize(text, platforms=("Linux", "Windows")):
            marker = {"line": 2, "text": text, "imported": []}
            return self.categorize(site(kind="marker", markers=[marker], platforms={p: "M" for p in platforms}))
        s = categorize("unistd.h fsync on Linux: FileDescriptor.synchronize()")
        self.assertEqual(s["category"], "unexplained")
        s = categorize("sys/vfs.h statfs on Windows, and unistd.h fsync on Linux")
        self.assertEqual((s["category"], s["holder"]), ("System gap", ["[statfs]"]))
        self.assertEqual(s["holders"][0]["platforms"], ["Windows"])
        s = categorize("unistd.h fsync (and fdatasync), on Linux")
        self.assertEqual(s["category"], "unexplained")
        # A word that isn't a platform names none; nor does a platform the
        # site isn't compiled on.
        s = categorize("unistd.h fsync in Embedded Swift")
        self.assertEqual(s["holders"][0]["platforms"], ["Windows"])
        s = categorize("unistd.h fsync on OpenBSD")
        self.assertEqual(s["holders"][0]["platforms"], ["Windows"])
        self.assertEqual(ledger.named_platforms("backtrace on Linux, Android, FreeBSD and OpenBSD, and "
                                                "backtrace_async on Darwin", "backtrace"),
                         {"Linux", "Android", "FreeBSD", "OpenBSD"})
        self.assertEqual(ledger.named_platforms("backtrace on Linux, and backtrace_async on Darwin",
                                                "backtrace_async"), {"Darwin"})


class MarkerParserTests(unittest.TestCase):
    """status.py's marker parser, which the ledger reads markers with."""

    def names(self, text):
        return [i for i, _, _ in status.marker_interfaces(text, [])]

    def test_a_name_and_where_it_is_missing(self):
        self.assertEqual(self.names("unistd.h isatty on WASI: FileDescriptor.isTerminal"), ["isatty"])
        self.assertEqual(self.names("unistd.h pipe2 before macOS 27: FileDescriptor.pipe(options:)"), ["pipe2"])
        self.assertEqual(self.names("dlfcn.h dlsym with RTLD_DEFAULT or a handle the caller owns"), ["dlsym"])
        self.assertEqual(self.names("gnu/libc-version.h gnu_get_libc_version: the C library's version"),
                         ["gnu_get_libc_version"])
        self.assertEqual(self.names("statfs on Linux"), ["statfs"])
        self.assertEqual(self.names("stdio.h remove on Windows and WASI: FilePath.remove()"), ["remove"])
        self.assertEqual(self.names("file cloning (sys/clonefile.h fclonefileat, FreeBSD's copy_file_range)"),
                         ["fclonefileat", "copy_file_range"])

    def test_prose_stays_prose(self):
        # A colon's list continues a head only when it starts with a name.
        self.assertEqual(self.names("DynamicLibrary, in the framework build: dlopen with RTLD_NOLOAD | RTLD_FIRST, "
                                    "dlsym and dlclose"), ["DynamicLibrary"])
        self.assertEqual(self.names("the raw posix_spawn path"), ["raw posix_spawn path"])


class RankTests(unittest.TestCase):
    @staticmethod
    def gap_site(*units, platforms=("Linux",), file="a.swift"):
        return {"category": "System gap", "repository": "pkg", "file": file,
                "holders": [{"category": "System gap", "holder": u, "names": [u], "platforms": list(platforms)}
                            for u in units]}

    def test_greedy_unblocking(self):
        sites = [self.gap_site("A"), self.gap_site("A"), self.gap_site("B"), self.gap_site("B", "C"),
                 self.gap_site("C")]
        order = [(u, g["unblocks"], g["holds"]) for u, g in ledger.rank_gaps(sites)]
        self.assertEqual(order, [("A", 2, 2), ("B", 1, 2), ("C", 2, 2)])

    def test_files_unblocked(self):
        sites = [self.gap_site("A"), self.gap_site("A"), self.gap_site("A", file="b.swift")]
        self.assertEqual([(u, g["unblocks"], g["files"]) for u, g in ledger.rank_gaps(sites)], [("A", 3, 2)])

    def test_nothing_unblocked_alone(self):
        order = [(u, g["unblocks"]) for u, g in ledger.rank_gaps([self.gap_site("A", "B"), self.gap_site("A", "B")])]
        self.assertEqual(order, [("A", 0), ("B", 2)])

    def test_ties_go_to_more_platforms(self):
        sites = [self.gap_site("A"), self.gap_site("B", platforms=("Linux", "Windows"))]
        self.assertEqual([u for u, _ in ledger.rank_gaps(sites)], ["B", "A"])

    def test_floor(self):
        sites = [dict(site(platforms={"Linux": "T", "Windows": "M"}), category="System gap"),
                 dict(site(platforms={"Linux": "T"}), category="exception"),
                 dict(site(platforms={"Darwin": "T"}), category="excluded"),
                 dict(site(module="os", group="report", platforms={"Darwin": "T"}), category="undecided")]
        fl = ledger.floor(sites)
        self.assertEqual({p: len(v) for p, v in fl.items() if v}, {"Linux": 1, "Windows": 1})


def git(repo, *args):
    """git in a test's own repository, without the user's or the system's
    configuration."""
    env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_AUTHOR_NAME="t",
               GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")
    return subprocess.run(["git", "-C", repo, *args], env=env, check=True, capture_output=True, text=True).stdout


def commit_files(repo, files, message):
    for path, text in files.items():
        os.makedirs(os.path.join(repo, os.path.dirname(path)), exist_ok=True)
        with open(os.path.join(repo, path), "w") as f:
            f.write(text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--no-verify", "-m", message)
    return git(repo, "rev-parse", "HEAD").strip()


A_SWIFT = """#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif
import Dispatch

func f() {
    #if os(Linux)
    _ = epoll_create1(0)
    #endif
    _ = fsync(3)
    _ = statfs()   // the repository's own, below: not a C name
    _ = DispatchQueue(label: "q")
}

struct statfs {}
"""
B_SWIFT = """// SYSTEM-GAP: usleep for deployment targets before macOS 13
import func Darwin.usleep
"""
C_SWIFT = """// SYSTEM-GAP: getloadavg
func g() {}
"""
D_SWIFT = """#if os(Android)
import stdlib_h
#endif
"""
E_SWIFT = """#if canImport(Glibc)
import Glibc
#endif

func wait(label: String, timeout: Int) -> Int32 {
    let deadline = timeout + 1
    print(label, deadline)
    return fsync(3)
}

#if objectFormat(MachO)
// SYSTEM-GAP: getsectiondata
func sections() {}
#elseif objectFormat(ELF)
// SYSTEM-GAP: dl_iterate_phdr
func headers() {}
#endif
"""


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="ledger-test-")
        self.repo = os.path.join(self.root, "pkg")
        os.makedirs(self.repo)
        git(self.repo, "init", "-q", "-b", "main")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_sites_platforms_names_and_markers(self):
        commit = commit_files(self.repo, {"Sources/Pkg/A.swift": A_SWIFT, "Sources/Pkg/B.swift": B_SWIFT,
                                          "Tests/PkgTests/C.swift": C_SWIFT, "Sources/Pkg/D.swift": D_SWIFT},
                              "fixtures")
        modules = ledger.Modules(MODULES)
        cov = coverage()
        vocab = ledger.Vocabulary({"Darwin.POSIX.unistd": {"fsync": [32768, 1], "usleep": [32768, 1]}}, modules, cov,
                                  swift=("Int",))
        vocab.names.add("epoll_create1")
        sites, notsys = ledger.scan_repository("pkg", self.repo, commit, None, modules, vocab,
                                               ledger.qualified_re(modules))
        by = {(s["file"], s["line"]): s for s in sites}
        self.assertEqual(notsys["Dispatch"], 1)
        darwin = by[("Sources/Pkg/A.swift", 2)]
        self.assertEqual(set(darwin["platforms"]), {"Darwin"})
        self.assertEqual(set(darwin["names"]), {"fsync"})
        glibc = by[("Sources/Pkg/A.swift", 4)]
        self.assertEqual(set(glibc["platforms"]), {"Linux", "FreeBSD", "OpenBSD"})
        self.assertEqual(set(glibc["names"]["epoll_create1"]), {"Linux"})   # only Linux compiles that line
        self.assertEqual(set(glibc["names"]["fsync"]), {"Linux", "FreeBSD", "OpenBSD"})
        self.assertNotIn("statfs", glibc["names"])
        self.assertEqual(set(by[("Sources/Pkg/A.swift", 6)]["platforms"]), {"Windows"})
        scoped = by[("Sources/Pkg/B.swift", 2)]
        self.assertEqual((scoped["importKind"], list(scoped["names"])), ("scoped", ["usleep"]))
        self.assertEqual(len(scoped["markers"]), 1)   # the marker sits over the import: no site of its own
        self.assertNotIn(("Sources/Pkg/B.swift", 1), by)
        marker = by[("Tests/PkgTests/C.swift", 1)]
        self.assertEqual((marker["type"], marker["kind"]), ("marker", "tests"))
        self.assertEqual(set(by[("Sources/Pkg/D.swift", 2)]["platforms"]), {"Android"})

    def test_swift_words_and_object_formats(self):
        # `label` and `timeout` are parameter names here, not C's; and a
        # marker under objectFormat() is compiled only where the format is.
        commit = commit_files(self.repo, {"Sources/Pkg/E.swift": E_SWIFT}, "fixtures")
        modules = ledger.Modules(MODULES)
        vocab = ledger.Vocabulary({"Darwin.POSIX.unistd": {"fsync": [32768, 1], "label": [32768, 1],
                                                           "timeout": [32768, 1]}}, modules, coverage())
        sites, _ = ledger.scan_repository("pkg", self.repo, commit, None, modules, vocab,
                                          ledger.qualified_re(modules))
        by = {(s["file"], s["line"]): s for s in sites}
        self.assertEqual(set(by[("Sources/Pkg/E.swift", 2)]["names"]), {"fsync"})
        self.assertEqual(set(by[("Sources/Pkg/E.swift", 12)]["platforms"]), {"Darwin"})
        self.assertEqual(set(by[("Sources/Pkg/E.swift", 15)]["platforms"]),
                         {"Linux", "Musl", "Android", "FreeBSD", "OpenBSD"})

    def test_markers_at_the_newest_branch(self):
        commit_files(self.repo, {"Sources/Pkg/A.swift": "// SYSTEM-GAP: getloadavg\nfunc a() {}\n"}, "base")
        git(self.repo, "checkout", "-q", "-b", "migrate-darwin")
        darwin = commit_files(self.repo, {"Sources/Pkg/B.swift": "// SYSTEM-GAP: statfs\nfunc b() {}\n"}, "darwin")
        git(self.repo, "checkout", "-q", "-b", "migrate-unix")
        unix = commit_files(self.repo, {"Sources/Pkg/C.swift": "// SYSTEM-GAP: inotify_init1\nfunc c() {}\n"}, "unix")
        git(self.repo, "checkout", "-q", "main")
        cache = os.path.join(self.root, "cache")
        branches = ["migrate-all", "migrate-unix", "migrate-darwin"]
        newest = status.marker_snapshots(self.root, [], "newest", branches, {}, cache)
        self.assertEqual([(n, b, c) for n, b, c, _ in newest], [("pkg", "migrate-unix", unix)])
        self.assertEqual(sorted(m[2] for m in newest[0][3].markers), ["getloadavg", "inotify_init1", "statfs"])
        # A package's own list of branches comes first.
        own = status.marker_snapshots(self.root, [], "newest", branches, {"pkg": ["migrate-darwin"]}, cache)
        self.assertEqual([(b, c) for _, b, c, _ in own], [("migrate-darwin", darwin)])
        # The old view: the packages at their --branch.
        snap = status.Snapshot(self.repo, darwin, cache, "pkg")
        old = status.marker_snapshots(self.root, [{"name": "pkg", "branch": "migrate-darwin", "tip": darwin,
                                                   "now": snap}], "branch", branches, {}, cache)
        self.assertEqual(sorted(m[2] for m in old[0][3].markers), ["getloadavg", "statfs"])


if __name__ == "__main__":
    unittest.main()
