#!/usr/bin/env python3
"""The compiler's own list of what a package still takes from the platform
C modules: build an export of one branch with a target's imports of them
removed, one target at a time, and read what the compiler can't find.

Usage: probe.py [--linux] [--branch BRANCH] [--system REF] [--targets T,...]
                [--work DIR] [--out DIR] [--keep] [--no-skip] [--min-free-gb N]
                CLONE...

For each clone (a checkout of a package: a clone or a worktree):
  1. The branch (default: its newest migration branch, migrate-all, then
     migrate-unix, then migrate-darwin) is exported with `git archive` into
     a scratch directory, WORK/<package>-<platform>/src/<package>. The
     clone is only read.
  2. Its dependencies become path dependencies on exports in WORK/.../deps:
     System at --system (default system-next, in this worktree), and remote
     packages from SwiftPM's cache (manifests.py). Nothing is fetched.
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
     files are restored.
  5. The errors in the target's files are read (diags.py), less the
     baseline's, and each name is classified against System (classify.py).
  6. WORK/... is deleted unless --keep; OUT/<package>/<platform>.json is
     written, and summary.py's OUT/<package>/SUMMARY.md.

--linux builds in a container through Utilities/linux/build.sh (--root the
scratch directory, --dir the package), with the image's Swift; macOS is
the default.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
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
    os.makedirs(dest, exist_ok=True)
    archive = subprocess.run(["git", "--no-optional-locks", "-C", repo, "archive", commit], capture_output=True,
                             check=True, env=GIT_ENV).stdout
    subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)


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

def package_config(name):
    """packages.ini's settings for a package: shims (modules whose imports
    are removed like a C module's) and a note."""
    import configparser
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    cp.read(os.path.join(TOOL, "packages.ini"), encoding="utf-8")
    if not cp.has_section(name):
        return {"shims": [], "note": ""}
    sec = dict(cp.items(name))
    return {"shims": sec.get("shims", "").split(), "note": " ".join(sec.get("note", "").split())}


# ---------------------------------------------------------------- the copy

def prepare(clone, commit, name, work, repo, system_commit):
    """Exports the package and its dependencies, rewrites the manifests;
    returns what was done, for the record."""
    pkg = os.path.join(work, "src", name)
    export(clone, commit, pkg)
    deps = os.path.join(work, "deps")
    record = {"system": system_commit, "dependencies": []}
    sysdir = os.path.join(deps, "swift-system")
    export(repo, system_commit, sysdir)
    sm = os.path.join(sysdir, "Package.swift")
    with open(sm, encoding="utf-8") as f:
        text = f.read()
    with open(sm, "w", encoding="utf-8") as f:
        f.write(manifests.drop_samples(text))
    paths = {"swift-system": "../../deps/swift-system"}
    pins = manifests.resolved_pins(pkg)
    for m in manifests.manifests(pkg):
        with open(os.path.join(pkg, m), encoding="utf-8") as f:
            text = f.read()
        for d in manifests.dependencies(text):
            ident = d["identity"]
            if d["kind"] != "url" or ident in paths:
                continue
            clone_dir, rev, version = manifests.choose(d["location"], d["requirement"], pins.get(ident))
            export(clone_dir, rev, os.path.join(deps, ident))
            paths[ident] = f"../../deps/{ident}"
            record["dependencies"].append({"identity": ident, "url": d["location"], "requirement": d["requirement"],
                                           "version": version, "revision": rev})
    for m in manifests.manifests(pkg):
        p = os.path.join(pkg, m)
        with open(p, encoding="utf-8") as f:
            text = f.read()
        new, done = manifests.rewrite(text, paths)
        if new != text:
            with open(p, "w", encoding="utf-8") as f:
                f.write(new)
        record.setdefault("rewrites", {})[m] = done
    return pkg, record


def describe(pkg, scratch, logs):
    p = subprocess.run(["swift", "package", "--disable-sandbox", "--package-path", pkg, "--scratch-path", scratch,
                        "describe", "--type", "json"], capture_output=True, text=True)
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


# ---------------------------------------------------------------- builds

