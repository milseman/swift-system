#!/usr/bin/env python3
"""Write API-DELTA.md and api-delta.json from the pieces regenerate.sh produces.

Inputs (all paths are arguments; see regenerate.sh):
  --delta         symbolgraph_delta.py output
  --base-scan     scan_sources.py output for main
  --head-scan     scan_sources.py output for system-next
  --diff          `git diff -U0 BASE HEAD -- Sources/System Sources/SystemSockets`
  --base-reqavail / --head-reqavail
                  logs of builds with -require-explicit-availability=warn
  --docc          LABEL=PATH diagnostics files from `docc convert`, e.g.
                  head:SystemSockets=.../SystemSockets.diagnostics.json
  --meta          JSON with refs, commits, toolchain, SDK, date
  --base-root / --head-root
                  source roots of the two exports, stripped from paths
"""

import argparse
import collections
import json
import os
import re

OS_ORDER = ["macOS", "iOS", "watchOS", "tvOS", "visionOS"]
ALL_PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
# Conformances that are implied or inferred; hidden to keep type lines short.
IMPLIED = {"BitwiseCopyable", "SendableMetatype", "Copyable", "Escapable"}


def load(p):
    return json.load(open(p))


def parse_diff(path):
    added = collections.defaultdict(set)
    removed = collections.defaultdict(set)
    old = new = None
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("--- "):
            p = line[4:].strip()
            old = None if p == "/dev/null" else p[2:]
        elif line.startswith("+++ "):
            p = line[4:].strip()
            new = None if p == "/dev/null" else p[2:]
        elif line.startswith("@@"):
            m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            a, b = int(m.group(1)), int(m.group(2) or 1)
            c, d = int(m.group(3)), int(m.group(4) or 1)
            if old:
                removed[old].update(range(a, a + b))
            if new:
                added[new].update(range(c, c + d))
    return added, removed


def parse_reqavail(path, root):
    """Unique (file, line, declaration text) warnings."""
    out = {}
    if not path or not os.path.exists(path):
        return []
    roots = [os.path.realpath(root) + "/", root.rstrip("/") + "/"]
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^(/[^:]+):(\d+):(\d+): warning: public declarations should have an availability attribute", line)
        if not m:
            continue
        f = m.group(1)
        for r in roots:
            if f.startswith(r):
                f = f[len(r):]
            elif f.startswith("/private" + r):
                f = f[len("/private" + r):]
        ln = int(m.group(2))
        src = os.path.join(root, f)
        text = ""
        if os.path.exists(src):
            lines = open(src, encoding="utf-8").read().split("\n")
            if ln - 1 < len(lines):
                text = lines[ln - 1].strip()
        out[(f, ln)] = text
    return [{"file": f, "line": l, "text": t} for (f, l), t in sorted(out.items())]


def parse_docc(specs, roots):
    diags = collections.defaultdict(list)
    for spec in specs or []:
        label, path = spec.split("=", 1)
        side, module = label.split(":")
        if not os.path.exists(path):
            continue
        for d in load(path).get("diagnostics", []):
            src = d.get("source", "")
            if src.startswith("file://"):
                src = src[7:]
            src = os.path.realpath(src)
            for r in roots[side]:
                if src.startswith(r):
                    src = src[len(r):]
            diags[side].append({
                "module": module,
                "severity": d.get("severity"),
                "summary": d.get("summary"),
                "file": src,
                "line": (d.get("range") or {}).get("start", {}).get("line"),
            })
    return diags


def conformance_text(confs):
    s = set(c for c in confs if c not in IMPLIED)
    if "OptionSet" in s:
        s -= {"SetAlgebra", "ExpressibleByArrayLiteral", "RawRepresentable", "Equatable"}
    if "Hashable" in s or "Comparable" in s:
        s.discard("Equatable")
    if "ExpressibleByStringLiteral" in s:
        s -= {"ExpressibleByExtendedGraphemeClusterLiteral", "ExpressibleByUnicodeScalarLiteral"}
    if "Collection" in s:
        s.discard("Sequence")
    if {"Encodable", "Decodable"} <= s:
        s -= {"Encodable", "Decodable"}
        s.add("Codable")
    return ", ".join(sorted(s))


