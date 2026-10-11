#!/usr/bin/env python3
"""The compiler's own list of what a package still takes from the platform
C modules: build an export of one branch with a target's imports of them
removed, one target at a time, and read what the compiler can't find.

Usage: probe.py [--linux] [--branch BRANCH] [--system REF] [--targets T,...]
                [--nested | --package-dir DIR,...] [--path-dep IDENTITY=[REPO@]REF]...
                [--own-modules | --reexport]
                [--work DIR] [--out DIR] [--keep] [--no-skip] [--min-free-gb N]
                CLONE...

For each clone (a checkout of a package: a clone or a worktree):
  1. The branch (default: its newest migration branch, migrate-all, then
     migrate-unix, then migrate-darwin) is exported with `git archive` into
     a scratch directory, WORK/<package>-<platform>/src/<package>. The
     clone is only read. A nested package (--nested, --package-dir: a
     directory of the branch with its own Package.swift) is probed in place
     in that export, and reported on its own.
  2. Its dependencies become path dependencies on exports in WORK/.../deps:
     System at --system (default system-next, in this worktree), remote
     packages from SwiftPM's cache (manifests.py), and local path
     dependencies from their checkouts' commits, followed transitively.
     Nothing is fetched for them.
  3. `swift package describe` gives the targets and their dependencies; the
     Swift targets are probed in dependency order.
  4. For each target, its imports of modules.ini's [count] modules (and a
     package's configured shims, packages.ini) are removed (strip.py). A
     target none of whose removed imports the platform compiles (by
     adopter-coverage's `#if` evaluator; a maybe counts as compiled) isn't
     built. If any target is, the whole package is built once first (the
     baseline, `--build-tests`); then each target is built alone with
     `-Xswiftc -continue-building-after-errors`, the other targets as they
     were, in one build directory, so each build is incremental; then its
     files are restored. --own-modules adds two builds of each target that
     imports one of the package's own C modules (below).
  5. The errors in the target's files are read (diags.py), less the
     baseline's, and each name is classified against System (classify.py).
  6. WORK/... is deleted unless --keep; OUT/<package>/<platform>.json is
     written, and summary.py's OUT/<package>/SUMMARY.md.

--own-modules: the C names a file reaches through a C module of its own
package (CNIOBoringSSL, CAsyncHTTPClient), whose module re-exports the
system headers it includes. Each target that imports one is built twice
more: without those imports as well as its C imports, and then with the
platform's C library imported in each of its files instead. A name the
first build can't find, the second can, and the ordinary probe's build
could is one the file took from the C library through its own C module.

--reexport (reexport.py) is a different run: the names a package gets only
through an `@_exported import` of a C module, such as NIOPosix's of Glibc.

--linux builds in a container through Utilities/linux/build.sh (--root the
scratch directory, --dir the package), with the image's Swift; macOS is
the default.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import datetime  # noqa: E402
import glob  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import time  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.dirname(HERE)
UTILITIES = os.path.dirname(TOOL)
sys.path.insert(0, HERE)
sys.path.append(os.path.join(UTILITIES, "api-delta", "scripts"))

import classify  # noqa: E402  (puts adopter-coverage's scripts on the path)
import diags  # noqa: E402
import manifests  # noqa: E402
import strip  # noqa: E402
import summary  # noqa: E402
import platforms  # noqa: E402  (adopter-coverage's)
from scan_sources import strip_comments_and_strings  # noqa: E402

BRANCHES = ("migrate-all", "migrate-unix", "migrate-darwin")
MARKER = ".import-probe-work"
GIT_ENV = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_TERMINAL_PROMPT="0")
LINUX_BUILD = os.path.join(UTILITIES, "linux", "build.sh")
# The C library each platform's build imports in place of a package's own C
# module (--own-modules) or a demoted re-export (--reexport).
C_LIBRARY = {"macos": "Darwin", "linux": "Glibc"}
OWN_C_TYPES = ("ClangTarget", "SystemLibraryTarget")


def log(msg):
    print(f"import-probe: {msg}", flush=True)


def git(repo, *args, ok=(0,)):
    p = subprocess.run(["git", "--no-optional-locks", "-C", repo, *args], capture_output=True, text=True,
                       env=GIT_ENV)
    if p.returncode not in ok:
        raise RuntimeError(f"git -C {repo} {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def commit_of(repo, ref):
    return git(repo, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", ok=(0, 1)).strip() or None


def newest_branch(clone):
    for b in BRANCHES:
        if commit_of(clone, f"refs/heads/{b}"):
            return b
    return None


def export(repo, commit, dest):
    """`git archive` of a commit (or `commit:subdirectory`) into dest."""
    os.makedirs(dest, exist_ok=True)
    archive = subprocess.run(["git", "--no-optional-locks", "-C", repo, "archive", commit], capture_output=True,
                             check=True, env=GIT_ENV).stdout
    subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)


def nested_packages(clone, commit):
    """The branch's nested packages: each directory, other than the root,
    with its own Package.swift."""
    files = git(clone, "ls-tree", "-r", "--name-only", commit).split("\n")
    return sorted(os.path.dirname(f) for f in files if f.endswith("/Package.swift"))


def display_name(name, subdir):
    """The name a package's output goes by: the clone's directory's, and a
    nested package's directory after it (`swift-nio-ssl-Benchmarks`)."""
    subdir = os.path.normpath(subdir)
    return name if subdir == "." else f"{name}-{subdir.replace(os.sep, '-')}"


