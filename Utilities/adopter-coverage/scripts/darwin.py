#!/usr/bin/env python3
"""The Darwin module metric: which of a package's files see the Darwin
module on Darwin, and how.

A Swift file sees Darwin's C names when
  - it imports Darwin itself, in any form: `import Darwin`, `import
    Darwin.C`, `import func Darwin.getpid`, `@preconcurrency import Darwin`,
    `@_exported import Darwin`;
  - another file of its module re-exports Darwin (`@_exported import
    Darwin.C` in NIOPosix/System.swift makes it visible in every NIOPosix
    file, and in every module that imports NIOPosix);
  - it imports a module that re-exports Darwin, directly or through other
    re-exports: one of the package's own, a dependency's (TSCLibc, SWBLibc),
    or the SDK's (Foundation, Dispatch, os, Security and others; see
    probe()).
Each file gets the most direct of those. A package migrating off Darwin
has to remove the first kind and the re-exports; the rest follow.

The interfaces that matter most for a migration are the OS names a file
reaches only through Apple Foundation's re-export: they compile today only
because the file imports Foundation, and they break when it moves to
FoundationEssentials, which re-exports nothing.

Usage (as a module): darwin.analyze(...) from extract.py.
       darwin.py reexports CHECKOUTS_DIR OUT.json
                 the modules each dependency checkout re-exports, from its
                 sources' `@_exported import` lines
"""

import sys

sys.dont_write_bytecode = True

import collections
import json
import os
import re
import subprocess
import tempfile

# The modules Darwin's C library comes from. Swift 6.2's SDK splits part of
# the C library into _DarwinFoundation1-3, which Darwin re-exports.
DARWIN = {"Darwin", "_DarwinFoundation1", "_DarwinFoundation2", "_DarwinFoundation3"}
EXPORTED = re.compile(r"^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*@_exported\s+(?:@[\w.]+(?:\([^)]*\))?\s+)*"
                      r"(?:(?:public|internal|package|private|fileprivate)\s+)?import\s+"
                      r"(?:(?:func|let|var|struct|class|enum|typealias|protocol)\s+)?([A-Za-z_][\w.]*)")
# How a file sees Darwin, most direct first.
CLASSES = ("direct", "module re-export", "package re-export", "Foundation", "SDK re-export")


def is_darwin(module):
    return module.split(".")[0] in DARWIN


def exported_modules(path):
    """The first components of the modules a Swift file re-exports."""
    out = set()
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return out
    for line in text.split("\n"):
        m = EXPORTED.match(line)
        if m:
            out.add(m.group(1).split(".")[0])
    return out


def dependency_reexports(checkouts):
    """{module: [modules it re-exports]} for every Swift target directory
    under each checkout's Sources: a target's module is its directory's
    name, which is its name unless the manifest says otherwise."""
    out = collections.defaultdict(set)
    if not checkouts or not os.path.isdir(checkouts):
        return {}
    for pkg in sorted(os.listdir(checkouts)):
        src = os.path.join(checkouts, pkg, "Sources")
        if not os.path.isdir(src):
            continue
        for target in sorted(os.listdir(src)):
            base = os.path.join(src, target)
            if not os.path.isdir(base):
                continue
            for dirpath, _, files in os.walk(base):
                for f in files:
                    if f.endswith(".swift"):
                        out[target.replace("-", "_")].update(exported_modules(os.path.join(dirpath, f)))
    return {m: sorted(v) for m, v in sorted(out.items()) if v}


def probe(modules, cache_path, swiftc=None):
    """{module: "re-exports" | "no" | "absent"} for SDK modules: whether
    `import M` alone makes getpid() visible. Answers are kept in cache_path
    (keyed by the SDK), since each takes a type-check."""
    cache = {}
    if cache_path and os.path.exists(cache_path):
        cache = json.load(open(cache_path))
    todo = [m for m in sorted(modules) if m not in cache]
    answers = {}
    if todo:
        # Through xcrun, which gives swiftc the SDK.
        cmd = [swiftc] if swiftc else ["xcrun", "swiftc"]
        with tempfile.TemporaryDirectory() as d:
            for m in todo:
                path = os.path.join(d, "probe.swift")
                with open(path, "w") as f:
                    f.write(f"import {m}\nfunc probe() -> Int32 {{ getpid() }}\n")
                r = subprocess.run(cmd + ["-typecheck", path], capture_output=True, text=True)
                if r.returncode == 0:
                    cache[m] = "re-exports"
                elif re.search(r"no such module", r.stderr):
                    cache[m] = "absent"
                elif re.search(r"cannot find 'getpid' in scope", r.stderr):
                    cache[m] = "no"
                else:
                    # The probe itself failed: say so, and don't keep it.
                    answers[m] = "error: " + (r.stderr.strip().split("\n") or [""])[0][:160]
        if cache_path:
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            json.dump(dict(sorted(cache.items())), open(cache_path, "w"), indent=1)
    return {m: answers.get(m) or cache.get(m, "no") for m in modules}


def darwin_active(scan, line):
    st = scan["states"][line - 1] if 0 < line <= len(scan["states"]) else None
    return bool(st) and "Darwin" in st


