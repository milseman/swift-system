#!/usr/bin/env python3
"""Build the burn-down of the public API the head ref adds over the base ref.

The unit is a public declaration, exactly as api-delta lists it as added:
every symbol-graph entry with status `added`, and every declaration in
`hiddenFromGraphs.added` (compiled only off Darwin, `unavailable` fix-it
stubs, underscored). Overloads and per-platform variants count separately,
as api-delta lists them. Each declaration is in one of five states:

  1 not in a pitch
  2 in a pitch draft: a pitch file in Prototype/Pitches matches it
  3 pitched, and 4 PR open: its pitch's entry in Prototype/Burndown/states.json
  5 merged: in an earlier day's set, and now in the base ref's public API

Deprecated, underscored and SPI declarations and fix-it stubs are kept,
flagged, outside the main count. A declaration in two pitches counts under
the first pitch file by name, flagged.

Usage:
  burndown.py --repo R --delta DIR --graph GRAPH --out-json F [options]
  burndown.py --check --out-json F --delta DIR [--page HTML]
README.md in Utilities/api-burndown describes the inputs and outputs.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import datetime  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "api-graph", "scripts")))
import headers as hdr  # noqa: E402
import history as hist  # noqa: E402
import pitches as pitchlib  # noqa: E402  (api-graph's pitch resolver)

SCHEMA = "api-burndown/1"
STATES = [
    {"id": 1, "key": "none", "label": "Not in a pitch"},
    {"id": 2, "key": "draft", "label": "In a pitch draft"},
    {"id": 3, "key": "pitched", "label": "Pitched"},
    {"id": 4, "key": "pr", "label": "PR open"},
    {"id": 5, "key": "merged", "label": "Merged"},
]
HAND_STATES = {"pitched": 3, "pr": 4}
FLAGS = {
    # Outside the main count.
    "deprecated": "Deprecated",
    "underscored": "Underscored",
    "spi": "SPI",
    "stub": "Fix-it stub (unavailable, renamed)",
    # Informational.
    "pitches": "In more than one pitch; counted under the first by file name",
    "overload": "Shares its path with another added declaration (an overload or a per-platform variant)",
    "unexplained": "Public, compiled on Darwin, and not in the macOS symbol graphs (api-delta: unexplained)",
    "nograph": "Not in the graph used, so no C name, pitch or adopter data",
    "upstream": "Already in the upstream ref's public API (the base ref is behind it)",
}
EXCLUDED = hist.EXCLUDED
KIND_NAMES = {
    "swift.struct": "Structure", "swift.enum": "Enumeration", "swift.class": "Class", "swift.protocol": "Protocol",
    "swift.actor": "Actor", "swift.typealias": "Type Alias", "swift.method": "Instance Method",
    "swift.type.method": "Type Method", "swift.func": "Function", "swift.func.op": "Operator",
    "swift.init": "Initializer", "swift.property": "Instance Property", "swift.type.property": "Type Property",
    "swift.subscript": "Instance Subscript", "swift.type.subscript": "Type Subscript", "swift.enum.case": "Case",
    "swift.var": "Global Variable", "swift.macro": "Macro", "swift.associatedtype": "Associated Type",
}
ROLE_ORDER = {"subject": 0, "alternative": 1, "argument": 2}
CODE_KIND_ORDER = {"function": 0, "field": 1, "constant": 2, "macro": 2, "variable": 3}
NOT_DARWIN = "(not on Darwin)"
NO_CNAME = "(no C name)"
SWIFT_ONLY = "Swift-only"
NOT_IN_SDK = "(not in the macOS SDK)"
NO_MODULE = "(in no SDK module)"


def load_json(path):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def git(repo, *args, check=True):
    return hist.git(repo, *args, check=check)


def is_ancestor(repo, a, b):
    return subprocess.run(["git", "-C", repo, "merge-base", "--is-ancestor", a, b],
                          capture_output=True).returncode == 0


# ------------------------------------------------------------------ areas

class Areas:
    """A declaration's System area: the directory under its module's sources,
    or, for a file at the top, its file group: the shortest top-level file
    stem or directory name its stem starts with (FileControlCommand.swift
    is in FileControl, ErrnoWindows.swift in Errno, Util+StringArray.swift
    in Util)."""

    def __init__(self, repo, commit):
        self.names = {}
        for d, module in hist.MODULE_DIRS.items():
            out = git(repo, "ls-tree", "--name-only", commit, d + "/", check=False).split()
            stems = set()
            for p in out:
                base = p.split("/")[-1]
                stems.add(base[:-6].split("+")[0] if base.endswith(".swift") else base)
            self.names[d] = stems

    def of(self, file):
        if not file:
            return "(no source file)"
        parts = file.split("/")
        d = "/".join(parts[:2])
        label = parts[1]
        if len(parts) > 3:
            return f"{label}/{parts[2]}"
        stem = parts[-1][:-6].split("+")[0] if parts[-1].endswith(".swift") else parts[-1]
        cands = [s for s in self.names.get(d, ()) if s and stem.startswith(s)]
        return f"{label}/{min(cands, key=len) if cands else stem}"


# ------------------------------------------------------------------ units

def delta_units(delta, head_scan):
    """api-delta's added declarations, each with the ID its scanned
    declaration has (history.reduce_scan), so that the same declaration has
    the same ID on every day."""
    at = {(d["file"], d["line"]): d for d in head_scan["declarations"]}
    units = []
    seen_graph_only = collections.Counter()
    for e in delta["entries"]:
        if e["status"] != "added":
            continue
        d = at.get((e["file"], e["line"])) if e.get("file") else None
        flags = []
        if e.get("deprecated"):
            flags.append("deprecated")
        title = e.get("title") or ""
        if re.search(r"(\(|:)_[A-Za-z]", title) or title.startswith("_"):
            flags.append("underscored")
        if d:
            uid = d["id"]
            for f in d["flags"]:
                if f not in flags and not (f == "underscored" and "stub" in d["flags"]):
                    flags.append(f)
        else:
            uid = hist.graph_only_id(e["module"], e["path"], e["kind"], seen_graph_only)
        units.append({
            "id": uid, "origin": "graph", "usr": e["usr"], "module": e["module"], "path": e["path"],
            "title": title, "kind": e["kind"], "kindName": e.get("kindName") or KIND_NAMES.get(e["kind"], e["kind"]),
            "decl": e.get("decl") or "", "file": e.get("file"), "line": e.get("line"),
            "platforms": e.get("platforms") or (d["platforms"] if d else None),
            "availability": e.get("availability") or "", "docSummary": e.get("docSummary") or "",
            "hiddenClass": None, "flags": flags, "renamedTo": None,
        })
    for x in delta["hiddenFromGraphs"]["added"]:
        path = ".".join(x["scopes"] + [x["name"]])
        d = at.get((x["file"], x["line"]))
        if d:
            uid, flags, kind = d["id"], list(d["flags"]), d["kind"]
        else:
            # Not expected: every hidden declaration comes from the scan.
            uid, flags, kind = f"{x['module']}|{path}|scan:{x['file']}:{x['line']}", [], "swift." + x["kw"]
        if x["hiddenClass"] == "unexplained":
            flags.append("unexplained")
        avail = x["availability"] + x["scopeAvailability"]
        units.append({
            "id": uid, "origin": "scan", "usr": None, "module": x["module"], "path": path, "title": x["name"],
            "kind": kind, "kindName": KIND_NAMES.get(kind, kind),
            "decl": re.sub(r"\s+", " ", x["signature"]).strip(), "file": x["file"], "line": x["line"],
            "platforms": x["platforms"],
            "availability": ", ".join(dict.fromkeys(v.replace("@available(", "").rstrip(")") for v in avail)),
            "docSummary": "", "hiddenClass": x["hiddenClass"], "flags": flags,
            "renamedTo": (d or {}).get("renamedTo"),
        })
    # Platforms for graph entries the scan doesn't see (enum cases): their
    # type's.
    by_path = {}
    for u in units:
        by_path.setdefault((u["module"], u["path"]), u)
    for u in units:
        if not u["platforms"]:
            parent = u["path"].rsplit(".", 1)[0] if "." in u["path"] else None
            p = by_path.get((u["module"], parent)) if parent else None
            u["platforms"] = (p or {}).get("platforms") or ["Darwin"]
    counts = collections.Counter((u["module"], u["path"]) for u in units)
    for u in units:
        if counts[(u["module"], u["path"])] > 1:
            u["flags"].append("overload")
    return units


# ------------------------------------------------------------------ the graph

def graph_head_nodes(doc):
    nodes = doc["nodes"]
    return {nid for nid, n in nodes.items() if n["kind"] == "declaration" and n.get("origin") == "head"}


def unit_nodes(units, doc, by_location=False):
    """{unit id: node id}. A graph entry is its USR's node (by_location: the
    node at its file and line, for a snapshot of another commit); a hidden
    declaration is the graph node with its path, as build_graph.py merges it,
    or its own `scan:` node."""
    nodes = doc["nodes"]
    head = graph_head_nodes(doc)
    by_path = collections.defaultdict(list)
    by_loc = {}
    for nid in head:
        n = nodes[nid]
        by_path[(n["module"], n["path"])].append(nid)
        if n.get("source") == "graph" and n.get("file"):
            by_loc[(n["file"], n.get("line"))] = nid
    out = {}
    for u in units:
        nid = None
        hidden = u.get("origin") == "scan"
        if not hidden:
            if by_location:
                nid = by_loc.get((u.get("file"), u.get("line")))
            elif u.get("usr") in head:
                nid = u["usr"]
            if nid is None:
                cands = [c for c in by_path.get((u["module"], u["path"]), []) if nodes[c].get("source") == "graph"]
                nid = cands[0] if len(cands) == 1 else None
        else:
            sid = f"scan:{u['module']}:{u['path']}"
            if sid in head:
                nid = sid
            else:
                cands = [c for c in by_path.get((u["module"], u["path"]), []) if nodes[c].get("source") == "graph"]
                if len(cands) > 1:
                    plats = set(u.get("platforms") or [])
                    cands = [c for c in cands if plats <= set(nodes[c].get("platforms") or [])] or cands
                nid = cands[0] if cands else None
        if nid:
            out[u["id"]] = nid
    return out


def resolve_pitches(doc, pitch_files):
    """{pitch id: set of node IDs}, and the problems api-graph's resolver reports."""
    R = pitchlib.Resolver(doc)
    out, problems = {}, []
    for p in pitch_files:
        got, _, probs = R.pitch(p)
        out[p["id"]] = got
        problems += [f"{p['id']}: {x}" for x in probs]
    return out, problems


