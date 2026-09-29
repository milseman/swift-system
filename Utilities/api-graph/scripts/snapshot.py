#!/usr/bin/env python3
"""Build the API graph's snapshot: typed nodes and links, one JSON document
per commit. The schema is in Prototype/ApiGraph/REPORT.md, section 1.

Node kinds: declaration (origin head, base or external), cname, internal,
block, test, sample, package. Link kinds: memberOf, nestedIn, extends,
conformsTo, usesInSignature, wraps, reaches, inBlock, testedBy, sampledBy,
stubFor, usedBy, calls. Derived kinds (sameCFamily, sameImplementation,
sameBlock, sameMark, couldUse) are computed by graphq.py, not stored.

The inputs are the pipeline's: build_graph.py's graph.json (declarations,
their edges, blocks, tests, samples and implementation), cnames.py's
cnames.json (the C names each declaration wraps, and their families),
adopters.py's adopters.json (the packages, their adopted and would-benefit
sites and hunks), and api-delta's symbol graphs (the base and external
types' kinds). Nothing here clusters, promotes or cuts: every link is kept.

With --store, the snapshot is also filed as <store>/<head commit>.json.gz,
listed in <store>/index.json, and compared with the store's previous
snapshot of the same head ref (graphq.py's diff), into --diff-out.

Usage: snapshot.py --graph graph.json --cnames cnames.json [--adopters adopters.json]
                   --delta-dir DIR --meta meta.json --out graph.json.gz
                   [--store DIR] [--previous SNAPSHOT] [--diff-out DIR]
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import datetime  # noqa: E402
import glob  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402

SCHEMA = "api-graph-snapshot/1"
# Protocols every type gets without spelling them, which link nothing.
MARKER_PROTOCOLS = {"SendableMetatype", "BitwiseCopyable", "Copyable", "Escapable"}
DECL_FIELDS = ("path", "title", "symbolKind", "isType", "module", "file", "line", "start", "end", "decl",
               "availability", "system", "platforms", "docSummary", "hasDoc", "source", "hiddenClass", "noncopyable",
               "nonescapable", "hasDeinit", "lifetime", "renamedTo", "parentPath", "deprecated")


def load(path):
    if path.endswith(".gz"):
        return json.load(gzip.open(path, "rt", encoding="utf-8"))
    return json.load(open(path, encoding="utf-8"))


def dump(doc, path):
    tmp = path + ".tmp"
    with (gzip.open(tmp, "wt", encoding="utf-8") if path.endswith(".gz") else open(tmp, "w", encoding="utf-8")) as f:
        json.dump(doc, f, separators=(",", ":"), sort_keys=True)
    os.replace(tmp, path)


def symbol_kinds(delta_dir):
    """USR -> (kind identifier, path) for every symbol of both sides' graphs."""
    out = {}
    for side in ("base", "head"):
        for f in sorted(glob.glob(os.path.join(delta_dir, "symbolgraphs", side, "*.symbols.json"))):
            for s in load(f)["symbols"]:
                out[s["identifier"]["precise"]] = (s["kind"]["identifier"], ".".join(s["pathComponents"]))
    return out


def block_ids(blocks):
    """Stable IDs for a file's blocks: file, subject and MARK, and the
    block's ordinal among the file's blocks with both."""
    out = {}
    for rel, bs in blocks.items():
        count = collections.Counter()
        for b in sorted(bs, key=lambda b: b["start"]):
            key = (b["subject"], b["mark"] or "")
            count[key] += 1
            out[(rel, b["id"])] = f"block:{rel}:{b['subject']}" + (f":{b['mark']}" if b["mark"] else "") + \
                f"#{count[key]}"
    return out


