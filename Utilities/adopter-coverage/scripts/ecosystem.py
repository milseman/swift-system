#!/usr/bin/env python3
"""The toolchain's Swift packages: the ones swift's update-checkout clones
for the main branch scheme, and which of them import Darwin.

  ecosystem.py scheme  ECOSYSTEM          the main scheme's repositories, from
                                          ECOSYSTEM/swift's utils/update_checkout
  ecosystem.py clone   ECOSYSTEM          shallow clones of the Swift packages
                                          among them, at the scheme's refs
  ecosystem.py survey  ECOSYSTEM OUT      each clone's manifest tools version and
                                          a lexical count of the files of its library
                                          targets that import Darwin
  ecosystem.py packages SURVEY PACKAGES   a package file per Darwin-importing
                                          package, in PACKAGES/ecosystem
  ecosystem.py specs   SURVEY             check.sh's arguments for the ecosystem run
  ecosystem.py latest-run SURVEY RESULTS  the newest stored run with every one of them
  ecosystem.py report  RUN_DIR RESULTS SURVEY MAPPING SWIFTSHIMS OUT.md
                                          the ecosystem report for a run

The four audited adopters (swift-nio, swift-foundation, swiftpm,
swift-subprocess) keep their own package files, pointed at the ecosystem's
clones; the others get generated ones (see packages/ecosystem/README.md).
Nothing here edits a clone after it's made.
"""

import sys

sys.dont_write_bytecode = True

import collections
import json
import os
import re
import subprocess

# The audited adopters, by repository: their package files in packages/.
AUDITED = {"swift-nio": "nio", "swift-foundation": "foundation", "swiftpm": "swiftpm",
           "swift-subprocess": "subprocess"}
IMPORT_DARWIN = re.compile(r"^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:(?:public|internal|package|private|fileprivate)\s+)?"
                           r"import\s+(?:(?:func|let|var|struct|class|enum|typealias|protocol)\s+)?Darwin\b", re.M)
EXPORTED_DARWIN = re.compile(r"@_exported\s+(?:@[\w.]+\s+)*(?:public\s+)?import\s+Darwin\b")
# Directories that don't hold library code, for the lexical pre-scan.
NOT_LIBRARY = re.compile(r"(^|/)(Tests?|IntegrationTests|Benchmarks?|Examples?|Fixtures|Snippets|Plugins|"
                         r"Documentation|docs|Utilities|utils|Tools|TestInputs|TestSupport|Inputs|\.build)(/|$)", re.I)


def config_path(eco):
    return os.path.join(eco, "swift", "utils", "update_checkout", "update-checkout-config.json")


def scheme(eco):
    c = json.load(open(config_path(eco)))
    main = c["branch-schemes"]["main"]["repos"]
    out = []
    for name, ref in sorted(main.items()):
        r = c["repos"].get(name, {})
        out.append({"name": name, "ref": ref, "remote": r.get("remote", {}).get("id", ""),
                    "platforms": r.get("platforms", [])})
    return out


def git(*args, cwd=None):
    return subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True, text=True)


def clone(eco):
    for r in scheme(eco):
        dest = os.path.join(eco, r["name"])
        if r["name"] == "swift" or os.path.isdir(os.path.join(dest, ".git")):
            continue
        url = f"https://github.com/{r['remote']}.git"
        # A branch or tag clones shallowly; a commit needs a fetch of it.
        p = git("clone", "--quiet", "--depth", "1", "--branch", r["ref"], url, dest)
        if p.returncode != 0 and re.fullmatch(r"[0-9a-f]{40}", r["ref"]):
            os.makedirs(dest, exist_ok=True)
            git("init", "--quiet", cwd=dest)
            git("remote", "add", "origin", url, cwd=dest)
            p = git("fetch", "--quiet", "--depth", "1", "origin", r["ref"], cwd=dest)
            if p.returncode == 0:
                p = git("checkout", "--quiet", "FETCH_HEAD", cwd=dest)
        print(f"{r['name']}: {'cloned' if p.returncode == 0 else 'FAILED: ' + p.stderr.strip()[:200]}")


