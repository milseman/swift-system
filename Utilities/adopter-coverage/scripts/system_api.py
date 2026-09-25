#!/usr/bin/env python3
"""Find System declarations to cite in mapping.ini.

Prints each public declaration whose name, scope or text matches a regular
expression, in the form a mapping entry's `system` key takes
(`Scope: declaration`), with where it compiles and its availability.

Usage: system_api.py [--system system-api.json] [--all] REGEX...
       (the default is the last run's .build/adopter-coverage/system-api.json)
"""

import sys

sys.dont_write_bytecode = True

import argparse
import json
import os
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402

ABBREV = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
          "Windows": "N"}


def main():
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.normpath(os.path.join(here, "..", "..", ".."))
    ap.add_argument("--system", default=os.path.join(repo, ".build", "adopter-coverage", "system-api.json"))
    ap.add_argument("--all", action="store_true", help="include underscored (@usableFromInline) declarations")
    ap.add_argument("patterns", nargs="+")
    args = ap.parse_args()
    api = check.SystemAPI(json.load(open(args.system)))
    pats = [re.compile(p) for p in args.patterns]
    seen = set()
    for entries in api.by_key.values():
        for e in entries:
            text = f"{e['scope']}: {e['declaration']}" if e["scope"] else e["declaration"]
            if e["unavailable"] or text in seen or not any(p.search(text) for p in pats):
                continue
            if not args.all and e["name"].startswith("_"):
                continue
            seen.add(text)
            av = e["availability"]
            bits = [f"System {av['system']}" if av.get("system") else "no @available"] + av.get("os", [])
            plats = " ".join(ABBREV[p] for p in e["platforms"] if p in ABBREV)
            print(f"{text}\n    {e['module']} {e['file']}:{e['line']} [{plats}] {', '.join(bits)}")


if __name__ == "__main__":
    main()