def build(a):
    g = load(a.graph)
    cn = load(a.cnames)
    ad = load(a.adopters) if a.adopters and os.path.exists(a.adopters) else None
    meta = load(a.meta)
    kinds = symbol_kinds(a.delta_dir) if a.delta_dir else {}
    gnodes, vocab = g["nodes"], g["vocabulary"]

    nodes, links = {}, []

    def link(kind, frm, to, **attrs):
        links.append(dict({"kind": kind, "from": frm, "to": to}, **attrs))

    # ------------------------------------------------------------ declarations
    # Base types named by path in scan-only edges ("path:FileDescriptor") get
    # their USR when a symbol graph has one.
    by_path = {}
    for usr, (k, path) in kinds.items():
        by_path.setdefault(path, usr)

    def norm(ref):
        if ref.startswith("path:"):
            return by_path.get(ref[5:], ref)
        return ref

    for nid, n in gnodes.items():
        rec = {"kind": "declaration", "origin": "head"}
        for k in DECL_FIELDS:
            if k == "symbolKind":
                rec[k] = n.get("kind")
            elif n.get(k) is not None:
                rec[k] = n[k]
        nodes[nid] = rec
    for vid, v in vocab.items():
        vid2 = norm(vid)
        if vid2 in nodes:
            continue
        origin = "base" if v["why"] in ("base", "platform-only") else "external"
        k, path = kinds.get(vid2, (None, v["path"]))
        nodes[vid2] = {"kind": "declaration", "origin": origin, "path": path or v["path"], "module": v["module"],
                       "symbolKind": k, "isType": True}

    def ensure_external(usr, name):
        if usr not in nodes:
            k, path = kinds.get(usr, (None, name))
            module = "Swift" if usr.startswith(("s:s", "s:S")) else "C" if usr.startswith("c:") else "other"
            nodes[usr] = {"kind": "declaration", "origin": "external", "path": path or name, "module": module,
                          "symbolKind": k, "isType": True}
        return usr

    # ------------------------------------------------------------ structure
    for e in g["edges"]:
        frm, to = e["from"], norm(e["to"])
        if to not in nodes:
            ensure_external(to, vocab.get(e["to"], {}).get("path", to))
        if e["kind"] == "memberOf":
            link("memberOf", frm, to)
        elif e["kind"] == "nestedIn":
            link("nestedIn", frm, to)
        elif e["kind"] == "references":
            link("usesInSignature", frm, to, roles=sorted(e.get("roles") or ["signature"]))
        elif e["kind"] == "conformsTo":
            pass   # from g["conformances"], below, which has every target
    seen_conf = set()
    for c in g.get("conformances", []):
        if c["name"] in MARKER_PROTOCOLS or (c["from"], c["to"]) in seen_conf:
            continue
        seen_conf.add((c["from"], c["to"]))
        ensure_external(c["to"], c["name"])
        link("conformsTo", c["from"], c["to"])
    # `extends`: a member added by an extension somewhere other than its
    # host's own file: of a base or external type, or of a new type from
    # another file. (An `extension T` beside T's declaration is how this
    # repository writes most members; it adds nothing a pitch needs to know.)
    host = {e["from"]: norm(e["to"]) for e in g["edges"] if e["kind"] in ("memberOf", "nestedIn")}
    for nid, n in gnodes.items():
        b = n.get("block")
        h = host.get(nid)
        if not (b and b["kind"] == "extension" and h):
            continue
        hn = nodes.get(h, {})
        if hn.get("origin") != "head" or hn.get("file") != n.get("file"):
            link("extends", nid, h)

    # ------------------------------------------------------------ blocks
    bids = block_ids(g.get("blocks", {}))
    for nid, n in gnodes.items():
        b = n.get("block")
        if not b:
            continue
        bid = bids.get((b["file"], b["index"]))
        if not bid:
            continue
        if bid not in nodes:
            nodes[bid] = {"kind": "block", "file": b["file"], "blockKind": b["kind"], "subject": b["subject"],
                          "mark": b["mark"], "start": b["start"], "end": b["end"], "line": b["line"]}
        link("inBlock", nid, bid)

    # ------------------------------------------------------------ C names
    for name, v in cn["names"].items():
        nodes["cname:" + name] = {"kind": "cname", "name": name, "cKinds": v["kinds"], "family": v["family"],
                                  "baseCovered": v["baseCovered"], "platforms": v["platforms"]}
    for w in cn["wraps"]:
        if w["node"] in nodes:
            link("wraps", w["node"], "cname:" + w["name"], role=w["role"], restricted=w["restricted"],
                 source=w["source"], joiner=w.get("joiner"), sentence=w["sentence"])

    # ------------------------------------------------------------ implementation
    for nid, n in gnodes.items():
        for p in n.get("implementation", []):
            iid = ("internal:c:" + p["name"]) if p["kind"].startswith("c-") else ("internal:" + (p.get("usr") or
                                                                                               p["name"]))
            if iid not in nodes:
                nodes[iid] = {"kind": "internal", "name": p["name"], "pieceKind": p["kind"], "file": p["file"],
                              "start": p["start"], "end": p["end"], "line": p["line"]}
            link("reaches", nid, iid)

    # ------------------------------------------------------------ tests, samples
    for tid, t in g["tests"].items():
        nodes["test:" + tid] = dict({"kind": "test"}, **{k: t[k] for k in ("file", "name", "scope", "framework",
                                                                            "mock", "target", "start", "end",
                                                                            "line", "platforms")})
    for sid, smp in g["samples"].items():
        nodes["sample:" + sid] = {"kind": "sample", "file": smp["file"], "commands": smp["commands"],
                                  "abstract": smp["abstract"], "unavailableStub": smp["unavailableStub"]}
    for nid, n in gnodes.items():
        for t in n.get("tests", []):
            link("testedBy", nid, "test:" + t, lexical=bool(n.get("lexicalTests")))
        for smp in n.get("samples", []):
            link("sampledBy", nid, "sample:" + smp, lexical=bool(n.get("lexicalSamples")))

    # ------------------------------------------------------------ fix-it stubs
    by_parent = collections.defaultdict(list)
    for nid, n in gnodes.items():
        if n["hiddenClass"] != "unavailable":
            by_parent[n.get("parentPath") or ""].append(nid)
    path_of = {n["path"]: nid for nid, n in gnodes.items() if n["hiddenClass"] != "unavailable"}
    for nid, n in gnodes.items():
        ren = n.get("renamedTo")
        if n["hiddenClass"] != "unavailable" or not ren:
            continue
        target = path_of.get(ren)
        if not target:
            base = re.sub(r"\(.*$", "", ren.split(".")[-1])
            cands = [x for x in by_parent.get(n.get("parentPath") or "", [])
                     if re.sub(r"\(.*$", "", gnodes[x]["title"]) == base]
            target = next((x for x in cands if gnodes[x]["title"] == ren.split(".")[-1]), cands[0] if cands else None)
            if not target and "." in ren:
                qual = re.sub(r"\(.*$", "", ren)
                target = next((x for p_, x in path_of.items() if re.sub(r"\(.*$", "", p_) == qual), None)
        if target:
            link("stubFor", nid, target)

    # ------------------------------------------------------------ adopters
    hunks = {}
    if ad:
        for p in ad["packages"]:
            nodes["package:" + p["key"]] = {"kind": "package", "key": p["key"], "name": p["name"],
                                            "remote": p["remote"], "adopted": p["adopted"], "benefit": p["benefit"],
                                            "adoptersClone": p.get("adoptersClone")}
        by_use = collections.defaultdict(list)
        for s in ad["adoptedSites"]:
            by_use[(s["node"], s["package"])].append({k: s[k] for k in ("file", "line", "column", "resolution", "how",
                                                                         "qualifier", "introduced", "hunk", "text")})
        for (nid, pkg), sites in sorted(by_use.items()):
            if nid in nodes:
                link("usedBy", nid, "package:" + pkg, sites=sites,
                     qualifierOnly=all(x["qualifier"] for x in sites))
        by_call = collections.defaultdict(list)
        for s in ad["benefitSites"]:
            for name in s.get("cnames") or []:
                by_call[(s["package"], name)].append({k: s.get(k) for k in ("file", "line", "interface", "resolution",
                                                                            "evidence", "target", "platforms",
                                                                            "onBranch")})
        for (pkg, name), sites in sorted(by_call.items()):
            if "cname:" + name in nodes:
                link("calls", "package:" + pkg, "cname:" + name, sites=sites)
        hunks = ad["hunks"]

    # ------------------------------------------------------------ reach
    reach_of(nodes, links)
    return {"schema": SCHEMA,
            "meta": dict(meta, snapshotDate=datetime.date.today().isoformat(),
                         adopterMeta=ad["meta"] if ad else None),
            "nodes": nodes, "links": links, "hunks": hunks}


