#!/usr/bin/env python3
"""Assemble the master view's data: what system-next adds over main, who
uses it, and what each package still needs, from the other tools' outputs.

Reads (nothing here is recomputed; README.md in this directory lists each):
  universe.tsv                  the packages, by cluster (scripts/universe.py)
  api-burndown's burndown.json  the added declarations (api-delta's added set),
                                their pitch states and the per-day history
  api-delta.json                beside it: the added count, scopes, main's API
  the API graph                 the one burndown.json names: usedBy links and
                                each package's migration branch and commit
  api-graph's adopter cache     the index references of each migration build,
                                for the API already on main a package uses
  the ledger                    status.sh's ledger.json and its STATUS.md:
                                the update-checkout cluster's sites left on C
  STATUS.md's git history       the ledger's figures on earlier days
  the coverage tools' scans     survey-popular.json and the newest ecosystem
                                runs: other packages' Darwin C use
  the examples' GAPS.md         what the Unix tools still need
  set-aside.tsv                 packages shown, but kept out of the headline
  the tracked history file      every earlier run's figures

The examples' repository is one package of the graph (api-graph reads it at
its main); its uses are split among the universe's rows for its tools and
their shared target, by directory.

Writes master.json (meta, headline, declarations, packages, charts, notes)
and the updated history file. Usage: assemble.py --help.
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
import re  # noqa: E402
import subprocess  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
UTILITIES = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import universe as uv  # noqa: E402

SCHEMA = "master-view/2"
CLUSTERS = uv.CLUSTERS
CLUSTER_LABELS = {"update-checkout": "update-checkout", "swiftlang and apple": "swiftlang and apple",
                  "ecosystem": "ecosystem (not yet picked)", "Unix tools": "the examples: Unix tools"}
# The adopter universe is the three library clusters; the examples are the other user.
ADOPTER_CLUSTERS = CLUSTERS[:3]
EXAMPLES_CLUSTER = CLUSTERS[3]
KINDS = ("migrated", "on-system", "scanned", "not-scanned", "no-swift")
KIND_LABELS = {"migrated": "migrated: real usage", "on-system": "written on System: real usage",
               "scanned": "scanned: C use only", "not-scanned": "not scanned yet", "no-swift": "no Swift code"}
STATE_LABELS = {1: "not in a pitch", 2: "in a pitch draft", 3: "pitched", 4: "PR open", 5: "merged"}
TYPE_KINDS = {"swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.actor"}
TYPE_KWS = {"struct", "enum", "class", "protocol", "actor"}
MIGRATION_BRANCHES = uv.MIGRATION_BRANCHES
PLATFORMS = ("Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows")
# The ledger's categories (ledger.py's CATEGORIES), in its order, in plain words.
LEDGER_CATEGORIES = ("unexplained", "System gap", "queued", "exception", "undecided", "not System's",
                     "standard library")
CATEGORY_LABELS = {"unexplained": "unexplained: System may cover it already",
                   "System gap": "System lacks it", "queued": "work queued", "exception": "approved to stay on C",
                   "undecided": "undecided", "not System's": "not System's (a lane's verdict)",
                   "standard library": "the standard library has it"}
ROLE_IMPLICIT = 1 << 8   # an index reference the compiler made, not the source (adopters.py)
# The history's figures: those the page shows, then the earlier page's two
# burn-down charts, whose rows stay in the file but get no new points.
CHARTS = ("used", "unpitched-used", "cuses")
OLD_CHARTS = ("unpitched", "pitched")
# The C-use split: what the adopter can do now, what System has to add, the rest.
SPLIT = ("covers", "lacks", "other")
SPLIT_LABELS = {"covers": "System covers it", "lacks": "System lacks it", "other": "other"}
HISTORY_COLUMNS = ("date", "chart", "count", "scope_added", "source", "commit", "detail")
STATUS_PATH = "Prototype/Status/STATUS.md"
CATEGORY_SENTENCE = re.compile(r"Categories, by .*?`: (.*?); (\d+) excluded\.", re.S)
REPO_LINE = re.compile(r"^\*\*(.+?)\*\*, at (.+?): (?:(\d+) sites|no sites)", re.M)


# ------------------------------------------------------------------ small helpers

def load_json(path):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def git(repo, *args, ok=(0,)):
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1")
    p = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, env=env)
    if p.returncode not in ok:
        raise RuntimeError(f"git -C {repo} {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def rev(repo, ref):
    return git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}", ok=(0, 1)).strip() or None


def short(c):
    return (c or "")[:10]


def realpath(p):
    return os.path.realpath(p) if p else None


# ------------------------------------------------------------------ declarations (by API)

def delta_groups(delta):
    """{(module, path, file, line): the type a declaration belongs to}: api-delta's
    `group` for a symbol-graph entry; for a declaration only the scan sees, its
    scopes (and itself, for a type)."""
    out = {}
    for e in delta["entries"]:
        if e["status"] == "added":
            out[(e["module"], e["path"], e.get("file"), e.get("line"))] = e.get("group") or ""
    for x in delta["hiddenFromGraphs"]["added"]:
        path = ".".join(x["scopes"] + [x["name"]])
        g = path if x["kw"] in TYPE_KWS else ".".join(x["scopes"])
        out[(x["module"], path, x["file"], x["line"])] = g
    return out


def type_group(u, groups):
    g = groups.get((u["module"], u["path"], u.get("file"), u.get("line")))
    if g is None:
        if u["kind"] in TYPE_KINDS:
            g = u["path"]
        else:
            g = u["path"].rsplit(".", 1)[0] if "." in u["path"].split("(")[0] else ""
    return g or "(top level)"


def graph_index(doc):
    """(usedBy links by declaration node, package nodes by ID)."""
    used = collections.defaultdict(list)
    for ln in doc["links"]:
        if ln["kind"] == "usedBy":
            used[ln["from"]].append(ln)
    packages = {nid: n for nid, n in doc["nodes"].items() if n["kind"] == "package"}
    return used, packages


def site_tuple(s):
    """[file, line, column, how]: how is p (precise), l (lexical), q (precise,
    only qualifying another name)."""
    how = "q" if s.get("qualifier") else ("p" if s.get("resolution") == "precise" else "l")
    return [s.get("file") or "", s.get("line") or 0, s.get("column") or 0, how, (s.get("text") or "")[:200]]


def owners(units, u2n, nodes):
    """{node: owning unit id} for every node a unit maps to, and {unit id:
    owning unit id} for the units that share a node they don't own. A node's
    owner is the symbol-graph unit with its USR, else the first unit (in
    api-delta's order) only the scan sees. A use site belongs to one
    declaration: a variant compiled only off Darwin shares its node's uses,
    which the Darwin builds made, without counting them again."""
    by_node = collections.defaultdict(list)
    for u in units:
        nid = u2n.get(u["id"])
        if nid:
            by_node[nid].append(u)
    own, same = {}, {}
    for nid, us in by_node.items():
        graph_owner = [u for u in us if u["origin"] == "graph" and u.get("usr") == nid]
        o = (graph_owner or [u for u in us if u["origin"] == "graph"] or us)[0]
        own[nid] = o["id"]
        for u in us:
            if u["id"] != o["id"]:
                same[u["id"]] = o["id"]
    return own, same


# ------------------------------------------------------------------ packages

def migration(path, main_refs=("main", "origin/main", "master", "origin/master")):
    """A migrated clone's branches: {branches: {name: commit}, newest:
    {branch, commit, commits (beyond its merge base with main), base}}."""
    branches = {}
    for b in MIGRATION_BRANCHES:
        c = rev(path, f"refs/heads/{b}")
        if c:
            branches[b] = c
    if not branches:
        return None
    newest = next(b for b in MIGRATION_BRANCHES if b in branches)
    tip = branches[newest]
    base = None
    for m in main_refs:
        if rev(path, m):
            base = git(path, "merge-base", tip, m, ok=(0, 1)).strip() or None
            if base:
                break
    n = int(git(path, "rev-list", "--count", f"{base}..{tip}").strip() or 0) if base else None
    return {"branches": branches, "newest": {"branch": newest, "commit": tip, "base": base, "commits": n,
                                             "subject": git(path, "log", "-1", "--format=%s", tip).strip()}}


class WebLinks:
    """GitHub URLs for files at a commit, only where the commit is on a
    remote-tracking branch of the clone (so GitHub has it): a migration
    branch is local, and gets none."""

    def __init__(self):
        self.memo = {}

    def base(self, clone, commit, remote):
        if not (clone and commit and remote and os.path.isdir(clone)):
            return None
        key = (clone, commit)
        if key not in self.memo:
            out = git(clone, "branch", "-r", "--contains", commit, ok=(0, 1, 129)).strip()
            self.memo[key] = f"https://github.com/{remote}/blob/{commit}/" if out else None
        return self.memo[key]


def base_api(delta_dir):
    """{USR: path} of main's public API (api-delta's base symbol graphs),
    {USR: path} of the declarations whose USR changed (api-delta's changed
    entries: on main under another USR), and the paths of main's types."""
    main, types = {}, set()
    for f in sorted(glob.glob(os.path.join(delta_dir, "symbolgraphs", "base", "*.symbols.json"))):
        for s in load_json(f).get("symbols", []):
            path = ".".join(s.get("pathComponents") or [])
            main[s["identifier"]["precise"]] = path
            if (s.get("kind") or {}).get("identifier") in TYPE_KINDS | {"swift.typealias"}:
                types.add(path)
    delta = load_json(os.path.join(delta_dir, "api-delta.json"))
    changed = {e["usr"]: e["path"] for e in delta["entries"] if e["status"] == "changed" and e.get("usr")}
    return main, changed, types


