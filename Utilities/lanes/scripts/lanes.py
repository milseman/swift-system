#!/usr/bin/env python3
"""The state of every lane: each worktree of swift-system and of
swift-system-examples, each adopter clone in ../adopters and worktree in
../adopters-unix, and the adopter workspaces themselves, read-only.

A lane is whatever exists: nothing about lanes is configured here. For each
one, from git (every call with --no-optional-locks and lazy fetching off):
its branch, head commit and time, commits ahead of and behind its
integration branch (system-next for swift-system, main for the examples,
origin/main for a swift-system worktree on a `pitch/` branch; an
adopter's branch has no recorded base, so its last commit time stands
in), uncommitted files, a merge, rebase or cherry-pick in progress, and a
trial merge's conflicts against the integration branch (`git merge-tree`,
its objects written to a temporary directory, never the repository's).
From the file system: the newest report it owns (a REPORT*.md, *-REPORT.md
or Prototype/*/REPORT.md that its branch or working tree changed; for an
adopter, any in its working tree), with the first line under "Resume here";
the newest log in ../linux-logs named for it, with its test totals; and the
newest transcript of a Claude Code session in it.

A worktree's recorded path can differ from where it's seen, as when the
folder is mounted elsewhere: its `.git` file then names a directory that
doesn't exist, and its git directory is found under the main clone's by
the path's last components.

Usage: lanes.py [--json] [--root DIR] [--claude DIR] [--timeout SECONDS]
                [--deadline SECONDS] [--no-merge-tree] [--only NAME...]
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import concurrent.futures  # noqa: E402
import datetime  # noqa: E402
import fnmatch  # noqa: E402
import glob  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import threading  # noqa: E402
import time  # noqa: E402

REPOS = (("swift-system", "system", "system-next"), ("swift-system-examples", "examples", "main"))
PITCH_PREFIX = "pitch/"
ADOPTER_DIRS = (("adopters", "adopter"), ("adopters-unix", "adopter worktree"))
REPORT_NAMES = ("REPORT*.md", "*-REPORT.md")
REPORT_PATHS = ("Prototype/*/REPORT.md",)
RESUME = re.compile(r"^\s*(?:#+\s*|\*\*)?resume here\b[*:.\s]*(.*)$", re.I)
TESTS = re.compile(r"^\s*(Executed \d+ tests?\b.*|.*Test run with \d+ tests?\b.*)$")
ENV = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", LC_ALL="C")


class Slow(Exception):
    pass


# ---------------------------------------------------------------- paths

def suffix_candidates(base, recorded):
    """Paths under base that end with the recorded path's last components,
    longest first: where a worktree recorded elsewhere is seen now."""
    parts = [p for p in recorded.split(os.sep) if p]
    return [os.path.join(base, *parts[-k:]) for k in range(len(parts), 0, -1)]


def locate(base, recorded, want=os.path.exists):
    """The recorded path if it exists, else the first candidate under base
    that does, resolved through symbolic links."""
    if want(recorded):
        return os.path.realpath(recorded)
    for c in suffix_candidates(base, recorded):
        if want(c):
            return os.path.realpath(c)
    return None


def gitdir_of(base, worktree):
    """(git directory, recorded gitdir) for a working tree: its `.git`
    directory, or the directory its `.git` file names, found under base
    when the recorded path is missing."""
    dot = os.path.join(worktree, ".git")
    if os.path.isdir(dot):
        return dot, None
    if not os.path.isfile(dot):
        return None, None
    with open(dot, encoding="utf-8", errors="replace") as f:
        line = f.read().strip()
    if not line.startswith("gitdir:"):
        return None, None
    recorded = line[len("gitdir:"):].strip()
    if not os.path.isabs(recorded):
        recorded = os.path.normpath(os.path.join(worktree, recorded))
    return locate(base, recorded, lambda p: os.path.isfile(os.path.join(p, "HEAD"))), recorded


def claude_dir_name(path):
    """Claude Code's directory for a project at path, under
    ~/.claude/projects: every character but a letter or digit becomes `-`."""
    return re.sub(r"[^A-Za-z0-9]", "-", path)


# ---------------------------------------------------------------- git

class Git:
    """git on one working tree, with its git directory given, so a worktree
    whose `.git` file names a path that isn't here still works. Each call
    has a timeout, cut short by `deadline` (a time.time() value) if given."""

    def __init__(self, path, gitdir, timeout, deadline=None):
        self.path, self.gitdir, self.timeout, self.deadline = path, gitdir, timeout, deadline

    def __call__(self, *args, ok=(0,), env=None, input=None):
        cmd = ["git", "--no-optional-locks", "--git-dir", self.gitdir, "--work-tree", self.path, *args]
        timeout = self.timeout
        if self.deadline is not None:
            left = self.deadline - time.time()
            if left <= 0:
                raise Slow(f"past the deadline before git {args[0]}")
            timeout = min(timeout, left)
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, env=env or ENV, timeout=timeout,
                               cwd=self.path, input=input, errors="replace")
        except subprocess.TimeoutExpired:
            raise Slow(f"git {args[0]} took over {round(timeout, 1)} s")
        if p.returncode not in ok:
            raise RuntimeError(f"git {' '.join(args)}: {p.stderr.strip()[:300]}")
        return p

    def out(self, *args, ok=(0,)):
        return self(*args, ok=ok).stdout


def worktrees(main, base, timeout):
    """[(recorded path, path seen now or None, branch, head)] from a main
    clone's `git worktree list --porcelain`."""
    p = subprocess.run(["git", "--no-optional-locks", "-C", main, "worktree", "list", "--porcelain"],
                       capture_output=True, text=True, env=ENV, timeout=timeout)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip())
    out, cur = [], {}
    for line in p.stdout.split("\n") + [""]:
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
        seen = locate(base, recorded, lambda p: os.path.exists(os.path.join(p, ".git")))
        branch = w.get("branch", "")
        branch = branch[len("refs/heads/"):] if isinstance(branch, str) and branch.startswith("refs/heads/") else (
            "(detached)" if w.get("detached") else "")
        res.append((recorded, seen, branch, w.get("HEAD")))
    return res


