#!/usr/bin/env python3
"""Cluster the declaration graph, tag contingencies, and rank carve-outs.

The steps, each described with the alternative it rejected in method.md:

 1. Atom graph. build_graph.py's node edges, lifted to atoms (top-level
    blocks): A -> B when a declaration in A names a type declared in B.
    Edges to vocabulary (anything on the base commit, or from another
    module) don't connect anything.
 2. Promotion. A new type that code in several places depends on (ProcessID,
    say: terminal job control, fcntl, file locks, libproc) is promoted to
    shared vocabulary. Edges into it from outside its home are cut; each
    becomes a prerequisite of the cluster it came from.
 3. Clusters: the connected components of what's left. Members of namespace
    blocks (CInterop aliases) join the cluster that uses them most.
 4. Parts: inside a cluster, the pieces that could be pitched separately,
    in dependency order: atoms merged when they're mutually dependent, when
    one extends a type the other declares in the same file, or when one is
    used only by the other.
 5. Contingencies: contingencies.json's rules, per declaration, then per
    cluster and part, and inherited through prerequisites. Inheritance
    through nesting alone (PThread.Mutex needs the name PThread, not the
    answer to PThread's deinit) is marked as such.
 6. Ranking: clusters, and the parts of big clusters, easiest first.

Usage: cluster.py --graph graph.json --config config.json
                  --contingencies contingencies.json --evidence evidence.json
                  --root DIR [--drafts DIR] --out clusters.json
"""

import argparse
import collections
import json
import os
import re

TYPE_KINDS = {"swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.actor", "swift.typealias"}
EDGE_KIND = {"memberOf": "extends", "nestedIn": "nests", "references": "uses", "conformsTo": "conforms"}
PLATFORM_ORDER = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
# C calls that multiplex many operations, which prose mentions in passing.
GENERIC_C = {"fcntl", "ioctl", "sysctl", "open", "openat", "close", "read", "write", "stat", "fstat", "lstat"}


def load(p):
    return json.load(open(p))


def slug(s):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.lower())).strip("-")[:60]


def place(rel):
    """Where a file lives, for promotion: a directory under a module's
    sources, or the file itself when it's in the module's root."""
    for root in ("Sources/System/", "Sources/SystemSockets/"):
        if rel and rel.startswith(root):
            rest = rel[len(root):]
            mod = "SystemPackage" if root == "Sources/System/" else "SystemSockets"
            return f"{mod}:{rest.split('/')[0]}/" if "/" in rest else f"{mod}:{rest}"
    return rel or "?"


class UnionFind:
    def __init__(self, items):
        self.p = {x: x for x in items}

    def find(self, x):
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            # Deterministic: the smaller key becomes the root.
            if rb < ra:
                ra, rb = rb, ra
            self.p[rb] = ra
            return True
        return False

    def groups(self):
        g = collections.defaultdict(list)
        for x in self.p:
            g[self.find(x)].append(x)
        return g


