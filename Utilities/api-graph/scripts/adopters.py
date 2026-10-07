#!/usr/bin/env python3
"""Where other packages use the graph's declarations, and where they would.

Two kinds of use sites, for every node of graph.json:

  adopted        Packages migrated onto System on a branch of a clone in
                 ADOPTERS, each read at its newest migration branch (the
                 first of --branches it has: migrate-all, else migrate-unix,
                 else migrate-darwin): the files and lines of the branch
                 that use each declaration, with the diff hunk, against the
                 branch's merge base with the package's main, that
                 introduced the use. The examples' repository (--examples,
                 at its main) is read the same way, as a package written on
                 System from the start: its Sources are all its own, so
                 there are no hunks, and the lexical pass reads every line
                 of them the Darwin build doesn't compile.
                 - Precise where the compiler resolves the use. The branch's
                   commit is exported, its path dependency on swift-system
                   pointed at an export of the head commit (and a path
                   dependency on another migrated clone at that clone's
                   branch), and built as the coverage tools build it
                   (Utilities/adopter-coverage/packages/*.ini) with an index
                   store. The store's references to a node's USR are its
                   sites. The references are cached by package commit,
                   toolchain, settings and path dependencies, with the
                   System tree they were built against and a fingerprint
                   of each System declaration they name; against another
                   System tree, they're revalidated (reused when every one
                   of those declarations is unchanged in the head commit's
                   symbol graphs) or rebuilt. With --builds-dir, each
                   migration's export and build are kept, the export updated
                   in place, so a rebuild is incremental; else the build is
                   deleted as soon as it's read.
                 - Lexical elsewhere: files the build doesn't compile (tests,
                   or everything, when the build fails), and added lines in
                   `#if` branches Darwin doesn't take. Names are matched on
                   the lines the migration added, only where they're
                   distinctive (see LexicalMatcher).
  would benefit  Packages in ECOSYSTEM, and clones in ADOPTERS without a
                 migration: the C interfaces they use, joined with the C
                 names each declaration's doc comment gives ("The
                 corresponding C function is `x`."), read by the coverage
                 tools' own derivation (adopter-coverage's derive.py, run by
                 cnames.py). The
                 interfaces are the coverage tools' extraction
                 (interfaces.json.gz in their results store) at the clone's
                 commit; a package the store has no extraction for is
                 scanned lexically. C names the base commit already covers
                 are left out, since a package using them needs nothing
                 new, and so are restricted subjects (`fcntl`, with the
                 `F_GETFL` command: only F_GETFL counts). For a package that
                 also has a migration, each site says whether its line is
                 unchanged on the migration branch.

A package is a git clone; clones of one repository (by origin URL) in both
directories are one package. System itself is skipped.

Usage: adopters.py --graph graph.json --repo DIR --head COMMIT
                   --head-src DIR --base-src DIR --head-scan F --base-scan F
                   --cnames cnames.json
                   --work DIR --cache DIR --out adopters.json
                   [--symbolgraphs DIR] [--validate declarations|interface|tree]
                   [--builds-dir DIR] [--jobs 4]
                   [--adopters DIR] [--ecosystem DIR] [--coverage-results DIR]
                   [--examples DIR] [--examples-ref main]
                   [--branches migrate-all,migrate-unix,migrate-darwin]
                   [--builds build|reuse|none]
                   [--rebuild] [--min-free-gb 15] [--only KEY,...]
  --branches is newest first: each clone is read at the first it has
  (--branch B is --branches B).
  --symbolgraphs is api-delta's symbol graphs of the head commit
  (symbolgraphs/head), what cached indexes are revalidated against.
  --builds-dir keeps a build directory per migration, and System's export,
  for the next build to be incremental. --jobs is how many migrations are
  built at a time, longest first.
"""

import sys

sys.dont_write_bytecode = True   # nothing written into the coverage tool's scripts directory

import argparse  # noqa: E402
import bisect  # noqa: E402
import collections  # noqa: E402
import concurrent.futures  # noqa: E402
import datetime  # noqa: E402
import fcntl  # noqa: E402
import glob  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import importlib.util  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import stat  # noqa: E402
import subprocess  # noqa: E402
import threading  # noqa: E402
import time  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
UTILITIES = os.path.dirname(os.path.dirname(HERE))
COVERAGE = os.path.join(UTILITIES, "adopter-coverage")
sys.path.insert(0, os.path.join(UTILITIES, "api-delta", "scripts"))
import scan_sources as ss  # noqa: E402  (api-delta's comment and string blanker)
sys.path.insert(0, HERE)
import index_refs  # noqa: E402

# Bump when what the cached index holds changes.
READER_VERSION = "1"
SYSTEM_MODULES = ("13SystemPackage", "13SystemSockets")
ROLE_IMPLICIT = 1 << 8
SWIFT_VERSION = (6, 2)   # for compiler(>=...) conditions; replaced from `swift --version`
# The migration branches, newest first (status.py's PLATFORM_BRANCHES): a
# clone is read at the first of them it has.
MIGRATION_BRANCHES = ("migrate-all", "migrate-unix", "migrate-darwin")
# The index's symbol kinds that are types (indexstore.h: enum, struct,
# class, protocol, union, type alias). Only a type named right before
# another reference is a qualifier (`PThread` in `PThread.Mutex`); a
# property or method before one is a use (`ProcessID.current` in
# `ProcessID.current.rawValue`).
TYPE_SYMBOL_KINDS = {5, 6, 7, 8, 10, 11}

# Member names too common to match lexically: a use of one could be any
# type's. Names declared on the base commit, and names the package declares
# itself, are ruled out as well.
COMMON_NAMES = set("""
    init deinit lock unlock close open read write run wait value values count description debugDescription
    rawValue contains insert remove removeAll append update reset start stop cancel resume suspend flush sync
    send receive bind listen accept connect shutdown kind type flags options mode size name path data bytes
    buffer first last next current error errno code message events event filter identifier id seconds
    nanoseconds milliseconds microseconds duration get set withLock lockForReading lockForWriting
    signal status result state handle load store exchange start end index offset length capacity address
    port family protocol level option socket file files directory entry entries item items key keys
    none all empty zero max min default standard system user group owner permissions
    isEmpty isValid isOpen isClosed withUnsafeBytes withUnsafeMutableBytes withUnsafeBufferPointer
    hash hashValue hasher encode decode copy move clone duplicate truncate seek position
    source target from to at by with using into over under inputs outputs input output
    success failure timeout interrupted invalid unknown other some
    union intersection symmetricDifference subtracting subtract formUnion formIntersection
    formSymmetricDifference isSubset isSuperset isDisjoint isStrictSubset isStrictSuperset
    makeIterator startIndex endIndex formIndex distance elementsEqual map compactMap flatMap reduce forEach
    sorted reversed prefix suffix dropFirst dropLast joined split allSatisfy firstIndex lastIndex
    withContiguousStorageIfAvailable underestimatedCount customMirror
""".split())
# Type names that other modules also declare (the standard library,
# Synchronization, Foundation, Dispatch), so an unqualified use is ambiguous.
COMMON_TYPES = set("""
    Mutex Atomic Duration Span RawSpan MutableSpan MutableRawSpan OutputSpan OutputRawSpan Thread Process
    Pipe FileHandle URL Data Date Lock Condition Semaphore Timer Clock Signal Kind Flags Options Mode Error
    Result Entry Event Events Attributes Info Status State Iterator Element Index Handle Name Priority
    Policy Action Filter Descriptor Queue Configuration Options Identifier ID Group User Owner Scope Level
""".split())


PRINT_LOCK = threading.Lock()
# libIndexStore's thread safety isn't documented, and reading a store is
# Python callbacks under the GIL anyway: one store at a time.
READ_LOCK = threading.Lock()


def say(line):
    """A line of the log, whole, from any thread."""
    with PRINT_LOCK:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def load_json(path):
    if path.endswith(".gz"):
        return json.load(gzip.open(path, "rt", encoding="utf-8"))
    return json.load(open(path, encoding="utf-8"))


def coverage_module(name):
    """A script of Utilities/adopter-coverage, imported read-only from its
    file under a prefixed name, so it can't shadow this tool's own scripts."""
    spec = importlib.util.spec_from_file_location("coverage_" + name, os.path.join(COVERAGE, "scripts", name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(cmd, cwd=None, env=None, log=None, check=False, input_bytes=None):
    """(returncode, stdout text). With log, stdout and stderr go there."""
    if log:
        with open(log, "ab") as f:
            f.write(("\n$ " + " ".join(cmd) + "\n").encode())
            f.flush()
            r = subprocess.run(cmd, cwd=cwd, env=env, stdout=f, stderr=subprocess.STDOUT, input=input_bytes)
        out = ""
    else:
        r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, input=input_bytes)
        out = r.stdout.decode("utf-8", "replace")
    if check and r.returncode != 0:
        raise SystemExit(f"adopters: command failed ({r.returncode}): {' '.join(cmd)}")
    return r.returncode, out


def git(repo, *args, check=True):
    code, out = run(["git", "-C", repo, *args])
    if check and code != 0:
        raise SystemExit(f"adopters: git {' '.join(args)} failed in {repo}")
    return out if code == 0 else None


def rev(repo, ref):
    out = git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}", check=False)
    return out.strip() if out else None


def export(repo, commit, dest):
    os.makedirs(dest, exist_ok=True)
    archive = subprocess.run(["git", "-C", repo, "archive", commit], capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)


def same_file(a, b):
    """Whether two paths hold the same file: links with one target, or
    regular files with one content and executable bit."""
    try:
        sa, sb = os.lstat(a), os.lstat(b)
    except OSError:
        return False
    if stat.S_ISLNK(sa.st_mode) or stat.S_ISLNK(sb.st_mode):
        return stat.S_ISLNK(sa.st_mode) and stat.S_ISLNK(sb.st_mode) and os.readlink(a) == os.readlink(b)
    if not (stat.S_ISREG(sa.st_mode) and stat.S_ISREG(sb.st_mode)) or sa.st_size != sb.st_size \
            or (sa.st_mode & 0o111) != (sb.st_mode & 0o111):
        return False
    with open(a, "rb") as fa, open(b, "rb") as fb:
        while True:
            x = fa.read(1 << 20)
            if x != fb.read(1 << 20):
                return False
            if not x:
                return True


def make_dir(path):
    """os.makedirs, removing a file or link where the path needs a directory."""
    p = path
    while not (os.path.isdir(p) and not os.path.islink(p)):
        if os.path.lexists(p):
            os.unlink(p)
            break
        p = os.path.dirname(p)
    os.makedirs(path, exist_ok=True)


