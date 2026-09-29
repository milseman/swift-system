#!/usr/bin/env python3
"""List the free-function calls in a package's Swift sources that the package doesn't declare.

Usage: freefuncs.py [--min N] [--all] PACKAGE [SUBDIR...]

Counts the calls `name(` that aren't members (`.name(`), in the Swift files under the SUBDIRs
(default: the whole package, without Fixtures), whose names no Swift file of the package declares
(as a function, type, case, variable, parameter or closure argument) and that aren't in a list of
standard library, Foundation, Dispatch, XCTest and Swift Testing functions. What's left are the
candidates for C library calls reached through an import (Darwin, Foundation's re-export, a C
shim), and the package's C targets' functions, which --all lists too. Most used first, with the
first places each is called. Comments and string literals are skipped (interpolations aren't).
It reads the working tree; it can't tell a C function from a Swift one it doesn't know, so check
each with darwin_audit.py or by reading.
"""

import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

STD = set('''print debugPrint dump min max abs precondition preconditionFailure assert assertionFailure fatalError
zip stride sequence repeatElement type withExtendedLifetime withUnsafePointer withUnsafeMutablePointer withUnsafeBytes
withUnsafeMutableBytes withUnsafeTemporaryAllocation withoutActuallyEscaping unsafeBitCast unsafeDowncast numericCast
swap isKnownUniquelyReferenced readLine withTaskGroup withThrowingTaskGroup withCheckedContinuation
withCheckedThrowingContinuation withUnsafeContinuation withUnsafeThrowingContinuation withTaskCancellationHandler
withDiscardingTaskGroup withThrowingDiscardingTaskGroup withTaskPriorityEscalationHandler autoreleasepool
NSLocalizedString NSStringFromClass NSClassFromString NSTemporaryDirectory NSHomeDirectory NSUserName NSFullUserName
NSSearchPathForDirectoriesInDomains XCTAssert XCTAssertEqual XCTAssertNotEqual XCTAssertTrue XCTAssertFalse XCTAssertNil
XCTAssertNotNil XCTFail XCTAssertThrowsError XCTAssertNoThrow XCTUnwrap XCTSkip XCTSkipIf XCTSkipUnless
XCTAssertGreaterThan XCTAssertGreaterThanOrEqual XCTAssertLessThan XCTAssertLessThanOrEqual XCTAssertEqualWithAccuracy
XCTExpectFailure XCTAssertIdentical XCTAssertNotIdentical XCTAssertNotEqualWithAccuracy expect require confirmation
withKnownIssue init self super some any if switch for while guard return try await catch repeat do defer is as let var
case in where throw throws rethrows consume copy borrowing consuming isolated sending get set willSet didSet
subscript private fileprivate internal public open package inout deinit operator extension mutating nonmutating
nonisolated async lazy weak unowned
dispatchPrecondition __dispatch_precondition CFGetTypeID CFStringGetTypeID CFBooleanGetTypeID CFBooleanGetValue
CFNumberGetTypeID CFRunLoopGetCurrent CFRunLoopRun CFRunLoopStop CFRelease CFRetain getVaList withVaList
_isDebugAssertConfiguration _getUnsafePointerToStoredProperties'''.split())
DECLARED = [
    re.compile(r'\b(?:func|init|case|var|let|class|struct|enum|actor|typealias|protocol|macro|associatedtype)\s+`?(\w+)'),
    re.compile(r'\b(\w+)\s*:\s*(?:@escaping\s+|@Sendable\s+|@autoclosure\s+|inout\s+|borrowing\s+|consuming\s+)*\('),
    re.compile(r'\blet\s+\(([^)]*)\)'),
]
CALL = re.compile(r'(?<![\w.$#@])([a-z_][A-Za-z0-9_]*)\s*\(')
FUNC_BEFORE = re.compile(r'\bfunc\s+$')
DIRECTIVE = re.compile(r'\s*#(?:if|elseif)\b')
C_DECL = re.compile(r'^(?!return\b|if\b|while\b|for\b|switch\b|#)[A-Za-z_][\w \t*]*?[\s*](\w+)\s*\(', re.M)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("package")
    ap.add_argument("subdirs", nargs="*", metavar="SUBDIR")
    ap.add_argument("--min", type=int, default=1, help="only names called at least this often")
    ap.add_argument("--all", action="store_true", help="also list names a C target of the package declares")
    a = ap.parse_args()
    root = os.path.abspath(a.package)
    everything = common.swift_files(root)
    scanned = common.swift_files(root, paths=a.subdirs or None)
    if not a.subdirs:
        scanned = [f for f in scanned if "/Fixtures/" not in f"/{f}"]
    texts = {f: common.blank_swift(t) for f, t in common.read_sources(root, everything).items()}
    declared = set()
    for t in texts.values():
        for pattern in DECLARED:
            for m in pattern.findall(t):
                declared.update(n.strip() for n in m.split(","))
    c_declared = set()
    if not a.all:
        # The package's own C functions: declared or defined at the top level of its headers (an
        # unindented line with a return type before the name).
        for f in common.swift_files(root, extensions=(".h",)):
            try:
                with open(os.path.join(root, f), encoding="utf-8", errors="replace") as h:
                    c_declared.update(C_DECL.findall(h.read()))
            except OSError:
                pass
    hits = {}
    for f in scanned:
        for i, line in enumerate(texts[f].split("\n")):
            if DIRECTIVE.match(line):
                continue            # `#if os(Linux)` isn't a call
            for m in CALL.finditer(line):
                n = m.group(1)
                if n in STD or n in declared or n in c_declared or FUNC_BEFORE.search(line[:m.start()]):
                    continue
                hits.setdefault(n, []).append(f"{f}:{i + 1}")
    for n, locs in sorted(hits.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        if len(locs) >= a.min:
            print(f"{n:28} {len(locs):4}  {', '.join(locs[:4])}{' ...' if len(locs) > 4 else ''}")


if __name__ == "__main__":
    main()