def type_tags(decls, main_types, nodes):
    """{type group: what it is}, for the groups that aren't a type
    system-next adds: one main has, a C type System extends, or another
    module's type."""
    new_types = {d["path"] for d in decls if d["kind"] in TYPE_KINDS}
    aliases = {d["path"] for d in decls if d["kind"] == "swift.typealias"}
    external = {n.get("name") for n in nodes.values() if n["kind"] == "declaration" and n.get("origin") == "external"}
    tags = {}
    for g in sorted({d["type"] for d in decls}):
        if g in new_types:
            continue
        if g == "(top level)":
            tags[g] = "functions and values"
        elif g in main_types:
            tags[g] = "already on main"
        elif g in aliases:
            tags[g] = "a new type alias, and members of the type it names"
        elif g in external or (g[:1].islower() and "." not in g):
            tags[g] = "a C type System extends"
        else:
            tags[g] = "another module's type"
    return tags


def adopter_cache_file(cache_dir, node):
    """The cached index references api-graph read this migration from: the
    file for the branch's commit built against the System commit the graph
    records (newest first, if several)."""
    ad = node.get("adopted") or {}
    commit, built = ad.get("commit"), (ad.get("build") or {}).get("builtAgainst")
    if not (cache_dir and commit and built):
        return None, None
    cands = []
    for d in {ad.get("dir"), node.get("key")} - {None}:
        for f in glob.glob(os.path.join(cache_dir, d, commit + "-*.json.gz")):
            cands.append(f)
    best = None
    for f in sorted(set(cands), key=os.path.getmtime, reverse=True):
        try:
            x = load_json(f)
        except (OSError, ValueError):
            continue
        if (x.get("system") or {}).get("commit") == built:
            best = (f, x)
            break
    return best if best else (None, None)


def main_usage(cache, main, changed, head, prefix=None):
    """From a migration's cached index references: {USR: [sites]} of the API
    already on main it uses, and {USR: count} of new declarations it
    references (for the cross-check with the graph). Implicit references
    (accessors a property use calls) are left out, as api-graph leaves them.
    With prefix, only the files under it (one target of the package)."""
    on_main = collections.defaultdict(list)
    new_refs = collections.Counter()
    for rel, fd in sorted((cache.get("files") or {}).items()):
        if prefix and not rel.startswith(prefix):
            continue
        for line, col, usr, flags in fd.get("references") or []:
            if flags & ROLE_IMPLICIT:
                continue
            if usr in main or usr in changed:
                on_main[usr].append([rel, line, col])
            elif usr in head:
                new_refs[usr] += 1
    return on_main, new_refs


def load_set_aside(path):
    """{lowercased remote: {by, why}} from set-aside.tsv: packages the page
    shows, but keeps out of every headline figure."""
    out = {}
    if path and os.path.exists(path):
        for row in uv.read_tsv(path):
            if row and row[0].strip():
                out[row[0].strip().lower()] = {"by": (row[1].strip() if len(row) > 1 else ""),
                                               "why": (row[2].strip() if len(row) > 2 else "")}
    return out


def subdir_rows(pkgs):
    """{lowercased remote: [(directory + "/", package index)]}, longest
    first: the rows that each cover one directory of a clone (the examples'
    tools and their shared target)."""
    out = collections.defaultdict(list)
    for i, r in enumerate(pkgs):
        if r.get("subdir"):
            out[(r.get("remote") or "").lower()].append((r["subdir"].rstrip("/") + "/", i))
    for v in out.values():
        v.sort(key=lambda x: -len(x[0]))
    return dict(out)


def row_of_file(rows, path):
    """The row of [(directory + "/", index)] whose directory holds path, or None."""
    return next((i for prefix, i in rows if path.startswith(prefix)), None)


def group_of(p):
    """A package's user group in the headline: its library cluster, or the examples."""
    return p["cluster"]