def sccs(nodes, succ):
    """Tarjan's strongly connected components."""
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
            out.append(comp)

    import sys
    sys.setrecursionlimit(10000)
    for v in sorted(nodes):
        if v not in index:
            visit(v)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--contingencies", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--drafts")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    g = load(a.graph)
    cfg = load(a.config)
    conts = load(a.contingencies)["contingencies"]
    evidence_cfg = load(a.evidence)["sources"]
    nodes, edges, atoms, vocab = g["nodes"], g["edges"], g["atoms"], g["vocabulary"]
    W = cfg["weights"]

    node_atom = {nid: n["atom"] for nid, n in nodes.items() if n.get("atom")}
    loose = {k for k, v in atoms.items() if v["loose"]}

    # ------------------------------------------------------------ 1. atom graph
    atom_edges = collections.defaultdict(list)   # (A, B) -> [(from, to, kind)]
    atom_vocab = collections.defaultdict(collections.Counter)
    for e in edges:
        u, v = e["from"], e["to"]
        A = node_atom.get(u)
        if A is None:
            continue
        if v in nodes:
            B = node_atom.get(v)
            if B and B != A:
                atom_edges[(A, B)].append((u, v, EDGE_KIND[e["kind"]]))
        else:
            atom_vocab[A][vocab.get(v, {}).get("path", v)] += 1

    out_edges, in_edges = collections.defaultdict(list), collections.defaultdict(list)
    for (A, B), evs in atom_edges.items():
        out_edges[A].append((B, evs))
        in_edges[B].append((A, evs))

    def home(tnode):
        return place(tnode["file"])

    # ------------------------------------------------------------ 2. promotion
    dependents_of = collections.defaultdict(lambda: collections.defaultdict(set))  # type -> place -> atoms
    for (A, B), evs in atom_edges.items():
        if A in loose:
            continue
        for u, v, kind in evs:
            t = nodes[v]
            if not t["isType"]:
                continue
            p = place(atoms[A]["file"])
            if p != home(t):
                dependents_of[v][p].add(A)
    promoted = {}
    for tid, by_place in dependents_of.items():
        t = nodes[tid]
        if node_atom.get(tid) in loose or t["path"] in cfg["demote"]:
            continue
        if len(by_place) >= cfg["promoteMinPlaces"] or t["path"] in cfg["promote"]:
            promoted[tid] = {"type": t["path"], "id": tid, "home": home(t),
                             "places": {p: sorted(v) for p, v in sorted(by_place.items())}}
    for path in cfg["promote"]:
        tid = next((k for k, n in nodes.items() if n["path"] == path and n["isType"]), None)
        if tid and tid not in promoted:
            promoted[tid] = {"type": path, "id": tid, "home": home(nodes[tid]), "places": {}}

    def edge_is_cut(A, evs):
        pa = place(atoms[A]["file"])
        return all(v in promoted and pa != promoted[v]["home"] for _, v, _ in evs)

    # ------------------------------------------------------------ 3. clusters
    solid = [k for k in atoms if k not in loose]
    uf = UnionFind(solid)
    cut = {}
    for (A, B), evs in atom_edges.items():
        if A in loose or B in loose:
            continue
        if edge_is_cut(A, evs):
            cut[(A, B)] = evs
        else:
            uf.union(A, B)
    comp = {x: uf.find(x) for x in solid}
    # Loose atoms join the cluster whose signatures use them most; failing
    # that, the one whose implementations do (an alias only a body names);
    # failing that, the one that owns most of their file.
    impl_users = collections.defaultdict(collections.Counter)
    for nid, n in nodes.items():
        A = node_atom.get(nid)
        if A is None or A in loose:
            continue
        for used in n.get("implUses", ()):
            L = node_atom.get(used)
            if L in loose:
                impl_users[L][A] += 1
    loose_home, loose_users, loose_via = {}, {}, {}
    file_owner = collections.defaultdict(collections.Counter)
    for A in solid:
        file_owner[atoms[A]["file"]][comp[A]] += len(atoms[A]["nodes"])
    for L in sorted(loose):
        votes = collections.Counter()
        for A, evs in in_edges[L]:
            if A not in loose:
                votes[comp[A]] += len(evs)
        via = "signature"
        if not votes:
            for A, k in impl_users[L].items():
                votes[comp[A]] += k
            via = "implementation"
        loose_users[L] = votes
        if votes:
            best = max(votes.items(), key=lambda kv: (kv[1], -len(kv[0]), kv[0]))[0]
        elif file_owner.get(atoms[L]["file"]):
            best, via = file_owner[atoms[L]["file"]].most_common(1)[0][0], "file"
        else:
            continue
        loose_home[L] = best
        loose_via[L] = via
        comp[L] = best
        file_owner[atoms[L]["file"]][best] += 1
    # Aliases nothing uses go with the aliases declared beside them, or
    # else form one cluster per file.
    orphan_root = {}
    for L in sorted(loose):
        if L in comp:
            continue
        f = atoms[L]["file"]
        if file_owner.get(f):
            best, via = file_owner[f].most_common(1)[0][0], "file"
        else:
            best, via = orphan_root.setdefault(f, L), "unused"
        loose_home[L], loose_via[L], comp[L] = best, via, best
    # A cluster no signature connects to anything, whose types only the
    # implementation of one other cluster in the same file uses (an error a
    # body throws), belongs to that cluster.
    impl_users_of = collections.defaultdict(set)   # node -> components whose bodies use it
    for nid, n in nodes.items():
        A = node_atom.get(nid)
        if A is None:
            continue
        for used in n.get("implUses", ()):
            B = node_atom.get(used)
            if B is not None and comp[A] != comp[B]:
                impl_users_of[used].add(comp[A])
    touching = set()
    for (A, B) in atom_edges:
        if comp.get(A) != comp.get(B):
            touching |= {comp.get(A), comp.get(B)}
    groups0 = collections.defaultdict(list)
    for x, c in comp.items():
        groups0[c].append(x)
    attached, attached_info = {}, []
    for root, xs in sorted(groups0.items()):
        if root in touching:
            continue
        types = [i for x in xs for i in atoms[x]["nodes"] if nodes[i]["isType"]]
        users = set().union(*(impl_users_of.get(t, set()) for t in types)) if types else set()
        users.discard(root)
        files = {atoms[x]["file"] for x in xs}
        if len(users) == 1:
            (target,) = users
            shared_files = files & {atoms[y]["file"] for y in groups0[target]}
            if shared_files:
                attached[root] = target
                attached_info.append({"from": root, "into": target, "file": sorted(shared_files)[0],
                                      "types": sorted(nodes[t]["path"] for t in types)})
    for x, c in list(comp.items()):
        while c in attached:
            c = attached[c]
        comp[x] = c
    members = collections.defaultdict(list)
    for x, c in comp.items():
        members[c].append(x)

    # ------------------------------------------------------------ helpers
    def unit_nodes(atom_ids):
        out = []
        for x in atom_ids:
            out.extend(atoms[x]["nodes"])
        return out

    def is_api(n):
        return n["hiddenClass"] != "unavailable"

    # ------------------------------------------------------------ 5a. contingencies per node
    drafts = a.drafts if a.drafts and os.path.isdir(a.drafts) else None
    node_tags = collections.defaultdict(list)   # nid -> [(cid, weight, evidence)]
    edges_from = collections.defaultdict(list)
    for e in edges:
        edges_from[e["from"]].append(e)

    def target_path(t):
        return nodes[t]["path"] if t in nodes else vocab.get(t, {}).get("path", t)

    def throwing_closure(n):
        d = n["decl"]
        return (re.search(r"\)\s*(async\s+)?throws(\([^)]*\))?\s*(->|$|where)", d) is not None
                and re.search(r":\s*(@\w+\s+)*\((?:[^()]|\([^()]*\))*\)\s*(async\s+)?throws(\([^)]*\))?\s*->", d)
                is not None and "rethrows" not in d)

    for nid, n in nodes.items():
        for c in conts:
            for r in c["rules"]:
                k = r["kind"]
                hit, extra = False, {}
                if k == "noncopyableType":
                    hit = n["noncopyable"]
                elif k == "hasDeinit":
                    hit = n["hasDeinit"]
                elif k == "lifetime":
                    hit = n["lifetime"] or n["nonescapable"]
                elif k == "declRegex":
                    hit = re.search(r["pattern"], n["decl"]) is not None
                elif k == "pathRegex":
                    hit = re.search(r["pattern"], n["path"]) is not None
                elif k == "referencesPath":
                    hit = any(re.search(r["pattern"], target_path(e["to"])) for e in edges_from[nid]
                              if e["kind"] == "references")
                elif k == "referencesNodePath":
                    hit = any(e["to"] in nodes and re.search(r["pattern"], nodes[e["to"]]["path"])
                              for e in edges_from[nid] if e["kind"] == "references")
                elif k == "module":
                    hit = n["module"] in r["modules"]
                elif k == "platform":
                    hit = r["platform"] in (n["platforms"] or [])
                elif k == "throwingClosure":
                    hit = throwing_closure(n)
                elif k == "changedThrows":
                    hit = n["status"] == "changed" and any("throws" in ch for ch in n["changes"])
                elif k == "cName":
                    names = [x for x in n["cNames"] + n["cCalls"] if re.search(r["pattern"], x)]
                    hit = bool(names)
                    extra["cname"] = ", ".join(names)
                elif k == "implementationName":
                    hit = any(re.search(r["pattern"], p["name"]) and re.search(r["filePattern"], p["file"])
                              for p in n["implementation"])
                else:
                    raise SystemExit(f"cluster: unknown rule kind {k!r} in contingency {c['id']}")
                if hit and not (k == "platform" and n["hiddenClass"] == "unavailable"):
                    ev = r["evidence"].format(path=n["path"], **extra)
                    if r.get("draft") and drafts:
                        ev += f" ({os.path.join(os.path.basename(drafts), r['draft'])})"
                    node_tags[nid].append((c["id"], r.get("weight", 1), ev, r.get("inherit", True)))

    cont_by_id = {c["id"]: c for c in conts}

    # ------------------------------------------------------------ evidence off Darwin
    verified = collections.defaultdict(list)   # file -> [(platforms, level, source, detail)]
    for src in evidence_cfg:
        files = []
        if src["kind"] == "script":
            p = os.path.join(a.root, src["path"])
            if os.path.exists(p):
                files = sorted(set(re.findall(r"[\"']((?:Sources|Tests)/[^\"']+\.swift)[\"']", open(p).read())))
        elif src["kind"] == "files":
            files = src["files"]
        for f in files:
            verified[f].append({"platforms": src["platforms"], "level": src["level"],
                                "source": src.get("path", src.get("name", "?")), "detail": src.get("detail", "")})

    # ------------------------------------------------------------ prior text
    prior_docs = []
    for rel in sorted(os.listdir(os.path.join(a.root, "Proposals"))) if os.path.isdir(
            os.path.join(a.root, "Proposals")) else []:
        if rel.endswith(".md"):
            prior_docs.append(("proposal", os.path.join("Proposals", rel), os.path.join(a.root, "Proposals", rel)))
    for d in sorted(os.listdir(os.path.join(a.root, "Prototype"))) if os.path.isdir(
            os.path.join(a.root, "Prototype")) else []:
        p = os.path.join(a.root, "Prototype", d, "README.md")
        if os.path.exists(p):
            prior_docs.append(("prototype", os.path.join("Prototype", d, "README.md"), p))
    if drafts:
        for rel in sorted(os.listdir(drafts)):
            if rel.endswith(".md"):
                prior_docs.append(("draft", os.path.join(os.path.basename(drafts), rel), os.path.join(drafts, rel)))
    prior_text = {rel: open(p, encoding="utf-8").read() for _, rel, p in prior_docs}
    prior_words = {rel: collections.Counter(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", t)) for rel, t in prior_text.items()}
    prior_kind = {rel: k for k, rel, _ in prior_docs}
    gist_re = re.compile(r"https?://gist\.github(?:usercontent)?\.com/[^\s)>\"'`]+")
    gists = sorted({m for t in prior_text.values() for m in gist_re.findall(t)})
    # Names that identify a unit in prose: its new types' last components
    # and C names, when they're distinctive enough not to match everything.
    common_words = {"Flags", "Options", "Kind", "Entry", "Info", "ID", "Attributes", "Name", "Mode", "Event",
                    "Events", "Order", "Action", "Queue", "Scheduling", "Filter", "Message", "Key", "Parity"}

    def prior_matches(unit_node_ids):
        names = set()
        for nid in unit_node_ids:
            n = nodes[nid]
            if n["isType"]:
                last = n["path"].split(".")[-1]
                if last not in common_words and len(last) > 3:
                    names.add(last)
            for c in n["cNames"]:
                if len(c) > 3 and c not in GENERIC_C:
                    names.add(c)
        out = []
        for rel, words in prior_words.items():
            hits = collections.Counter({nm: words[nm] for nm in names if words.get(nm)})
            score = sum(min(v, 10) for v in hits.values())
            if score >= 3 and (len(hits) >= 2 or max(hits.values()) >= 5):
                out.append({"file": rel, "kind": prior_kind[rel], "score": score,
                            "names": [k for k, _ in hits.most_common(6)]})
        out.sort(key=lambda x: (-x["score"], x["file"]))
        return out[:6]

    # ------------------------------------------------------------ unit metrics
    def availability_class(n):
        if n["hiddenClass"] == "unavailable":
            return "fix-it stub"
        s = n.get("system")
        os_floor = bool(n.get("explicitOS"))
        if s and os_floor:
            return f"System {s} + OS floor"
        if s:
            return f"System {s}"
        if os_floor:
            return "OS floor only"
        return "none"

    def metrics(node_ids):
        ns = [nodes[x] for x in node_ids]
        api = [n for n in ns if is_api(n)]
        plats = set()
        for n in api:
            plats |= set(p for p in (n["platforms"] or []) if not p.startswith("?"))
        plat_sets = collections.Counter(tuple(n["platforms"] or []) for n in api)
        files = sorted({n["file"] for n in ns if n["file"]})
        ver = []
        for f in files:
            for v in verified.get(f, []):
                if v not in ver:
                    ver.append(v)
        verified_plats = sorted({p for v in ver for p in v["platforms"]},
                                key=lambda p: PLATFORM_ORDER.index(p) if p in PLATFORM_ORDER else 99)
        claimed_off = [p for p in PLATFORM_ORDER if p in plats and p != "Darwin"]
        tests = sorted({t for n in ns for t in n["tests"]})
        oddities = [n["path"] for n in api if n.get("system") not in ("199",) and n["status"] == "added"
                    and n["source"] == "graph"]
        return {
            "declarations": len(api),
            "types": sum(1 for n in api if n["isType"]),
            "stubs": sum(1 for n in ns if n["hiddenClass"] == "unavailable"),
            "offDarwinOnly": sum(1 for n in api if n["source"] == "scan" and n["hiddenClass"] == "platform"),
            "documented": sum(1 for n in api if n["hasDoc"]),
            "tested": sum(1 for n in api if n["tests"]),
            "lexicallyTested": sum(1 for n in api if n.get("lexicalTests")),
            "tests": tests,
            "mockTests": sorted(t for t in tests if g["tests"].get(t, {}).get("mock")),
            "samples": sorted({s for n in ns for s in n["samples"]}),
            "platforms": [p for p in PLATFORM_ORDER if p in plats],
            "platformVariants": len(plat_sets),
            "claimedOffDarwin": claimed_off,
            "verifiedOffDarwin": ver,
            "unverifiedOffDarwin": [p for p in claimed_off if p not in verified_plats],
            "darwin": "Darwin" in plats,
            "availability": dict(collections.Counter(availability_class(n) for n in ns).most_common()),
            "availabilityOddities": oddities,
            "files": files,
            "modules": sorted({n["module"] for n in ns}),
            "cNames": sorted({c for n in ns for c in n["cNames"] + n["cCalls"]}),
        }

    # ------------------------------------------------------------ naming
    dep_atoms = collections.defaultdict(set)   # type -> atoms that depend on it
    for (A, B), evs in atom_edges.items():
        for _, v, _ in evs:
            if nodes[v]["isType"]:
                dep_atoms[v].add(A)

    def name_for(atom_ids, whole_cluster=False):
        """A unit's name: a type it declares at top level (an owner before
        plain data, then the one most other code depends on), or a type
        covering much of it; else the type its blocks extend, with the MARK
        comment or file that sets them apart."""
        ns = [nodes[x] for x in unit_nodes(atom_ids)]
        api = [n for n in ns if is_api(n)] or ns
        type_paths = {n["path"] for n in ns if n["isType"]}
        roots = [n for n in ns if n["isType"] and n["kind"] != "swift.typealias" and n["parentPath"] not in type_paths]
        subjects = collections.Counter(atoms[x]["subject"] for x in atom_ids if not atoms[x]["loose"])
        if not subjects:
            subjects = collections.Counter(n["parentPath"] or n["path"] for n in ns)
        subject = subjects.most_common(1)[0][0]

        def size(t):
            return sum(1 for m in api if m["path"] == t["path"] or m["path"].startswith(t["path"] + "."))
        if roots:
            best = max(roots, key=lambda t: (t["path"] in subjects, t["noncopyable"], len(dep_atoms[t["id"]]),
                                              size(t), -len(t["path"]), t["path"]))
            if best["path"] not in subjects and not whole_cluster:
                best = max(roots, key=lambda t: (size(t), len(dep_atoms[t["id"]]), -len(t["path"]), t["path"]))
            if best["path"] in subjects or whole_cluster or size(best) * 10 >= 4 * len(api):
                return best["path"], best
        ordered = sorted((x for x in atom_ids if not atoms[x]["loose"]),
                         key=lambda k: (atoms[k]["file"], atoms[k]["start"]))
        marks = list(dict.fromkeys(atoms[x]["mark"] for x in ordered if atoms[x]["mark"]))
        files = collections.Counter(atoms[x]["file"] for x in ordered)
        stem = os.path.splitext(os.path.basename(files.most_common(1)[0][0]))[0] if files else None
        cn = list(dict.fromkeys(c for n in ns for c in n["cNames"]))
        if marks:
            return f"{subject}: {', '.join(marks[:3])}" + (", ..." if len(marks) > 3 else ""), None
        # Blocks that only extend a vocabulary type are named for what they
        # wrap; the file would name several of them alike.
        if cn and not roots:
            return f"{subject}: {', '.join(cn[:3])}", None
        if stem and stem.split("+")[0] != subject.split(".")[-1] and stem != subject:
            return f"{subject} ({stem})", None
        if cn:
            return f"{subject}: {', '.join(cn[:3])}", None
        return f"{subject}: {', '.join(list(dict.fromkeys(re.sub(r'[(].*', '', n['title']) for n in ns))[:3])}", None

    # ------------------------------------------------------------ clusters
    clusters = []
    cluster_of_atom = {}
    for root, xs in sorted(members.items(), key=lambda kv: kv[0]):
        cid = f"c{len(clusters)}"
        for x in xs:
            cluster_of_atom[x] = cid
        clusters.append({"key": cid, "atoms": sorted(xs, key=lambda k: (atoms[k]["file"] or "", atoms[k]["start"]))})
    by_key = {c["key"]: c for c in clusters}
    root_cluster = {r: cluster_of_atom[r] for r in members}

    # Prerequisites between clusters, from cut edges.
    for c in clusters:
        c["prereq"] = collections.defaultdict(lambda: {"kinds": set(), "types": set(), "edges": []})
    for (A, B), evs in cut.items():
        ca, cb = cluster_of_atom[A], cluster_of_atom[B]
        if ca == cb:
            continue
        p = by_key[ca]["prereq"][cb]
        for u, v, kind in evs:
            p["kinds"].add(kind)
            p["types"].add(nodes[v]["path"])
            p["edges"].append([nodes[u]["path"], nodes[v]["path"], kind])

    # ------------------------------------------------------------ 4. parts
    def is_helper(atom_ids):
        ns = [nodes[i] for i in unit_nodes(atom_ids)]
        return not any(n["noncopyable"] or n["cCalls"] for n in ns)

    def files_of(atom_ids):
        return {atoms[x]["file"] for x in atom_ids}

    def make_parts(c):
        xs = [x for x in c["atoms"] if x not in loose]
        if len(xs) <= 1:
            return [{"atoms": list(c["atoms"])}], {}
        uf2 = UnionFind(xs)
        intra = {(A, B): evs for A in xs for B, evs in out_edges[A]
                 if B in uf2.p and (A, B) not in cut}
        # Same file: an atom that extends or nests into a type another atom
        # declares, or that extends the same new type.
        for (A, B), evs in intra.items():
            if atoms[A]["file"] == atoms[B]["file"] and any(k in ("extends", "nests") for _, _, k in evs):
                uf2.union(A, B)
        by_subject = collections.defaultdict(list)
        for x in xs:
            by_subject[(atoms[x]["file"], atoms[x]["subject"])].append(x)
        new_type_paths = {nodes[i]["path"] for x in xs for i in atoms[x]["nodes"] if nodes[i]["isType"]}
        for (f, subj), group in by_subject.items():
            if subj in new_type_paths and len(group) > 1:
                for x in group[1:]:
                    uf2.union(group[0], x)
        changed = True
        while changed:
            changed = False
            succ = collections.defaultdict(set)
            for (A, B) in intra:
                ra, rb = uf2.find(A), uf2.find(B)
                if ra != rb:
                    succ[ra].add(rb)
            parts_now = sorted(set(uf2.find(x) for x in xs))
            for comp_ in sccs(parts_now, succ):
                if len(comp_) > 1:
                    for x in comp_[1:]:
                        changed |= uf2.union(comp_[0], x)
            if changed:
                continue
            preds = collections.defaultdict(set)
            for s_, ts in succ.items():
                for t_ in ts:
                    preds[t_].add(s_)
            current = collections.defaultdict(list)
            for x in xs:
                current[uf2.find(x)].append(x)
            for p_ in parts_now:
                # A part used by one other part only belongs to it when it's
                # a helper (a copyable type that wraps no C function of its
                # own: flags, a value type) or shares its file. An owner, or
                # a type with its own calls elsewhere, stands on its own.
                if len(preds.get(p_, ())) == 1:
                    (only,) = preds[p_]
                    if is_helper(current[p_]) or files_of(current[p_]) & files_of(current[only]):
                        changed |= uf2.union(only, p_)
                        if changed:
                            break
            if changed:
                continue
            # Leaves in one file that the author didn't set apart with
            # different MARK comments, and that need the same parts, are one
            # piece (PThreadNames.swift's two extensions, say).
            leaves = collections.defaultdict(list)
            for p_ in parts_now:
                if preds.get(p_):
                    continue
                fs = files_of(current[p_])
                marks = {atoms[x]["mark"] for x in current[p_]}
                if len(fs) == 1 and len(marks) == 1:
                    leaves[(next(iter(fs)), next(iter(marks)), frozenset(succ.get(p_, ())))].append(p_)
            for group in leaves.values():
                for p_ in group[1:]:
                    changed |= uf2.union(group[0], p_)
        groups = uf2.groups()
        part_of = {x: uf2.find(x) for x in xs}
        for L in c["atoms"]:
            if L in loose:
                votes = collections.Counter()
                for A, evs in in_edges[L]:
                    if A in part_of:
                        votes[part_of[A]] += len(evs)
                if not votes:
                    for A, k in impl_users[L].items():
                        if A in part_of:
                            votes[part_of[A]] += k
                target = votes.most_common(1)[0][0] if votes else sorted(groups)[0]
                groups[target].append(L)
                part_of[L] = target
        parts = [{"root": r, "atoms": sorted(v, key=lambda k: (atoms[k]["file"] or "", atoms[k]["start"]))}
                 for r, v in sorted(groups.items())]
        return parts, part_of

    # ------------------------------------------------------------ units
    units = {}

    def new_unit(kind, atom_ids, cluster_key):
        nids = unit_nodes(atom_ids)
        name, primary = name_for(atom_ids, whole_cluster=kind == "cluster")
        u = {"kind": kind, "cluster": cluster_key, "atoms": atom_ids, "nodes": nids, "name": name,
             "primaryType": primary["path"] if primary else None,
             "types": sorted({nodes[i]["path"] for i in nids if nodes[i]["isType"]}),
             "metrics": metrics(nids), "prior": prior_matches(nids)}
        direct = collections.defaultdict(list)
        for i in nids:
            for cid_, w, ev, inherit in node_tags.get(i, ()):
                direct[cid_].append((w, ev, inherit))
        u["direct"] = {k: {"weight": max(w for w, _, _ in v), "count": len(v),
                           "inheritWeight": max((w for w, _, inh in v if inh), default=0),
                           "evidence": list(dict.fromkeys(ev for _, ev, _ in v))[:6]} for k, v in sorted(direct.items())}
        return u

    for c in clusters:
        parts, part_of = make_parts(c)
        c["parts"] = parts
        c["part_of"] = part_of
        cu = new_unit("cluster", c["atoms"], c["key"])
        units[c["key"]] = cu
        c["unit"] = cu
        if len(parts) > 1:
            for k, p in enumerate(parts):
                pk = f"{c['key']}.p{k}"
                pu = new_unit("part", p["atoms"], c["key"])
                units[pk] = pu
                p["key"] = pk
        else:
            parts[0]["key"] = c["key"]

    # Ids from names: stable across runs as long as the names are.
    # Units named alike (two blocks wrapping the same C calls) are told
    # apart by the file most of their declarations are in.
    name_count = collections.Counter((u["kind"], u["name"]) for u in units.values())
    for u in units.values():
        if name_count[(u["kind"], u["name"])] > 1:
            files = collections.Counter(nodes[i]["file"] for i in u["nodes"] if nodes[i]["file"])
            if files:
                stem = os.path.splitext(os.path.basename(files.most_common(1)[0][0]))[0]
                u["name"] = f"{u['name']} ({stem})"
    used = collections.Counter()
    for key in sorted(units, key=lambda k: (units[k]["kind"] != "cluster", k)):
        u = units[key]
        base = slug(u["name"]) or "unit"
        if u["kind"] == "part":
            base = slug(units[u["cluster"]]["name"]) + "--" + base
        used[base] += 1
        u["id"] = base if used[base] == 1 else f"{base}-{used[base]}"

    # Part-level prerequisites: other parts of the cluster, and the clusters
    # its cut edges lead to.
    def unit_of_atom(x):
        c = by_key[cluster_of_atom[x]]
        if len(c["parts"]) == 1:
            return c["key"]
        return next(p["key"] for p in c["parts"] if x in p["atoms"])

    for key, u in units.items():
        pre = collections.defaultdict(lambda: {"kinds": set(), "types": set(), "edges": []})
        mine = set(u["atoms"])
        for A, B, evs in ((A, B, evs) for A in u["atoms"] for B, evs in out_edges[A]):
            if B in mine:
                continue
            same_cluster = cluster_of_atom[B] == u["cluster"]
            if B in loose and not same_cluster:
                continue   # a shared CInterop alias, recorded as such
            if u["kind"] == "cluster":
                if same_cluster or (A, B) not in cut:
                    continue
                tgt = cluster_of_atom[B]
            else:
                tgt = unit_of_atom(B) if same_cluster else cluster_of_atom[B]
            if tgt == key:
                continue
            p = pre[tgt]
            for uu, v, kind in evs:
                p["kinds"].add(kind)
                p["types"].add(nodes[v]["path"])
                if len(p["edges"]) < 8:
                    p["edges"].append([nodes[uu]["path"], nodes[v]["path"], kind])
        u["prerequisites"] = {k: {"kinds": sorted(v["kinds"]), "types": sorted(v["types"]), "edges": v["edges"],
                                  "namespaceOnly": set(v["kinds"]) <= {"nests"}} for k, v in sorted(pre.items())}

    # ------------------------------------------------------------ 5b. inheritance
    def all_prereqs(key, seen=None, stack=frozenset()):
        """Every unit `key` needs, transitively, and whether only through nesting."""
        seen = {} if seen is None else seen
        for k, info in units[key]["prerequisites"].items():
            ns_only = info["namespaceOnly"]
            if k in seen:
                seen[k] = seen[k] and ns_only
                continue
            seen[k] = ns_only
            sub = {}
            if k not in stack: all_prereqs(k, sub, stack | {key})
            for kk, v in sub.items():
                if kk == key:
                    continue
                val = ns_only or v
                seen[kk] = seen[kk] and val if kk in seen else val
        return seen

    strength = {"api": 3, "implementation": 2, "nesting": 1}

    def type_of(nid):
        """The type a member belongs to."""
        for e in edges_from[nid]:
            if e["kind"] in ("memberOf", "nestedIn") and e["to"] in nodes:
                return e["to"]
        return None

    part_key = {}
    for c in clusters:
        for p in c["parts"]:
            for x in p["atoms"]:
                part_key[x] = p["key"]

    closure_memo = {}

    def node_closure(x, stack=()):
        """The contingencies using declaration x involves: its own tags;
        its parent's, since a member needs its type (route api) and a nested
        type needs its parent's name (route nesting); and those of the types
        its signature names (route api). A type's other members don't count:
        taking an OwnedFD doesn't involve OwnedFD's Span-based read.
        {cid: (route, weight, via)}"""
        if x in closure_memo:
            return closure_memo[x]
        if x in stack:
            return {}
        out = {}

        def put(cid_, route, w, via):
            cur = out.get(cid_)
            if cur is None or strength[route] > strength[cur[0]] or (route == cur[0] and w > cur[1]):
                out[cid_] = (route, w, via)
        for cid_, w, ev, inherit in node_tags.get(x, ()):
            if inherit:
                put(cid_, "api", w, nodes[x]["path"])
        for e in edges_from[x]:
            r = e["to"]
            if r == x or r not in nodes:
                continue
            route = "nesting" if e["kind"] == "nestedIn" else "api"
            for cid_, (st, w, via) in node_closure(r, stack + (x,)).items():
                put(cid_, min(route, st, key=lambda q: strength[q]), w, via)
        if len(stack) == 0:
            closure_memo[x] = out
        return out

    for key, u in units.items():
        pre = all_prereqs(key)
        u["allPrerequisites"] = {k: {"namespaceOnly": v} for k, v in sorted(pre.items())}
        # Implementation prerequisites: new public API of other units that
        # this unit's bodies use (KernelQueue keeps an OwnedFD, say), which
        # no signature shows.
        ip = collections.defaultdict(list)
        mine_nodes = set(u["nodes"])
        for nid in u["nodes"]:
            for used in nodes[nid].get("implUses", ()):
                A = node_atom.get(used)
                if A is None or A in loose or used in mine_nodes:
                    continue
                ck = cluster_of_atom[A]
                if ck == u["cluster"] and u["kind"] == "cluster":
                    continue
                tgt = ck if ck != u["cluster"] else unit_of_atom(A)
                if tgt == key or tgt in pre:
                    continue
                if len(ip[tgt]) < 6:
                    ip[tgt].append([nodes[nid]["path"], nodes[used]["path"]])
        u["implPrerequisites"] = dict(sorted(ip.items()))
        # Inherited: what each declaration this unit uses from outside
        # involves (node_closure), by the route it's used through.
        inh = {}
        outside = collections.defaultdict(set)   # node -> routes it's reached by
        for nid in u["nodes"]:
            for e in edges_from[nid]:
                t = e["to"]
                if t in nodes and t not in mine_nodes:
                    outside[t].add("nesting" if e["kind"] == "nestedIn" else "api")
            for used in nodes[nid].get("implUses", ()):
                if used not in mine_nodes and node_atom.get(used) not in loose:
                    outside[used].add("implementation")
        for t, routes in outside.items():
            route = max(routes, key=lambda r: strength[r])
            for cid_, (st, w, via) in node_closure(t).items():
                if cid_ in u["direct"]:
                    continue
                through = min(route, st, key=lambda r: strength[r])
                cur = inh.get(cid_)
                if cur is None or strength[through] > strength[cur["through"]] or (
                        through == cur["through"] and w > cur["weight"]):
                    inh[cid_] = {"via": via, "through": through, "weight": w, "namespaceOnly": through == "nesting"}
        u["inherited"] = dict(sorted(inh.items()))
        u["cyclic"] = key in pre

    # ------------------------------------------------------------ 6. ranking
    def score(u):
        m = u["metrics"]
        parts = []

        def add(label, value):
            if value:
                parts.append((label, round(value, 1)))
        add("declarations", W["declaration"] * m["declarations"])
        add("types", W["type"] * m["types"])
        add("undocumented", W["undocumented"] * (m["declarations"] - m["documented"]))
        add("untested", W["untested"] * (m["declarations"] - m["tested"]))
        add("off-Darwin-only code", W["offDarwinOnly"] * m["offDarwinOnly"])
        add("unverified platforms", W["unverifiedPlatforms"] * (1 if m["unverifiedOffDarwin"] else 0))
        add("platform variants", W["platformVariant"] * max(0, m["platformVariants"] - 1))
        add("availability oddities", W["availabilityOddity"] * len(m["availabilityOddities"]))
        for cid_, info in u["direct"].items():
            add(f"open: {cont_by_id[cid_]['title']}", W["contingency"] * info["weight"])
        for cid_, info in u["inherited"].items():
            w = {"api": W["inheritedContingency"], "implementation": W["implementationContingency"],
                 "nesting": W["namespaceContingency"]}[info["through"]]
            add(f"inherits {cont_by_id[cid_]['title']} via {info['via']} ({info['through']})", w * info["weight"])
        add("prerequisites", W["prerequisite"] * len(u["allPrerequisites"]))
        if any(p["kind"] == "proposal" and p["score"] >= 5 for p in u["prior"]):
            add("prior proposal", W["priorProposal"])
        u["openScore"] = round(sum(v for k, v in parts if k.startswith(("open:", "inherits "))), 1)
        u["effortScore"] = round(sum(v for k, v in parts if not k.startswith(("open:", "inherits "))), 1)
        return round(sum(v for _, v in parts), 1), parts

    def reason(u):
        m = u["metrics"]
        bits = []
        n = m["declarations"]
        bits.append(f"{n} declaration{'s' if n != 1 else ''}" + (f" ({m['types']} type{'s' if m['types'] != 1 else ''})"
                                                                  if m["types"] else "")
                    + (f", plus {m['stubs']} fix-it stub{'s' if m['stubs'] != 1 else ''}" if m["stubs"] else ""))
        if not u["direct"] and not u["inherited"]:
            bits.append("no open questions")
        else:
            opens = [cont_by_id[k]["title"] for k in u["direct"]]
            inh = [f"{cont_by_id[k]['title']} (via {v['via']}"
                   + {"api": "", "implementation": ", implementation only", "nesting": ", nesting only"}[v["through"]]
                   + ")" for k, v in u["inherited"].items()]
            if opens:
                bits.append("open: " + ", ".join(opens))
            if inh:
                bits.append("inherits: " + ", ".join(inh))
        doc = m["documented"]
        bits.append("all documented" if doc == n else f"{n - doc} undocumented")
        bits.append("all tested" if m["tested"] == n else f"{m['tested']}/{n} tested")
        if not m["darwin"]:
            bits.append("not compiled on Darwin: " + ", ".join(m["platforms"]))
        elif m["unverifiedOffDarwin"]:
            bits.append("unverified on " + ", ".join(m["unverifiedOffDarwin"]))
        elif m["platforms"] == ["Darwin"]:
            bits.append("Darwin only")
        if u["allPrerequisites"]:
            bits.append("needs " + ", ".join(units[k]["id"] for k in u["allPrerequisites"]))
        if u["implPrerequisites"]:
            bits.append("its implementation uses " + ", ".join(units[k]["id"] for k in u["implPrerequisites"]))
        if u["prior"]:
            pp = [p["file"] for p in u["prior"] if p["kind"] == "proposal"]
            if pp:
                bits.append("prior text: " + ", ".join(pp))
        return "; ".join(bits)

    # Batches: contingency-free clusters that only add members to one
    # vocabulary type in one file (FileOperations.swift's wrappers, say).
    # Each is small alone; together they're one pitch, and they're ranked as
    # one, in place of their clusters.
    batch_groups = collections.defaultdict(list)
    for c in clusters:
        u = c["unit"]
        if u["types"] or u["direct"] or u["inherited"] or u["allPrerequisites"] or u["implPrerequisites"]:
            continue
        subjects = {atoms[x]["subject"] for x in c["atoms"] if not atoms[x]["loose"]}
        files = {atoms[x]["file"] for x in c["atoms"] if not atoms[x]["loose"]}
        if len(subjects) == 1 and len(files) == 1:
            batch_groups[(next(iter(subjects)), next(iter(files)))].append(c["key"])
    batched = {}
    for bi, ((subject, f), keys) in enumerate(sorted(batch_groups.items())):
        if len(keys) < 2:
            continue
        bk = f"b{bi}"
        member_atoms = [x for k in keys for x in units[k]["atoms"]]
        bu = new_unit("batch", member_atoms, None)
        wrapped = list(dict.fromkeys(cn for k in sorted(keys, key=lambda k: units[k]["atoms"][0])
                                     for cn in units[k]["metrics"]["cNames"]))
        bu["name"] = f"{subject}: {len(keys)} wrappers in {os.path.basename(f)}"
        bu["id"] = slug(f"{subject} {os.path.splitext(os.path.basename(f))[0]} batch")
        bu["members"] = sorted(keys)
        bu["wraps"] = wrapped
        bu["prerequisites"], bu["allPrerequisites"], bu["implPrerequisites"] = {}, {}, {}
        bu["inherited"], bu["cyclic"] = {}, False
        units[bk] = bu
        for k in keys:
            batched[k] = bk

    for key, u in units.items():
        u["score"], u["scoreParts"] = score(u)
        u["reason"] = reason(u)
        if u["kind"] == "batch":
            u["reason"] = (f"{len(u['members'])} independent clusters ("
                           + ", ".join(units[k]["id"] for k in sorted(u["members"], key=lambda k: units[k]["score"]))
                           + "); " + u["reason"])

    candidates = []
    for c in clusters:
        u = c["unit"]
        if c["key"] not in batched:
            candidates.append(c["key"])
        if len(c["parts"]) > 1 and u["metrics"]["declarations"] > cfg["partsForClustersOver"]:
            for p in c["parts"]:
                candidates.append(p["key"])
    candidates += sorted(k for k, u in units.items() if u["kind"] == "batch")
    cand_set = set(candidates)

    def as_candidate(k):
        if k in cand_set:
            return k
        if k in batched:
            return batched[k]
        return units[k]["cluster"] if units[k]["cluster"] in cand_set else None
    needs = {k: {as_candidate(p) for p in units[k]["allPrerequisites"]} - {None, k} for k in candidates}
    # Open questions first, whatever the size; then effort.
    order_key = {k: (units[k]["openScore"], units[k]["effortScore"], units[k]["metrics"]["declarations"], units[k]["id"])
                 for k in candidates}
    placed, ordered = set(), []
    remaining = set(candidates)
    while remaining:
        ready = [k for k in remaining if needs[k] <= placed]
        # A prerequisite cycle: break it at the easiest candidate.
        pick = min(ready or remaining, key=lambda k: order_key[k])
        ordered.append(pick)
        placed.add(pick)
        remaining.discard(pick)
    candidates = ordered
    for r, k in enumerate(candidates, 1):
        units[k]["rank"] = r
    for k, bk in batched.items():
        units[k]["rank"] = units[bk]["rank"]
        units[k]["batch"] = units[bk]["id"]

    # ------------------------------------------------------------ output
    def unit_out(key):
        u = units[key]
        out = {k: v for k, v in u.items() if k not in ("atoms",)}
        out["key"] = key
        out["atoms"] = u["atoms"]
        out["prerequisites"] = {units[k]["id"]: v for k, v in u["prerequisites"].items()}
        out["allPrerequisites"] = {units[k]["id"]: v for k, v in u["allPrerequisites"].items()}
        out["implPrerequisites"] = {units[k]["id"]: v for k, v in u["implPrerequisites"].items()}
        out["cluster"] = units[u["cluster"]]["id"] if u["cluster"] else None
        if u["kind"] == "batch":
            out["members"] = [units[k]["id"] for k in u["members"]]
        return out

    dependents = collections.defaultdict(set)
    for key, u in units.items():
        for k in u["prerequisites"]:
            dependents[k].add(units[key]["id"])
    out_clusters = []
    for c in clusters:
        cu = unit_out(c["key"])
        cu["dependents"] = sorted(dependents.get(c["key"], ()))
        cu["parts"] = [dict(unit_out(p["key"]), dependents=sorted(dependents.get(p["key"], ())))
                       for p in c["parts"]] if len(c["parts"]) > 1 else []
        cu["sharedAliases"] = []
        for L in c["atoms"]:
            if L in loose:
                others = [units[root_cluster[k]]["id"] for k in loose_users.get(L, {})
                          if root_cluster.get(k) != c["key"]]
                if others:
                    cu["sharedAliases"].append({"alias": nodes[atoms[L]["nodes"][0]]["path"], "alsoUsedBy": others})
        cu["vocabulary"] = dict(sum((atom_vocab[x] for x in c["atoms"]), collections.Counter()).most_common(12))
        out_clusters.append(cu)
    out_clusters.sort(key=lambda c: c["rank"])

    json.dump({
        "config": cfg,
        "contingencies": conts,
        "promoted": [dict(v, cluster=units[cluster_of_atom[node_atom[k]]]["id"]) for k, v in
                     sorted(promoted.items(), key=lambda kv: kv[1]["type"])],
        "clusters": out_clusters,
        "candidates": [{"id": units[k]["id"], "kind": units[k]["kind"],
                        "cluster": units[units[k]["cluster"]]["id"] if units[k]["cluster"] else None,
                        "name": units[k]["name"], "rank": units[k]["rank"], "score": units[k]["score"],
                        "openScore": units[k]["openScore"], "effortScore": units[k]["effortScore"],
                        "reason": units[k]["reason"], "declarations": units[k]["metrics"]["declarations"]}
                       for k in candidates],
        "batches": [unit_out(k) for k in sorted(units) if units[k]["kind"] == "batch"],
        "gists": gists,
        "attached": [dict(x, into=units[cluster_of_atom[x["into"]]]["id"]) for x in attached_info],
        "aliasAttachment": {nodes[atoms[L]["nodes"][0]]["path"]: v for L, v in sorted(loose_via.items())},
        "nodeTags": {k: v for k, v in node_tags.items()},
    }, open(a.out, "w"), indent=1, default=lambda o: sorted(o) if isinstance(o, set) else str(o))
    print(f"cluster: {len(promoted)} promoted types, {len(clusters)} clusters, "
          f"{sum(len(c['parts']) for c in clusters if len(c['parts']) > 1)} parts in multi-part clusters, "
          f"{len(candidates)} ranked carve-outs -> {a.out}")


if __name__ == "__main__":
    main()
