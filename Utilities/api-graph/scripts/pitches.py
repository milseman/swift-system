#!/usr/bin/env python3
"""Resolve and check the hand-curated pitch files against a graph snapshot.

A pitch file (Prototype/Pitches/<id>.json; the format is in
Prototype/ApiGraph/REPORT.md, section 2) names a set of the graph's new
declarations by rules. This tool never writes pitch files: it resolves
them, checks them together, and reports:

  - each pitch's declarations, and the rules that matched nothing or named
    what the graph doesn't have;
  - declarations no pitch covers yet, and declarations two pitches cover;
  - prerequisites: a pitch whose declarations name (in a signature, as a
    host, an enclosing type, an extended type or a protocol) a type
    another pitch owns needs that pitch; one that names a new type no pitch
    owns needs one; cycles;
  - whether each pitch fits its pattern;
  - what changed since the previous snapshot: declarations a pitch's rules
    match now and didn't, ones they no longer match, and changed
    declarations it includes.

Usage: pitches.py --snapshot graph.json.gz --pitches DIR --out DIR
                  [--previous SNAPSHOT]
       pitches.py --snapshot graph.json.gz --pitches DIR --show ID
Writes PITCHES.md and pitches.json into --out.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import graphq  # noqa: E402

PATTERNS = {
    "types-without-members": "a family of types, without their members",
    "members-of-pitched-type": "the members of a type another pitch owns",
    "self-contained-type": "a type with its members and nested types",
    "function-family": "the wrappers of one C function family, on existing types",
    "vocabulary-type": "a type many pitches name, with the members they need",
    "constants": "new constants, options or cases on an existing type",
}
STATUSES = ("draft", "ready", "pitched", "accepted")
RULE_KEYS = {"ids", "paths", "types", "membersOf", "cFamily", "cNames", "match"}
RULE_OPTIONS = {"members", "nested", "file", "mark", "except", "note"}
# The links through which a pitch's declarations need a type.
NEEDS = ("usesInSignature", "memberOf", "nestedIn", "extends", "conformsTo")


class Resolver:
    def __init__(self, doc):
        self.g = graphq.Graph(doc)
        self.nodes = doc["nodes"]
        self.head = {nid for nid, n in self.nodes.items() if n["kind"] == "declaration" and n["origin"] == "head"}
        self.stub_target = {ln["from"]: ln["to"] for ln in doc["links"] if ln["kind"] == "stubFor"}
        self.mark_of = {}
        for ln in doc["links"]:
            if ln["kind"] == "inBlock":
                self.mark_of[ln["from"]] = self.nodes[ln["to"]].get("mark")

    def decl(self, text, types_only=False):
        """A declaration by ID or path: (id, problem)."""
        if text in self.nodes and self.nodes[text]["kind"] == "declaration":
            return text, None
        cands = [x for x in self.g.by_path.get(text, []) if self.nodes[x]["kind"] == "declaration"
                 and (not types_only or self.nodes[x].get("isType"))]
        head = [x for x in cands if x in self.head]
        if len(cands) == 1:
            return cands[0], None
        if len(head) == 1:
            return head[0], None
        if not cands:
            return None, f"`{text}` isn't a declaration in the graph"
        return None, f"`{text}` names {len(cands)} declarations; use `ids`"

    def members(self, tid, nested):
        """The type's members; with nested, its nested types' members too
        (not the nested types themselves)."""
        out = set()
        for ln in self.g.inc[tid]:
            if ln["kind"] == "memberOf":
                out.add(ln["from"])
            elif ln["kind"] == "nestedIn" and nested:
                out |= self.members(ln["from"], nested)
        return out

    def nested_types(self, tid):
        out = set()
        for ln in self.g.inc[tid]:
            if ln["kind"] == "nestedIn":
                out.add(ln["from"])
                out |= self.nested_types(ln["from"])
        return out

    def rule(self, r):
        """(declarations, problems) for one rule."""
        keys = RULE_KEYS & set(r)
        problems = [f"unknown rule field `{k}`" for k in set(r) - RULE_KEYS - RULE_OPTIONS]
        if len(keys) != 1:
            return set(), problems + [f"a rule needs exactly one of {', '.join(sorted(RULE_KEYS))}: {json.dumps(r)}"]
        (key,) = keys
        val = r[key]
        out = set()
        if key == "ids":
            for x in val:
                if x in self.nodes and self.nodes[x]["kind"] == "declaration":
                    out.add(x)
                else:
                    problems.append(f"`{x}` isn't a declaration's ID")
        elif key == "paths":
            for x in val:
                d, p = self.decl(x)
                out.add(d) if d else problems.append(p)
        elif key == "types":
            for x in val:
                d, p = self.decl(x, types_only=True)
                if not d:
                    problems.append(p)
                    continue
                out.add(d)
                if r.get("nested"):
                    out |= self.nested_types(d)
                if r.get("members"):
                    out |= self.members(d, bool(r.get("nested")))
        elif key == "membersOf":
            d, p = self.decl(val, types_only=True)
            if not d:
                problems.append(p)
            else:
                out |= self.members(d, bool(r.get("nested")))
        elif key == "cFamily":
            fams = [val] if isinstance(val, str) else val
            for fam in fams:
                cids = [cid for cid, n in self.nodes.items() if n["kind"] == "cname" and n.get("family") == fam]
                if not cids:
                    c = self.nodes.get("cname:" + fam)
                    if c and c.get("family"):
                        problems.append(f"`{fam}` is in the `{c['family']}` family; name that")
                    else:
                        problems.append(f"no C function family `{fam}`")
                for cid in cids:
                    for ln in self.g.inc[cid]:
                        if ln["kind"] == "wraps" and ln["role"] in ("subject", "alternative"):
                            out.add(ln["from"])
        elif key == "cNames":
            for nm in val:
                cid = "cname:" + nm
                if cid not in self.nodes:
                    problems.append(f"no declaration wraps `{nm}`")
                    continue
                for ln in self.g.inc[cid]:
                    if ln["kind"] == "wraps":
                        out.add(ln["from"])
        elif key == "match":
            try:
                pat = re.compile(val)
            except re.error as e:
                return set(), problems + [f"bad regular expression {val!r}: {e}"]
            out = {x for x in self.head if pat.search(self.nodes[x].get("path") or "")}
        # Only new declarations are a pitch's; base and external ones only
        # lead to their new members.
        out = {x for x in out if x in self.head}
        if r.get("file"):
            out = {x for x in out if (self.nodes[x].get("file") or "").startswith(r["file"])}
        if r.get("mark"):
            out = {x for x in out if self.mark_of.get(x) == r["mark"]}
        if r.get("except"):
            ex = set()
            for x in r["except"]:
                d, _ = self.decl(x)
                if d:
                    ex.add(d)
            out -= ex
        return out, problems

    def pitch(self, p):
        """(declarations, per-rule report, problems)"""
        problems, rules = [], []
        inc, exc = set(), set()
        for which, dest in (("include", inc), ("exclude", exc)):
            for r in p.get(which) or []:
                got, probs = self.rule(r)
                rules.append({"part": which, "rule": r, "matches": len(got), "problems": probs})
                problems += [f"{which} {json.dumps(r)}: {x}" for x in probs]
                if not got and not probs:
                    problems.append(f"{which} {json.dumps(r)} matches nothing")
                dest |= got
        out = inc - exc
        # Fix-it stubs go with what they rename.
        for s_, t in self.stub_target.items():
            if t in out and s_ not in exc:
                out.add(s_)
        return out, rules, problems


def load_pitches(directory):
    out, problems = [], []
    if not os.path.isdir(directory):
        return out, [f"no pitch directory {directory}"]
    for f in sorted(os.listdir(directory)):
        if not f.endswith(".json"):
            continue
        path = os.path.join(directory, f)
        try:
            p = json.load(open(path, encoding="utf-8"))
        except ValueError as e:
            problems.append(f"{f}: not JSON: {e}")
            continue
        p["_file"] = os.path.relpath(path)
        pid = p.get("id")
        if pid != f[:-5]:
            problems.append(f"{f}: `id` is {pid!r}, and should be the file's name, {f[:-5]!r}")
            p["id"] = f[:-5]
        for k in ("title", "pattern", "include"):
            if k not in p:
                problems.append(f"{f}: no `{k}`")
        if p.get("pattern") and p["pattern"] not in PATTERNS:
            problems.append(f"{f}: unknown pattern {p['pattern']!r} (known: {', '.join(PATTERNS)})")
        if p.get("status", "draft") not in STATUSES:
            problems.append(f"{f}: unknown status {p.get('status')!r}")
        unknown = set(p) - {"id", "title", "pattern", "status", "include", "exclude", "requires", "notes", "_file"}
        if unknown:
            problems.append(f"{f}: unknown fields {', '.join(sorted(unknown))}")
        out.append(p)
    return out, problems


def check(doc, pitches, file_problems, previous=None):
    R = Resolver(doc)
    nodes = doc["nodes"]
    res = {}
    owner = collections.defaultdict(list)
    for p in pitches:
        got, rules, probs = R.pitch(p)
        res[p["id"]] = {"id": p["id"], "file": p["_file"], "title": p.get("title"), "pattern": p.get("pattern"),
                        "status": p.get("status", "draft"), "requires": p.get("requires", []), "nodes": sorted(got),
                        "rules": rules, "problems": list(probs)}
        for x in got:
            owner[x].append(p["id"])
    for fp in file_problems:
        pid = fp.split(".json:")[0] if ".json:" in fp else None
        if pid in res:
            res[pid]["problems"].append(fp.split(": ", 1)[1])
    # Prerequisites.
    for pid, r in res.items():
        mine = set(r["nodes"])
        needs = collections.defaultdict(list)     # pitch -> [(declaration, link, type)]
        unowned = collections.defaultdict(list)   # new type no pitch owns -> [(declaration, link)]
        for x in mine:
            for ln in R.g.out[x]:
                if ln["kind"] not in NEEDS:
                    continue
                t = ln["to"]
                if t in mine or t not in R.head:
                    continue
                if not nodes[t].get("isType") and ln["kind"] != "memberOf":
                    continue
                owners = [o for o in owner.get(t, []) if o != pid]
                if owners:
                    for o in owners:
                        needs[o].append((x, ln["kind"], t))
                elif pid not in owner.get(t, []):
                    unowned[t].append((x, ln["kind"]))
        r["needs"] = {o: [{"declaration": nodes[x]["path"], "link": k, "type": nodes[t]["path"]} for x, k, t in v[:8]]
                      for o, v in sorted(needs.items())}
        r["needsCount"] = {o: len(v) for o, v in needs.items()}
        r["unownedTypes"] = {nodes[t]["path"]: [{"declaration": nodes[x]["path"], "link": k} for x, k in v[:5]]
                             for t, v in sorted(unowned.items(), key=lambda kv: nodes[kv[0]]["path"])}
        r["unlistedPrerequisites"] = sorted(set(needs) - set(r["requires"]))
        r["unneededRequires"] = sorted(set(r["requires"]) - set(needs))
        for q in r["requires"]:
            if q not in res:
                r["problems"].append(f"requires `{q}`, which isn't a pitch")
    cycles = find_cycles({pid: set(r["needs"]) for pid, r in res.items()})
    # Patterns.
    for pid, r in res.items():
        r["patternReport"] = pattern_report(R, r, owner)
    # Coverage.
    stubs = {x for x in R.head if nodes[x].get("hiddenClass") == "unavailable"}
    covered = set(owner)
    uncovered = sorted(R.head - covered - stubs, key=lambda x: nodes[x]["path"])
    overlaps = {nodes[x]["path"]: sorted(v) for x, v in owner.items() if len(v) > 1}
    changes = changes_since(previous, doc, pitches, res) if previous else None
    return {"pitches": res, "uncovered": uncovered, "overlaps": overlaps, "cycles": cycles,
            "fileProblems": file_problems, "changes": changes,
            "totals": {"declarations": len(R.head - stubs), "covered": len((covered & R.head) - stubs),
                       "stubs": len(stubs)}}


def find_cycles(succ):
    index, low, on, stack, out = {}, {}, set(), [], []
    counter = [0]

    def visit(v):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on.add(v)
        for w in succ.get(v, ()):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                out.append(sorted(comp))
    for v in sorted(succ):
        if v not in index:
            visit(v)
    return out


def pattern_report(R, r, owner):
    """Whether the pitch's declarations fit its pattern: [(ok, text)]."""
    nodes = R.nodes
    mine = set(r["nodes"])
    api = {x for x in mine if nodes[x].get("hiddenClass") != "unavailable"}
    types = {x for x in api if nodes[x].get("isType")}
    host = {}
    for x in api:
        for ln in R.g.out[x]:
            if ln["kind"] == "memberOf":
                host[x] = ln["to"]
    members = {x for x in api if x in host}
    out = []
    pat = r["pattern"]
    if pat == "types-without-members":
        own_members = {x for x in members if host[x] in types}
        out.append((not own_members, f"{len(types)} types, {len(own_members)} of their members"
                    + (": " + ", ".join(f"`{nodes[x]['path']}`" for x in sorted(own_members)[:6]) if own_members else "")))
    elif pat == "members-of-pitched-type":
        hosts = collections.Counter(host.get(x) for x in api)
        bad = []
        for h, n in hosts.items():
            if h is None:
                bad.append(f"{n} declarations that aren't members")
                continue
            owners = [o for o in owner.get(h, []) if o != r["id"]]
            if h in mine:
                bad.append(f"its host `{nodes[h]['path']}` is in this pitch")
            elif h in R.head and not owners:
                bad.append(f"no other pitch owns `{nodes[h]['path']}`")
        out.append((not bad, f"{len(api)} members of " + ", ".join(
            f"`{nodes[h]['path']}`" for h in hosts if h) + (": " + "; ".join(bad) if bad else "")))
    elif pat == "self-contained-type":
        missing = []
        for t in types:
            for m in R.members(t, nested=True):
                if m in R.head and m not in mine and nodes[m].get("hiddenClass") != "unavailable":
                    missing.append(m)
        out.append((not missing, f"{len(types)} types with {len(members)} members"
                    + (f"; {len(missing)} of their members aren't in it: " + ", ".join(
                        f"`{nodes[x]['path']}`" for x in sorted(missing, key=lambda x: nodes[x]['path'])[:6])
                       if missing else "")))
    elif pat == "function-family":
        fams = collections.Counter()
        for x in api:
            for ln in R.g.out[x]:
                if ln["kind"] == "wraps" and ln["role"] in ("subject", "alternative"):
                    fam = nodes[ln["to"]].get("family")
                    if fam:
                        fams[fam] += 1
        new_types = sorted(nodes[x]["path"] for x in types)
        out.append((len(fams) >= 1 and not new_types, f"families {', '.join(f'`{f}`' for f, _ in fams.most_common())}"
                    + (f"; new types {', '.join(new_types)}" if new_types else "")))
    elif pat == "vocabulary-type":
        users = set()
        for t in types:
            for ln in R.g.inc[t]:
                if ln["kind"] == "usesInSignature":
                    users |= {o for o in owner.get(ln["from"], []) if o != r["id"]}
        out.append((bool(types), f"{len(types)} types, which {len(users)} other pitches name"))
    elif pat == "constants":
        kinds = collections.Counter(nodes[x].get("symbolKind") for x in api)
        out.append((not types, ", ".join(f"{v} {k}" for k, v in kinds.most_common())))
    return out


