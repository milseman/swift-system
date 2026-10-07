#!/usr/bin/env python3
"""A package's probe results as Markdown, SUMMARY.md beside its JSON files,
with the comparison against status.sh's ledger of sites left when there's a
ledger.json to read.

The comparison, per platform, is between two readings of one commit:

- the ledger's import sites (adopter-coverage's ledger.py, status.sh's
  section 5): each import of a counted module the platform compiles, with
  the C names it serves there, found lexically;
- the probe's: the imports it removed that the platform compiles, and the
  names the compiler then couldn't find.

It lists the imports one has and the other doesn't, and for each file both
have, the names only the ledger gives (what the compiler found without the
import), the names only the compiler needed, and the imports whose file
built without them (removable now). The ledger must have read the same
commit, which the summary checks.

Usage: summary.py OUT/<package> [--ledger ledger.json]
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402

PLATFORM_ORDER = ("macos", "linux", "musl", "wasi")
CLASS_ORDER = ("gap", "covered", "not System's", "standard library", "shim's own", "module")
CLASS_TEXT = {"gap": "System gap", "covered": "System covers it", "not System's": "not System's",
              "standard library": "standard library", "shim's own": "the shim's own", "module": "module"}
LEDGER_KIND = {"System gap": "gap", "covered": "covered", "not System's": "not System's",
               "standard library": "standard library"}
# The ledger's names for clones whose directory isn't the repository's
# scheme name (status.py's ADOPTER_DIRS, inverted).
LEDGER_NAMES = {"WasmKit": "wasmkit", "swift-llbuild": "llbuild", "swift-package-manager": "swiftpm"}


def short(c):
    return (c or "")[:10]


def code(s):
    return f"`{s}`"


def attribution(result):
    """Which removed imports explain which found names: a file's names are
    its own imports', and in a target with an `@_exported` import removed,
    the names in files with no import of their own removed are that
    import's, since a re-export in one file serves the whole module.
    Returns ({(file, line) of an import: names}, {target: names in files
    no removed import explains})."""
    by_file = collections.defaultdict(set)
    for r in result["records"]:
        by_file[r["file"]].add(r["name"])
    files = result.get("files", {})
    serves, unexplained = {}, {}
    for t in result["targets"]:
        active = [r for r in t.get("removed", []) if r["active"]]
        own = {r["file"] for r in active}
        others = set()
        for f, target in files.items():
            if target == t["name"] and f not in own:
                others |= by_file.get(f, set())
        exported = [r for r in active if r["exported"]]
        for r in active:
            serves[(r["file"], r["line"])] = by_file.get(r["file"], set()) | (others if r["exported"] else set())
        if others and not exported:
            unexplained[t["name"]] = sorted(others)
    return serves, unexplained


def ledger_compare(result, led):
    """The comparison for one platform's result, as a dict (see the module
    docstring)."""
    meta = result["meta"]
    repo = LEDGER_NAMES.get(meta["package"], meta["package"])
    plat = meta["platformName"]
    read = next((r for r in led.get("read", []) if r["repository"] == repo), None)
    out = {"repository": repo, "ledgerCommit": read["commit"] if read else None,
           "sameCommit": bool(read and read["commit"] == meta["commit"])}
    sites = [s for s in led.get("sites", []) if s["repository"] == repo and plat in (s.get("platforms") or {})]
    imports = [s for s in sites if s["type"] == "import"]
    out["ledgerMarkers"] = len(sites) - len(imports)
    files = result.get("files", {})
    removed = {}
    for t in result["targets"]:
        for r in t.get("removed", []):
            removed[(r["file"], r["line"])] = dict(r, target=t["name"])
    probed = {t["name"] for t in result["targets"] if t.get("status") == "probed"}
    through = result.get("reachesThrough", {})
    serves, unexplained = attribution(result)
    class_of = {}
    for r in result["records"]:
        class_of.setdefault(r["name"], r["class"])
    matched, outside, inactive, unseen = [], [], [], []
    for s in imports:
        key = (s["file"], s["line"])
        r = removed.get(key)
        if r is None:
            (outside if s["file"] not in files else unseen).append(s)
        elif not r["active"]:
            inactive.append(s)
        else:
            matched.append((s, r))
    ledger_keys = {(s["file"], s["line"]) for s in imports}
    probe_only = [r for k, r in sorted(removed.items()) if r["active"] and k not in ledger_keys]
    out["ledgerImports"] = len(imports)
    out["matched"] = len(matched)
    out["outsideTargets"] = [{"file": s["file"], "line": s["line"], "module": s.get("module"), "kind": s.get("kind")}
                             for s in outside]
    out["inactiveForProbe"] = [{"file": s["file"], "line": s["line"], "module": s.get("module"),
                                "ledger": s["platforms"][plat]} for s in inactive]
    out["notRemovedByProbe"] = [{"file": s["file"], "line": s["line"], "text": s.get("text")} for s in unseen]
    shims = set(meta.get("shims") or [])
    out["probeOnlyImports"] = [{"file": r["file"], "line": r["line"], "text": r["text"], "target": r["target"],
                                "shim": r["module"] in shims, "names": sorted(serves.get((r["file"], r["line"]), ()))}
                               for r in probe_only]
    out["unexplained"] = unexplained
    sites_out = []
    for s, r in matched:
        lnames, answers = set(), {}
        for n, ps in (s.get("names") or {}).items():
            if plat in ps:
                lnames.add(n)
                a = (s.get("answers") or {}).get(n, {}).get(plat)
                if a:
                    answers[n] = LEDGER_KIND.get(a[0], a[0])
        pnames = serves.get((r["file"], r["line"]), set())
        built = r["target"] in probed
        disagree = sorted(n for n in lnames & pnames if answers.get(n) and answers[n] != class_of.get(n))
        others = sorted(p for p in (s.get("platforms") or {}) if p != plat)
        sites_out.append({"file": s["file"], "line": s["line"], "target": r["target"], "built": built,
                          "exported": r["exported"], "otherPlatforms": others, "both": sorted(lnames & pnames),
                          "ledgerOnly": sorted(lnames - pnames), "probeOnly": sorted(pnames - lnames),
                          "classDisagrees": disagree, "through": through.get(r["target"], []),
                          "removable": built and not pnames and not through.get(r["target"])})
    out["files"] = sites_out
    return out


def plural(n, one, many=None):
    return f"{n} {one if n == 1 else (many or one + 's')}"


def names_table(w, records):
    by = collections.defaultdict(list)
    for r in records:
        by[(r["class"], r["name"])].append(r)
    rows = sorted(by.items(), key=lambda kv: (CLASS_ORDER.index(kv[0][0]) if kv[0][0] in CLASS_ORDER else 99,
                                               -len(kv[1]), kv[0][1]))
    w("| Name | Class | System's answer | Sites | Files |")
    w("|---|---|---|---|---|")
    for (cls, name), rs in rows[:40]:
        files = sorted({r["file"] for r in rs})
        how = rs[0]["how"] or ""
        if len(how) > 80:
            how = how[:77] + "..."
        w(f"| {code(name)} | {CLASS_TEXT.get(cls, cls)} | {how.replace('|', '/')} | {len(rs)} | "
          + ", ".join(code(f) for f in files[:3]) + (f" and {len(files) - 3} more" if len(files) > 3 else "") + " |")
    if len(rows) > 40:
        w(f"| … {len(rows) - 40} more names in the JSON | | | | |")


def platform_section(w, result, led):
    meta = result["meta"]
    t = result["targets"]
    swift = [x for x in t if x.get("moduleType") == "SwiftTarget"]
    status = collections.Counter(x.get("status") for x in swift)
    w(f"## {meta['platformName']} ({meta['platform']})")
    w("")
    w(f"`{meta['branch']}` @ `{short(meta['commit'])}`, against System `{short(meta['system'])}`, "
      f"{meta['date']}, {meta['seconds']} s. Tool commit `{short(meta['tool'])}`."
      + (f" Shims removed like C modules: {', '.join(code(s) for s in meta['shims'])}." if meta.get("shims") else ""))
    w("")
    probed = status.get("probed", 0)
    skipped = sum(v for k, v in status.items() if k and k.startswith("no removed import"))
    w(f"- **Targets**: {plural(len(swift), 'Swift target')}: {probed} built without their C imports, {skipped} whose "
      f"removed imports {meta['platformName']} doesn't compile, {status.get('no imports to remove', 0)} with none to "
      "remove." + (f" Other: {dict((k, v) for k, v in status.items() if k not in ('probed', 'no imports to remove') and not (k or '').startswith('no removed import'))}."
                   if any(k not in ('probed', 'no imports to remove') and not (k or '').startswith('no removed import')
                          for k in status) else ""))
    if result.get("baseline"):
        b = result["baseline"]
        w(f"- **Baseline** (the unmodified copy, `--build-tests`): exit {b['exit']}, {plural(b['errors'], 'error')}, "
          f"{b['seconds']} s.")
    recs = result["records"]
    cls = collections.Counter(r["class"] for r in recs)
    names = {r["name"] for r in recs}
    w(f"- **Names the compiler couldn't find**: {plural(len(recs), 'site')}, {plural(len(names), 'distinct name')}"
      + (": " + ", ".join(f"{CLASS_TEXT.get(k, k)} {v}" for k, v in sorted(cls.items(), key=lambda kv: CLASS_ORDER.index(kv[0]) if kv[0] in CLASS_ORDER else 99)) if recs else "")
      + f". Follow-on errors: {len(result['followOns'])}; other errors: {len(result['others'])}"
      + (f"; errors outside the probed target's files: {len(result['outside'])}" if result["outside"] else "") + ".")
    if result["reexporters"]:
        w("- **Re-exports removed**: " + "; ".join(f"{code(m)} re-exported {', '.join(code(x) for x in v)}"
                                                   for m, v in sorted(result["reexporters"].items()))
          + ". Each target that depends on one still reaches those modules through it when the probe builds the "
            "target: " + "; ".join(f"{code(k)} through {', '.join(code(x) for x in v)}"
                                   for k, v in sorted(result["reachesThrough"].items())) + ".")
    ff = result.get("foundationFiles", [])
    if ff:
        w(f"- **Files importing Foundation**: {plural(len(ff), 'file')} in "
          f"{plural(len({f['target'] for f in ff}), 'target')}. "
          + ("On Darwin, Foundation re-exports Darwin, so a C name these files use resolves without their own "
             "import, and the probe can't see it." if meta["platform"] == "macos" else
             "A C name Foundation's own imports make visible isn't seen in them."))
    ci = result.get("clangImports", [])
    if ci:
        mods = sorted({m for f in ci for m in f["modules"]})
        w(f"- **Files importing the package's C targets** ({', '.join(code(m) for m in mods)}): "
          f"{plural(len(ci), 'file')}. A C target's module re-exports the system headers it includes, so names "
          "these files take through it aren't seen.")
    w("")
    if recs:
        names_table(w, recs)
        w("")
    rows = [x for x in t if x.get("status") == "probed"]
    if rows:
        w("| Target | Imports removed (compiled here) | Names | Follow-ons | Other | Build |")
        w("|---|---|---|---|---|---|")
        for x in rows:
            act = sum(1 for r in x["removed"] if r["active"])
            w(f"| {code(x['name'])} | {len(x['removed'])} ({act}) | {x.get('names', 0)} | {x.get('followOns', 0)} | "
              f"{x.get('others', 0)} | {x.get('seconds')} s, exit {x.get('exit')} |")
        w("")
    if result["others"]:
        w("Other errors (not a name, and not inside a declaration with one):")
        w("")
        for d in result["others"][:10]:
            w(f"- `{d['file']}:{d['line']}`: {d['message']}")
        if len(result["others"]) > 10:
            w(f"- … {len(result['others']) - 10} more in the JSON")
        w("")
    if led is not None:
        cmp = ledger_compare(result, led)
        result["comparison"] = cmp
        ledger_section(w, result, cmp)


def ledger_section(w, result, cmp):
    plat = result["meta"]["platformName"]
    w(f"### Against the ledger ({plat})")
    w("")
    if not cmp["ledgerCommit"]:
        w(f"The ledger didn't read `{cmp['repository']}`.")
        w("")
        return
    if not cmp["sameCommit"]:
        w(f"**The ledger read `{short(cmp['ledgerCommit'])}`, not the probe's `{short(result['meta']['commit'])}`**: "
          "rerun status.sh, or probe that commit, before reading this.")
        w("")
    w(f"The ledger has {plural(cmp['ledgerImports'], 'import site')} compiled on {plat} "
      f"({plural(cmp['ledgerMarkers'], 'marker site')} besides); the probe removed "
      f"{plural(cmp['matched'] + len(cmp['probeOnlyImports']), 'import')} {plat} compiles, "
      f"{cmp['matched']} of them the ledger's.")
    w("")
    if cmp["outsideTargets"]:
        w(f"- **Outside every target the probe builds** ({len(cmp['outsideTargets'])}): "
          + ", ".join(f"`{s['file']}:{s['line']}`" for s in cmp["outsideTargets"][:12])
          + (" …" if len(cmp["outsideTargets"]) > 12 else "")
          + ". Nested packages, benchmarks, integration tests and scripts aren't the package's targets.")
    if cmp["inactiveForProbe"]:
        w(f"- **The ledger says {plat} compiles them; the probe's evaluation says it doesn't** "
          f"({len(cmp['inactiveForProbe'])}): " + ", ".join(f"`{s['file']}:{s['line']}`" for s in cmp["inactiveForProbe"]))
    if cmp["notRemovedByProbe"]:
        w(f"- **In a target, but the probe didn't remove them** ({len(cmp['notRemovedByProbe'])}): "
          + ", ".join(f"`{s['file']}:{s['line']}` ({s['text']})" for s in cmp["notRemovedByProbe"]))
    plain = [s for s in cmp["probeOnlyImports"] if not s["shim"]]
    shim = [s for s in cmp["probeOnlyImports"] if s["shim"]]
    if plain:
        w(f"- **Removed by the probe, no ledger site** ({len(plain)}): "
          + ", ".join(f"`{s['file']}:{s['line']}`" for s in plain))
    if shim:
        needed = sorted({n for s in shim for n in s["names"]})
        w(f"- **Shim imports** ({len(shim)}, of {', '.join(sorted({code(s['text'].split()[-1]) for s in shim}))}): "
          "the ledger counts a shim's re-export, not the imports of it, so these have no site. "
          + (f"The compiler needed {', '.join(code(n) for n in needed[:10])} from them."
             if needed else f"The compiler needed nothing from them on {plat}: on this platform they can go."))
    removable = [f for f in cmp["files"] if f["removable"]]
    if removable:
        w(f"- **Builds without them** ({len(removable)}): the compiler needed nothing these imports gave on {plat}, "
          "and the target reaches no C module through another target's re-export: "
          + ", ".join(f"`{f['file']}:{f['line']}`"
                      + (f" (the ledger has it compiled on {', '.join(f['otherPlatforms'])} too, which this run "
                         "didn't build)" if f["otherPlatforms"] else " (only here: it can go)")
                      for f in removable) + ".")
    through = [f for f in cmp["files"] if f["built"] and not f["both"] and not f["probeOnly"] and f["through"]]
    if through:
        w(f"- **Builds without them, but only through a re-export** ({len(through)}): "
          + ", ".join(f"`{f['file']}:{f['line']}` (through {', '.join(code(x) for x in f['through'])})"
                      for f in through)
          + ". The target still sees the C module through the other target's `@_exported` import, so the "
            "ledger's names for these may be served there.")
    for f in cmp["files"]:
        if f["exported"] and f["probeOnly"]:
            w(f"- **A re-export serves its whole module**: `{f['file']}:{f['line']}` is `@_exported`, and "
              f"{code(f['target'])}'s other files needed {plural(len(f['probeOnly']), 'name')} it gave; the ledger "
              "gives the import only the names in its own file.")
    if cmp["unexplained"]:
        w("- **Names in files no removed import explains**: " + "; ".join(
            f"{code(t)}: {', '.join(code(n) for n in ns[:8])}" for t, ns in sorted(cmp["unexplained"].items())))
    w("")
    rows = [f for f in cmp["files"] if f["ledgerOnly"] or f["probeOnly"] or f["classDisagrees"]]
    if rows:
        w("| Import | Both | Only the ledger's | Only the compiler's | Classes differ |")
        w("|---|---|---|---|---|")
        for f in rows:
            def names(xs):
                return ", ".join(code(x) for x in xs[:8]) + (f" and {len(xs) - 8} more" if len(xs) > 8 else "")
            w(f"| `{f['file']}:{f['line']}` | {len(f['both'])} | {names(f['ledgerOnly']) or '—'} | "
              f"{names(f['probeOnly']) or '—'} | {names(f['classDisagrees']) or '—'} |")
        w("")
    elif cmp["files"]:
        w(f"For the {plural(len(cmp['files']), 'import')} both have, the names agree.")
        w("")


def write(out_dir, ledger_path=None):
    """Writes OUT/<package>/SUMMARY.md from its platforms' JSON files (and
    the comparison back into each); returns the path."""
    led = None
    if ledger_path:
        with open(ledger_path, encoding="utf-8") as f:
            led = json.load(f)
    results = []
    for platform in PLATFORM_ORDER:
        p = os.path.join(out_dir, f"{platform}.json")
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                results.append((p, json.load(f)))
    lines = []
    w = lines.append
    if not results:
        return None
    meta = results[0][1]["meta"]
    w(f"# import-probe: {meta['package']}")
    w("")
    w(f"`{meta['clone']}`. Each section is one platform's probe: the package's branch exported, each Swift target "
      "built alone without its imports of modules.ini's counted modules, and the names the compiler then couldn't "
      "find, each with System's answer. `import-probe.json` beside this has every site. "
      + (f"Compared with the ledger in `{ledger_path}`." if led else "No ledger.json was given, so there's no "
                                                                        "comparison."))
    if meta.get("note"):
        w("")
        w(f"Package note (packages.ini): {meta['note']}")
    w("")
    flat = []
    for path, result in results:
        platform_section(w, result, led)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=1)
        flat += result["records"]
    with open(os.path.join(out_dir, "import-probe.json"), "w", encoding="utf-8") as f:
        json.dump(flat, f, indent=1)
    path = os.path.join(out_dir, "SUMMARY.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip() + "\n")
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--ledger")
    a = ap.parse_args()
    print(write(a.out, a.ledger))


if __name__ == "__main__":
    main()
