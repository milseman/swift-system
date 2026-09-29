#!/usr/bin/env python3
"""Adopter reach: which packages use a carve-out's declarations, and which
would, from adopters.json (scripts/adopters.py). Imported by bundles.py and
report.py for their Adopters sections and columns, and run on its own to
rank or filter a run's carve-outs by reach:

  reach.py                               # every ranked carve-out, by reach
  reach.py --package swift-nio           # what one package uses or would
  reach.py --min 3 --kind part,cluster   # reaching at least 3 packages
  reach.py --sort rank --limit 20        # the pitch order, with reach
  reach.py --json                        # the same, machine-readable

A carve-out's reach is the number of packages that use it on their
migration branch or would benefit from it; ties go to more packages using
it, then to more sites. Qualifier-only uses (`PThread` in `PThread.Mutex`)
don't count: the nested type's carve-out has the use, and needs this one.

Usage: reach.py [--dir .build/api-graph] [--sort reach|using|benefit|sites|rank]
                [--package KEY] [--kind cluster,part,batch] [--min N]
                [--limit N] [--json]
"""

import argparse
import collections
import json
import os


def load(path):
    return json.load(open(path, encoding="utf-8")) if path and os.path.exists(path) else None


def aggregate(adopters, node_ids):
    """Per package, the unit's adopted and would-benefit sites.

    {"packages": {key: {"adopted": [site], "qualifiers": n, "benefit": [site],
                        "declarationsUsed": [nid], "interfaces": Counter}},
     "using": [key], "benefiting": [key], "reach": n, "sites": n}"""
    out = {"packages": {}, "using": [], "benefiting": [], "reach": 0, "sites": 0}
    if not adopters:
        return out
    pk = collections.defaultdict(lambda: {"adopted": [], "qualifiers": 0, "benefit": [], "declarationsUsed": set(),
                                          "interfaces": collections.Counter()})
    seen_a, seen_b = set(), set()
    A, B = adopters["adoptedSites"], adopters["benefitSites"]
    for nid in node_ids:
        for k in adopters["adopted"].get(nid, ()):
            s = A[k]
            if s["qualifier"]:
                pk[s["package"]]["qualifiers"] += 1
                continue
            key = (s["package"], s["file"], s["line"], s["node"])
            if key in seen_a:
                continue
            seen_a.add(key)
            pk[s["package"]]["adopted"].append(s)
            pk[s["package"]]["declarationsUsed"].add(s["node"])
        for k in adopters["benefit"].get(nid, ()):
            if k in seen_b:
                continue
            seen_b.add(k)
            s = B[k]
            pk[s["package"]]["benefit"].append(s)
            pk[s["package"]]["interfaces"][s["interface"]] += 1
    for key, v in pk.items():
        v["adopted"].sort(key=lambda s: (s["file"], s["line"], s["column"]))
        v["benefit"].sort(key=lambda s: (s["file"], s["line"], s["interface"]))
        v["declarationsUsed"] = sorted(v["declarationsUsed"])
    out["packages"] = dict(sorted(pk.items()))
    out["using"] = sorted(k for k, v in pk.items() if v["adopted"])
    out["benefiting"] = sorted(k for k, v in pk.items() if v["benefit"])
    out["reach"] = len(set(out["using"]) | set(out["benefiting"]))
    out["sites"] = sum(len(v["adopted"]) + len(v["benefit"]) for v in pk.values())
    out["adoptedSites"] = sum(len(v["adopted"]) for v in pk.values())
    out["benefitSites"] = sum(len(v["benefit"]) for v in pk.values())
    return out


def summary(agg):
    """The compact form api-graph.json and the tables keep."""
    return {"reach": agg["reach"], "using": agg["using"], "benefiting": agg["benefiting"],
            "adoptedSites": agg.get("adoptedSites", 0), "benefitSites": agg.get("benefitSites", 0),
            "byPackage": {k: {"adopted": len(v["adopted"]),
                              "precise": sum(1 for s in v["adopted"] if s["resolution"] == "precise"),
                              "declarationsUsed": len(v["declarationsUsed"]), "qualifiers": v["qualifiers"],
                              "benefit": len(v["benefit"]),
                              "benefitPrecise": sum(1 for s in v["benefit"] if s["resolution"] == "precise"),
                              "interfaces": dict(v["interfaces"].most_common())}
                          for k, v in agg["packages"].items()}}


def cell(s):
    """'2 / 5': packages using / packages that would benefit."""
    if not s:
        return "—"
    return f"{len(s['using'])} / {len(s['benefiting'])}"


def order_key(sort):
    return {
        "reach": lambda x: (-x["reach"]["reach"], -len(x["reach"]["using"]), -(x["reach"]["adoptedSites"]
                                                                              + x["reach"]["benefitSites"]),
                            x["rank"]),
        "using": lambda x: (-len(x["reach"]["using"]), -x["reach"]["adoptedSites"], x["rank"]),
        "benefit": lambda x: (-len(x["reach"]["benefiting"]), -x["reach"]["benefitSites"], x["rank"]),
        "sites": lambda x: (-(x["reach"]["adoptedSites"] + x["reach"]["benefitSites"]), x["rank"]),
        "rank": lambda x: x["rank"],
    }[sort]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dir", default=os.path.join(".build", "api-graph"),
                    help="a run's output directory (API_GRAPH_OUT)")
    ap.add_argument("--sort", choices=("reach", "using", "benefit", "sites", "rank"), default="reach")
    ap.add_argument("--package", help="only carve-outs this package uses or would benefit from")
    ap.add_argument("--kind", default="", help="cluster, part, batch (comma-separated)")
    ap.add_argument("--min", type=int, default=0, help="minimum reach")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    doc = load(os.path.join(a.dir, "api-graph.json"))
    if not doc:
        raise SystemExit(f"reach: no api-graph.json in {a.dir}")
    kinds = set(x for x in a.kind.split(",") if x)
    rows = []
    for c in doc["candidates"]:
        r = c.get("adopters")
        if r is None:
            raise SystemExit("reach: this run has no adopter data (API_GRAPH_ADOPTERS was empty)")
        if kinds and c["kind"] not in kinds:
            continue
        if r["reach"] < a.min:
            continue
        if a.package and a.package not in r["byPackage"]:
            continue
        rows.append({"rank": c["rank"], "id": c["id"], "kind": c["kind"], "declarations": c["declarations"],
                     "name": c["name"], "reach": r})
    rows.sort(key=order_key(a.sort))
    if a.limit:
        rows = rows[:a.limit]
    if a.json:
        print(json.dumps(rows, indent=1))
        return
    print(f"{'rank':>4}  {'reach':>5}  {'use/ben':>7}  {'sites':>6}  {'kind':<7} carve-out")
    for x in rows:
        r = x["reach"]
        extra = ""
        if a.package:
            b = r["byPackage"][a.package]
            extra = f"   [{a.package}: {b['adopted']} adopted, {b['benefit']} would benefit]"
        print(f"{x['rank']:>4}  {r['reach']:>5}  {cell(r):>7}  {r['adoptedSites'] + r['benefitSites']:>6}  "
              f"{x['kind']:<7} {x['id']}{extra}")
        if not a.package:
            if r["using"]:
                print(f"{'':>34}using: {', '.join(r['using'])}")
            if r["benefiting"]:
                print(f"{'':>34}would benefit: {', '.join(r['benefiting'])}")


if __name__ == "__main__":
    main()
