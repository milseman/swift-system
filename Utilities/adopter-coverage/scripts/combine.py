#!/usr/bin/env python3
"""Write a run's combined report from its packages' results.

check.sh runs this after storing each package's result: it reads the run's
run.json, and each package's coverage.json from the results store, and
writes COVERAGE.md and coverage.json into the run's directory. It says
which gaps block how many adopters, ranks the gaps across all of them by
the code each package could delete, puts the packages' Darwin-module
numbers side by side, and lists the mapping's symbols that no package uses.

Usage: combine.py --run RUN_DIR --results RESULTS --mapping mapping.ini --packages PACKAGES_DIR
"""

import sys

sys.dont_write_bytecode = True

import argparse
import collections
import json
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402
import lanes  # noqa: E402
import package  # noqa: E402

ABBREV = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
          "Windows": "N"}
RANKED = 40
DARWIN_CLASSES = ("direct", "module re-export", "package re-export", "Foundation", "SDK re-export")


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def load_run(run_dir, results):
    run = json.load(open(os.path.join(run_dir, "run.json")))
    covs = {}
    for p in run["packages"]:
        if p.get("result"):
            covs[p["name"]] = json.load(open(os.path.join(results, p["result"], "coverage.json")))
    return run, covs


def totals(cov):
    tot = collections.Counter()
    for row in cov["summary"]["all"].values():
        tot.update(row.get("all", {}))
    return tot


