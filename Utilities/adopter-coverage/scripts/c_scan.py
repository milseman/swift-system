#!/usr/bin/env python3
"""Lexical scan of NIO's C sources (the CNIO* targets).

Like swift_scan.py: per-line platform states (platforms.c_line_states, with
the target's own defines), then candidate references to OS symbols. It also
records each file-scope definition (function or variable) with its line
span, so extract.py can say which OS symbols each NIO shim wraps.

A candidate is an identifier that isn't a C keyword, a field access (after
`.` or `->`), or a name the NIO sources declare: functions, variables,
typedefs, struct and enum tags, enum constants, fields, macros they
#define, parameters, locals and goto labels. The structure comes from a
small recursive pass over braces, which tells initializers, type bodies,
function bodies and `extern "C"` blocks apart. Lines that no platform
compiles (`#ifdef __cplusplus`, `#if 0`) are dropped first.

It doesn't expand macros, except NIO's own token-pasting ones such as
CNIOWindows' `NIO(name)`: whatever a macro's expansion references is
invisible to it. extract.py measures its accuracy against the index on
Darwin.
"""

import re

import platforms

C_KEYWORDS = set("""
auto break case char const continue default do double else enum extern float for goto if inline int long
register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while
_Bool _Complex _Imaginary _Static_assert _Thread_local _Alignas _Alignof _Atomic _Generic _Noreturn
__attribute__ __always_inline__ __declspec __cdecl __stdcall asm __asm__ typeof __typeof__ __extension__
__inline __inline__ __restrict __restrict__ __volatile__ defined
""".split())

TYPE_WORDS = {"int", "char", "unsigned", "signed", "short", "long", "float", "double", "void", "_Bool", "const",
              "volatile", "static", "register", "struct", "union", "enum", "extern", "inline", "_Thread_local",
              "_Atomic", "__inline", "__inline__"}

TOKEN = re.compile(r"""
    (?P<nl>\n)
  | (?P<ws>[ \t\r\f\v]+)
  | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<num>\.?\d[\w.]*)
  | (?P<p>->|\#\#|&&|\|\||==|!=|<=|>=|<<|>>|\+\+|--|\.\.\.|[{}()\[\],:;.?!=<>@#&|^~+\-*/%])
  | (?P<other>.)
""", re.X)


def blank_c(text):
    """Blank comments, string and character literals, keeping newlines.
    Returns (code, lines that end inside a block comment)."""
    out = list(text)
    i, n = 0, len(text)
    in_comment_newlines = []

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            while j < n and j > 0 and text[j - 1] == "\\":
                k = text.find("\n", j + 1)
                j = n if k < 0 else k
            blank(i, j)
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if text[k] == "\n":
                    in_comment_newlines.append(k)
            blank(i, j)
            i = j
        elif text[i] in "\"'":
            q = text[i]
            j = i + 1
            while j < n and text[j] != q and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            blank(i + 1, j)
            i = j + 1
        else:
            i += 1
    code = "".join(out)
    ends_in_comment = set()
    for k in in_comment_newlines:
        ends_in_comment.add(code.count("\n", 0, k) + 1)
    return code, ends_in_comment


class Tok:
    __slots__ = ("kind", "text", "line", "col")

    def __init__(self, kind, text, line, col):
        self.kind, self.text, self.line, self.col = kind, text, line, col

    def __repr__(self):
        return f"{self.text}@{self.line}"


def matching(toks, i, open_, close):
    """Index of the bracket that closes the one at i."""
    depth = 0
    for j in range(i, len(toks)):
        if toks[j].text == open_:
            depth += 1
        elif toks[j].text == close:
            depth -= 1
            if depth == 0:
                return j
    return len(toks) - 1


