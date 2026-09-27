#!/usr/bin/env python3
"""Write COVERAGE.md from check.py's coverage.json.

Usage: report.py --coverage coverage.json --method method.md --out COVERAGE.md
"""

import argparse
import collections
import json

ABBREV = {"Darwin": "D", "Linux": "L", "Musl": "M", "Android": "A", "FreeBSD": "F", "OpenBSD": "O", "WASI": "W",
          "Windows": "N"}
STATUS_ORDER = ("covered", "partial", "missing")
GAP_COUNT = 20


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def code(s):
    return "`" + str(s).replace("`", "'") + "`"


def plat_status(entry, platforms):
    """'covered: D L M · missing: N' for an entry, in platform order."""
    groups = collections.OrderedDict((s, []) for s in STATUS_ORDER + ("ignore",))
    for p in platforms:
        st = entry["platformStatus"].get(p)
        if st:
            groups[st["status"]].append(ABBREV[p])
    parts = [f"{s}: {' '.join(ps)}" for s, ps in groups.items() if ps]
    return " · ".join(parts) if parts else "not used"


def api_cell(entry, cap=4):
    lines = []
    apis = entry["apis"]
    for a in apis[:cap]:
        tag = ""
        if a["matched"]:
            h = a["matched"][0]
            av = h["availability"]
            bits = []
            if av.get("system") == "199":
                bits.append("unreleased")
            elif av.get("system"):
                bits.append(f"System {av['system']}")
            bits.extend(av.get("os", []))
            if len(h["platforms"]) < 8:
                bits.append(" ".join(ABBREV[p] for p in h["platforms"] if p in ABBREV))
            if h.get("scopeLost"):
                bits.append("scanner lost the scope")
            tag = f" ({', '.join(bits)})" if bits else ""
        else:
            tag = " (**not on the tip**)"
        lines.append(code(a["text"]) + esc(tag))
    if len(apis) > cap:
        lines.append(f"and {len(apis) - cap} more")
    return "<br>".join(lines)


def counts_cell(c):
    c = c or {}
    total = sum(c.get(s, 0) for s in STATUS_ORDER)
    if not total:
        return ""
    return f"{c.get('covered', 0)} / {c.get('partial', 0)} / {c.get('missing', 0)}"


def summary_table(table, platforms, categories, swift_alts):
    out = ["| Category | " + " | ".join(platforms) + " | All platforms | Stdlib alternative |",
           "|---|" + "---|" * (len(platforms) + 2)]
    totals = {p: collections.Counter() for p in platforms + ["all"]}
    for c in categories:
        row = table.get(c, {})
        if not any(row.get(p) for p in platforms + ["all"]):
            continue
        cells = []
        for p in platforms + ["all"]:
            totals[p].update(row.get(p, {}))
            cells.append(counts_cell(row.get(p)))
        out.append(f"| {c} | " + " | ".join(cells) + f" | {swift_alts.get(c, 0) or ''} |")
    out.append("| **total** | " + " | ".join(f"**{counts_cell(totals[p])}**" for p in platforms + ["all"])
               + f" | {sum(swift_alts.values()) or ''} |")
    return out


def and_list(items):
    items = list(items)
    if len(items) <= 2:
        return " and ".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


def system_dependency_text(name, dep):
    """What the package's manifest asks of swift-system, and what the build
    fetched."""
    if not dep:
        return f"{name} doesn't depend on swift-system."
    how = f"by URL ({code(dep['url'])})" if dep.get("url") else f"at a path ({code(dep.get('path') or '?')})"
    got = f", and the build resolved {dep['resolved']}" if dep.get("resolved") else ""
    return (f"{name}'s manifest asks for swift-system {code(dep.get('requirement') or '?')} {how}{got}: a released "
            f"System, not the commit this report checks against. That doesn't affect the extraction, which is "
            f"about what {name} uses; the System API it already calls is looked up on the tip below.")


