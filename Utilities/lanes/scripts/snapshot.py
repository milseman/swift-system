#!/usr/bin/env python3
"""A snapshot of every lane, the integration branches, the Linux logs, lint
and the environment: everything the coordinator gathers on a check-in, at
full fidelity, read-only. See README.md in this directory.

Usage: snapshot.py --out DIR [--since TIME] [--section NAME [--json]]
                   [--root DIR] [--claude DIR] [--only NAME...]
                   [--deadline SECONDS] [--timeout SECONDS] [--jobs N]

Without --section, every section is written to DIR as NAME.json and NAME.md,
with index.json and index.md, and the index is printed. With --section, that
section alone is computed and printed (Markdown, or JSON with --json), and
nothing is written to DIR but scratch, which is deleted.

Nothing is written outside DIR: scratch (trial merges' objects, the
checkout lint runs from) goes in DIR/.scratch-<pid> and is deleted. Every
git call has --no-optional-locks and GIT_NO_LAZY_FETCH=1. DIR must not be
inside the folder read, and must be empty, new, or hold an earlier snapshot,
which the new one replaces after the since-previous section diffs them.

Parts still running at the deadline (--deadline, 85 s by default) are
stopped; the index lists each with the command that gets it alone.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import concurrent.futures  # noqa: E402
import datetime  # noqa: E402
import fnmatch  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import platform  # noqa: E402
import re  # noqa: E402
import shlex  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import threading  # noqa: E402
import time  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import lanes as L  # noqa: E402

TOOL = "lanes-snapshot"
FORMAT = 1
SECTIONS = (
    ("environment", "Environment"),
    ("lanes", "Lanes"),
    ("branches", "Branches"),
    ("commits", "Commits"),
    ("changed-files", "Changed files"),
    ("git-state", "Git state"),
    ("trial-merges", "Trial merges"),
    ("names", "Names added by more than one lane"),
    ("activity", "Activity"),
    ("reports", "Reports"),
    ("linux-logs", "Linux logs"),
    ("integration", "Integration branches"),
    ("status", "STATUS.md"),
    ("lint", "lint"),
    ("since-previous", "Since the previous snapshot"),
)
SECTION_NAMES = [s for s, _ in SECTIONS]
TITLES = dict(SECTIONS)
INTEGRATIONS = (("swift-system", "system-next", "system-next"), ("swift-system-examples", "main", "examples"))
MIGRATION_BRANCHES = ("migrate-all", "migrate-unix", "migrate-darwin")
LOG_FORMAT = "--format=%H%x1f%P%x1f%ct%x1f%s%x1e"
HASH = re.compile(r"(?<![0-9A-Za-z_])[0-9a-f]{7,40}(?![0-9A-Za-z_])")
MERGE_SUBJECT = re.compile(r"^Merge (?:remote-tracking )?branch '([^']+)'")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")
EXECUTED = re.compile(r"Executed \d+ tests?\b.*")
TEST_RUN = re.compile(r"Test run with \d+ tests?\b.*")
EXIT_LINE = re.compile(r"^== .*\bexit status -?\d+")
MARKER = re.compile(r"^(<<<<<<< |=======\s*$|>>>>>>> |\|\|\|\|\|\|\| )")
UNMERGED = {"DD", "AU", "UD", "UA", "DU", "AA", "UU"}
NOT_RUN = (
    ("System builds on macOS", "swift-system", "swift build"),
    ("System's tests pass on macOS", "swift-system", "swift test"),
    ("A lane builds and passes its tests on macOS", "<lane>", "swift build && swift test"),
    ("The Win32 namespace and its tests compile against the Windows model", "swift-system",
     "Prototype/Win32/check-windows.sh"),
    ("SystemWinSocks and its tests compile against the Winsock model", "swift-system",
     "Prototype/Win32/check-winsock.sh"),
    ("The examples' tests pass on Linux (writes ../linux-logs/examples-<commit>-all.log)", "swift-system-examples",
     "Scripts/test-linux.sh"),
    ("The examples build and pass their tests on macOS", "swift-system-examples", "swift build && swift test"),
    ("System's tests pass on Linux, with the log a Close writes", "swift-system",
     'Utilities/linux/build.sh --quiet --log "$PWD/../linux-logs/system-next-$(git rev-parse --short HEAD)-test.log" '
     'test'),
    ("lint's api check (runs api-delta, about 40 s, into .build/lint)", "swift-system", "Utilities/lint/lint.sh api"),
)


class Usage(Exception):
    pass


# ---------------------------------------------------------------- times

def local(t):
    return datetime.datetime.fromtimestamp(t).astimezone()


def iso(t):
    """A time as JSON holds it: ISO 8601 in the local zone, with its offset."""
    return None if t is None else local(t).isoformat(timespec="seconds")


class Zone:
    """The zone every time is shown in: the shell's own, as at the start."""

    def __init__(self, now):
        d = local(now)
        self.offset = d.utcoffset()
        off = d.strftime("%z")
        self.label = f"{d.strftime('%Z') or 'local'} (UTC{off[:3]}:{off[3:]})" if off else "UTC"

    def show(self, value, seconds=False):
        """A JSON time as Markdown shows it: `YYYY-MM-DD HH:MM`, with its
        offset when it isn't the zone's (a change of daylight time)."""
        if not value:
            return ""
        d = datetime.datetime.fromisoformat(value)
        s = d.strftime("%Y-%m-%d %H:%M:%S" if seconds else "%Y-%m-%d %H:%M")
        if d.utcoffset() != self.offset:
            off = d.strftime("%z")
            s += f" UTC{off[:3]}:{off[3:]}"
        return s


def epoch(value):
    return datetime.datetime.fromisoformat(value).timestamp() if value else None


# ---------------------------------------------------------------- the run

class Run:
    """One snapshot's settings, clock and record of what was skipped."""

    def __init__(self, args):
        self.args = args
        self.start = time.time()
        self.zone = Zone(self.start)
        self.deadline = args.deadline
        self.deadline_at = self.start + args.deadline if args.deadline and args.deadline > 0 else None
        self.timeout = args.timeout
        self.root = os.path.realpath(args.root)
        self.out = os.path.abspath(args.out)
        self.only = args.only or []
        self.claude = L.claude_root(args.claude)
        self.logs_dir = os.path.join(self.root, "linux-logs")
        self.copies = L.ObjectCopies()
        self.lanes_args = argparse.Namespace(timeout=args.timeout, no_merge_tree=False, deadline_at=self.deadline_at,
                                             object_copies=self.copies)
        self.lock = threading.Lock()
        self.timings = {}
        self.scratch = None
        self.prog = os.environ.get("SNAPSHOT_PROG") or "Utilities/lanes/snapshot.sh"
        self.rev_cache = {}

    def left(self):
        return None if self.deadline_at is None else self.deadline_at - time.time()

    def expired(self):
        left = self.left()
        return left is not None and left <= 0

    def call_timeout(self, cap=None):
        """A subprocess timeout: the per-call timeout (or cap), cut short by
        the deadline; raises L.Slow when the deadline has passed."""
        t = cap if cap is not None else self.timeout
        left = self.left()
        if left is not None:
            if left <= 0:
                raise L.Slow("past the deadline")
            t = min(t, left)
        return t

    def git(self, path, gitdir=None):
        return L.Git(path, gitdir or os.path.join(path, ".git"), self.timeout, self.deadline_at)

    def selected(self, name):
        return not self.only or any(name == p or fnmatch.fnmatchcase(name, p) for p in self.only)

    def command(self, section, only=None):
        parts = [self.prog, "--out", self.out, "--section", section]
        if self.args.root_given:
            parts += ["--root", self.args.root]
        if self.args.claude:
            parts += ["--claude", self.args.claude]
        if only:
            parts += ["--only", only]
        return " ".join(shlex.quote(p) for p in parts)

    def skip(self, section, part, why, lane=None, progress=None):
        rec = {"section": section, "part": part, "why": why,
               "command": self.command(section, lane), "atSeconds": round(time.time() - self.start, 1)}
        if lane:
            rec["lane"] = lane
        if progress:
            rec["progress"] = progress
        return rec

    def timed(self, name, t0):
        with self.lock:
            self.timings[name] = round(time.time() - t0, 2)


def sh(cmd, timeout, cwd=None, env=None, input=None):
    """A subprocess's (returncode, stdout, stderr), in a process group of its
    own; raises L.Slow on timeout, after stopping the group (the process and
    any it started, such as lint's git calls)."""
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE if input is not None else subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace", cwd=cwd,
                         env=env or L.ENV, start_new_session=True)
    try:
        out, err = p.communicate(input=input, timeout=timeout)
    except subprocess.TimeoutExpired:
        stop_group(p)
        raise L.Slow(f"{os.path.basename(cmd[0])} took over {round(timeout, 1)} s")
    return p.returncode, out, err


def stop_group(p):
    """Stops a process started with start_new_session, and everything in
    its group: only processes this snapshot started."""
    import signal
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except OSError:
        p.kill()
    p.communicate()


# ---------------------------------------------------------------- git readings

def parse_log(text, since=None):
    out = []
    for rec in text.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        h, parents, ct, subject = rec.split("\x1f", 3)
        c = {"hash": h, "time": iso(int(ct)), "subject": subject, "parents": parents.split()}
        if since is not None:
            c["new"] = int(ct) >= since
        out.append(c)
    return out


def name_status(text):
    parts, out, i = text.split("\0"), [], 0
    while i < len(parts):
        st = parts[i]
        if not st:
            i += 1
            continue
        if st[0] in "RC" and i + 2 < len(parts):
            out.append({"status": st, "from": parts[i + 1], "path": parts[i + 2]})
            i += 3
        elif i + 1 < len(parts):
            out.append({"status": st, "path": parts[i + 1]})
            i += 2
        else:
            break
    return out


def numstat(text):
    """{path: (added, deleted)} from `git diff --numstat -z`; a binary file's
    counts are None."""
    parts, out, i = text.split("\0"), {}, 0
    while i < len(parts):
        rec = parts[i]
        if not rec:
            i += 1
            continue
        fields = rec.split("\t", 2)
        if len(fields) < 3:
            i += 1
            continue
        a, d, path = fields
        if not path and i + 2 < len(parts):  # a rename: the two paths follow
            path = parts[i + 2]
            i += 2
        out[path] = (None if a == "-" else int(a), None if d == "-" else int(d))
        i += 1
    return out


def file_changes(g, a, b):
    """Every file changed from a to b, with its status and line counts."""
    files = name_status(g.out("diff", "--name-status", "-z", a, b))
    counts = numstat(g.out("diff", "--numstat", "-z", a, b))
    for f in files:
        added, deleted = counts.get(f["path"], (None, None))
        f["added"], f["deleted"] = added, deleted
    return files


def top_level(files):
    """A diffstat by top-level directory (`.` for files at the top)."""
    agg = collections.OrderedDict()
    for f in sorted(files, key=lambda f: f["path"]):
        top = f["path"].split("/", 1)[0] if "/" in f["path"] else "."
        a = agg.setdefault(top, {"directory": top, "files": 0, "added": 0, "deleted": 0})
        a["files"] += 1
        a["added"] += f.get("added") or 0
        a["deleted"] += f.get("deleted") or 0
    return list(agg.values())


def is_sources(path):
    return path.startswith("Sources/") or path == "Package.swift"


def split_stat(files):
    """A merge's files, split into Sources/ with Package.swift, and the rest."""
    out = {}
    for key, pick in (("sources", True), ("rest", False)):
        fs = [f for f in files if is_sources(f["path"]) == pick]
        out[key] = {"files": len(fs), "added": sum(f.get("added") or 0 for f in fs),
                    "deleted": sum(f.get("deleted") or 0 for f in fs), "list": fs}
    return out


def batch_check(g, tokens):
    """{token: (type or "missing"/"ambiguous", full hash or None)} from
    `git cat-file --batch-check`, for abbreviated or full object names."""
    tokens = list(dict.fromkeys(tokens))
    if not tokens:
        return {}
    p = g("cat-file", "--batch-check", input="\n".join(tokens) + "\n", ok=(0, 128))
    out = {}
    lines = p.stdout.split("\n")
    for tok, line in zip(tokens, lines):
        parts = line.split()
        if len(parts) == 3 and len(parts[0]) == 40:
            out[tok] = (parts[1], parts[0])
        elif len(parts) >= 2 and parts[-1] in ("missing", "ambiguous"):
            out[tok] = (parts[-1], None)
        else:
            out[tok] = ("missing", None)
    return out


def read_blobs(g, specs):
    """{spec: text} for `<rev>:<path>` specs, through one `git cat-file
    --batch`; a missing one is left out."""
    specs = list(dict.fromkeys(specs))
    if not specs:
        return {}
    cmd = ["git", "--no-optional-locks", "--git-dir", g.gitdir, "--work-tree", g.path, "cat-file", "--batch"]
    timeout = g.timeout
    if g.deadline is not None:
        left = g.deadline - time.time()
        if left <= 0:
            raise L.Slow("past the deadline before git cat-file")
        timeout = min(timeout, left)
    try:
        p = subprocess.run(cmd, input=("\n".join(specs) + "\n").encode(), capture_output=True, env=L.ENV,
                           timeout=timeout, cwd=g.path)
    except subprocess.TimeoutExpired:
        raise L.Slow(f"git cat-file took over {round(timeout, 1)} s")
    data, pos, out = p.stdout, 0, {}
    for spec in specs:
        nl = data.find(b"\n", pos)
        if nl < 0:
            break
        header = data[pos:nl].decode("utf-8", "replace").split()
        pos = nl + 1
        if len(header) == 3 and header[1] in ("blob", "commit", "tree", "tag"):
            size = int(header[2])
            out[spec] = data[pos:pos + size].decode("utf-8", "replace")
            pos += size + 1
    return out


def rev_set(run, g, rev):
    """The commits reachable from rev, cached by its commit."""
    commit = g.out("rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}", ok=(0, 1)).strip()
    if not commit:
        return set()
    key = commit
    with run.lock:
        got = run.rev_cache.get(key)
    if got is None:
        got = set(g.out("rev-list", commit).split())
        with run.lock:
            run.rev_cache[key] = got
    return got


# ---------------------------------------------------------------- reports