def intersection(decls, pkgs, gaps_rows):
    """The headline: how much of the new API real users use (the adopters
    by cluster, the examples), how much of that is in no pitch, and what
    the adopters still use from C, split into what System covers (adopter
    work), what it lacks (System work) and the rest. Set-aside packages
    count in none of it. The page's model recounts all of it (check.py)."""
    counted = [i for i, p in enumerate(pkgs) if not p.get("aside")]
    users = {g: set() for g in CLUSTERS}          # group -> declaration indexes
    sites = collections.Counter()
    using = {g: set() for g in CLUSTERS}          # group -> package indexes with a use
    for i in counted:
        p = pkgs[i]
        for di, ss in (p.get("usage") or {}).get("new") or []:
            users[group_of(p)].add(di)
            using[group_of(p)].add(i)
            sites[group_of(p)] += len(ss)
    adopters = set().union(*(users[g] for g in ADOPTER_CLUSTERS))
    examples = users[EXAMPLES_CLUSTER]
    anyone = adopters | examples

    def state_counts(ds):
        c = collections.Counter(decls[d]["state"] for d in ds if not decls[d]["excluded"])
        return {str(k): c.get(k, 0) for k in range(1, 6)}

    def unpitched(ds):
        return sum(1 for d in ds if decls[d]["state"] == 1 and not decls[d]["excluded"])

    # Read: a package whose use of System was read (a migration's branch, or
    # the examples' main); a migrated package api-graph can't read isn't.
    read = {g: sum(1 for i in counted if pkgs[i]["cluster"] == g and pkgs[i].get("usage")) for g in CLUSTERS}
    migrated = {g: sum(1 for i in counted if pkgs[i]["cluster"] == g and pkgs[i]["kind"] == "migrated")
                for g in CLUSTERS}
    use = {"groups": {g: {"declarations": len(users[g]), "packages": len(using[g]), "read": read[g],
                          "migrated": migrated[g],
                          "sites": sites[g], "unpitched": unpitched(users[g]),
                          "inCluster": sum(1 for i in counted if pkgs[i]["cluster"] == g)} for g in CLUSTERS},
           "adopters": len(adopters), "examples": len(examples), "any": len(anyone),
           "both": len(adopters & examples), "adoptersOnly": len(adopters - examples),
           "examplesOnly": len(examples - adopters), "byState": state_counts(anyone),
           "unpitched": unpitched(anyone), "unpitchedAdopters": unpitched(adopters),
           "unpitchedExamples": unpitched(examples),
           "outside": sum(1 for d in anyone if decls[d]["excluded"]),
           "aside": [pkgs[i]["name"] for i in range(len(pkgs)) if pkgs[i].get("aside")]}
    cuses = {}
    for g in CLUSTERS:
        row = {"covers": 0, "lacks": 0, "other": 0, "parts": collections.Counter(), "packages": 0,
               "withData": 0, "aside": 0}
        for i, p in enumerate(pkgs):
            if p["cluster"] != g:
                continue
            sp = (p.get("cUse") or {}).get("split")
            if p.get("aside"):
                row["aside"] += sum(sp[b] for b in SPLIT) if sp else 0
                continue
            row["packages"] += 1
            if not sp:
                continue
            row["withData"] += 1
            for b in SPLIT:
                row[b] += sp[b]
            row["parts"].update(sp["parts"])
        row["parts"] = dict(row["parts"])
        row["unit"] = {"update-checkout": "sites", EXAMPLES_CLUSTER: "gaps"}.get(g, "files")
        cuses[g] = row
    if gaps_rows is not None:
        # A gap GAPS.md lists for several tools is one thing System lacks:
        # the cluster's figure counts it once (each tool's lists it).
        n = sum(1 for r in gaps_rows if r["tools"])
        cuses[EXAMPLES_CLUSTER].update(lacks=n, parts={"a gap in GAPS.md": n} if n else {})
    return {"use": use, "cuses": cuses}


# ------------------------------------------------------------------ the ledger

def parse_status_md(text):
    """Section 5 of a STATUS.md: {total (sites, excluded ones aside), byCategory,
    excluded, perRepo (sites including excluded, by repository), read
    (repository: where), excludedByRepo} or None when it has no section 5."""
    if "# 5. Sites left" not in text:
        return None
    sec = text.split("# 5. Sites left", 1)[1].split("\n# How this is computed", 1)[0]
    m = CATEGORY_SENTENCE.search(sec)
    if not m:
        return None
    by_cat = {}
    for part in m.group(1).split(","):
        part = part.strip()
        mm = re.match(r"(\d+) (.+)$", part)
        if mm:
            by_cat[mm.group(2)] = int(mm.group(1))
    per_repo, read = {}, {}
    for mm in REPO_LINE.finditer(sec):
        per_repo[mm.group(1)] = int(mm.group(3) or 0)
        read[mm.group(1)] = mm.group(2)
    ex_repo = collections.Counter()
    exc = sec.split("\n## Excluded", 1)
    if len(exc) == 2:
        for row in exc[1].split("\n## ", 1)[0].splitlines():
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            if len(cells) >= 3 and cells[1].isdigit() and not cells[0].startswith("Entry"):
                repos = [r.strip() for r in cells[-1].split(",") if r.strip() and r.strip() != "—"]
                if len(repos) == 1:
                    ex_repo[repos[0]] += int(cells[1])
                elif repos:
                    for r in repos:
                        ex_repo[r] += 0   # can't split an entry's count between repositories
    return {"total": sum(by_cat.values()), "byCategory": by_cat, "excluded": int(m.group(2)),
            "perRepo": per_repo, "read": read, "excludedByRepo": dict(ex_repo), "markers": markers_by_repo(sec)}


MARKER_IN_CELL = re.compile(r"(?:^|, )(\d+)(?:-(\d+))? marker: ")


def markers_by_repo(sec):
    """{repository: SYSTEM-GAP markers that sit over no import, excluded
    ones aside}, from section 5's text: the Unexplained table's rows and
    Every site's lines, where each such marker is a run `12 marker: …`."""
    out = collections.Counter()
    head, _, every = sec.partition("## Every site")
    for line in head.split("## Unexplained", 1)[-1].split("\n## ", 1)[0].splitlines():
        m = re.match(r"^\| ([^|]+?) \| `[^`]+` \| (.*?) \| ", line)
        if m:
            out[m.group(1)] += marker_runs(m.group(2))
    repo = None
    for line in every.splitlines():
        m = REPO_LINE.match(line)
        if m:
            repo = m.group(1)
            out.setdefault(repo, 0)
        elif line.startswith("- `") and repo and "**excluded**" not in line:
            out[repo] += marker_runs(line.split("` ", 1)[-1])
    return dict(out)


def marker_runs(cell):
    """How many markers a lines cell has: `12 marker: …` is one, and a run
    of consecutive lines alike, `12-14 marker: … ×3`, is three."""
    n = 0
    for m in MARKER_IN_CELL.finditer(cell):
        n += (int(m.group(2)) - int(m.group(1)) + 1) if m.group(2) else 1
    return n


def ledger_from_json(led):
    """The ledger's sites, excluded ones aside, by repository, its totals,
    and whose work each queued entry is (System's or the adopter's)."""
    sites = [s for s in led.get("sites") or [] if s["category"] != "excluded"]
    by_repo = collections.defaultdict(list)
    for s in sites:
        by_repo[s["repository"]].append(s)
    markers = collections.Counter(s["repository"] for s in sites if s.get("type") == "marker")
    return {"sites": by_repo, "total": len(sites), "markers": dict(markers),
            "byCategory": dict(collections.Counter(s["category"] for s in sites)),
            "excluded": sum(1 for s in led.get("sites") or [] if s["category"] == "excluded"),
            "read": {r["repository"]: r for r in led.get("read") or []},
            "notRead": {r["repository"]: r["why"] for r in led.get("notRead") or []},
            "work": {e["id"]: e.get("work") for e in led.get("entries") or [] if e.get("kind") == "queued"},
            "floor": led.get("floor") or {}, "meta": led.get("meta") or {}}