def refuse_tracked(path, repo):
    """The scratch and output directories must be outside git's view:
    ignored, or outside this repository."""
    absolute = os.path.abspath(path)
    top = os.path.abspath(repo)
    if not (absolute + "/").startswith(top + "/"):
        return
    rel = os.path.relpath(absolute, top)
    if subprocess.run(["git", "-C", repo, "check-ignore", "-q", rel], env=GIT_ENV).returncode != 0:
        sys.exit(f"import-probe: {path} isn't ignored by git; use a directory under .build")


def fresh_work(work):
    """An empty scratch directory of this tool's: one it made before (its
    marker says so) is emptied, anything else there is refused."""
    if os.path.exists(work):
        if not os.path.isfile(os.path.join(work, MARKER)):
            sys.exit(f"import-probe: {work} exists and isn't this tool's scratch directory; not touching it")
        for entry in os.listdir(work):
            if entry.startswith("scratch-") or entry == MARKER:
                continue
            p = os.path.join(work, entry)
            shutil.rmtree(p) if os.path.isdir(p) and not os.path.islink(p) else os.remove(p)
    os.makedirs(work, exist_ok=True)
    open(os.path.join(work, MARKER), "w").close()


def remove_work(work):
    if os.path.isfile(os.path.join(work, MARKER)):
        shutil.rmtree(work)


def free_gb(path):
    while not os.path.exists(path):
        path = os.path.dirname(path)
    return shutil.disk_usage(path).free / 2 ** 30


# ---------------------------------------------------------------- configuration

def package_config(name, subdir="."):
    """packages.ini's settings for a package: shims (modules whose imports
    are removed like a C module's) and a note. A nested package takes its
    own section, `[<package>/<directory>]`, if there is one, else its
    clone's."""
    import configparser
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    cp.read(os.path.join(TOOL, "packages.ini"), encoding="utf-8")
    section = f"{name}/{os.path.normpath(subdir)}"
    if not cp.has_section(section):
        section = name
    if not cp.has_section(section):
        return {"shims": [], "note": ""}
    sec = dict(cp.items(section))
    return {"shims": sec.get("shims", "").split(), "note": " ".join(sec.get("note", "").split())}


def path_dep_refs(specs):
    """{identity: (checkout or None, ref)} from --path-dep IDENTITY=REF or
    IDENTITY=REPO@REF."""
    out = {}
    for spec in specs or ():
        ident, _, value = spec.partition("=")
        repo, at, ref = value.rpartition("@")
        if not (ident and ref):
            sys.exit(f"import-probe: --path-dep {spec}: want IDENTITY=REF or IDENTITY=REPO@REF")
        out[ident.lower()] = (os.path.abspath(os.path.expanduser(repo)) if at else None, ref)
    return out


# ---------------------------------------------------------------- the copy

def inside(path, directory):
    path, directory = os.path.realpath(path), os.path.realpath(directory)
    return path == directory or path.startswith(directory + os.sep)