class Builder:
    def __init__(self, platform, work, name, args):
        self.platform, self.work, self.name, self.args = platform, work, name, args
        self.pkg = os.path.join(work, "src", name)
        self.logs = os.path.join(work, "logs")
        os.makedirs(self.logs, exist_ok=True)
        self.scratch = os.path.join(work, f"scratch-{platform}")
        self.count = 0

    @property
    def roots(self):
        if self.platform == "linux":
            return [f"/code/src/{self.name}"]
        return [self.pkg, os.path.realpath(self.pkg)]

    def build(self, label, target=None):
        """(exit status, log text, seconds) of one build."""
        self.count += 1
        log_path = os.path.join(self.logs, f"{self.count:03d}-{label}.log")
        extra = ["-Xswiftc", "-continue-building-after-errors"]
        if target:
            extra = ["--target", target] + extra
        start = time.time()
        if self.platform == "linux":
            cmd = [LINUX_BUILD, "--quiet", "--root", self.work, "--dir", f"src/{self.name}",
                   "--scratch", "../../scratch-linux", "--log", log_path]
            if self.args.swift:
                cmd += ["--swift", self.args.swift]
            cmd += ["build" if target else "build-tests", "--"] + extra
            p = subprocess.run(cmd, capture_output=True, text=True)
            with open(log_path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            text += "\n" + p.stdout + p.stderr
        else:
            cmd = ["swift", "build", "--disable-sandbox", "--package-path", self.pkg, "--scratch-path", self.scratch]
            if not target:
                cmd.append("--build-tests")
            cmd += extra
            p = subprocess.run(cmd, capture_output=True, text=True)
            text = p.stdout + p.stderr
            with open(log_path, "w", encoding="utf-8") as f:
                f.write(" ".join(cmd) + "\n" + text)
        return p.returncode, text, round(time.time() - start, 1), log_path


# ---------------------------------------------------------------- one package

def probe(clone, branch, platform, args, repo, head):
    clone = os.path.abspath(clone)
    name = os.path.basename(clone.rstrip("/"))
    branch = branch or newest_branch(clone)
    if not branch:
        raise RuntimeError(f"{clone} has none of the branches {', '.join(BRANCHES)}; give --branch")
    commit = commit_of(clone, branch)
    if not commit:
        raise RuntimeError(f"{clone} has no branch or commit {branch}")
    system_commit = commit_of(repo, args.system)
    if not system_commit:
        raise RuntimeError(f"no System commit {args.system} in {repo}")
    work = os.path.join(args.work, f"{name}-{platform}")
    gb = free_gb(args.work)
    if gb < args.min_free_gb:
        raise RuntimeError(f"only {gb:.1f} GiB free (less than {args.min_free_gb}); not starting {name}")
    log(f"{name} {branch} @ {commit[:10]} on {platform}, against System {system_commit[:10]}; scratch {work}")
    fresh_work(work)
    plat = classify.PLATFORM[platform]
    cfg = package_config(name)
    started = time.time()
    result = {"meta": {"package": name, "clone": clone, "branch": branch, "commit": commit, "platform": platform,
                       "platformName": plat, "system": system_commit, "tool": head,
                       "date": datetime.date.today().isoformat(), "shims": cfg["shims"], "note": cfg["note"]},
              "targets": [], "records": [], "followOns": [], "others": [], "outside": [], "baseline": None,
              "foundationFiles": [], "reexporters": {}, "reachesThrough": {}}
    try:
        pkg, rec = prepare(clone, commit, name, work, repo, system_commit)
        result["meta"]["preparation"] = rec
        b = Builder(platform, work, name, args)
        desc = describe(pkg, os.path.join(work, "scratch-macos"), b.logs)
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
        plan = []
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
                    text = open(os.path.join(pkg, rel), encoding="utf-8").read()
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
        if plan:
            log(f"{name}: {len(plan)} of {len(targets)} targets to probe; baseline build")
            code, text, secs, lp = b.build("baseline")
            base = diags.parse(text, b.roots)
            result["baseline"] = {"exit": code, "seconds": secs, "errors": len(base), "log": os.path.relpath(lp, work)}
            base_keys = {(d["file"], d["line"], d["message"]) for d in base}
            if code != 0:
                log(f"{name}: the baseline build failed ({len(base)} errors); probe errors that match them are "
                    "dropped")
            for t, entry, rem in plan:
                for rel, (_, new, _) in rem.items():
                    with open(os.path.join(pkg, rel), "w", encoding="utf-8") as f:
                        f.write(new)
                # Every file of the target is compiled again: an import one
                # file re-exports (`@_exported`) serves the whole module, and
                # an incremental build recompiles only the files it thinks
                # changed.
                now = time.time()
                for rel in target_files(pkg, t):
                    try:
                        os.utime(os.path.join(pkg, rel), (now, now))
                    except OSError:
                        pass
                try:
                    code, text, secs, lp = b.build(t["name"].replace("/", "_"), t["name"])
                finally:
                    for rel, (orig, _, _) in rem.items():
                        with open(os.path.join(pkg, rel), "w", encoding="utf-8") as f:
                            f.write(orig)
                found = [d for d in diags.parse(text, b.roots) if (d["file"], d["line"], d["message"]) not in base_keys]
                mine = set(rem) | set(target_files(pkg, t))
                inside = [d for d in found if d["file"] in mine]
                result["outside"] += [dict(d, target=t["name"]) for d in found if d["file"] not in mine]
                code_cache = {}

                def code_of(rel):
                    if rel not in code_cache:
                        try:
                            code_cache[rel] = strip_comments_and_strings(
                                open(os.path.join(pkg, rel), encoding="utf-8").read())[0].split("\n")
                        except (OSError, UnicodeDecodeError):
                            code_cache[rel] = None
                    return code_cache[rel]
                prim, follow, other = diags.split(inside, code_of)
                removed_modules = {r["module"] for r in entry["removed"]}
                for d, kind, nm, details in prim:
                    module = details.get("module")
                    if kind == "value" and nm in removed_modules:
                        line = (open(os.path.join(pkg, d["file"]), encoding="utf-8").read().split("\n")
                                [d["line"] - 1])
                        q = diags.qualified_name(line, d["col"], nm)
                        if q:
                            kind, module, nm = "qualified", nm, q
                    cls, unit, how = result_class(b, nm, plat, kind, cfg, pkg, desc)
                    result["records"].append({
                        "package": name, "branch": branch, "commit": commit, "platform": platform,
                        "target": t["name"], "file": d["file"], "line": d["line"], "column": d["col"],
                        "name": nm, "kind": kind, "module": module, "class": cls, "unit": unit, "how": how,
                        "message": d["message"]})
                result["followOns"] += [dict(d, target=t["name"]) for d in follow]
                result["others"] += [dict(d, target=t["name"]) for d in other]
                entry.update({"status": "probed", "exit": code, "seconds": secs, "log": os.path.relpath(lp, work),
                              "names": len(prim), "followOns": len(follow), "others": len(other)})
                log(f"{name}: {t['name']}: {len(prim)} names, {len(follow)} follow-ons, {len(other)} other errors "
                    f"({secs} s)")
        else:
            log(f"{name}: no target has a removed import compiled on {plat}; nothing to build")
    finally:
        result["meta"]["seconds"] = round(time.time() - started, 1)
        if args.keep:
            result["meta"]["work"] = work
        else:
            remove_work(work)
    return result


CLASSIFIER = {}


def result_class(builder, name, plat, kind, cfg, pkg, desc):
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
    args = ap.parse_args()
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
    status = 0
    for clone in args.clones:
        try:
            system_commit = commit_of(repo, args.system)
            if "c" not in CLASSIFIER or CLASSIFIER["c"].system_commit != system_commit:
                CLASSIFIER["c"] = classify.Classifier(repo, head, system_commit,
                                                      os.path.join(os.path.dirname(args.work), "system-cache"))
            result = probe(clone, args.branch, platform, args, repo, head)
            result["meta"]["tool"] = tool_id
        except (RuntimeError, LookupError, ValueError, subprocess.CalledProcessError) as e:
            log(f"{clone}: {e}")
            status = 1
            continue
        out = os.path.join(args.out, result["meta"]["package"])
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, f"{platform}.json")
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
