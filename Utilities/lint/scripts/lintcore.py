#!/usr/bin/env python3
"""What lint's checks share: findings, git, the adopter clones and their
branches, and the run's context."""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import subprocess  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.dirname(HERE)
UTILITIES = os.path.dirname(TOOL)
for d in ("adopter-coverage", "api-delta", "api-graph"):
    p = os.path.join(UTILITIES, d, "scripts")
    if p not in sys.path:
        sys.path.append(p)

ENV = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_TERMINAL_PROMPT="0")
MIGRATION_BRANCHES = ("migrate-all", "migrate-unix", "migrate-darwin")


class Finding:
    __slots__ = ("file", "line", "rule", "level", "message", "extra")

    def __init__(self, file, line, rule, level, message, **extra):
        self.file, self.line, self.rule, self.level, self.message, self.extra = \
            file, int(line or 0), rule, level, message, extra

    def text(self):
        return f"{self.file}:{self.line}: {self.rule}: {self.message}"

    def as_json(self):
        return dict({"file": self.file, "line": self.line, "rule": self.rule, "level": self.level,
                     "message": self.message}, **self.extra)


class CheckError(Exception):
    """A check that can't run, with why."""


def git(repo, *args, ok=(0,), stdin=None):
    p = subprocess.run(["git", "--no-optional-locks", "-C", repo, *args], capture_output=True, text=True,
                       env=ENV, input=stdin)
    if p.returncode not in ok:
        raise CheckError(f"git -C {repo} {' '.join(args)}: {p.stderr.strip()[:300]}")
    return p.stdout


def commit_of(repo, ref):
    return git(repo, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", ok=(0, 1)).strip() or None


def newest_branch(clone):
    for b in MIGRATION_BRANCHES:
        if commit_of(clone, f"refs/heads/{b}"):
            return b
    return None


def default_clones(repo):
    """The adopter clones beside the repository: ../adopters/*."""
    top = os.path.join(os.path.dirname(repo), "adopters")
    if not os.path.isdir(top):
        return []
    return [os.path.join(top, d) for d in sorted(os.listdir(top), key=str.lower)
            if os.path.exists(os.path.join(top, d, ".git"))]


def display(path):
    """A path as the findings print it: relative to the current directory
    when that's shorter."""
    rel = os.path.relpath(path)
    return rel if len(rel) < len(path) else path


class Context:
    def __init__(self, args):
        self.args = args
        self.repo = git(HERE, "rev-parse", "--show-toplevel").strip()
        self.head = commit_of(self.repo, "HEAD")
        self.work = os.path.join(self.repo, ".build", "lint")
        self.notes = []

    def clones(self):
        return [os.path.abspath(c) for c in self.args.clone] if self.args.clone else default_clones(self.repo)

    def note(self, text):
        self.notes.append(text)


# ---------------------------------------------------------------- System's coverage

MODULES_FILE = "Utilities/adopter-coverage/modules.ini"
MAPPING_FILE = "Utilities/adopter-coverage/mapping.ini"
_COVERAGE = {}


def coverage(ctx, system_ref):
    """adopter-coverage's ledger.Coverage for System at a commit, with
    mapping.ini at this worktree's HEAD, as the ledger reads them; cached
    in .build/lint/system/<commit>. Returns (coverage, scan, commit)."""
    commit = commit_of(ctx.repo, system_ref)
    if not commit:
        raise CheckError(f"no System commit {system_ref}")
    if commit not in _COVERAGE:
        import check
        import ledger
        work = os.path.join(ctx.work, "system")
        os.makedirs(work, exist_ok=True)
        mapping_path = os.path.join(work, f"mapping-{ctx.head[:12]}.ini")
        with open(mapping_path, "w", encoding="utf-8") as f:
            f.write(git(ctx.repo, "show", f"{ctx.head}:{MAPPING_FILE}"))
        _, mapping, _ = check.load_mapping(mapping_path)
        scan, derived = ledger.system_api(ctx.repo, commit, work)
        _COVERAGE[commit] = (ledger.Coverage(scan, derived, mapping), scan, commit)
    return _COVERAGE[commit]


def modules(ctx):
    import ledger
    return ledger.Modules(git(ctx.repo, "show", f"{ctx.head}:{MODULES_FILE}"))
