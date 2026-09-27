#!/usr/bin/env python3
"""The results store: what each run found, by commit.

  results/<package>/<package commit>/<System commit>/<tool>/
        one package checked against one System commit by one version of the
        tool: coverage.json, interfaces.json.gz, meta.json, COVERAGE.md
  runs/<run>/run.json, COVERAGE.md, coverage.json
        one check.sh invocation: the System commit, the tool, and each
        package's commit and result; the combined report
  runs/log.tsv
        every invocation, with its date
  systems/<System commit>/<tool>/   System's API scan and the derivation
  index/<package>/<package commit>/<key>/
        a build's index dump and the export it was made from, reused by any
        run of that commit with the same build settings
  vocab/, sdk-probe/
        the SDK's names for lexical extraction, and which SDK modules
        re-export Darwin

A run's id is derived from its System commit, its tool and its packages'
commits, so repeating a run with the same inputs lands on the same id, and
the stored results are compared with the new ones first.

Usage:
  results.py record ...              (check.sh)
  results.py list [--results DIR]
  results.py show RUN
  results.py delta RUN_A RUN_B [--package NAME] [--markdown OUT.md]
  results.py compare-results DIR_A DIR_B      two packages' result directories
  results.py resolve RUN                      prints the run's directory
  results.py specs RUN                        the check.sh arguments that repeat it
RUN is a run id or a prefix of one, `latest`, or a System commit (prefix):
the latest run of it.
"""

import sys

sys.dont_write_bytecode = True

import argparse
import collections
import datetime
import gzip
import hashlib
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ABBREV = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
          "Windows": "N"}
STATUS_RANK = {"covered": 0, "partial": 1, "missing": 2, "ignore": -1}
# Keys of coverage.json that name where and when a run happened, not what it
# found; comparing two results ignores them.
VOLATILE_META = {"date", "host", "path", "systemPath", "subject", "systemSubject", "ref", "systemRef", "indexKey"}


def default_results():
    repo = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
    return os.environ.get("ADOPTER_COVERAGE_RESULTS") or os.path.join(os.path.dirname(repo), "coverage-results")


def h12(text):
    return hashlib.sha1(text.encode()).hexdigest()[:12]


def load(path):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    return json.load(open(path))


# ---------------------------------------------------------------- record

def normalized(cov):
    """A coverage.json without what varies between identical runs."""
    c = json.loads(json.dumps(cov))
    c["meta"] = {k: v for k, v in c.get("meta", {}).items() if k not in VOLATILE_META}
    return c


def result_dir(results, name, commit, system, tool):
    return os.path.join(results, "results", name, commit, system, tool)


def record(a):
    stage = a.stage
    packages = []
    for spec in a.specs:
        name = spec.split("=")[0].split("@")[0]
        src = os.path.join(stage, name)
        meta = json.load(open(os.path.join(src, "meta.json")))
        entry = {"name": name, "spec": spec, "path": meta["path"], "ref": meta["ref"], "commit": meta["commit"],
                 "extraction": meta.get("extraction"), "buildFailed": meta.get("buildFailed")}
        if a.verify_dir:
            dest = os.path.join(a.verify_dir, name)
            if os.path.exists(dest):
                shutil.rmtree(dest)
            shutil.copytree(src, dest)
            packages.append(entry)
            continue
        dest = result_dir(a.results, name, meta["commit"], a.system_commit, a.tool)
        new = json.load(open(os.path.join(src, "coverage.json")))
        if os.path.isfile(os.path.join(dest, "coverage.json")):
            old = json.load(open(os.path.join(dest, "coverage.json")))
            diffs = compare_coverage(old, new)
            entry["reproduced"] = not diffs
            if diffs:
                print(f"{name}: the stored result for these commits and this tool differs ({len(diffs)} "
                      f"differences); replacing it. First ones:")
                for d in diffs[:8]:
                    print("    " + d)
            else:
                print(f"{name}: reproduced the stored result for these commits and this tool")
            shutil.rmtree(dest)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copytree(src, dest, ignore=shutil.ignore_patterns("interfaces.json", ".adopter-coverage-out"))
        with open(os.path.join(src, "interfaces.json"), "rb") as f, gzip.open(os.path.join(dest, "interfaces.json.gz"),
                                                                             "wb") as g:
            shutil.copyfileobj(f, g)
        entry["result"] = os.path.relpath(dest, a.results)
        packages.append(entry)
    run = {
        "systemRef": a.system_ref, "systemCommit": a.system_commit, "tool": a.tool, "toolCommit": a.tool_commit,
        "toolDirty": "-dirty-" in a.tool, "mapping": h12(open(a.mapping).read()),
        "packages": sorted(packages, key=lambda p: p["name"]), "failed": a.failed or [],
    }
    ident = a.system_commit + " " + a.tool + " " + " ".join(f"{p['name']}:{p['commit']}" for p in run["packages"])
    run["id"] = f"{a.system_commit[:12]}-{h12(ident)[:8]}"
    now = datetime.datetime.now().isoformat(timespec="seconds")
    if not a.verify_dir:
        rd = os.path.join(a.results, "runs", run["id"])
        os.makedirs(rd, exist_ok=True)
        prev = os.path.join(rd, "run.json")
        run["dates"] = (json.load(open(prev)).get("dates", []) if os.path.exists(prev) else []) + [now]
        json.dump(run, open(prev, "w"), indent=1)
        with open(os.path.join(a.results, "runs", "log.tsv"), "a") as f:
            f.write("\t".join([now, run["id"], a.system_commit, a.tool,
                               " ".join(f"{p['name']}@{p['commit'][:10]}" for p in run["packages"])]) + "\n")
    json.dump(run, open(a.out, "w"), indent=1)