def note_text(entry):
    """The package's note for an entry, then the shared one."""
    return " ".join(x for x in (entry.get("packageNote"), entry.get("note")) if x)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--coverage", required=True)
    ap.add_argument("--method", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    cov = json.load(open(args.coverage))
    meta = cov.get("meta", {})
    platforms = cov["platforms"]
    categories = cov["categories"]
    # The mapping is shared; this report is about the entries the package uses.
    entries = [e for e in cov["entries"] if e.get("sites")]
    interfaces = cov["interfaces"]
    problems = cov["problems"]
    ext = cov["extraction"]
    by_id = {e["id"]: e for e in entries}
    owner = {s: e for e in entries for s in e["symbols"]}
    pkg = cov["package"]
    name, title = pkg["name"], pkg["title"]

    out = []
    w = out.append
    w(f"# {title}'s OS interfaces and swift-system coverage")
    w("")
    w("| | Commit | |")
    w("|---|---|---|")
    w(f"| swift-system | `{meta.get('systemCommit', '?')}` ({esc(meta.get('systemRef', ''))}) | "
      f"{esc(meta.get('systemSubject', ''))} |")
    w(f"| {title} | `{meta.get('commit', '?')}` ({esc(meta.get('ref', ''))}) | "
      f"{esc(meta.get('subject', ''))} |")
    w("")
    w(f"Generated {meta.get('date', '')} on {meta.get('host', '')} with {meta.get('swift', '')}, by "
      f"`Utilities/adopter-coverage/check.sh {pkg['key']}` (tool `{meta.get('tool', '?')}`) from "
      f"`Utilities/adopter-coverage/mapping.ini`, with System's coverage derived from its sources at the commit "
      f"above. The last section says how.")
    w("")
    mode = ext.get("mode", "index")
    if mode == "lexical":
        why = meta.get("buildFailed") or "the build was skipped"
        w(f"**Lexical extraction.** {name} didn't build here ({esc(why)}), so the lexical rules read every line, "
          "with the Darwin SDK's names from another package's index store. On NIO they find about 94% of the "
          "Darwin interfaces the index finds, with no false positives. Names declared nowhere the rules can see "
          "(only on Linux or Windows, or in a dependency) are dropped rather than presumed to be the C library's, "
          "so other platforms are undercounted: "
          f"{sum(ext.get('lexicalUnresolvedDropped', {}).values())} such references, the most frequent "
          + ", ".join(code(k) for k in list(ext.get("lexicalUnresolvedDropped", {}))[:10]) + ".")
        w("")
    for pd in meta.get("pathDependencies") or []:
        if pd["kind"] == "swift-system":
            w(f"The manifest's path dependency {code(pd['from'])} is a swift-system checkout; the build used an "
              "export of the System commit above instead, so it depends on commits only.")
        else:
            w(f"The manifest's path dependency {code(pd['from'])} was built from {code(pd['to'])} as it stood, "
              "a working tree rather than a commit.")
        w("")
    w("Platforms: " + ", ".join(f"{ABBREV[p]} = {p}" for p in platforms) + ". Darwin means macOS.")
    w("")
    sdep = ext.get("systemDependency")
    if sdep:
        w(f"{name}'s build fetched a released swift-system ({sdep.get('resolved') or '?'}, from its manifest's "
          f"{code(sdep.get('requirement') or '?')}"
          + (" by URL" if sdep.get("url") else "") + "), not the System commit above. That doesn't matter for the "
          f"extraction, which is about what {name} uses; the System API {name} already calls is looked up on the "
          "tip (see *System API " + name + " already uses*).")
        w("")

    # ------------------------------------------------------------ check
    w("## Check")
    w("")
    checks = [
        ("unmapped", f"{name} interfaces with no mapping entry"),
        ("apiMissing", "System declarations the mapping cites that the tip lacks"),
        ("alreadySystemMissing", f"System API that {name} already calls and the tip lacks"),
        ("duplicate", "symbols in more than one entry"),
        ("malformed", "mapping errors"),
    ]
    for k, label in checks:
        n = len(problems.get(k, []))
        w(f"- {'**' + str(n) + '**' if n else 'No'} {label}.")
    stale = problems.get("staleNotes", [])
    w(f"- {len(stale) or 'No'} entries have a `note.{pkg['key']}` although {name} uses none of their symbols"
      + (" (not an error; drop the note)." if stale else ".") + " Symbols no package uses are in the combined report.")
    w("")
    if problems.get("unmapped"):
        w(f"### New {name} interfaces")
        w("")
        w("Add each to an entry in `mapping.ini` (see its header).")
        w("")
        w("| Interface | Kinds | Platforms | Evidence | Declared in | Examples |")
        w("|---|---|---|---|---|---|")
        for u in problems["unmapped"]:
            w(f"| {code(u['name'])} | {', '.join(u['kinds'])} | {' '.join(ABBREV[p] for p in u['platforms'])} | "
              f"{', '.join(u['evidence'])} | {esc(', '.join(u['headers'][:2]))} | {esc(', '.join(u['examples']))} |")
        w("")
    if problems.get("apiMissing"):
        w("### Cited System API missing on the tip")
        w("")
        w("| Entry | Cited declaration | Declarations of that name on the tip |")
        w("|---|---|---|")
        for m in problems["apiMissing"]:
            w(f"| {esc(m['entry'])} | {code(m['api'])} | "
              f"{'<br>'.join(code(x) for x in m['sameName']) or 'none'} |")
        w("")
    if problems.get("alreadySystemMissing"):
        w(f"### System API {name} calls today that the tip lacks")
        w("")
        for m in problems["alreadySystemMissing"]:
            w(f"- {code(m['symbol'])}: " + ", ".join(f"{s['file']}:{s['line']}" for s in m["sites"]))
        w("")
    for k in ("duplicate", "malformed"):
        for m in problems.get(k, []):
            w(f"- {esc(m)}")
    if stale:
        w("")
        w("Stale notes: " + "; ".join(f"[{s['entry']}]" for s in stale) + ".")
    w("")

    # ------------------------------------------------------- derivation
    der = cov.get("derivation") or {}
    de = der.get("entries", {})
    ds = der.get("system", {})
    w("## Derivation")
    w("")
    w(f"What System covers comes from its sources at the commit above: {ds.get('declarations', '?')} public "
      f"declarations, {ds.get('documented', '?')} of them with a *The corresponding C ...* sentence, and "
      f"{ds.get('typealiases', '?')} CInterop typealiases, name {der.get('systemNames', '?')} C interfaces. Of the "
      f"{sum(1 for e in entries if e.get('used'))} entries {name} uses, the derivation decides "
      f"**{de.get('derived', 0)}**"
      + (f" ({de.get('auto', 0)} of them interfaces no entry names)" if de.get("auto") else "")
      + f", a hand status in the mapping decides {de.get('hand', 0)}"
      + (f", and a per-platform override {de.get('override', 0)}" if de.get("override") else "") + ". "
      "The derivation runs for those too; where it disagrees, the rows below say why.")
    w("")
    dis = der.get("disagreements", [])
    if dis:
        w("| Entry | Hand | Derived | Where | Why the derivation differs |")
        w("|---|---|---|---|---|")
        for d in dis:
            byst = collections.defaultdict(list)
            for p, v in d["platforms"].items():
                byst[(v["hand"], v["derived"], v["reason"])].append(ABBREV[p])
            for (h, dv, why), ps in sorted(byst.items()):
                w(f"| {esc(d['entry'])} | {h} | {dv} | {' '.join(ps)} | {esc(why) or '—'} |")
        w("")

    # ---------------------------------------------------------- summary
    swift_alts_f, swift_alts_a = collections.Counter(), collections.Counter()
    for e in entries:
        if e["status"] == "missing" and e.get("swift"):
            swift_alts_f[e["category"]] += len(e["functionLike"])
            swift_alts_a[e["category"]] += len([s for s in e["symbols"] if s in interfaces])
    w("## Summary")
    w("")
    w(f"Each cell is **covered / partial / missing**, counting the OS and C-library symbols {name}'s library targets "
      "use there (the extractor's names: a function, type, constant or variable). A symbol counts as covered on a "
      "platform only if a System declaration that covers its entry (named by System's doc comments, or cited by "
      "the mapping) is built there, so an entry covered on Linux can be missing on Windows. *All platforms* counts each symbol once, at its worst status over the platforms that "
      "use it. *Stdlib alternative* counts the missing symbols whose entry names a Swift standard library "
      "replacement.")
    w("")
    w("### Functions and function-like macros")
    w("")
    out.extend(summary_table(cov["summary"]["functions"], platforms, categories, swift_alts_f))
    w("")
    w("### All interfaces")
    w("")
    out.extend(summary_table(cov["summary"]["all"], platforms, categories, swift_alts_a))
    w("")
    unrel = [e for e in entries if e.get("unreleased") and e["status"] in ("covered", "partial")]
    rel_syms = sum(len([s for s in e["symbols"] if s in interfaces]) for e in unrel)
    w(f"{len(unrel)} of the covered and partial entries ({rel_syms} symbols) cite unreleased `System 199` API, so "
      f"{name} can adopt them only once a release ships it. Entries {name} uses, by status: " +
      ", ".join(f"{sum(1 for e in entries if e['status'] == s)} {s}" for s in STATUSES_ALL) + ".")
    w("")

    # ------------------------------------------------------------- gaps
    w(f"## The {GAP_COUNT} largest gaps")
    w("")
    twins = pkg.get("twin-targets") or []
    w(f"Ranked by an estimate of the {name} code that System API for the entry would let {name} delete: the code "
      "lines of the thin wrapper functions (up to "
      f"{cov['config']['thinWrapperLines']} lines) in {name}'s syscall-layer files that reference the entry, plus the "
      "C shim definitions it would retire (each with its header declaration). A function that references several "
      "gaps is split between them, and one whose calls System already covers counts for no gap. Only sites on "
      "platforms where the entry has a gap count. *Call sites* counts lines outside those files that reference the "
      "entry: code that would change rather than go. "
      + (f"{and_list(twins)} are twins, so their code counts twice. " if twins else "")
      + f"The wrapper files are `wrapper-files` in `packages/{pkg['key']}.ini`, and the error-state accessors that "
      "get no wrapper lines ("
      + ", ".join(code(x) for x in cov["config"].get("secondary", [])) + ") are under `[config]` in "
      "`mapping.ini`. Entries the Swift standard library covers aren't ranked: "
      + ", ".join(cov["config"].get("unrankedStdlib", [])) + "."
      + (" Nor are those that aren't System's to wrap (`wrap = no`): "
         + ", ".join(cov["config"]["notWrapped"]) + "." if cov["config"].get("notWrapped") else ""))
    w("")
    w("| # | Entry | Category | Gap on | Lines (Swift + C) | Call sites | What's missing |")
    w("|---|---|---|---|---|---|---|")
    for i, g in enumerate(cov["gaps"][:GAP_COUNT], 1):
        e = by_id[g["id"]]
        note = note_text(e)
        if len(note) > 260:
            note = note[:257].rsplit(" ", 1)[0] + " ..."
        w(f"| {i} | {esc(g['id'])} | {g['category']} | {' '.join(ABBREV[p] for p in g['gapPlatforms'])} | "
          f"{g['total']} ({g['swiftLines']} + {g['cLines']}) | {g['callSitesElsewhere']} | {esc(note)} |")
    w("")

    # --------------------------------------------------------- by entry
    w("## Coverage by entry")
    w("")
    w(f"One row per mapping entry {name} uses, by category. *Status* groups the platforms where {name} uses the "
      f"entry by their status. *Uses* is the number of {name} source lines that reference the entry's symbols, with "
      "the targets.")
    w("")
    for c in categories:
        rows = [e for e in entries if e["category"] == c and e["status"] != "ignore"]
        if not rows:
            continue
        w(f"### {c}")
        w("")
        w("| Entry | Symbols | Status | System API | Uses | Note |")
        w("|---|---|---|---|---|---|")
        for e in sorted(rows, key=lambda e: e["id"].lower()):
            syms = [s for s in e["symbols"] if s in interfaces]
            sym_cell = ", ".join(code(s) for s in syms[:12]) + (f" and {len(syms) - 12} more" if len(syms) > 12 else "")
            tg = ", ".join(f"{t} {n}" for t, n in sorted(e["targets"].items(), key=lambda kv: -kv[1])[:4])
            reason = "; ".join(sorted({f"{ABBREV[p]}: {v['reason']}" for p, v in e["platformStatus"].items()
                                        if v.get("reason")}))
            status = plat_status(e, platforms) + (f" ({esc(reason)})" if reason else "") + \
                {"hand": " *(hand)*", "override": " *(override)*"}.get(e.get("decidedBy"), "")
            note = note_text(e) + (f" *Swift:* {e['swift']}." if e.get("swift") else "")
            w(f"| {esc(e['id'])}{' *(no entry)*' if e.get('auto') else ''} | {sym_cell} | {status} | "
              f"{api_cell(e) or '—'} | {e['sites']} ({esc(tg)}) | {esc(note)} |")
        w("")
    ignored = [e for e in entries if e["status"] == "ignore"]
    if ignored:
        w("### Ignored (not OS interfaces)")
        w("")
        for e in ignored:
            w(f"- [{esc(e['id'])}] {', '.join(code(s) for s in e['symbols'])}: {esc(note_text(e))}")
        w("")

    # ---------------------------------------------------------- Darwin
    dz = cov.get("darwin") or {}
    if dz:
        sm = dz.get("summary", {})
        bc = sm.get("byClass", {})
        w("## The Darwin module")
        w("")
        w(f"How {name}'s {sm.get('swiftFiles', 0)} library Swift files see the Darwin module on Darwin "
          "(`scripts/darwin.py`): "
          + ", ".join(f"{bc.get(c, 0)} {c}" for c in ("direct", "module re-export", "package re-export", "Foundation",
                                                      "SDK re-export"))
          + f", and {sm.get('noDarwin', 0)} not at all. *Direct* is a file that imports it in any form; *module "
          "re-export*, one whose module re-exports it from another file; *package re-export*, one that imports a "
          "module of the package or a dependency that re-exports it; *Foundation* and *SDK re-export*, one that "
          "sees it only through Apple Foundation's re-export or another SDK module's.")
        w("")
        if dz.get("reexportShims"):
            w("Re-export shims (files whose `@_exported import` makes Darwin visible to other files): "
              + ", ".join(code(x) for x in dz["reexportShims"]) + ". Re-exporting modules: "
              + ", ".join(f"{m} ({esc(c)})" for m, c in dz.get("reexportModules", {}).items()) + ".")
            w("")
        files = dz.get("files", {})
        direct = sorted(r for r, f in files.items() if f.get("class") == "direct")
        if direct:
            w(f"<details><summary>The {len(direct)} files that import Darwin</summary>")
            w("")
            for r in direct:
                f = files[r]
                w(f"- `{r}`: " + "; ".join(code(d["text"]) for d in f["direct"][:3]))
            w("")
            w("</details>")
            w("")
        ibc = dz.get("interfacesByClass", {})
        via = ibc.get("Foundation", [])
        w(f"Darwin interfaces {name} uses, by the most direct way a file that uses them sees Darwin: "
          + ", ".join(f"{len(ibc.get(c, []))} {c}" for c in ("direct", "module re-export", "package re-export",
                                                             "Foundation", "SDK re-export") if ibc.get(c)) + ". "
          + (f"Reached only through Foundation's re-export: " + ", ".join(
              f"{code(x['name'])} ({x['sites']})" for x in via[:40]) + "." if via else
             "None is reached only through Foundation's re-export."))
        w("")

    # --------------------------------------------------- per interface
    w("## Every interface")
    w("")
    w(f"The extractor's full list: each OS or C-library symbol {name}'s library targets reference, with the entry "
      "that maps it. *Evidence* is how it was found: `index` (the compiler, in the Darwin build), or a lexical "
      "rule on code the Darwin build doesn't compile (`qualified`: `Glibc.x`; `import`: `import func "
      f"WinSDK.x`; `shim`: declared by one of {name}'s C shims; `darwin-name`: named like a Darwin SDK declaration; "
      f"`unresolved`: declared nowhere {name} can see, so presumed to come from the platform's C library; "
      "`member`: a name declared nowhere, used inside an extension of an OS type, so counted as that type's member; "
      "`unindexed`: a C call the index missed). *Conditions* are the opt-in or configuration flags some sites "
      "depend on.")
    w("")
    w("| Interface | Entry | Kinds | Platforms | Targets | Sites | Examples | Evidence | Declared in |")
    w("|---|---|---|---|---|---|---|---|---|")
    for iname in sorted(interfaces, key=lambda n: (n.lower(), n)):
        it = interfaces[iname]
        e = owner.get(iname)
        ex = ", ".join(f"{s['file'].replace('Sources/', '')}:{s['line']}" for s in it["examples"][:2])
        conds = sorted({c for s in it["examples"] for c in s.get("conditions", [])})
        plats = " ".join(ABBREV[p] for p in it["platforms"])
        if conds:
            plats += f" ({esc(', '.join(conds))})"
        decl = ", ".join((it["headers"] or it["reachedThrough"])[:2])
        if it.get("shim"):
            decl = (decl + "; " if decl else "") + f"shim in {it['shim']['target']}"
        ev = ", ".join(x.replace("lexical-", "") for x in it["evidence"])
        w(f"| {code(iname)} | {esc(e['id']) if e else '**unmapped**'} | {', '.join(it['kinds'])} | {plats} | "
          f"{esc(', '.join(it['targets']))} | {it['siteCount']} | {esc(ex)} | {ev} | {esc(decl)} |")
    w("")

    # ------------------------------------------------- System already
    already = cov.get("alreadySystem", [])
    w(f"## System API {name} already uses")
    w("")
    sp = [a for a in already if a["module"] == "SystemPackage"]
    sdk = [a for a in already if a["module"] != "SystemPackage"]
    users = sorted({t for a in already for t in a.get("targets", [])})
    w(system_dependency_text(name, ext.get("systemDependency")))
    w("")
    w(f"{and_list(users) if users else name} reference{'s' if len(users) == 1 else ''} {len(sp)} SystemPackage "
      f"symbols and {len(sdk)} symbols of Apple's SDK `System` module. The check looks each SystemPackage symbol up on "
      f"the tip by scope, name and argument labels: {sum(1 for a in sp if a['onTip'])} of {len(sp)} are there.")
    w("")
    w("<details><summary>The symbols</summary>")
    w("")
    w("| Module | Symbol | Sites | On the tip |")
    w("|---|---|---|---|")
    for a in already:
        on = "" if a["onTip"] is None else ("yes" if a["onTip"] else "**no**")
        w(f"| {a['module']} | {code(a['symbol'])} | {a['sites']} | {on} |")
    w("")
    w("</details>")
    w("")

    # --------------------------------------------------- dependencies
    dep = ext.get("dependencies")
    if dep and dep.get("packages"):
        w("## OS use through dependencies")
        w("")
        w(f"{name}'s library targets name OS interfaces directly on {cov.get('directLines', 0)} lines: the "
          "extraction above. They also call into their package dependencies, whose sources the index store covers "
          "too, so the tool follows those calls through the dependencies' call graph (`scripts/deps.py`). A "
          "dependency symbol *reaches the OS* when its implementation calls an OS function, directly or through "
          "other dependency code. A requirement the package calls through a protocol reaches what any implementation "
          "the build compiled reaches, and a property what its accessors do; inside the dependencies, dispatch isn't "
          "expanded again, which misses OS work behind a dependency's own protocols. *Upper bound* expands dispatch "
          "everywhere instead, which over-counts. Either way it's what a symbol may reach, however rarely the path is "
          "taken, and process exit (an error path) doesn't count. An OS function here is "
          "one the Darwin SDK's libc and kernel interfaces declare (Darwin and its overlays, MachO), other than the C "
          "library's computation (strings, memory, math, locale, and stdio's and stdlib's formatting, conversions "
          "and allocation) and errno; file streams (fopen, fwrite) count. Dispatch, the Apple "
          "frameworks, C++'s library and OS types' initializers don't count, nor do locks and thread-local storage, "
          "which a library takes for its own synchronization. The dependencies aren't mapped; their OS calls are "
          "only counted.")
        w("")
        w(f"| Dependency | Its own OS calls: functions (sites) | {name} lines that use it | …using a symbol that "
          "reaches the OS | Upper bound | Symbols used | …that reach the OS |")
        w("|---|---|---|---|---|---|---|")
        rows = sorted(dep["packages"].items(), key=lambda kv: (-kv[1]["reachingSites"], -kv[1]["boundarySites"], kv[0]))
        for p, d in rows:
            if not d["boundarySites"] and not d["osSites"]:
                continue
            hl = f"**{p}**" if p in dep.get("through", []) else p
            w(f"| {hl} | {d['osFunctions']} ({d['osSites']}) | {d['boundarySites']} | {d['reachingSites']} | "
              f"{d.get('upperSites', '')} | {d['boundarySymbols']} | {d['reachingSymbols']} |")
        w("")
        th = [p for p in dep.get("through", []) if p in dep["packages"]]
        if th:
            tot = sum(dep["packages"][p]["reachingSites"] for p in th)
            up = sum(dep["packages"][p].get("upperSites", 0) for p in th)
            w(f"Through {and_list(th)}: {tot} lines of {name} use a symbol of one of them that reaches the OS ({up} "
              f"with dispatch expanded everywhere). {name}'s own code names an OS interface in System's scope on "
              f"{cov.get('directScopeLines', 0)} lines ({cov.get('directLines', 0)} counting Dispatch, the Apple "
              "frameworks, C libraries, C types and string, math and atomics functions). A line can do both, and one "
              "that uses two dependencies counts for each.")
            w("")
            for p in th:
                d = dep["packages"][p]
                if not d["top"]:
                    continue
                w(f"<details><summary>{p}: the symbols {name} uses most that reach the OS</summary>")
                w("")
                w("| Symbol | Lines | OS functions reached | Some of them |")
                w("|---|---|---|---|")
                for t in d["top"]:
                    w(f"| {code(t['symbol'])} | {t['sites']} | {t['reachCount']} | "
                      f"{esc(', '.join(t['reaches']))} |")
                w("")
                w(f"Its own most frequent OS calls: " + ", ".join(f"{code(n)} ×{c}" for n, c in d["topOs"]) + ".")
                w("")
                w("</details>")
                w("")
        fd = dep.get("foundation") or {}
        if fd.get("sites"):
            w(f"{name} also uses Foundation on {fd['sites']} references. The SDK's Foundation is a binary framework, "
              "so the index can't follow those calls; the types referenced most are "
              + ", ".join(f"{t} ({n})" for t, n in fd["types"][:12]) + ".")
            w("")
        g = dep.get("graph", {})
        w(f"The call graph has {g.get('symbols', 0)} symbols and {g.get('edges', 0)} edges; "
          f"{g.get('osFunctions', 0)} of its symbols are OS functions.")
        w("")

    # ------------------------------------------------------ extraction
    w("## Extraction")
    w("")
    w(f"**Library targets ({len(ext['libraryTargets'])}):** " + ", ".join(ext["libraryTargets"]) + ".")
    w("")
    sk = ext["skippedTargets"]
    nested = ext.get("nestedPackages") or {}
    w("**Skipped:** " + "; ".join(f"{k} targets ({len(v)}): {', '.join(v)}" for k, v in sorted(sk.items())) +
      (". Also the separate packages under " + and_list(
          f"`{d}`" + (f" ({n})" if n > 1 else "") for d, n in nested.items()) if nested else "") + ".")
    w("")
    if ext.get("unsupportedPlatforms"):
        w("**Targets that don't build on a platform** (they reach `#error` there), whose sites don't count there: " +
          "; ".join(f"{t} on {', '.join(ps)} ({', '.join(ext['unsupportedBecause'].get(t, [])[:2])})"
                    for t, ps in ext["unsupportedPlatforms"].items()) + ".")
        w("")
    cc = ext["crosscheck"]
    w("### Accuracy of the lexical scan")
    w("")
    w("On the lines the Darwin build compiles, the extractor also runs its lexical rules and compares them with "
      "the index. That's the estimate of how well the rules do on Linux-, Windows- and WASI-only code, which only "
      "they see. References the index attributes to a line without the name being written there (through a "
      "typealias, or inside a macro's expansion) are left out of the comparison, since no lexical rule could find "
      "them.")
    w("")
    w("| | Index references | Lexical findings | Both | Recall | Precision | *Unresolved* rule alone: findings, precision |")
    w("|---|---|---|---|---|---|---|")
    for lang in ("swift", "c"):
        d = cc.get(lang, {})
        idx, lx, ag = d.get("index", 0), d.get("lexical", 0), d.get("agree", 0)
        ul, ua = d.get("unresolvedLexical", 0), d.get("unresolvedAgree", 0)
        rec = f"{100 * ag / idx:.1f}%" if idx else "—"
        prec = f"{100 * ag / lx:.1f}%" if lx else "—"
        uprec = f"{100 * ua / ul:.1f}%" if ul else "—"
        w(f"| {'Swift' if lang == 'swift' else 'C'} | {idx} | {lx} | {ag} | {rec} | {prec} | {ul}, {uprec} |")
    w("")
    w("The *unresolved* column reruns the Swift rules without the Darwin SDK's vocabulary, so every C name falls "
      "through to the last rule; that's how names that exist only on Linux or Windows are found.")
    w("")
    sw = cc.get("swift", {})
    if sw.get("memberRule"):
        w(f"The *member* rule (a name declared nowhere, inside an extension of an OS type) fired {sw['memberRule']} "
          f"times on these lines, and the index saw a member of the same type there {sw.get('memberRuleAgree', 0)} "
          "times. Its findings aren't in the table above.")
        w("")
    for label, key in (("Missed", "misses"), ("False positives", "falsePositives")):
        items = cc.get(key, [])[:12]
        if items:
            w(f"{label} (most frequent): " + "; ".join(
                f"{code(m['name'])} ×{m['count']} ({m['examples'][0].replace('Sources/', '')})" for m in items) + ".")
            w("")
    exc = ext.get("excludedReferences", {})
    deps = sorted(set((ext.get("dependencyPackages") or {}).values()))
    w("Index references left out: " + ", ".join(f"{n} {k}" for k, n in sorted(exc.items(), key=lambda kv: -kv[1])) +
      f". `own` and `swift` are {name}'s own and the Swift libraries' declarations; `dependency` is "
      + (and_list(deps) if deps else "its package dependencies")
      + "; `implicit` and `SDK macro expansion` are references not written on their line.")
    w("")
    if ext.get("warnings"):
        w("Warnings: " + "; ".join(esc(x) for x in ext["warnings"][:20]))
        w("")

    w("## How this was generated")
    w("")
    out.append(open(args.method).read().rstrip())
    w("")
    open(args.out, "w").write("\n".join(out) + "\n")


STATUSES_ALL = ("covered", "partial", "missing", "ignore")

if __name__ == "__main__":
    main()