class Structure:
    """Walks the token stream, recording what NIO declares and where each
    file-scope definition starts and ends."""

    def __init__(self, toks):
        self.toks = toks
        self.declared = set()       # file-scope names: functions, variables, typedefs, tags
        self.local_decls = set()    # fields, enum constants, prototype parameters
        self.defs = []              # {"name", "kind", "start", "end", "tok_start", "tok_end", "locals"}
        self.skip = set()           # token indices that are declarations, not references
        self.kinds = {}             # declared name -> function, variable, type
        self.walk(0, len(toks))

    def walk(self, i, end):
        toks = self.toks
        start = i
        while i < end:
            t = toks[i]
            if t.text == ";":
                self.declaration(start, i)
                i += 1
                start = i
                continue
            if t.text == "{":
                stmt = toks[start:i]
                words = [s.text for s in stmt]
                close = matching(toks, i, "{", "}")
                if words and words[-1] == "=":
                    i = close + 1           # initializer; the statement goes on to `;`
                    continue
                if not stmt or (words[0] == "extern" and len(words) <= 3 and "(" not in words):
                    self.walk(i + 1, close)  # extern "C" { ... }: transparent
                    i = close + 1
                    start = i
                    continue
                paren = [k for k, s in enumerate(stmt) if s.text == "("]
                tag = next((k for k, s in enumerate(stmt) if s.text in ("struct", "union", "enum")), None)
                if tag is not None and (not paren or tag < paren[0]) and not self.is_function(stmt):
                    self.type_body(i, close, stmt[tag].text == "enum")
                    if tag + 1 < len(stmt) and stmt[tag + 1].kind == "id":
                        self.declared.add(stmt[tag + 1].text)
                        self.kinds.setdefault(stmt[tag + 1].text, "type")
                        self.skip.add(start + tag + 1)
                    i = close + 1           # declarators may follow: `} name;`
                    continue
                if self.is_function(stmt):
                    name_k = self.function_name(stmt)
                    name = stmt[name_k].text if name_k is not None else "?"
                    self.declared.add(name)
                    self.kinds[name] = "function"
                    if name_k is not None:
                        self.skip.add(start + name_k)
                    params = self.params(start, i)
                    locals_, labels = self.body(i, close)
                    self.defs.append({"name": name, "kind": "function", "start": stmt[0].line,
                                      "end": toks[close].line, "tok_start": start, "tok_end": close,
                                      "locals": params | locals_ | labels})
                    i = close + 1
                    start = i
                    continue
                i = close + 1               # something else; skip it
                start = i
                continue
            i += 1

    def is_function(self, stmt):
        """`... name(params) [attributes] {`."""
        k = len(stmt) - 1
        while k >= 0 and stmt[k].text != ")":
            if stmt[k].kind != "id":
                return False
            k -= 1
        return k >= 0 and self.function_name(stmt) is not None

    def function_name(self, stmt):
        depth = 0
        for k, s in enumerate(stmt):
            if s.text == "(":
                if depth == 0 and k > 0 and stmt[k - 1].kind == "id" and stmt[k - 1].text not in C_KEYWORDS:
                    return k - 1
                depth += 1
            elif s.text == ")":
                depth -= 1
        return None

    def params(self, start, brace):
        """Parameter names of the definition whose header spans toks[start:brace]."""
        toks = self.toks
        stmt = toks[start:brace]
        name_k = self.function_name(stmt)
        names = set()
        if name_k is None:
            return names
        open_ = start + name_k + 1
        close = matching(toks, open_, "(", ")")
        chunk = []
        depth = 0
        for j in range(open_ + 1, close + 1):
            t = toks[j]
            if t.text == "(":
                depth += 1
            elif t.text == ")":
                depth -= 1
            if (t.text == "," and depth == 0) or j == close:
                k = self.param_name(chunk)
                if k is not None:
                    names.add(toks[k].text)
                    self.skip.add(k)
                chunk = []
                continue
            chunk.append(j)
        return names

    def param_name(self, chunk):
        toks = self.toks
        # `int (*compar)(const FTSENT **, ...)`: the name inside the first parens.
        for a, j in enumerate(chunk):
            if toks[j].text == "(" and a + 2 < len(chunk) and toks[chunk[a + 1]].text == "*" \
                    and toks[chunk[a + 2]].kind == "id":
                return chunk[a + 2]
        ids = [j for j in chunk if toks[j].kind == "id" and toks[j].text not in C_KEYWORDS]
        if len(ids) >= 2 or (ids and len(chunk) > 1 and chunk[-1] == ids[-1] and toks[chunk[0]].text in TYPE_WORDS):
            return ids[-1]
        return None

    def type_body(self, open_, close, is_enum):
        toks = self.toks
        if is_enum:
            expect = True
            depth = 0
            for j in range(open_ + 1, close):
                t = toks[j]
                if t.text in ("(", "["):
                    depth += 1
                elif t.text in (")", "]"):
                    depth -= 1
                elif depth == 0 and t.text == ",":
                    expect = True
                elif depth == 0 and expect and t.kind == "id":
                    self.local_decls.add(t.text)
                    self.skip.add(j)
                    expect = False
            return
        # Fields: the declarator before each `;`, `,`, `[` or `:` (bit-field)
        # at the body's own level; nested bodies recurse.
        j = open_ + 1
        while j < close:
            t = toks[j]
            if t.text == "{":
                inner = matching(toks, j, "{", "}")
                back = [toks[k].text for k in range(max(open_ + 1, j - 3), j)]
                self.type_body(j, inner, "enum" in back)
                j = inner + 1
                continue
            nxt = toks[j + 1] if j + 1 < close else None
            if t.kind == "id" and t.text not in C_KEYWORDS and nxt is not None \
                    and nxt.text in (";", ",", "[", ":", ")") and j > open_ + 1 \
                    and (toks[j - 1].kind == "id" or toks[j - 1].text in ("*", "}")) \
                    and toks[j - 1].text not in ("struct", "union", "enum"):
                self.local_decls.add(t.text)
                self.skip.add(j)
            j += 1

    def body(self, open_, close):
        """Locals and goto labels of a function body."""
        toks = self.toks
        locals_, labels = set(), set()
        stmt = []
        for j in range(open_ + 1, close + 1):
            t = toks[j]
            if t.text in (";", "{", "}"):
                for k in self.local_decl(stmt):
                    locals_.add(toks[k].text)
                    self.skip.add(k)
                stmt = []
                continue
            if t.text == "(" and stmt and toks[stmt[-1]].text == "for":
                stmt = []
                continue
            # `label:` at the start of a statement; `goto label`.
            if t.kind == "id" and not stmt and j + 1 < close and toks[j + 1].text == ":" \
                    and t.text not in ("default", "case"):
                labels.add(t.text)
                self.skip.add(j)
                continue
            if t.kind == "id" and j > 0 and toks[j - 1].text == "goto":
                labels.add(t.text)
            stmt.append(j)
        return locals_, labels

    def local_decl(self, stmt):
        """Token indices of the names a local declaration declares:
        `uint32_t a, b = 1, *c;` -> a, b, c."""
        first = self._first_declarator(stmt)
        if first is None:
            return []
        toks = self.toks
        out = [first]
        depth = 0
        pos = stmt.index(first)
        for a in range(pos + 1, len(stmt)):
            t = toks[stmt[a]]
            if t.text in ("(", "["):
                depth += 1
            elif t.text in (")", "]"):
                depth -= 1
            elif depth == 0 and t.text == ",":
                b = a + 1
                while b < len(stmt) and toks[stmt[b]].text == "*":
                    b += 1
                if b < len(stmt) and toks[stmt[b]].kind == "id":
                    out.append(stmt[b])
        return out

    def _first_declarator(self, stmt):
        toks = self.toks
        if len(stmt) < 2:
            return None
        k = 0
        while k < len(stmt) and toks[stmt[k]].text in TYPE_WORDS:
            if toks[stmt[k]].text in ("struct", "union", "enum") and k + 1 < len(stmt):
                k += 1
            k += 1
        if k == 0:
            if toks[stmt[0]].kind != "id":
                return None
            k = 1
        elif k < len(stmt) and toks[stmt[k]].kind == "id" and k + 1 < len(stmt) and toks[stmt[k + 1]].kind == "id":
            k += 1
        while k < len(stmt) and toks[stmt[k]].text == "*":
            k += 1
        if k < len(stmt) and toks[stmt[k]].kind == "id" and toks[stmt[k]].text not in C_KEYWORDS and \
                (k + 1 == len(stmt) or toks[stmt[k + 1]].text in ("=", "[", ",")):
            return stmt[k]
        return None

    def declaration(self, start, end):
        """A file-scope statement ending in `;`. Brace contents (a type body
        or an initializer, handled already) are left out."""
        toks = self.toks
        keep, depth = [], 0
        for j in range(start, end):
            if toks[j].text == "{":
                depth += 1
            elif toks[j].text == "}":
                depth -= 1
            elif depth == 0:
                keep.append(j)
        if not keep:
            return
        if len(keep) != end - start:
            # Re-index so that stmt[k] is toks[index[k]].
            self._declaration([toks[j] for j in keep], keep, end)
            return
        self._declaration(toks[start:end], list(range(start, end)), end)

    def _declaration(self, stmt, index, end):
        start = index[0]
        toks = self.toks
        words = [s.text for s in stmt]
        if words[0] == "typedef":
            for k, s in enumerate(stmt):
                if s.text == "(" and k + 2 < len(stmt) and stmt[k + 1].text in ("*", "__cdecl", "__stdcall"):
                    ids = [(k2, u) for k2, u in enumerate(stmt[k + 1:], k + 1)
                           if u.kind == "id" and u.text not in C_KEYWORDS]
                    if ids:
                        self.declared.add(ids[0][1].text)
                        self.kinds.setdefault(ids[0][1].text, "type")
                        self.skip.add(index[ids[0][0]])
                        return
            # Every declarator: `typedef struct {...} A, *PA;` declares A and PA.
            depth = 0
            last = None
            for k, s in enumerate(stmt):
                if s.text in ("(", "["):
                    depth += 1
                elif s.text in (")", "]"):
                    depth -= 1
                elif depth == 0 and s.kind == "id" and s.text not in C_KEYWORDS:
                    last = k
                elif depth == 0 and s.text == "," and last is not None:
                    self.declared.add(stmt[last].text)
                    self.kinds.setdefault(stmt[last].text, "type")
                    self.skip.add(index[last])
                    last = None
            if last is not None:
                self.declared.add(stmt[last].text)
                self.kinds.setdefault(stmt[last].text, "type")
                self.skip.add(index[last])
            return
        # A variable when an `=` or `[` follows a parenthesized group at the
        # top level: `static const char ALIGN(16) blob[] = {...};`.
        depth, after_parens, is_var = 0, False, False
        for s in stmt:
            if s.text == "(":
                depth += 1
            elif s.text == ")":
                depth -= 1
                if depth == 0:
                    after_parens = True
            elif depth == 0 and after_parens and s.text in ("=", "["):
                is_var = True
                break
        name_k = None if is_var else self.function_name(stmt)
        if name_k is not None and not any(s.text == "=" for s in stmt[:name_k]):
            # A prototype: its name, and its parameter names.
            self.declared.add(stmt[name_k].text)
            self.kinds.setdefault(stmt[name_k].text, "function")
            self.skip.add(index[name_k])
            self.params(index[0], end)
            return
        depth = 0
        for k, s in enumerate(stmt):
            if s.text in ("(", "["):
                if depth == 0 and s.text == "[" and k > 0 and stmt[k - 1].kind == "id":
                    self.declared.add(stmt[k - 1].text)
                    self.kinds.setdefault(stmt[k - 1].text, "variable")
                    self.skip.add(index[k - 1])
                    self.defs.append(self.var_def(start, end, stmt[k - 1].text))
                    return
                depth += 1
            elif s.text in (")", "]"):
                depth -= 1
            elif depth == 0 and s.text == "=" and k > 0 and stmt[k - 1].kind == "id":
                self.declared.add(stmt[k - 1].text)
                self.kinds.setdefault(stmt[k - 1].text, "variable")
                self.skip.add(index[k - 1])
                self.defs.append(self.var_def(start, end, stmt[k - 1].text))
                return
        last = stmt[-1]
        if last.kind == "id" and last.text not in C_KEYWORDS and len(stmt) > 1:
            self.declared.add(last.text)
            self.kinds.setdefault(last.text, "variable")
            self.skip.add(index[-1])

    def var_def(self, start, end, name):
        return {"name": name, "kind": "variable", "start": self.toks[start].line, "end": self.toks[end].line,
                "tok_start": start, "tok_end": end, "locals": set()}