def pitches_of(units_by_node, pitch_nodes, order):
    """{unit id: [pitch ids, in file-name order]}."""
    out = collections.defaultdict(list)
    for pid in order:
        for nid in pitch_nodes.get(pid, ()):
            for uid in units_by_node.get(nid, ()):
                if pid not in out[uid]:
                    out[uid].append(pid)
    return out


def invert(unit_to_node):
    out = collections.defaultdict(list)
    for uid, nid in unit_to_node.items():
        out[nid].append(uid)
    return out


def load_pitch_dir(directory):
    if not os.path.isdir(directory):
        return [], [f"no pitch directory {directory}"]
    files, problems = pitchlib.load_pitches(directory)
    files.sort(key=lambda p: os.path.basename(p["_file"]))
    return files, problems


def pitch_files_at(repo, commit, rel_dir, work):
    """The pitch files at a commit, read with git, or None if it has none."""
    listing = git(repo, "ls-tree", "--name-only", commit, rel_dir.rstrip("/") + "/", check=False).split()
    names = [p for p in listing if p.endswith(".json")]
    if not names:
        return None
    d = os.path.join(work, f"pitches-{commit[:12]}")
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    for p in names:
        with open(os.path.join(d, os.path.basename(p)), "w", encoding="utf-8") as f:
            f.write(git(repo, "show", f"{commit}:{p}"))
    files, _ = load_pitch_dir(d)
    shutil.rmtree(d)
    return files