def trial_conflicts(g, common, ours, theirs, copies=None):
    """(count, how): how many files trial_merge finds conflicting."""
    files, how = trial_merge(g, common, ours, theirs, copies)
    return len(files), how


_MODES = {}
_MODES_LOCK = threading.Lock()


def merge_tree_mode(g):
    """`write-tree` if this git's merge-tree has `--write-tree` (git 2.38 and
    later), else `trivial`: read from the usage it prints when given no
    commits, which writes nothing. Remembered for the PATH it ran with."""
    key = ENV.get("PATH")
    with _MODES_LOCK:
        if key in _MODES:
            return _MODES[key]
    p = g("merge-tree", "--write-tree", ok=(0, 1, 128, 129))
    text = p.stdout + p.stderr
    mode = "write-tree" if "[--write-tree]" in text and not NO_WRITE_TREE.search(text) else "trivial"
    with _MODES_LOCK:
        _MODES[key] = mode
    return mode


class ObjectCopies:
    """Copies of repositories' object stores in one temporary directory,
    each made the first time it's asked for. A trial merge runs with one as
    its object directory, so that what `merge-tree --write-tree` writes, and
    the times git updates on objects it finds it already has (it
    "freshens" them, even in an alternate), stay in the copy."""

    def __init__(self):
        self.dir, self.copies = None, {}
        self.lock = threading.Lock()

    def get(self, common):
        key = os.path.realpath(common)
        with self.lock:
            if key not in self.copies:
                if self.dir is None:
                    self.dir = tempfile.mkdtemp(prefix="lanes-objects-")
                dst = os.path.join(self.dir, str(len(self.copies)))
                copy_objects(os.path.join(common, "objects"), dst)
                self.copies[key] = dst
            return self.copies[key]

    def close(self):
        if self.dir:
            shutil.rmtree(self.dir, ignore_errors=True)
            self.dir = None


def copy_objects(src, dst):
    """A repository's loose objects and packs, copied (not linked: a link
    shares the file whose time git would update)."""
    os.makedirs(os.path.join(dst, "pack"))
    os.makedirs(os.path.join(dst, "info"))
    for d in os.listdir(src):
        p = os.path.join(src, d)
        if len(d) == 2 and os.path.isdir(p):
            os.makedirs(os.path.join(dst, d))
            for f in os.listdir(p):
                shutil.copyfile(os.path.join(p, f), os.path.join(dst, d, f))
    pack = os.path.join(src, "pack")
    if os.path.isdir(pack):
        for f in os.listdir(pack):
            if f.endswith((".pack", ".idx")):
                shutil.copyfile(os.path.join(pack, f), os.path.join(dst, "pack", f))