def outline(lines):
    out, fenced = [], False
    for n, line in enumerate(lines, 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        m = HEADING.match(line)
        if m:
            out.append({"line": n, "level": len(m.group(1)), "text": m.group(2)})
    return out


def resume_section(lines):
    """{"line", "text"}: the "Resume here" section, to the next heading of
    its level or above; for a bold or plain "Resume here" line, its
    paragraph and any list after it."""
    for i, line in enumerate(lines):
        if not L.RESUME.match(line):
            continue
        h = HEADING.match(line)
        if h:
            level, j = len(h.group(1)), i + 1
            while j < len(lines):
                m = HEADING.match(lines[j])
                if m and len(m.group(1)) <= level:
                    break
                j += 1
        else:
            j = i + 1
            while j < len(lines):
                s = lines[j]
                if HEADING.match(s):
                    break
                if not s.strip():
                    nxt = next((x for x in lines[j + 1:] if x.strip()), "")
                    if not re.match(r"^\s*([-*+]|\d+[.)])\s", nxt):
                        break
                j += 1
        return {"line": i + 1, "text": "\n".join(lines[i:j]).rstrip()}
    return None


def hash_tokens(lines):
    """[{"hash", "line", "count"}]: every 7-to-40-digit hexadecimal word,
    the line it first appears on and how often."""
    seen = collections.OrderedDict()
    for n, line in enumerate(lines, 1):
        for m in HASH.finditer(line):
            t = m.group(0)
            if t in seen:
                seen[t]["count"] += 1
            else:
                seen[t] = {"hash": t, "line": n, "count": 1}
    return list(seen.values())


def read_report(path, rel):
    try:
        st = os.stat(path)
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError as e:
        return {"path": rel, "problem": str(e)}
    lines = text.split("\n")
    return {"path": rel, "modified": iso(st.st_mtime), "size": st.st_size, "lines": len(lines),
            "outline": outline(lines), "resume": resume_section(lines), "hashes": hash_tokens(lines)}


def report_paths(lane):
    rels = list(lane.get("ownedReports") or [])
    if lane["kind"] in ("adopter", "adopter worktree") and os.path.isfile(os.path.join(lane["path"], "MIGRATION.md")):
        rels.append("MIGRATION.md")
    return sorted(set(rels))


def resolve_hashes(run, g, reports, head_rev="HEAD"):
    """Marks each report hash: a commit in this repository or not, on the
    lane's branch (head_rev) or not, and the local branches that have it."""
    tokens = [h["hash"] for r in reports for h in r.get("hashes", [])]
    if not tokens:
        return
    found = batch_check(g, tokens)
    head = rev_set(run, g, head_rev)
    branches = None
    for r in reports:
        for h in r.get("hashes", []):
            kind, full = found.get(h["hash"], ("missing", None))
            h["inRepo"] = kind
            if kind != "commit":
                continue
            h["commit"] = full
            h["onBranch"] = full in head
            if not h["onBranch"]:
                if branches is None:
                    branches = [b for b in g.out("for-each-ref", "--format=%(refname:short)", "refs/heads").split()]
                h["branches"] = [b for b in branches if g("merge-base", "--is-ancestor", full, b, ok=(0, 1)).returncode == 0]


# ---------------------------------------------------------------- one lane

LANE_STEPS = ("commits", "changed-files", "git-state", "reports")


def lane_task(run, lane):
    """(lane's fields, skips): everything about one lane but its activity."""
    t0 = time.time()
    d = dict(lane)
    skips = []
    try:
        if d["kind"] == "workspace":
            L.workspace_lane(d)
        elif d.get("path") and not d.get("problem"):
            L.git_lane(d, run.root, run.lanes_args)
    except L.Slow as e:
        d["skipped"] = str(e)
        for section in ("lanes", "trial-merges") + LANE_STEPS:
            skips.append(run.skip(section, f"{d['name']}'s git state", str(e), lane=d["name"]))
    except RuntimeError as e:
        d["problem"] = str(e)
    if d.get("path") and not d.get("problem") and not d.get("skipped"):
        step = None
        try:
            if d["kind"] != "workspace":
                g = run.git(d["path"], d.get("gitDirUsed"))
                for step in LANE_STEPS:
                    if step == "commits":
                        lane_commits(run, g, d)
                    elif step == "changed-files":
                        lane_changes(g, d)
                    elif step == "git-state":
                        lane_state(run, g, d)
                    else:
                        d["reports"] = [read_report(os.path.join(d["path"], r), r) for r in report_paths(d)]
                        resolve_hashes(run, g, d["reports"])
            else:
                step = "reports"
                d["reports"] = [read_report(os.path.join(d["path"], r), r) for r in report_paths(d)]
        except L.Slow as e:
            rest = LANE_STEPS[LANE_STEPS.index(step):] if step in LANE_STEPS else LANE_STEPS
            for section in rest:
                skips.append(run.skip(section, f"{d['name']}'s {section}", str(e), lane=d["name"]))
            d.setdefault("partial", []).extend(rest)
        except RuntimeError as e:
            d.setdefault("problems", []).append(f"{step}: {e}")
    if d.get("path"):
        names, contains = L.log_names(d)
        if d["kind"] == "examples" and d["name"] == "swift-system-examples":
            names = names + ["examples"]
        commits = [c["hash"] for c in d.get("commits", [])] + ([d["head"]] if d.get("head") else [])
        d["linuxLogs"] = lane_logs(run, names, contains, commits)
        d["session"] = session_of(run, d["hostPath"])
    run.timed(f"lane {d['name']}", t0)
    return d, skips


def lane_commits(run, g, d):
    since = run.since
    if d["kind"] in ("adopter", "adopter worktree"):
        d["commitsRange"] = "HEAD, since --since"
        d["commits"] = parse_log(g.out("log", f"--since=@{int(since)}", LOG_FORMAT, "HEAD", ok=(0, 128)), since)
        main = g.out("rev-parse", "--verify", "--quiet", "refs/heads/main", ok=(0, 1)).strip()
        if main and d.get("head"):
            d["diffBase"] = "main"
            behind, ahead = g.out("rev-list", "--left-right", "--count", f"{main}...HEAD").split()
            d["aheadOfMain"], d["behindMain"] = int(ahead), int(behind)
            mb = g.out("merge-base", main, "HEAD", ok=(0, 1)).strip()
            if mb:
                d["mergeBase"] = mb
    elif d.get("integrationHead"):
        d["commitsRange"] = f"{d['integration']}..HEAD"
        d["commits"] = parse_log(g.out("log", LOG_FORMAT, f"{d['integrationHead']}..HEAD"), since)
    else:
        d["commits"] = []
    d["newCommits"] = sum(1 for c in d.get("commits", []) if c.get("new"))


def lane_changes(g, d):
    mb = d.get("mergeBase")
    if not mb or not d.get("head"):
        return
    files = file_changes(g, mb, "HEAD")
    d["changedFiles"] = files
    d["changedByTop"] = top_level(files)


def lane_state(run, g, d):
    gitdir = d["gitDirUsed"]
    detail = {}
    for f, name in L.IN_PROGRESS:
        p = os.path.join(gitdir, f)
        if not os.path.exists(p):
            continue
        item = {"file": f, "modified": iso(os.path.getmtime(p))}
        if os.path.isfile(p):
            with open(p, errors="replace") as fh:
                ref = fh.read().strip().split("\n")[0]
            item["commit"] = ref
            item["subject"] = g.out("log", "-1", "--format=%s", ref, ok=(0, 128)).strip()
        else:
            for k in ("head-name", "onto", "msgnum", "end", "next", "last"):
                q = os.path.join(p, k)
                if os.path.isfile(q):
                    with open(q, errors="replace") as fh:
                        item[k] = fh.read().strip()
        detail[name] = item
    msg = os.path.join(gitdir, "MERGE_MSG")
    if "merge" in detail and os.path.isfile(msg):
        with open(msg, errors="replace") as fh:
            detail["merge"]["message"] = fh.read().strip().split("\n")[0]
    d["inProgressDetail"] = detail
    entries = d.get("uncommittedFiles") or []
    d["unmerged"] = [e["path"] for e in entries if e["status"] in UNMERGED]
    markers = []
    for e in entries:
        if run.expired():
            raise L.Slow("past the deadline in conflict-marker scan")
        if e["status"][1:] == "D" or e["status"][:1] == "D":
            continue
        found = conflict_markers(os.path.join(d["path"], e["path"]))
        if found:
            markers.append({"path": e["path"], "lines": found})
    d["conflictMarkers"] = markers


def conflict_markers(path, limit=4 << 20):
    """The lines of a text file that are git's conflict markers."""
    try:
        if not os.path.isfile(path) or os.path.getsize(path) > limit:
            return []
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return []
    if b"\0" in data[:8192]:
        return []
    out = []
    for n, line in enumerate(data.decode("utf-8", "replace").split("\n"), 1):
        if MARKER.match(line):
            out.append(n)
    # A lone `=======` is a Markdown underline; markers come as <<<, ===, >>>.
    text_lines = data.decode("utf-8", "replace").split("\n")
    has_open = any(text_lines[n - 1].startswith("<<<<<<< ") for n in out)
    return out if has_open else []


def session_of(run, host_path):
    s = dict(L.session(run.claude, host_path))
    if "mtime" in s:
        s["modified"] = iso(s.pop("mtime"))
    return s


def lane_logs(run, names, contains, commits=()):
    """Every Linux log for a lane, newest first: named for it, by
    L.linux_log's rule, or naming one of its commits (the examples' logs
    are named `examples-<commit>`, whichever lane ran them)."""
    out = []
    for log in run.log_list:
        f = log["file"]
        c = log.get("commit")
        by_name = any(f.startswith(n + "-") for n in names) or any(f"-{p}-" in f for p in contains)
        by_commit = bool(c) and not log.get("package") and any(h.startswith(c) for h in commits)
        if by_name or by_commit:
            out.append({"file": f, "modified": log["modified"], "size": log["size"], "commit": c,
                        "matched": "name" if by_name else "commit"})
    return out


# ---------------------------------------------------------------- repositories: branches and locks

def repositories(run, lanes):
    """[(name, main clone path)]: swift-system, the examples and each
    adopter clone, the ones with a lane selected."""
    out = []
    for repo, _, _ in L.REPOS:
        p = os.path.join(run.root, repo)
        if os.path.isdir(os.path.join(p, ".git")) and any(
                x.get("repository") == repo and run.selected(x["name"]) for x in lanes):
            out.append((repo, p))
    top = os.path.join(run.root, "adopters")
    if os.path.isdir(top):
        for name in sorted(os.listdir(top), key=str.lower):
            p = os.path.join(top, name)
            if os.path.isdir(os.path.join(p, ".git")) and (
                    run.selected(f"adopters/{name}") or run.selected(f"adopters-unix/{name}")):
                out.append((f"adopters/{name}", p))
    return out


def repo_task(run, repo, path):
    t0 = time.time()
    g = run.git(path)
    out = {"repository": repo, "path": path}
    skips = []
    try:
        fmt = "%(refname)%00%(objectname)%00%(committerdate:unix)%00%(subject)%00%(worktreepath)%00%(upstream:short)"
        local, remote = [], []
        for line in g.out("for-each-ref", f"--format={fmt}", "refs/heads", "refs/remotes").split("\n"):
            if not line:
                continue
            ref, obj, ct, subject, wt, upstream = (line.split("\0") + [""] * 6)[:6]
            item = {"name": ref.split("/", 2)[2], "head": obj, "time": iso(int(ct)) if ct.isdigit() else None,
                    "subject": subject}
            if ref.startswith("refs/heads/"):
                if wt:
                    item["worktree"] = wt
                    seen = L.locate(run.root, wt, lambda p: os.path.exists(os.path.join(p, ".git")))
                    if seen and seen != wt:
                        item["worktreeSeen"] = seen
                    elif not seen:
                        item["worktreeMissing"] = True
                if upstream:
                    item["upstream"] = upstream
                if item["name"] in MIGRATION_BRANCHES:
                    item["migration"] = True
                local.append(item)
            elif not ref.endswith("/HEAD"):
                remote.append(item)
        out["local"], out["remote"] = local, remote
        names = {b["name"] for b in local}
        newest = next((b for b in MIGRATION_BRANCHES if b in names), None)
        if repo.startswith("adopters/"):
            out["newestMigration"] = newest
        out["worktrees"] = worktree_list(run, g)
    except L.Slow as e:
        skips.append(run.skip("branches", f"{repo}'s branches", str(e), lane=repo if repo.startswith("adopters/")
                              else None))
    except RuntimeError as e:
        out["problem"] = str(e)
    try:
        out["locks"] = lock_files(run, os.path.join(path, ".git"))
    except L.Slow as e:
        skips.append(run.skip("git-state", f"{repo}'s lock files", str(e)))
    run.timed(f"repository {repo}", t0)
    return out, skips


def worktree_list(run, g):
    out, cur = [], {}
    for line in g.out("worktree", "list", "--porcelain").split("\n") + [""]:
        if not line.strip():
            if cur.get("worktree"):
                out.append(cur)
            cur = {}
            continue
        k, _, v = line.partition(" ")
        cur[k] = v if v else True
    res = []
    for w in out:
        recorded = w["worktree"]
        seen = L.locate(run.root, recorded, lambda p: os.path.exists(os.path.join(p, ".git")))
        item = {"recorded": recorded, "head": w.get("HEAD"),
                "branch": (w.get("branch") or "")[len("refs/heads/"):] if isinstance(w.get("branch"), str) else None}
        if w.get("detached"):
            item["detached"] = True
        if seen and seen != recorded:
            item["seen"] = seen
        if not seen:
            item["missing"] = True
        for k in ("locked", "prunable", "bare"):
            if k in w:
                item[k] = w[k]
        res.append(item)
    return res


def lock_files(run, gitdir):
    """Every `*.lock` file under a repository's git directory (its
    worktrees' directories included), not looking inside `objects/` but at
    its `info` and `pack` directories."""
    out = []
    stack = [gitdir]
    n = 0
    while stack:
        d = stack.pop()
        try:
            entries = list(os.scandir(d))
        except OSError:
            continue
        for e in entries:
            n += 1
            if n % 100 == 0 and run.expired():
                raise L.Slow("past the deadline in the lock-file scan")
            try:
                if e.is_dir(follow_symlinks=False):
                    if e.name == "objects":
                        for sub in ("info", "pack"):
                            q = os.path.join(e.path, sub)
                            if os.path.isdir(q):
                                for f in os.listdir(q):
                                    if f.endswith(".lock"):
                                        add_lock(out, gitdir, os.path.join(q, f))
                        continue
                    stack.append(e.path)
                elif e.name.endswith(".lock"):
                    add_lock(out, gitdir, e.path)
            except OSError:
                continue
    return sorted(out, key=lambda x: x["path"])


def add_lock(out, gitdir, path):
    try:
        st = os.lstat(path)
    except OSError:
        return
    out.append({"path": os.path.relpath(path, os.path.dirname(gitdir)), "modified": iso(st.st_mtime),
                "size": st.st_size})


# ---------------------------------------------------------------- activity: newest writes

class Walker:
    """The newest file in each lane's tree, in `.build` and outside it, not
    looking inside `.git` or past symbolic links: worker threads take
    directories from one queue across every lane, newest first by the
    directory's own modification time (which a file's creation, removal
    or rename in it changes, so a build's or a Close's writes tend to come
    first). A walk the deadline stops is incomplete: a directory's time
    says nothing about what's deeper, and a file rewritten in place
    doesn't change its directory's time."""

    def __init__(self, run):
        import heapq
        self.heapq = heapq
        self.run = run
        self.heap = []
        self.seq = 0
        self.cv = threading.Condition()
        self.busy = 0
        self.best = {}
        self.entries = collections.Counter()
        self.stopped = False

    def add(self, lane, root, in_build=False, skip_top=()):
        try:
            m = os.lstat(root).st_mtime
        except OSError:
            return
        self.best.setdefault(lane, {"all": None, "build": None, "outside": None})
        self.push([(-m, lane, root, in_build, tuple(skip_top))])

    def push(self, items):
        with self.cv:
            for item in items:
                self.seq += 1
                self.heapq.heappush(self.heap, (item[0], self.seq) + item[1:])
            self.cv.notify_all()

    def work(self):
        local = {}
        counts = collections.Counter()
        while True:
            with self.cv:
                while not self.heap and self.busy and not self.stopped:
                    self.cv.wait(0.5)
                if self.stopped or not self.heap or self.run.expired():
                    self.stopped = self.stopped or self.run.expired()
                    self.cv.notify_all()
                    break
                prio, _seq, lane, d, in_build, skip = self.heapq.heappop(self.heap)
                self.busy += 1
            subdirs = []
            try:
                listing = list(os.scandir(d))
            except OSError:
                listing = []
            best = local.setdefault(lane, {"all": None, "build": None, "outside": None})
            cut = False
            for i, e in enumerate(listing):
                if i % 500 == 499 and self.run.expired():
                    cut = True
                    break
                if e.name == ".git" or e.name in skip:
                    continue
                counts[lane] += 1
                try:
                    st = e.stat(follow_symlinks=False)
                    is_dir = e.is_dir(follow_symlinks=False)
                except OSError:
                    continue
                if is_dir:
                    subdirs.append((-st.st_mtime, lane, e.path, in_build or e.name == ".build", ()))
                    continue
                m = st.st_mtime
                for key in ("all", "build" if in_build else "outside"):
                    if best[key] is None or m > best[key][0]:
                        best[key] = (m, e.path)
            if cut:  # back in the queue, which no one reads now: it counts as unread
                subdirs.append((prio, lane, d, in_build, skip))
            if subdirs:
                self.push(subdirs)
            with self.cv:
                self.busy -= 1
                self.cv.notify_all()
        with self.cv:
            for lane, b in local.items():
                mine = self.best.setdefault(lane, {"all": None, "build": None, "outside": None})
                for k, v in b.items():
                    if v and (mine[k] is None or v[0] > mine[k][0]):
                        mine[k] = v
            self.entries.update(counts)

    def walk(self, threads):
        t0 = time.time()
        workers = [threading.Thread(target=self.work, daemon=True) for _ in range(max(1, threads))]
        for w in workers:
            w.start()
        for w in workers:
            left = self.run.left()
            w.join(None if left is None else max(0.0, left) + 1.0)
        self.seconds = round(time.time() - t0, 2)
        with self.cv:
            self.stopped = True
            unread = collections.Counter()
            unread_t = {}
            for item in self.heap:
                lane, m = item[2], -item[0]
                unread[lane] += 1
                unread_t[lane] = max(unread_t.get(lane, m), m)
            return unread, unread_t


def activity_roots(lane):
    """The roots a lane's walk starts from: its tree, or for a workspace,
    its directories that aren't clones."""
    if lane["kind"] != "workspace":
        return [(lane["path"], ())]
    return [(e.path, ()) for e in sorted(os.scandir(lane["path"]), key=lambda e: e.name.lower())
            if e.is_dir(follow_symlinks=False) and not os.path.exists(os.path.join(e.path, ".git"))]


def activity_task(run, lanes, threads):
    """Every lane's activity: one walk across all of them, then each lane's
    newest files, workspace directories and session."""
    t0 = time.time()
    w = Walker(run)
    for x in lanes:
        for root, skip in activity_roots(x):
            key = x["name"] if x["kind"] != "workspace" else f"{x['name']}/{os.path.basename(root)}"
            w.add(key, root, skip_top=skip)
    unread, unread_t = w.walk(threads)
    out, skips = [], []
    for x in lanes:
        a = {"name": x["name"], "kind": x["kind"], "path": x["path"]}
        keys = [x["name"]] if x["kind"] != "workspace" else \
            [f"{x['name']}/{os.path.basename(r)}" for r, _ in activity_roots(x)]
        best = {"all": None, "build": None, "outside": None}
        dirs = []
        for k in keys:
            b = w.best.get(k) or {}
            for kind, v in b.items():
                if v and (best[kind] is None or v[0] > best[kind][0]):
                    best[kind] = v
            if x["kind"] == "workspace":
                item = {"directory": k.split("/", 1)[1], "entries": w.entries.get(k, 0)}
                if b.get("all"):
                    item["newest"] = {"path": os.path.relpath(b["all"][1], x["path"]), "modified": iso(b["all"][0])}
                if unread.get(k):
                    item["partial"] = True
                dirs.append(item)
        a["entries"] = sum(w.entries.get(k, 0) for k in keys)
        for kind, name in (("all", "newest"), ("build", "newestInBuild"), ("outside", "newestOutsideBuild")):
            if best[kind]:
                a[name] = {"path": os.path.relpath(best[kind][1], x["path"]), "modified": iso(best[kind][0])}
        if x["kind"] == "workspace":
            a["directories"] = dirs
            top = None
            for e in os.scandir(x["path"]):
                if not e.is_dir(follow_symlinks=False):
                    try:
                        m = e.stat(follow_symlinks=False).st_mtime
                    except OSError:
                        continue
                    if top is None or m > top[0]:
                        top = (m, e.name)
            if top:
                a["newestTopFile"] = {"path": top[1], "modified": iso(top[0])}
        n_unread = sum(unread.get(k, 0) for k in keys)
        if n_unread:
            newest_unread = max(unread_t[k] for k in keys if k in unread_t)
            a["partial"] = True
            a["unreadDirectories"] = n_unread
            a["unreadNewestDirectoryTime"] = iso(newest_unread)
            skips.append(run.skip("activity", f"{x['name']}'s walk", "past the deadline", lane=x["name"],
                                  progress=f"{a['entries']} entries read; {n_unread} directories unread, "
                                           f"their own times up to {run.zone.show(iso(newest_unread))}"))
        a["session"] = session_of(run, x["hostPath"])
        out.append(a)
    run.timed("activity", t0)
    return {"lanes": out, "threads": threads, "seconds": w.seconds}, skips


# ---------------------------------------------------------------- Linux logs

def list_logs(run, packages):
    """Every `*.log` at the top of ../linux-logs, newest first, with what its
    name says: `<lane>[-<package>[-<variant>]]-<commit>[-<rest>].log`."""
    out = []
    d = run.logs_dir
    if not os.path.isdir(d):
        return out
    for f in os.listdir(d):
        if not f.endswith(".log"):
            continue
        p = os.path.join(d, f)
        try:
            st = os.stat(p)
        except OSError:
            continue
        if not os.path.isfile(p):
            continue
        item = {"file": f, "modified": iso(st.st_mtime), "size": st.st_size, "_mtime": st.st_mtime}
        item.update(parse_log_name(f, packages))
        out.append(item)
    out.sort(key=lambda x: (-x["_mtime"], x["file"]))
    for x in out:
        del x["_mtime"]
    return out


def parse_log_name(f, packages):
    words = f[:-len(".log")].split("-")
    for i, w in enumerate(words):
        if re.fullmatch(r"[0-9a-f]{7,40}", w) and re.search(r"[0-9]", w):
            prefix = "-".join(words[:i])
            rest = "-".join(words[i + 1:])
            out = {"prefix": prefix, "commit": w, "rest": rest}
            lane, package, variant = prefix, None, None
            for pkg in sorted(packages, key=len, reverse=True):
                k = prefix.find("-" + pkg)
                while k >= 0:
                    end = k + 1 + len(pkg)
                    if end == len(prefix) or prefix[end] == "-":
                        lane, package, variant = prefix[:k], pkg, prefix[end + 1:] or None
                        break
                    k = prefix.find("-" + pkg, k + 1)
                if package:
                    break
            out["lane"] = lane
            if package:
                out["package"] = package
            if variant:
                out["variant"] = variant
            return out
    return {"prefix": f[:-len(".log")], "lane": f[:-len(".log")]}


def read_log(path):
    out = {}
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        return {"problem": str(e)}
    text = data.decode("utf-8", "replace")
    lines = text.split("\n")
    out["lines"] = len(lines)
    out["header"] = lines[0] if lines else ""
    executed = run_with = exit_line = None
    errors, distinct, first = 0, collections.OrderedDict(), []
    for line in lines:
        m = EXECUTED.search(line)
        if m:
            executed = m.group(0).strip()
        m = TEST_RUN.search(line)
        if m:
            run_with = m.group(0).strip()
        if "error:" in line:
            errors += 1
            if not line.lstrip().startswith("|"):
                key = line.strip()
                if key not in distinct:
                    distinct[key] = True
        if EXIT_LINE.match(line):
            exit_line = line.strip()
    out["summary"] = [x for x in (executed, run_with) if x]
    out["errors"] = {"lines": errors, "distinct": len(distinct), "first": list(distinct)[:10]}
    if exit_line:
        out["exit"] = exit_line
    return out


def logs_task(run, logs, lanes):
    """Reads each log, newest first, and finds the repository each one's
    commit is in."""
    t0 = time.time()
    skips = []
    done = 0
    for log in logs:
        if run.expired():
            skips.append(run.skip("linux-logs", f"{len(logs) - done} older logs' contents", "past the deadline",
                                  progress=f"{done} of {len(logs)} read"))
            break
        log.update(read_log(os.path.join(run.logs_dir, log["file"])))
        done += 1
    # Which repository each named commit is in.
    try:
        repos = {}
        for repo, _, _ in L.REPOS:
            p = os.path.join(run.root, repo)
            if os.path.isdir(os.path.join(p, ".git")):
                repos[repo] = p
        adopters = os.path.join(run.root, "adopters")
        wanted = collections.defaultdict(set)
        for log in logs:
            c = log.get("commit")
            if not c:
                continue
            if log.get("package") and os.path.isdir(os.path.join(adopters, log["package"], ".git")):
                wanted[f"adopters/{log['package']}"].add(c)
            else:
                for r in repos:
                    wanted[r].add(c)
        found = {}
        for repo, toks in wanted.items():
            path = repos.get(repo) or os.path.join(run.root, repo)
            res = batch_check(run.git(path), sorted(toks))
            for t, (kind, full) in res.items():
                if kind == "commit":
                    found.setdefault(t, []).append(repo)
        for log in logs:
            if log.get("commit"):
                log["commitIn"] = found.get(log["commit"], [])
    except L.Slow as e:
        skips.append(run.skip("linux-logs", "the repositories of the logs' commits", str(e)))
    run.timed("linux-logs", t0)
    return logs, skips


# ---------------------------------------------------------------- integration branches

def integration_task(run, repo, branch, log_prefix, lanes):
    t0 = time.time()
    path = os.path.join(run.root, repo)
    out = {"repository": repo, "branch": branch, "logPrefix": log_prefix}
    skips = []
    if not os.path.isdir(os.path.join(path, ".git")):
        out["problem"] = f"no clone {repo}"
        return out, skips
    g = run.git(path)
    try:
        head = g.out("log", "-1", LOG_FORMAT, f"refs/heads/{branch}", ok=(0, 128))
        heads = parse_log(head)
        if not heads:
            out["problem"] = f"no branch {branch}"
            return out, skips
        out["head"] = heads[0]
        local = set(g.out("for-each-ref", "--format=%(refname:short)", "refs/heads").split())
        wts = worktree_list(run, g)
        logs_by_commit = collections.defaultdict(list)
        for log in run.log_list:
            if log.get("commit"):
                logs_by_commit[log["commit"]].append(log)
        history = parse_log(g.out("log", "--first-parent", f"--since=@{int(run.since)}", LOG_FORMAT,
                                  f"refs/heads/{branch}"), run.since)
        for c in history:
            if run.expired():
                raise L.Slow("past the deadline in the first-parent history")
            parent = c["parents"][0] if c["parents"] else None
            if parent:
                files = file_changes(g, parent, c["hash"])
                c["stat"] = split_stat(files)
                c["touchesSources"] = c["stat"]["sources"]["files"] > 0
            logs = [x for k, v in logs_by_commit.items() if c["hash"].startswith(k) for x in v]
            c["closeLogs"] = sorted(x["file"] for x in logs if x["file"].startswith(log_prefix + "-"))
            c["otherLogs"] = sorted(x["file"] for x in logs if not x["file"].startswith(log_prefix + "-"))
            m = MERGE_SUBJECT.match(c["subject"])
            if len(c["parents"]) > 1:
                merged = {"lane": m.group(1) if m else None, "tip": c["parents"][1]}
                lane = merged["lane"]
                if lane:
                    merged["branch"] = "present" if lane in local else "gone"
                    if lane in local:
                        bh = g.out("rev-parse", f"refs/heads/{lane}").strip()
                        merged["branchHead"] = bh
                        merged["commitsPastMerge"] = int(g.out("rev-list", "--count", f"{c['hash']}..{bh}").strip())
                    wt = [w for w in wts if w.get("branch") == lane or
                          os.path.basename(w["recorded"].rstrip("/")) == lane]
                    if wt:
                        merged["worktree"] = "missing (recorded only)" if all(w.get("missing") for w in wt) \
                            else "present"
                        merged["worktreePaths"] = [w.get("seen") or w["recorded"] for w in wt]
                    else:
                        merged["worktree"] = "gone"
                c["merge"] = merged
        out["history"] = history
        out["since"] = iso(run.since)
        # The last first-parent commit with a <prefix>-<commit> log.
        tokens = {log["commit"] for log in run.log_list if log.get("commit") and log["prefix"] == log_prefix}
        firsts = g.out("rev-list", "--first-parent", f"refs/heads/{branch}").split()
        last = None
        for i, h in enumerate(firsts):
            if any(h.startswith(t) for t in tokens):
                last = (i, h)
                break
        if last:
            i, h = last
            info = parse_log(g.out("log", "-1", LOG_FORMAT, h))[0]
            info["logs"] = sorted(x["file"] for x in run.log_list if x.get("commit") and h.startswith(x["commit"])
                                  and x["prefix"] == log_prefix)
            info["firstParentCommitsSince"] = i
            newer = parse_log(g.out("log", "--first-parent", "-n", str(i), LOG_FORMAT, f"refs/heads/{branch}")) \
                if i else []
            for c in newer:
                if run.expired():
                    raise L.Slow("past the deadline after the last logged commit")
                names = g.out("diff", "--name-only", "-z", c["parents"][0], c["hash"]).split("\0") \
                    if c["parents"] else []
                c["touchesSources"] = any(is_sources(n) for n in names if n)
            info["since"] = newer
            out["lastLogged"] = info
        else:
            out["lastLogged"] = None
        if repo == "swift-system":
            out["cmake"] = cmake_recipe(g, f"refs/heads/{branch}")
    except L.Slow as e:
        out["partial"] = True
        skips.append(run.skip("integration", f"{repo} {branch}", str(e)))
    except RuntimeError as e:
        out["problem"] = str(e)
    run.timed(f"integration {repo}", t0)
    return out, skips


def cmake_recipe(g, rev):
    """The handoff's CMake list check, on a commit rather than a working
    tree: each tracked `.swift` file of Sources/System whose path relative
    to it isn't in Sources/System/CMakeLists.txt (`grep -qF`)."""
    files = [f for f in g.out("ls-tree", "-r", "--name-only", "-z", rev, "--", "Sources/System").split("\0")
             if f.endswith(".swift")]
    text = g.out("show", f"{rev}:Sources/System/CMakeLists.txt", ok=(0, 128))
    if not text:
        return {"problem": "no Sources/System/CMakeLists.txt"}
    missing = [f for f in files if f[len("Sources/System/"):] not in text]
    return {"checked": len(files), "missing": missing}


# ---------------------------------------------------------------- STATUS.md

STATUS_FILE = "Prototype/Status/STATUS.md"


def split_row(line):
    cells, cur, i = [], "", 0
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s) and s[i + 1] == "|":
            cur += "|"
            i += 2
            continue
        if s[i] == "|":
            cells.append(cur.strip())
            cur = ""
        else:
            cur += s[i]
        i += 1
    cells.append(cur.strip())
    return cells


