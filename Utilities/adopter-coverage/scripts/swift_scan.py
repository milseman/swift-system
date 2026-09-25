#!/usr/bin/env python3
"""Lexical scan of a package's Swift sources.

For every file it records, per line, the platforms that compile the line
(platforms.swift_line_states, with the target's platforms.Model) and
whether the Darwin index build compiled it. It then lists *candidate* references to C or OS symbols: identifiers
that aren't keywords, member accesses, argument labels, or names bound in
an enclosing scope. extract.py decides which candidates are OS symbols,
using vocabularies from the index store.

Scopes are tracked with braces. Each `{` opens a type, function, closure,
or block scope; parameters, closure parameters, generic parameters and
`let`/`var`/`for`/`case let` bindings are recorded in the scope they
belong to. A candidate is "bound" when a binding of that name is visible
from it, or when it names a member of an enclosing type (members are
collected from every file, since extensions spread types across files).

This is a scanner, not a parser. It doesn't respect declaration order
within a scope, and it can't see members inherited from protocols or
superclasses; extract.py measures its accuracy against the index on the
lines the Darwin build compiled.

Flags the package file calls false (`false-flags`, such as Foundation's
FOUNDATION_FRAMEWORK) are F everywhere in the model; a file that tests one
is evaluated a second time without them, and the lines only that hides are
counted, so the report can say how much code no modeled build compiles.
"""

import sys

sys.dont_write_bytecode = True  # no __pycache__, here or in api-delta's scripts

import collections
import os
import re

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "api-delta", "scripts"))
from scan_sources import strip_comments_and_strings  # noqa: E402

import platforms  # noqa: E402

KEYWORDS = set("""
associatedtype class deinit enum extension fileprivate func import init inout internal let open operator
private precedencegroup protocol public rethrows static struct subscript typealias var break case catch
continue default defer do else fallthrough for guard if in repeat return throw switch where while Any as
await false is nil self Self super throws true try _ associativity convenience didSet dynamic final get
indirect infix lazy left mutating none nonmutating optional override postfix precedence prefix Protocol
required right set Type unowned weak willSet some any async actor nonisolated isolated consuming borrowing
consume copy discard each package macro sending unsafe yield then __consuming __owned __shared nonsending
""".split())

DECL_KW = {"func", "var", "let", "case", "typealias", "struct", "class", "enum", "protocol", "actor",
           "associatedtype", "init", "subscript", "deinit", "macro"}
TYPE_KW = {"struct", "class", "enum", "protocol", "actor", "extension"}
FUNC_KW = {"func", "init", "deinit", "subscript"}
CONTROL_KW = {"if", "guard", "for", "while", "switch", "do", "catch", "else", "repeat", "defer"}
ACCESSOR_KW = {"get", "set", "willSet", "didSet", "_read", "_modify", "unsafeAddress", "unsafeMutableAddress"}

TOKEN = re.compile(r"""
    (?P<nl>\n)
  | (?P<ws>[ \t\r\f\v]+)
  | (?P<id>`[^`\n]+`|[A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z0-9_]+)
  | (?P<num>\d[\w.]*)
  | (?P<p>\.\.\.|\.\.<|->|&&|\|\||==|!=|<=|>=|[{}()\[\],:;.?!=<>@#&|^~+\-*/%\\"'])
  | (?P<other>.)
""", re.X)


class Tok:
    __slots__ = ("kind", "text", "line", "col")

    def __init__(self, kind, text, line, col):
        self.kind, self.text, self.line, self.col = kind, text, line, col

    def __repr__(self):
        return f"{self.text}@{self.line}"


def tokenize(code):
    toks = []
    line, line_start = 1, 0
    for m in TOKEN.finditer(code):
        kind = m.lastgroup
        if kind == "nl":
            line += 1
            line_start = m.end()
            continue
        if kind == "ws":
            continue
        text = m.group(kind)
        if kind == "id" and text.startswith("`"):
            text = text[1:-1]
        toks.append(Tok(kind, text, line, m.start() - line_start + 1))
    return toks


def directive_lines(code_lines):
    """Lines that are compiler directives (#if, #error, ...), which the
    scanner skips."""
    out = set()
    for i, l in enumerate(code_lines):
        if l.lstrip().startswith("#") and re.match(r"\s*#(if|elseif|else|endif|error|warning|sourceLocation)\b", l):
            out.add(i + 1)
    return out


