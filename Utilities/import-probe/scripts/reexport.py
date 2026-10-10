#!/usr/bin/env python3
"""The re-export run (probe.py --reexport): the names a package gets only
through an `@_exported import` of a C module, such as NIOPosix's of Glibc.

In probe.py's scratch copy of the package and its dependencies:

  1. The copy is built as it is (the baseline, `--build-tests`).
  2. Every `@_exported import` of a modules.ini [count] module, in the
     package and in its dependencies' exports, becomes a plain import. A
     re-export serves its whole module, so each other file of the
     re-exporting target gets the import first: the module builds as
     before, and only its clients lose the C module. A re-export the
     platform doesn't compile (adopter-coverage's `#if` evaluator; a maybe
     counts) gives nothing, and none at all means nothing is built.
  3. The copy is built again, until no file has new errors: SwiftPM stops
     at a failed target and builds nothing that depends on one, so each
     file with errors gets the C import first and the build is repeated.
     Errors in the package's own targets' files, less the baseline's, are
     the names it gets only through a re-export. A dependency's file that
     fails (swift-nio's _NIOFileSystem, which reaches the C library through
     NIOPosix, or a nested package's root package, whose own names are its
     own run's) gets the import too, uncounted.

The C import added is the demoted ones the platform compiles, each under
`#if canImport(...)`. Lines the import shifts belong to files whose errors
were read already; a file given it isn't read again.

Output: OUT/<package>/<platform>-reexport.json, and a section of
SUMMARY.md.
"""

import sys

sys.dont_write_bytecode = True

import datetime  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import time  # noqa: E402

import probe  # noqa: E402  (probe.py's main makes this itself)
import classify  # noqa: E402
import diags  # noqa: E402
import manifests  # noqa: E402
import platforms  # noqa: E402
import strip  # noqa: E402
from scan_sources import strip_comments_and_strings  # noqa: E402

ROUNDS = 30
FIXUP_NOTE = "// import-probe: in place of a demoted re-export"
EXPORTED = re.compile(r"@_exported\b[ \t]*")


def swift_files(directory):
    """The Swift files under a directory, manifests and dot-directories
    (.build, .git) aside."""
    for dirpath, dirnames, files in os.walk(directory):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        for f in sorted(files):
            if f.endswith(".swift") and not manifests.MANIFEST.match(f):
                yield os.path.join(dirpath, f)


def c99(name):
    """SwiftPM's module name for a target name."""
    out = re.sub(r"[^A-Za-z0-9_]", "_", name)
    return "_" + out if out[:1].isdigit() else out


def find_reexports(work, counted, platform, model, scan=None):
    """[{file (relative to the scratch directory), line, module, import,
    text, attrs, target, active}] for each `@_exported import` of a counted
    module in the copy's Swift files: on its own line, or with `@_exported`
    on an attribute line above. `scan` is [(directory, target module)],
    the targets' directories (default: all of src/ and deps/); `active` is
    whether the platform compiles the line."""
    plat = classify.PLATFORM[platform]
    out, seen = [], set()
    for directory, target in scan if scan is not None else [(os.path.join(work, d), None) for d in ("src", "deps")]:
        for path in swift_files(directory):
            if os.path.realpath(path) in seen:
                continue
            seen.add(os.path.realpath(path))
            try:
                with open(path, encoding="utf-8") as f:
                    text = f.read()
            except (OSError, UnicodeDecodeError):
                continue
            if "@_exported" not in text:
                continue
            lines = text.split("\n")
            code = strip_comments_and_strings(text)[0].split("\n")
            states = None
            for i, line in enumerate(lines):
                m = strip.IMPORT.match(line)
                if not m or not counted(m.group("module")) or "import" not in code[i]:
                    continue
                k, exported = i - 1, "@_exported" in m.group("attrs")
                while not exported and k >= 0 and strip.ATTR_ONLY.match(lines[k]):
                    exported = "@_exported" in lines[k]
                    k -= 1
                if not exported:
                    continue
                if states is None:
                    try:
                        states = platforms.swift_line_states(code, model)[0]
                    except (ValueError, IndexError):
                        states = []
                st = states[i] if i < len(states) else None
                out.append({"file": os.path.relpath(path, work), "line": i + 1, "module": m.group("module"),
                            "import": f"{m.group('module')}{m.group('rest')}", "text": line.strip(),
                            "attrs": EXPORTED.sub("", m.group("attrs")).strip(), "target": target,
                            "active": True if st is None else plat in st})
    return out


