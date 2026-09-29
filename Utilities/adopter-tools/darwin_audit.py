#!/usr/bin/env python3
"""Audit a SwiftPM package's Swift files for Darwin use, from a debug build's index store.

Usage:
  darwin_audit.py PACKAGE [--build DIR | --store DIR] [--dump FILE | --reuse] [--all-units]
                  [--reexporters A,B] [--scope Sources,Tests,...] [--files] [--refs SUBSTR]...
                  [--json OUT] [--quiet] [--libindexstore PATH]

Build the package first, in debug with tests (`swift build --build-tests`): SwiftPM writes an index
store on macOS. The store is found under PACKAGE/.build, or under --build DIR for a build with
`--scratch-path DIR`, or given with --store. indexstore.py (here) reads it into a dump in
$ADOPTER_TOOLS_TMP, which --reuse reads again; --dump reads a given one. Only PACKAGE is read: the
package, its build and its sources are never written.

Each Swift file under PACKAGE (or under --scope's top-level directories) is:
  import     it imports Darwin, in any form (`import Darwin`, `import Darwin.C`, `@_exported import
             Darwin`, `import func Darwin.fopen`), or a module that re-exports it (a package module
             with an `@_exported import Darwin`, or one named with --reexporters, such as TSCLibc),
             and isn't gap. Unmigrated.
  gap        every such import is under a `SYSTEM-GAP:` marker, and so is every Darwin name the file
             uses: a marker's text names it, or a scoped import under a marker names it (or, for a
             field, its struct), or it's declared in a submodule imported under a marker. A file
             whose imports under markers are all of another SDK module (`import struct
             MachO.load_command`) is gap too, if they account for every Darwin name it uses.
  leak       no Darwin import, but names written in it resolve to Darwin: it reaches Darwin through
             another module's re-export (Foundation's, XCTest's, a C shim's `export *`). Unmigrated.
  fields     no Darwin import, and its only Darwin names are fields of C structs it names some other
             way, such as `CInterop.Stat`'s `st_mode`, or the package's own alias of a Darwin type.
             Listed, not unmigrated.
  not built  it has Darwin imports, but the build compiled it into no unit (a target this build
             doesn't build, a fixture, a nested package), so they aren't counted.

Only imports the build compiled count: the index has a module reference on each compiled import
line, so an import under an `#if` the macOS build doesn't take (`#if FOUNDATION_FRAMEWORK`) is
listed as inactive instead.

Darwin is the Darwin module and the modules it's built from: _DarwinFoundation1-3, the C standard
library's modules and the others the SDK's module maps declare alongside them. A declaration in an
SDK C header counts when the SDK's module maps put the header in one of those, or in no module
(removefile.h), even when a package's C target includes it textually; a header of another SDK
module (Dispatch, os, ObjectiveC, MachO, SQLite3, zlib, XPC, libc++) isn't Darwin's, unless
--darwin-modules names it (`--darwin-modules MachO` counts Mach-O's structures). A name written where
a non-Darwin typealias also resolves (the package's `typealias sockaddr_storage =
Darwin.sockaddr_storage`, System's `CInterop.Stat`) is the alias's, and only names written at the
position count (not a macro's or alias's expansion).
"""

import argparse
import collections
import glob
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

DARWIN_NAME = re.compile(r"^(Darwin|_Darwin\w*|_DarwinFoundation\d*|_c_standard_library\w*|_xlocale\w*|sys_types\w*"
                         r"|_stdio|_stdlib|_string)$")
# SDK module maps whose top-level modules are all Darwin's: they declare the modules Darwin is
# built from (the C standard library's, pthread, unistd, ...).
DARWIN_MAPS = re.compile(r"^(Darwin|Darwin_\w+|DarwinFoundation\d*|c_standard_library)\.modulemap$")
SDK_HEADER = re.compile(r"^(.*?\.sdk)/usr/include/(.+)$")
SWIFT_MODULE = re.compile(r"/usr/lib/swift/(\w+)\.swiftmodule/")
FIELD_USR = re.compile(r"^c:@(?:S|SA|U|UA)@(\w+)(?:@\w+)*@FI@\w+$")
MM_TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|[A-Za-z_*][\w.]*|[{}\[\],!]|\S')
KIND_TYPEALIAS, KIND_FIELD, KIND_INSTANCE_PROPERTY = 11, 14, 19


