#!/usr/bin/env python3
"""The ledger of sites left: every site in the update-checkout cluster that
still uses a platform C module, with one category and a reason each, ranked
by what filling it would unblock. status.py writes it as STATUS.md's section
5, "Sites left", and as ledger.json beside its scratch; METHOD below is the
section's account of itself.

The inputs are commits only, read through status.py's git readers with lazy
fetching off: each repository of scheme-main.tsv at status.py's newest
migration branch (else its ecosystem clone's HEAD, within the sparse
checkout when the clone is partial), System at system-next (api-delta's
scanner and adopter-coverage's derive.py, as ../adopters-unix's
inventory.py reads System), and three hand-kept files at System's HEAD:
modules.ini (which modules count), exceptions.ini (exceptions, queued work,
undecided, excluded, and gaps decided by hand) and mapping.ini (concepts,
the standard library's answers, and wrap = no, a lane's verdict).
"""

import sys

sys.dont_write_bytecode = True

import collections  # noqa: E402
import configparser  # noqa: E402
import fnmatch  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "api-delta", "scripts"))
from scan_sources import strip_comments_and_strings  # noqa: E402

import check  # noqa: E402
import derive  # noqa: E402
import platforms  # noqa: E402
import status as st  # noqa: E402

PLATFORMS = platforms.PLATFORMS
MODULES_FILE = "Utilities/adopter-coverage/modules.ini"
EXCEPTIONS_FILE = "Utilities/adopter-coverage/exceptions.ini"
SCAN_SOURCES = os.path.join(HERE, "..", "..", "api-delta", "scripts", "scan_sources.py")

# The categories, in the order the section lists them, and the order a
# site's own entries decide it. `excluded` sites aren't sites: they're
# listed apart and count nowhere.
CATEGORIES = ("unexplained", "System gap", "queued", "exception", "undecided", "not System's",
              "standard library", "excluded")


# ---------------------------------------------------------------- the hand-kept files

def ini(text, name):
    cp = configparser.ConfigParser(interpolation=None, delimiters=("=",), comment_prefixes=("#",),
                                   inline_comment_prefixes=None, strict=True, empty_lines_in_values=False,
                                   default_section="__none__")
    cp.optionxform = str
    try:
        cp.read_string(text, source=name)
    except configparser.Error as e:
        raise ValueError(f"can't read {name}: {e}")
    return cp


def words(text):
    return " ".join((text or "").split())


GROUPS = ("count", "report", "not System's")


def glob_regex(pattern):
    """A module-name glob as a regular expression's alternative."""
    return "".join("[A-Za-z0-9_]*" if c == "*" else "[A-Za-z0-9_]" if c == "?" else re.escape(c) for c in pattern)


class Modules:
    """modules.ini: which imported modules count as platform C modules
    (`count`), which are listed but don't count toward the floor yet
    (`report`), and which aren't System's (`not System's`)."""

    def __init__(self, text, name=MODULES_FILE):
        cp = ini(text, name)
        extra = set(cp.sections()) - set(GROUPS)
        if extra:
            raise ValueError(f"{name}: unknown section(s) {', '.join(sorted(extra))}")
        self.names, self.patterns, self.meta = {}, {}, {}
        for g in GROUPS:
            if not cp.has_section(g):
                raise ValueError(f"{name}: no [{g}] section")
            items = dict(cp.items(g))
            unknown = set(items) - {"modules", "patterns", "note", "decided"}
            if unknown:
                raise ValueError(f"{name}: [{g}]: unknown key(s) {', '.join(sorted(unknown))}")
            self.names[g] = items.get("modules", "").split()
            self.patterns[g] = items.get("patterns", "").split()
            self.meta[g] = {"note": words(items.get("note")), "decided": words(items.get("decided"))}

    def group(self, module):
        """The module's group, or None: a name a group lists first, then a
        group's patterns."""
        for g in GROUPS:
            if module in self.names[g]:
                return g
        for g in GROUPS:
            if any(fnmatch.fnmatchcase(module, p) for p in self.patterns[g]):
                return g
        return None

    def alternatives(self, groups=GROUPS):
        """Regular-expression alternatives for the groups' modules, for
        ecosystem.import_of and git grep: the names, then the patterns."""
        return [re.escape(n) for g in groups for n in self.names[g]] + \
            [glob_regex(p) for g in groups for p in self.patterns[g]]

    def counted(self):
        """The `count` group's names, for tables."""
        return list(self.names["count"])


KINDS = ("excluded", "exception", "undecided", "queued", "gap")
ENTRY_FIELDS = ("kind", "title", "reason", "decided", "ends", "where", "work")
ENTRY_RULES = ("repositories", "paths", "modules", "names", "mapping", "platforms", "only-under")
# The flags whose builds status.py models: the site compiles only where the
# flag is true when the package model compiles it nowhere and the framework
# model somewhere.
MODELED_FLAGS = ("FOUNDATION_FRAMEWORK",)


class Entry:
    def __init__(self, id, items, name):
        self.id = id
        unknown = set(items) - set(ENTRY_FIELDS) - set(ENTRY_RULES)
        if unknown:
            raise ValueError(f"{name}: [{id}]: unknown key(s) {', '.join(sorted(unknown))}")
        for k in ENTRY_FIELDS:
            setattr(self, k, words(items.get(k)))
        if self.kind not in KINDS:
            raise ValueError(f"{name}: [{id}]: kind must be one of {', '.join(KINDS)}, not {self.kind!r}")
        if not self.title:
            raise ValueError(f"{name}: [{id}]: no title")
        if self.kind == "exception" and not self.decided:
            raise ValueError(f"{name}: [{id}]: an exception needs `decided`: who approved it, and when")
        if self.kind == "queued" and not self.where:
            raise ValueError(f"{name}: [{id}]: queued work needs `where`")
        self.rules = {}
        for k in ENTRY_RULES:
            if k not in items:
                continue
            raw = items[k]
            # mapping.ini's ids have spaces: one per line.
            vals = [x.strip() for x in raw.split("\n") if x.strip()] if k == "mapping" else raw.split()
            if vals:
                self.rules[k] = vals
        for f in self.rules.get("only-under", []):
            if f not in MODELED_FLAGS:
                raise ValueError(f"{name}: [{id}]: only-under: only {', '.join(MODELED_FLAGS)} is modeled")
        for p in self.rules.get("platforms", []):
            if p not in PLATFORMS:
                raise ValueError(f"{name}: [{id}]: no platform {p!r} (one of {', '.join(PLATFORMS)})")
        self.by_name = bool(self.rules.get("names") or self.rules.get("mapping"))
        self.matches_anything = bool(set(self.rules) - {"platforms"})

    def site_matches(self, site):
        """Whether the entry's site rules (all but names, mapping and
        platforms) match the site."""
        if not self.matches_anything:
            return False
        r = self.rules
        if "repositories" in r and not any(fnmatch.fnmatchcase(site["repository"], g) for g in r["repositories"]):
            return False
        if "paths" in r and not any(fnmatch.fnmatchcase(site["file"], g) for g in r["paths"]):
            return False
        if "modules" in r and not (site.get("module") and any(fnmatch.fnmatchcase(site["module"], g)
                                                              for g in r["modules"])):
            return False
        if "only-under" in r and not all(f in site.get("onlyUnder", ()) for f in r["only-under"]):
            return False
        return True

    def holds_site(self, site):
        """A whole-site entry holds the site when its rules match and the
        site compiles on none of the platforms the entry leaves out."""
        if self.by_name or not self.site_matches(site):
            return False
        plats = self.rules.get("platforms")
        return not plats or set(site["platforms"]) <= set(plats)

    def holds_name(self, site, name, mapping_id, plat):
        if not self.by_name or not self.site_matches(site):
            return False
        r = self.rules
        if "platforms" in r and plat not in r["platforms"]:
            return False
        return any(fnmatch.fnmatchcase(name, g) for g in r.get("names", [])) or \
            (mapping_id is not None and mapping_id in r.get("mapping", []))

    def as_json(self):
        return {"id": self.id, **{k: getattr(self, k) for k in ENTRY_FIELDS}, "rules": self.rules}