def status_task(run):
    t0 = time.time()
    path = os.path.join(run.root, "swift-system")
    out = {"file": STATUS_FILE}
    skips = []
    try:
        g = run.git(path)
        last = parse_log(g.out("log", "-1", LOG_FORMAT, "refs/heads/system-next", "--", STATUS_FILE, ok=(0, 128)))
        out["lastChange"] = last[0] if last else None
        text = g.out("show", f"refs/heads/system-next:{STATUS_FILE}", ok=(0, 128))
        if not text:
            out["problem"] = f"no {STATUS_FILE} on system-next"
            return out, skips
        out["size"] = len(text.encode())
        out.update(parse_status(text))
    except L.Slow as e:
        skips.append(run.skip("status", "STATUS.md", str(e)))
    run.timed("status", t0)
    return out, skips


def parse_status(text):
    lines = text.split("\n")
    out = {"floor": {}, "categories": [], "gaps": []}
    sec5 = next((i for i, x in enumerate(lines) if re.match(r"^#\s+5\.", x)), None)
    if sec5 is None:
        out["problem"] = "no section 5"
        return out
    end = next((i for i in range(sec5 + 1, len(lines)) if re.match(r"^#\s", lines[i])), len(lines))
    body = lines[sec5:end]
    for line in body:
        if "The floor" in line:
            for p, n in re.findall(r"([A-Za-z]+) \((\d+) sites? left\)", line):
                out["floor"][p] = int(n)
        if "Categories" in line and ":" in line:
            tail = line.rsplit(": ", 1)[-1]
            for n, name in re.findall(r"(\d+) ([A-Za-z][A-Za-z ]*?)(?=[,;.]|$)", tail):
                out["categories"].append({"category": name.strip(), "sites": int(n)})
    start = next((i for i, x in enumerate(body) if x.startswith("## ") and "System gaps" in x), None)
    if start is None:
        out["problem"] = "no gap table in section 5"
        return out
    header = None
    for line in body[start + 1:]:
        if line.startswith("## "):
            break
        if not line.startswith("|"):
            continue
        cells = split_row(line)
        if header is None:
            header = [c.strip("*").lower() for c in cells]
            continue
        if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
            continue
        row = dict(zip(header, cells))
        unblocks = re.match(r"(\d+)(?:\s*\((\d+) files?\))?", row.get("unblocks", ""))
        gap = {"rank": int(row["#"]) if row.get("#", "").isdigit() else row.get("#"),
               "gap": row.get("gap", ""),
               "lacks": [p.strip() for p in row.get("lacks", "").split(",") if p.strip()],
               "unblocks": int(unblocks.group(1)) if unblocks else None,
               "unblocksFiles": int(unblocks.group(2)) if unblocks and unblocks.group(2) else None,
               "holds": int(row["holds"]) if row.get("holds", "").isdigit() else None,
               "repositories": [r.strip() for r in row.get("repositories", "").split(",")
                                if r.strip() and r.strip() != "—"],
               "cNames": row.get("c names", ""), "system": row.get("system", "")}
        out["gaps"].append(gap)
    out["gapColumns"] = header
    out["sums"] = gap_sums(out["gaps"])
    return out


def gap_sums(gaps):
    def add(acc, g):
        acc["rows"] += 1
        acc["unblocks"] += g["unblocks"] or 0
        acc["holds"] += g["holds"] or 0

    def blank():
        return {"rows": 0, "unblocks": 0, "holds": 0}

    by_platform = collections.OrderedDict()
    total, windows_only, other = blank(), blank(), blank()
    for g in gaps:
        add(total, g)
        for p in g["lacks"]:
            add(by_platform.setdefault(p, blank()), g)
        if g["lacks"] == ["Windows"]:
            add(windows_only, g)
        if any(p != "Windows" for p in g["lacks"]):
            add(other, g)
    return {"byPlatform": by_platform, "windowsOnly": windows_only, "lackingAnotherPlatform": other, "total": total}


# ---------------------------------------------------------------- lint

def lint_task(run, adopter_clones):
    """lint at system-next's head, from a scratch checkout of it: cmake,
    pitches and api (only with a current api-delta output); then markers and
    conditionals for each adopter clone."""
    t0 = time.time()
    skips = []
    out = {"system": None, "adopters": None, "xcrun": bool(shutil.which("xcrun"))}
    path = os.path.join(run.root, "swift-system")
    try:
        g = run.git(path)
        head = g.out("rev-parse", "--verify", "--quiet", "refs/heads/system-next", ok=(0, 1)).strip()
        if not head:
            out["problem"] = "no system-next"
            return out, skips
        out["head"] = head
        if not g.out("ls-tree", "--name-only", head, "Utilities/lint/lint.sh").strip():
            out["problem"] = "no Utilities/lint/lint.sh at system-next's head"
            return out, skips
        work = os.path.join(run.scratch, "lint")
        checkout = os.path.join(work, "swift-system")
        scratch_checkout(run, g, path, checkout, head)
        snaps = os.path.join(run.root, "api-graph-snapshots")
        if os.path.isdir(snaps):
            os.symlink(snaps, os.path.join(work, "api-graph-snapshots"))
        lint = os.path.join(checkout, "Utilities", "lint", "lint.sh")
        env = dict(L.ENV, PYTHONDONTWRITEBYTECODE="1", TMPDIR=run.scratch,
                   ADOPTER_COVERAGE_RESULTS=os.path.join(run.root, "coverage-results"))
        system_args = ["--json", "cmake", "pitches", "api", "--no-run"]
        delta = os.path.join(path, ".build", "api-delta")
        if os.path.isdir(delta):
            system_args += ["--api-delta", delta]
        if run.selected("swift-system"):
            out["system"] = scrub(run_lint(run, lint, system_args, env), work, run.root)
        if adopter_clones:
            rels = [os.path.relpath(c, run.root) for c in adopter_clones]
            res = {}
            # markers first: it fills lint's cache of System's coverage (in the scratch checkout's
            # .build/lint), which the conditionals runs then read, three at once.
            chunks = [[rels]] + [[rels[i::3] for i in range(3) if rels[i::3]]]
            for check, parts in zip(("markers", "conditionals"), chunks):
                got = run_lint_many(run, lint, [["--json", check] + clone_args(p) for p in parts], env)
                merged = None
                for part, r in zip(parts, got):
                    if isinstance(r, L.Slow):
                        for rel in part:
                            skips.append(run.skip("lint", f"{check} for {rel}", str(r), lane=rel))
                        continue
                    merged = merge_lint(merged, r)
                if merged:
                    res[check] = merged
            out["adopters"] = split_by_clone(res, rels)
        out = scrub(out, work, run.root)
    except L.Slow as e:
        skips.append(run.skip("lint", "lint", str(e)))
    except (RuntimeError, OSError, subprocess.CalledProcessError) as e:
        out["problem"] = str(e)
    run.timed("lint", t0)
    return out, skips


