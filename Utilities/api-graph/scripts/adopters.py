#!/usr/bin/env python3
"""Where other packages use the graph's declarations, and where they would.

Two kinds of use sites, for every node of graph.json:

  adopted        Packages migrated onto System on a branch (migrate-darwin)
                 of a clone in ADOPTERS: the files and lines of the branch
                 that use each declaration, with the diff hunk, against the
                 branch's merge base with the package's main, that
                 introduced the use.
                 - Precise where the compiler resolves the use. The branch's
                   commit is exported, its path dependency on swift-system
                   pointed at an export of the head commit (and a path
                   dependency on another migrated clone at that clone's
                   branch), and built as the coverage tools build it
                   (Utilities/adopter-coverage/packages/*.ini) with an index
                   store. The store's references to a node's USR are its
                   sites. The references are cached by package commit,
                   System tree, toolchain and settings, and the build is
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
                 tools' own derivation (adopter-coverage's derive.py). The
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
                   --work DIR --cache DIR --out adopters.json
                   [--adopters DIR] [--ecosystem DIR] [--coverage-results DIR]
                   [--branch migrate-darwin] [--builds build|reuse|none]
                   [--rebuild] [--min-free-gb 15] [--only KEY,...]
"""

import sys

sys.dont_write_bytecode = True   # nothing written into the coverage tool's scripts directory

import argparse  # noqa: E402
import bisect  # noqa: E402
import collections  # noqa: E402
import datetime  # noqa: E402
import glob  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import importlib.util  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
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


def discover(adopters_dir, ecosystem_dir, branch, repo):
    """Every package clone: {key: {key, name, remote, adopters, ecosystem}}."""
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
                tip = rev(path, branch)
                info["branch"] = branch if tip else None
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


# ---------------------------------------------------------------- indexed builds