def library_dirs(d):
    """The directories of the package's regular targets (its library code),
    from `swift package dump-package` on an export in a temporary directory:
    the clone is never written to. None if the manifest can't be read, even
    with its tools version lowered to this toolchain's."""
    import shutil
    import tempfile
    tmp = tempfile.mkdtemp(prefix="ecosystem-survey.")
    try:
        archive = subprocess.run(["git", "-C", d, "archive", "HEAD", "Package.swift"], capture_output=True).stdout
        subprocess.run(["tar", "-x", "-C", tmp], input=archive)
        for attempt in (0, 1):
            p = subprocess.run(["swift", "package", "--disable-sandbox", "--package-path", tmp, "--scratch-path",
                                os.path.join(tmp, ".build"), "dump-package"], capture_output=True, text=True)
            if p.returncode == 0:
                break
            if attempt == 0 and "is using Swift tools version" in p.stderr:
                have = re.search(r"Swift version (\d+\.\d+)", subprocess.run(
                    ["swift", "--version"], capture_output=True, text=True).stdout)
                path = os.path.join(tmp, "Package.swift")
                text = open(path).read()
                open(path, "w").write(re.sub(r"swift-tools-version\s*:\s*[\d.]+", "swift-tools-version:" +
                                             (have.group(1) if have else "6.2"), text, count=1))
                continue
            return None
        dump = json.loads(p.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    dirs = []
    for t in dump.get("targets", []):
        # Regular targets, less test support (SKTestSupport, _InternalTestSupport); XCTest is a library.
        if t.get("type") != "regular" or re.search(r"(Test|Testing)(Support|Utilities|Utils|Helpers)$", t["name"]):
            continue
        dirs.append(os.path.normpath(t.get("path") or os.path.join("Sources", t["name"])))
    return dirs


def survey(eco, out):
    rows = []
    for r in scheme(eco):
        d = os.path.join(eco, r["name"])
        manifest = os.path.join(d, "Package.swift")
        if r["name"] == "swift" or not os.path.isfile(manifest):
            rows.append(dict(r, package=False))
            continue
        first = open(manifest, encoding="utf-8", errors="replace").readline()
        m = re.search(r"swift-tools-version\s*:\s*([\d.]+)", first)
        libs = library_dirs(d)
        files, exported = [], []
        for dirpath, dirnames, fs in os.walk(d):
            rel_dir = os.path.relpath(dirpath, d)
            dirnames[:] = [x for x in dirnames if not x.startswith(".")]
            # Only top-level directories: Sources/ArgumentParser/Utilities is
            # library code.
            if rel_dir != "." and "/" not in rel_dir and NOT_LIBRARY.search(rel_dir):
                dirnames[:] = []
                continue
            for f in fs:
                if not f.endswith(".swift") or f == "Package.swift" or f.startswith("Package@"):
                    continue
                rel = os.path.normpath(os.path.join(rel_dir, f))
                # Library code: in one of the manifest's regular targets.
                if libs is not None and not any(rel.startswith(x + "/") for x in libs):
                    continue
                text = open(os.path.join(dirpath, f), encoding="utf-8", errors="replace").read()
                if IMPORT_DARWIN.search(text):
                    files.append(rel)
                if EXPORTED_DARWIN.search(text):
                    exported.append(rel)
        commit = git("rev-parse", "HEAD", cwd=d).stdout.strip()
        rows.append(dict(r, package=True, commit=commit, tools=m.group(1) if m else None,
                         darwinFiles=len(files), darwinFileList=sorted(files), reexports=sorted(exported),
                         audited=AUDITED.get(r["name"]), libraryTargets=libs,
                         scan="library targets" if libs is not None else "outside tests and examples"))
    json.dump(rows, open(out, "w"), indent=1)
    pk = [x for x in rows if x.get("package")]
    dz = [x for x in pk if x["darwinFiles"]]
    print(f"survey: {len(rows)} repositories in the main scheme, {len(pk)} Swift packages, {len(dz)} import "
          f"Darwin in {sum(x['darwinFiles'] for x in dz)} files (lexical pre-scan) -> {out}")


PACKAGE_FILE = """# {name}: generated by `Utilities/adopter-coverage/ecosystem.sh survey` from the
# swift repository's update-checkout main scheme ({remote} at {ref}). Edit it
# by hand only to say what the generator can't know; see README.md here.

[package]
title = {name}
name = {name}
variable = {variable}
checkout = ../ecosystem/{name}
in-all = no
# The mapping has no entries for this package's interfaces: those it
# doesn't name get entries of their own (see mapping.ini's header).
strict = no
note = One of the toolchain's packages ({remote}, {ref}).
# Library targets only: the executables and tests aren't audited.
build-targets = :libraries
"""


def packages(survey_path, packages_dir):
    rows = json.load(open(survey_path))
    d = os.path.join(packages_dir, "ecosystem")
    os.makedirs(d, exist_ok=True)
    made = []
    for r in rows:
        if not r.get("package") or not r["darwinFiles"] or r.get("audited") or r["name"] in NOT_AUDITED:
            continue
        path = os.path.join(d, r["name"] + ".ini")
        if os.path.exists(path):
            continue      # kept: it may have hand edits
        var = re.sub(r"\W", "_", r["name"]).upper()
        open(path, "w").write(PACKAGE_FILE.format(name=r["name"], remote=r["remote"], ref=r["ref"], variable=var))
        made.append(r["name"])
    print(f"packages: {len(made)} new package files in {d}" + (": " + ", ".join(made) if made else ""))


# swift-system itself: its OS use is what it wraps, so it isn't audited.
NOT_AUDITED = {"swift-system": "swift-system itself: its OS use is what it wraps"}


def specs_list(rows):
    out = []
    for r in rows:
        if not r.get("package") or not r["darwinFiles"] or r["name"] in NOT_AUDITED:
            continue
        out.append(f"{r['audited']}=../ecosystem/{r['name']}" if r.get("audited") else r["name"])
    return out


def specs(survey_path):
    print(" ".join(specs_list(json.load(open(survey_path)))))


def latest_run(survey_path, results):
    """The newest stored run that covers every ecosystem package."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import results as store
    want = {sp.split("=")[0] for sp in specs_list(json.load(open(survey_path)))}
    for r in reversed(store.runs(results)):
        if want <= {p["name"] for p in r["packages"]}:
            print(r["id"])
            return 0
    return 1


TOP = 30
# How many of the interfaces that Darwin-importing files use, per symbol, the
# report lists; the JSON has them all.
DARWIN_TOP = 60
# Categories whose names come from modules other than Darwin's, which files
# see through a re-export (Foundation's of Dispatch and ObjectiveC).
NOT_DARWIN_CATEGORIES = {"dispatch", "Apple frameworks"}


def darwin_queue(run, results):
    """What the library files that import Darwin still need from it: every
    interface that the files importing Darwin in any form but through Apple
    Foundation's re-export use (the Darwin metric's interfacesByClass, in each
    package's interfaces.json.gz), with System's coverage of it on Darwin, per
    symbol: covered where the derivation's evidence for it is a doc sentence
    (a `same.` name counts as its target), or where the entry's hand status
    says covered. Answered by the standard library: an entry that's missing
    with a `swift` answer. The packages' own C shims, and names from other
    modules (NOT_DARWIN_CATEGORIES), are set apart."""
    import gzip
    rows = {}
    for p in run["packages"]:
        if not p.get("result"):
            continue
        d = os.path.join(results, p["result"])
        cov = json.load(open(os.path.join(d, "coverage.json")))
        ints = json.load(gzip.open(os.path.join(d, "interfaces.json.gz")))
        shims = {i["name"] for i in ints["interfaces"] if i.get("shim")}
        owner = {s_: e for e in cov["entries"] for s_ in e["symbols"]}
        for cls, used in (ints["darwin"].get("interfacesByClass") or {}).items():
            if cls == "Foundation":
                continue
            for it in used:
                name = it["name"]
                e = owner.get(name)
                if e is None or e["status"] == "ignore":
                    continue
                ev = (((e.get("derived") or {}).get("Darwin") or {}).get("evidence") or {}).get(name) or [None]
                hand = e.get("hand")
                if hand == "covered" or (hand is None and ev[0] == "doc"):
                    status = "covered"
                elif hand in ("partial", "missing"):
                    status = hand
                else:
                    status = "missing"
                if name in shims:
                    kind = "shim"
                elif e["category"] in NOT_DARWIN_CATEGORIES:
                    kind = "other module"
                elif status == "missing" and e.get("swift"):
                    kind = "standard library"
                else:
                    kind = "gap" if status != "covered" else "covered"
                r = rows.setdefault(name, {"name": name, "entry": e["id"], "category": e["category"],
                                           "status": status, "kind": kind, "packages": {}, "files": {}})
                r["packages"][p["name"]] = r["packages"].get(p["name"], 0) + it["sites"]
                r["files"].setdefault(p["name"], set()).update(it["files"])
    out = sorted(rows.values(), key=lambda r: (-len(r["packages"]), -sum(r["packages"].values()), r["name"]))
    for r in out:
        r["files"] = {k: sorted(v) for k, v in r["files"].items()}
        r["sites"] = sum(r["packages"].values())
    return out


def report(run_dir, results, survey_path, mapping, swiftshims_path, out_path):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import check
    import combine
    import lanes
    run, covs = combine.load_run(run_dir, results)
    rows = json.load(open(survey_path))
    shims = json.load(open(swiftshims_path)) if os.path.exists(swiftshims_path) else None
    lane_rules = lanes.load(mapping)
    by_repo = {}
    for r in rows:
        key = r.get("audited") or r["name"]
        if key in covs:
            by_repo[r["name"]] = key

    gaps = combine.gap_rows(covs)
    for g in gaps:
        g["lane"] = lanes.assign(g, lane_rules)
        g["inScope"] = g["category"] not in check.OUT_OF_SCOPE
    ranked = sorted((g for g in gaps if g["inScope"]),
                    key=lambda g: (-len(g["adopters"]), -g["allSites"], -g["total"], g["id"]))

    out = []
    w = out.append
    swift_commit = shims["swiftCommit"] if shims else "?"
    w("# The toolchain's Swift packages: the Darwin module, and what swift-system covers")
    w("")
    w(f"Run `{run['id']}`: System `{run['systemCommit']}`, tool `{run['tool']}`. The packages are the Swift packages "
      f"that swift's `utils/update_checkout/update-checkout-config.json` (swift `{swift_commit[:12]}`) clones for the "
      "`main` branch scheme, at the scheme's refs, cloned shallowly next to the worktree (`ecosystem.sh clone`). "
      "Those whose library code imports Darwin are audited with `check.sh`, from their own package files "
      "(`packages/ecosystem/`, generated; the four audited adopters keep theirs). Where a package builds with the "
      "installed toolchain (Swift 6.2) the extraction is the index store's; where it doesn't, it's lexical, and "
      "labeled so.")
    w("")

    # ------------------------------------------------------- the table
    w("## Every Swift package in the main scheme")
    w("")
    w("*Darwin files*: library files that import Darwin in any form (the tool's count, from the manifest's library "
      "targets; for packages not audited, the lexical pre-scan's). *Via Foundation*: files that see Darwin only "
      "through Apple Foundation's re-export. *Interfaces*: the OS and C-library interfaces the library targets use, "
      "and those in System's scope (not C language, strings, stdio, math, atomics, Dispatch or Apple frameworks); "
      "*covered / partial / missing* counts all of them over every platform, each at its worst status.")
    w("")
    w("| Package | Ref | Tools | Extraction | Darwin files | Re-export shims | Via Foundation | Interfaces (in scope) | "
      "Covered / partial / missing |")
    w("|---|---|---|---|---|---|---|---|---|")
    totals = collections.Counter()
    for r in rows:
        if not r.get("package"):
            continue
        key = by_repo.get(r["name"])
        c = covs.get(key) if key else None
        if c is None:
            why = NOT_AUDITED.get(r["name"]) or ("doesn't import Darwin" if not r["darwinFiles"] else "not in this run")
            w(f"| {r['name']} | `{r['ref']}` | {r.get('tools') or '?'} | — ({why}) | {r['darwinFiles']} | "
              f"{len(r.get('reexports') or [])} | | | |")
            continue
        dz = (c.get("darwin") or {}).get("summary", {})
        tot = combine.totals(c)
        owner = {s_: e for e in c["entries"] for s_ in e["symbols"]}
        used = [n for n in c["interfaces"] if owner.get(n) and owner[n]["status"] != "ignore"]
        inscope = [n for n in used if owner[n]["category"] not in check.OUT_OF_SCOPE]
        mode = c.get("extraction", {}).get("mode", "index")
        failed = (c.get("meta") or {}).get("buildFailed")
        w(f"| {r['name']}{' (audited adopter: ' + key + ')' if r.get('audited') else ''} | `{r['ref']}` | "
          f"{r.get('tools') or '?'} | {mode}{' (' + failed.split(' for ')[0] + ')' if mode == 'lexical' and failed else ''} "
          f"| {dz.get('direct', 0)} | {dz.get('reexportShims', 0)} | {dz.get('byClass', {}).get('Foundation', 0)} | "
          f"{len(used)} ({len(inscope)}) | {tot['covered']} / {tot['partial']} / {tot['missing']} |")
        totals["darwin"] += dz.get("direct", 0)
        totals["shims"] += dz.get("reexportShims", 0)
        totals["foundation"] += dz.get("byClass", {}).get("Foundation", 0)
        totals["packages"] += 1
        totals["darwinPackages"] += bool(dz.get("direct", 0) or dz.get("reexportShims", 0))
        totals.update({k: tot[k] for k in ("covered", "partial", "missing")})
    w("")
    w(f"Audited: {totals['packages']} packages; {totals['darwin']} library files import Darwin, "
      f"{totals['shims']} re-export it, {totals['foundation']} see it only through Foundation. Summed over the "
      f"packages (an interface counts once per package): {totals['covered']} covered, {totals['partial']} partial, "
      f"{totals['missing']} missing.")
    w("")

    # ------------------------------------------------------ SwiftShims
    if shims:
        t = shims["total"]
        w("## The standard library: SwiftShims and its C calls")
        w("")
        w(f"From a sparse clone of swiftlang/swift at `{shims['swiftCommit'][:12]}` (`scripts/swiftshims.py`, "
          "lexical): the names the Darwin SDK declares in C that SwiftShims' headers, the runtime, the stubs, "
          "Concurrency's C++, the threading layer and the Swift sources of core, Concurrency and Synchronization use, "
          "and System's coverage of each. Counts only.")
        w("")
        w(f"**{t['used']}** C library and kernel interfaces, **{t['inScope']}** in System's scope: "
          f"**{t['inScopeCovered']}** covered by System, {t['inScopePartial']} partly, {t['inScopeMissing']} not. "
          f"(All of them, the C language and string functions included: {t['covered']} / {t['partial']} / "
          f"{t['missing']}.) Another {shims['otherOS']} names come from Darwin's other modules (MachO, os, Dispatch, "
          "ObjectiveC, CoreFoundation).")
        w("")
        w("| Component | Files | Interfaces | In scope | Covered | Partly | Not |")
        w("|---|---|---|---|---|---|---|")
        for k, v in shims["components"].items():
            c = v["counts"]
            w(f"| {k} | {v['files']} | {c['used']} | {c['inScope']} | {c['inScopeCovered']} | {c['inScopePartial']} | "
              f"{c['inScopeMissing']} |")
        w("")
        w("Most used of those System doesn't cover (by components that use them): "
          + ", ".join(f"`{n}`" for n in shims["missingNames"][:40]) + ".")
        w("")

    # ------------------------------------------------------------ gaps
    w(f"## The top {TOP} gaps across the ecosystem")
    w("")
    w("Entries missing or partial, where a package uses them, ranked by how many of the audited packages they block, "
      "then by the lines that use them. An entry is a mapping entry, or for an interface the mapping doesn't name, "
      "the interface itself (*no entry*). Out of System's scope (C language, strings, stdio, math, atomics, "
      "Dispatch, Apple frameworks, C libraries): not ranked. *Lane* is the System lane that should take it "
      "(mapping.ini's `lanes`).")
    w("")
    w("| # | Gap | Category | Lane | Packages | Sites | Gap on | Packages that use it |")
    w("|---|---|---|---|---|---|---|---|")
    A = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
         "Windows": "N"}
    for i, g in enumerate(ranked[:TOP], 1):
        plats = sorted({p for ps in g["platforms"].values() for p in ps}, key=list(A).index)
        w(f"| {i} | {g['id']}{' *(no entry)*' if g['auto'] else ''} | {g['category']} | {g['lane']} | "
          f"{len(g['adopters'])} | {g['allSites']} | {' '.join(A[p] for p in plats)} | "
          + ", ".join(sorted(g["adopters"])) + " |")
    w("")
    queue = darwin_queue(run, results)
    kinds = collections.Counter(r["kind"] for r in queue)
    gaps_d = [r for r in queue if r["kind"] == "gap"]
    w("## What the files that import Darwin still need")
    w("")
    w(f"The interfaces that library files importing Darwin use (in any form but through Apple Foundation's "
      f"re-export; the Darwin metric's per-file classes), one row per symbol, and System's coverage of each on "
      f"Darwin: **{len(queue)}** interfaces, {kinds['covered']} covered, **{len(gaps_d)}** gaps; set apart: "
      f"{kinds['standard library']} the standard library answers (a `swift` answer in mapping.ini), "
      f"{kinds['other module']} from other modules (Dispatch, ObjectiveC), {kinds['shim']} the packages' own C "
      f"shims. Ranked by packages, then sites; the JSON next to this report has every row. This is the list "
      f"a package's `import Darwin` waits on, whatever other platforms need.")
    w("")
    w("| # | Interface | Entry | Status | Packages | Sites | Packages that use it |")
    w("|---|---|---|---|---|---|---|")
    for i, r in enumerate(gaps_d[:DARWIN_TOP], 1):
        w(f"| {i} | `{r['name']}` | {r['entry']} | {r['status']} | {len(r['packages'])} | {r['sites']} | "
          + ", ".join(sorted(r["packages"])) + " |")
    w("")
    per_lane = collections.defaultdict(list)
    for g in ranked:
        per_lane[g["lane"]].append(g)
    w("## By lane")
    w("")
    w("| Lane | Gaps | Blocking 2+ packages | Largest |")
    w("|---|---|---|---|")
    for lane, gs in sorted(per_lane.items(), key=lambda kv: -len(kv[1])):
        w(f"| {lane} | {len(gs)} | {sum(1 for g in gs if len(g['adopters']) > 1)} | "
          + ", ".join(g["id"] for g in gs[:8]) + " |")
    w("")
    oos = [g for g in gaps if not g["inScope"]]
    w(f"Not ranked, out of System's scope: {len(oos)} gap entries, "
      + ", ".join(f"{c} {n}" for c, n in collections.Counter(g["category"] for g in oos).most_common()) + ".")
    w("")
    open(out_path, "w").write("\n".join(out) + "\n")
    json.dump({"run": run, "ranked": ranked, "outOfScope": oos, "totals": dict(totals), "darwinQueue": queue,
               "perLane": {k: [g["id"] for g in v] for k, v in per_lane.items()}},
              open(os.path.splitext(out_path)[0] + ".json", "w"), indent=1)
    print(f"ecosystem: {totals['packages']} packages, {len(ranked)} gaps in scope -> {out_path}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "scheme":
        for r in scheme(sys.argv[2]):
            print("\t".join([r["name"], r["ref"], r["remote"], ",".join(r["platforms"])]))
    elif cmd == "clone":
        clone(sys.argv[2])
    elif cmd == "survey":
        survey(sys.argv[2], sys.argv[3])
    elif cmd == "packages":
        packages(sys.argv[2], sys.argv[3])
    elif cmd == "specs":
        specs(sys.argv[2])
    elif cmd == "latest-run":
        sys.exit(latest_run(sys.argv[2], sys.argv[3]))
    elif cmd == "report":
        report(*sys.argv[2:8])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