# ------------------------------------------------------------------ states.json

def load_states(path):
    """{pitch id: [{state, date, link}], oldest first}, and problems."""
    if not path or not os.path.exists(path):
        return {}, []
    doc = load_json(path)
    out, problems = {}, []
    if not isinstance(doc, dict):
        return {}, [f"{path}: expected an object of pitch IDs"]
    for pid, v in doc.items():
        entries = v if isinstance(v, list) else [v]
        good = []
        for e in entries:
            if not isinstance(e, dict):
                problems.append(f"{pid}: expected {{state, date, link}}, got {json.dumps(e)}")
                continue
            st, date = e.get("state"), e.get("date")
            if st not in HAND_STATES:
                problems.append(f"{pid}: state {st!r} isn't one of {', '.join(HAND_STATES)}; merged comes from main")
                continue
            try:
                datetime.date.fromisoformat(date or "")
            except ValueError:
                problems.append(f"{pid}: date {date!r} isn't YYYY-MM-DD")
                continue
            good.append({"state": st, "date": date, "link": e.get("link")})
        good.sort(key=lambda e: e["date"])
        if good:
            out[pid] = good
    return out, problems


def hand_state(states, pid, day):
    """The states.json state of a pitch on a day: (state number, entry) or (None, None)."""
    best = None
    for e in states.get(pid, ()):
        if e["date"] <= day:
            best = e
    return (HAND_STATES[best["state"]], best) if best else (None, None)


def state_of(pitch_list, states, day):
    if not pitch_list:
        return 1
    st, _ = hand_state(states, pitch_list[0], day)
    return st or 2


# ------------------------------------------------------------------ C names

def c_names(doc, nid):
    """[{name, role, cKinds, restricted, code, pos}] for a node's wraps links,
    the stated ones (a doc sentence's or a typealias's) first, then by role
    and the sentence's order, or for code-only ones, by kind. `code` marks a
    name only the declaration's code reaches; a snapshot before api-graph's
    schema 2 has only stated links."""
    if not nid:
        return []
    nodes = doc["nodes"]
    out = []
    for ln in doc.get("_out", {}).get(nid, ()):
        if ln["kind"] != "wraps":
            continue
        c = nodes.get(ln["to"]) or {}
        name = c.get("name") or ln["to"].split(":", 1)[-1]
        pos = (ln.get("sentence") or "").find(f"`{name.rsplit('.', 1)[-1]}`")
        code = (ln.get("sources") or [ln.get("source") or "doc"]) == ["code"]
        out.append({"name": name, "role": ln.get("role") or "subject",
                    "cKinds": [ln["cKind"]] if ln.get("cKind") else c.get("cKinds") or [],
                    "restricted": bool(ln.get("restricted")), "code": code, "pos": pos if pos >= 0 else 999})
    # Among names only code reaches, functions first: they're what a wrapper
    # calls; the constants are what it passes them.
    out.sort(key=lambda c: (c["code"], ROLE_ORDER.get(c["role"], 9),
                            CODE_KIND_ORDER.get(c["cKinds"][0] if c["code"] and c["cKinds"] else "", 0),
                            c["pos"], c["name"]))
    return out


