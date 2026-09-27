#!/usr/bin/env python3
"""Build the graph of the declarations a head commit adds over a base.

Nodes are the added and changed declarations: every one in api-delta's
symbol-graph delta, plus the public declarations only the source scan sees
(API compiled only off Darwin, `unavailable` fix-it stubs, underscored
names). Edges, from a declaration to what it needs:

  memberOf    a member to the type it's declared in
  nestedIn    a nested type to its enclosing type (a memberOf that's a type)
  references  a declaration to a type its signature names: a parameter,
              result, property or aliased type, from the symbol graph's
              declaration fragments (by USR), or, for scan-only
              declarations, from the type names in their source text
  conformsTo  a type to a protocol

Targets that exist on the base commit (FileDescriptor, FilePath, Errno,
CInterop, ...), and those from other modules, are vocabulary: the edges are
kept, but they're not nodes.

Each node also belongs to an atom: the top-level block (a type declaration,
or one `extension X { ... }`) that holds it, which is what cluster.py
clusters. Members of namespace blocks (CInterop by default) are atoms of
their own, since one CInterop block holds the aliases of many features.

Last, it attaches what the index store says about each node: the tests and
samples that reference it, and the new internal declarations its body
reaches (`_foo`, `system_foo`, constants, CSystem shims), which a carve-out
has to bring along.

Usage: build_graph.py --delta-dir DIR --head-scan F --base-scan F
                      --source-index F --refs F --diff F --root DIR
                      [--namespaces CInterop,...] --out graph.json
"""

import argparse
import bisect
import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "api-delta", "scripts"))
from report import parse_diff  # noqa: E402  (api-delta's diff parser, reused)
import scan_sources as ss  # noqa: E402  (and its lexer)

TYPE_KINDS = {"swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.actor", "swift.typealias"}
SCAN_TYPE_KWS = {"struct", "enum", "class", "protocol", "actor", "typealias"}
SCAN_KIND = {"struct": "swift.struct", "enum": "swift.enum", "class": "swift.class", "protocol": "swift.protocol",
             "actor": "swift.actor", "typealias": "swift.typealias", "func": "swift.method", "init": "swift.init",
             "init?": "swift.init", "init!": "swift.init", "var": "swift.property", "let": "swift.property",
             "subscript": "swift.subscript", "case": "swift.enum.case", "macro": "swift.macro"}
# "The corresponding C function is `fsync`." and its variants.
C_NAME_RE = re.compile(r"[Tt]he corresponding C (?:[a-z]+ )?(function|functions|constant|constants|type|types|"
                       r"macro|macros|call|calls|struct|structure|field|fields|value|values|option|options|"
                       r"command|commands|flag|flags|request|requests)[^`]*((?:`[^`]+`[^`.]*)+)")
TOKEN_RE = re.compile(r"\b[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*")


def load(path):
    return json.load(open(path))


def c_names(doc):
    out = []
    for m in C_NAME_RE.finditer(doc or ""):
        for name in re.findall(r"`([^`]+)`", m.group(2)):
            name = name.strip()
            if re.match(r"^[A-Za-z_][\w]*(\(\))?$", name) and name not in out:
                out.append(name.rstrip("()"))
    return out


