#!/usr/bin/env python3
"""The symbols System's release builds export, for STATUS.md's section 1.

exports() builds one commit: it's exported with `git archive`, its
Package.swift patched by api-delta's patch_manifest.py (no Samples, so no
network), and built with `swift build -c release` for SystemSockets, which
builds SystemPackage too (SystemPackage alone where the commit has no
SystemSockets). `nm` lists each module's external symbols in its objects,
less the private externs. A result is cached by the commit's `Sources` and
`Package.swift` trees, so a commit that changes neither builds nothing.

The rest reads what the builds export: symbol_kind() sorts a demangled
symbol into property descriptors, conformances, types, initial values or
code; code_symbols() finds a declaration's code symbols (functions and
accessors) from its USR; and forwarding() reads a declaration's source for a
body that only forwards a C header value, the code that
@_alwaysEmitIntoClient would leave to the client.

Darwin only: the objects are read as Mach-O.
"""

import sys

sys.dont_write_bytecode = True

import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "api-delta", "scripts"))
from scan_sources import strip_comments_and_strings  # noqa: E402

import platforms  # noqa: E402

PATCH_MANIFEST = os.path.join(HERE, "..", "..", "api-delta", "scripts", "patch_manifest.py")
MODULES = ("SystemPackage", "SystemSockets")
# System's release build on Darwin, as Package.swift defines its flags.
SYSTEM_BUILD = platforms.model(build_flags={"SYSTEM_PACKAGE_DARWIN": platforms.T, "SYSTEM_PACKAGE": platforms.T,
                                            "ENABLE_MOCKING": platforms.F, "DEBUG": platforms.F})


# ---------------------------------------------------------------- builds

def _git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, check=True).stdout


def tree_key(repo, commit):
    """What a build depends on: the commit's Sources and Package.swift trees."""
    trees = _git(repo, "rev-parse", f"{commit}:Sources", f"{commit}:Package.swift").split()
    return hashlib.sha256(" ".join(trees).encode()).hexdigest()[:16]


def _exported(objects):
    """The external symbols the objects define, less the private externs."""
    out = subprocess.run(["nm", "-gUm", *objects], capture_output=True, text=True, check=True).stdout
    syms = set()
    for line in out.splitlines():
        if " external " in line and "private external" not in line:
            syms.add(line.split()[-1])
    return sorted(syms)


def exports(repo, commit, work, role, log=lambda m: print(m, file=sys.stderr)):
    """{"key", "commit", "modules": {module: [symbols]}, "error"} for one
    commit's release build. `role` ("head", "base") names its scratch
    directory under `work`, replaced by each build; results stay in
    `work/exports-<key>.json`."""
    key = tree_key(repo, commit)
    cached = os.path.join(work, f"exports-{key}.json")
    if os.path.exists(cached):
        with open(cached) as f:
            return json.load(f)
    if sys.platform != "darwin":
        return {"key": key, "commit": commit, "modules": {}, "error": "the objects are read as Mach-O, on Darwin only"}
    scratch = os.path.join(work, role)
    shutil.rmtree(scratch, ignore_errors=True)
    src = os.path.join(scratch, "src")
    os.makedirs(src)
    archive = subprocess.run(["git", "-C", repo, "archive", commit], capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", src], input=archive, check=True)
    manifest = os.path.join(src, "Package.swift")
    subprocess.run([sys.executable, PATCH_MANIFEST, manifest], capture_output=True, check=True)
    with open(manifest) as f:
        text = f.read()
    modules = [m for m in MODULES if f'name: "{m}"' in text]
    log(f"abi: release build of {commit[:8]} ({role}, about a minute)")
    build_log = os.path.join(work, f"{role}.log")
    with open(build_log, "w") as f:
        p = subprocess.run(["swift", "build", "--disable-sandbox", "-c", "release", "--target", modules[-1],
                            "--package-path", src, "--scratch-path", os.path.join(scratch, "build")],
                           stdout=f, stderr=subprocess.STDOUT)
    result = {"key": key, "commit": commit, "modules": {}, "error": None}
    if p.returncode != 0:
        with open(build_log) as f:
            errors = [line.strip() for line in f if " error: " in line]
        result["error"] = (f"the release build failed ({os.path.relpath(build_log, repo)})"
                           + (f": {errors[0][:300]}" if errors else ""))
        return result
    release = os.path.join(scratch, "build", "release")
    for m in modules:
        d = os.path.join(release, f"{m}.build")
        objects = sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".o"))
        result["modules"][m] = _exported(objects)
    with open(cached, "w") as f:
        json.dump(result, f)
    shutil.rmtree(scratch, ignore_errors=True)
    return result


