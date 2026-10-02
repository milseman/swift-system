#!/usr/bin/env python3
"""Pick the newest API graph for a head commit.

The candidates are graph files (this worktree's .build/api-graph/graph.json.gz)
and the api-graph snapshot store's entries. One for the head commit wins;
otherwise the one whose commit is the nearest ancestor of the head, by
commit count; otherwise the newest by date. Prints "PATH<TAB>DESCRIPTION",
or exits 1 when there's no graph at all.

Usage: choose_graph.py --repo R --head COMMIT [--candidate FILE]... [--store DIR]
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import subprocess  # noqa: E402


def graph_meta(path):
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return json.load(f).get("meta", {})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--candidate", action="append", default=[])
    ap.add_argument("--store")
    a = ap.parse_args()

    cands = []   # (path, commit, date, description)
    for p in a.candidate:
        if os.path.exists(p):
            m = graph_meta(p)
            cands.append((p, m.get("headCommit"), m.get("snapshotDate") or m.get("date") or "",
                          f"this worktree's {os.path.relpath(os.path.dirname(p), a.repo)}"))
    if a.store and os.path.exists(os.path.join(a.store, "index.json")):
        with open(os.path.join(a.store, "index.json"), encoding="utf-8") as f:
            entries = json.load(f)
        for e in entries:
            p = os.path.join(a.store, e.get("file") or f"{e['headCommit']}.json.gz")
            if os.path.exists(p):
                cands.append((p, e["headCommit"], e.get("date") or "", "the snapshot store"))
    if not cands:
        sys.exit(1)

    def distance(c):
        if not c:
            return None
        if subprocess.run(["git", "-C", a.repo, "merge-base", "--is-ancestor", c, a.head],
                          capture_output=True).returncode != 0:
            return None
        out = subprocess.run(["git", "-C", a.repo, "rev-list", "--count", f"{c}..{a.head}"],
                             capture_output=True, text=True).stdout.strip()
        return int(out or 0)

    scored = [(distance(c), p, c, d, desc) for p, c, d, desc in cands]
    near = sorted((x for x in scored if x[0] is not None), key=lambda x: x[0])
    if near:
        dist, p, c, d, desc = near[0]
        what = "the head commit" if dist == 0 else f"{dist} commits before the head"
    else:
        dist, p, c, d, desc = sorted(scored, key=lambda x: x[3])[-1]
        what = "not an ancestor of the head; the newest by date"
    print(f"{p}\t{desc} at {(c or '?')[:10]} ({what})")


if __name__ == "__main__":
    main()
