#!/usr/bin/env python3
"""Find the swift-system declarations that mention C names, or are named for them.

Usage: cfuncs.py [--system DIR] [--ref REF] NAME [NAME...]

For each NAME, prints the public declarations of System (SystemPackage and SystemSockets) whose doc
comment has NAME in backticks (`fsync`, `fsync()`, `fsync(2)`, `struct stat`), in a corresponding-C sentence or
anywhere else, or whose own name is NAME:
`NAME  file:line  [scope] declaration  #if conditions`, with the signature on one line.

It casts wider than cmap.py, which reads only the corresponding-C sentences: a declaration that
mentions `fsync` while documenting something else shows here too. System is found as for cmap.py
(--system, $ADOPTER_TOOLS_SYSTEM, or the checkout these tools are in; --ref for a commit).
"""

import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

OWN = r"\b(?:func|var|let|case|struct|enum|class|typealias|actor|protocol)\s+`?{}`?\b"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("names", nargs="+", metavar="NAME")
    ap.add_argument("--system", help="a swift-system checkout (default: the one these tools are in)")
    ap.add_argument("--ref", help="read System's sources at this commit instead of its working tree")
    a = ap.parse_args()
    sources, what = common.system_sources(common.system_checkout(a.system), a.ref)
    mentions = [(n, re.compile(r"`(?:struct |union |enum )?" + re.escape(n) + r"(?:\(\d*\))?`"),
                 re.compile(OWN.format(re.escape(n))))
                for n in a.names]
    found = set()
    for d in common.system_declarations(sources):
        hit = [n for n, mention, own in mentions if mention.search(d.doc) or own.search(d.signature)]
        if hit:
            found.update(hit)
            print(f"{','.join(hit)}  {d.describe(sources)}")
    missing = [n for n in a.names if n not in found]
    if missing:
        print(f"cfuncs.py: nothing in {what} mentions {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