def scratch_checkout(run, g, path, checkout, head):
    """A checkout of head in scratch: a new repository whose objects are
    the clone's (alternates), with the clone's branches, so nothing is
    written to the clone."""
    os.makedirs(os.path.dirname(checkout), exist_ok=True)
    env = dict(L.ENV, GIT_CONFIG_NOSYSTEM="1")
    t = run.call_timeout()
    code, _, err = sh(["git", "init", "-q", "--template=", checkout], t, env=env)
    if code:
        raise RuntimeError(f"git init: {err.strip()}")
    common = os.path.join(path, ".git")
    alternates = [os.path.join(common, "objects")]
    info = os.path.join(common, "objects", "info", "alternates")
    if os.path.isfile(info):
        with open(info) as f:
            alternates += [a.strip() for a in f if a.strip() and not a.startswith("#")]
    with open(os.path.join(checkout, ".git", "objects", "info", "alternates"), "w") as f:
        f.write("\n".join(alternates) + "\n")
    refs = g.out("for-each-ref", "--format=%(objectname) %(refname)", "refs/heads", "refs/remotes/origin")
    with open(os.path.join(checkout, ".git", "packed-refs"), "w") as f:
        f.write("# pack-refs with: peeled fully-peeled sorted \n")
        for line in sorted(refs.split("\n"), key=lambda x: x.split(" ")[-1]):
            if line.strip() and not line.endswith("/HEAD"):
                f.write(line + "\n")
    with open(os.path.join(checkout, ".git", "HEAD"), "w") as f:
        f.write("ref: refs/heads/system-next\n")
    code, _, err = sh(["git", "-C", checkout, "read-tree", "--reset", "-u", head], run.call_timeout(60), env=env)
    if code:
        raise RuntimeError(f"git read-tree: {err.strip()}")


def scrub(value, work, root):
    """lint's output with the scratch checkout's paths made the folder's:
    the snapshot store's symbolic link, and the checkout itself."""
    pairs = []
    for w in {work, os.path.realpath(work)}:
        pairs += [(os.path.join(w, "api-graph-snapshots"), os.path.join(root, "api-graph-snapshots")),
                  (os.path.join(w, "swift-system") + os.sep, "")]
    if isinstance(value, str):
        for a, b in pairs:
            value = value.replace(a, b)
        return value
    if isinstance(value, list):
        return [scrub(v, work, root) for v in value]
    if isinstance(value, dict):
        return {k: scrub(v, work, root) for k, v in value.items()}
    return value


def clone_args(rels):
    out = []
    for r in rels:
        out += ["--clone", r]
    return out


def run_lint_many(run, lint, arg_lists, env):
    """run_lint for each argument list at once; a run still going at the
    deadline is stopped, and its place in the result is the L.Slow."""
    procs = []
    for args in arg_lists:
        procs.append((args, subprocess.Popen([lint] + args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                             stderr=subprocess.PIPE, text=True, errors="replace", cwd=run.root,
                                             env=env, start_new_session=True)))
    out = []
    for args, p in procs:
        try:
            left = run.left()
            stdout, stderr = p.communicate(timeout=None if left is None else max(0.1, left))
            out.append(lint_result(args, p.returncode, stdout, stderr))
        except subprocess.TimeoutExpired:
            stop_group(p)
            out.append(L.Slow("lint was still running at the deadline"))
    return out


def merge_lint(acc, r):
    if acc is None:
        return dict(r, commands=[r["command"]])
    acc = dict(acc)
    acc["commands"] = acc["commands"] + [r["command"]]
    acc["command"] = " ; ".join(acc["commands"])
    acc["exit"] = max(acc["exit"], r["exit"])
    acc["stderr"] = acc["stderr"] + r["stderr"]
    for k in ("findings", "notes", "failed"):
        acc[k] = acc.get(k, []) + r.get(k, [])
    if r.get("problem"):
        acc["problem"] = r["problem"]
    return acc


def lint_result(args, code, stdout, stderr):
    res = {"command": "Utilities/lint/lint.sh " + " ".join(shlex.quote(a) for a in args), "exit": code,
           "stderr": [x for x in stderr.split("\n") if x.strip()]}
    try:
        doc = json.loads(stdout)
        res.update(findings=doc.get("findings", []), notes=doc.get("notes", []), failed=doc.get("failed", []))
    except ValueError:
        res["problem"] = "lint printed no JSON"
        res["stdout"] = stdout[-4000:]
    return res


def run_lint(run, lint, args, env):
    t = run.call_timeout(10 ** 6)
    code, stdout, stderr = sh([lint] + args, t, cwd=run.root, env=env)
    return lint_result(args, code, stdout, stderr)


def split_by_clone(res, clones):
    """Each adopter check's findings and notes, by clone."""
    out = collections.OrderedDict((c, {"clone": c}) for c in clones)
    for check, r in res.items():
        for c in clones:
            out[c][check] = {"findings": [], "notes": [], "counts": {}}
        for f in r.get("findings", []):
            c = owner(f.get("file", ""), clones)
            if c:
                item = out[c][check]
                item["findings"].append(f)
                item["counts"][f["rule"]] = item["counts"].get(f["rule"], 0) + 1
        for n in r.get("notes", []):
            c = next((c for c in sorted(clones, key=len, reverse=True)
                      if re.match(rf"^\w+: {re.escape(c)}\b(?![-\w])", n)), None)
            if c:
                out[c][check]["notes"].append(n)
        for c in clones:
            out[c][check]["exit"] = r.get("exit")
            if r.get("failed"):
                out[c][check]["failed"] = r["failed"]
            if r.get("problem"):
                out[c][check]["problem"] = r["problem"]
    return {"clones": list(out.values()), "runs": {k: {"command": v["command"], "exit": v["exit"],
                                                        "stderr": v["stderr"]} for k, v in res.items()}}


def owner(path, clones):
    for c in sorted(clones, key=len, reverse=True):
        if path.startswith(c + "/"):
            return c
    return None


# ---------------------------------------------------------------- cross-lane: trial merges and names

def groups(lanes):
    """{(repository, base): [lanes ahead of it]}."""
    out = collections.OrderedDict()
    for x in lanes:
        if x.get("ahead") and x.get("head") and x.get("integrationHead") and not x.get("skipped"):
            out.setdefault((x["repository"], x["integration"]), []).append(x)
    return out


def pairs_task(run, key, members):
    t0 = time.time()
    skips = []
    repo, base = key
    path = os.path.join(run.root, repo)
    g = run.git(path)
    out = {"repository": repo, "base": base, "lanes": [m["name"] for m in members], "pairs": []}
    common = os.path.join(path, ".git")
    for i in range(len(members)):
        for j in range(i + 1, len(members)):
            a, b = members[i], members[j]
            try:
                files, how = L.trial_merge(g, common, a["head"], b["head"], run.copies)
                out["pairs"].append({"a": a["name"], "b": b["name"], "mode": how, "files": files})
            except L.Slow as e:
                skips.append(run.skip("trial-merges", f"{a['name']} with {b['name']}", str(e)))
            except RuntimeError as e:
                out["pairs"].append({"a": a["name"], "b": b["name"], "problem": str(e)})
    run.timed(f"pairs {repo} {base}", t0)
    return out, skips


# Declarations, from a Swift file with its comments and strings blanked.
DECL = re.compile(r"""(?x)^[ \t]*
    (?:@[A-Za-z_][\w.]*(?:\((?:[^()]|\([^()]*\))*\))?\s*)*
    (?P<mods>(?:(?:public|open|package|internal|fileprivate|private)(?:\(\s*set\s*\))?\s+
              |(?:static|class|final|override|mutating|nonmutating|convenience|required|indirect|nonisolated
                 |dynamic|lazy|weak|unowned|optional|consuming|borrowing|isolated|distributed|prefix|postfix
                 |infix|__consuming)\s+)*)
    (?P<kind>func|var|let|struct|class|enum|protocol|typealias|actor|init|subscript|case|macro|associatedtype)
    (?P<after>(?![\w]).*)$""")
TYPE_LINE = re.compile(r"""(?mx)^[ \t]*
    (?:@[A-Za-z_][\w.]*(?:\((?:[^()]|\([^()]*\))*\))?\s*)*
    (?P<mods>(?:(?:public|open|package|internal|fileprivate|private|final|indirect|nonisolated|distributed)\s+)*)
    (?P<kind>extension|struct|class|enum|protocol|actor)\s+
    (?!(?:func|var|let|init|subscript|case|typealias|associatedtype|in|where|static)\b)
    (?P<name>[A-Za-z_][\w.]*)""")
ACCESS = ("open", "public", "package", "internal", "fileprivate", "private")
STRING_START = re.compile(r'(#*)("""|")')


def blank(text):
    """The text with its comments and string literals' contents replaced by
    spaces, newlines kept, so braces and keywords in them don't count."""
    out = list(text)
    n = len(text)
    special = re.compile(r'//|/\*|#*"')

    def fill(a, b):
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    def skip_string(i, hashes, quote):
        """(end of the content, end of the literal) for a string literal
        whose content starts at i."""
        close = quote + hashes
        esc = "\\" + hashes
        while i < n:
            if text.startswith(esc, i):
                j = i + len(esc)
                if j < n and text[j] == "(":
                    depth, j = 1, j + 1
                    while j < n and depth:
                        m = STRING_START.match(text, j)
                        if m:
                            j = skip_string(m.end(), m.group(1), m.group(2))[1]
                            continue
                        if text[j] == "(":
                            depth += 1
                        elif text[j] == ")":
                            depth -= 1
                        j += 1
                    i = j
                    continue
                i = j + 1
                continue
            if text.startswith(close, i):
                return i, i + len(close)
            if quote == '"' and text[i] == "\n":
                return i, i
            i += 1
        return n, n

    i = 0
    while i < n:
        m = special.search(text, i)
        if not m:
            break
        s = m.start()
        tok = m.group(0)
        if tok == "//":
            e = text.find("\n", s)
            e = n if e < 0 else e
            fill(s, e)
            i = e
        elif tok == "/*":
            depth, j = 1, s + 2
            while j < n and depth:
                if text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            fill(s, j)
            i = j
        else:
            m2 = STRING_START.match(text, s)
            if not m2:
                i = s + 1
                continue
            content_end, e = skip_string(m2.end(), m2.group(1), m2.group(2))
            fill(m2.end(), content_end)
            i = max(e, s + 1)
    return "".join(out)


def statement_starts(blanked):
    """[(position, scopes)]: where a declaration can start (each line's
    start, and just past each `{`, `}` and `;`) with the scopes enclosing
    it: a tuple of (kind, name, access) for each type or extension, or None
    for any other brace (a function body, a closure, a computed property)."""
    stack, out, last = [], [(0, ())], 0
    for i, c in enumerate(blanked):
        if c == "\n":
            out.append((i + 1, tuple(stack)))
        elif c == "{":
            header = "\n".join(x for x in blanked[last:i].split("\n") if not x.lstrip().startswith("#"))
            found = None
            for m in TYPE_LINE.finditer(header):
                found = m
            if found:
                mods = found.group("mods").split()
                access = next((a for a in mods if a in ACCESS), None)
                stack.append((found.group("kind"), found.group("name"), access))
            else:
                stack.append(None)
            last = i + 1
            out.append((i + 1, tuple(stack)))
        elif c in "};":
            if c == "}" and stack:
                stack.pop()
            last = i + 1
            out.append((i + 1, tuple(stack)))
    return out


def split_top(s, stop=None):
    """s split at its top-level commas (outside (), [], <> and {}), up to a
    top-level stop character."""
    parts, cur, depth = [], "", 0
    prev = ""
    for c in s:
        if depth == 0 and stop and c in stop:
            break
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "<":
            depth += 1
        elif c == ">" and prev != "-":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += c
        prev = c
    parts.append(cur)
    return parts


def paren_group(s, start):
    """The text inside the parentheses that open at s[start], or None."""
    if start >= len(s) or s[start] != "(":
        return None
    depth = 0
    for j in range(start, len(s)):
        if s[j] == "(":
            depth += 1
        elif s[j] == ")":
            depth -= 1
            if depth == 0:
                return s[start + 1:j]
    return s[start + 1:]


def labels(params, subscript=False):
    out = []
    for p in split_top(params):
        if not p.strip():
            continue
        head = split_top(p, stop=":")[0].split()
        if not head:
            continue
        if subscript:
            out.append(head[0] if len(head) > 1 else "_")
        else:
            out.append(head[0])
    return "".join(f"{x}:" for x in out)


IDENT = re.compile(r"`[^`]+`|[A-Za-z_][\w]*")


def decl_names(kind, after_text, rest_of_file):
    """The names a declaration line declares: `name(label:)` for functions,
    initializers and subscripts, each name for a case or a property list."""
    a = after_text
    if kind == "func":
        m = re.match(r"\s*(`[^`]+`|[A-Za-z_][\w]*|[-+*/=<>!&|^~%?.]+)\s*(<)?", a)
        if not m:
            return []
        name = m.group(1)
        pos = m.end()
        if m.group(2) and not re.match(r"[-+*/=<>!&|^~%?.]", name):
            depth, j = 1, pos
            while j < len(rest_of_file) and depth:
                if rest_of_file[j] == "<":
                    depth += 1
                elif rest_of_file[j] == ">" and rest_of_file[j - 1] != "-":
                    depth -= 1
                j += 1
            pos = j
        k = rest_of_file.find("(", pos)
        params = paren_group(rest_of_file, k) if k >= 0 else ""
        return [f"{name}({labels(params or '')})"]
    if kind in ("init", "subscript"):
        k = rest_of_file.find("(")
        params = paren_group(rest_of_file, k) if k >= 0 else ""
        return [f"{kind}({labels(params or '', subscript=kind == 'subscript')})"]
    if kind in ("case", "var", "let"):
        names = []
        for part in split_top(a, stop="{"):
            part = part.strip()
            if part.startswith("("):
                names += IDENT.findall(split_top(paren_group(part, 0) or "", stop=":=")[0])
                continue
            m = IDENT.match(part)
            if m:
                names.append(m.group(0))
        return [n for n in names if n not in ("let", "var")]
    m = IDENT.match(a.strip())
    return [m.group(0)] if m else []


def declarations(text, path):
    """[{scope, name, kind, access, line, file, module, text}]: the
    declarations in a Swift file outside function bodies and closures, with
    the types and extensions they're in."""
    import bisect
    b = blank(text)
    raw = text.split("\n")
    line_starts = [0]
    for i, c in enumerate(b):
        if c == "\n":
            line_starts.append(i + 1)
    parts = path.split("/")
    module = "/".join(parts[:2]) if parts[0] in ("Sources", "Tests") and len(parts) > 2 else parts[0]
    out = []
    for pos, stack in statement_starts(b):
        if any(f is None for f in stack):
            continue
        end = b.find("\n", pos)
        segment = b[pos:end if end >= 0 else len(b)]
        m = DECL.match(segment)
        if not m:
            continue
        kind = m.group("kind")
        names = decl_names(kind, m.group("after"), b[pos + m.start("after"):])
        mods = m.group("mods").split()
        access = next((a for a in mods if a in ACCESS), None)
        if access is None:
            access = next((f[2] for f in reversed(stack) if f and f[0] == "extension" and f[2]), None) or "internal"
            if access == "private":
                access = "fileprivate"
        scope = ".".join(f[1] for f in stack)
        n = bisect.bisect_right(line_starts, pos) - 1
        source = raw[n].strip() if n < len(raw) else ""
        for name in names:
            out.append({"scope": scope, "name": name, "kind": kind, "access": access, "line": n + 1, "file": path,
                        "module": module, "text": source})
    return out


def decl_key(d):
    if d["access"] in ("private", "fileprivate"):
        return ("file", d["file"], d["scope"], d["name"])
    if d["scope"]:
        return ("member", d["scope"], d["name"])
    return ("top", d["module"], d["name"])


def added_declarations(run, g, old, new):
    """The declarations new's Swift files have that old's same files don't,
    by key: what a lane or the integration branch added."""
    files = [f for f in g.out("diff", "--name-only", "--no-renames", "-z", old, new, "--", "*.swift").split("\0") if f]
    specs = [f"{old}:{f}" for f in files] + [f"{new}:{f}" for f in files]
    blobs = read_blobs(g, specs)
    out = []
    for f in files:
        if run.expired():
            raise L.Slow("past the deadline in the declaration scan")
        after = blobs.get(f"{new}:{f}")
        if after is None:
            continue
        before = {decl_key(d) for d in declarations(blobs.get(f"{old}:{f}", ""), f)}
        out += [d for d in declarations(after, f) if decl_key(d) not in before]
    return out