def locate(headers, c):
    """A C name's header: a field's is its struct's (`stat.st_size` is in
    sys/stat.h), if that header names the field too; Darwin's `struct stat`
    has `st_atimespec`, not `st_atim`. One the code reaches but the graph
    has no struct for is looked up as a field."""
    if "field" in c["cKinds"] and "." in c["name"]:
        struct, field = c["name"].split(".", 1)
        r = headers.locate(struct, ["type"])
        if r["header"] and not headers.has_identifier(r["header"], field.split(".", 1)[0]):
            return {"header": None, "module": None, "sdkModule": None,
                    "how": f"not in the macOS SDK: {r['header']} has no {field}"}
        return r
    return headers.locate(c["name"], c["cKinds"])


def primary_header(cnames, platforms, headers, reaches_c=None):
    """The C name a declaration is grouped by, with its header and module:
    the first of its C names the macOS SDK declares (`stat.st_atimespec`,
    not another platform's `stat.st_atim`, which comes first). A declaration
    with no C name is Swift-only when its code reaches no C at all
    (`reaches_c` False, from the graph), and has no C name otherwise."""
    if "Darwin" not in (platforms or []):
        return None, {"header": NOT_DARWIN, "module": NOT_DARWIN, "sdkModule": NOT_DARWIN, "how": "not on Darwin"}
    # `int`, as a type's doc comment can name it, isn't any header's.
    cnames = [c for c in cnames if c["name"] not in hdr.BUILTIN_TYPES]
    if not cnames:
        if reaches_c is False:
            return None, {"header": SWIFT_ONLY, "module": SWIFT_ONLY, "sdkModule": SWIFT_ONLY,
                          "how": "Swift-only: its code reaches no C"}
        return None, {"header": NO_CNAME, "module": NO_CNAME, "sdkModule": NO_CNAME, "how": "no C name"}
    for c in cnames:
        r = locate(headers, c)
        if r["header"]:
            return c["name"], r
    return cnames[0]["name"], {"header": NOT_IN_SDK, "module": NOT_IN_SDK, "sdkModule": NOT_IN_SDK,
                               "how": "not in the macOS SDK"}


# ------------------------------------------------------------------ the graph choice

def describe_graph(path):
    doc = load_json(path)
    m = doc.get("meta", {})
    return doc, {"path": os.path.abspath(path), "headCommit": m.get("headCommit"), "baseCommit": m.get("baseCommit"),
                 "date": m.get("snapshotDate") or m.get("date"), "headRef": m.get("headRef")}


# ------------------------------------------------------------------ main