def checkout_of(path):
    """(the git checkout's top directory, the path's directory in it) for a
    directory on disk."""
    if not os.path.isdir(path):
        raise RuntimeError(f"no directory {path}")
    p = subprocess.run(["git", "--no-optional-locks", "-C", path, "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True, env=GIT_ENV)
    if p.returncode != 0:
        raise RuntimeError(f"{path} isn't in a git checkout; the probe exports commits only")
    top = p.stdout.strip()
    return top, os.path.relpath(os.path.realpath(path), os.path.realpath(top))


def prepare(clone, commit, name, work, repo, system_commit, subdir=".", path_refs=None, swiftpm=()):
    """Exports the package, System and the dependencies, and rewrites the
    local packages' manifests; returns (the package's directory in the
    export, what was done, for the record).

    The local packages are the probed one, the packages of its own branch
    it takes by path (a nested package's `../..`), and the local path
    dependencies, transitively: each has its remote dependencies exported
    from SwiftPM's cache and its path dependencies followed, as SwiftPM's
    `dump-package` reads its manifest, and its manifests rewritten to point
    at the exports. A path dependency outside the branch is exported from
    its checkout's HEAD, or --path-dep's ref. A remote package keeps its
    manifest: SwiftPM resolves its own remote dependencies, from its cache
    on macOS and from the network in a container, and gives an identity
    the export has to the export, as it does for a root's."""
    root = os.path.join(work, "src", name)
    export(clone, commit, root)
    pkg = os.path.normpath(os.path.join(root, subdir))
    if not inside(pkg, root) or not os.path.isfile(os.path.join(pkg, "Package.swift")):
        raise RuntimeError(f"{subdir} has no Package.swift at {commit[:10]}")
    deps = os.path.join(work, "deps")
    scratch = os.path.join(work, "scratch-macos")
    path_refs = path_refs or {}
    record = {"system": system_commit, "dependencies": [], "local": [], "conflicts": [], "rewrites": {}}
    sysdir = os.path.join(deps, "swift-system")
    export(repo, system_commit, sysdir)
    sm = os.path.join(sysdir, "Package.swift")
    with open(sm, encoding="utf-8") as f:
        text = f.read()
    with open(sm, "w", encoding="utf-8") as f:
        f.write(manifests.drop_samples(text))
    exports = {"swift-system": sysdir}
    origins = {root: clone}
    pins = manifests.resolved_pins(pkg)

    def origin_of(p):
        for d, o in origins.items():
            if inside(p, d):
                return os.path.normpath(os.path.join(o, os.path.relpath(os.path.realpath(p), os.path.realpath(d))))
        raise RuntimeError(f"no origin for {p}")

    queue, done = [pkg], []
    while queue:
        p = queue.pop(0)
        if any(os.path.realpath(p) == os.path.realpath(q) for q in done):
            continue
        done.append(p)
        if p != pkg:
            record["local"].append(os.path.relpath(p, work))
        for m in manifests.manifests(p):
            with open(os.path.join(p, m), encoding="utf-8") as f:
                text = f.read()
            for d in manifests.dependencies(text):
                ident = d["identity"]
                if d["kind"] != "url" or ident in exports:
                    continue
                clone_dir, rev, version = manifests.choose(d["location"], d["requirement"], pins.get(ident))
                exports[ident] = os.path.join(deps, ident)
                export(clone_dir, rev, exports[ident])
                record["dependencies"].append({"identity": ident, "url": d["location"], "requirement": d["requirement"],
                                               "version": version, "revision": rev})
        for d in manifests.active_dependencies(p, scratch, swiftpm):
            if d["kind"] != "path":
                continue
            # SwiftPM's path is resolved (/private/var for /var); the
            # scratch directory's, the work's, may not be.
            ident, target = d["identity"], os.path.realpath(d["location"])
            literal = os.path.relpath(target, os.path.realpath(p))
            if inside(target, work):
                target = os.path.join(work, os.path.relpath(target, os.path.realpath(work)))
            if inside(target, root):
                if not os.path.isfile(os.path.join(target, "Package.swift")):
                    raise RuntimeError(f"{os.path.relpath(p, work)} takes the path dependency {literal}, which "
                                       f"has no Package.swift at {commit[:10]}")
                queue.append(os.path.normpath(target))
                continue
            original = os.path.normpath(os.path.join(origin_of(p), literal))
            if ident in exports:
                if ident != "swift-system" and not any(inside(original, o) and inside(o, original)
                                                       for e, o in origins.items() if e == exports[ident]):
                    record["conflicts"].append({"identity": ident, "from": os.path.relpath(p, work),
                                                "location": original, "used": os.path.relpath(exports[ident], work)})
                continue
            repo_dir, ref = path_refs.get(ident, (None, "HEAD"))
            if repo_dir:
                top, sub = repo_dir, "."
            else:
                try:
                    top, sub = checkout_of(original)
                except RuntimeError as e:
                    raise RuntimeError(f"{os.path.relpath(p, work)}'s path dependency {literal}: {e}")
            rev = commit_of(top, ref)
            if not rev:
                raise RuntimeError(f"path dependency {ident}: no commit {ref} in {top}")
            dest = os.path.join(deps, ident)
            exports[ident] = dest
            export(top, rev if sub == "." else f"{rev}:{sub}", dest)
            origins[dest] = os.path.normpath(os.path.join(top, sub))
            dirty = git(top, "status", "--porcelain", "--untracked-files=no").strip()
            on = git(top, "symbolic-ref", "--short", "-q", "HEAD", ok=(0, 1)).strip() if ref == "HEAD" else ""
            entry = {"identity": ident, "url": origins[dest], "requirement": f"path: {literal}",
                     "version": f"{ref} ({on + ', ' if on else ''}local)", "revision": rev}
            if dirty and ref == "HEAD":
                entry["uncommitted"] = len(dirty.split("\n"))
                log(f"{ident}: {top} has uncommitted changes; the export is its HEAD, {rev[:10]}")
            record["dependencies"].append(entry)
            queue.append(dest)
    for p in done:
        for m in manifests.manifests(p):
            path = os.path.join(p, m)
            with open(path, encoding="utf-8") as f:
                text = f.read()
            new, rewrites = manifests.rewrite(text, {i: os.path.relpath(d, p) for i, d in exports.items()})
            if new != text:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new)
            record["rewrites"][os.path.relpath(path, pkg)] = rewrites
    return pkg, record


def describe(pkg, scratch, logs, swiftpm=()):
    p = subprocess.run(["swift", "package", "--disable-sandbox", *swiftpm, "--package-path", pkg,
                        "--scratch-path", scratch, "describe", "--type", "json"], capture_output=True, text=True)
    with open(os.path.join(logs, "describe.log"), "w") as f:
        f.write(p.stderr)
    if p.returncode != 0:
        raise RuntimeError(f"swift package describe failed; see {logs}/describe.log:\n{p.stderr[-2000:]}")
    return json.loads(p.stdout)


def ordered_targets(desc):
    """The package's targets, each after the targets it depends on."""
    targets = {t["name"]: t for t in desc["targets"]}
    done, out = set(), []

    def visit(n, stack=()):
        if n in done or n not in targets or n in stack:
            return
        for d in targets[n].get("target_dependencies", []):
            visit(d, stack + (n,))
        done.add(n)
        out.append(targets[n])
    for t in desc["targets"]:
        visit(t["name"])
    return out


def target_files(pkg, t):
    return [os.path.normpath(os.path.join(t["path"], s)) for s in t.get("sources", []) if s.endswith(".swift")]


def removals(pkg, t, should_remove, platform, model):
    """{file: (original, stripped, removed)} for a target; each removed
    import carries `active`: whether the platform compiles it."""
    out = {}
    for rel in target_files(pkg, t):
        path = os.path.join(pkg, rel)
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except (OSError, UnicodeDecodeError):
            continue
        new, removed = strip.strip(text, should_remove)
        if not removed:
            continue
        code = strip_comments_and_strings(text)[0].split("\n")
        try:
            states, _, _ = platforms.swift_line_states(code, model)
        except (ValueError, IndexError):
            states = None
        for r in removed:
            st = states[r["line"] - 1] if states and r["line"] - 1 < len(states) else None
            r["active"] = True if st is None else platform in st
            r["maybe"] = bool(st and platform in st and st[platform][0] == platforms.M)
        out[rel] = (text, new, removed)
    return out


def imports_of(text, module):
    return any(m == module for _, m, _, _ in strip.imports(text))


def with_import_first(text, line):
    """(text, the 1-based line inserted) with an import line first, after
    a `#!` line if there is one."""
    lines = text.split("\n")
    at = 1 if lines and lines[0].startswith("#!") else 0
    return "\n".join(lines[:at] + [line] + lines[at:]), at + 1


# ---------------------------------------------------------------- builds

class Builder:
    def __init__(self, platform, work, name, args, pkg=None, swiftpm=()):
        self.platform, self.work, self.name, self.args = platform, work, name, args
        self.pkg = pkg or os.path.join(work, "src", name)
        self.rel = os.path.relpath(self.pkg, work)
        self.swiftpm = list(swiftpm)
        self.logs = os.path.join(work, "logs")
        os.makedirs(self.logs, exist_ok=True)
        self.scratch = os.path.join(work, f"scratch-{platform}")
        self.count = 0

    @property
    def roots(self):
        if self.platform == "linux":
            return [f"/code/{self.rel}"]
        return [self.pkg, os.path.realpath(self.pkg)]

    def build(self, label, target=None):
        """(exit status, log text, seconds, log path) of one build."""
        self.count += 1
        log_path = os.path.join(self.logs, f"{self.count:03d}-{label}.log")
        extra = ["-Xswiftc", "-continue-building-after-errors"]
        if target:
            extra = ["--target", target] + extra
        start = time.time()
        if self.platform == "linux":
            cmd = [LINUX_BUILD, "--quiet", "--root", self.work, "--dir", self.rel,
                   "--scratch", os.path.relpath(self.scratch, self.pkg), "--log", log_path]
            if self.args.swift:
                cmd += ["--swift", self.args.swift]
            cmd += ["build" if target else "build-tests", "--"] + self.swiftpm + extra
            p = subprocess.run(cmd, capture_output=True, text=True)
            with open(log_path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            text += "\n" + p.stdout + p.stderr
        else:
            cmd = ["swift", "build", "--disable-sandbox", *self.swiftpm, "--package-path", self.pkg,
                   "--scratch-path", self.scratch]
            if not target:
                cmd.append("--build-tests")
            cmd += extra
            p = subprocess.run(cmd, capture_output=True, text=True)
            text = p.stdout + p.stderr
            with open(log_path, "w", encoding="utf-8") as f:
                f.write(" ".join(cmd) + "\n" + text)
        return p.returncode, text, round(time.time() - start, 1), log_path


def build_target(b, pkg, t, texts, label, base_keys):
    """Builds target t alone with some of its files' texts replaced
    ({file: text}), every file of it recompiled (an import one file
    re-exports serves the whole module, and an incremental build recompiles
    only the files it thinks changed), then restores them. Returns (exit,
    errors in the target's files, errors elsewhere, seconds, log path),
    less the baseline's."""
    originals = {}
    for rel, new in texts.items():
        path = os.path.join(pkg, rel)
        with open(path, encoding="utf-8") as f:
            originals[rel] = f.read()
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
    now = time.time()
    for rel in target_files(pkg, t):
        try:
            os.utime(os.path.join(pkg, rel), (now, now))
        except OSError:
            pass
    try:
        code, text, secs, lp = b.build(label, t["name"])
    finally:
        for rel, orig in originals.items():
            with open(os.path.join(pkg, rel), "w", encoding="utf-8") as f:
                f.write(orig)
    found = [d for d in diags.parse(text, b.roots) if (d["file"], d["line"], d["message"]) not in base_keys]
    mine = set(texts) | set(target_files(pkg, t))
    return (code, [d for d in found if d["file"] in mine], [d for d in found if d["file"] not in mine], secs, lp)


def code_reader(pkg):
    """code_of(file) for diags.split: a file's lines with comments and
    strings blanked, or None."""
    cache = {}

    def code_of(rel):
        if rel not in cache:
            try:
                with open(os.path.join(pkg, rel), encoding="utf-8") as f:
                    cache[rel] = strip_comments_and_strings(f.read())[0].split("\n")
            except (OSError, UnicodeDecodeError):
                cache[rel] = None
        return cache[rel]
    return code_of


def name_records(prim, pkg, removed_modules, classify_name):
    """[(diagnostic, kind, name, module, (class, unit, how))] for a build's
    primary diagnostics: `cannot find 'Glibc'` for a removed module is a
    qualified use, read from the source."""
    out = []
    for d, kind, nm, details in prim:
        module = details.get("module")
        if kind == "value" and nm in removed_modules:
            with open(os.path.join(pkg, d["file"]), encoding="utf-8") as f:
                line = f.read().split("\n")[d["line"] - 1]
            q = diags.qualified_name(line, d["col"], nm)
            if q:
                kind, module, nm = "qualified", nm, q
        out.append((d, kind, nm, module, classify_name(nm, kind)))
    return out


# ---------------------------------------------------------------- one package

def probe(clone, branch, platform, args, repo, head, subdir="."):
    clone = os.path.abspath(clone)
    name = os.path.basename(clone.rstrip("/"))
    shown = display_name(name, subdir)
    branch = branch or newest_branch(clone)
    if not branch:
        raise RuntimeError(f"{clone} has none of the branches {', '.join(BRANCHES)}; give --branch")
    commit = commit_of(clone, branch)
    if not commit:
        raise RuntimeError(f"{clone} has no branch or commit {branch}")
    system_commit = commit_of(repo, args.system)
    if not system_commit:
        raise RuntimeError(f"no System commit {args.system} in {repo}")
    work = os.path.join(args.work, f"{shown}-{platform}")
    gb = free_gb(args.work)
    if gb < args.min_free_gb:
        raise RuntimeError(f"only {gb:.1f} GiB free (less than {args.min_free_gb}); not starting {shown}")
    log(f"{shown} {branch} @ {commit[:10]} on {platform}, against System {system_commit[:10]}; scratch {work}")
    fresh_work(work)
    plat = classify.PLATFORM[platform]
    cfg = package_config(name, subdir)
    swiftpm = getattr(args, "swiftpm", ())
    started = time.time()
    result = {"meta": {"package": name, "clone": clone, "branch": branch, "commit": commit, "platform": platform,
                       "platformName": plat, "system": system_commit, "tool": head,
                       "date": datetime.date.today().isoformat(), "shims": cfg["shims"], "note": cfg["note"]},
              "targets": [], "records": [], "followOns": [], "others": [], "outside": [], "baseline": None,
              "foundationFiles": [], "reexporters": {}, "reachesThrough": {}}
    if os.path.normpath(subdir) != ".":
        result["meta"].update(nested=os.path.normpath(subdir), name=shown)
    try:
        pkg, rec = prepare(clone, commit, name, work, repo, system_commit, subdir, path_dep_refs(args.path_dep),
                           swiftpm)
        result["meta"]["preparation"] = rec
        b = Builder(platform, work, name, args, pkg, swiftpm)
        desc = describe(pkg, os.path.join(work, "scratch-macos"), b.logs, swiftpm)
        mods = classify.modules(repo, head)
        should_remove = strip.module_matcher(mods, cfg["shims"])
        own_modules = {t["c99name"] for t in desc["targets"]} | {"SystemPackage", "SystemSockets", "CSystem"}
        for d in result["meta"]["preparation"]["dependencies"]:
            own_modules.add(d["identity"])
        model = platforms.model(imports=own_modules)
        targets = ordered_targets(desc)
        if args.targets:
            wanted = set(args.targets.split(","))
            targets = [t for t in targets if t["name"] in wanted]
        clang = {t["c99name"] for t in desc["targets"] if t.get("module_type") == "ClangTarget"}
        own_c = {t["c99name"] for t in desc["targets"] if t.get("module_type") in OWN_C_TYPES} - set(cfg["shims"])
        plan, own_plan = [], {}
        result["files"] = {f: t["name"] for t in desc["targets"] for f in target_files(pkg, t)}
        for t in targets:
            entry = {"name": t["name"], "type": t.get("type"), "moduleType": t.get("module_type"),
                     "dependencies": t.get("target_dependencies", []), "files": len(target_files(pkg, t))}
            result["targets"].append(entry)
            if t.get("module_type") != "SwiftTarget":
                entry["status"] = "not Swift"
                continue
            rem = removals(pkg, t, should_remove, plat, model)
            entry["removed"] = [dict(r, file=f) for f, (_, _, rs) in sorted(rem.items()) for r in rs]
            active = [r for r in entry["removed"] if r["active"]]
            if any(r["exported"] for r in active):
                result["reexporters"][t["c99name"]] = sorted({r["module"] for r in active if r["exported"]})
            for rel in target_files(pkg, t):
                try:
                    with open(os.path.join(pkg, rel), encoding="utf-8") as f:
                        text = f.read()
                except (OSError, UnicodeDecodeError):
                    continue
                if imports_of(text, "Foundation"):
                    result["foundationFiles"].append({"target": t["name"], "file": rel})
                c_imports = sorted({m for _, m, _, _ in strip.imports(text) if m in clang})
                if c_imports:
                    result.setdefault("clangImports", []).append({"target": t["name"], "file": rel,
                                                                  "modules": c_imports})
            if not entry["removed"]:
                entry["status"] = "no imports to remove"
            elif not active and not args.no_skip:
                entry["status"] = f"no removed import compiled on {plat}"
            else:
                entry["status"] = "to probe"
                plan.append((t, entry, rem))
            if args.own_modules and own_c:
                both = removals(pkg, t, lambda m: should_remove(m) or m in own_c, plat, model)
                if any(r["active"] and r["module"] in own_c for _, _, rs in both.values() for r in rs):
                    own_plan[t["name"]] = both
        # Targets that reach C through another target's re-export.
        by_name = {t["name"]: t for t in desc["targets"]}
        c99 = {t["name"]: t["c99name"] for t in desc["targets"]}

        def deps_of(n, seen=None):
            seen = set() if seen is None else seen
            for d in by_name.get(n, {}).get("target_dependencies", []):
                if d not in seen:
                    seen.add(d)
                    deps_of(d, seen)
            return seen
        for t in targets:
            via = sorted(c99[d] for d in deps_of(t["name"]) if c99.get(d) in result["reexporters"])
            if via:
                result["reachesThrough"][t["name"]] = via
        if args.own_modules:
            result["ownModules"] = {"modules": sorted(own_c), "targets": [], "records": [], "ownNames": {}}
        if plan or own_plan:
            log(f"{shown}: {len(plan)} of {len(targets)} targets to probe"
                + (f", {len(own_plan)} with the package's own C modules" if args.own_modules else "")
                + "; baseline build")
            code, text, secs, lp = b.build("baseline")
            base = diags.parse(text, b.roots)
            result["baseline"] = {"exit": code, "seconds": secs, "errors": len(base), "log": os.path.relpath(lp, work)}
            base_keys = {(d["file"], d["line"], d["message"]) for d in base}
            if code != 0:
                log(f"{shown}: the baseline build failed ({len(base)} errors); probe errors that match them are "
                    "dropped")

            def classify_name(nm, kind):
                return result_class(nm, plat, kind, cfg, pkg, desc)
            planned = {t["name"]: (t, entry, rem) for t, entry, rem in plan}
            for t in targets:
                ordinary = []
                if t["name"] in planned:
                    _, entry, rem = planned[t["name"]]
                    code, inside_t, outside_t, secs, lp = build_target(
                        b, pkg, t, {rel: new for rel, (_, new, _) in rem.items()}, t["name"].replace("/", "_"),
                        base_keys)
                    result["outside"] += [dict(d, target=t["name"]) for d in outside_t]
                    prim, follow, other = diags.split(inside_t, code_reader(pkg))
                    removed_modules = {r["module"] for r in entry["removed"]}
                    for d, kind, nm, module, (cls, unit, how) in name_records(prim, pkg, removed_modules,
                                                                               classify_name):
                        ordinary.append((d["file"], nm))
                        result["records"].append({
                            "package": name, "branch": branch, "commit": commit, "platform": platform,
                            "target": t["name"], "file": d["file"], "line": d["line"], "column": d["col"],
                            "name": nm, "kind": kind, "module": module, "class": cls, "unit": unit, "how": how,
                            "message": d["message"], **({"nested": result["meta"]["nested"]}
                                                        if "nested" in result["meta"] else {})})
                    result["followOns"] += [dict(d, target=t["name"]) for d in follow]
                    result["others"] += [dict(d, target=t["name"]) for d in other]
                    entry.update({"status": "probed", "exit": code, "seconds": secs, "log": os.path.relpath(lp, work),
                                  "names": len(prim), "followOns": len(follow), "others": len(other)})
                    log(f"{shown}: {t['name']}: {len(prim)} names, {len(follow)} follow-ons, {len(other)} other "
                        f"errors ({secs} s)")
                if t["name"] in own_plan:
                    own_pass(b, pkg, t, own_plan[t["name"]], own_c, ordinary, base_keys, platform, classify_name,
                             result, work, shown)
        else:
            log(f"{shown}: no target has a removed import compiled on {plat}; nothing to build")
    finally:
        result["meta"]["seconds"] = round(time.time() - started, 1)
        if args.keep:
            result["meta"]["work"] = work
        else:
            remove_work(work)
    return result


def own_pass(b, pkg, t, both, own_c, ordinary, base_keys, platform, classify_name, result, work, shown):
    """--own-modules for one target: built without its imports of the
    package's own C modules as well as its C imports (X1), then with the
    platform's C library imported first in each of its files (X2). A name
    X1 can't find in a file, X2 can and the ordinary probe's build could
    (`ordinary`, [(file, name)]) is one the file took from the C library
    through its own C module."""
    x1 = {rel: new for rel, (_, new, _) in both.items()}
    label = t["name"].replace("/", "_")
    code1, in1, out1, secs1, lp1 = build_target(b, pkg, t, x1, f"{label}-own", base_keys)
    library = f"@preconcurrency import {C_LIBRARY[platform]} // import-probe: the C library, for --own-modules"
    x2, inserted = {}, {}
    for rel in target_files(pkg, t):
        try:
            if rel in x1:
                text = x1[rel]
            else:
                with open(os.path.join(pkg, rel), encoding="utf-8") as f:
                    text = f.read()
        except (OSError, UnicodeDecodeError):
            continue
        x2[rel], inserted[rel] = with_import_first(text, library)
    code2, in2, _, secs2, lp2 = build_target(b, pkg, t, x2, f"{label}-own-library", set())
    # X2's lines are one more than the file's after the inserted import.
    for d in in2:
        if d["file"] in inserted and d["line"] > inserted[d["file"]]:
            d["line"] -= 1
    in2 = [d for d in in2 if (d["file"], d["line"], d["message"]) not in base_keys]
    removed = {r["module"] for _, _, rs in both.values() for r in rs}
    prim1, _, other1 = diags.split(in1, code_reader(pkg))
    prim2, _, _ = diags.split(in2, code_reader(pkg))
    recs1 = name_records(prim1, pkg, removed, classify_name)
    missing2 = {(d["file"], nm) for d, kind, nm, module, _ in name_records(prim2, pkg, removed, lambda n, k: None)}
    plain = set(ordinary)
    via_of = {rel: sorted({r["module"] for r in rs if r["module"] in own_c and r["active"]})
              for rel, (_, _, rs) in both.items()}
    through, own_names = [], {}
    for d, kind, nm, module, (cls, unit, how) in recs1:
        key = (d["file"], nm)
        if key in missing2:
            own_names.setdefault(d["file"], set()).add(nm)
        elif key not in plain:
            through.append({"package": result["meta"]["package"], "commit": result["meta"]["commit"],
                            "platform": result["meta"]["platform"], "target": t["name"], "file": d["file"],
                            "line": d["line"], "column": d["col"], "name": nm, "kind": kind, "module": module,
                            "via": via_of.get(d["file"]) or ["(another file's re-export)"], "class": cls,
                            "unit": unit, "how": how, "message": d["message"]})
    om = result["ownModules"]
    om["records"] += through
    for f, ns in own_names.items():
        om["ownNames"][f] = sorted(ns)
    om["targets"].append({"name": t["name"], "files": sorted(f for f, v in via_of.items() if v),
                          "withoutModules": {"exit": code1, "seconds": secs1, "log": os.path.relpath(lp1, work),
                                             "names": len(prim1), "others": len(other1)},
                          "withLibrary": {"exit": code2, "seconds": secs2, "log": os.path.relpath(lp2, work),
                                          "names": len(prim2)},
                          "through": len(through), "ownNames": sum(len(v) for v in own_names.values()),
                          "outside": len(out1)})
    log(f"{shown}: {t['name']}: {len(through)} names through the package's own C modules, "
        f"{sum(len(v) for v in own_names.values())} of the modules' own ({secs1} s + {secs2} s)")


CLASSIFIER = {}


def result_class(name, plat, kind, cfg, pkg, desc):
    """(class, unit, how), with a configured shim's own declarations as
    `shim's own`."""
    for shim in cfg["shims"]:
        t = next((t for t in desc["targets"] if t["c99name"] == shim), None)
        if t and declares(pkg, t, name):
            return "shim's own", shim, f"declared in {shim}"
    return CLASSIFIER["c"].classify(name, plat, kind)


def declares(pkg, t, name):
    """Whether a shim target declares the name itself: in its Swift
    sources, or its C headers and sources (ledger.py's C_DECLARES)."""
    import re
    import ledger
    swift = re.compile(rf"\b(?:func|var|let|typealias|struct|class|enum|protocol|case)\s+`?{re.escape(name)}\b")
    root = os.path.join(pkg, t["path"])
    for dirpath, _, files in os.walk(root):
        for f in files:
            if not f.endswith((".swift", ".h", ".c", ".cpp", ".hpp", ".m")):
                continue
            try:
                text = open(os.path.join(dirpath, f), encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                continue
            if f.endswith(".swift"):
                if swift.search(text):
                    return True
            elif name in text and any(name in [g for g in m.groups() if g]
                                      for line in text.split("\n")
                                      for m in [ledger.C_DECLARES.match(line)] if m):
                return True
    return False


def package_dirs(clone, branch, args):
    """The clone's package directories to probe: --package-dir's, else the
    root and, with --nested, every nested package."""
    if args.package_dir:
        return [os.path.normpath(d) for part in args.package_dir for d in part.split(",") if d]
    dirs = ["."]
    if args.nested:
        branch = branch or newest_branch(os.path.abspath(clone))
        commit = branch and commit_of(os.path.abspath(clone), branch)
        if commit:
            dirs += nested_packages(os.path.abspath(clone), commit)
    return dirs


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("clones", nargs="+")
    ap.add_argument("--linux", action="store_true")
    ap.add_argument("--branch")
    ap.add_argument("--system", default="system-next")
    ap.add_argument("--targets")
    ap.add_argument("--swift", help="the Linux image's Swift version (build.sh --swift)")
    ap.add_argument("--work")
    ap.add_argument("--out")
    ap.add_argument("--ledger", help="ledger.json from status.sh, for the summary's comparison")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--no-skip", action="store_true")
    ap.add_argument("--min-free-gb", type=float, default=15)
    ap.add_argument("--nested", action="store_true",
                    help="also probe each nested package of the branch (a directory with its own Package.swift)")
    ap.add_argument("--package-dir", action="append",
                    help="probe these package directories of the clone instead (`.` is the root); repeatable")
    ap.add_argument("--path-dep", action="append", default=[],
                    help="IDENTITY=REF or IDENTITY=REPO@REF: export that local path dependency at REF")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--own-modules", action="store_true",
                      help="also find the C names files reach through the package's own C modules")
    mode.add_argument("--reexport", action="store_true",
                      help="the re-export run instead: names a package gets only through an `@_exported import` "
                           "of a C module (reexport.py)")
    args = ap.parse_args()
    path_dep_refs(args.path_dep)
    repo = git(HERE, "rev-parse", "--show-toplevel").strip()
    head = commit_of(repo, "HEAD")
    # The tool's own state, for the record: uncommitted changes to it make
    # its id `<commit>-dirty`.
    tool_id = head + ("-dirty" if git(repo, "status", "--porcelain", "--", os.path.relpath(TOOL, repo)).strip()
                      else "")
    args.work = os.path.abspath(args.work or os.path.join(repo, ".build", "import-probe", "work"))
    args.out = os.path.abspath(args.out or os.path.join(repo, ".build", "import-probe", "out"))
    for d in (args.work, args.out):
        refuse_tracked(d, repo)
    platform = "linux" if args.linux else "macos"
    if platform == "linux" and not shutil.which("container"):
        sys.exit("import-probe: --linux needs Apple's `container` tool (Utilities/linux/README.md)")
    if args.reexport:
        # reexport.py imports this module by name; this run's is __main__.
        sys.modules.setdefault("probe", sys.modules[__name__])
        import reexport
    status = 0
    for clone in args.clones:
        for subdir in package_dirs(clone, args.branch, args):
            try:
                system_commit = commit_of(repo, args.system)
                if "c" not in CLASSIFIER or CLASSIFIER["c"].system_commit != system_commit:
                    CLASSIFIER["c"] = classify.Classifier(repo, head, system_commit,
                                                          os.path.join(os.path.dirname(args.work), "system-cache"))
                if args.reexport:
                    result = reexport.run(clone, args.branch, platform, args, repo, head, subdir)
                else:
                    result = probe(clone, args.branch, platform, args, repo, head, subdir)
                result["meta"]["tool"] = tool_id
            except (RuntimeError, LookupError, ValueError, subprocess.CalledProcessError) as e:
                log(f"{clone}{'' if subdir == '.' else ' ' + subdir}: {e}")
                status = 1
                continue
            out = os.path.join(args.out, display_name(result["meta"]["package"], subdir))
            os.makedirs(out, exist_ok=True)
            path = os.path.join(out, f"{platform}{'-reexport' if args.reexport else ''}.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=1)
            ledger_path = args.ledger or os.path.join(repo, ".build", "status", "ledger.json")
            md = summary.write(out, ledger_path if os.path.isfile(ledger_path) else None)
            log(f"wrote {path} and {md}")
    combined = []
    for p in sorted(glob.glob(os.path.join(args.out, "*", "import-probe.json"))):
        with open(p, encoding="utf-8") as f:
            combined += json.load(f)
    with open(os.path.join(args.out, "import-probe.json"), "w", encoding="utf-8") as f:
        json.dump(combined, f, indent=1)
    return status


if __name__ == "__main__":
    sys.exit(main())