def platforms_text(platforms, module_platforms):
    if platforms is None:
        return "?"
    ps = [p for p in ALL_PLATFORMS if p in platforms]
    full = [p for p in ALL_PLATFORMS if p in module_platforms]
    if ps == full:
        return ""
    missing = [p for p in full if p not in ps]
    if len(missing) <= len(ps):
        return "not on " + ", ".join(missing)
    return "only " + ", ".join(ps)


def md_code(s):
    s = s.replace("`", "'")
    return f"`{s}`"


def md_text(s):
    return re.sub(r"([\\`*_\[\]<>|])", r"\\\1", s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--delta", required=True)
    ap.add_argument("--base-scan", required=True)
    ap.add_argument("--head-scan", required=True)
    ap.add_argument("--diff", required=True)
    ap.add_argument("--base-reqavail")
    ap.add_argument("--head-reqavail")
    ap.add_argument("--base-root", required=True)
    ap.add_argument("--head-root", required=True)
    ap.add_argument("--docc", action="append")
    ap.add_argument("--meta", required=True)
    ap.add_argument("--digester")
    ap.add_argument("--out-md", required=True)
    ap.add_argument("--out-json", required=True)
    a = ap.parse_args()

    meta = load(a.meta)
    delta = load(a.delta)
    base_scan = load(a.base_scan)
    head_scan = load(a.head_scan)
    added_lines, removed_lines = parse_diff(a.diff)
    roots = {
        "base": [os.path.realpath(a.base_root) + "/"],
        "head": [os.path.realpath(a.head_root) + "/"],
    }

    entries = delta["entries"]
    added = [e for e in entries if e["status"] == "added"]
    removed = [e for e in entries if e["status"] == "removed"]
    changed = [e for e in entries if e["status"] == "changed"]

    # Attach scanner facts (platforms, spelled attributes) to graph entries.
    hs_decls = head_scan["declarations"]
    bs_decls = base_scan["declarations"]
    hs_index = {(d["file"], d["line"]): d for d in hs_decls}
    bs_index = {(d["file"], d["line"]): d for d in bs_decls}
    unsupported = {m: set(v) for m, v in head_scan["moduleUnsupportedPlatforms"].items()}
    module_platforms = {m: [p for p in ALL_PLATFORMS if p not in unsupported.get(m, set())]
                        for m in ("SystemPackage", "SystemSockets")}
    for e in entries:
        idx = bs_index if e["status"] == "removed" else hs_index
        d = idx.get((e["file"], e["line"]))
        e["platforms"] = d["platforms"] if d else None
        e["ownAvailability"] = d["availability"] if d else None
        e["scopeAvailability"] = d["scopeAvailability"] if d else None
        e["scannerHasDoc"] = d["hasDoc"] if d else None

    # Public declarations the graphs don't show.
    def is_public(d):
        return d["access"] and (d["access"].startswith("public") or d["access"] == "open")

    type_access = {}
    for scan in (base_scan, head_scan):
        for t in scan.get("types", []):
            type_access[(t["module"], t["name"])] = t["access"]

    def hidden_class(d):
        if d["unavailable"]:
            return "unavailable"
        if d["underscored"]:
            return "underscored"
        if "Darwin" not in d["platforms"]:
            return "platform"
        for kind, name, acc in zip(d["scopeKinds"], d["scopes"], d["scopeAccess"]):
            if kind == "extension":
                acc = type_access.get((d["module"], name), "public")
            if acc not in ("public", "open"):
                return "nonpublic-scope"
        return "unexplained"

    # Graph symbol locations on each side, from the graphs themselves.
    head_graph_locs = set()
    base_graph_locs = set()
    for side, key in (("head", "headLocations"), ("base", "baseLocations")):
        for f, l in delta.get(key, []):
            (head_graph_locs if side == "head" else base_graph_locs).add((f, l))

    hidden_new = []
    for d in hs_decls:
        if not is_public(d) or (d["file"], d["line"]) in head_graph_locs:
            continue
        if d["line"] not in added_lines.get(d["file"], ()):
            continue
        d = dict(d, hiddenClass=hidden_class(d))
        hidden_new.append(d)
    hidden_removed = []
    for d in bs_decls:
        if not is_public(d) or (d["file"], d["line"]) in base_graph_locs:
            continue
        if d["line"] not in removed_lines.get(d["file"], ()):
            continue
        hidden_removed.append(dict(d, hiddenClass=hidden_class(d)))
    hidden_all_head = collections.Counter(hidden_class(d) for d in hs_decls
                                          if is_public(d) and (d["file"], d["line"]) not in head_graph_locs)
    underscored_existing = [d for d in hs_decls if is_public(d) and d["underscored"]
                            and d["line"] not in added_lines.get(d["file"], ())]

    # Explicit-availability warnings.
    ra_base = parse_reqavail(a.base_reqavail, a.base_root)
    ra_head = parse_reqavail(a.head_reqavail, a.head_root)
    base_texts = collections.Counter((w["file"], w["text"]) for w in ra_base)
    for w in ra_head:
        w["new"] = base_texts[(w["file"], w["text"])] == 0
        d = hs_index.get((w["file"], w["line"]))
        w["kind"] = ("public" if d and is_public(d) else "@usableFromInline" if d and d["usableFromInline"]
                     else "extension" if w["text"].startswith("extension") else "other")

    # DocC diagnostics: new = summary not present on main.
    docc = parse_docc(a.docc, roots)
    base_summaries = collections.Counter(d["summary"] for d in docc.get("base", []))
    for d in docc.get("head", []):
        d["new"] = base_summaries[d["summary"]] == 0

    # Oddities computed from the data.
    no_avail = [e for e in added if e["availabilityClass"] == "none"]
    os_floor_in_199 = [e for e in added if e["system"] == "199" and e["explicitOS"]
                       and e["ownAvailability"] and any(re.search(r"\b(macOS|iOS|watchOS|tvOS|visionOS)\b", x)
                                                        for x in e["ownAvailability"])
                       and any("System 199" in x for x in (e["scopeAvailability"] or []))]
    old_macro_new_api = [e for e in added if e["system"] and e["system"] != "199"]
    os_only = [e for e in added if e["availabilityClass"] == "OS only"]
    no_doc = [e for e in added if not e["hasDoc"] and not e.get("inheritsDocFrom")]
    inherits_doc = [e for e in added if not e["hasDoc"] and e.get("inheritsDocFrom")]
    detached_doc = [e for e in added if not e["hasDoc"] and e.get("scannerHasDoc")]
    escaped_ticks = [e for e in added if "\\`" in (e.get("docText") or "")]
    hidden_no_doc = [d for d in hidden_new if d["hiddenClass"] == "platform" and not d["hasDoc"]]
    underscored_graph = [e for e in added if re.search(r"(\(|:)_[A-Za-z]", e["title"]) or e["title"].startswith("_")]

    # ------------------------------------------------------------ markdown
    L = []
    w = L.append
    base_ref, head_ref = meta["baseRef"], meta["headRef"]
    w(f"# Public API delta: `{base_ref}` → `{head_ref}`")
    w("")
    for side, ref in (("Base", base_ref), ("Head", head_ref)):
        subject = meta.get(side.lower() + "Subject")
        w(f"- {side}: `{ref}` @ `{meta[side.lower() + 'Commit']}`" + (f" — {md_text(subject)}" if subject else ""))
    w("")
    w(f"This covers the **SystemPackage** and **SystemSockets** modules. It was generated {meta['date']} "
      f"on {meta['host']} with {meta['swift']}, macOS SDK {meta['sdk']}.")
    w("")
    w("The primary source is the public symbol graphs of a macOS debug build of each commit. Synthesized "
      "members are left out, and so are inherited doc comments. A source scan adds the public declarations "
      "those graphs can't see: API compiled only on other platforms, `unavailable` stubs, and underscored "
      "names. [How this was generated](#how-this-was-generated) records each design decision and the "
      "alternative it rejected.")
    w("")

    # Summary.
    n_add = collections.Counter(e["module"] for e in added)
    cnt = delta["counts"]
    w("## Summary")
    w("")
    w(f"- **{len(added)} added, {len(removed)} removed, {len(changed)} changed** declarations in the macOS "
      f"symbol graphs.")
    for m in ("SystemPackage", "SystemSockets"):
        b, h = cnt["base"].get(m, 0), cnt["head"].get(m, 0)
        note = " SystemSockets is a new module; it doesn't exist on `main`." if b == 0 and h else ""
        w(f"  - {m}: +{n_add.get(m, 0)} ({b} → {h} public symbols).{note}")
    ac = collections.Counter(avail_class(e) for e in added)
    w("- Availability of the additions:")
    for k in sorted(ac, key=lambda k: (-ac[k], k)):
        w(f"  - {k}: {ac[k]}")
    hn = collections.Counter(d["hiddenClass"] for d in hidden_new)
    w("- The source scan finds these new public declarations, which the macOS graphs can't show:")
    w(f"  - {hn.get('platform', 0)} compiled only on other platforms;")
    w(f"  - {hn.get('unavailable', 0)} new `@available(*, unavailable, renamed:)` stubs;")
    w(f"  - {hn.get('underscored', 0)} new underscored public declaration(s).")
    if hn.get("unexplained") or hn.get("nonpublic-scope"):
        w(f"  - {hn.get('unexplained', 0) + hn.get('nonpublic-scope', 0)} declarations the scan couldn't classify; "
          f"see the list below.")
    w(f"- {len(hidden_removed)} public declarations hidden from the graphs were removed.")
    if a.digester and os.path.exists(a.digester):
        dg = load(a.digester)
        w("- Cross-check with `swift-api-digester`, which dumps every declaration, implicit ones included:")
        for m, i in dg["modules"].items():
            extra = ("; explicit declarations it has that the graphs don't: "
                     + ", ".join(f"`{p}`" for p in i["digesterOnlyExplicit"])) if i["digesterOnlyExplicit"] else ""
            missing = (f"; **{len(i['graphAddedMissingFromDigester'])} graph additions it doesn't have**"
                       if i["graphAddedMissingFromDigester"] else "; it has every graph addition")
            brk = ("" if i["diagnoseSdk"] is None else
                   "; `-diagnose-sdk` reports no breaking changes" if not i["diagnoseSdk"] else
                   f"; `-diagnose-sdk` reports: " + "; ".join(i["diagnoseSdk"]))
            w(f"  - {m}: +{i['digesterAdded']} / -{len(i['digesterRemoved'])} declarations, which is the graphs' "
              f"+{i['graphAdded']} plus {i['digesterOnlyImplicit']} implicit ones{extra}{missing}{brk}.")
        for err in dg.get("errors", []):
            w(f"  - error: {err}")
    w("- Nothing was removed or changed. Every deletion in `git diff` between the two commits is "
      "implementation code. The *changed* check compares declaration text (including default "
      "arguments), availability, conformances, generic and extension constraints, and access level, "
      "and pairs symbols by path when a signature change alters the USR.")
    w("")

    # Area table.
    w("### By area")
    w("")
    w("Each row is a top-level type, and nested types count toward it: `FilePath.ResolutionFlags` counts under "
      "`FilePath`. Extensions of another module's types appear under the extended type. Availability counts "
      "use S = `System`; +OS means an explicit OS floor.")
    w("")
    w("| Module | Area | Added | Removed | Changed | Availability of additions |")
    w("|---|---|---:|---:|---:|---|")
    rows = collections.defaultdict(lambda: {"added": 0, "removed": 0, "changed": 0, "avail": collections.Counter()})
    for e in entries:
        if e["status"] not in ("added", "removed", "changed"):
            continue
        area = e["area"] + (f" (extends {e['extendedModule']})" if e.get("extendedModule") else "")
        r = rows[(e["module"], area)]
        r[e["status"]] += 1
        if e["status"] == "added":
            r["avail"][short_avail(e)] += 1
    tot = collections.Counter()
    for (m, area) in sorted(rows):
        r = rows[(m, area)]
        tot.update({k: r[k] for k in ("added", "removed", "changed")})
        av = ", ".join(f"{k} ×{v}" for k, v in sorted(r["avail"].items(), key=lambda kv: (-kv[1], kv[0])))
        w(f"| {m} | [`{area}`](#{anchor(m, area)}) | {r['added']} | {r['removed']} | {r['changed']} | {av} |")
    w(f"| **Total** | | **{tot['added']}** | **{tot['removed']}** | **{tot['changed']}** | |")
    w("")

    # By file.
    w("### By source file")
    w("")
    w("| File | Added | Removed | Changed | Groups (types and extensions) |")
    w("|---|---:|---:|---:|---|")
    files = collections.defaultdict(lambda: {"added": 0, "removed": 0, "changed": 0, "groups": collections.Counter()})
    for e in entries:
        if e["status"] not in ("added", "removed", "changed"):
            continue
        f = files[e["file"] or "(no location: synthesized)"]
        f[e["status"]] += 1
        f["groups"][e["group"]] += 1
    for fname in sorted(files):
        f = files[fname]
        groups = ", ".join(f"`{g}`" + (f" ×{c}" if c > 1 else "") for g, c in sorted(f["groups"].items()))
        w(f"| `{fname}` | {f['added']} | {f['removed']} | {f['changed']} | {groups} |")
    w("")

    # Oddities.
    w("## Oddities")
    w("")
    w("### 1. Availability")
    w("")
    w(f"**Public API with no `@available` at all ({len(no_avail)} symbols).** In the "
      f"`SYSTEM_ABI_STABLE` build these would appear as if always available:")
    w("")
    for g, items in group_by(no_avail, "group"):
        w(f"- `{g}` ({len(items)}): " + ", ".join(md_code(i["title"]) for i in items)
          + f" — `{items[0]['file']}`")
    w("")
    w(f"**Explicit OS floor on a member of a `System 199` extension ({len(os_floor_in_199)} symbols).** "
      "Under `SYSTEM_ABI_STABLE`, `System 199` means macOS 9999, so these members are \"more available than "
      "the enclosing scope\", and that build fails. CLAUDE.md's fix is to put both attributes on the member, "
      "in an extension without `System 199`:")
    w("")
    for g, items in group_by(os_floor_in_199, "group"):
        floors = sorted(set(", ".join(f"{k} {v}" for k, v in sorted(i["explicitOS"].items(), key=osk)) for i in items))
        w(f"- `{g}`: " + ", ".join(md_code(i["title"]) for i in items) + f" — floor {'; '.join(floors)} — "
          + ", ".join(sorted(set(f"`{i['file']}`" for i in items))))
    w("")
    w(f"**Unreleased additions that don't carry `System 199` ({len(old_macro_new_api) + len(os_only)} symbols).** "
      "CLAUDE.md describes this pattern as intentional for the Span-based I/O. It's still worth a check, "
      "because nothing marks these symbols as unreleased:")
    w("")
    for g, items in group_by(old_macro_new_api + os_only, "group"):
        labels = sorted(set(i["availability"] for i in items))
        w(f"- `{g}`: " + ", ".join(md_code(i["title"]) for i in items) + " — " + "; ".join(labels))
    w("")
    new_ra = [x for x in ra_head if x["new"]]
    w(f"**`-require-explicit-availability` warnings.** There are {len(ra_head)} on `{head_ref}` and "
      f"{len(ra_base)} on `{base_ref}`; {len(new_ra)} are new. The check also flags `@usableFromInline` "
      "declarations, which are ABI-public:")
    w("")
    w("| Kind | Declaration | Source |")
    w("|---|---|---|")
    for x in ra_head:
        w(f"| {x['kind']}{'' if x['new'] else ' (also on main)'} | {md_code(x['text'])} | `{x['file']}:{x['line']}` |")
    w("")
    hidden_noavail = [d for d in hidden_new if d["hiddenClass"] == "platform"
                      and not d["availability"] and not d["scopeAvailability"]]
    if hidden_noavail:
        w(f"**Platform-only additions with no availability ({len(hidden_noavail)}):** "
          + ", ".join(md_code(".".join(d['scopes'] + [d['name']])) for d in hidden_noavail))
        w("")

    w("### 2. Documentation")
    w("")
    w(f"**Added symbols with no doc comment ({len(no_doc)}).** This leaves out the {len(inherits_doc)} "
      "symbols, such as `rawValue`, `init(rawValue:)`, `==`, `hash(into:)` and `description`, that "
      "inherit a doc comment from the protocol requirement they implement:")
    w("")
    for g, items in group_by(no_doc, "group"):
        w(f"- `{g}` ({len(items)}): " + ", ".join(md_code(i["title"]) for i in items))
    w("")
    if hidden_no_doc:
        w(f"**Platform-only additions with no doc comment ({len(hidden_no_doc)}):** "
          + ", ".join(md_code(".".join(d['scopes'] + [d['name']])) for d in hidden_no_doc))
        w("")
    if detached_doc:
        w(f"**Doc comments the compiler doesn't attach ({len(detached_doc)}).** The source has a `///` "
          "comment, but the symbol graph has none. The usual cause is a comment placed between an "
          "attribute and the declaration:")
        w("")
        for e in detached_doc:
            w(f"- {md_code(e['path'])} — `{e['file']}:{e['line']}`")
        w("")
    if escaped_ticks:
        byfile = collections.Counter(e["file"] for e in escaped_ticks)
        w(f"**Escaped backticks in doc comments ({len(escaped_ticks)} added symbols).** "
          "Text like ``\\`BRKINT\\` `` renders as literal backticks rather than code voice. Affected files: "
          + ", ".join(f"`{f}` ({c})" for f, c in byfile.most_common()) + ".")
        w("")
    head_docc = docc.get("head", [])
    w(f"**DocC diagnostics.** Building the docs produced {len(head_docc)} warnings on `{head_ref}` and "
      f"{len(docc.get('base', []))} on `{base_ref}`:")
    w("")
    w("| Module | Warning | Source | New |")
    w("|---|---|---|---|")
    for d in sorted(head_docc, key=lambda d: (d["module"], d["file"], d["line"] or 0)):
        s = d["summary"].replace("|", "\\|")
        w(f"| {d['module']} | {s} | `{d['file']}:{d['line']}` | {'yes' if d['new'] else 'no'} |")
    w("")
    amb = sorted(set(re.sub(r" at .*", "", d["summary"]) for d in head_docc
                     if d["new"] and "is ambiguous" in (d["summary"] or "")))
    if amb:
        w("New ambiguous links (" + ", ".join(amb) + ") mean a name linked from a doc comment has gained "
          "an overload. Each such link needs a disambiguating suffix.")
        w("")
    missing = sorted(set(re.sub(r" doesn't exist.*", "", d["summary"]) for d in head_docc
                         if d["new"] and "doesn't exist" in (d["summary"] or "")))
    if missing:
        w("New unresolved links (" + ", ".join(missing) + ") point to a symbol DocC can't find from that "
          "page. A link to another module's symbol needs the module prefix, as in ``SystemPackage/Errno``.")
        w("")

    w("### 3. Underscored and SPI API")
    w("")
    und_new = [d for d in hidden_new if d["hiddenClass"] == "underscored"]
    w(f"- New public declarations with an underscored name or label: {len(und_new) + len(underscored_graph)}.")
    for d in und_new:
        w(f"  - {md_code(d['signature'])}: `{d['file']}:{d['line']}`, with availability "
          f"{', '.join(d['availability'] + d['scopeAvailability']) or 'none'}.")
    for e in underscored_graph:
        w(f"  - {md_code(e['decl'])}: `{e['file']}:{e['line']}`")
    w(f"- Underscored public declarations that were already on `{base_ref}`: {len(underscored_existing)}"
      + (" (" + ", ".join(md_code('.'.join(d['scopes'] + [d['name']])) for d in underscored_existing) + ")"
         if underscored_existing else "") + ".")
    w(f"- `@_spi` declarations: {meta.get('spiCountHead', 0)} on `{head_ref}` and "
      f"{meta.get('spiCountBase', 0)} on `{base_ref}`. Symbol graphs are extracted without "
      "`--include-spi-symbols`, so SPI would show up only here.")
    npub_new = sum(1 for d in hidden_new if d["hiddenClass"] == "nonpublic-scope")
    w(f"- Public members of non-public types: {hidden_all_head.get('nonpublic-scope', 0)} on `{head_ref}`, "
      f"{npub_new} of them new. These are not API.")
    w("")

    w("### 4. ABI surface")
    w("")
    ufi_new = [d for d in hs_decls if d["usableFromInline"] and d["line"] in added_lines.get(d["file"], ())]
    ufi_top = [d for d in ufi_new if not d["scopes"]]
    base_ufi_top = collections.Counter(d["file"] for d in bs_decls if d["usableFromInline"] and not d["scopes"])
    w(f"- New `@usableFromInline` declarations: {len(ufi_new)}, of which {len(ufi_top)} are at top level. "
      f"On `{base_ref}`, the only top-level `@usableFromInline` declarations are in "
      + (", ".join(f"`{f}`" for f in sorted(base_ufi_top)) or "no file") + ". The new top-level ones are:")
    for d in ufi_top:
        w(f"  - {md_code(d['signature'][:120])}: `{d['file']}:{d['line']}`, availability: "
          f"{', '.join(d['availability']) or 'none'}")
    nonaeic = [d for d in [h for h in hidden_new if h["hiddenClass"] == "platform"]
               + [hs_index[(e['file'], e['line'])] for e in added if (e['file'], e['line']) in hs_index]
               if d["kw"] in ("func", "init", "subscript") and is_public(d)
               and not any(x.startswith(("@_alwaysEmitIntoClient", "@inlinable", "@inline(__always)", "@_transparent"))
                           for x in d["attributes"])]
    byfile = collections.Counter(d["file"] for d in nonaeic)
    w(f"- New public functions, initializers and subscripts without `@_alwaysEmitIntoClient` or `@inlinable`: "
      f"{len(nonaeic)}. In the SDK build these become ABI entry points. By file: "
      + ", ".join(f"`{f}` ({c})" for f, c in byfile.most_common()) + ".")
    w("")

    w("### 5. Public declarations the macOS graphs can't see")
    w("")
    plat = [d for d in hidden_new if d["hiddenClass"] == "platform"]
    w(f"**New public API that isn't compiled on Darwin ({len(plat)}).** Platforms come from evaluating each "
      "declaration's `#if` stack:")
    w("")
    w("| Declaration | Platforms | Availability | Doc | Source |")
    w("|---|---|---|---|---|")
    for d in plat:
        name = ".".join(d["scopes"] + [d["name"]])
        av = ", ".join(dict.fromkeys(x.replace("@available(", "").rstrip(")")
                                     for x in d["availability"] + d["scopeAvailability"]))
        w(f"| {md_code(name)} | {', '.join(d['platforms'])} | {av or 'none'} | {'yes' if d['hasDoc'] else '**no**'} "
          f"| `{d['file']}:{d['line']}` |")
    w("")
    unav = [d for d in hidden_new if d["hiddenClass"] == "unavailable"]
    w(f"**New `@available(*, unavailable, renamed:)` stubs ({len(unav)}).** Symbol graphs omit these:")
    w("")
    for d in unav:
        ren = re.search(r'renamed:\s*"([^"]*)"', " ".join(d["unavailable"]))
        w(f"- {md_code('.'.join(d['scopes'] + [d['name']]))} → `{ren.group(1) if ren else '?'}` "
          f"(platforms: {', '.join(d['platforms'])}) — `{d['file']}:{d['line']}`")
    w("")
    other = [d for d in hidden_new if d["hiddenClass"] in ("unexplained", "nonpublic-scope")]
    if other:
        w(f"**Unclassified ({len(other)}):**")
        for d in other:
            w(f"- {md_code(d['signature'])} — `{d['file']}:{d['line']}`")
        w("")

    # Full list.
    w("## Full list by type and extension")
    w("")
    w("Each entry is the declaration as the symbol graph prints it, then its effective availability. "
      "Where the entry says so, it adds the platforms (from the `#if` stack; empty means every platform "
      "the module builds on), a missing doc comment, and constraints, then gives the source location.")
    w("")
    w(f"SystemPackage builds on {', '.join(module_platforms['SystemPackage'])}. SystemSockets builds on "
      f"{', '.join(module_platforms['SystemSockets'])}, because its files `#error` elsewhere.")
    w("")
    for status, title in (("removed", "Removed"), ("changed", "Changed")):
        items = [e for e in entries if e["status"] == status]
        w(f"### {title} ({len(items)})")
        w("")
        if not items:
            w("None.")
            w("")
        for e in items:
            ch = "; ".join(e.get("changes", []))
            w(f"- {md_code(e['path'])} — {ch} — `{e['file']}:{e['line']}`")
        if items:
            w("")
    w(f"### Added ({len(added)})")
    w("")
    for m in ("SystemPackage", "SystemSockets"):
        items = [e for e in added if e["module"] == m]
        if not items:
            continue
        w(f"#### {m} (+{len(items)})")
        w("")
        for area, area_items in group_by(items, "area"):
            ext = area_items[0].get("extendedModule")
            area_label = area + (f" (extends {ext})" if ext else "")
            w(f'<a id="{anchor(m, area_label)}"></a>')
            w("")
            for g, gitems in group_by(area_items, "group"):
                files = sorted(set(i["file"] for i in gitems if i["file"]))
                ext_mod = gitems[0].get("extendedModule")
                w(f"##### `{g}` (+{len(gitems)})" + (f" — extension of `{ext_mod}.{g}`" if ext_mod else ""))
                w("")
                w("Files: " + ", ".join(f"`{f}`" for f in files))
                w("")
                gitems = sorted(gitems, key=lambda i: (i["kind"] not in ("swift.struct", "swift.enum", "swift.class",
                                                                         "swift.protocol"), i["file"] or "", i["line"] or 0))
                for i in gitems:
                    bits = [f"`{short_avail_full(i)}`"]
                    pt = platforms_text(i.get("platforms"), module_platforms[m])
                    if pt:
                        bits.append(pt)
                    if not i["hasDoc"] and not i.get("inheritsDocFrom"):
                        bits.append("**no doc**")
                    if i["extConstraints"]:
                        bits.append(f"where {i['extConstraints']}")
                    conf = conformance_text(i["conformances"]) if i["kind"] in (
                        "swift.struct", "swift.enum", "swift.class", "swift.protocol") else ""
                    decl = i["decl"] + (f" : {conf}" if conf else "")
                    w(f"- {md_code(decl)} — {' · '.join(bits)} — `{os.path.basename(i['file'] or '?')}:{i['line']}`")
                w("")

    # Method.
    w("## How this was generated")
    w("")
    w(open(os.path.join(os.path.dirname(__file__), "method.md")).read().strip())
    w("")

    open(a.out_md, "w").write("\n".join(L) + "\n")

    json.dump({
        "meta": meta,
        "counts": {"added": len(added), "removed": len(removed), "changed": len(changed),
                   "byModule": dict(n_add), "symbols": cnt},
        "entries": [e for e in entries if e["status"] in ("added", "removed", "changed")],
        "hiddenFromGraphs": {"added": hidden_new, "removed": hidden_removed},
        "oddities": {
            "noAvailability": [e["path"] for e in no_avail],
            "osFloorInSystem199Extension": [e["path"] for e in os_floor_in_199],
            "unreleasedWithoutSystem199": [e["path"] for e in old_macro_new_api + os_only],
            "requireExplicitAvailability": {"head": ra_head, "base": ra_base},
            "noDocComment": [e["path"] for e in no_doc],
            "detachedDocComment": [e["path"] for e in detached_doc],
            "escapedBackticksInDocs": [e["path"] for e in escaped_ticks],
            "docc": docc,
            "underscored": {"new": [d["signature"] for d in und_new] + [e["decl"] for e in underscored_graph],
                            "existing": [d["signature"] for d in underscored_existing]},
            "usableFromInlineNew": len(ufi_new),
            "publicWithoutAEIC": [f"{d['file']}:{d['line']}" for d in nonaeic],
        },
    }, open(a.out_json, "w"), indent=1)
    print(f"report: wrote {a.out_md} and {a.out_json}")


def osk(kv):
    k = kv[0]
    return (OS_ORDER.index(k) if k in OS_ORDER else 99, k)


def avail_class(e):
    if e["system"] and e["explicitOS"]:
        return f"System {e['system']} + explicit OS floor"
    if e["system"]:
        return f"System {e['system']}"
    if e["explicitOS"]:
        return "explicit OS floor only (no `System` macro)"
    return "no `@available`"


def short_avail(e):
    if e["availabilityClass"] == "none":
        return "none"
    s = f"S{e['system']}" if e["system"] else ""
    if e["explicitOS"]:
        s += ("+" if s else "") + "OS"
    return s


def short_avail_full(e):
    parts = []
    if e["system"]:
        parts.append(f"System {e['system']}")
    if e["explicitOS"]:
        parts.append(", ".join(f"{k} {v}" for k, v in sorted(e["explicitOS"].items(), key=osk)))
    s = " + ".join(parts) if parts else "no @available"
    if e.get("deprecated"):
        s += "; deprecated"
    return s


def group_by(items, key):
    d = collections.OrderedDict()
    for i in sorted(items, key=lambda i: (i[key], i.get("file") or "", i.get("line") or 0)):
        d.setdefault(i[key], []).append(i)
    return list(d.items())


def anchor(module, area):
    return re.sub(r"[^a-z0-9]+", "-", f"{module}-{area}".lower()).strip("-")


if __name__ == "__main__":
    main()
