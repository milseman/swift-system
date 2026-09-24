#!/usr/bin/env python3
"""Diff two sets of Swift symbol graphs, from a base and a head commit.

Symbols are matched by precise identifier (USR). Unmatched symbols are then
paired by (module, path, kind), because a signature change such as
`throws` -> `throws(Errno)` changes the USR; such pairs are reported as
changed rather than as a removal plus an addition.

Availability is decoded from the `OpenBSD` marker domain that
patch_manifest.py adds to each `System x.y` macro (see that script).

Usage:
  symbolgraph_delta.py --base DIR --base-root PATH --head DIR --head-root PATH
                       [--base-docs DIR --head-docs DIR] --out delta.json

DIR holds `<Module>.symbols.json` and `<Module>@<Other>.symbols.json` files.
PATH is the source root the graphs were built from; it is stripped from
source locations so they come out repo-relative.
The optional docs graphs (built without --skip-inherited-docs) are used only
to tell whether a symbol without its own doc comment inherits one from a
protocol requirement.
"""

import argparse
import difflib
import glob
import json
import os
import re
import sys
from collections import defaultdict

MODULES = ["SystemPackage", "SystemSockets"]
MARKER_DOMAIN = "OpenBSD"
# What every `System x.y` macro expands to in the default (non-ABI-stable) build.
SOURCE_AVAILABILITY = {"macOS": "10.10", "iOS": "8.0", "watchOS": "2.0", "tvOS": "9.0", "visionOS": "1.0"}
OS_ORDER = ["macOS", "iOS", "watchOS", "tvOS", "visionOS"]


def version_str(v):
    if v is None:
        return None
    parts = [v.get("major", 0)]
    if "minor" in v:
        parts.append(v["minor"])
    if "patch" in v:
        parts.append(v["patch"])
    return ".".join(str(p) for p in parts)