def changes_since(prev_doc, doc, pitches, res):
    P = Resolver(prev_doc)
    old_nodes, new_nodes = prev_doc["nodes"], doc["nodes"]
    out = {}
    for p in pitches:
        before, _, _ = P.pitch(p)
        now = set(res[p["id"]]["nodes"])
        changed = []
        for x in sorted(now & before):
            a_, b_ = graphq.node_facts(old_nodes[x]), graphq.node_facts(new_nodes[x])
            if a_ != b_:
                changed.append({"declaration": new_nodes[x]["path"],
                                "fields": sorted(f for f in set(a_) | set(b_) if a_.get(f) != b_.get(f))})
        added = sorted(new_nodes[x]["path"] for x in now - before)
        removed = sorted((old_nodes.get(x) or {}).get("path", x) for x in before - now)
        if added or removed or changed:
            out[p["id"]] = {"added": added, "removed": removed, "changed": changed}
    return {"previous": prev_doc["meta"], "pitches": out}


def report_md(result, doc, previous_path=None):
    nodes = doc["nodes"]
    P = result["pitches"]
    t = result["totals"]
    L = ["# Pitches", "",
         f"{len(P)} pitch files cover {t['covered']} of the {t['declarations']} new declarations (fix-it stubs, "
         f"{t['stubs']}, go with what they rename). The format is in `Prototype/ApiGraph/REPORT.md`, section 2; "
         "the tool resolves the files against this run's graph snapshot and never edits them.", ""]
    L += ["| Pitch | Pattern | Status | Declarations | Needs | Fits its pattern | Problems |",
          "|---|---|---|---:|---|---|---:|"]
    for pid, r in sorted(P.items()):
        needs = ", ".join(f"`{o}`" for o in r["needs"]) or "—"
        fits = "; ".join(("" if ok else "**no**: ") + txt for ok, txt in r["patternReport"]) or "—"
        L.append(f"| [`{pid}`](pitches/{pid}/bundle.md) | {r['pattern']} | {r['status']} | {len(r['nodes'])} | {needs} | "
                 f"{fits} | {len(r['problems'])} |")
    L.append("")
    probs = [(pid, x) for pid, r in sorted(P.items()) for x in r["problems"]] + \
        [(None, x) for x in result["fileProblems"] if ".json:" not in x]
    L += ["## Problems", ""]
    L += [f"- `{pid}`: {x}" if pid else f"- {x}" for pid, x in probs] or ["None."]
    L.append("")
    L += ["## Prerequisites", "",
          "A pitch needs another when its declarations name a type the other owns: in a signature, as the host "
          "of a member, the type a nested type is in, an extended type or a protocol.", ""]
    for pid, r in sorted(P.items()):
        if r["needs"]:
            for o, evs in r["needs"].items():
                L.append(f"- `{pid}` needs `{o}` ({r['needsCount'][o]} links"
                         + (", listed in `requires`" if o in r["requires"] else ", not in `requires`")
                         + "): " + "; ".join(f"`{e['declaration']}` {e['link']} `{e['type']}`" for e in evs[:3]) + ".")
        if r["unownedTypes"]:
            L.append(f"- `{pid}` names {len(r['unownedTypes'])} new types no pitch owns yet: "
                     + ", ".join(f"`{k}`" for k in list(r["unownedTypes"])[:12])
                     + (", …" if len(r["unownedTypes"]) > 12 else "") + ".")
        if r["unneededRequires"]:
            L.append(f"- `{pid}` lists `requires` it doesn't need: " + ", ".join(f"`{x}`" for x in r["unneededRequires"]))
    if result["cycles"]:
        L.append("- **Cycles**: " + "; ".join(" ↔ ".join(f"`{x}`" for x in c) for c in result["cycles"]) + ".")
    L.append("")
    ov = result["overlaps"]
    L += [f"## Declarations in two pitches ({len(ov)})", ""]
    L += [f"- `{k}`: " + ", ".join(f"`{x}`" for x in v) for k, v in sorted(ov.items())[:60]] or ["None."]
    if len(ov) > 60:
        L.append(f"- … and {len(ov) - 60} more (pitches.json)")
    L.append("")
    un = result["uncovered"]
    L += [f"## Not covered yet ({len(un)})", "",
          "By the top-level type they belong to, largest first; `pitches.json` lists every one.", ""]
    by_top = collections.defaultdict(list)
    for x in un:
        top = (nodes[x].get("parentPath") or nodes[x]["path"]).split(".")[0]
        by_top[top].append(x)
    L.append("| Under | Declarations | Such as |")
    L.append("|---|---:|---|")
    for top, xs in sorted(by_top.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:60]:
        L.append(f"| `{top}` | {len(xs)} | " + ", ".join(f"`{nodes[x]['path']}`" for x in xs[:3]) + " |")
    if len(by_top) > 60:
        L.append(f"| … {len(by_top) - 60} more | | |")
    L.append("")
    ch = result.get("changes")
    L += ["## Changed since the previous snapshot", ""]
    if not ch:
        L.append("No previous snapshot to compare with.")
    else:
        pm = ch["previous"]
        L.append(f"Against `{pm.get('headRef')}` @ `{pm.get('headCommit', '')[:10]}` ({pm.get('snapshotDate')}).")
        L.append("")
        if not ch["pitches"]:
            L.append("No pitch's declarations changed.")
        for pid, c in sorted(ch["pitches"].items()):
            bits = []
            if c["added"]:
                bits.append(f"now also matches {len(c['added'])}: " + ", ".join(f"`{x}`" for x in c["added"][:6]))
            if c["removed"]:
                bits.append(f"no longer matches {len(c['removed'])}: " + ", ".join(f"`{x}`" for x in c["removed"][:6]))
            if c["changed"]:
                bits.append(f"{len(c['changed'])} changed: " + ", ".join(
                    f"`{x['declaration']}` ({', '.join(x['fields'])})" for x in c["changed"][:6]))
            L.append(f"- `{pid}`: " + "; ".join(bits) + ".")
    L.append("")
    return "\n".join(L) + "\n"


