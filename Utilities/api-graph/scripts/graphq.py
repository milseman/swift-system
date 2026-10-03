#!/usr/bin/env python3
"""Query the API graph's snapshots (snapshot.py): neighborhoods by link kind,
a type with or without its members, what reaches a C function family, a C
name's callers, a package's reach, and the difference between snapshots.

  graphq.py find 'PThread.Mutex'               nodes whose path or name matches
  graphq.py show 'PThread.Mutex.lock()'        a node and every link, by kind
  graphq.py neighbors KernelQueue --kind memberOf,usesInSignature --depth 2
  graphq.py type ProcessID --members           a type, its members, their reach
  graphq.py family chmod                       the chmod family: C names, wrappers, callers
  graphq.py cname getpid                       who wraps getpid, and who calls it
  graphq.py package swift-nio                  what swift-nio uses, and could
  graphq.py domain signals                     a domain's declarations, by C family
  graphq.py diff OLD NEW                       nodes and links added, removed, changed
  graphq.py summary --out GRAPH.md             the snapshot's report
  graphq.py doc-sentences --out DOC-SENTENCES.md   the work list for doc sentences

A NODE is an ID, a path (`FileDescriptor.setOwner(user:group:retryOnInterrupt:)`),
a C name (`getpid`), a package key, or a unique part of a path. Link kinds
are the stored ones (memberOf, nestedIn, extends, conformsTo,
usesInSignature, wraps, reaches, inBlock, testedBy, sampledBy, stubFor,
usedBy, calls) and the derived ones (sameCFamily, sameImplementation,
sameBlock, sameMark, couldUse). --json prints the answer as JSON.

The snapshot is --snapshot PATH, or a commit whose snapshot the store has
(--store, default ../api-graph-snapshots beside the repository), or else the
last run's (.build/api-graph/graph.json.gz).
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

STORED = ["memberOf", "nestedIn", "extends", "conformsTo", "usesInSignature", "wraps", "reaches", "inBlock",
          "testedBy", "sampledBy", "stubFor", "usedBy", "calls"]
DERIVED = ["sameCFamily", "sameImplementation", "sameBlock", "sameMark", "couldUse"]
HUB = 20   # internal code more declarations than this reach is a shared helper, not a shared implementation
DECL_COMPARE = ("path", "decl", "availability", "platforms", "symbolKind", "hiddenClass", "origin", "module",
                "file", "renamedTo")


def link_sources(ln):
    """A wraps link's sources: `doc` (a doc sentence), `typealias` (a
    CInterop typealias), `code` (what its code reaches). A snapshot before
    schema 2 has one `source`."""
    return ln.get("sources") or [ln.get("source") or "doc"]


def stated(ln):
    """A wraps link a doc sentence or a typealias makes, which says what the
    declaration stands for: what reach, families, domains and pitch rules
    read. A code-only link says what its implementation touches."""
    return ln["kind"] == "wraps" and any(x in ("doc", "typealias") for x in link_sources(ln))


def could_use(ln, nodes):
    """Whether a package that calls the C name a link points to could use
    the declaration instead: a stated link, not restricted to one use of the
    name, not a field's (the coverage tools record a field as a member of its
    struct's interface), to a name the base commit doesn't cover."""
    return (stated(ln) and not ln["restricted"] and ln.get("cKind") != "field"
            and not nodes[ln["to"]]["baseCovered"])


def load(path):
    if path.endswith(".gz"):
        return json.load(gzip.open(path, "rt", encoding="utf-8"))
    return json.load(open(path, encoding="utf-8"))


def repo_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    return out or os.getcwd()


def find_snapshot(arg, store):
    if arg and os.path.exists(arg):
        return arg
    root = repo_root()
    store = store or os.path.join(os.path.dirname(root), "api-graph-snapshots")
    if arg:
        commit = subprocess.run(["git", "rev-parse", "--verify", "--quiet", arg + "^{commit}"],
                                capture_output=True, text=True).stdout.strip() or arg
        cand = [os.path.join(store, f) for f in os.listdir(store) if f.startswith(commit)] \
            if os.path.isdir(store) else []
        if len(cand) == 1:
            return cand[0]
        raise SystemExit(f"graphq: no snapshot of {arg} in {store}")
    default = os.path.join(root, ".build", "api-graph", "graph.json.gz")
    if os.path.exists(default):
        return default
    raise SystemExit(f"graphq: no snapshot: run Utilities/api-graph/regenerate.sh, or pass --snapshot")


class Graph:
    def __init__(self, doc):
        self.doc = doc
        self.nodes = doc["nodes"]
        self.out = collections.defaultdict(list)
        self.inc = collections.defaultdict(list)
        for ln in doc["links"]:
            self.out[ln["from"]].append(ln)
            self.inc[ln["to"]].append(ln)
        self.by_path = collections.defaultdict(list)
        for nid, n in self.nodes.items():
            for key in (n.get("path"), n.get("name"), n.get("key")):
                if key:
                    self.by_path[key].append(nid)

    def label(self, nid):
        n = self.nodes.get(nid)
        if not n:
            return nid
        k = n["kind"]
        if k == "declaration":
            return n.get("path") or nid
        if k == "cname":
            return n["name"]
        if k == "package":
            return n["name"]
        if k == "internal":
            return n["name"]
        if k == "block":
            return f"{n['blockKind']} {n['subject']}" + (f" (MARK: {n['mark']})" if n.get("mark") else "") + \
                f" {n['file']}:{n['start']}"
        if k == "test":
            return f"{n['scope'] + '.' if n.get('scope') else ''}{n['name']}"
        if k == "sample":
            return n["file"]
        return nid

    def resolve(self, text, kinds=None):
        """The node a NODE argument names."""
        if text in self.nodes:
            return text
        for prefix in ("cname:", "package:"):
            if prefix + text in self.nodes and (not kinds or self.nodes[prefix + text]["kind"] in kinds):
                return prefix + text
        exact = [x for x in self.by_path.get(text, []) if not kinds or self.nodes[x]["kind"] in kinds]
        head = [x for x in exact if self.nodes[x].get("origin") in (None, "head")]
        if len(exact) == 1 or len(head) == 1:
            return exact[0] if len(exact) == 1 else head[0]
        part = [nid for nid, n in self.nodes.items() if (not kinds or n["kind"] in kinds)
                and text in (n.get("path") or n.get("name") or "")]
        if len(part) == 1:
            return part[0]
        if not part and not exact:
            raise SystemExit(f"graphq: nothing is named {text!r}; try `graphq.py find`")
        cands = exact or part
        raise SystemExit(f"graphq: {text!r} names {len(cands)} nodes, such as: "
                         + "; ".join(self.label(x) for x in sorted(cands, key=self.label)[:8]))

    # -------------------------------------------------------- derived links
    def derived(self, nid, kind):
        """[(other node, detail)] for a derived link kind."""
        out = []
        if kind == "sameCFamily":
            fams = {self.nodes[ln["to"]]["family"] for ln in self.out[nid] if stated(ln)
                    and self.nodes[ln["to"]].get("family")}
            for fam in sorted(fams):
                for cid, c in self.nodes.items():
                    if c["kind"] == "cname" and c.get("family") == fam:
                        for ln in self.inc[cid]:
                            if stated(ln) and ln["from"] != nid:
                                out.append((ln["from"], f"{fam} family ({c['name']})"))
        elif kind == "sameImplementation":
            for ln in self.out[nid]:
                # A helper most wrappers reach (nothingOrErrno, the mock
                # hooks) says nothing about two of them.
                if ln["kind"] == "reaches" and sum(1 for x in self.inc[ln["to"]] if x["kind"] == "reaches") <= HUB:
                    for l2 in self.inc[ln["to"]]:
                        if l2["kind"] == "reaches" and l2["from"] != nid:
                            out.append((l2["from"], self.label(ln["to"])))
        elif kind in ("sameBlock", "sameMark"):
            for ln in self.out[nid]:
                if ln["kind"] != "inBlock":
                    continue
                blocks = [ln["to"]]
                b = self.nodes[ln["to"]]
                if kind == "sameMark" and b.get("mark"):
                    blocks = [x for x, n in self.nodes.items() if n["kind"] == "block" and n["file"] == b["file"]
                              and n.get("mark") == b["mark"]]
                for bid in blocks:
                    for l2 in self.inc[bid]:
                        if l2["kind"] == "inBlock" and l2["from"] != nid:
                            out.append((l2["from"], self.label(bid)))
        elif kind == "couldUse":
            for ln in self.out[nid]:
                if could_use(ln, self.nodes):
                    for l2 in self.inc[ln["to"]]:
                        if l2["kind"] == "calls":
                            n_ = len(l2["sites"])
                            out.append((l2["from"], f"calls {self.nodes[ln['to']]['name']} "
                                                    f"({n_} site{'s' if n_ != 1 else ''})"))
        seen, uniq = set(), []
        for x in out:
            if x[0] not in seen:
                seen.add(x[0])
                uniq.append(x)
        return uniq

    def neighbors(self, nid, kinds, direction="both"):
        """[(kind, direction, other, link or detail)]"""
        res = []
        for ln in self.out[nid] if direction in ("out", "both") else []:
            if not kinds or ln["kind"] in kinds:
                res.append((ln["kind"], "→", ln["to"], ln))
        for ln in self.inc[nid] if direction in ("in", "both") else []:
            if not kinds or ln["kind"] in kinds:
                res.append((ln["kind"], "←", ln["from"], ln))
        for k in DERIVED:
            if kinds and k not in kinds:
                continue
            if not kinds and k in ("sameBlock", "sameMark", "sameImplementation"):
                continue   # shown on request: blocks and shared helpers are big
            for other, detail in self.derived(nid, k):
                res.append((k, "↔", other, detail))
        return res

    def members(self, tid, nested=False):
        out = []
        for ln in self.inc[tid]:
            if ln["kind"] == "memberOf":
                out.append(ln["from"])
            elif ln["kind"] == "nestedIn" and nested:
                out.append(ln["from"])
                out += self.members(ln["from"], nested=True)
        return out

    def sites(self, ln):
        return ln.get("sites") or []


# ---------------------------------------------------------------- commands

def md_cell(text):
    return text.replace("|", "\\|").replace("\n", " ")


def link_text(g, kind, arrow, other, detail):
    txt = f"{kind:<18} {arrow} {g.label(other)}"
    if isinstance(detail, dict):
        extra = []
        if detail.get("roles"):
            extra.append("/".join(detail["roles"]))
        if kind == "wraps":
            extra.append(detail["role"] + (", restricted" if detail["restricted"] else "") + ", from "
                         + "+".join(link_sources(detail)))
        if detail.get("sites"):
            s = detail["sites"]
            extra.append(f"{len(s)} site{'s' if len(s) != 1 else ''}: " + ", ".join(
                f"{x['file']}:{x['line']}" + (f" ({x['resolution']})" if x.get("resolution") else "")
                for x in s[:3]) + (", …" if len(s) > 3 else ""))
        if extra:
            txt += "  [" + "; ".join(extra) + "]"
    elif detail:
        txt += f"  [{detail}]"
    return txt


def cmd_find(g, a):
    pat = re.compile(a.pattern)
    rows = [(nid, n) for nid, n in g.nodes.items()
            if pat.search(n.get("path") or n.get("name") or n.get("file") or nid)
            and (not a.kind or n["kind"] == a.kind)]
    rows.sort(key=lambda r: (r[1]["kind"], g.label(r[0])))
    if a.json:
        return print(json.dumps([dict(n, id=nid) for nid, n in rows], indent=1))
    for nid, n in rows[:a.limit]:
        origin = f"/{n['origin']}" if n.get("origin") else ""
        print(f"{n['kind']}{origin:<9} {g.label(nid)}   {nid}")
    if len(rows) > a.limit:
        print(f"… {len(rows) - a.limit} more (--limit)")


def cmd_show(g, a):
    nid = g.resolve(a.node)
    n = g.nodes[nid]
    res = g.neighbors(nid, None)
    if a.json:
        return print(json.dumps({"id": nid, "node": n, "links": [
            {"kind": k, "direction": d, "other": o, "detail": x if isinstance(x, (dict, str)) else None}
            for k, d, o, x in res]}, indent=1))
    print(f"{g.label(nid)}  ({n['kind']}{'/' + n['origin'] if n.get('origin') else ''})  {nid}")
    for k in ("decl", "file", "line", "availability", "platforms", "docSummary", "family", "cKinds", "baseCovered",
              "remote", "domains"):
        if n.get(k) not in (None, "", []):
            print(f"  {k}: {n[k]}")
    if n.get("reach") is not None:
        print(f"  reach: {reach_line(g, nid)}")
    by = collections.defaultdict(list)
    for k, d, o, x in res:
        by[k].append((d, o, x))
    for k in STORED + DERIVED:
        for d, o, x in sorted(by.get(k, []), key=lambda r: g.label(r[1]))[:a.limit]:
            print("  " + link_text(g, k, d, o, x))
        if len(by.get(k, [])) > a.limit:
            print(f"  {k:<18}   … {len(by[k]) - a.limit} more")


def cmd_neighbors(g, a):
    nid = g.resolve(a.node)
    kinds = set(a.kind.split(",")) if a.kind else None
    frontier, seen, rows = [nid], {nid}, []
    for depth in range(1, a.depth + 1):
        nxt = []
        for x in frontier:
            for k, d, o, detail in g.neighbors(x, kinds, a.direction):
                rows.append((depth, x, k, d, o, detail))
                if o not in seen:
                    seen.add(o)
                    nxt.append(o)
        frontier = nxt
    if a.json:
        return print(json.dumps([{"depth": dp, "from": x, "kind": k, "direction": d, "node": o}
                                 for dp, x, k, d, o, _ in rows], indent=1))
    for dp, x, k, d, o, detail in rows:
        print(("  " * (dp - 1)) + (f"{g.label(x)}: " if dp > 1 else "") + link_text(g, k, d, o, detail))


def reach_line(g, nid):
    r = g.nodes[nid].get("reach") or {}
    u = [g.label("package:" + k) for k in r.get("usedBy", [])]
    c = [g.label("package:" + k) for k in r.get("couldUse", [])]
    return f"used by {len(u)}" + (f" ({', '.join(u)})" if u else "") + f"; could be used by {len(c)}" + (
        f" ({', '.join(c)})" if c else "")


def cmd_type(g, a):
    tid = g.resolve(a.type, kinds={"declaration"})
    rows = [tid] + (sorted(set(g.members(tid, nested=a.nested)), key=g.label) if a.members else [])
    out = []
    for nid in rows:
        n = g.nodes[nid]
        if n.get("origin") != "head" and nid != tid:
            continue
        callers = collections.defaultdict(list)
        for k, d, o, detail in g.neighbors(nid, {"couldUse"}):
            callers[o].append(detail)
        out.append({"id": nid, "path": n.get("path"), "origin": n.get("origin"), "reach": n.get("reach"),
                    "wraps": [g.nodes[ln["to"]]["name"] + ("" if stated(ln) else " (code)")
                              for ln in g.out[nid] if ln["kind"] == "wraps"]})
    if a.json:
        return print(json.dumps(out, indent=1))
    for r in out:
        print(f"{r['path']}  ({r['origin']})" + (f"  wraps {', '.join(r['wraps'])}" if r["wraps"] else ""))
        if r["reach"] is not None:
            print(f"    {reach_line(g, r['id'])}")
        if a.sites:
            for ln in g.out[r["id"]]:
                if ln["kind"] == "usedBy":
                    for s in ln["sites"][:a.limit]:
                        print(f"      uses: {g.label(ln['to'])} {s['file']}:{s['line']} ({s['resolution']})")
                if stated(ln) and not ln["restricted"]:
                    for l2 in g.inc[ln["to"]]:
                        if l2["kind"] == "calls":
                            for s in l2["sites"][:a.limit]:
                                print(f"      calls {g.nodes[ln['to']]['name']}: {g.label(l2['from'])} "
                                      f"{s['file']}:{s['line']} ({s['resolution']})")


def family_members(g, name):
    c = g.nodes.get("cname:" + name)
    fam = c.get("family") if c else None
    if not fam:
        fams = {n.get("family") for n in g.nodes.values() if n["kind"] == "cname" and n.get("family") == name}
        fam = name if fams else None
    if not fam:
        raise SystemExit(f"graphq: {name!r} is in no C function family")
    return fam, sorted(cid for cid, n in g.nodes.items() if n["kind"] == "cname" and n.get("family") == fam)


def cmd_family(g, a):
    fam, cids = family_members(g, a.name)
    return cnames_report(g, cids, f"the {fam} family", a)


def cmd_cname(g, a):
    cid = g.resolve(a.name, kinds={"cname"})
    return cnames_report(g, [cid], g.label(cid), a)


def cnames_report(g, cids, title, a):
    out = []
    for cid in cids:
        c = g.nodes[cid]
        wrappers = [(ln["from"], ln["role"], ln["restricted"], link_sources(ln)) for ln in g.inc[cid]
                    if ln["kind"] == "wraps"]
        callers = [(ln["from"], ln["sites"]) for ln in g.inc[cid] if ln["kind"] == "calls"]
        users = set()
        for w, _, _, _ in wrappers:
            for ln in g.out[w]:
                if ln["kind"] == "usedBy" and not ln.get("qualifierOnly"):
                    users.add(ln["to"])
        out.append({"cname": c["name"], "baseCovered": c["baseCovered"], "cKinds": c["cKinds"],
                    "wrappers": [{"id": w, "path": g.label(w), "role": r, "restricted": rs, "sources": src}
                                 for w, r, rs, src in wrappers],
                    "callers": [{"package": g.label(p), "sites": s} for p, s in callers],
                    "wrappersUsedBy": sorted(g.label(u) for u in users)})
    if a.json:
        return print(json.dumps(out, indent=1))
    print(f"{title}: {', '.join(r['cname'] for r in out)}")
    for r in out:
        print(f"\n{r['cname']}  ({', '.join(r['cKinds'])}"
              + (", covered on the base commit" if r["baseCovered"] else "") + ")")
        for w in r["wrappers"]:
            print(f"  wrapped by {w['path']}  [{w['role']}{', restricted' if w['restricted'] else ''}, from "
                  f"{'+'.join(w['sources'])}]")
        if r["wrappersUsedBy"]:
            print(f"  its wrappers are used by: {', '.join(r['wrappersUsedBy'])}")
        for c in sorted(r["callers"], key=lambda c: -len(c["sites"])):
            s = c["sites"]
            print(f"  called by {c['package']}: {len(s)} site{'s' if len(s) != 1 else ''}: " + ", ".join(
                f"{x['file']}:{x['line']}" for x in s[:a.limit]) + (", …" if len(s) > a.limit else ""))


def cmd_domain(g, a):
    doms = {d["id"]: d for d in g.doc["meta"].get("domains", [])}
    if a.name not in doms:
        raise SystemExit(f"graphq: no domain {a.name!r}; the domains are: {', '.join(doms)}")
    rows = collections.defaultdict(list)
    for nid, n in g.nodes.items():
        if n["kind"] == "declaration" and n.get("origin") == "head" and a.name in (n.get("domains") or []):
            fams = sorted({g.nodes[ln["to"]].get("family") or g.nodes[ln["to"]]["name"] for ln in g.out[nid]
                           if stated(ln) and a.name in (g.nodes[ln["to"]].get("domains") or [])})
            rows[", ".join(fams)].append(nid)
    if a.json:
        return print(json.dumps({k: [g.label(x) for x in v] for k, v in rows.items()}, indent=1))
    d = doms[a.name]
    print(f"{d['title']}" + (f" (APUE chapter {d['apue']})" if d.get("apue") else "")
          + f": {sum(len(v) for v in rows.values())} declarations")
    for fam, xs in sorted(rows.items()):
        print(f"\n  {fam}:")
        for x in sorted(xs, key=g.label)[:a.limit]:
            print(f"    {g.label(x)}  [{reach_line(g, x)}]")
        if len(xs) > a.limit:
            print(f"    … {len(xs) - a.limit} more")


def cmd_package(g, a):
    pid = g.resolve(a.key, kinds={"package"})
    p = g.nodes[pid]
    uses = [(ln["from"], ln["sites"]) for ln in g.inc[pid] if ln["kind"] == "usedBy" and not ln.get("qualifierOnly")]
    could = collections.defaultdict(list)
    for ln in g.out[pid]:
        if ln["kind"] != "calls":
            continue
        c = g.nodes[ln["to"]]
        for l2 in g.inc[ln["to"]]:
            if could_use(l2, g.nodes):
                could[l2["from"]].append((c["name"], len(ln["sites"])))
    if a.json:
        return print(json.dumps({"package": p, "uses": [{"id": u, "path": g.label(u), "sites": s} for u, s in uses],
                                 "couldUse": [{"id": k, "path": g.label(k), "cnames": v} for k, v in could.items()]},
                                indent=1))
    ad = p.get("adopted")
    print(f"{p['name']}  ({p['remote']})")
    if ad:
        print(f"  migration: {ad['branch']} @ {ad['commit'][:10]}, {ad['commits']} commits past "
              f"{ad['mainRef']} @ {(ad['base'] or '')[:10]}, {ad['resolution']}")
    if p.get("benefit"):
        b = p["benefit"]
        print(f"  C interfaces: {b['role']} @ {b['commit'][:10]}, {b['source']} ({b['extraction']})")
    print(f"\nuses {len(uses)} declarations:")
    for u, s in sorted(uses, key=lambda r: -len(r[1]))[:a.limit]:
        print(f"  {g.label(u)}: {len(s)} site{'s' if len(s) != 1 else ''}, such as {s[0]['file']}:{s[0]['line']} "
              f"({s[0]['resolution']})")
    if len(uses) > a.limit:
        print(f"  … {len(uses) - a.limit} more")
    used = {u for u, _ in uses}
    rest = [(k, v) for k, v in could.items() if k not in used]
    print(f"\ncould use {len(rest)} more, by the C interfaces it calls:")
    for k, v in sorted(rest, key=lambda r: -sum(n for _, n in r[1]))[:a.limit]:
        print(f"  {g.label(k)}: " + ", ".join(f"{c} ×{n}" for c, n in v))
    if len(rest) > a.limit:
        print(f"  … {len(rest) - a.limit} more")


# ---------------------------------------------------------------- diff

def link_key(ln):
    return (ln["kind"], ln["from"], ln["to"], ln.get("role") or "")


def link_facts(ln):
    """What a link says, less its line numbers, which move with every edit."""
    out = {k: v for k, v in ln.items() if k not in ("kind", "from", "to", "sites", "sentence")}
    if "sites" in ln:
        out["sites"] = len(ln["sites"])
        out["files"] = sorted({s["file"] for s in ln["sites"]})
    return out


def node_facts(n):
    if n["kind"] == "declaration":
        out = {k: n.get(k) for k in DECL_COMPARE}
        if n.get("reach") is not None:
            out["reach"] = n["reach"]
        return out
    if n["kind"] == "package":
        return {"adopted": (n.get("adopted") or {}).get("commit"), "benefit": (n.get("benefit") or {}).get("commit")}
    return {k: v for k, v in n.items() if k not in ("start", "end", "line")}


def diff(old, new):
    on, nn = old["nodes"], new["nodes"]
    added = sorted(set(nn) - set(on))
    removed = sorted(set(on) - set(nn))
    changed = []
    for k in sorted(set(on) & set(nn)):
        a_, b_ = node_facts(on[k]), node_facts(nn[k])
        if a_ != b_:
            changed.append({"id": k, "fields": sorted(f for f in set(a_) | set(b_) if a_.get(f) != b_.get(f)),
                            "old": {f: a_.get(f) for f in a_ if a_.get(f) != b_.get(f)},
                            "new": {f: b_.get(f) for f in b_ if a_.get(f) != b_.get(f)}})
    ol = {link_key(ln): ln for ln in old["links"]}
    nl = {link_key(ln): ln for ln in new["links"]}
    l_added = sorted(set(nl) - set(ol))
    l_removed = sorted(set(ol) - set(nl))
    l_changed = [k for k in sorted(set(ol) & set(nl)) if link_facts(ol[k]) != link_facts(nl[k])]

    def lab(doc, nid):
        n = doc["nodes"].get(nid) or {}
        return n.get("path") or n.get("name") or nid
    return {
        "old": old["meta"], "new": new["meta"],
        "nodes": {"added": [{"id": k, "kind": nn[k]["kind"], "label": lab(new, k)} for k in added],
                  "removed": [{"id": k, "kind": on[k]["kind"], "label": lab(old, k)} for k in removed],
                  "changed": [dict(c, label=lab(new, c["id"])) for c in changed]},
        "links": {"added": [{"kind": k[0], "from": lab(new, k[1]), "to": lab(new, k[2])} for k in l_added],
                  "removed": [{"kind": k[0], "from": lab(old, k[1]), "to": lab(old, k[2])} for k in l_removed],
                  "changed": [{"kind": k[0], "from": lab(new, k[1]), "to": lab(new, k[2]),
                               "old": link_facts(ol[k]), "new": link_facts(nl[k])} for k in l_changed]},
    }


def diff_summary(d):
    def count(xs, key):
        c = collections.Counter(x[key] for x in xs)
        return ", ".join(f"{v} {k}" for k, v in c.most_common()) or "none"
    return (f"nodes +{len(d['nodes']['added'])} −{len(d['nodes']['removed'])} ~{len(d['nodes']['changed'])}; "
            f"links +{len(d['links']['added'])} −{len(d['links']['removed'])} ~{len(d['links']['changed'])} "
            f"(added: {count(d['links']['added'], 'kind')})")


def diff_md(d, limit=60):
    L = ["# Graph diff", "",
         f"From `{d['old'].get('headRef')}` @ `{d['old'].get('headCommit', '')[:10]}` "
         f"({d['old'].get('snapshotDate')}) to `{d['new'].get('headRef')}` @ `{d['new'].get('headCommit', '')[:10]}` "
         f"({d['new'].get('snapshotDate')}): {diff_summary(d)}.", ""]
    for part, title in (("added", "Added"), ("removed", "Removed")):
        xs = d["nodes"][part]
        L += [f"## Nodes {part} ({len(xs)})", ""]
        by = collections.defaultdict(list)
        for x in xs:
            by[x["kind"]].append(x["label"])
        for k, v in sorted(by.items()):
            L.append(f"- {k} ({len(v)}): " + ", ".join(f"`{x}`" for x in sorted(v)[:limit])
                     + (f", and {len(v) - limit} more" if len(v) > limit else ""))
        L.append("")
    xs = d["nodes"]["changed"]
    L += [f"## Nodes changed ({len(xs)})", ""]
    for c in xs[:limit]:
        L.append(f"- `{c['label']}`: " + "; ".join(f"{f}: {json.dumps(c['old'].get(f))} → {json.dumps(c['new'].get(f))}"
                                                    for f in c["fields"])[:400])
    if len(xs) > limit:
        L.append(f"- … and {len(xs) - limit} more (diff.json)")
    L.append("")
    for part in ("added", "removed", "changed"):
        xs = d["links"][part]
        L += [f"## Links {part} ({len(xs)})", ""]
        by = collections.defaultdict(list)
        for x in xs:
            by[x["kind"]].append(x)
        for k, v in sorted(by.items()):
            L.append(f"- {k} ({len(v)}): " + "; ".join(f"`{x['from']}` → `{x['to']}`" for x in v[:12])
                     + (f"; and {len(v) - 12} more" if len(v) > 12 else ""))
        L.append("")
    return "\n".join(L) + "\n"


def cmd_diff(g_unused, a):
    old = load(find_snapshot(a.old, a.store))
    new = load(find_snapshot(a.new, a.store))
    d = diff(old, new)
    if a.json:
        return print(json.dumps(d, indent=1))
    print(diff_md(d, limit=a.limit))


# ---------------------------------------------------------------- summary

def summary_md(doc, diff_file=None):
    g = Graph(doc)
    m = doc["meta"]
    kinds = collections.Counter(n["kind"] if n["kind"] != "declaration" else f"declaration ({n['origin']})"
                                for n in doc["nodes"].values())
    lk = collections.Counter(ln["kind"] for ln in doc["links"])
    heads = [nid for nid, n in doc["nodes"].items() if n["kind"] == "declaration" and n["origin"] == "head"]
    L = [f"# API graph: `{m['baseRef']}` → `{m['headRef']}`", "",
         f"- Base: `{m['baseRef']}` @ `{m['baseCommit']}`", f"- Head: `{m['headRef']}` @ `{m['headCommit']}`", "",
         f"The graph of every declaration `{m['headRef']}` adds over `{m['baseRef']}`, the base and external types "
         "they build on, and typed links between them, with each declaration's adopter reach. The schema is in "
         "`Prototype/ApiGraph/REPORT.md`, section 1; `Utilities/api-graph/scripts/graphq.py` queries it. The "
         "snapshot is `graph.json.gz`, and the store keeps one per commit.", "",
         "## Nodes", "", "| Kind | Count |", "|---|---:|"]
    for k, v in sorted(kinds.items()):
        L.append(f"| {k} | {v} |")
    L += ["", "## Links", "", "| Kind | Count |", "|---|---:|"]
    for k in STORED:
        L.append(f"| `{k}` | {lk.get(k, 0)} |")
    by_src = collections.Counter("+".join(link_sources(ln)) for ln in doc["links"] if ln["kind"] == "wraps")
    L += ["", "`wraps` links by source: " + ", ".join(f"{v} {k}" for k, v in sorted(by_src.items()))
          + ". A `doc` link is a doc sentence's, a `typealias` link a CInterop typealias's, and a `code` link what "
          "the declaration's code reaches through internal code; `DOC-SENTENCES.md` lists the declarations whose "
          "C names come only from their code."]
    fams = collections.Counter(n.get("family") for n in doc["nodes"].values() if n["kind"] == "cname" and n.get("family"))
    L += ["", f"Derived at query time: `sameCFamily` ({len(fams)} C function families), `sameImplementation`, "
          "`sameBlock`, `sameMark`, `couldUse`.", ""]
    used = [x for x in heads if (doc["nodes"][x].get("reach") or {}).get("usedBy")]
    could = [x for x in heads if (doc["nodes"][x].get("reach") or {}).get("couldUse")]
    L += ["## Adopter reach", "",
          f"{len(used)} of the {len(heads)} new declarations are used by a package's migration branch, and "
          f"{len(could)} wrap a C interface some package calls.", "",
          "The declarations used by the most packages:", "", "| Declaration | Used by | Could be used by |",
          "|---|---|---|"]
    for nid in sorted(used, key=lambda x: (-len(doc["nodes"][x]["reach"]["usedBy"]),
                                           -len(doc["nodes"][x]["reach"]["couldUse"]), g.label(x)))[:25]:
        r = doc["nodes"][nid]["reach"]
        L.append(f"| `{g.label(nid)}` | {len(r['usedBy'])} ({', '.join(g.label('package:' + k) for k in r['usedBy'])}) "
                 f"| {len(r['couldUse'])} |")
    L += ["", "The declarations the most packages could use and none does yet:", "",
          "| Declaration | Could be used by | Through |", "|---|---:|---|"]
    rest = [x for x in could if not doc["nodes"][x]["reach"]["usedBy"]]
    for nid in sorted(rest, key=lambda x: (-len(doc["nodes"][x]["reach"]["couldUse"]), g.label(x)))[:25]:
        r = doc["nodes"][nid]["reach"]
        via = sorted({g.nodes[ln["to"]]["name"] for ln in g.out[nid] if could_use(ln, g.nodes)})
        L.append(f"| `{g.label(nid)}` | {len(r['couldUse'])} | {', '.join('`' + v + '`' for v in via[:4])} |")
    pk = [n for n in doc["nodes"].values() if n["kind"] == "package"]
    L += ["", "## Packages", "", "| Package | Migration | Declarations it uses | Interface data |", "|---|---|---:|---|"]
    for p in sorted(pk, key=lambda p: p["key"]):
        pid = "package:" + p["key"]
        n_use = sum(1 for ln in g.inc[pid] if ln["kind"] == "usedBy" and not ln.get("qualifierOnly"))
        ad, be = p.get("adopted"), p.get("benefit")
        mig = f"`{ad['branch']}` @ `{ad['commit'][:10]}` ({ad['resolution']})" if ad else "—"
        dat = f"{be['role']} `{be['commit'][:10]}` ({be['source']}, {be['extraction']})" if be else "—"
        L.append(f"| `{p['name']}` | {mig} | {n_use} | {dat} |")
    migs = [p for p in sorted(pk, key=lambda p: p["key"]) if p.get("adopted")]
    if migs:
        L += ["", "## The migrations' indexes", "",
              "Whether each migration's index was reused (built against this System tree), revalidated (built "
              "against another, and every System declaration it names is unchanged) or rebuilt, and why.", "",
              "| Package | Index | Why | Build |", "|---|---|---|---|"]
        for p in migs:
            b = p["adopted"].get("build") or {}
            built = f"{b.get('status')}, {b['seconds']} s" if b.get("seconds") is not None else b.get("status", "—")
            if b.get("cached"):
                built += f", against `{(b.get('builtAgainst') or '')[:10]}`"
            elif b.get("start"):
                built += f", {b['start']}"
            L.append(f"| `{p['name']}` | {b.get('decision') or '—'} | {md_cell(b.get('decisionReason') or '')} "
                     f"| {md_cell(built)} |")
        builds = (doc["meta"].get("adopterMeta") or {}).get("buildDirectories")
        if builds:
            L += ["", f"The build directories, in `{builds['dir']}`, take {builds['totalMB'] / 1024:.1f} GB: "
                      f"{len(builds['packagesMB'])} packages' and System's export, each as measured after its "
                      "last build."]
    L += ["", "## Querying it", "", "```sh",
          "python3 Utilities/api-graph/scripts/graphq.py show 'PThread.Mutex.lock()'",
          "python3 Utilities/api-graph/scripts/graphq.py type ProcessID --members --sites",
          "python3 Utilities/api-graph/scripts/graphq.py neighbors KernelQueue --kind memberOf,usesInSignature",
          "python3 Utilities/api-graph/scripts/graphq.py family chmod",
          "python3 Utilities/api-graph/scripts/graphq.py cname getpid",
          "python3 Utilities/api-graph/scripts/graphq.py package swift-nio",
          "python3 Utilities/api-graph/scripts/graphq.py diff OLD_COMMIT NEW_COMMIT", "```", ""]
    doms = doc["meta"].get("domains") or []
    if doms:
        L += ["## Domains", "", "Loose groupings by task (`Utilities/api-graph/domains.json`, after the chapters of "
              "*Advanced Programming in the UNIX Environment*), for suggesting related API the links don't connect. "
              "`graphq.py domain ID` lists one.", "", "| Domain | Declarations | Used by packages |", "|---|---:|---:|"]
        for d in doms:
            xs = [x for x in heads if d["id"] in (doc["nodes"][x].get("domains") or [])]
            users = {p for x in xs for p in (doc["nodes"][x].get("reach") or {}).get("usedBy", [])}
            L.append(f"| `{d['id']}`: {d['title']}" + (f" (APUE {d['apue']})" if d.get("apue") else "")
                     + f" | {len(xs)} | {len(users)} |")
        fams = collections.Counter(n.get("family") for n in doc["nodes"].values()
                                   if n["kind"] == "cname" and n.get("family") and not n.get("domains"))
        if fams:
            L += ["", f"C function families no domain names yet ({len(fams)}): "
                  + ", ".join(f"`{f}`" for f in sorted(fams)[:60]) + (", …" if len(fams) > 60 else "") + "."]
        L.append("")
    if diff_file and os.path.exists(diff_file):
        L += ["## Since the previous snapshot", "", open(diff_file).read().split("\n", 2)[2].strip().split("\n")[0],
              "", "`DIFF.md` lists the nodes and links.", ""]
    return "\n".join(L) + "\n"


def doc_sentences_md(doc):
    """The work list for doc sentences: the new public declarations whose
    code reaches C that no doc sentence of theirs names, the types whose
    members reach C that no doc sentence names a C type for, and the
    declarations with no doc comment, by file."""
    g = Graph(doc)
    m = doc["meta"]
    code_only, types, bare = (collections.defaultdict(list) for _ in range(3))

    def wanted(nid):
        n = doc["nodes"].get(nid) or {}
        return (n.get("kind") == "declaration" and n.get("origin") == "head"
                and n.get("hiddenClass") not in ("unavailable", "underscored"))

    def member_names(nid, seen):
        out = []
        for ln in g.inc[nid]:
            if ln["kind"] in ("memberOf", "nestedIn") and ln["from"] not in seen:
                seen.add(ln["from"])
                out += [g.nodes[x["to"]]["name"] for x in g.out[ln["from"]] if x["kind"] == "wraps"]
                out += member_names(ln["from"], seen)
        return out
    for nid, n in doc["nodes"].items():
        if not wanted(nid):
            continue
        ws = [ln for ln in g.out[nid] if ln["kind"] == "wraps"]
        if ws and not any(stated(ln) for ln in ws):
            code_only[n.get("file") or "?"].append((n.get("line") or 0, g.label(nid), sorted(
                f"{g.nodes[ln['to']]['name']}" for ln in ws)))
        elif n.get("isType") and n.get("reachesC") and not ws:
            types[n.get("file") or "?"].append((n.get("line") or 0, g.label(nid),
                                                list(dict.fromkeys(member_names(nid, {nid})))))
        if not n.get("ownDoc"):
            bare[n.get("file") or "?"].append((n.get("line") or 0, g.label(nid), bool(n.get("hasDoc"))))
    L = [f"# Doc sentences to add: `{m['baseRef']}` → `{m['headRef']}`", "",
         f"The work list for adding \"The corresponding C … is `x`.\" sentences to the doc comments of the "
         f"declarations `{m['headRef']}` @ `{m['headCommit'][:10]}` adds, from the graph (`graph.json.gz`), by file "
         "and line. Fix-it stubs and underscored declarations are left out: a stub's name is its C name.", "",
         f"## Code that reaches C no doc sentence names ({sum(len(v) for v in code_only.values())})", "",
         "Each declaration's code, through the internal code it calls, references these C functions, macros, "
         "constants, variables or fields (a field as `struct.field`), and none of its doc sentences names a C "
         "interface. They're where to start, not the sentence: code can reach C a declaration doesn't stand for, "
         "such as the helpers a convenience combines.", ""]
    for f in sorted(code_only):
        L += [f"### `{f}`", ""]
        for line, path, names in sorted(code_only[f]):
            L.append(f"- {line}: `{path}`: " + ", ".join(f"`{x}`" for x in names[:12])
                     + (f", and {len(names) - 12} more" if len(names) > 12 else ""))
        L.append("")
    L += [f"## Types whose members reach C, and no doc sentence names a C type ({sum(len(v) for v in types.values())})",
          "", "A type gets no C names from its code, since its lines hold its members, so these are \"(no C name)\" on "
          "the burn-down page. Some stand for a C type or a family of constants; some are only namespaces. Each is "
          "listed with its members' C names.", ""]
    for f in sorted(types):
        L += [f"### `{f}`", ""]
        for line, path, names in sorted(types[f]):
            L.append(f"- {line}: `{path}`: " + (", ".join(f"`{x}`" for x in names[:8])
                                                + (f", and {len(names) - 8} more" if len(names) > 8 else "")
                                                if names else "only through a CSystem shim"))
        L.append("")
    own = sum(1 for v in bare.values() for x in v if not x[2])
    L += [f"## No doc comment ({sum(len(v) for v in bare.values())})", "",
          f"Declarations without a doc comment of their own. {own} have none at all; the rest inherit one from "
          "the protocol requirement they implement (marked *inherits*), and usually need none.", ""]
    for f in sorted(bare):
        L += [f"### `{f}`", ""]
        for line, path, inherits in sorted(bare[f]):
            L.append(f"- {line}: `{path}`" + (" *inherits*" if inherits else ""))
        L.append("")
    return "\n".join(L) + "\n"


def cmd_doc_sentences(g, a):
    text = doc_sentences_md(g.doc)
    if a.out:
        open(a.out, "w").write(text)
    else:
        print(text)


def cmd_summary(g, a):
    text = summary_md(g.doc, a.diff)
    if a.out:
        open(a.out, "w").write(text)
    else:
        print(text)


def main():
    # The common options go before or after the command; SUPPRESS keeps a
    # subcommand's absent option from overwriting one given before it.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--snapshot", default=argparse.SUPPRESS, help="a snapshot file, or a commit the store has")
    common.add_argument("--store", default=argparse.SUPPRESS, help="the snapshot store (default ../api-graph-snapshots)")
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS)
    common.add_argument("--limit", type=int, default=argparse.SUPPRESS, help="rows per list (default 20)")
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], parents=[common])
    sub = ap.add_subparsers(dest="cmd", required=True)
    real_add = sub.add_parser
    sub.add_parser = lambda name, **kw: real_add(name, parents=[common], **kw)
    p = sub.add_parser("find")
    p.add_argument("pattern")
    p.add_argument("--kind")
    p = sub.add_parser("show")
    p.add_argument("node")
    p = sub.add_parser("neighbors")
    p.add_argument("node")
    p.add_argument("--kind", default="")
    p.add_argument("--depth", type=int, default=1)
    p.add_argument("--direction", choices=("out", "in", "both"), default="both")
    p = sub.add_parser("type")
    p.add_argument("type")
    p.add_argument("--members", action="store_true")
    p.add_argument("--nested", action="store_true")
    p.add_argument("--sites", action="store_true")
    p = sub.add_parser("family")
    p.add_argument("name")
    p = sub.add_parser("cname")
    p.add_argument("name")
    p = sub.add_parser("package")
    p.add_argument("key")
    p = sub.add_parser("domain")
    p.add_argument("name")
    p = sub.add_parser("diff")
    p.add_argument("old")
    p.add_argument("new")
    p = sub.add_parser("summary")
    p.add_argument("--out")
    p.add_argument("--diff")
    p = sub.add_parser("doc-sentences")
    p.add_argument("--out")
    a = ap.parse_args()
    for k, v in (("snapshot", None), ("store", None), ("json", False), ("limit", 20)):
        if not hasattr(a, k):
            setattr(a, k, v)
    if a.cmd == "diff":
        return cmd_diff(None, a)
    g = Graph(load(find_snapshot(a.snapshot, a.store)))
    {"find": cmd_find, "show": cmd_show, "neighbors": cmd_neighbors, "type": cmd_type, "family": cmd_family,
     "cname": cmd_cname, "package": cmd_package, "domain": cmd_domain, "summary": cmd_summary,
     "doc-sentences": cmd_doc_sentences}[a.cmd](g, a)


if __name__ == "__main__":
    main()
