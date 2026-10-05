#!/usr/bin/env python3
"""High-value carve-outs: the suggestions that pass the vision's three tests
for a high-return pitch, ranked by what the update-checkout cluster would
use. report.py writes them as SUGGESTIONS.md's first section; run on its
own, this lists them from a run's suggestions.json.

A carve-out (a cluster, a part of one, or a batch) passes when it
  1. has a potential adopter in the update-checkout cluster: a package of
     scheme-main.tsv that uses it on its migration branch, or calls a C
     interface it newly wraps (reach.py's sites, adopted or would-benefit);
  2. establishes no new design pattern, approximated as no open question
     (contingencies.json's, direct or inherited) and no type promoted to
     shared vocabulary among its declarations;
  3. is a meaningful but not enormous chunk: config.json's `valueSize`
     declarations (3 to 60).
Passing carve-outs are ranked by their update-checkout sites, then by the
suggested order's penalty score. A part is listed only when its cluster
doesn't pass; the cluster's row counts the parts that pass too.

  value.py                                  # the ranking, from .build/api-graph
  value.py --dir DIR --scheme FILE --json   # another run, another scheme list
  value.py --all                            # every carve-out, with each test
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402

DEFAULT_SIZE = (3, 60)


def scheme_repos(path):
    """[(name, remote)] from scheme-main.tsv (name, ref, owner/repo, ...)."""
    with open(path, encoding="utf-8") as f:
        return parse_scheme(f.read())


def parse_scheme(text):
    out = []
    for line in text.split("\n"):
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        out.append((cols[0], cols[2].strip() if len(cols) > 2 else ""))
    return out


def cluster_keys(scheme, packages):
    """{adopter package key: scheme name} for the packages that are the
    scheme's repositories: by their remote (owner/repo, either case), else
    by name."""
    by_remote = {remote.lower(): name for name, remote in scheme if remote}
    by_name = {name.lower(): name for name, _ in scheme}
    out = {}
    for p in packages:
        remote = (p.get("remote") or "").lower().removesuffix(".git")
        name = by_remote.get(remote) or by_name.get((p.get("name") or "").lower()) or by_name.get(p["key"].lower())
        if name:
            out[p["key"]] = name
    return out


def units_of(doc):
    """{id: unit} for every cluster, part and batch of suggestions.json."""
    units = {}
    for c in doc["clusters"]:
        units[c["id"]] = c
        for p in c.get("parts", []):
            units[p["id"]] = p
    for b in doc.get("batches", []):
        units[b["id"]] = b
    return units


def tests(cand, unit, promoted, keys, size):
    """The three tests for one carve-out: {"adopter": [(scheme name, adopted,
    would benefit)], "open": [contingency ids], "vocabulary": [promoted
    types], "size": declarations, and pass flags}."""
    by_pkg = (cand.get("adopters") or {}).get("byPackage", {})
    cluster = sorted(((keys[k], v.get("adopted", 0), v.get("benefit", 0)) for k, v in by_pkg.items()
                      if k in keys and (v.get("adopted", 0) or v.get("benefit", 0))),
                     key=lambda x: (-(x[1] + x[2]), x[0]))
    opens = list(unit.get("direct", [])) + list((unit.get("inherited") or {}).keys())
    nodes = set(unit.get("nodes", []))
    vocab = sorted(p["type"] for p in promoted if p["id"] in nodes)
    n = cand["declarations"]
    out = {"adopter": cluster, "open": opens, "vocabulary": vocab, "declarations": n,
           "sites": sum(a + b for _, a, b in cluster)}
    out["passAdopter"] = bool(cluster)
    out["passPattern"] = not opens and not vocab
    out["passSize"] = size[0] <= n <= size[1]
    out["pass"] = out["passAdopter"] and out["passPattern"] and out["passSize"]
    return out


def rank(doc, scheme, size=None):
    """(rows, every carve-out's tests): the passing carve-outs, by
    update-checkout sites, then by the penalty score and the suggested
    order. A part whose cluster passes isn't a row of its own."""
    size = tuple(size or doc.get("config", {}).get("valueSize") or DEFAULT_SIZE)
    units = units_of(doc)
    keys = cluster_keys(scheme, doc.get("adopterPackages", []))
    part_of = {p["id"]: c["id"] for c in doc["clusters"] for p in c.get("parts", [])}
    every = {}
    for cand in doc["candidates"]:
        every[cand["id"]] = dict(tests(cand, units.get(cand["id"], {}), doc.get("promoted", []), keys, size),
                                 id=cand["id"], kind=cand["kind"], name=cand.get("name", ""), rank=cand["rank"],
                                 score=cand["score"], cluster=part_of.get(cand["id"]))
    rows = []
    for t in every.values():
        if not t["pass"]:
            continue
        if t["kind"] == "part" and every.get(t["cluster"], {}).get("pass"):
            continue
        t = dict(t, partsPassing=[p for p, c in part_of.items() if c == t["id"] and every.get(p, {}).get("pass")])
        rows.append(t)
    rows.sort(key=lambda t: (-t["sites"], t["score"], t["rank"], t["id"]))
    return rows, every, size


def md(s):
    return str(s).replace("|", "\\|")


def packages_cell(t):
    """`swift-nio 5 (3 used), swift-foundation 2`: sites per package."""
    return ", ".join(f"{name} {a + b}" + (f" ({a} used)" if a else "") for name, a, b in t["adopter"])


def section(w, doc, scheme, link=True):
    """SUGGESTIONS.md's first section."""
    rows, every, size = rank(doc, scheme)
    w("## High-value carve-outs")
    w("")
    n = len(every)
    fail = {k: sum(1 for t in every.values() if not t[k]) for k in ("passAdopter", "passPattern", "passSize")}
    w("The carve-outs that pass the vision's three tests for a high-return pitch, as `scripts/value.py` "
      "approximates them: (1) a potential adopter in the update-checkout cluster, a package of `scheme-main.tsv` "
      "that uses it on its migration branch or calls a C interface it newly wraps; (2) no new design pattern: no "
      "open question, directly or through what it needs, and no type promoted to shared vocabulary; (3) a "
      f"meaningful but not enormous chunk, {size[0]} to {size[1]} declarations (`config.json`'s `valueSize`). "
      "Ranked by the cluster's sites, adopted and would-benefit, then by the suggested order's score. A part "
      "is listed only when its cluster doesn't pass. The orders below are unchanged.")
    w("")
    w(f"{len(rows)} carve-outs pass (of {n} ranked; {fail['passAdopter']} have no update-checkout adopter, "
      f"{fail['passPattern']} an open question or a vocabulary type, {fail['passSize']} a size outside the range).")
    w("")
    if rows:
        w("| # | Carve-out | Kind | Decls | Update-checkout sites | Packages: sites | Order | Score |")
        w("|---:|---|---|---:|---:|---|---:|---:|")
        for k, t in enumerate(rows, 1):
            name = f"[`{t['id']}`](suggestions/{t['id']}/bundle.md)" if link else f"`{t['id']}`"
            parts = f", {len(t['partsPassing'])} of its parts too" if t["partsPassing"] else ""
            kind = t["kind"] + (f" of `{t['cluster']}`" if t["kind"] == "part" else "") + parts
            w(f"| {k} | {name} | {kind} | {t['declarations']} | {t['sites']} | {md(packages_cell(t))} | "
              f"{t['rank']} | {t['score']} |")
        w("")
    near = sorted((t for t in every.values() if not t["pass"] and t["passAdopter"]),
                  key=lambda t: (-t["sites"], t["score"]))[:10]
    if near:
        w("The carve-outs with the most update-checkout sites that fail a test, for judging the cut:")
        w("")
        for t in near:
            why = []
            if t["open"]:
                why.append("open questions: " + ", ".join(t["open"]))
            if t["vocabulary"]:
                why.append("shared vocabulary: " + ", ".join(f"`{v}`" for v in t["vocabulary"]))
            if not t["passSize"]:
                why.append(f"{t['declarations']} declarations")
            w(f"- `{t['id']}` ({t['kind']}, {t['sites']} sites: {md(packages_cell(t))}): {md('; '.join(why))}.")
        w("")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dir", default=os.path.join(".build", "api-graph"), help="a run's output (API_GRAPH_OUT)")
    ap.add_argument("--scheme", default=os.path.join("..", "ecosystem", "scheme-main.tsv"),
                    help="the update-checkout cluster's repositories (ecosystem.py's scheme-main.tsv)")
    ap.add_argument("--all", action="store_true", help="every carve-out, with each test's result")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    path = os.path.join(a.dir, "suggestions.json")
    if not os.path.exists(path):
        raise SystemExit(f"value: no suggestions.json in {a.dir}")
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    if not os.path.exists(a.scheme):
        raise SystemExit(f"value: no {a.scheme}")
    rows, every, _ = rank(doc, scheme_repos(a.scheme))
    out = sorted(every.values(), key=lambda t: (not t["pass"], -t["sites"], t["score"])) if a.all else rows
    if a.json:
        print(json.dumps(out, indent=1))
        return
    for k, t in enumerate(out, 1):
        flags = "".join(c if t[f] else "-" for c, f in (("A", "passAdopter"), ("P", "passPattern"), ("S", "passSize")))
        print(f"{k:>3} {flags} {t['sites']:>4} sites {t['declarations']:>3} decls  order {t['rank']:>3}  {t['id']}"
              f"  [{packages_cell(t)}]")


if __name__ == "__main__":
    main()