class Scope:
    __slots__ = ("kind", "name", "start", "end", "bindings", "parent", "decl_line")

    def __init__(self, kind, name, start, parent, decl_line=None):
        self.kind, self.name, self.start, self.parent = kind, name, start, parent
        self.end = None
        self.bindings = set()
        self.decl_line = decl_line if decl_line is not None else start


# A line break is not a statement boundary when the line before ends with,
# or the line after starts with, one of these.
CONT_END = {",", "(", "[", "->", "=", ":", "&&", "||", "+", "-", "*", "/", "|", "&", "<", ".", "where", "in",
            "throws", "rethrows", "async", "as", "is", "try", "await", "return"}
CONT_START = {".", "->", "throws", "rethrows", "async", "where", "&&", "||", ")", "]", ",", ":", "=", "?", "{",
              "+", "-", "*", "/", "|", "&", "as", "is", "else", ">"}


def header_tokens(toks, open_index):
    """Tokens of the statement that ends at the `{` at open_index: back to
    the previous `{`, `}` or `;` at the same nesting, or to a line break
    that ends a statement. Attribute-only lines belong to the statement."""
    j = open_index - 1
    depth = 0
    while j >= 0:
        t = toks[j]
        # depth counts the brackets closed in toks[j+1:open_index].
        if depth == 0 and j + 1 < open_index and toks[j + 1].line > t.line:
            nxt = toks[j + 1]
            if t.text not in CONT_END and nxt.text not in CONT_START and not _attr_line_ends_at(toks, j):
                break
        if t.text in (")", "]"):
            depth += 1
        elif t.text in ("(", "["):
            if depth == 0:
                break
            depth -= 1
        elif depth == 0 and t.text in ("{", "}", ";"):
            break
        j -= 1
    return toks[j + 1:open_index]


def _attr_line_ends_at(toks, j):
    """Whether the line ending at token j holds only attributes, such as
    `@inlinable` or `@available(macOS 10.15, *)`."""
    line = toks[j].line
    k = j
    while k > 0 and toks[k - 1].line == line:
        k -= 1
    while k <= j:
        if toks[k].text != "@" or k + 1 > j or toks[k + 1].kind != "id":
            return False
        k += 2
        if k <= j and toks[k].text == "(":
            depth = 0
            while k <= j:
                if toks[k].text == "(":
                    depth += 1
                elif toks[k].text == ")":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            k += 1
    return True


def param_names(toks):
    """Names bound by the first parameter clause in toks, e.g.
    `(label name: T, _ other: U)` -> {label, name, _, other}."""
    names = set()
    try:
        start = next(i for i, t in enumerate(toks) if t.text == "(")
    except StopIteration:
        return names
    depth, chunk = 0, []
    for t in toks[start:]:
        if t.text in ("(", "[", "<"):
            depth += 1
            if depth == 1:
                continue
        elif t.text in (")", "]", ">"):
            depth -= 1
            if depth == 0:
                names |= _param_chunk(chunk)
                break
        if depth == 1 and t.text == ",":
            names |= _param_chunk(chunk)
            chunk = []
            continue
        if depth >= 1:
            chunk.append(t)
    return names


def _param_chunk(chunk):
    out = set()
    for i, t in enumerate(chunk):
        if t.text == ":":
            for u in chunk[:i]:
                if u.kind == "id" and u.text not in ("inout", "borrowing", "consuming", "sending", "isolated"):
                    out.add(u.text)
            break
    return out


def generic_names(toks):
    """Generic parameter names declared by a header: the `<...>` right after
    the declared name (`func f<T>`, `struct S<T>`, `init<T>`)."""
    out = set()
    k = decl_start(toks)
    if k >= len(toks):
        return out
    j = k + 1
    if toks[k].text in ("func", "struct", "class", "enum", "protocol", "actor", "typealias"):
        j = k + 2
    if j >= len(toks) or toks[j].text != "<":
        return out
    depth = 0
    expect = True
    for u in toks[j:]:
        if u.text == "<":
            depth += 1
            continue
        if u.text == ">":
            depth -= 1
            if depth == 0:
                break
            continue
        if depth == 1 and u.text == ",":
            expect = True
            continue
        if depth == 1 and expect and u.kind == "id" and u.text != "each":
            out.add(u.text)
            expect = False
    return out