def names_task(run, key, members):
    t0 = time.time()
    skips = []
    repo, base = key
    path = os.path.join(run.root, repo)
    out = {"repository": repo, "base": base, "lanes": [], "duplicates": [], "publicNames": []}
    added = {}
    for m in members:
        if not m.get("mergeBase"):
            continue
        g = run.git(m["path"], m.get("gitDirUsed"))
        try:
            mine = added_declarations(run, g, m["mergeBase"], m["head"])
            theirs = added_declarations(run, g, m["mergeBase"], m["integrationHead"])
        except L.Slow as e:
            skips.append(run.skip("names", f"{m['name']}'s added declarations", str(e), lane=m["name"]))
            continue
        except RuntimeError as e:
            out["lanes"].append({"lane": m["name"], "problem": str(e)})
            continue
        added[m["name"]] = mine
        theirs_by = collections.defaultdict(list)
        for d in theirs:
            theirs_by[decl_key(d)].append(d)
        clashes = []
        for d in mine:
            k = decl_key(d)
            if k in theirs_by:
                clashes.append({"key": list(k), "lane": d, "integration": theirs_by[k]})
        out["lanes"].append({"lane": m["name"], "mergeBase": m["mergeBase"], "added": mine,
                             "integrationAddedSinceMergeBase": len(theirs), "clashesWithIntegration": clashes})
    by_key = collections.defaultdict(list)
    by_public = collections.defaultdict(list)
    for lane, decls in added.items():
        for d in decls:
            by_key[decl_key(d)].append(dict(d, lane=lane))
            if not d["scope"] and d["access"] in ("public", "open"):
                by_public[d["name"]].append(dict(d, lane=lane))
    for k, ds in sorted(by_key.items()):
        if len({d["lane"] for d in ds}) > 1:
            out["duplicates"].append({"key": list(k), "declarations": ds})
    for name, ds in sorted(by_public.items()):
        if len({d["lane"] for d in ds}) > 1:
            out["publicNames"].append({"name": name, "declarations": ds})
    run.timed(f"names {repo} {base}", t0)
    return out, skips


# ---------------------------------------------------------------- reports elsewhere

def report_repositories(run):
    """[(name, path)] of every repository a report's hash can be in."""
    repos = []
    for repo, _, _ in L.REPOS:
        p = os.path.join(run.root, repo)
        if os.path.isdir(os.path.join(p, ".git")):
            repos.append((repo, p))
    top = os.path.join(run.root, "adopters")
    if os.path.isdir(top):
        for name in sorted(os.listdir(top), key=str.lower):
            p = os.path.join(top, name)
            if os.path.isdir(os.path.join(p, ".git")):
                repos.append((f"adopters/{name}", p))
    return repos


def unresolved_hashes(lanes):
    return sorted({h["hash"] for x in lanes for r in x.get("reports") or [] for h in r.get("hashes", [])
                   if h.get("inRepo") != "commit"})


def elsewhere_task(run, repo, path, tokens):
    """{hash: {"repository", "commit", "branches"}} for the report hashes
    that aren't commits in their lane's repository (or that a workspace's
    report names) but are in this one, with the local branches that have
    them."""
    t0 = time.time()
    skips, found = [], {}
    try:
        g = run.git(path)
        hits = {t: full for t, (kind, full) in batch_check(g, tokens).items() if kind == "commit"}
        if hits:
            branches = g.out("for-each-ref", "--format=%(refname:short)", "refs/heads").split()
            sets = {b: rev_set(run, g, f"refs/heads/{b}") for b in branches}
            for t, full in hits.items():
                found[t] = {"repository": repo, "commit": full, "branches": [b for b in branches if full in sets[b]]}
    except L.Slow as e:
        skips.append(run.skip("reports", f"report hashes in {repo}", str(e)))
    run.timed(f"reports elsewhere {repo}", t0)
    return found, skips


def apply_elsewhere(lanes, results):
    found = collections.defaultdict(list)
    for res in results:
        for t, item in (res or {}).items():
            found[t].append(item)
    for x in lanes:
        for r in x.get("reports") or []:
            for h in r.get("hashes", []):
                if h.get("inRepo") != "commit" and h["hash"] in found:
                    h["elsewhere"] = found[h["hash"]]


# ---------------------------------------------------------------- environment

def git_version():
    try:
        return subprocess.run(["git", "--version"], capture_output=True, text=True, env=L.ENV,
                              timeout=10).stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return f"unknown ({e})"


def merge_mode(run):
    """Whether this git's `merge-tree` has `--write-tree`: lanes.py's probe,
    which writes nothing."""
    path = os.path.join(run.root, "swift-system")
    if not os.path.isdir(os.path.join(path, ".git")):
        return "not probed: no swift-system"
    try:
        return L.merge_tree_mode(run.git(path))
    except (L.Slow, RuntimeError) as e:
        return f"not probed: {e}"


def environment_task(run, discovery):
    t0 = time.time()
    out = {"root": run.root, "hostRoot": discovery["hostRoot"], "python": platform.python_version(),
           "platform": f"{platform.system()} {platform.release()} {platform.machine()}",
           "git": git_version(), "trialMerges": merge_mode(run), "xcrun": shutil.which("xcrun"),
           "claude": "readable" if run.claude else "unknown (~/.claude can't be read here)"}
    try:
        code, df, err = sh(["df", "-h", run.root], run.call_timeout(20))
        out["df"] = df.strip() if code == 0 else err.strip()
        du = shutil.disk_usage(run.root)
        out["freeGiB"] = round(du.free / 2 ** 30, 1)
    except L.Slow as e:
        out["df"] = f"skipped: {e}"
    run.timed("environment", t0)
    return out, []


def du_task(run):
    t0 = time.time()
    skips = []
    out = {"path": run.logs_dir}
    if not os.path.isdir(run.logs_dir):
        out["problem"] = "no linux-logs"
        return out, skips
    try:
        code, stdout, err = sh(["du", "-sh", run.logs_dir], run.call_timeout(60))
        out["du"] = stdout.strip() if code == 0 else err.strip()
    except L.Slow as e:
        out["skipped"] = str(e)
        skips.append({"section": "environment", "part": "du -sh of linux-logs", "why": str(e),
                      "command": f"du -sh {shlex.quote(run.logs_dir)}",
                      "atSeconds": round(time.time() - run.start, 1)})
    out["seconds"] = round(time.time() - t0, 2)
    run.timed("du linux-logs", t0)
    return out, skips


def path_mappings(lanes, discovery):
    mapped, failed, gitdirs = [], [], []
    for x in lanes:
        if x.get("recordedPath") and x.get("path"):
            mapped.append({"lane": x["name"], "recorded": x["recordedPath"], "seen": x["path"]})
        if x.get("gitDir") and x.get("recordedGitDir"):
            gitdirs.append({"lane": x["name"], "recorded": x["recordedGitDir"], "seen": x["gitDir"]})
        if x.get("problem") and ("isn't here" in x["problem"]):
            failed.append({"lane": x["name"], "why": x["problem"]})
    return {"hostRoot": discovery["hostRoot"], "worktreePaths": mapped, "gitDirs": gitdirs, "failed": failed}


def not_run_here(run, discovery, integration):
    host = discovery["hostRoot"] or run.root
    out = []
    for check, where, cmd in NOT_RUN:
        out.append({"check": check, "command": f"cd {host}/{where} && {cmd}"})
    return out


# ---------------------------------------------------------------- the previous snapshot

def load_previous(out_dir):
    """The earlier snapshot in DIR as {section: json}, or None."""
    idx = os.path.join(out_dir, "index.json")
    if not os.path.isfile(idx):
        return None
    try:
        with open(idx) as f:
            index = json.load(f)
    except (OSError, ValueError):
        return None
    if index.get("tool") != TOOL:
        return None
    prev = {"index": index}
    for name in SECTION_NAMES:
        p = os.path.join(out_dir, f"{name}.json")
        if os.path.isfile(p):
            try:
                with open(p) as f:
                    prev[name] = json.load(f)
            except (OSError, ValueError):
                pass
    return prev


def diff_previous(run, prev, new, full_lanes):
    """What changed between the earlier snapshot and this one, field by
    field: no judgment of what matters."""
    out = {"previous": prev["index"].get("generated"), "previousSince": prev["index"].get("since")}
    full = {x["name"]: x for x in full_lanes}
    old_lanes = {x["name"]: x for x in (prev.get("lanes") or {}).get("lanes", [])}
    new_lanes = {x["name"]: x for x in new["lanes"]["lanes"]}
    out["lanesAppeared"] = sorted(set(new_lanes) - set(old_lanes))
    out["lanesVanished"] = sorted(set(old_lanes) - set(new_lanes))
    moved, changed, removed = [], [], []
    for name in sorted(set(old_lanes) & set(new_lanes)):
        a, b = old_lanes[name], new_lanes[name]
        if a.get("head") != b.get("head") and b.get("head"):
            moved.append(head_move(run, full.get(name, b), a.get("head"), b.get("head")))
        if a.get("path") and not a.get("problem") and b.get("problem"):
            removed.append({"lane": name, "now": b["problem"]})
        fields = {}
        for k in ("branch", "ahead", "behind", "uncommitted", "inProgress", "conflicts", "problem", "newestWrite",
                  "newestBuildWrite", "newestReport", "linuxLog", "session"):
            was, now = a.get(k), b.get(k)
            if k == "session":
                was, now = (was or {}).get("modified"), (now or {}).get("modified")
            if was != now:
                fields[k] = {"was": was, "now": now}
        if fields:
            changed.append({"lane": name, "fields": fields})
    for name in out["lanesVanished"]:
        if old_lanes[name].get("path"):
            removed.append({"lane": name, "now": "not listed"})
    out["headsMoved"], out["laneFields"], out["worktreesRemoved"] = moved, changed, removed
    # Branches.
    obr = {r["repository"]: r for r in (prev.get("branches") or {}).get("repositories", [])}
    br = []
    for r in new["branches"]["repositories"]:
        o = obr.get(r["repository"])
        if not o:
            continue
        for kind in ("local", "remote"):
            ob = {b["name"]: b["head"] for b in o.get(kind, [])}
            nb = {b["name"]: b["head"] for b in r.get(kind, [])}
            for n in sorted(set(nb) - set(ob)):
                br.append({"repository": r["repository"], "kind": kind, "branch": n, "change": "appeared",
                           "head": nb[n]})
            for n in sorted(set(ob) - set(nb)):
                br.append({"repository": r["repository"], "kind": kind, "branch": n, "change": "vanished",
                           "head": ob[n]})
            for n in sorted(set(ob) & set(nb)):
                if ob[n] != nb[n]:
                    br.append({"repository": r["repository"], "kind": kind, "branch": n, "change": "moved",
                               "was": ob[n], "now": nb[n]})
    out["branches"] = br
    # Integration branches.
    oint = {i["repository"]: i for i in (prev.get("integration") or {}).get("branches", [])}
    ints = []
    for i in new["integration"]["branches"]:
        o = oint.get(i["repository"])
        if not o or not i.get("head"):
            continue
        was = (o.get("head") or {}).get("hash")
        if was != i["head"]["hash"]:
            seen = {c["hash"] for c in o.get("history", [])}
            ints.append({"repository": i["repository"], "branch": i["branch"], "was": was, "now": i["head"]["hash"],
                         "newFirstParent": [{"hash": c["hash"], "subject": c["subject"], "time": c["time"]}
                                            for c in i.get("history", []) if c["hash"] not in seen]})
    out["integration"] = ints
    # Linux logs.
    ologs = {x["file"]: x for x in (prev.get("linux-logs") or {}).get("logs", [])}
    nlogs = {x["file"]: x for x in new["linux-logs"]["logs"]}
    out["logsNew"] = [{"file": f, "modified": nlogs[f]["modified"], "summary": nlogs[f].get("summary", [])}
                      for f in sorted(set(nlogs) - set(ologs), key=lambda f: nlogs[f]["modified"], reverse=True)]
    out["logsGone"] = sorted(set(ologs) - set(nlogs))
    out["logsChanged"] = [{"file": f, "was": {"size": ologs[f]["size"], "modified": ologs[f]["modified"]},
                           "now": {"size": nlogs[f]["size"], "modified": nlogs[f]["modified"]}}
                          for f in sorted(set(ologs) & set(nlogs))
                          if (ologs[f]["size"], ologs[f]["modified"]) != (nlogs[f]["size"], nlogs[f]["modified"])]
    # Reports.
    orep = {(x["lane"], r["path"]): r for x in (prev.get("reports") or {}).get("lanes", []) for r in x["reports"]}
    nrep = {(x["lane"], r["path"]): r for x in new["reports"]["lanes"] for r in x["reports"]}
    reps = []
    for k in sorted(set(orep) | set(nrep)):
        a, b = orep.get(k), nrep.get(k)
        if a is None:
            reps.append({"lane": k[0], "path": k[1], "change": "appeared", "size": b.get("size"),
                         "modified": b.get("modified")})
        elif b is None:
            reps.append({"lane": k[0], "path": k[1], "change": "vanished"})
        elif (a.get("size"), a.get("modified")) != (b.get("size"), b.get("modified")):
            oh = [h["text"] for h in a.get("outline", [])]
            nh = [h["text"] for h in b.get("outline", [])]
            reps.append({"lane": k[0], "path": k[1], "change": "changed",
                         "was": {"size": a.get("size"), "modified": a.get("modified")},
                         "now": {"size": b.get("size"), "modified": b.get("modified")},
                         "headingsAdded": [h for h in nh if h not in oh],
                         "headingsRemoved": [h for h in oh if h not in nh],
                         "resumeChanged": (a.get("resume") or {}).get("text") != (b.get("resume") or {}).get("text")})
    out["reports"] = reps
    # Lock files, STATUS.md, lint counts.
    olock = {(r["repository"], x["path"]) for r in (prev.get("git-state") or {}).get("repositories", [])
             for x in r.get("locks", [])}
    nlock = {(r["repository"], x["path"]) for r in new["git-state"]["repositories"] for x in r.get("locks", [])}
    out["locksNew"] = [{"repository": a, "path": b} for a, b in sorted(nlock - olock)]
    out["locksGone"] = [{"repository": a, "path": b} for a, b in sorted(olock - nlock)]
    os_ = (prev.get("status") or {}).get("lastChange") or {}
    ns_ = new["status"].get("lastChange") or {}
    out["statusMd"] = None if os_.get("hash") == ns_.get("hash") else {"was": os_.get("hash"), "now": ns_.get("hash")}
    out["lint"] = lint_count_changes(prev.get("lint") or {}, new["lint"])
    return out


def head_move(run, lane, was, now):
    item = {"lane": lane["name"], "was": was, "now": now}
    if not was or not lane.get("path") or not lane.get("gitDirUsed") or run.expired():
        return item
    try:
        g = run.git(lane["path"], lane["gitDirUsed"])
        if g("cat-file", "-e", f"{was}^{{commit}}", ok=(0, 1, 128)).returncode != 0:
            item["relation"] = "the earlier head isn't in this repository"
        elif g("merge-base", "--is-ancestor", was, now, ok=(0, 1)).returncode == 0:
            item["relation"] = "fast-forward"
            item["commits"] = int(g.out("rev-list", "--count", f"{was}..{now}").strip())
        else:
            item["relation"] = "rewritten (the earlier head isn't an ancestor)"
    except (L.Slow, RuntimeError) as e:
        item["relation"] = f"not read: {e}"
    return item


def lint_count_changes(old, new):
    def counts(doc):
        out = {}
        sysr = doc.get("system") or {}
        for f in sysr.get("findings", []):
            out[("swift-system", f["rule"])] = out.get(("swift-system", f["rule"]), 0) + 1
        for c in ((doc.get("adopters") or {}).get("clones") or []):
            for check in ("markers", "conditionals"):
                for rule, n in ((c.get(check) or {}).get("counts") or {}).items():
                    out[(c["clone"], rule)] = n
        return out
    a, b = counts(old), counts(new)
    return [{"where": k[0], "rule": k[1], "was": a.get(k, 0), "now": b.get(k, 0)}
            for k in sorted(set(a) | set(b)) if a.get(k, 0) != b.get(k, 0)]


# ---------------------------------------------------------------- assembling the sections

def lane_row(x, act):
    row = {k: x.get(k) for k in ("name", "kind", "repository", "path", "hostPath", "recordedPath", "gitDir", "branch",
                                 "head", "headTime", "subject", "integration", "ahead", "behind", "newCommits",
                                 "uncommitted", "inProgress", "conflicts", "conflictsBy", "problem", "note",
                                 "skipped", "partial", "problems")
           if x.get(k) is not None}
    if x["kind"] in ("adopter", "adopter worktree") and "aheadOfMain" in x:
        row.update(integration="main", ahead=x["aheadOfMain"], behind=x["behindMain"])
    if row.get("headTime"):
        row["headTime"] = iso(epoch(row["headTime"]))
    if act:
        row["newestWrite"] = (act.get("newest") or {}).get("modified")
        row["newestBuildWrite"] = (act.get("newestInBuild") or {}).get("modified")
        if act.get("partial"):
            row["activityPartial"] = True
    reps = [r for r in x.get("reports") or [] if r.get("modified")]
    row["reports"] = len(reps)
    if reps:
        newest = max(reps, key=lambda r: r["modified"])
        row["newestReport"] = {"path": newest["path"], "modified": newest["modified"]}
    logs = x.get("linuxLogs") or []
    if logs:
        lg = logs[0]
        row["linuxLog"] = {"file": lg["file"], "modified": lg["modified"],
                           "namesHead": bool(x.get("head") and lg.get("commit") and x["head"].startswith(lg["commit"]))}
    if x.get("session"):
        row["session"] = x["session"]
    return row