def build(a):
    repo = a.repo
    delta = load_json(os.path.join(a.delta, "api-delta.json"))
    dmeta = delta["meta"]
    base_commit, head_commit = dmeta["baseCommit"], dmeta["headCommit"]
    today = a.today or datetime.date.today().isoformat()
    os.makedirs(a.cache, exist_ok=True)
    os.makedirs(a.work, exist_ok=True)
    log = lambda *x: print("burndown:", *x, flush=True)  # noqa: E731

    head_scan, _ = hist.scan_commit(repo, head_commit, a.cache, a.work)
    base_scan, _ = hist.scan_commit(repo, base_commit, a.cache, a.work)
    units = delta_units(delta, head_scan)
    log(f"{len(units)} added declarations from api-delta ({base_commit[:10]}..{head_commit[:10]})")

    # The graph.
    doc, gmeta = describe_graph(a.graph)
    out_links = collections.defaultdict(list)
    for ln in doc["links"]:
        out_links[ln["from"]].append(ln)
    doc["_out"] = out_links
    gmeta["matchesHead"] = gmeta["headCommit"] == head_commit
    gmeta["source"] = a.graph_source
    u2n = unit_nodes(units, doc)
    n2u = invert(u2n)
    for u in units:
        if u["id"] not in u2n:
            u["flags"].append("nograph")
    gmeta["unitsWithoutNode"] = sum(1 for u in units if u["id"] not in u2n)
    log(f"graph {gmeta['headCommit'][:10]} ({a.graph_source}): {len(units) - gmeta['unitsWithoutNode']} of "
        f"{len(units)} declarations have a node")

    # Pitches, from the working tree, as api-graph reads them.
    pitch_files, pitch_problems = load_pitch_dir(a.pitches)
    order = [p["id"] for p in pitch_files]
    pitch_nodes, resolve_problems = resolve_pitches(doc, pitch_files)
    upitches = pitches_of(n2u, pitch_nodes, order)
    states, state_problems = load_states(a.states)
    future = [f"{pid}: {e['date']} is after today ({today})" for pid, es in states.items() for e in es
              if e["date"] > today]
    unknown_pitches = sorted(set(states) - set(order))

    # C names, headers, adopters.
    vocab = a.vocab or hdr.newest_vocab(a.coverage_results)
    sdk, sdk_version = hdr.sdk_path()
    headers = hdr.Headers(vocab, sdk, a.sdk_cache or a.cache)
    packages = {nid: n for nid, n in doc["nodes"].items() if n["kind"] == "package"}
    areas = Areas(repo, head_commit)
    for u in units:
        nid = u2n.get(u["id"])
        n = doc["nodes"].get(nid) or {}
        u["node"] = nid
        if not u["docSummary"]:
            u["docSummary"] = n.get("docSummary") or ""
        cn = c_names(doc, nid)
        u["cNames"] = [{"name": c["name"], "role": c["role"], "restricted": c["restricted"], "code": c["code"]}
                       for c in cn]
        u["cName"], loc = primary_header(cn, u["platforms"], headers, n.get("reachesC") if nid else None)
        u["cNameFromCode"] = bool(u["cName"]) and next(c["code"] for c in cn if c["name"] == u["cName"])
        u["header"], u["sdkSubmodule"], u["sdkModule"], u["headerHow"] = (
            loc["header"], loc["module"] or NO_MODULE, loc["sdkModule"] or NO_MODULE, loc["how"])
        used = []
        for ln in out_links.get(nid, ()):
            if ln["kind"] != "usedBy":
                continue
            pk = packages.get(ln["to"]) or {}
            sites = sorted(([s.get("file"), s.get("line"), s.get("column"), s.get("resolution")]
                            for s in ln.get("sites") or []), key=lambda s: (s[0] or "", s[1] or 0, s[2] or 0))
            used.append({"package": pk.get("name") or ln["to"].split(":", 1)[-1], "sites": sites})
        used.sort(key=lambda x: x["package"].lower())
        u["usedBy"] = used
        u["couldUse"] = len((n.get("reach") or {}).get("couldUse") or [])
        u["area"] = areas.of(u["file"])
        u["pitches"] = upitches.get(u["id"], [])
        u["pitch"] = u["pitches"][0] if u["pitches"] else None
        if len(u["pitches"]) > 1:
            u["flags"].append("pitches")
        u["state"] = state_of(u["pitches"], states, today)
        u["excluded"] = any(f in EXCLUDED for f in u["flags"])

    # Upstream: is the base behind the ref it's meant to stand for?
    upstream = None
    up = git(repo, "rev-parse", "--verify", "--quiet", a.upstream + "^{commit}", check=False).strip() \
        if a.upstream else ""
    if up and up != base_commit and not is_ancestor(repo, up, base_commit):
        up_scan, _ = hist.scan_commit(repo, up, a.cache, a.work)
        have = collections.Counter((d["module"], d["path"], d["sig"]) for d in up_scan["declarations"])
        base_have = collections.Counter((d["module"], d["path"], d["sig"]) for d in base_scan["declarations"])
        scanned = {d["id"]: d for d in head_scan["declarations"]}
        hits = 0
        for u in units:
            d = scanned.get(u["id"])
            k = (d["module"], d["path"], d["sig"]) if d else None
            if d and base_have[k] < d["occ"] <= have[k]:
                u["flags"].append("upstream")
                hits += 1
        behind = int(git(repo, "rev-list", "--count", f"{base_commit}..{up}").strip() or 0)
        fetched = git(repo, "log", "-g", "-1", "--format=%gd", "--date=format:%Y-%m-%d", a.upstream,
                      check=False).strip()
        m = re.search(r"\{(\d{4}-\d\d-\d\d)\}", fetched)
        upstream = {"ref": a.upstream, "commit": up, "behind": behind, "declarations": hits,
                    "subject": git(repo, "log", "-1", "--format=%s", up).strip(),
                    "updated": m.group(1) if m else None,
                    "containsHead": is_ancestor(repo, up, head_commit)}
        log(f"{a.base_ref} is {behind} commits behind {a.upstream}; {hits} added declarations are in its API")

    # History.
    log("history")
    history, global_units = build_history(a, repo, head_commit, base_commit, today, units, u2n, doc,
                                          pitch_nodes, order, states, areas)

    merged_now = [g for g in global_units if g.get("mergedNow")]
    totals = collections.Counter()
    flagged = collections.Counter()
    for u in units:
        (flagged if u["excluded"] else totals)[u["state"]] += 1
    for g in merged_now:
        (flagged if g["excluded"] else totals)[5] += 1
    flag_counts = collections.Counter(f for u in units for f in u["flags"])

    meta = {
        "generated": today,
        "baseRef": a.base_ref, "baseCommit": base_commit, "baseSubject": dmeta.get("baseSubject"),
        "headRef": a.head_ref, "headCommit": head_commit, "headSubject": dmeta.get("headSubject"),
        "apiDelta": {"path": os.path.abspath(a.delta), "date": dmeta.get("date"), "swift": dmeta.get("swift"),
                     "sdk": dmeta.get("sdk"), "added": len(delta["entries"]),
                     "hidden": len(delta["hiddenFromGraphs"]["added"]),
                     "byModule": dict(collections.Counter(u["module"] for u in units))},
        "graph": gmeta,
        "pitches": {"dir": os.path.abspath(a.pitches), "files": order,
                    "dirty": bool(git(repo, "status", "--porcelain", "--", a.pitches, check=False).strip()),
                    "problems": pitch_problems + resolve_problems},
        "states": {"path": os.path.abspath(a.states), "entries": {k: v for k, v in sorted(states.items())},
                   "problems": state_problems + future, "unknownPitches": unknown_pitches},
        "headers": {"vocab": vocab, "vocabNote": headers.vocab_note, "sdk": sdk, "sdkVersion": sdk_version},
        "upstream": upstream,
        "tool": {"commit": git(repo, "rev-parse", "HEAD").strip(),
                 "tree": git(repo, "rev-parse", "HEAD:Utilities/api-burndown", check=False).strip() or None,
                 "dirty": bool(git(repo, "status", "--porcelain", "--", "Utilities/api-burndown",
                                   check=False).strip())},
    }
    for u in units:
        u.pop("node", None)
    result = {
        "schema": SCHEMA,
        "meta": meta,
        "states": STATES,
        "flags": FLAGS,
        "excludedFlags": list(EXCLUDED),
        "totals": {"main": {str(k): totals[k] for k in range(1, 6)},
                   "outside": {str(k): flagged[k] for k in range(1, 6)},
                   "mainCount": sum(totals.values()), "outsideCount": sum(flagged.values()),
                   "declarations": len(units), "merged": len(merged_now),
                   "flags": dict(sorted(flag_counts.items()))},
        "declarations": units,
        "merged": merged_now,
        "history": history,
        "historyUnits": global_units,
    }
    return result


