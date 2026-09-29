#!/usr/bin/env python3
"""Write API-GRAPH.md, the graph exports, and the comparison with a previous run.

  API-GRAPH.md        the map: summary, pitch order, clusters, contingencies,
                      shared vocabulary, a cluster map, where the tool is
                      wrong, changes since the previous run, and the method
  api-graph.json      clusters.json plus the run's metadata
  clusters.dot        clusters and their prerequisites, for Graphviz
  atoms.dot           the atom graph (top-level blocks), colored by cluster

Usage: report.py --graph graph.json --clusters clusters.json --meta meta.json
                 --out DIR [--previous old-api-graph.json]
"""

import argparse
import collections
import json
import os
import re

import reach

HERE = os.path.dirname(os.path.abspath(__file__))
PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
SHORT = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
         "Windows": "Win"}
TOP = 15


def load(p):
    return json.load(open(p))


def md(s):
    return re.sub(r"([|])", r"\\\1", s)


def plat(ps):
    return " ".join(SHORT[p] for p in PLATFORMS if p in (ps or [])) or "?"


def compare(prev, cur):
    """Clusters matched by id, then by the declarations they share."""
    def index(doc):
        out = {}
        for c in doc["clusters"]:
            out[c["id"]] = c
        return out
    old, new = index(prev), index(cur)
    old_nodes = {k: set(c["nodes"]) for k, c in old.items()}
    new_nodes = {k: set(c["nodes"]) for k, c in new.items()}
    matched, rows = {}, []
    for k in new:
        if k in old:
            matched[k] = k
    for k in new:
        if k in matched:
            continue
        best, overlap = None, 0
        for ok, ons in old_nodes.items():
            if ok in matched.values():
                continue
            ov = len(new_nodes[k] & ons)
            if ov > overlap:
                best, overlap = ok, ov
        if best and overlap * 2 >= min(len(new_nodes[k]), len(old_nodes[best])):
            matched[k] = best
    added = [k for k in new if k not in matched]
    removed = [k for k in old if k not in matched.values()]
    for k, ok in sorted(matched.items()):
        c, o = new[k], old[ok]
        changes = []
        if k != ok:
            changes.append(f"renamed from `{ok}`")
        grew = len(new_nodes[k] - old_nodes[ok])
        shrank = len(old_nodes[ok] - new_nodes[k])
        if grew or shrank:
            changes.append(f"+{grew}/−{shrank} declarations")
        oc, nc = set(o["direct"]) | set(o["inherited"]), set(c["direct"]) | set(c["inherited"])
        if oc != nc:
            if nc - oc:
                changes.append("now depends on " + ", ".join(sorted(nc - oc)))
            if oc - nc:
                changes.append("no longer depends on " + ", ".join(sorted(oc - nc)))
        ro, rn = o.get("rank"), c.get("rank")
        small_moves = 0
        if ro != rn and ro and rn:
            if abs(ro - rn) >= 5 or (ro <= TOP) != (rn <= TOP):
                changes.append(f"rank {ro} → {rn}")
            elif not changes:
                small_moves = 1
        if changes:
            rows.append((k, changes))
        elif small_moves:
            rows.append((k, None))
    return added, removed, rows, matched