# ----------------------------------------------------------------- query

def runs(results):
    d = os.path.join(results, "runs")
    out = []
    if os.path.isdir(d):
        for r in os.listdir(d):
            p = os.path.join(d, r, "run.json")
            if os.path.isfile(p):
                out.append(json.load(open(p)))
    return sorted(out, key=lambda r: (r.get("dates") or [""])[-1])


def resolve(results, ref):
    rs = runs(results)
    if not rs:
        sys.exit(f"no runs in {results}")
    if ref == "latest":
        return rs[-1]
    hits = [r for r in rs if r["id"].startswith(ref)]
    if len(hits) == 1:
        return hits[0]
    if not hits:
        hits = [r for r in rs if r["systemCommit"].startswith(ref)]
        if hits:
            return hits[-1]
        sys.exit(f"no run matches {ref}; `results.py list` shows them")
    sys.exit(f"{ref} matches {len(hits)} runs: " + ", ".join(r["id"] for r in hits))


def cmd_list(a):
    for r in runs(a.results):
        pk = ", ".join(f"{p['name']}@{p['commit'][:8]}" + ("" if p.get("extraction") in (None, "index") else " (lexical)")
                       for p in r["packages"])
        print(f"{r['id']}  {(r.get('dates') or ['?'])[-1]}  System {r['systemCommit'][:10]}  tool {r['tool']}"
              f"{' (dirty)' if r.get('toolDirty') else ''}  {pk}")


def cmd_show(a):
    r = resolve(a.results, a.run)
    print(json.dumps(r, indent=1))
    print(os.path.join(a.results, "runs", r["id"], "COVERAGE.md"))


def cmd_specs(a):
    r = resolve(a.results, a.run)
    print(r["systemCommit"])
    print(" ".join(f"{p['name']}={p['path']}@{p['commit']}" for p in r["packages"]))


def coverage_of(results, run, name):
    p = next((x for x in run["packages"] if x["name"] == name), None)
    if p is None or not p.get("result"):
        return None
    return load(os.path.join(results, p["result"], "coverage.json"))


# ------------------------------------------------------------ comparing

def symbol_status(cov):
    """{symbol: (worst status over the platforms that use it, {platform: status}, entry)}."""
    owner = {s: e for e in cov["entries"] for s in e["symbols"]}
    out = {}
    for name, it in cov["interfaces"].items():
        e = owner.get(name)
        if e is None:
            continue
        per = {}
        for p in it["platforms"]:
            st = e["platformStatus"].get(p, {"status": e["status"]})["status"]
            per[p] = st
        if e["status"] == "ignore":
            continue
        worst = max(per.values(), key=lambda s: STATUS_RANK.get(s, 0)) if per else e["status"]
        out[name] = (worst, per, e["id"])
    return out


def darwin_files(cov):
    d = cov.get("darwin") or {}
    return {rel: f for rel, f in (d.get("files") or {}).items() if f.get("class")}


