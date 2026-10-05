#!/usr/bin/env python3
"""Check that the burn-down page can be trusted, without a quota: what a
reviewer would otherwise do by hand after each regenerate.sh. It reads
burndown.json, the page, api-delta.json, the API graph, the SDK and the
adopters' clones, and never imports burndown.py.

Each check prints pass, warn or fail lines:

  1 freshness (warns): the commits burndown.json records for the head ref,
    the base ref, api-delta and the API graph, against those refs now; each
    adopter branch the graph's usedBy came from, against its head now; how
    far the base ref is behind the upstream ref, and when that was last
    fetched (its reflog, and FETCH_HEAD's time if it names the branch).
    Nothing is fetched.
  2 sums (fails): the page is this burndown.json's; the totals add up; the
    page's rows, by state and in each of its groupings (header, area, pitch,
    platform, kind, reach), with and without the declarations outside the
    count, add up to them.
  3 recount (fails): api-delta.json's added declarations, counted here by
    module, kind and kind name, against burndown.json and the page.
  4 sites (fails on a miss): a seeded sample of usedBy sites. Each line,
    read with `git show <branch>:<file>` from the adopter's clone, has the
    declaration's name on it (an init: its type's name or `.init`).
  5 C names (fails on a miss): a seeded sample of declarations with a
    header: the header the page shows declares the C name, and the SDK
    vocabulary puts the name in the page's module; and a sample of
    declarations with a C name from the code: the graph has that link, from
    the code only, and the name is in the code the declaration reaches (its
    own lines and the new internal code the graph records, then any internal
    code they name, read from git; mock hooks left out).

A miss that a known cause explains (KNOWN) doesn't fail: a cause in the
checking method passes, and a known error in the page, which
Prototype/Burndown/VERIFY-REPORT.md records until it's fixed, warns. Every
miss is listed. README.md in this directory ("Verify") says what each check
catches and what it can't.

Usage: verify.py --repo R --burndown F [--page HTML] [--sample N|all] [--seed S]
                 [--report verify.md] [options]
Exits 1 if any line fails.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import datetime  # noqa: E402
import glob  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import random  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

LEVELS = ("pass", "warn", "fail")
CHECKS = {1: "freshness", 2: "sums", 3: "recount", 4: "sites", 5: "C names"}
STATES = (1, 2, 3, 4, 5)
# The page's own labels (page.js), which aren't data.
UNKNOWN, NO_PITCH = "(unknown)", "(no pitch)"
# Headers that aren't files: what the page shows instead of one.
SPECIAL_HEADERS = {"(no C name)", "Swift-only", "(not on Darwin)", "(not in the macOS SDK)"}
NO_MODULE = "(in no SDK module)"
DEFAULT_SAMPLE = 25

# Why a miss isn't a failure. A `method` cause is in how a check looks
# (the page is right); an `error` is a real error in the page, recorded in
# VERIFY-REPORT.md, which warns until it's fixed and its rule matches
# nothing. Each check's classify function names the causes it can find.
KNOWN = {
    "branch-moved": (4, "method", "the adopter's branch has moved since the graph read it; at the commit the graph "
                                  "read, the line has the name"),
    "init-through-alias": (4, "method", "an initializer called through a typealias of its type (`CInterop.TimeSpec("
                                        "…)` for `timespec.init`, NIO's `IOVector(…)` for `iovec.init`), which the "
                                        "adopter's branch or System declares"),
    "vocab-forward-declaration": (5, "method", "the vocabulary puts a struct, union or enum in the module of its "
                                               "first declaration, a forward one; the page's header defines it"),
    "vocab-parent-module": (5, "method", "the vocabulary puts the name in a parent of the page's module: its "
                                         "header is in no module, and a header of the page's module includes it"),
    "header-in-no-module": (5, "method", "the page's header is in no SDK module, so the vocabulary, which is by "
                                         "module, has no entry for the page's module"),
    "macro-not-indexed": (5, "method", "a macro the index didn't record, so the vocabulary hasn't got it; the "
                                       "page's header defines it"),
}

COMMENT_RE = re.compile(r"/\*.*?\*/|//[^\n]*", re.S)
IDENT_RE = re.compile(r"[A-Za-z_]\w*")
PAGE_DATA_RE = re.compile(r'<script id="burndown-data" type="application/json">(.*?)</script>', re.S)
TAG_KINDS = (1 << 5) | (1 << 6) | (1 << 10)   # enum, struct, union, as vocab.py records them
OPERATOR_CHARS = set("/=-+!*%<>&|^~?.")


def load_json(path):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def fmt(n):
    return f"{n:,}"


def short(c):
    return (c or "?")[:10]


class Report:
    """The lines (check, level, text), and each check's details, in Markdown."""

    def __init__(self):
        self.lines = []
        self.details = collections.defaultdict(list)

    def add(self, check, level, text):
        assert level in LEVELS
        self.lines.append((check, level, text))

    def detail(self, check, text):
        self.details[check].append(text)

    def count(self, level):
        return sum(1 for _, lv, _ in self.lines if lv == level)

    def failed(self):
        return self.count("fail") > 0


# ------------------------------------------------------------------ git