def header_end(src_root, rel, line, cache):
    """The line that opens a declaration's body: its first `{` at or after
    the keyword's line."""
    if rel not in cache:
        path = os.path.join(src_root, rel)
        cache[rel] = open(path, encoding="utf-8", errors="replace").read().split("\n") if os.path.exists(path) else []
    lines = cache[rel]
    for k in range(line - 1, min(len(lines), line + 12)):
        if "{" in lines[k]:
            return k + 1
    return line


def bundle_units(result, pitches, graph, snapshot, conts, evidence, drafts, src_root):
    """Each pitch as a unit bundles.py writes a bundle for: its declarations,
    the source ranges that hold them (a type pitched without its members
    shows only its declaration's head; a member, its extension's head too),
    metrics, open questions (its own, and those of the types it needs from
    other pitches or from no pitch), prerequisites and dependents."""
    import units as U
    gn = graph["nodes"]
    node_tags = U.tag_nodes(gn, graph["edges"], graph["vocabulary"], conts, drafts)
    verified = U.load_verified(evidence, src_root)
    prior = U.Prior(src_root, drafts)
    R = result["pitches"]
    owner = collections.defaultdict(list)
    for pid, r in R.items():
        for x in r["nodes"]:
            owner[x].append(pid)
    dependents = collections.defaultdict(set)
    for pid, r in R.items():
        for o in r["needs"]:
            dependents[o].add(pid)
    by_id = {p["id"]: p for p in pitches}
    cache = {}
    units_out = []
    for pid, r in sorted(R.items()):
        nids = [x for x in r["nodes"] if x in gn]
        mine = set(nids)
        ranges = []
        heads = set()
        for x in nids:
            n = gn[x]
            if not n.get("file"):
                continue
            members_in = any(m in mine for m in members_of(snapshot, x))
            if n["isType"] and not members_in and n["kind"] != "swift.typealias":
                ranges.append([n["file"], n["start"], header_end(src_root, n["file"], n["line"], cache),
                               f"{n['path']} (its declaration)"])
            else:
                ranges.append([n["file"], n["start"], n["end"], n["path"]])
            b = n.get("block")
            if b and b["kind"] == "extension" and (b["file"], b["start"]) not in heads and b["line"] < n["start"]:
                heads.add((b["file"], b["start"]))
                ranges.append([b["file"], b["start"], b["line"], f"extension {b['subject']} (its head)"])
        direct = U.direct_tags(node_tags, nids)
        inherited = {}
        for o, evs in r["needs"].items():
            for x in R[o]["nodes"]:
                for cid_, w, ev, inh in node_tags.get(x, ()):
                    if inh and cid_ not in direct and cid_ not in inherited:
                        inherited[cid_] = {"via": f"{gn[x]['path']} (pitch {o})", "through": "api", "weight": w,
                                           "namespaceOnly": False}
        path_id = {gn[x]["path"]: x for x in gn}
        for tpath in r["unownedTypes"]:
            t = path_id.get(tpath)
            for cid_, w, ev, inh in node_tags.get(t, ()) if t else ():
                if inh and cid_ not in direct and cid_ not in inherited:
                    inherited[cid_] = {"via": f"{tpath} (no pitch owns it)", "through": "api", "weight": w,
                                       "namespaceOnly": False}
        prereq = {o: {"kinds": sorted({e["link"] for e in evs}), "types": sorted({e["type"] for e in evs}),
                      "edges": [[e["declaration"], e["type"], e["link"]] for e in evs], "namespaceOnly": False}
                  for o, evs in r["needs"].items()}
        impl = collections.defaultdict(list)
        for x in nids:
            for used in gn[x].get("implUses", ()):
                for o in owner.get(used, []):
                    if o != pid and o not in prereq and len(impl[o]) < 6:
                        impl[o].append([gn[x]["path"], gn[used]["path"]])
        related = related_api(snapshot, mine, owner, pid)
        p = by_id[pid]
        units_out.append({
            "id": pid, "kind": "pitch", "name": r["title"] or pid, "pattern": r["pattern"], "status": r["status"],
            "file": r["file"], "notes": p.get("notes"), "rules": r["rules"], "problems": r["problems"],
            "patternReport": r["patternReport"], "requires": r["requires"], "unownedTypes": r["unownedTypes"],
            "nodes": nids, "atoms": [], "ranges": ranges,
            "metrics": U.metrics(gn, graph["tests"], verified, nids), "prior": prior.matches(gn, nids),
            "direct": direct, "inherited": inherited, "prerequisites": prereq, "allPrerequisites": prereq,
            "implPrerequisites": dict(impl), "dependents": sorted(dependents.get(pid, ())), "parts": [],
            "reason": None, "related": related,
        })
    return {"units": units_out, "owners": {k: v for k, v in owner.items()}, "gists": prior.gists}


