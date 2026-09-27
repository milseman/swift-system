#!/usr/bin/env python3
"""Write the combined report from every package's coverage.json.

check.sh runs this after the packages' reports are in place, over every
package directory in the output, including ones an earlier run wrote. It
says which gaps block how many adopters, ranks the gaps across all of them
by the code each package could delete, explains each package's estimate,
and lists the mapping's symbols that no package uses.

Usage: combine.py --out OUT_DIR --mapping mapping.ini --packages PACKAGES_DIR
"""

import sys

sys.dont_write_bytecode = True

import argparse
import collections
import json
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402
import package  # noqa: E402

ABBREV = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
          "Windows": "N"}
RANKED = 40


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--mapping", required=True)
    ap.add_argument("--packages", required=True)
    args = ap.parse_args()

    covs = {}
    for d in sorted(os.listdir(args.out)):
        p = os.path.join(args.out, d, "coverage.json")
        if os.path.isfile(p):
            covs[d] = json.load(open(p))
    if not covs:
        return
    names = {k: c["package"]["name"] for k, c in covs.items()}
    expected = [f[:-4] for f in sorted(os.listdir(args.packages))
                if f.endswith(".ini") and package.load(os.path.join(args.packages, f))["in-all"] == "yes"]
    missing_pkgs = [k for k in expected if k not in covs]
    _config, entries, _problems = check.load_mapping(args.mapping)
    by_id = {e["id"]: e for e in entries}

    # ------------------------------------------------------------ gaps
    gaps = collections.defaultdict(dict)   # entry -> package -> gap
    entry_of = {}
    for k, c in covs.items():
        cov_by_id = {e["id"]: e for e in c["entries"]}
        for g in c["gaps"]:
            gaps[g["id"]][k] = g
            entry_of.setdefault(g["id"], cov_by_id.get(g["id"], {}))
    rows = []
    for gid, per in gaps.items():
        # The status is the package's: derived, or the mapping's.
        e = entry_of.get(gid) or by_id.get(gid, {})
        rows.append({"id": gid, "category": e.get("category", ""), "status": e.get("status", ""),
                     "adopters": sorted(per), "lines": {k: g["total"] for k, g in per.items()},
                     "total": sum(g["total"] for g in per.values()),
                     "platforms": {k: g["gapPlatforms"] for k, g in per.items()},
                     "note": e.get("note") or ""})
    shared = sorted((r for r in rows if len(r["adopters"]) > 1),
                    key=lambda r: (-len(r["adopters"]), -r["total"], r["id"]))
    ranked = sorted(rows, key=lambda r: (-r["total"], -len(r["adopters"]), r["id"]))

    # ------------------------------------------------ unused symbols
    used = set()
    for c in covs.values():
        used.update(c["interfaces"])
    unused = [(e["id"], [s for s in e["symbols"] if s not in used]) for e in entries]
    unused = [(i, s) for i, s in unused if s]

    # ---------------------------------------------------------- report
    out = []
    w = out.append
    w("# swift-system's adopters: OS interfaces and coverage")
    w("")
    w("One report per package is in its directory here; this one puts them side by side. `Utilities/adopter-coverage"
      "/check.sh` writes it, from each package's `coverage.json` in this directory, including packages an earlier "
      "run wrote.")
    w("")
    w("| Package | Commit | System | Unmapped | Cited API missing | Every platform, all interfaces (covered / partial "
      "/ missing) | Report |")
    w("|---|---|---|---|---|---|---|")
    systems = set()
    for k, c in covs.items():
        m = c.get("meta", {})
        systems.add(m.get("systemCommit"))
        tot = collections.Counter()
        for row in c["summary"]["all"].values():
            tot.update(row.get("all", {}))
        w(f"| {esc(c['package']['title'])} | `{m.get('commit', '?')[:10]}` | `{m.get('systemCommit', '?')[:10]}` | "
          f"{len(c['problems']['unmapped'])} | {len(c['problems']['apiMissing'])} | "
          f"{tot['covered']} / {tot['partial']} / {tot['missing']} | [{k}/COVERAGE.md]({k}/COVERAGE.md) |")
    w("")
    if len(systems) > 1:
        w("**The packages were checked against different System commits**, so their statuses don't compare exactly; "
          "rerun `check.sh` with no arguments to check them all against one.")
        w("")
    if missing_pkgs:
        w("Not here: " + ", ".join(missing_pkgs) + " (no report in this directory). The unused-symbol list below needs "
          "every package, so it's left out.")
        w("")
    unmapped = [k for k, c in covs.items() if c["problems"]["unmapped"]]
    if unmapped:
        w("Packages with unmapped interfaces (" + ", ".join(names[k] for k in unmapped) + ") have gaps the ranking "
          "below can't see: an interface counts only once an entry maps it.")
        w("")

    w("## Gaps shared by adopters")
    w("")
    w("Mapping entries that are missing or partial, on a platform that uses them, in more than one package: what "
      "System would have to add for several adopters at once. Ranked by how many adopters an entry blocks, then by "
      "the estimated lines they could delete together (see *How the estimates work*). Entries the Swift standard "
      "library covers, and those that aren't System's to wrap (`wrap = no`), aren't gaps.")
    w("")
    pk = list(covs)
    w("| # | Entry | Category | Adopters | " + " | ".join(f"{names[k]} lines" for k in pk) + " | Total |")
    w("|---|---|---|---|" + "---|" * len(pk) + "---|")
    for i, r in enumerate(shared, 1):
        cells = [str(r["lines"][k]) if k in r["lines"] else "" for k in pk]
        w(f"| {i} | {esc(r['id'])} | {r['category']} | {len(r['adopters'])} | " + " | ".join(cells)
          + f" | {r['total']} |")
    w("")
    by_count = collections.Counter(len(r["adopters"]) for r in rows)
    w(f"{len(rows)} entries are gaps for at least one package: " + ", ".join(
        f"{by_count[n]} for {n} {'package' if n == 1 else 'packages'}" for n in sorted(by_count, reverse=True)) + ".")
    w("")

    w(f"## The {RANKED} largest gaps across adopters")
    w("")
    w("Every gap, ranked by the lines all the adopters could delete together if System covered it.")
    w("")
    w("| # | Entry | Category | " + " | ".join(names[k] for k in pk) + " | Total | What's missing |")
    w("|---|---|---|" + "---|" * len(pk) + "---|---|")
    for i, r in enumerate(ranked[:RANKED], 1):
        cells = [f"{r['lines'][k]} ({' '.join(ABBREV[p] for p in r['platforms'][k])})" if k in r["lines"] else ""
                 for k in pk]
        note = r["note"]
        if len(note) > 200:
            note = note[:197].rsplit(" ", 1)[0] + " ..."
        w(f"| {i} | {esc(r['id'])} | {r['category']} | " + " | ".join(cells) + f" | {r['total']} | {esc(note)} |")
    w("")

    w("## How the estimates work")
    w("")
    w("Each package's number is the code its own sources could delete: the code lines of its thin wrapper functions "
      f"(up to {next(iter(covs.values()))['config']['thinWrapperLines']} lines) in the files its package file lists as "
      "its syscall layer, that reference the entry on a platform where it's a gap, plus the definitions of its C shims "
      "that the entry would retire. A function that references several gaps is split between them; one whose calls "
      "System covers already counts for no gap. Code a dependency would delete doesn't count for the package that "
      "uses it. Per package:")
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

    open(os.path.join(args.out, "COVERAGE.md"), "w").write("\n".join(out) + "\n")
    json.dump({"packages": {k: {"title": c["package"]["title"], "meta": c.get("meta", {})} for k, c in covs.items()},
               "missingPackages": missing_pkgs, "gaps": ranked, "shared": shared,
               "unusedSymbols": unused if not missing_pkgs else None},
              open(os.path.join(args.out, "coverage.json"), "w"), indent=1)
    print(f"combine: {len(covs)} packages, {len(rows)} gap entries, {len(shared)} shared")


if __name__ == "__main__":
    main()
