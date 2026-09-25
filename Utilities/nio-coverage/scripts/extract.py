#!/usr/bin/env python3
"""List every OS and C-library interface that NIO's library targets use.

Inputs: the index-store dump (indexstore.py) from a macOS debug build of an
export of NIO, and the export's sources, which swift_scan.py and c_scan.py
scan lexically. Output: nio-interfaces.json.

How a reference is found:
  - Lines the Darwin build compiled: the index store. The compiler resolved
    every reference, so the defining module is known exactly. The lexical
    `#if` evaluation then says which other platforms compile the same line.
  - Lines the Darwin build didn't compile (Linux-, Windows-, WASI-only
    code): the lexical scans. A candidate identifier counts when it is
    qualified by an OS or shim module (`Glibc.x`, `CNIOLinux.y`), named by
    a scoped import (`import func WinSDK.z`), declared by a NIO shim, or
    named like a Darwin SDK declaration; or, failing all of those, when
    it's declared nowhere in NIO, the Swift libraries or NIO's dependencies
    ("unresolved": presumed to come from the platform's C library).
  - The same lexical classification also runs on the lines the Darwin build
    compiled and is compared with the index. That's the estimate of the
    lexical scan's accuracy on the lines nothing else checks.

Usage: extract.py --root EXPORT --index index.json --dump dump.json
                  --describe describe.json --out nio-interfaces.json
"""

import sys

sys.dont_write_bytecode = True  # no __pycache__, here or in api-delta's scripts

import argparse
import collections
import glob
import json
import os
import re
import subprocess

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import c_scan  # noqa: E402
import platforms  # noqa: E402
import swift_scan  # noqa: E402

PLATFORMS = platforms.PLATFORMS

# NIO's C shim targets: C code that exists to reach the OS. Their
# declarations are interfaces of their own, and the report says which OS
# interfaces each one wraps. NIO's other C targets (CNIOAtomics, CNIOLLHTTP,
# CNIOSHA1) are implementations: their own functions are NIO-internal, but
# what they call in the C library counts.
SHIM_TARGETS = {"CNIOLinux", "CNIODarwin", "CNIOWindows", "CNIOOpenBSD", "CNIOFreeBSD", "CNIOWASI", "CNIOPosix"}
# Modules whose members are OS or C-library symbols when named with a
# qualifier, as in `Glibc.SOCK_CLOEXEC`.
OS_MODULES = {"Darwin", "Glibc", "Musl", "Android", "Bionic", "WinSDK", "ucrt", "WASILibc", "wasi_pthread",
              "Dispatch", "ObjectiveC", "os"}
SWIFT_LIBS = {"Swift", "_Concurrency", "_StringProcessing", "Synchronization", "Observation", "_SwiftConcurrencyShims",
              "SwiftOnoneSupport", "RegexBuilder", "Distributed", "_RegexParser", "Cxx", "CxxStdlib", "_Volatile",
              "_Differentiation", "SwiftShims", "Combine"}
FOUNDATION = {"Foundation", "FoundationEssentials", "FoundationInternationalization", "_FoundationCShims",
              "FoundationNetworking", "FoundationXML"}
SYSTEM_MODULES = {"SystemPackage", "System", "CSystem", "SystemSockets"}

KIND_NAMES = {4: "macro", 5: "type", 6: "type", 7: "type", 8: "type", 10: "type", 11: "type", 12: "function",
              13: "variable", 14: "field", 15: "constant", 16: "function", 17: "function", 18: "function",
              19: "variable", 20: "variable", 21: "variable", 22: "function", 23: "function"}
ROLE_CALL = 1 << 5
# Top-level declaration kinds (module, macro, enum, struct, class, protocol,
# union, typealias, function, variable), as a mask over indexstore kinds.
TOP_LEVEL_KINDS = sum(1 << k for k in (1, 4, 5, 6, 7, 8, 10, 11, 12, 13))
FIELD_KINDS = 1 << 14
DISPATCH_TYPES = {"OS_dispatch_queue": "DispatchQueue", "OS_dispatch_group": "DispatchGroup",
                  "OS_dispatch_semaphore": "DispatchSemaphore", "OS_dispatch_source": "DispatchSource",
                  "OS_dispatch_object": "DispatchObject", "OS_dispatch_io": "DispatchIO",
                  "OS_dispatch_data": "DispatchData"}


def lowest_kind(mask):
    for k in range(63):
        if mask & (1 << k):
            return k
    return 0


