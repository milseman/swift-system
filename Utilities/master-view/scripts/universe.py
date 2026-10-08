#!/usr/bin/env python3
"""The universe of packages the master view covers, in four clusters.

  update-checkout       the repositories of swift's update-checkout main scheme
                        (scheme-main.tsv), but swift-system itself
  swiftlang and apple   the swiftlang and apple GitHub organizations (the
                        org-*.json snapshots), less archived repositories, forks
                        (unless update-checkout has the fork) and anything
                        update-checkout has
  ecosystem             the clones in ../ecosystem in neither list: provisional
  Unix tools            the tools of ../swift-system-examples, on its main, and
                        the library targets they share (ExamplesSupport)

Writes a TSV with one row per package: name, cluster, source (where the row
comes from), clone (a path relative to the repository, or none), remote
(owner/repository on GitHub), swift (yes, no, or ? when there's no clone to
look in and non-swift.tsv doesn't list it), a note, and subdir: the
directory of the clone a row covers when it's one target of a package (a
tool's Sources/Ls), else empty. What it left out is listed after them, with
cluster `excluded` and the reason as the note.

Nothing is fetched: clones are read with git, with lazy fetching off.

Usage: universe.py --repo R --ecosystem DIR --adopters DIR --examples DIR
                   --non-swift TSV --out TSV
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

CLUSTERS = ("update-checkout", "swiftlang and apple", "ecosystem", "Unix tools")
SYSTEM_REMOTE = "apple/swift-system"
COLUMNS = ("name", "cluster", "source", "clone", "remote", "swift", "note", "subdir")
MANIFEST_RE = re.compile(r"(^|/)Package(@swift-[0-9.]+)?\.swift$")
TOOL_RE = re.compile(r'\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')
LIBRARY_TARGET_RE = re.compile(r'\.target\(\s*name:\s*"([^"]+)"')
ORGS = (("org-swiftlang.json", "swiftlang"), ("org-apple.json", "apple"))
# Each migrated package's branches, newest first (status.py's PLATFORM_BRANCHES).
MIGRATION_BRANCHES = ("migrate-all", "migrate-unix", "migrate-darwin", "no-darwin")


def git(path, *args, ok=(0,)):
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1")
    p = subprocess.run(["git", "-C", path, *args], capture_output=True, text=True, env=env)
    if p.returncode not in ok:
        raise RuntimeError(f"git -C {path} {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def is_clone(path):
    return os.path.exists(os.path.join(path, ".git"))


def github_remote(url):
    """owner/repository from a GitHub URL, else None."""
    m = re.search(r"github\.com[:/]+([^/\s]+)/([^/\s]+?)(?:\.git)?/?$", (url or "").strip())
    return f"{m.group(1)}/{m.group(2)}" if m else None


def remote_of(path):
    return github_remote(git(path, "config", "--get", "remote.origin.url", ok=(0, 1)))


def clones(directory):
    """{lowercased remote: directory name} for the git clones in directory."""
    out = {}
    if not directory or not os.path.isdir(directory):
        return out
    for d in sorted(os.listdir(directory)):
        path = os.path.join(directory, d)
        if os.path.isdir(path) and is_clone(path):
            r = remote_of(path)
            if r:
                out.setdefault(r.lower(), d)
    return out


def swift_files(path, commit):
    """The number of .swift files at a commit, package manifests aside, or
    None if the commit can't be read."""
    try:
        listing = git(path, "ls-tree", "-r", "--name-only", commit)
    except RuntimeError:
        return None
    return sum(1 for f in listing.splitlines() if f.endswith(".swift") and not MANIFEST_RE.search(f))


def migration_commit(path):
    for b in MIGRATION_BRANCHES:
        c = git(path, "rev-parse", "--verify", "--quiet", f"refs/heads/{b}^{{commit}}", ok=(0, 1)).strip()
        if c:
            return c
    return None


def read_tsv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            rows.append(line.rstrip("\n").split("\t"))
    return rows


def load_non_swift(path):
    """{lowercased remote: why}."""
    if not path or not os.path.exists(path):
        return {}
    return {r[0].strip().lower(): (r[1].strip() if len(r) > 1 else "") for r in read_tsv(path) if r and r[0].strip()}