class Builder:
    def __init__(self, a, pkgs, compiler):
        self.a = a
        self.pkgs = pkgs
        self.compiler = compiler
        self.pathdeps = coverage_module("pathdeps")
        self.package = coverage_module("package")
        self.settings_files = coverage_package_files()
        self.system_tree = tree_of(a.repo, a.head)
        self.system_export = None

    def settings(self, pkg):
        info = pkg["adopters"]
        p = self.settings_files.get(info["dir"].lower()) or self.settings_files.get(pkg["key"])
        s = self.package.load(p) if p else {"build-targets": [], "build-flags": [], "unset-env": [],
                                            "variable": re.sub(r"\W", "_", pkg["key"]).upper(),
                                            "skip-targets": [], "skipReasons": {}}
        s["file"] = os.path.relpath(p, UTILITIES) if p else None
        return s

    def system(self):
        if not self.system_export:
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
        swift-system's tree, another clone's commit, or a plain path."""
        keys = []
        listing = git(repo, "ls-tree", "--name-only", commit) or ""
        for name in sorted(x for x in listing.split("\n") if re.match(r"^Package(@swift-[\d.]+)?\.swift$", x)):
            text = git(repo, "show", f"{commit}:{name}", check=False) or ""
            for m in self.pathdeps.PATH_DEP.finditer(text):
                rel = m.group(2)
                target = rel if os.path.isabs(rel) else os.path.normpath(os.path.join(repo, rel))
                if self.is_system(target):
                    keys.append(f"swift-system@{self.system_tree}")
                    continue
                top = toplevel(target) if os.path.isdir(target) else None
                if top:
                    c = rev(top, self.a.branch) or rev(top, "HEAD")
                    keys.append(f"{os.path.basename(target)}@{c}")
                    if (top, c) not in seen:
                        seen.add((top, c))
                        keys += self.dep_keys(top, c, seen)
                else:
                    keys.append(f"path:{target}")
        return sorted(set(keys))

    def rewrite(self, export_dir, checkout, deps_dir, seen, notes):
        """Point the export's path dependencies at commits: swift-system at the
        head commit's export, another clone at an export of its migration
        branch (or its HEAD). Returns the keys the build depends on."""
        keys = []
        for manifest in sorted(glob.glob(os.path.join(export_dir, "Package*.swift"))):
            text = open(manifest, encoding="utf-8").read()

            def sub(m):
                rel = m.group(2)
                target = rel if os.path.isabs(rel) else os.path.normpath(os.path.join(checkout, rel))
                if self.is_system(target):
                    keys.append(f"swift-system@{self.system_tree}")
                    return m.group(1) + json.dumps(self.system())
                top = toplevel(target) if os.path.isdir(target) else None
                if top:
                    commit = rev(top, self.a.branch) or rev(top, "HEAD")
                    dest = os.path.join(deps_dir, os.path.basename(target.rstrip("/")))
                    keys.append(f"{os.path.basename(target)}@{commit}")
                    if dest not in seen:
                        seen.add(dest)
                        export(top, commit, dest)
                        keys.extend(self.rewrite(dest, target, deps_dir, seen, notes))
                        notes.append(f"{rel} -> {os.path.basename(target)} at {commit[:10]}")
                    return m.group(1) + json.dumps(dest)
                notes.append(f"{rel}: not a clone; left as {target}")
                keys.append(f"path:{target}")
                return m.group(1) + json.dumps(target)

            new = self.pathdeps.PATH_DEP.sub(sub, text)
            if new != text:
                open(manifest, "w", encoding="utf-8").write(new)
        return keys

    def index(self, pkg):
        """{status, files, symbols, build}, from the cache or a build."""
        a = self.a
        info = pkg["adopters"]
        s = self.settings(pkg)
        exec_var = f"{s['variable']}_SWIFT_EXEC"
        swift_exec = os.environ.get(exec_var) or (newest_toolchain() if s.get("build-hint") else None)
        settings_text = json.dumps({k: s.get(k) for k in ("build-targets", "build-flags", "unset-env")},
                                   sort_keys=True)
        # The key: everything the build depends on but the local path
        # dependencies, which only an export shows; those are added below.
        base_key = [info["commit"], self.system_tree, self.compiler, swift_exec or "", settings_text, READER_VERSION,
                    self.dep_keys(info["path"], info["commit"], set())]
        cache_dir = os.path.join(a.cache, pkg["key"])
        # A cached index whose key matches; with --builds reuse, the latest of this commit.
        cached = None
        for p in sorted(glob.glob(os.path.join(cache_dir, info["commit"] + "-*.json.gz")), key=os.path.getmtime):
            try:
                d = load_json(p)
            except (OSError, ValueError):
                continue
            if d.get("baseKey") == json.loads(json.dumps(base_key)) or a.builds == "reuse":
                cached = d
        if cached and not a.rebuild:
            cached["build"]["cached"] = True
            return cached
        if a.builds != "build":
            return {"status": "not built", "files": {}, "symbols": {},
                    "build": {"status": "not built", "reason": f"--builds {a.builds}", "settings": s["file"]}}
        free = shutil.disk_usage(a.work if os.path.isdir(a.work) else os.path.dirname(a.work)).free / 2 ** 30
        if free < a.min_free_gb:
            return {"status": "not built", "files": {}, "symbols": {},
                    "build": {"status": "not built", "reason": f"{free:.1f} GiB free, under {a.min_free_gb}",
                              "settings": s["file"]}}
        w = os.path.join(a.work, "adopters", pkg["key"])
        shutil.rmtree(w, ignore_errors=True)
        os.makedirs(w)
        # The export's directory is named as the clone's is: a root package's
        # identity is its directory's name, and it has to match the package's
        # own when the package is also a dependency (swift-argument-parser is
        # swift-system's).
        src, build, log = os.path.join(w, info["dir"]), os.path.join(w, "build"), os.path.join(w, "build.log")
        t0 = time.time()
        export(info["path"], info["commit"], src)
        notes = []
        self.rewrite(src, info["path"], os.path.join(w, "deps"), set(), notes)
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
            if code != 0:
                # A manifest for newer tools than these reads with its tools version lowered.
                for manifest in glob.glob(os.path.join(src, "Package*.swift")):
                    t = open(manifest, encoding="utf-8").read()
                    t = re.sub(r"^// swift-tools-version: *[0-9.]+", "// swift-tools-version:%d.%d" % SWIFT_VERSION, t)
                    open(manifest, "w", encoding="utf-8").write(t)
                notes.append("tools version lowered to %d.%d" % SWIFT_VERSION)
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
            files, symbols, _defs, n_records = index_refs.read_store(store, src, keep, definitions_too=False)
            if status == "failed" and files:
                status = "partial"
        elif status == "indexed":
            status, reason = "failed", "the build left no index store"
        tail = open(log, encoding="utf-8", errors="replace").read().split("\n")[-30:] if os.path.exists(log) else []
        result = {
            "baseKey": base_key, "status": status,
            "files": files, "symbols": symbols,
            "build": {"status": status, "reason": reason, "seconds": round(time.time() - t0),
                      "targets": built_targets, "requestedTargets": targets, "flags": flags,
                      "swiftExec": swift_exec, "compiler": self.compiler, "settings": s["file"],
                      "pathDependencies": notes, "records": n_records, "date": datetime.date.today().isoformat(),
                      "logTail": tail if status != "indexed" else [], "cached": False},
        }
        os.makedirs(cache_dir, exist_ok=True)
        name = info["commit"] + "-" + hashlib.sha1(json.dumps(base_key).encode()).hexdigest()[:12] + ".json.gz"
        with gzip.open(os.path.join(cache_dir, name), "wt", encoding="utf-8") as f:
            json.dump(result, f)
        # The build is scratch: gone as soon as it's read (SwiftPM's is several GB).
        shutil.rmtree(w, ignore_errors=True)
        return result


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
SWIFT_WORDS = {"nil", "true", "false", "self", "Self", "super", "init", "Void", "Any", "some", "any", "inout"}


def param_names(decl):
    """The labels and parameter names a declaration's text spells."""
    out = set()
    m = re.search(r"\((.*)\)", decl)
    if m:
        for prm in top_level_split(m.group(1)):
            out.update(re.findall(IDENT, prm.partition(":")[0]))
    return out


