#!/usr/bin/env python3
"""The burn-down's history: what the head ref adds over the base ref, day by day.

There's one point per day, from the day of the head ref's first first-parent
commit that isn't on the base ref, to today. Each point is the last
first-parent commit of the head ref that day, or, on a day with none, the
last one before it. A commit's day is its committer date in the time zone
it was recorded in.

A point's declarations come from api-delta's source scan
(Utilities/api-delta/scripts/scan_sources.py) of its commit and of the base
ref's commit that day. A public declaration is new when the base has fewer
declarations with the same module, path and signature (attributes and
access modifiers dropped, so an availability edit isn't a new declaration).
That reproduces api-delta's added list except for what the scan can't see:
enum cases, which have no `public` keyword, and implicit members.
Where the api-graph snapshot store has a point's commit, its graph adds
those, and the declarations main already has on other platforms that the
commit adds on Darwin, so the point matches api-delta's method. The head
commit's point is api-delta's own list, which burndown.py passes in.

Scans are cached by commit, keyed by the scanner's contents and this
file's SCAN_FORMAT, so a rerun scans only commits it hasn't seen.
"""

import sys

sys.dont_write_bytecode = True

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
UTILITIES = os.path.normpath(os.path.join(HERE, "..", ".."))
SCAN_SOURCES = os.path.join(UTILITIES, "api-delta", "scripts", "scan_sources.py")
sys.path.insert(0, os.path.join(UTILITIES, "api-delta", "scripts"))
import scan_sources as ss  # noqa: E402  (api-delta's lexer, for its attribute pattern)

# Bump when the cached scan's shape or the reduction below changes.
SCAN_FORMAT = 3
MODULE_DIRS = ss.MODULE_DIRS
ACCESS_RE = re.compile(r"\b(?:public|open|internal|package)\b(?:\([^)]*\))?")
ATTR_RE = re.compile(ss.ATTR)

# The kinds api-graph gives scan-only declarations (build_graph.py), which
# scan_kind refines as the symbol graphs do.
SCAN_KIND = {"struct": "swift.struct", "enum": "swift.enum", "class": "swift.class", "protocol": "swift.protocol",
             "actor": "swift.actor", "typealias": "swift.typealias", "func": "swift.method", "init": "swift.init",
             "init?": "swift.init", "init!": "swift.init", "var": "swift.property", "let": "swift.property",
             "subscript": "swift.subscript", "case": "swift.enum.case", "macro": "swift.macro"}
# A function named by an operator, not an identifier: `==(lhs:rhs:)`, and
# `< ()`, as the scanner names `static func < (lhs:rhs:)`.
OPERATOR_NAME_RE = re.compile(r"\s*[^\w\s`(]")

# An enum case declaration at the start of a line: `case a`, `case b(Int)`,
# `indirect case c`, after any attributes.
CASE_RE = re.compile(r"^(\s*(?:@[A-Za-z_][\w.]*(?:\([^()]*\))?\s*)*(?:indirect\s+)?)(case)\s+[A-Za-z_`]")

# Flags that put a declaration outside the main count.
EXCLUDED = ("deprecated", "underscored", "spi", "stub")


# ------------------------------------------------------------------ git

def git(repo, *args, check=True):
    p = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def first_parent(repo, commit, exclude=None):
    """[(commit, day, subject)], newest first."""
    rng = f"{exclude}..{commit}" if exclude else commit
    out = git(repo, "log", "--first-parent", "--no-show-signature", "--format=%H%x09%cd%x09%s",
              "--date=format:%Y-%m-%d", rng)
    rows = []
    for line in out.splitlines():
        c, day, subject = (line.split("\t", 2) + ["", ""])[:3]
        rows.append((c, day, subject))
    return rows


def days_between(start, end):
    d = datetime.date.fromisoformat(start)
    e = datetime.date.fromisoformat(end)
    out = []
    while d <= e:
        out.append(d.isoformat())
        d += datetime.timedelta(days=1)
    return out


def last_on_or_before(rows, day):
    """The newest of rows (newest first) whose day is on or before `day`."""
    for c, d, s in rows:
        if d <= day:
            return c, d, s
    return None