def base_name(name):
    name = re.sub(r"^(getter|setter|_modify|_read|willSet|didSet|init):", "", name)
    return name.split("(")[0]


def load_targets(dump, describe):
    """Library targets and the ones skipped, from `swift package dump-package`
    and `describe`."""
    types = {t["name"]: t["type"] for t in dump["targets"]}
    defines = {}
    for t in dump["targets"]:
        defines[t["name"]] = [s["kind"]["define"]["_0"] for s in t.get("settings", [])
                              if s.get("tool") == "c" and "define" in s.get("kind", {})]
    lib, skipped = [], collections.defaultdict(list)
    for t in describe["targets"]:
        kind = types.get(t["name"], t.get("type"))
        info = {"name": t["name"], "c99name": t.get("c99name", t["name"]), "path": t["path"],
                "language": "c" if t.get("module_type") == "ClangTarget" else "swift",
                "sources": t.get("sources", []), "defines": defines.get(t["name"], [])}
        if kind == "regular":
            lib.append(info)
        else:
            skipped[kind].append(t["name"])
    return sorted(lib, key=lambda t: t["name"]), {k: sorted(v) for k, v in skipped.items()}


def c_usr_parts(usr):
    """For a C USR: (kind hint, name, parent). c:@S@stat@FI@st_mode ->
    ('field', 'st_mode', 'stat')."""
    body = re.sub(r"^c:(?:[^@]*\.h)?", "", usr)
    parts = [p for p in body.split("@") if p]
    if "FI" in parts:
        k = parts.index("FI")
        parent = next((parts[j] for j in range(k - 1, -1, -1)
                       if parts[j] not in ("S", "U", "SA", "UA", "T", "E")), None)
        return "field", parts[k + 1] if k + 1 < len(parts) else None, parent
    return None, parts[-1] if parts else None, None


def demangle(usrs):
    """Simplified demangled names for Swift USRs, via swift-demangle."""
    usrs = sorted(usrs)
    if not usrs:
        return {}
    try:
        out = subprocess.run(["xcrun", "swift-demangle", "--simplified"], capture_output=True, text=True,
                             input="\n".join("$s" + u[2:] for u in usrs)).stdout.split("\n")
    except OSError:
        return {}
    return dict(zip(usrs, out))


def swift_symbol_key(demangled, fallback):
    """(key, member) for a Swift OS-module symbol; members fold into their type."""
    d = re.sub(r"^(static |class )", "", demangled or "")
    d = re.sub(r"^\(extension in [^)]*\):", "", d)
    head = d.split("(")[0].split(" : ")[0].split("<")[0].strip()
    head = re.sub(r"\.(getter|setter|modify|read|unsafeAddressor|unsafeMutableAddressor|willset|didset)$", "", head)
    if not head:
        return fallback, None
    comps = head.split(".")
    if len(comps) == 1:
        return comps[0], None
    return DISPATCH_TYPES.get(comps[-2], comps[-2]), comps[-1]


def header_of(path):
    """A readable name for the file that declares an OS symbol."""
    m = re.search(r"/usr/include/(.+)$", path or "")
    if m:
        return m.group(1)
    m = re.search(r"/([^/]+)\.framework/(?:Versions/[^/]+/)?Headers/(.+)$", path or "")
    if m:
        return m.group(1) + "/" + m.group(2)
    m = re.search(r"/lib/(?:clang/[^/]+/include|swift)/([^/]+?)(\.swiftmodule|\.swiftinterface)?(/|$)", path or "")
    if m:
        return m.group(1) + (" (Swift overlay)" if m.group(2) else "")
    return os.path.basename(path) if path else None


class Classifier:
    """Classifies a declaration by the module and file that declare it."""

    def __init__(self, src_root, targets, dep_modules, all_nio_modules):
        self.src_root = src_root.rstrip("/") + "/"
        self.path_to_target = sorted(((t["path"].rstrip("/") + "/", t["c99name"]) for t in targets),
                                     key=lambda x: -len(x[0]))
        self.dep_modules = dep_modules
        self.nio_modules = all_nio_modules

    def target_of(self, rel):
        for prefix, name in self.path_to_target:
            if rel.startswith(prefix):
                return name
        return None

    def module_class(self, module, path):
        if path and path.startswith(self.src_root):
            t = self.target_of(os.path.normpath(path[len(self.src_root):]))
            return ("shim" if t in SHIM_TARGETS else "nio"), t
        top = (module or "").split(".")[0]
        if top in SWIFT_LIBS:
            return "swift", top
        if top in FOUNDATION:
            return "foundation", top
        if top in SYSTEM_MODULES:
            return "system", top
        if top in self.nio_modules:
            return "nio", top
        if top in self.dep_modules or (path and "/checkouts/" in path):
            return "dependency", top
        if not top:
            return "unknown", top
        return "os", top