def body_brace(toks, k):
    """Index of the `{` that opens the block a statement's bindings belong
    to: the first one after token k outside parentheses and brackets, so
    that `for (a, b) in xs.sorted(by: { ... }) {` binds a and b in the loop's
    body rather than in the closure. None if the statement ends first."""
    depth = 0
    for j in range(k + 1, min(len(toks), k + 400)):
        t = toks[j]
        if t.text in ("(", "["):
            depth += 1
        elif t.text in (")", "]"):
            depth -= 1
            if depth < 0:
                return None
        elif t.text == "{" and depth == 0:
            return j
        elif t.text in ("}", ";") and depth == 0:
            return None
    return None


def pattern_sites(toks, i):
    """Token indices of the names bound by the `let`/`var` pattern at i:
    `let x`, `let (a, b)`, `case .some(let x)`, and each name of
    `var a: [UInt8] = [], b: [UInt8] = []`."""
    out = set()
    depth = 0
    j = i + 1
    while j < len(toks):
        t = toks[j]
        if t.text in ("(", "["):
            depth += 1
        elif t.text in (")", "]"):
            if depth == 0:
                break
            depth -= 1
        elif depth == 0 and t.text in (":", "=") and toks[i].text in ("let", "var") \
                and not (i > 0 and toks[i - 1].line == toks[i].line
                         and toks[i - 1].text in ("if", "guard", "while", ",", "case", "(")):
            # A type annotation or an initializer; another binding may
            # follow it after a comma on the same line.
            k, d = j + 1, 0
            while k < len(toks) and toks[k].line == t.line:
                if toks[k].text in ("(", "[", "<", "{"):
                    d += 1
                elif toks[k].text in (")", "]", ">", "}"):
                    d -= 1
                    if d < 0:
                        break
                elif d == 0 and toks[k].text == ",":
                    break
                k += 1
            if k < len(toks) and toks[k].text == "," and toks[k].line == t.line and d == 0:
                j = k + 1
                continue
            break
        elif depth == 0 and t.text in ("=", ":", "{", "}", ";", "in", ","):
            break
        elif t.kind == "id" and t.text not in KEYWORDS and toks[j - 1].text != ".":
            out.add(j)
        j += 1
    return out


def param_sites(toks, open_paren):
    """Token indices of the labels and names in the parameter clause that
    starts at open_paren."""
    out = set()
    depth = 0
    chunk = []
    for j in range(open_paren, len(toks)):
        t = toks[j]
        if t.text in ("(", "[", "<"):
            depth += 1
            if depth == 1:
                continue
        elif t.text in (")", "]", ">"):
            depth -= 1
            if depth == 0:
                out |= _chunk_sites(toks, chunk)
                break
        if depth == 1 and t.text == ",":
            out |= _chunk_sites(toks, chunk)
            chunk = []
            continue
        if depth >= 1:
            chunk.append(j)
    return out


def _chunk_sites(toks, chunk):
    """The label and name positions of one parameter: identifiers before
    its `:`."""
    out = set()
    for j in chunk:
        if toks[j].text == ":":
            return out
        if toks[j].kind == "id":
            out.add(j)
    return set()


def closure_params(toks, open_index):
    """Parameters of a closure whose `{` is at open_index: identifiers
    between the brace and a top-level `in`, if there is one."""
    out = set()
    depth = 0
    j = open_index + 1
    while j < len(toks) and j < open_index + 60:
        t = toks[j]
        if t.text in ("(", "["):
            depth += 1
        elif t.text in (")", "]"):
            depth -= 1
        elif t.text in ("{", "}"):
            return set()
        elif t.text == "in" and depth == 0:
            return out
        elif t.kind == "id" and t.text not in KEYWORDS and toks[j - 1].text not in (".", ":", "->"):
            out.add(t.text)
        j += 1
    return set()


MODIFIERS = {"public", "private", "fileprivate", "internal", "open", "package", "static", "final", "mutating",
             "nonmutating", "override", "convenience", "required", "indirect", "lazy", "weak", "unowned",
             "nonisolated", "dynamic", "optional", "prefix", "postfix", "infix", "consuming", "borrowing",
             "__consuming", "distributed", "isolated"}