def points(repo, head_commit, base_commit, today):
    """One point per day: {day, commit, subject, commitDay, base, baseDay}."""
    head_rows = first_parent(repo, head_commit, exclude=base_commit)
    if not head_rows:
        return []
    base_rows = first_parent(repo, base_commit)
    start = min(d for _, d, _ in head_rows)
    end = max(today, max(d for _, d, _ in head_rows))
    out = []
    for day in days_between(start, end):
        h = last_on_or_before(head_rows, day)
        b = last_on_or_before(base_rows, day) or base_rows[-1]
        out.append({"day": day, "commit": h[0], "commitDay": h[1], "subject": h[2],
                    "newCommit": h[1] == day, "base": b[0], "baseDay": b[1]})
    return out


# ------------------------------------------------------------------ scans

def tool_hash():
    h = hashlib.sha1()
    with open(SCAN_SOURCES, "rb") as f:
        h.update(f.read())
    h.update(f"format {SCAN_FORMAT}".encode())
    return h.hexdigest()[:12]


def sig_norm(sig):
    s = ATTR_RE.sub(" ", sig or "")
    s = ACCESS_RE.sub(" ", s)
    return re.sub(r"\s+", " ", s).strip()


def is_public(d):
    a = d.get("access") or ""
    return a.startswith("public") or a == "open"


def scan_kind(d):
    """A scanned declaration's kind, as the symbol graphs give it (Swift
    6.2): an operator is `swift.func.op`, a type's static member or global;
    a `class` member is static, like a `static` one; a static subscript is
    a type subscript. A top-level `var` stays a property, not the symbol
    graphs' `swift.var`: the scanner loses some declarations' scopes
    (IORing.swift's instance properties)."""
    kw = d["kw"]
    if kw == "func" and OPERATOR_NAME_RE.match(d["name"]):
        return "swift.func.op"
    kind = SCAN_KIND.get(kw, "swift." + kw)
    if kw == "func" and not d["scopes"]:
        kind = "swift.func"
    if kw in ("var", "let", "func", "subscript") and {"static", "class"} & set(d["modifiers"]):
        kind = {"swift.method": "swift.type.method", "swift.property": "swift.type.property",
                "swift.subscript": "swift.type.subscript"}.get(kind, kind)
    return kind


def scan_flags(d):
    flags = []
    if d.get("deprecated"):
        flags.append("deprecated")
    # A fix-it stub's name is the C name it renames (`_SC_ARG_MAX`), so it's
    # a stub, not underscored API; api-delta classifies it the same way.
    if d.get("unavailable"):
        flags.append("stub")
    elif d.get("underscored") or any(s.startswith("_") for s in d.get("scopes") or []):
        flags.append("underscored")
    # The scan records a declaration's own attributes, not its extension's,
    # so `@_spi` on an enclosing extension isn't seen (README, limitations).
    if any(a.startswith("@_spi") for a in d.get("attributes") or []):
        flags.append("spi")
    return flags


def top_level_colon(code):
    depth = 0
    for ch in code:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == ":" and depth == 0:
            return True
    return False


def mark_enum_cases(raw):
    """The source with `public` before each enum case declaration.

    The scanner records declarations spelled `public`, and an enum case
    never is, so a scan would miss every new case. This marks the cases at
    the top level of an enum's body (not a switch's `case .a:` inside a
    method) in the scratch export, and reduce_scan keeps those of public
    enums. Line numbers don't change. A line with two cases (`case a, b`)
    yields only the first."""
    code, _ = ss.strip_comments_and_strings(raw)
    raw_lines, code_lines = raw.split("\n"), code.split("\n")
    stack, header = [], ""
    for idx, line in enumerate(code_lines):
        m = CASE_RE.match(line)
        if m and stack and stack[-1] == "enum" and not top_level_colon(line[m.end(2):]):
            col = m.start(2)
            if raw_lines[idx][col:col + 4] == "case":
                raw_lines[idx] = raw_lines[idx][:col] + "public " + raw_lines[idx][col:]
        for i, ch in enumerate(line):
            if ch == "{":
                kws = list(ss.LAST_KW_RE.finditer(header + " " + line[:i]))
                stack.append("enum" if kws and kws[-1].group(1) == "enum" else "other")
                header = ""
            elif ch == "}":
                if stack:
                    stack.pop()
                header = ""
            elif ch == ";":
                header = ""
        header = (header + " " + line[max(line.rfind("{"), line.rfind("}"), line.rfind(";")) + 1:])[-4000:]
    return "\n".join(raw_lines)