def load_entries(text, name=EXCEPTIONS_FILE):
    cp = ini(text, name)
    return [Entry(sec, dict(cp.items(sec)), name) for sec in cp.sections()]


# ---------------------------------------------------------------- System at system-next

# Names System answers under another name, or whose System answer the
# derivation doesn't see: name -> (the API, declaration paths in api-delta's
# scan, whose platforms are the name's). From ../adopters-unix's
# scripts/inventory.py (EQUIVALENTS); status.py's EQUIVALENTS, by C name,
# are read too.
EQUIVALENT_APIS = {
    "usleep": ("PThread.sleep(for:)", ["PThread.sleep"]), "sleep": ("PThread.sleep(for:)", ["PThread.sleep"]),
    "STDIN_FILENO": ("FileDescriptor.standardInput", ["FileDescriptor.standardInput"]),
    "STDOUT_FILENO": ("FileDescriptor.standardOutput", ["FileDescriptor.standardOutput"]),
    "STDERR_FILENO": ("FileDescriptor.standardError", ["FileDescriptor.standardError"]),
    "gettimeofday": ("ClockID.realtime", ["ClockID.realtime"]), "time": ("ClockID.realtime", ["ClockID.realtime"]),
    "S_ISDIR": ("FileMode.type", ["FileMode.type"]), "S_ISREG": ("FileMode.type", ["FileMode.type"]),
    "S_ISLNK": ("FileMode.type", ["FileMode.type"]),
    "mkstemp": ("FilePath.makeUniqueFile()", ["FilePath.makeUniqueFile"]),
    "mkdtemp": ("FilePath.makeUniqueDirectory()", ["FilePath.makeUniqueDirectory"]),
    "signal": ("Signal.setAction(_:)", ["Signal.setAction"]),
    "getpagesize": ("SystemConfig.value(.pageSize)", ["SystemConfig.Name.pageSize"]),
    "getdtablesize": ("SystemConfig.value(.maxOpenFiles)", ["SystemConfig.Name.maxOpenFiles"]),
    "epoll_data": ("CInterop.EPollEvent, EventPoll.Event", ["EventPoll.Event"]),
    "id_t": ("ProcessDescriptor.wait (waitid with P_PIDFD)", ["ProcessDescriptor.wait"]),
    "idtype_t": ("ProcessDescriptor.wait (waitid with P_PIDFD)", ["ProcessDescriptor.wait"]),
}
THREADS_ONLY = "_runtime(_multithreaded)"


def short_decl(d):
    """A derived declaration as `Scope.name`."""
    decl = d.get("declaration") or ""
    m = re.search(r"\b(?:func|var|let|case|typealias|struct|enum|class|protocol|actor|subscript)\s+`?([A-Za-z_]\w*)",
                  decl)
    ident = "init" if re.match(r"^\s*(?:\w+\s+)*init\b", decl) else m.group(1) if m else decl.split("(")[0].strip()
    return f"{d['scope']}.{ident}" if d.get("scope") else ident