def related_api(G, mine, owner, pid, limit=40):
    """New declarations in the pitch's domains (domains.json) that the graph
    doesn't link to it: no stored link between them and the pitch's
    declarations, and no shared C family or block. By domain, then C family,
    each with the pitch that owns it."""
    nodes = G.nodes
    doms = {d for x in mine for d in (nodes[x].get("domains") or [])}
    if not doms:
        return {}
    linked = set()
    fams, blocks = set(), set()
    for x in mine:
        for ln in G.out[x]:
            linked.add(ln["to"])
            if ln["kind"] == "wraps" and nodes[ln["to"]].get("family"):
                fams.add(nodes[ln["to"]]["family"])
            if ln["kind"] == "inBlock":
                blocks.add(ln["to"])
        for ln in G.inc[x]:
            linked.add(ln["from"])
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    for nid, n in nodes.items():
        if n["kind"] != "declaration" or n.get("origin") != "head" or nid in mine or nid in linked:
            continue
        if n.get("hiddenClass") == "unavailable":
            continue
        shared = set(n.get("domains") or []) & doms
        if not shared:
            continue
        nf = {nodes[ln["to"]].get("family") or nodes[ln["to"]]["name"] for ln in G.out[nid] if ln["kind"] == "wraps"}
        nb = {ln["to"] for ln in G.out[nid] if ln["kind"] == "inBlock"}
        if nf & fams or nb & blocks or any(ln["to"] in mine for ln in G.out[nid]):
            continue
        for d in sorted(shared):
            out[d][", ".join(sorted(nf)) or "—"].append({"path": n["path"],
                                                         "pitches": [o for o in owner.get(nid, []) if o != pid]})
    # Keep it short: the largest families first, up to `limit` declarations.
    res, total = {}, 0
    for d in sorted(out, key=lambda d: -sum(len(v) for v in out[d].values())):
        for fam, xs in sorted(out[d].items(), key=lambda kv: -len(kv[1])):
            if total >= limit:
                break
            res.setdefault(d, {})[fam] = sorted(xs, key=lambda x: x["path"])[:8]
            total += min(len(xs), 8)
    return res