def build_history(a, repo, head_commit, base_commit, today, units, u2n, doc, pitch_nodes, order, states, areas):
    """The days, each with its counts by state, and every declaration seen on
    any day with its state per day."""
    pts = hist.points(repo, head_commit, base_commit, today)
    store = hist.store_index(a.store)
    cur = {u["id"]: u for u in units}
    head_pitches = pitches_of(invert(u2n), pitch_nodes, order)
    sets, mains, pitch_maps, notes, methods, skipped = [], [], [], [], [], []
    scan_cache = {}
    base_cache = {}

    def scan(c):
        if c not in scan_cache:
            scan_cache[c] = hist.scan_commit(repo, c, a.cache, a.work)[0]
        return scan_cache[c]

    def base_of(c):
        if c not in base_cache:
            base_cache[c] = scan(c)
        return base_cache[c]

    computed = {}
    for p in pts:
        c = p["commit"]
        key = (c, p["base"])
        if key in computed:
            sets.append(computed[key]["set"])
            mains.append(computed[key]["main"])
            pitch_maps.append(computed[key]["pitches"])
            methods.append(computed[key]["method"])
            notes.append(computed[key]["note"])
            skipped.append(computed[key]["skip"])
            continue
        entry = {"set": None, "main": None, "pitches": {}, "method": None, "note": None, "skip": None}
        try:
            b = base_of(p["base"])
            entry["main"] = hist.path_counts(b)
            if c == head_commit and p["base"] == base_commit:
                entry["set"] = {uid: lite(u) for uid, u in cur.items()}
                entry["method"] = "api-delta"
                entry["pitches"] = {uid: v for uid, v in head_pitches.items()}
                entry["note"] = "pitch files from the working tree"
            else:
                s = scan(c)
                if c in store:
                    snap = hist.load_snapshot(store[c])
                    us = hist.units_with_snapshot(s, b, snap)
                    entry["method"] = "snapshot"
                else:
                    snap = None
                    us = hist.new_units(s, b)
                    entry["method"] = "scan"
                entry["set"] = {u["id"]: lite(u) for u in us}
                files = pitch_files_at(repo, c, a.pitches_rel, a.work)
                if files:
                    if snap is not None:
                        snap_units = [dict(u, origin="graph" if (u.get("file"), u.get("line")) in snap_locs(snap)
                                           else "scan") for u in us]
                        um = unit_nodes(snap_units, snap, by_location=True)
                        pn, _ = resolve_pitches(snap, files)
                        entry["pitches"] = pitches_of(invert(um), pn, [f["id"] for f in files])
                        entry["note"] = "pitch files at this commit, resolved against its snapshot"
                    else:
                        pn, _ = resolve_pitches(doc, files)
                        hp = pitches_of(invert(u2n), pn, [f["id"] for f in files])
                        entry["pitches"] = {uid: v for uid, v in hp.items() if uid in entry["set"]}
                        entry["note"] = ("pitch files at this commit, resolved against the newest graph: "
                                         "declarations it doesn't have count as in no pitch")
        except (RuntimeError, ValueError, OSError, KeyError) as e:
            entry = {"set": None, "main": None, "pitches": {}, "method": None, "note": None, "skip": str(e)}
        computed[key] = entry
        sets.append(entry["set"])
        mains.append(entry["main"])
        pitch_maps.append(entry["pitches"])
        methods.append(entry["method"])
        notes.append(entry["note"])
        skipped.append(entry["skip"])

    # Merged, over the days that could be computed.
    ok = [i for i, s in enumerate(sets) if s is not None]
    merged_ok = hist.merged_by_point([sets[i] for i in ok], [mains[i] for i in ok])
    merged = [None] * len(sets)
    for i, m in zip(ok, merged_ok):
        merged[i] = m

    # Every declaration seen, current ones first, in the order of `units`.
    gindex = {}
    gunits = []
    for u in units:
        gindex[u["id"]] = len(gunits)
        gunits.append({"id": u["id"], "current": True})
    for i in ok:
        for uid, u in list(sets[i].items()) + list(merged[i].items()):
            if uid not in gindex:
                gindex[uid] = len(gunits)
                gunits.append(dict(u, current=False, area=areas.of(u.get("file")),
                                   kindName=KIND_NAMES.get(u.get("kind"), u.get("kind"))))
            elif not gunits[gindex[uid]]["current"]:
                gunits[gindex[uid]].update(dict(u, current=False, area=areas.of(u.get("file")),
                                                kindName=KIND_NAMES.get(u.get("kind"), u.get("kind"))))
    last = ok[-1] if ok else None
    for g in gunits:
        if not g["current"]:
            g["excluded"] = any(f in EXCLUDED for f in g.get("flags") or [])
            g["mergedNow"] = last is not None and g["id"] in merged[last]

    days = []
    for i, p in enumerate(pts):
        row = {"day": p["day"], "commit": p["commit"], "commitDay": p["commitDay"], "newCommit": p["newCommit"],
               "subject": p["subject"], "base": p["base"], "method": methods[i], "note": notes[i]}
        if sets[i] is None:
            row["skipped"] = skipped[i]
            row["codes"] = None
            days.append(row)
            continue
        codes = ["."] * len(gunits)
        counts, outside = collections.Counter(), collections.Counter()
        for uid, u in sets[i].items():
            pl = pitch_maps[i].get(uid, [])
            st = state_of(pl, states, p["day"])
            ex = any(f in EXCLUDED for f in u.get("flags") or [])
            codes[gindex[uid]] = "abcde"[st - 1] if ex else str(st)
            (outside if ex else counts)[st] += 1
        for uid, u in merged[i].items():
            ex = any(f in EXCLUDED for f in u.get("flags") or [])
            codes[gindex[uid]] = "e" if ex else "5"
            (outside if ex else counts)[5] += 1
        row["counts"] = {str(k): counts[k] for k in range(1, 6)}
        row["outside"] = {str(k): outside[k] for k in range(1, 6)}
        row["scope"] = sum(counts.values())
        row["codes"] = "".join(codes)
        days.append(row)
    for g in gunits:
        if g["current"]:
            for k in list(g):
                if k not in ("id", "current"):
                    del g[k]
    return {"days": days, "snapshotStore": a.store, "storeCommits": sorted(store)}, gunits