class Git:
    """Reads one repository: refs, counts, files at a commit. Nothing that
    writes, and nothing that fetches."""

    def __init__(self, path):
        self.path = path
        self.blobs = {}

    def run(self, *args):
        r = subprocess.run(["git", "-C", self.path, *args], capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else None

    def rev(self, ref):
        out = self.run("rev-parse", "--verify", "--quiet", ref + "^{commit}")
        return out.strip() if out else None

    def count(self, a, b):
        """How many commits b has that a hasn't."""
        out = self.run("rev-list", "--count", f"{a}..{b}")
        return int(out.strip()) if out else None

    def is_ancestor(self, a, b):
        return subprocess.run(["git", "-C", self.path, "merge-base", "--is-ancestor", a, b],
                              capture_output=True).returncode == 0

    def show(self, ref, file):
        """A file's text at a ref, or None."""
        key = (ref, file)
        if key not in self.blobs:
            r = subprocess.run(["git", "-C", self.path, "show", f"{ref}:{file}"], capture_output=True)
            self.blobs[key] = r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None
        return self.blobs[key]

    def show_many(self, ref, files):
        """{file: text} for files at a ref, in one `git cat-file --batch`."""
        want = [f for f in files if (ref, f) not in self.blobs]
        if want:
            r = subprocess.run(["git", "-C", self.path, "cat-file", "--batch"],
                               input="".join(f"{ref}:{f}\n" for f in want).encode(), capture_output=True)
            out, i = r.stdout, 0
            for f in want:
                nl = out.index(b"\n", i)
                header = out[i:nl].split()
                i = nl + 1
                if len(header) == 3 and header[1] == b"blob":
                    size = int(header[2])
                    self.blobs[(ref, f)] = out[i:i + size].decode("utf-8", "replace")
                    i += size + 1
                else:
                    self.blobs[(ref, f)] = None
        return {f: self.blobs[(ref, f)] for f in files}

    def ls(self, ref, *dirs):
        out = self.run("ls-tree", "-r", "--name-only", ref, *dirs)
        return out.split("\n")[:-1] if out else []

    def reflog_date(self, ref):
        """When the ref last moved, from its reflog: an aware datetime, or None."""
        out = self.run("reflog", "show", "-n1", "--date=iso-strict", "--format=%gd", ref)
        m = re.search(r"@\{([^}]+)\}", out or "")
        try:
            return datetime.datetime.fromisoformat(m.group(1)) if m else None
        except ValueError:
            return None

    def fetch_head_date(self, branch):
        """FETCH_HEAD's time, if it records a fetch of the branch."""
        common = self.run("rev-parse", "--path-format=absolute", "--git-common-dir")
        path = os.path.join(common.strip(), "FETCH_HEAD") if common else None
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            if f"branch '{branch}' of" not in text:
                return None
            return datetime.datetime.fromtimestamp(os.path.getmtime(path)).astimezone()
        except (OSError, TypeError):
            return None


# ------------------------------------------------------------------ inputs

def page_data(path):
    """The data the page embeds, or None."""
    try:
        with open(path, encoding="utf-8") as f:
            html = f.read()
    except OSError:
        return None
    m = PAGE_DATA_RE.search(html)
    return json.loads(m.group(1)) if m else None


def page_rows(pd):
    """The page's rows as page.js decodes them (the fields the checks use)."""
    S = pd["S"]

    def s(i):
        return None if i is None or i < 0 else S[i]
    return [{"state": r[0], "module": s(r[2]), "path": r[3], "kind": s(r[4]), "area": s(r[5]), "plat": r[8],
             "pitch": s(r[9]), "cname": s(r[11]), "header": s(r[12]), "reach": len(r[18]), "excluded": r[22] == 1}
            for r in pd["D"]]


def body_digest(data):
    """The digest burndown.py gives its output: of everything but the digest."""
    body = json.dumps({k: v for k, v in data.items() if k != "digest"}, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(body.encode()).hexdigest()


class GraphView:
    """The API graph the page was made from: its nodes, links by source, and
    package nodes by name."""

    def __init__(self, doc):
        self.meta = doc.get("meta") or {}
        self.nodes = doc["nodes"]
        self.out = collections.defaultdict(list)
        for ln in doc["links"]:
            self.out[ln["from"]].append(ln)
        self.packages = {}
        for nid, n in self.nodes.items():
            name = n.get("name") or nid.split(":", 1)[-1]
            # A name two packages share: the one with a migration branch.
            if n["kind"] == "package" and (name not in self.packages or n.get("adopted")):
                self.packages[name] = n
        self.by_path = collections.defaultdict(list)
        for nid, n in self.nodes.items():
            if n["kind"] == "declaration" and n.get("origin") == "head":
                self.by_path[(n.get("module"), n.get("path"))].append(nid)

    def nodes_of(self, u):
        """A declaration's candidate nodes: its USR's; else its scan node, or
        every head node with its module and path (per-platform variants)."""
        if u.get("usr") in self.nodes:
            return [u["usr"]]
        sid = f"scan:{u['module']}:{u['path']}"
        if sid in self.nodes:
            return [sid]
        return list(self.by_path.get((u["module"], u["path"]), []))


def find_graph(data, given, store):
    """(graph document, where) for the graph burndown.json names: the given
    file, else the recorded path if it's still that commit's, else the
    snapshot store's copy."""
    gm = data["meta"].get("graph") or {}
    want = gm.get("headCommit")
    cands = [given] if given else [gm.get("path")] + ([os.path.join(store, f"{want}.json.gz")] if store and want else [])
    for path in cands:
        if path and os.path.exists(path):
            doc = load_json(path)
            if given or (doc.get("meta") or {}).get("headCommit") == want:
                return doc, path
    return None, None


# ------------------------------------------------------------------ 1 freshness

def ref_line(rep, git, ref, recorded, what):
    cur = git.rev(ref)
    if not cur:
        rep.add(1, "warn", f"{ref}: can't resolve it here, to compare {what} at {short(recorded)}")
    elif cur == recorded:
        rep.add(1, "pass", f"{ref}: {what} is at its head, {short(cur)}")
    elif git.is_ancestor(recorded, cur):
        n = git.count(recorded, cur)
        rep.add(1, "warn", f"{ref}: {what} is at {short(recorded)}, {fmt(n)} commit{'s' * (n != 1)} behind its "
                           f"head {short(cur)}")
    else:
        rep.add(1, "warn", f"{ref}: {what} is at {short(recorded)}, which isn't in its history now (head "
                           f"{short(cur)})")
    return cur


def check_freshness(rep, data, delta, graph, git, upstream, now, fetch_age_days, siblings=None):
    m = data["meta"]
    head_ref, base_ref = m["headRef"], m["baseRef"]
    ref_line(rep, git, head_ref, m["headCommit"], "the page")
    ref_line(rep, git, base_ref, m["baseCommit"], "the page's base")
    if delta is None:
        rep.add(1, "warn", "api-delta: no api-delta.json to compare")
    else:
        dm = delta["meta"]
        if (dm["baseCommit"], dm["headCommit"]) != (m["baseCommit"], m["headCommit"]):
            rep.add(1, "warn", f"api-delta: it compares {short(dm['baseCommit'])}..{short(dm['headCommit'])}, the "
                               f"page {short(m['baseCommit'])}..{short(m['headCommit'])}")
        else:
            ref_line(rep, git, head_ref, dm["headCommit"], "api-delta")
    if graph is None:
        rep.add(1, "warn", "graph: not found, so the adopters' branches aren't compared")
    else:
        ref_line(rep, git, head_ref, graph.meta.get("headCommit"), "the graph")
        same, moved = [], []
        for name, p in sorted(graph.packages.items(), key=lambda x: x[0].lower()):
            ad = p.get("adopted")
            if not ad:
                continue
            clone = ad.get("path")
            if not (clone and os.path.isdir(clone)) and siblings and ad.get("dir"):
                clone = os.path.join(siblings, "adopters", ad["dir"])
            if not (clone and os.path.isdir(clone)):
                rep.add(1, "warn", f"{name}: no clone at {ad.get('path')}, to compare {ad['branch']}")
                continue
            ag = Git(clone)
            cur = ag.rev(ad["branch"])
            if cur == ad["commit"]:
                same.append(name)
            elif not cur:
                rep.add(1, "warn", f"{name}: no {ad['branch']} in {clone}; the graph read {short(ad['commit'])}")
            else:
                n = ag.count(ad["commit"], cur)
                moved.append(name)
                rep.add(1, "warn", f"{name}: {ad['branch']} is at {short(cur)}, "
                                   + (f"{fmt(n)} commit{'s' * (n != 1)} past" if n and ag.is_ancestor(ad["commit"], cur)
                                      else "not a descendant of")
                                   + f" the graph's {short(ad['commit'])}, so its usedBy sites may have moved")
        if same:
            rep.add(1, "pass", (f"adopters: {len(same)} of the graph's {len(same) + len(moved)} migration branches are"
                                if moved else f"adopters: the graph's {len(same)} migration branches are")
                    + " where it read them")
    if not upstream:
        return
    up, base = git.rev(upstream), git.rev(base_ref)
    if not up or not base:
        rep.add(1, "warn", f"{upstream}: can't resolve it (or {base_ref}) here")
        return
    behind = git.count(base, up)
    branch = upstream.split("/", 1)[-1]
    dates = [d for d in (git.reflog_date(upstream), git.fetch_head_date(branch)) if d]
    last = max(dates) if dates else None
    age = (now - last).days if last else None
    when = f"last fetched {last.date().isoformat()}, {age} day{'s' * (age != 1)} ago" if last else \
        "with no record of when it was fetched"
    recorded = m.get("upstream") or {}
    flagged = recorded.get("declarations")
    text = (f"{base_ref} has everything in {upstream}" if behind == 0 else
            f"{base_ref} is {fmt(behind)} commit{'s' * (behind != 1)} behind {upstream}"
            + (f" (the page flags {fmt(flagged)} declarations upstream)" if flagged else "")) + f"; {upstream} was {when}"
    stale = last is None or age > fetch_age_days
    flags_old = recorded.get("commit") and recorded.get("ref") == upstream and recorded["commit"] != up
    rep.add(1, "warn" if behind or stale or flags_old else "pass",
            text + (f", over {fetch_age_days} days" if stale and last else "")
            + (f"; the page's upstream flags are from {short(recorded['commit'])}, before it moved" if flags_old
               else ""))


# ------------------------------------------------------------------ 2 sums

def view_keys(view, row, platforms):
    """A row's keys in one of the page's groupings, as page.js computes them."""
    if view == "header":
        return [row["header"] or UNKNOWN]
    if view == "area":
        return [row["area"] or UNKNOWN]
    if view == "pitch":
        return [row["pitch"] or NO_PITCH]
    if view == "platform":
        return [p for b, p in enumerate(platforms) if row["plat"] & (1 << b)]
    if view == "kind":
        return [row["kind"] or UNKNOWN]
    if view == "reach":
        return ["No packages" if row["reach"] == 0 else f"{fmt(row['reach'])} package{'s' * (row['reach'] != 1)}"]
    raise ValueError(view)


VIEWS = ("header", "area", "pitch", "platform", "kind", "reach")


def aggregate(rows, keys):
    groups = {}
    for r in rows:
        for k in keys(r):
            g = groups.setdefault(k, {"n": 0, "by": collections.Counter(), "rows": []})
            g["n"] += 1
            g["by"][r["state"]] += 1
            g["rows"].append(r)
    return groups


def sum_problems(rows, groups, overlapping, by_state, platforms_of=None):
    """Why a grouping's counts don't add up to its rows', or []."""
    probs = []
    for k, g in groups.items():
        if sum(g["by"][s] for s in STATES) != g["n"]:
            probs.append(f"group {k!r}: {fmt(g['n'])} declarations, but its states add up to "
                         f"{fmt(sum(g['by'][s] for s in STATES))}")
    if overlapping:
        none = [r for r in rows if not platforms_of(r)]
        if none:
            probs.append(f"{fmt(len(none))} declarations are in no group, such as {none[0]['path']}")
        want = sum(len(platforms_of(r)) for r in rows)
        if sum(g["n"] for g in groups.values()) != want:
            probs.append(f"the groups add up to {fmt(sum(g['n'] for g in groups.values()))}, the rows' platforms "
                         f"to {fmt(want)}")
    else:
        total = sum(g["n"] for g in groups.values())
        if total != len(rows):
            probs.append(f"the groups add up to {fmt(total)}, not {fmt(len(rows))}")
        for s in STATES:
            got = sum(g["by"][s] for g in groups.values())
            if got != by_state[s]:
                probs.append(f"state {s}: the groups add up to {fmt(got)}, not {fmt(by_state[s])}")
    return probs


def check_sums(rep, data, pd, page_path):
    t = data["totals"]
    decls, merged = data["declarations"], data["merged"]
    # The page is this burndown.json's, which is as burndown.py wrote it.
    probs = []
    if data.get("digest") != body_digest(data):
        probs.append("burndown.json's digest isn't its content's: it was changed after burndown.py wrote it")
    if pd is None:
        probs.append(f"no burn-down data in {page_path}")
    elif pd.get("digest") != data.get("digest"):
        probs.append(f"the page embeds digest {short(pd.get('digest'))}, burndown.json has {short(data.get('digest'))}")
    rep.add(2, "fail" if probs else "pass", "page: " + ("; ".join(probs) if probs else
            f"it embeds this burndown.json's data, digest {short(data['digest'])}"))
    # The totals.
    probs = []
    for part, count in (("main", "mainCount"), ("outside", "outsideCount")):
        if sum(t[part].get(str(s), 0) for s in STATES) != t[count]:
            probs.append(f"the {part} states add up to {fmt(sum(t[part].get(str(s), 0) for s in STATES))}, "
                         f"not {count} {fmt(t[count])}")
    if t["declarations"] != len(decls) or t["merged"] != len(merged):
        probs.append(f"totals say {fmt(t['declarations'])} declarations and {fmt(t['merged'])} merged; the lists "
                     f"have {fmt(len(decls))} and {fmt(len(merged))}")
    if t["mainCount"] + t["outsideCount"] != len(decls) + len(merged):
        probs.append(f"{fmt(t['mainCount'])} in the main count + {fmt(t['outsideCount'])} outside isn't "
                     f"{fmt(len(decls))} declarations + {fmt(len(merged))} merged")
    rep.add(2, "fail" if probs else "pass", "totals: " + ("; ".join(probs) if probs else
            f"{fmt(t['mainCount'])} in the main count + {fmt(t['outsideCount'])} outside = "
            f"{fmt(len(decls))} declarations + {fmt(len(merged))} merged, and each adds up by state"))
    if pd is None:
        return
    # The page's rows: the tiles count them.
    rows = page_rows(pd)
    probs = []
    if len(rows) != len(decls) + len(merged):
        probs.append(f"the page has {fmt(len(rows))} rows, not {fmt(len(decls) + len(merged))}")
    bad = [r for r in rows if r["state"] not in STATES]
    if bad:
        probs.append(f"{fmt(len(bad))} rows have no state 1-5, such as {bad[0]['path']} ({bad[0]['state']!r})")
    main = collections.Counter(r["state"] for r in rows if not r["excluded"])
    out = collections.Counter(r["state"] for r in rows if r["excluded"])
    for part, got in (("main", main), ("outside", out)):
        want = {s: t[part].get(str(s), 0) for s in STATES}
        if {s: got[s] for s in STATES} != want:
            probs.append(f"the page's {part} rows by state are {[got[s] for s in STATES]}, the totals "
                         f"{[want[s] for s in STATES]}")
    rep.add(2, "fail" if probs else "pass", "states: " + ("; ".join(probs) if probs else
            "the page's rows by state, in the main count and outside it, are the totals'"))
    # Each grouping, as the page shows it (the main count) and with the
    # declarations outside the count.
    platforms = pd.get("platforms") or []
    lists = {"main count": [r for r in rows if not r["excluded"]], "with those outside": rows}
    for view in VIEWS:
        probs, ngroups = [], 0
        for label, lst in lists.items():
            keys = lambda r, v=view: view_keys(v, r, platforms)  # noqa: E731
            groups = aggregate(lst, keys)
            ngroups = max(ngroups, len(groups))
            by_state = collections.Counter(r["state"] for r in lst)
            probs += [f"{label}: {p}" for p in sum_problems(lst, groups, view == "platform", by_state,
                                                            platforms_of=keys)]
            if view == "header":
                # Each header's C names add up to the header's count.
                for k, g in groups.items():
                    sub = aggregate(g["rows"], lambda r: [r["cname"] or UNKNOWN])
                    if sum(x["n"] for x in sub.values()) != g["n"]:
                        probs.append(f"{label}: header {k!r}: its C names add up to "
                                     f"{fmt(sum(x['n'] for x in sub.values()))}, not {fmt(g['n'])}")
        n_main, n_all = len(lists["main count"]), len(rows)
        if probs:
            rep.add(2, "fail", f"{view}: " + "; ".join(probs[:5]) + (f"; and {len(probs) - 5} more" if len(probs) > 5
                                                                      else ""))
        elif view == "platform":
            rep.add(2, "pass", f"{view}: every declaration is under at least one of {ngroups} platforms, and each "
                               f"platform's states add up")
        else:
            rep.add(2, "pass", f"{view}: {fmt(ngroups)} groups add up to {fmt(n_main)} (the main count) and "
                               f"{fmt(n_all)} (with those outside), by state too")


# ------------------------------------------------------------------ 3 recount

def symbol_kind(x):
    """The symbol-graph kind of a declaration only the source scan sees,
    from api-delta's record of it: the kind the symbol graphs would give it."""
    kw, scoped = x["kw"], bool(x.get("scopes"))
    mods = set(x.get("modifiers") or [])
    static = bool(mods & {"static", "class"})
    # The scanner names `static func < (lhs:rhs:)` `< ()`.
    base = x["name"].split("(", 1)[0].strip()
    if kw in ("var", "let"):
        return ("swift.type.property" if static else "swift.property") if scoped else "swift.var"
    if kw == "func":
        if base and all(ch in OPERATOR_CHARS for ch in base):
            return "swift.func.op"
        return ("swift.type.method" if static else "swift.method") if scoped else "swift.func"
    if kw.startswith("init"):
        return "swift.init"
    if kw == "subscript":
        return "swift.type.subscript" if static else "swift.subscript"
    if kw == "case":
        return "swift.enum.case"
    return "swift." + kw


# The names of kinds no graph entry has to learn them from.
KIND_FALLBACK = {"swift.var": "Global Variable", "swift.func": "Function", "swift.func.op": "Operator",
                 "swift.type.subscript": "Type Subscript", "swift.subscript": "Instance Subscript",
                 "swift.class": "Class", "swift.protocol": "Protocol", "swift.actor": "Actor",
                 "swift.macro": "Macro", "swift.enum.case": "Case"}


def recount(delta):
    """api-delta's added declarations: [{origin, module, path, file, line,
    kind, kindName}], graph entries then hidden ones."""
    names = {}
    for e in delta["entries"]:
        if e.get("kindName"):
            names.setdefault(e["kind"], e["kindName"])
    out = []
    for e in delta["entries"]:
        if e["status"] == "added":
            out.append({"origin": "graph", "module": e["module"], "path": e["path"], "file": e.get("file"),
                        "line": e.get("line"), "kind": e["kind"],
                        "kindName": e.get("kindName") or names.get(e["kind"]) or KIND_FALLBACK.get(e["kind"])})
    for x in delta["hiddenFromGraphs"]["added"]:
        k = symbol_kind(x)
        out.append({"origin": "scan", "module": x["module"], "path": ".".join(x["scopes"] + [x["name"]]),
                    "file": x["file"], "line": x["line"], "kind": k,
                    "kindName": names.get(k) or KIND_FALLBACK.get(k, k)})
    return out


def counter_diff(a, b):
    """'k: a vs b' for each key whose counts differ."""
    return [f"{k}: {fmt(a.get(k, 0))} vs {fmt(b.get(k, 0))}" for k in sorted(set(a) | set(b), key=str)
            if a.get(k, 0) != b.get(k, 0)]


def check_recount(rep, data, delta, pd):
    if delta is None:
        rep.add(3, "fail", "api-delta.json: not found, so nothing to recount")
        return
    mine = recount(delta)
    decls = data["declarations"]
    rows = page_rows(pd)[:len(decls)] if pd else None
    n_added = sum(1 for u in mine if u["origin"] == "graph")

    def key(u):
        return u["origin"], u["module"], u["path"], u.get("file"), u.get("line")
    missing = collections.Counter(key(x) for x in mine) - collections.Counter(key(u) for u in decls)
    extra = collections.Counter(key(u) for u in decls) - collections.Counter(key(x) for x in mine)
    for k in list(missing)[:10]:
        rep.detail(3, f"- api-delta's `{k[2]}` ({k[3]}:{k[4]}, {k[0]}) isn't in burndown.json")
    for k in list(extra)[:10]:
        rep.detail(3, f"- burndown.json's `{k[2]}` ({k[3]}:{k[4]}, {k[0]}) isn't api-delta's")
    total_ok = len(mine) == len(decls) and (rows is None or len(rows) == len(decls)) and not missing and not extra
    rep.add(3, "pass" if total_ok else "fail",
            f"total: api-delta adds {fmt(n_added)} + {fmt(len(mine) - n_added)} hidden = {fmt(len(mine))}; "
            f"burndown.json has {fmt(len(decls))}" + (f", the page {fmt(len(rows))}" if rows is not None else "")
            + (f"; {fmt(sum(missing.values()))} of api-delta's aren't burndown.json's and {fmt(sum(extra.values()))} "
               f"of burndown.json's aren't api-delta's, by origin, path, file and line" if missing or extra else
               ", each by origin, path, file and line"))
    diff = counter_diff(collections.Counter(u["module"] for u in mine), collections.Counter(u["module"] for u in decls))
    rep.add(3, "fail" if diff else "pass", "modules: " + ("; ".join(diff) + " (api-delta vs burndown.json)" if diff
                                                          else "each module's count is api-delta's"))
    # Kinds, declaration by declaration where they pair.
    theirs_at = collections.defaultdict(list)
    for u in decls:
        theirs_at[key(u)].append(u)
    differ = []
    for x in mine:
        cands = theirs_at.get(key(x)) or []
        if cands and all(c["kind"] != x["kind"] for c in cands):
            differ.append(x)
            rep.detail(3, f"- `{x['path']}` ({x['file']}:{x['line']}): api-delta's record makes it `{x['kind']}`, "
                          f"burndown.json `{cands[0]['kind']}`")
    kinds_mine = collections.Counter(u["kind"] for u in mine)
    diff = counter_diff(kinds_mine, collections.Counter(u["kind"] for u in decls))
    rep.add(3, "fail" if diff else "pass", "kinds: " + (
        f"{len(kinds_mine)} kinds, each with api-delta's count" if not diff else "; ".join(diff)
        + " (recounted vs burndown.json)"
        + (f"; {fmt(len(differ))} declaration{'s' * (len(differ) != 1)} of another kind, listed in the report"
           if differ else "")))
    if rows is not None:
        diff = counter_diff(collections.Counter(u["kindName"] for u in mine),
                            collections.Counter(r["kind"] for r in rows))
        rep.add(3, "fail" if diff else "pass", "kind names (the page's Kind grouping): " + (
            "each is api-delta's count" if not diff else "; ".join(diff) + " (recounted vs the page)"))


# ------------------------------------------------------------------ 4 sites

def split_name(path):
    """(the name of the type it's in, or None; its base name) for a
    declaration path: `FilePath.Attribute.init(rawValue:)` gives
    (`Attribute`, `init`), `FileDescriptor.==(_:_:)` (`FileDescriptor`, `==`)."""
    head = path.split("(", 1)[0]
    m = re.search(r"[A-Za-z_`][\w`]*$", head)
    if m and (m.start() == 0 or head[m.start() - 1] == "."):
        base, start = m.group(0), m.start()
    else:
        m = re.search(r"[^\w`\s]+$", head)
        start = m.start() if m else 0
        base = head[start:]
        # An operator may start with a dot; its separator is the first one.
        if start > 0 and base.startswith(".") and head[start - 1] not in OPERATOR_CHARS:
            base, start = base[1:], start + 1
    scope = head[:start].rstrip(".")
    return (scope.rsplit(".", 1)[-1] if scope else None), base.strip("`")


def name_patterns(path):
    """The regexes, any of which on a line is the declaration's name there."""
    type_name, base = split_name(path)

    def word(x):
        return re.compile(r"(?<![\w])" + re.escape(x) + r"(?![\w])")
    if base == "init":
        return ([word(type_name)] if type_name else []) + [re.compile(r"\.init\b")]
    if base == "subscript":
        return [re.compile(r"\[")]
    if base and all(ch in OPERATOR_CHARS for ch in base):
        return [re.compile(re.escape(base))]
    return [word(base)]


def line_at(text, n):
    if text is None:
        return None
    lines = text.split("\n")
    return lines[n - 1] if 0 < n <= len(lines) else None


def has_name(line, patterns):
    return line is not None and any(p.search(line) for p in patterns)


def sample(population, n, seed, label):
    """A seeded sample, in the population's order: all of it for n None."""
    if n is None or n >= len(population):
        return list(population)
    rng = random.Random(f"{seed}:{label}")
    return [population[i] for i in sorted(rng.sample(range(len(population)), n))]


def called_at(line, col):
    """The name called as an initializer at a 1-based column (the index's,
    in UTF-8 bytes), if one is: `IOVector` in `IOVector(base: …)`."""
    if not line or not col or col < 1:
        return None
    m = re.match(r"([A-Za-z_]\w*)\s*(?:\(|\.init\b|\{)", line.encode()[col - 1:].decode("utf-8", "ignore"))
    return m.group(1) if m else None


def aliases(git, ref, name, paths, depth=3):
    """The right-hand sides of `typealias NAME = …` in a tree, following an
    alias of an alias: ['iovec'] for NIO's IOVector."""
    out = git.run("grep", "-h", "-E", rf"typealias[[:space:]]+{re.escape(name)}[[:space:]]*=", ref, "--", *paths) or ""
    rhs = [x.split("=", 1)[1].strip() for x in out.split("\n") if "=" in x]
    if depth > 1:
        for r in list(rhs):
            last = IDENT_RE.findall(r)
            if last and last[-1] != name:
                rhs += aliases(git, ref, last[-1], paths, depth - 1)
    return rhs


def alias_explains(u, line, col, adopter, branch, system, commit):
    """Whether an initializer's site calls it through a typealias of its
    type that the adopter's branch or System declares."""
    type_name, base = split_name(u["path"])
    alias = called_at(line, col) if base == "init" and type_name else None
    if not alias or alias == type_name:
        return False
    word = re.compile(r"(?<![\w])" + re.escape(type_name) + r"(?![\w])")
    rhs = aliases(adopter, branch, alias, ["*.swift"]) + (aliases(system, commit, alias, ["Sources"])
                                                         if system and commit else [])
    return any(word.search(r) for r in rhs)


def check_sites(rep, data, graph, n, seed, max_misses, siblings=None, system=None):
    decls = data["declarations"]
    pop = [(i, ub["package"], s) for i, u in enumerate(decls) for ub in u.get("usedBy") or [] for s in ub["sites"]]
    if not pop:
        rep.add(4, "pass", "no declaration has a usedBy site")
        return
    if graph is None:
        rep.add(4, "fail", f"the graph isn't available, so none of the {fmt(len(pop))} sites can be read")
        return
    if n == 0:
        rep.add(4, "warn", f"not checked (--sample 0), {fmt(len(pop))} usedBy sites")
        return
    picked = sample(pop, n, seed, "sites")
    gits, rows, misses, explained = {}, [], [], []
    for i, package, (file, line, col, resolution) in picked:
        u = decls[i]
        p = graph.packages.get(package) or {}
        ad = p.get("adopted") or {}
        clone = ad.get("path")
        if not (clone and os.path.isdir(clone)) and siblings and ad.get("dir"):
            clone = os.path.join(siblings, "adopters", ad["dir"])
        site = f"{package}: {file}:{line}:{col} ({resolution})"
        if not (clone and os.path.isdir(clone) and ad.get("branch")):
            misses.append((u, site, f"no clone or branch for {package} in the graph"))
            continue
        g = gits.setdefault(clone, Git(clone))
        pats = name_patterns(u["path"])
        text = line_at(g.show(ad["branch"], file), line)
        if has_name(text, pats):
            rows.append((u, site, "ok", text))
            continue
        if alias_explains(u, text, col, g, ad["branch"], system, graph.meta.get("headCommit")):
            explained.append((u, site, "init-through-alias", text))
            continue
        cur = g.rev(ad["branch"])
        then = line_at(g.show(ad["commit"], file), line) if ad.get("commit") and cur != ad["commit"] else None
        if has_name(then, pats) or (then is not None and alias_explains(u, then, col, g, ad["commit"], system,
                                                                         graph.meta.get("headCommit"))):
            explained.append((u, site, "branch-moved", then))
        else:
            why = "no such file or line on " + ad["branch"] if text is None else "the line hasn't the name"
            misses.append((u, site, f"{why}: {(text or '').strip()[:160]!r}"))
    for u, site, cause, text in explained:
        rep.detail(4, f"- known ({cause}): `{u['path']}` at {site}: {text.strip()[:160]!r}")
    for u, site, why in misses:
        rep.detail(4, f"- **miss**: `{u['path']}` at {site}: {why}")
    if len(picked) <= 50:
        for u, site, _, text in rows:
            rep.detail(4, f"- ok: `{u['path']}` at {site}: {text.strip()[:120]!r}")
    what = f"{fmt(len(picked))} of {fmt(len(pop))} usedBy sites" + (f" (seed {seed})" if len(picked) < len(pop) else "")
    level = "pass" if not misses else ("warn" if len(misses) <= max_misses else "fail")
    causes = collections.Counter(c for _, _, c, _ in explained)
    rep.add(4, level, f"{what}: {fmt(len(rows))} lines have the declaration's name"
            + (f"; {fmt(len(explained))} explained ({', '.join(f'{c} {k}' for c, k in causes.most_common())})"
               if explained else "")
            + (f"; {fmt(len(misses))} miss{'es' * (len(misses) != 1)}, listed in the report" if misses else ""))


# ------------------------------------------------------------------ 5 C names

class SDK:
    """The SDK's headers, as text without comments, and the vocabulary,
    by name: {name: {module: kind mask}}."""

    def __init__(self, sdk, vocab_path):
        self.sdk = sdk
        self.include = os.path.join(sdk, "usr", "include") if sdk else None
        self.texts = {}
        self.where = collections.defaultdict(dict)
        if vocab_path:
            for mod, names in load_json(vocab_path)["vocab"].items():
                for name, (kinds, _lang) in names.items():
                    self.where[name][mod] = self.where[name].get(mod, 0) | kinds

    def text(self, header):
        """A header's text, from usr/include, or for `F/h.h`, framework F's."""
        if header not in self.texts:
            paths = [os.path.join(self.include, header)] if self.include else []
            if self.sdk and "/" in header:
                fw, rest = header.split("/", 1)
                paths.append(os.path.join(self.sdk, "System", "Library", "Frameworks", f"{fw}.framework", "Headers",
                                          rest))
            self.texts[header] = None
            for path in paths:
                try:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        self.texts[header] = COMMENT_RE.sub(" ", f.read())
                    break
                except OSError:
                    continue
        return self.texts[header]


def declares(text, name):
    """Whether a header's text names each part of a C name (`stat.st_size`:
    both `stat` and `st_size`) as an identifier."""
    ids = set(IDENT_RE.findall(text))
    return all(p in ids for p in name.split("."))


def defines_tag(text, tag):
    return re.search(r"\b(?:struct|union|enum)\s+" + re.escape(tag) + r"\s*\{", text) is not None


def defines_macro(text, name):
    return re.search(r"^[ \t]*#[ \t]*define[ \t]+" + re.escape(name) + r"\b", text, re.M) is not None


def classify_header(u, sdk):
    """(ok, cause, why) for a declaration's header and C name: ok with no
    cause when header and vocabulary agree; else the known cause, or None."""
    name, header, sub = u["cName"], u["header"], u["sdkSubmodule"]
    text = sdk.text(header)
    if text is None:
        return False, None, f"{header} isn't a header in the SDK"
    lead = name.split(".", 1)[0]
    if not declares(text, name):
        return False, None, f"{header} doesn't declare {name}"
    mods = sdk.where.get(lead, {})
    if sub in mods:
        return True, None, None
    if sub == NO_MODULE:
        return True, "header-in-no-module", None
    if mods and all(k & TAG_KINDS for k in mods.values()) and defines_tag(text, lead):
        return True, "vocab-forward-declaration", None
    if any(sub.startswith(m + ".") for m in mods):
        return True, "vocab-parent-module", None
    if not mods and defines_macro(text, lead):
        return True, "macro-not-indexed", None
    return False, None, (f"the vocabulary puts {lead} in {', '.join(sorted(mods)) or 'no module'}, not {sub}")


STRING_RE = re.compile(r'"""(?:.|\n)*?"""|"(?:[^"\\\n]|\\.)*"|/\*(?:.|\n)*?\*/|//[^\n]*')
DECL_RE = re.compile(r"^(?P<pre>[^{}=\"]*?)\b(?P<kw>func|var|let|init)\b[?!]?\s*(?P<name>[A-Za-z_]\w*)?")
TYPE_RE = re.compile(r"^(?P<pre>\s*(?:(?:public|internal|private|fileprivate|package|open|final|indirect|"
                     r"@\w+(?:\([^)]*\))?)\s+)*)(?P<kw>extension|struct|enum|class|actor|protocol)\s+"
                     r"(?P<name>[A-Za-z_][\w.]*)")
ACCESS_PUBLIC_RE = re.compile(r"\b(?:public|open)\b")
FLOW_RE = re.compile(r"\b(?:if|guard|while|for|case|return|switch|repeat|catch|else)\b")


def code_lines(text):
    """A Swift file's lines with comments and string literals blanked, and
    the lines only a mock build has (`#if ENABLE_MOCKING`) dropped."""
    text = STRING_RE.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    out, stack = [], []
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("#if"):
            stack.append("ENABLE_MOCKING" in s and "!" not in s)
            out.append("")
        elif s.startswith("#else") or s.startswith("#elseif"):
            if stack:
                stack[-1] = False
            out.append("")
        elif s.startswith("#endif"):
            if stack:
                stack.pop()
            out.append("")
        else:
            out.append("" if any(stack) else line)
    return out


class SourceWalk:
    """What System's code reaches, lexically: from some lines, the
    identifiers on them, then the bodies of the internal code they name,
    read from git at one commit, a few levels deep. Only names that System
    spells as internal are followed: `_x` and `system_x` functions and
    properties, and the initializers of types it doesn't make public
    (`SystemString(platformString:)`). A lexical stand-in for the index's
    walk: following every internal name reaches nearly all of System."""

    def __init__(self, git, commit, dirs=("Sources/System", "Sources/SystemSockets"), depth=4):
        self.git, self.commit, self.depth = git, commit, depth
        files = [f for f in git.ls(commit, *dirs) if f.endswith(".swift")]
        self.lines = {f: code_lines(t) for f, t in git.show_many(commit, files).items() if t is not None}
        self.defs = collections.defaultdict(list)    # internal function or property → its bodies
        self.inits = collections.defaultdict(list)   # type → its internal initializers' bodies
        self.internal_types = set()
        for L in self.lines.values():
            self.index(L)

    def index(self, L):
        depth, owners = 0, []   # owners: [type, its body's depth, whether its brace has opened]
        for i, line in enumerate(L):
            t = TYPE_RE.match(line)
            if t:
                name = t.group("name").rsplit(".", 1)[-1]
                owners.append([name, depth + 1, False])
                if t.group("kw") != "extension" and not ACCESS_PUBLIC_RE.search(t.group("pre")):
                    self.internal_types.add(name)
            m = DECL_RE.match(line)
            if m and not FLOW_RE.search(m.group("pre")) and not ACCESS_PUBLIC_RE.search(m.group("pre")):
                if m.group("kw") == "init":
                    if owners:
                        self.inits[owners[-1][0]].append(self.body(L, i))
                elif m.group("name"):
                    self.defs[m.group("name")].append(self.body(L, i))
            depth = max(0, depth + line.count("{") - line.count("}"))
            if owners and "{" in line:
                owners[-1][2] = True
            while owners and owners[-1][2] and depth < owners[-1][1]:
                owners.pop()

    @staticmethod
    def follows(name):
        return name.startswith("_") or name.startswith("system_")

    @staticmethod
    def body(L, i):
        """The declaration's text from line i: to its body's closing brace,
        or, with no body, its line (`let _X = X`)."""
        parens, depth, j, started = 0, 0, i, False
        while j < len(L) and j - i < 400:
            for ch in L[j]:
                if ch in "([":
                    parens += 1
                elif ch in ")]":
                    parens -= 1
                elif ch == "{":
                    depth += 1
                    started = True
                elif ch == "}":
                    depth -= 1
            if started and depth <= 0:
                break
            if not started and parens <= 0 and "{" not in L[j] and j + 1 < len(L) \
                    and not re.match(r"\s*(?:->|throws|rethrows|where|async|\{)", L[j + 1]) and "=" in L[i]:
                break
            j += 1
        return "\n".join(L[i:j + 1])

    def text(self, file, start, end):
        L = self.lines.get(file)
        return "\n".join(L[start - 1:end]) if L and start else ""

    def reach(self, text):
        seen = set(IDENT_RE.findall(text))
        frontier, followed = set(seen), set()
        for _ in range(self.depth):
            nxt = set()
            for name in frontier:
                if name in followed:
                    continue
                followed.add(name)
                bodies = (self.defs.get(name, []) + self.inits.get(name, [])) if self.follows(name) else \
                    self.inits.get(name, []) if name in self.internal_types else []
                for b in bodies:
                    for x in IDENT_RE.findall(b):
                        if x not in seen:
                            seen.add(x)
                            nxt.add(x)
            if not nxt:
                break
            frontier = nxt
        return seen


def code_text(graph, walk, nids):
    """The lines a declaration's nodes cover, and the new internal code they
    reach, and for a fix-it stub, the same of the declaration it renames."""
    parts, todo, seen = [], list(nids), set()
    while todo:
        nid = todo.pop()
        if nid in seen:
            continue
        seen.add(nid)
        n = graph.nodes.get(nid) or {}
        parts.append(walk.text(n.get("file"), n.get("start"), n.get("end")))
        for ln in graph.out.get(nid, ()):
            if ln["kind"] == "reaches":
                i = graph.nodes.get(ln["to"]) or {}
                parts.append(walk.text(i.get("file"), i.get("start"), i.get("end")))
            elif ln["kind"] == "stubFor":
                todo.append(ln["to"])
    return "\n".join(parts)


def check_cnames(rep, data, graph, sdk, walk_for, n, seed, max_misses):
    decls = data["declarations"]
    # Headers.
    pop = [u for u in decls if u.get("cName") and u.get("header") not in SPECIAL_HEADERS and u.get("header")]
    if sdk is None or sdk.include is None or not os.path.isdir(sdk.include):
        rep.add(5, "fail", "headers: no SDK to read them from")
    elif not pop:
        rep.add(5, "pass", "headers: no declaration has a header")
    elif n == 0:
        rep.add(5, "warn", f"headers: not checked (--sample 0), {fmt(len(pop))} declarations with one")
    else:
        picked = sample(pop, n, seed, "headers")
        misses, known, agree = [], [], 0
        for u in picked:
            ok, cause, why = classify_header(u, sdk)
            if cause:
                known.append((u, cause, why))
            elif not ok:
                misses.append((u, why))
            else:
                agree += 1
                if len(picked) <= 50:
                    rep.detail(5, f"- ok: `{u['path']}`: `{u['cName']}` in {u['header']} ({u['sdkSubmodule']})")
        for u, cause, why in known:
            rep.detail(5, f"- known ({cause}): `{u['path']}`: `{u['cName']}` in {u['header']} ({u['sdkSubmodule']}, "
                          f"by {u.get('headerHow')})" + (f": {why}" if why else ""))
        for u, why in misses:
            rep.detail(5, f"- **miss**: `{u['path']}`: `{u['cName']}` in {u['header']} ({u['sdkSubmodule']}, by "
                          f"{u.get('headerHow')}): {why}")

        def causes(kind):
            c = collections.Counter(c for _, c, _ in known if KNOWN[c][1] == kind)
            return sum(c.values()), ", ".join(f"{k} {n}" for k, n in c.most_common())
        n_method, method = causes("method")
        n_error, error = causes("error")
        what = f"headers: {fmt(len(picked))} of {fmt(len(pop))} declarations with one" + (
            f" (seed {seed})" if len(picked) < len(pop) else "")
        level = "fail" if len(misses) > max_misses else ("warn" if misses or n_error else "pass")
        rep.add(5, level, f"{what}: {fmt(agree)} headers declare the C name, in the vocabulary's module"
                + (f"; {fmt(n_method)} do, by a method cause ({method})" if n_method else "")
                + (f"; {fmt(n_error)} known errors ({error})" if n_error else "")
                + (f"; {fmt(len(misses))} miss{'es' * (len(misses) != 1)}, listed in the report" if misses else ""))
    # C names from the code.
    pop = [u for u in decls if any(c.get("code") for c in u.get("cNames") or [])]
    if not pop:
        rep.add(5, "pass", "code: no declaration has a C name from its code")
        return
    if graph is None:
        rep.add(5, "fail", f"code: the graph isn't available, so none of {fmt(len(pop))} declarations can be checked")
        return
    if n == 0:
        rep.add(5, "warn", f"code: not checked (--sample 0), {fmt(len(pop))} declarations with a C name from the code")
        return
    walk = walk_for(graph.meta.get("headCommit"))
    if walk is None:
        rep.add(5, "fail", f"code: the graph's commit {short(graph.meta.get('headCommit'))} isn't in this "
                           f"repository, so its code can't be read")
        return
    picked = sample(pop, n, seed, "code")
    misses, checked, marks = [], 0, 0
    for u in picked:
        nids = graph.nodes_of(u)
        links = {}
        for nid in nids:
            for ln in graph.out.get(nid, ()):
                if ln["kind"] == "wraps":
                    links.setdefault(ln["to"].split(":", 1)[-1], set()).update(ln.get("sources") or [ln.get("source")
                                                                                                    or "doc"])
        reached = None
        for c in u.get("cNames") or []:
            src = links.get(c["name"])
            if src is None:
                misses.append((u, c["name"], "the graph has no wraps link to it"))
                continue
            if bool(c.get("code")) != (src == {"code"}):
                misses.append((u, c["name"], f"the page marks it {'code' if c.get('code') else 'stated'}; the "
                                             f"graph's link is from {'+'.join(sorted(src))}"))
                continue
            marks += 1
            if not c.get("code"):
                continue
            checked += 1
            if reached is None:
                reached = walk.reach(code_text(graph, walk, nids))
            if c["name"].rsplit(".", 1)[-1] not in reached:
                misses.append((u, c["name"], "no code it reaches names it"))
            elif len(picked) <= 50:
                rep.detail(5, f"- ok: `{u['path']}`: `{c['name']}` (code)")
    for u, name, why in misses:
        rep.detail(5, f"- **miss**: `{u['path']}`: `{name}`: {why}")
    what = f"code: {fmt(len(picked))} of {fmt(len(pop))} declarations with a C name from the code" + (
        f" (seed {seed})" if len(picked) < len(pop) else "")
    level = "pass" if not misses else ("warn" if len(misses) <= max_misses else "fail")
    rep.add(5, level, f"{what}: {fmt(marks)} of their C names are the graph's links, marked as the graph has them, "
                      f"and {fmt(checked - sum(1 for _, _, w in misses if w.startswith('no code')))} of the "
                      f"{fmt(checked)} from the code are named in the code they reach"
            + (f"; {fmt(len(misses))} miss{'es' * (len(misses) != 1)}, listed in the report" if misses else ""))


# ------------------------------------------------------------------ the report

def markdown(rep, data, args, inputs):
    m = data["meta"]
    L = ["# Burn-down verification", "",
         f"`verify.sh` on {args.now.date().isoformat()}: **{rep.count('fail')} fail, {rep.count('warn')} warn, "
         f"{rep.count('pass')} pass**. The page {inputs['page']} and burndown.json, generated {m['generated']} at "
         f"{m['headRef']} {short(m['headCommit'])} (digest {short(data.get('digest'))}).",
         "",
         f"Sample: {'everything' if args.sample is None else f'{args.sample} of each'} in checks 4 and 5, seed "
         f"{args.seed}; `Utilities/api-burndown/verify.sh --seed {args.seed}` reruns it.", "",
         "Inputs: " + "; ".join(f"{k} `{v}`" for k, v in inputs.items() if k != "page") + ".", "",
         "| | Check | |", "|---|---|---|"]
    for c, lv, text in rep.lines:
        cell = text.replace("|", "\\|")
        L.append(f"| {lv} | {c} {CHECKS[c]} | {cell} |")
    for c in sorted(rep.details):
        L += ["", f"## {c}. {CHECKS[c][0].upper()}{CHECKS[c][1:]}", ""] + rep.details[c]
    L += ["", "## Known causes", "",
          "A `method` cause is how a check looks, not an error in the page, and passes. An `error` is a real error "
          "in the page, recorded in `Prototype/Burndown/VERIFY-REPORT.md`, and warns until it's fixed.", "",
          "| Cause | Check | | What |", "|---|---|---|---|"]
    for k, (c, kind, text) in KNOWN.items():
        L.append(f"| `{k}` | {c} | {kind} | {text} |")
    return "\n".join(L) + "\n"


def parse_sample(s):
    if s == "all":
        return None
    n = int(s)
    if n < 0:
        raise argparse.ArgumentTypeError("--sample takes a count or `all`")
    return n


def newest_vocab(coverage):
    files = sorted(glob.glob(os.path.join(coverage, "vocab", "macosx*.json.gz")), key=os.path.getmtime) \
        if coverage else []
    return files[-1] if files else None


def main(argv=None):
    ap = argparse.ArgumentParser(description="Check the burn-down page against its inputs.")
    ap.add_argument("--repo", required=True, help="the System repository the page is of")
    ap.add_argument("--burndown", required=True, help="burndown.json")
    ap.add_argument("--page", help="the page, which burndown.json doesn't record (verify.sh gives it)")
    ap.add_argument("--delta", help="api-delta's output directory (default: burndown.json's)")
    ap.add_argument("--graph", help="the API graph (default: burndown.json's, or the store's copy)")
    ap.add_argument("--store", help="the api-graph snapshot store")
    ap.add_argument("--vocab", help="the SDK vocabulary (default: burndown.json's, or the newest in --coverage-results)")
    ap.add_argument("--coverage-results", help="the coverage tools' results store")
    ap.add_argument("--sdk", help="the macOS SDK (default: burndown.json's, else xcrun's)")
    ap.add_argument("--upstream", default="origin/main", help="a ref the base should contain; empty skips it")
    ap.add_argument("--siblings", help="the directory holding ../adopters, for a graph whose clone paths moved")
    ap.add_argument("--sample", type=parse_sample, default=DEFAULT_SAMPLE,
                    help=f"how many sites and declarations checks 4 and 5 sample (default {DEFAULT_SAMPLE}), or all")
    ap.add_argument("--seed", help="the sample's seed (default: from burndown.json's digest)")
    ap.add_argument("--max-misses", type=int, default=0,
                    help="unexplained misses a sampled check warns about rather than fails on (default 0)")
    ap.add_argument("--fetch-age", type=int, default=7,
                    help="warn when the upstream ref was last fetched more than this many days ago (default 7)")
    ap.add_argument("--report", help="the Markdown report to write")
    args = ap.parse_args(argv)
    args.now = datetime.datetime.now().astimezone()

    data = load_json(args.burndown)
    m = data["meta"]
    args.seed = args.seed or str(int((data.get("digest") or "0")[:12], 16))
    delta_dir = args.delta or (m.get("apiDelta") or {}).get("path")
    delta_file = os.path.join(delta_dir, "api-delta.json") if delta_dir else None
    delta = load_json(delta_file) if delta_file and os.path.exists(delta_file) else None
    gdoc, gpath = find_graph(data, args.graph, args.store)
    graph = GraphView(gdoc) if gdoc else None
    recorded = (m.get("headers") or {}).get("vocab")
    vocab = args.vocab or (recorded if recorded and os.path.exists(recorded) else None) \
        or newest_vocab(args.coverage_results)
    sdk_path = args.sdk or (m.get("headers") or {}).get("sdk")
    if not (sdk_path and os.path.isdir(sdk_path)):
        r = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True)
        sdk_path = r.stdout.strip() if r.returncode == 0 else None
    pd = page_data(args.page) if args.page else None
    git = Git(args.repo)
    inputs = {"page": args.page, "burndown.json": args.burndown, "api-delta": delta_file, "graph": gpath,
              "vocabulary": vocab, "SDK": sdk_path}

    rep = Report()
    check_freshness(rep, data, delta, graph, git, args.upstream, args.now, args.fetch_age, args.siblings)
    check_sums(rep, data, pd, args.page)
    check_recount(rep, data, delta, pd)
    check_sites(rep, data, graph, args.sample, args.seed, args.max_misses, args.siblings, system=git)
    walks = {}

    def walk_for(commit):
        if commit and commit not in walks:
            walks[commit] = SourceWalk(git, commit) if git.rev(commit) else None
        return walks.get(commit)
    check_cnames(rep, data, graph, SDK(sdk_path, vocab) if sdk_path else None, walk_for, args.sample, args.seed,
                 args.max_misses)

    width = max(len(CHECKS[c]) for c in CHECKS) + 2
    for c, lv, text in rep.lines:
        print(f"{lv:4}  {c} {CHECKS[c]:<{width}}{text}")
    if args.report:
        os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
        tmp = args.report + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(markdown(rep, data, args, inputs))
        os.replace(tmp, args.report)
    print(f"verify: {rep.count('fail')} fail, {rep.count('warn')} warn, {rep.count('pass')} pass"
          + (f"; details in {args.report}" if args.report else ""))
    return 1 if rep.failed() else 0


if __name__ == "__main__":
    sys.exit(main())