def analyze(root, swift_scans, interfaces, own_modules, dep_modules, dep_reexports, sdk_probe, foundation,
            swift_libs, system_modules):
    """The `darwin` section of interfaces.json.

    swift_scans: swift_scan results by path, with "target" (c99 name) and
    "imports"; interfaces: the extraction's; dep_reexports: {module:
    [modules]} from the dependencies' sources; sdk_probe(modules) ->
    {module: answer}."""
    files = {}
    own_exports = collections.defaultdict(set)     # own module -> modules its files re-export
    imported = set()
    for rel, sc in sorted(swift_scans.items()):
        raw = open(os.path.join(root, rel), encoding="utf-8", errors="replace").read().split("\n")
        direct, exports, mods = [], set(), set()
        for line, kw, module, name in sc["imports"]:
            if not darwin_active(sc, line):
                continue
            text = raw[line - 1] if 0 < line <= len(raw) else ""
            top = module.split(".")[0]
            mods.add(top)
            if EXPORTED.match(text):
                exports.add(top)
            if is_darwin(top):
                direct.append({"line": line, "text": text.strip()[:120]})
        files[rel] = {"target": sc["target"], "direct": direct, "exports": sorted(exports), "imports": sorted(mods)}
        own_exports[sc["target"]].update(exports)
        imported.update(mods)

    # Which modules re-export Darwin, through any chain of re-exports.
    edges = {m: set(v) for m, v in dep_reexports.items()}
    for m, v in own_exports.items():
        edges.setdefault(m, set()).update(v)
    sdk = sorted(m for m in imported | {x for v in edges.values() for x in v}
                 if m not in own_modules and m not in dep_modules and m not in edges and not is_darwin(m)
                 and m not in swift_libs and m not in system_modules and m not in foundation - {"Foundation"})
    answers = sdk_probe(sdk) if sdk else {}
    memo = {}

    def chain(m, seen=()):
        """The re-export chain from m to Darwin, or None."""
        if is_darwin(m):
            return [m]
        if m in memo:
            return memo[m]
        if m in seen:
            return None
        memo[m] = None
        if answers.get(m) == "re-exports":
            memo[m] = [m, "Darwin"]
            return memo[m]
        for x in sorted(edges.get(m, ())):
            c = chain(x, seen + (m,))
            if c:
                memo[m] = [m] + c
                break
        return memo[m]

    for rel, f in files.items():
        via = {}
        for m in f["imports"]:
            if m == f["target"] or is_darwin(m):
                continue
            c = chain(m)
            if c:
                via[m] = c
        own_chain = chain(f["target"]) if f["target"] in own_exports and own_exports[f["target"]] else None
        f["via"] = {m: " > ".join(c) for m, c in sorted(via.items())}
        if f["direct"]:
            cls = "direct"
        elif own_chain:
            cls = "module re-export"
        elif any(m in own_modules or m in dep_modules or m in dep_reexports for m in via):
            cls = "package re-export"
        elif "Foundation" in via:
            cls = "Foundation"
        elif via:
            cls = "SDK re-export"
        else:
            cls = None
        f["class"] = cls
        f["reexportsDarwin"] = bool(f["exports"]) and any(chain(m) for m in f["exports"])

    # OS names of Darwin's C library, by how the files that use them see
    # Darwin: an interface used on Darwin only in files that see it through
    # Foundation compiles only because of Foundation's re-export.
    by_class = collections.defaultdict(list)
    for it in interfaces:
        mods = it.get("darwinModules") or []
        darwin_sites = [s for s in it["sites"] if "Darwin" in s["platforms"] and s["file"] in files]
        if not darwin_sites:
            continue
        if mods and not any(is_darwin(m) for m in mods):
            continue
        if not mods and "lexical-darwin-name" not in it["evidence"] and "index" not in it["evidence"]:
            continue
        classes = {files[s["file"]]["class"] for s in darwin_sites}
        best = next((c for c in CLASSES if c in classes), None)
        by_class[best or "unknown"].append({"name": it["name"], "sites": len(darwin_sites),
                                            "files": sorted({s["file"] for s in darwin_sites})[:6]})

    counts = collections.Counter(f["class"] for f in files.values())
    reexport_shims = sorted(rel for rel, f in files.items() if f["reexportsDarwin"])
    return {
        "files": files,
        "summary": {
            "swiftFiles": len(files),
            "direct": counts["direct"],
            "reexportShims": len(reexport_shims),
            "byClass": {c: counts[c] for c in CLASSES if counts[c]},
            "noDarwin": counts[None],
            "interfacesByClass": {c: len(v) for c, v in by_class.items()},
        },
        "reexportShims": reexport_shims,
        "reexportModules": {m: " > ".join(chain(m)) for m in sorted(set(edges) | set(answers)) if chain(m)},
        "sdkProbe": answers,
        "interfacesByClass": {c: sorted(v, key=lambda x: (-x["sites"], x["name"])) for c, v in by_class.items()},
    }


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "reexports":
        json.dump(dependency_reexports(sys.argv[2]), open(sys.argv[3], "w"), indent=1)
        return 0
    sys.exit(__doc__)


if __name__ == "__main__":
    sys.exit(main())