def prune(work, keep):
    """Removes the cached results whose keys aren't in `keep`."""
    for f in os.listdir(work):
        m = re.match(r"^exports-([0-9a-f]+)\.json$", f)
        if m and m.group(1) not in keep:
            os.remove(os.path.join(work, f))


def demangle(symbols):
    """The symbols demangled (simplified), in order; Mach-O's leading
    underscore is dropped first."""
    if not symbols:
        return []
    text = "\n".join(s[1:] if s.startswith("_") else s for s in symbols) + "\n"
    out = subprocess.run(["xcrun", "swift-demangle", "--simplified"], input=text, capture_output=True, text=True,
                         check=True).stdout.split("\n")
    return out[:len(symbols)]


# ---------------------------------------------------------------- kinds

# A symbol's kind, by its demangled form's opening. What none of these
# matches is code: a function, an accessor or an addressor.
KINDS = (
    ("property descriptors", re.compile(r"^property descriptor for ")),
    ("conformances", re.compile(r"^(protocol conformance descriptor|protocol witness table|protocol witness|"
                                r"lazy protocol witness table|associated conformance|base conformance)")),
    ("types", re.compile(r"^(nominal type descriptor|type metadata|full type metadata|metaclass|class metadata|"
                         r"generic type metadata|singleton metadata|protocol descriptor|protocol requirements|"
                         r"associated type descriptor|method descriptor|dispatch thunk|enum case|reflection|"
                         r"opaque type descriptor|extension descriptor|module descriptor)")),
    ("initial values", re.compile(r"^variable initialization expression of ")),
)
KIND_NAMES = tuple(k for k, _ in KINDS) + ("code",)


def symbol_kind(demangled):
    for name, pattern in KINDS:
        if pattern.search(demangled):
            return name
    return "code"


ACCESSORS = ("g", "s", "M", "r", "x", "y", "au", "lu", "ao", "lo")
ACCESSOR_NAMES = {"g": "getter", "s": "setter", "M": "modify", "r": "read", "x": "modify", "y": "read",
                  "au": "addressor", "lu": "addressor", "ao": "addressor", "lo": "addressor"}


def code_symbols(usr, exported):
    """[(symbol, what)] for the code a declaration exports, given its USR
    (`s:` and the declaration's mangling): a function's or initializer's
    entry point, a property's or subscript's accessors."""
    if not usr.startswith("s:"):
        return []
    base = "$s" + usr[2:]
    m = re.match(r"^(.*)([vi])p(Z?)$", base)
    if m:
        stem, v, z = m.groups()
        return [(s, ACCESSOR_NAMES[a]) for a in ACCESSORS for s in [f"{stem}{v}{a}{z}"] if s in exported]
    what = "initializer" if base.endswith("fc") else "function"
    names = [base] + ([base[:-2] + "fC"] if base.endswith("fc") else [])
    return [(s, what) for s in names if s in exported]


def usr_of(symbol, usrs):
    """The USR in `usrs` whose declaration a code symbol belongs to, or None."""
    b = symbol[2:] if symbol.startswith("$s") else symbol
    cands = [b]
    m = re.match(r"^(.*)([vi])(g|s|M|r|x|y|au|lu|ao|lo)(Z?)$", b)
    if m:
        cands.append(f"{m.group(1)}{m.group(2)}p{m.group(4)}")
    if b.endswith("fC"):
        cands.append(b[:-2] + "fc")
    return next(("s:" + c for c in cands if "s:" + c in usrs), None)


# ---------------------------------------------------------------- forwarding bodies

