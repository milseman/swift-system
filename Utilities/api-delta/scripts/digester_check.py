#!/usr/bin/env python3
"""Cross-check the symbol-graph delta with swift-api-digester.

For each module and side, dumps the module's API with
`swift-api-digester -dump-sdk`. It then reconciles the declarations the
digester sees added and removed with the symbol-graph delta, by USR, and runs
`-diagnose-sdk` for modules present on both sides, which lists breaking
changes.

The digester also reports implicit declarations (associated-type aliases,
`hashValue`, synthesized `Codable` members) and underscored ones, which the
symbol graphs omit by design. Those are reported separately, not as
mismatches.

Usage: digester_check.py WORK DELTA.json OUT.json
  WORK is regenerate.sh's scratch directory ($WORK/{base,head}/build, /src).
"""

import collections
import glob
import json
import os
import platform
import subprocess
import sys

MODULES = ["SystemPackage", "SystemSockets"]
SKIP_KINDS = {"Accessor", "TypeNominal", "TypeNameAlias", "TypeFunc", "Import"}


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True)


def walk(node, out, path=()):
    for c in node.get("children", []):
        kind = c.get("kind")
        name = c.get("printedName") or c.get("name")
        if c.get("usr") and kind not in SKIP_KINDS:
            out.setdefault(c["usr"], {
                "path": ".".join(path + (name,)),
                "kind": c.get("declKind") or kind,
                "implicit": c.get("implicit", False),
                "module": c.get("moduleName"),
            })
        if kind == "TypeDecl":
            walk(c, out, path + (name,))


def main():
    work, delta_path, out_path = sys.argv[1:4]
    sdk = sh("xcrun", "--sdk", "macosx", "--show-sdk-path").stdout.strip()
    sdk_version = sh("xcrun", "--sdk", "macosx", "--show-sdk-version").stdout.strip()
    target = f"{platform.machine()}-apple-macosx{sdk_version}"
    delta = json.load(open(delta_path))
    graph_added = collections.defaultdict(set)
    graph_removed = collections.defaultdict(set)
    for e in delta["entries"]:
        if e["status"] == "added":
            graph_added[e["module"]].add(e["usr"])
        elif e["status"] == "removed":
            graph_removed[e["module"]].add(e["usr"])

    dumps = {}
    errors = []
    for side in ("base", "head"):
        mods_dir = next(iter(glob.glob(os.path.join(work, side, "build", "*", "debug", "Modules"))), None)
        for m in MODULES:
            if not mods_dir or not os.path.exists(os.path.join(mods_dir, f"{m}.swiftmodule")):
                continue
            out = os.path.join(work, f"{side}-{m}.api.json")
            r = sh("xcrun", "swift-api-digester", "-dump-sdk", "-module", m,
                   "-I", mods_dir, "-I", os.path.join(work, side, "src", "Sources", "CSystem", "include"),
                   "-sdk", sdk, "-target", target, "-o", out, "-abort-on-module-fail")
            if r.returncode != 0 or not os.path.getsize(out):
                errors.append(f"{side} {m}: {r.stderr.strip()[-300:]}")
                continue
            decls = {}
            walk(json.load(open(out))["ABIRoot"], decls)
            dumps[(side, m)] = {u: d for u, d in decls.items() if d["module"] == m}

    result = {"target": target, "errors": errors, "modules": {}}
    for m in MODULES:
        if ("head", m) not in dumps:
            continue
        b = dumps.get(("base", m), {})
        h = dumps[("head", m)]
        added = set(h) - set(b)
        removed = set(b) - set(h)
        only_dig = added - graph_added[m]
        info = {
            "digesterAdded": len(added),
            "digesterRemoved": sorted(b[u]["path"] for u in removed),
            "graphAdded": len(graph_added[m]),
            "graphAddedMissingFromDigester": sorted(graph_added[m] - added),
            "digesterOnlyImplicit": len([u for u in only_dig if h[u]["implicit"]]),
            "digesterOnlyExplicit": sorted(h[u]["path"] for u in only_dig if not h[u]["implicit"]),
            "diagnoseSdk": None,
        }
        if ("base", m) in dumps:
            report = os.path.join(work, f"digester-{m}.txt")
            sh("xcrun", "swift-api-digester", "-diagnose-sdk",
               "-input-paths", os.path.join(work, f"base-{m}.api.json"),
               "-input-paths", os.path.join(work, f"head-{m}.api.json"), "-o", report)
            lines = open(report).read().splitlines() if os.path.exists(report) else None
            info["diagnoseSdk"] = None if lines is None else [
                l for l in lines if l.strip() and not l.startswith("/*")]
        result["modules"][m] = info
    json.dump(result, open(out_path, "w"), indent=1)
    for m, i in result["modules"].items():
        print(f"digester_check: {m}: digester +{i['digesterAdded']} -{len(i['digesterRemoved'])}, "
              f"graphs +{i['graphAdded']}, digester-only explicit {i['digesterOnlyExplicit']}, "
              f"breaking {i['diagnoseSdk']}")
    for e in errors:
        print("digester_check: error:", e)


if __name__ == "__main__":
    main()