def tools_of(examples):
    """[(command, target)] from the examples' Package.swift `tools` table, on main."""
    text = git(examples, "show", "main:Package.swift")
    m = re.search(r"let\s+tools\s*:[^=]*=\s*\[(.*?)\n\]", text, re.S)
    if not m:
        raise SystemExit(f"universe: no `let tools` table in {examples}'s Package.swift on main")
    return TOOL_RE.findall(m.group(1))


def library_targets_of(examples):
    """The examples' library targets (`.target(name: "ExamplesSupport", ...)`),
    the code the tools share, from Package.swift on main."""
    return LIBRARY_TARGET_RE.findall(git(examples, "show", "main:Package.swift"))


def build(a):
    """The rows: [{name, cluster, source, clone, remote, swift, note}], the
    universe's clusters in order, then what's excluded."""
    eco = clones(a.ecosystem)
    adopt = clones(a.adopters)
    non_swift = load_non_swift(a.non_swift)
    rel = lambda p: os.path.relpath(p, a.repo)  # noqa: E731

    def place(remote):
        """(clone path for the row, other clone or None, path read for Swift
        files, commit read)."""
        key = (remote or "").lower()
        ad = os.path.join(a.adopters, adopt[key]) if key in adopt else None
        ec = os.path.join(a.ecosystem, eco[key]) if key in eco else None
        if ad:
            commit = migration_commit(ad) or git(ad, "rev-parse", "HEAD").strip()
            return ad, ec, ad, commit
        if ec:
            return ec, None, ec, git(ec, "rev-parse", "HEAD").strip()
        return None, None, None, None

    def swift_of(remote, path, commit):
        if path:
            n = swift_files(path, commit)
            if n is None:
                return "?", "its clone's commit can't be read"
            return ("yes", "") if n else ("no", "no .swift file but package manifests")
        key = (remote or "").lower()
        if key in non_swift:
            return "no", non_swift[key]
        return "?", ""

    rows, excluded = [], []
    scheme = read_tsv(os.path.join(a.ecosystem, "scheme-main.tsv"))
    uc_remotes = set()
    for r in scheme:
        name, remote = r[0], (r[2] if len(r) > 2 else "")
        if remote.lower() == SYSTEM_REMOTE:
            excluded.append({"name": name, "cluster": "excluded", "source": "scheme-main.tsv", "clone": "none",
                             "remote": remote, "swift": "yes", "note": "System itself"})
            continue
        uc_remotes.add(remote.lower())
        clone, other, path, commit = place(remote)
        swift, why = swift_of(remote, path, commit)
        notes = []
        if other:
            notes.append(f"also {rel(other)}")
        if swift == "no" and why:
            notes.append(why)
        rows.append({"name": name, "cluster": CLUSTERS[0], "source": "scheme-main.tsv",
                     "clone": rel(clone) if clone else "none", "remote": remote, "swift": swift,
                     "note": "; ".join(notes)})

    seen = set(uc_remotes) | {SYSTEM_REMOTE}
    org_rows = []
    for fname, owner in ORGS:
        path = os.path.join(a.ecosystem, fname)
        with open(path, encoding="utf-8") as f:
            repos = json.load(f)
        for x in sorted(repos, key=lambda x: x["name"].lower()):
            remote = f"{owner}/{x['name']}"
            key = remote.lower()
            base = {"name": x["name"], "source": fname, "remote": remote}
            if key == SYSTEM_REMOTE:
                excluded.append(dict(base, cluster="excluded", clone="none", swift="yes", note="System itself"))
                continue
            if key in uc_remotes:
                continue   # in update-checkout already
            if x.get("isArchived"):
                excluded.append(dict(base, cluster="excluded", clone="none", swift="?", note="archived"))
                continue
            if x.get("isFork"):
                excluded.append(dict(base, cluster="excluded", clone="none", swift="?",
                                     note="a fork that update-checkout doesn't have"))
                continue
            if key in seen:
                continue
            seen.add(key)
            clone, other, cpath, commit = place(remote)
            swift, why = swift_of(remote, cpath, commit)
            org_rows.append(dict(base, cluster=CLUSTERS[1], clone=rel(clone) if clone else "none", swift=swift,
                                 note="; ".join(([f"also {rel(other)}"] if other else []) +
                                                ([why] if swift == "no" and why else []))))
    rows += sorted(org_rows, key=lambda x: x["name"].lower())

    eco_rows = []
    for key, d in sorted(eco.items(), key=lambda kv: kv[1].lower()):
        if key in seen:
            continue
        seen.add(key)
        path = os.path.join(a.ecosystem, d)
        commit = git(path, "rev-parse", "HEAD").strip()
        swift, why = swift_of(key, path, commit)
        eco_rows.append({"name": d, "cluster": CLUSTERS[2], "source": "ecosystem clone", "clone": rel(path),
                         "remote": remote_of(path), "swift": swift,
                         "note": "; ".join(["provisional"] + ([why] if swift == "no" and why else []))})
    for key, d in sorted(adopt.items(), key=lambda kv: kv[1].lower()):
        if key in seen:
            continue
        seen.add(key)
        path = os.path.join(a.adopters, d)
        swift, why = swift_of(key, path, migration_commit(path) or "HEAD")
        eco_rows.append({"name": d, "cluster": CLUSTERS[2], "source": "adopters clone", "clone": rel(path),
                         "remote": remote_of(path), "swift": swift, "note": "provisional"})
    rows += eco_rows

    ex_remote = remote_of(a.examples) if is_clone(a.examples) else None
    if is_clone(a.examples):
        for command, target in tools_of(a.examples):
            rows.append({"name": command, "cluster": CLUSTERS[3], "source": "swift-system-examples main",
                         "clone": rel(a.examples), "remote": ex_remote or "", "swift": "yes",
                         "note": f"target {target}, Sources/{target}", "subdir": f"Sources/{target}"})
        for target in library_targets_of(a.examples):
            rows.append({"name": target, "cluster": CLUSTERS[3], "source": "swift-system-examples main",
                         "clone": rel(a.examples), "remote": ex_remote or "", "swift": "yes",
                         "note": f"the tools' shared code: target {target}, Sources/{target}",
                         "subdir": f"Sources/{target}"})
    # A name two rows share (each organization's `.github`) becomes the
    # repository's owner/name, so that every package has a name of its own.
    names = collections.Counter(r["name"] for r in rows)
    for r in rows:
        if names[r["name"]] > 1 and r.get("remote"):
            r["name"] = r["remote"]
    seen_ex, kept = set(), []
    for r in excluded:
        if (r["remote"] or "").lower() not in seen_ex:
            seen_ex.add((r["remote"] or "").lower())
            kept.append(r)
    return rows + kept