def c_names_by_node(nodes, derive, head_src, head_scan, base_src, base_scan):
    """{nid: {"names", "restricted", "baseCovered"}} from the coverage tools'
    derivation of the head commit, and {name: kinds}. A name the base
    commit's derivation covers is set aside, and so are the Swift words and
    parameter names the derivation takes for C names (`nil` in "with
    `UTIME_OMIT` for a `nil` time", `value` in "the 8 bytes of `value`")."""
    head = derive.derive(head_src, head_scan)
    base = derive.derive(base_src, base_scan)
    base_covered = {name for name, v in base["names"].items() if v["status"] == "covered"}
    at = collections.defaultdict(list)
    for nid, n in nodes.items():
        for f, ln in n.get("sites") or [[n["file"], n["line"]]]:
            if f:
                at[(f, ln)].append(nid)
    out = collections.defaultdict(lambda: {"names": set(), "restricted": set(), "baseCovered": set()})
    kinds = {}
    for name, v in head["names"].items():
        if name in SWIFT_WORDS:
            continue
        kinds[name] = v["kinds"]
        for d in v["declarations"]:
            for nid in at.get((d["file"], d["line"]), []):
                if d["role"] == "argument" and not name.isupper() and name in param_names(nodes[nid]["decl"]):
                    continue
                rec = out[nid]
                if d["restricted"]:
                    rec["restricted"].add(name)
                elif name in base_covered:
                    rec["baseCovered"].add(name)
                else:
                    rec["names"].add(name)
    return {k: {kk: sorted(vv) for kk, vv in v.items()} for k, v in out.items()}, kinds


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
    ap.add_argument("--work", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--adopters")
    ap.add_argument("--ecosystem")
    ap.add_argument("--coverage-results")
    ap.add_argument("--branch", default="migrate-darwin")
    ap.add_argument("--builds", choices=("build", "reuse", "none"), default="build")
    ap.add_argument("--rebuild", action="store_true")
    ap.add_argument("--min-free-gb", type=float, default=15)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    a.work, a.cache = os.path.abspath(a.work), os.path.abspath(a.cache)
    t_start = time.time()

    g = load_json(a.graph)
    nodes = g["nodes"]
    compiler = run(["swift", "--version"])[1].split("\n")[0].replace("swift-driver version: ", "swift-driver ")
    mv = re.search(r"Swift version (\d+)\.(\d+)", compiler)
    if mv:
        SWIFT_VERSION = (int(mv.group(1)), int(mv.group(2)))

    pkgs = discover(a.adopters, a.ecosystem, a.branch, a.repo)
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
    conds = Conditions()
    builder = Builder(a, pkgs, compiler)

    adopted_sites, hunks = [], {}
    by_node_adopted = collections.defaultdict(list)
    pkg_out = []

    for key in sorted(pkgs):
        p = pkgs[key]
        rec = {"key": key, "name": p["name"], "remote": p["remote"], "adopted": None, "benefit": None}
        pkg_out.append(rec)
        info = p["adopters"]
        if not info or not info.get("migrated"):
            if info:
                rec["adoptersClone"] = {"path": info["path"], "branch": info.get("branch"),
                                        "note": "no commits past the merge base" if info.get("branch") else
                                        f"no {a.branch} branch"}
            continue
        t0 = time.time()
        print(f"adopters: {key}: {a.branch} @ {info['commit'][:10]}, {info['commits']} commits past "
              f"{info['base'][:10] if info['base'] else '?'}", flush=True)
        repo, commit, base = info["path"], info["commit"], info["base"]
        co = Commit(repo, commit)
        diff_text = git(repo, "-c", "core.quotePath=false", "diff", "--no-ext-diff", "--no-textconv", "--no-color",
                        "--src-prefix=a/", "--dst-prefix=b/", "--find-renames", "-U3", base, commit) if base else ""
        diff = parse_diff(diff_text)
        swift_changed = sorted(f for f in diff if f.endswith(".swift"))
        idx = builder.index(p)
        indexed = set(idx["files"])
        symbols = idx["symbols"]
        own = declared_names(co)

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
        n_precise = n_lexical = n_qualifier = 0

        def add(f, line, col, nid, resolution, how=None, qualifier=False):
            nonlocal n_precise, n_lexical, n_qualifier
            k_ = (f, line, nid)
            if k_ in seen:
                return
            seen.add(k_)
            lines = co.lines(f)
            text = lines[line - 1].strip() if 0 < line <= len(lines) else ""
            introduced = line in diff.get(f, {}).get("added", ())
            site = {"package": key, "file": f, "line": line, "column": col, "node": nid,
                    "resolution": resolution, "how": how, "qualifier": qualifier, "introduced": introduced,
                    "hunk": hunk_for(f, line), "text": text[:240]}
            by_node_adopted[nid].append(len(adopted_sites))
            adopted_sites.append(site)
            if qualifier:
                n_qualifier += 1
            elif resolution == "precise":
                n_precise += 1
            else:
                n_lexical += 1

        # Precise: the index's references to the nodes' USRs. A type named
        # only to qualify another reference right after it (`PThread` in
        # `PThread.Mutex`) is recorded as a qualifier, and implicit
        # references (accessors a property use calls) are dropped.
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
                name = re.sub(r"\(.*$", "", symbols.get(usr, {}).get("name", ""))
                text = lines[line - 1] if 0 < line <= len(lines) else ""
                qual = False
                if name and text[col - 1:col - 1 + len(name)] == name:
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

        resolution = {"indexed": "index", "partial": "partial index"}.get(idx["status"], "lexical")
        rec["adopted"] = {
            "path": info["path"], "dir": info["dir"], "branch": a.branch, "commit": commit,
            "subject": info["subject"], "mainRef": info["mainRef"], "mainCommit": info["mainCommit"],
            "base": base, "baseSubject": info["baseSubject"], "commits": info["commits"],
            "swiftFilesChanged": len(swift_changed), "indexedFilesChanged": len([f for f in swift_changed
                                                                                 if f in indexed]),
            "resolution": resolution, "build": idx["build"],
            "sites": {"precise": n_precise, "lexical": n_lexical, "qualifier": n_qualifier},
            "seconds": round(time.time() - t0),
        }
        co.close()
        print(f"adopters: {key}: {resolution} ({idx['build'].get('status')}"
              f"{', cached' if idx['build'].get('cached') else ''}"
              f"{': ' + idx['build']['reason'] if idx['build'].get('reason') else ''}); "
              f"{n_precise} precise and {n_lexical} lexical sites, {n_qualifier} qualifiers, "
              f"{round(time.time() - t0)} s", flush=True)

    # ------------------------------------------------------------ would benefit
    derive = coverage_module("derive")
    cnames, c_kinds = c_names_by_node(nodes, derive, a.head_src, load_json(a.head_scan), a.base_src, base_scan)
    name_nodes = collections.defaultdict(list)
    for nid, v in cnames.items():
        for nm in v["names"]:
            name_nodes[nm].append(nid)
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
            hits = sorted({nid for nm in names for nid in name_nodes.get(nm, ())})
            if not hits:
                continue
            via = sorted(nm for nm in names if nm in name_nodes)
            used.add(itf["name"])
            type_only = not ({"function", "constant", "macro", "variable", "error"} & set(itf.get("kinds") or []))
            for s in itf["sites"]:
                if type_only and s["file"].endswith(C_FILES):
                    continue   # C code spelling a C type can't adopt a Swift one; a shim's calls can go
                site = {"package": rec["key"], "file": s["file"], "line": s["line"], "interface": itf["name"],
                        "via": [v for v in via if v != itf["name"]], "target": s.get("target"),
                        "platforms": sorted(k for k, v in (s.get("platforms") or {}).items() if v),
                        "resolution": "precise" if s.get("evidence") == "index" else "lexical",
                        "evidence": s.get("evidence"), "nodes": hits}
                if maps is not None:
                    path_new, spans = maps.get(s["file"], (s["file"], []))
                    ml = map_line(spans, s["line"])
                    site["onBranch"] = {"file": path_new, "line": ml} if ml else None
                k = len(benefit_sites)
                benefit_sites.append(site)
                n_sites += 1
                for nid in hits:
                    by_node_benefit[nid].append(k)
        rec["benefit"] = {"path": src["path"], "commit": commit, "subject": src.get("subject"), "role": src["role"],
                          "source": source, "extraction": extraction,
                          "result": os.path.relpath(os.path.dirname(path), a.coverage_results) if path else None,
                          "interfaces": len(used), "sites": n_sites,
                          "branchMapped": maps is not None}
        print(f"adopters: {rec['key']}: would benefit at {commit[:10]} ({source}, {extraction}): "
              f"{len(used)} interfaces, {n_sites} sites", flush=True)

    json.dump({
        "meta": {"branch": a.branch, "adopters": a.adopters, "ecosystem": a.ecosystem,
                 "coverageResults": a.coverage_results, "headCommit": a.head, "systemTree": builder.system_tree,
                 "swift": compiler, "builds": a.builds, "date": datetime.date.today().isoformat(),
                 "seconds": round(time.time() - t_start)},
        "packages": pkg_out,
        "adoptedSites": adopted_sites, "adopted": by_node_adopted, "hunks": hunks,
        "benefitSites": benefit_sites, "benefit": by_node_benefit,
        "cNames": cnames,
    }, open(a.out, "w"), indent=0)
    na = sum(1 for r in pkg_out if r["adopted"])
    nb = sum(1 for r in pkg_out if r["benefit"])
    print(f"adopters: {len(pkg_out)} packages ({na} migrated, {nb} with interface data), "
          f"{len(adopted_sites)} adopted sites on {len(by_node_adopted)} declarations, "
          f"{len(benefit_sites)} would-benefit sites on {len(by_node_benefit)} declarations, "
          f"{round(time.time() - t_start)} s -> {a.out}")


if __name__ == "__main__":
    main()