class Lexicon:
    """What a lexical candidate is, from vocabularies of every name the index
    store saw declared plus NIO's own declarations from the scans."""

    def __init__(self, index, swift_scans, c_scans, all_nio, dep_modules):
        vocab = index["vocab"]
        # Library names count only when they're top-level: a member such as
        # FileDescriptor.read, or System's unavailable `Errno.EBADF` stub,
        # doesn't shadow a C function. OS names are every C declaration plus
        # top-level Swift overlay declarations.
        self.os_vocab, self.lib_vocab, self.lib_vocab_all, self.nio_vocab = {}, set(), set(), set()
        self.os_c_vocab = set()   # C declarations only: what C code can name
        for module, names in vocab.items():
            top = module.split(".")[0]
            if top in SWIFT_LIBS or top in FOUNDATION or top in dep_modules or top in SYSTEM_MODULES:
                for n, (kinds, _langs) in names.items():
                    self.lib_vocab_all.add(n)
                    if kinds & TOP_LEVEL_KINDS:
                        self.lib_vocab.add(n)
            elif top in all_nio or top == "":
                self.nio_vocab.update(names)
            else:
                for n, (kinds, langs) in names.items():
                    # C declarations other than fields (a field can't be
                    # named unqualified), and top-level Swift overlay
                    # declarations. An extension in an OS module names an
                    # OS type: the Dispatch overlay extends `DispatchQueue`.
                    if (langs & 1 and kinds & ~FIELD_KINDS) or kinds & (TOP_LEVEL_KINDS | 1 << 9):
                        prev = self.os_vocab.get(n)
                        self.os_vocab[n] = ((prev[0] if prev else 0) | kinds, prev[1] if prev else module)
                    if langs & 1 and kinds & ~FIELD_KINDS:
                        self.os_c_vocab.add(n)
        # NIO's own top-level names, with the platforms that compile them: a
        # Windows-only `typealias socklen_t` doesn't shadow Glibc's.
        self.nio_top = {}
        for sc in swift_scans.values():
            for name, line in sc["topLevel"]:
                ent = self.nio_top.setdefault(name, {"platforms": set(), "built": False})
                ent["platforms"].update((sc["states"][line - 1] or {}).keys())
                ent["built"] = ent["built"] or sc["build"][line - 1]
        # Names NIO declares at top level anywhere, whatever the platform.
        self.nio_top_any = set(self.nio_top)
        self.shim_decls = {}
        self.shim_kinds = {}
        self.target_decls = collections.defaultdict(set)
        for sc in c_scans.values():
            if sc["target"] in SHIM_TARGETS:
                for n in sc["declared"]:
                    self.shim_decls.setdefault(n, sc["target"])
                for n, k in sc.get("declaredKinds", {}).items():
                    self.shim_kinds.setdefault(n, k)
            self.target_decls[sc["target"]].update(sc["declared"])
            self.target_decls[sc["target"]].update(sc["localDeclared"])
        self.module_names = set(vocab) | {m.split(".")[0] for m in vocab} | all_nio | OS_MODULES | SWIFT_LIBS \
            | FOUNDATION | SYSTEM_MODULES | dep_modules

    def swift(self, c, scan, built, use_os_vocab=True):
        """(key, evidence, via, platforms to leave out) or None."""
        name, q = c["name"], c["qualifier"]
        if q is not None:
            if q in OS_MODULES:
                return name, "lexical-qualified", q, ()
            if q in SHIM_TARGETS:
                if name in self.shim_decls:
                    return name, "lexical-shim", None, ()
                return name, "lexical-qualified", q, ()
            return None
        if c["bound"] or name in swift_scan.KEYWORDS or name in self.module_names:
            return None
        if name in self.shim_decls:
            return name, "lexical-shim", None, ()
        shadowed = ()
        ent = self.nio_top.get(name)
        if ent is not None:
            if built:
                if ent["built"]:
                    return None
            else:
                site = set((scan["states"][c["line"] - 1] or {}).keys())
                if site <= ent["platforms"]:
                    return None
                # NIO declares the name on some of the site's platforms. A
                # name the Darwin SDK also declares (`socklen_t`) is the OS's
                # on the others; any other name is NIO's own, used under
                # looser conditions than it's declared under.
                if name not in self.os_vocab:
                    return None
                shadowed = tuple(sorted(site & ent["platforms"]))
        if name in self.lib_vocab:
            return None
        if use_os_vocab and name in self.os_vocab:
            return name, "lexical-darwin-name", None, shadowed
        # A member (of a NIO type, or one NIO inherits from a library) can be
        # named unqualified only inside a type.
        if c["types"] and (name in self.nio_vocab or name in self.lib_vocab_all):
            return None
        if name in self.nio_top_any:
            return None
        return name, "lexical-unresolved", None, shadowed

    def c(self, c, target, use_os_vocab=True):
        # C code sees only C declarations: the SDK's, its own target's, and
        # the other shims'. Swift names can't shadow anything.
        name = c["name"]
        if name in self.target_decls[target]:
            return None
        if name in self.shim_decls:
            return name, "lexical-shim", None, ()
        if use_os_vocab and name in self.os_c_vocab:
            return name, "lexical-darwin-name", None, ()
        return name, "lexical-unresolved", None, ()

    def guess_kind(self, name, called):
        """A kind for a name the index didn't resolve: the Darwin
        declaration's, the shim's, or a guess from its spelling."""
        if name in self.os_vocab:
            mask = self.os_vocab[name][0]
            for k, kind in ((12, "function"), (4, "macro"), (13, "variable"), (15, "constant"), (6, "type"),
                            (11, "type"), (5, "type"), (10, "type"), (7, "type"), (9, "type")):
                if mask & (1 << k):
                    return kind
        if name in self.shim_kinds:
            return self.shim_kinds[name]
        if called:
            return "function"
        if re.match(r"^[A-Z][A-Z0-9_]+$", name):
            return "constant"
        if re.match(r"^[A-Z]|.*_t$", name):
            return "type"
        return "unknown"