def sync_export(repo, commit, dest, transform=None, keep=("Package.resolved",)):
    """Make dest what `export` would, in place: the commit is exported
    beside it, `transform(stage)` edits that (the manifests' path
    dependencies), and only the files that differ are moved in, so the rest
    keep their modification times and a build of dest is incremental. What
    the commit doesn't have is removed, except the root files in `keep`
    (the Package.resolved SwiftPM writes when the commit has none).
    Returns (files written, entries removed)."""
    stage = dest.rstrip("/") + ".stage"
    shutil.rmtree(stage, ignore_errors=True)
    os.makedirs(stage)
    archive = subprocess.run(["git", "-C", repo, "archive", commit], capture_output=True, check=True).stdout
    # -m: a file moved in is dated now, newer than any build of what it replaces.
    subprocess.run(["tar", "-x", "-m", "-C", stage], input=archive, check=True)
    if transform:
        transform(stage)
    written = removed = 0
    wanted = set()
    for root, dirs, files in os.walk(stage):
        rel = os.path.relpath(root, stage)
        rel = "" if rel == "." else rel
        links = [d for d in dirs if os.path.islink(os.path.join(root, d))]
        dirs[:] = [d for d in dirs if d not in links]
        wanted.update(os.path.join(rel, d) for d in dirs)
        for name in files + links:
            r = os.path.join(rel, name)
            wanted.add(r)
            src, dst = os.path.join(stage, r), os.path.join(dest, r)
            if same_file(src, dst):
                continue
            make_dir(os.path.dirname(dst))
            if os.path.isdir(dst) and not os.path.islink(dst):
                shutil.rmtree(dst)
            os.replace(src, dst)
            written += 1
    for root, dirs, files in os.walk(dest):
        rel = os.path.relpath(root, dest)
        rel = "" if rel == "." else rel
        for d in list(dirs):
            if os.path.join(rel, d) not in wanted:
                p_ = os.path.join(root, d)
                if os.path.islink(p_):
                    os.unlink(p_)
                else:
                    shutil.rmtree(p_)
                dirs.remove(d)
                removed += 1
        for name in files:
            if os.path.join(rel, name) not in wanted and not (rel == "" and name in keep):
                os.unlink(os.path.join(root, name))
                removed += 1
    shutil.rmtree(stage)
    return written, removed


TOOLS_NOTE = "tools version lowered to %d.%d"


def lower_tools_version(package_dir):
    """Lower each manifest's tools version that's newer than this toolchain's
    (SWIFT_VERSION) to it; True if any was."""
    changed = False
    for manifest in glob.glob(os.path.join(package_dir, "Package*.swift")):
        t = open(manifest, encoding="utf-8").read()
        m = re.match(r"// swift-tools-version: *(\d+)(?:\.(\d+))?", t)
        if m and (int(m.group(1)), int(m.group(2) or 0)) > SWIFT_VERSION:
            t = re.sub(r"^// swift-tools-version: *[0-9.]+", "// swift-tools-version:%d.%d" % SWIFT_VERSION, t)
            open(manifest, "w", encoding="utf-8").write(t)
            changed = True
    return changed


def manifest_digest(package_dir):
    """A digest of a package's manifests, as its build reads them."""
    h = hashlib.sha1()
    for p in sorted(glob.glob(os.path.join(package_dir, "Package*.swift"))):
        h.update(os.path.basename(p).encode() + b"\0" + open(p, "rb").read() + b"\0")
    return h.hexdigest()[:16]


def disk_kb(path):
    code, out = run(["du", "-sk", path])
    return int(out.split()[0]) if out.strip() else None


class Commit:
    """Files of one commit, read through one `git cat-file --batch` process,
    never from a working tree."""

    def __init__(self, repo, commit):
        self.repo, self.commit = repo, commit
        self.cache = {}
        self.proc = None

    def text(self, rel):
        if rel not in self.cache:
            if self.proc is None:
                self.proc = subprocess.Popen(["git", "-C", self.repo, "cat-file", "--batch"],
                                             stdin=subprocess.PIPE, stdout=subprocess.PIPE)
            self.proc.stdin.write(f"{self.commit}:{rel}\n".encode())
            self.proc.stdin.flush()
            header = self.proc.stdout.readline().decode().split()
            if len(header) == 3 and header[1] == "blob":
                data = self.proc.stdout.read(int(header[2]))
                self.proc.stdout.read(1)   # the newline after the contents
                self.cache[rel] = data.decode("utf-8", "replace")
            else:
                self.cache[rel] = None     # "<name> missing", or not a file
        return self.cache[rel]

    def lines(self, rel):
        if ("lines", rel) not in self.cache:
            t = self.text(rel)
            self.cache[("lines", rel)] = t.split("\n") if t is not None else []
        return self.cache[("lines", rel)]

    def close(self):
        if self.proc:
            self.proc.stdin.close()
            self.proc.wait()
            self.proc = None


# ---------------------------------------------------------------- discovery

MAIN_REFS = ("main", "master", "origin/main", "origin/master", "origin/HEAD")


def toplevel(path):
    out = git(path, "rev-parse", "--show-toplevel", check=False)
    return os.path.realpath(out.strip()) if out else None


def remote_identity(path):
    """('owner/repo', 'repo') from the clone's origin URL, else from its
    directory's name."""
    url = (git(path, "config", "--get", "remote.origin.url", check=False) or "").strip()
    m = re.search(r"([^/:]+)/([^/:]+?)(?:\.git)?/?$", url)
    if m:
        return f"{m.group(1)}/{m.group(2)}", m.group(2)
    name = os.path.basename(path)
    return name, name


def common_dir(path):
    out = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir", check=False)
    return os.path.realpath(out.strip()) if out else None


def newest_branch(path, branches):
    """(branch, commit) of the first of `branches`, newest first, that the
    clone has as a local branch, or (None, None)."""
    for b in branches:
        c = rev(path, f"refs/heads/{b}")
        if c:
            return b, c
    return None, None


def discover(adopters_dir, ecosystem_dir, branches, repo, examples=None):
    """Every package clone: {key: {key, name, remote, adopters, ecosystem}}.
    An adopters clone is read at its newest migration branch, the first of
    `branches` it has (its info's `branch`; `branches` lists every one it
    has). `examples` is (directory, ref): the examples' repository, read at
    that ref as a package written on System from the start, with no merge
    base (`examples` in its info, and `role` in its entry)."""
    own = common_dir(repo)
    pkgs = {}
    for role, parent in (("adopters", adopters_dir), ("ecosystem", ecosystem_dir)):
        if not parent or not os.path.isdir(parent):
            continue
        for d in sorted(os.listdir(parent)):
            path = os.path.realpath(os.path.join(parent, d))
            if not os.path.isdir(path) or toplevel(path) != path:
                continue
            remote, name = remote_identity(path)
            key = name.lower()
            if key == "swift-system" or common_dir(path) == own:
                continue
            head = rev(path, "HEAD")
            if not head or git(path, "cat-file", "-e", f"{head}:Package.swift", check=False) is None:
                continue   # not a Swift package (the swift repository, say)
            e = pkgs.setdefault(key, {"key": key, "name": name, "remote": remote, "adopters": None, "ecosystem": None})
            info = {"path": path, "dir": d, "head": head}
            if role == "adopters":
                branch, tip = newest_branch(path, branches)
                info["branch"] = branch
                info["branches"] = {b: c for b in branches for c in [rev(path, f"refs/heads/{b}")] if c}
                if tip:
                    main_ref = next((r for r in MAIN_REFS if rev(path, r)), None)
                    base = git(path, "merge-base", tip, main_ref, check=False) if main_ref else None
                    base = base.strip() if base else None
                    n = int(git(path, "rev-list", "--count", f"{base}..{tip}").strip()) if base else None
                    info.update({"commit": tip, "subject": git(path, "log", "-1", "--format=%s", tip).strip(),
                                 "mainRef": main_ref, "mainCommit": rev(path, main_ref) if main_ref else None,
                                 "base": base, "baseSubject": git(path, "log", "-1", "--format=%s", base).strip()
                                 if base else None, "commits": n, "migrated": bool(n)})
                else:
                    info.update({"commit": None, "migrated": False})
            else:
                info.update({"commit": head, "subject": git(path, "log", "-1", "--format=%s", head).strip()})
            e[role] = info
    if examples and examples[0] and os.path.isdir(examples[0]):
        path, ref = os.path.realpath(examples[0]), examples[1]
        tip = rev(path, f"refs/heads/{ref}") or rev(path, ref)
        remote, name = remote_identity(path)
        key = name.lower()
        if toplevel(path) != path or not tip or git(path, "cat-file", "-e", f"{tip}:Package.swift", check=False) is None:
            say(f"adopters: the examples, {path}: no Swift package at {ref}; left out")
        elif key in pkgs:
            say(f"adopters: the examples, {path}: another clone is {key} too; left out")
        else:
            pkgs[key] = {"key": key, "name": name, "remote": remote, "role": "examples", "ecosystem": None,
                         "adopters": {"path": path, "dir": os.path.basename(path), "head": rev(path, "HEAD"),
                                      "branch": ref, "branches": {ref: tip}, "commit": tip,
                                      "subject": git(path, "log", "-1", "--format=%s", tip).strip(),
                                      "mainRef": None, "mainCommit": None, "base": None, "baseSubject": None,
                                      "commits": int(git(path, "rev-list", "--count", tip).strip()),
                                      "migrated": True, "examples": True}}
    return pkgs


# ---------------------------------------------------------------- build settings

def coverage_package_files():
    """The coverage tools' package files, by the directory name of the
    checkout each names, and by title, lowercased."""
    out = {}
    for sub in ("", "ecosystem"):
        for p in sorted(glob.glob(os.path.join(COVERAGE, "packages", sub, "*.ini"))):
            text = open(p, encoding="utf-8").read()
            for key in ("checkout", "title"):
                m = re.search(rf"^{key}\s*=\s*(\S+)", text, re.M)
                if m:
                    out.setdefault(os.path.basename(m.group(1).rstrip("/")).lower(), p)
    return out


def newest_toolchain():
    """A swift.org toolchain's swiftc, for a package the default toolchain
    can't build: swift-latest's, else the newest by name."""
    base = os.path.expanduser("~/Library/Developer/Toolchains")
    # The toolchain's directory is resolved, not swiftc: it's a link to
    # swift-driver, which takes its mode from the name it's run by.
    latest = os.path.join(base, "swift-latest.xctoolchain")
    if os.path.exists(os.path.join(latest, "usr", "bin", "swiftc")):
        return os.path.join(os.path.realpath(latest), "usr", "bin", "swiftc")
    cands = sorted(glob.glob(os.path.join(base, "*.xctoolchain", "usr", "bin", "swiftc")))
    return cands[-1] if cands else None


def tree_of(repo, commit):
    """What a build against System at commit depends on: the trees of its
    Sources and manifest (as the coverage tools key their builds)."""
    out = git(repo, "rev-parse", f"{commit}:Sources", f"{commit}:Package.swift").split()
    return "-".join(t[:12] for t in out)


# ---------------------------------------------------------------- System's declarations, for revalidation