def members_of(snapshot_graph, tid):
    return [ln["from"] for ln in snapshot_graph.inc[tid] if ln["kind"] == "memberOf"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", required=True)
    ap.add_argument("--pitches", required=True)
    ap.add_argument("--previous")
    ap.add_argument("--out")
    ap.add_argument("--show", help="print one pitch's declarations")
    ap.add_argument("--units-out", help="write the pitches as bundle units (needs --graph and --root)")
    ap.add_argument("--graph", help="build_graph.py's graph.json")
    ap.add_argument("--root", help="the head commit's export")
    ap.add_argument("--contingencies")
    ap.add_argument("--evidence")
    ap.add_argument("--drafts")
    a = ap.parse_args()
    doc = graphq.load(a.snapshot)
    pitches, file_problems = load_pitches(a.pitches)
    prev = graphq.load(a.previous) if a.previous and os.path.exists(a.previous) else None
    result = check(doc, pitches, file_problems, prev)
    if a.show:
        r = result["pitches"].get(a.show) or sys.exit(f"pitches: no pitch {a.show!r}")
        for x in r["nodes"]:
            print(doc["nodes"][x]["path"])
        return
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        json.dump(result, open(os.path.join(a.out, "pitches.json"), "w"), indent=1)
        open(os.path.join(a.out, "PITCHES.md"), "w").write(report_md(result, doc))
    if a.units_out:
        graph = graphq.load(a.graph)
        conts = json.load(open(a.contingencies))["contingencies"] if a.contingencies else []
        evidence = json.load(open(a.evidence))["sources"] if a.evidence else []
        drafts = a.drafts if a.drafts and os.path.isdir(a.drafts) else None
        units_doc = bundle_units(result, pitches, graph, graphq.Graph(doc), conts, evidence, drafts, a.root)
        units_doc["contingencies"] = conts
        json.dump(units_doc, open(a.units_out, "w"), indent=1)
    t = result["totals"]
    n_probs = sum(len(r["problems"]) for r in result["pitches"].values()) + len(result["fileProblems"])
    print(f"pitches: {len(pitches)} pitch files cover {t['covered']} of {t['declarations']} declarations; "
          f"{len(result['overlaps'])} in two pitches, {len(result['uncovered'])} uncovered, {n_probs} problems"
          + (f" -> {a.out}" if a.out else ""))


if __name__ == "__main__":
    main()