def write(rows, path):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("# The master view's packages, by cluster; regenerated by Utilities/master-view/regenerate.sh\n")
        f.write("# (scripts/universe.py). README.md in Utilities/master-view says how each cluster is defined.\n")
        f.write("\t".join(COLUMNS) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c) or "").replace("\t", " ") for c in COLUMNS) + "\n")
    os.replace(tmp, path)


def read(path):
    """The rows of a universe.tsv, as dicts."""
    out = []
    with open(path, encoding="utf-8") as f:
        header = None
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            cells = line.rstrip("\n").split("\t")
            if header is None:
                header = cells
                continue
            out.append(dict(zip(header, cells + [""] * (len(header) - len(cells)))))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--ecosystem", required=True)
    ap.add_argument("--adopters", required=True)
    ap.add_argument("--examples", required=True)
    ap.add_argument("--non-swift")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    for d in ("repo", "ecosystem", "adopters", "examples"):
        setattr(a, d, os.path.realpath(getattr(a, d)))
    rows = build(a)
    write(rows, a.out)
    counts = {c: sum(1 for r in rows if r["cluster"] == c) for c in CLUSTERS + ("excluded",)}
    print("universe: " + ", ".join(f"{n} {c}" for c, n in counts.items()) + f" -> {a.out}")


if __name__ == "__main__":
    main()
