#!/usr/bin/env python3
"""lint's pitches check: the hand-curated pitch files
(Prototype/Pitches/*.json, read from the working tree, as api-graph reads
them) against the api-graph output, through api-graph's own resolver and
checks (pitches.py's load_pitches and check, imported read-only).

  pitches/file          error    a pitch file api-graph can't use: not JSON, an `id` other than its name,
                                 a missing or unknown field, pattern or status
  pitches/missing       error    a rule names a declaration that isn't in the added set, names several, or
                                 matches nothing
  pitches/overlap       error    a declaration two pitches include
  pitches/requires      error    `requires` names a pitch that doesn't exist
  pitches/cycle         error    pitches that need each other
  pitches/prerequisite  warning  a pitch's declarations need a new type no pitch owns

The graph is --graph, else the api-graph output's graph.json.gz in this
worktree's .build/api-graph when it maps HEAD, else the snapshot store's
graph of HEAD (../api-graph-snapshots), else the newest graph either has,
with a note that it isn't HEAD's.
"""

import sys

sys.dont_write_bytecode = True

import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402

from lintcore import CheckError, Finding, git  # noqa: E402

RULES = [
    ("pitches/file", "error", "a pitch file api-graph can't use"),
    ("pitches/missing", "error", "a pitch rule naming a declaration that isn't in the added set"),
    ("pitches/overlap", "error", "a declaration in two pitches"),
    ("pitches/requires", "error", "a pitch requiring a pitch that doesn't exist"),
    ("pitches/cycle", "error", "pitches that need each other"),
    ("pitches/prerequisite", "warning", "a pitch whose prerequisites are in no pitch"),
]
MISSING = ("isn't a declaration", "matches nothing", "names ", "no declaration wraps", "no C function family",
           "is in the `", "a rule needs exactly one", "unknown rule field", "bad regular expression")


def load_graph(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8") as f:
        return json.load(f)


def find_graph(ctx):
    """(path, note or None)."""
    if ctx.args.graph:
        return ctx.args.graph, None
    candidates = []
    out = os.path.join(ctx.repo, ".build", "api-graph", "graph.json.gz")
    if os.path.isfile(out):
        candidates.append(out)
    store = os.path.join(os.path.dirname(ctx.repo), "api-graph-snapshots")
    if os.path.isfile(os.path.join(store, f"{ctx.head}.json.gz")):
        return os.path.join(store, f"{ctx.head}.json.gz"), None
    for p in candidates:
        h = load_graph(p).get("meta", {}).get("headCommit")
        if h == ctx.head or (h and same_sources(ctx, h)):
            return p, None
    if os.path.isdir(store):
        snaps = sorted((os.path.join(store, f) for f in os.listdir(store) if f.endswith(".json.gz")),
                       key=os.path.getmtime)
        candidates += snaps[-1:]
    if not candidates:
        raise CheckError("no api-graph output: run Utilities/api-graph/regenerate.sh (BASE_REF=main HEAD_REF=HEAD), "
                         "or give --graph")
    newest = max(candidates, key=os.path.getmtime)
    return newest, "isn't HEAD's"


def same_sources(ctx, commit):
    """Whether a commit's Sources and Package.swift are HEAD's: the same API."""
    try:
        a = git(ctx.repo, "rev-parse", f"{commit}:Sources", f"{commit}:Package.swift", ok=(0,)).split()
        b = git(ctx.repo, "rev-parse", f"{ctx.head}:Sources", f"{ctx.head}:Package.swift", ok=(0,)).split()
    except CheckError:
        return False
    return a == b


def line_of(text, needle, default=1):
    """The 1-based line of the first occurrence of needle in text."""
    i = text.find(needle)
    return text.count("\n", 0, i) + 1 if i >= 0 else default


def run(ctx):
    import pitches as P
    graph_path, problem = find_graph(ctx)
    doc = load_graph(graph_path)
    head = doc.get("meta", {}).get("headCommit", "")
    if problem and head and same_sources(ctx, head):
        problem = None
    if problem:
        ctx.note(f"pitches: the newest graph, {graph_path} (head {head[:10]}), {problem} ({ctx.head[:10]}); rerun "
                 "api-graph for HEAD")
    else:
        ctx.note(f"pitches: graph {graph_path} (head {head[:10]})")
    pdir = ctx.args.pitches or os.path.join(ctx.repo, "Prototype", "Pitches")
    cwd = os.getcwd()
    try:
        os.chdir(ctx.repo)
        pitches, file_problems = P.load_pitches(os.path.relpath(pdir, ctx.repo))
    finally:
        os.chdir(cwd)
    result = P.check(doc, pitches, file_problems)
    texts, findings = {}, []
    rel_dir = os.path.relpath(pdir, ctx.repo)

    def path_of(pid):
        return os.path.join(rel_dir, f"{pid}.json")

    def text_of(pid):
        if pid not in texts:
            try:
                with open(os.path.join(pdir, f"{pid}.json"), encoding="utf-8") as f:
                    texts[pid] = f.read()
            except OSError:
                texts[pid] = ""
        return texts[pid]
    for fp in file_problems:
        name, _, msg = fp.partition(": ")
        pid = name[:-5] if name.endswith(".json") else name
        findings.append(Finding(path_of(pid), 1, "pitches/file", "error", msg or fp))
    for pid, r in sorted(result["pitches"].items()):
        text = text_of(pid)
        for rule in r["rules"]:
            needle = json.dumps(rule["rule"]).split(",")[0].strip("{")
            line = line_of(text, needle.split(":")[0]) if needle else 1
            for prob in rule["problems"] + ([] if rule["matches"] or rule["problems"] else ["matches nothing"]):
                if any(m in prob for m in MISSING):
                    named = re.search(r"`([^`]+)`", prob)
                    at = line_of(text, json.dumps(named.group(1)), line) if named else line
                    findings.append(Finding(path_of(pid), at, "pitches/missing", "error",
                                            f"{rule['part']} {json.dumps(rule['rule'])}: {prob}"))
        for q in r.get("requires", []):
            if q not in result["pitches"]:
                findings.append(Finding(path_of(pid), line_of(text, f'"{q}"'), "pitches/requires", "error",
                                        f"requires `{q}`, which isn't a pitch"))
        for t, uses in sorted(r.get("unownedTypes", {}).items()):
            via = ", ".join(f"`{u['declaration']}` ({u['link']})" for u in uses[:3])
            findings.append(Finding(path_of(pid), 1, "pitches/prerequisite", "warning",
                                    f"needs `{t}`, a new type no pitch owns: {via}"))
    for decl, owners in sorted(result["overlaps"].items()):
        for pid in owners:
            others = [o for o in owners if o != pid]
            findings.append(Finding(path_of(pid), line_of(text_of(pid), decl.split("(")[0].split(".")[-1]),
                                    "pitches/overlap", "error",
                                    f"`{decl}` is in {', '.join(f'`{o}`' for o in others)} too"))
    for cycle in result["cycles"]:
        for pid in cycle:
            findings.append(Finding(path_of(pid), 1, "pitches/cycle", "error",
                                    f"pitches that need each other: {', '.join(cycle)}"))
    return findings
