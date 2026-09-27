#!/usr/bin/env python3
"""List every OS and C-library interface that a package's library targets use.

Inputs: the package's settings (packages/NAME.ini), the index-store dump
(indexstore.py) from a macOS debug build of an export of the package, and
the export's sources, which swift_scan.py and c_scan.py scan lexically.
Output: interfaces.json.

How a reference is found:
  - Lines the Darwin build compiled: the index store. The compiler resolved
    every reference, so the defining module is known exactly. The lexical
    `#if` evaluation then says which other platforms compile the same line.
  - Lines the Darwin build didn't compile (Linux-, Windows-, WASI-only
    code): the lexical scans. A candidate identifier counts when it is
    qualified by an OS or shim module (`Glibc.x`, `CNIOLinux.y`), named by
    a scoped import (`import func WinSDK.z`), declared by one of the
    package's shims, or named like a Darwin SDK declaration; or, failing all
    of those, when it's declared nowhere in the package, the Swift libraries
    or the package's dependencies ("unresolved": presumed to come from the
    platform's C library).
  - The same lexical classification also runs on the lines the Darwin build
    compiled and is compared with the index. That's the estimate of the
    lexical scan's accuracy on the lines nothing else checks.

Usage: extract.py --package packages/NAME.ini --root EXPORT --index index.json
                  --dump dump.json --describe describe.json --out interfaces.json
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
import darwin  # noqa: E402
import deps  # noqa: E402
import package  # noqa: E402
import platforms  # noqa: E402
import swift_scan  # noqa: E402

PLATFORMS = platforms.PLATFORMS

# The package's C shim targets (`shim-targets`): C code that exists to reach
# the OS. Their declarations are interfaces of their own, and the report
# says which OS interfaces each one wraps. The package's other C targets are
# implementations: their own functions are internal, but what they call in
# the C library counts. Set from the package file in main().
SHIM_TARGETS = set()
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
# What C code can name: macros, types, functions, variables and enumerators,
# not Objective-C's methods and properties (NSObject's `class`).
C_NAMEABLE_KINDS = sum(1 << k for k in (4, 5, 6, 7, 10, 11, 12, 13, 15))
TYPE_KINDS = sum(1 << k for k in (5, 6, 7, 8, 10, 11))
DISPATCH_TYPES = {"OS_dispatch_queue": "DispatchQueue", "OS_dispatch_group": "DispatchGroup",
                  "OS_dispatch_semaphore": "DispatchSemaphore", "OS_dispatch_source": "DispatchSource",
                  "OS_dispatch_object": "DispatchObject", "OS_dispatch_io": "DispatchIO",
                  "OS_dispatch_data": "DispatchData"}


def load_json(path):
    """A JSON file, gzipped or not."""
    if path.endswith(".gz"):
        import gzip
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    return json.load(open(path))


CXX_EXTENSIONS = {".cpp", ".cc", ".cxx", ".c++", ".C", ".mm", ".hpp", ".hh"}
CXX_KEYWORDS = set("""bool true false class namespace template typename public private protected virtual using new
delete this nullptr operator friend explicit mutable constexpr noexcept decltype thread_local alignas alignof override
final try catch throw wchar_t char8_t char16_t char32_t concept requires co_await co_yield co_return""".split())
# The C library's macros from textual headers, which the index doesn't
# record as references.
LIBC_MACROS = {"assert", "errno", "offsetof", "va_start", "va_end", "va_arg", "va_copy", "alloca", "setjmp",
               "longjmp", "static_assert"}
# Directory names that confine a C or C++ file to some platforms.
PLATFORM_DIRS = {"windows": {"Windows"}, "win32": {"Windows"},
                 "unix": {"Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD"},
                 "linux": {"Linux", "Musl", "Android"}, "android": {"Android"},
                 "darwin": {"Darwin"}, "apple": {"Darwin"}, "macos": {"Darwin"},
                 "freebsd": {"FreeBSD"}, "openbsd": {"OpenBSD"}, "wasi": {"WASI"}}


def platform_dirs(rel):
    """The platforms a file's directories confine it to, or None."""
    allowed = None
    for part in rel.split("/")[:-1]:
        plats = PLATFORM_DIRS.get(part.lower())
        if plats is not None:
            allowed = plats if allowed is None else allowed & plats
    return allowed


def relocate(index, root):
    """An index dump read for an export other than the one it was built
    from (a rerun from the results store) names the build's export in its
    absolute paths: move them to this one, so the package's own
    declarations are still its own."""
    old = (index.get("srcRoot") or "").rstrip("/")
    new = root.rstrip("/")
    if not old or old == new:
        return
    for u, d in index["decls"].items():
        if d[1] and (d[1] == old or d[1].startswith(old + "/")):
            d[1] = new + d[1][len(old):]
    for unit in index.get("units", []):
        f = unit.get("mainFile") or ""
        if f.startswith(old + "/"):
            unit["mainFile"] = new + f[len(old):]


def lowest_kind(mask):
    for k in range(63):
        if mask & (1 << k):
            return k
    return 0


def base_name(name):
    name = re.sub(r"^(getter|setter|_modify|_read|willSet|didSet|init):", "", name)
    return name.split("(")[0]


