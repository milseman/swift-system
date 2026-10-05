#!/usr/bin/env python3
"""Tests of the high-value carve-outs (value.py): which packages are the
update-checkout cluster's, the three tests, the ranking, and the section,
from a text fixture of suggestions.json. Nothing is read or written on
disk, and nothing reaches the network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-graph/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import copy  # noqa: E402
import os  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import value  # noqa: E402

SCHEME = """swift-nio\t2.92.2\tapple/swift-nio\t
swiftpm\tmain\tswiftlang/swift-package-manager\t
swift-foundation\tmain\tswiftlang/swift-foundation\t
"""


def unit(id, nodes=("n",), direct=(), inherited=(), parts=()):
    return {"id": id, "nodes": list(nodes), "direct": list(direct),
            "inherited": {k: {"through": "api"} for k in inherited}, "parts": list(parts)}


def cand(id, decls, rank, score, kind="cluster", **sites):
    return {"id": id, "kind": kind, "name": id, "declarations": decls, "rank": rank, "score": score,
            "adopters": {"byPackage": {k.replace("_", "-"): {"adopted": a, "benefit": b} for k, (a, b) in sites.items()}}}


DOC = {
    "config": {"valueSize": [3, 60]},
    "promoted": [{"type": "ProcessID", "id": "s:ProcessID", "cluster": "vocab"}],
    "adopterPackages": [{"key": "swift-nio", "name": "swift-nio", "remote": "apple/swift-nio"},
                        {"key": "swift-package-manager", "name": "swift-package-manager",
                         "remote": "swiftlang/swift-package-manager"},
                        {"key": "vapor", "name": "vapor", "remote": "vapor/vapor"}],
    "clusters": [
        unit("small"), unit("open", direct=["owned"]), unit("inherits", inherited=["typed-throws"]),
        unit("vocab", nodes=("s:ProcessID", "m")), unit("big"), unit("tiny"), unit("server"), unit("edge"),
        unit("whole", parts=[unit("whole-1"), unit("whole-2")]),
        unit("split", direct=["span"], parts=[unit("split-1"), unit("split-2", direct=["span"])]),
    ],
    "batches": [],
    "candidates": [
        cand("small", 10, 1, 2.0, swift_nio=(2, 3)),
        cand("open", 10, 2, 101.0, swift_nio=(9, 9)),
        cand("inherits", 10, 3, 61.0, swift_nio=(9, 9)),
        cand("vocab", 10, 4, 3.0, swift_nio=(9, 9)),
        cand("big", 61, 5, 61.0, swift_nio=(9, 9)),
        cand("tiny", 2, 6, 2.0, swift_nio=(9, 9)),
        cand("server", 10, 7, 2.0, vapor=(9, 9)),
        cand("edge", 3, 8, 3.0, swift_package_manager=(0, 5)),
        cand("whole", 40, 9, 40.0, swift_nio=(1, 1)),
        cand("whole-1", 20, 10, 20.0, kind="part", swift_nio=(1, 0)),
        cand("whole-2", 20, 11, 20.0, kind="part", swift_nio=(0, 1)),
        cand("split", 40, 12, 140.0, swift_nio=(4, 4)),
        cand("split-1", 20, 13, 20.0, kind="part", swift_nio=(0, 5)),
        cand("split-2", 20, 14, 120.0, kind="part", swift_nio=(4, 0)),
    ],
}


class ClusterTests(unittest.TestCase):
    def test_packages_by_remote_then_name(self):
        keys = value.cluster_keys(value.parse_scheme(SCHEME), DOC["adopterPackages"])
        self.assertEqual(keys, {"swift-nio": "swift-nio", "swift-package-manager": "swiftpm"})

    def test_scheme_parsing(self):
        self.assertEqual(value.parse_scheme("# comment\n\nzlib\tv1.3.1\tmadler/zlib\n"), [("zlib", "madler/zlib")])


class TestTests(unittest.TestCase):
    def setUp(self):
        self.rows, self.every, self.size = value.rank(copy.deepcopy(DOC), value.parse_scheme(SCHEME))

    def test_each_test(self):
        e = self.every
        self.assertTrue(e["small"]["pass"])
        self.assertEqual(e["small"]["adopter"], [("swift-nio", 2, 3)])
        self.assertEqual(e["small"]["sites"], 5)
        self.assertFalse(e["open"]["passPattern"])        # an open question of its own
        self.assertFalse(e["inherits"]["passPattern"])    # one through what it needs
        self.assertEqual(e["vocab"]["vocabulary"], ["ProcessID"])
        self.assertFalse(e["vocab"]["passPattern"])       # a new shared vocabulary type
        self.assertFalse(e["big"]["passSize"])
        self.assertFalse(e["tiny"]["passSize"])
        self.assertTrue(e["edge"]["passSize"])            # the bounds are inclusive
        self.assertFalse(e["server"]["passAdopter"])      # vapor isn't in the scheme
        self.assertEqual(self.size, (3, 60))

    def test_ranking(self):
        # By update-checkout sites, then score; a passing cluster's parts aren't rows,
        # a failing one's passing parts are.
        self.assertEqual([t["id"] for t in self.rows], ["small", "edge", "split-1", "whole"])
        whole = next(t for t in self.rows if t["id"] == "whole")
        self.assertEqual(whole["partsPassing"], ["whole-1", "whole-2"])
        self.assertEqual(next(t for t in self.rows if t["id"] == "split-1")["cluster"], "split")

    def test_size_from_config(self):
        doc = copy.deepcopy(DOC)
        doc["config"]["valueSize"] = [1, 100]
        rows, every, size = value.rank(doc, value.parse_scheme(SCHEME))
        self.assertEqual(size, (1, 100))
        self.assertTrue(every["big"]["pass"] and every["tiny"]["pass"])

    def test_section(self):
        lines = []
        value.section(lines.append, copy.deepcopy(DOC), value.parse_scheme(SCHEME))
        text = "\n".join(lines)
        self.assertTrue(text.startswith("## High-value carve-outs"))
        self.assertIn("| 1 | [`small`](suggestions/small/bundle.md) | cluster | 10 | 5 | swift-nio 5 (2 used) | 1 | 2.0 |",
                      text)
        self.assertIn("part of `split`", text)
        self.assertIn("2 of its parts too", text)
        self.assertIn("- `open` (cluster, 18 sites: swift-nio 18 (9 used)): open questions: owned.", text)
        self.assertIn("- `vocab` (cluster, 18 sites: swift-nio 18 (9 used)): shared vocabulary: `ProcessID`.", text)


if __name__ == "__main__":
    unittest.main()
