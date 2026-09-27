#!/usr/bin/env python3
"""Check mapping.ini against a package's extraction and System's API, and
compute the coverage the report shows.

  - Every interface the extractor found must be named by exactly one
    mapping entry; the rest are reported as new and unmapped.
  - Every System declaration an entry cites must exist on the checked-out
    tip, in the scope given, with the same declaration text (attributes,
    access modifiers and whitespace aside). One that doesn't is reported as
    missing, with the declarations of the same name that do exist.
  - A covered or partial entry is covered only on the platforms where one
    of its declarations compiles, per api-delta's source scan; elsewhere
    it counts as missing.

Usage: check.py --package packages/NAME.ini --interfaces I.json --system S.json
                --mapping M.ini --meta meta.json --out coverage.json
       check.py --summary coverage.json
Exit status: 0 if the mapping accounts for everything, 2 if not.
"""

import sys

sys.dont_write_bytecode = True  # no __pycache__, here or in api-delta's scripts

import argparse
import collections
import configparser
import fnmatch
import json
import os
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import package  # noqa: E402

PLATFORMS = package.PLATFORMS
STATUSES = ("covered", "partial", "missing", "ignore")
CATEGORIES = [
    "file I/O", "file system", "directories", "sockets", "name resolution", "network interfaces",
    "event notification", "io_uring", "system calls", "processes", "terminals", "signals", "threads & locks", "time",
    "memory",
    "dynamic loading", "system info", "errno & errors", "dispatch", "Apple frameworks", "C libraries",
    "strings/ctype/libm/stdio", "atomics", "C language", "compiler intrinsics", "uncategorized",
]
# Platforms an `@available(<name>, unavailable)` takes away.
UNAVAILABLE_PLATFORMS = {"macOS": ["Darwin"], "Windows": ["Windows"], "Linux": ["Linux", "Musl"],
                         "Android": ["Android"], "WASI": ["WASI"], "FreeBSD": ["FreeBSD"], "OpenBSD": ["OpenBSD"]}
# Categories outside System's scope: the OS's, but not System's to wrap, or
# not OS interfaces at all. Used for the lines that compare with the reach
# of the dependencies.
OUT_OF_SCOPE = {"dispatch", "Apple frameworks", "C libraries", "strings/ctype/libm/stdio", "atomics", "C language",
                "compiler intrinsics"}
# A function too long to be a thin wrapper counts only its call-site lines.
THIN_WRAPPER_LINES = 40
# [config] keys in mapping.ini.
CONFIG_KEYS = {"secondary", "header-category", "name-category", "lanes"}
# Evidence levels, strongest first (see Derivation).
EVIDENCE = ("doc", "restricted", "impl", "elsewhere")

ACCESS = r"\b(public|open|internal|package|fileprivate|private)(\((set|get)\))?\s+"
ATTRIBUTE = r"@[A-Za-z_][\w.]*(\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?\s*"
DECL_START = re.compile(r"^(static |class |mutating |nonmutating |consuming |borrowing |final |override |"
                        r"convenience |required |nonisolated |indirect |optional |dynamic )*"
                        r"(func|init[?!]?|subscript|var|let|case|typealias|struct|enum|class|protocol|actor|"
                        r"extension|associatedtype)\b")


