#!/usr/bin/env python3
"""What a set of declarations adds up to, for any carve-out: an automatic
cluster, part or batch (cluster.py) or a hand-curated pitch (pitches.py).

  tag_nodes       the open design questions (contingencies.json) each
                  declaration raises, with the evidence
  load_verified   what's been checked off Darwin (evidence.json), by file
  Prior           prior text (proposals, prototype write-ups, Win32 drafts)
                  that names a set's types or C calls, and the gists it cites
  metrics         a set's size, documentation, tests, samples, platforms,
                  availability and C API
  direct_tags     a set's own open questions, from its declarations' tags

The functions take build_graph.py's graph.json nodes.
"""

import collections
import os
import re

PLATFORM_ORDER = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
# C calls that multiplex many operations, which prose mentions in passing.
GENERIC_C = {"fcntl", "ioctl", "sysctl", "open", "openat", "close", "read", "write", "stat", "fstat", "lstat"}
# Names that identify a unit in prose: its new types' last components and C
# names, when they're distinctive enough not to match everything.
COMMON_WORDS = {"Flags", "Options", "Kind", "Entry", "Info", "ID", "Attributes", "Name", "Mode", "Event",
                "Events", "Order", "Action", "Queue", "Scheduling", "Filter", "Message", "Key", "Parity"}


def is_api(n):
    return n["hiddenClass"] != "unavailable"


def throwing_closure(n):
    d = n["decl"]
    return (re.search(r"\)\s*(async\s+)?throws(\([^)]*\))?\s*(->|$|where)", d) is not None
            and re.search(r":\s*(@\w+\s+)*\((?:[^()]|\([^()]*\))*\)\s*(async\s+)?throws(\([^)]*\))?\s*->", d)
            is not None and "rethrows" not in d)


def tag_nodes(nodes, edges, vocab, conts, drafts):
    """{nid: [(contingency id, weight, evidence, inherits)]}"""
    node_tags = collections.defaultdict(list)
    edges_from = collections.defaultdict(list)
    for e in edges:
        edges_from[e["from"]].append(e)

    def target_path(t):
        return nodes[t]["path"] if t in nodes else vocab.get(t, {}).get("path", t)

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
                    raise SystemExit(f"units: unknown rule kind {k!r} in contingency {c['id']}")
                if hit and not (k == "platform" and n["hiddenClass"] == "unavailable"):
                    ev = r["evidence"].format(path=n["path"], **extra)
                    if r.get("draft") and drafts:
                        ev += f" ({os.path.join(os.path.basename(drafts), r['draft'])})"
                    node_tags[nid].append((c["id"], r.get("weight", 1), ev, r.get("inherit", True)))
    return node_tags


def load_verified(evidence_cfg, root):
    """{file: [{platforms, level, source, detail}]}"""
    verified = collections.defaultdict(list)
    for src in evidence_cfg:
        files = []
        if src["kind"] == "script":
            p = os.path.join(root, src["path"])
            if os.path.exists(p):
                files = sorted(set(re.findall(r"[\"']((?:Sources|Tests)/[^\"']+\.swift)[\"']", open(p).read())))
        elif src["kind"] == "files":
            files = src["files"]
        for f in files:
            verified[f].append({"platforms": src["platforms"], "level": src["level"],
                                "source": src.get("path", src.get("name", "?")), "detail": src.get("detail", "")})
    return verified


class Prior:
    """The prior text a set of declarations can draw on."""

    def __init__(self, root, drafts):
        docs = []
        for rel in sorted(os.listdir(os.path.join(root, "Proposals"))) if os.path.isdir(
                os.path.join(root, "Proposals")) else []:
            if rel.endswith(".md"):
                docs.append(("proposal", os.path.join("Proposals", rel), os.path.join(root, "Proposals", rel)))
        for d in sorted(os.listdir(os.path.join(root, "Prototype"))) if os.path.isdir(
                os.path.join(root, "Prototype")) else []:
            p = os.path.join(root, "Prototype", d, "README.md")
            if os.path.exists(p):
                docs.append(("prototype", os.path.join("Prototype", d, "README.md"), p))
        if drafts:
            for rel in sorted(os.listdir(drafts)):
                if rel.endswith(".md"):
                    docs.append(("draft", os.path.join(os.path.basename(drafts), rel), os.path.join(drafts, rel)))
        text = {rel: open(p, encoding="utf-8").read() for _, rel, p in docs}
        self.words = {rel: collections.Counter(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", t)) for rel, t in text.items()}
        self.kind = {rel: k for k, rel, _ in docs}
        gist_re = re.compile(r"https?://gist\.github(?:usercontent)?\.com/[^\s)>\"'`]+")
        self.gists = sorted({m for t in text.values() for m in gist_re.findall(t)})

    def matches(self, nodes, node_ids):
        names = set()
        for nid in node_ids:
            n = nodes[nid]
            if n["isType"]:
                last = n["path"].split(".")[-1]
                if last not in COMMON_WORDS and len(last) > 3:
                    names.add(last)
            for c in n["cNames"]:
                if len(c) > 3 and c not in GENERIC_C:
                    names.add(c)
        out = []
        for rel, words in self.words.items():
            # In name order, so ties list alike from run to run (a set's
            # order changes with the hash seed).
            hits = collections.Counter({nm: words[nm] for nm in sorted(names) if words.get(nm)})
            score = sum(min(v, 10) for v in hits.values())
            if score >= 3 and (len(hits) >= 2 or max(hits.values()) >= 5):
                out.append({"file": rel, "kind": self.kind[rel], "score": score,
                            "names": [k for k, _ in hits.most_common(6)]})
        out.sort(key=lambda x: (-x["score"], x["file"]))
        return out[:6]


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


def metrics(nodes, tests_by_id, verified, node_ids):
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
        "mockTests": sorted(t for t in tests if tests_by_id.get(t, {}).get("mock")),
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


def direct_tags(node_tags, nids):
    """A set's own open questions: {contingency: {weight, count, inheritWeight, evidence}}"""
    direct = collections.defaultdict(list)
    for i in nids:
        for cid_, w, ev, inherit in node_tags.get(i, ()):
            direct[cid_].append((w, ev, inherit))
    return {k: {"weight": max(w for w, _, _ in v), "count": len(v),
                "inheritWeight": max((w for w, _, inh in v if inh), default=0),
                "evidence": list(dict.fromkeys(ev for _, ev, _ in v))[:6]} for k, v in sorted(direct.items())}
