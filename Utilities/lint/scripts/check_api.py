#!/usr/bin/env python3
"""lint's api check: the public declarations main..HEAD adds, from
api-delta's output (its symbol-graph entries and the scanner's declarations
the graphs can't show), against the conventions.

  api/availability         error    no `@available(System 199, *)` on the declaration or an enclosing scope
  api/doc-sentence         error    a "corresponding C" sentence the coverage tools can't read: derive.py's
                                    grammar reads no C name from it, or its form isn't theirs ("The
                                    corresponding C parameter of `X` is `y`.")
  api/doc-sentence-missing warning  its code wraps C, by System's conventions, and its doc names none: it
                                    reaches a `system_*` wrapper or a `_CONSTANT` (Constants*.swift)
                                    through `_`-prefixed helpers, or it's a Swift-named accessor in an
                                    `extension CInterop.X`
  api/aeic                 error    a header constant (its doc names a C constant or macro, or it forwards a
                                    `_CONSTANT`) that isn't `@_alwaysEmitIntoClient`
  api/typed-throws         error    it throws, and not `throws(Errno)` (rethrows and a generic error type pass)
  api/c-struct-property    error    a stored property whose type is a C struct or union with no Swift-named
                                    accessors, other than a `rawValue`

The doc sentences are read with adopter-coverage's derive.py (sentences,
parse), the reading the coverage tools and api-graph derive coverage from.
Attributes come from api-delta's scanner, run on HEAD's commit (the
ledger's system_api, cached in .build/lint/system). C-struct types come from
the symbol graphs api-delta keeps: the property's type, or the CInterop
typealias it names, resolves to a `c:@S@`, `c:@SA@`, `c:@U@` or `c:@UA@` USR.
A typedef's USR (`c:@T@fsid_t`) can't tell a struct from a scalar, so such
types aren't judged.

api-delta's output is --api-delta, else .build/api-delta when it compares
main with HEAD, else a fresh run into .build/lint/api-delta (about 40 s;
--no-run refuses instead). allowlist.ini exempts declarations, by rule and
path (a shell glob), each with a reason.
"""

import sys

sys.dont_write_bytecode = True

import collections  # noqa: E402
import configparser  # noqa: E402
import fnmatch  # noqa: E402
import glob  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

from lintcore import TOOL, UTILITIES, CheckError, Finding, commit_of, git  # noqa: E402

RULES = [
    ("api/availability", "error", "an added public declaration without @available(System 199, *)"),
    ("api/doc-sentence", "error", "a corresponding-C doc sentence the coverage tools can't read"),
    ("api/doc-sentence-missing", "warning", "a declaration that wraps C by System's conventions with no sentence"),
    ("api/aeic", "error", "a header constant that isn't @_alwaysEmitIntoClient"),
    ("api/typed-throws", "error", "a new throwing declaration that doesn't throw(Errno)"),
    ("api/c-struct-property", "error", "a public stored property of a C struct type a client must reach into"),
]
ALLOWLIST = os.path.join(TOOL, "allowlist.ini")
SYSTEM_DIRS = ("Sources/System", "Sources/SystemSockets", "Sources/SystemWinSocks")
C_STRUCT_USR = re.compile(r"^c:@(?:S|SA|U|UA)@")
CORRESPONDING = re.compile(r"\bcorresponding\s+C\b", re.I)
IDENT = re.compile(r"(?<![\w$])([A-Za-z_]\w*)")
CONSTANT_DEF = re.compile(r"\bvar\s+(_[A-Za-z][A-Za-z0-9_]*)\s*:\s*[\w.<>?\[\] ]+\{\s*([A-Za-z_]\w*)\s*\}")
DECL_START = re.compile(r"\b(?:func|var|let|init[?!]?|subscript)\b\s*`?([A-Za-z_]\w*)?")


# ---------------------------------------------------------------- inputs