# C header values by their spelling: a macro or enumerator (AF_INET, EPERM),
# System's internal accessor for one (_EPERM, __PC_PIPE_BUF), or a C struct's
# field (sin_port, msg_namelen). System's own names are never snake_case.
C_CONSTANT = re.compile(r"^(?:_+[A-Z][A-Z0-9_]*|[A-Z][A-Z0-9]*_[A-Z0-9_]+|[A-Z][A-Z0-9]{2,})$")
C_FIELD = re.compile(r"^[a-z][a-z0-9]*_[a-z0-9_]+$")
RAW = {"rawValue", "_rawValue"}
TOKEN = re.compile(r"\s*(`[^`]+`|[A-Za-z_][A-Za-z0-9_]*|0[xXbBoO][0-9a-fA-F_]+|\d[\d_]*|<<|>>|==|!=|&&|\|\||\S)")
# Calls a forwarding expression may make: conversions and wrappers, and
# Duration's unit factories (`.milliseconds(rawValue.tcpi_rto)`).
CALLS = {"init", "numericCast"}
UNIT_FACTORIES = {"seconds", "milliseconds", "microseconds", "nanoseconds"}
KEYWORDS = {"if", "else", "switch", "case", "guard", "let", "var", "for", "while", "repeat", "do", "try", "throw",
            "await", "in", "where", "as", "is", "default", "defer", "return", "nil", "withUnsafePointer",
            "withUnsafeMutablePointer", "withUnsafeBytes"}
OPERATORS = {".", "(", ")", ",", ":", "&", "|", "^", "~", "<<", ">>", "==", "!=", "!", "&&", "||"}
ACCESSOR_BLOCK = re.compile(r"(?:(?:mutating|nonmutating)\s+)?(get|set|_read|_modify|willSet|didSet|unsafeAddress|"
                            r"unsafeMutableAddress)\b\s*(?:\([^)]*\))?\s*\{")
DECL_START = re.compile(r"^\s*(?:@|(?:public|internal|private|fileprivate|package|open|static|var|let|func|init|"
                        r"subscript|case|typealias|struct|enum|class|extension|deinit|mutating|nonmutating)\b|#|\}|$)")


def _matching(text, i):
    """The index of the `}` matching the `{` at `i`."""
    depth = 0
    for k in range(i, len(text)):
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
            if depth == 0:
                return k
    return len(text)


def _body(code, start):
    """(body start, body end) of the declaration that starts at `start` in
    blanked code, or None when it has none (a stored property): its body is
    the first `{` at bracket depth 0, unless a line ends at depth 0 and the
    next starts another declaration first."""
    depth = 0
    k = start
    while k < len(code):
        c = code[k]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == "{" and depth == 0:
            return k + 1, _matching(code, k)
        elif c == "\n" and depth == 0:
            end = code.find("\n", k + 1)
            following = code[k + 1:end if end >= 0 else len(code)]
            if DECL_START.match(following) and not following.strip().startswith("{"):
                return None
        k += 1
    return None


def _statements(text):
    """`text` split into statements at newlines and semicolons at bracket
    depth 0; a line that opens with `.` or a binary operator continues the
    one before."""
    out, cur, depth = [], "", 0
    for c in text:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c in "\n;" and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += c
    out.append(cur)
    merged = []
    for s in (s.strip() for s in out):
        if not s:
            continue
        if merged and re.match(r"^(\.|&|\||\^|<<|>>|==|!=|&&|\|\|)", s):
            merged[-1] += " " + s
        else:
            merged.append(s)
    return merged


def _forwarded(expr):
    """The C names and raw values a trivial expression reads, as (constants,
    fields, raw), or None when it does more than forward: a call that isn't a
    conversion, a closure, control flow, a string, arithmetic."""
    toks = TOKEN.findall(expr)
    if toks and toks[0] == "return":
        toks = toks[1:]
    if not toks:
        return None
    constants, fields, raw = [], [], False
    for k, t in enumerate(toks):
        prev = toks[k - 1] if k else ""
        nxt = toks[k + 1] if k + 1 < len(toks) else ""
        if t in KEYWORDS:
            return None
        if re.match(r"^[A-Za-z_`]", t):
            name = t.strip("`")
            if nxt == "(" and name[0].islower() and name not in CALLS \
                    and not (prev == "." and name in UNIT_FACTORIES):
                return None
            if name in RAW:
                raw = True
            elif prev != "." and C_CONSTANT.match(name):
                constants.append(name)
            elif C_FIELD.match(name):
                fields.append(name)
        elif re.match(r"^\d|^0[xXbBoO]", t):
            continue
        elif t not in OPERATORS:
            return None
    return constants, fields, raw