# ---------------------------------------------------------------- the SDK's module maps

class ModuleMaps:
    """Which top-level module each header of an SDK's usr/include belongs to."""

    def __init__(self, sdk):
        self.include = os.path.join(sdk, "usr", "include")
        self.headers, self.umbrellas, self.darwin = {}, [], set()
        self.found = os.path.isdir(self.include)
        for path in sorted(glob.glob(os.path.join(self.include, "**", "*.modulemap"), recursive=True)):
            self._parse(path)
        self.umbrellas.sort(key=lambda u: -len(u[0]))

    def _parse(self, path):
        try:
            with open(path, encoding="utf-8", errors="replace") as h:
                text = h.read()
        except OSError:
            return
        text = re.sub(r"/\*.*?\*/", " ", re.sub(r"//[^\n]*", " ", text), flags=re.S)
        toks = MM_TOKEN.findall(text)
        base = os.path.relpath(os.path.dirname(path), self.include)
        whole_map = bool(DARWIN_MAPS.match(os.path.basename(path)))
        stack, pending, i = [], None, 0
        while i < len(toks):
            t = toks[i]
            if t == "extern" and i + 1 < len(toks) and toks[i + 1] == "module":
                i += 4                                  # extern module NAME "file": parsed on its own
                continue
            if t == "module" and i + 1 < len(toks):
                pending = toks[i + 1]
                if not stack and (whole_map or DARWIN_NAME.match(pending.split(".")[0])):
                    self.darwin.add(pending.split(".")[0] if pending.startswith("Darwin") else pending)
                i += 2
                continue
            if t == "{":
                stack.append(pending)
                pending = None
            elif t == "}":
                if stack:
                    stack.pop()
            elif t == "header" and i + 1 < len(toks) and toks[i + 1].startswith('"'):
                if stack and stack[0] and not (i > 0 and toks[i - 1] == "exclude"):
                    rel = os.path.normpath(os.path.join(base, toks[i + 1][1:-1]))
                    self.headers.setdefault(rel, stack[0])
                i += 2
                continue
            elif t == "umbrella" and i + 1 < len(toks) and toks[i + 1].startswith('"'):
                if stack and stack[0]:
                    rel = os.path.normpath(os.path.join(base, toks[i + 1][1:-1]))
                    self.umbrellas.append((rel.rstrip("/") + "/", stack[0]))
                i += 2
                continue
            i += 1

    def owner(self, header):
        """The top-level module that declares `header` (relative to usr/include), or None."""
        header = os.path.normpath(header)
        top = self.headers.get(header)
        if top is None:
            top = next((m for d, m in self.umbrellas if header.startswith(d)), None)
        return top

    def is_darwin(self, module):
        top = module.split(".")[0]
        return bool(DARWIN_NAME.match(top)) or top in self.darwin or module in self.darwin


_MAPS = {}


def module_maps(sdk):
    if sdk not in _MAPS:
        _MAPS[sdk] = ModuleMaps(sdk)
    return _MAPS[sdk]


EXTRA_DARWIN = set()      # --darwin-modules


def darwin_decl(module, path, maps_used):
    """Whether a declaration, by the module the store gives it and the file declaring it, is
    Darwin's."""
    m = SDK_HEADER.match(path or "")
    maps = module_maps(m.group(1)) if m else None
    if maps is not None:
        maps_used.add((m.group(1), maps.found))
    top = (module or "").split(".")[0]
    if top in EXTRA_DARWIN:
        return True
    if top and top != "<sdk>" and (maps.is_darwin(module) if maps else DARWIN_NAME.match(top)):
        return True
    if m:
        if not maps.found:
            return True                                 # no module maps to go by: the lanes' old rule
        owner = maps.owner(m.group(2))
        return owner is None or maps.is_darwin(owner) or owner.split(".")[0] in EXTRA_DARWIN
    sm = SWIFT_MODULE.search(path or "")
    return bool(sm and (DARWIN_NAME.match(sm.group(1)) or sm.group(1) in EXTRA_DARWIN))


# ---------------------------------------------------------------- the index

