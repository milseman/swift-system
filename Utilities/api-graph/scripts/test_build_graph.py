#!/usr/bin/env python3
"""Tests of the kinds build_graph.py gives scan-only declarations
(scan_kind), the ones only api-delta's source scan sees, such as API that
compiles only off Darwin: a Swift text fixture is scanned with api-delta's
own scanner, in a temporary directory that the tests remove, and each
declaration's kind is checked against the kind Swift 6.2's symbol graphs
(swiftc -emit-symbol-graph) give the same source. Nothing reaches the
network.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/api-graph/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_graph  # noqa: E402

SOURCE = "\n".join([
    "public struct Moment: Comparable {",
    "  public var ticks: Int",
    "  public static func < (lhs: Moment, rhs: Moment) -> Bool { lhs.ticks < rhs.ticks }",
    "  public static func ==(lhs: Moment, rhs: Moment) -> Bool { lhs.ticks == rhs.ticks }",
    "  public static func ~= (pattern: Moment, value: Moment) -> Bool { pattern == value }",
    "  public static func now() -> Moment { Moment(ticks: 0) }",
    "  public static var zero: Moment { Moment(ticks: 0) }",
    "  public static subscript(ticks: Int) -> Moment { Moment(ticks: ticks) }",
    "  public subscript(scale: Int) -> Int { ticks * scale }",
    "  public func later() -> Moment { self }",
    "  public init(ticks: Int) { self.ticks = ticks }",
    "}",
    "public final class Clock {",
    "  public class func shared() -> Clock { Clock() }",
    "  public class var name: String { \"c\" }",
    "}",
    "public enum Unit {",
    "  case second",
    "}",
    "public typealias Ticks = Int",
    "public func ==(lhs: Clock, rhs: Clock) -> Bool { lhs === rhs }",
    "prefix operator √",
    "public prefix func √(x: Moment) -> Moment { x }",
    "public func tick() {}",
    "",
])

# What the symbol graphs say, in the order the scan finds the declarations.
# The scanner reports declarations with an access modifier, which an enum
# case can't have, so `case second` isn't among them, nor `prefix operator`.
SYMBOL_GRAPH_KINDS = [
    ("Moment", "swift.struct"), ("Moment.ticks", "swift.property"), ("Moment.<", "swift.func.op"),
    ("Moment.==", "swift.func.op"), ("Moment.~=", "swift.func.op"), ("Moment.now", "swift.type.method"),
    ("Moment.zero", "swift.type.property"), ("Moment.subscript", "swift.type.subscript"),
    ("Moment.subscript", "swift.subscript"), ("Moment.later", "swift.method"), ("Moment.init", "swift.init"),
    ("Clock", "swift.class"), ("Clock.shared", "swift.type.method"), ("Clock.name", "swift.type.property"),
    ("Unit", "swift.enum"), ("Ticks", "swift.typealias"),
    ("==", "swift.func.op"), ("√", "swift.func.op"), ("tick", "swift.func"),
]


class ScanKindTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="api-graph-scan-kind-")
        os.makedirs(os.path.join(self.root, "Sources", "System"))
        with open(os.path.join(self.root, "Sources", "System", "Moment.swift"), "w") as f:
            f.write(SOURCE)
        self.found, _, _ = build_graph.ss.scan_file(self.root, "Sources/System/Moment.swift", "SystemPackage")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_kinds_are_the_symbol_graphs(self):
        got = [(".".join(d["scopes"] + [d["name"].split("(", 1)[0].strip()]), build_graph.scan_kind(d))
               for d in self.found]
        self.assertEqual(got, SYMBOL_GRAPH_KINDS)

    def test_the_scanners_operator_names(self):
        # `static func <` is `< ()` to the scanner; `==` keeps its labels.
        names = {d["name"] for d in self.found if d["kw"] == "func"}
        self.assertIn("< ()", names)
        self.assertIn("==(lhs:rhs:)", names)

    def test_names(self):
        def kind(name, modifiers=("public", "static"), scopes=("T",)):
            return build_graph.scan_kind({"kw": "func", "name": name, "scopes": list(scopes),
                                          "modifiers": list(modifiers)})
        self.assertEqual(kind("< ()"), "swift.func.op")
        self.assertEqual(kind("..<(_:_:)"), "swift.func.op")
        self.assertEqual(kind("√(_:)", ("public", "prefix"), ()), "swift.func.op")
        self.assertEqual(kind("`default`()"), "swift.type.method")
        self.assertEqual(kind("_unsafe()", ("public",)), "swift.method")
        # A top-level var stays a property: the scanner can lose a scope.
        self.assertEqual(build_graph.scan_kind({"kw": "var", "name": "x", "scopes": [], "modifiers": ["public"]}),
                         "swift.property")


if __name__ == "__main__":
    unittest.main()