def snap_locs(snap):
    if "_locs" not in snap:
        snap["_locs"] = {(n.get("file"), n.get("line")) for n in snap["nodes"].values()
                         if n["kind"] == "declaration" and n.get("origin") == "head" and n.get("source") == "graph"}
    return snap["_locs"]


def lite(u):
    return {k: u.get(k) for k in ("id", "module", "path", "title", "kind", "file", "line", "platforms", "flags",
                                  "decl")}


# ------------------------------------------------------------------ check

def check(a):
    """Reconcile burndown.json with api-delta.json (and the page, if given)."""
    problems = []
    data = load_json(a.out_json)
    delta = load_json(os.path.join(a.delta, "api-delta.json"))
    dm, bm = delta["meta"], data["meta"]
    if (dm["baseCommit"], dm["headCommit"]) != (bm["baseCommit"], bm["headCommit"]):
        problems.append(f"commits differ: api-delta {dm['baseCommit'][:10]}..{dm['headCommit'][:10]}, "
                        f"burn-down {bm['baseCommit'][:10]}..{bm['headCommit'][:10]}")
    added = [e for e in delta["entries"] if e["status"] == "added"]
    hidden = delta["hiddenFromGraphs"]["added"]
    decls = data["declarations"]
    want = len(added) + len(hidden)
    if len(decls) != want:
        problems.append(f"{len(decls)} declarations; api-delta adds {len(added)} + {len(hidden)} hidden = {want}")
    for m in sorted({e["module"] for e in added} | {x["module"] for x in hidden} | {u["module"] for u in decls}):
        a_ = sum(1 for e in added if e["module"] == m) + sum(1 for x in hidden if x["module"] == m)
        b_ = sum(1 for u in decls if u["module"] == m)
        if a_ != b_:
            problems.append(f"{m}: {b_} declarations; api-delta adds {a_}")
    # Each api-delta entry is one declaration, by origin and location.
    keyed = collections.Counter((u["origin"], u["module"], u["path"], u.get("file"), u.get("line")) for u in decls)
    want_keys = collections.Counter([("graph", e["module"], e["path"], e.get("file"), e.get("line")) for e in added] +
                                    [("scan", x["module"], ".".join(x["scopes"] + [x["name"]]), x["file"], x["line"])
                                     for x in hidden])
    if keyed != want_keys:
        extra, missing = keyed - want_keys, want_keys - keyed
        for k in list(missing)[:5]:
            problems.append(f"api-delta's {k[2]} ({k[3]}:{k[4]}) isn't in the burn-down")
        for k in list(extra)[:5]:
            problems.append(f"the burn-down's {k[2]} ({k[3]}:{k[4]}) isn't api-delta's")
    ids = collections.Counter(u["id"] for u in decls)
    dup = [k for k, v in ids.items() if v > 1]
    if dup:
        problems.append(f"{len(dup)} declaration IDs repeat, such as {dup[0]}")
    t = data["totals"]
    main = sum(1 for u in decls if not u["excluded"])
    outside = sum(1 for u in decls if u["excluded"])
    merged_main = sum(1 for g in data["merged"] if not g["excluded"])
    merged_out = len(data["merged"]) - merged_main
    if t["mainCount"] != main + merged_main or t["outsideCount"] != outside + merged_out:
        problems.append(f"totals {t['mainCount']} + {t['outsideCount']} outside don't match the declarations' "
                        f"{main + merged_main} + {outside + merged_out}")
    by_state = collections.Counter(u["state"] for u in decls if not u["excluded"])
    by_state[5] += merged_main
    if {str(k): by_state[k] for k in range(1, 6)} != t["main"]:
        problems.append(f"state totals {t['main']} don't match the declarations' {dict(by_state)}")
    days = [d for d in data["history"]["days"] if d.get("codes") is not None]
    if days:
        last = days[-1]
        if last["commit"] == bm["headCommit"] and last["scope"] != t["mainCount"]:
            problems.append(f"the last day's scope, {last['scope']}, isn't the main count, {t['mainCount']}")
        for d in days:
            n = sum(1 for ch in d["codes"] if ch in "12345")
            if n != d["scope"]:
                problems.append(f"{d['day']}: codes count {n}, scope {d['scope']}")
    if a.page:
        digest = data.get("digest")
        try:
            with open(a.page, encoding="utf-8") as f:
                page = f.read()
        except OSError as e:
            page = ""
            problems.append(f"can't read {a.page}: {e}")
        if page and digest and f'"{digest}"' not in page:
            problems.append(f"{a.page} isn't the page of this burndown.json (digest {digest[:12]})")
        if page and len(page.encode()) >= 5_000_000:
            problems.append(f"{a.page} is {len(page.encode())} bytes, over 5 MB")
        if page and re.search(r"""(?:src|href)\s*=\s*["']https?://""", page):
            problems.append(f"{a.page} loads something from the network")
    for p in problems:
        print(f"check: {p}", file=sys.stderr)
    if problems:
        print(f"check: FAILED, {len(problems)} problem(s)", file=sys.stderr)
        return 1
    print(f"check: OK: {len(decls)} declarations = api-delta's {len(added)} added + {len(hidden)} hidden; "
          f"{t['mainCount']} in the main count, {t['outsideCount']} outside; {len(days)} days")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo")
    ap.add_argument("--delta", required=True)
    ap.add_argument("--graph")
    ap.add_argument("--graph-source", default="given")
    ap.add_argument("--pitches")
    ap.add_argument("--pitches-rel", default="Prototype/Pitches")
    ap.add_argument("--states")
    ap.add_argument("--vocab")
    ap.add_argument("--coverage-results")
    ap.add_argument("--store")
    ap.add_argument("--cache")
    ap.add_argument("--sdk-cache")
    ap.add_argument("--work")
    ap.add_argument("--upstream")
    ap.add_argument("--base-ref", default="main")
    ap.add_argument("--head-ref", default="system-next")
    ap.add_argument("--today")
    ap.add_argument("--out-json", required=True)
    ap.add_argument("--page")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        sys.exit(check(a))
    result = build(a)
    body = json.dumps(result, sort_keys=True, separators=(",", ":"))
    result["digest"] = hashlib.sha256(body.encode()).hexdigest()
    tmp = a.out_json + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(result, f, sort_keys=True, indent=1)
    os.replace(tmp, a.out_json)
    t = result["totals"]
    by_state = ", ".join("%s %d" % (s["label"].lower(), t["main"][str(s["id"])]) for s in STATES)
    print(f"burndown: {t['declarations']} declarations, {t['mainCount']} in the main count ({by_state}), "
          f"{t['outsideCount']} outside; {len(result['history']['days'])} days -> {a.out_json}")


if __name__ == "__main__":
    main()