def enclosing_func(scan, line):
    best = None
    for f in scan["funcs"]:
        if f["start"] <= line <= f["end"] and (best is None or f["start"] >= best[1]):
            best = (f["name"], f["start"], f["end"])
    return best


class Collector:
    def __init__(self, unsupported):
        self.interfaces = {}
        self.unsupported = unsupported

    def interface(self, key):
        if key not in self.interfaces:
            self.interfaces[key] = {"kinds": set(), "darwinModules": set(), "headers": set(), "evidence": set(),
                                    "members": set(), "sites": [], "reachedThrough": set()}
        return self.interfaces[key]

    def add(self, key, kind, scan, rel, line, evidence, called, member=None, module=None, header=None,
            via=None, func=None, exclude_platforms=()):
        target = scan["target"]
        st = scan["states"][line - 1] if 0 < line <= len(scan["states"]) else None
        plats, maybes = {}, set()
        for p, (v, m) in (st or {}).items():
            if p in self.unsupported.get(target, ()) or p in exclude_platforms:
                continue
            plats[p] = v
            maybes.update(m)
        if not plats:
            return False
        it = self.interface(key)
        if kind:
            it["kinds"].add(kind)
        if module:
            it["darwinModules"].add(module)
        if header:
            it["headers"].add(header)
        if member:
            it["members"].add(member)
        if via:
            it["reachedThrough"].add(via)
        it["evidence"].add(evidence)
        it["sites"].append({"file": rel, "line": line, "target": target, "platforms": plats,
                            "conditions": sorted(maybes), "evidence": evidence, "called": called,
                            "member": member, "func": list(func) if func else None})
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--index", required=True)
    ap.add_argument("--dump", required=True)
    ap.add_argument("--describe", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    root = os.path.realpath(args.root)
    index = json.load(open(args.index))
    describe = json.load(open(args.describe))
    targets, skipped = load_targets(json.load(open(args.dump)), describe)
    all_nio = {t["c99name"] for t in describe["targets"]}
    lib_names = {t["c99name"] for t in targets}
    dep_modules = {u["module"].split(".")[0] for u in index["units"] if u["module"]} - all_nio - SYSTEM_MODULES
    cls = Classifier(root, targets, dep_modules, all_nio)

    # ------------------------------------------------------------ scans
    swift_scans, c_scans = {}, {}
    for t in targets:
        base = os.path.join(root, t["path"])
        if t["language"] == "swift":
            for src in t["sources"]:
                rel = os.path.normpath(os.path.join(t["path"], src))
                swift_scans[rel] = swift_scan.scan_file(os.path.join(root, rel), rel)
                swift_scans[rel]["target"] = t["c99name"]
        else:
            rels = {os.path.normpath(os.path.join(t["path"], s)) for s in t["sources"]}
            for h in glob.glob(os.path.join(base, "**", "*.h"), recursive=True):
                rels.add(os.path.relpath(h, root))
            for rel in sorted(rels):
                c_scans[rel] = c_scan.scan_c_file(os.path.join(root, rel), rel, t["defines"])
                c_scans[rel]["target"] = t["c99name"]
    swift_scan.resolve_member_filter(list(swift_scans.values()))

    # A target that reaches `#error` on a platform doesn't build there.
    unsupported = collections.defaultdict(set)
    error_sites = collections.defaultdict(list)
    for rel, sc in swift_scans.items():
        for idx, st in sc["errors"]:
            for p, (v, _m) in st.items():
                if v == platforms.T:
                    unsupported[sc["target"]].add(p)
                    error_sites[sc["target"]].append(f"{rel}:{idx + 1} ({p})")

    lex = Lexicon(index, swift_scans, c_scans, all_nio, dep_modules)
    col = Collector(unsupported)

    # ------------------------------------------------- index references
    decls = index["decls"]
    refs = [[usr, name, lang, kind, os.path.normpath(f), line, colm, roles]
            for usr, name, lang, kind, f, line, colm, roles in index["refs"]]
    swift_usrs = {r[0] for r in refs if r[0].startswith("s:") and r[0] in decls
                  and cls.module_class(*decls[r[0]][:2])[0] in ("os", "system")}
    demangled = demangle(swift_usrs)
    loc_has_c = collections.defaultdict(set)
    for usr, name, lang, kind, f, line, colm, roles in refs:
        if usr.startswith("c:"):
            loc_has_c[(f, line, colm)].add(usr)

    source_lines = {}

    def literal(rel, line, name):
        if rel not in source_lines:
            source_lines[rel] = open(os.path.join(root, rel), encoding="utf-8", errors="replace").read().split("\n")
        text = source_lines[rel][line - 1] if 0 < line <= len(source_lines[rel]) else ""
        return re.search(r"(?<![\w$])" + re.escape(name) + r"(?![\w$])", text) is not None

    target_macros = collections.defaultdict(set)
    for sc in c_scans.values():
        target_macros[sc["target"]].update(n for n, k in sc.get("declaredKinds", {}).items() if k == "macro")

    def nio_macro_on_line(rel, line):
        sc = c_scans.get(rel)
        if sc is None:
            return False
        macros = target_macros[sc["target"]]
        if rel not in source_lines:
            literal(rel, line, "_")
        text = source_lines[rel][line - 1] if 0 < line <= len(source_lines[rel]) else ""
        return any(w in macros for w in re.findall(r"[A-Za-z_]\w*", text))

    index_hits = collections.defaultdict(set)          # (file, line) -> keys, for the cross-check
    index_hits_members = collections.defaultdict(set)  # fields and members, which the scans don't look for
    already_system = collections.defaultdict(list)
    excluded = collections.Counter()
    warnings = []
    seen = set()
    for usr, name, lang, kind, f, line, colm, roles in refs:
        target = cls.target_of(f)
        if target not in lib_names:
            continue
        scan = swift_scans.get(f) or c_scans.get(f)
        if scan is None:
            warnings.append(f"index reference in a file the scans don't cover: {f}:{line}")
            continue
        if usr.startswith("c:@M@"):
            continue   # a module name, in an import
        called = bool(roles & ROLE_CALL)
        d = decls.get(usr)
        if d is None:
            # Swift's synthesized accessors for imported C declarations
            # (s:So..., s:SC...). Usually the C declaration is recorded at
            # the same spot; otherwise take the C name from the USR.
            if usr.startswith(("s:So", "s:SC")) and loc_has_c.get((f, line, colm)):
                continue
            m = re.match(r"s:S[oC](\d+)", usr)
            if not m:
                excluded["unresolved USR"] += 1
                continue
            n = int(m.group(1))
            key = usr[m.end():m.end() + n]
            member = None
            mm = re.match(r"V(\d+)", usr[m.end() + n:])
            if usr.startswith("s:So") and mm:
                member = usr[m.end() + n + mm.end():m.end() + n + mm.end() + int(mm.group(1))]
            if (f, line, key, member) in seen:
                continue
            seen.add((f, line, key, member))
            if not literal(f, line, key) and not (member and literal(f, line, member)):
                excluded["implicit"] += 1
                continue
            if col.add(key, "type" if usr.startswith("s:So") else "constant", scan, f, line, "index", called,
                       member=member):
                (index_hits_members if member else index_hits)[(f, line)].add(key)
            continue
        mc, mod = cls.module_class(d[0], d[1])
        # A name that isn't written on the line is an implicit reference:
        # through a typealias in Swift, or from a macro's expansion in C.
        # Keep what NIO's own macros expand to (CNIOAtomics' MAKE(type)
        # calls atomic_load_explicit and friends); drop what an SDK macro
        # expands to (IOCTL_VM_SOCKETS_GET_LOCAL_CID's IOC_OUT).
        if not literal(f, line, c_usr_parts(usr)[1] or base_name(name)) and not literal(f, line, base_name(name)):
            if f in swift_scans or not nio_macro_on_line(f, line):
                excluded["implicit" if f in swift_scans else "SDK macro expansion"] += 1
                continue
        if mc == "shim" and mod == target:
            excluded["shim's own declaration"] += 1
            continue
        if mc == "system":
            sym = re.sub(r"\.(getter|setter|modify|read|unsafeAddressor|unsafeMutableAddressor)$", "",
                         demangled.get(usr) or base_name(name))
            already_system[(mod, sym)].append({"file": f, "line": line, "target": target})
            continue
        if mc not in ("os", "shim"):
            excluded[mc] += 1
            continue
        kname = KIND_NAMES.get(kind, "other")
        member = None
        if usr.startswith("c:"):
            hint, cname, parent = c_usr_parts(usr)
            if hint == "field":
                key, member, kname = parent or base_name(name), cname, "type"
            else:
                # The C name, even where Swift renames it: DispatchGroup's
                # enter() is dispatch_group_enter.
                key = cname if cname and re.match(r"^[A-Za-z_]\w*$", cname) else base_name(name)
                if key != base_name(name):
                    member = None
        else:
            key, member = swift_symbol_key(demangled.get(usr), base_name(name))
            if member:
                kname = "type"
        if (f, line, key, member) in seen:
            continue
        seen.add((f, line, key, member))
        # A reserved name (`__DARWIN_ALIGN32`, `__assert_rtn`) that doesn't
        # appear on the line comes from the expansion of an SDK macro, such
        # as CMSG_DATA or assert; the macro itself is recorded.
        if re.match(r"^(__|_[A-Z])", member or key) and not literal(f, line, member or key):
            excluded["SDK macro expansion"] += 1
            continue
        func = enclosing_func(swift_scans[f], line) if f in swift_scans else None
        # Where NIO declares the same top-level name (NIOFS's Windows
        # stand-ins for fchmod and friends), the site means NIO's.
        shadow = ()
        ent = lex.nio_top.get(key) if f in swift_scans and not member else None
        if ent is not None:
            shadow = tuple(sorted(ent["platforms"]))
        ok = col.add(key, kname, scan, f, line, "index", called, member=member,
                     module=d[0] if mc == "os" else None, header=header_of(d[1]) if mc == "os" else None,
                     func=func, exclude_platforms=shadow)
        if ok:
            (index_hits_members if member else index_hits)[(f, line)].add(key)

    # ------------------------------------------------ lexical candidates
    cross = {"swift": collections.Counter(), "c": collections.Counter()}
    misses, false_pos, un_false_pos = (collections.defaultdict(list) for _ in range(3))

    def compare(kind, rel, line, lex_keys, lex_unresolved):
        all_idx = index_hits.get((rel, line), set())
        idx = {k for k in all_idx if literal(rel, line, k)}
        cross[kind]["implicit"] += len(all_idx - idx)
        members = index_hits_members.get((rel, line), set())
        cross[kind]["index"] += len(idx)
        cross[kind]["lexical"] += len(lex_keys)
        cross[kind]["agree"] += len(lex_keys & idx)
        cross[kind]["unresolvedLexical"] += len(lex_unresolved)
        cross[kind]["unresolvedAgree"] += len(lex_unresolved & idx)
        where = f"{rel}:{line}"
        for k in idx - lex_keys:
            misses[(kind, k)].append(where)
        for k in lex_keys - all_idx - members:
            false_pos[(kind, k)].append(where)
        for k in lex_unresolved - all_idx - members:
            un_false_pos[(kind, k)].append(where)

    def ranked(d):
        return [{"language": k[0], "name": k[1], "count": len(v), "examples": v[:3]}
                for k, v in sorted(d.items(), key=lambda kv: (-len(kv[1]), kv[0]))]

    for rel, sc in sorted(swift_scans.items()):
        by_line = collections.defaultdict(list)
        for c in sc["candidates"]:
            by_line[c["line"]].append(c)
        for (f, ln) in list(index_hits):
            if f == rel:
                by_line.setdefault(ln, [])
        for line, cs in sorted(by_line.items()):
            if sc["build"][line - 1]:
                keys = {r[0] for r in (lex.swift(c, sc, True) for c in cs) if r}
                unresolved = {r[0] for r in (lex.swift(c, sc, True, use_os_vocab=False) for c in cs)
                              if r and r[1] == "lexical-unresolved"}
                compare("swift", rel, line, keys, unresolved)
                continue
            if index_hits.get((rel, line)):
                warnings.append(f"the index saw references on a line the #if evaluation says the Darwin "
                                f"build skips: {rel}:{line}")
            for c in cs:
                r = lex.swift(c, sc, False)
                if r:
                    key, evidence, via, shadowed = r
                    col.add(key, lex.guess_kind(key, c["called"]), sc, rel, line, evidence, c["called"], via=via,
                            func=c["func"], exclude_platforms=shadowed)
        # Scoped imports: `import func WinSDK.inet_ntop`.
        for line, kw, module, name in sc["imports"]:
            if kw != "module" and name and (module in OS_MODULES or module in SHIM_TARGETS) \
                    and not sc["build"][line - 1]:
                kind = {"func": "function", "struct": "type", "class": "type", "typealias": "type",
                        "enum": "type", "protocol": "type"}.get(kw, "constant")
                col.add(name, kind, sc, rel, line, "lexical-import", False, via=module)

    for rel, sc in sorted(c_scans.items()):
        target = sc["target"]
        by_line = collections.defaultdict(list)
        for c in sc["candidates"]:
            by_line[c["line"]].append(c)
        for (f, ln) in list(index_hits):
            if f == rel:
                by_line.setdefault(ln, [])
        for line, cs in sorted(by_line.items()):
            if sc["build"][line - 1]:
                keys = {r[0] for r in (lex.c(c, target) for c in cs) if r}
                unresolved = {r[0] for r in (lex.c(c, target, use_os_vocab=False) for c in cs)
                              if r and r[1] == "lexical-unresolved"}
                compare("c", rel, line, keys, unresolved)
                # The index doesn't record every macro use (assert, from the
                # textual <assert.h>, is missing). Add calls it didn't see.
                seen_here = index_hits.get((rel, line), set()) | index_hits_members.get((rel, line), set())
                for c in cs:
                    r = lex.c(c, target)
                    if r and c["called"] and r[0] not in seen_here and not r[0].startswith("__builtin_"):
                        col.add(r[0], "macro", sc, rel, line, "lexical-unindexed", True)
                continue
            for c in cs:
                r = lex.c(c, target)
                if r:
                    key, evidence, via, _ = r
                    col.add(key, lex.guess_kind(key, c["called"]), sc, rel, line, evidence, c["called"])

    # ------------------------------------------------- shim definitions
    # What each shim definition wraps (the other interfaces used inside
    # it, per platform), and how many code lines it takes.
    shims = {}
    for rel, sc in c_scans.items():
        if sc["target"] not in SHIM_TARGETS:
            continue
        for d in sc["defs"]:
            end = d.get("end", d["start"])
            ent = shims.setdefault(d["name"], {"target": sc["target"], "defs": [], "wraps": {}})
            ent["defs"].append({"file": rel, "start": d["start"], "end": end, "kind": d["kind"],
                                "codeLines": sum(1 for ln in sc["codeLines"] if d["start"] <= ln <= end)})
            for key, it in col.interfaces.items():
                if key == d["name"]:
                    continue
                for s in it["sites"]:
                    if s["file"] == rel and d["start"] <= s["line"] <= end:
                        for p in s["platforms"]:
                            ent["wraps"].setdefault(p, set()).add(key)

    # ------------------------------------------------------------ output
    out_interfaces = []
    for key in sorted(col.interfaces, key=lambda k: (k.lower(), k)):
        it = col.interfaces[key]
        plats, tgts = collections.Counter(), collections.Counter()
        for s in it["sites"]:
            for p in s["platforms"]:
                plats[p] += 1
            tgts[s["target"]] += 1
        shim = shims.get(key)
        if shim is None and key in lex.shim_decls:
            shim = {"target": lex.shim_decls[key], "defs": [], "wraps": {}}
        if shim is not None:
            shim = {"target": shim["target"], "defs": shim["defs"],
                    "wraps": {p: sorted(v) for p, v in sorted(shim["wraps"].items())}}
        out_interfaces.append({
            "name": key,
            "kinds": sorted(it["kinds"]),
            "darwinModules": sorted(it["darwinModules"]),
            "headers": sorted(it["headers"]),
            "evidence": sorted(it["evidence"]),
            "members": sorted(m for m in it["members"] if m),
            "reachedThrough": sorted(it["reachedThrough"]),
            "platforms": {p: plats[p] for p in PLATFORMS if plats[p]},
            "targets": dict(sorted(tgts.items())),
            "shim": shim,
            "sites": sorted(it["sites"], key=lambda s: (s["file"], s["line"])),
        })

    # Captures: NIO reaches most syscalls through file-scope function
    # values (`private let sysRead = read`), which its wrappers then call
    # (`sysRead(fd, ...)`). Record which interfaces each wrapper reaches
    # that way, for the gap estimate.
    function_like = {k for k, it in col.interfaces.items()
                     if "function" in it["kinds"] or ("macro" in it["kinds"] and any(x["called"] for x in it["sites"]))}
    sites_by_line = collections.defaultdict(dict)   # (file, line) -> {interface: platforms}
    for key, it in col.interfaces.items():
        if key in function_like:
            for x in it["sites"]:
                sites_by_line[(x["file"], x["line"])].setdefault(key, set()).update(x["platforms"])
    capture_calls = collections.defaultdict(list)
    for rel, sc in swift_scans.items():
        tops = sorted(sc["topLevel"], key=lambda t: t[1])
        captures = {}
        for k, (name, line) in enumerate(tops):
            stop = min(tops[k + 1][1] if k + 1 < len(tops) else line + 4, line + 4)
            reached = {}
            for ln in range(line, stop):
                for key, plats in sites_by_line.get((rel, ln), {}).items():
                    reached.setdefault(key, set()).update(plats)
            if reached:
                captures.setdefault(name, {}).update(reached)
        if not captures:
            continue
        calls = collections.defaultdict(dict)
        for c in sc["candidates"]:
            if c["called"] and c["qualifier"] is None and c["name"] in captures and c["func"]:
                for key, plats in captures[c["name"]].items():
                    calls[tuple(c["func"])].setdefault(key, set()).update(plats)
        for f, reached in sorted(calls.items()):
            # The platforms are the capture's: `private let sysRead = read`
            # compiles on Darwin and Linux, whatever else uses read.
            capture_calls[rel].append({"func": list(f),
                                       "interfaces": {k: sorted(v) for k, v in sorted(reached.items())}})

    files = {}
    for rel, sc in list(swift_scans.items()) + list(c_scans.items()):
        files[rel] = {"target": sc["target"], "codeLines": sc["codeLines"],
                      "funcs": sc.get("funcs") or [{"name": d["name"], "start": d["start"],
                                                    "end": d.get("end", d["start"])} for d in sc.get("defs", [])],
                      "captureCalls": capture_calls.get(rel, [])}

    out = {
        "nioRoot": root,
        "platforms": PLATFORMS,
        "libraryTargets": [t["name"] for t in targets],
        "shimTargets": sorted(SHIM_TARGETS & lib_names),
        "skippedTargets": skipped,
        "unsupportedPlatforms": {t: sorted(v) for t, v in sorted(unsupported.items())},
        "unsupportedBecause": {t: v for t, v in sorted(error_sites.items())},
        "interfaces": out_interfaces,
        "alreadySystem": [{"module": m, "symbol": k, "sites": v} for (m, k), v in sorted(already_system.items())],
        "excludedReferences": dict(sorted(excluded.items())),
        "crosscheck": {
            "swift": dict(cross["swift"]), "c": dict(cross["c"]),
            "misses": ranked(misses), "falsePositives": ranked(false_pos),
            "unresolvedFalsePositives": ranked(un_false_pos),
        },
        "files": files,
        "warnings": warnings,
    }
    json.dump(out, open(args.out, "w"), indent=1, default=lambda o: sorted(o) if isinstance(o, set) else str(o))
    print(f"extract: {len(out_interfaces)} interfaces, {sum(len(i['sites']) for i in out_interfaces)} sites in "
          f"{len(targets)} library targets; {len(out['alreadySystem'])} System symbols already used")


if __name__ == "__main__":
    main()
