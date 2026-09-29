#!/usr/bin/env python3
"""Map C names to the swift-system declarations that wrap them.

Usage: cmap.py [--system DIR] [--ref REF] [REGEX]

Reads the doc comments of System's public declarations (SystemPackage's and SystemSockets'), whose
sentences "The corresponding C function is `fsync`." (and the like for constants, types, errors,
fields, macros and variables, one name or a list) name what each wraps, and prints
`C name -> file:line  [scope] declaration  #if conditions` for every C name the REGEX matches (a
Python regular expression, searched: anchor it for one name, `'^fsync$'`), or for all of them.
These sentences are what adopter-coverage's status.sh counts as covered.

System is the checkout these tools are in, or --system DIR, or $ADOPTER_TOOLS_SYSTEM; its working
tree, or with --ref its sources at a commit (`--ref system-next`), exported once into
$ADOPTER_TOOLS_TMP. The `#if` conditions are the source's, unevaluated: a declaration under
`#if os(Linux)` doesn't exist on Darwin. cfuncs.py finds every mention of a name instead, and
sysapi.sh greps the declarations.
"""

import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

HEAD = re.compile(r"\bThe corresponding C (?:[a-z]+ )*?(?:function|constant|type|error|field|property|macro|variable"
                  r"|structure|struct|union|enumeration|enum|flag|option)s?\s+(?:is|are)\b", re.I)
NAME = re.compile(r"`([^`]+)`")
DOCC_LINK = re.compile(r"``[^`]*``")
NOT_C = {"true", "false", "nil"}


def c_names(doc):
    """The C names a doc comment's corresponding-C sentences give."""
    doc = DOCC_LINK.sub(" ", doc)
    names = []
    for m in HEAD.finditer(doc):
        rest = doc[m.end():]
        # The sentence runs to a period that isn't inside backticks.
        end, tick = len(rest), False
        for k, c in enumerate(rest):
            if c == "`":
                tick = not tick
            elif c == "." and not tick and (k + 1 == len(rest) or rest[k + 1].isspace()):
                end = k
                break
        for n in NAME.findall(rest[:end]):
            n = re.sub(r"^(?:struct|union|enum) ", "", re.sub(r"\(\d*\)$", "", n.strip()))
            if n and n not in NOT_C:
                names.append(n)
    return list(dict.fromkeys(names))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("regex", nargs="?", help="C names to look up (default: every mapping)")
    ap.add_argument("--system", help="a swift-system checkout (default: the one these tools are in)")
    ap.add_argument("--ref", help="read System's sources at this commit instead of its working tree")
    a = ap.parse_args()
    sources, what = common.system_sources(common.system_checkout(a.system), a.ref)
    pattern = re.compile(a.regex) if a.regex else None
    out = []
    for d in common.system_declarations(sources):
        if "orresponding C" not in d.doc:
            continue
        for n in c_names(d.doc):
            if pattern is None or pattern.search(n):
                out.append((n, d.describe(sources)))
    for n, text in sorted(set(out), key=lambda x: (x[0].lower(), x[1])):
        print(f"{n} -> {text}")
    if not out:
        print(f"cmap.py: no corresponding-C sentence in {what} names {a.regex}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
