#!/usr/bin/env python3
"""Convention checks for swift-system and its adopters, each a separate
check behind one entry point.

Usage: lint.py [CHECK...] [--json] [--clone PATH...] [--branch B] [--base REF]
               [--system REF] [--api-delta DIR] [--no-run] [--graph FILE]
               [--pitches DIR] [--rules]

Checks (default: all):
  cmake         every Sources/System and Sources/SystemWinSocks Swift file is in its CMakeLists.txt
  api           api-delta's added declarations (main..HEAD): availability, doc
                sentences, @_alwaysEmitIntoClient constants, typed throws,
                C-struct stored properties
  markers       SYSTEM-GAP markers on adopter branches: their form, and the
                stale ones System now covers
  conditionals  new platform conditionals on an adopter branch that call
                System in one arm and C in another
  pitches       Prototype/Pitches against the api-graph output: overlaps,
                missing declarations, prerequisites in no pitch

Each finding is printed as `file:line: rule: message`. Exit status: 0 with
no error-level finding, 1 with one, 2 when a check couldn't run (a summary
on standard error says which). `--rules` lists every rule with its level.
allowlist.ini holds the api check's allowed exceptions, each with a reason.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from lintcore import CheckError, Context  # noqa: E402

CHECKS = ("cmake", "api", "markers", "conditionals", "pitches")


def load_check(name):
    import importlib
    return importlib.import_module(f"check_{name}")


def rules():
    out = []
    for name in CHECKS:
        mod = load_check(name)
        for rule, level, what in mod.RULES:
            out.append((rule, level, what))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("checks", nargs="*", help=f"any of {', '.join(CHECKS)} (default: all)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--clone", action="append", default=[], help="an adopter clone (markers, conditionals); "
                    "default: every clone in ../adopters")
    ap.add_argument("--branch", help="the adopter branch (default: its newest migration branch)")
    ap.add_argument("--base", default="main", help="conditionals: the adopter's base, compared at its merge base "
                    "with the branch (default main)")
    ap.add_argument("--system", default="system-next", help="the System commit markers are checked against")
    ap.add_argument("--api-delta", help="api-delta's output for main..HEAD (default .build/api-delta, if it is)")
    ap.add_argument("--no-run", action="store_true", help="api: don't run api-delta when its output isn't current")
    ap.add_argument("--graph", help="pitches: api-graph's graph.json.gz (default .build/api-graph's, else the "
                    "snapshot store's for HEAD)")
    ap.add_argument("--pitches", help="pitches: the pitch files (default Prototype/Pitches)")
    ap.add_argument("--rules", action="store_true", help="list the rules and their levels")
    args = ap.parse_args(argv)
    if args.rules:
        for rule, level, what in rules():
            print(f"{rule:32} {level:8} {what}")
        return 0
    unknown = [c for c in args.checks if c not in CHECKS]
    if unknown:
        ap.error(f"unknown check(s) {', '.join(unknown)}; the checks are {', '.join(CHECKS)}")
    ctx = Context(args)
    findings, failed = [], []
    for name in args.checks or CHECKS:
        try:
            got = load_check(name).run(ctx)
        except CheckError as e:
            failed.append((name, str(e)))
            continue
        findings += got
    findings.sort(key=lambda f: (f.rule.split("/")[0], f.file, f.line, f.rule))
    if args.json:
        json.dump({"head": ctx.head, "findings": [f.as_json() for f in findings], "notes": ctx.notes,
                   "failed": [{"check": n, "why": w} for n, w in failed]}, sys.stdout, indent=1)
        print()
    else:
        for f in findings:
            print(f.text())
    counts = collections.Counter((f.rule, f.level) for f in findings)
    for n in ctx.notes:
        print(f"lint: {n}", file=sys.stderr)
    for n, w in failed:
        print(f"lint: {n} didn't run: {w}", file=sys.stderr)
    errors = sum(v for (r, lv), v in counts.items() if lv == "error")
    warnings = sum(v for (r, lv), v in counts.items() if lv == "warning")
    detail = ", ".join(f"{r} {v}" for (r, lv), v in sorted(counts.items()))
    print(f"lint: {errors} errors, {warnings} warnings" + (f" ({detail})" if detail else ""), file=sys.stderr)
    if failed:
        return 2
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