def decl_start(header):
    """Index of the declaration keyword in a statement's tokens, after its
    attributes and modifiers (and their parenthesized arguments)."""
    k = 0
    while k < len(header):
        t = header[k]
        if t.text == "@" and k + 1 < len(header):
            k += 2
            if k < len(header) and header[k].text == "(" and header[k].line == header[k - 1].line:
                depth = 0
                while k < len(header):
                    if header[k].text == "(":
                        depth += 1
                    elif header[k].text == ")":
                        depth -= 1
                        if depth == 0:
                            k += 1
                            break
                    k += 1
            continue
        if t.kind == "id" and (t.text in MODIFIERS or
                               (t.text == "class" and k + 1 < len(header) and header[k + 1].text in
                                ("func", "var", "let", "subscript", "init"))):
            k += 1
            if k < len(header) and header[k].text == "(" and header[k - 1].text in MODIFIERS:
                # `private(set)`, `nonisolated(unsafe)`
                while k < len(header) and header[k].text != ")":
                    k += 1
                k += 1
            continue
        return k
    return k


def classify_open(header):
    """(kind, name) for the scope a `{` opens, from its statement's tokens."""
    if not header:
        return "closure", None
    k = decl_start(header)
    if k >= len(header):
        return "closure", None
    t = header[k]
    nxt = header[k + 1] if k + 1 < len(header) else None
    if t.kind == "id" and t.text in TYPE_KW:
        # `extension Foo.Bar where ...`, `struct Foo<T>: P`
        name_toks = []
        for u in header[k + 1:]:
            if u.kind == "id" or u.text == ".":
                name_toks.append(u.text)
            else:
                break
        return "type", "".join(name_toks)
    if t.kind == "id" and t.text == "func":
        return "func", nxt.text if nxt is not None else "?"
    if t.kind == "id" and t.text in FUNC_KW:
        return "func", t.text
    if t.kind == "id" and t.text in ACCESSOR_KW:
        return "block", t.text
    if t.kind == "id" and t.text in CONTROL_KW:
        return "block", t.text
    if t.kind == "id" and t.text in ("var", "let"):
        nm = nxt.text if nxt is not None else "?"
        if header[-1].text == "=":
            return "closure", nm
        if "=" not in [h.text for h in header[k:]]:
            return "func", nm
        return "closure", nm
    return "closure", None


def where_names(header):
    """The names a type header's `where` clause constrains, which are the
    extended type's generic parameters or associated types:
    `extension Optional where Wrapped == String` -> {Wrapped}. As (name,
    token offset in header) pairs."""
    out = []
    depth = 0
    k = None
    for j, u in enumerate(header):
        if u.text == "<":
            depth += 1
        elif u.text == ">":
            depth -= 1
        elif depth == 0 and u.kind == "id" and u.text == "where":
            k = j
            break
    if k is None:
        return out
    expect = True
    for j in range(k + 1, len(header)):
        u = header[j]
        if u.text == "<":
            depth += 1
        elif u.text == ">":
            depth -= 1
        elif depth == 0 and u.text == ",":
            expect = True
        elif depth == 0 and expect and u.kind == "id":
            out.append((u.text, j))
            expect = False
    return out


def inherited_types(header):
    """Types named in a type declaration's inheritance clause."""
    k = decl_start(header)
    depth = 0
    out = []
    j = k + 1
    while j < len(header) and header[j].text != ":":
        if header[j].text == "<":
            depth += 1
        elif header[j].text == ">":
            depth -= 1
        if header[j].text == ":" and depth == 0:
            break
        j += 1
    j += 1
    expect = True
    while j < len(header):
        u = header[j]
        if u.kind == "id" and u.text == "where":
            break
        if u.text == "<":
            depth += 1
        elif u.text == ">":
            depth -= 1
        elif depth == 0 and u.text == ",":
            expect = True
        elif depth == 0 and expect and u.kind == "id" and u.text not in ("any", "some"):
            out.append(u.text)
            expect = False
        j += 1
    return out