def delta_dir(ctx):
    """An api-delta output for main..HEAD: (directory, meta)."""
    main = commit_of(ctx.repo, "main")
    head_tree = git(ctx.repo, "rev-parse", f"{ctx.head}:Sources").strip()

    def current(d):
        try:
            with open(os.path.join(d, "api-delta.json"), encoding="utf-8") as f:
                meta = json.load(f)["meta"]
        except (OSError, ValueError, KeyError):
            return None
        if meta.get("baseCommit") != main:
            return None
        if meta.get("headCommit") != ctx.head:
            tree = git(ctx.repo, "rev-parse", f"{meta.get('headCommit')}:Sources", ok=(0, 128)).strip()
            if tree != head_tree:
                return None
        return meta
    if ctx.args.api_delta:
        meta = current(ctx.args.api_delta)
        if not meta:
            raise CheckError(f"{ctx.args.api_delta} isn't api-delta's output for main..HEAD")
        return ctx.args.api_delta, meta
    for d in (os.path.join(ctx.repo, ".build", "api-delta"), os.path.join(ctx.work, "api-delta")):
        meta = current(d)
        if meta:
            return d, meta
    if ctx.args.no_run:
        raise CheckError("no api-delta output for main..HEAD (run BASE_REF=main HEAD_REF=HEAD "
                         "Utilities/api-delta/regenerate.sh, or drop --no-run)")
    out = os.path.join(ctx.work, "api-delta")
    env = dict(os.environ, BASE_REF="main", HEAD_REF="HEAD", API_DELTA_OUT=out,
               API_DELTA_WORK=os.path.join(ctx.work, "api-delta-work"))
    os.makedirs(ctx.work, exist_ok=True)
    log = os.path.join(ctx.work, "api-delta.log")
    with open(log, "w") as f:
        p = subprocess.run([os.path.join(UTILITIES, "api-delta", "regenerate.sh")], cwd=ctx.repo, env=env,
                           stdout=f, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise CheckError(f"api-delta failed; see {log}")
    ctx.note(f"api: ran api-delta for main..HEAD into {os.path.relpath(out, ctx.repo)}")
    meta = current(out)
    if not meta:
        raise CheckError(f"api-delta's output in {out} isn't for main..HEAD")
    return out, meta


def load_allowlist(path=ALLOWLIST):
    """{rule: [(path glob, reason)]}."""
    cp = configparser.ConfigParser(interpolation=None, delimiters=("=",), comment_prefixes=("#",),
                                   inline_comment_prefixes=None, strict=True, default_section="__none__")
    cp.optionxform = str
    if os.path.isfile(path):
        cp.read(path, encoding="utf-8")
    out = {}
    for sec in cp.sections():
        out[sec] = []
        for k, v in cp.items(sec):
            reason = " ".join(v.split())
            if not reason:
                raise CheckError(f"{os.path.basename(path)}: [{sec}] {k} has no reason")
            out[sec].append((k.strip(), reason))
    return out


def allowed(allow, rule, key):
    """The reason allowlist.ini gives for a declaration's path (or, for
    typed-throws, `throws:<error type>`) under a rule, or None. A path
    entry is a shell glob; `[` and `]` match themselves."""
    for pat, reason in allow.get(rule, []):
        if fnmatch.fnmatchcase(key, pat.replace("[", "[[]")):
            return reason
    return None


class Source:
    """System's Swift sources at a commit, raw and blanked."""

    def __init__(self, repo=None, commit=None, texts=None):
        import status as st
        from scan_sources import strip_comments_and_strings
        if texts is None:
            files = [f for f in st.tree_files(repo, commit) if f.endswith(".swift") and f.startswith(SYSTEM_DIRS)]
            blobs = st.read_blobs(repo, [f"{commit}:{f}" for f in files])
            texts = {f: blobs[f"{commit}:{f}"] for f in files if f"{commit}:{f}" in blobs}
        self.raw, self.code = {}, {}
        for f, text in texts.items():
            self.raw[f] = text.split("\n")
            self.code[f] = strip_comments_and_strings(text)[0].split("\n")

    def body(self, f, line):
        """The text of the declaration at (file, 1-based line), through its
        body's closing brace (blanked), or its line when it has none."""
        code = self.code.get(f)
        if not code or line < 1 or line > len(code):
            return ""
        depth, opened, out = 0, False, []
        for j in range(line - 1, min(len(code), line - 1 + 400)):
            text = code[j]
            if not opened and j > line - 1 and depth == 0 and DECL_START.search(text):
                break
            out.append(text)
            for ch in text:
                if ch == "{":
                    depth += 1
                    opened = True
                elif ch == "}":
                    depth -= 1
            if opened and depth <= 0:
                break
        return "\n".join(out)


def module_dir(f):
    """The module directory of a source path: the SYSTEM_DIRS entry it's in."""
    return next((d for d in SYSTEM_DIRS if f.startswith(d + "/")), "")


class Reach:
    """What a declaration's code reaches by System's three-layer
    convention: `system_foo` calls the C function foo, `_FOO` in
    Constants*.swift forwards the C constant FOO, and a `_foo(...)` helper
    (layer 2) is followed once, when the declaration's module declares one
    function of that name, to the `system_` calls and constants in its body.
    Helpers of common or overloaded names aren't followed: by name alone
    they lead anywhere. A helper is looked up in the declaration's own
    module, since one module can't call another's internal helpers, and
    SystemWinSocks repeats SystemSockets' (`_bind`, `_accept`)."""

    def __init__(self, source):
        self.constants = {}
        bodies = collections.defaultdict(list)
        for f, code in source.code.items():
            text = "\n".join(code)
            if os.path.basename(f).startswith("Constants"):
                for m in CONSTANT_DEF.finditer(text):
                    self.constants[m.group(1)] = m.group(2)
            for i, line in enumerate(code, 1):
                for m in re.finditer(r"\bfunc\s+`?(_[a-z]\w*)\s*[(<]", line):
                    bodies[(module_dir(f), m.group(1))].append(source.body(f, i))
        self.helpers = {k: b[0] for k, b in bodies.items() if len(b) == 1}

    def direct(self, body):
        names = set(IDENT.findall(body))
        funcs = {n[len("system_"):] for n in names if n.startswith("system_")}
        consts = {self.constants[n] for n in names if n in self.constants}
        return funcs, consts, names

    def reach(self, body, f=""):
        """(C functions, C constants) a body in file f reaches."""
        funcs, consts, names = self.direct(body)
        for n in names:
            helper = self.helpers.get((module_dir(f), n))
            if helper is not None and re.search(rf"\b{re.escape(n)}\s*\(", body):
                f2, c2, _ = self.direct(helper)
                funcs |= f2
                consts |= c2
        return funcs, consts


class Graphs:
    """The head symbol graphs api-delta kept: symbols by USR."""

    def __init__(self, directory=None, symbols=()):
        self.symbols = {}
        for p in glob.glob(os.path.join(directory, "symbolgraphs", "head", "*.symbols.json")) if directory else []:
            with open(p, encoding="utf-8") as f:
                for s in json.load(f).get("symbols", []):
                    self.symbols.setdefault(s["identifier"]["precise"], s)
        for s in symbols:
            self.symbols.setdefault(s["identifier"]["precise"], s)

    def type_usr(self, usr):
        """The C record USR a stored property's type names, directly or
        through a typealias, or None; and the text of its type."""
        s = self.symbols.get(usr)
        if not s:
            return None, None
        frags = s.get("declarationFragments") or []
        after, seen_colon = [], False
        for fr in frags:
            if not seen_colon:
                if fr["kind"] == "text" and ":" in fr["spelling"]:
                    seen_colon = True
                continue
            after.append(fr)
        text = "".join(fr["spelling"] for fr in after).strip()
        if "<" in text or "(" in text or "[" in text:
            return None, text
        types = [fr for fr in after if fr["kind"] == "typeIdentifier"]
        if not types:
            return None, text
        last = types[-1].get("preciseIdentifier") or ""
        if C_STRUCT_USR.match(last):
            return last, text
        alias = self.symbols.get(last)
        if alias and alias["kind"]["identifier"] == "swift.typealias":
            targets = [fr for fr in alias.get("declarationFragments") or [] if fr["kind"] == "typeIdentifier"]
            if len(targets) == 1 and C_STRUCT_USR.match(targets[0].get("preciseIdentifier") or ""):
                return targets[0]["preciseIdentifier"], text
        return None, text

    def alias_targets(self):
        """{CInterop alias path: C record USR}."""
        out = {}
        for s in self.symbols.values():
            if s["kind"]["identifier"] != "swift.typealias" or s["pathComponents"][:1] != ["CInterop"]:
                continue
            ts = [fr for fr in s.get("declarationFragments") or [] if fr["kind"] == "typeIdentifier"]
            if len(ts) == 1 and C_STRUCT_USR.match(ts[0].get("preciseIdentifier") or ""):
                out[".".join(s["pathComponents"])] = ts[0]["preciseIdentifier"]
        return out


# ---------------------------------------------------------------- declarations

class Decl:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def added_declarations(delta, scan, source):
    import derive
    index = {(d["file"], d["line"]): d for d in scan["declarations"]}
    out = []
    for e in delta["entries"]:
        if e["status"] != "added":
            continue
        d = index.get((e["file"], e["line"]))
        out.append(Decl(path=e["path"], kind=e["kind"], decl=e["decl"], file=e["file"], line=e["line"],
                        attrs=(d or {}).get("attributes", []),
                        availability=None if d is None else (d.get("availability", []) + d.get("scopeAvailability", [])),
                        system=e.get("system"), doc=(e.get("docText") or "").split("\n"), scan=d, usr=e.get("usr"),
                        deprecated=bool(e.get("deprecated")), name=e["title"].split("(")[0], hidden=None,
                        kw=(d or {}).get("kw")))
    for d in delta.get("hiddenFromGraphs", {}).get("added", []):
        raw = source.raw.get(d["file"], [])
        out.append(Decl(path=".".join(d["scopes"] + [d["name"]]), kind=d["kw"], decl=d["signature"], file=d["file"],
                        line=d["line"], attrs=d.get("attributes", []),
                        availability=d.get("availability", []) + d.get("scopeAvailability", []), system=None,
                        doc=derive.doc_comment(raw, d["line"]) if raw else [], scan=d, usr=None,
                        deprecated=bool(d.get("deprecated")), name=d["name"], hidden=d.get("hiddenClass"),
                        kw=d["kw"]))
    return out


def sentence_at(text, i, limit=160):
    """The sentence from i to the first period outside backticks that ends
    one, as derive.py's sentences() reads them, shortened past limit."""
    tick = False
    for j in range(i, len(text)):
        ch = text[j]
        if ch == "`":
            tick = not tick
        elif ch == "." and not tick and (j + 1 == len(text) or text[j + 1].isspace()):
            out = text[i:j + 1]
            break
    else:
        out = text[i:]
    return out if len(out) <= limit else out[:limit - 1].rstrip() + "…"


def skipped(d):
    """Declarations that aren't API to judge: fix-it stubs, underscored and
    deprecated ones, public members of non-public types."""
    if d.hidden in ("unavailable", "underscored", "nonpublic-scope"):
        return True
    if d.name.startswith("_") or d.deprecated:
        return True
    if d.scan and (d.scan.get("unavailable") or d.scan.get("underscored")):
        return True
    return False


def own_effects(decl):
    """The text of a function's own effects (between its parameter clause and
    its result), or a property's accessor block; None if it has none."""
    s = re.sub(r"@\w+(\([^()]*\))?", " ", decl)
    m = re.search(r"\b(func|init[?!]?|subscript)\b", s)
    if m:
        i = s.find("(", m.end())
        if i < 0:
            return None
        depth = 0
        for j in range(i, len(s)):
            if s[j] == "(":
                depth += 1
            elif s[j] == ")":
                depth -= 1
                if depth == 0:
                    rest = s[j + 1:]
                    end = min([k for k in (rest.find("->"), rest.find("{"), rest.find(" where ")) if k >= 0]
                              or [len(rest)])
                    return rest[:end]
        return None
    m = re.search(r"\{([^{}]*)\}\s*$", s)
    return m.group(1) if m else None


def generic_names(decl):
    m = re.search(r"\b(?:func|init[?!]?|subscript)\s*[\w`]*\s*<([^>]*)>", decl)
    return {g.split(":")[0].strip() for g in m.group(1).split(",")} if m else set()


# ---------------------------------------------------------------- the rules

def run(ctx):
    import ledger
    directory, meta = delta_dir(ctx)
    with open(os.path.join(directory, "api-delta.json"), encoding="utf-8") as f:
        delta = json.load(f)
    head = meta["headCommit"]
    ctx.note(f"api: api-delta {os.path.relpath(directory, ctx.repo)} ({meta['baseRef']} {meta['baseCommit'][:10]} → "
             f"{meta['headRef']} {head[:10]})")
    work = os.path.join(ctx.work, "system")
    os.makedirs(work, exist_ok=True)
    scan, _ = ledger.system_api(ctx.repo, head, work)
    findings, used = check(delta, scan, Source(ctx.repo, head), Graphs(directory), load_allowlist())
    for rule, n in sorted(used.items()):
        ctx.note(f"api: allowlist.ini exempted {n} for {rule}")
    return findings


def check(delta, scan, source, graphs, allow):
    """(findings, {rule: declarations the allowlist exempted}) for an
    api-delta document, the scanner's declarations at its head commit,
    System's sources there (Source) and its symbol graphs (Graphs)."""
    import derive
    reach = Reach(source)
    aliases = graphs.alias_targets()
    accessor_records = {aliases[s] for s in {d["scopes"][0] for d in scan["declarations"]
                                             if d["scopes"] and d["scopes"][0].startswith("CInterop.")
                                             and d["scopeKinds"][:1] == ["extension"]} if s in aliases}
    findings, used = [], collections.Counter()

    def report(d, rule, level, message, keys=(), **extra):
        why = allowed(allow, rule, d.path) or next((r for r in (allowed(allow, rule, k) for k in keys) if r), None)
        if why:
            used[rule] += 1
            return
        findings.append(Finding(d.file, d.line, rule, level, f"`{d.path}`: {message}", declaration=d.path, **extra))

    for d in added_declarations(delta, scan, source):
        if skipped(d):
            continue
        # availability
        if d.availability is None:
            if d.system != "199":
                report(d, "api/availability", "error", f"available as System {d.system or 'none'}, not System 199")
        elif not any(re.search(r"\bSystem 199\b", a) for a in d.availability):
            spelled = ", ".join(dict.fromkeys(d.availability)) or "no @available"
            report(d, "api/availability", "error", f"{spelled}; new API is `@available(System 199, *)`")
        # doc sentences
        said = derive.sentences(d.doc)
        joined = " ".join(d.doc)
        for kind_word, _verb, text, body in said:
            names, _ = derive.parse(kind_word, body)
            if not names:
                report(d, "api/doc-sentence", "error", f"derive.py reads no C name from “{text}”")
        for m in CORRESPONDING.finditer(joined):
            start = max(0, m.start() - 4)
            if derive.HEAD.match(joined, start):
                continue
            report(d, "api/doc-sentence", "error",
                   f"“{sentence_at(joined, start if joined[start:m.start()].lower() == 'the ' else m.start())}” "
                   "isn't a form the coverage tools read (“The corresponding C function is `x`.”, or constant, "
                   "type, field, macro, variable)")
        body = source.body(d.file, d.line) if d.kw in ("func", "init", "var", "let", "subscript") or \
            d.kind in ("swift.func", "swift.method", "swift.type.method", "swift.init", "swift.property",
                       "swift.type.property", "swift.subscript", "swift.func.op") else ""
        funcs, consts = reach.reach(body, d.file) if body else (set(), set())
        accessor = bool(d.scan and d.scan["scopes"] and d.scan["scopes"][0].startswith("CInterop.")
                        and d.scan["kw"] in ("var", "let"))
        if not said and (funcs or consts or accessor):
            what = []
            if funcs:
                what.append("C function" + ("s " if len(funcs) > 1 else " ") + ", ".join(f"`{x}`" for x in sorted(funcs)[:4]))
            if consts:
                what.append("C constant" + ("s " if len(consts) > 1 else " ") + ", ".join(f"`{x}`" for x in sorted(consts)[:4]))
            if accessor and not what:
                what.append(f"a field of `{d.scan['scopes'][0]}` (an accessor)")
            report(d, "api/doc-sentence-missing", "warning",
                   "its code reaches " + " and ".join(what) + ", and its doc names no C interface "
                   "(“The corresponding C … is `x`.”)", functions=sorted(funcs), constants=sorted(consts))
        # header constants: a static property whose short body forwards a
        # C constant (a `_CONSTANT`, or the one its doc sentence names)
        static = d.kind == "swift.type.property" or (d.scan is not None and d.kw in ("var", "let") and
                                                     any(m in ("static", "class") for m in d.scan["modifiers"]))
        if static:
            subject = []
            for kind_word, _v, _t, b in said:
                names, _ = derive.parse(kind_word, b)
                subject += [ck for _n, _p, ck, role in names if role == "subject"]
            short = body.count("\n") <= 3
            constant = short and not funcs and (bool(consts) or any(k in ("constant", "macro") for k in subject))
            aeic = any(a.startswith("@_alwaysEmitIntoClient") for a in d.attrs)
            if constant and not aeic:
                stored = d.kw == "let" or (d.kw == "var" and "{" not in body)
                report(d, "api/aeic", "error",
                       "a header constant, " + ("stored: make it a computed property with "
                                                "`@_alwaysEmitIntoClient`" if stored else
                                                "not `@_alwaysEmitIntoClient`"))
        # typed throws
        eff = own_effects(d.decl or "")
        if eff and re.search(r"\bthrows\b", eff):
            m = re.search(r"\bthrows\s*\(\s*([^)]*?)\s*\)", eff)
            if not m:
                report(d, "api/typed-throws", "error", "throws untyped; new API throws `throws(Errno)`")
            elif m.group(1) not in ("Errno", "SystemPackage.Errno") and m.group(1) not in generic_names(d.decl):
                report(d, "api/typed-throws", "error", f"throws `{m.group(1)}`, not `Errno`",
                       keys=(f"throws:{m.group(1)}",))
        # C-struct stored properties
        if d.usr and d.kind in ("swift.property", "swift.type.property") and "{" not in (d.decl or "") \
                and d.name != "rawValue":
            record, text = graphs.type_usr(d.usr)
            if record and record not in accessor_records:
                report(d, "api/c-struct-property", "error",
                       f"a stored `{text}`, a C {'union' if '@U' in record else 'struct'} with no Swift-named "
                       "accessors, so a client must reach into its C fields")
    return findings, used