def norm_version(s):
    """'10.10' and '10.10.0' compare equal; '15' and '15.0' too."""
    parts = [int(p) for p in s.split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def decode_availability(entries):
    """Returns a dict describing a symbol's effective availability."""
    out = {
        "system": None,           # e.g. "199", "1.7.0"
        "os": {},                 # explicit OS floors differing from the macro expansion
        "osRaw": {},              # every OS domain as recorded
        "deprecated": None,       # message/renamed if deprecated
        "unavailable": [],        # domains where unavailable
        "other": [],
    }
    for e in entries or []:
        d = e.get("domain")
        if d == MARKER_DOMAIN:
            out["system"] = version_str(e.get("introduced"))
            continue
        intro = version_str(e.get("introduced"))
        if e.get("isUnconditionallyUnavailable"):
            out["unavailable"].append(d)
        if e.get("isUnconditionallyDeprecated") or e.get("deprecated"):
            dep = {"domain": d}
            for k in ("message", "renamed"):
                if e.get(k):
                    dep[k] = e[k]
            if e.get("deprecated"):
                dep["version"] = version_str(e["deprecated"])
            out["deprecated"] = dep
        if intro is not None:
            out["osRaw"][d] = intro
            if d in SOURCE_AVAILABILITY:
                if norm_version(intro) != norm_version(SOURCE_AVAILABILITY[d]) or out["system"] is None:
                    out["os"][d] = intro
            else:
                out["os"][d] = intro
        for k in ("obsoleted",):
            if e.get(k):
                out["other"].append({"domain": d, k: version_str(e[k])})
    # A marker may be processed after an OS entry; redo the explicit-floor test.
    if out["system"] is not None:
        out["os"] = {d: v for d, v in out["osRaw"].items()
                     if d not in SOURCE_AVAILABILITY
                     or norm_version(v) != norm_version(SOURCE_AVAILABILITY[d])}
    return out


def availability_label(a):
    parts = []
    if a["system"]:
        parts.append(f"System {a['system']}")
    if a["os"]:
        doms = sorted(a["os"], key=lambda d: (OS_ORDER.index(d) if d in OS_ORDER else 99, d))
        parts.append(", ".join(f"{d} {a['os'][d]}" for d in doms))
    label = " + ".join(parts) if parts else "none"
    if a["deprecated"]:
        dep = a["deprecated"]
        extra = ""
        if dep.get("renamed"):
            extra = f", renamed: {dep['renamed']}"
        elif dep.get("message"):
            extra = f": {dep['message']}"
        label += f"; deprecated{extra}"
    if a["unavailable"]:
        label += "; unavailable on " + ", ".join(sorted(a["unavailable"]))
    return label


def availability_class(a):
    if a["system"] and a["os"]:
        return "System + OS"
    if a["system"]:
        return f"System {a['system']}"
    if a["os"]:
        return "OS only"
    return "none"


def fragments_text(frags):
    return re.sub(r"\s+", " ", "".join(f["spelling"] for f in frags or [])).strip()


def constraints_text(cs):
    out = []
    for c in cs or []:
        op = {"conformance": ":", "sameType": "==", "superclass": ":"}.get(c.get("kind"), c.get("kind"))
        out.append(f"{c.get('lhs')} {op} {c.get('rhs')}")
    return ", ".join(out)


class Graphs:
    def __init__(self, directory, root, docs_directory=None):
        self.symbols = {}          # usr -> record
        self.rel = defaultdict(list)
        self.root = os.path.realpath(root)
        self.ext_blocks = {}       # extension-block usr -> (module, extended path, extendedModule)
        self.docs_inherited = {}   # usr -> source module of inherited doc comment
        for module in MODULES:
            for path in sorted(glob.glob(os.path.join(directory, f"{module}.symbols.json"))
                               + glob.glob(os.path.join(directory, f"{module}@*.symbols.json"))):
                self._load(module, path)
        if docs_directory:
            for module in MODULES:
                for path in sorted(glob.glob(os.path.join(docs_directory, f"{module}.symbols.json"))
                                   + glob.glob(os.path.join(docs_directory, f"{module}@*.symbols.json"))):
                    g = json.load(open(path))
                    for s in g["symbols"]:
                        dc = s.get("docComment")
                        if dc and dc.get("module") and dc.get("module") != module:
                            self.docs_inherited[s["identifier"]["precise"]] = dc["module"]
                        elif dc and not dc.get("uri"):
                            self.docs_inherited[s["identifier"]["precise"]] = dc.get("module", "?")

    def relpath(self, uri):
        if not uri:
            return None
        p = uri[len("file://"):] if uri.startswith("file://") else uri
        p = os.path.realpath(p)
        if p.startswith(self.root + os.sep):
            return p[len(self.root) + 1:]
        return p

    def _load(self, module, path):
        g = json.load(open(path))
        for s in g["symbols"]:
            usr = s["identifier"]["precise"]
            kind = s["kind"]["identifier"]
            ext = s.get("swiftExtension") or {}
            loc = s.get("location") or {}
            if kind == "swift.extension":
                self.ext_blocks[usr] = {
                    "module": module,
                    "path": ".".join(s["pathComponents"]),
                    "extendedModule": ext.get("extendedModule"),
                    "constraints": constraints_text(ext.get("constraints")),
                    "availability": decode_availability(s.get("availability")),
                    "file": self.relpath(loc.get("uri")),
                    "line": (loc.get("position", {}).get("line", -1) + 1) if loc else None,
                }
                continue
            doc = s.get("docComment")
            doc_lines = [l["text"] for l in doc["lines"]] if doc else []
            summary = ""
            for l in doc_lines:
                if l.strip():
                    summary = l.strip()
                    break
            rec = {
                "usr": usr,
                "module": module,
                "extendedModule": ext.get("extendedModule") if ext.get("extendedModule") != module else None,
                "kind": kind,
                "kindName": s["kind"]["displayName"],
                "pathComponents": s["pathComponents"],
                "path": ".".join(s["pathComponents"]),
                "title": s["names"]["title"],
                "decl": fragments_text(s.get("declarationFragments")),
                "access": s.get("accessLevel"),
                "extConstraints": constraints_text(ext.get("constraints")),
                "generics": constraints_text((s.get("swiftGenerics") or {}).get("constraints")),
                "availabilityRaw": s.get("availability"),
                "availability": decode_availability(s.get("availability")),
                "hasDoc": bool(doc) and bool("".join(doc_lines).strip()),
                "docText": "\n".join(doc_lines),
                "docSummary": summary,
                "file": self.relpath(loc.get("uri")),
                "line": (loc.get("position", {}).get("line", -1) + 1) if loc else None,
                "spi": s.get("spi", False),
                "conformances": [],
            }
            self.symbols[usr] = rec
        for r in g["relationships"]:
            self.rel[r["kind"]].append((module, r))

    def finish(self):
        # Conformances: source is a type or an extension block.
        self.conformances = defaultdict(set)   # (module, type path) -> {protocol}
        for module, r in self.rel["conformsTo"]:
            target = r.get("targetFallback") or r["target"]
            target = target.replace("Swift.", "") if target.startswith("Swift.") else target
            src = r["source"]
            cons = ""
            if src in self.symbols:
                key = (self.symbols[src]["module"], self.symbols[src]["path"])
            elif src in self.ext_blocks:
                eb = self.ext_blocks[src]
                key = (eb["module"], eb["path"])
                cons = eb["constraints"]
            else:
                continue
            # Constraints on a conditional conformance.
            rc = constraints_text((r.get("swiftConstraints") or []))
            if rc:
                cons = rc
            self.conformances[key].add(target + (f" (where {cons})" if cons else ""))
        for usr, rec in self.symbols.items():
            key = (rec["module"], rec["path"])
            rec["conformances"] = sorted(self.conformances.get(key, []))
            rec["inheritsDocFrom"] = self.docs_inherited.get(usr)


def top_level_area(rec):
    comps = rec["pathComponents"]
    # A top-level function, variable or typealias gets its own area row.
    if len(comps) == 1 and rec["kind"] in ("swift.func", "swift.var", "swift.typealias", "swift.func.op"):
        return "(top level)"
    return comps[0]


def group_key(rec):
    """Type or extension the declaration belongs to."""
    comps = rec["pathComponents"]
    if rec["kind"] in ("swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.actor"):
        return ".".join(comps)
    if len(comps) == 1:
        return "(top level)"
    return ".".join(comps[:-1])


def signature(rec):
    """What we compare for 'changed'. Location and docs are excluded."""
    a = rec["availability"]
    return {
        "decl": rec["decl"],
        "extConstraints": rec["extConstraints"],
        "generics": rec["generics"],
        "access": rec["access"],
        "availability": availability_label(a),
        "conformances": rec["conformances"],
        "kind": rec["kind"],
    }


def describe_changes(b, h):
    sb, sh = signature(b), signature(h)
    changes = []
    if b["usr"] != h["usr"]:
        changes.append("USR changed (signature or mangling changed)")
    if sb["decl"] != sh["decl"]:
        changes.append(f"declaration: `{sb['decl']}` → `{sh['decl']}`")
    if sb["extConstraints"] != sh["extConstraints"]:
        changes.append(f"extension constraints: `{sb['extConstraints'] or '—'}` → `{sh['extConstraints'] or '—'}`")
    if sb["generics"] != sh["generics"]:
        changes.append(f"generic constraints: `{sb['generics'] or '—'}` → `{sh['generics'] or '—'}`")
    if sb["access"] != sh["access"]:
        changes.append(f"access: {sb['access']} → {sh['access']}")
    if sb["availability"] != sh["availability"]:
        changes.append(f"availability: {sb['availability']} → {sh['availability']}")
    if sb["conformances"] != sh["conformances"]:
        added = sorted(set(sh["conformances"]) - set(sb["conformances"]))
        removed = sorted(set(sb["conformances"]) - set(sh["conformances"]))
        if added:
            changes.append("conformances added: " + ", ".join(added))
        if removed:
            changes.append("conformances removed: " + ", ".join(removed))
    if b["module"] != h["module"]:
        changes.append(f"module: {b['module']} → {h['module']}")
    return changes


def entry(rec, status, **extra):
    a = rec["availability"]
    e = {
        "status": status,
        "module": rec["module"],
        "extendedModule": rec["extendedModule"],
        "area": top_level_area(rec),
        "group": group_key(rec),
        "path": rec["path"],
        "title": rec["title"],
        "kind": rec["kind"],
        "kindName": rec["kindName"],
        "decl": rec["decl"],
        "extConstraints": rec["extConstraints"],
        "generics": rec["generics"],
        "availability": availability_label(a),
        "availabilityClass": availability_class(a),
        "system": a["system"],
        "explicitOS": a["os"],
        "deprecated": a["deprecated"],
        "hasDoc": rec["hasDoc"],
        "inheritsDocFrom": rec.get("inheritsDocFrom"),
        "docSummary": rec["docSummary"],
        "docText": rec["docText"],
        "file": rec["file"],
        "line": rec["line"],
        "conformances": rec["conformances"],
        "usr": rec["usr"],
    }
    e.update(extra)
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--base-root", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--head-root", required=True)
    ap.add_argument("--base-docs")
    ap.add_argument("--head-docs")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    base = Graphs(args.base, args.base_root, args.base_docs)
    head = Graphs(args.head, args.head_root, args.head_docs)
    base.finish()
    head.finish()

    entries = []
    unmatched_b = {u: r for u, r in base.symbols.items() if u not in head.symbols}
    unmatched_h = {u: r for u, r in head.symbols.items() if u not in base.symbols}

    for usr in sorted(set(base.symbols) & set(head.symbols)):
        b, h = base.symbols[usr], head.symbols[usr]
        changes = describe_changes(b, h)
        notes = []
        if b["file"] != h["file"]:
            notes.append(f"moved: {b['file']} → {h['file']}")
        if b["docText"] != h["docText"]:
            notes.append("doc comment edited")
        if changes:
            entries.append(entry(h, "changed", changes=changes, notes=notes,
                                 baseDecl=b["decl"], baseAvailability=availability_label(b["availability"]),
                                 baseFile=b["file"], baseLine=b["line"]))
        elif notes:
            entries.append(entry(h, "unchanged-note", notes=notes, baseFile=b["file"], baseLine=b["line"]))

    # Pair leftovers by (path, kind) — same name, different USR.
    by_key_b = defaultdict(list)
    by_key_h = defaultdict(list)
    for r in unmatched_b.values():
        by_key_b[(r["path"], r["kind"])].append(r)
    for r in unmatched_h.values():
        by_key_h[(r["path"], r["kind"])].append(r)
    paired_b, paired_h = set(), set()
    for key in sorted(set(by_key_b) & set(by_key_h)):
        cands = []
        for b in by_key_b[key]:
            for h in by_key_h[key]:
                ratio = difflib.SequenceMatcher(None, b["decl"], h["decl"]).ratio()
                cands.append((ratio, b["usr"], h["usr"], b, h))
        cands.sort(key=lambda t: (-t[0], t[1], t[2]))
        for ratio, ub, uh, b, h in cands:
            if ub in paired_b or uh in paired_h:
                continue
            if ratio < 0.5:
                continue
            paired_b.add(ub)
            paired_h.add(uh)
            notes = []
            if b["file"] != h["file"]:
                notes.append(f"moved: {b['file']} → {h['file']}")
            if b["docText"] != h["docText"]:
                notes.append("doc comment edited")
            entries.append(entry(h, "changed", changes=describe_changes(b, h), notes=notes,
                                 baseDecl=b["decl"], baseAvailability=availability_label(b["availability"]),
                                 baseFile=b["file"], baseLine=b["line"], baseUsr=b["usr"]))

    for usr, r in unmatched_b.items():
        if usr not in paired_b:
            entries.append(entry(r, "removed"))
    for usr, r in unmatched_h.items():
        if usr not in paired_h:
            entries.append(entry(r, "added"))

    # Conformance changes on extension blocks of external types are covered by
    # the per-type conformance comparison above only for types this module owns;
    # record conformances added by extension blocks to other modules' types.
    ext_conf = []
    for side, g in (("base", base), ("head", head)):
        for (module, path), protos in g.conformances.items():
            owner = next((r for r in g.symbols.values() if r["module"] == module and r["path"] == path), None)
            if owner is None:
                for p in protos:
                    ext_conf.append((side, module, path, p))
    ext_conf_b = {(m, p, c) for s, m, p, c in ext_conf if s == "base"}
    ext_conf_h = {(m, p, c) for s, m, p, c in ext_conf if s == "head"}
    conformance_entries = []
    for m, p, c in sorted(ext_conf_h - ext_conf_b):
        conformance_entries.append({"status": "added", "module": m, "type": p, "protocol": c})
    for m, p, c in sorted(ext_conf_b - ext_conf_h):
        conformance_entries.append({"status": "removed", "module": m, "type": p, "protocol": c})

    ext_blocks = {"base": base.ext_blocks, "head": head.ext_blocks}
    json.dump({
        "entries": entries,
        "externalConformances": conformance_entries,
        "extensionBlocks": ext_blocks,
        # Every symbol location, so scan_sources.py results can be matched.
        "baseLocations": sorted({(r["file"], r["line"]) for r in base.symbols.values() if r["file"]}),
        "headLocations": sorted({(r["file"], r["line"]) for r in head.symbols.values() if r["file"]}),
        "counts": {
            "base": {m: sum(1 for r in base.symbols.values() if r["module"] == m) for m in MODULES},
            "head": {m: sum(1 for r in head.symbols.values() if r["module"] == m) for m in MODULES},
        },
    }, open(args.out, "w"), indent=1, sort_keys=False)
    n = defaultdict(int)
    for e in entries:
        n[e["status"]] += 1
    print(f"symbolgraph_delta: {dict(n)}; external conformances: {len(conformance_entries)}; wrote {args.out}")


if __name__ == "__main__":
    main()