def mark_tree(root):
    for d in MODULE_DIRS:
        for dirpath, _, files in os.walk(os.path.join(root, d)):
            for f in files:
                if f.endswith(".swift"):
                    path = os.path.join(dirpath, f)
                    with open(path, encoding="utf-8") as fh:
                        raw = fh.read()
                    marked = mark_enum_cases(raw)
                    if marked != raw:
                        with open(path, "w", encoding="utf-8") as fh:
                            fh.write(marked)


def is_case_of_public_enum(d):
    """A marked case api-delta would list: of a public enum, compiled on
    Darwin (api-delta sees cases only in the macOS symbol graphs)."""
    if "Darwin" not in (d.get("platforms") or []):
        return False
    kinds, access = d.get("scopeKinds") or [], d.get("scopeAccess") or []
    if not kinds or kinds[-1] != "enum" or access[-1] not in ("public", "open"):
        return False
    return all(a in ("public", "open") or k == "extension" for k, a in zip(kinds, access))


def reduce_scan(scan):
    """The scan's public declarations, with stable IDs.

    A declaration's ID is module|path|signature, and #n for the nth of
    several with the same key, in file and line order."""
    decls = [d for d in scan["declarations"] if is_public(d) and (d["kw"] != "case" or is_case_of_public_enum(d))]
    decls.sort(key=lambda d: (d["file"], d["line"]))
    seen = collections.Counter()
    out = []
    for d in decls:
        path = ".".join(d["scopes"] + [d["name"]])
        sig = sig_norm(d["signature"])
        key = (d["module"], path, sig)
        seen[key] += 1
        uid = f"{d['module']}|{path}|{sig}" + (f"#{seen[key]}" if seen[key] > 1 else "")
        out.append({"id": uid, "occ": seen[key], "module": d["module"], "path": path, "sig": sig,
                    "file": d["file"], "line": d["line"], "kind": scan_kind(d), "title": d["name"],
                    "platforms": d["platforms"], "flags": scan_flags(d),
                    "renamedTo": (re.search(r'renamed:\s*"([^"]*)"', " ".join(d.get("unavailable") or [])) or [None, None])[1],
                    "decl": re.sub(r"\s+", " ", d["signature"]).strip()})
    return {"declarations": out, "unsupported": scan.get("moduleUnsupportedPlatforms", {})}


def export_sources(repo, commit, dest):
    present = git(repo, "ls-tree", "--name-only", commit, "Sources/").split()
    dirs = [d for d in MODULE_DIRS if d in present]
    if not dirs:
        raise RuntimeError("no Sources/System or Sources/SystemSockets")
    os.makedirs(dest, exist_ok=True)
    archive = subprocess.Popen(["git", "-C", repo, "archive", commit, *dirs], stdout=subprocess.PIPE)
    untar = subprocess.run(["tar", "-x", "-C", dest], stdin=archive.stdout, capture_output=True)
    archive.stdout.close()
    if archive.wait() != 0 or untar.returncode != 0:
        raise RuntimeError(f"git archive {commit[:10]} failed: {untar.stderr.decode().strip()}")