def reach_of(nodes, links):
    """Each head declaration's reach: the packages using it on their
    migration branch (not only to qualify a nested type), and the packages
    calling a C name it wraps, unrestricted, that the base commit doesn't
    cover."""
    used = collections.defaultdict(set)
    callers = collections.defaultdict(set)
    wraps = collections.defaultdict(set)
    for ln in links:
        if ln["kind"] == "usedBy" and not ln.get("qualifierOnly"):
            used[ln["from"]].add(ln["to"][len("package:"):])
        elif ln["kind"] == "calls":
            callers[ln["to"]].add(ln["from"][len("package:"):])
        elif ln["kind"] == "wraps" and not ln["restricted"] and not nodes[ln["to"]]["baseCovered"]:
            wraps[ln["from"]].add(ln["to"])
    for nid, n in nodes.items():
        if n["kind"] == "declaration" and n["origin"] == "head":
            could = set()
            for c in wraps.get(nid, ()):
                could |= callers.get(c, set())
            n["reach"] = {"usedBy": sorted(used.get(nid, ())), "couldUse": sorted(could)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--cnames", required=True)
    ap.add_argument("--adopters")
    ap.add_argument("--delta-dir")
    ap.add_argument("--meta", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--store")
    ap.add_argument("--previous", help="a snapshot to diff with, instead of the store's previous one")
    ap.add_argument("--diff-out", help="a directory for DIFF.md and diff.json")
    a = ap.parse_args()
    doc = build(a)
    dump(doc, a.out)
    kinds = collections.Counter(n["kind"] if n["kind"] != "declaration" else "declaration/" + n["origin"]
                                for n in doc["nodes"].values())
    lk = collections.Counter(ln["kind"] for ln in doc["links"])
    print(f"snapshot: {len(doc['nodes'])} nodes ({', '.join(f'{v} {k}' for k, v in sorted(kinds.items()))}), "
          f"{len(doc['links'])} links ({', '.join(f'{v} {k}' for k, v in sorted(lk.items()))}) -> {a.out}")
    previous = a.previous
    if a.store:
        os.makedirs(a.store, exist_ok=True)
        idx_path = os.path.join(a.store, "index.json")
        index = load(idx_path) if os.path.exists(idx_path) else []
        head, ref = doc["meta"]["headCommit"], doc["meta"]["headRef"]
        if not previous:
            older = [x for x in index if x["headRef"] == ref and x["headCommit"] != head]
            if older:
                previous = os.path.join(a.store, older[-1]["file"])
        name = f"{head}.json.gz"
        shutil.copyfile(a.out, os.path.join(a.store, name))
        index = [x for x in index if x["headCommit"] != head] + [{
            "headCommit": head, "headRef": ref, "baseCommit": doc["meta"]["baseCommit"],
            "baseRef": doc["meta"]["baseRef"], "date": doc["meta"]["snapshotDate"], "file": name,
            "nodes": len(doc["nodes"]), "links": len(doc["links"])}]
        json.dump(index, open(idx_path, "w"), indent=1)
        print(f"snapshot: filed as {os.path.join(a.store, name)}")
    if a.diff_out:
        import graphq
        os.makedirs(a.diff_out, exist_ok=True)
        if previous and os.path.exists(previous):
            d = graphq.diff(load(previous), doc)
            json.dump(d, open(os.path.join(a.diff_out, "diff.json"), "w"), indent=1)
            open(os.path.join(a.diff_out, "DIFF.md"), "w").write(graphq.diff_md(d))
            print(f"snapshot: diff with {previous}: " + graphq.diff_summary(d))
        else:
            open(os.path.join(a.diff_out, "DIFF.md"), "w").write(
                "# Graph diff\n\nNo previous snapshot of this head ref to compare with.\n")


if __name__ == "__main__":
    main()