def scan_c_file(path, rel, defines=()):
    raw = open(path, encoding="utf-8", errors="replace").read()
    code, ends_in_comment = blank_c(raw)
    code_lines = code.split("\n")
    raw_lines = raw.split("\n")
    states, build = platforms.c_line_states(code_lines, defines)
    dead = {k + 1 for k, st in enumerate(states) if not st and not build[k]}

    # Directive lines (with their continuations: a trailing backslash, or a
    # comment that runs onto the next line), includes and macro definitions.
    directive = set()
    includes = []
    macros = set()
    paste_macros = {}   # NAME -> prefix, for `#define NAME(x) PREFIX ## x`
    k = 0
    while k < len(code_lines):
        line = code_lines[k]
        if line.lstrip().startswith("#"):
            start = k
            full = line
            while (full.rstrip().endswith("\\") or (k + 1) in ends_in_comment) and k + 1 < len(code_lines):
                k += 1
                full = full.rstrip().rstrip("\\") + " " + code_lines[k]
            for j in range(start, k + 1):
                directive.add(j + 1)
            m = re.match(r"\s*#\s*include\s*[<\"]([^>\"]+)[>\"]", raw_lines[start])
            if m:
                includes.append((start + 1, m.group(1)))
            m = re.match(r"\s*#\s*define\s+([A-Za-z_]\w*)(\(([^)]*)\))?\s*(.*)$", full)
            if m:
                macros.add(m.group(1))
                if m.group(2):
                    arg = m.group(3).strip()
                    pm = re.match(rf"([A-Za-z_]\w*)\s*##\s*{re.escape(arg)}\s*$", m.group(4).strip())
                    if pm:
                        paste_macros[m.group(1)] = pm.group(1)
        k += 1

    toks = []
    line, line_start = 1, 0
    for m in TOKEN.finditer(code):
        kind = m.lastgroup
        if kind == "nl":
            line += 1
            line_start = m.end()
            continue
        if kind == "ws" or line in directive or line in dead:
            continue
        toks.append(Tok(kind, m.group(kind), line, m.start() - line_start + 1))

    # Expand token-pasting macros: NIO(recv) -> CNIOWindows_recv.
    if paste_macros:
        out = []
        i = 0
        while i < len(toks):
            t = toks[i]
            if t.kind == "id" and t.text in paste_macros and i + 3 < len(toks) and toks[i + 1].text == "(" \
                    and toks[i + 2].kind == "id" and toks[i + 3].text == ")":
                out.append(Tok("id", paste_macros[t.text] + toks[i + 2].text, t.line, t.col))
                i += 4
                continue
            out.append(t)
            i += 1
        toks = out

    st = Structure(toks)
    declared = st.declared | macros
    kinds = dict(st.kinds)
    for m in macros:
        kinds.setdefault(m, "macro")

    # Arguments of __attribute__((...)) and __declspec(...).
    in_attr = set()
    for j, t in enumerate(toks):
        if t.text in ("__attribute__", "__declspec") and j + 1 < len(toks) and toks[j + 1].text == "(":
            end = matching(toks, j + 1, "(", ")")
            in_attr.update(range(j + 1, end + 1))

    def def_at(j):
        for d in st.defs:
            if d["tok_start"] <= j <= d["tok_end"]:
                return d
        return None

    cands = []
    for j, t in enumerate(toks):
        if t.kind != "id" or t.text in C_KEYWORDS or j in in_attr or j in st.skip:
            continue
        prev = toks[j - 1] if j > 0 else None
        nxt = toks[j + 1] if j + 1 < len(toks) else None
        if prev is not None and prev.text in (".", "->"):
            continue
        if t.text in declared or t.text in st.local_decls:
            continue
        d = def_at(j)
        if d is not None and t.text in d["locals"]:
            continue
        cands.append({"line": t.line, "col": t.col, "name": t.text,
                      "called": nxt is not None and nxt.text == "(",
                      "struct": prev is not None and prev.text in ("struct", "union", "enum"),
                      "def": d["name"] if d else None})

    return {
        "file": rel,
        "states": states,
        "build": build,
        "includes": includes,
        "declared": sorted(declared),
        "declaredKinds": kinds,
        "localDeclared": sorted(st.local_decls),
        "defs": [{"name": d["name"], "kind": d["kind"], "start": d["start"], "end": d["end"]} for d in st.defs],
        "candidates": cands,
        "codeLines": [i + 1 for i, l in enumerate(code_lines) if l.strip() and not l.strip().startswith("#")],
    }


if __name__ == "__main__":
    import json
    import os
    import sys
    root = sys.argv[1]
    json.dump([scan_c_file(os.path.join(root, rel), rel, ["_GNU_SOURCE"]) for rel in sys.argv[2:]], sys.stdout,
              indent=1, default=str)