def scan_commit(repo, commit, cache, work):
    """The reduced scan of a commit, from the cache or by scanning it."""
    path = os.path.join(cache, f"scan-{commit}-{tool_hash()}.json.gz")
    if os.path.exists(path):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f), True
    root = os.path.join(work, f"export-{commit[:12]}")
    if os.path.exists(root):
        shutil.rmtree(root)
    try:
        export_sources(repo, commit, root)
        mark_tree(root)
        out = os.path.join(work, f"scan-{commit[:12]}.json")
        p = subprocess.run([sys.executable, SCAN_SOURCES, root, out], capture_output=True, text=True,
                           env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        if p.returncode != 0:
            last = (p.stderr.strip().splitlines() or ["(no output)"])[-1]
            raise RuntimeError(f"scan_sources.py failed: {last}")
        with open(out, encoding="utf-8") as f:
            reduced = reduce_scan(json.load(f))
        os.remove(out)
    finally:
        if os.path.exists(root):
            shutil.rmtree(root)
    os.makedirs(cache, exist_ok=True)
    tmp = path + ".tmp"
    with gzip.open(tmp, "wt", encoding="utf-8") as f:
        json.dump(reduced, f, separators=(",", ":"))
    os.replace(tmp, path)
    return reduced, False


def path_counts(reduced):
    return collections.Counter((d["module"], d["path"]) for d in reduced["declarations"])


def new_units(head, base):
    """Head declarations whose (module, path, signature) the base has fewer of."""
    have = collections.Counter((d["module"], d["path"], d["sig"]) for d in base["declarations"])
    return [d for d in head["declarations"] if d["occ"] > have[(d["module"], d["path"], d["sig"])]]


# ------------------------------------------------------------------ snapshots

def graph_only_id(module, path, kind, seen):
    k = (module, path, kind)
    seen[k] += 1
    return f"{module}|{path}|graph:{kind}" + (f"#{seen[k]}" if seen[k] > 1 else "")


def units_with_snapshot(head, base, snapshot):
    """new_units, plus what the snapshot's graph has that the scan doesn't
    show as new: declarations without a scanned declaration at their
    location (enum cases, implicit members), and Darwin declarations whose
    key main has on other platforms."""
    units = {d["id"]: d for d in new_units(head, base)}
    at = {(d["file"], d["line"]): d for d in head["declarations"]}
    seen = collections.Counter()
    nodes = snapshot["nodes"]
    graph_nodes = sorted((nid for nid, n in nodes.items() if n["kind"] == "declaration"
                          and n.get("origin") == "head" and n.get("source") == "graph"),
                         key=lambda nid: (nodes[nid].get("file") or "", nodes[nid].get("line") or 0, nid))
    for nid in graph_nodes:
        n = nodes[nid]
        d = at.get((n.get("file"), n.get("line")))
        if d:
            if d["id"] not in units:
                units[d["id"]] = dict(d, origin="graph")
            continue
        uid = graph_only_id(n["module"], n["path"], n.get("symbolKind") or "", seen)
        units[uid] = {"id": uid, "module": n["module"], "path": n["path"], "sig": "", "file": n.get("file"),
                      "line": n.get("line"), "kind": n.get("symbolKind"), "title": n.get("title"),
                      "platforms": n.get("platforms") or ["Darwin"], "flags": ["deprecated"] if n.get("deprecated") else [],
                      "decl": n.get("decl") or "", "origin": "graph"}
    return list(units.values())


def load_snapshot(path):
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return json.load(f)


def store_index(store):
    """{commit: snapshot path} for the snapshot store."""
    out = {}
    idx = os.path.join(store, "index.json") if store else None
    if idx and os.path.exists(idx):
        try:
            with open(idx, encoding="utf-8") as f:
                entries = json.load(f)
            for e in entries:
                p = os.path.join(store, e.get("file") or f"{e['headCommit']}.json.gz")
                if os.path.exists(p):
                    out[e["headCommit"]] = p
        except (ValueError, KeyError):
            pass
    return out


# ------------------------------------------------------------------ merged

def merged_by_point(sets, main_counts):
    """For each point i, {unit id: unit} of declarations merged by then.

    sets[i] is {id: unit} at point i, main_counts[i] the base's Counter of
    (module, path) that day. A declaration last seen at point j < i, and
    absent at i, is merged at i if the base has more declarations with its
    module and path than it did at j: it left the delta because main gained
    it, not because it was removed."""
    last_seen = {}
    out = []
    for i, cur in enumerate(sets):
        merged = {}
        for uid, (j, u) in last_seen.items():
            if uid in cur:
                continue
            k = (u["module"], u["path"])
            if main_counts[i][k] > main_counts[j][k]:
                merged[uid] = u
        out.append(merged)
        for uid, u in cur.items():
            last_seen[uid] = (i, u)
    return out
