#!/usr/bin/env python3
"""Tests of the burn-down's own logic, without the package or its tools.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-burndown/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import collections  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import burndown as bd  # noqa: E402
import headers as hdr  # noqa: E402
import history as hist  # noqa: E402
import page  # noqa: E402


def decl(path, sig, occ=1, module="SystemPackage", file="Sources/System/A.swift", line=1, flags=()):
    return {"id": f"{module}|{path}|{sig}" + (f"#{occ}" if occ > 1 else ""), "occ": occ, "module": module,
            "path": path, "sig": sig, "file": file, "line": line, "kind": "swift.property", "title": path,
            "platforms": ["Darwin"], "flags": list(flags), "decl": sig}


class SignatureTests(unittest.TestCase):
    def test_attributes_and_access_are_dropped(self):
        self.assertEqual(hist.sig_norm("@available(System 199, *) @_alwaysEmitIntoClient public  static var x: Int"),
                         "static var x: Int")
        self.assertEqual(hist.sig_norm("public func f(_ a: Int) throws(Errno)"), "func f(_ a: Int) throws(Errno)")


class EnumCaseTests(unittest.TestCase):
    SOURCE = "\n".join([
        "public enum E: Int {",
        "  case a",
        "  @available(*, deprecated) case b(Int)",
        "  indirect case c",
        "  public var name: String {",
        "    switch self {",
        "    case a: return \"a\"",
        "    case .b: return \"b\"",
        "    default: return \"\"",
        "    }",
        "  }",
        "}",
        "func g(x: Int) { switch x { case 1: break; default: break } }",
        "",
    ])

    def test_marks_enum_body_cases_only(self):
        out = hist.mark_enum_cases(self.SOURCE).split("\n")
        self.assertEqual(len(out), len(self.SOURCE.split("\n")))
        self.assertEqual(out[1], "  public case a")
        self.assertEqual(out[2], "  @available(*, deprecated) public case b(Int)")
        self.assertEqual(out[3], "  indirect public case c")
        self.assertEqual(out[6], "    case a: return \"a\"")
        self.assertEqual(out[7], "    case .b: return \"b\"")
        self.assertEqual(out[12], self.SOURCE.split("\n")[12])

    def test_comments_and_strings_are_left_alone(self):
        src = "public enum E {\n  // case x\n  case y\n  var s: String { \"case z\" }\n}\n"
        out = hist.mark_enum_cases(src).split("\n")
        self.assertEqual(out[1], "  // case x")
        self.assertEqual(out[2], "  public case y")


class NewUnitTests(unittest.TestCase):
    def test_multiset_difference(self):
        base = {"declarations": [decl("A.x", "var x: Int"), decl("A.y", "var y: Int")]}
        head = {"declarations": [decl("A.x", "var x: Int"), decl("A.x", "var x: Int", occ=2, line=9),
                                 decl("A.y", "var y: Int8"), decl("A.z", "var z: Int")]}
        got = sorted(u["id"] for u in hist.new_units(head, base))
        self.assertEqual(got, ["SystemPackage|A.x|var x: Int#2", "SystemPackage|A.y|var y: Int8",
                               "SystemPackage|A.z|var z: Int"])


class MergedTests(unittest.TestCase):
    def test_merged_needs_main_to_gain_the_path(self):
        a, b, c = decl("A.a", "a"), decl("A.b", "b"), decl("A.c", "c")
        sets = [{a["id"]: a, b["id"]: b, c["id"]: c}, {c["id"]: c}, {c["id"]: c}]
        mains = [collections.Counter(), collections.Counter({("SystemPackage", "A.a"): 1}),
                 collections.Counter({("SystemPackage", "A.a"): 1})]
        merged = hist.merged_by_point(sets, mains)
        self.assertEqual(merged[0], {})
        self.assertEqual(set(merged[1]), {a["id"]})          # left the delta, main gained it
        self.assertEqual(set(merged[2]), {a["id"]})          # stays merged
        self.assertNotIn(b["id"], merged[2])                  # removed, not merged

    def test_an_overload_that_lands_beside_an_existing_one(self):
        a1, a2 = decl("A.f(_:)", "func f(_ x: Int)"), decl("A.f(_:)", "func f(_ x: Int8)")
        sets = [{a2["id"]: a2}, {}]
        mains = [collections.Counter({("SystemPackage", "A.f(_:)"): 1}),
                 collections.Counter({("SystemPackage", "A.f(_:)"): 2})]
        self.assertEqual(set(hist.merged_by_point(sets, mains)[1]), {a2["id"]})
        del a1


class StatesTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="api-burndown-test-")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def write(self, doc):
        p = os.path.join(self.dir, "states.json")
        with open(p, "w") as f:
            json.dump(doc, f)
        return p

    def test_validation_and_dates(self):
        p = self.write({"a": {"state": "pitched", "date": "2026-10-03", "link": "x"},
                        "b": [{"state": "pr", "date": "2026-10-09"}, {"state": "pitched", "date": "2026-10-05"}],
                        "c": {"state": "merged", "date": "2026-10-01"},
                        "d": {"state": "pitched", "date": "October"}})
        states, problems = bd.load_states(p)
        self.assertEqual(sorted(states), ["a", "b"])
        self.assertEqual(len(problems), 2)
        self.assertEqual(bd.hand_state(states, "b", "2026-10-04"), (None, None))
        self.assertEqual(bd.hand_state(states, "b", "2026-10-06")[0], 3)
        self.assertEqual(bd.hand_state(states, "b", "2026-10-09")[0], 4)

    def test_first_pitch_by_name_decides(self):
        states, _ = bd.load_states(self.write({"b-pitch": {"state": "pr", "date": "2026-10-01"}}))
        self.assertEqual(bd.state_of([], states, "2026-10-02"), 1)
        self.assertEqual(bd.state_of(["a-pitch", "b-pitch"], states, "2026-10-02"), 2)
        self.assertEqual(bd.state_of(["b-pitch", "a-pitch"], states, "2026-10-02"), 4)

    def test_empty_file(self):
        self.assertEqual(bd.load_states(self.write({})), ({}, []))


class AreaTests(unittest.TestCase):
    def test_file_groups(self):
        areas = bd.Areas.__new__(bd.Areas)
        areas.names = {"Sources/System": {"FileControl", "FileControlCommand", "Errno", "ErrnoWindows", "Util",
                                          "UtilConsumers", "FilePath", "FileDescriptor"},
                       "Sources/SystemSockets": {"Sockets"}}
        self.assertEqual(areas.of("Sources/System/FileControlCommand.swift"), "System/FileControl")
        self.assertEqual(areas.of("Sources/System/ErrnoWindows.swift"), "System/Errno")
        self.assertEqual(areas.of("Sources/System/Util+StringArray.swift"), "System/Util")
        self.assertEqual(areas.of("Sources/System/FileDescriptor.swift"), "System/FileDescriptor")
        self.assertEqual(areas.of("Sources/System/FilePath/FilePathParsing.swift"), "System/FilePath")
        self.assertEqual(areas.of("Sources/SystemSockets/Sockets/Socket.swift"), "SystemSockets/Sockets")
        self.assertEqual(areas.of(None), "(no source file)")


class PointsTests(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp(prefix="api-burndown-repo-")
        self.git("init", "-q", "-b", "main")
        self.commit("base", "2026-09-01T10:00:00-0600")
        self.git("checkout", "-q", "-b", "next")
        self.commit("one", "2026-09-03T09:00:00-0600")
        self.commit("two", "2026-09-03T17:00:00-0600")
        self.commit("three", "2026-09-05T08:00:00-0600")

    def tearDown(self):
        shutil.rmtree(self.repo)

    def git(self, *args, env=None):
        e = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null",
                 GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com", GIT_COMMITTER_NAME="t",
                 GIT_COMMITTER_EMAIL="t@example.com", **(env or {}))
        return subprocess.run(["git", "-C", self.repo, *args], capture_output=True, text=True, env=e,
                              check=True).stdout.strip()

    def commit(self, msg, date):
        with open(os.path.join(self.repo, "f"), "a") as f:
            f.write(msg + "\n")
        self.git("add", "f")
        self.git("commit", "-q", "-m", msg, env={"GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date})

    def test_one_point_a_day_with_carry_forward(self):
        head, base = self.git("rev-parse", "next"), self.git("rev-parse", "main")
        pts = hist.points(self.repo, head, base, "2026-09-06")
        self.assertEqual([p["day"] for p in pts], ["2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06"])
        subjects = {p["day"]: p["subject"] for p in pts}
        self.assertEqual(subjects, {"2026-09-03": "two", "2026-09-04": "two", "2026-09-05": "three",
                                    "2026-09-06": "three"})
        self.assertEqual([p["newCommit"] for p in pts], [True, False, True, False])
        self.assertTrue(all(p["base"] == base for p in pts))


class ModuleMapTests(unittest.TestCase):
    def setUp(self):
        self.sdk = tempfile.mkdtemp(prefix="api-burndown-sdk-")
        inc = os.path.join(self.sdk, "usr", "include")
        os.makedirs(os.path.join(inc, "sys"))
        os.makedirs(os.path.join(inc, "apache2"))
        files = {
            "module.modulemap": 'extern module Darwin "Darwin.modulemap"\n',
            "Darwin.modulemap": 'module Darwin [system] {\n  extern module POSIX "Darwin_POSIX.modulemap"\n'
                                '  explicit module sys {\n    module event { header "sys/event.h" export * }\n  }\n}\n',
            "Darwin_POSIX.modulemap": 'module Darwin.POSIX {\n  module fcntl {\n    requires !swift, objc\n'
                                      '    header "fcntl.h"\n    header "sys/fcntl.h"\n    export *\n  }\n}\n',
            "fcntl.h": "#include <sys/fcntl.h>\nint open(const char *, int, ...);\n",
            "sys/fcntl.h": "#define O_RDONLY 0x0000\n#include <sys/_o_sync.h>\n",
            "sys/_o_sync.h": "#define O_SYNC 0x0080\n",
            "sys/event.h": "struct kevent {\n int x;\n};\nint kevent(int kq);\nenum { EV_A = 1, EV_B };\n",
            "apache2/junk.h": "#define environ junk\n",
        }
        for rel, text in files.items():
            with open(os.path.join(inc, rel), "w") as f:
                f.write(text)
        self.vocab = os.path.join(self.sdk, "vocab.json.gz")
        with gzip.open(self.vocab, "wt") as f:
            json.dump({"note": "test", "modules": 2, "vocab": {
                "Darwin.POSIX.fcntl": {"open": [1 << hdr.K_FUNCTION, 1]},
                "Darwin.sys.event": {"kevent": [1 << hdr.K_FUNCTION, 1]},
                "Darwin.bsm.audit_record": {"kevent": [1 << hdr.K_STRUCT, 1]},
            }}, f)

    def tearDown(self):
        shutil.rmtree(self.sdk)

    def test_module_maps(self):
        maps = hdr.ModuleMaps(os.path.join(self.sdk, "usr", "include"))
        self.assertEqual(maps.headers["Darwin.POSIX.fcntl"], ["fcntl.h", "sys/fcntl.h"])
        self.assertEqual(maps.headers["Darwin.sys.event"], ["sys/event.h"])

    def test_locate(self):
        h = hdr.Headers(self.vocab, self.sdk, None)
        self.assertEqual(h.locate("open", ["function"])["header"], "fcntl.h")
        r = h.locate("O_SYNC", ["constant"])
        self.assertEqual((r["header"], r["module"], r["how"]), ("sys/_o_sync.h", "Darwin.POSIX.fcntl", "#define"))
        # The struct by its definition, not the vocabulary's forward declaration.
        r = h.locate("kevent", ["type"])
        self.assertEqual((r["header"], r["module"], r["how"]), ("sys/event.h", "Darwin.sys.event", "definition"))
        self.assertEqual(h.locate("EV_B", ["constant"])["header"], "sys/event.h")
        self.assertIsNone(h.locate("environ", ["variable"])["header"])     # only another library's header
        self.assertEqual(h.locate("int", ["type"])["how"], "a C built-in type")


class PageTests(unittest.TestCase):
    def test_codes_follow_the_rows(self):
        decls = [{"id": "x", "state": 1, "flags": [], "module": "M", "path": "A", "kindName": "Structure",
                  "area": "System/A", "file": "f", "line": 1, "platforms": ["Darwin"], "pitch": None,
                  "pitches": [], "cName": None, "header": "(no C name)", "sdkModule": "(no C name)",
                  "sdkSubmodule": "(no C name)", "decl": "struct A", "availability": "", "docSummary": "",
                  "usedBy": [], "couldUse": 0, "cNames": [], "headerHow": "no C name", "excluded": False}]
        merged = [{"id": "m", "module": "M", "path": "B", "kindName": "Case", "area": "System/B", "file": "f",
                   "line": 2, "platforms": ["Linux"], "flags": [], "decl": "case b", "excluded": False}]
        history_units = [{"id": "x", "current": True},
                         {"id": "gone", "current": False, "module": "M", "path": "C", "kindName": "Case",
                          "area": "System/C", "platforms": [], "flags": ["stub"], "excluded": True},
                         {"id": "m", "current": False, "mergedNow": True}]
        data = {"flags": {"stub": "", "upstream": ""}, "declarations": decls, "merged": merged,
                "historyUnits": history_units, "digest": "d", "states": [], "excludedFlags": ["stub"],
                "totals": {}, "history": {"days": [{"day": "2026-10-01", "commit": "c" * 40, "newCommit": True,
                                                     "subject": "s", "method": "scan", "codes": "1a5"}],
                                          "storeCommits": []},
                "meta": {"generated": "2026-10-01", "baseRef": "main", "baseCommit": "b" * 40, "baseSubject": "",
                         "headRef": "next", "headCommit": "h" * 40, "headSubject": "", "graph": {},
                         "pitches": {"files": [], "dirty": False, "problems": []},
                         "states": {"entries": {}, "problems": [], "unknownPitches": []}, "upstream": None,
                         "headers": {"sdkVersion": "26.0", "vocab": "v"},
                         "apiDelta": {"added": 1, "hidden": 0, "date": "", "swift": ""}, "tool": {}}}
        out = page.compact(data)
        self.assertEqual(len(out["D"]), 2)             # the declaration and the merged one
        self.assertEqual(len(out["X"]), 1)             # the one only an earlier day has
        self.assertEqual(out["days"][0]["codes"], "15a")


if __name__ == "__main__":
    unittest.main()