class SystemDeclarations:
    """System's public declarations at the head commit, by USR, from
    api-delta's symbol graphs of it (graph.json has only the delta): what a
    cached index built against another System commit is revalidated
    against. A declaration's fingerprint covers what decides how a client's
    use of it compiles: its declaration fragments (the signature, default
    arguments and attributes included), availability, SPI, access, generic
    signature and extension constraints, and a type's conformances. Doc
    comments and source locations don't count."""

    # A property's or subscript's accessor, which the index records beside
    # the property: `...Sivg` (getter) for `...Sivp`, `...SivgZ` for a
    # static one; setters, modify, read, observers, addressors likewise.
    ACCESSOR = re.compile(r"^(.*[vi])(?:[gsGwWrMixybz]|[al][uOop])(Z?)$")

    def __init__(self, sg_dir):
        self.fingerprint, self.name = {}, {}
        symbols, rels = {}, []
        for path in sorted(glob.glob(os.path.join(sg_dir, "*.symbols.json"))):
            d = load_json(path)
            for s in d.get("symbols", []):
                symbols[s["identifier"]["precise"]] = s
            rels += d.get("relationships", [])
        # A conformance an extension declares belongs to the extended type.
        extended = {r["source"]: r["target"] for r in rels if r["kind"] == "extensionTo"}
        conformances = collections.defaultdict(list)
        for r in rels:
            if r["kind"] in ("conformsTo", "inheritsFrom"):
                conformances[extended.get(r["source"], r["source"])].append(
                    [r["kind"], r["target"], r.get("swiftConstraints")])
        for usr, s in symbols.items():
            if s["kind"]["identifier"] == "swift.extension":
                continue
            facts = {"kind": s["kind"]["identifier"],
                     "declaration": [[f.get("kind"), f.get("spelling"), f.get("preciseIdentifier")]
                                     for f in s.get("declarationFragments", [])],
                     "availability": s.get("availability"), "spi": s.get("spi", False),
                     "access": s.get("accessLevel"), "generics": s.get("swiftGenerics"),
                     "extension": s.get("swiftExtension"),
                     "conformances": sorted(conformances.get(usr, []), key=json.dumps)}
            self.fingerprint[usr] = hashlib.sha1(json.dumps(facts, sort_keys=True).encode()).hexdigest()[:16]
            self.name[usr] = ".".join(s.get("pathComponents") or [usr])
        # The whole public interface, for --validate interface.
        self.interface = hashlib.sha1(json.dumps(sorted(self.fingerprint.items())).encode()).hexdigest()[:16]

    def owner(self, usr):
        """The System declaration a referenced USR stands for: itself, or
        the property whose accessor it is; None when it isn't System's (an
        adopter's own extension member, or a declaration whose signature
        only mentions a System type)."""
        if usr in self.fingerprint:
            return usr
        m = self.ACCESSOR.match(usr)
        if m and m.group(1) + "p" + m.group(2) in self.fingerprint:
            return m.group(1) + "p" + m.group(2)
        return None

    def referenced(self, files):
        """{usr: [fingerprint, name]} for the System declarations an index's
        references name, explicitly or implicitly."""
        out = {}
        for f in files.values():
            for _line, _col, usr, _flags in f["references"]:
                o = self.owner(usr)
                if o and o not in out:
                    out[o] = [self.fingerprint[o], self.name[o]]
        return out

    def check(self, recorded):
        """Of the declarations a cached index recorded, the names of those
        whose fingerprint changed, and of those that are gone."""
        changed, gone = [], []
        for usr, (fp, name) in sorted(recorded.items(), key=lambda kv: kv[1][1]):
            now = self.fingerprint.get(usr)
            if now is None:
                gone.append(name)
            elif now != fp:
                changed.append(name)
        return changed, gone


def some(names, n=3):
    return ", ".join(f"`{x}`" for x in names[:n]) + (f" and {len(names) - n} more" if len(names) > n else "")


# ---------------------------------------------------------------- indexed builds

