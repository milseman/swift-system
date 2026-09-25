#!/usr/bin/env python3
"""Compare two runs' coverage.json for one package: what a change to the
tool or the mapping did to the results.

It compares the numbers and sets, not the report's text: the summary
tables, the check's problems (unmapped interfaces first), the gap ranking,
each entry's per-platform status and sites, each interface's sites,
platforms and evidence, the System API the package already calls, and the
extraction's cross-check. Keys the tool has renamed are read under both
names, so a run of nio-coverage compares with one of this tool.

Usage: compare.py OLD/coverage.json NEW/coverage.json
Exit status: 0 if they agree, 1 if not.
"""

import sys

sys.dont_write_bytecode = True

import json

RENAMED = {"nio": "own"}   # excludedReferences classes


def load(path):
    return json.load(open(path))


def diff_dict(label, old, new, out):
    for k in sorted(set(old) | set(new), key=str):
        if old.get(k) != new.get(k):
            out.append(f"{label}[{k}]: {old.get(k)!r} -> {new.get(k)!r}")


def main():
    old, new = load(sys.argv[1]), load(sys.argv[2])
    out = []

    for kind in ("functions", "all"):
        for cat in sorted(set(old["summary"][kind]) | set(new["summary"][kind])):
            o, n = old["summary"][kind].get(cat, {}), new["summary"][kind].get(cat, {})
            for p in sorted(set(o) | set(n)):
                if {k: v for k, v in o.get(p, {}).items() if v} != {k: v for k, v in n.get(p, {}).items() if v}:
                    out.append(f"summary {kind} / {cat} / {p}: {o.get(p)} -> {n.get(p)}")

    for k in sorted(set(old["problems"]) | set(new["problems"])):
        o, n = old["problems"].get(k, []), new["problems"].get(k, [])
        key = (lambda x: x.get("name") or x.get("entry") or json.dumps(x, sort_keys=True)) \
            if (o or n) and isinstance((o or n)[0], dict) else str
        so, sn = {key(x) for x in o}, {key(x) for x in n}
        if so != sn:
            out.append(f"problems {k}: removed {sorted(so - sn)}, added {sorted(sn - so)}")

    og = [(g["id"], g["total"], g["swiftLines"], g["cLines"], g["callSitesElsewhere"], tuple(g["gapPlatforms"]))
          for g in old["gaps"]]
    ng = [(g["id"], g["total"], g["swiftLines"], g["cLines"], g["callSitesElsewhere"], tuple(g["gapPlatforms"]))
          for g in new["gaps"]]
    if og != ng:
        od, nd = {g[0]: (i + 1, g) for i, g in enumerate(og)}, {g[0]: (i + 1, g) for i, g in enumerate(ng)}
        for gid in sorted(set(od) | set(nd), key=lambda g: (nd.get(g, od.get(g))[0], g)):
            if od.get(gid) != nd.get(gid):
                out.append(f"gap {gid}: {od.get(gid)} -> {nd.get(gid)}")

    oe, ne = {e["id"]: e for e in old["entries"]}, {e["id"]: e for e in new["entries"]}
    for eid in sorted(set(oe) | set(ne)):
        o, n = oe.get(eid), ne.get(eid)
        if o is None or n is None:
            if (o or n).get("used"):
                out.append(f"entry [{eid}]: {'added' if o is None else 'removed'} (used on {sorted((o or n)['used'])})")
            continue
        for k in ("status", "category", "used", "sites", "targets", "functionLike"):
            if o.get(k) != n.get(k):
                out.append(f"entry [{eid}] {k}: {o.get(k)} -> {n.get(k)}")
        ops = {p: v["status"] for p, v in o["platformStatus"].items()}
        nps = {p: v["status"] for p, v in n["platformStatus"].items()}
        if ops != nps:
            out.append(f"entry [{eid}] platformStatus: {ops} -> {nps}")

    oi, ni = old["interfaces"], new["interfaces"]
    for name in sorted(set(oi) | set(ni)):
        o, n = oi.get(name), ni.get(name)
        if o is None or n is None:
            out.append(f"interface {name}: {'added' if o is None else 'removed'}")
            continue
        for k in ("siteCount", "platforms", "evidence", "kinds", "targets", "members"):
            if o.get(k) != n.get(k):
                out.append(f"interface {name} {k}: {o.get(k)} -> {n.get(k)}")

    oa = {(a["module"], a["symbol"]): (a["sites"], a["onTip"]) for a in old.get("alreadySystem", [])}
    na = {(a["module"], a["symbol"]): (a["sites"], a["onTip"]) for a in new.get("alreadySystem", [])}
    diff_dict("alreadySystem", oa, na, out)

    ox, nx = old["extraction"], new["extraction"]
    for lang in ("swift", "c"):
        diff_dict(f"crosscheck {lang}", ox["crosscheck"].get(lang, {}), nx["crosscheck"].get(lang, {}), out)
    diff_dict("excludedReferences", {RENAMED.get(k, k): v for k, v in ox["excludedReferences"].items()},
              {RENAMED.get(k, k): v for k, v in nx["excludedReferences"].items()}, out)
    for k in ("libraryTargets", "shimTargets", "unsupportedPlatforms"):
        if ox.get(k) != nx.get(k):
            out.append(f"extraction {k}: {ox.get(k)} -> {nx.get(k)}")
    if len(ox.get("warnings", [])) != len(nx.get("warnings", [])):
        out.append(f"extraction warnings: {len(ox.get('warnings', []))} -> {len(nx.get('warnings', []))}")

    if out:
        print("\n".join(out))
        print(f"{len(out)} differences")
        return 1
    print("the same: summary counts, problems, gap ranking, entries, interfaces, System use and cross-check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