def trial_merge(g, common, ours, theirs, copies=None):
    """(files, how): the files `git merge-tree` finds conflicting in a merge
    of theirs into ours, sorted, and how they were found. `write-tree` is
    git's own list (`--write-tree`, git 2.38 and later), run with a copy of
    the repository's objects as its object directory (copies, an
    ObjectCopies; a temporary one when it's None), so nothing it writes or
    touches is the repository's. With a git too old for it, the
    three-argument form, the trivial merge, is used instead (`trivial`),
    which writes nothing: see trivial_conflict_files."""
    if merge_tree_mode(g) == "write-tree":
        own = copies is None
        copies = copies or ObjectCopies()
        try:
            env = dict(ENV, GIT_OBJECT_DIRECTORY=copies.get(common))
            env.pop("GIT_ALTERNATE_OBJECT_DIRECTORIES", None)
            info = os.path.join(common, "objects", "info", "alternates")
            if os.path.isfile(info):
                with open(info) as f:
                    env["GIT_ALTERNATE_OBJECT_DIRECTORIES"] = os.pathsep.join(
                        a.strip() for a in f if a.strip() and not a.startswith("#"))
            p = g("merge-tree", "--write-tree", "--name-only", "--no-messages", "-z", ours, theirs,
                  ok=(0, 1, 128), env=env)
            if p.returncode in (0, 1):
                files = [x for x in p.stdout.split("\0")[1:] if x.strip()]
                return (sorted(set(files)) if p.returncode == 1 else []), "write-tree"
            raise RuntimeError(f"git merge-tree --write-tree: {p.stderr.strip()[:300]}")
        finally:
            if own:
                copies.close()
    base = g.out("merge-base", ours, theirs, ok=(0, 1)).strip()
    if not base:
        raise RuntimeError(f"no merge base of {ours} and {theirs} for a trial merge")
    return trivial_conflict_files(g.out("merge-tree", base, ours, theirs)), "trivial"


# What a git without `merge-tree --write-tree` says: its usage, which names
# only the three-argument form, or an unknown option.
NO_WRITE_TREE = re.compile(r"usage: git merge-tree <base-tree>|unknown option|unrecognized argument", re.I)
TRIVIAL_SECTION = re.compile(r"^(changed in both|added in both|removed in local|removed in remote|added in local|"
                             r"added in remote|merged)$")
TRIVIAL_ENTRY = re.compile(r"^  (base|our|their) +\d+ ([0-9a-f]+) (.+)$")


def trivial_conflicts(text):
    """How many files trivial_conflict_files finds."""
    return len(trivial_conflict_files(text))


def trivial_conflict_files(text):
    """The files a trivial merge's output (`git merge-tree BASE OURS
    THEIRS`) conflicts in, sorted: those whose merged text has git's
    conflict markers (`+<<<<<<< .our`), and those one side removed and the
    other changed. It can't follow renames, so a conflict that
    `--write-tree` finds through one is missed."""
    files = set()
    section, entries, in_diff = None, {}, False

    def close():
        if section in ("removed in local", "removed in remote"):
            kept = entries.get("their" if section == "removed in local" else "our")
            if kept and entries.get("base") and kept[0] != entries["base"][0]:
                files.add(kept[1])

    for line in text.split("\n"):
        if TRIVIAL_SECTION.match(line):
            close()
            section, entries, in_diff = line, {}, False
            continue
        if section is None:
            continue
        if line.startswith("@@"):
            in_diff = True
            continue
        m = TRIVIAL_ENTRY.match(line) if not in_diff else None
        if m:
            entries[m.group(1)] = (m.group(2), m.group(3))
        elif in_diff and line.rstrip() == "+<<<<<<< .our" and entries:
            files.add(next(iter(entries.values()))[1])
    close()
    return sorted(files)


# ---------------------------------------------------------------- reports, logs, sessions

def is_report(rel):
    name = os.path.basename(rel)
    return any(fnmatch.fnmatchcase(name, p) for p in REPORT_NAMES) or \
        any(fnmatch.fnmatchcase(rel, p) for p in REPORT_PATHS)