def build(run, discovery, lanes, acts, repos, logs, integ, status, lint, pair_results, name_results, env, du, skips):
    by = {x["name"]: x for x in lanes}
    act_by = {a["name"]: a for a in acts}
    sec = {}
    env = dict(env or {})
    env["paths"] = path_mappings(lanes, discovery)
    env["du"] = du
    env["notes"] = discovery["notes"]
    env["notRunHere"] = not_run_here(run, discovery, integ)
    sec["environment"] = env
    sec["lanes"] = {"lanes": [lane_row(x, act_by.get(x["name"])) for x in lanes]}
    sec["branches"] = {"repositories": [{k: r.get(k) for k in ("repository", "path", "local", "remote", "worktrees",
                                                                 "newestMigration", "problem") if k in r}
                                         for r in repos]}
    sec["commits"] = {"lanes": [{"lane": x["name"], "kind": x["kind"], "range": x.get("commitsRange"),
                                 "commits": x.get("commits", []), "newCommits": x.get("newCommits", 0)}
                                for x in lanes if "commits" in x]}
    sec["changed-files"] = {"lanes": [{"lane": x["name"], "kind": x["kind"], "mergeBase": x.get("mergeBase"),
                                       "base": x.get("diffBase") or x.get("integration"),
                                       "files": x.get("changedFiles", []), "byTopLevel": x.get("changedByTop", [])}
                                      for x in lanes if "changedFiles" in x]}
    sec["git-state"] = {"lanes": [{"lane": x["name"], "kind": x["kind"], "uncommitted": x.get("uncommittedFiles", []),
                                   "unmerged": x.get("unmerged", []), "conflictMarkers": x.get("conflictMarkers", []),
                                   "inProgress": x.get("inProgressDetail", {})}
                                  for x in lanes if "uncommittedFiles" in x],
                        "repositories": [{"repository": r["repository"], "locks": r.get("locks", [])} for r in repos]}
    sec["trial-merges"] = {
        "lanes": [{"lane": x["name"], "base": x.get("integration"), "ahead": x.get("ahead"), "behind": x.get("behind"),
                   "mode": x.get("conflictsBy") or ("not needed: one side contains the other" if "conflicts" in x
                                                    else None),
                   "files": x.get("conflictFiles", [])}
                  for x in lanes if x.get("integrationHead")],
        "pairs": pair_results}
    sec["names"] = {"groups": name_results}
    sec["activity"] = {"lanes": acts}
    sec["reports"] = {"lanes": [{"lane": x["name"], "kind": x["kind"], "reports": x.get("reports", [])}
                                for x in lanes if x.get("reports")]}
    sec["linux-logs"] = {"directory": run.logs_dir, "logs": logs}
    sec["integration"] = {"branches": integ}
    sec["status"] = status or {}
    sec["lint"] = lint or {}
    return sec


# ---------------------------------------------------------------- Markdown

def esc(text):
    return str(text if text is not None else "").replace("|", "\\|").replace("\n", " ")


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(esc(c) for c in r) + " |")
    return out


def short(h):
    return f"`{h[:10]}`" if h else ""


def md_section(name, doc, meta, zone):
    t = zone.show
    L_ = [f"# {TITLES[name]}", ""]
    L_.append(f"Snapshot of `{meta['root']}` at {t(meta['generated'], True)}; times are {zone.label}. "
              f"Since: {t(meta['since'])} ({meta['sinceFrom']}).")
    skipped = [s for s in meta.get("skipped", []) if s["section"] == name]
    if skipped:
        L_.append("")
        L_.append(f"**Incomplete**: {len(skipped)} part(s) skipped; each one's command gets it alone.")
        for s in skipped:
            L_.append(f"- {s['part']}: {s['why']}" + (f" ({s['progress']})" if s.get("progress") else "")
                      + f": `{s['command']}`")
    L_.append("")
    L_ += RENDER[name](doc, zone)
    return "\n".join(L_).rstrip() + "\n"


def r_environment(doc, zone):
    out = []
    p = doc.get("paths") or {}
    out.append(f"- Root: `{doc.get('root')}`" + (f", recorded as `{doc['hostRoot']}`" if doc.get("hostRoot") else
                                                  " (the lanes' recorded paths)"))
    out.append(f"- Git: {doc.get('git')}; trial merges: {doc.get('trialMerges')}")
    out.append(f"- xcrun: {doc.get('xcrun') or 'none (lint conditionals runs without the SDK Swift names)'}")
    out.append(f"- Python {doc.get('python')}, {doc.get('platform')}")
    out.append(f"- Claude Code sessions: {doc.get('claude')}")
    out.append(f"- Free disk: {doc.get('freeGiB')} GiB")
    du = doc.get("du") or {}
    out.append(f"- linux-logs: {du.get('du') or du.get('skipped') or du.get('problem')}")
    out.append(f"- Run: {doc.get('seconds')} s of a {doc.get('deadline')} s deadline")
    out.append("")
    out.append("```")
    out.append(doc.get("df") or "")
    out.append("```")
    out.append("")
    out.append("## Paths")
    out.append("")
    if not (p.get("worktreePaths") or p.get("gitDirs") or p.get("failed")):
        out.append("No mapping was needed: every recorded path is here.")
    else:
        out.append(f"Recorded under `{p.get('hostRoot')}`; mapped to this folder by the paths' last components.")
        out.append("")
        if p.get("worktreePaths"):
            out += table(["Lane", "Recorded", "Seen"], [(m["lane"], m["recorded"], m["seen"])
                                                         for m in p["worktreePaths"]])
            out.append("")
        if p.get("gitDirs"):
            out += table(["Lane", "Git directory recorded", "Seen"], [(m["lane"], m["recorded"], m["seen"])
                                                                      for m in p["gitDirs"]])
            out.append("")
        if p.get("failed"):
            out.append("Failed:")
            out += [f"- `{m['lane']}`: {m['why']}" for m in p["failed"]]
            out.append("")
    if doc.get("notes"):
        out.append("## Notes")
        out += [f"- {n}" for n in doc["notes"]]
        out.append("")
    out.append("## Checks not run here")
    out.append("")
    out += table(["Check", "Command"], [(c["check"], f"`{c['command']}`") for c in doc.get("notRunHere", [])])
    out.append("")
    out.append("## Timings (seconds)")
    out.append("")
    out += table(["Part", "Seconds"], sorted((doc.get("timings") or {}).items(), key=lambda kv: -kv[1]))
    return out


def r_lanes(doc, zone):
    t = zone.show
    out = []
    kinds = collections.OrderedDict()
    for x in doc["lanes"]:
        kinds.setdefault(x["kind"], []).append(x)
    for kind, rows in kinds.items():
        out.append(f"## {kind}")
        out.append("")
        body = []
        for x in rows:
            rel = f"+{x['ahead']} −{x['behind']} vs {x['integration']}" if "ahead" in x else ""
            conflicts = "" if x.get("conflicts") is None else (
                f"{x['conflicts']}" + ("*" if x.get("conflictsBy") == "trivial" else ""))
            rep = x.get("newestReport") or {}
            lg = x.get("linuxLog") or {}
            s = x.get("session") or {}
            body.append((f"`{x['name']}`", x.get("branch") or "", short(x.get("head")) + " " + t(x.get("headTime")),
                         rel, x.get("newCommits", ""), x.get("uncommitted", ""),
                         ", ".join(x.get("inProgress") or []), conflicts,
                         t(x.get("newestWrite")) + (" (partial)" if x.get("activityPartial") else ""),
                         t(x.get("newestBuildWrite")),
                         (f"{rep.get('path')} {t(rep.get('modified'))} ({x.get('reports', 0)})" if rep else ""),
                         (f"{lg['file']} {t(lg['modified'])}" + (" (head)" if lg.get("namesHead") else ""))
                         if lg else "",
                         f"{s.get('state', '')} {t(s.get('modified'))}".strip(),
                         x.get("problem") or x.get("skipped") or x.get("note") or ""))
        out += table(["Lane", "Branch", "Head", "Base", "New commits", "Uncommitted", "In progress", "Conflicts",
                      "Newest write", "Newest in .build", "Newest report (count)", "Newest Linux log", "Session",
                      "Problem"], body)
        out.append("")
    if any(x.get("conflictsBy") == "trivial" for x in doc["lanes"]):
        out.append("\\* From a trivial merge (`git merge-tree BASE OURS THEIRS`): this git has no `--write-tree`; a "
                   "conflict through a rename isn't seen.")
    return out


def r_branches(doc, zone):
    t = zone.show
    out = []
    for r in doc["repositories"]:
        out.append(f"## {r['repository']}")
        out.append("")
        if r.get("problem"):
            out.append(f"Problem: {r['problem']}")
            out.append("")
        if r.get("newestMigration") is not None:
            out.append(f"Newest migration branch: `{r['newestMigration']}`")
            out.append("")
        out += table(["Branch", "Head", "Time", "Subject", "Checked out in", "Upstream"],
                     [(("**" + b["name"] + "**") if b.get("migration") else b["name"], short(b["head"]),
                       t(b.get("time")), b.get("subject", ""),
                       (b.get("worktreeSeen") or b.get("worktree") or "") + (" (missing)" if b.get("worktreeMissing")
                                                                              else ""),
                       b.get("upstream", "")) for b in r.get("local", [])])
        out.append("")
        if r.get("worktrees"):
            out.append("Worktrees:")
            out.append("")
            out += table(["Recorded", "Seen", "Branch", "Head", "State"],
                         [(w["recorded"], w.get("seen", ""), w.get("branch") or ("(detached)" if w.get("detached")
                                                                                 else ""),
                           short(w.get("head")), ", ".join(k for k in ("missing", "locked", "prunable", "bare")
                                                           if w.get(k)))
                          for w in r["worktrees"]])
            out.append("")
        if r.get("remote"):
            out.append(f"<details><summary>{len(r['remote'])} remote-tracking branches</summary>")
            out.append("")
            out += table(["Branch", "Head", "Time", "Subject"],
                         [(b["name"], short(b["head"]), t(b.get("time")), b.get("subject", "")) for b in r["remote"]])
            out.append("")
            out.append("</details>")
            out.append("")
    return out


def r_commits(doc, zone):
    t = zone.show
    out = []
    for x in doc["lanes"]:
        out.append(f"## {x['lane']}: {len(x['commits'])} commits ({x.get('range') or 'no base'}), "
                   f"{x.get('newCommits', 0)} new since --since")
        out.append("")
        if x["commits"]:
            out += table(["Commit", "Time", "New", "Merge", "Subject"],
                         [(short(c["hash"]), t(c["time"]), "new" if c.get("new") else "",
                           "merge" if len(c["parents"]) > 1 else "", c["subject"]) for c in x["commits"]])
            out.append("")
    return out


def r_changed(doc, zone):
    out = []
    for x in doc["lanes"]:
        out.append(f"## {x['lane']}: {len(x['files'])} files since {short(x.get('mergeBase'))} "
                   f"(merge base with {x.get('base')})")
        out.append("")
        if x["byTopLevel"]:
            out += table(["Directory", "Files", "Added", "Deleted"],
                         [(d["directory"], d["files"], d["added"], d["deleted"]) for d in x["byTopLevel"]])
            out.append("")
            out += table(["Status", "File", "Added", "Deleted"],
                         [(f["status"], (f"{f['from']} → " if f.get("from") else "") + f["path"],
                           "binary" if f.get("added") is None else f["added"],
                           "" if f.get("deleted") is None else f["deleted"]) for f in x["files"]])
            out.append("")
    return out


def r_state(doc, zone):
    t = zone.show
    out = []
    clean = [x["lane"] for x in doc["lanes"] if not (x["uncommitted"] or x["inProgress"] or x["unmerged"]
                                                     or x["conflictMarkers"])]
    if clean:
        out.append(f"Clean ({len(clean)}): " + ", ".join(f"`{c}`" for c in clean) + ".")
        out.append("")
    for x in doc["lanes"]:
        if x["lane"] in clean:
            continue
        n = len(x["uncommitted"])
        bits = [f"{n} uncommitted"]
        if x["inProgress"]:
            bits.append("in progress: " + ", ".join(x["inProgress"]))
        if x["unmerged"]:
            bits.append(f"{len(x['unmerged'])} unmerged")
        if x["conflictMarkers"]:
            bits.append(f"conflict markers in {len(x['conflictMarkers'])} files")
        out.append(f"## {x['lane']}: " + "; ".join(bits))
        out.append("")
        for name, item in x["inProgress"].items():
            out.append(f"- {name}: " + ", ".join(f"{k} {v}" for k, v in item.items()))
        if x["inProgress"]:
            out.append("")
        if x["uncommitted"]:
            out += table(["Status", "File"], [(e["status"], (f"{e['from']} → " if e.get("from") else "") + e["path"])
                                             for e in x["uncommitted"]])
            out.append("")
        for m in x["conflictMarkers"]:
            out.append(f"- conflict markers in `{m['path']}` at lines {', '.join(map(str, m['lines']))}")
        if x["conflictMarkers"]:
            out.append("")
    out.append("## Lock files")
    out.append("")
    locks = [(r["repository"], lk["path"], t(lk["modified"], True), lk["size"])
             for r in doc["repositories"] for lk in r["locks"]]
    out += table(["Repository", "File", "Modified", "Size"], locks) if locks else ["None."]
    return out


def r_trial(doc, zone):
    out = ["## Each lane with its base", ""]
    out += table(["Lane", "Base", "Ahead", "Behind", "Mode", "Conflicting files"],
                 [(x["lane"], x["base"], x["ahead"], x["behind"], x["mode"] or "",
                   ", ".join(x["files"]) or ("none" if x["mode"] else "")) for x in doc["lanes"]])
    out.append("")
    out.append("## Lanes with each other")
    out.append("")
    if not doc["pairs"]:
        out.append("No two lanes are ahead of the same base.")
    for gp in doc["pairs"]:
        out.append(f"### {gp['repository']}, ahead of {gp['base']}: {', '.join(gp['lanes'])}")
        out.append("")
        out += table(["Lane", "Lane", "Mode", "Conflicting files"],
                     [(p["a"], p["b"], p.get("mode", ""), p.get("problem") or ", ".join(p.get("files", [])) or "none")
                      for p in gp["pairs"]]) if gp["pairs"] else ["Only one lane."]
        out.append("")
    return out


def decl_cell(d):
    where = f"`{d['file']}:{d['line']}` `{d.get('text', '')}`"
    return f"{d['lane']}: {where}" if "lane" in d else where


def r_names(doc, zone):
    out = []
    if not doc["groups"]:
        out.append("No lane is ahead of its base.")
    for gp in doc["groups"]:
        out.append(f"## {gp['repository']}, ahead of {gp['base']}")
        out.append("")
        out.append(f"Added by more than one lane (same type's member, same module's top-level name, or the same "
                   f"file's private name): {len(gp['duplicates'])}; public top-level names: "
                   f"{len(gp['publicNames'])}.")
        out.append("")
        if gp["duplicates"]:
            out += table(["Key", "Declarations"], [(" ".join(map(str, k["key"])),
                                                    "; ".join(decl_cell(d) for d in k["declarations"]))
                                                   for k in gp["duplicates"]])
            out.append("")
        if gp["publicNames"]:
            out += table(["Public name", "Declarations"], [(k["name"], "; ".join(decl_cell(d) for d in
                                                                                  k["declarations"]))
                                                           for k in gp["publicNames"]])
            out.append("")
        for ln in gp["lanes"]:
            if ln.get("problem"):
                out.append(f"### {ln['lane']}: {ln['problem']}")
                continue
            out.append(f"### {ln['lane']}: {len(ln['added'])} declarations added; "
                       f"{len(ln['clashesWithIntegration'])} also added by {gp['base']} since {short(ln['mergeBase'])} "
                       f"({ln['integrationAddedSinceMergeBase']} added there)")
            out.append("")
            if ln["clashesWithIntegration"]:
                out += table(["Key", "Lane", gp["base"]],
                             [(" ".join(map(str, c["key"])), decl_cell(c["lane"]),
                               "; ".join(decl_cell(d) for d in c["integration"])) for c in ln["clashesWithIntegration"]])
                out.append("")
            if ln["added"]:
                out += table(["Scope", "Name", "Kind", "Access", "Where", "Line"],
                             [(d["scope"] or f"({d['module']})", d["name"], d["kind"], d["access"],
                               f"`{d['file']}:{d['line']}`", f"`{d.get('text', '')}`") for d in ln["added"]])
                out.append("")
    return out