class Builder:
    def __init__(self, a, pkgs, compiler, decls):
        self.a = a
        self.pkgs = pkgs
        self.compiler = compiler
        self.decls = decls
        self.pathdeps = coverage_module("pathdeps")
        self.package = coverage_module("package")
        self.settings_files = coverage_package_files()
        self.system_tree = tree_of(a.repo, a.head)
        self.system_manifest = git(a.repo, "rev-parse", f"{a.head}:Package.swift").strip()
        # Persistent build directories, one per migration, or None: a
        # scratch build per migration, deleted once read.
        self.builds = a.builds_dir
        self.system_export = None

    def settings(self, pkg):
        info = pkg["adopters"]
        p = self.settings_files.get(info["dir"].lower()) or self.settings_files.get(pkg["key"])
        s = self.package.load(p) if p else {"build-targets": [], "build-flags": [], "unset-env": [],
                                            "variable": re.sub(r"\W", "_", pkg["key"]).upper(),
                                            "skip-targets": [], "skipReasons": {}}
        s["file"] = os.path.relpath(p, UTILITIES) if p else None
        return s

    def put(self, repo, commit, dest, transform):
        """Export a commit into dest and let transform edit it: in place,
        writing only what changed, when builds persist; else afresh."""
        if self.builds:
            sync_export(repo, commit, dest, transform)
        else:
            export(repo, commit, dest)
            transform(dest)

    def system(self):
        """The export of System's head commit that every build's manifest
        points at: with persistent builds, one under the builds directory,
        updated in place, so a build against it recompiles only what the
        change reaches; else one in the scratch directory."""
        if not self.system_export:
            if self.builds:
                dest = os.path.join(self.builds, "system", "swift-system")
                state_path = os.path.join(self.builds, "system", "state.json")
                state = load_json(state_path) if os.path.exists(state_path) else {}
                if state.get("commit") != self.a.head or not os.path.isfile(os.path.join(dest, "Package.swift")):
                    sync_export(self.a.repo, self.a.head, dest)
                    with open(state_path, "w") as f:
                        json.dump({"commit": self.a.head, "tree": self.system_tree}, f)
            else:
                dest = os.path.join(self.a.work, "system", "swift-system")
                if not os.path.isfile(os.path.join(dest, "Package.swift")):
                    export(self.a.repo, self.a.head, dest)
            self.system_export = dest
        return self.system_export

    def is_system(self, target):
        return (os.path.isdir(target) and self.pathdeps.is_swift_system(target, self.a.repo)) or \
            (not os.path.exists(target) and os.path.basename(target) == "swift-system")

    def dep_keys(self, repo, commit, seen):
        """What a commit's path dependencies are, from its manifests in git:
        swift-system (whose commit the cached index records, not the key),
        another clone's commit, or a plain path."""
        keys = []
        listing = git(repo, "ls-tree", "--name-only", commit) or ""
        for name in sorted(x for x in listing.split("\n") if re.match(r"^Package(@swift-[\d.]+)?\.swift$", x)):
            text = git(repo, "show", f"{commit}:{name}", check=False) or ""
            for m in self.pathdeps.PATH_DEP.finditer(text):
                rel = m.group(2)
                target = rel if os.path.isabs(rel) else os.path.normpath(os.path.join(repo, rel))
                if self.is_system(target):
                    keys.append("swift-system")
                    continue
                top = toplevel(target) if os.path.isdir(target) else None
                if top:
                    c = newest_branch(top, self.a.branches)[1] or rev(top, "HEAD")
                    keys.append(f"{os.path.basename(target)}@{c}")
                    if (top, c) not in seen:
                        seen.add((top, c))
                        keys += self.dep_keys(top, c, seen)
                else:
                    keys.append(f"path:{target}")
        return sorted(set(keys))

    def rewrite(self, export_dir, checkout, deps_dir, seen, notes):
        """Point the export's path dependencies at commits: swift-system at the
        head commit's export, another clone at an export of its newest
        migration branch (or its HEAD). Returns the keys the build depends on; `seen`
        gets the exports it made."""
        keys = []
        for manifest in sorted(glob.glob(os.path.join(export_dir, "Package*.swift"))):
            text = open(manifest, encoding="utf-8").read()

            def sub(m):
                rel = m.group(2)
                target = rel if os.path.isabs(rel) else os.path.normpath(os.path.join(checkout, rel))
                if self.is_system(target):
                    keys.append("swift-system")
                    return m.group(1) + json.dumps(self.system())
                top = toplevel(target) if os.path.isdir(target) else None
                if top:
                    commit = newest_branch(top, self.a.branches)[1] or rev(top, "HEAD")
                    dest = os.path.join(deps_dir, os.path.basename(target.rstrip("/")))
                    keys.append(f"{os.path.basename(target)}@{commit}")
                    if dest not in seen:
                        seen.add(dest)
                        sub_keys = []
                        self.put(top, commit, dest, lambda stage: sub_keys.extend(
                            self.rewrite(stage, target, deps_dir, seen, notes)))
                        keys.extend(sub_keys)
                        notes.append(f"{rel} -> {os.path.basename(target)} at {commit[:10]}")
                    return m.group(1) + json.dumps(dest)
                notes.append(f"{rel}: not a clone; left as {target}")
                keys.append(f"path:{target}")
                return m.group(1) + json.dumps(target)

            new = self.pathdeps.PATH_DEP.sub(sub, text)
            if new != text:
                open(manifest, "w", encoding="utf-8").write(new)
        return keys

    def system_block(self, files):
        """What a cached index records of the System it was built against:
        the commit and tree, the manifest, and the fingerprints of the System
        declarations its references name."""
        return {"commit": self.a.head, "tree": self.system_tree, "manifest": self.system_manifest,
                "interface": self.decls.interface if self.decls else None,
                "declarations": self.decls.referenced(files) if self.decls else None}

    def invalid(self, d):
        """Why a cached index built against another System tree doesn't hold
        for this run's, or None when it does (revalidated)."""
        s = d["system"]
        since = f"since {s['commit'][:10]}"
        if d["status"] != "indexed":
            return (f"its build failed{' partway' if d['status'] == 'partial' else ''} against System at "
                    f"{s['commit'][:10]}, which has changed")
        if self.a.validate == "tree":
            return f"System's sources changed {since} (API_GRAPH_ADOPTER_VALIDATE=tree)"
        if s.get("manifest") != self.system_manifest:
            return f"System's Package.swift changed {since}"
        if self.decls is None:
            return "no symbol graphs of the head commit to revalidate against"
        if self.a.validate == "interface":
            return None if s.get("interface") == self.decls.interface else \
                f"System's public interface changed {since} (API_GRAPH_ADOPTER_VALIDATE=interface)"
        if s.get("declarations") is None:
            return "its build recorded no System declarations"
        changed, gone = self.decls.check(s["declarations"])
        if not changed and not gone:
            return None
        n = len(s["declarations"])
        return (f"of its {n} System declarations, " + "; ".join(
            x for x in (f"{len(changed)} changed {since} ({some(changed)})" if changed else "",
                        f"{len(gone)} {'is' if len(gone) == 1 else 'are'} gone ({some(gone)})" if gone else "") if x))

    def plan(self, pkg):
        """Whether a migration's cached index serves this run, and why:
        {decision, reason, entry, key, ...}. The decision is `reused` (built
        against this System tree), `revalidated` (built against another one,
        and every System declaration its references name is unchanged), or
        `rebuild`."""
        a = self.a
        info = pkg["adopters"]
        s = self.settings(pkg)
        exec_var = f"{s['variable']}_SWIFT_EXEC"
        swift_exec = os.environ.get(exec_var) or (newest_toolchain() if s.get("build-hint") else None)
        settings_text = json.dumps({k: s.get(k) for k in ("build-targets", "build-flags", "unset-env")},
                                   sort_keys=True)
        # The key: everything the build depends on but System, whose tree
        # and declarations the entry records instead. An earlier version of
        # this tool keyed on System's tree; its entries are still read.
        deps = self.dep_keys(info["path"], info["commit"], set())
        key = [info["commit"], self.compiler, swift_exec or "", settings_text, READER_VERSION, deps]
        legacy = [info["commit"], self.system_tree, self.compiler, swift_exec or "", settings_text, READER_VERSION,
                  sorted(set(f"swift-system@{self.system_tree}" if k == "swift-system" else k for k in deps))]
        plan = {"key": key, "deps": deps, "settings": s, "swiftExec": swift_exec, "entry": None,
                "config": {"compiler": self.compiler, "swiftExec": swift_exec, "settings": settings_text},
                "decision": "rebuild", "reason": "no cached index of this commit"}
        cache_dir = os.path.join(a.cache, pkg["key"])
        entries = []
        for p in sorted(glob.glob(os.path.join(cache_dir, info["commit"] + "-*.json.gz")),
                        key=os.path.getmtime, reverse=True):
            try:
                entries.append((p, load_json(p)))
            except (OSError, ValueError):
                continue

        def use(d, decision, reason):
            plan.update(entry=d, decision=decision, reason=reason)
            return plan

        if a.rebuild:
            plan["reason"] = "--rebuild"
            return plan
        if a.builds == "reuse" and entries:
            return use(entries[0][1], "reused", "the latest cached index of this commit (--builds reuse)")
        mine = [d for _p, d in entries if d.get("baseKey") == json.loads(json.dumps(key)) and d.get("system")]
        for d in mine:
            if d["system"]["tree"] == self.system_tree:
                return use(d, "reused", f"built against this System tree, at {d['system']['commit'][:10]}")
        for _p, d in entries:
            if d.get("baseKey") == json.loads(json.dumps(legacy)):
                # The previous version's entry for this very tree: record the
                # declarations it names now, as its own build would have.
                d = dict(d, baseKey=key, system=self.system_block(d["files"]))
                self.store(pkg, d)
                return use(d, "reused", "built against this System tree, by the previous version of this tool")
        reasons = []
        for d in mine:
            why = self.invalid(d)
            if why is None:
                n = len(d["system"].get("declarations") or {})
                return use(d, "revalidated", f"built against System at {d['system']['commit'][:10]}; "
                                             f"its {n} System declarations are unchanged")
            reasons.append(why)
        if reasons:
            plan["reason"] = reasons[0]
        elif any("system" not in d for _p, d in entries):
            plan["reason"] = "cached by the previous version of this tool, which keyed on System's tree"
        elif entries:
            plan["reason"] = "the cached indexes of this commit are for other settings, toolchains or dependencies"
        return plan

    def store(self, pkg, result):
        """File a cache entry: one per package commit, key and System tree."""
        cache_dir = os.path.join(self.a.cache, pkg["key"])
        os.makedirs(cache_dir, exist_ok=True)
        name = (pkg["adopters"]["commit"] + "-" + hashlib.sha1(json.dumps(result["baseKey"]).encode()).hexdigest()[:12]
                + "-" + result["system"]["tree"] + ".json.gz")
        with gzip.open(os.path.join(cache_dir, name), "wt", encoding="utf-8") as f:
            json.dump(result, f)

    def last_seconds(self, pkg):
        """How long the package's last recorded build took, from its newest
        cache entry, which the builds are ordered by; None if it has none."""
        for path in sorted(glob.glob(os.path.join(self.a.cache, pkg["key"], "*.json.gz")),
                           key=os.path.getmtime, reverse=True):
            try:
                seconds = (load_json(path).get("build") or {}).get("seconds")
            except (OSError, ValueError):
                continue
            if seconds is not None:
                return seconds
        return None

    def index(self, pkg, plan):
        """{status, files, symbols, build}, from the cache or a build. Safe to
        run for several packages at once, once system() has run."""
        a = self.a
        info = pkg["adopters"]
        s, swift_exec, base_key = plan["settings"], plan["swiftExec"], plan["key"]
        if plan["entry"] is not None:
            cached = plan["entry"]
            cached["build"] = dict(cached["build"], cached=True, decision=plan["decision"],
                                   decisionReason=plan["reason"],
                                   builtAgainst=(cached.get("system") or {}).get("commit"))
            return cached
        if a.builds != "build":
            return {"status": "not built", "files": {}, "symbols": {},
                    "build": {"status": "not built", "reason": f"--builds {a.builds}", "settings": s["file"],
                              "decision": "not built", "decisionReason": plan["reason"]}}
        where = self.builds or a.work
        free = shutil.disk_usage(where if os.path.isdir(where) else os.path.dirname(where)).free / 2 ** 30
        if free < a.min_free_gb:
            return {"status": "not built", "files": {}, "symbols": {},
                    "build": {"status": "not built", "reason": f"{free:.1f} GiB free, under {a.min_free_gb}",
                              "settings": s["file"], "decision": "not built", "decisionReason": plan["reason"]}}
        if self.builds:
            # Kept: the export is updated in place and the build is incremental.
            w = os.path.join(self.builds, pkg["key"])
        else:
            w = os.path.join(a.work, "adopters", pkg["key"])
            shutil.rmtree(w, ignore_errors=True)
        os.makedirs(w, exist_ok=True)
        # The export's directory is named as the clone's is: a root package's
        # identity is its directory's name, and it has to match the package's
        # own when the package is also a dependency (swift-argument-parser is
        # swift-system's).
        src, build, log = os.path.join(w, info["dir"]), os.path.join(w, "build"), os.path.join(w, "build.log")
        deps_dir, state_path = os.path.join(w, "deps"), os.path.join(w, "state.json")
        state = {}
        if self.builds and os.path.exists(state_path):
            try:
                state = load_json(state_path)
            except ValueError:
                pass
        t0 = time.time()
        open(log, "w").close()
        self.system()
        # Re-exported only when the commit or a path dependency's commit
        # moved: SwiftPM then rebuilds only what the changed files reach.
        notes, lowered = list(state.get("notes") or []), bool(state.get("lowered"))
        if not (state.get("commit") == info["commit"] and state.get("deps") == plan["deps"]
                and os.path.isfile(os.path.join(src, "Package.swift"))):
            notes, seen = [], set()

            def transform(stage):
                self.rewrite(stage, info["path"], deps_dir, seen, notes)
                if lowered and lower_tools_version(stage):
                    notes.append(TOOLS_NOTE % SWIFT_VERSION)
            self.put(info["path"], info["commit"], src, transform)
            for d in sorted(os.listdir(deps_dir)) if os.path.isdir(deps_dir) else []:
                if os.path.join(deps_dir, d) not in seen:
                    shutil.rmtree(os.path.join(deps_dir, d), ignore_errors=True)   # a dependency it dropped
        # A build directory is started over when what it was built with
        # changed: another compiler or settings, or another manifest (the
        # targets may differ), whose index units would otherwise linger.
        start = "cold"
        if os.path.isdir(build):
            if not state:
                start = "cold: no record of how the build directory was built"
            elif state.get("config") != plan["config"]:
                start = "cold: the compiler or the build settings changed"
            elif state.get("manifest") != manifest_digest(src):
                start = "cold: the package's manifest changed"
            else:
                start = "incremental"
            if start != "incremental":
                shutil.rmtree(build)
        if start == "incremental":
            # SwiftPM plans a build again when a root package's files come or
            # go, or its manifest changes, but not when a path dependency's
            # files do (System's, when the head commit adds or removes one): the
            # old plan would name a file that's gone, or leave out a new one. A
            # manifest dated now makes it plan again.
            now = time.time()
            for manifest in glob.glob(os.path.join(src, "Package*.swift")):
                os.utime(manifest, (now, now))
        env = dict(os.environ)
        for v in s.get("unset-env", []):
            env.pop(v, None)
        if swift_exec:
            env["SWIFT_EXEC"] = swift_exec
            env["SWIFT_EXEC_MANIFEST"] = run(["xcrun", "--find", "swiftc"])[1].strip()
        swiftpm = ["--disable-sandbox", "--package-path", src, "--scratch-path", build]
        flags = list(s.get("build-flags", []))
        targets = list(s.get("build-targets", []))
        status, reason = "indexed", None
        if targets == [":libraries"]:
            code, out = run(["swift", "package", *swiftpm, *flags, "dump-package"], env=env)
            if code != 0 and lower_tools_version(src):
                # A manifest for newer tools than these reads with its tools version lowered.
                lowered = True
                notes.append(TOOLS_NOTE % SWIFT_VERSION)
                code, out = run(["swift", "package", *swiftpm, *flags, "dump-package"], env=env)
            targets = self.package.library_roots(s, json.loads(out)) if code == 0 else []
            if code != 0:
                status, reason = "failed", "swift package dump-package failed"
        built_targets = []
        if status == "indexed":
            for t in (targets or [None]):
                cmd = ["swift", "build", *swiftpm, *flags] + (["--target", t] if t else [])
                code, _ = run(cmd, env=env, log=log)
                if code != 0:
                    status = "failed"
                    errs = [ln for ln in open(log, encoding="utf-8", errors="replace").read().split("\n")
                            if "error:" in ln]
                    reason = (f"swift build{' --target ' + t if t else ''} failed: "
                              + (re.sub(r"^.*?error: ", "", errs[0])[:200] if errs else "see the log"))
                    break
                built_targets.append(t or "(all)")
        store = next((p for p in glob.glob(os.path.join(build, "*", "*", "index", "store"))), None)
        files, symbols, n_records = {}, {}, 0
        if store:
            def keep(usr, rel, is_c):
                return not is_c and any(m in usr for m in SYSTEM_MODULES)
            with READ_LOCK:
                files, symbols, _defs, n_records = index_refs.read_store(store, src, keep, definitions_too=False)
            if status == "failed" and files:
                status = "partial"
        elif status == "indexed":
            status, reason = "failed", "the build left no index store"
        tail = open(log, encoding="utf-8", errors="replace").read().split("\n")[-30:] if os.path.exists(log) else []
        seconds = round(time.time() - t0)
        result = {
            "baseKey": base_key, "status": status,
            "files": files, "symbols": symbols,
            "build": {"status": status, "reason": reason, "seconds": seconds, "start": start,
                      "targets": built_targets, "requestedTargets": targets, "flags": flags,
                      "swiftExec": swift_exec, "compiler": self.compiler, "settings": s["file"],
                      "pathDependencies": notes, "records": n_records, "date": datetime.date.today().isoformat(),
                      "logTail": tail if status != "indexed" else [], "cached": False},
            "system": self.system_block(files),
        }
        self.store(pkg, result)
        if self.builds:
            kb = disk_kb(w)
            with open(state_path, "w") as f:
                json.dump({"commit": info["commit"], "deps": plan["deps"], "config": plan["config"],
                           "manifest": manifest_digest(src), "lowered": lowered, "notes": notes,
                           "system": a.head, "status": status, "seconds": seconds, "start": start, "kb": kb,
                           "date": datetime.date.today().isoformat()}, f, indent=1)
            result["build"]["diskMB"] = round(kb / 1024) if kb else None
        else:
            # A scratch build: gone as soon as it's read (SwiftPM's is up to about 2 GB).
            shutil.rmtree(w, ignore_errors=True)
        result["build"] = dict(result["build"], decision="rebuilt", decisionReason=plan["reason"],
                               builtAgainst=a.head)
        return result