def status_history(repo, rel=STATUS_PATH):
    """The ledger's figures from STATUS.md's git history: one per day, the
    day's last commit that has section 5. [{day, commit, ...parse_status_md}]."""
    out = git(repo, "log", "--no-show-signature", "--format=%H%x09%cI", "--", rel, ok=(0, 128))
    by_day = {}
    for line in out.splitlines():
        c, iso = line.split("\t")
        day = iso[:10]
        if day in by_day:
            continue   # newest first: the day's last commit is already in
        text = git(repo, "show", f"{c}:{rel}", ok=(0, 128))
        p = parse_status_md(text) if text else None
        if p:
            by_day[day] = dict(p, day=day, commit=c, time=iso)
    return [by_day[d] for d in sorted(by_day)]


def site_record(s, work=None):
    """A ledger site as the page shows it, with its part of the split."""
    names = sorted(s.get("names") or {})
    lacks = sorted({n for h in s.get("holders") or [] if h["category"] == "System gap" for n in h["names"]})
    bucket, part = ledger_bucket(s, work or {})
    return {"file": s["file"], "line": s["line"], "module": s.get("module"), "type": s.get("type"),
            "importKind": s.get("importKind"), "category": s["category"], "reason": s.get("reason") or "",
            "platforms": [p for p in PLATFORMS if (s.get("platforms") or {}).get(p)],
            "names": names, "lacks": lacks, "kind": s.get("kind"), "text": (s.get("text") or "")[:160],
            "bucket": bucket, "part": part}


# The parts of the split, in plain words, in the order the page lists them.
PARTS = {
    "covers": ("System covers every C name it uses",),
    "lacks": ("System lacks a C name it uses", "a SYSTEM-GAP marker: the adopter says System lacks it",
              "work queued for System", "a gap in GAPS.md"),
    "other": ("the standard library has it", "work queued for the adopter", "approved to stay on C", "undecided",
              "not System's (a lane's verdict)", "another module has it", "its own C shim",
              "no build compiles it", "no C name found"),
}


def ledger_bucket(s, work):
    """(covers, lacks or other; the part) for a ledger site. The ledger's
    unexplained sites whose C names System all covers are adopter work; its
    System gaps, the queued work that's System's, and the SYSTEM-GAP markers
    it can't tie to a C name (the marker is the adopter saying System lacks
    something) are System work; the rest is neither yet."""
    cat, reason = s["category"], s.get("reason") or ""
    if cat == "System gap":
        return "lacks", "System lacks a C name it uses"
    if cat == "queued":
        owners = {work.get(h) for h in s.get("holder") or []}
        return ("lacks", "work queued for System") if "System" in owners else ("other", "work queued for the adopter")
    if cat == "unexplained":
        if reason.startswith("System covers every C name") or "; System covers it" in reason:
            return "covers", "System covers every C name it uses"
        if s.get("type") == "marker":
            return "lacks", "a SYSTEM-GAP marker: the adopter says System lacks it"
        if reason.startswith("no platform's build compiles it"):
            return "other", "no build compiles it"
        return "other", "no C name found"
    return "other", {"standard library": "the standard library has it", "exception": "approved to stay on C",
                     "undecided": "undecided", "not System's": "not System's (a lane's verdict)"}.get(cat, cat)


def scan_split(du):
    """The split of a scanned package's Darwin C use, by library file: a
    file that imports Darwin, or uses a Darwin C name the scan found. A file
    goes as the ledger takes a site: System lacks it if any name it uses is
    a gap; else the standard library's, another module's or its own shim's,
    if any name is; else System covers it, when it uses a name at all."""
    kinds = collections.defaultdict(set)
    for x in du.get("names") or []:
        for f in x.get("files") or []:
            kinds[f].add(x["kind"])
    files = sorted(set(du.get("fileList") or []) | set(kinds))
    out = {"covers": 0, "lacks": 0, "other": 0, "parts": collections.Counter(), "files": {}}
    for f in files:
        ks = kinds.get(f, set())
        if "gap" in ks:
            b, part = "lacks", "System lacks a C name it uses"
        elif "standard library" in ks:
            b, part = "other", "the standard library has it"
        elif "other module" in ks:
            b, part = "other", "another module has it"
        elif "shim" in ks:
            b, part = "other", "its own C shim"
        elif ks:
            b, part = "covers", "System covers every C name it uses"
        else:
            b, part = "other", "no C name found"
        out[b] += 1
        out["parts"][part] += 1
        out["files"][f] = [b, part]
    out["parts"] = dict(out["parts"])
    return out


# ------------------------------------------------------------------ other scans

def survey(ecosystem):
    """{lowercased remote: survey-popular.json's entry}."""
    path = os.path.join(ecosystem, "survey-popular.json")
    if not os.path.exists(path):
        return {}, None
    rows = load_json(path)
    when = datetime.date.fromtimestamp(os.path.getmtime(path)).isoformat()
    return {(x.get("remote") or "").lower(): x for x in rows}, when


def ecosystem_runs(results):
    """The coverage tools' ecosystem runs, newest first, not made with a
    dirty tool: [{id, date, file, systemCommit, packages (by realpath),
    queue rows}]."""
    out = []
    log = os.path.join(results, "runs", "log.tsv") if results else None
    if not log or not os.path.exists(log):
        return out
    dates = {}
    with open(log, encoding="utf-8") as f:
        for line in f:
            cells = line.rstrip("\n").split("\t")
            if len(cells) >= 2:
                dates[cells[1]] = cells[0]
    for run, date in sorted(dates.items(), key=lambda kv: kv[1], reverse=True):
        for name in ("POPULAR.json", "ECOSYSTEM.json"):
            path = os.path.join(results, "runs", run, name)
            if not os.path.exists(path):
                continue
            d = load_json(path)
            r = d.get("run") or {}
            if r.get("toolDirty"):
                continue
            pk = {}
            for p in r.get("packages") or []:
                pk[realpath(p.get("path"))] = p
            out.append({"id": run, "date": date[:10], "file": path, "systemCommit": r.get("systemCommit"),
                        "packages": pk, "queue": d.get("darwinQueue") or []})
    return out


QUEUE_KIND_LABELS = {"covered": "System has it", "gap": "System lacks it", "standard library":
                     "the standard library has it", "other module": "another module has it",
                     "shim": "the package's own C shim"}


def darwin_use(clone, remote, sv, runs):
    """A package's Darwin C use from the survey and the newest ecosystem run
    that read its clone, or None."""
    entry = sv.get((remote or "").lower())
    rp = realpath(clone)
    run = next((r for r in runs if rp in r["packages"]), None)
    if not entry and not run:
        return None
    out = {"files": None, "fileList": [], "commit": None, "names": [], "run": None}
    if entry:
        out.update(files=entry.get("darwinFiles"), fileList=entry.get("darwinFileList") or [],
                   commit=entry.get("commit"), scan=entry.get("scan"))
    if run:
        p = run["packages"][rp]
        key = p.get("name")
        names = []
        for row in run["queue"]:
            n = (row.get("packages") or {}).get(key)
            if n:
                names.append({"name": row["name"], "kind": row.get("kind") or row.get("status"),
                              "sites": n, "files": (row.get("files") or {}).get(key) or []})
        names.sort(key=lambda x: (x["kind"] != "gap", x["name"].lower()))
        out["names"] = names
        out["run"] = {"id": run["id"], "date": run["date"], "systemCommit": run["systemCommit"],
                      "commit": p.get("commit"), "extraction": p.get("extraction")}
        out["commit"] = out["commit"] or p.get("commit")
    return out