def system_api(repo, commit, work):
    """(scan, derived) for System at `commit`: api-delta's scan of an export
    of its Sources, and derive.py's names, with each C field's platforms as
    `fieldPlatforms`. Cached by commit in `work`."""
    d = os.path.join(work, "system", commit)
    scan_path, derived_path = os.path.join(d, "scan.json"), os.path.join(d, "derived.json")
    if os.path.exists(scan_path) and os.path.exists(derived_path):
        with open(scan_path) as f:
            scan = json.load(f)
        with open(derived_path) as f:
            return scan, json.load(f)
    os.makedirs(d, exist_ok=True)
    src = tempfile.mkdtemp(prefix="system-", dir=d)
    try:
        archive = subprocess.run(["git", "-C", repo, "archive", commit, "Sources", "Package.swift"],
                                 capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", src], input=archive, check=True)
        subprocess.run([sys.executable, SCAN_SOURCES, src, scan_path + ".tmp"], capture_output=True, check=True)
        with open(scan_path + ".tmp") as f:
            scan = json.load(f)
        derived = derive.derive(src, scan)
        derived["fieldPlatforms"] = field_platforms(src, scan)
    finally:
        shutil.rmtree(src, ignore_errors=True)
    with open(derived_path, "w") as f:
        json.dump(derived, f)
    os.replace(scan_path + ".tmp", scan_path)
    return scan, derived


def field_platforms(root, scan):
    """{C field: [platforms]}: the derivation keeps fields without their
    declarations, so its doc-comment parser is run again for them, as
    inventory.py's field_platforms does."""
    out, files = collections.defaultdict(set), {}
    for d in scan["declarations"]:
        if d.get("access") in (None, "internal") or d.get("underscored"):
            continue
        if d["file"] not in files:
            try:
                with open(os.path.join(root, d["file"]), encoding="utf-8") as f:
                    files[d["file"]] = f.read().split("\n")
            except OSError:
                files[d["file"]] = []
        for kind_word, _verb, _text, body in derive.sentences(derive.doc_comment(files[d["file"]], d["line"])):
            found, _ = derive.parse(kind_word, body)
            for name, _parent, ck, _role in found or []:
                if ck == "field":
                    ps = set(d["platforms"])
                    if any(THREADS_ONLY in c for c in d.get("conditions", [])):
                        ps.discard("WASI")
                    out[name] |= ps
    return {k: sorted(v) for k, v in sorted(out.items())}


class Coverage:
    """What System at a commit answers for a C name on a platform, beside
    mapping.ini's answers outside System and the hand-kept gaps.

    WASI is WASI without threads, as inventory.py reads it: a declaration
    that only `_runtime(_multithreaded)` builds doesn't count there."""

    def __init__(self, scan, derived, mapping_entries, names_next=None):
        threads_only = {(e["file"], e["line"]) for e in scan["declarations"]
                        if any(THREADS_ONLY in c for c in e.get("conditions", []))}
        names = json.loads(json.dumps(derived.get("names", {})))
        for n in names.values():
            for decl in n.get("declarations", []):
                if (decl["file"], decl["line"]) in threads_only:
                    decl["platforms"] = [p for p in decl["platforms"] if p != "WASI"]
            full = {p for decl in n["declarations"] if not decl.get("restricted") for p in decl["platforms"]}
            part = {p for decl in n["declarations"] if decl.get("restricted") for p in decl["platforms"]} - full
            n["platforms"] = [p for p in PLATFORMS if p in full]
            n["partialPlatforms"] = [p for p in PLATFORMS if p in part]
        self.derivation = check.Derivation(dict(derived, names=names), {}, (), {})
        self.names = names
        self.fields = {k: set(v) for k, v in derived.get("fieldPlatforms", {}).items()}
        self.api = check.SystemAPI(scan)
        # Declaration paths, for EQUIVALENT_APIS.
        paths = collections.defaultdict(set)
        for e in scan["declarations"]:
            if e.get("access") in ("public", "open"):
                p = ".".join(e["scopes"] + [e["name"]])
                ps = set(e["platforms"]) - ({"WASI"} if (e["file"], e["line"]) in threads_only else set())
                paths[p] |= ps
                paths[p.split("(")[0]] |= ps
        self.equivalents = {n: (api, set().union(*(paths.get(x, set()) for x in ps)))
                            for n, (api, ps) in EQUIVALENT_APIS.items()}
        self.entries = [e for e in mapping_entries if e["hand"] != "ignore"]
        self.ignored = {s for e in mapping_entries if e["hand"] == "ignore" for s in e["symbols"]}
        self.entry_of = {}
        for e in self.entries:
            for s in e["symbols"]:
                self.entry_of.setdefault(s, e)
        self.entry_platforms = {}
        for e in self.entries:
            if e["hand"] in ("covered", "partial"):
                ps = set()
                for a in e["apis"]:
                    hits, _ = self.api.find(a["scope"], a["decl"])
                    for h in hits:
                        ps |= {p for p in h["platforms"] if not ((h["file"], h["line"]) in threads_only
                                                                 and p == "WASI")}
                self.entry_platforms[e["id"]] = ps
        # A phrase only an ANSWERED entry speaks for (status.py).
        self.names_next = names_next

    def mapping_id(self, name):
        e = self.entry_of.get(name)
        return e["id"] if e else None

    def answer(self, name, plat, field=False):
        """(kind, unit, how) for a C name on a platform: `covered` (System
        has it there), `standard library` or `not System's` (mapping.ini's
        `swift` answer, or its `wrap = no`, a lane's verdict), or `gap`
        (System lacks it there). A gap's unit is its mapping.ini entry, else
        the C name."""
        e = self.entry_of.get(name)
        unit = f"[{e['id']}]" if e else name
        if field:
            ps = self.fields.get(name, set())
            if plat in ps:
                return "covered", unit, "a Swift-named accessor"
            if e is None:
                return ("gap", unit, f"System's accessor isn't built on {plat}" if ps else
                        "System has no accessor for it")
        if e and e["hand"] in ("covered", "partial"):
            ov = e["overrides"].get(plat)
            if plat in self.entry_platforms.get(e["id"], set()) and not (ov and ov["status"] == "missing"):
                return "covered", unit, f"mapping.ini [{e['id']}] ({e['hand']}): {e['apis'][0]['text']}"
        level, found_as, decls = self.derivation.evidence(name, plat, e["same"] if e else {})
        if level in ("doc", "restricted"):
            api = short_decl(decls[0]) if decls else ""
            note = " (for some uses)" if level == "restricted" else ""
            via = f" as `{found_as}`" if found_as and found_as != name else ""
            return "covered", unit, f"{api}{via}{note}"
        for other in st.EQUIVALENTS.get(name, ()):
            lv, _, ds = self.derivation.evidence(other, plat, {})
            if lv in ("doc", "restricted"):
                return "covered", unit, f"as `{other}`" + (f": {short_decl(ds[0])}" if ds else "")
        if name in self.equivalents:
            api, ps = self.equivalents[name]
            if plat in ps:
                return "covered", unit, api
        if e and e["swift"]:
            return "standard library", unit, f"[{e['id']}]: {e['swift']}"
        if e and e["wrap"] == "no":
            return "not System's", unit, f"[{e['id']}] (lane verdict, unreviewed)"
        if level == "elsewhere":
            plats = sorted({p for d in decls for p in d["platforms"]}, key=PLATFORMS.index)
            api = short_decl(decls[0]) if decls else name
            return "gap", unit, f"{api} isn't built on {plat} (only {', '.join(plats) or 'nowhere'})"
        if name in self.equivalents and self.equivalents[name][1]:
            api, ps = self.equivalents[name]
            return "gap", unit, f"{api} isn't built on {plat}"
        if level == "impl":
            return "gap", unit, "System's implementation uses it; no public declaration names it"
        return "gap", unit, "System names it nowhere"


# ---------------------------------------------------------------- C names

# From inventory.py: the vocabulary's kinds that aren't interfaces, its
# field kind, the Darwin submodules whose names aren't C interfaces, words
# that are Swift's as often as C's, and the names that count only as calls.
VOCAB_SKIP_MODULES = re.compile(r"(availability|TargetConditionals|cdefs|appleapiopts|bounds)")
FIELD_KIND = 16384
SKIP_KINDS = {4194304, 589824, 65536, 262144, 32}
NOT_C = set("""true false nil init self Self super some any index time data value name size type mode flags
count length key id events description hash round log random select signal wait link remove rename
access open close read write send recv bind listen connect accept shutdown socket poll sync truncate
exit abort sleep kill pipe dup stat lock unlock free alarm pause fork clock times raise system
signal environ optarg optind group Duration Handle _reserved I""".split())
CALL_ONLY = set("""index time round log random select signal wait link remove rename access open close read
write send recv bind listen connect accept shutdown socket poll sync truncate exit abort sleep kill pipe dup
stat lock unlock free alarm pause fork clock times raise system""".split())
DECLARES = re.compile(r"\b(?:func|var|let|typealias|struct|class|enum|protocol|case|actor|associatedtype)\s+"
                      r"`?([A-Za-z_]\w*)")
IDENT = re.compile(r"(?<![\w$])([A-Za-z_]\w*)")
DECL_BEFORE = re.compile(r"\b(func|var|let|case|typealias|struct|class|enum|protocol|import)\s+$")
# A C header's own declarations: a function's name before its parameters,
# a macro, a typedef's name. The repository's C targets (its shims) declare
# them, not a platform module.
C_DECLARES = re.compile(r"^\s*(?:#\s*define\s+([A-Za-z_]\w*)|(?:typedef\b.*?\b([A-Za-z_]\w*)\s*;)|"
                        r"(?:(?:static\s+|inline\s+|extern\s+|const\s+|unsigned\s+|signed\s+|struct\s+)*"
                        r"(?!(?:return|else|if|while|for|switch|case|sizeof|do|goto)\b)"
                        r"[A-Za-z_]\w*[\s*]+\**([A-Za-z_]\w*)\s*\())")
SWIFT_DECLARES_ERE = (r"(func|var|let|typealias|struct|class|enum|protocol|case|actor|associatedtype)[[:space:]]+"
                      r"`?[A-Za-z_][A-Za-z0-9_]*")


def rust_windows_bindings():
    """The Win32 bindings of Rust's standard library, where rustc is
    installed, as Prototype/Win32/survey-windows-imports.py reads them."""
    try:
        sysroot = subprocess.run(["rustc", "--print", "sysroot"], capture_output=True, text=True,
                                 timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    path = os.path.join(sysroot, "lib", "rustlib", "src", "rust", "library", "std", "src", "sys", "pal",
                        "windows", "c", "windows_sys.rs")
    return path if sysroot and os.path.exists(path) else None


# The modules Swift code has on every platform, whose names an unqualified
# use means: the standard library's String and UInt, not Mach's asm macro or
# libkern's typedef. Prototype/Win32/survey-windows-imports.py's list.
SWIFT_MODULES = ("Swift", "Foundation", "FoundationEssentials", "Dispatch", "_Concurrency", "Synchronization", "XCTest",
                 "Testing", "_StringProcessing", "RegexBuilder", "Observation", "Distributed", "System")
TYPE_DECLARATION = re.compile(r"\b(?:struct|class|enum|protocol|typealias|actor|associatedtype|macro)\s+`?([A-Za-z_]\w*)")
TOP_DECLARATION = re.compile(r"^(?:@\S+\s+)*(?:public\s+|open\s+)?(?:func|var|let)\s+`?([A-Za-z_]\w*)")


def swift_declared_names():
    """The types the macOS SDK's Swift interfaces of SWIFT_MODULES declare,
    and their top-level functions and variables (`assert`, `abs`): not their
    members, since `case read` or a method `close()` would hide C's."""
    try:
        sdk = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True, text=True,
                             timeout=60).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return set()
    names = set()
    for module in SWIFT_MODULES:
        for base in (os.path.join(sdk, "usr", "lib", "swift"), os.path.join(sdk, "System", "Library", "Frameworks")):
            directory = os.path.join(base, module + ".swiftmodule")
            if not os.path.isdir(directory):
                directory = os.path.join(base, module + ".framework", "Modules", module + ".swiftmodule")
            if not os.path.isdir(directory):
                continue
            for entry in sorted(os.listdir(directory)):
                if entry.endswith(".swiftinterface") and "arm64" in entry:
                    with open(os.path.join(directory, entry), encoding="utf-8", errors="replace") as f:
                        for line in f:
                            names.update(TYPE_DECLARATION.findall(line))
                            m = TOP_DECLARATION.match(line)
                            if m:
                                names.add(m.group(1))
                    break
    return names


def windows_names(repo_root, bindings):
    """Names Windows' SDK and UCRT declare, as far as this can tell without
    them: Prototype/Win32/WindowsModel's headers and overlay, and Rust's
    Win32 bindings. Capitalized and `_`-prefixed names only, since a
    lowercase one reads as Swift."""
    names = set()
    model = os.path.join(repo_root, "Prototype", "Win32", "WindowsModel")
    for name in ("WinSDK.h", "ucrt.h", "WinSDK.swift"):
        path = os.path.join(model, name)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        names.update(re.findall(r"#define\s+(\w+)", text))
        names.update(re.findall(r"\b(\w+)\s*\(", text))
        names.update(re.findall(r"typedef\b[^;]*?\b(\w+)\s*;", text))
        names.update(re.findall(r"\}\s*(\w+)", text))
        names.update(re.findall(r"public (?:var|typealias) (\w+)", text))
    if bindings:
        with open(bindings, encoding="utf-8", errors="replace") as f:
            text = f.read()
        names.update(re.findall(r"\bfn (\w+)\s*\(", text))
        names.update(re.findall(r"\bpub (?:const|type|struct|union) (\w+)", text))
    return {n for n in names if len(n) > 1 and not n[0].islower()}


class Vocabulary:
    """The C names a lexical pass looks for, as inventory.py's vocabulary():
    the SDK's names in the counted modules' Darwin submodules (fields apart),
    System's C names, mapping.ini's symbols (but those of entries that are
    another module's: Dispatch, frameworks, SQLite), less the words Swift
    uses as often (with the C calls among them back, as calls only).
    Windows' names count on Windows only, and no name Swift's own modules
    declare counts (swift_declared_names)."""

    def __init__(self, sdk_vocab, modules, coverage, windows=(), swift=()):
        names, fields, self.any_field = set(), set(), set()
        for module, entries in (sdk_vocab or {}).items():
            top = module.split(".")[0]
            if not (modules.group(top) == "count" or top.startswith("_DarwinFoundation") or
                    top.startswith("_Builtin_")) or VOCAB_SKIP_MODULES.search(module):
                continue
            for n, (kind, _) in entries.items():
                if not n or kind in SKIP_KINDS:
                    continue
                if kind == FIELD_KIND:
                    self.any_field.add(n)
                    if "_" in n:
                        fields.add(n)
                else:
                    names.add(n)
        names |= {n for n in coverage.names if "_" in n or n.isupper()}
        names |= set(EQUIVALENT_APIS)
        others = {"dispatch", "Apple frameworks"}
        for e in coverage.entries:
            if e["wrap"] == "no" and (e["category"] in others or e["id"] in ("SQLite", "autoreleasepool",
                                                                             "Objective-C runtime")):
                continue
            names.update(s for s in e["symbols"] if re.match(r"^[A-Za-z_]\w*$", s))
        fields |= {f for f in coverage.fields if "_" in f}
        self.names = (names - NOT_C - coverage.ignored - set(swift)) | CALL_ONLY
        self.fields = fields - NOT_C
        self.windows = set(windows) - self.names - set(swift)

    def known(self, name, plat):
        return name in self.names or (plat == "Windows" and name in self.windows)

    def marker_name(self, name, coverage):
        """Whether a name a marker gives is a C interface of its own: a C
        name this vocabulary or System or mapping.ini knows, or one shaped
        like C (status.py's STRONG), but not a C struct's field, which a
        marker lists after its struct (`mach_header (magic, cputype)`)."""
        if name.endswith(" members"):
            return True
        if name in self.any_field and name not in self.names and name not in coverage.entry_of:
            return False
        return (name in self.names or name in self.windows or name in coverage.entry_of or name in coverage.names
                or bool(st.STRONG.match(name)))


def own_names(repo, commit, scope=None):
    """The names a repository declares itself: in its Swift sources, and in
    its C headers (its shims). `scope`: the directories read, or None."""
    own = set()
    swift = [f"{d}/*.swift" for d in scope] if scope else ["*.swift"]
    out = st.git(repo, "grep", "-h", "-I", "-o", "-E", "-e", SWIFT_DECLARES_ERE, commit, "--", *swift,
                 ok=(0, 1, 128))
    for line in out.splitlines():
        m = DECLARES.search(line)
        if m:
            own.add(m.group(1))
    headers = [f"{d}/*.h" for d in scope] if scope else ["*.h"]
    out = st.git(repo, "grep", "-h", "-I", "-E", "-e", r"#[[:space:]]*define|typedef|\(", commit, "--", *headers,
                 ok=(0, 1, 128))
    for line in out.splitlines():
        m = C_DECLARES.match(line)
        if m:
            own.add(next(g for g in m.groups() if g))
    return own


def qualified_re(modules):
    return re.compile(r"\b(?:" + "|".join(modules.alternatives(("count",))) + r")\.$")


def uses(code_lines, active, vocab, own, plat, qualified, shims=()):
    """{name: {line}} for the C names on the platform's active lines
    (1-based), by inventory.py's lexical_uses: not a declaration, a label,
    or a member of anything but a platform module (a C field is a member),
    a call-only name only when called, and the repository's own names
    (and its C targets' `CTarget_` names, `shims`) only when qualified.
    Import lines are left to the imports, and directives skipped."""
    out = collections.defaultdict(set)
    for ln, line in enumerate(code_lines, 1):
        if plat not in active[ln - 1] or st.IMPORT.match(line) or line.lstrip().startswith("#"):
            continue
        for m in IDENT.finditer(line):
            w = m.group(1)
            before, after = line[:m.start()], line[m.end():]
            dotted = before.endswith(".")
            is_qualified = bool(qualified.search(before))
            if DECL_BEFORE.search(before):
                continue
            if re.match(r"\s*:(?!:)", after) and not re.search(r"[?]\s*$", before) and not is_qualified:
                continue
            if (w in own or ("_" in w and w.split("_", 1)[0] in shims)) and not is_qualified:
                continue
            if w in vocab.fields and dotted:
                out[w].add(ln)
                continue
            if not vocab.known(w, plat) or (dotted and not is_qualified):
                continue
            if w in CALL_ONLY and not re.match(r"\s*\(", after):
                continue
            out[w].add(ln)
    return out


# ---------------------------------------------------------------- reading the cluster

def partial_clone(path):
    """Whether a checkout is a partial clone, whose blobs may be missing."""
    out = st.git(path, "config", "--get-regexp", r"^(remote\..*\.promisor|extensions\.partialclone)$", ok=(0, 1))
    return any(line.split()[-1] not in ("false", "") for line in out.splitlines())


def sparse_cone(path):
    """The sparse checkout's directories, or None when it has none."""
    if st.git(path, "config", "--get", "core.sparseCheckout", ok=(0, 1)).strip() != "true":
        return None
    out = st.git(path, "sparse-checkout", "list", ok=(0, 1, 128))
    return [x.strip().strip("/") for x in out.splitlines() if x.strip()] or None


def repositories(a, branches, branches_for, skip=("swift-system",)):
    """[(name, path or None, commit, where, scope)] for scheme-main.tsv's
    repositories, each at section 4's commit: its adopter checkout's newest
    migration branch, else its ecosystem clone's HEAD. `scope` is the
    pathspecs read: a partial clone is read only within its sparse checkout,
    so that no blob has to be fetched."""
    out = []
    for r in st.scheme_repos(a.ecosystem) or []:
        if r in skip:
            continue
        d = st.ADOPTER_DIRS.get(r, r)
        path = os.path.join(a.adopters, d)
        branch, tip = st.newest_branch(path, branches_for.get(d, branches))
        clone = os.path.join(a.ecosystem, r)
        if tip:
            out.append((r, path, tip, f"`{os.path.relpath(path, a.repo)}` `{branch}` @ `{st.short(tip)}`", None))
        elif os.path.exists(os.path.join(clone, ".git")) and st.commit_of(clone, "HEAD"):
            commit = st.commit_of(clone, "HEAD")
            scope = None
            where = f"`{os.path.relpath(clone, a.repo)}` @ `{st.short(commit)}`"
            if partial_clone(clone):
                scope = sparse_cone(clone)
                where += (", its sparse checkout (" + ", ".join(f"`{x}`" for x in scope) + ")" if scope else
                          ", a partial clone")
            out.append((r, clone, commit, where, scope))
        else:
            out.append((r, None, None, None, None))
    return out


IMPORT_ANY = re.compile(r"^\s*(?:@\w+(?:\([^()\n]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private|open)\s+)*"
                        r"import\s+(?:(?P<kind>typealias|struct|class|enum|protocol|let|var|func)\s+)?"
                        r"(?P<module>[A-Za-z_]\w*)(?P<rest>(?:\.\w+)*)")


def marker_imports(raw_lines, i):
    """The 1-based lines of the imports a marker on line i (0-based) sits
    over: its own line's import, when it trails one, else the imports
    right under its comment, as status.py's file_markers reads them."""
    line = raw_lines[i]
    code = line[:line.find("//")] if "//" in line else ""
    if IMPORT_ANY.match(code.rstrip() + "\n"):
        return [i + 1]
    k = i + 1
    while k < len(raw_lines) and raw_lines[k].strip() and st.COMMENT.match(raw_lines[k]) and \
            "SYSTEM-GAP" not in raw_lines[k] and not IMPORT_ANY.match(raw_lines[k]):
        k += 1
    out = []
    while k < len(raw_lines):
        s = raw_lines[k].strip()
        if IMPORT_ANY.match(s):
            out.append(k + 1)
            k += 1
            continue
        if s.startswith("//") and "SYSTEM-GAP" not in s:
            k += 1
            continue
        break
    return out


def line_states(lines, model):
    try:
        states, _, _ = platforms.swift_line_states(lines, model)
    except (ValueError, IndexError):
        states = [{p: (platforms.M, []) for p in PLATFORMS}] * len(lines)
    return states


def plat_map(state):
    return {p: v for p, (v, _) in state.items()}


def scan_repository(name, path, commit, scope, modules, vocab, qualified):
    """(sites, not-System's import counts, markers' count) for one
    repository at a commit: each import of a counted or reported module, its
    platforms and the C names it serves, and each SYSTEM-GAP marker."""
    alts = modules.alternatives()
    pathspec = [f"{d}/*.swift" for d in scope] if scope else ["*.swift"]
    files = st.tree_files(path, commit)
    nested = {os.path.dirname(f) for f in files if st.MANIFEST.match(os.path.basename(f)) and "/" in f}
    # The repository's C targets, whose `CTarget_name` shims aren't a
    # platform module's.
    shims = {f.split("/")[1] for f in files if f.startswith("Sources/C") and f.count("/") >= 2}
    candidates = st.grep_files(path, commit, "|".join(alts), pathspec, fixed=False)
    gap_specs = [f"{d}/*{e}" for d in scope for e in st.SOURCE_EXTENSIONS] if scope else \
        [f"*{e}" for e in st.SOURCE_EXTENSIONS]
    gap_files = st.grep_files(path, commit, "SYSTEM-GAP", gap_specs)
    blobs = st.read_blobs(path, [f"{commit}:{f}" for f in set(candidates) | set(gap_files)])
    own = own_names(path, commit, scope)
    sites, notsys = [], collections.Counter()
    for f in sorted(set(candidates) | set(gap_files)):
        text = blobs.get(f"{commit}:{f}")
        if text is None:
            continue
        swift = f.endswith(".swift")
        code = strip_comments_and_strings(text)[0] if swift else text
        lines = code.split("\n")
        raw = text.split("\n")
        kind = st.import_kind(f, nested)
        imports = []
        if swift:
            for i, line in enumerate(lines):
                m = IMPORT_ANY.match(line)
                if not m:
                    continue
                group = modules.group(m.group("module"))
                if group is None:
                    continue
                if group == "not System's":
                    notsys[m.group("module")] += 1
                    continue
                imports.append((i, m, group))
        markers = st.file_markers(text) if f in gap_files else []
        if not imports and not markers:
            continue
        states = line_states(lines, st.PACKAGE_MODEL) if swift else \
            [{p: (platforms.M, []) for p in PLATFORMS}] * len(lines)
        fw = None
        active = [set(s) for s in states]
        cache = {}

        def used_on(plat):
            if plat not in cache:
                cache[plat] = uses(lines, active, vocab, own, plat, qualified, shims) if swift else {}
            return cache[plat]

        def only_under(i):
            nonlocal fw
            if states[i]:
                return []
            if fw is None:
                fw = line_states(lines, st.FRAMEWORK_MODEL) if swift else states
            return ["FOUNDATION_FRAMEWORK"] if fw[i] else []

        by_line = {}
        for i, m, group in imports:
            plats = plat_map(states[i])
            ikind = "scoped" if m.group("kind") else "submodule" if m.group("rest") else "whole"
            names = {}
            if ikind == "scoped":
                n = m.group("rest").split(".")[-1]
                names[n] = {p: [] for p in plats}
            else:
                for p in plats:
                    for n, lns in used_on(p).items():
                        names.setdefault(n, {})[p] = sorted(lns)
            site = {"repository": name, "file": f, "line": i + 1, "type": "import", "kind": kind,
                    "module": m.group("module"), "group": group, "importKind": ikind,
                    "exported": "@_exported" in line_prefix(lines[i]),
                    "text": raw[i].strip() if i < len(raw) else lines[i].strip(),
                    "platforms": plats, "onlyUnder": only_under(i), "names": names, "markers": []}
            by_line[i + 1] = site
            sites.append(site)
        for line, body, imported in markers:
            over = [by_line[k] for k in marker_imports(raw, line - 1) if k in by_line]
            marker = {"line": line, "text": body, "imported": imported}
            if over:
                for s in over:
                    s["markers"].append(marker)
                continue
            i = line - 1
            plats = plat_map(states[i]) if i < len(states) else {p: platforms.M for p in PLATFORMS}
            sites.append({"repository": name, "file": f, "line": line, "type": "marker", "kind": kind,
                          "module": None, "group": "count", "importKind": None, "exported": False,
                          "text": body, "platforms": plats, "onlyUnder": only_under(i) if i < len(states)
                          else [], "names": {}, "markers": [marker]})
    return sites, notsys


def line_prefix(line):
    return line[:line.find("import")] if "import" in line else ""


# ---------------------------------------------------------------- categories

def marker_names(site, vocab, coverage):
    """The C names a site's markers give (vocab.marker_name's), with the
    phrases that name none."""
    names, phrases = [], []
    for mk in site["markers"]:
        for iface, phrase, ns in st.marker_interfaces(mk["text"], mk["imported"]):
            if iface == phrase and not ns:
                phrases.append(iface)
                continue
            names += [n for n in ns if vocab is None or vocab.marker_name(n, coverage)]
    return list(dict.fromkeys(names)), list(dict.fromkeys(phrases))


def categorize(site, entries, coverage, modules, vocab=None):
    """Sets the site's category, holders (its `holder` ids), every holder
    with its names and platforms (`holders`), and reason. A site's own
    entries decide first, in exceptions.ini's kind order (excluded,
    exception, undecided, queued, then a hand-kept gap); a reported module
    is undecided. Otherwise each C name it serves is answered on each
    platform it's used on (an entry that holds names first), and the site
    takes the first of: System gap, queued, not System's, standard library,
    unexplained."""
    site["holders"] = []
    for kind in KINDS:
        for e in entries:
            if e.kind == kind and e.holds_site(site):
                site.update(category=CATEGORY_OF[kind], holder=[e.id], reason=e.title)
                return site
    if site["group"] == "report":
        site.update(category="undecided", holder=[f"module {site['module']}"],
                    reason=f"`{site['module']}` (modules.ini [report]: Michael decides module by module)")
        return site
    if not site["platforms"]:
        site.update(category="unexplained", holder=[],
                    reason="no platform's build compiles it (a branch none takes, or a flag the model sets false)")
        return site
    names = {n: dict(ps) for n, ps in site["names"].items()}
    from_markers, phrases = marker_names(site, vocab, coverage)
    for n in from_markers:
        names.setdefault(n, {p: [] for p in site["platforms"]})
    answers = {}   # name -> {platform: (category, unit, how)}
    for n, ps in sorted(names.items()):
        field = n in coverage.fields and n not in coverage.names and n not in coverage.entry_of
        mid = coverage.mapping_id(n)
        for p in ps:
            held = next((e for e in entries if e.holds_name(site, n, mid, p)), None)
            if held:
                answers.setdefault(n, {})[p] = (CATEGORY_OF[held.kind], held.id, held.title)
            elif n.endswith(" members"):
                ok, how = coverage.names_next.covers(n) if coverage.names_next else (False, "")
                answers.setdefault(n, {})[p] = (("covered", n, how) if ok else
                                                ("System gap", n, "System has no Swift-named accessors for it"))
            else:
                kind, unit, how = coverage.answer(n, p, field=field)
                answers.setdefault(n, {})[p] = (CATEGORY_NAME.get(kind, kind), unit, how)
    site["answers"] = {n: {p: list(v) for p, v in ps.items()} for n, ps in answers.items()}
    holders = collections.OrderedDict()
    for n, ps in answers.items():
        for p, (kind, unit, how) in ps.items():
            if kind == "covered":
                continue
            h = holders.setdefault((kind, unit), {"names": set(), "platforms": set()})
            h["names"].add(n)
            h["platforms"].add(p)
    site["holders"] = [{"category": k, "holder": u, "names": sorted(v["names"]),
                        "platforms": [p for p in PLATFORMS if p in v["platforms"]]}
                       for (k, u), v in holders.items()]
    for kind in ("System gap", "queued", "not System's", "standard library"):
        hs = [h for h in site["holders"] if h["category"] == kind]
        if hs:
            shown = "; ".join(f"{h['holder']} ({', '.join(h['names'][:3])}"
                              f"{'…' if len(h['names']) > 3 else ''}: {plats(h['platforms'])})" for h in hs[:6])
            site.update(category=kind, holder=[h["holder"] for h in hs],
                        reason=shown + (f"; and {len(hs) - 6} more" if len(hs) > 6 else ""))
            return site
    site["holder"] = []
    if site["type"] == "marker" and not names:
        site.update(category="unexplained",
                    reason="the marker names no C interface" + (f" ({phrases[0]})" if phrases else ""))
        if phrases and coverage.names_next is not None:
            ok, how = coverage.names_next.covers(phrases[0])
            if ok:
                site["reason"] += f"; System covers it {how}"
        return site
    if not names:
        site.update(category="unexplained", reason="no C name it serves was found on its platforms")
    else:
        site.update(category="unexplained",
                    reason="System covers every C name it serves there: " + ", ".join(sorted(names)[:8]) +
                    ("…" if len(names) > 8 else ""))
    return site


CATEGORY_OF = {"excluded": "excluded", "exception": "exception", "undecided": "undecided", "queued": "queued",
               "gap": "System gap"}
CATEGORY_NAME = {"gap": "System gap"}


def plats(ps):
    return ", ".join(ps) if ps else "no platform"


# ---------------------------------------------------------------- ranking

def rank_gaps(sites):
    """The System gaps in the order to fill them: each next one is the gap
    that unblocks the most sites given the ones before it are filled (a site
    is unblocked when none of its gaps is left), ties going to more
    platforms, then to more sites held. When no gap would unblock a site on
    its own, the one holding the most sites goes next. Returns [(unit,
    {unblocks, holds, platforms, names, repositories, how})]."""
    left = {}
    info = collections.defaultdict(lambda: {"holds": 0, "platforms": set(), "names": set(), "repositories": set(),
                                            "how": collections.Counter()})
    for k, s in enumerate(sites):
        if s["category"] != "System gap":
            continue
        units = set()
        for h in s["holders"]:
            if h["category"] == "System gap":
                units.add(h["holder"])
                i = info[h["holder"]]
                i["platforms"].update(h["platforms"])
                i["names"].update(h["names"])
                i["repositories"].add(s["repository"])
        for u in units:
            info[u]["holds"] += 1
        for n, ps in s.get("answers", {}).items():
            for p, (kind, unit, how) in ps.items():
                if kind == "System gap":
                    info[unit]["how"][how] += 1
        if units:
            left[k] = units
    order = []
    while left:
        alone = collections.Counter(next(iter(us)) for us in left.values() if len(us) == 1)
        held = collections.Counter(u for us in left.values() for u in us)
        pick = min(held, key=lambda u: (-alone[u], -len(info[u]["platforms"]), -held[u], u))
        freed = [k for k, us in left.items() if us == {pick}]
        for k in list(left):
            left[k].discard(pick)
            if not left[k]:
                del left[k]
        i = info[pick]
        order.append((pick, {"unblocks": len(freed), "holds": i["holds"],
                             "platforms": [p for p in PLATFORMS if p in i["platforms"]],
                             "names": sorted(i["names"]), "repositories": sorted(i["repositories"]),
                             "how": [h for h, _ in i["how"].most_common(2)]}))
    return order


def floor(sites):
    """{platform: sites left there}: every site but exceptions, excluded
    sites and reported modules' sites, on each platform it compiles on
    (maybe included)."""
    out = {p: [] for p in PLATFORMS}
    for s in sites:
        if s["category"] in ("exception", "excluded") or s["group"] == "report":
            continue
        for p in s["platforms"]:
            out[p].append(s)
    return out


# ---------------------------------------------------------------- the whole ledger

def build(a, head, nxt, branches, branches_for, cache, vocab_path, sys_next_names=None):
    """The ledger, from status.py's arguments: a dict with every site, the
    rankings and what wasn't read."""
    spec = {MODULES_FILE: None, EXCEPTIONS_FILE: None, st.MAPPING: None}
    blobs = st.read_blobs(a.repo, [f"{head}:{p}" for p in spec])
    missing = [p for p in spec if f"{head}:{p}" not in blobs]
    if missing:
        return {"error": f"{', '.join(missing)} isn't in HEAD's commit"}
    modules = Modules(blobs[f"{head}:{MODULES_FILE}"])
    entries = load_entries(blobs[f"{head}:{EXCEPTIONS_FILE}"])
    os.makedirs(cache, exist_ok=True)
    mapping_path = os.path.join(cache, "ledger-mapping.ini")
    with open(mapping_path, "w", encoding="utf-8") as f:
        f.write(blobs[f"{head}:{st.MAPPING}"])
    _, mapping, problems = check.load_mapping(mapping_path)
    scan, derived = system_api(a.repo, nxt, cache)
    coverage = Coverage(scan, derived, mapping, sys_next_names)
    sdk = None
    if vocab_path and os.path.exists(vocab_path):
        with gzip.open(vocab_path, "rt", encoding="utf-8") as f:
            sdk = json.load(f)["vocab"]
    bindings = rust_windows_bindings()
    vocab = Vocabulary(sdk, modules, coverage, windows_names(a.repo, bindings), swift_declared_names())
    qualified = qualified_re(modules)
    sites, read, not_read, notsys = [], [], [], collections.Counter()
    for name, path, commit, where, scope in repositories(a, branches, branches_for):
        if path is None:
            not_read.append((name, "not cloned"))
            continue
        ss, ns = scan_repository(name, path, commit, scope, modules, vocab, qualified)
        sites += ss
        notsys += ns
        read.append({"repository": name, "commit": commit, "where": where, "scope": scope})
        if scope:
            not_read.append((name, "outside its clone's sparse checkout (" + ", ".join(scope) + "): a partial clone, "
                             "read without fetching"))
    for s in sites:
        categorize(s, entries, coverage, modules, vocab)
    gaps = rank_gaps(sites)
    held = holdings(sites)
    mapping_sites = collections.defaultdict(set)
    for k, s in enumerate(sites):
        for n in s.get("answers", {}):
            mid = coverage.mapping_id(n)
            if mid:
                mapping_sites[mid].add(k)
    return {"modules": modules, "entries": entries, "mapping": mapping, "mappingProblems": problems,
            "coverage": coverage, "sites": sites, "gaps": gaps, "held": held, "read": read, "notRead": not_read,
            "notSystems": notsys, "floor": floor(sites), "system": nxt, "bindings": bindings,
            "vocab": vocab_path if sdk else None, "mappingSites": {k: len(v) for k, v in mapping_sites.items()}}


def holdings(sites):
    """{holder: {sites, also, repositories}}: the sites whose category a
    holder decides, and those it also holds under another category."""
    held = collections.defaultdict(lambda: {"sites": 0, "also": 0, "repositories": set()})
    for s in sites:
        for h in s["holder"] or []:
            held[h]["sites"] += 1
            held[h]["repositories"].add(s["repository"])
        for h in s["holders"]:
            if h["holder"] not in (s["holder"] or []):
                held[h["holder"]]["also"] += 1
    return held


# ---------------------------------------------------------------- the report

def site_ref(s):
    return f"{s['repository']}: `{s['file']}:{s['line']}`"


def site_platforms(s):
    out = []
    for p in PLATFORMS:
        v = s["platforms"].get(p)
        if v:
            out.append(p + ("?" if v == platforms.M else ""))
    return ", ".join(out) or "none"


def floor_line(led):
    fl = led["floor"]
    holds = [p for p in PLATFORMS if not fl[p]]
    fails = [p for p in PLATFORMS if fl[p]]
    text = "**The floor** (no site left on a platform but exceptions) "
    if not fails:
        return text + "holds on every platform."
    text += ("holds on " + ", ".join(holds) + "; it doesn't on " if holds else "holds on no platform: ")
    return text + ", ".join(f"{p} ({len(fl[p])} sites left)" for p in fails) + "."


def section(w, a, led):
    """Writes STATUS.md's section 5."""
    w("# 5. Sites left")
    w("")
    if led.get("error"):
        w(f"Not computed: {led['error']}.")
        w("")
        return
    w(floor_line(led))
    w("")
    sites = led["sites"]
    counted = [s for s in sites if s["category"] != "excluded"]
    by_cat = collections.Counter(s["category"] for s in counted)
    w(f"The ledger: every site in the update-checkout cluster that still uses a platform C module, each with one "
      f"category and its reason, so that nothing left on C is lost; in full in `ledger.json` (status.sh's "
      f"`STATUS_LEDGER_JSON`). A *site* is an import of a module that `{MODULES_FILE}` counts ([count]) or lists "
      f"([report]), at its file and line, with the platforms whose build compiles it (`?`: maybe) and the C names "
      f"it serves there; or a `SYSTEM-GAP:` marker that sits over no such import (one that does is part of the "
      f"imports' reason). Every library, test and other file is read, at the commits section 4 reads, and the "
      f"swift repository too. Categories, by `{EXCEPTIONS_FILE}`'s entries first, then by each C name against "
      f"System at `{a.system_next}` @ `{st.short(led['system'])}` and `{st.MAPPING}`: "
      + ", ".join(f"{by_cat[c]} {c}" for c in CATEGORIES if c != "excluded" and by_cat[c]) +
      f"; {sum(1 for s in sites if s['category'] == 'excluded')} excluded. How each is decided is in "
      "[How this is computed](#how-this-is-computed).")
    w("")
    if led["mappingProblems"]:
        w("mapping.ini has problems (`check.sh` reports them): " + "; ".join(led["mappingProblems"][:3]) + ".")
        w("")

    # Unexplained first.
    un = [s for s in sites if s["category"] == "unexplained"]
    w("## Unexplained")
    w("")
    w("Sites that no entry and no System gap explains: the ones to look at. Either System covers every C name the "
      "site serves on its platforms (the site could move now, or the scan misses a name), or the scan found none "
      "(a type or macro it can't see, or an import nothing uses), or a marker names no C interface.")
    w("")
    if un:
        w("| Repository | File | Lines: what | Platforms | Why |")
        w("|---|---|---|---|---|")
        for ss in grouped(un):
            s = ss[0]
            w(f"| {s['repository']} | `{s['file']}` | {lines_cell(ss)} | {group_platforms(ss)} | "
              f"{st.cell(s['reason'])} |")
    else:
        w("None.")
    w("")

    # System gaps.
    w("## System gaps, by sites unblocked")
    w("")
    w("Each row is a gap in System at `system-next`: a mapping.ini entry (or a C name in none) that System lacks on "
      "the platforms given, or a gap `exceptions.ini` keeps by hand. *Unblocks*: the sites that leave this "
      "category once it's filled, given the rows above are; the order is greedy, ties going to more platforms. "
      "*Holds*: every site it's one of the gaps of.")
    w("")
    if led["gaps"]:
        w("| # | Gap | Lacks | Unblocks | Holds | Repositories | C names | System |")
        w("|---:|---|---|---:|---:|---|---|---|")
        entry = {e.id: e for e in led["entries"]}
        for k, (unit, g) in enumerate(led["gaps"], 1):
            label = f"{unit}: {entry[unit].title}" if unit in entry else unit
            names = ", ".join(f"`{n}`" for n in g["names"][:6]) + ("…" if len(g["names"]) > 6 else "")
            how = "kept by hand (`exceptions.ini`)" if unit in entry else (g["how"] or [""])[0]
            how = how if len(how) <= 110 else how[:110].rsplit(" ", 1)[0] + " …"
            w(f"| {k} | {st.cell(label)} | {', '.join(g['platforms'])} | {g['unblocks']} | {g['holds']} | "
              f"{', '.join(g['repositories'])} | {names} | {st.cell(how)} |")
    else:
        w("None.")
    w("")

    def entry_table(kind, title, intro, cols):
        es = [e for e in led["entries"] if e.kind == kind]
        w(f"## {title}")
        w("")
        w(intro)
        w("")
        if not es:
            w("None.")
            w("")
            return
        w("| Entry | Sites | " + " | ".join(c for c, _ in cols) + " |")
        w("|---|---:|" + "---|" * len(cols))
        ranked = sorted(es, key=lambda e: (-led["held"][e.id]["sites"], e.id))
        for e in ranked:
            h = led["held"][e.id]
            also = f" (+{h['also']})" if h["also"] else ""
            w(f"| {e.id}: {st.cell(e.title)} | {h['sites']}{also} | " +
              " | ".join(st.cell(f(e, h)) for _, f in cols) + " |")
        w("")

    def repos(_e, h):
        return ", ".join(sorted(h["repositories"])) or "—"

    entry_table("queued", "Queued work", "System or adopter work already identified, with where; ranked by the sites "
                "each holds (*+n*: sites it also holds whose category is another).",
                [("Work", lambda e, h: e.work or "—"), ("Where", lambda e, h: e.where), ("Ends", lambda e, h: e.ends or "—"),
                 ("Repositories", repos)])
    entry_table("exception", "Exceptions", "Michael's explicit list: sites approved to stay on C.",
                [("Reason", lambda e, h: e.reason), ("Approved", lambda e, h: e.decided),
                 ("Ends", lambda e, h: e.ends or "—"), ("Repositories", repos)])
    undecided = [s for s in sites if s["category"] == "undecided"]
    entry_table("undecided", "Undecided", "Sites whose status is Michael's to decide: the entries below, and every import "
                "of a module modules.ini lists under [report], which doesn't count toward the floor yet.",
                [("Reason", lambda e, h: e.reason), ("Decided", lambda e, h: e.decided or "—"), ("Repositories", repos)])
    rep = collections.Counter(s["module"] for s in undecided if s["group"] == "report")
    if rep:
        w("Reported modules (modules.ini [report]), sites by module: " +
          ", ".join(f"`{m}` {n}" for m, n in rep.most_common()) + ".")
        w("")

    # mapping.ini's verdicts.
    w("## Not System's: mapping.ini's lane verdicts, unreviewed")
    w("")
    w("mapping.ini's 14 `wrap = no` entries were written by lanes and never reviewed by Michael: lane proposals, not "
      "decisions. Each is listed with the sites it holds; the Mach-O and ar.h ones are System gaps now "
      "(`exceptions.ini` E3).")
    w("")
    gap_mapping = {m for e in led["entries"] if e.kind == "gap" for m in e.rules.get("mapping", [])}
    w("| mapping.ini entry | Category | Sites | Symbols |")
    w("|---|---|---:|---|")
    for e in led["mapping"]:
        if e["wrap"] != "no":
            continue
        now = "System gap (E3)" if e["id"] in gap_mapping else "not System's (lane verdict, unreviewed)"
        w(f"| [{st.cell(e['id'])}] | {now} | {led['mappingSites'].get(e['id'], 0)} | " +
          ", ".join(f"`{x}`" for x in e["symbols"][:6]) + ("…" if len(e["symbols"]) > 6 else "") + " |")
    w("")
    if led["notSystems"]:
        w("Imports of the modules modules.ini lists as not System's (reviewed by Michael, 2026-10-05: libraries, not OS "
          "interfaces) aren't sites: " + ", ".join(f"`{m}` {n}" for m, n in led["notSystems"].most_common()) + ".")
        w("")

    std = [s for s in sites if s["category"] == "standard library"]
    w("## Standard library")
    w("")
    w("Sites whose C names that System doesn't cover all have the standard library's answer in mapping.ini (`swift`): "
      "adopter work, with the answer given.")
    w("")
    if std:
        by = collections.defaultdict(list)
        for s in std:
            by[", ".join(s["holder"])].append(s)
        w("| Answer | Sites | Repositories |")
        w("|---|---:|---|")
        for h, ss in sorted(by.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            w(f"| {st.cell(h)} | {len(ss)} | {', '.join(sorted({s['repository'] for s in ss}))} |")
    else:
        w("None.")
    w("")

    entry_table("excluded", "Excluded", "Not sites at all; they count nowhere.",
                [("Reason", lambda e, h: e.reason), ("Decided", lambda e, h: e.decided or "—"), ("Repositories", repos)])

    w("## Every site")
    w("")
    w("<details><summary>By repository: file, lines and what they import, platforms, category, holder and "
      "reason; the unexplained sites are in the table above</summary>")
    w("")
    for r in led["read"]:
        everyone = [s for s in sites if s["repository"] == r["repository"]]
        ss = [s for s in everyone if s["category"] != "unexplained"]
        n_un = len(everyone) - len(ss)
        w(f"**{r['repository']}**, at {r['where']}: " + (f"{len(everyone)} sites" if everyone else "no sites")
          + (f", {n_un} of them unexplained (above)" if n_un else "") + ".")
        w("")
        for g in grouped(ss):
            s = g[0]
            holder = ", ".join(s["holder"] or [])
            w(f"- `{s['file']}` {lines_cell(g)} ({group_platforms(g)}): **{s['category']}**"
              + (f" ({st.cell(holder)})" if holder and s["category"] not in ("System gap", "not System's",
                                                                             "standard library") else "")
              + f": {st.cell(s['reason'])}")
        if ss:
            w("")
    w("</details>")
    w("")
    if led["notRead"]:
        w("Not read: " + "; ".join(f"{r} ({why})" for r, why in led["notRead"]) + ".")
        w("")


def grouped(sites):
    """The sites by repository and file, those of a file with the same
    category and reason together, in line order."""
    out = collections.OrderedDict()
    for s in sorted(sites, key=lambda s: (s["repository"], s["file"], s["line"])):
        out.setdefault((s["repository"], s["file"], s["category"], s["reason"]), []).append(s)
    return list(out.values())


def lines_cell(ss):
    """`12 ucrt, 13 WinSDK`; a run of consecutive lines alike is one range,
    `22-37 MachO (scoped) ��16`."""
    runs = []
    for s in ss:
        text = imports_cell(s)
        if runs and runs[-1][2] == text and runs[-1][1] == s["line"] - 1:
            runs[-1][1] = s["line"]
            runs[-1][3] += 1
        else:
            runs.append([s["line"], s["line"], text, 1])
    return ", ".join(f"{a}-{b} {t} ×{n}" if n > 1 else f"{a} {t}" for a, b, t, n in runs)


def group_platforms(ss):
    best = {}
    for s in ss:
        for p, v in s["platforms"].items():
            if best.get(p) != platforms.T:
                best[p] = v
    return ", ".join(p + ("?" if best[p] == platforms.M else "") for p in PLATFORMS if p in best) or "none"


def imports_cell(s):
    if s["type"] == "marker":
        return "marker: " + st.cell(s["text"][:70]) + ("…" if len(s["text"]) > 70 else "")
    what = f"`{s['module']}`" + (f" ({s['importKind']})" if s["importKind"] != "whole" else "")
    if s["exported"]:
        what += ", re-exported"
    if s["markers"]:
        what += f", {len(s['markers'])} marker" + ("s" if len(s["markers"]) > 1 else "")
    return what


def as_json(led, meta):
    if led.get("error"):
        return {"meta": meta, "error": led["error"]}
    return {
        "meta": dict(meta, system=led["system"], vocab=led["vocab"], windowsBindings=led["bindings"]),
        "floor": {p: len(v) for p, v in led["floor"].items()},
        "modules": {g: {"modules": led["modules"].names[g], "patterns": led["modules"].patterns[g],
                        **led["modules"].meta[g]} for g in GROUPS},
        "entries": [dict(e.as_json(), sites=led["held"][e.id]["sites"], also=led["held"][e.id]["also"])
                    for e in led["entries"]],
        "gaps": [dict(g, gap=u, rank=k) for k, (u, g) in enumerate(led["gaps"], 1)],
        "read": led["read"], "notRead": [{"repository": r, "why": w} for r, w in led["notRead"]],
        "notSystemsImports": dict(led["notSystems"]),
        "sites": led["sites"],
    }


METHOD = """
- **Sites left** (section 5) reads every repository of `scheme-main.tsv` but swift-system at the commits section 4
  reads, and the swift repository too, at its ecosystem clone: that clone is partial (blobless), so it's read only
  within its sparse checkout, and every git command runs with `GIT_NO_LAZY_FETCH=1`, so that nothing is fetched.
  Every Swift file is read, library, tests, other code and nested packages alike, with comments and strings blanked.
  A *site* is an import of a module that `modules.ini` puts in [count] or [report], in any form, at its line, with
  the platforms whose build compiles that line (platforms.py's evaluation, FOUNDATION_FRAMEWORK false); or a
  `SYSTEM-GAP:` marker that sits over no such import (the imports it does sit over take its interfaces as theirs).
  Imports of [not System's] modules aren't sites; their counts are given. A file that reaches a platform module
  only through another module's re-export (TSCLibc's, SWBLibc's) isn't a site; the re-export is.
- **C names**: a scoped import serves the declaration it names. A whole-module or submodule import serves the C
  names on the lines its platform compiles, found lexically as `../adopters-unix/scripts/inventory.py` finds them:
  the macOS SDK's names in the counted modules (adopter-coverage's stored vocabulary), System's C names, and
  mapping.ini's symbols (not Dispatch's, the frameworks', SQLite's or the Objective-C runtime's), with Windows' names
  (Prototype/Win32/WindowsModel and Rust's Win32 bindings, where rustc is installed) on Windows only; not a
  declaration or a label, not a member of anything but a platform module (a C field is one), a call-only word (`read`,
  `close`) only when called, and none the repository declares itself, in Swift or in its C headers, unless qualified
  (`Glibc.read`). A file's names count for each of its imports compiled on the platform. Rejected: adopter-coverage's
  extractions (`interfaces.json.gz`), which exist for some repositories, at other commits; and a vocabulary of any
  capitalized name, which reads every Swift type as C.
- **Categories**: `exceptions.ini`'s entries decide a site first, by kind: *excluded* (not a site), *exception* (Michael's
  list, with who approved it and when), *undecided*, *queued* (work already identified, with where), then a gap kept by
  hand; an entry with `names` or `mapping` holds only those names. A [report] module's import is *undecided*. Otherwise
  each C name is answered on each platform it's used on, against System at `system-next` (api-delta's scan of its
  sources and `derive.py`, as inventory.py reads them, with WASI as WASI without threads): *covered* when a public
  declaration built there names it in a doc comment's *The corresponding C …* sentence (or only for some uses), a
  CInterop alias or accessor covers it, mapping.ini's hand status covers it there, or System covers it under another C
  name (status.py's and inventory.py's equivalents); else the standard library's answer (`swift`), else *not System's*
  (`wrap = no`, a lane's verdict, unreviewed); else a *System gap*, whose unit is the name's mapping.ini entry, or the
  name. The site takes the first of: System gap, queued, not System's, standard library; with none, it's *unexplained*:
  System covers every name it serves there, the scan found none, or it's a marker that names no C interface.
- **Ranking**: System gaps in the order to fill them, greedily: next is the gap that unblocks the most sites, given the
  ones above are filled (a site is unblocked when none of its gaps is left), ties going to more platforms, then to more
  sites held. Entries by the sites they hold. **The floor** holds on a platform when no site compiled there (maybe
  included) is left but exceptions, excluded ones and [report] modules'. Rejected: counting each C name on each line as
  a site (inventory.py's unit), which made a whole-module import of WinSDK hundreds of sites; and ranking gaps by the
  sites they hold, which counts a site once per gap and ranks gaps that free nothing alone above ones that do.
"""