def built_modules(scratch):
    """The Swift modules a build directory has (`<triple>/debug/Modules`)."""
    import glob
    return {os.path.splitext(os.path.basename(p))[0]
            for p in glob.glob(os.path.join(scratch, "*", "debug", "Modules", "*.swiftmodule"))}


def demote(work, sites):
    """Each re-export a plain import, in place: `@_exported` goes from its
    line or the attribute line above, and the line count stays."""
    by_file = {}
    for s in sites:
        by_file.setdefault(s["file"], []).append(s)
    for rel, ss in by_file.items():
        path = os.path.join(work, rel)
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
        for s in ss:
            i = s["line"] - 1
            if "@_exported" in lines[i]:
                lines[i] = EXPORTED.sub("", lines[i], count=1)
            else:
                k = i - 1
                while k >= 0 and strip.ATTR_ONLY.match(lines[k]) and "@_exported" not in lines[k]:
                    k -= 1
                if k >= 0 and "@_exported" in lines[k]:
                    lines[k] = EXPORTED.sub("", lines[k], count=1)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))


def fixup_block(sites):
    """The import that stands in for the active re-exports: one
    `#if canImport` block for each module imported."""
    seen, out = set(), []
    for s in sites:
        if not s["active"] or s["import"] in seen:
            continue
        seen.add(s["import"])
        attrs = (s["attrs"] + " ") if s["attrs"] else ""
        out += [f"#if canImport({s['module']})", f"{attrs}import {s['import']} {FIXUP_NOTE}", "#endif"]
    return "\n".join(out)


def add_import(path, block):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    at = 1 if lines and lines[0].startswith("#!") else 0
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines[:at] + [block] + lines[at:]))


def package_of(work, path):
    """The package directory (nearest Package.swift) a file of the copy is
    in, or None."""
    d = os.path.dirname(os.path.join(work, path))
    while inside(d, work):
        if os.path.isfile(os.path.join(d, "Package.swift")):
            return d
        if os.path.realpath(d) == os.path.realpath(work):
            return None
        d = os.path.dirname(d)
    return None


def inside(path, directory):
    return probe.inside(path, directory)


def module_files(work, path, desc_of):
    """The files of the target a file of the copy belongs to, from its
    package's targets (`desc_of(package directory)`: [(name, directory)]),
    relative to the scratch directory; [] when that can't be told."""
    pkg = package_of(work, path)
    if not pkg:
        return []
    full = os.path.join(work, path)
    best = None
    for _, directory in desc_of(pkg):
        d = os.path.join(pkg, directory)
        if inside(full, d) and (best is None or len(d) > len(best)):
            best = d
    if not best:
        return []
    return [os.path.relpath(p, work) for p in swift_files(best)]


def target_dirs(pkg, swiftpm, scratch):
    """[(target name, directory relative to the package)] from the package's
    manifest (`swift package dump-package`), SwiftPM's default directories
    for targets without a path."""
    import json
    import subprocess
    p = subprocess.run(["swift", "package", "--disable-sandbox", *swiftpm, "--package-path", pkg,
                        "--scratch-path", scratch, "dump-package"], capture_output=True, text=True)
    if p.returncode != 0:
        return []
    out = []
    for t in json.loads(p.stdout).get("targets", []):
        if t.get("path"):
            out.append((t["name"], t["path"]))
            continue
        roots = ("Tests",) if t.get("type") == "test" else ("Sources", "Source", "src", "srcs")
        for r in roots:
            if os.path.isdir(os.path.join(pkg, r, t["name"])):
                out.append((t["name"], os.path.join(r, t["name"])))
                break
    return out


