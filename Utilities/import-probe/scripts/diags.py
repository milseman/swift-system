#!/usr/bin/env python3
"""The compiler's diagnostics from a build log, and the names they say a
file can't find.

A diagnostic is a `path:line:column: error: message` line of the log;
SwiftPM's source excerpts (the `|` lines under each) and errors without a
location are skipped, and a diagnostic two jobs both print (the emit-module
job and the compile job) is kept once. Paths are made relative to the
package: a host path under the scratch copy, or a container's `/code/...`.

The primary diagnostics, each naming what's missing:

  cannot find 'X' in scope                       value
  cannot find type 'X' in scope                  type
  property 'X' is not available due to missing
    import of defining module 'M'                member (MemberImportVisibility)
  value of type 'T' has no member 'X'            member
  type 'T' has no member 'X'                     member
  no such module 'X'                             module

`cannot find 'Glibc' in scope` for a module the probe removed is a
qualified use (`Glibc.exit(1)`), and the name is read from the source at
the diagnostic's column.

A follow-on is an error the probe can tell another one caused: one whose
message has `<<error type>>` or names a name the file can't find, one inside
the declaration of a primary diagnostic (an unresolved type in a signature,
then a mismatch in the body), or one on a declaration that holds a primary
diagnostic (a type whose stored property's type is unresolved can't
conform). They're counted apart, as is every other error; an error caused
by another file's unresolved declaration (a call whose callee's signature
failed) isn't recognized.
"""

import sys

sys.dont_write_bytecode = True

import collections  # noqa: E402
import re  # noqa: E402

LOCATED = re.compile(r"^(?P<path>/[^:\n]+?\.(?:swift|h|c|m|mm|cpp)):(?P<line>\d+):(?P<col>\d+): "
                     r"(?P<severity>error|warning|note): (?P<message>.*)$")
CATEGORY = re.compile(r"\s*\[#\w+\]\s*$")

PRIMARY = [
    ("value", re.compile(r"^cannot find '(?P<name>[^']+)' in scope$")),
    ("type", re.compile(r"^cannot find type '(?P<name>[^']+)' in scope$")),
    ("member", re.compile(r"^(?P<what>[a-z][a-z ]*?) '(?P<name>[^']+)' is not available due to missing import of "
                          r"defining module '(?P<module>[^']+)'")),
    ("member", re.compile(r"^value of type '(?P<type>.+)' has no member '(?P<name>[^']+)'$")),
    ("member", re.compile(r"^type '(?P<type>.+)' has no member '(?P<name>[^']+)'$")),
    ("module", re.compile(r"^no such module '(?P<name>[^']+)'$")),
]


def relative(path, roots):
    """The path relative to the first root it's under, or None."""
    for r in roots:
        r = r.rstrip("/") + "/"
        if path.startswith(r):
            return path[len(r):]
    return None


def parse(log, roots):
    """[{file, line, col, severity, message}] for the located errors of a
    log under the roots, in order, each once."""
    out, seen = [], set()
    for raw in log.splitlines():
        m = LOCATED.match(raw.rstrip())
        if not m or m.group("severity") != "error":
            continue
        rel = relative(m.group("path"), roots)
        if rel is None:
            continue
        message = CATEGORY.sub("", m.group("message")).strip()
        key = (rel, int(m.group("line")), int(m.group("col")), message)
        if key in seen:
            continue
        seen.add(key)
        out.append({"file": rel, "line": key[1], "col": key[2], "severity": "error", "message": message})
    return out


def base_name(name):
    """`foo(_:bar:)` -> `foo`."""
    return name.split("(")[0].strip()


def primary(message):
    """(kind, name, details) for a primary diagnostic's message, else None."""
    for kind, pattern in PRIMARY:
        m = pattern.match(message)
        if m:
            d = m.groupdict()
            return kind, base_name(d["name"]), {k: v for k, v in d.items() if k != "name" and v}
    return None


QUALIFIED = re.compile(r"\b([A-Za-z_]\w*)\s*\.\s*`?([A-Za-z_]\w*)")