def normalize_decl(text, kw=None):
    """A declaration's text without attributes, access modifiers or layout
    differences, cut to what identifies it."""
    s = re.sub(ATTRIBUTE, "", text)
    s = re.sub(ACCESS, "", s)
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\(\s+", "(", s)
    s = re.sub(r"\s+\)", ")", s)
    s = re.sub(r"\s*,\s*", ", ", s)
    s = re.sub(r"\s+:", ":", s)
    s = re.sub(r"<\s+", "<", s)
    s = re.sub(r"\s+>", ">", s)
    s = s.rstrip("{ ").strip()
    m = DECL_START.match(s)
    kw = kw or (m.group(2) if m else None)
    if kw in ("struct", "enum", "class", "protocol", "actor", "extension", "typealias", "associatedtype"):
        m2 = re.match(r"^((?:\w+ )*?)(struct|enum|class|protocol|actor|extension|typealias|associatedtype)\s+"
                      r"([A-Za-z_][\w.]*)", s)
        if m2:
            return f"{m2.group(2)} {m2.group(3)}"
    if kw in ("var", "let", "case"):
        s = re.split(r"\s=\s|\s\{", s)[0].strip()
    return s


def decl_key_name(decl):
    """`func read(into buffer: X, retryOnInterrupt: Bool) throws` -> 'read'."""
    m = re.search(r"\b(?:func|var|let|case|typealias|struct|enum|class|protocol|actor|associatedtype)\s+"
                  r"([A-Za-z_]\w*|`[^`]+`|[^\s(<]+)", decl)
    if m:
        return m.group(1)
    m = re.search(r"\b(init[?!]?|subscript)\b", decl)
    return m.group(1).rstrip("?!") if m else None


def parse_api_line(line):
    """`Scope.Path: decl` or a bare top-level `decl`."""
    line = line.strip()
    m = re.match(r"^([A-Za-z_][\w.]*):\s+(.+)$", line)
    if m and DECL_START.match(re.sub(ATTRIBUTE, "", m.group(2)).strip()):
        return m.group(1), m.group(2).strip()
    return "", line


class SystemAPI:
    def __init__(self, scan):
        self.by_key = collections.defaultdict(list)
        self.by_name = collections.defaultdict(list)
        self.entries = []   # one per scanned declaration, in the scan's order
        self.unsupported = scan.get("moduleUnsupportedPlatforms", {})
        for d in scan["declarations"]:
            scope = ".".join(d["scopes"])
            kw = d["kw"].rstrip("?!")
            base = d["name"].split("(")[0].rstrip("?!")
            # `@available(*, unavailable)` (a renamed stub) can't be cited;
            # `@available(Windows, unavailable)` only takes Windows away.
            unavail = d.get("unavailable") or []
            gone = {p for a in unavail for name, plats in UNAVAILABLE_PLATFORMS.items()
                    if re.search(rf"\(\s*{name}\s*,\s*unavailable", a) for p in plats}
            entry = {
                "scope": scope, "name": d["name"], "module": d["module"], "file": d["file"], "line": d["line"],
                "declaration": normalize_decl(d["signature"], kw if kw in ("var", "let", "case") else None),
                "platforms": [p.lstrip("?") for p in d["platforms"] if p.lstrip("?") not in gone],
                "uncertainPlatforms": [p[1:] for p in d["platforms"] if p.startswith("?")],
                "availability": availability(d["availability"] + d.get("scopeAvailability", [])),
                "unavailable": any(re.search(r"\(\s*\*\s*,\s*unavailable", a) for a in unavail),
                "unavailableOn": sorted(gone),
            }
            self.entries.append(entry)
            self.by_key[(scope, entry["declaration"])].append(entry)
            self.by_name[(scope, base)].append(entry)

    def find(self, scope, decl):
        """(matches, same-name declarations). api-delta's scanner sometimes
        loses a scope, placing members at the top level (IORing's, after
        nested one-line bodies); a match there counts, marked so."""
        norm = normalize_decl(decl)
        hits = [e for e in self.by_key.get((scope, norm), []) if not e["unavailable"]]
        if hits:
            return hits, []
        if scope:
            lost = [dict(e, scopeLost=True) for e in self.by_key.get(("", norm), []) if not e["unavailable"]]
            if lost:
                return lost, []
        name = decl_key_name(norm)
        return [], [e for e in self.by_name.get((scope, name), []) if not e["unavailable"]]


def availability(attrs):
    """{'system': '199', 'os': ['macOS 27.0', ...]} from @available texts."""
    system, floors = None, []
    for a in attrs:
        for v in re.findall(r"\bSystem\s+([\d.]+)", a):
            if system is None or tuple(int(x) for x in v.split(".")) > tuple(int(x) for x in system.split(".")):
                system = v
        m = re.search(r"\bmacOS\s+([\d.]+)", a)
        if m and "System" not in a:
            floors.append("macOS " + m.group(1))
    return {"system": system, "os": sorted(set(floors))}


def load_mapping(path, packages=()):
    """(config, entries, problems). `packages` are the names note.<package>
    may use."""
    problems = []
    cp = configparser.ConfigParser(interpolation=None, delimiters=("=",), comment_prefixes=("#",),
                                   inline_comment_prefixes=None, strict=True, empty_lines_in_values=False,
                                   default_section="__none__")
    cp.optionxform = str
    try:
        with open(path, encoding="utf-8") as f:
            cp.read_file(f)
    except configparser.Error as e:
        return {}, [], [f"can't read {path}: {e}"]
    config = {}
    entries = []
    for sec in cp.sections():
        items = dict(cp.items(sec))
        if sec == "config":
            config = items
            for k in config:
                if k == "wrapper-files":
                    problems.append("[config]: wrapper-files belongs in the package's file under packages/")
                elif k not in CONFIG_KEYS:
                    problems.append(f"[config]: unknown key {k!r}")
            continue
        hand = items.get("status", "").strip() or None
        e = {"id": sec, "symbols": (items.get("symbols") or sec).split(),
             "category": items.get("category", "").strip(), "status": hand, "hand": hand,
             "note": " ".join(items.get("note", "").split()), "swift": " ".join(items.get("swift", "").split()),
             "notes": {}, "apis": [], "overrides": {}, "same": {}, "wrap": items.get("wrap", "yes").strip()}
        for line in (items.get("system") or "").split("\n"):
            if line.strip():
                scope, decl = parse_api_line(line)
                e["apis"].append({"text": line.strip(), "scope": scope, "decl": decl})
        for k, v in items.items():
            m = re.match(r"^note\.([\w-]+)$", k)
            if m:
                if packages and m.group(1) not in packages:
                    problems.append(f"[{sec}]: {k} names no package in packages/")
                e["notes"][m.group(1)] = " ".join(v.split())
                continue
            m = re.match(r"^same\.(\S+)$", k)
            if m:
                if m.group(1) not in e["symbols"]:
                    problems.append(f"[{sec}]: {k} names a symbol the entry doesn't have")
                elif not re.match(r"^[A-Za-z_]\w*$", v.strip()):
                    problems.append(f"[{sec}]: {k} = {v}: the value must be one C name")
                else:
                    e["same"][m.group(1)] = v.strip()
                continue
            m = re.match(r"^status\.(\w+)$", k)
            if m:
                plat = next((p for p in PLATFORMS if p.lower() == m.group(1).lower()), None)
                st, _, reason = v.partition(":")
                if plat is None or st.strip() not in STATUSES:
                    problems.append(f"[{sec}]: bad override {k} = {v}")
                else:
                    e["overrides"][plat] = {"status": st.strip(), "reason": " ".join(reason.split())}
            elif k not in ("symbols", "category", "status", "system", "note", "swift", "wrap"):
                problems.append(f"[{sec}]: unknown key {k!r}")
        if e["wrap"] not in ("yes", "no"):
            problems.append(f"[{sec}]: wrap must be yes or no, not {e['wrap']!r}")
        if hand is not None and hand not in STATUSES:
            problems.append(f"[{sec}]: status must be one of {', '.join(STATUSES)}, not {hand!r}")
        if hand != "ignore" and e["category"] not in CATEGORIES:
            problems.append(f"[{sec}]: unknown category {e['category']!r}")
        if hand in ("covered", "partial") and not e["apis"]:
            problems.append(f"[{sec}]: a {hand} entry needs a `system` declaration")
        if hand is None and e["apis"]:
            problems.append(f"[{sec}]: `system` needs a `status`; without one, the derivation finds System's API")
        if hand in ("partial", "ignore") and not e["note"] and not e["notes"]:
            problems.append(f"[{sec}]: a {hand} entry needs a note")
        entries.append(e)
    return config, entries, problems


def is_function_like(it):
    return "function" in it["kinds"] or ("macro" in it["kinds"] and any(s["called"] for s in it["sites"]))


class Derivation:
    """An entry's status per platform, from what System's sources say they
    cover (derive.py's output) rather than from the mapping.

    Each symbol gets the strongest evidence it has on a platform:
      doc         a public declaration built there names it in its doc
                  comment ("The corresponding C function is `x`.") or is a
                  CInterop typealias of it;
      restricted  only declarations that name it for one use (`fcntl`,
                  with the `F_GETFL` command);
      impl        System's own code uses it there, but no public
                  declaration names it (a deinit's pthread_mutex_destroy);
      elsewhere   named, but by declarations not built there.
    A symbol reads as another C name where the mapping says so
    (`same.<symbol>`), and on Windows ucrt's `_x` reads as `x`.

    The symbols that decide are the ones the package uses on the platform,
    other than its own shims and the C names only its shims use. Where it
    uses nothing else there, the entry's other symbols decide (NIO's Linux
    rename goes through its shim; System's rename names renamex_np and
    renameat2), and failing those, what the shims wrap.

    Covered: every deciding symbol has doc or impl evidence, and one has
    doc. Partial: some have doc, or the best is restricted. Missing:
    otherwise, including an entry whose own name is one of its deciding
    symbols and isn't named: System's QoS constants don't make posix_spawn
    partial."""

    def __init__(self, derived, interfaces, shim_targets, owner):
        self.names = derived.get("names", {})
        self.impl = derived.get("implementation", {})
        self.interfaces = interfaces
        self.shim_targets = set(shim_targets)
        self.owner = owner

    def evidence(self, sym, plat, same):
        """(level or None, the C name it was found as, declarations)."""
        cands = ([same[sym]] if sym in same else []) + [sym]
        if plat == "Windows" and re.match(r"^_[A-Za-z]", sym):
            cands.append(sym[1:])
        found = None
        for c in cands:
            n = self.names.get(c)
            if not n:
                continue
            if plat in n["platforms"]:
                return "doc", c, [d for d in n["declarations"] if not d["restricted"] and plat in d["platforms"]]
            if plat in n["partialPlatforms"]:
                if found is None or found[0] != "restricted":
                    found = ("restricted", c, [d for d in n["declarations"] if plat in d["platforms"]])
            elif found is None:
                found = ("elsewhere", c, n["declarations"])
        if found and found[0] == "restricted":
            return found
        for c in cands:
            if plat in self.impl.get(c, ()):
                return "impl", c, []
        return found or (None, None, [])

    def deciding(self, e, plat):
        """(basis, symbols) that decide the entry on a platform."""
        its = self.interfaces
        syms = e["symbols"]
        shim = {s for s in syms if its.get(s, {}).get("shim")}
        internal = {s for s in syms if s in its and s not in shim and its[s]["targets"]
                    and set(its[s]["targets"]) <= self.shim_targets}
        used = [s for s in syms if its.get(s, {}).get("platforms", {}).get(plat)]
        counted = [s for s in used if s not in shim and s not in internal]
        if counted:
            return "used", counted
        counted = [s for s in syms if s in its and s not in shim and s not in internal]
        if counted:
            return "spellings", counted
        counted = [s for s in syms if s in its and s not in shim]
        if counted:
            return "shim calls", counted
        wraps = set()
        for s in used:
            wraps.update((its[s].get("shim") or {}).get("wraps", {}).get(plat, []))
        counted = sorted(w for w in wraps if w in self.owner and self.owner[w].get("hand") != "ignore"
                         and self.owner[w]["category"] not in OUT_OF_SCOPE)
        if counted:
            return "shim wraps", counted
        return "mapping", [s for s in syms if s not in shim]

    def entry(self, e, plats):
        """{platform: {status, basis, evidence: {symbol: [level, as, declaration keys]}}}, and the
        declarations that cover the entry anywhere."""
        out, decls = {}, {}
        # The functions the package calls for the entry anywhere, its shims'
        # calls included (pdfork, inside Subprocess's C shim), though not the
        # shims themselves.
        its = self.interfaces
        all_funcs = [s for s in e["symbols"] if s in its and not its[s].get("shim") and self.function_like(s)]
        for p in plats:
            basis, counted = self.deciding(e, p)
            ev = {}
            for s in counted:
                level, name, ds = self.evidence(s, p, e["same"])
                ev[s] = [level, name, [f"{d['file']}:{d['line']}" for d in ds[:6]]]
                if level in ("doc", "restricted"):
                    for d in ds:
                        decls.setdefault(f"{d['file']}:{d['line']}", d)
            levels = [v[0] for v in ev.values()]
            named = ("doc", "restricted")
            # An operation isn't covered by its constants: System naming
            # CLOCK_MONOTONIC (for its condition variables) doesn't cover
            # clock_gettime. Where functions decide, one must be named.
            funcs = all_funcs
            rule = None
            if e["id"] in e["symbols"] and e["id"] not in self.names:
                st, rule = "missing", f"System names no {e['id']}"
            elif e["id"] in ev and ev[e["id"]][0] not in named:
                st, rule = "missing", f"System doesn't name {e['id']} here"
            elif funcs and not any(self.evidence(s, p, e["same"])[0] in named for s in funcs):
                st, rule = "missing", "System names none of its functions"
            elif levels and all(x in ("doc", "impl") for x in levels) and "doc" in levels:
                st = "covered"
            elif "doc" in levels or "restricted" in levels:
                st = "partial"
            else:
                st = "missing"
            out[p] = {"status": st, "basis": basis, "evidence": ev, "rule": rule}
        return out, decls

    def function_like(self, sym):
        it = self.interfaces.get(sym)
        if it is not None:
            return is_function_like(it)
        return "function" in self.names.get(sym, {}).get("kinds", [])


def derived_reason(d, plat):
    """What decided a derived status, for the report."""
    ev = d["evidence"]
    by = collections.defaultdict(list)
    for s, (level, name, _ds) in ev.items():
        by[level].append(s if name in (s, None) else f"{s} (as {name})")
    bits = [d["rule"]] if d.get("rule") else []
    if d["status"] != "covered":
        if by.get("restricted"):
            bits.append("named only for some uses: " + ", ".join(by["restricted"]))
        if by.get("elsewhere"):
            bits.append(f"System's API that names them isn't built on {plat}: " + ", ".join(by["elsewhere"]))
        if by.get(None):
            bits.append("not named by System: " + ", ".join(by[None]))
        if by.get("impl") and d["status"] == "missing":
            bits.append("used by System's implementation only: " + ", ".join(by["impl"]))
    elif by.get("impl"):
        bits.append("with what System's implementation handles: " + ", ".join(by["impl"]))
    if d["basis"] != "used":
        bits.append({"spellings": "decided by the entry's other spellings",
                     "shim calls": "decided by the C names the package's shims call",
                     "shim wraps": "decided by what the package's shims wrap",
                     "mapping": "decided by the mapping's symbols"}[d["basis"]])
    return "; ".join(bits)


def auto_category(it, config):
    """A category for an interface no entry names: by the header that
    declares it, then by its name ([config] header-category and
    name-category in mapping.ini)."""
    for line in (config.get("header-category") or "").split("\n"):
        globs, _, cat = line.rpartition(":")
        for h in it.get("headers") or []:
            if any(fnmatch.fnmatch(h, g) for g in globs.split()):
                return cat.strip()
    for line in (config.get("name-category") or "").split("\n"):
        pat, _, cat = line.rpartition(":")
        if pat.strip() and re.search(pat.strip(), it["name"]):
            return cat.strip()
    return "uncategorized"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package")
    ap.add_argument("--interfaces")
    ap.add_argument("--system")
    ap.add_argument("--derived", help="derive.py's output for the same System commit")
    ap.add_argument("--mapping")
    ap.add_argument("--meta")
    ap.add_argument("--out")
    ap.add_argument("--strict", action="store_true",
                    help="unmapped interfaces are problems (the audited adopters); otherwise they're classified")
    ap.add_argument("--summary")
    args = ap.parse_args()
    if args.summary:
        return print_summary(json.load(open(args.summary)))

    pkg = package.load(args.package)
    platforms = [p for p in PLATFORMS if p in pkg["platforms"]]
    ext = json.load(open(args.interfaces))
    api = SystemAPI(json.load(open(args.system)))
    derived = json.load(open(args.derived)) if args.derived else {}
    meta = json.load(open(args.meta)) if args.meta else {}
    known = {f[:-4] for f in os.listdir(os.path.dirname(os.path.abspath(args.package))) if f.endswith(".ini")}
    config, entries, malformed = load_mapping(args.mapping, known)
    interfaces = {i["name"]: i for i in ext["interfaces"]}
    for e in entries:
        e["packageNote"] = e["notes"].get(pkg["key"], "")

    problems = {"malformed": malformed, "unmapped": [], "duplicate": [], "apiMissing": [], "staleNotes": [],
                "alreadySystemMissing": []}

    # ------------------------------------------------- symbols to entries
    owner = {}
    for e in entries:
        for s in e["symbols"]:
            if s in owner:
                problems["duplicate"].append(f"{s} is in both [{owner[s]['id']}] and [{e['id']}]")
            else:
                owner[s] = e
    # An interface no entry names gets an entry of its own, derived like
    # any other, in the category its header or name suggests. For the
    # audited adopters (--strict) it's also a problem to fix in the mapping.
    for name, it in sorted(interfaces.items()):
        if name in owner:
            continue
        cat = auto_category(it, config)
        problems["unmapped"].append({"name": name, "kinds": it["kinds"], "evidence": it["evidence"],
                                     "platforms": it["platforms"], "targets": it["targets"],
                                     "headers": it["headers"] or it["reachedThrough"], "category": cat,
                                     "examples": [f"{s['file']}:{s['line']}" for s in it["sites"][:3]]})
        e = {"id": name, "symbols": [name], "category": cat, "status": None, "hand": None, "note": "",
             "swift": "", "notes": {}, "apis": [], "overrides": {}, "same": {}, "wrap": "yes", "packageNote": "",
             "auto": True}
        entries.append(e)
        owner[name] = e
    # A note for this package on an entry it no longer uses. (Symbols no
    # package uses are the combined report's to find.)
    for e in entries:
        if e["packageNote"] and not any(s in interfaces for s in e["symbols"]):
            problems["staleNotes"].append({"entry": e["id"], "symbols": e["symbols"]})

    # ------------------------------------------------------ System APIs
    for e in entries:
        for a in e["apis"]:
            hits, near = api.find(a["scope"], a["decl"])
            a["matched"] = hits
            a["suggestions"] = near
            if not hits and e["hand"] in ("covered", "partial"):
                problems["apiMissing"].append({"entry": e["id"], "api": a["text"],
                                               "sameName": [f"{n['scope'] + ': ' if n['scope'] else ''}"
                                                            f"{n['declaration']} ({n['file']}:{n['line']})"
                                                            for n in near]})

    # --------------------------------------------------- per platform
    # The derivation decides every entry; a hand status in the mapping
    # overrides it, and a `status.<Platform>` overrides both.
    derivation = Derivation(derived, interfaces, ext.get("shimTargets", []), owner)
    for e in entries:
        used = collections.Counter()
        for s in e["symbols"]:
            for p, n in interfaces.get(s, {}).get("platforms", {}).items():
                used[p] += n
        e["used"] = {p: used[p] for p in platforms if used[p]}
        api_plats = set()
        for a in e["apis"]:
            for h in a["matched"]:
                api_plats.update(h["platforms"])
        e["systemPlatforms"] = [p for p in PLATFORMS if p in api_plats]
        dplat, ddecls = derivation.entry(e, list(e["used"]))
        e["derived"] = {p: dict(d, reason=derived_reason(d, p)) for p, d in dplat.items()}
        e["derivedApis"] = [{"text": f"{d['scope'] + ': ' if d['scope'] else ''}{d['declaration']}",
                             "scope": d["scope"], "decl": d["declaration"], "matched": [d], "derived": True}
                            for _k, d in sorted(ddecls.items(), key=lambda kv: (kv[1]["file"], kv[1]["line"]))]
        e["platformStatus"] = {}
        for p in e["used"]:
            if p in e["overrides"]:
                e["platformStatus"][p] = dict(e["overrides"][p], by="override")
            elif e["hand"] in ("covered", "partial"):
                if p in api_plats:
                    e["platformStatus"][p] = {"status": e["hand"], "reason": "", "by": "hand"}
                elif not any(a["matched"] for a in e["apis"]):
                    e["platformStatus"][p] = {"status": "missing", "reason": "the cited System API isn't on the tip",
                                              "by": "hand"}
                else:
                    e["platformStatus"][p] = {"status": "missing", "reason": f"System's API isn't built on {p}",
                                              "by": "hand"}
            elif e["hand"] in ("missing", "ignore"):
                e["platformStatus"][p] = {"status": e["hand"], "reason": "", "by": "hand"}
            else:
                d = e["derived"][p]
                e["platformStatus"][p] = {"status": d["status"], "reason": d["reason"], "by": "derived"}
        # The entry's status: the hand's, or the best the derivation found
        # where the package uses it (a covered entry can be missing on the
        # platforms System's API isn't built on, as with a hand status).
        if e["hand"]:
            e["status"] = e["hand"]
        else:
            got = {v["status"] for v in e["platformStatus"].values()}
            e["status"] = next((s for s in ("covered", "partial", "missing") if s in got), "missing")
        e["decidedBy"] = "hand" if e["hand"] else ("override" if e["overrides"] else "derived")
        if not e["hand"]:
            e["apis"] = e["derivedApis"]
        # Where the hand and the derivation disagree, per platform.
        e["disagree"] = {p: {"hand": e["platformStatus"][p]["status"], "derived": e["derived"][p]["status"],
                             "reason": e["derived"][p]["reason"]}
                         for p in e["used"] if e["hand"] and e["hand"] != "ignore"
                         and e["platformStatus"][p]["status"] != e["derived"][p]["status"]}
        e["functionLike"] = [s for s in e["symbols"] if s in interfaces and is_function_like(interfaces[s])]
        e["sites"] = sum(len(interfaces[s]["sites"]) for s in e["symbols"] if s in interfaces)
        tg = collections.Counter()
        for s in e["symbols"]:
            for t, n in interfaces.get(s, {}).get("targets", {}).items():
                tg[t] += n
        e["targets"] = dict(sorted(tg.items()))
        if e["hand"]:
            e["unreleased"] = any(h["availability"]["system"] == "199" for a in e["apis"] for h in a["matched"])
        else:
            # Derived: some symbol that decides it is covered only by
            # unreleased (System 199) declarations.
            named = {v[1] for d in e["derived"].values() for v in d["evidence"].values()
                     if v[0] in ("doc", "restricted")}
            e["unreleased"] = any(derivation.names.get(n, {}).get("unreleased") for n in named)

    # ------------------------------------------------------ summaries
    def tally(function_only):
        table = {c: {p: collections.Counter() for p in platforms + ["all"]} for c in CATEGORIES}
        for e in entries:
            if e["status"] == "ignore":
                continue
            syms = e["functionLike"] if function_only else [s for s in e["symbols"] if s in interfaces]
            for s in syms:
                it = interfaces[s]
                statuses = []
                for p in it["platforms"]:
                    st = e["platformStatus"].get(p, {"status": e["status"]})["status"]
                    table[e["category"]][p][st] += 1
                    statuses.append(st)
                # A symbol's overall status: the worst over its platforms.
                worst = "missing" if "missing" in statuses else "partial" if "partial" in statuses else "covered"
                table[e["category"]]["all"][worst] += 1
        return {c: {p: dict(v) for p, v in row.items()} for c, row in table.items()}

    summary = {"functions": tally(True), "all": tally(False)}

    # ------------------------------------------------ deletable lines
    wrapper_globs = pkg["wrapper-files"]
    files = ext["files"]

    def in_wrapper(path):
        return any(fnmatch.fnmatch(path, g) for g in wrapper_globs)

    def code_lines(path, start, end):
        return sum(1 for ln in files.get(path, {}).get("codeLines", []) if start <= ln <= end)

    # Gaps: entries missing or partial somewhere, other than those the Swift
    # standard library covers (a `swift` alternative) and those that aren't
    # System's to wrap (`wrap = no`: Dispatch, Apple's frameworks).
    gap_entries = [e for e in entries if e["status"] != "ignore" and not (e["status"] == "missing" and e["swift"])
                   and e["wrap"] != "no"
                   and any(v["status"] in ("missing", "partial") for v in e["platformStatus"].values())]
    secondary = set((config.get("secondary") or "").split())
    gap_ids = {e["id"] for e in gap_entries}
    gap_plats = {e["id"]: {p for p, v in e["platformStatus"].items() if v["status"] in ("missing", "partial")}
                 for e in gap_entries}
    # A wrapper function exists for the calls it makes: its lines go to the
    # gap entries it calls, or to no one when every call it makes is
    # covered. Only a function that calls nothing (a conversion, a constant
    # table) is split among the gap entries whose types and constants it
    # uses. Sites count only on the platforms where their entry has a gap.
    func_calls = collections.defaultdict(set)      # function -> entries called in it
    func_others = collections.defaultdict(set)     # function -> gap entries used but not called
    line_owners = collections.defaultdict(set)
    shim_owners = collections.defaultdict(set)
    touched = collections.defaultdict(set)
    for e in entries:
        if e["status"] == "ignore":
            continue
        for s in e["symbols"]:
            it = interfaces.get(s)
            if not it:
                continue
            fl = is_function_like(it)
            for site in it["sites"]:
                on_gap = e["id"] in gap_ids and bool(set(site["platforms"]) & gap_plats[e["id"]])
                if in_wrapper(site["file"]):
                    f = site.get("func")
                    if f and code_lines(site["file"], f[1], f[2]) <= THIN_WRAPPER_LINES:
                        key = (site["file"], f[1], f[2])
                        if s in secondary:
                            pass
                        elif fl and site.get("called"):
                            func_calls[key].add((e["id"], on_gap))
                        elif on_gap:
                            func_others[key].add(e["id"])
                    elif on_gap and s not in secondary:
                        line_owners[(site["file"], site["line"])].add(e["id"])
                elif on_gap:
                    touched[e["id"]].add((site["file"], site["line"]))
            if e["id"] in gap_ids and it.get("shim"):
                for d in it["shim"]["defs"]:
                    shim_owners[(d["file"], d["start"], d["end"], d["codeLines"])].add(e["id"])
    # Calls through file-scope captures (NIO's `sysRead(...)` for read).
    for path, info in files.items():
        if not in_wrapper(path):
            continue
        for cc in info.get("captureCalls", []):
            name, start, end = cc["func"]
            if code_lines(path, start, end) > THIN_WRAPPER_LINES:
                continue
            for sym, plats in cc["interfaces"].items():
                e = owner.get(sym)
                if e is None or e["status"] == "ignore" or sym in secondary:
                    continue
                on_gap = e["id"] in gap_ids and bool(set(plats) & gap_plats[e["id"]])
                func_calls[(path, start, end)].add((e["id"], on_gap))
    estimate = collections.defaultdict(lambda: {"swift": 0.0, "c": 0.0, "functions": [], "shims": []})
    for key in set(func_calls) | set(func_others):
        path, start, end = key
        n = code_lines(path, start, end)
        if key in func_calls:
            owners = {eid for eid, on_gap in func_calls[key] if on_gap and eid in gap_ids}
        else:
            owners = func_others[key]
        for o in owners:
            estimate[o]["swift"] += n / len(owners)
            estimate[o]["functions"].append(f"{path}:{start}-{end}")
    for (path, line), owners in line_owners.items():
        for o in owners:
            estimate[o]["swift"] += 1 / len(owners)
    for (path, start, end, n), owners in shim_owners.items():
        for o in owners:
            # The definition, plus its declaration in the shim's header.
            estimate[o]["c"] += (n + 1) / len(owners)
            estimate[o]["shims"].append(f"{path}:{start}-{end}")
    gaps = []
    for e in gap_entries:
        est = estimate.get(e["id"], {"swift": 0.0, "c": 0.0, "functions": [], "shims": []})
        gaps.append({"id": e["id"], "category": e["category"], "status": e["status"],
                     "gapPlatforms": [p for p, v in e["platformStatus"].items()
                                      if v["status"] in ("missing", "partial")],
                     "swiftLines": round(est["swift"]), "cLines": round(est["c"]),
                     "total": round(est["swift"] + est["c"]), "functions": sorted(set(est["functions"])),
                     "shims": sorted(set(est["shims"])), "callSitesElsewhere": len(touched.get(e["id"], ())),
                     "sites": e["sites"], "symbols": [s for s in e["symbols"] if s in interfaces]})
    gaps.sort(key=lambda g: (-g["total"], -g["callSitesElsewhere"], g["id"]))

    # ------------------------------ System API the package already uses
    already = []
    for a in ext.get("alreadySystem", []):
        sym = a["symbol"]
        found = None
        if a["module"] == "SystemPackage":
            found = find_used_symbol(api, sym)
            if not found:
                problems["alreadySystemMissing"].append({"symbol": sym, "sites": a["sites"][:3]})
        already.append({"module": a["module"], "symbol": sym, "sites": len(a["sites"]),
                        "targets": sorted({s["target"] for s in a["sites"]}),
                        "examples": [f"{s['file']}:{s['line']}" for s in a["sites"][:2]],
                        "onTip": bool(found) if a["module"] == "SystemPackage" else None})

    # ------------------------------------------------------ derivation
    # Which entries the derivation decides and which the mapping's hand
    # statuses do, and where the two disagree, over the entries the package
    # uses.
    in_use = [e for e in entries if e["used"]]
    stats = collections.Counter(e["decidedBy"] for e in in_use)
    stats.update("auto" for e in in_use if e.get("auto"))
    agree = collections.Counter()
    for e in in_use:
        if e["hand"] and e["hand"] != "ignore":
            agree["disagree" if e["disagree"] else "agree"] += 1
    derivation_out = {
        "entries": dict(stats), "handAgreement": dict(agree),
        "disagreements": [{"entry": e["id"], "hand": e["hand"], "category": e["category"],
                           "platforms": e["disagree"]} for e in in_use if e["disagree"]],
        "system": {k: derived.get("stats", {}).get(k) for k in ("declarations", "documented", "sentences",
                                                                  "typealiases", "implementationNames")},
        "systemNames": len(derivation.names),
    }

    out = {
        "meta": meta,
        "package": pkg,
        "derivation": derivation_out,
        "config": {"wrapperFiles": wrapper_globs, "thinWrapperLines": THIN_WRAPPER_LINES,
                   "secondary": sorted(secondary),
                   "unrankedStdlib": sorted(e["id"] for e in entries if e["status"] == "missing" and e["swift"]
                                            and e.get("sites")),
                   "notWrapped": sorted(e["id"] for e in entries if e["wrap"] == "no" and e.get("sites"))},
        "platforms": platforms,
        "categories": CATEGORIES,
        "problems": problems,
        "entries": [{k: v for k, v in e.items()} for e in entries],
        "interfaces": {n: {k: v for k, v in i.items() if k != "sites"} | {
            "siteCount": len(i["sites"]), "examples": i["sites"][:4]} for n, i in interfaces.items()},
        "summary": summary,
        "gaps": gaps,
        "alreadySystem": already,
        "directLines": len({(x["file"], x["line"]) for i in ext["interfaces"] for x in i["sites"]}),
        "directScopeLines": len({(x["file"], x["line"]) for i in ext["interfaces"] for x in i["sites"]
                                 if i["name"] in owner and owner[i["name"]]["wrap"] != "no"
                                 and owner[i["name"]]["status"] != "ignore"
                                 and owner[i["name"]]["category"] not in OUT_OF_SCOPE}),
        "extraction": {k: ext.get(k) for k in ("libraryTargets", "shimTargets", "skippedTargets",
                                               "unsupportedPlatforms", "unsupportedBecause", "excludedReferences",
                                               "crosscheck", "warnings", "nestedPackages", "dependencyPackages",
                                               "systemDependency", "dependencies", "model",
                                               "lexicalUnresolvedDropped")} | {"mode": ext.get("extraction", "index")},
        "darwin": ext.get("darwin"),
    }
    json.dump(out, open(args.out, "w"), indent=1)
    kinds = ("malformed", "duplicate", "apiMissing", "alreadySystemMissing") + (("unmapped",) if args.strict else ())
    failed = any(problems[k] for k in kinds)
    return 2 if failed else 0


def find_used_symbol(api, demangled):
    """Whether a System symbol the package references (a simplified
    demangled name, e.g.
    'FileDescriptor.read(fromAbsoluteOffset:into:retryOnInterrupt:)') still
    exists."""
    d = re.sub(r"^(static |class )", "", demangled)
    d = re.sub(r"^\(extension in [^)]*\):", "", d)
    head = d.split(" : ")[0]
    head = re.sub(r"\.(getter|setter|modify|read|unsafeAddressor|unsafeMutableAddressor)$", "", head)
    head = re.sub(r"<[^<>]*>", "", head)
    m = re.match(r"^(.*?)([A-Za-z_]\w*|init)(\([^()]*\))?$", head)
    if not m:
        return None
    scope = m.group(1).rstrip(".")
    base, labels = m.group(2), m.group(3) or ""
    cands = api.by_name.get((scope, base), [])
    if not cands and "." not in scope:
        # A type itself: FilePath, Errno, CInterop.
        cands = api.by_name.get(("", base), [])
    if labels:
        want = base + labels
        exact = [c for c in cands if c["name"].rstrip("?!").replace("init?", "init") == want
                 or c["name"] == want]
        return exact or None
    return cands or None


def print_summary(cov):
    p = cov["problems"]
    for kind, label in (("functions", "functions"), ("all", "all interfaces")):
        per = []
        for plat in cov["platforms"] + ["all"]:
            tot = collections.Counter()
            for c, row in cov["summary"][kind].items():
                tot.update(row.get(plat, {}))
            per.append(f"{'every platform' if plat == 'all' else plat} "
                       f"{tot['covered']}/{tot['partial']}/{tot['missing']}")
        print(f"{label} (covered/partial/missing): " + ", ".join(per))
    name = cov.get("package", {}).get("name", "the package")
    for k, label in (("unmapped", f"{name} interfaces with no mapping entry"),
                     ("apiMissing", "cited System declarations missing on the tip"),
                     ("alreadySystemMissing", f"System API {name} already uses, missing on the tip"),
                     ("duplicate", "symbols mapped twice"), ("malformed", "mapping errors"),
                     ("staleNotes", f"entries with a note for {name} that {name} no longer uses")):
        if p.get(k):
            print(f"{label}: {len(p[k])}")
            for x in p[k][:10]:
                print("   ", x if isinstance(x, str) else json.dumps(x)[:160])
    return 0


if __name__ == "__main__":
    sys.exit(main())