def run(clone, branch, platform, args, repo, head, subdir="."):
    """The re-export run of one package of a clone; returns its result."""
    clone = os.path.abspath(clone)
    name = os.path.basename(clone.rstrip("/"))
    shown = probe.display_name(name, subdir)
    branch = branch or probe.newest_branch(clone)
    if not branch:
        raise RuntimeError(f"{clone} has none of the branches {', '.join(probe.BRANCHES)}; give --branch")
    commit = probe.commit_of(clone, branch)
    if not commit:
        raise RuntimeError(f"{clone} has no branch or commit {branch}")
    system_commit = probe.commit_of(repo, args.system)
    if not system_commit:
        raise RuntimeError(f"no System commit {args.system} in {repo}")
    plat = classify.PLATFORM[platform]
    work = os.path.join(args.work, f"{shown}-{platform}-reexport")
    gb = probe.free_gb(args.work)
    if gb < args.min_free_gb:
        raise RuntimeError(f"only {gb:.1f} GiB free (less than {args.min_free_gb}); not starting {shown}")
    probe.log(f"{shown} {branch} @ {commit[:10]} on {platform}, the re-export run, against System "
              f"{system_commit[:10]}; scratch {work}")
    probe.fresh_work(work)
    cfg = probe.package_config(name, subdir)
    swiftpm = getattr(args, "swiftpm", ())
    started = time.time()
    result = {"meta": {"package": name, "clone": clone, "branch": branch, "commit": commit, "platform": platform,
                       "platformName": plat, "system": system_commit, "tool": head, "run": "reexport",
                       "date": datetime.date.today().isoformat(), "note": cfg["note"]},
              "demoted": [], "fixups": {"module": [], "own": [], "dependencies": []}, "rounds": [],
              "baseline": None, "records": [], "followOns": [], "others": [], "residual": [], "outsideErrors": []}
    if os.path.normpath(subdir) != ".":
        result["meta"].update(nested=os.path.normpath(subdir), name=shown)
    try:
        pkg, rec = probe.prepare(clone, commit, name, work, repo, system_commit, subdir,
                                 probe.path_dep_refs(args.path_dep), swiftpm)
        result["meta"]["preparation"] = rec
        b = probe.Builder(platform, work, name, args, pkg, swiftpm)
        desc = probe.describe(pkg, os.path.join(work, "scratch-macos"), b.logs, swiftpm)
        mods = classify.modules(repo, head)
        own_modules = {t["c99name"] for t in desc["targets"]} | {"SystemPackage", "SystemSockets", "CSystem"}
        own_modules |= {d["identity"] for d in rec["dependencies"]}
        model = platforms.model(imports=own_modules)
        dumped = {}

        def desc_of(p):
            """[(target name, directory)] of a package of the copy."""
            if p not in dumped:
                if os.path.realpath(p) == os.path.realpath(pkg):
                    dumped[p] = [(t["name"], t["path"]) for t in desc["targets"]]
                else:
                    dumped[p] = target_dirs(p, swiftpm, os.path.join(work, "scratch-macos"))
            return dumped[p]
        packages = []
        for p in ([pkg] + [os.path.join(work, d) for d in rec["local"]]
                  + [os.path.join(work, "deps", i) for i in ["swift-system"] + [d["identity"] for d in rec["dependencies"]]]):
            if os.path.isdir(p) and not any(os.path.realpath(p) == os.path.realpath(q) for q in packages):
                packages.append(p)
        scan = [(os.path.join(p, d), c99(n)) for p in packages for n, d in desc_of(p)]
        sites = find_reexports(work, lambda m: mods.group(m) == "count", platform, model, scan)
        result["demoted"] = sites
        if not any(s["active"] for s in sites):
            probe.log(f"{shown}: no re-export of a C module that {plat} compiles; nothing to build")
            return result
        roots = ["/code"] if platform == "linux" else [work, os.path.realpath(work)]
        rel_pkg = os.path.relpath(pkg, work)
        own_files = {}
        for t in desc["targets"]:
            if t.get("module_type") == "SwiftTarget":
                for f in probe.target_files(pkg, t):
                    own_files[os.path.normpath(os.path.join(rel_pkg, f))] = t["name"]
        code, text, secs, lp = b.build("baseline")
        base = diags.parse(text, roots)
        base_keys = {(d["file"], d["line"], d["message"]) for d in base}
        result["baseline"] = {"exit": code, "seconds": secs, "errors": len(base), "log": os.path.relpath(lp, work)}
        # A re-export counts only in a module the build has: a manifest's
        # text has packages and targets the graph doesn't take.
        built = built_modules(b.scratch)
        for s in sites:
            s["built"] = not built or s["target"] in built
        active = [s for s in sites if s["active"] and s["built"]]
        probe.log(f"{shown}: baseline: exit {code}, {len(base)} errors ({secs} s); demoting "
                  + (", ".join(f"{s['file']}:{s['line']}" for s in active) or "nothing the build has"))
        if not active:
            return result
        demote(work, [s for s in sites if s["built"]])
        block = fixup_block(active)
        fixed = set()
        for s in active:
            for f in module_files(work, s["file"], desc_of):
                if f != s["file"] and f not in fixed:
                    add_import(os.path.join(work, f), block)
                    fixed.add(f)
                    result["fixups"]["module"].append(f)
        code_of = probe.code_reader(pkg)
        demoted_modules = {s["module"] for s in sites}

        def classify_name(nm, kind):
            return probe.result_class(nm, plat, kind, cfg, pkg, desc)
        last = []
        for n in range(1, ROUNDS + 1):
            code, text, secs, lp = b.build(f"round{n}")
            errs = [d for d in diags.parse(text, roots) if (d["file"], d["line"], d["message"]) not in base_keys]
            last = errs
            new = [d for d in errs if d["file"] not in fixed]
            own = [dict(d, file=os.path.relpath(os.path.join(work, d["file"]), pkg))
                   for d in new if d["file"] in own_files]
            prim, follow, other = diags.split(own, code_of)
            for d, kind, nm, module, (cls, unit, how) in probe.name_records(prim, pkg, demoted_modules,
                                                                             classify_name):
                result["records"].append({
                    "package": name, "branch": branch, "commit": commit, "platform": platform,
                    "target": own_files[os.path.normpath(os.path.join(rel_pkg, d["file"]))], "file": d["file"],
                    "line": d["line"], "column": d["col"], "name": nm, "kind": kind, "module": module,
                    "class": cls, "unit": unit, "how": how, "message": d["message"], "round": n,
                    **({"nested": result["meta"]["nested"]} if "nested" in result["meta"] else {})})
            target_of = {d["file"]: own_files[os.path.normpath(os.path.join(rel_pkg, d["file"]))] for d in own}
            result["followOns"] += [dict(d, target=target_of[d["file"]]) for d in follow]
            result["others"] += [dict(d, target=target_of[d["file"]]) for d in other]
            to_fix = sorted({d["file"] for d in new})
            failing = sorted({own_files[f] for f in to_fix if f in own_files})
            dep_files = [f for f in to_fix if f not in own_files]
            result["rounds"].append({"round": n, "exit": code, "seconds": secs, "log": os.path.relpath(lp, work),
                                     "errors": len(own), "names": len(prim), "targets": failing,
                                     "dependencyFiles": dep_files})
            probe.log(f"{shown}: round {n}: exit {code}, {len(prim)} names in {', '.join(failing) or 'no target'}"
                      + (f", {len(dep_files)} dependency files with errors" if dep_files else "") + f" ({secs} s)")
            if code == 0 or not to_fix:
                break
            for f in to_fix:
                add_import(os.path.join(work, f), block)
                fixed.add(f)
                result["fixups"]["own" if f in own_files else "dependencies"].append(f)
        else:
            probe.log(f"{shown}: stopped after {ROUNDS} rounds")
            result["meta"]["stopped"] = ROUNDS
        if code != 0:
            result["residual"] = [d for d in last if d["file"] in fixed]
            if not last:
                result["outsideErrors"] = sorted({ln.strip() for ln in text.split("\n")
                                                  if "error:" in ln and not ln.lstrip().startswith("|")})[:40]
                probe.log(f"{shown}: the build failed outside any file: {result['outsideErrors'][:3]}")
        result["meta"]["fixed"] = {k: len(v) for k, v in result["fixups"].items()}
    finally:
        result["meta"]["seconds"] = round(time.time() - started, 1)
        if args.keep:
            result["meta"]["work"] = work
        else:
            probe.remove_work(work)
    return result