def resume_line(path):
    """The first line under "Resume here", or None."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().split("\n")
    except OSError:
        return None
    for i, line in enumerate(lines):
        m = RESUME.match(line)
        if not m:
            continue
        rest = m.group(1).strip().strip("*").strip()
        if rest:
            return rest
        for nxt in lines[i + 1:i + 40]:
            if nxt.strip():
                return None if nxt.lstrip().startswith("#") else nxt.strip()
        return None
    return None


def newest_report(root, rels):
    best = None
    for rel in set(rels):
        p = os.path.join(root, rel)
        try:
            m = os.path.getmtime(p)
        except OSError:
            continue
        if best is None or m > best[1]:
            best = (rel, m)
    if not best:
        return None
    return {"file": best[0], "modified": stamp(best[1]), "resume": resume_line(os.path.join(root, best[0]))}


def tree_reports(root):
    rels = []
    for pat in REPORT_NAMES + REPORT_PATHS:
        rels += [os.path.relpath(p, root) for p in glob.glob(os.path.join(root, pat))]
    return rels


def linux_log(logs_dir, names, contains=()):
    """The newest log in ../linux-logs whose name starts with `<name>-` for
    one of the names, or has `-<contains>-` (an adopter's package), with its
    test totals."""
    if not os.path.isdir(logs_dir):
        return None
    best = None
    for f in os.listdir(logs_dir):
        if not f.endswith(".log"):
            continue
        if not (any(f.startswith(n + "-") for n in names) or any(f"-{c}-" in f for c in contains)):
            continue
        p = os.path.join(logs_dir, f)
        try:
            m = os.path.getmtime(p)
        except OSError:
            continue
        if best is None or m > best[1]:
            best = (f, m)
    if not best:
        return None
    executed = run_with = None
    try:
        with open(os.path.join(logs_dir, best[0]), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = TESTS.match(line)
                if m:
                    text = m.group(1).strip()
                    if text.startswith("Executed"):
                        executed = text
                    else:
                        run_with = text[text.index("Test run with"):]
    except OSError:
        pass
    return {"file": best[0], "modified": stamp(best[1]), "summary": [x for x in (executed, run_with) if x]}


def session(claude, host_path):
    """The newest transcript's time for a project path, "none", or
    "unknown" when ~/.claude can't be read."""
    if claude is None:
        return {"state": "unknown"}
    d = os.path.join(claude, "projects", claude_dir_name(host_path))
    if not os.path.isdir(d):
        return {"state": "none", "directory": os.path.basename(d)}
    newest = None
    for p in glob.glob(os.path.join(d, "*.jsonl")):
        try:
            m = os.path.getmtime(p)
        except OSError:
            continue
        newest = m if newest is None or m > newest else newest
    if newest is None:
        return {"state": "none", "directory": os.path.basename(d)}
    age = time.time() - newest
    return {"state": "active" if age < 15 * 60 else "idle", "modified": stamp(newest), "minutes": int(age // 60),
            "directory": os.path.basename(d), "mtime": newest}


def stamp(t):
    return datetime.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M")


# ---------------------------------------------------------------- one lane

def status_entries(text):
    """[{"status": XY, "path": p, "from": source or absent}] from
    `git status --porcelain=v1 -z`."""
    entries = [e for e in text.split("\0") if e]
    out = []
    i = 0
    while i < len(entries):
        e = entries[i]
        item = {"status": e[:2], "path": e[3:]}
        if e[:1] in ("R", "C") and i + 1 < len(entries):
            i += 1  # the rename's source follows
            item["from"] = entries[i]
        out.append(item)
        i += 1
    return out


IN_PROGRESS = (("MERGE_HEAD", "merge"), ("CHERRY_PICK_HEAD", "cherry-pick"), ("REVERT_HEAD", "revert"),
               ("rebase-merge", "rebase"), ("rebase-apply", "rebase"))


def git_lane(lane, base, args):
    """Fills a git lane's fields; raises Slow when a call times out."""
    path = lane["path"]
    gitdir, recorded_gitdir = gitdir_of(base, path)
    if not gitdir:
        lane["problem"] = (f"its .git names {recorded_gitdir}, which isn't here" if recorded_gitdir
                           else "no git directory")
        if recorded_gitdir:
            lane["recordedGitDir"] = recorded_gitdir
        return lane
    if recorded_gitdir and os.path.normpath(gitdir) != os.path.normpath(recorded_gitdir):
        lane["gitDir"] = gitdir
        lane["recordedGitDir"] = recorded_gitdir
    lane["gitDirUsed"] = gitdir
    g = Git(path, gitdir, args.timeout, getattr(args, "deadline_at", None))
    common = g.out("rev-parse", "--git-common-dir").strip()
    common = common if os.path.isabs(common) else os.path.normpath(os.path.join(path, common))
    lane["commonDir"] = common
    lane["branch"] = g.out("branch", "--show-current").strip() or "(detached)"
    head = g.out("log", "-1", "--format=%H%x00%cI%x00%s", ok=(0, 128)).strip().split("\0")
    if len(head) == 3:
        lane["head"], lane["headTime"], lane["subject"] = head[0], head[1], head[2]
    entries = status_entries(g.out("status", "--porcelain=v1", "-z", "--untracked-files=all"))
    changed = [e["path"] for e in entries]
    lane["uncommitted"] = len(entries)
    lane["uncommittedFiles"] = entries
    state = [name for f, name in IN_PROGRESS if os.path.exists(os.path.join(gitdir, f))]
    lane["inProgress"] = sorted(set(state))
    integration = lane.get("integration")
    owned = []
    if integration and lane.get("head"):
        ref = lane.get("integrationRef") or f"refs/heads/{integration}"
        base_ref = g.out("rev-parse", "--verify", "--quiet", ref, ok=(0, 1)).strip()
        if base_ref:
            lane["integrationHead"] = base_ref
            counts = g.out("rev-list", "--left-right", "--count", f"{base_ref}...HEAD").split()
            lane["behind"], lane["ahead"] = int(counts[0]), int(counts[1])
            if lane["ahead"] and lane["behind"] and not args.no_merge_tree:
                files, lane["conflictsBy"] = trial_merge(g, common, base_ref, "HEAD",
                                                         getattr(args, "object_copies", None))
                lane["conflicts"], lane["conflictFiles"] = len(files), files
            elif not args.no_merge_tree:
                lane["conflicts"], lane["conflictFiles"] = 0, []
            mb = g.out("merge-base", base_ref, "HEAD", ok=(0, 1)).strip()
            if mb:
                lane["mergeBase"] = mb
                owned = [x for x in g.out("diff", "--name-only", "-z", mb, "HEAD").split("\0") if x]
        else:
            lane["note"] = (f"no local {integration} branch" if ref == f"refs/heads/{integration}"
                            else f"no {ref} here")
    if integration:
        rels = [r for r in owned + changed if is_report(r)]
    else:
        rels = tree_reports(path) + [r for r in changed if is_report(r)]
    lane["ownedReports"] = sorted(set(rels))
    lane["report"] = newest_report(path, rels)
    return lane


def workspace_lane(lane):
    path = lane["path"]
    lane["ownedReports"] = sorted(set(tree_reports(path)))
    lane["report"] = newest_report(path, lane["ownedReports"])
    return lane


def discover(base, timeout):
    """Every lane under base, before any is read: {"lanes": [...], "notes":
    [...], "hostRoot": the path the lanes were recorded under, or None when
    it's base}. A swift-system worktree on a `pitch/` branch is a pitch lane,
    whose base is `origin/main`."""
    lanes, notes = [], []
    host_base = None
    for repo, kind, integration in REPOS:
        main = os.path.join(base, repo)
        if not os.path.isdir(os.path.join(main, ".git")):
            notes.append(f"no clone {repo} in {base}")
            continue
        try:
            wts = worktrees(main, base, timeout)
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            notes.append(f"{repo}: can't list worktrees: {e}")
            continue
        for recorded, seen, branch, head in wts:
            if seen and host_base is None and os.path.normpath(seen) != os.path.normpath(recorded):
                rel = os.path.relpath(seen, base)
                if recorded.endswith(os.sep + rel):
                    host_base = recorded[:-len(rel) - 1]
            lane = {"kind": kind, "repository": repo, "integration": integration,
                    "name": os.path.relpath(seen, base) if seen else os.path.basename(recorded),
                    "path": seen, "recordedPath": recorded if not seen or seen != recorded else None,
                    "branch": branch, "head": head}
            if kind == "system" and branch.startswith(PITCH_PREFIX):
                lane.update(kind="pitch", integration="origin/main", integrationRef="refs/remotes/origin/main")
            if not seen:
                lane["problem"] = f"recorded at {recorded}, which isn't here (git worktree prune would drop it)"
            lanes.append(lane)
    for d, kind in ADOPTER_DIRS:
        top = os.path.join(base, d)
        if not os.path.isdir(top):
            continue
        for name in sorted(os.listdir(top), key=str.lower):
            p = os.path.join(top, name)
            if os.path.exists(os.path.join(p, ".git")):
                lanes.append({"kind": kind, "name": f"{d}/{name}", "path": p, "package": name})
        lanes.append({"kind": "workspace", "name": d, "path": top})
    hosted = host_base or base
    for lane in lanes:
        if lane.get("path"):
            lane["hostPath"] = os.path.join(hosted, os.path.relpath(lane["path"], base))
    return {"lanes": lanes, "notes": notes, "hostRoot": host_base if host_base and host_base != base else None}


def claude_root(claude):
    """Claude Code's directory if its projects can be read, else None."""
    claude = claude if claude is not None else os.path.expanduser("~/.claude")
    return claude if os.access(os.path.join(claude, "projects"), os.R_OK | os.X_OK) else None


def log_names(lane):
    """(names, contains) that linux_log matches a lane's logs by."""
    if lane["kind"] in ("system", "pitch", "examples"):
        names = [os.path.basename(lane["path"])]
        if lane.get("branch") and lane["branch"] != "(detached)":
            names.append(lane["branch"].replace("/", "-"))
        return names, []
    if lane["kind"] == "workspace":
        rep = lane.get("report")
        return ([rep["file"][:-len("-REPORT.md")].lower()] if rep and rep["file"].endswith("-REPORT.md") else []), []
    return [lane["package"]], [lane["package"]]


def collect(args):
    started = time.time()
    base = os.path.realpath(args.root)
    found = discover(base, args.timeout)
    lanes, notes = found["lanes"], found["notes"]
    host_base = found["hostRoot"] or base
    claude = claude_root(args.claude)
    logs = os.path.join(base, "linux-logs")

    def one(lane):
        if time.time() - started > args.deadline:
            lane["skipped"] = "past the deadline"
            return lane
        try:
            if lane["kind"] == "workspace":
                workspace_lane(lane)
            elif lane.get("path") and not lane.get("problem"):
                git_lane(lane, base, args)
        except Slow as e:
            lane["skipped"] = str(e)
        except RuntimeError as e:
            lane["problem"] = str(e)
        if lane.get("path"):
            names, contains = log_names(lane)
            lane["linuxLog"] = linux_log(logs, names, contains) if names else None
            lane["session"] = session(claude, lane["hostPath"])
        return lane

    args.object_copies = ObjectCopies()
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            lanes = list(pool.map(one, lanes))
    finally:
        args.object_copies.close()
    du = shutil.disk_usage(base)
    df = subprocess.run(["df", "-h", base], capture_output=True, text=True).stdout.strip().split("\n")
    return {"generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "root": base,
            "hostRoot": host_base if host_base != base else None,
            "claude": "readable" if claude else "unknown",
            "disk": {"freeGiB": round(du.free / 2 ** 30, 1), "totalGiB": round(du.total / 2 ** 30, 1),
                     "df": df[-1] if df else ""},
            "notes": notes, "lanes": lanes, "seconds": round(time.time() - started, 1)}


# ---------------------------------------------------------------- output

def cell(text, limit=None):
    text = (text or "").replace("|", "\\|").replace("\n", " ")
    if limit and len(text) > limit:
        text = text[:limit - 1].rstrip() + "…"
    return text


def short_time(iso):
    return iso[5:16].replace("T", " ") if iso else ""


def markdown(doc):
    L = []
    w = L.append
    d = doc["disk"]
    w(f"# Lanes, {doc['generated']}")
    w("")
    w(f"Read in {doc['seconds']} s from `{doc['root']}`" + (f" (recorded as `{doc['hostRoot']}`)" if doc["hostRoot"] else "")
      + f". Free disk: {d['freeGiB']} GiB of {d['totalGiB']} GiB (`df -h`: {d['df']}). "
      + ("Sessions: from `~/.claude/projects`." if doc["claude"] == "readable" else
         "Sessions: unknown, `~/.claude` isn't readable here."))
    for n in doc["notes"]:
        w(f"- {n}")
    w("")
    groups = (("system", "swift-system", "system-next"), ("pitch", "Pitch worktrees (swift-system)", "origin/main"),
              ("examples", "swift-system-examples", "main"),
              ("adopter", "Adopter clones (`adopters/`)", None),
              ("adopter worktree", "Adopter worktrees (`adopters-unix/`)", None),
              ("workspace", "Adopter workspaces", None))
    for kind, title, integration in groups:
        rows = [x for x in doc["lanes"] if x["kind"] == kind]
        if not rows:
            continue
        w(f"## {title}")
        w("")
        if kind == "workspace":
            w("| Workspace | Newest report | Resume here | Linux log | Session |")
            w("|---|---|---|---|---|")
            for x in rows:
                w(f"| `{x['name']}` | {report_cell(x)} | {cell((x.get('report') or {}).get('resume'), 110)} | "
                  f"{log_cell(x)} | {session_cell(x)} |")
            w("")
            continue
        vs = f"vs `{integration}`" if integration else "Last commit"
        w(f"| Lane | Branch | Head | {vs} | Uncommitted | In progress | Conflicts | Report | Resume here | Linux log "
          "| Session |")
        w("|---|---|---|---|---|---|---|---|---|---|---|")
        for x in rows:
            if x.get("problem") or x.get("skipped"):
                w(f"| `{x['name']}` | {cell(x.get('branch'))} | | | | | | | **{cell(x.get('problem') or 'skipped: ' + x['skipped'])}** "
                  f"| {log_cell(x)} | {session_cell(x)} |")
                continue
            head = f"`{(x.get('head') or '')[:7]}` {short_time(x.get('headTime'))}"
            if integration:
                rel = f"+{x['ahead']} −{x['behind']}" if "ahead" in x else cell(x.get("note"))
            else:
                rel = short_time(x.get("headTime"))
            conflicts = x.get("conflicts")
            if conflicts is not None and x.get("conflictsBy") == "trivial":
                conflicts = f"{conflicts}*"
            w(f"| `{x['name']}` | `{cell(x.get('branch'))}` | {head} | {rel} | {x.get('uncommitted', '')} | "
              f"{', '.join(x.get('inProgress') or []) or '—'} | {'—' if conflicts is None else conflicts} | "
              f"{report_cell(x)} | {cell((x.get('report') or {}).get('resume'), 110)} | {log_cell(x)} | "
              f"{session_cell(x)} |")
        w("")
        if any(x.get("conflictsBy") == "trivial" for x in rows):
            w("\\* Counted from a trivial merge (`git merge-tree BASE OURS THEIRS`): this git has no "
              "`merge-tree --write-tree` (git 2.38). Files with conflict markers, and files one side deleted and "
              "the other changed; a conflict through a rename isn't seen.")
            w("")
    skipped = [x for x in doc["lanes"] if x.get("skipped")]
    if skipped:
        w("Skipped as slow: " + ", ".join(f"`{x['name']}` ({x['skipped']})" for x in skipped) + ".")
        w("")
    return "\n".join(L).rstrip() + "\n"


def report_cell(x):
    r = x.get("report")
    return f"`{r['file']}` {short_time(r['modified'].replace(' ', 'T'))}" if r else "—"


def log_cell(x):
    g = x.get("linuxLog")
    if not g:
        return "—"
    s = "; ".join(g["summary"])
    return f"`{g['file']}` {short_time(g['modified'].replace(' ', 'T'))}" + (f": {cell(s, 120)}" if s else "")


def session_cell(x):
    s = x.get("session") or {}
    st = s.get("state")
    if st in ("active", "idle"):
        return f"{st}, {short_time(s['modified'].replace(' ', 'T'))}"
    return st or ""


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(here)))),
                    help="the folder that holds swift-system, its worktrees and the adopters")
    ap.add_argument("--claude", help="Claude Code's directory (default ~/.claude)")
    ap.add_argument("--timeout", type=float, default=20, help="seconds for one git call")
    ap.add_argument("--deadline", type=float, default=45, help="seconds after which lanes not yet read are skipped")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--no-merge-tree", action="store_true")
    ap.add_argument("--only", nargs="*", help="lanes to show, by name or glob")
    args = ap.parse_args()
    doc = collect(args)
    if args.only:
        doc["lanes"] = [x for x in doc["lanes"] if any(fnmatch.fnmatchcase(x["name"], p) for p in args.only)]
    if args.json:
        json.dump(doc, sys.stdout, indent=1)
        print()
    else:
        sys.stdout.write(markdown(doc))


if __name__ == "__main__":
    main()