def gap_rows(covs):
    """Every gap entry, over the packages, with its status there."""
    gaps = collections.defaultdict(dict)
    entry_of = {}
    for k, c in covs.items():
        by_id = {e["id"]: e for e in c["entries"]}
        for g in c["gaps"]:
            gaps[g["id"]][k] = g
            entry_of.setdefault(g["id"], by_id.get(g["id"], {}))
    rows = []
    for gid, per in gaps.items():
        e = entry_of.get(gid, {})
        rows.append({"id": gid, "category": e.get("category", ""), "status": e.get("status", ""),
                     "auto": bool(e.get("auto")), "decidedBy": e.get("decidedBy"),
                     "adopters": sorted(per), "lines": {k: g["total"] for k, g in per.items()},
                     "total": sum(g["total"] for g in per.values()),
                     "sites": {k: g.get("sites", 0) for k, g in per.items()},
                     "allSites": sum(g.get("sites", 0) for g in per.values()),
                     "platforms": {k: g["gapPlatforms"] for k, g in per.items()},
                     "note": e.get("note") or "", "symbols": e.get("symbols", [])})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--results", required=True)
    ap.add_argument("--mapping", required=True)
    ap.add_argument("--packages", required=True)
    args = ap.parse_args()

    run, covs = load_run(args.run, args.results)
    if not covs:
        open(os.path.join(args.run, "COVERAGE.md"), "w").write(
            f"# swift-system's adopters: OS interfaces and coverage\n\nRun `{run['id']}`: no package's check "
            f"finished ({', '.join(run.get('failed') or []) or 'none ran'} failed); see the run's log.\n")
        json.dump({"run": run, "packages": {}, "gaps": [], "shared": []},
                  open(os.path.join(args.run, "coverage.json"), "w"), indent=1)
        print("combine: no package finished")
        return
    names = {k: c["package"]["name"] for k, c in covs.items()}
    expected = [f[:-4] for f in sorted(os.listdir(args.packages))
                if f.endswith(".ini") and package.load(os.path.join(args.packages, f))["in-all"] == "yes"]
    missing_pkgs = [k for k in expected if k not in covs]
    config, entries, _problems = check.load_mapping(args.mapping)
    lane_rules = lanes.load(args.mapping)

    rows = gap_rows(covs)
    for r in rows:
        r["lane"] = lanes.assign(r, lane_rules)
    shared = sorted((r for r in rows if len(r["adopters"]) > 1),
                    key=lambda r: (-len(r["adopters"]), -r["total"], -r["allSites"], r["id"]))
    ranked = sorted(rows, key=lambda r: (-r["total"], -len(r["adopters"]), -r["allSites"], r["id"]))

    used = set()
    for c in covs.values():
        used.update(c["interfaces"])
    unused = [(e["id"], [s for s in e["symbols"] if s not in used]) for e in entries]
    unused = [(i, s) for i, s in unused if s]

    out = []
    w = out.append
    w("# swift-system's adopters: OS interfaces and coverage")
    w("")
    w(f"Run `{run['id']}`: System `{run['systemCommit']}` ({esc(run.get('systemRef', ''))}), tool `{run['tool']}`"
      + (f" (commit `{run['toolCommit'][:12]}`)" if run.get("toolCommit") else "")
      + (", **with uncommitted changes**" if run.get("toolDirty") else "") + f", mapping `{run['mapping']}`. "
      f"One report per package is in the results store; this one puts them side by side. "
      f"`Utilities/adopter-coverage/results.sh verify {run['id']}` repeats the run with the same tool and compares.")
    w("")
    w("| Package | Commit | Extraction | Darwin-importing files | Re-export shims | Via Foundation only | Unmapped | "
      "Every platform, all interfaces (covered / partial / missing) | Entries: derived / hand |")
    w("|---|---|---|---|---|---|---|---|---|")
    for k, c in covs.items():
        m = c.get("meta", {})
        tot = totals(c)
        dz = (c.get("darwin") or {}).get("summary", {})
        der = c.get("derivation", {}).get("entries", {})
        ext = c.get("extraction", {}).get("mode", "index")
        w(f"| {esc(c['package']['title'])} | `{m.get('commit', '?')[:10]}` | {ext} | {dz.get('direct', '?')} | "
          f"{dz.get('reexportShims', '?')} | {dz.get('byClass', {}).get('Foundation', 0)} | "
          f"{len(c['problems']['unmapped'])} | {tot['covered']} / {tot['partial']} / {tot['missing']} | "
          f"{der.get('derived', 0)} / {der.get('hand', 0) + der.get('override', 0)} |")
    w("")
    lexical = [k for k, c in covs.items() if c.get("extraction", {}).get("mode") == "lexical"]
    if lexical:
        w("**Lexical extractions** (" + ", ".join(names[k] for k in lexical) + "): the package didn't build with the "
          "compiler at hand, so every line was read by the lexical rules alone, with the SDK's names from another "
          "package's index. They find about 94% of the Darwin interfaces the index finds, with no false positives "
          "(measured on NIO), and drop names declared nowhere (Linux-, Windows- and dependency-only names), which "
          "undercounts other platforms. Each package's report says why its build failed.")
        w("")
    if missing_pkgs:
        w("Not in this run: " + ", ".join(missing_pkgs) + ". The unused-symbol list below needs every package, so "
          "it's left out.")
        w("")
    unmapped = [k for k, c in covs.items() if c["problems"]["unmapped"]]
    if unmapped:
        w("Interfaces no mapping entry names (" + ", ".join(f"{names[k]} {len(covs[k]['problems']['unmapped'])}"
                                                            for k in unmapped) + ") get an entry of their own, "
          "derived like the others, in the category their header or name suggests.")
        w("")

    # ------------------------------------------------------ derivation
    any_cov = next(iter(covs.values()))
    ds = any_cov.get("derivation", {}).get("system", {})
    w("## What decides each status")
    w("")
    w(f"System's sources at this commit decide what it covers: {ds.get('declarations', '?')} public declarations, "
      f"{ds.get('documented', '?')} of them with a *The corresponding C ...* sentence, and {ds.get('typealiases', '?')} "
      f"CInterop typealiases name {any_cov.get('derivation', {}).get('systemNames', '?')} C interfaces; System's "
      f"implementation uses {ds.get('implementationNames', '?')} more names, which can complete an entry. The mapping "
      "keeps only what can't be derived. Per package, the entries it uses:")
    w("")
    w("| Package | Derived | Hand status | Per-platform override | No entry (derived) | Hand and derivation disagree |")
    w("|---|---|---|---|---|---|")
    for k, c in covs.items():
        d = c.get("derivation", {})
        e = d.get("entries", {})
        w(f"| {names[k]} | {e.get('derived', 0)} | {e.get('hand', 0)} | {e.get('override', 0)} | {e.get('auto', 0)} | "
          f"{d.get('handAgreement', {}).get('disagree', 0)} of {sum(d.get('handAgreement', {}).values())} |")
    w("")

    # ------------------------------------------------------------ gaps
    w("## Gaps shared by adopters")
    w("")
    w("Entries that are missing or partial, on a platform that uses them, in more than one package: what System "
      "would have to add for several adopters at once. Ranked by how many adopters an entry blocks, then by the "
      "estimated lines they could delete together (see *How the estimates work*), then by the sites that use it. "
      "Entries the Swift standard library covers, and those that aren't System's to wrap (`wrap = no`), aren't gaps. "
      "*Lane* is the System lane that should take it (`lanes` in mapping.ini).")
    w("")
    pk = list(covs)
    w("| # | Entry | Category | Lane | Adopters | " + " | ".join(f"{names[k]} lines" for k in pk) + " | Total | Sites |")
    w("|---|---|---|---|---|" + "---|" * len(pk) + "---|---|")
    for i, r in enumerate(shared, 1):
        cells = [str(r["lines"][k]) if k in r["lines"] else "" for k in pk]
        w(f"| {i} | {esc(r['id'])}{' (no entry)' if r['auto'] else ''} | {r['category']} | {r['lane']} | "
          f"{len(r['adopters'])} | " + " | ".join(cells) + f" | {r['total']} | {r['allSites']} |")
    w("")
    by_count = collections.Counter(len(r["adopters"]) for r in rows)
    w(f"{len(rows)} entries are gaps for at least one package: " + ", ".join(
        f"{by_count[n]} for {n} {'package' if n == 1 else 'packages'}" for n in sorted(by_count, reverse=True)) + ".")
    w("")

    w(f"## The {RANKED} largest gaps across adopters")
    w("")
    w("Every gap, ranked by the lines all the adopters could delete together if System covered it.")
    w("")
    w("| # | Entry | Category | Lane | " + " | ".join(names[k] for k in pk) + " | Total | What's missing |")
    w("|---|---|---|---|" + "---|" * len(pk) + "---|---|")
    for i, r in enumerate(ranked[:RANKED], 1):
        cells = [f"{r['lines'][k]} ({' '.join(ABBREV[p] for p in r['platforms'][k])})" if k in r["lines"] else ""
                 for k in pk]
        note = r["note"]
        if len(note) > 200:
            note = note[:197].rsplit(" ", 1)[0] + " ..."
        w(f"| {i} | {esc(r['id'])} | {r['category']} | {r['lane']} | " + " | ".join(cells)
          + f" | {r['total']} | {esc(note)} |")
    w("")

    # --------------------------------------------------------- Darwin
    w("## The Darwin module")
    w("")
    w("How each package's library files see the Darwin module on Darwin (`scripts/darwin.py`): by importing it "
      "(*direct*, in any form), through another file of their module that re-exports it (*module re-export*), "
      "through a module of the package or a dependency that re-exports it (*package re-export*: NIOPosix, TSCLibc, "
      "SWBLibc), or only through Apple Foundation's re-export, or another SDK module's (Dispatch, os, Security, ...). "
      "*Interfaces via Foundation only* are Darwin names used only in files that see Darwin through Foundation: they "
      "compile only because the file imports Foundation, which FoundationEssentials wouldn't do.")
    w("")
    w("| Package | Swift files | " + " | ".join(DARWIN_CLASSES) + " | Re-export shims | Interfaces via Foundation "
      "only |")
    w("|---|---|" + "---|" * len(DARWIN_CLASSES) + "---|---|")
    for k, c in covs.items():
        dz = (c.get("darwin") or {}).get("summary", {})
        bc = dz.get("byClass", {})
        w(f"| {names[k]} | {dz.get('swiftFiles', '?')} | " + " | ".join(str(bc.get(x, 0)) for x in DARWIN_CLASSES)
          + f" | {dz.get('reexportShims', 0)} | {dz.get('interfacesByClass', {}).get('Foundation', 0)} |")
    w("")

    w("## How the estimates work")
    w("")
    w("Each package's number is the code its own sources could delete: the code lines of its thin wrapper functions "
      f"(up to {any_cov['config']['thinWrapperLines']} lines) in the files its package file lists as its syscall "
      "layer, that reference the entry on a platform where it's a gap, plus the definitions of its C shims that the "
      "entry would retire. A function that references several gaps is split between them; one whose calls System "
      "covers already counts for no gap. Code a dependency would delete doesn't count for the package that uses it. "
      "A package with no syscall-layer files counts no lines; *Sites* counts the lines that use the entry instead. "
      "Per package:")
    w("")
    for k, c in covs.items():
        cfg = c["config"]
        pkg = c["package"]
        shims = c["extraction"].get("shimTargets") or []
        twins = pkg.get("twin-targets") or []
        w(f"- **{names[k]}**: {len(cfg['wrapperFiles'])} syscall-layer globs in `packages/{k}.ini`"
          + (f"; C shims in {', '.join(shims)}" if shims else "; no C shim target")
          + (f"; {' and '.join(twins)} are twins, so their code counts twice" if twins else "")
          + (f". Its dependencies' OS use is reported separately (*OS use through dependencies* in its report)"
             if pkg.get("through") else "") + ".")
    w("")

    if not missing_pkgs:
        w("## Symbols no package uses")
        w("")
        if unused:
            w("The mapping lists these, but no package's extraction found them: prune them, unless a package that "
              "isn't audited here uses them.")
            w("")
            for i, s in unused:
                w(f"- [{esc(i)}] " + ", ".join(f"`{x}`" for x in s))
        else:
            w("None.")
        w("")

    open(os.path.join(args.run, "COVERAGE.md"), "w").write("\n".join(out) + "\n")
    json.dump({"run": run, "packages": {k: {"title": c["package"]["title"], "meta": c.get("meta", {}),
                                            "totals": dict(totals(c)),
                                            "darwin": (c.get("darwin") or {}).get("summary"),
                                            "derivation": c.get("derivation")} for k, c in covs.items()},
               "missingPackages": missing_pkgs, "gaps": ranked, "shared": shared,
               "unusedSymbols": unused if not missing_pkgs else None},
              open(os.path.join(args.run, "coverage.json"), "w"), indent=1)
    print(f"combine: {len(covs)} packages, {len(rows)} gap entries, {len(shared)} shared")


if __name__ == "__main__":
    main()