def r_activity(doc, zone):
    t = zone.show
    out = []
    rows = []
    for a in doc["lanes"]:
        if a["kind"] == "workspace":
            continue
        s = a.get("session") or {}
        rows.append((f"`{a['name']}`", t((a.get("newest") or {}).get("modified")), (a.get("newest") or {}).get("path", ""),
                     t((a.get("newestInBuild") or {}).get("modified")), (a.get("newestInBuild") or {}).get("path", ""),
                     t((a.get("newestOutsideBuild") or {}).get("modified")),
                     (a.get("newestOutsideBuild") or {}).get("path", ""), a.get("entries", ""),
                     (f"partial: {a['unreadDirectories']} directories unread, their own times up to "
                      f"{t(a['unreadNewestDirectoryTime'])}") if a.get("partial") else a.get("problem", ""),
                     f"{s.get('state', '')} {t(s.get('modified'))}".strip()))
    out += table(["Lane", "Newest", "File", "Newest in .build", "File", "Newest outside .build", "File", "Entries",
                  "", "Session"], rows)
    out.append("")
    for a in doc["lanes"]:
        if a["kind"] != "workspace":
            continue
        out.append(f"## Workspace {a['name']}")
        out.append("")
        if a.get("newestTopFile"):
            out.append(f"Newest file at its top: `{a['newestTopFile']['path']}` {t(a['newestTopFile']['modified'])}")
            out.append("")
        out += table(["Directory", "Newest", "File", "Entries", ""],
                     [(d["directory"], t((d.get("newest") or {}).get("modified")), (d.get("newest") or {}).get("path", ""),
                       d["entries"], "partial" if d.get("partial") else "") for d in a.get("directories", [])])
        s = a.get("session") or {}
        out.append("")
        out.append(f"Session: {s.get('state', '')} {t(s.get('modified'))}")
        out.append("")
    return out


def r_reports(doc, zone):
    t = zone.show
    out = []
    for x in doc["lanes"]:
        for r in x["reports"]:
            out.append(f"## {x['lane']}: `{r['path']}`")
            out.append("")
            if r.get("problem"):
                out.append(f"Problem: {r['problem']}")
                out.append("")
                continue
            out.append(f"{r['size']} bytes, {r['lines']} lines, modified {t(r['modified'], True)}.")
            out.append("")
            out.append("Outline:")
            out.append("")
            out += [f"- {h['line']}: {'#' * h['level']} {h['text']}" for h in r["outline"]] or ["- (no headings)"]
            out.append("")
            if r.get("resume"):
                out.append(f"Resume here (line {r['resume']['line']}):")
                out.append("")
                out += ["> " + ln if ln else ">" for ln in r["resume"]["text"].split("\n")]
            else:
                out.append("No \"Resume here\".")
            out.append("")
            if r["hashes"]:
                rows = []
                for h in r["hashes"]:
                    where = h.get("inRepo", "")
                    if h.get("inRepo") == "commit":
                        where = "on the lane's branch" if h.get("onBranch") else (
                            "not on the lane's branch" + (f"; on {', '.join(h['branches'])}" if h.get("branches")
                                                          else ""))
                    elif h.get("elsewhere"):
                        where += "; in " + "; ".join(
                            f"{e['repository']}" + (f" on {', '.join(e['branches'])}" if e["branches"] else
                                                    " on no local branch") for e in h["elsewhere"])
                    rows.append((f"`{h['hash']}`", h["line"], h["count"], where))
                out += table(["Hash", "Line", "Times", "Where"], rows)
                out.append("")
    return out


def r_logs(doc, zone):
    t = zone.show
    out = [f"{len(doc['logs'])} logs in `{doc['directory']}`, newest first.", ""]
    out += table(["Log", "Modified", "Size", "Lane", "Package", "Commit", "In", "Totals", "error: lines (distinct)",
                  "Exit", "First error lines"],
                 [(x["file"], t(x["modified"]), x["size"], x.get("lane", ""), x.get("package", ""),
                   x.get("commit", ""), ", ".join(x.get("commitIn", [])), "; ".join(x.get("summary", [])),
                   f"{(x.get('errors') or {}).get('lines', '')} ({(x.get('errors') or {}).get('distinct', '')})"
                   if x.get("errors") else "",
                   x.get("exit", ""), first_errors(x)) for x in doc["logs"]])
    out.append("")
    out.append("First lines:")
    out.append("")
    out += table(["Log", "First line"], [(x["file"], x.get("header", "")) for x in doc["logs"]])
    return out


def first_errors(x):
    e = x.get("errors") or {}
    first = e.get("first", [])
    more = e.get("distinct", 0) - len(first)
    return " ⏎ ".join(first) + (f" (and {more} more distinct: grep 'error:' on the log)" if more > 0 else "")


def r_integration(doc, zone):
    t = zone.show
    out = []
    for b in doc["branches"]:
        out.append(f"## {b['repository']} `{b['branch']}`")
        out.append("")
        if b.get("problem"):
            out.append(f"Problem: {b['problem']}")
            out.append("")
            continue
        h = b["head"]
        out.append(f"Head {short(h['hash'])} {t(h['time'])} {h['subject']}. First-parent history since "
                   f"{t(b.get('since'))}: {len(b.get('history', []))} commits.")
        out.append("")
        for c in b.get("history", []):
            m = c.get("merge")
            st = c.get("stat") or {}
            line = f"- {short(c['hash'])} {t(c['time'])} {c['subject']}"
            out.append(line)
            if m:
                out.append(f"  - merged {short(m['tip'])}; branch {m.get('branch', '?')}"
                           + (f" at {short(m.get('branchHead'))}, {m.get('commitsPastMerge')} commits past the merge"
                              if m.get("branchHead") else "")
                           + f"; worktree {m.get('worktree', '?')}"
                           + (f" ({', '.join(m['worktreePaths'])})" if m.get("worktreePaths") else ""))
            if st:
                s_, r_ = st["sources"], st["rest"]
                out.append(f"  - Sources/ and Package.swift: {s_['files']} files +{s_['added']} −{s_['deleted']}; "
                           f"the rest: {r_['files']} files +{r_['added']} −{r_['deleted']}")
                for f in s_["list"]:
                    out.append(f"    - {f['status']} `{f['path']}` +{f.get('added')} −{f.get('deleted')}")
                for f in r_["list"]:
                    out.append(f"    - {f['status']} `{f['path']}` +{f.get('added')} −{f.get('deleted')} (rest)")
            out.append(f"  - Close logs ({b['logPrefix']}-<commit>-*.log): "
                       + (", ".join(f"`{x}`" for x in c.get("closeLogs", [])) or "none")
                       + ("; other logs naming it: " + ", ".join(f"`{x}`" for x in c["otherLogs"])
                          if c.get("otherLogs") else ""))
        out.append("")
        ll = b.get("lastLogged")
        if ll:
            out.append(f"Last first-parent commit with a `{b['logPrefix']}-<commit>` log: {short(ll['hash'])} "
                       f"{t(ll['time'])} {ll['subject']} ({', '.join(ll['logs'])}); "
                       f"{ll['firstParentCommitsSince']} first-parent commits since:")
            out += [f"- {short(c['hash'])} {c['subject']}" + (" (touches Sources/ or Package.swift)"
                                                               if c["touchesSources"] else "") for c in ll["since"]]
        elif "lastLogged" in b:
            out.append(f"No first-parent commit has a `{b['logPrefix']}-<commit>` log.")
        out.append("")
        if b.get("cmake"):
            cm = b["cmake"]
            if cm.get("problem"):
                out.append(f"CMake list check: {cm['problem']}")
            else:
                out.append(f"CMake list check at the head: {cm['checked']} files, "
                           + (f"MISSING: {', '.join(cm['missing'])}" if cm["missing"] else "none missing") + ".")
            out.append("")
    return out


def r_status(doc, zone):
    t = zone.show
    out = []
    if doc.get("problem") and not doc.get("gaps"):
        return [f"Problem: {doc['problem']}"]
    lc = doc.get("lastChange") or {}
    out.append(f"`{doc.get('file')}` on system-next, {doc.get('size')} bytes; last changed by "
               f"{short(lc.get('hash'))} {t(lc.get('time'))} {lc.get('subject', '')}.")
    out.append("")
    if doc.get("floor"):
        out.append("Sites left by platform: " + ", ".join(f"{k} {v}" for k, v in doc["floor"].items()) + ".")
        out.append("")
    if doc.get("categories"):
        out.append("Ledger categories: " + ", ".join(f"{c['category']} {c['sites']}" for c in doc["categories"]) + ".")
        out.append("")
    s = doc.get("sums") or {}
    if s:
        out.append("## Sums of the gap table")
        out.append("")
        rows = [(p, v["rows"], v["unblocks"], v["holds"]) for p, v in s["byPlatform"].items()]
        rows += [("(lacking only Windows)", s["windowsOnly"]["rows"], s["windowsOnly"]["unblocks"],
                  s["windowsOnly"]["holds"]),
                 ("(lacking a platform other than Windows)", s["lackingAnotherPlatform"]["rows"],
                  s["lackingAnotherPlatform"]["unblocks"], s["lackingAnotherPlatform"]["holds"]),
                 ("(every row)", s["total"]["rows"], s["total"]["unblocks"], s["total"]["holds"])]
        out += table(["Platform lacking", "Rows", "Unblocks", "Holds"], rows)
        out.append("")
    out.append("## Section 5's gap table")
    out.append("")
    out += table(["#", "Gap", "Lacks", "Unblocks", "Files", "Holds", "Repositories", "C names", "System"],
                 [(g["rank"], g["gap"], ", ".join(g["lacks"]), g["unblocks"], g["unblocksFiles"], g["holds"],
                   ", ".join(g["repositories"]), g["cNames"], g["system"]) for g in doc.get("gaps", [])])
    return out


def r_lint(doc, zone):
    out = []
    if doc.get("problem"):
        out.append(f"Problem: {doc['problem']}")
        out.append("")
    out.append(f"At system-next's head {short(doc.get('head'))}, from a scratch checkout of it.")
    out.append("")
    if doc.get("xcrun") is False:
        out.append("No `xcrun` here: lint's conditionals check reads the macOS SDK's Swift interfaces through it "
                   "(`ledger.swift_declared_names`), so here it runs without their names, and can find more.")
        out.append("")
    s = doc.get("system")
    if s:
        out.append("## System: cmake, pitches, api")
        out.append("")
        out.append(f"`{s['command']}`: exit {s['exit']}")
        out.append("")
        out += [f"- {x}" for x in s.get("stderr", [])]
        out.append("")
        for f in s.get("failed", []):
            out.append(f"- **{f['check']} didn't run**: {f['why']}")
        if s.get("failed"):
            out.append("")
        if s.get("findings"):
            out += table(["File", "Line", "Rule", "Level", "Message"],
                         [(f["file"], f["line"], f["rule"], f["level"], f["message"]) for f in s["findings"]])
            out.append("")
    a = doc.get("adopters")
    if a:
        out.append("## Adopters: markers and conditionals, each clone at its newest migration branch")
        out.append("")
        for k, r in (a.get("runs") or {}).items():
            out.append(f"- `{r['command']}`: exit {r['exit']}; " + (r["stderr"][-1] if r["stderr"] else ""))
        out.append("")
        rows = []
        for c in a["clones"]:
            for check in ("markers", "conditionals"):
                item = c.get(check)
                if item is None:
                    continue
                rows.append((c["clone"], check, ", ".join(f"{k} {v}" for k, v in sorted(item["counts"].items()))
                             or "none", " / ".join(item["notes"])))
        out += table(["Clone", "Check", "Findings", "Notes"], rows)
        out.append("")
        for c in a["clones"]:
            fs = [(check, f) for check in ("markers", "conditionals") for f in (c.get(check) or {}).get("findings", [])]
            if not fs:
                continue
            out.append(f"### {c['clone']}")
            out.append("")
            out += table(["File", "Line", "Rule", "Message"],
                         [(f["file"], f["line"], f["rule"], f["message"]) for _, f in fs])
            out.append("")
    return out


def r_previous(doc, zone):
    t = zone.show
    out = [f"Compared with the snapshot of {t(doc.get('previous'), True)}.", ""]

    def block(title, rows, headers):
        out.append(f"## {title}: {len(rows)}")
        out.append("")
        if rows:
            out.extend(table(headers, rows))
            out.append("")
    block("Lanes appeared", [(n,) for n in doc["lanesAppeared"]], ["Lane"])
    block("Lanes vanished", [(n,) for n in doc["lanesVanished"]], ["Lane"])
    block("Worktrees removed", [(r["lane"], r["now"]) for r in doc["worktreesRemoved"]], ["Lane", "Now"])
    block("Heads moved", [(m["lane"], short(m["was"]), short(m["now"]), m.get("relation", ""), m.get("commits", ""))
                          for m in doc["headsMoved"]], ["Lane", "Was", "Now", "Relation", "Commits"])
    block("Lane fields changed", [(c["lane"], k, json.dumps(v["was"], ensure_ascii=False),
                                   json.dumps(v["now"], ensure_ascii=False))
                                  for c in doc["laneFields"] for k, v in c["fields"].items()],
          ["Lane", "Field", "Was", "Now"])
    block("Branches", [(b["repository"], b["kind"], b["branch"], b["change"],
                        short(b.get("was") or b.get("head")), short(b.get("now")))
                       for b in doc["branches"]], ["Repository", "Kind", "Branch", "Change", "Was", "Now"])
    block("Integration branches moved", [(i["repository"], i["branch"], short(i["was"]), short(i["now"]),
                                          "; ".join(f"{short(c['hash'])} {c['subject']}" for c in i["newFirstParent"]))
                                         for i in doc["integration"]],
          ["Repository", "Branch", "Was", "Now", "New first-parent commits"])
    block("New Linux logs", [(x["file"], t(x["modified"]), "; ".join(x["summary"])) for x in doc["logsNew"]],
          ["Log", "Modified", "Totals"])
    block("Linux logs changed", [(x["file"], x["was"]["size"], x["now"]["size"], t(x["now"]["modified"]))
                                 for x in doc["logsChanged"]], ["Log", "Size was", "Size now", "Modified"])
    block("Linux logs gone", [(f,) for f in doc["logsGone"]], ["Log"])
    block("Reports", [(r["lane"], r["path"], r["change"],
                       f"{(r.get('was') or {}).get('size', '')} → {(r.get('now') or {}).get('size', r.get('size', ''))}",
                       "; ".join(r.get("headingsAdded", [])), "; ".join(r.get("headingsRemoved", [])),
                       "yes" if r.get("resumeChanged") else "")
                      for r in doc["reports"]],
          ["Lane", "Report", "Change", "Size", "Headings added", "Headings removed", "Resume changed"])
    block("Lock files new", [(x["repository"], x["path"]) for x in doc["locksNew"]], ["Repository", "File"])
    block("Lock files gone", [(x["repository"], x["path"]) for x in doc["locksGone"]], ["Repository", "File"])
    out.append(f"STATUS.md: " + (f"{short(doc['statusMd']['was'])} → {short(doc['statusMd']['now'])}"
                                 if doc.get("statusMd") else "unchanged"))
    out.append("")
    block("lint counts", [(x["where"], x["rule"], x["was"], x["now"]) for x in doc["lint"]],
          ["Where", "Rule", "Was", "Now"])
    return out


RENDER = {"environment": r_environment, "lanes": r_lanes, "branches": r_branches, "commits": r_commits,
          "changed-files": r_changed, "git-state": r_state, "trial-merges": r_trial, "names": r_names,
          "activity": r_activity, "reports": r_reports, "linux-logs": r_logs, "integration": r_integration,
          "status": r_status, "lint": r_lint, "since-previous": r_previous}