GAP_TOOL_RE = re.compile(r"`([a-z][a-z0-9_-]*)(?:\s[^`]*)?`")


def parse_gaps(text, tools):
    """GAPS.md's table: [{names, tools, where, platforms, note}], each row's
    tools being those of `tools` its second column names (`ls -l`)."""
    rows = []
    in_table = False
    for line in text.splitlines():
        if line.startswith("| C name"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            break
        if set(line.replace("|", "").strip()) <= set("-: "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        used_by = sorted({m.group(1) for m in GAP_TOOL_RE.finditer(cells[1]) if m.group(1) in tools})
        rows.append({"what": cells[0], "names": re.findall(r"`([^`]+)`", cells[0]), "tools": used_by,
                     "where": cells[1], "platforms": cells[2], "note": cells[3]})
    return rows


def examples_gaps(examples, tools):
    """GAPS.md's table on the examples' main, or None if it can't be read."""
    try:
        text = git(examples, "show", "main:GAPS.md")
    except RuntimeError:
        return None
    return parse_gaps(text, tools)


# ------------------------------------------------------------------ charts

def cuses_points(hist, today_ledger, today):
    """Chart 3's points before they're merged with the history file: each
    STATUS.md day, then today's ledger run, with each repository's count
    (excluded sites aside)."""
    pts = []
    for h in hist:
        per = {r: n - h["excludedByRepo"].get(r, 0) for r, n in h["perRepo"].items()}
        pts.append({"day": h["day"], "count": h["total"], "perRepo": per, "markers": h.get("markers") or {},
                    "source": "STATUS.md", "commit": h["commit"]})
    if today_ledger:
        per = {r: len(ss) for r, ss in today_ledger["sites"].items()}
        for r in today_ledger["read"]:
            per.setdefault(r, 0)
        p = {"day": today, "count": today_ledger["total"], "perRepo": per,
             "markers": {r: today_ledger["markers"].get(r, 0) for r in per}, "source": "run",
             "commit": today_ledger["meta"].get("head")}
        pts = [x for x in pts if x["day"] != today] + [p]
    return pts


def derive_cuses(rows):
    """Chart 3's scope added and changes, from consecutive points' counts by
    repository. Scope added: the sites of a repository read that the point
    before didn't read, and the SYSTEM-GAP markers over no import a
    repository gained (C use it had, newly marked, and so newly counted).
    The rest of each repository's change is in `changes`. The first point
    is all scope."""
    prev = None
    for r in sorted((r for r in rows if r["chart"] == "cuses"), key=lambda r: r["date"]):
        det = dict(r.get("detail") or {})
        per, mk = det.get("perRepo"), det.get("markers")
        for k in ("changes", "newRepos", "newlyMarked"):
            det.pop(k, None)
        if prev is None:
            r["scope_added"] = r["count"]
        elif per is None or prev.get("perRepo") is None:
            r["scope_added"] = 0
        else:
            new = sorted(k for k in per if k not in prev["perRepo"])
            marked = {}
            if mk is not None and prev.get("markers") is not None:
                marked = {k: mk.get(k, 0) - prev["markers"].get(k, 0) for k in per
                          if k not in new and mk.get(k, 0) > prev["markers"].get(k, 0)}
            r["scope_added"] = sum(per[k] for k in new) + sum(marked.values())
            det["changes"] = {k: per.get(k, 0) - prev["perRepo"].get(k, 0) - marked.get(k, 0)
                              for k in sorted(set(per) | set(prev["perRepo"]))
                              if k not in new and per.get(k, 0) - prev["perRepo"].get(k, 0) - marked.get(k, 0)}
            if new:
                det["newRepos"] = new
            if marked:
                det["newlyMarked"] = marked
        r["detail"] = det
        prev = det if per is not None else None
    return rows


def read_history(path):
    rows = []
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#") or not line.strip() or line.startswith("date\t"):
                    continue
                cells = line.rstrip("\n").split("\t")
                r = dict(zip(HISTORY_COLUMNS, cells + [""] * (len(HISTORY_COLUMNS) - len(cells))))
                r["count"] = int(r["count"])
                r["scope_added"] = int(r["scope_added"] or 0)
                r["detail"] = json.loads(r["detail"]) if r["detail"] else {}
                rows.append(r)
    return rows


def write_history(path, rows):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("# The master view's figures, one row per figure per day; Utilities/master-view/regenerate.sh\n")
        f.write("# adds today's on each run and back-fills earlier days it has no point for (README.md).\n")
        f.write("\t".join(HISTORY_COLUMNS) + "\n")
        order = OLD_CHARTS + CHARTS   # an earlier day's rows keep the order they were written in
        for r in sorted(rows, key=lambda r: (r["date"], order.index(r["chart"]) if r["chart"] in order else 99,
                                             r["chart"])):
            f.write("\t".join([r["date"], r["chart"], str(r["count"]), str(r["scope_added"]), r["source"],
                               r.get("commit") or "",
                               json.dumps(r.get("detail") or {}, sort_keys=True, separators=(",", ":"))]) + "\n")
    os.replace(tmp, path)


def merge_history(rows, computed, today):
    """The history file's rows, with today's computed points replacing any
    earlier today's, and the computed points of days the file has no point
    for added (back-fill). Points the file has for earlier days stand: they
    record what an earlier run showed. Only details a point lacks are
    filled in from the back-fill (a newer tool records more), and only when
    it counts the same."""
    have = {(r["date"], r["chart"]): r for r in rows}
    out = [r for r in rows if r["date"] != today]
    for r in computed:
        old = have.get((r["date"], r["chart"]))
        if r["date"] == today or old is None:
            out.append(r)
        elif old["count"] == r["count"]:
            old["detail"] = dict(r.get("detail") or {}, **(old.get("detail") or {}))
    return out


def history_rows(headline, pkgs, cus, today, head):
    """The history file's rows this run computes: today's headline figures
    (the new API real users use, and how much of it is in no pitch), and the
    C uses left in update-checkout, each STATUS.md day and today, with each
    repository's count (and today, the split by cluster and the set-aside
    packages' counts)."""
    u = headline["use"]
    used_by = {p["name"]: [len(p["usage"]["new"]), (p["usage"].get("commit") or "")[:10]]
               for p in pkgs if p.get("usage") and not p.get("aside")}
    rows = [{"date": today, "chart": "used", "count": u["any"], "scope_added": 0, "source": "run", "commit": head or "",
             "detail": {"groups": {g: u["groups"][g]["declarations"] for g in CLUSTERS}, "adopters": u["adopters"],
                        "examples": u["examples"], "both": u["both"], "packages": used_by}},
            {"date": today, "chart": "unpitched-used", "count": u["unpitched"], "scope_added": 0, "source": "run",
             "commit": head or "", "detail": {"byState": u["byState"],
                                              "groups": {g: u["groups"][g]["unpitched"] for g in CLUSTERS}}}]
    aside = {p["name"]: len((p.get("cUse") or {}).get("sites") or []) for p in pkgs
             if p.get("aside") and p["cluster"] == "update-checkout"}
    for p in cus:
        det = {"perRepo": p["perRepo"], "markers": p.get("markers") or {}}
        if p["source"] == "run":
            det["split"] = {g: {b: headline["cuses"][g][b] for b in SPLIT} for g in CLUSTERS}
            det["aside"] = aside
        rows.append({"date": p["day"], "chart": "cuses", "count": p["count"], "scope_added": 0,
                     "source": "run" if p["source"] == "run" else "back-fill: STATUS.md", "commit": p.get("commit") or "",
                     "detail": det})
    return rows


def derive_used(rows):
    """Each "used" point's changes from the one before, by package: how
    many more or fewer new declarations it uses, and why it can have moved:
    its branch moved (adopter work), it's read for the first time, or
    neither (System changed under it, or how it's read did)."""
    prev = None
    for r in sorted((r for r in rows if r["chart"] == "used"), key=lambda r: r["date"]):
        det = dict(r.get("detail") or {})
        det.pop("changes", None)
        now = det.get("packages")
        if prev is not None and now is not None:
            ch = {}
            for name in sorted(set(now) | set(prev)):
                a_, b_ = prev.get(name), now.get(name)
                n = (b_[0] if b_ else 0) - (a_[0] if a_ else 0)
                if not n:
                    continue
                why = "read for the first time" if a_ is None else ("no longer read" if b_ is None else
                                                                   "its branch moved" if a_[1] != b_[1] else
                                                                   "same commit: System or the reading changed")
                ch[name] = [n, why]
            det["changes"] = ch
        r["detail"] = det
        prev = now if now is not None else prev
    return rows


def chart_series(rows, chart):
    """[{date, count, scopeAdded, detail, source, commit}] for one chart, by date."""
    return [{"date": r["date"], "count": r["count"], "scopeAdded": r["scope_added"], "detail": r["detail"],
             "source": r["source"], "commit": r.get("commit") or ""}
            for r in sorted((r for r in rows if r["chart"] == chart), key=lambda r: r["date"])]


# ------------------------------------------------------------------ assembly

def import_burndown():
    sys.path.insert(0, os.path.join(UTILITIES, "api-burndown", "scripts"))
    import burndown  # noqa: E402  (api-burndown's own unit-to-node mapping)
    return burndown


def assemble(a):
    problems = []
    today = a.today or datetime.date.today().isoformat()
    rows = uv.read(a.universe)
    pkgs = [r for r in rows if r["cluster"] in CLUSTERS]
    left_out = [r for r in rows if r["cluster"] == "excluded"]
    aside = load_set_aside(a.set_aside)

    bd = load_json(os.path.join(a.burndown, "burndown.json"))
    delta_dir = os.path.join(a.burndown, "api-delta")
    delta = load_json(os.path.join(delta_dir, "api-delta.json"))
    units = bd["declarations"]
    groups = delta_groups(delta)

    gpath = a.graph or bd["meta"]["graph"]["path"]
    doc = load_json(gpath)
    nodes = doc["nodes"]
    used, gpkgs = graph_index(doc)
    burndown = import_burndown()
    u2n = burndown.unit_nodes(units, doc)
    own, same = owners(units, u2n, nodes)
    head_usrs = {nid for nid, n in nodes.items() if n["kind"] == "declaration" and n.get("origin") == "head"}

    # The packages: the universe's, with the graph's package nodes by remote.
    by_remote = {}
    for nid, n in gpkgs.items():
        if n.get("remote"):
            by_remote.setdefault(n["remote"].lower(), nid)
    # A package node is one row's, or, for a clone whose rows each cover a
    # directory (the examples' tools), split among them by each site's file.
    node_pkg, node_split = {}, {}
    split_rows = subdir_rows(pkgs)
    for i, r in enumerate(pkgs):
        key = (r.get("remote") or "").lower()
        nid = by_remote.get(key)
        if not nid:
            continue
        if key in split_rows:
            node_split[nid] = split_rows[key]
        else:
            node_pkg.setdefault(nid, i)
    graph_not_in_universe = sorted(n["name"] for nid, n in gpkgs.items() if nid not in node_pkg and
                                   nid not in node_split)

    # By API: every added declaration, with its owner's uses.
    decls = []
    uid_index = {}
    for u in units:
        uid_index[u["id"]] = len(decls)
        decls.append(u)
    used_by = collections.defaultdict(list)     # decl index -> [(pkg index, [sites])]
    used_missing = collections.Counter()        # graph packages a declaration's uses name, not in the universe
    for nid, uid in own.items():
        di = uid_index[uid]
        for ln in used.get(nid, ()):
            sites = [site_tuple(s) for s in ln.get("sites") or []]
            sites.sort(key=lambda s: (s[0], s[1], s[2]))
            if ln["to"] in node_split:
                by_row = collections.defaultdict(list)
                for st in sites:
                    pi = row_of_file(node_split[ln["to"]], st[0])
                    if pi is None:
                        used_missing[f"{gpkgs[ln['to']].get('name')} (outside its rows' directories)"] += 1
                    else:
                        by_row[pi].append(st)
                for pi, ss in sorted(by_row.items()):
                    used_by[di].append([pi, ss])
                continue
            pi = node_pkg.get(ln["to"])
            if pi is None:
                used_missing[(gpkgs.get(ln["to"]) or {}).get("name") or ln["to"]] += len(sites)
                continue
            used_by[di].append([pi, sites])
    # Uses of graph nodes no added declaration owns: a declaration api-delta
    # lists as changed rather than added (FileDescriptor.close(), whose USR
    # changed), which the page counts as API already on main.
    unowned = {}
    for nid, lns in used.items():
        if nid in own:
            continue
        n = nodes.get(nid) or {}
        unowned[n.get("path") or nid] = {(gpkgs.get(ln["to"]) or {}).get("name") or ln["to"]: len(ln.get("sites") or [])
                                         for ln in lns}
    out_decls = []
    for di, u in enumerate(decls):
        ub = sorted(used_by.get(di, []), key=lambda x: pkgs[x[0]]["name"].lower())
        out_decls.append({
            "id": u["id"], "module": u["module"], "path": u["path"], "title": u["title"], "kind": u["kind"],
            "kindName": u["kindName"], "area": u["area"], "type": type_group(u, groups), "state": u["state"],
            "pitch": u.get("pitch"), "pitches": u.get("pitches") or [], "flags": u.get("flags") or [],
            "excluded": bool(u.get("excluded")), "file": u.get("file"), "line": u.get("line"),
            "platforms": u.get("platforms") or [], "availability": u.get("availability") or "",
            "decl": u.get("decl") or "", "doc": u.get("docSummary") or "", "cName": u.get("cName"),
            "header": u.get("header"), "origin": u["origin"], "hiddenClass": u.get("hiddenClass"),
            "usedBy": ub, "sameAs": uid_index[same[u["id"]]] if u["id"] in same else None,
        })

    # Migrations, uses and C use, package by package.
    main, changed, main_types = base_api(delta_dir)
    led = ledger_from_json(load_json(a.ledger_json)) if a.ledger_json and os.path.exists(a.ledger_json) else None
    if not led:
        problems.append(f"no ledger JSON at {a.ledger_json}: the update-checkout cluster's C use isn't shown")
    sv, sv_date = survey(a.ecosystem)
    runs = ecosystem_runs(a.coverage_results)
    links = WebLinks()
    tools = [r["name"] for r in pkgs if r["cluster"] == "Unix tools"]
    gaps = examples_gaps(a.examples, set(tools)) if tools else None
    new_by_pkg = collections.defaultdict(list)   # pkg index -> [(decl index, sites)]
    for di, d in enumerate(out_decls):
        for pi, sites in d["usedBy"]:
            new_by_pkg[pi].append([di, sites])
    out_pkgs = []
    branch_differs = []
    cache_checks = []
    ledger_names = set(led["sites"]) | set(led["read"]) | set(led["notRead"]) if led else set()
    uc_names = {r["name"] for r in pkgs if r["cluster"] == "update-checkout"}
    for i, r in enumerate(pkgs):
        clone = os.path.normpath(os.path.join(a.repo, r["clone"])) if r["clone"] not in ("", "none") else None
        rec = {"name": r["name"], "cluster": r["cluster"], "source": r["source"], "remote": r.get("remote") or "",
               "clone": r["clone"] if clone else None, "swift": r.get("swift") or "?", "note": r.get("note") or "",
               "subdir": r.get("subdir") or None, "migration": None, "usage": None, "cUse": None,
               "aside": aside.get((r.get("remote") or "").lower())}
        nid = next((n for n, pi in node_pkg.items() if pi == i), None) or \
            next((n for n, rs in node_split.items() if any(pi == i for _, pi in rs)), None)
        gnode = gpkgs.get(nid) if nid else None
        prefix = (r["subdir"].rstrip("/") + "/") if r.get("subdir") else None
        # The migration, if its clone is a migrated one.
        if clone and r["cluster"] != "Unix tools" and os.path.isdir(clone) and \
                realpath(clone).startswith(realpath(a.adopters) + os.sep):
            mig = migration(clone)
            if mig:
                ad = (gnode or {}).get("adopted")
                mig["readAt"] = {"branch": ad["branch"], "commit": ad["commit"],
                                 "resolution": ad.get("resolution"), "subject": ad.get("subject"),
                                 "build": (ad.get("build") or {}).get("status")} if ad else None
                rec["migration"] = mig
                if mig["newest"]["commits"] and (not ad or ad["commit"] != mig["newest"]["commit"]):
                    branch_differs.append({"package": i, "newest": mig["newest"]["branch"],
                                           "newestCommit": mig["newest"]["commit"],
                                           "readBranch": ad["branch"] if ad else None,
                                           "readCommit": ad["commit"] if ad else None})
        # System API it uses: the new declarations (By API's uses, reversed)
        # and those already on main (the migration build's index).
        new = sorted(new_by_pkg.get(i, []), key=lambda x: out_decls[x[0]]["path"])
        on_main = []
        cache_file = None
        if gnode and gnode.get("adopted"):
            cache_file, cache = adopter_cache_file(a.graph_cache, gnode)
            if cache:
                om, refs = main_usage(cache, main, changed, head_usrs, prefix)
                for usr, sites in om.items():
                    name = main.get(usr) or changed.get(usr) or usr
                    on_main.append({"usr": usr, "path": name, "changed": usr in changed and usr not in main,
                                    "sites": sorted(sites)})
                on_main.sort(key=lambda x: x["path"])
                graph_usrs = collections.Counter()
                for di, sites in new:
                    d = out_decls[di]
                    nid_ = u2n.get(d["id"])
                    graph_usrs[nid_] += sum(1 for s in sites if s[3] in "pq")
                only_index = sorted(set(refs) - set(graph_usrs))
                only_graph = sorted(u for u, n in graph_usrs.items() if n and u not in refs)
                cache_checks.append({"package": i, "indexOnly": len(only_index), "graphOnly": len(only_graph),
                                     "indexOnlyExamples": [nodes.get(u, {}).get("path") or u for u in only_index[:5]],
                                     "graphOnlyExamples": [nodes.get(u, {}).get("path") or u for u in only_graph[:5]]})
            else:
                problems.append(f"{r['name']}: no cached index of its migration build in {a.graph_cache}, "
                                "so the API already on main it uses isn't shown")
        if gnode and gnode.get("adopted") or new or on_main:
            ad = (gnode or {}).get("adopted") or {}
            rec["usage"] = {"new": new, "main": on_main, "branch": ad.get("branch"), "commit": ad.get("commit"),
                            "resolution": ad.get("resolution"), "cache": cache_file,
                            "link": links.base(clone, ad.get("commit"), r.get("remote"))}
        # C use: the ledger for update-checkout; the scans for the rest;
        # GAPS.md for the Unix tools.
        if r["cluster"] == "update-checkout" and led:
            read = led["read"].get(r["name"])
            if read:
                ss = [site_record(s, led["work"]) for s in led["sites"].get(r["name"], [])]
                ss.sort(key=lambda s: (s["file"], s["line"]))
                lacks = sorted({n for s in ss for n in s["lacks"]})
                rec["cUse"] = {"source": "ledger", "where": read.get("where"), "commit": read.get("commit"),
                               "scope": read.get("scope"), "sites": ss, "lacks": lacks,
                               "byCategory": dict(collections.Counter(s["category"] for s in ss)),
                               "split": dict({b: sum(1 for x in ss if x["bucket"] == b) for b in SPLIT},
                                             parts=dict(collections.Counter(x["part"] for x in ss))),
                               "link": links.base(clone if clone else None, read.get("commit"), r.get("remote"))}
                if r["name"] in led["notRead"]:
                    rec["cUse"]["partial"] = led["notRead"][r["name"]]
            elif r["name"] in led["notRead"]:
                rec["cUse"] = {"source": "ledger", "notRead": led["notRead"][r["name"]]}
        elif r["cluster"] in ("swiftlang and apple", "ecosystem") and clone:
            du = darwin_use(clone, r.get("remote"), sv, runs)
            if du:
                du["source"] = "scan"
                du["surveyDate"] = sv_date
                du["link"] = links.base(clone, du.get("commit"), r.get("remote"))
                sp = scan_split(du)
                du["split"] = {b: sp[b] for b in SPLIT}
                du["split"]["parts"] = sp["parts"]
                du["fileBuckets"] = sp["files"]
                rec["cUse"] = du
        elif r["cluster"] == "Unix tools" and gaps is not None:
            mine = [g for g in gaps if r["name"] in g["tools"]]
            rec["cUse"] = {"source": "GAPS.md", "gaps": mine,
                           "split": {"covers": 0, "lacks": len(mine), "other": 0,
                                     "parts": {"a gap in GAPS.md": len(mine)} if mine else {}},
                           "commit": rev(a.examples, "main")}
        # The kind of data it has.
        if rec["swift"] == "no":
            kind = "no-swift"
        elif rec["migration"] and rec["migration"]["newest"]["commits"]:
            kind = "migrated"
        elif r["cluster"] == "Unix tools" and rec["usage"]:
            kind = "on-system"
        elif rec["cUse"] and rec["cUse"].get("source") in ("ledger", "scan") and not rec["cUse"].get("notRead"):
            kind = "scanned"
        else:
            kind = "not-scanned"
        rec["kind"] = kind
        out_pkgs.append(rec)

    # The headline, and its figures over time: today's, the C uses' back-fill
    # from STATUS.md's history, merged with the history file.
    headline = intersection(out_decls, out_pkgs, gaps)
    hist = status_history(a.repo) if not a.no_status_history else []
    cus = cuses_points(hist, led, today)
    computed = history_rows(headline, out_pkgs, cus, today, bd["meta"].get("headCommit"))
    rows_before = read_history(a.history)
    merged = derive_used(derive_cuses(merge_history(rows_before, computed, today)))
    charts = {c: chart_series(merged, c) for c in CHARTS}

    # Where the two ways in, and the inputs, disagree.
    notes = {
        "branchDiffers": branch_differs,
        "graphPackagesNotInUniverse": graph_not_in_universe,
        "usesOfPackagesNotInUniverse": dict(used_missing),
        "ledgerReposNotInUniverse": sorted(n for n in ledger_names if n not in uc_names),
        "universeNotInLedger": sorted(n for n in uc_names if led and n not in ledger_names),
        "migratedWithoutUsage": [i for i, p in enumerate(out_pkgs) if p["kind"] == "migrated" and
                                 not (p["usage"] and p["usage"].get("branch"))],
        "sharedUses": len(same),
        "usesNotOfNewAPI": unowned,
        "indexVersusGraph": [c for c in cache_checks if c["indexOnly"] or c["graphOnly"]],
        "leftOut": [{"name": r["name"], "source": r["source"], "remote": r.get("remote"), "why": r.get("note")}
                    for r in left_out],
    }

    used_runs = {(p["cUse"].get("run") or {}).get("id") for p in out_pkgs if p.get("cUse") and p["cUse"].get("source") == "scan"}
    bm = bd["meta"]
    meta = {
        "generated": today,
        "head": {"ref": bm.get("headRef"), "commit": bm.get("headCommit"), "subject": bm.get("headSubject")},
        "base": {"ref": bm.get("baseRef"), "commit": bm.get("baseCommit"), "subject": bm.get("baseSubject")},
        "apiDelta": {"date": delta["meta"].get("date"), "added": sum(1 for e in delta["entries"]
                                                                       if e["status"] == "added"),
                     "hidden": len(delta["hiddenFromGraphs"]["added"]), "swift": delta["meta"].get("swift")},
        "burndown": {"path": os.path.abspath(os.path.join(a.burndown, "burndown.json")), "digest": bd.get("digest"),
                     "states": bm.get("states"), "pitches": (bm.get("pitches") or {}).get("files"),
                     "upstream": bm.get("upstream")},
        "graph": {"path": os.path.abspath(gpath), "commit": (doc.get("meta") or {}).get("headCommit"),
                  "date": (doc.get("meta") or {}).get("date"),
                  "matchesHead": (doc.get("meta") or {}).get("headCommit") == bm.get("headCommit"),
                  "behind": commits_between(a.repo, (doc.get("meta") or {}).get("headCommit"), bm.get("headCommit")),
                  "withoutNode": sum(1 for d in out_decls if "nograph" in d["flags"]),
                  "adopterBranches": (((doc.get("meta") or {}).get("adopterMeta") or {}).get("branches") or
                                      [((doc.get("meta") or {}).get("adopterMeta") or {}).get("branch")]),
                  "cache": os.path.relpath(a.graph_cache, a.repo) if a.graph_cache else None},
        "ledger": ({"json": os.path.abspath(a.ledger_json), "statusMd": os.path.abspath(a.status_md)
                    if a.status_md else None, "date": led["meta"].get("date"), "system": led["meta"].get("system"),
                    "total": led["total"], "byCategory": led["byCategory"], "excluded": led["excluded"],
                    "floor": led["floor"]} if led else None),
        "survey": {"date": sv_date, "entries": len(sv)},
        "runs": [{"id": r["id"], "date": r["date"], "systemCommit": r["systemCommit"], "file": r["file"]}
                 for r in runs if r["id"] in used_runs],
        "examples": {"path": a.examples, "commit": rev(a.examples, "main") if os.path.isdir(a.examples) else None},
        "universe": {"path": os.path.abspath(a.universe),
                     "counts": {c: sum(1 for r in pkgs if r["cluster"] == c) for c in CLUSTERS},
                     "leftOut": len(left_out)},
        "history": {"path": os.path.abspath(a.history) if a.history else None, "rowsBefore": len(rows_before)},
        "statusHistory": [{"day": h["day"], "commit": h["commit"], "total": h["total"]} for h in hist],
        "problems": problems,
        "typeTags": type_tags(out_decls, main_types, nodes),
        "labels": {"clusters": CLUSTER_LABELS, "kinds": KIND_LABELS, "states": STATE_LABELS,
                   "categories": CATEGORY_LABELS, "queueKinds": QUEUE_KIND_LABELS, "split": SPLIT_LABELS,
                   "parts": PARTS},
    }
    result = {"schema": SCHEMA, "meta": meta, "headline": headline, "declarations": out_decls,
              "packages": out_pkgs, "charts": charts, "notes": notes}
    return result, merged


def commits_between(repo, a, b):
    """How many commits b has that a doesn't, or None."""
    if not (a and b):
        return None
    out = git(repo, "rev-list", "--count", f"{a}..{b}", ok=(0, 128)).strip()
    return int(out) if out.isdigit() else None


def digest(obj):
    body = json.dumps(obj, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(body.encode()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description="Assemble the master view's data (master.json).")
    ap.add_argument("--repo", required=True)
    ap.add_argument("--universe", required=True)
    ap.add_argument("--burndown", required=True, help="api-burndown's output directory (burndown.json, api-delta/)")
    ap.add_argument("--graph", help="the API graph (default: the one burndown.json names)")
    ap.add_argument("--graph-cache", help="api-graph's adopter cache (.build/api-graph-cache)")
    ap.add_argument("--ledger-json", help="status.sh's ledger.json")
    ap.add_argument("--status-md", help="the STATUS.md written with it")
    ap.add_argument("--adopters", required=True)
    ap.add_argument("--ecosystem", required=True)
    ap.add_argument("--examples", required=True)
    ap.add_argument("--coverage-results")
    ap.add_argument("--history", help="the tracked history file, read and rewritten")
    ap.add_argument("--set-aside", help="set-aside.tsv: packages kept out of the headline")
    ap.add_argument("--no-status-history", action="store_true", help="don't back-fill chart 3 from git")
    ap.add_argument("--today")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    for k in ("repo", "adopters", "ecosystem", "examples"):
        setattr(a, k, os.path.realpath(getattr(a, k)))
    result, rows = assemble(a)
    result["digest"] = digest(result)
    tmp = a.out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(result, f, sort_keys=True, indent=0)
    os.replace(tmp, a.out)
    if a.history:
        write_history(a.history, rows)
    m = result["meta"]
    kinds = collections.Counter(p["kind"] for p in result["packages"])
    print(f"assemble: {len(result['declarations'])} declarations, {len(result['packages'])} packages "
          f"({', '.join(f'{kinds[k]} {KIND_LABELS[k]}' for k in KINDS)}); C uses left in update-checkout: "
          f"{m['ledger']['total'] if m['ledger'] else 'n/a'} -> {a.out}")
    for p in m["problems"]:
        print(f"assemble: note: {p}")


if __name__ == "__main__":
    main()