def find_store(root, build, store):
    if store:
        return os.path.abspath(store)
    base = os.path.abspath(build) if build else os.path.join(root, ".build")
    for cand in ("arm64-apple-macosx/debug/index/store", "x86_64-apple-macosx/debug/index/store", "debug/index/store"):
        p = os.path.join(base, cand)
        if os.path.isdir(p):
            return p
    found = [p for p in glob.glob(os.path.join(base, "**", "index", "store"), recursive=True) if os.path.isdir(p)]
    if found:
        return max(found, key=os.path.getmtime)
    common.fail(f"no index store under {base}; build the package in debug first "
                f"(swift build --build-tests), or pass --build or --store")


def libindexstore(explicit):
    if explicit:
        return explicit
    if os.environ.get("LIBINDEXSTORE"):
        return os.environ["LIBINDEXSTORE"]
    swift = subprocess.run(["xcrun", "--find", "swift"], capture_output=True, text=True).stdout.strip()
    lib = os.path.normpath(os.path.join(os.path.dirname(swift), "..", "lib", "libIndexStore.dylib"))
    if not os.path.isfile(lib):
        common.fail(f"no libIndexStore.dylib next to {swift or 'swift'}; pass --libindexstore")
    return lib


def so_type_name(usr):
    """s:So4statV... -> 'stat'; s:SC5EBADFs5Int32Vvg -> 'EBADF'"""
    m = re.match(r"s:S[oC](\d+)", usr)
    return usr[m.end():m.end() + int(m.group(1))] if m else None


def base_name(name):
    return re.sub(r"^(getter|setter|_modify|_read|willSet|didSet):", "", name).split("(")[0]


# ---------------------------------------------------------------- the audit