def qualified_name(source_line, col, module):
    """The member named after `module.` at (1-based) col in the line."""
    for m in QUALIFIED.finditer(source_line):
        if m.group(1) == module and m.start(1) <= col - 1 <= m.end(1):
            return m.group(2)
    for m in QUALIFIED.finditer(source_line):
        if m.group(1) == module:
            return m.group(2)
    return None


MODIFIERS = (r"^\s*(?:@\w+(?:\([^()]*\))?\s*)*(?:(?:public|private|fileprivate|internal|package|open|static|"
             r"class|final|override|mutating|nonmutating|convenience|required|lazy|weak|unowned|indirect|"
             r"nonisolated|dynamic|consuming|borrowing)(?:\([^)]*\))?\s+)*")
DECL = re.compile(MODIFIERS + r"(?:func|init[?!]?|deinit|subscript|var|let|case|typealias|struct|class|enum|"
                  r"extension|protocol|actor)\b")
FUNCTION = re.compile(MODIFIERS + r"(?:func|init[?!]?|deinit|subscript)\b")
CONTINUES = (",", "(", "->", "=", ":", "&&", "||")
CONTINUED = (".", "->", "{", "where", "throws", "rethrows", "async", "&&", "||", ")")


def _end(code, s):
    """The last line of the declaration that starts at index s."""
    paren = brace = 0
    opened = False
    for j in range(s, len(code)):
        for ch in code[j]:
            if ch in "([":
                paren += 1
            elif ch in ")]":
                paren -= 1
            elif ch == "{":
                brace += 1
                opened = True
            elif ch == "}":
                brace -= 1
                if brace <= 0 and (opened or brace < 0):
                    return j
        if not opened and paren <= 0:
            text = code[j].rstrip()
            nxt = code[j + 1].lstrip() if j + 1 < len(code) else ""
            if not text.endswith(CONTINUES) and not nxt.startswith(CONTINUED):
                return j
    return len(code) - 1


def _innermost(code, idx, pattern):
    s = min(idx, len(code) - 1)
    while s >= 0:
        while s >= 0 and not pattern.match(code[s]):
            s -= 1
        if s < 0:
            return None
        e = _end(code, s)
        if e >= idx:
            return s + 1, e + 1
        s -= 1
    return None


def decl_range(code, line):
    """(first, last), 1-based, of the declaration a line of blanked code is
    in: the innermost function, initializer, deinitializer or subscript
    around it, else the innermost declaration of any kind (a stored
    property, a case), by brackets."""
    return _innermost(code, line - 1, FUNCTION) or _innermost(code, line - 1, DECL) or (line, line)


def split(diags, code_of):
    """(primaries, follow-ons, others) of a target's errors. `code_of(file)`
    gives a file's blanked lines (or None). A primary is (diag, kind, name,
    details)."""
    prim, rest = [], []
    for d in diags:
        p = primary(d["message"])
        if p:
            prim.append((d,) + p)
        else:
            rest.append(d)
    ranges, lines, names = {}, collections.defaultdict(list), collections.defaultdict(set)
    for d, _, name, _ in prim:
        code = code_of(d["file"])
        if code is not None:
            ranges.setdefault(d["file"], []).append(decl_range(code, d["line"]))
        lines[d["file"]].append(d["line"])
        names[d["file"]].add(name)
    follow, other = [], []
    for d in rest:
        f = d["file"]
        inside = any(a <= d["line"] <= b for a, b in ranges.get(f, []))
        code = code_of(f)
        if not inside and code is not None and lines.get(f):
            # The error's own declaration holds a primary one: a type whose
            # stored property's type is unresolved can't conform.
            a, b = decl_range(code, d["line"])
            inside = any(a <= x <= b for x in lines[f])
        mentions = any(re.search(rf"(?<![\w]){re.escape(n)}(?![\w])", d["message"]) for n in names.get(f, ()))
        if "<<error type>>" in d["message"] or inside or mentions:
            follow.append(d)
        else:
            other.append(d)
    return prim, follow, other