class Graphs:
    """Every symbol of one side's symbol graphs, with resolved parents."""

    def __init__(self, directory):
        self.symbols, self.parent, self.conforms = {}, {}, collections.defaultdict(set)
        ext_to = {}
        rels = []
        for path in sorted(glob.glob(os.path.join(directory, "*.symbols.json"))):
            g = load(path)
            for s in g["symbols"]:
                self.symbols[s["identifier"]["precise"]] = s
            rels += g["relationships"]
        for r in rels:
            if r["kind"] == "extensionTo":
                ext_to[r["source"]] = r["target"]
        for r in rels:
            src, tgt = r["source"], r["target"]
            tgt = ext_to.get(tgt, tgt)
            if r["kind"] == "memberOf":
                self.parent[src] = tgt
            elif r["kind"] == "conformsTo":
                self.conforms[ext_to.get(src, src)].add((tgt, r.get("targetFallback") or tgt))

    def path(self, usr):
        s = self.symbols.get(usr)
        return ".".join(s["pathComponents"]) if s else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--delta-dir", required=True)
    ap.add_argument("--head-scan", required=True)
    ap.add_argument("--base-scan", required=True)
    ap.add_argument("--source-index", required=True)
    ap.add_argument("--refs", required=True)
    ap.add_argument("--diff", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--namespaces", default="CInterop")
    ap.add_argument("--lexical-samples", action="store_true",
                    help="match samples by name: Samples wasn't built, so the index doesn't have them")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    delta = load(os.path.join(a.delta_dir, "api-delta.json"))
    head = Graphs(os.path.join(a.delta_dir, "symbolgraphs", "head"))
    base = Graphs(os.path.join(a.delta_dir, "symbolgraphs", "base"))
    head_scan, base_scan = load(a.head_scan), load(a.base_scan)
    sindex = load(a.source_index)["files"]
    refs = load(a.refs)
    added_lines, _ = parse_diff(a.diff)
    namespaces = set(x for x in a.namespaces.split(",") if x)

    # ------------------------------------------------------------ vocabulary
    # Every declaration on the base commit, in the graphs (macOS) or in the
    # scan (any platform), plus anything from another module.
    base_usrs = set(base.symbols)
    base_paths = {(".".join(s["pathComponents"])) for s in base.symbols.values()}
    base_paths |= {t["name"] for t in base_scan["types"]}
    vocabulary = {}

    def vocab(target_usr, spelling):
        if target_usr in vocabulary:
            return target_usr
        s = head.symbols.get(target_usr)
        if s:
            path = ".".join(s["pathComponents"])
            module = "SystemSockets" if target_usr.startswith("s:13SystemSockets") else "SystemPackage"
            vocabulary[target_usr] = {"id": target_usr, "path": path, "module": module, "why": "base"}
        else:
            # The standard library's USRs start s:s or, abbreviated, s:S.
            module = ("Swift" if target_usr.startswith(("s:s", "s:S")) else
                      "C" if target_usr.startswith("c:") else "other")
            vocabulary[target_usr] = {"id": target_usr, "path": spelling, "module": module, "why": "external"}
        return target_usr

    # ------------------------------------------------------------ source lookup
    decl_lines = {}   # file -> sorted keyword lines, and the decls
    for rel, info in sindex.items():
        ds = info.get("decls") or []
        decl_lines[rel] = (sorted((d["line"], i) for i, d in enumerate(ds)), ds)

    def decl_at(rel, line):
        """The source_index declaration whose keyword is on `line`, or the
        innermost one whose extent holds it."""
        if rel not in decl_lines:
            return None
        order, ds = decl_lines[rel]
        k = bisect.bisect_left(order, (line, -1))
        if k < len(order) and order[k][0] == line:
            return ds[order[k][1]]
        best = None
        for d in ds:
            if d["start"] <= line <= d["end"] and (best is None or d["start"] >= best["start"]):
                best = d
        return best

    def innermost(rel, line, pred):
        _, ds = decl_lines.get(rel, ([], []))
        best = None
        for d in ds:
            if d["start"] <= line <= d["end"] and pred(d) and (best is None or d["start"] >= best["start"]):
                best = d
        return best

    def doc_text_from_source(rel, d):
        path = os.path.join(a.root, rel)
        if not d or not os.path.exists(path):
            return ""
        lines = open(path, encoding="utf-8").read().split("\n")[d["start"] - 1:d["line"] - 1]
        return "\n".join(re.sub(r"^\s*///\s?", "", l) for l in lines if l.strip().startswith("///"))

    # ------------------------------------------------------------ nodes
    nodes = {}
    for e in delta["entries"]:
        if e["status"] not in ("added", "changed"):
            continue
        usr = e["usr"]
        s = head.symbols.get(usr, {})
        d = decl_at(e["file"], e["line"]) if e["file"] else None
        nodes[usr] = {
            "id": usr, "usr": usr, "source": "graph", "status": e["status"], "hiddenClass": None,
            "module": e["module"], "path": e["path"], "title": e["title"], "kind": e["kind"],
            "isType": e["kind"] in TYPE_KINDS, "decl": e["decl"],
            "availability": e["availability"], "system": e["system"], "explicitOS": e["explicitOS"],
            "deprecated": e["deprecated"],
            "platforms": e.get("platforms") or (d["platforms"] if d else None),
            "hasDoc": bool(e["hasDoc"] or e.get("inheritsDocFrom")), "ownDoc": bool(e["hasDoc"]),
            "docSummary": e["docSummary"], "cNames": c_names(e.get("docText")),
            "file": e["file"], "line": e["line"],
            "start": d["start"] if d else e["line"], "end": d["end"] if d else e["line"],
            "conformances": sorted({fb.replace("Swift.", "") for _, fb in head.conforms.get(usr, ())}),
            "changes": e.get("changes") or [],
            "parentPath": ".".join(s.get("pathComponents", [])[:-1]) or None,
        }

    # Scan-only declarations, merged across per-platform duplicates, and into
    # the graph's declaration when one platform's variant of it is compiled
    # here (a CInterop alias spelled per C library, say).
    graph_by_path = {(n["module"], n["path"]): nid for nid, n in nodes.items()}
    for x in delta["hiddenFromGraphs"]["added"]:
        path = ".".join(x["scopes"] + [x["name"]])
        nid = graph_by_path.get((x["module"], path), f"scan:{x['module']}:{path}")
        d = decl_at(x["file"], x["line"])
        doc = doc_text_from_source(x["file"], d)
        if nid in nodes:
            n = nodes[nid]
            n["platforms"] = sorted(set(n["platforms"] or []) | set(x["platforms"]),
                                    key=lambda p: list(head_scan["platforms"]).index(p) if p in head_scan["platforms"] else 99)
            n.setdefault("sites", [[n["file"], n["line"]]]).append([x["file"], x["line"]])
            n["variants"] = n.get("variants", 1) + 1
            continue
        kind = SCAN_KIND.get(x["kw"], "swift." + x["kw"])
        if x["kw"] == "func" and not x["scopes"]:
            kind = "swift.func"
        if x["kw"] in ("var", "let", "func") and "static" in x["modifiers"]:
            kind = {"swift.method": "swift.type.method", "swift.property": "swift.type.property"}.get(kind, kind)
        ren = re.search(r'renamed:\s*"([^"]*)"', " ".join(x["unavailable"]))
        avail_text = x["availability"] + x["scopeAvailability"]
        sysm = None
        for av in avail_text:
            mm = re.search(r"System\s+([\d.]+)", av)
            if mm:
                sysm = mm.group(1)
        nodes[nid] = {
            "id": nid, "usr": None, "source": "scan", "status": "added", "hiddenClass": x["hiddenClass"],
            "module": x["module"], "path": path, "title": x["name"], "kind": kind,
            "isType": x["kw"] in SCAN_TYPE_KWS, "decl": re.sub(r"\s+", " ", x["signature"]).strip(),
            "availability": ", ".join(dict.fromkeys(v.replace("@available(", "").rstrip(")") for v in avail_text)) or "none",
            "system": sysm, "explicitOS": {}, "deprecated": x["deprecated"] or None,
            "platforms": x["platforms"], "hasDoc": x["hasDoc"], "ownDoc": x["hasDoc"],
            "docSummary": next((l.strip() for l in doc.split("\n") if l.strip()), ""), "cNames": c_names(doc),
            "file": x["file"], "line": x["line"],
            "start": d["start"] if d else x["line"], "end": d["end"] if d else x["line"],
            "conformances": [], "changes": [],
            "parentPath": ".".join(x["scopes"]) or None,
            "renamedTo": ren.group(1) if ren else None,
            "sites": [[x["file"], x["line"]]], "variants": 1,
        }

    # ------------------------------------------------------------ source facts
    # Symbol graphs print neither `~Copyable` nor a deinit, so read them, and
    # lifetime attributes, from the source.
    code_cache = {}

    def code_lines(rel):
        if rel not in code_cache:
            path = os.path.join(a.root, rel)
            raw = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
            code_cache[rel] = ss.strip_comments_and_strings(raw)[0].split("\n")
        return code_cache[rel]

    for n in nodes.values():
        d = decl_at(n["file"], n["line"]) if n["file"] else None
        inherits = " ".join((d or {}).get("inherits") or [])
        attrs = " ".join((d or {}).get("attributes") or [])
        n["noncopyable"] = bool(n["isType"] and ("~Copyable" in inherits or "~Copyable" in n["decl"]))
        n["nonescapable"] = bool("~Escapable" in inherits or "~Escapable" in n["decl"])
        n["lifetime"] = bool(re.search(r"@_?lifetime\b", attrs))
        n["hasDeinit"] = False
        if n["isType"] and d and n["kind"] != "swift.typealias":
            body = code_lines(n["file"])[d["line"]:d["end"]]
            # Only the type's own body: its nested types' deinits don't count.
            depth, found = 0, False
            for ln in body:
                if depth == 1 and re.match(r"\s*(?:@\w+\s+)*deinit\b", ln):
                    found = True
                    break
                depth += ln.count("{") - ln.count("}")
            n["hasDeinit"] = found

    # ------------------------------------------------------------ types by path
    # For resolving the source text of scan-only declarations.
    type_by_path = {}
    for usr, s in head.symbols.items():
        if s["kind"]["identifier"] in TYPE_KINDS:
            type_by_path.setdefault(".".join(s["pathComponents"]), usr)
    for nid, n in nodes.items():
        if n["isType"]:
            type_by_path.setdefault(n["path"], nid)
    scan_types = {t["name"] for t in head_scan["types"]}

    def resolve_path(name, scopes):
        for k in range(len(scopes), -1, -1):
            cand = ".".join(scopes[:k] + [name])
            if cand in type_by_path:
                return type_by_path[cand]
            if cand in scan_types or cand in base_paths:
                return "path:" + cand
        return None

    # ------------------------------------------------------------ edges
    edges = []
    seen_edges = set()

    def edge(src, dst, kind, spelling=None):
        if src == dst or (src, dst, kind) in seen_edges:
            return
        seen_edges.add((src, dst, kind))
        if dst not in nodes:
            if dst.startswith("path:"):
                if dst not in vocabulary:
                    vocabulary[dst] = {"id": dst, "path": dst[5:], "module": "SystemPackage",
                                       "why": "base" if dst[5:] in base_paths else "platform-only"}
            else:
                vocab(dst, spelling or dst)
        edges.append({"from": src, "to": dst, "kind": kind})

    for nid, n in nodes.items():
        if n["source"] == "graph":
            s = head.symbols.get(nid, {})
            par = head.parent.get(nid)
            if par:
                edge(nid, par, "nestedIn" if n["isType"] else "memberOf", head.path(par))
            # A qualified name, `PThread.Mutex.Kind`, comes as one type
            # identifier per component, separated by `.`. Only the whole name
            # is a reference; its qualifiers are namespaces, which the named
            # type's own nesting records. A member typealias named through
            # its parent (`CInterop.Termios`) has no USR on its last
            # component, so the qualified name is looked up.
            frags = s.get("declarationFragments", [])
            chain, k = [], 0
            while k < len(frags):
                fr = frags[k]
                if fr.get("kind") == "typeIdentifier":
                    chain.append((fr["spelling"], fr.get("preciseIdentifier")))
                    if k + 2 < len(frags) and frags[k + 1].get("spelling") == "." \
                            and frags[k + 2].get("kind") == "typeIdentifier":
                        k += 2
                        continue
                    qualified = ".".join(sp for sp, _ in chain)
                    t = chain[-1][1] or type_by_path.get(qualified)
                    if t and t != nid:
                        edge(nid, t, "references", qualified)
                    chain = []
                k += 1
            for tgt, fb in head.conforms.get(nid, ()):
                if tgt in nodes:
                    edge(nid, tgt, "conformsTo", fb)
        else:
            scopes = n["parentPath"].split(".") if n["parentPath"] else []
            if scopes:
                par = resolve_path(scopes[-1], scopes[:-1])
                if par:
                    edge(nid, par, "nestedIn" if n["isType"] else "memberOf", n["parentPath"])
            text = re.sub(r"@\w+(\([^)]*\))?", " ", n["decl"])
            text = re.sub(r'"[^"]*"', " ", text)
            own = n["path"].split(".")[-1]
            for tok in dict.fromkeys(TOKEN_RE.findall(text)):
                if tok in (own, "Self") or tok.split(".")[0] in ("Swift",):
                    continue
                tgt = resolve_path(tok, scopes if not n["isType"] else scopes + [own])
                if tgt and tgt != nid:
                    edge(nid, tgt, "references", tok)

    # ------------------------------------------------------------ atoms
    atoms = {}
    node_atom = {}
    for nid, n in nodes.items():
        rel = n["file"]
        d = decl_at(rel, n["line"]) if rel else None
        info = sindex.get(rel) if rel else None
        if not d or not info:
            continue
        blk = info["blocks"][d["block"]] if d["block"] is not None else None
        if blk is None:
            continue
        if blk["subject"] in namespaces and blk["kind"] == "extension":
            key = "loose:" + nid
            atoms[key] = {"id": key, "loose": True, "file": rel, "kind": "member", "subject": blk["subject"],
                          "mark": None, "start": n["start"], "end": n["end"], "line": n["line"],
                          "platforms": n["platforms"], "conditions": d["conditions"],
                          "availability": blk["availability"], "nodes": []}
        else:
            key = f"{rel}#{blk['id']}"
            if key not in atoms:
                atoms[key] = {"id": key, "loose": False, "file": rel, "kind": blk["kind"],
                              "subject": blk["subject"], "mark": blk["mark"], "start": blk["start"],
                              "end": blk["end"], "line": blk["line"], "platforms": blk["platforms"],
                              "conditions": blk["conditions"], "availability": blk["availability"],
                              "nodes": []}
        atoms[key]["nodes"].append(nid)
        node_atom[nid] = key
        n["atom"] = key
    # Nodes with no location (synthesized members) join their parent's atom.
    for nid, n in nodes.items():
        if nid in node_atom:
            continue
        par = next((e["to"] for e in edges if e["from"] == nid and e["kind"] in ("memberOf", "nestedIn")), None)
        if par in node_atom:
            node_atom[nid] = node_atom[par]
            n["atom"] = node_atom[par]
            atoms[node_atom[par]]["nodes"].append(nid)
        else:
            key = "loose:" + nid
            atoms[key] = {"id": key, "loose": True, "file": n["file"], "kind": "member", "subject": n["parentPath"],
                          "mark": None, "start": n["start"], "end": n["end"], "line": n["line"],
                          "platforms": n["platforms"], "conditions": [], "availability": [], "nodes": [nid]}
            node_atom[nid] = key
            n["atom"] = key

    # ------------------------------------------------------------ tests and samples
    tests = {}   # test id -> record

    def test_record(rel, d):
        info = sindex[rel]
        scope = ".".join(d["scopes"])
        tid = f"{rel}::{scope + '.' if scope else ''}{d['name']}"
        if tid not in tests:
            parent = info["decls"][d["parent"]] if d["parent"] is not None else None
            framework = "swift-testing" if any(x.startswith("@Test") for x in d["attributes"]) else "XCTest"
            tests[tid] = {"id": tid, "file": rel, "name": d["name"], "scope": scope, "line": d["line"],
                          "start": d["start"], "end": d["end"], "framework": framework,
                          "target": info["module"], "conditions": d["conditions"],
                          "platforms": d["platforms"], "suite": parent["name"] if parent else None,
                          "mock": False}
        return tests[tid]

    samples = {}

    def sample_record(rel):
        if rel not in samples:
            path = os.path.join(a.root, rel)
            text = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
            names = list(dict.fromkeys(re.findall(r'commandName:\s*"([^"]+)"', text)))
            if not names:
                # ArgumentParser's default: the type's name in kebab case.
                names = [re.sub(r"(?<!^)(?=[A-Z])", "-", t).lower()
                         for t in re.findall(r"struct\s+(\w+)\s*:\s*(?:Async)?ParsableCommand", text)]
            abstract = re.findall(r'abstract:\s*"((?:[^"\\]|\\.)*)"', text)
            samples[rel] = {"file": rel, "commands": names, "abstract": abstract[0] if abstract else "",
                            "unavailableStub": bool(abstract and abstract[0].startswith("Unavailable:"))}
        return samples[rel]

    usr_node = {n["usr"]: nid for nid, n in nodes.items() if n["usr"]}
    helpers = collections.defaultdict(set)
    for rel, f in refs["files"].items():
        is_test = rel.startswith("Tests/")
        is_sample = rel.startswith("Sources/Samples/")
        if not (is_test or is_sample) or rel not in sindex:
            continue
        for line, _col, usr, _flags in f["references"]:
            nid = usr_node.get(usr)
            if not nid:
                continue
            n = nodes[nid]
            if is_sample:
                sample_record(rel)
                n.setdefault("samples", set()).add(rel)
                continue
            d = innermost(rel, line, lambda x: x.get("isTest"))
            if d:
                t = test_record(rel, d)
                n.setdefault("tests", set()).add(t["id"])
            else:
                helpers[nid].add(rel)
    # Mock tests: those whose body builds a MockTestCase or drives the mock.
    for tid, t in tests.items():
        path = os.path.join(a.root, t["file"])
        body = open(path, encoding="utf-8").read().split("\n")[t["start"] - 1:t["end"]]
        t["mock"] = bool(re.search(r"MockTestCase|withMockingEnabled|mockingEnabled", "\n".join(body)))

    # Scan-only declarations aren't compiled here, so neither are their tests:
    # match their names in the test and sample sources instead.
    lexical_files = {}
    for rel, info in sindex.items():
        if (rel.startswith("Tests/") or rel.startswith("Sources/Samples/")) and rel.endswith(".swift"):
            lexical_files[rel] = open(os.path.join(a.root, rel), encoding="utf-8").read().split("\n")
    for nid, n in nodes.items():
        if n["hiddenClass"] == "unavailable":
            continue
        # Graph nodes too when Samples couldn't be built and indexed.
        want_tests = n["source"] == "scan"
        want_samples = want_tests or a.lexical_samples
        if not want_samples:
            continue
        own = n["path"].split(".")[-1]
        simple = re.sub(r"\(.*$", "", own)
        parent_simple = n["parentPath"].split(".")[-1] if n["parentPath"] else None
        if n["isType"]:
            pat = re.compile(rf"\b{re.escape(simple)}\b")
            need = None
        elif simple in ("init",) or len(simple) < 4:
            continue
        else:
            pat = re.compile(rf"\.{re.escape(simple)}\b")
            need = re.compile(rf"\b{re.escape(parent_simple)}\b") if parent_simple else None
        for rel, lines in lexical_files.items():
            info = sindex[rel]
            if not want_tests and not rel.startswith("Sources/Samples/"):
                continue
            if rel.startswith("Sources/Samples/"):
                text = "\n".join(lines)
                if pat.search(text) and (need is None or need.search(text)):
                    sample_record(rel)
                    n.setdefault("samples", set()).add(rel)
                    n.setdefault("lexicalSamples", True)
                continue
            for d in info["decls"]:
                if not d.get("isTest"):
                    continue
                body = "\n".join(lines[d["start"] - 1:d["end"]])
                if pat.search(body) and (need is None or need.search(body)):
                    t = test_record(rel, d)
                    n.setdefault("tests", set()).add(t["id"])
                    n["lexicalTests"] = True

    # ------------------------------------------------------------ implementation
    # The new internal declarations each public node's body reaches.
    defs = refs["definitions"]
    syms = refs["symbols"]
    public_usrs = set(usr_node)
    refs_by_file = {}
    for rel, f in refs["files"].items():
        refs_by_file[rel] = sorted(f["references"])

    def refs_in(rel, start, end, uses=False):
        """USRs referenced in lines start...end of rel. With uses, leave out
        a type named only to qualify a nested one (the `PThread` of
        `PThread.Mutex`), which the index records as a reference too."""
        rs = refs_by_file.get(rel, [])
        k = bisect.bisect_left(rs, [start, -1, "", 0])
        out = []
        lines = code_lines(rel) if uses else None
        while k < len(rs) and rs[k][0] <= end:
            line, col, usr = rs[k][0], rs[k][1], rs[k][2]
            k += 1
            if uses and line - 1 < len(lines):
                name = re.sub(r"\(.*$", "", syms.get(usr, {}).get("name", ""))
                text = lines[line - 1]
                after = text[col - 1 + len(name):col + len(name) + 1] if text[col - 1:col - 1 + len(name)] == name else ""
                if re.match(r"\.[A-Z]", after):
                    continue
            out.append(usr)
        return out

    def is_new(rel, line):
        return line in added_lines.get(rel, ())

    cdecl_index = {}
    for rel, info in sindex.items():
        for c in info.get("cdecls", []):
            cdecl_index.setdefault(c["name"], []).append((rel, c))

    piece_cache = {}

    def piece_for(usr):
        """The new internal declaration (or C shim) a USR names, if any."""
        if usr in piece_cache:
            return piece_cache[usr]
        out = None
        name = syms.get(usr, {}).get("name", "")
        if re.match(r"^(getter|setter|_read|_modify|read|modify|willSet|didSet|init|unsafeAddress|"
                    r"unsafeMutableAddress):", name):
            # An accessor: the index also records its property.
            piece_cache[usr] = None
            return None
        if usr.startswith("c:"):
            simple = re.sub(r"\(.*$", "", name)
            for rel, c in cdecl_index.get(simple, []):
                if any(is_new(rel, ln) for ln in range(c["line"], c["end"] + 1)):
                    out = {"usr": usr, "name": simple, "file": rel, "start": c["start"], "end": c["end"],
                           "line": c["line"], "kind": "c-" + c["kind"]}
                    break
        elif usr not in public_usrs:
            for rel, line, _col in defs.get(usr, []):
                if not rel.startswith("Sources/") or rel.startswith("Sources/Samples/"):
                    continue
                d = decl_at(rel, line)
                if d and d["line"] == line and is_new(rel, line):
                    out = {"usr": usr, "name": name, "file": rel, "start": d["start"], "end": d["end"],
                           "line": d["line"], "kind": d["kw"]}
                    break
        piece_cache[usr] = out
        return out

    c_calls = collections.defaultdict(set)
    for nid, n in nodes.items():
        if n["source"] != "graph" or not n["file"]:
            continue
        seen, stack, pieces = set(), [(n["file"], n["start"], n["end"])], []
        while stack:
            rel, start, end = stack.pop()
            for usr in refs_in(rel, start, end):
                if usr in seen:
                    continue
                seen.add(usr)
                if usr.startswith("c:"):
                    nm = re.sub(r"\(.*$", "", syms.get(usr, {}).get("name", ""))
                    if nm and not nm.startswith("_") and "@F@" in usr:
                        c_calls[nid].add(nm)
                p = piece_for(usr)
                if p:
                    pieces.append(p)
                    if not p["kind"].startswith("c-"):
                        stack.append((p["file"], p["start"], p["end"]))
        n["implementation"] = sorted(pieces, key=lambda p: (p["file"], p["start"]))
        n["cCalls"] = sorted(c_calls[nid])
        # Other new public API its implementation uses, such as a CInterop
        # alias no signature names.
        used = set(refs_in(n["file"], n["start"], n["end"], uses=True))
        for p in pieces:
            if not p["kind"].startswith("c-"):
                used |= set(refs_in(p["file"], p["start"], p["end"], uses=True))
        n["implUses"] = sorted({usr_node[u] for u in used if u in usr_node and usr_node[u] != nid})

    for n in nodes.values():
        n["tests"] = sorted(n.get("tests", ()))
        n["samples"] = sorted(n.get("samples", ()))
        n["helperFiles"] = sorted(helpers.get(n["id"], ()))
        n.setdefault("implementation", [])
        n.setdefault("cCalls", [])
        n.setdefault("implUses", [])

    json.dump({
        "nodes": nodes, "edges": edges, "atoms": atoms, "vocabulary": vocabulary,
        "tests": tests, "samples": samples,
        "meta": {"namespaces": sorted(namespaces), "basePaths": len(base_paths), "baseSymbols": len(base_usrs)},
    }, open(a.out, "w"), indent=0)
    kinds = collections.Counter(e["kind"] for e in edges)
    print(f"build_graph: {len(nodes)} nodes ({sum(1 for n in nodes.values() if n['source'] == 'scan')} from the "
          f"scan), {len(edges)} edges {dict(kinds)}, {len(atoms)} atoms, {len(vocabulary)} vocabulary targets, "
          f"{len(tests)} tests, {len(samples)} samples -> {a.out}")


if __name__ == "__main__":
    main()