def compare_coverage(old, new):
    """Differences between two results of one package, as lines."""
    out = []
    o, n = normalized(old), normalized(new)
    if o.get("meta") != n.get("meta"):
        for k in sorted(set(o["meta"]) | set(n["meta"])):
            if o["meta"].get(k) != n["meta"].get(k):
                out.append(f"meta {k}: {o['meta'].get(k)!r} -> {n['meta'].get(k)!r}")
    so, sn = symbol_status(old), symbol_status(new)
    for s in sorted(set(so) | set(sn)):
        if so.get(s, (None, None))[:2] != sn.get(s, (None, None))[:2]:
            out.append(f"interface {s}: {so.get(s, ('-',))[0]} {so.get(s, (None, {}))[1]} -> "
                       f"{sn.get(s, ('-',))[0]} {sn.get(s, (None, {}))[1]}")
    for k in ("summary", "gaps", "problems", "alreadySystem", "derivation"):
        if o.get(k) != n.get(k):
            out.append(f"{k} differs")
    fo, fn = darwin_files(old), darwin_files(new)
    if {k: v["class"] for k, v in fo.items()} != {k: v["class"] for k, v in fn.items()}:
        out.append("Darwin files differ")
    return out


def delta(old, new):
    """What changed for one package between two runs."""
    so, sn = symbol_status(old), symbol_status(new)
    both = set(so) & set(sn)
    newly = sorted(s for s in both if so[s][0] != "covered" and sn[s][0] == "covered")
    better = sorted(s for s in both if so[s][0] == "missing" and sn[s][0] == "partial")
    worse = sorted(s for s in both if STATUS_RANK.get(sn[s][0], 0) > STATUS_RANK.get(so[s][0], 0))
    still = sorted(s for s in both if so[s][0] == "missing" and sn[s][0] == "missing")
    added = sorted(set(sn) - set(so))
    removed = sorted(set(so) - set(sn))
    fo, fn = darwin_files(old), darwin_files(new)
    do = {k for k, v in fo.items() if v["class"] == "direct"}
    dn = {k for k, v in fn.items() if v["class"] == "direct"}

    def tot(cov):
        c = collections.Counter()
        for row in cov["summary"]["all"].values():
            c.update(row.get("all", {}))
        return c

    return {
        "commits": {"old": old["meta"].get("commit"), "new": new["meta"].get("commit"),
                    "oldSystem": old["meta"].get("systemCommit"), "newSystem": new["meta"].get("systemCommit")},
        "totals": {"old": dict(tot(old)), "new": dict(tot(new))},
        "newlyCovered": newly, "missingToPartial": better, "regressed": worse, "stillMissing": still,
        "newInterfaces": [(s, sn[s][0]) for s in added], "goneInterfaces": [(s, so[s][0]) for s in removed],
        "darwin": {"old": len(do), "new": len(dn), "added": sorted(dn - do), "removed": sorted(do - dn),
                   "oldByClass": collections.Counter(v["class"] for v in fo.values()),
                   "newByClass": collections.Counter(v["class"] for v in fn.values())},
        "entries": {s: (sn.get(s) or so.get(s))[2] for s in newly + better + worse},
    }


