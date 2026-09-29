#!/usr/bin/env python3
"""Write API-GRAPH.md, the index of a run's output: the graph (the
product), the pitch files' checks, and the clustering's suggestions.

Usage: index.py OUT_DIR
"""

import sys

sys.dont_write_bytecode = True

import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402


def main():
    out = sys.argv[1]
    g = json.load(gzip.open(os.path.join(out, "graph.json.gz"), "rt", encoding="utf-8"))
    m = g["meta"]
    heads = sum(1 for n in g["nodes"].values() if n["kind"] == "declaration" and n["origin"] == "head")
    pk = sum(1 for n in g["nodes"].values() if n["kind"] == "package")
    p = json.load(open(os.path.join(out, "pitches.json")))
    t = p["totals"]
    sg = json.load(open(os.path.join(out, "suggestions.json")))
    diff_line = ""
    if os.path.exists(os.path.join(out, "DIFF.md")):
        lines = open(os.path.join(out, "DIFF.md")).read().split("\n")
        diff_line = next((ln for ln in lines[2:] if ln.strip()), "")
    L = [f"# API graph: `{m['baseRef']}` → `{m['headRef']}`", "",
         f"- Base: `{m['baseRef']}` @ `{m['baseCommit']}` — {m.get('baseSubject', '')}",
         f"- Head: `{m['headRef']}` @ `{m['headCommit']}` — {m.get('headSubject', '')}", "",
         f"Generated {m['date']} on {m['host']} with {m['swift']}.", "",
         f"- [`GRAPH.md`](GRAPH.md): **the graph**, the product: the {heads} declarations `{m['headRef']}` adds, the "
         f"base and external types they build on, {len(g['links'])} typed links, and each declaration's reach "
         f"into {pk} packages. The snapshot is `graph.json.gz`, also filed in the snapshot store; "
         "`Utilities/api-graph/scripts/graphq.py` queries it.",
         f"- [`DIFF.md`](DIFF.md): what changed since the previous snapshot. {diff_line}",
         f"- [`PITCHES.md`](PITCHES.md): the hand-curated pitch files (`Prototype/Pitches`), checked together: "
         f"{len(p['pitches'])} pitches cover {t['covered']} of the {t['declarations']} declarations. Each has a "
         "bundle in `pitches/`.",
         f"- [`SUGGESTIONS.md`](SUGGESTIONS.md): the automatic clustering's proposals, {len(sg['candidates'])} "
         "suggested carve-outs with bundles in `suggestions/`, and draft pitch files for the leading ones no pitch "
         "covers yet (`suggestions/drafts/`).", ""]
    open(os.path.join(out, "API-GRAPH.md"), "w").write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