def follow_dependencies(plans, pkgs):
    """A revalidated index whose build compiled another migration (a path
    dependency on its clone, at its branch) holds only if that migration's
    does too: the dependency's sources were compiled against System as
    well, and its own references are what its plan checked."""
    by_dep = {f"{pkgs[k]['adopters']['dir']}@{pkgs[k]['adopters']['commit']}": k for k in plans}
    moved = True
    while moved:
        moved = False
        for p in plans.values():
            if p["decision"] != "revalidated":
                continue
            dep = next((by_dep[d] for d in p["deps"] if by_dep.get(d) and plans[by_dep[d]]["decision"] == "rebuild"),
                       None)
            if dep:
                p.update(decision="rebuild", entry=None, reason=f"its path dependency {dep} is rebuilt")
                moved = True


# ---------------------------------------------------------------- #if, three-valued

class Conditions:
    """Whether a line is compiled in the macOS arm64 debug build the index
    comes from: True, False, or None when a condition can't be decided
    lexically (a package's own flags, canImport of a module that isn't a
    platform's C library)."""

    TOKEN = re.compile(r"\s*(\|\||&&|!|\(|\)|[A-Za-z_$][\w$]*(?:\([^()]*\))?)")
    NOT_ON_DARWIN = {"Glibc", "Musl", "Android", "Bionic", "WinSDK", "ucrt", "CRT", "WASILibc", "wasi_pthread",
                     "Foundation_Linux"}
    ON_DARWIN = {"Darwin", "Dispatch", "Foundation", "ObjectiveC", "os", "SystemPackage", "System", "XCTest",
                 "Synchronization", "CoreFoundation", "Security", "Testing"}

    def __init__(self):
        self.memo = {}

    def value(self, text):
        if text not in self.memo:
            try:
                toks, pos = [], 0
                while pos < len(text):
                    m = self.TOKEN.match(text, pos)
                    if not m:
                        raise ValueError(text)
                    toks.append(m.group(1))
                    pos = m.end()
                    while pos < len(text) and text[pos].isspace():
                        pos += 1
                self.toks, self.k = toks, 0
                v = self._or()
                self.memo[text] = v if self.k == len(toks) else None
            except (ValueError, IndexError):
                self.memo[text] = None
        return self.memo[text]

    def _peek(self):
        return self.toks[self.k] if self.k < len(self.toks) else None

    def _or(self):
        v = self._and()
        while self._peek() == "||":
            self.k += 1
            r = self._and()
            v = True if (v is True or r is True) else (False if (v is False and r is False) else None)
        return v

    def _and(self):
        v = self._not()
        while self._peek() == "&&":
            self.k += 1
            r = self._not()
            v = False if (v is False or r is False) else (True if (v is True and r is True) else None)
        return v

    def _not(self):
        if self._peek() == "!":
            self.k += 1
            v = self._not()
            return None if v is None else not v
        if self._peek() == "(":
            self.k += 1
            v = self._or()
            if self._peek() != ")":
                raise ValueError("unbalanced")
            self.k += 1
            return v
        tok = self._peek()
        if tok is None:
            raise ValueError("empty")
        self.k += 1
        return self.atom(tok)

    def atom(self, tok):
        m = re.match(r"(\w+)\((.*)\)$", tok)
        if not m:
            return {"DEBUG": True, "true": True, "false": False}.get(tok)
        fn, arg = m.group(1), m.group(2).strip()
        if fn == "os":
            return arg == "macOS"
        if fn == "canImport":
            name = arg.split(",")[0].strip()
            return True if name in self.ON_DARWIN else (False if name in self.NOT_ON_DARWIN else None)
        if fn in ("compiler", "swift"):
            mm = re.match(r"(>=|<)\s*([\d.]+)", arg)
            if not mm:
                return None
            want = tuple(int(x) for x in mm.group(2).split(".")[:2])
            return (SWIFT_VERSION >= want) if mm.group(1) == ">=" else (SWIFT_VERSION < want)
        if fn == "arch":
            return arg == "arm64"
        if fn == "_endian":
            return arg == "little"
        if fn == "_pointerBitWidth":
            return arg == "_64"
        if fn == "_runtime":
            return True
        if fn == "targetEnvironment":
            return False
        return None

    def darwin_lines(self, code_lines):
        """For each line (1-based), whether the Darwin build compiles it."""
        out = [True]
        stack = []   # [previous conditions, current condition or None for #else]
        for line in code_lines:
            s = line.strip()
            m = re.match(r"^#(if|elseif|else|endif)\b(.*)$", s)
            if m:
                kw, rest = m.group(1), m.group(2).strip()
                if kw == "if":
                    stack.append([[], rest])
                elif kw == "elseif" and stack:
                    stack[-1] = [stack[-1][0] + [stack[-1][1]], rest]
                elif kw == "else" and stack:
                    stack[-1] = [stack[-1][0] + [stack[-1][1]], None]
                elif kw == "endif" and stack:
                    stack.pop()
                out.append(None)
                continue
            v = True
            for prev, cur in stack:
                vals = [self.value(c) for c in prev]
                if any(x is True for x in vals):
                    here = False
                elif all(x is False for x in vals):
                    here = True if cur is None else self.value(cur)
                else:
                    here = None if cur is None or self.value(cur) is not False else False
                if here is False:
                    v = False
                    break
                if here is None:
                    v = None
            out.append(v)
        return out


# ---------------------------------------------------------------- lexical System uses

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"


def split_title(title):
    """'setOwner(user:group:)' -> ('setOwner', ['user', 'group']); a
    property or case -> (name, None)."""
    m = re.match(r"^([^(]+)\((.*)\)$", title)
    if not m:
        return title, None
    return m.group(1), [x for x in m.group(2).split(":") if x != ""]


def top_level_split(text):
    """Split at the commas outside brackets; `->` isn't a closing `>`."""
    parts, depth, cur, prev = [], 0, [], ""
    for ch in text:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}" or (ch == ">" and prev != "-"):
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
        prev = ch
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


def has_default(typ):
    """Whether a parameter's type text is followed by `= default`."""
    depth, prev = 0, ""
    for k, ch in enumerate(typ):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "=" and depth == 0 and prev not in "=!<>" and typ[k + 1:k + 2] != "=":
            return True
        prev = ch
    return False


def decl_params(decl, base):
    """[(label, optional)] for a function or initializer declaration's
    parameters: optional when it has a default, or is a closure a trailing
    closure can supply. None when the text doesn't parse."""
    m = re.search(rf"\b{re.escape(base)}\s*(?:<[^()]*>)?\s*\(", decl)
    if not m:
        return None
    depth, k = 0, m.end() - 1
    for k in range(m.end() - 1, len(decl)):
        if decl[k] == "(":
            depth += 1
        elif decl[k] == ")":
            depth -= 1
            if depth == 0:
                break
    inner = decl[m.end():k]
    out = []
    for prm in top_level_split(inner):
        head, _, typ = prm.partition(":")
        names = head.split()
        if not names:
            return None
        label = names[0]
        default = has_default(typ)
        out.append((label, default or "->" in typ))
    return out


def call_labels(code, start):
    """The argument labels of the call whose `(` is at code[start]: '_' for
    an unlabeled argument. None when the parentheses don't close."""
    depth, k, labels, arg_start = 0, start, [], start + 1
    n = len(code)
    while k < n:
        ch = code[k]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                seg = code[arg_start:k].strip()
                if seg:
                    labels.append(label_of(seg))
                return labels
        elif ch == "," and depth == 1:
            labels.append(label_of(code[arg_start:k].strip()))
            arg_start = k + 1
        k += 1
    return None


def label_of(seg):
    m = re.match(rf"^({IDENT})\s*:(?!:)", seg)
    return m.group(1) if m else "_"


def labels_fit(call, params):
    """Whether a call's labels supply the declaration's parameters in
    order, leaving out only defaulted ones and trailing closures."""
    if call is None or params is None:
        return True
    j = 0
    for label, optional in params:
        if j < len(call) and call[j] == label:
            j += 1
        elif not optional:
            return False
    return j == len(call)