def _accessor_blocks(body):
    """{accessor: text} for a property body: its accessor blocks, or
    {"get": body} for a body that is the getter itself."""
    if not ACCESSOR_BLOCK.match(body.lstrip()):
        return {"get": body}
    out, k = {}, 0
    while True:
        m = ACCESSOR_BLOCK.search(body, k)
        if not m:
            break
        brace = m.end() - 1
        end = _matching(body, brace)
        out[m.group(1)] = body[brace + 1:end]
        k = end + 1
    return out


def forwarding(text, line, kind):
    """(what, names) when the declaration on `line` (1-based) of a Swift
    file's `text` only forwards a C header value, else None. `kind` is the
    symbol graph's (`swift.property`, `swift.type.property`, `swift.init`,
    ...). `what` is "constant" (a static member that reads a C constant),
    "raw value" (an initializer that stores a raw value, or a raw value's
    getter) or "accessor" (an instance member that reads or writes a C
    struct's field or tests a C constant), and `names` the C names read.
    Only the lines the Darwin build compiles are read."""
    code, _ = strip_comments_and_strings(text)
    lines = code.split("\n")
    try:
        _, build, _ = platforms.swift_line_states(lines, SYSTEM_BUILD)
    except (ValueError, IndexError):
        build = [True] * len(lines)
    # The lines the build doesn't compile, and the directives, become blanks
    # of the same length, so that offsets hold.
    code = "\n".join(l if build[i] and not l.strip().startswith("#") else " " * len(l) for i, l in enumerate(lines))
    start = sum(len(l) + 1 for l in lines[:line - 1])
    span = _body(code, start)
    if not span:
        return None
    body = code[span[0]:span[1]]
    signature = code[start:span[0] - 1]
    if kind == "swift.init":
        stmts = _statements(body)
        names, raw = [], False
        for s in stmts:
            m = re.match(r"^(?:self\.)?([A-Za-z_]\w*)\s*=\s*(.+)$", s, re.S)
            d = re.match(r"^self\.init\((.*)\)$", s, re.S)
            if m and m.group(1) in RAW:
                got = _forwarded(m.group(2))
                raw = True
            elif d and re.search(r"\brawValue\s*:", d.group(1)):
                got = _forwarded(d.group(1))
                raw = True
            else:
                return None
            if got is None:
                return None
            names += got[0] + got[1]
        return ("raw value", names) if stmts and raw else None
    if kind in ("swift.property", "swift.type.property", "swift.subscript", "swift.method", "swift.type.method"):
        blocks = _accessor_blocks(body) if kind.endswith("property") or kind == "swift.subscript" else {"get": body}
        if set(blocks) - {"get", "set"} or "get" not in blocks:
            return None
        names, raw = [], False
        for which, block in blocks.items():
            stmts = _statements(block)
            if len(stmts) != 1:
                return None
            expr = stmts[0]
            if which == "set":
                m = re.match(r"^(?:self\.)?[A-Za-z_][\w.]*\s*=\s*(.+)$", expr, re.S)
                if not m:
                    return None
                expr = m.group(1)
            got = _forwarded(expr)
            if got is None:
                return None
            names += got[0] + got[1]
            raw = raw or got[2]
        constants = [n for n in names if C_CONSTANT.match(n)]
        fields = [n for n in names if C_FIELD.match(n)]
        static = kind.startswith("swift.type.")
        if static and constants and not fields:
            return "constant", list(dict.fromkeys(constants))
        if not static and (fields or constants):
            return "accessor", list(dict.fromkeys(fields + constants))
        if not static and raw and re.search(r"\b(?:var|let)\s+rawValue\b", signature):
            return "raw value", []
        return None
    return None
