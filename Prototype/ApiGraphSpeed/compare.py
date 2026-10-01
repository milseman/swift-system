#!/usr/bin/env python3
"""Compares the adopter links of two api-graph snapshots: `usedBy` (a
declaration a package's migration branch uses) and `calls` (a package calling
a C name), each with its sites, and the hunks the sites cite. A migration's
build record (whether its index was reused, and how long it took) is left
out, since that's what the runs compared are meant to differ in; its index's
resolution and site counts aren't.

  compare.py A.json.gz B.json.gz [--limit 10]

Prints each difference, and exits 1 if there's any.
"""

import argparse
import collections
import gzip
import json


def load(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8") as f:
        return json.load(f)


def site_key(s):
    return json.dumps(s, sort_keys=True)


def adopter_links(snap):
    out = {}
    for ln in snap["links"]:
        if ln["kind"] in ("usedBy", "calls"):
            out[(ln["kind"], ln["from"], ln["to"])] = sorted(site_key(s) for s in ln.get("sites") or [])
    return out


def packages(snap):
    out = {}
    for nid, n in snap["nodes"].items():
        if n.get("kind") == "package":
            ad = n.get("adopted") or {}
            out[nid] = {"resolution": ad.get("resolution"), "sites": ad.get("sites"), "commit": ad.get("commit"),
                        "benefit": {k: (n.get("benefit") or {}).get(k) for k in ("commit", "source", "sites")}}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--limit", type=int, default=10)
    args = ap.parse_args()
    A, B = load(args.a), load(args.b)
    la, lb = adopter_links(A), adopter_links(B)
    diffs = 0

    def say(text):
        nonlocal diffs
        diffs += 1
        if diffs <= args.limit:
            print("  " + text)

    counts = collections.Counter()
    for k in sorted(set(la) | set(lb)):
        kind = k[0]
        if k not in lb:
            say(f"only in A: {k} ({len(la[k])} sites)")
        elif k not in la:
            say(f"only in B: {k} ({len(lb[k])} sites)")
        elif la[k] != lb[k]:
            sa, sb = set(la[k]), set(lb[k])
            say(f"sites differ: {k}: {len(sa - sb)} only in A, {len(sb - sa)} only in B; "
                f"e.g. {sorted(sa - sb)[:1] or sorted(sb - sa)[:1]}")
        else:
            counts[kind] += 1
    ha, hb = A.get("hunks") or {}, B.get("hunks") or {}
    for h in sorted(set(ha) | set(hb)):
        if ha.get(h) != hb.get(h):
            say(f"hunk {h}: {'only in A' if h not in hb else 'only in B' if h not in ha else 'differs'}")
    pa, pb = packages(A), packages(B)
    for p in sorted(set(pa) | set(pb)):
        if pa.get(p) != pb.get(p):
            say(f"package {p}: {pa.get(p)} vs {pb.get(p)}")
    n_sites = sum(len(v) for v in la.values())
    print(f"A: {len(la)} adopter links, {n_sites} sites; B: {len(lb)} links, {sum(len(v) for v in lb.values())} sites; "
          f"identical: {dict(sorted(counts.items()))}; {len(set(ha) & set(hb))} hunks in both; "
          f"{diffs} difference{'s' if diffs != 1 else ''}" + (f" ({diffs - args.limit} not shown)"
                                                               if diffs > args.limit else ""))
    raise SystemExit(1 if diffs else 0)


if __name__ == "__main__":
    main()