def library_names(cache_dir, compiler):
    """The names the Swift libraries a package sees declare (Swift,
    _Concurrency, Synchronization, Dispatch, Foundation), from their symbol
    graphs, extracted once per SDK and compiler and kept in the cache."""
    sdk = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"])[1].strip()
    key = hashlib.sha1((sdk + compiler).encode()).hexdigest()[:12]
    path = os.path.join(cache_dir, f"swift-library-names-{key}.json")
    if os.path.exists(path):
        return set(load_json(path))
    tmp = os.path.join(cache_dir, "symbolgraphs-tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    names = set()
    for module in ("Swift", "_Concurrency", "Synchronization", "Dispatch", "Foundation"):
        run(["xcrun", "swift-symbolgraph-extract", "-module-name", module, "-target", "arm64-apple-macosx26.0",
             "-sdk", sdk, "-output-dir", tmp])
    for f in glob.glob(os.path.join(tmp, "*.symbols.json")):
        for sym in load_json(f).get("symbols", []):
            comps = sym.get("pathComponents") or []
            if comps:
                names.add(re.sub(r"\(.*$", "", comps[-1]))
    shutil.rmtree(tmp, ignore_errors=True)
    if names:
        json.dump(sorted(names), open(path, "w"))
    return names


class LexicalMatcher:
    """Uses of the graph's declarations in a line of Swift, by name.

    - A qualified type path (`PThread.Mutex`, `FileDescriptor.StatusFlags`,
      after an optional `SystemPackage.`) names that type; a member after it
      (`PThread.Mutex.Kind.errorChecking`) names that member; `Type(` names
      the type's initializers whose parameters the call's labels supply.
    - An unqualified name counts only if it's distinctive: no declaration on
      the base commit has it, the package doesn't declare it, the Swift
      libraries don't (so not `union` or `lazy`), it isn't in COMMON_NAMES
      or COMMON_TYPES, and it's at least four characters long. A member
      (`.lockForWriting()`) then matches the new declarations of that name
      whose parameters the call supplies, when they're all of one type; an
      implicit member (`.errorChecking`) only when exactly one does.
    """

    MODULES = ("SystemPackage", "System", "SystemSockets")

    def __init__(self, nodes, base_names, library):
        self.types = {}                                  # path -> nid
        self.type_last = collections.defaultdict(list)   # last component -> [nid]
        self.members = collections.defaultdict(list)     # (parent path, base) -> [(nid, params)]
        self.by_base = collections.defaultdict(list)     # base -> [(nid, params, parent)]
        self.base_names = base_names
        self.library = library
        for nid, n in nodes.items():
            if n["hiddenClass"] == "unavailable":
                continue
            if n["isType"]:
                self.types[n["path"]] = nid
                self.type_last[n["path"].split(".")[-1]].append(nid)
                continue
            base, labels = split_title(n["title"])
            params = None
            if labels is not None:
                params = decl_params(n["decl"], "init" if base == "init" else base) \
                    or [(x, False) for x in labels]
            parent = n["parentPath"] or ""
            self.members[(parent, base)].append((nid, params))
            self.by_base[base].append((nid, params, parent))

    def distinctive(self, name, own):
        return (len(name) >= 4 and name not in COMMON_NAMES and name not in COMMON_TYPES
                and name not in self.base_names and name not in own and name not in self.library)

    def match(self, code, line_start, line_end, own):
        """[(nid, column, how)] for code[line_start:line_end], where code is
        the file's blanked text (calls can run past the line)."""
        seg = code[line_start:line_end]
        out = []
        taken = []   # spans a qualified match explains
        for m in re.finditer(rf"(?<![\w.])({IDENT}(?:\s*\.\s*{IDENT})+)", seg):
            parts = [x.strip() for x in m.group(1).split(".")]
            col = m.start(1) + 1
            if parts[0] in self.MODULES and len(parts) > 1:
                parts = parts[1:]
            for k in range(len(parts), 0, -1):
                path = ".".join(parts[:k])
                rest = parts[k:]
                tid = self.types.get(path)
                if tid:
                    out.append((tid, col, "qualified type"))
                    if rest:
                        out += self._fit(self.members.get((path, rest[0]), []), code, line_start + m.end(1), col,
                                         "qualified member", qualified=True)
                    elif re.match(r"\s*\(", seg[m.end(1):]):
                        out += self._fit(self.members.get((path, "init"), []), code, line_start + m.end(1), col,
                                         "initializer", qualified=True)
                    taken.append((m.start(1), m.end(1)))
                    break
                if rest and path[0].isupper() and (path, rest[0]) in self.members:
                    out += self._fit(self.members[(path, rest[0])], code, line_start + m.end(1), col,
                                     "qualified member", qualified=True)
                    taken.append((m.start(1), m.end(1)))
                    break
        for m in re.finditer(rf"(\.)?\b({IDENT})\b", seg):
            name = m.group(2)
            if any(s_ <= m.start() < e_ for s_, e_ in taken):
                continue
            col = m.start(2) + 1
            if m.group(1):
                if not self.distinctive(name, own) or name not in self.by_base:
                    continue
                before = seg[:m.start()].rstrip()
                implicit = not before or not re.search(r"[\w)\]?!]$", before)
                cands = [(nid, params) for nid, params, _ in self.by_base[name]]
                hits = self._fit(cands, code, line_start + m.end(2), col, "member")
                parents = {p for nid, _, p in self.by_base[name] if any(h[0] == nid for h in hits)}
                if len(parents) > 1 or (implicit and len(hits) != 1):
                    continue   # several types have it: which one, only the compiler knows
                out += [(nid, c_, "implicit member" if implicit else how) for nid, c_, how in hits]
            elif name[0].isupper():
                ids = self.type_last.get(name, [])
                if len(ids) == 1 and self.distinctive(name, own):
                    out.append((ids[0], col, "type"))
            else:
                if not self.distinctive(name, own) or name not in self.by_base:
                    continue
                cands = [(nid, params) for nid, params, parent in self.by_base[name] if not parent]
                if cands and re.match(r"\s*\(", seg[m.end(2):]):
                    out += self._fit(cands, code, line_start + m.end(2), col, "function")
        return out

    def _fit(self, cands, code, after, col, how, qualified=False):
        """The candidates the use fits: a call (`name(...)`) fits a function
        or initializer whose parameters its labels supply, and a bare name a
        property or enum case. Qualified, a call can also be to a property
        of function type (`Memory.reallocateFunction(...)`)."""
        k = after
        while k < len(code) and code[k] in " \t":
            k += 1
        called = k < len(code) and code[k] == "("
        labels = call_labels(code, k) if called else None
        fit = [nid for nid, params in cands
               if (params is not None) == called and (not called or labels_fit(labels, params))]
        if not fit and called and qualified:
            fit = [nid for nid, params in cands if params is None]
        return [(nid, col, how) for nid in fit]


DECL_RE = r"\b(?:func|var|let|case|class|struct|enum|protocol|typealias|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"


def declared_names(commit_obj, files=None):
    """Names the package declares, lexically: in the given files, or with
    `git grep`, in all of its Swift files."""
    out = set()
    if files is None:
        code, text = run(["git", "-C", commit_obj.repo, "grep", "-h", "-o", "-E",
                          "(func|var|let|case|class|struct|enum|protocol|typealias|actor)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*",
                          commit_obj.commit, "--", "*.swift"])
        for line in text.split("\n"):
            m = re.search(DECL_RE, line)
            if m:
                out.add(m.group(1))
        return out
    for rel in files:
        t = commit_obj.text(rel)
        if t:
            out.update(re.findall(DECL_RE, t))
    return out


# ---------------------------------------------------------------- diffs and hunks

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


def parse_diff(text):
    """{new path: {old, status, hunks: [{header, oldStart, oldCount, newStart,
    newCount, lines}], added: {new line numbers}}}"""
    files = {}
    cur = hunk = old_path = None
    rem_old = rem_new = 0
    for line in text.split("\n"):
        if hunk is not None and (rem_old > 0 or rem_new > 0):
            if line.startswith("+"):
                cur["added"].add(new_line)
                hunk["lines"].append(line)
                new_line += 1
                rem_new -= 1
                continue
            if line.startswith("-"):
                hunk["lines"].append(line)
                rem_old -= 1
                continue
            if line.startswith(" "):
                hunk["lines"].append(line)
                new_line += 1
                rem_old -= 1
                rem_new -= 1
                continue
            if line.startswith("\\"):
                continue
        hunk = None
        if line.startswith("diff --git "):
            cur = old_path = None
            continue
        if line.startswith("--- "):
            # A path with a space in it ends in a tab.
            p_ = line[4:-1] if line.endswith("\t") else line[4:]
            old_path = None if p_ == "/dev/null" else (p_[2:] if p_.startswith("a/") else p_)
            continue
        if line.startswith("+++ "):
            p_ = line[4:-1] if line.endswith("\t") else line[4:]
            if p_ == "/dev/null":
                cur = None
                continue
            new = p_[2:] if p_.startswith("b/") else p_
            cur = files.setdefault(new, {"old": old_path, "status": "added" if old_path is None else "modified",
                                         "hunks": [], "added": set()})
            continue
        m = HUNK.match(line)
        if m and cur is not None:
            hunk = {"header": line, "oldStart": int(m.group(1)),
                    "oldCount": int(m.group(2)) if m.group(2) is not None else 1,
                    "newStart": int(m.group(3)),
                    "newCount": int(m.group(4)) if m.group(4) is not None else 1, "lines": []}
            rem_old, rem_new, new_line = hunk["oldCount"], hunk["newCount"], hunk["newStart"]
            cur["hunks"].append(hunk)
    return files


def line_map(diff_files):
    """{old path: (new path, [(oldStart, oldCount, newStart, newCount)])} from
    a -U0 diff, for map_line."""
    return {(f["old"] or path): (path, [(h["oldStart"], h["oldCount"], h["newStart"], h["newCount"])
                                        for h in f["hunks"]]) for path, f in diff_files.items()}


def map_line(hunks, line):
    """The line's number after the diff, or None if the diff changed it."""
    delta = 0
    for o0, oc, _n0, nc in hunks:
        if oc > 0:
            if o0 <= line <= o0 + oc - 1:
                return None
            if o0 + oc - 1 < line:
                delta += nc - oc
        elif o0 < line:
            delta += nc
    return line + delta


# ---------------------------------------------------------------- would benefit: C names

C_FILES = (".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".m", ".mm", ".def", ".inc")


def join_tables(cn):
    """From cnames.json: {nid: {names, restricted, baseCovered}} (what each
    declaration's would-benefit sites are joined on, and what's left out),
    {name: [nid]} for the join, and every wrapped name with its kinds.
    Only stated links count, from a doc sentence or a typealias: a code-only
    link says what a declaration's implementation touches, not that it
    stands for the C interface. Fields don't either: the coverage tools
    record a use of one as a member of its struct's interface."""
    per = collections.defaultdict(lambda: {"names": set(), "restricted": set(), "baseCovered": set()})
    joined = set()
    for w in cn["wraps"]:
        if w["cKind"] == "field" or not any(s in ("doc", "typealias") for s in w.get("sources") or ["doc"]):
            continue
        joined.add(w["name"])
        rec = per[w["node"]]
        if w["restricted"]:
            rec["restricted"].add(w["name"])
        elif cn["names"][w["name"]]["baseCovered"]:
            rec["baseCovered"].add(w["name"])
        else:
            rec["names"].add(w["name"])
    per = {k: {kk: sorted(vv - (v["names"] if kk != "names" else set())) for kk, vv in v.items()}
           for k, v in per.items()}
    name_nodes = collections.defaultdict(list)
    for nid, v in per.items():
        for nm in v["names"]:
            name_nodes[nm].append(nid)
    kinds = {n: v["kinds"] for n, v in cn["names"].items() if n in joined}
    return per, name_nodes, kinds


def interfaces_for(results, commit):
    """The newest coverage extraction of a package commit, from the results
    store: (path, data) or (None, None)."""
    cands = glob.glob(os.path.join(results, "results", "*", commit, "*", "*", "interfaces.json.gz"))
    if not cands:
        return None, None
    best = max(cands, key=os.path.getmtime)
    return best, load_json(best)


def lexical_interfaces(commit_obj, kinds, library):
    """A lexical stand-in for the coverage extraction, for a package the
    store has no extraction of: uses of the given C names in its library
    Swift sources (under Sources/, outside comments and strings), where the
    spelling says it's the C name: a function called (`name(`, not after a
    `.`), a constant or type spelled as C spells them (upper case, or with
    an underscore: `O_CLOEXEC`, `pthread_t`), or another type in a type
    position. Names the package declares don't count, nor, unless they have
    an underscore, names the Swift libraries declare."""
    listing = git(commit_obj.repo, "ls-tree", "-r", "--name-only", commit_obj.commit) or ""
    files = [f for f in listing.split("\n") if f.endswith(".swift") and f.startswith("Sources/")
             and "/Tests/" not in f]
    own = declared_names(commit_obj)
    want = {n: k for n, k in kinds.items() if n not in own}
    if not want:
        return []
    pat = re.compile(r"(?<![\w.])(" + "|".join(sorted(map(re.escape, want), key=len, reverse=True)) + r")\b")
    sites = collections.defaultdict(list)
    for rel in files:
        t = commit_obj.text(rel)
        if not t or not pat.search(t):
            continue
        code = ss.strip_comments_and_strings(t)[0]
        for k, line in enumerate(code.split("\n"), 1):
            for m in pat.finditer(line):
                name = m.group(1)
                ks = want[name]
                after = line[m.end():].lstrip()
                before = line[:m.start()].rstrip()
                c_like = "_" in name or name.isupper()
                ok = ("function" in ks and after.startswith("(")) or \
                     (bool({"constant", "macro", "type", "error", "variable"} & set(ks))
                      and (c_like or (name not in library and "type" in ks
                                      and re.search(r"(:|<|\[|->|\bas|\bis)$", before))))
                if ok and (c_like or after.startswith("(") or name not in library):
                    sites[name].append({"file": rel, "line": k, "target": rel.split("/")[1] if "/" in rel else "",
                                        "platforms": {}, "evidence": "lexical-name"})
    return [{"name": n, "sites": v} for n, v in sorted(sites.items())]


# ---------------------------------------------------------------- adopted sites

def own_sources(co):
    """The examples' diff stand-in: every Swift file under Sources at the
    commit, each line of it added, with no hunks (there's no merge base to
    diff against: all of it is the package's own)."""
    listing = git(co.repo, "ls-tree", "-r", "--name-only", co.commit, "--", "Sources") or ""
    return {f: {"old": f, "status": "A", "hunks": [], "added": set(range(1, len(co.lines(f)) + 1))}
            for f in listing.split("\n") if f.endswith(".swift")}


def migration_sites(key, p, idx, usr_node, matcher, conds):
    """One migration's adopted sites, from its index and lexically, with
    the hunks they cite: {sites, hunks, adopted}. `conds` is the caller's
    own, since its parser keeps state. The examples (`examples` in the
    info) have no merge base: every line of their Sources counts as theirs,
    so the lexical pass reads all the lines the Darwin build doesn't
    compile, and no site cites a hunk."""
    info = p["adopters"]
    repo, commit, base = info["path"], info["commit"], info["base"]
    co = Commit(repo, commit)
    if info.get("examples"):
        diff = own_sources(co)
    else:
        diff_text = git(repo, "-c", "core.quotePath=false", "diff", "--no-ext-diff", "--no-textconv", "--no-color",
                        "--src-prefix=a/", "--dst-prefix=b/", "--find-renames", "-U3", base, commit) if base else ""
        diff = parse_diff(diff_text)
    swift_changed = sorted(f for f in diff if f.endswith(".swift"))
    indexed = set(idx["files"])
    symbols = idx["symbols"]
    own = declared_names(co)
    sites, hunks = [], {}

    # Hunk ids, per file, in order.
    hunk_at = {}
    for f, fd in diff.items():
        for k, h in enumerate(fd["hunks"]):
            hid = f"{key}:{f}#{k}"
            hunk_at.setdefault(f, []).append((h["newStart"], h["newStart"] + max(h["newCount"], 1) - 1, hid, h))

    def hunk_for(f, line):
        for s_, e_, hid, h in hunk_at.get(f, []):
            if s_ <= line <= e_:
                if hid not in hunks:
                    hunks[hid] = {"package": key, "file": f, "oldFile": diff[f]["old"], "header": h["header"],
                                  "oldStart": h["oldStart"], "oldCount": h["oldCount"],
                                  "newStart": h["newStart"], "newCount": h["newCount"], "lines": h["lines"]}
                return hid
        return None

    seen = set()
    counts = collections.Counter()

    def add(f, line, col, nid, resolution, how=None, qualifier=False):
        k_ = (f, line, nid)
        if k_ in seen:
            return
        seen.add(k_)
        lines = co.lines(f)
        text = lines[line - 1].strip() if 0 < line <= len(lines) else ""
        introduced = line in diff.get(f, {}).get("added", ())
        sites.append({"package": key, "file": f, "line": line, "column": col, "node": nid,
                      "resolution": resolution, "how": how, "qualifier": qualifier, "introduced": introduced,
                      "hunk": hunk_for(f, line), "text": text[:240]})
        counts["qualifier" if qualifier else resolution] += 1

    # Precise: the index's references to the nodes' USRs. A type named
    # only to qualify another reference right after it (`PThread` in
    # `PThread.Mutex`) is recorded as a qualifier, and implicit
    # references (accessors a property use calls) are dropped. Only a
    # type is a qualifier: a property or method before another reference
    # (`ProcessID.current` in `ProcessID.current.rawValue`) is a use.
    for rel, fdata in sorted(idx["files"].items()):
        refs = fdata["references"]
        at_col = {(l_, c_) for l_, c_, _u, _f in refs}
        lines = co.lines(rel)
        for line, col, usr, flags in refs:
            if flags & ROLE_IMPLICIT:
                continue
            nid = usr_node.get(usr)
            if not nid:
                continue
            sym = symbols.get(usr, {})
            name = re.sub(r"\(.*$", "", sym.get("name", ""))
            text = lines[line - 1] if 0 < line <= len(lines) else ""
            qual = False
            if name and sym.get("kind") in TYPE_SYMBOL_KINDS and text[col - 1:col - 1 + len(name)] == name:
                after = col + len(name)
                if text[after - 1:after] == "." and (line, after + 1) in at_col:
                    qual = True
            add(rel, line, col, nid, "precise", qualifier=qual)

    # Lexical: the lines the migration added, in files the build didn't
    # compile, and in `#if` branches the Darwin build doesn't take.
    for rel in swift_changed:
        added = sorted(diff[rel]["added"])
        if not added:
            continue
        raw = co.text(rel)
        if raw is None:
            continue
        code = ss.strip_comments_and_strings(raw)[0]
        code_lines = code.split("\n")
        starts = [0]
        for ln in code_lines:
            starts.append(starts[-1] + len(ln) + 1)
        darwin = conds.darwin_lines(code_lines) if rel in indexed else None
        for line in added:
            if line > len(code_lines):
                continue
            if darwin is not None and darwin[line] is not False:
                continue   # the index decides here
            for nid, col, how in matcher.match(code, starts[line - 1], starts[line] - 1, own):
                add(rel, line, col, nid, "lexical", how=how)
    co.close()

    resolution = {"indexed": "index", "partial": "partial index"}.get(idx["status"], "lexical")
    adopted = {
        "path": info["path"], "dir": info["dir"], "branch": info["branch"], "commit": commit,
        "branches": info.get("branches") or {}, "examples": bool(info.get("examples")),
        "subject": info["subject"], "mainRef": info["mainRef"], "mainCommit": info["mainCommit"],
        "base": base, "baseSubject": info["baseSubject"], "commits": info["commits"],
        "swiftFilesChanged": len(swift_changed), "indexedFilesChanged": len([f for f in swift_changed
                                                                             if f in indexed]),
        "resolution": resolution, "build": idx["build"],
        "sites": {"precise": counts["precise"], "lexical": counts["lexical"], "qualifier": counts["qualifier"]},
    }
    return {"sites": sites, "hunks": hunks, "adopted": adopted}


# ---------------------------------------------------------------- main

def main():
    global SWIFT_VERSION
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--head-src", required=True)
    ap.add_argument("--base-src", required=True)
    ap.add_argument("--head-scan", required=True)
    ap.add_argument("--base-scan", required=True)
    ap.add_argument("--cnames", required=True, help="cnames.json, from cnames.py")
    ap.add_argument("--work", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--adopters")
    ap.add_argument("--ecosystem")
    ap.add_argument("--coverage-results")
    ap.add_argument("--branches", default=",".join(MIGRATION_BRANCHES), metavar="BRANCH,...",
                    help="the migration branches, newest first: each clone is read at the first it has")
    ap.add_argument("--branch", help="one migration branch, for --branches")
    ap.add_argument("--examples", help="the examples' repository: a package written on System, read at --examples-ref")
    ap.add_argument("--examples-ref", default="main")
    ap.add_argument("--builds", choices=("build", "reuse", "none"), default="build")
    ap.add_argument("--rebuild", action="store_true")
    ap.add_argument("--symbolgraphs", help="api-delta's symbol graphs of the head commit (symbolgraphs/head)")
    ap.add_argument("--validate", choices=("declarations", "interface", "tree"), default="declarations")
    ap.add_argument("--builds-dir", help="persistent build directories, one per migration")
    ap.add_argument("--jobs", type=int, default=4, help="migrations built at a time")
    ap.add_argument("--min-free-gb", type=float, default=15)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    a.work, a.cache = os.path.abspath(a.work), os.path.abspath(a.cache)
    a.branches = [a.branch] if a.branch else [b for b in a.branches.split(",") if b]
    a.builds_dir = os.path.abspath(a.builds_dir) if a.builds_dir and a.builds == "build" else None
    t_start = time.time()

    g = load_json(a.graph)
    nodes = g["nodes"]
    compiler = run(["swift", "--version"])[1].split("\n")[0].replace("swift-driver version: ", "swift-driver ")
    mv = re.search(r"Swift version (\d+)\.(\d+)", compiler)
    if mv:
        SWIFT_VERSION = (int(mv.group(1)), int(mv.group(2)))

    pkgs = discover(a.adopters, a.ecosystem, a.branches, a.repo, (a.examples, a.examples_ref) if a.examples else None)
    only = set(x for x in a.only.split(",") if x)
    if only:
        pkgs = {k: v for k, v in pkgs.items() if k in only}

    usr_node = {n["usr"]: nid for nid, n in nodes.items() if n["usr"]}
    base_scan = load_json(a.base_scan)
    base_names = set()
    for d in base_scan["declarations"]:
        base_names.add(split_title(d["name"])[0].rstrip("?!"))
    for t in base_scan.get("types", []):
        base_names.add(t["name"].split(".")[-1])
    os.makedirs(a.cache, exist_ok=True)
    matcher = LexicalMatcher(nodes, base_names, library_names(a.cache, compiler))
    decls = None
    if a.symbolgraphs and glob.glob(os.path.join(a.symbolgraphs, "*.symbols.json")):
        decls = SystemDeclarations(a.symbolgraphs)
    builder = Builder(a, pkgs, compiler, decls)
    # Every migration's plan first, since one whose build compiles another
    # migration is revalidated only with it.
    plans = {k: builder.plan(p) for k, p in sorted(pkgs.items()) if (p["adopters"] or {}).get("migrated")}
    follow_dependencies(plans, pkgs)

    pkg_out = []
    for key in sorted(pkgs):
        p = pkgs[key]
        rec = {"key": key, "name": p["name"], "remote": p["remote"], "adopted": None, "benefit": None}
        if p.get("role"):
            rec["role"] = p["role"]
        pkg_out.append(rec)
        info = p["adopters"]
        if info and not info.get("migrated"):
            rec["adoptersClone"] = {"path": info["path"], "branch": info.get("branch"),
                                    "note": "no commits past the merge base" if info.get("branch") else
                                    f"no {' or '.join(a.branches)} branch"}
    recs = {r["key"]: r for r in pkg_out}

    # The builds, API_GRAPH_ADOPTER_JOBS at a time, longest first (by the
    # package's last recorded build; one with none first, since it could be
    # anything), then the cached indexes. Each worker builds or reads its
    # migration's index and finds its sites; they're merged in key order, so
    # the output doesn't depend on which finished first.
    last = {k: builder.last_seconds(pkgs[k]) for k in plans if plans[k]["entry"] is None}
    order = sorted(last, key=lambda k: (last[k] is not None, -(last[k] or 0), k)) + \
        sorted(k for k in plans if plans[k]["entry"] is not None)
    jobs = max(1, a.jobs)
    if last and a.builds == "build":
        if a.builds_dir:
            # One run at a time builds in a builds directory; the lock goes with the process.
            os.makedirs(a.builds_dir, exist_ok=True)
            lock = open(os.path.join(a.builds_dir, ".lock"), "w")
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                say(f"adopters: waiting for another run to finish with {a.builds_dir}")
                fcntl.flock(lock, fcntl.LOCK_EX)
        builder.system()   # before the workers, which all build against it
        say(f"adopters: {len(plans)} migrations: {len(last)} to build, {min(jobs, len(last))} at a time, longest "
            f"first ({', '.join(k + (f' {last[k]} s' if last[k] is not None else '') for k in order[:len(last)])}), "
            f"{len(plans) - len(last)} from the cache")

    def work(key):
        t0 = time.time()
        idx = builder.index(pkgs[key], plans[key])
        out = migration_sites(key, pkgs[key], idx, usr_node, matcher, Conditions())
        out["adopted"]["seconds"] = round(time.time() - t0)
        b, n = idx["build"], out["adopted"]["sites"]
        info = pkgs[key]["adopters"]
        say(f"adopters: {key}: {b.get('decision')} ({b.get('decisionReason')}); {out['adopted']['resolution']} "
            f"({b.get('status')}{': ' + b['reason'] if b.get('reason') else ''}"
            f"{'; ' + b['start'] if not b.get('cached') and b.get('start') else ''}); "
            f"{n['precise']} precise and {n['lexical']} lexical sites, {n['qualifier']} qualifiers; "
            f"{out['adopted']['seconds']} s ({info['branch']} at {info['commit'][:10]}, {info['commits']} commits)")
        return out

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        results = dict(zip(order, pool.map(work, order)))
    adopted_sites, hunks = [], {}
    by_node_adopted = collections.defaultdict(list)
    for key in sorted(results):
        r = results[key]
        for site in r["sites"]:
            by_node_adopted[site["node"]].append(len(adopted_sites))
            adopted_sites.append(site)
        hunks.update(r["hunks"])
        recs[key]["adopted"] = r["adopted"]

    # ------------------------------------------------------------ would benefit
    # A site counts for every C name the graph wraps (so the graph can say
    # who calls `fcntl` or `read`), and for a declaration's reach only
    # through the names it's joined on: not restricted, and not covered on
    # the base commit.
    cnames, name_nodes, c_kinds = join_tables(load_json(a.cnames))
    all_names = set(c_kinds)
    benefit_sites = []
    by_node_benefit = collections.defaultdict(list)
    for rec in pkg_out:
        p = pkgs[rec["key"]]
        # Where the interfaces come from, first choice first: the coverage
        # store's extraction of a migration's merge base (the code the
        # migration started from), of the ecosystem's clone, of an adopters'
        # clone without a migration; else a lexical scan of the same.
        ad = p["adopters"]
        choices = []
        if ad and ad.get("migrated") and ad.get("base"):
            choices.append(dict(ad, commit=ad["base"], subject=ad.get("baseSubject"), role="merge base"))
        if p["ecosystem"]:
            choices.append(dict(p["ecosystem"], role="ecosystem clone"))
        if ad and not ad.get("migrated"):
            c = ad.get("commit") or ad["head"]
            choices.append(dict(ad, commit=c, subject=git(ad["path"], "log", "-1", "--format=%s", c).strip(),
                                role="adopters clone"))
        if not choices:
            continue
        src, path, data = choices[0], None, None
        if a.coverage_results:
            for ch in choices:
                path, data = interfaces_for(a.coverage_results, ch["commit"])
                if data:
                    src = ch
                    break
        if not data and p["ecosystem"] and not (ad and ad.get("migrated")):
            src = choices[0]
        commit = src["commit"]
        if data:
            interfaces = data["interfaces"]
            source, extraction = "coverage", data.get("extraction", "index")
        else:
            cobj = Commit(src["path"], commit)
            interfaces = lexical_interfaces(cobj, {n: c_kinds.get(n, []) for n in name_nodes}, matcher.library)
            cobj.close()
            source, extraction = "lexical", "lexical"
        # For a package with a migration, whether each site's line survives
        # on the branch: the diff from this commit to the branch's tip, in
        # the migrated clone (which has both).
        migrated = p["adopters"] if p["adopters"] and p["adopters"].get("migrated") else None
        maps = None
        if migrated and rev(migrated["path"], commit):
            d0 = git(migrated["path"], "-c", "core.quotePath=false", "diff", "--no-ext-diff", "--no-color",
                     "--src-prefix=a/", "--dst-prefix=b/", "--find-renames", "-U0", commit, migrated["commit"])
            maps = line_map(parse_diff(d0))
        n_sites, used = 0, set()
        for itf in interfaces:
            names = {itf["name"]}
            shim = itf.get("shim") or {}
            for plat, wrapped in (shim.get("wraps") or {}).items():
                for w in wrapped:
                    names.add(w[4:] if w.startswith("SYS_") else w)
            matched = sorted(names & all_names)
            if not matched:
                continue
            hits = sorted({nid for nm in names for nid in name_nodes.get(nm, ())})
            via = sorted(nm for nm in names if nm in name_nodes)
            if hits:
                used.add(itf["name"])
            type_only = not ({"function", "constant", "macro", "variable", "error"} & set(itf.get("kinds") or []))
            for s in itf["sites"]:
                if type_only and s["file"].endswith(C_FILES):
                    continue   # C code spelling a C type can't adopt a Swift one; a shim's calls can go
                site = {"package": rec["key"], "file": s["file"], "line": s["line"], "interface": itf["name"],
                        "via": [v for v in via if v != itf["name"]], "target": s.get("target"),
                        "platforms": sorted(k for k, v in (s.get("platforms") or {}).items() if v),
                        "resolution": "precise" if s.get("evidence") == "index" else "lexical",
                        "evidence": s.get("evidence"), "cnames": matched, "nodes": hits}
                if maps is not None:
                    path_new, spans = maps.get(s["file"], (s["file"], []))
                    ml = map_line(spans, s["line"])
                    site["onBranch"] = {"file": path_new, "line": ml} if ml else None
                k = len(benefit_sites)
                benefit_sites.append(site)
                n_sites += 1 if hits else 0
                for nid in hits:
                    by_node_benefit[nid].append(k)
        rec["benefit"] = {"path": src["path"], "commit": commit, "subject": src.get("subject"), "role": src["role"],
                          "source": source, "extraction": extraction,
                          "result": os.path.relpath(os.path.dirname(path), a.coverage_results) if path else None,
                          "interfaces": len(used), "sites": n_sites,
                          "branchMapped": maps is not None}
        print(f"adopters: {rec['key']}: would benefit at {commit[:10]} ({source}, {extraction}): "
              f"{len(used)} interfaces, {n_sites} sites", flush=True)

    decisions = collections.Counter((r["adopted"]["build"] or {}).get("decision") for r in pkg_out if r["adopted"])
    build_dirs = None
    if a.builds_dir and os.path.isdir(a.builds_dir):
        # Each build directory's size, as measured after its last build.
        per = {}
        for d in sorted(os.listdir(a.builds_dir)):
            sp = os.path.join(a.builds_dir, d, "state.json")
            if d != "system" and os.path.isfile(sp):
                try:
                    per[d] = load_json(sp).get("kb")
                except ValueError:
                    per[d] = None
        system_kb = disk_kb(os.path.join(a.builds_dir, "system")) or 0
        build_dirs = {"dir": a.builds_dir,
                      "packagesMB": {k: round(v / 1024) if v else None for k, v in per.items()},
                      "systemMB": round(system_kb / 1024),
                      "totalMB": round((sum(v for v in per.values() if v) + system_kb) / 1024)}
        top = sorted(((v, k) for k, v in build_dirs["packagesMB"].items() if v), reverse=True)[:3]
        print(f"adopters: build directories in {a.builds_dir}: {build_dirs['totalMB'] / 1024:.1f} GB for {len(per)} "
              f"packages (the largest: {', '.join(f'{k} {v / 1024:.1f} GB' for v, k in top)})", flush=True)
    json.dump({
        "meta": {"branch": a.branches[0] if len(a.branches) == 1 else None, "branches": a.branches,
                 "examples": a.examples, "examplesRef": a.examples_ref if a.examples else None,
                 "adopters": a.adopters, "ecosystem": a.ecosystem,
                 "coverageResults": a.coverage_results, "headCommit": a.head, "systemTree": builder.system_tree,
                 "systemManifest": builder.system_manifest, "validate": a.validate,
                 "systemDeclarations": len(decls.fingerprint) if decls else None,
                 "decisions": dict(sorted(decisions.items())), "buildDirectories": build_dirs, "jobs": a.jobs,
                 "swift": compiler, "builds": a.builds, "date": datetime.date.today().isoformat(),
                 "seconds": round(time.time() - t_start)},
        "packages": pkg_out,
        "adoptedSites": adopted_sites, "adopted": by_node_adopted, "hunks": hunks,
        "benefitSites": benefit_sites, "benefit": by_node_benefit,
        "cNames": cnames,
    }, open(a.out, "w"), indent=0)
    na = sum(1 for r in pkg_out if r["adopted"])
    nb = sum(1 for r in pkg_out if r["benefit"])
    print(f"adopters: {len(pkg_out)} packages ({na} migrated: "
          f"{', '.join(f'{n} {d}' for d, n in sorted(decisions.items()))}; {nb} with interface data), "
          f"{len(adopted_sites)} adopted sites on {len(by_node_adopted)} declarations, "
          f"{len(benefit_sites)} would-benefit sites on {len(by_node_benefit)} declarations, "
          f"{round(time.time() - t_start)} s -> {a.out}")


if __name__ == "__main__":
    main()