def swift_version(text):
    """(6, 2) from `Apple Swift version 6.2 (...)`, or None."""
    m = re.search(r"Swift version (\d+)\.(\d+)", text or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


def target_models(dump, pkg, imports, compiler):
    """Each target's platforms.Model: the Swift flags its manifest settings
    define, on which platforms and in which configuration; the package's
    traits; SWIFT_PACKAGE; the package file's false flags. A flag the
    manifest defines only for other targets is F here. Also the relaxed
    model, with the false flags unknown instead, and each target's C
    defines as {name: platforms}."""
    T, F, M = platforms.T, platforms.F, platforms.M
    traits = dump.get("traits") or []
    default = set(next((t.get("enabledTraits") or [] for t in traits if t["name"] == "default"), []))
    trait_names = {t["name"] for t in traits if t["name"] != "default"}
    defined, cdefs, manifest = {}, {}, set()
    for t in dump["targets"]:
        fl, bl, cd = {}, {}, {}
        for st in t.get("settings", []):
            if "define" not in st.get("kind", {}):
                continue
            name = st["kind"]["define"]["_0"].split("=")[0]
            cond = st.get("condition") or {}
            plats = platforms.condition_platforms(cond)
            if st.get("tool") == "c":
                cd.setdefault(name, set()).update(plats)
                continue
            if st.get("tool") != "swift":
                continue
            manifest.add(name)
            config = cond.get("config")
            for p in PLATFORMS:
                v = (T if config is None else M) if p in plats else F
                fl.setdefault(name, {})[p] = platforms._tri_or(fl.get(name, {}).get(p, F), v)
            b = T if "Darwin" in plats and config in (None, "debug") else F
            bl[name] = platforms._tri_or(bl.get(name, F), b)
        defined[t["name"]] = (fl, bl)
        cdefs[t["name"]] = cd
    false_flags = set(pkg["false-flags"])
    models = {}
    for t in dump["targets"]:
        fl, bl = defined[t["name"]]
        flags, build = {}, {}
        for name in manifest - set(fl):
            flags[name], build[name] = {p: F for p in PLATFORMS}, F
        for name in trait_names:
            v = T if name in default else M
            flags[name], build[name] = {p: v for p in PLATFORMS}, T if name in default else F
        flags["SWIFT_PACKAGE"], build["SWIFT_PACKAGE"] = {p: T for p in PLATFORMS}, T
        flags.update(fl)
        build.update(bl)
        relaxed = platforms.model(dict(flags), dict(build), imports, compiler)
        for name in false_flags:
            flags[name], build[name] = {p: F for p in PLATFORMS}, F
        models[t["name"]] = (platforms.model(flags, build, imports, compiler), relaxed)
    return models, cdefs, {"traits": sorted(trait_names), "defaultTraits": sorted(default),
                           "swiftDefines": sorted(manifest)}


def c_macro_values(files):
    """Per-platform values of the integer macros the package's C headers
    define (c_scan.integer_macros): {name: {platform or "build": value}},
    None where the definitions active there disagree or depend on the
    configuration."""
    raw = collections.defaultdict(list)
    for path, defines in files:
        for name, defs in c_scan.integer_macros(path, defines).items():
            raw[name].extend(defs)
    values = {}
    for name, defs in raw.items():
        v = {}
        for p in PLATFORMS:
            active = [(val, (st or {})[p][0]) for val, st, _b in defs if p in (st or {})]
            if active:
                vals = {val for val, _ in active}
                v[p] = vals.pop() if len(vals) == 1 and all(m == platforms.T for _, m in active) else None
        bvals = {val for val, _st, b in defs if b}
        if bvals:
            v["build"] = bvals.pop() if len(bvals) == 1 else None
        values[name] = v
    return values


def load_targets(dump, describe, skip):
    """Library targets and the ones skipped, from `swift package dump-package`
    and `describe`. `skip` is the package file's `skip-targets`: regular
    targets that aren't library code, such as test support."""
    types = {t["name"]: t["type"] for t in dump["targets"]}
    lib, skipped = [], collections.defaultdict(list)
    for t in describe["targets"]:
        kind = types.get(t["name"], t.get("type"))
        info = {"name": t["name"], "c99name": t.get("c99name", t["name"]), "path": t["path"],
                "language": "c" if t.get("module_type") == "ClangTarget" else "swift",
                "sources": t.get("sources", [])}
        if kind == "regular" and t["name"] not in skip:
            lib.append(info)
        else:
            skipped[skip.get(t["name"], "skipped") if kind == "regular" else kind].append(t["name"])
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
    """Simplified demangled names for Swift USRs, via swift-demangle. A
    global operator's gets the type of its first operand as its scope, which
    the simplified form drops: Dispatch's `+ infix(_:_:)` on DispatchTime
    becomes `Dispatch.DispatchTime.+ infix(_:_:)`, a member of DispatchTime."""
    usrs = sorted(usrs)
    if not usrs:
        return {}
    try:
        out = subprocess.run(["xcrun", "swift-demangle", "--simplified"], capture_output=True, text=True,
                             input="\n".join("$s" + u[2:] for u in usrs)).stdout.split("\n")
    except OSError:
        return {}
    names = dict(zip(usrs, out))
    ops = [u for u, d in names.items() if re.match(r"^[^\w(\s]", d or "")]
    if ops:
        full = subprocess.run(["xcrun", "swift-demangle"], capture_output=True, text=True,
                              input="\n".join("$s" + u[2:] for u in ops)).stdout.split("\n")
        for u, d in zip(ops, full):
            m = re.search(r"\(([A-Za-z_][\w.]*)(?:, |\))", d)
            if m:
                names[u] = m.group(1) + "." + names[u]
    return names


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
    # Clang's own headers, which the toolchain reaches both as
    # usr/lib/clang/<version>/include and through usr/lib/swift/clang; which
    # path the index records depends on the build.
    m = re.search(r"/lib/(?:swift/clang|clang/[^/]+)/include/(.+)$", path or "")
    if m:
        return m.group(1)
    m = re.search(r"/lib/(?:clang/[^/]+/include|swift)/([^/]+?)(\.swiftmodule|\.swiftinterface)?(/|$)", path or "")
    if m:
        return m.group(1) + (" (Swift overlay)" if m.group(2) else "")
    return os.path.basename(path) if path else None


class Classifier:
    """Classifies a declaration by the module and file that declare it."""

    def __init__(self, src_root, targets, dep_modules, own_modules):
        self.src_root = src_root.rstrip("/") + "/"
        self.path_to_target = sorted(((t["path"].rstrip("/") + "/", t["c99name"]) for t in targets),
                                     key=lambda x: -len(x[0]))
        self.dep_modules = dep_modules
        self.own_modules = own_modules

    def target_of(self, rel):
        for prefix, name in self.path_to_target:
            if rel.startswith(prefix):
                return name
        return None

    def module_class(self, module, path):
        if path and path.startswith(self.src_root):
            t = self.target_of(os.path.normpath(path[len(self.src_root):]))
            return ("shim" if t in SHIM_TARGETS else "own"), t
        top = (module or "").split(".")[0]
        if top in SWIFT_LIBS:
            return "swift", top
        if top in FOUNDATION:
            return "foundation", top
        if top in SYSTEM_MODULES:
            return "system", top
        if top in self.own_modules:
            return "own", top
        if top in self.dep_modules or (path and "/checkouts/" in path):
            return "dependency", top
        if not top:
            # A header the index saw only through a textual include has no
            # module; in an SDK it's still the OS's.
            if path and ".sdk/" in path:
                return "os", header_of(path)
            return "unknown", top
        return "os", top


class Lexicon:
    """What a lexical candidate is, from vocabularies of every name the index
    store saw declared plus the package's own declarations from the scans."""

    def __init__(self, index, swift_scans, c_scans, own, dep_modules):
        vocab = index["vocab"]
        # Names in module-less records (headers read textually, which an
        # index read before indexstore.py named them by place has as ""):
        # where the package's code references one, its declaration's path
        # says whether it's the SDK's, a dependency's or the package's.
        by_place = {}
        for usr, d in index["decls"].items():
            if not d[0] and usr.startswith("c:") and d[1]:
                n = c_usr_parts(usr)[1]
                # libc++ is in the SDK, but it's the C++ language's library.
                if n and "/include/c++/" in d[1]:
                    by_place.setdefault(n, "<c++>")
                elif n and ".sdk/" in d[1]:
                    by_place.setdefault(n, "<sdk>")
                elif n and "/checkouts/" in d[1]:
                    by_place.setdefault(n, "<dependency>/" + d[1].split("/checkouts/")[1].split("/")[0])
        if "" in vocab:
            vocab = dict(vocab)
            rest = {}
            for n, v in vocab[""].items():
                place = by_place.get(n)
                if place:
                    vocab.setdefault(place, {})[n] = v
                else:
                    rest[n] = v
            vocab[""] = rest
        # Library names count only when they're top-level: a member such as
        # FileDescriptor.read, or System's unavailable `Errno.EBADF` stub,
        # doesn't shadow a C function. OS names are every C declaration plus
        # top-level Swift overlay declarations.
        self.os_vocab, self.lib_vocab, self.lib_vocab_all, self.own_vocab = {}, set(), set(), set()
        self.os_c_vocab = set()   # C declarations only: what C code can name
        # The same, from named OS modules only, less ncurses: C++ code names
        # libc++'s move and find, which the index files under <sdk> with the
        # SDK's other textual headers, and ncurses has a move() too.
        self.os_c_vocab_named = set()
        for module, names in vocab.items():
            top = module.split(".")[0]
            if top.startswith("<dependency>/"):
                top = next(iter(dep_modules), top)    # a dependency's header, read textually
            elif top == "<sdk>":
                top = "Darwin"                        # an SDK header, read textually
            if top in SWIFT_LIBS or top in FOUNDATION or top in dep_modules or top in SYSTEM_MODULES or top == "<c++>":
                for n, (kinds, _langs) in names.items():
                    # Foundation's Objective-C classes are named in Swift
                    # without their prefix: NSURLSessionTask is
                    # URLSessionTask.
                    aliases = [n, n[2:]] if top in FOUNDATION and re.match(r"^NS[A-Z]", n) else [n]
                    for a in aliases:
                        self.lib_vocab_all.add(a)
                        if kinds & TOP_LEVEL_KINDS:
                            self.lib_vocab.add(a)
            elif top in own or top == "":
                self.own_vocab.update(names)
            else:
                for n, (kinds, langs) in names.items():
                    # C declarations other than fields (a field can't be
                    # named unqualified), and top-level Swift overlay
                    # declarations. An extension in an OS module names an
                    # OS type: the Dispatch overlay extends `DispatchQueue`.
                    if (langs & 1 and kinds & ~FIELD_KINDS) or kinds & (TOP_LEVEL_KINDS | 1 << 9):
                        prev = self.os_vocab.get(n)
                        self.os_vocab[n] = ((prev[0] if prev else 0) | kinds, prev[1] if prev else module)
                    if langs & 1 and kinds & C_NAMEABLE_KINDS:
                        self.os_c_vocab.add(n)
                        if module not in ("<sdk>", "") and not module.startswith("Darwin.ncurses"):
                            self.os_c_vocab_named.add(n)
        # The package's own top-level names, with the platforms that compile
        # them: a Windows-only `typealias socklen_t` doesn't shadow Glibc's.
        self.own_top = {}
        for sc in swift_scans.values():
            for name, line in sc["topLevel"]:
                ent = self.own_top.setdefault(name, {"platforms": set(), "built": False})
                ent["platforms"].update((sc["states"][line - 1] or {}).keys())
                ent["built"] = ent["built"] or sc["build"][line - 1]
        # Names the package declares at top level anywhere, whatever the
        # platform.
        self.own_top_any = set(self.own_top)
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
        # OS types, which an extension can extend.
        self.os_types = {n for n, (kinds, _m) in self.os_vocab.items() if kinds & TYPE_KINDS}
        # OS names that are Swift declarations or types, which can take
        # labels: `timespec(tv_sec:tv_nsec:)`, `dispatchPrecondition(condition:)`.
        self.os_swift_or_types = set()
        for module, names in vocab.items():
            top = module.split(".")[0]
            if top in own or top in SWIFT_LIBS or top in FOUNDATION or top in dep_modules or top in SYSTEM_MODULES:
                continue
            self.os_swift_or_types.update(n for n, (kinds, langs) in names.items() if langs & 2 or kinds & TYPE_KINDS)
        # Types the package's dependencies declare, and what else each of
        # their modules declares: inside `extension TerminalController`, TSC's
        # `write` is the class's, not Darwin's.
        self.dep_type_modules = collections.defaultdict(set)
        self.module_vocab = {}
        for module, names in vocab.items():
            top = module.split(".")[0]
            if top in dep_modules:
                self.module_vocab[module] = names
                for n, (kinds, _langs) in names.items():
                    if kinds & TYPE_KINDS:
                        self.dep_type_modules[n].add(module)
        self.module_names = set(vocab) | {m.split(".")[0] for m in vocab} | own | OS_MODULES | SWIFT_LIBS \
            | FOUNDATION | SYSTEM_MODULES | dep_modules

    def swift(self, c, scan, built, use_os_vocab=True):
        """(key, evidence, via, platforms to leave out, member) or None."""
        name, q = c["name"], c["qualifier"]
        if q is not None:
            if c.get("qualifierBound"):
                return None
            if q in OS_MODULES:
                return name, "lexical-qualified", q, (), None
            if q in SHIM_TARGETS:
                if name in self.shim_decls:
                    return name, "lexical-shim", None, (), None
                return name, "lexical-qualified", q, (), None
            return None
        if c["bound"] or name in swift_scan.KEYWORDS or name in self.module_names:
            return None
        if name in self.shim_decls:
            return name, "lexical-shim", None, (), None
        shadowed = ()
        ent = self.own_top.get(name)
        if ent is not None:
            if built:
                if ent["built"]:
                    return None
            else:
                site = set((scan["states"][c["line"] - 1] or {}).keys())
                if site <= ent["platforms"]:
                    return None
                # The package declares the name on some of the site's
                # platforms. A name the Darwin SDK also declares
                # (`socklen_t`) is the OS's on the others; any other name is
                # the package's own, used under looser conditions than it's
                # declared under.
                if name not in self.os_vocab:
                    return None
                shadowed = tuple(sorted(site & ent["platforms"]))
        if name in self.lib_vocab:
            return None
        if c["types"] and any(name in self.module_vocab.get(m, ()) for m in self.dep_type_modules.get(c["types"][0], ())):
            return None
        # A C function takes no argument labels and no trailing closure, so
        # `index(i, offsetBy: 1)` or `filter { ... }` is some Swift member,
        # not index(3) or ncurses' filter().
        if (c.get("labeled") or c.get("trailingClosure")) and name in self.os_c_vocab \
                and name not in self.os_swift_or_types:
            return None
        if use_os_vocab and name in self.os_vocab:
            return name, "lexical-darwin-name", None, shadowed, None
        # A member (of the package's type, or one it inherits from a library)
        # can be named unqualified only inside a type.
        if c["types"] and (name in self.own_vocab or name in self.lib_vocab_all):
            return None
        if name in self.own_top_any:
            return None
        # Inside an extension of an OS type (`extension siginfo_t`), a name
        # declared nowhere else is one of that type's members, such as
        # Glibc's `_sifields` field; it folds into the type.
        # (Not a type the Swift libraries declare too: `extension UInt32`
        # extends Swift's, not MacTypes'.)
        if use_os_vocab and c["types"] and c["types"][0] in self.os_types \
                and c["types"][0] not in self.own_top_any and c["types"][0] not in self.lib_vocab:
            return c["types"][0], "lexical-member", None, shadowed, name
        # The standard library's underscored internals (`_fastPath`,
        # `_typeName`) aren't all in its vocabulary; C's underscored names
        # are `_lower_case` or `_Upper` (`_get_osfhandle`, `_O_BINARY`).
        if re.match(r"^_[a-z]+[A-Z]\w*$", name):
            return None
        return name, "lexical-unresolved", None, shadowed, None

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


def nested_packages(root):
    """Directories under the export's root that hold packages of their own
    (a Package.swift below the top level), by top-level directory, with how
    many there are: `Benchmarks/`, `Fixtures/`, ..."""
    out = collections.Counter()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        if dirpath != root and "Package.swift" in filenames:
            out[os.path.relpath(dirpath, root).split(os.sep)[0] + "/"] += 1
    return dict(sorted(out.items()))


def system_dependency(dump, root):
    """How the manifest asks for swift-system, and what the build resolved
    (from the Package.resolved the build wrote), or None."""
    for dep in dump.get("dependencies", []):
        for kind, specs in dep.items():
            for spec in specs or []:
                if spec.get("identity") != "swift-system":
                    continue
                out = {"kind": kind, "url": None, "path": None, "requirement": None, "resolved": None}
                loc = spec.get("location") or {}
                if loc.get("remote"):
                    out["url"] = loc["remote"][0].get("urlString")
                if loc.get("local"):
                    out["path"] = loc["local"][0]
                if spec.get("path"):
                    out["path"] = spec["path"]
                req = spec.get("requirement") or {}
                if req.get("range"):
                    lo, hi = req["range"][0]["lowerBound"], req["range"][0]["upperBound"]
                    nxt = f"{int(lo.split('.')[0]) + 1}.0.0"
                    out["requirement"] = f"from: {lo}" if hi == nxt else f"{lo}..<{hi}"
                for k in ("exact", "revision", "branch"):
                    if req.get(k):
                        out["requirement"] = f"{k}: {req[k][0]}"
                try:
                    pins = json.load(open(os.path.join(root, "Package.resolved"))).get("pins", [])
                except (OSError, ValueError):
                    pins = []
                for pin in pins:
                    if pin.get("identity") == "swift-system":
                        st = pin.get("state", {})
                        out["resolved"] = st.get("version") or st.get("branch") or st.get("revision")
                return out
    return None


def dependency_packages(units):
    """Module -> dependency package, from the index units whose main file is
    in a checkout of the build (`.../checkouts/swift-atomics/...`)."""
    out = {}
    for u in units:
        m = re.search(r"/checkouts/([^/]+)/", u.get("mainFile") or "")
        if m and u["module"]:
            out.setdefault(u["module"].split(".")[0], m.group(1))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", required=True)
    ap.add_argument("--swift-version", default="", help="the first line of the compiler's --version")
    ap.add_argument("--sdk", help="the macOS SDK the package was built with, for __has_include")
    ap.add_argument("--root", required=True)
    ap.add_argument("--index", required=True)
    ap.add_argument("--dump", required=True)
    ap.add_argument("--describe", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--lexical", action="store_true",
                    help="no index: the lexical rules decide every line, with --vocab's names for the SDK")
    ap.add_argument("--vocab", help="for --lexical: the SDK's and Swift libraries' names (vocab.py's output)")
    ap.add_argument("--dep-reexports", help="darwin.py reexports' output for the build's dependency checkouts")
    ap.add_argument("--sdk-probe-cache", help="where to keep the SDK modules' re-export answers")
    args = ap.parse_args()

    pkg = package.load(args.package)
    SHIM_TARGETS.update(pkg["shim-targets"])
    platforms.SDK_PATH = args.sdk
    root = os.path.realpath(args.root)
    if args.lexical:
        # No build: every line is the lexical rules', and the vocabulary of
        # the SDK and the Swift libraries comes from another build's index.
        index = {"refs": [], "decls": {}, "units": [], "depGraph": None,
                 "vocab": load_json(args.vocab)["vocab"] if args.vocab else {}}
    else:
        index = load_json(args.index)
        relocate(index, root)
    describe = json.load(open(args.describe))
    dump = json.load(open(args.dump))
    targets, skipped = load_targets(dump, describe,
                                    {t: pkg["skipReasons"].get(t, "skipped") for t in pkg["skip-targets"]})
    own = {t["c99name"] for t in describe["targets"]}
    lib_names = {t["c99name"] for t in targets}
    dep_modules = {u["module"].split(".")[0] for u in index["units"] if u["module"]} - own - SYSTEM_MODULES
    dep_packages = dependency_packages(index["units"])
    cls = Classifier(root, targets, dep_modules, own)
    # canImport finds the package's own modules and every module its build
    # built, on every platform.
    built = {u["module"].split(".")[0] for u in index["units"] if u["module"]}
    compiler = swift_version(args.swift_version)
    models, cdefines, manifest_model = target_models(dump, pkg, own | built, compiler)

    # ------------------------------------------------------------ scans
    swift_scans, c_scans = {}, {}
    c_files = []
    for t in targets:
        if t["language"] != "swift":
            base = os.path.join(root, t["path"])
            rels = {os.path.normpath(os.path.join(t["path"], s)) for s in t["sources"]}
            for h in glob.glob(os.path.join(base, "**", "*.h"), recursive=True):
                rels.add(os.path.relpath(h, root))
            c_files.extend((t, rel) for rel in sorted(rels))
    c_values = c_macro_values([(os.path.join(root, rel), cdefines.get(t["name"], {})) for t, rel in c_files])
    for t in targets:
        if t["language"] == "swift":
            mdl, relaxed = models.get(t["name"], (None, None))
            for src in t["sources"]:
                rel = os.path.normpath(os.path.join(t["path"], src))
                swift_scans[rel] = swift_scan.scan_file(os.path.join(root, rel), rel, mdl,
                                                        relaxed if pkg["false-flags"] else None, pkg["false-flags"])
                swift_scans[rel]["target"] = t["c99name"]
    for t, rel in c_files:
        c_scans[rel] = c_scan.scan_c_file(os.path.join(root, rel), rel, cdefines.get(t["name"], {}), c_values)
        c_scans[rel]["target"] = t["c99name"]
    swift_scan.resolve_member_filter(list(swift_scans.values()))
    if args.lexical:
        for sc in list(swift_scans.values()) + list(c_scans.values()):
            sc["build"] = [False] * len(sc["build"])
    # A C or C++ file in a directory named for a platform (LLVM's Windows/
    # and Unix/, llbuild's and indexstore-db's copies of them) is compiled
    # only there, whatever its #if lines say; WindowsSupport.h has none. A
    # file for other platforms than Darwin isn't in the Darwin build.
    dir_excluded = {}
    for rel, sc in c_scans.items():
        allowed = platform_dirs(rel)
        if allowed is not None:
            dir_excluded[rel] = tuple(sorted(set(PLATFORMS) - allowed))
            if "Darwin" not in allowed:
                sc["build"] = [False] * len(sc["build"])
    # C++ targets: the C scanner can't see C++'s declarations (classes,
    # namespaces, members, locals), so a name it finds declared nowhere
    # isn't presumed to be the C library's there.
    cxx_targets = {t["c99name"] for t in targets
                   if any(os.path.splitext(x)[1] in CXX_EXTENSIONS for x in t.get("sources", []))}

    # A target that reaches `#error` on a platform doesn't build there, and
    # none builds on a platform the package doesn't support (`platforms`).
    unsupported = collections.defaultdict(set)
    error_sites = collections.defaultdict(list)
    for t in lib_names:
        unsupported[t].update(p for p in PLATFORMS if p not in pkg["platforms"])
    for rel, sc in swift_scans.items():
        for idx, st in sc["errors"]:
            for p, (v, _m) in st.items():
                if v == platforms.T:
                    unsupported[sc["target"]].add(p)
                    error_sites[sc["target"]].append(f"{rel}:{idx + 1} ({p})")

    lex = Lexicon(index, swift_scans, c_scans, own, dep_modules)
    if args.lexical:
        # What the index would have said: the package's C targets declare
        # these (CNIOAtomics' catmc_ functions), so they're its own.
        for sc in c_scans.values():
            lex.own_vocab.update(sc["declared"])
            lex.own_vocab.update(sc.get("localDeclared", ()))
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
    # C names a dependency's modules declare (ICU's), for the synthesized
    # USRs whose declaration the package doesn't reference directly.
    dep_c_names = set()
    for module, names in index["vocab"].items():
        top = module.split(".")[0]
        if top in dep_modules or top.startswith("<dependency>/"):
            dep_c_names.update(n for n, (_k, langs) in names.items() if langs & 1)
    # C declarations by name, to classify Swift's synthesized USRs for
    # imported C declarations (s:So10UErrorCodea), which have none of their
    # own: _FoundationICU's UErrorCode is a dependency's, not the OS's.
    c_decl_by_name = {}
    for u, d in decls.items():
        if u.startswith("c:"):
            n = c_usr_parts(u)[1]
            if n:
                c_decl_by_name.setdefault(n, d)

    source_lines = {}

    def literal(rel, line, name):
        if rel not in source_lines:
            source_lines[rel] = open(os.path.join(root, rel), encoding="utf-8", errors="replace").read().split("\n")
        text = source_lines[rel][line - 1] if 0 < line <= len(source_lines[rel]) else ""
        return re.search(r"(?<![\w$])" + re.escape(name) + r"(?![\w$])", text) is not None

    target_macros = collections.defaultdict(set)
    for sc in c_scans.values():
        target_macros[sc["target"]].update(n for n, k in sc.get("declaredKinds", {}).items() if k == "macro")

    def own_macro_on_line(rel, line):
        sc = c_scans.get(rel)
        if sc is None:
            return False
        macros = target_macros[sc["target"]]
        if rel not in source_lines:
            literal(rel, line, "_")
        text = source_lines[rel][line - 1] if 0 < line <= len(source_lines[rel]) else ""
        return any(w in macros for w in re.findall(r"[A-Za-z_]\w*", text))

    index_hits = collections.defaultdict(set)          # (file, line) -> keys, for the cross-check
    index_written = collections.defaultdict(dict)      # (file, line) -> {name written: key}
    index_hits_members = collections.defaultdict(set)  # fields and members, which the scans don't look for
    already_system = collections.defaultdict(list)
    excluded = collections.Counter()
    warnings = []
    seen = set()
    index_any = collections.defaultdict(set)          # (file, line) -> every name the index referenced there
    for usr, name, lang, kind, f, line, colm, roles in refs:
        index_any[(f, line)].add(base_name(name))
        if usr.startswith("c:"):
            index_any[(f, line)].add(c_usr_parts(usr)[1])
    for usr, name, lang, kind, f, line, colm, roles in refs:
        target = cls.target_of(f)
        if target not in lib_names:
            continue
        scan = swift_scans.get(f) or c_scans.get(f)
        if scan is None:
            warnings.append(f"index reference in a file the scans don't cover: {f}:{line}")
            continue
        if re.match(r"^c:@M@[^@]+$", usr):
            continue   # a module name, in an import (c:@M@Mod@E@X is a declaration in one)
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
            cd = c_decl_by_name.get(key)
            if cd is not None:
                cmc, cmod = cls.module_class(cd[0], cd[1])
                if cmc not in ("os", "shim") or (cmc == "shim" and cmod == target):
                    excluded[cmc if cmc != "shim" else "shim's own declaration"] += 1
                    continue
            elif key in dep_c_names:
                excluded["dependency"] += 1
                continue
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
                if not member and base_name(name) != key:
                    index_written[(f, line)][base_name(name)] = key
            continue
        # C++'s standard library ships in the SDK (usr/include/c++), but it's
        # the language's, not the OS's.
        if "/include/c++/" in (d[1] or "") or usr.startswith(("c:@N@std@", "c:@N@__1@")):
            excluded["C++ standard library"] += 1
            continue
        mc, mod = cls.module_class(d[0], d[1])
        # A name that isn't written on the line is an implicit reference:
        # through a typealias in Swift, or from a macro's expansion in C.
        # Keep what the package's own macros expand to (CNIOAtomics' MAKE(type)
        # calls atomic_load_explicit and friends); drop what an SDK macro
        # expands to (IOCTL_VM_SOCKETS_GET_LOCAL_CID's IOC_OUT).
        if not literal(f, line, c_usr_parts(usr)[1] or base_name(name)) and not literal(f, line, base_name(name)):
            if f in swift_scans or not own_macro_on_line(f, line):
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
            enum = re.search(r"@E@([A-Za-z_]\w*)@([A-Za-z_]\w*)$", usr)
            if hint == "field":
                key, member, kname = parent or base_name(name), cname, "type"
            elif enum and base_name(name) != enum.group(2) and not literal(f, line, enum.group(2)):
                # A C enumerator Swift renames into its enum, written
                # `.E2BIG` for POSIXErrorCodeE2BIG: a member of the enum.
                key, member, kname = enum.group(1), base_name(name), "type"
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
        # Where the package declares the same top-level name (NIOFS's
        # Windows stand-ins for fchmod and friends), the site means its own.
        shadow = ()
        ent = lex.own_top.get(key) if f in swift_scans and not member else None
        if ent is not None:
            shadow = tuple(sorted(ent["platforms"]))
        # A framework of the Darwin SDK (CryptoKit, Security) exists only on
        # Darwin: where the same line compiles elsewhere, the name means
        # something else there (swift-crypto's SHA256).
        if mc == "os" and "/System/Library/Frameworks/" in (d[1] or ""):
            shadow = tuple(sorted(set(shadow) | (set(PLATFORMS) - {"Darwin"})))
        ok = col.add(key, kname, scan, f, line, "index", called, member=member,
                     module=d[0] if mc == "os" else None, header=header_of(d[1]) if mc == "os" else None,
                     func=func, exclude_platforms=shadow)
        if ok:
            (index_hits_members if member else index_hits)[(f, line)].add(key)
            # The name the source wrote, when Swift renames the C one:
            # `CFDictionary` for CFDictionaryRef.
            if not member and base_name(name) != key:
                index_written[(f, line)][base_name(name)] = key

    # ------------------------------------------------ lexical candidates
    unresolved_dropped = collections.Counter()
    cross = {"swift": collections.Counter(), "c": collections.Counter()}
    misses, false_pos, un_false_pos = (collections.defaultdict(list) for _ in range(3))

    def compare(kind, rel, line, lex_keys, lex_unresolved):
        # A lexical finding of the name the source wrote stands for the key
        # the index gave it.
        written = index_written.get((rel, line), {})
        lex_keys = {written.get(k, k) for k in lex_keys}
        lex_unresolved = {written.get(k, k) for k in lex_unresolved}
        all_idx = index_hits.get((rel, line), set())
        idx = {k for k in all_idx if literal(rel, line, k) or any(v == k and literal(rel, line, w)
                                                                    for w, v in written.items())}
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
                found = [r for r in (lex.swift(c, sc, True) for c in cs) if r]
                keys = {r[0] for r in found if r[1] != "lexical-member"}
                # Scoped imports, `import class Dispatch.DispatchQueue`: the
                # same rule as on lines the Darwin build skips.
                keys |= {nm for ln, kw, module, nm in sc["imports"] if ln == line and kw != "module" and nm
                         and (module in OS_MODULES or module in SHIM_TARGETS)}
                unresolved = {r[0] for r in (lex.swift(c, sc, True, use_os_vocab=False) for c in cs)
                              if r and r[1] == "lexical-unresolved"}
                compare("swift", rel, line, keys, unresolved)
                # The member rule, measured on its own: does the index see a
                # member of the same type on the line?
                for r in found:
                    if r[1] == "lexical-member":
                        cross["swift"]["memberRule"] += 1
                        cross["swift"]["memberRuleAgree"] += r[0] in index_hits_members.get((rel, line), set())
                continue
            if index_hits.get((rel, line)):
                warnings.append(f"the index saw references on a line the #if evaluation says the Darwin "
                                f"build skips: {rel}:{line}")
            for c in cs:
                r = lex.swift(c, sc, False)
                if r and args.lexical and r[1] == "lexical-unresolved":
                    unresolved_dropped[r[0]] += 1
                    continue
                if r:
                    key, evidence, via, shadowed, member = r
                    col.add(key, "type" if member else lex.guess_kind(key, c["called"]), sc, rel, line, evidence,
                            c["called"], member=member, via=via, func=c["func"], exclude_platforms=shadowed)
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
                # In C++, where a declaration looks like a call to the C
                # scanner, the index references std::string's append, and a
                # template's dependent call (`Size(n)`) isn't resolved, the
                # index is the word except for the C library's textual
                # macros.
                seen_here = index_hits.get((rel, line), set()) | index_hits_members.get((rel, line), set())
                cxx = target in cxx_targets
                if cxx:
                    seen_here = seen_here | index_any.get((rel, line), set())
                for c in cs:
                    r = lex.c(c, target)
                    if r and c["called"] and r[0] not in seen_here and not r[0].startswith("__builtin_") \
                            and (not cxx or r[0] in LIBC_MACROS):
                        col.add(r[0], "macro", sc, rel, line, "lexical-unindexed", True)
                continue
            for c in cs:
                r = lex.c(c, target)
                if r and r[1] == "lexical-unresolved" and (args.lexical or target in cxx_targets):
                    unresolved_dropped[r[0]] += 1
                    continue
                # A C++ identifier that some SDK header also declares (a
                # parameter named `other`) is the C library's only when it
                # looks like one: called, a macro's spelling, or a _t type.
                if r and target in cxx_targets and r[1] == "lexical-darwin-name" and (
                        r[0] in CXX_KEYWORDS or r[0] not in lex.os_c_vocab_named
                        or not c["called"] and not re.fullmatch(r"_*[A-Z][A-Z0-9_]+|\w+_t|FILE|DIR", r[0])):
                    continue
                if r:
                    key, evidence, via, _ = r
                    col.add(key, lex.guess_kind(key, c["called"]), sc, rel, line, evidence, c["called"],
                            exclude_platforms=dir_excluded.get(rel, ()))

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
    # that way, for the gap estimate. Any package can do this.
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

    dependencies = deps.analyze(index, cls, lib_names, lambda m: cls.module_class(m, None)[0] == "os", FOUNDATION,
                                pkg["through"])

    # --------------------------------------------------- Darwin module
    dep_reexports = load_json(args.dep_reexports) if args.dep_reexports else {}
    darwin_out = darwin.analyze(root, swift_scans, out_interfaces, own, dep_modules, dep_reexports,
                                lambda mods: darwin.probe(mods, args.sdk_probe_cache), FOUNDATION, SWIFT_LIBS,
                                SYSTEM_MODULES)

    # A target the package doesn't support on a platform isn't news; the
    # report lists only the ones that reach `#error`.
    not_supported = set(PLATFORMS) - set(pkg["platforms"])
    out = {
        "package": pkg,
        "root": root,
        "platforms": PLATFORMS,
        "packagePlatforms": pkg["platforms"],
        "nestedPackages": nested_packages(root),
        "systemDependency": system_dependency(dump, root),
        "dependencies": dependencies,
        "model": dict(manifest_model, compiler=".".join(map(str, compiler)) if compiler else None,
                      falseFlags={f: {"files": sorted(r for r, sc in swift_scans.items() if f in sc["hiddenBy"])}
                                  for f in pkg["false-flags"]},
                      hiddenLines=sum(sc["hiddenLines"] for sc in swift_scans.values()),
                      cMacroValues={n: v for n, v in sorted(c_values.items())
                                    if any(n in sc["conditionMacros"] for sc in c_scans.values())}),
        "dependencyPackages": {m: p for m, p in sorted(dep_packages.items()) if m in dep_modules},
        "libraryTargets": [t["name"] for t in targets],
        "shimTargets": sorted(SHIM_TARGETS & lib_names),
        "skippedTargets": skipped,
        "unsupportedPlatforms": {t: sorted(v - not_supported) for t, v in sorted(unsupported.items())
                                 if v - not_supported},
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
        "darwin": darwin_out,
        "extraction": "lexical" if args.lexical else "index",
        "lexicalUnresolvedDropped": dict(unresolved_dropped.most_common()),
        "warnings": warnings,
    }
    json.dump(out, open(args.out, "w"), indent=1, default=lambda o: sorted(o) if isinstance(o, set) else str(o))
    print(f"extract: {len(out_interfaces)} interfaces, {sum(len(i['sites']) for i in out_interfaces)} sites in "
          f"{len(targets)} library targets; {len(out['alreadySystem'])} System symbols already used")


if __name__ == "__main__":
    main()
