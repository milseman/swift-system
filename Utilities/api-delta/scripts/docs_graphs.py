#!/usr/bin/env python3
"""Prepare symbol graphs for DocC.

Copies the `<Module>.symbols.json` and `<Module>@*.symbols.json` files for one
module from SRC to DEST, rewriting availability so DocC's badges show the
availability as spelled in the sources:

  - the `OpenBSD x.y` marker domain (see patch_manifest.py) becomes a
    `System x.y` domain, which DocC renders like a platform;
  - OS entries that merely repeat what every `System` macro expands to in the
    default build (macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0)
    are dropped, so explicit OS floors such as `macOS 15` remain visible.

Usage: docs_graphs.py SRC DEST MODULE
"""

import glob
import json
import os
import shutil
import sys

SOURCE_AVAILABILITY = {"macOS": "10.10", "iOS": "8.0", "watchOS": "2.0", "tvOS": "9.0", "visionOS": "1.0"}


def vtuple(v):
    parts = [v.get("major", 0), v.get("minor", 0), v.get("patch", 0)]
    return tuple(parts)


def default_tuple(s):
    parts = [int(p) for p in s.split(".")] + [0, 0]
    return tuple(parts[:3])


def rewrite(entries):
    out = []
    for e in entries:
        d = e.get("domain")
        if d == "OpenBSD":
            e = dict(e, domain="System")
        elif d in SOURCE_AVAILABILITY and set(e) <= {"domain", "introduced"} \
                and vtuple(e.get("introduced", {})) == default_tuple(SOURCE_AVAILABILITY[d]):
            continue
        out.append(e)
    return out


def main():
    src, dest, module = sys.argv[1:4]
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    files = [os.path.join(src, f"{module}.symbols.json")] + sorted(glob.glob(os.path.join(src, f"{module}@*.symbols.json")))
    for path in files:
        g = json.load(open(path))
        for s in g["symbols"]:
            if "availability" in s:
                s["availability"] = rewrite(s["availability"])
                if not s["availability"]:
                    del s["availability"]
        json.dump(g, open(os.path.join(dest, os.path.basename(path)), "w"))
    print(f"docs_graphs: {module}: {len(files)} files -> {dest}")


if __name__ == "__main__":
    main()
