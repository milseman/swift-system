#!/usr/bin/env python3
"""Tests of how the graph gets its C names: the C references code reaches
(build_graph.py), doc and code links and their merge, and field
qualification (cnames.py), and which links the derived facts read
(graphq.py). No build or index store is needed.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-graph/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_graph as bg  # noqa: E402
import cnames  # noqa: E402
import graphq  # noqa: E402


class CReferenceTests(unittest.TestCase):
    def test_kinds(self):
        self.assertEqual(bg.c_reference("c:@F@sigaddset"), ("sigaddset", "function"))
        self.assertEqual(bg.c_reference("c:@macro@SIGTTIN"), ("SIGTTIN", "macro"))
        self.assertEqual(bg.c_reference("c:@macro@_SC_CHILD_MAX"), ("_SC_CHILD_MAX", "macro"))
        self.assertEqual(bg.c_reference("c:CSystemDarwin.h@386@macro@X"), ("X", "macro"))
        self.assertEqual(bg.c_reference("c:@E@vtype@VREG"), ("VREG", "constant"))
        self.assertEqual(bg.c_reference("c:@Ea@REMOVEFILE_RECURSIVE@REMOVEFILE_KEEP_PARENT"),
                         ("REMOVEFILE_KEEP_PARENT", "constant"))
        self.assertEqual(bg.c_reference("c:@EA@idtype_t@P_PID"), ("P_PID", "constant"))
        self.assertEqual(bg.c_reference("c:@timezone"), ("timezone", "variable"))

    def test_fields_are_named_for_their_record(self):
        self.assertEqual(bg.c_reference("c:@S@rusage_info_v6@FI@ri_pageins"), ("rusage_info_v6.ri_pageins", "field"))
        self.assertEqual(bg.c_reference("c:@SA@malloc_type_summary_v0_t@FI@version"),
                         ("malloc_type_summary_v0_t.version", "field"))
        # The importer's member for a field of an anonymous union.
        self.assertEqual(bg.c_reference("c:@UA@malloc_type_descriptor_v0_t@summary"),
                         ("malloc_type_descriptor_v0_t.summary", "field"))

    def test_types_and_modules_are_not_references(self):
        for usr in ("c:@S@stat", "c:@SA@DIR", "c:@T@pid_t", "c:@EA@idtype_t", "c:@E@vtype", "c:@M@Darwin"):
            self.assertIsNone(bg.c_reference(usr), usr)


class ShimTests(unittest.TestCase):
    defs = {"c:@F@csystem_posix_pipe2": [["Sources/CSystem/include/CSystemShared.h", 11, 5]],
            "c:@F@pipe2": [["Sources/System/Internals/Syscalls.swift", 3, 1]]}

    def test_by_where_it_is_declared(self):
        headers = {"CSystemDarwin.h", "CSystemShared.h"}
        self.assertTrue(bg.c_shim("c:@F@csystem_posix_pipe2", self.defs, headers))
        self.assertTrue(bg.c_shim("c:CSystemDarwin.h@386@macro@COMPATIBILITY_O_CLOFORK", {}, headers))
        # Not by name: an SDK function, and an SDK macro that starts with `_`.
        self.assertFalse(bg.c_shim("c:@F@pipe2", self.defs, headers))
        self.assertFalse(bg.c_shim("c:@F@csystem_lookalike", {}, headers))
        self.assertFalse(bg.c_shim("c:@macro@_SC_CHILD_MAX", {}, headers))


class MockLineTests(unittest.TestCase):
    def test_lines_only_a_mocking_build_has(self):
        lines = ["func system_close(_ fd: CInt) -> CInt {", "  #if ENABLE_MOCKING",
                 "  if mockingEnabled { return _mock(fd) }", "  #endif", "  return close(fd)", "}",
                 "#if !ENABLE_MOCKING", "let a = 1", "#else", "let b = getTLS(key)", "#endif",
                 "#if os(Linux)", "  #if ENABLE_MOCKING", "  let c = 3", "  #else", "  let d = 4", "  #endif", "#endif"]
        self.assertEqual(bg.mock_only_lines(lines), {3, 10, 14})


class WalkTests(unittest.TestCase):
    # Lines of one file: 1 the public `update`, 2 the internal `_add`, 3 the
    # public `insert`, 4 a stub, 5 the internal helper `insert` calls.
    REFS = {1: ["s:_add", "s:insert"], 2: ["c:@F@sigaddset", "c:@macro@NSIG", "c:@F@csystem_shim"],
            3: ["s:_helper"], 4: ["s:insert"], 5: ["c:@F@sigismember", "c:@S@sigset"]}
    BODIES = {"s:_add": ("f", 2, 2, "internal"), "s:insert": ("f", 3, 3, "public"),
              "s:_helper": ("f", 5, 5, None)}

    def walk(self, line, stub=False):
        return bg.walk_c(("f", line, line), lambda rel, a, b: [u for ln in range(a, b + 1) for u in self.REFS.get(ln, [])],
                         self.BODIES.get, lambda usr: "csystem" in usr, stub=stub)

    def test_internal_code_is_followed_and_public_api_is_not(self):
        found, shim = self.walk(1)
        self.assertEqual(found, {"sigaddset": "function", "NSIG": "macro"})
        self.assertTrue(shim)

    def test_a_stub_follows_the_declaration_it_renames(self):
        found, shim = self.walk(4, stub=True)
        self.assertEqual(found, {"sigismember": "function"})   # through public insert, then internal _helper
        self.assertFalse(shim)
        self.assertEqual(self.walk(4), ({}, False))


class LinkTests(unittest.TestCase):
    def test_doc_and_code_links_merge(self):
        nodes = {"u": {"cRefs": [{"name": "NSIG", "cKind": "macro"}, {"name": "sigaddset", "cKind": "function"}]},
                 "one": {"cRefs": [{"name": "SIGTTIN", "cKind": "macro"}]},
                 "T": {"isType": True, "cRefs": [{"name": "sigemptyset", "cKind": "function"}]}}
        links = cnames.Links()
        links.add("u", "sigaddset", "subject", False, "function", "doc", "The corresponding C function is `sigaddset`.")
        links.add_code(nodes)
        got = {(w["node"], w["name"]): (w["role"], w["sources"]) for w in links.records}
        self.assertEqual(got, {("u", "sigaddset"): ("subject", ["code", "doc"]),   # the doc sentence's role
                               ("u", "NSIG"): ("argument", ["code"]),
                               ("one", "SIGTTIN"): ("subject", ["code"])})          # a type gets none
        self.assertTrue(cnames.stated(links.index[("u", "sigaddset", "subject")]))
        self.assertFalse(cnames.stated(links.index[("u", "NSIG", "argument")]))

    def test_a_typealias_and_a_sentence_are_one_link(self):
        links = cnames.Links()
        links.add("t", "stat", "subject", False, "type", "typealias", "typealias Stat = stat")
        links.add("t", "stat", "subject", False, "type", "doc", "The corresponding C type is `stat`.")
        self.assertEqual([w["sources"] for w in links.records], [["doc", "typealias"]])


class FieldTests(unittest.TestCase):
    def test_qualify(self):
        own = {"ri_pageins": {"rusage_info_v6.ri_pageins"}}
        self.assertEqual(cnames.qualify("ri_pageins", None, own, {}, {"rusage_info_v6"}, None),
                         "rusage_info_v6.ri_pageins")
        self.assertEqual(cnames.qualify("sched_priority", "sched_param", {}, {}, set(), None),
                         "sched_param.sched_priority")
        self.assertEqual(cnames.qualify("tm_sec", None, {}, {"tm_sec": {"tm.tm_sec"}}, set(), None), "tm.tm_sec")
        self.assertEqual(cnames.qualify("st_mtim", None, {}, {}, {"stat"}, None), "stat.st_mtim")
        self.assertEqual(cnames.qualify("l_linger", None, {}, {}, set(), "linger"), "linger.l_linger")
        self.assertEqual(cnames.qualify("si_pid", None, {}, {}, set(), None), "si_pid")

    def test_doc_fields(self):
        root = tempfile.mkdtemp(prefix="api-graph-test-")
        try:
            os.makedirs(os.path.join(root, "Sources"))
            text = ["/// Whether to linger.", "///", "/// The corresponding C fields are `l_onoff` and `l_linger`.",
                    "@_alwaysEmitIntoClient", "public init(isEnabled: Bool) {}",
                    "/// The corresponding C field is `e_ppid`, of `kp_eproc`.", "public var parent: Int",
                    "/// The corresponding C property is `si_status`, for `CLD_EXITED`.", "public var status: Int",
                    "/// The corresponding C function is `close`.", "public func close()"]
            with open(os.path.join(root, "Sources", "A.swift"), "w") as f:
                f.write("\n".join(text) + "\n")
            derive = cnames.coverage_module("derive")
            got = cnames.doc_fields(derive, root, [("Sources/A.swift", 5), ("Sources/A.swift", 7),
                                                   ("Sources/A.swift", 9), ("Sources/A.swift", 11)])
        finally:
            shutil.rmtree(root)
        self.assertEqual([(m[0], m[2]) for m in got[("Sources/A.swift", 5)]],
                         [("l_onoff", "subject"), ("l_linger", "alternative")])
        self.assertEqual([m[0] for m in got[("Sources/A.swift", 7)]], ["e_ppid"])   # not the path to it
        self.assertEqual([m[0] for m in got[("Sources/A.swift", 9)]], ["si_status"])  # CLD_EXITED is a constant
        self.assertNotIn(("Sources/A.swift", 11), got)                                # derive.py's own names

    def test_add_doc_fields(self):
        nodes = {"linger.isEnabled": {"file": "A", "line": 1, "platforms": ["Darwin"],
                                      "cRefs": [{"name": "linger.l_onoff", "cKind": "field"}]},
                 "linger.init": {"file": "A", "line": 2, "platforms": ["Darwin"], "cRefs": []},
                 "StatFS.availableInodes": {"file": "A", "line": 3, "platforms": ["Linux"], "cRefs": []}}
        edges = [{"from": "linger.init", "to": "c:@S@linger", "kind": "memberOf"}]
        fields = {("A", 1): [("l_onoff", None, "subject", "s1")],
                  ("A", 2): [("l_onoff", None, "subject", "s2"), ("l_linger", None, "alternative", "s2")],
                  ("A", 3): [("f_favail", None, "subject", "s3"), ("statvfs", None, "alternative", "s3"),
                             ("size_t", None, "alternative", "s3")]}
        links = cnames.Links()
        cnames.add_doc_fields(links, nodes, edges, fields, not_fields={"statvfs"})
        self.assertEqual(sorted((w["node"], w["name"]) for w in links.records),
                         [("StatFS.availableInodes", "f_favail"), ("linger.init", "linger.l_linger"),
                          ("linger.init", "linger.l_onoff"), ("linger.isEnabled", "linger.l_onoff")])
        links.add_code(nodes)
        self.assertEqual(links.index[("linger.isEnabled", "linger.l_onoff", "subject")]["sources"], ["code", "doc"])


class StatedTests(unittest.TestCase):
    def test_which_links_say_what_a_declaration_stands_for(self):
        nodes = {"cname:close": {"baseCovered": False}, "cname:stat.st_size": {"baseCovered": False}}
        doc = {"kind": "wraps", "to": "cname:close", "role": "subject", "restricted": False, "sources": ["code", "doc"]}
        code = dict(doc, sources=["code"])
        old = {"kind": "wraps", "to": "cname:close", "role": "subject", "restricted": False, "source": "typealias"}
        field = dict(doc, to="cname:stat.st_size", cKind="field", sources=["doc"])
        self.assertEqual(graphq.link_sources(old), ["typealias"])     # a snapshot before schema 2
        self.assertTrue(graphq.stated(doc) and graphq.stated(old) and graphq.stated(field))
        self.assertFalse(graphq.stated(code))
        self.assertTrue(graphq.could_use(doc, nodes))
        self.assertFalse(graphq.could_use(code, nodes) or graphq.could_use(field, nodes))
        self.assertFalse(graphq.could_use(dict(doc, restricted=True), nodes))


class WorkListTests(unittest.TestCase):
    def test_doc_sentences(self):
        def decl(path, **kw):
            return dict({"kind": "declaration", "origin": "head", "path": path, "file": "Sources/A.swift",
                         "line": 1, "ownDoc": True, "hasDoc": True}, **kw)
        doc = {"meta": {"baseRef": "main", "headRef": "next", "headCommit": "c" * 40},
               "nodes": {"T": decl("T", isType=True, reachesC=True, line=1),
                         "T.update": decl("T.update", line=5), "T.insert": decl("T.insert", line=9),
                         "T.==": decl("T.==", line=12, ownDoc=False),
                         "T.STUB": decl("T.STUB", hiddenClass="unavailable", ownDoc=False),
                         "cname:sigaddset": {"kind": "cname", "name": "sigaddset"},
                         "cname:NSIG": {"kind": "cname", "name": "NSIG"}},
               "links": [{"kind": "memberOf", "from": m, "to": "T"} for m in ("T.update", "T.insert", "T.==")]
               + [{"kind": "wraps", "from": "T.update", "to": "cname:sigaddset", "sources": ["code"]},
                  {"kind": "wraps", "from": "T.update", "to": "cname:NSIG", "sources": ["code"]},
                  {"kind": "wraps", "from": "T.insert", "to": "cname:sigaddset", "sources": ["code", "doc"]}]}
        md = graphq.doc_sentences_md(doc)
        self.assertIn("- 5: `T.update`: `NSIG`, `sigaddset`", md)
        self.assertNotIn("`T.insert`:", md)                     # a doc sentence names its C name
        self.assertIn("- 1: `T`: `sigaddset`, `NSIG`", md)       # a type, through its members
        self.assertIn("- 12: `T.==` *inherits*", md)
        self.assertNotIn("T.STUB", md)                          # a stub's name is its C name


if __name__ == "__main__":
    unittest.main()