def audit(root, d, scope, extra_reexporters):
    maps_used = set()
    units = collections.defaultdict(set)
    for u in d["units"]:
        mf = u["mainFile"]
        if mf.startswith(root + "/"):
            units[mf[len(root) + 1:]].add(u["module"])
    decl_darwin = {}
    for usr, dec in d["decls"].items():
        decl_darwin[usr] = darwin_decl(dec[0], dec[1], maps_used)
    # C names Darwin's modules declare, for the declarations Swift synthesizes from them.
    sdk_maps = [module_maps(sdk) for sdk, found in maps_used if found]
    darwin_names = set()
    for mod, names in d["vocab"].items():
        if mod and mod != "<sdk>" and (DARWIN_NAME.match(mod.split(".")[0]) or any(m.is_darwin(mod) for m in sdk_maps)):
            darwin_names.update(n for n, (kinds, langs) in names.items() if langs & 1)

    files = common.swift_files(root, paths=scope)
    texts = common.read_sources(root, files)
    lines_of = {f: t.split("\n") for f, t in texts.items()}

    # Import lines the build compiled: each has a reference to the module it imports.
    compiled = collections.defaultdict(set)
    aliased = set()
    for usr, nm, lang, kind, f, ln, col, roles in d["refs"]:
        if usr.startswith("c:@M@"):
            compiled[f].add(ln)
        elif kind == KIND_TYPEALIAS and usr in decl_darwin and not decl_darwin[usr]:
            aliased.add((f, ln, col))

    refs = collections.defaultdict(list)      # file -> [(line, name, module, owner)]
    fields = collections.defaultdict(list)
    for usr, nm, lang, kind, f, ln, col, roles in d["refs"]:
        if not f.endswith(".swift") or (f, ln, col) in aliased:
            continue
        dec = d["decls"].get(usr)
        owner = None
        if dec is not None:
            if not decl_darwin.get(usr):
                continue
            mod = dec[0] or "<sdk>"
            bn = base_name(nm)
            if bn == "init":
                bn = so_type_name(usr) or bn
            fm = FIELD_USR.match(usr)
            is_field = kind in (KIND_FIELD, KIND_INSTANCE_PROPERTY) and fm is not None
            if fm:
                owner = fm.group(1)
        elif usr.startswith("c:@M@"):
            mod = usr[5:].split("@")[0]
            if not DARWIN_NAME.match(mod):
                continue
            bn, is_field = mod, False
        elif usr.startswith(("s:So", "s:SC")):
            # A Swift-synthesized declaration for a C one: a constant's getter, a field's accessor.
            tn = so_type_name(usr)
            bn = base_name(nm)
            if bn in ("init", "subscript"):
                bn = tn
            is_field = usr.startswith("s:So") and nm.startswith(("getter:", "setter:", "_modify:")) and tn != bn
            if not ((tn in darwin_names) if is_field else (bn in darwin_names)):
                continue
            mod, owner = "Darwin (synthesized)", (tn if is_field else None)
        else:
            continue
        line = lines_of.get(f, [])
        text = line[ln - 1] if 0 < ln <= len(line) else ""
        if not text[col - 1:].startswith(bn):
            continue          # not written here: an expansion
        (fields if is_field else refs)[f].append((ln, bn, mod, owner))

    # Package modules that re-export Darwin.
    parsed = {f: common.imports(texts[f]) for f in files if "@_exported" in texts[f]}
    reexporters = set(extra_reexporters)
    exported = [(f, im.module) for f, ims in parsed.items() for im in ims
                if im.exported and im.line in compiled.get(f, ())]
    while True:     # and the modules that re-export those
        more = {m for f, mod in exported if mod == "Darwin" or mod in reexporters for m in units.get(f, ())}
        if more <= reexporters:
            break
        reexporters |= more
    # Only a file that mentions Darwin, a re-exporter or a marker can have imports that count.
    mentions = re.compile(r"\b(?:" + "|".join(map(re.escape, sorted(reexporters | {"Darwin"}))) + r")\b|SYSTEM-GAP")
    for f in files:
        if f not in parsed and mentions.search(texts[f]):
            parsed[f] = common.imports(texts[f])

    report = {}
    for f in files:
        ims = parsed.get(f, [])
        built = f in units
        active = [im for im in ims if im.line in compiled.get(f, ())] if built else []
        inactive = [im for im in ims if (im.module == "Darwin" or im.module in reexporters) and im not in active]
        darwin = [im for im in active if im.module == "Darwin" or im.module in reexporters]
        others_under_markers = [im for im in active if im.kind and im.marker and im not in darwin]
        r, fl = refs.get(f, []), fields.get(f, [])
        text = texts[f]
        words = set()
        if "SYSTEM-GAP" in text:
            for mk in common.markers(text):
                words.update(common.IDENTIFIER.findall(mk.text))
        submodules = set()
        for im in active:
            if im.marker and (im.module == "Darwin" or im in others_under_markers):
                if im.kind and im.name:
                    words.add(im.name)
                elif im.module == "Darwin" and im.rest:
                    submodules.add("Darwin." + im.rest)

        def covered(ref):
            ln, bn, mod, owner = ref
            if bn == "Darwin":
                return bool(darwin)
            if bn in words or (owner and owner in words):
                return True
            return any(mod == s or mod.startswith(s + ".") for s in submodules)

        uncovered = [x for x in r if not covered(x)]
        if not built:
            status = "not built" if any(im.module == "Darwin" or im.module in reexporters for im in ims) else "clean"
        elif darwin:
            status = "gap" if all(im.marker for im in darwin) and not uncovered else "import"
        elif others_under_markers and r and not uncovered:
            status = "gap"
        elif r:
            status = "leak"
        elif fl:
            status = "fields"
        else:
            status = "clean"
        if status == "clean" and not inactive:
            continue
        report[f] = {
            "module": ", ".join(sorted(units.get(f, []))) or None,
            "status": status,
            "imports": [im.text for im in darwin],
            "inactiveImports": [im.text for im in inactive],
            "names": sorted({x[1] for x in r} - {"Darwin"}),
            "uncovered": sorted({x[1] for x in uncovered} - {"Darwin"}),
            "fieldNames": sorted({x[1] for x in fl}),
            "nrefs": len(r),
        }
    return report, sorted(reexporters), refs, maps_used, len(units)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("root", metavar="PACKAGE")
    ap.add_argument("--build", help="the build's scratch path (swift build --scratch-path), if not PACKAGE/.build")
    ap.add_argument("--store", help="the index store itself")
    ap.add_argument("--dump", help="read this index dump (indexstore.py's JSON) instead of the store")
    ap.add_argument("--reuse", action="store_true", help="read the last dump of PACKAGE again")
    ap.add_argument("--all-units", action="store_true", help="read every unit, not each file's newest")
    ap.add_argument("--libindexstore", help="libIndexStore.dylib (default: the one next to xcrun's swift)")
    ap.add_argument("--reexporters", default="", help="comma-separated modules that re-export Darwin")
    ap.add_argument("--darwin-modules", default="",
                    help="comma-separated SDK modules to count as Darwin's too, such as MachO")
    ap.add_argument("--scope", help="comma-separated top-level directories to audit (default: all)")
    ap.add_argument("--files", action="store_true", help="list every counted file")
    ap.add_argument("--refs", action="append", default=[], help="print the Darwin references of files matching")
    ap.add_argument("--json", help="write the per-file result here (migration_table.py reads it)")
    ap.add_argument("--quiet", action="store_true", help="don't print the reader's summary line")
    a = ap.parse_args()
    root = os.path.realpath(a.root)
    if not os.path.isdir(root):
        common.fail(f"{a.root}: no such directory")
    dump = a.dump or os.path.join(common.scratch("dumps"), common.path_key(root) + "-index.json")
    if not (a.dump or a.reuse):
        store = find_store(root, a.build, a.store)
        cmd = [sys.executable, "-B", os.path.join(common.HERE, "indexstore.py")]
        cmd += ["--all-units"] if a.all_units else []
        cmd += [libindexstore(a.libindexstore), store, root, dump]
        r = subprocess.run(cmd, stdout=subprocess.DEVNULL if a.quiet else None)
        if r.returncode:
            sys.exit(r.returncode)
    elif not os.path.isfile(dump):
        common.fail(f"no dump at {dump}; run without --reuse first")
    with open(dump) as h:
        d = json.load(h)
    if d.get("srcRoot") and d["srcRoot"].rstrip("/") != root:
        print(f"warning: the dump was read for {d['srcRoot']}, not {root}", file=sys.stderr)

    scope = [s for s in (a.scope or "").split(",") if s] or None
    EXTRA_DARWIN.update(m for m in a.darwin_modules.split(",") if m)
    report, reexporters, refs, maps_used, nunits = audit(root, d, scope, [m for m in a.reexporters.split(",") if m])
    if nunits == 0:
        print(f"warning: no unit of the index is for a file under {root}; was it built there?", file=sys.stderr)
    if any(not found for _, found in maps_used):
        print("warning: the SDK the build used isn't here, so SDK headers count as Darwin's without its "
              "module maps", file=sys.stderr)

    if a.json:
        with open(a.json, "w") as h:
            json.dump({"package": root, "reexporters": reexporters, "files": report}, h, indent=1)
    print(f"{os.path.basename(root)}: re-exporting modules: {', '.join(reexporters) or 'none'}")
    areas = collections.OrderedDict()
    for f, v in sorted(report.items()):
        areas.setdefault(f.split("/")[0] if "/" in f else ".", collections.Counter())[v["status"]] += 1
    for area, c in areas.items():
        extra = f", not built {c['not built']}" if c["not built"] else ""
        print(f"  {area}: import {c['import']}, gap {c['gap']}, leak {c['leak']}, fields-only {c['fields']}{extra}")
    if a.files:
        for f, v in sorted(report.items()):
            extra = ""
            if v["status"] in ("import", "leak", "gap"):
                extra = " " + " ".join(v["names"])
                if v["status"] == "import" and v["uncovered"] and v["imports"] and \
                        set(v["uncovered"]) != set(v["names"]):
                    extra += "  [no SYSTEM-GAP marker covers: " + " ".join(v["uncovered"]) + "]"
            elif v["status"] == "fields":
                extra = " " + " ".join(v["fieldNames"])
            if v["inactiveImports"]:
                extra += "  [inactive: " + "; ".join(v["inactiveImports"]) + "]"
            print(f"  [{v['status']}] {f}{extra}")
    for pat in a.refs:
        for f in sorted(refs):
            if pat in f:
                print(f"--- {f}")
                for ln, bn, mod, owner in sorted(set(refs[f])):
                    print(f"  {ln}: {bn}  ({mod})")


if __name__ == "__main__":
    main()