def describe(name, doc):
    """The index's one line for a section."""
    if name == "environment":
        du = (doc.get("du") or {}).get("du")
        p = doc.get("paths") or {}
        m = len(p.get("worktreePaths", [])) + len(p.get("gitDirs", []))
        return (f"{doc.get('git')}, trial merges {doc.get('trialMerges')}; {doc.get('freeGiB')} GiB free; "
                f"linux-logs {du.split()[0] if du else '(du skipped)'}; {m} path mappings, "
                f"{len(p.get('failed', []))} failed; checks not run here, with commands")
    if name == "lanes":
        c = collections.Counter(x["kind"] for x in doc["lanes"])
        return (f"{len(doc['lanes'])} lanes ({', '.join(f'{v} {k}' for k, v in c.items())}): branch, head, base, "
                f"ahead/behind, uncommitted, in progress, conflicts, newest write, report, Linux log, session")
    if name == "branches":
        n = sum(len(r.get("local", [])) for r in doc["repositories"])
        m = sum(len(r.get("remote", [])) for r in doc["repositories"])
        return f"{len(doc['repositories'])} repositories: {n} local branches with worktrees, {m} remote-tracking"
    if name == "commits":
        n = sum(len(x["commits"]) for x in doc["lanes"])
        new = sum(x.get("newCommits", 0) for x in doc["lanes"])
        return f"{n} commits across {len(doc['lanes'])} lanes since their bases ({new} since --since)"
    if name == "changed-files":
        n = sum(len(x["files"]) for x in doc["lanes"])
        return f"{n} files changed since the merge bases, by lane, with a diffstat by top-level directory"
    if name == "git-state":
        u = sum(len(x["uncommitted"]) for x in doc["lanes"])
        ip = sum(1 for x in doc["lanes"] if x["inProgress"])
        cm = sum(len(x["conflictMarkers"]) for x in doc["lanes"])
        lk = sum(len(r["locks"]) for r in doc["repositories"])
        return (f"{u} uncommitted or untracked files, {ip} lanes mid-operation, {cm} files with conflict markers, "
                f"{lk} lock files")
    if name == "trial-merges":
        c = sum(1 for x in doc["lanes"] if x["files"])
        p = sum(len(g["pairs"]) for g in doc["pairs"])
        pc = sum(1 for g in doc["pairs"] for x in g["pairs"] if x.get("files"))
        return f"{len(doc['lanes'])} lanes against their bases ({c} conflict); {p} lane pairs ({pc} conflict)"
    if name == "names":
        d = sum(len(g["duplicates"]) for g in doc["groups"])
        pn = sum(len(g["publicNames"]) for g in doc["groups"])
        ci = sum(len(ln.get("clashesWithIntegration", [])) for g in doc["groups"] for ln in g["lanes"])
        return (f"{d} declarations added by two lanes, {pn} public names, {ci} also added by the integration branch, "
                f"over {sum(len(g['lanes']) for g in doc['groups'])} lanes")
    if name == "activity":
        pa = sum(1 for a in doc["lanes"] if a.get("partial"))
        return f"newest writes in {len(doc['lanes'])} trees (.build and outside), workspaces' directories, sessions" + (
            f"; {pa} partial" if pa else "")
    if name == "reports":
        n = sum(len(x["reports"]) for x in doc["lanes"])
        h = sum(len(r.get("hashes", [])) for x in doc["lanes"] for r in x["reports"])
        return f"{n} reports: outline, Resume here, {h} commit hashes checked"
    if name == "linux-logs":
        newest = doc["logs"][0]["file"] if doc["logs"] else "none"
        return f"{len(doc['logs'])} logs, newest {newest}: lane, commit, totals, error lines, exit status"
    if name == "integration":
        parts = []
        for b in doc["branches"]:
            if b.get("head"):
                merges = sum(1 for c in b.get("history", []) if c.get("merge"))
                ll = b.get("lastLogged")
                parts.append(f"{b['branch']} {b['head']['hash'][:7]}: {merges} merges since --since, last logged "
                             f"{ll['hash'][:7] if ll else 'none'}"
                             + (f", {ll['firstParentCommitsSince']} commits since" if ll else ""))
        cm = next((b["cmake"] for b in doc["branches"] if b.get("cmake")), None)
        if cm and "missing" in cm:
            parts.append(f"CMake list: {len(cm['missing'])} missing")
        return "; ".join(parts)
    if name == "status":
        lc = doc.get("lastChange") or {}
        s = (doc.get("sums") or {}).get("total") or {}
        return (f"STATUS.md at {lc.get('hash', '')[:7]}: {len(doc.get('gaps', []))} gap rows ({s.get('unblocks', 0)} "
                f"sites unblocked), sums by platform, ledger categories")
    if name == "lint":
        s = doc.get("system") or {}
        a = doc.get("adopters") or {}
        n = sum(len((c.get(k) or {}).get("findings", [])) for c in a.get("clones", []) for k in ("markers",
                                                                                                "conditionals"))
        failed = ", ".join(f["check"] for f in s.get("failed", []))
        return (f"System {len(s.get('findings', []))} findings" + (f" ({failed} didn't run)" if failed else "")
                + f"; adopters {n} findings over {len(a.get('clones', []))} clones")
    if name == "since-previous":
        return (f"vs {doc.get('previous')}: {len(doc['headsMoved'])} heads moved, {len(doc['lanesAppeared'])} lanes "
                f"appeared, {len(doc['lanesVanished'])} vanished, {len(doc['logsNew'])} new logs, "
                f"{len(doc['reports'])} reports changed")
    return ""


# ---------------------------------------------------------------- the run

NEEDS = {
    "environment": set(),
    "lanes": {"lanes", "activity"},
    "branches": {"repos"},
    "commits": {"lanes"},
    "changed-files": {"lanes"},
    "git-state": {"lanes", "repos"},
    "trial-merges": {"lanes", "pairs"},
    "names": {"lanes", "names"},
    "activity": {"activity"},
    "reports": {"lanes", "elsewhere"},
    "linux-logs": {"logs"},
    "integration": {"integration"},
    "status": {"status"},
    "lint": {"lint"},
}


def parse_since(run, text):
    """A time from --since, in any form git's --since takes."""
    path = os.path.join(run.root, "swift-system")
    if os.path.isdir(os.path.join(path, ".git")):
        try:
            code, out, _ = sh(["git", "-C", path, "rev-parse", f"--since={text}"], 20)
            m = re.match(r"--max-age=(\d+)", out.strip())
            if code == 0 and m:
                return float(m.group(1))
        except L.Slow:
            pass
    try:
        return datetime.datetime.fromisoformat(text).timestamp()
    except ValueError:
        raise Usage(f"--since {text!r}: not a time git or ISO 8601 reads")


def check_out_dir(run, section_only):
    out = run.out
    if out == run.root or out.startswith(run.root + os.sep) or os.path.realpath(out).startswith(run.root + os.sep):
        raise Usage(f"--out {out} is inside the folder read ({run.root}); give a directory outside it")
    if section_only:
        return None
    if os.path.isdir(out):
        entries = [e for e in os.listdir(out) if not e.startswith(".scratch-")]
        prev = load_previous(out)
        if entries and prev is None:
            raise Usage(f"--out {out} holds files but no snapshot (index.json); give an empty or new directory")
        return prev
    return None


def run_snapshot(args, stdout=sys.stdout):
    """Takes the snapshot (or one section); returns the exit status."""
    run = Run(args)
    section_only = args.section
    if section_only and section_only not in NEEDS:
        raise Usage(f"--section {section_only}: one of {', '.join(NEEDS)}"
                    + ("; since-previous needs a whole snapshot" if section_only == "since-previous" else ""))
    prev = check_out_dir(run, section_only)
    if args.since:
        run.since, since_from = parse_since(run, args.since), "--since"
    elif prev and prev["index"].get("generated"):
        run.since, since_from = epoch(prev["index"]["generated"]), "the previous snapshot's time"
    else:
        run.since, since_from = run.start - 7 * 86400, "7 days before this run"
    os.makedirs(run.out, exist_ok=True)
    run.scratch = os.path.join(run.out, f".scratch-{os.getpid()}")
    os.makedirs(run.scratch, exist_ok=True)
    old_tempdir = tempfile.tempdir
    tempfile.tempdir = run.scratch
    try:
        return collect_and_write(run, args, section_only, prev, since_from, stdout)
    finally:
        run.copies.close()
        tempfile.tempdir = old_tempdir
        shutil.rmtree(run.scratch, ignore_errors=True)


SECTION_OF = {"lane": "lanes", "repo": "branches", "logs": "linux-logs", "env": "environment", "du": "environment",
              "pairs": "trial-merges", "elsewhere": "reports"}


def collect_and_write(run, args, section_only, prev, since_from, stdout):
    if section_only:
        want = set(NEEDS[section_only]) | ({"env", "du"} if section_only == "environment" else set())
    else:
        want = set().union(*NEEDS.values()) | {"env", "du"}
    t0 = time.time()
    discovery = L.discover(run.root, run.timeout)
    run.timed("discovery", t0)
    all_lanes = discovery["lanes"]
    lanes = [x for x in all_lanes if run.selected(x["name"])]
    packages = sorted({x["package"] for x in all_lanes if x.get("package")})
    run.log_list = list_logs(run, packages)
    skips, results, futures, reported = [], {}, {}, set()
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs))

    def submit(key, fn, *a):
        futures[pool.submit(fn, *a)] = key

    if "activity" in want:
        submit(("activity",), activity_task, run, [x for x in lanes if x.get("path") and os.path.isdir(x["path"])],
               max(2, args.jobs))
    if "lint" in want:
        submit(("lint",), lint_task, run, [x["path"] for x in lanes if x["kind"] == "adopter"])
    if "env" in want:
        submit(("env",), environment_task, run, discovery)
    if "integration" in want:
        for repo, branch, prefix in INTEGRATIONS:
            submit(("integration", repo), integration_task, run, repo, branch, prefix, lanes)
    if "status" in want:
        submit(("status",), status_task, run)
    lane_keys = []
    if want & {"lanes", "pairs", "names", "elsewhere"}:
        for x in lanes:
            submit(("lane", x["name"]), lane_task, run, x)
            lane_keys.append(x["name"])
    if "repos" in want:
        for repo, path in repositories(run, lanes):
            submit(("repo", repo), repo_task, run, repo, path)
    if "logs" in want:
        submit(("logs",), logs_task, run, [dict(x) for x in run.log_list], lanes)
    if "du" in want:
        submit(("du",), du_task, run)

    def wait(fs):
        left = run.left()
        done, not_done = concurrent.futures.wait(fs, timeout=None if left is None else max(0.0, left) + 5.0)
        for f in done:
            if f in reported:
                continue
            reported.add(f)
            key = futures[f]
            try:
                value, sk = f.result()
            except Exception as e:  # a bug in one part shouldn't lose the others
                value, sk = None, [run.skip(SECTION_OF.get(key[0], key[0]), " ".join(map(str, key)),
                                            f"failed: {type(e).__name__}: {e}")]
            results[key] = value
            skips.extend(sk)
        for f in not_done:
            if f in reported:
                continue
            reported.add(f)
            key = futures[f]
            skips.append(run.skip(SECTION_OF.get(key[0], key[0]), " ".join(map(str, key)),
                                  "still running at the deadline",
                                  lane=key[1] if len(key) > 1 and key[0] in ("lane", "activity") else None))

    if want & {"pairs", "names", "elsewhere"}:
        wait([f for f, k in futures.items() if k[0] == "lane"])
        done_lanes = [results[("lane", n)] for n in lane_keys if results.get(("lane", n))]
        for key, members in groups(done_lanes).items():
            if "pairs" in want and len(members) > 1:
                submit(("pairs",) + key, pairs_task, run, key, members)
            if "names" in want:
                submit(("names",) + key, names_task, run, key, members)
        if "elsewhere" in want:
            tokens = unresolved_hashes(done_lanes)
            if tokens:
                for repo, path in report_repositories(run):
                    submit(("elsewhere", repo), elsewhere_task, run, repo, path, tokens)
    wait([f for f in futures if f not in reported])
    try:
        pool.shutdown(wait=False, cancel_futures=True)
    except TypeError:  # Python before 3.9
        pool.shutdown(wait=False)
    lane_list = []
    for x in lanes:
        got = results.get(("lane", x["name"]))
        lane_list.append(got if got else dict(x, skipped=x.get("skipped") or "not read"))
    apply_elsewhere(lane_list, [v for k, v in results.items() if k[0] == "elsewhere"])
    activity = results.get(("activity",)) or {"lanes": []}
    acts = activity["lanes"]
    repos = [results[("repo", r)] for r, _ in repositories(run, lanes) if results.get(("repo", r))]
    integ = [results[("integration", r)] for r, _, _ in INTEGRATIONS if results.get(("integration", r))]
    logs = results.get(("logs",)) or run.log_list
    pair_results = [v for k, v in results.items() if k[0] == "pairs" and v]
    name_results = [v for k, v in results.items() if k[0] == "names" and v]
    env = results.get(("env",)) or {"root": run.root}
    sec = build(run, discovery, lane_list, acts, repos, logs, integ, results.get(("status",)),
                results.get(("lint",)), pair_results, name_results, env, results.get(("du",)), skips)
    seconds = round(time.time() - run.start, 1)
    sec["environment"].update(seconds=seconds, deadline=run.deadline, timings=dict(run.timings))
    meta = {"tool": TOOL, "format": FORMAT, "root": run.root, "generated": iso(run.start), "zone": run.zone.label,
            "since": iso(run.since), "sinceFrom": since_from, "seconds": seconds, "deadline": run.deadline,
            "only": run.only, "skipped": skips, "git": sec["environment"].get("git"),
            "trialMerges": sec["environment"].get("trialMerges")}
    if section_only:
        doc = dict(sec[section_only], section=section_only, **{k: v for k, v in meta.items() if k != "skipped"})
        doc["skipped"] = [x for x in skips if x["section"] == section_only]
        if args.json:
            json.dump(doc, stdout, indent=1, ensure_ascii=False)
            stdout.write("\n")
        else:
            stdout.write(md_section(section_only, sec[section_only], meta, run.zone))
        return 0
    if prev:
        try:
            sec["since-previous"] = diff_previous(run, prev, sec, lane_list)
        except Exception as e:  # an earlier snapshot of another shape
            sec["since-previous"] = dict(EMPTY_DIFF, previous=prev["index"].get("generated"),
                                         problem=f"{type(e).__name__}: {e}")
    write_snapshot(run, sec, meta, stdout)
    return 0


EMPTY_DIFF = {"lanesAppeared": [], "lanesVanished": [], "worktreesRemoved": [], "headsMoved": [], "laneFields": [],
              "branches": [], "integration": [], "logsNew": [], "logsGone": [], "logsChanged": [], "reports": [],
              "locksNew": [], "locksGone": [], "statusMd": None, "lint": []}


def write_file(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def write_snapshot(run, sec, meta, stdout):
    entries = []
    for name in SECTION_NAMES:
        if name not in sec:
            continue
        doc = dict(sec[name], section=name, **{k: v for k, v in meta.items() if k != "skipped"})
        doc["skipped"] = [s for s in meta["skipped"] if s["section"] == name]
        jtext = json.dumps(doc, indent=1, ensure_ascii=False) + "\n"
        mtext = md_section(name, sec[name], meta, run.zone)
        write_file(os.path.join(run.out, f"{name}.json"), jtext)
        write_file(os.path.join(run.out, f"{name}.md"), mtext)
        entries.append({"section": name, "markdown": f"{name}.md", "markdownBytes": len(mtext.encode()),
                        "json": f"{name}.json", "jsonBytes": len(jtext.encode()), "what": describe(name, sec[name]),
                        "complete": not doc["skipped"]})
    index = dict(meta, out=run.out, sections=entries, paths=sec["environment"].get("paths"))
    text = index_markdown(run, index, sec)
    write_file(os.path.join(run.out, "index.json"), json.dumps(index, indent=1, ensure_ascii=False) + "\n")
    write_file(os.path.join(run.out, "index.md"), text)
    stdout.write(text)


def size(n):
    return f"{n} B" if n < 1024 else (f"{n / 1024:.1f} KB" if n < 1 << 20 else f"{n / (1 << 20):.1f} MB")


def index_markdown(run, index, sec):
    z = run.zone
    total = sum(e["markdownBytes"] + e["jsonBytes"] for e in index["sections"])
    out = [f"# Snapshot index",
           "",
           f"Snapshot of `{index['root']}` at {z.show(index['generated'], True)}, {z.label}; {index['seconds']} s "
           f"(deadline {index['deadline']} s). Since {z.show(index['since'])} ({index['sinceFrom']}). "
           f"{index['git']}; trial merges: {index['trialMerges']}. Written to `{index['out']}`, {size(total)} in all."]
    p = index.get("paths") or {}
    n_map = len(p.get("worktreePaths", [])) + len(p.get("gitDirs", []))
    if n_map or p.get("failed"):
        out.append(f"Paths: recorded under `{p.get('hostRoot')}`, seen under `{index['root']}`: {n_map} mapped "
                   f"({len(p.get('worktreePaths', []))} worktree paths, {len(p.get('gitDirs', []))} git directories), "
                   f"{len(p.get('failed', []))} failed" + (": " + ", ".join(f"`{f['lane']}`" for f in p["failed"])
                                                           if p.get("failed") else "") + ".")
    else:
        out.append("Paths: as recorded; no mapping was needed.")
    if index.get("only"):
        out.append(f"Only: {', '.join(index['only'])}.")
    out.append("")
    out += table(["Section", "Markdown", "JSON", "What it holds"],
                 [(e["section"] + ("" if e["complete"] else " (incomplete)"),
                   f"{e['markdown']} {size(e['markdownBytes'])}", f"{e['json']} {size(e['jsonBytes'])}", e["what"])
                  for e in index["sections"]])
    out.append("")
    if index["skipped"]:
        out.append(f"Skipped ({len(index['skipped'])}), each with the command that gets it alone:")
        out.append("")
        for s in index["skipped"]:
            out.append(f"- {s['section']}: {s['part']}: {s['why']}" + (f" ({s['progress']})" if s.get("progress")
                                                                        else "") + f". `{s['command']}`")
        out.append("")
    else:
        out.append("Nothing was skipped.")
        out.append("")
    return "\n".join(out)


def parse_args(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    default_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(here))))
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", required=True, help="the directory to write the snapshot to (outside the folder read)")
    ap.add_argument("--since", help="the start of the history read (any form git's --since takes; default: the "
                                    "previous snapshot's time, else 7 days ago)")
    ap.add_argument("--section", help="compute and print only this section; nothing is written to --out")
    ap.add_argument("--json", action="store_true", help="with --section: print JSON")
    ap.add_argument("--root", help="the folder that holds swift-system, its worktrees and the adopters")
    ap.add_argument("--claude", help="Claude Code's directory (default ~/.claude)")
    ap.add_argument("--only", nargs="*", help="lanes to read, by name or shell glob")
    ap.add_argument("--deadline", type=float, default=85, help="seconds after which unfinished parts are skipped "
                                                               "(0: none)")
    ap.add_argument("--timeout", type=float, default=30, help="seconds for one git call")
    ap.add_argument("--jobs", type=int, default=8)
    args = ap.parse_args(argv)
    args.root_given = args.root is not None
    if args.root is None:
        args.root = default_root
    return args


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    args = parse_args(argv)
    try:
        status = run_snapshot(args)
    except Usage as e:
        print(f"snapshot: {e}", file=sys.stderr)
        status = 2
    sys.stdout.flush()
    sys.stderr.flush()
    # Daemon-free worker threads still blocked in a slow file system call
    # would hold up interpreter exit; everything is written by now.
    os._exit(status)


if __name__ == "__main__":
    main()
