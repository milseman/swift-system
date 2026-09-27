#!/usr/bin/env python3
"""Keep the SDK's and the Swift libraries' names from an index dump, for
extracting packages that don't build (extract.py --lexical).

The index store of any package's debug build holds every declaration of the
SDK and toolchain modules the build imported, with their kinds. The
lexical rules need exactly that vocabulary to tell a Darwin SDK name from
anything else. The package's own modules and its dependencies' (the index's
units) are left out, since they're another package's.

Usage: vocab.py INDEX.json[.gz] OUT.json.gz [--describe DESCRIBE.json] [--note TEXT]
"""

import sys

sys.dont_write_bytecode = True

import argparse
import gzip
import json
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import load_json  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("index")
    ap.add_argument("out")
    ap.add_argument("--note", default="")
    a = ap.parse_args()
    index = load_json(a.index)
    built = {u["module"].split(".")[0] for u in index["units"] if u.get("module")}
    vocab = {m: names for m, names in index["vocab"].items()
             if m and m.split(".")[0] not in built and not m.startswith("<dependency>/")}
    with gzip.open(a.out, "wt", encoding="utf-8") as f:
        json.dump({"note": a.note, "modules": len(vocab), "vocab": vocab}, f)
    print(f"vocab: {len(vocab)} SDK and toolchain modules, "
          f"{sum(len(v) for v in vocab.values())} names -> {a.out}")


if __name__ == "__main__":
    main()