def hidden_lines(code_lines, states, build, relaxed, false_flags):
    """How many code lines the false flags hide: active on some platform, or
    in the Darwin build, when the flags are unknown (`relaxed`), and nowhere
    when they're false; and which flags the file's directives test."""
    tested = sorted({f for l in code_lines if re.match(r"\s*#(if|elseif)\b", l)
                     for f in re.findall(r"[A-Za-z_]\w*", l) if f in false_flags})
    if not tested:
        return 0, []
    rstates, rbuild, _ = platforms.swift_line_states(code_lines, relaxed)
    n = 0
    for i, l in enumerate(code_lines):
        if l.strip() and not l.strip().startswith("#") and not states[i] and not build[i] \
                and (rstates[i] or rbuild[i]):
            n += 1
    return n, tested


def scan_file(path, rel, mdl=None, relaxed=None, false_flags=()):
    raw = open(path, encoding="utf-8").read()
    code, _ = strip_comments_and_strings(raw)
    code_lines = code.split("\n")
    states, build, errors = platforms.swift_line_states(code_lines, mdl)
    hidden, hidden_by = hidden_lines(code_lines, states, build, relaxed, set(false_flags)) if relaxed else (0, [])
    skip_lines = directive_lines(code_lines)
    toks = [t for t in tokenize(code) if t.line not in skip_lines]

    root = Scope("file", None, 1, None)
    scopes = [root]
    all_scopes = [root]
    scope_at = []          # scope of each token
    decls = []             # (scope, kind keyword, name, line)
    imports = []           # (line, kind, module, name)

    # Import statements: skip them, but record scoped imports.
    import_lines = set()
    for i, t in enumerate(toks):
        # `import X`, after any attributes and modifiers on its line.
        if t.text == "import" and t.kind == "id" and (i == 0 or toks[i - 1].line != t.line or
                                                      toks[i - 1].kind == "id"):
            line_toks = [u for u in toks if u.line == t.line]
            import_lines.add(t.line)
            after = [u for u in line_toks if u.col > t.col]
            if after and after[0].text in ("func", "let", "var", "struct", "class", "enum", "typealias", "protocol"):
                path_ids = [u.text for u in after[1:] if u.kind == "id"]
                if len(path_ids) >= 2:
                    imports.append((t.line, after[0].text, path_ids[0], path_ids[-1]))
            else:
                path_ids = [u.text for u in after if u.kind == "id"]
                if path_ids:
                    imports.append((t.line, "module", path_ids[0], None))

    pending = collections.defaultdict(set)   # `{` index -> bindings for the block it opens (for, if-let)
    type_info = {}             # type name -> inherited types and generic parameters
    binding_sites = set()      # token indices that bind a name
    for i, t in enumerate(toks):
        cur = scopes[-1]
        if t.text == "{" and t.kind == "p":
            header = header_tokens(toks, i)
            kind, name = classify_open(header)
            decl_line = header[0].line if header else t.line
            sc = Scope(kind, name, t.line, cur, decl_line)
            if kind == "func":
                sc.bindings |= param_names(header[decl_start(header):])
                sc.bindings |= generic_names(header)
                sc.bindings |= {"newValue", "oldValue"}
            elif kind == "type":
                sc.bindings |= generic_names(header)
                for wn, off in where_names(header):
                    sc.bindings.add(wn)
                    binding_sites.add(i - len(header) + off)
                if name:
                    ti = type_info.setdefault(name.split(".")[-1], {"inherits": set(), "generics": set(),
                                                                     "extension": True})
                    ti["inherits"].update(inherited_types(header))
                    ti["generics"].update(generic_names(header))
                    if header[decl_start(header)].text != "extension":
                        ti["extension"] = False
            elif kind == "closure":
                sc.bindings |= closure_params(toks, i)
                sc.bindings |= {"$0", "$1", "$2", "$3", "$4", "$5"}
            elif kind == "block":
                if name in ("set", "willSet", "didSet"):
                    sc.bindings |= {"newValue", "oldValue"}
                    # `set(newCPUSet) {`: a named accessor parameter.
                    if len(header) >= 4 and header[1].text == "(" and header[2].kind == "id" and header[3].text == ")":
                        sc.bindings.add(header[2].text)
                        binding_sites.add(i - len(header) + 2)
                if name == "catch":
                    sc.bindings.add("error")
            sc.bindings |= pending.pop(i, set())
            if kind in ("func", "type"):
                # The signature's tokens (generic parameters, labels,
                # parameter types) belong to the scope they declare.
                for j in range(i - len(header), i):
                    scope_at[j] = sc
            scopes.append(sc)
            all_scopes.append(sc)
            scope_at.append(sc)
            continue
        if t.text == "}" and t.kind == "p":
            if len(scopes) > 1:
                scopes[-1].end = t.line
                scopes.pop()
            scope_at.append(scopes[-1])
            continue
        scope_at.append(cur)
        if t.kind != "id" or (i > 0 and toks[i - 1].text == "."):
            continue
        if t.text in ("let", "var"):
            sites = pattern_sites(toks, i)
            names = {toks[j].text for j in sites}
            binding_sites.update(sites)
            if cur.kind != "file":
                cur.bindings |= names
            # `if let x {` / `guard let x else {`: visible in the block too.
            b = body_brace(toks, i)
            if b is not None:
                pending[b] |= names
            if cur.kind in ("type", "file"):
                for n in names:
                    decls.append((cur, t.text, n, t.line))
            continue
        if t.text == "for" and (i == 0 or toks[i - 1].line < t.line or toks[i - 1].text in ("{", "}", ";", ":")) \
                and not (i + 1 < len(toks) and toks[i + 1].text == ":"):
            j = i + 1
            names = set()
            while j < len(toks) and toks[j].text not in ("in", "{"):
                u = toks[j]
                if u.kind == "id" and u.text not in KEYWORDS and toks[j - 1].text != ".":
                    names.add(u.text)
                    binding_sites.add(j)
                j += 1
            b = body_brace(toks, j) if j < len(toks) and toks[j].text == "in" else (j if j < len(toks) else None)
            if b is not None:
                pending[b] |= names
            continue
        if t.text in ("func", "typealias", "struct", "class", "enum", "protocol", "actor", "associatedtype", "macro"):
            if i + 1 < len(toks) and toks[i + 1].kind == "id" and toks[i + 1].text not in ("func", "var", "let"):
                decls.append((cur, t.text, toks[i + 1].text, t.line))
                if cur.kind not in ("file", "type"):
                    cur.bindings.add(toks[i + 1].text)
            continue
        if t.text == "case" and cur.kind == "type":
            # Enum cases: `case a, b(Int), c = 1`.
            j = i + 1
            depth = 0
            expect = True
            while j < len(toks) and toks[j].line == t.line:
                u = toks[j]
                if u.text in ("(", "["):
                    depth += 1
                elif u.text in (")", "]"):
                    depth -= 1
                elif depth == 0 and u.text == ",":
                    expect = True
                elif depth == 0 and expect and u.kind == "id":
                    decls.append((cur, "case", u.text, t.line))
                    expect = False
                j += 1
            continue
    # Unclosed scopes end at the last line.
    last = len(code_lines)
    for sc in all_scopes:
        if sc.end is None:
            sc.end = last

    # Member names by type (the last component of `extension A.B`), and
    # top-level names with the line that declares them.
    members = {}
    top_level = []
    for sc, kw, name, line in decls:
        if sc.kind == "type" and sc.name:
            members.setdefault(sc.name.split(".")[-1], set()).add(name)
            # A property wrapper's storage and projection: `@OptionGroup var
            # globalOptions` declares `_globalOptions` and `$globalOptions`.
            if kw in ("var", "let"):
                members[sc.name.split(".")[-1]].update(("_" + name, "$" + name))
        elif sc.kind == "file":
            top_level.append((name, line))

    # Bracket depth of each token: `name:` is a label only inside (...) or [...].
    bracket = []
    depth = 0
    for t in toks:
        if t.text in (")", "]"):
            depth = max(0, depth - 1)
        bracket.append(depth)
        if t.text in ("(", "["):
            depth += 1

    # Parameter labels and names of every function declaration, bodies or
    # not (protocol requirements have none).
    for i, t in enumerate(toks):
        if t.kind == "id" and t.text == "typealias" and i + 2 < len(toks) and toks[i + 2].text == "<":
            # `typealias Name<A, B> = Other<A, B>`: A and B, to the line's end.
            names = generic_names(toks[i:i + 60])
            g = i + 2
            while g < len(toks) and (toks[g].line == t.line or toks[g - 1].text in CONT_END):
                if toks[g].kind == "id" and toks[g].text in names:
                    binding_sites.add(g)
                g += 1
            continue
        if t.kind == "id" and t.text in FUNC_KW and (i == 0 or toks[i - 1].text != "."):
            # `func name<T>(...)`, `init?<T>(...)`, `subscript(...)`.
            j = i + 2 if t.text == "func" else i + 1
            if j < len(toks) and toks[j].text in ("?", "!"):
                j += 1
            generics = set()
            if j < len(toks) and toks[j].text == "<":
                depth, expect, g = 0, True, j
                while g < len(toks):
                    if toks[g].text == "<":
                        depth += 1
                    elif toks[g].text == ">":
                        depth -= 1
                        if depth == 0:
                            break
                    elif depth == 1 and toks[g].text == ",":
                        expect = True
                    elif depth == 1 and expect and toks[g].kind == "id" and toks[g].text != "each":
                        generics.add(toks[g].text)
                        expect = False
                    g += 1
                j = g + 1
            if j < len(toks) and toks[j].text == "(":
                binding_sites.update(param_sites(toks, j))
            if generics:
                # Uses of the generic parameters in the signature, up to the
                # body or the end of the declaration's last line.
                close = j
                depth = 0
                while close < len(toks):
                    if toks[close].text == "(":
                        depth += 1
                    elif toks[close].text == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    close += 1
                g = i
                while g < len(toks) and toks[g].text != "{" and (g <= close or toks[g].line == toks[close].line
                                                                   or toks[g].text in ("where", ",", ":", ".")):
                    if toks[g].kind == "id" and toks[g].text in generics:
                        binding_sites.add(g)
                    g += 1

    # Attribute arguments, e.g. `@inline(never)`, `@available(macOS 10.15, *)`,
    # and `#available(...)` conditions.
    in_attr = set()
    for i, t in enumerate(toks):
        if t.text in ("@", "#") and i + 2 < len(toks) and toks[i + 1].kind == "id" and toks[i + 2].text == "(" \
                and toks[i + 2].line == toks[i + 1].line \
                and (t.text == "@" or toks[i + 1].text in ("available", "unavailable", "selector", "keyPath")):
            depth = 0
            for j in range(i + 2, len(toks)):
                if toks[j].text == "(":
                    depth += 1
                elif toks[j].text == ")":
                    depth -= 1
                    if depth == 0:
                        break
                in_attr.add(j)

    # Candidates.
    cands = []
    for i, t in enumerate(toks):
        if t.kind != "id" or t.line in import_lines or i in in_attr or i in binding_sites:
            continue
        name = t.text
        prev = toks[i - 1] if i > 0 else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        qualifier = None
        if prev is not None and prev.text == ".":
            pp = toks[i - 2] if i > 1 else None
            if pp is not None and pp.kind == "id" and pp.text not in KEYWORDS and (i < 3 or toks[i - 3].text != "."):
                qualifier = pp.text
            else:
                continue
        if name in KEYWORDS and qualifier is None:
            continue
        if prev is not None and prev.text in ("@", "#"):
            continue
        if nxt is not None and nxt.text == ":" and qualifier is None and \
                (bracket[i] > 0 or (prev is not None and prev.text == "}")):
            continue
        # `outer: for ...`, `break outer`, `continue outer`.
        if nxt is not None and nxt.text == ":" and i + 2 < len(toks) and \
                toks[i + 2].text in ("for", "while", "repeat", "do", "if", "switch"):
            continue
        if prev is not None and prev.text in ("break", "continue") and prev.line == t.line:
            continue
        # An accessor: `_modify {`, `set(newValue) {`.
        if name in ACCESSOR_KW and qualifier is None and nxt is not None and nxt.text in ("{", "("):
            continue
        if prev is not None and prev.kind == "id" and prev.text in DECL_KW and qualifier is None \
                and not (prev.text == "case" and scope_at[i].kind != "type"):
            continue
        if name.startswith("$"):
            continue
        # InlineArray's sugar, `[2 of CInt]`.
        if name == "of" and prev is not None and (prev.kind == "num" or prev.text == "_") \
                and nxt is not None and nxt.kind == "id":
            continue
        sc = scope_at[i]
        bound = False
        types = []
        s = sc
        while s is not None:
            if name in s.bindings:
                bound = True
            if s.kind == "type" and s.name:
                types.append(s.name.split(".")[-1])
            s = s.parent
        # A qualified reference `A.b` is never bound, but its qualifier may
        # be (`os.hasPrefix(...)` with a parameter named `os`), in which case
        # it isn't a module.
        qualifier_bound = False
        if qualifier is not None:
            bound = False
            s = sc
            while s is not None:
                if qualifier in s.bindings:
                    qualifier_bound = True
                    break
                s = s.parent
        func = None
        s = sc
        while s is not None and s.kind != "func":
            s = s.parent
        if s is not None:
            func = (s.name, s.decl_line, s.end)
        called = nxt is not None and nxt.text == "(" and nxt.line == t.line
        labeled = False
        if called:
            # `f(a, label: b)`: an argument label, which no C function takes.
            depth = 0
            for j in range(i + 1, min(len(toks), i + 200)):
                u = toks[j]
                if u.text in ("(", "[", "{"):
                    depth += 1
                elif u.text in (")", "]", "}"):
                    depth -= 1
                    if depth == 0:
                        break
                elif depth == 1 and u.kind == "id" and toks[j - 1].text in ("(", ",") \
                        and j + 1 < len(toks) and toks[j + 1].text == ":":
                    labeled = True
                    break
        cands.append({
            "line": t.line, "col": t.col, "name": name, "qualifier": qualifier,
            "labeled": labeled,
            # `filter { ... }` where an expression starts: after `return`,
            # `=`, `(` and the like, not as the operand in `if x == NAME {`.
            "trailingClosure": nxt is not None and nxt.text == "{" and nxt.line == t.line
                               and (prev is None or prev.line < t.line
                                    or prev.text in ("{", "}", ";", "=", "(", ",", "[", "return", "in", "try",
                                                     "await")),
            "called": called,
            "bound": bound, "types": types, "func": func, "qualifierBound": qualifier_bound,
        })

    funcs = [{"name": s.name, "start": s.decl_line, "end": s.end} for s in all_scopes if s.kind == "func"]
    return {
        "file": rel,
        "states": states,
        "build": build,
        "errors": errors,
        "candidates": cands,
        "imports": imports,
        "members": {k: sorted(v) for k, v in members.items()},
        "typeInfo": {k: {"inherits": sorted(v["inherits"]), "generics": sorted(v["generics"]),
                         "extension": v["extension"]} for k, v in type_info.items()},
        "topLevel": sorted(top_level),
        "funcs": funcs,
        "codeLines": [i + 1 for i, l in enumerate(code_lines) if l.strip() and not l.strip().startswith("#")],
        "hiddenLines": hidden, "hiddenBy": hidden_by,
    }