def cmd_delta(a):
    ra, rb = resolve(a.results, a.a), resolve(a.results, a.b)
    names = sorted({p["name"] for p in ra["packages"]} & {p["name"] for p in rb["packages"]})
    if a.package:
        names = [n for n in names if n in a.package]
    out = []
    w = out.append
    w(f"# Delta: run {ra['id']} -> run {rb['id']}")
    w("")
    w(f"| | Run A | Run B |")
    w("|---|---|---|")
    w(f"| System | `{ra['systemCommit'][:12]}` | `{rb['systemCommit'][:12]}` |")
    w(f"| Tool | `{ra['tool']}` | `{rb['tool']}` |")
    for n in names:
        ca = next(p for p in ra["packages"] if p["name"] == n)
        cb = next(p for p in rb["packages"] if p["name"] == n)
        w(f"| {n} | `{ca['commit'][:12]}` ({ca.get('extraction')}) | `{cb['commit'][:12]}` ({cb.get('extraction')}) |")
    w("")
    if ra["tool"] != rb["tool"]:
        w("The runs used different versions of the tool, so some differences may be the tool's rather than "
          "System's or the packages'.")
        w("")
    combined = collections.defaultdict(set)
    rows = []
    for n in names:
        old, new = coverage_of(a.results, ra, n), coverage_of(a.results, rb, n)
        if old is None or new is None:
            continue
        d = delta(old, new)
        rows.append((n, d))
        for k in ("newlyCovered", "missingToPartial", "regressed", "stillMissing"):
            combined[k].update(d[k])
    w("## Per package")
    w("")
    w("| Package | Covered / partial / missing, every platform | Newly covered | Missing → partial | Regressed | "
      "Still missing | New interfaces | Darwin-importing files |")
    w("|---|---|---|---|---|---|---|---|")
    for n, d in rows:
        o, nn = d["totals"]["old"], d["totals"]["new"]
        w(f"| {n} | {o.get('covered', 0)}/{o.get('partial', 0)}/{o.get('missing', 0)} → "
          f"{nn.get('covered', 0)}/{nn.get('partial', 0)}/{nn.get('missing', 0)} | {len(d['newlyCovered'])} | "
          f"{len(d['missingToPartial'])} | {len(d['regressed'])} | {len(d['stillMissing'])} | "
          f"{len(d['newInterfaces'])} (−{len(d['goneInterfaces'])}) | {d['darwin']['old']} → {d['darwin']['new']} |")
    w("")
    w("## Combined")
    w("")
    w(f"Across the packages: {len(combined['newlyCovered'])} interfaces newly covered, "
      f"{len(combined['missingToPartial'])} from missing to partial, {len(combined['regressed'])} regressed, "
      f"{len(combined['stillMissing'])} still missing. An interface counts once, however many packages use it.")
    w("")
    for n, d in rows:
        w(f"### {n}")
        w("")
        for label, key in (("Newly covered", "newlyCovered"), ("Missing → partial", "missingToPartial"),
                           ("Regressed", "regressed")):
            if d[key]:
                byentry = collections.defaultdict(list)
                for s in d[key]:
                    byentry[d["entries"].get(s, "?")].append(s)
                w(f"- **{label}** ({len(d[key])}): " + "; ".join(
                    f"[{e}] " + ", ".join(f"`{s}`" for s in ss[:8]) + (f" and {len(ss) - 8} more" if len(ss) > 8 else "")
                    for e, ss in sorted(byentry.items())))
        if d["newInterfaces"] or d["goneInterfaces"]:
            w(f"- **Interfaces** new: " + (", ".join(f"`{s}` ({st})" for s, st in d["newInterfaces"][:30]) or "none")
              + "; gone: " + (", ".join(f"`{s}`" for s, _ in d["goneInterfaces"][:30]) or "none"))
        dd = d["darwin"]
        w(f"- **Darwin-importing files**: {dd['old']} → {dd['new']}"
          + (f"; no longer: " + ", ".join(f"`{x}`" for x in dd["removed"][:20]) if dd["removed"] else "")
          + (f"; newly: " + ", ".join(f"`{x}`" for x in dd["added"][:20]) if dd["added"] else "")
          + ". By how they see Darwin: " + ", ".join(f"{k} {dd['oldByClass'].get(k, 0)} → {dd['newByClass'].get(k, 0)}"
                                                      for k in ("direct", "module re-export", "package re-export",
                                                                "Foundation", "SDK re-export")) + ".")
        w("")
    text = "\n".join(out) + "\n"
    if a.markdown:
        open(a.markdown, "w").write(text)
    print(text)


def cmd_compare_results(a):
    old = load(os.path.join(a.a, "coverage.json"))
    new = load(os.path.join(a.b, "coverage.json"))
    diffs = compare_coverage(old, new)
    for d in diffs:
        print(d)
    print(f"{len(diffs)} differences" if diffs else "reproduced: the results agree")
    return 1 if diffs else 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    for k in ("--results", "--stage", "--system-ref", "--system-commit", "--tool", "--tool-commit", "--mapping",
              "--packages", "--out"):
        r.add_argument(k, required=k not in ("--tool-commit",))
    r.add_argument("--verify-dir", default="")
    r.add_argument("--specs", nargs="*", default=[])
    r.add_argument("--failed", nargs="*", default=[])
    for name in ("list",):
        s = sub.add_parser(name)
        s.add_argument("--results", default=default_results())
    for name in ("show", "resolve", "specs"):
        s = sub.add_parser(name)
        s.add_argument("run")
        s.add_argument("--results", default=default_results())
    d = sub.add_parser("delta")
    d.add_argument("a")
    d.add_argument("b")
    d.add_argument("--package", nargs="*")
    d.add_argument("--markdown")
    d.add_argument("--results", default=default_results())
    c = sub.add_parser("compare-results")
    c.add_argument("a")
    c.add_argument("b")
    a = ap.parse_args()
    if a.cmd == "record":
        return record(a)
    if a.cmd == "list":
        return cmd_list(a)
    if a.cmd == "show":
        return cmd_show(a)
    if a.cmd == "resolve":
        print(os.path.join(a.results, "runs", resolve(a.results, a.run)["id"]))
        return 0
    if a.cmd == "specs":
        return cmd_specs(a)
    if a.cmd == "delta":
        return cmd_delta(a)
    if a.cmd == "compare-results":
        return cmd_compare_results(a)


if __name__ == "__main__":
    sys.exit(main())