def reach_section(w, adopters, cands, units, md):
    """## Adopter reach: the packages, the carve-outs by reach, and each
    package's carve-outs."""
    am = adopters["meta"]
    branch = am["branch"]
    pk = adopters["packages"]
    w("## Adopter reach")
    w("")
    w(f"Which packages use each carve-out's declarations on their `{branch}` branch (*using*), and which call "
      "C interfaces it newly wraps (*would benefit*). A carve-out's reach is the number of packages that do "
      "either. Adopted sites are the migration's uses, precise where the compiler's index of a build of the "
      "branch against this head resolved them and lexical elsewhere; would-benefit sites are the coverage "
      "tools' extraction of each package joined with the C names in the declarations' doc comments, less the "
      "names the base commit already covers. Each carve-out's bundle lists its sites and quotes the hunks "
      "that introduced them.")
    w("")
    w("To rank or filter by reach, run `Utilities/api-graph/scripts/reach.py` on this output: `--package "
      "swift-nio`, `--min 3`, `--kind part`, `--sort using|benefit|sites|rank`, `--json`.")
    w("")
    w("### The packages")
    w("")
    w(f"Found in `{am['adopters']}` and `{am['ecosystem']}`; a clone of a new package in either is picked up "
      "by the next run.")
    w("")
    w(f"| Package | `{branch}` | Resolution | Adopted sites | Carve-outs using | Interface data | "
      "Would-benefit sites | Carve-outs it would benefit from |")
    w("|---|---|---|---:|---:|---|---:|---:|")
    for p in pk:
        ad, be = p["adopted"], p["benefit"]
        using = [x for x in cands if p["key"] in x["adopters"]["using"]]
        benefiting = [x for x in cands if p["key"] in x["adopters"]["benefiting"]]
        if ad:
            b = ad["build"] or {}
            mig = f"`{ad['commit'][:10]}`, {ad['commits']} commit{'s' if ad['commits'] != 1 else ''}"
            res = {"index": "index", "partial index": "partial index", "lexical": "lexical"}[ad["resolution"]]
            if b.get("status") not in ("indexed",) and b.get("reason"):
                res += f" ({md(b['reason'][:90])})"
            sites = f"{ad['sites']['precise'] + ad['sites']['lexical']} ({ad['sites']['precise']} precise)"
        else:
            mig = (p.get("adoptersClone") or {}).get("note", "—")
            res, sites = "—", "—"
        if be:
            dat = (f"{be['role']} `{be['commit'][:10]}`: "
                   + ("coverage extraction" + (" (lexical)" if be["extraction"] == "lexical" else "")
                      if be["source"] == "coverage" else "lexical scan"))
            bsites = str(be["sites"])
        else:
            dat, bsites = "—", "—"
        w(f"| `{p['name']}` | {mig} | {res} | {sites} | {len(using)} | {dat} | {bsites} | {len(benefiting)} |")
    w("")
    order = sorted(cands, key=reach.order_key("reach", get=lambda x: x["adopters"]))
    shown = [x for x in order if x["adopters"]["reach"]][:25]
    w(f"### Carve-outs by reach")
    w("")
    w(f"The {len(shown)} with the widest reach; `reach.py` lists all of them. Pitch rank is the order above.")
    w("")
    w("| | Carve-out | Kind | Pitch rank | Decls | Reach | Using | Would benefit | Sites (adopted / would benefit) |")
    w("|---:|---|---|---:|---:|---:|---|---|---|")
    for k, x in enumerate(shown, 1):
        r = x["adopters"]
        w(f"| {k} | [`{x['id']}`](bundles/{x['id']}/bundle.md) | {x['kind']} | {x['rank']} | {x['declarations']} | "
          f"{r['reach']} | {', '.join(r['using']) or '—'} | {', '.join(r['benefiting']) or '—'} | "
          f"{r['adoptedSites']} / {r['benefitSites']} |")
    w("")
    w("### By package")
    w("")
    for p in pk:
        using = sorted((x for x in cands if p["key"] in x["adopters"]["using"]),
                       key=lambda x: -x["adopters"]["byPackage"][p["key"]]["adopted"])
        ben = sorted((x for x in cands if p["key"] in x["adopters"]["benefiting"]),
                     key=lambda x: -x["adopters"]["byPackage"][p["key"]]["benefit"])
        if not using and not ben:
            continue
        w(f"- **`{p['name']}`**"
          + (f" uses {len(using)}: " + ", ".join(f"`{x['id']}` ({x['adopters']['byPackage'][p['key']]['adopted']})"
                                                for x in using[:12]) + (", …" if len(using) > 12 else "")
             if using else "")
          + ("; it " if using and ben else " ")
          + (f"would benefit from {len(ben)}: " + ", ".join(
              f"`{x['id']}` ({x['adopters']['byPackage'][p['key']]['benefit']})" for x in ben[:8])
             + (", …" if len(ben) > 8 else "") if ben else "")
          + ".")
    w("")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--clusters", required=True)
    ap.add_argument("--meta", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--previous")
    ap.add_argument("--adopters", help="adopters.json, from adopters.py")
    a = ap.parse_args()

    g = load(a.graph)
    cl = load(a.clusters)
    meta = load(a.meta)
    nodes, edges, atoms, vocab = g["nodes"], g["edges"], g["atoms"], g["vocabulary"]
    conts = {c["id"]: c for c in cl["contingencies"]}
    clusters = cl["clusters"]
    by_id = {c["id"]: c for c in clusters}
    units = dict(by_id)
    for c in clusters:
        for p in c["parts"]:
            units[p["id"]] = p
    for b in cl["batches"]:
        units[b["id"]] = b
    cands = cl["candidates"]

    adopters = load(a.adopters) if a.adopters and os.path.exists(a.adopters) else None
    if adopters:
        # Every unit's reach, kept in api-graph.json for reach.py.
        for u in list(units.values()) + [x for c in clusters for x in c["parts"]]:
            if "adopters" not in u:
                u["adopters"] = reach.summary(reach.aggregate(
                    adopters, [n for n in u["nodes"] if nodes[n]["hiddenClass"] != "unavailable"]))
        for x in cands:
            x["adopters"] = units[x["id"]]["adopters"]
    doc = dict(cl, meta=meta)
    if adopters:
        doc["adopterPackages"] = [{k: v for k, v in p.items()} for p in adopters["packages"]]
        doc["adopterMeta"] = adopters["meta"]
    json.dump(doc, open(os.path.join(a.out, "api-graph.json"), "w"), indent=1)

    L = []
    w = L.append
    w(f"# API graph: `{meta['baseRef']}` → `{meta['headRef']}`")
    w("")
    for side in ("base", "head"):
        w(f"- {side.capitalize()}: `{meta[side + 'Ref']}` @ `{meta[side + 'Commit']}` — {md(meta.get(side + 'Subject', ''))}")
    w("")
    w(f"Generated {meta['date']} on {meta['host']} with {meta['swift']}. This is a map for carving the API "
      f"`{meta['headRef']}` adds into small pitches: which declarations belong together, what each group "
      "depends on, which open design questions it waits on, and which could go first. Every carve-out has a "
      "bundle in `bundles/` for a pitch-writing session. [How this was generated](#how-this-was-generated) "
      "records each design decision and the alternative it rejected.")
    w("")

    # ------------------------------------------------------------ summary
    n_graph = sum(1 for n in nodes.values() if n["source"] == "graph")
    n_scan = len(nodes) - n_graph
    n_stub = sum(1 for n in nodes.values() if n["hiddenClass"] == "unavailable")
    kinds = collections.Counter(e["kind"] for e in edges)
    to_vocab = collections.Counter(vocab[e["to"]]["path"] for e in edges if e["to"] in vocab
                                   and vocab[e["to"]]["why"] == "base")
    free = [c for c in clusters if not c["direct"] and not c["inherited"]]
    w("## Summary")
    w("")
    w(f"- **{len(nodes)} declarations** are new or changed: {n_graph} from the macOS symbol graphs and {n_scan} "
      f"that only the source scan sees ({n_stub} of them `unavailable` fix-it stubs, the rest compiled only off "
      "Darwin, or underscored).")
    w(f"- **{len(edges)} edges**: " + ", ".join(f"{v} {k}" for k, v in kinds.most_common()) + f", between "
      f"{len(atoms)} atoms (top-level blocks, and CInterop aliases one by one).")
    w("- Shared vocabulary on the base commit, most used first: "
      + ", ".join(f"`{k}` ×{v}" for k, v in to_vocab.most_common(10)) + ".")
    if cl["promoted"]:
        w("- **New types promoted to shared vocabulary**: " + "; ".join(
            f"`{p['type']}`, which code in {len(p['places'])} places outside `{p['home']}` uses ("
            + ", ".join(f"`{x.split(':', 1)[1]}`" for x in p["places"]) + ")" for p in cl["promoted"]) + ".")
    sizes = collections.Counter("1-5" if c["metrics"]["declarations"] <= 5 else "6-20" if c["metrics"]["declarations"] <= 20
                                else "21-60" if c["metrics"]["declarations"] <= 60 else "over 60" for c in clusters)
    nb = len(cl["batches"])
    w(f"- **{len(clusters)} clusters**: " + ", ".join(f"{sizes[k]} of {k} declarations" for k in
                                                     ("1-5", "6-20", "21-60", "over 60") if sizes[k])
      + f". {sum(1 for c in clusters if c['parts'])} of them have parts that could be pitched separately "
      f"({sum(len(c['parts']) for c in clusters)} parts), and {nb} batch{'es' if nb != 1 else ''} "
      f"group{'s' if nb == 1 else ''} small wrapper clusters.")
    w(f"- **{len(free)} clusters depend on none of the open questions**, directly or through what they need: "
      f"{sum(c['metrics']['declarations'] for c in free)} of {sum(c['metrics']['declarations'] for c in clusters)} "
      "declarations. They're the candidates for early pitches.")
    verified = collections.Counter()
    for c in clusters:
        m = c["metrics"]
        key = ("Darwin only" if m["platforms"] == ["Darwin"] else
               "not compiled on Darwin" if not m["darwin"] else
               "with some off-Darwin code typechecked" if m["verifiedOffDarwin"] else
               "claiming other platforms, unverified")
        verified[key] += 1
    w("- **Off Darwin**: " + ", ".join(f"{v} cluster{'s' if v != 1 else ''} {k}" for k, v in verified.most_common())
      + ". Nothing in this checkout builds for Linux, Windows or WASI, so a platform a declaration's `#if` "
      "allows is only claimed unless `evidence.json` records a check.")
    if adopters:
        am = adopters["meta"]
        mig = [p for p in adopters["packages"] if p["adopted"]]
        dat = [p for p in adopters["packages"] if p["benefit"]]
        used = [x for x in cands if x["adopters"]["using"]]
        ben = [x for x in cands if x["adopters"]["benefiting"]]
        n_used = len({s["node"] for s in adopters["adoptedSites"] if not s["qualifier"]})
        w(f"- **Adopters**: {len(mig)} packages have a migration on `{am['branch']}`, and together use "
          f"{n_used} of the new declarations, in {len(used)} of the {len(cands)} carve-outs; "
          f"{sum(1 for p in mig if p['adopted']['resolution'] == 'index')} of them were resolved by the index of "
          f"a build against this head. {len(dat)} packages have C interface data, and {len(ben)} carve-outs wrap "
          "C interfaces that some of them call. See [Adopter reach](#adopter-reach).")
    w("")

    # ------------------------------------------------------------ pitch order
    w("## Pitch order")
    w("")
    w("Carve-outs easiest first: clusters, the parts of clusters over "
      f"{cl['config']['partsForClustersOver']} declarations, and batches of small wrapper clusters in place "
      "of their members. The order is by a penalty score (see the method), except that nothing comes before "
      "a carve-out it needs. An open question costs far more than size, so every carve-out with none comes "
      "first.")
    w("")
    w(f"### The top {TOP}")
    w("")
    for x in cands[:TOP]:
        u = units[x["id"]]
        extra = ""
        if adopters:
            r = x["adopters"]
            extra = (f" Adopters: {len(r['using'])} using it" + (f" ({', '.join(r['using'])})" if r["using"] else "")
                     + f", {len(r['benefiting'])} would benefit.")
        w(f"{x['rank']}. **`{x['id']}`** — {md(u['name'])} ({x['kind']}, score {x['score']}). {md(x['reason'])}."
          + extra)
    w("")
    w("### All of them")
    w("")
    acol = " Adopters |" if adopters else ""
    w("| # | Carve-out | Kind | Decls | Open questions | Needs | Platforms |" + acol + " Score |")
    w("|---:|---|---|---:|---|---|---|" + ("---:|" if adopters else "") + "---:|")
    for x in cands:
        u = units[x["id"]]
        opens = [conts[k]["title"] for k in u["direct"]] + [
            conts[k]["title"] + {"api": " (inh.)", "implementation": " (impl.)", "nesting": " (nesting)"}[v["through"]]
            for k, v in u["inherited"].items()]
        needs = list(u["allPrerequisites"]) + [k + " (impl.)" for k in u.get("implPrerequisites", {})]
        w(f"| {x['rank']} | [`{x['id']}`](bundles/{x['id']}/bundle.md) | {x['kind']} | {x['declarations']} | "
          f"{md(', '.join(opens)) or '—'} | {md(', '.join(needs)) or '—'} | {plat(u['metrics']['platforms'])} | "
          + (f"{reach.cell(x['adopters'])} | " if adopters else "") + f"{x['score']} |")
    w("")
    w("Platforms: " + ", ".join(f"{v} {k}" for k, v in SHORT.items()) + "."
      + (" Adopters: packages using the carve-out on their migration branch / packages that would benefit "
         "(see [Adopter reach](#adopter-reach))." if adopters else ""))
    w("")
    if adopters:
        reach_section(w, adopters, cands, units, md)

    # ------------------------------------------------------------ clusters
    w("## Clusters")
    w("")
    w("A cluster is a connected piece of the graph once shared vocabulary is taken out. Types on the base "
      "commit are vocabulary, and so are new types promoted to it; an edge into a promoted type becomes a "
      "prerequisite instead. Sizes count declarations, not fix-it stubs.")
    w("")
    w("| Cluster | Decls | Types | Stubs | Parts | Files | Platforms | Off Darwin | Docs | Tests | Open (direct) | "
      "Inherited | Needs |" + (" Adopters |" if adopters else ""))
    w("|---|---:|---:|---:|---:|---:|---|---|---:|---:|---|---|---|" + ("---:|" if adopters else ""))
    for c in sorted(clusters, key=lambda c: -c["metrics"]["declarations"]):
        m = c["metrics"]
        off = ("—" if m["platforms"] == ["Darwin"] else "not compiled here" if not m["darwin"] else
               "typechecked: " + ", ".join(sorted({p for v in m["verifiedOffDarwin"] for p in v["platforms"]}))
               if m["verifiedOffDarwin"] else "unverified")
        inh = ", ".join(f"{conts[k]['title']} ({v['through']}, via {v['via']})" for k, v in c["inherited"].items())
        needs = ", ".join(list(c["allPrerequisites"]) + [k + " (impl.)" for k in c.get("implPrerequisites", {})])
        w(f"| [`{c['id']}`](bundles/{c['id']}/bundle.md) | {m['declarations']} | {m['types']} | {m['stubs']} | "
          f"{len(c['parts'])} | {len(m['files'])} | {plat(m['platforms'])} | {off} | "
          f"{round(100 * m['documented'] / max(1, m['declarations']))}% | "
          f"{round(100 * m['tested'] / max(1, m['declarations']))}% | "
          f"{md(', '.join(conts[k]['title'] for k in c['direct'])) or '—'} | {md(inh) or '—'} | {md(needs) or '—'} |"
          + (f" {reach.cell(c['adopters'])} |" if adopters else ""))
    w("")
    multi = [c for c in clusters if c["parts"]]
    if multi:
        w("### Parts of the multi-part clusters")
        w("")
        w("In dependency order within each cluster: a part needs only parts listed before it, or other clusters.")
        w("")
        for c in sorted(multi, key=lambda c: -c["metrics"]["declarations"]):
            w(f"**`{c['id']}`** ({c['metrics']['declarations']} declarations):")
            w("")
            order, placed = [], set()
            parts = {p["id"]: p for p in c["parts"]}
            while len(order) < len(parts):
                ready = [p for k, p in sorted(parts.items()) if k not in placed and
                         all(q in placed or q not in parts for q in p["prerequisites"])]
                pick = ready[0] if ready else next(p for k, p in sorted(parts.items()) if k not in placed)
                order.append(pick)
                placed.add(pick["id"])
            for p in order:
                needs = [q for q in p["prerequisites"]]
                w(f"- `{p['id']}` — {md(p['name'])}: {p['metrics']['declarations']} declarations"
                  + (f"; needs {', '.join('`' + q + '`' for q in needs)}" if needs else "")
                  + (f"; open: {', '.join(conts[k]['title'] for k in p['direct'])}" if p["direct"] else ""))
            w("")

    # ------------------------------------------------------------ contingencies
    w("## Open questions")
    w("")
    w("Each question with the carve-outs that depend on it. \"Would free\" counts the carve-outs whose only "
      "open question it is, so settling it would make them contingency-free.")
    w("")
    all_units = [units[x["id"]] for x in cands]
    w("| Question | Decisions | Direct | Inherited | Would free |")
    w("|---|---|---:|---:|---:|")
    for cid, c in conts.items():
        d_ = [u for u in all_units if cid in u["direct"]]
        i_ = [u for u in all_units if cid in u["inherited"]]
        only = [u for u in all_units if set(u["direct"]) | set(u["inherited"]) == {cid}]
        w(f"| {c['title']} | {c['decisions']} | {len(d_)} | {len(i_)} | {len(only)} |")
    w("")
    for cid, c in conts.items():
        d_ = [u for u in all_units if cid in u["direct"]]
        i_ = [u for u in all_units if cid in u["inherited"]]
        only = [u for u in all_units if set(u["direct"]) | set(u["inherited"]) == {cid}]
        w(f"### {c['title']} ({c['decisions']})")
        w("")
        w(c["question"])
        if c.get("deliberatelyOpen"):
            w("")
            w(f"**Deliberately open.** {c['deliberatelyOpen']}")
        w("")
        if not d_ and not i_:
            w("No carve-out depends on it on this commit.")
            w("")
            continue
        if d_:
            w("Directly: " + ", ".join(f"`{u['id']}` ({u['direct'][cid]['count']})" for u in d_) + ".")
            w("")
            ev = []
            for u in d_:
                ev += u["direct"][cid]["evidence"][:2]
            w("For example: " + "; ".join(md(e) for e in list(dict.fromkeys(ev))[:6]) + ".")
            w("")
        if i_:
            w("Inherited: " + ", ".join(f"`{u['id']}` ({u['inherited'][cid]['through']}, via "
                                        f"`{u['inherited'][cid]['via']}`)" for u in i_) + ".")
            w("")
        if only:
            w("Settling it alone would free: " + ", ".join(f"`{u['id']}`" for u in only) + ".")
            w("")

    # ------------------------------------------------------------ vocabulary
    w("## Shared vocabulary")
    w("")
    if cl["promoted"]:
        w("New types promoted to shared vocabulary, and the places that depend on them:")
        w("")
        for p in cl["promoted"]:
            w(f"- `{p['type']}` (cluster `{p['cluster']}`, home `{p['home']}`): "
              + "; ".join(f"`{pl.split(':', 1)[1]}` ({len(atl)} block{'s' if len(atl) != 1 else ''})"
                          for pl, atl in p["places"].items()))
        w("")
    w("Existing types the new API uses most, by edges from new declarations:")
    w("")
    w("| Type | Edges | Clusters using it |")
    w("|---|---:|---:|")
    users = collections.defaultdict(set)
    node_cluster = {}
    for c in clusters:
        for nid in c["nodes"]:
            node_cluster[nid] = c["id"]
    for e in edges:
        if e["to"] in vocab and vocab[e["to"]]["why"] == "base" and e["from"] in node_cluster:
            users[vocab[e["to"]]["path"]].add(node_cluster[e["from"]])
    for k, v in to_vocab.most_common(20):
        w(f"| `{k}` | {v} | {len(users[k])} |")
    w("")

    # ------------------------------------------------------------ map
    w("## Cluster map")
    w("")
    w("Clusters with a prerequisite or a dependent; an arrow points from a cluster to what it needs, dashed "
      "when only its implementation needs it. Green clusters depend on no open question. `clusters.dot` has "
      "every cluster, and `atoms.dot` the blocks they're made of.")
    w("")
    linked = set()
    for c in clusters:
        for k in list(c["prerequisites"]) + list(c.get("implPrerequisites", {})):
            linked |= {c["id"], k}
    w("```mermaid")
    w("flowchart LR")

    def mid(s):
        return re.sub(r"[^A-Za-z0-9_]", "_", s)
    for c in clusters:
        if c["id"] in linked:
            w(f'  {mid(c["id"])}["{c["name"]}<br/>{c["metrics"]["declarations"]}"]')
    for c in clusters:
        for k in c["prerequisites"]:
            w(f"  {mid(c['id'])} --> {mid(k)}")
        for k in c.get("implPrerequisites", {}):
            w(f"  {mid(c['id'])} -.-> {mid(k)}")
    for c in clusters:
        if c["id"] in linked and not c["direct"] and not c["inherited"]:
            w(f"  style {mid(c['id'])} fill:#d4f7d4")
    w("```")
    w("")

    # ------------------------------------------------------------ caveats
    w("## Where this run's map is uncertain")
    w("")
    w("The method's limitations list is general; these are this run's instances of them.")
    w("")
    lexical = [n["path"] for n in nodes.values() if n.get("lexicalTests")]
    w(f"- **Tests matched by name**: {len(lexical)} declarations aren't compiled on Darwin, so their tests "
      "(also not compiled here) were matched by name, not by the index. " +
      ("For example: " + ", ".join(f"`{x}`" for x in lexical[:8]) + "." if lexical else ""))
    heur = [(u["id"], cid) for u in all_units for cid, info in u["direct"].items() if info["weight"] < 1]
    if heur:
        w("- **Name overlaps, not dependencies**: weaker tags from a concept a Win32 draft covers or a type "
          "nested in FilePath: " + ", ".join(f"`{i}` ({conts[c]['title']})" for i, c in heur[:12]) + ".")
    impl_only = [(c["id"], k) for c in clusters for k in c.get("implPrerequisites", {})]
    if impl_only:
        w("- **Implementation-only prerequisites**, which a pitch might remove by changing the implementation: "
          + ", ".join(f"`{a_}` → `{b_}`" for a_, b_ in impl_only) + ".")
    shared = [(c["id"], s["alias"], s["alsoUsedBy"]) for c in clusters for s in c.get("sharedAliases", [])]
    if shared:
        w("- **Shared CInterop aliases**, assigned to the cluster that uses them most: "
          + "; ".join(f"`{al}` in `{cid}`, also {', '.join(o)}" for cid, al, o in shared[:10]) + ".")
    att = cl.get("attached", [])
    if att:
        w("- **Joined by implementation use only**: " + "; ".join(
            f"`{x['types'][0] if x['types'] else x['from']}` joined `{x['into']}`, whose bodies in `{x['file']}` use it"
            for x in att) + ".")
    via = collections.Counter(v for v in cl.get("aliasAttachment", {}).values())
    if via.get("implementation") or via.get("file") or via.get("unused"):
        w(f"- **CInterop aliases no signature names**: {via.get('implementation', 0)} joined the cluster whose "
          f"bodies use them, {via.get('file', 0)} the cluster owning the aliases beside them, and "
          f"{via.get('unused', 0)} nothing uses at all.")
    cyc = [u["id"] for u in all_units if u.get("cyclic")]
    if cyc:
        w("- **Prerequisite cycles**: " + ", ".join(f"`{x}`" for x in cyc) + ".")
    unnamed = [c["id"] for c in clusters if re.search(r"-\d+$", c["id"])]
    if unnamed:
        w("- **Clusters named alike**, told apart by a number: " + ", ".join(f"`{x}`" for x in unnamed) + ".")
    w("")

    # ------------------------------------------------------------ changes
    if a.previous and os.path.exists(a.previous):
        prev = load(a.previous)
        added, removed, rows, _ = compare(prev, cl)
        pm = prev.get("meta", {})
        w("## Changes since the previous run")
        w("")
        w(f"Against `{a.previous}`" + (f", generated {pm.get('date')} from `{pm.get('headRef')}` @ "
                                       f"`{pm.get('headCommit', '')[:10]}`" if pm else "") + ".")
        w("")
        if not added and not removed and not any(ch for _, ch in rows):
            w("No cluster changed membership, contingencies, or its place in the top of the ranking.")
        if added:
            w("- New clusters: " + ", ".join(f"`{x}`" for x in added) + ".")
        if removed:
            w("- Gone (merged into others, or removed): " + ", ".join(f"`{x}`" for x in removed) + ".")
        for k, ch in rows:
            if ch:
                w(f"- `{k}`: {'; '.join(ch)}.")
        small = [k for k, ch in rows if ch is None]
        if small:
            w(f"- {len(small)} other clusters moved fewer than 5 places in the ranking.")
        w("")

    w("## How this was generated")
    w("")
    w(open(os.path.join(HERE, "method.md")).read().strip())
    w("")
    open(os.path.join(a.out, "API-GRAPH.md"), "w").write("\n".join(L) + "\n")

    # ------------------------------------------------------------ DOT
    D = ["digraph clusters {", "  rankdir=LR; node [shape=box, fontname=Helvetica, fontsize=10];"]
    for c in clusters:
        color = "#d4f7d4" if not c["direct"] and not c["inherited"] else "#f7e0d4"
        D.append(f'  "{c["id"]}" [label="{c["name"]}\\n{c["metrics"]["declarations"]} decls", '
                 f'style=filled, fillcolor="{color}"];')
    for c in clusters:
        for k in c["prerequisites"]:
            D.append(f'  "{c["id"]}" -> "{k}";')
        for k in c.get("implPrerequisites", {}):
            D.append(f'  "{c["id"]}" -> "{k}" [style=dashed];')
    D.append("}")
    open(os.path.join(a.out, "clusters.dot"), "w").write("\n".join(D) + "\n")
    atom_cluster = {x: c["id"] for c in clusters for x in c["atoms"]}
    palette = ["#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69", "#fccde5",
               "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f"]
    color_of = {cid: palette[i % len(palette)] for i, cid in enumerate(sorted({c["id"] for c in clusters}))}
    A = ["digraph atoms {", "  rankdir=LR; node [shape=box, fontname=Helvetica, fontsize=9];"]
    for x, at in atoms.items():
        label = (nodes[at["nodes"][0]]["path"] if at["loose"] else f"{at['kind']} {at['subject']}") + \
            f"\\n{os.path.basename(at['file'] or '?')}:{at['line']} ({len(at['nodes'])})"
        A.append(f'  "{x}" [label="{label}", style=filled, fillcolor="{color_of.get(atom_cluster.get(x), "#ffffff")}"];')
    seen = set()
    node_atom = {nid: n.get("atom") for nid, n in nodes.items()}
    for e in edges:
        s_, t_ = node_atom.get(e["from"]), node_atom.get(e["to"])
        if s_ and t_ and s_ != t_ and (s_, t_) not in seen:
            seen.add((s_, t_))
            A.append(f'  "{s_}" -> "{t_}";')
    A.append("}")
    open(os.path.join(a.out, "atoms.dot"), "w").write("\n".join(A) + "\n")
    print(f"report: wrote {os.path.join(a.out, 'API-GRAPH.md')}, api-graph.json, clusters.dot, atoms.dot")


if __name__ == "__main__":
    main()