def resolve_member_filter(files):
    """Mark candidates that name a member of an enclosing type, using the
    members collected from every file. A type's members include its
    generic parameters and, transitively, the members of the types it
    inherits from or conforms to (as far as NIO declares them)."""
    members, inherits = {}, {}
    for f in files:
        for k, v in f["members"].items():
            members.setdefault(k, set()).update(v)
        for k, v in f.get("typeInfo", {}).items():
            members.setdefault(k, set()).update(v["generics"])
            inherits.setdefault(k, set()).update(v["inherits"])

    closure = {}

    def all_members(ty, seen=None):
        if ty in closure:
            return closure[ty]
        seen = seen or set()
        seen.add(ty)
        out = set(members.get(ty, ()))
        for sup in inherits.get(ty, ()):
            if sup not in seen:
                out |= all_members(sup, seen)
        closure[ty] = out
        return out

    for f in files:
        for c in f["candidates"]:
            if c["qualifier"] is None and not c["bound"]:
                for ty in c["types"]:
                    if c["name"] in all_members(ty):
                        c["bound"] = True
                        c["member_of"] = ty
                        break
    return members


if __name__ == "__main__":
    import json
    root = sys.argv[1]
    out = []
    for rel in sys.argv[2:]:
        out.append(scan_file(os.path.join(root, rel), rel))
    resolve_member_filter(out)
    json.dump(out, sys.stdout, indent=1, default=str)
