#!/usr/bin/env python3
"""Scan Swift sources for public declarations, independent of the compiler.

Symbol graphs from a macOS build can't show:
  - declarations compiled only on other platforms (`#if os(Linux)`, ...),
  - `@available(*, unavailable)` stubs (symbol graphs omit them),
  - underscored names or labels (symbol graphs treat them as private).
This scanner finds every declaration spelled `public` or `open` (plus members
of a `public extension`), records its `#if` condition stack, and evaluates
that stack for each platform, so it can report where each one is compiled.
It also records top-level `@usableFromInline` declarations (ABI-public).

It is a lexical scanner, not a parser: comments and string literals are
blanked, braces are tracked to find enclosing types and extensions, and a
declaration is recognized by its leading keyword. regenerate.sh
cross-checks it against the symbol graphs, and anything it can't explain is
reported rather than dropped.

Usage: scan_sources.py ROOT OUT.json
"""

import json
import os
import re
import sys

MODULE_DIRS = {"Sources/System": "SystemPackage", "Sources/SystemSockets": "SystemSockets",
               "Sources/SystemWinSocks": "SystemWinSocks"}
# Excluded from the SwiftPM build on non-Linux hosts, and compiled only on Linux.
LINUX_ONLY_DIRS = ["Sources/System/IORing"]

# Compilation environments. `debug` builds define ENABLE_MOCKING and DEBUG.
COMMON = {"SYSTEM_PACKAGE": True, "ENABLE_MOCKING": True, "DEBUG": True,
          "SYSTEM_OS_BUILD": False, "SYSTEM_CI": False, "SYSTEM_ABI_STABLE": False}
PLATFORMS = {
    "Darwin":  {"os": {"macOS"}, "import": {"Darwin", "CSystem"}, "flags": {"SYSTEM_PACKAGE_DARWIN": True}},
    "Linux":   {"os": {"Linux"}, "import": {"Glibc", "CSystem"}, "flags": {}},
    "Musl":    {"os": {"Linux"}, "import": {"Musl", "CSystem"}, "flags": {}},
    "Android": {"os": {"Android"}, "import": {"Android", "Bionic", "CSystem"}, "flags": {}},
    "FreeBSD": {"os": {"FreeBSD"}, "import": {"Glibc", "CSystem"}, "flags": {}},
    "OpenBSD": {"os": {"OpenBSD"}, "import": {"Glibc", "CSystem"}, "flags": {}},
    "WASI":    {"os": {"WASI"}, "import": {"WASILibc", "CSystem"}, "flags": {}},
    "Windows": {"os": {"Windows"}, "import": {"WinSDK", "ucrt", "CSystem"}, "flags": {}},
}

DECL_KEYWORDS = r"func|var|let|init[?!]?|subscript|typealias|struct|enum|class|protocol|actor|extension|case|associatedtype|macro"
MODIFIERS = (r"public|open|internal|private|fileprivate|package|static|class|final|mutating|nonmutating|"
             r"consuming|borrowing|override|convenience|required|lazy|dynamic|indirect|nonisolated|weak|unowned|"
             r"optional|prefix|postfix|infix|__consuming")
ATTR = r"@[A-Za-z_][\w.]*(?:\((?:[^()]|\([^()]*\))*\))?"
DECL_RE = re.compile(
    rf"^\s*(?P<attrs>(?:{ATTR}\s*)*)(?P<mods>(?:(?:{MODIFIERS})(?:\([^)]*\))?\s+)*)"
    rf"(?P<kw>{DECL_KEYWORDS})(?![\w])(?P<rest>.*)$")
ATTR_ONLY_RE = re.compile(rf"^\s*(?:{ATTR}\s*)+$")
TYPE_KW = {"struct", "enum", "class", "protocol", "actor", "extension"}
LAST_KW_RE = re.compile(r"\b(extension|struct|enum|class|protocol|actor|func|init|deinit|subscript|var|let|"
                        r"case|if|guard|for|while|switch|do|catch|else|repeat|defer|get|set|willSet|didSet|"
                        r"return|in|_read|_modify|unsafeAddress|unsafeMutableAddress)\b")


# ---------------------------------------------------------------- lexing

def strip_comments_and_strings(text):
    """Blank comments and string contents (keeping newlines and quotes).

    Returns (code_text, doc_comment_line_numbers)."""
    out = list(text)
    n = len(text)
    doc_lines = set()
    raw_open = re.compile(r'(#*)("""|")')

    line_starts = [0]
    for k, ch in enumerate(text):
        if ch == "\n":
            line_starts.append(k + 1)

    def lineno(pos):
        lo, hi = 0, len(line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if line_starts[mid] <= pos:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    def scan_code(i, interp):
        depth = 0
        while i < n:
            if text.startswith("//", i):
                j = text.find("\n", i)
                j = n if j < 0 else j
                if text.startswith("///", i) and not text.startswith("////", i):
                    doc_lines.add(lineno(i))
                blank(i, j)
                i = j
                continue
            if text.startswith("/*", i):
                is_doc = text.startswith("/**", i) and not text.startswith("/**/", i)
                d, j = 0, i
                while j < n:
                    if text.startswith("/*", j):
                        d += 1
                        j += 2
                    elif text.startswith("*/", j):
                        d -= 1
                        j += 2
                        if d == 0:
                            break
                    else:
                        j += 1
                if is_doc:
                    for ln in range(lineno(i), lineno(max(i, j - 1)) + 1):
                        doc_lines.add(ln)
                blank(i, j)
                i = j
                continue
            c = text[i]
            if c in "\"#":
                m = raw_open.match(text, i)
                if m and (c == '"' or m.group(1)):
                    i = scan_string(m.end(), m.group(2), len(m.group(1)))
                    continue
            if interp:
                if c == "(":
                    depth += 1
                elif c == ")":
                    if depth == 0:
                        return i + 1
                    depth -= 1
            i += 1
        return i

    def scan_string(i, delim, hashes):
        close = delim + "#" * hashes
        esc = "\\" + "#" * hashes
        while i < n:
            if text.startswith(esc, i):
                k = i + len(esc)
                if k < n and text[k] == "(":
                    i = scan_code(k + 1, True)
                    continue
                blank(i, k + 1)
                i = k + 1
                continue
            if text.startswith(close, i):
                return i + len(close)
            if text[i] != "\n":
                out[i] = " "
            i += 1
        return i

    scan_code(0, False)
    return "".join(out), doc_lines


# ------------------------------------------------------ #if conditions

class Cond:
    """Evaluates a Swift compilation condition in an environment."""

    TOKEN = re.compile(r"\s*(\|\||&&|!|\(|\)|[A-Za-z_$][\w$]*(?:\([^()]*\))?|>=|<=|<|>|[\d.]+)")

    def __init__(self, text):
        self.text = text.strip()

    def evaluate(self, env):
        s = self.text
        toks = []
        pos = 0
        while pos < len(s):
            m = self.TOKEN.match(s, pos)
            if not m:
                raise ValueError(f"can't tokenize #if condition: {s!r}")
            toks.append(m.group(1))
            pos = m.end()
            while pos < len(s) and s[pos].isspace():
                pos += 1
        self.toks, self.k = toks, 0
        v = self._or(env)
        if self.k != len(toks):
            raise ValueError(f"trailing tokens in #if condition: {s!r}")
        return v

    def _peek(self):
        return self.toks[self.k] if self.k < len(self.toks) else None

    def _or(self, env):
        v = self._and(env)
        while self._peek() == "||":
            self.k += 1
            r = self._and(env)
            v = v or r
        return v

    def _and(self, env):
        v = self._not(env)
        while self._peek() == "&&":
            self.k += 1
            r = self._not(env)
            v = v and r
        return v

    def _not(self, env):
        if self._peek() == "!":
            self.k += 1
            return not self._not(env)
        if self._peek() == "(":
            self.k += 1
            v = self._or(env)
            assert self._peek() == ")", self.text
            self.k += 1
            return v
        tok = self._peek()
        self.k += 1
        return atom(tok, env)


def atom(tok, env):
    m = re.match(r"(\w+)\((.*)\)$", tok)
    if m:
        fn, arg = m.group(1), m.group(2).strip()
        if fn == "os":
            return arg in env["os"]
        if fn == "canImport":
            name = arg.split(",")[0].strip()
            # `canImport(Darwin, _version: N)`: assume a current SDK.
            return name in env["import"]
        if fn == "compiler":
            return True   # compiler(>=6.2) on the 6.2 toolchain
        if fn == "swift":
            return not arg.startswith("<")
        if fn == "_runtime":
            return True
        if fn == "_pointerBitWidth":
            return arg == "_64"
        if fn == "arch":
            return arg in ("arm64", "x86_64")
        if fn == "targetEnvironment":
            return False
        raise ValueError(f"unknown #if function {tok!r}")
    if tok.startswith("$"):
        return True       # $Lifetimes and other enabled features
    if tok in env["flags"]:
        return env["flags"][tok]
    if tok in COMMON:
        return COMMON[tok]
    if tok == "SYSTEM_PACKAGE_DARWIN":
        return False
    raise ValueError(f"unknown #if flag {tok!r}")


def env_for(platform):
    p = PLATFORMS[platform]
    return {"os": p["os"], "import": p["import"], "flags": p["flags"]}


def branch_active(branch, env):
    """branch = (previous conditions, current condition or None for #else)"""
    prev, cur = branch
    if any(Cond(c).evaluate(env) for c in prev):
        return False
    return True if cur is None else Cond(cur).evaluate(env)


def branch_text(branch):
    prev, cur = branch
    if cur is None:
        return "#else of " + " / ".join(prev)
    if prev:
        return "#elseif " + cur + " (after " + " / ".join(prev) + ")"
    return "#if " + cur


# ---------------------------------------------------------------- scanning

def parse_labels(sig, kw):
    """Argument labels from a parameter list, e.g. 'a b: T, _ c: U' -> ['a', '_']."""
    depth = 0
    start = sig.find("(")
    if start < 0:
        return None
    depth, j = 0, start
    while j < len(sig):
        if sig[j] in "([<":
            depth += 1
        elif sig[j] in ")]>":
            # '->' isn't a closing angle bracket
            if sig[j] == ">" and j > 0 and sig[j - 1] == "-":
                j += 1
                continue
            depth -= 1
            if depth == 0:
                break
        j += 1
    inner = sig[start + 1:j]
    params, depth, cur = [], 0, ""
    k = 0
    while k < len(inner):
        ch = inner[k]
        if ch in "([<":
            depth += 1
        elif ch in ")]>" and not (ch == ">" and k > 0 and inner[k - 1] == "-"):
            depth -= 1
        if ch == "," and depth == 0:
            params.append(cur)
            cur = ""
        else:
            cur += ch
        k += 1
    if cur.strip():
        params.append(cur)
    labels = []
    for p in params:
        head = p.split(":")[0].strip()
        head = re.sub(rf"{ATTR}\s*", "", head).strip()
        words = head.split()
        if not words:
            continue
        if len(words) >= 2:
            labels.append(words[0])
        else:
            labels.append("_" if kw == "subscript" else words[0])
    return labels


def decl_name(kw, rest, sig):
    rest = rest.strip()
    sig = re.sub(rf"{ATTR}\s*", " ", sig)
    base = kw.rstrip("?!")
    km = re.search(rf"(?<![\w.]){re.escape(base)}(?![\w])", sig)
    after_kw = sig[km.end():] if km else sig
    if base in ("init", "subscript"):
        labels = parse_labels(after_kw, base) or []
        return kw + "(" + "".join(f"{l}:" for l in labels) + ")", labels
    if kw == "func":
        m = re.match(r"\s*([A-Za-z_]\w*|[^\s(<]+)", after_kw)
        name = m.group(1) if m else rest.split("(")[0]
        tail = after_kw[m.end():] if m else after_kw
        # Skip generic parameters.
        if tail.lstrip().startswith("<"):
            t = tail.lstrip()
            depth = 0
            for j, ch in enumerate(t):
                if ch == "<":
                    depth += 1
                elif ch == ">":
                    depth -= 1
                    if depth == 0:
                        tail = t[j + 1:]
                        break
        labels = parse_labels(tail, "func") or []
        return name + "(" + "".join(f"{l}:" for l in labels) + ")", labels
    if kw == "case":
        return rest.split("(")[0].split("=")[0].split(",")[0].strip(), []
    m = re.match(r"([A-Za-z_][\w.]*)", rest)
    return (m.group(1) if m else rest[:40]), []


def collect_signature(code_lines, idx):
    """Join lines from idx until the parameter list closes and a '{' or the
    end of the declaration is reached."""
    text, depth = "", 0
    k = idx
    while k < len(code_lines) and k < idx + 60:
        line = code_lines[k]
        for j, ch in enumerate(line):
            if ch in "([":
                depth += 1
            elif ch in ")]":
                depth -= 1
            elif ch == "{" and depth <= 0:
                return re.sub(r"\s+", " ", text + " " + line[:j]).strip()
        text += " " + line
        nxt = code_lines[k + 1].strip() if k + 1 < len(code_lines) else ""
        if depth <= 0 and not re.match(r"^(->|throws|rethrows|async|where|&|\.|:|=)", nxt) \
                and not re.search(r"(,|->|:|=|&|\()$", line.strip()):
            break
        k += 1
    return re.sub(r"\s+", " ", text).strip()


def scan_file(root, rel, module):
    path = os.path.join(root, rel)
    raw = open(path, encoding="utf-8").read()
    code, doc_lines = strip_comments_and_strings(raw)
    code_lines = code.split("\n")
    raw_lines = raw.split("\n")

    in_linux_only_dir = any(rel.startswith(d + "/") for d in LINUX_ONLY_DIRS)
    decls = []
    types = []          # every struct/enum/class/protocol/actor declaration
    errors = []         # condition stacks of `#error` directives
    cond_stack = []     # list of [prev_conds, cur_cond]
    scopes = []         # stack of dicts
    header = ""
    pending_attrs = []
    pending_attr_open = None
    pending_attr_open_raw = None
    attr_lines = set()

    def raw_attrs(code_text, raw_text):
        """Attributes found in code_text, spelled as in raw_text (same positions)."""
        return [raw_text[m.start():m.end()] for m in re.finditer(ATTR, code_text)]

    for idx, line in enumerate(code_lines):
        lineno = idx + 1
        raw_line = raw_lines[idx] if idx < len(raw_lines) else line
        s = line.strip()
        # Compiler directives.
        m = re.match(r"^#(if|elseif|else|endif)\b(.*)$", s)
        if m:
            d, rest = m.group(1), m.group(2).strip()
            if d == "if":
                cond_stack.append([[], rest])
            elif d == "elseif":
                prev, cur = cond_stack[-1]
                cond_stack[-1] = [prev + [cur], rest]
            elif d == "else":
                prev, cur = cond_stack[-1]
                cond_stack[-1] = [prev + [cur], None]
            elif d == "endif":
                cond_stack.pop()
            continue
        if s.startswith("#error"):
            errors.append([(tuple(b[0]), b[1]) for b in cond_stack])
            continue
        if s.startswith("#"):
            continue

        # Attribute-only lines (possibly spanning lines).
        if pending_attr_open is not None:
            attr_lines.add(idx)
            pending_attr_open += " " + s
            pending_attr_open_raw += " " + raw_line.strip()
            if pending_attr_open.count("(") <= pending_attr_open.count(")"):
                pending_attrs.append(re.sub(r"\s+", " ", pending_attr_open_raw))
                pending_attr_open = None
            header += " " + line
            continue
        if s.startswith("@") and s.count("(") > s.count(")"):
            attr_lines.add(idx)
            pending_attr_open = s
            pending_attr_open_raw = raw_line.strip()
            header += " " + line
            continue
        if s and ATTR_ONLY_RE.match(s):
            attr_lines.add(idx)
            pending_attrs.extend(raw_attrs(line, raw_line))
            header += " " + line
            continue

        dm = DECL_RE.match(line)
        if dm and s:
            # A new declaration starts; drop header text from earlier ones.
            header = " ".join(pending_attrs) + " "
            a0, a1 = dm.span("attrs")
            attrs = pending_attrs + raw_attrs(line[a0:a1], raw_line[a0:a1])
            mods = (dm.group("mods") or "").split()
            kw = dm.group("kw")
            rest = dm.group("rest")
            is_class_member_kw = kw == "class" and re.match(r"\s*(func|var|let|subscript|init)\b", rest)
            if is_class_member_kw:
                # `class func` / `class var`: the keyword is a modifier.
                mods.append("class")
                m2 = re.match(r"\s*(func|var|let|subscript|init[?!]?)(?![\w])(.*)$", rest)
                kw, rest = m2.group(1), m2.group(2)
            enclosing_public_ext = next((sc for sc in reversed(scopes) if sc["kind"] == "extension"), None)
            explicit_access = next((m_ for m_ in mods if m_.split("(")[0] in
                                    ("public", "open", "internal", "private", "fileprivate", "package")), None)
            access = explicit_access.split("(")[0] if explicit_access else None
            if access is None and scopes and scopes[-1]["kind"] == "extension" and scopes[-1]["access"] == "public" and kw != "extension":
                access = "public (from public extension)"
            ufi = any(a.startswith("@usableFromInline") for a in attrs)
            if access and (access.startswith("public") or access == "open" or (ufi and access == "internal")) \
                    or (ufi and access is None):
                sig = collect_signature(code_lines, idx)
                name, labels = decl_name(kw, rest, sig)
                # Doc comment: the nearest line above that isn't an attribute.
                k = idx - 1
                while k >= 0 and (k + 1) not in doc_lines and k in attr_lines:
                    k -= 1
                has_doc = k >= 0 and (k + 1) in doc_lines
                scope_chain = [sc["name"] for sc in scopes if sc["kind"] != "other"]
                avail = [a for a in attrs if a.startswith("@available")]
                scope_avail = [a for sc in scopes if sc["kind"] != "other" for a in sc["attrs"] if a.startswith("@available")]
                branches = [tuple(b) for b in cond_stack]
                platforms = []
                for p in PLATFORMS:
                    env = env_for(p)
                    if in_linux_only_dir and p not in ("Linux", "Musl"):
                        continue
                    try:
                        if all(branch_active((tuple(b[0]), b[1]), env) for b in cond_stack):
                            platforms.append(p)
                    except ValueError as e:
                        platforms.append(f"?{p}")
                underscored = name.startswith("_") or any(l.startswith("_") and l != "_" for l in labels)
                decls.append({
                    "module": module,
                    "file": rel,
                    "line": lineno,
                    "kw": kw,
                    "name": name,
                    "labels": labels,
                    "access": access if access else ("internal" if ufi else None),
                    "usableFromInline": ufi,
                    "modifiers": mods,
                    "attributes": attrs,
                    "availability": avail,
                    "scopeAvailability": scope_avail,
                    "scopes": scope_chain,
                    "scopeAccess": [sc["access"] for sc in scopes if sc["kind"] != "other"],
                    "scopeKinds": [sc["kind"] for sc in scopes if sc["kind"] != "other"],
                    "conditions": [branch_text((tuple(b[0]), b[1])) for b in cond_stack],
                    "platforms": platforms,
                    "hasDoc": has_doc,
                    "underscored": underscored,
                    "unavailable": [a for a in avail if re.search(r"\bunavailable\b", a)],
                    "deprecated": [a for a in avail if re.search(r"\bdeprecated\b", a)],
                    "signature": sig[:400],
                })
            pending_attrs = []
        elif s:
            pending_attrs = []

        # Braces and scopes.
        for ch_i, ch in enumerate(line):
            if ch == "{":
                h = (header + " " + line[:ch_i])
                kws = list(LAST_KW_RE.finditer(h))
                last = kws[-1] if kws else None
                if last and last.group(1) in TYPE_KW:
                    # Header: text from this keyword; modifiers/attributes before it.
                    before = h[:last.start()]
                    after = h[last.end():]
                    nm = re.match(r"\s*([A-Za-z_][\w.]*)", after)
                    mods_before = re.findall(r"\b(public|open|internal|private|fileprivate|package)\b",
                                             re.sub(ATTR, " ", before.split("}")[-1].split(";")[-1]))
                    attrs_before = re.findall(ATTR, before.split("}")[-1].split(";")[-1])
                    scopes.append({"kind": last.group(1), "name": nm.group(1) if nm else "?",
                                   "access": mods_before[-1] if mods_before else None,
                                   "attrs": attrs_before + [], "line": lineno})
                    if last.group(1) != "extension":
                        # Every type, whatever its access, so extensions of
                        # non-public types can be recognized.
                        chain = [sc["name"] for sc in scopes if sc["kind"] != "other"]
                        types.append({"module": module, "name": ".".join(chain),
                                      "access": mods_before[-1] if mods_before else "internal",
                                      "file": rel, "line": lineno})
                else:
                    scopes.append({"kind": "other", "name": None, "access": None, "attrs": [], "line": lineno})
                header = ""
            elif ch == "}":
                if scopes:
                    scopes.pop()
                header = ""
            elif ch == ";":
                header = ""
        tail = line[max(line.rfind("{"), line.rfind("}"), line.rfind(";")) + 1:]
        header += " " + tail
        # Keep the header from growing without bound across many body-less lines.
        if len(header) > 4000:
            header = header[-4000:]

    # Platforms where an `#error` in this file is active can't build the file.
    failing = set()
    for stack in errors:
        for p in PLATFORMS:
            if all(branch_active(b, env_for(p)) for b in stack):
                failing.add(p)
    return decls, failing, types


def main():
    root, out = sys.argv[1], sys.argv[2]
    all_decls = []
    all_types = []
    module_failing = {}
    for d, module in MODULE_DIRS.items():
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        failing = set()
        decls = []
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                if f.endswith(".swift"):
                    rel = os.path.relpath(os.path.join(dirpath, f), root)
                    ds, fail, ts = scan_file(root, rel, module)
                    decls.extend(ds)
                    all_types.extend(ts)
                    failing |= fail
        # A module that hits `#error` on a platform doesn't build there at all.
        for dcl in decls:
            dcl["platforms"] = [p for p in dcl["platforms"] if p not in failing]
        module_failing[module] = sorted(failing)
        all_decls.extend(decls)
    all_decls.sort(key=lambda d: (d["file"], d["line"]))
    json.dump({"declarations": all_decls, "types": all_types, "moduleUnsupportedPlatforms": module_failing,
               "platforms": list(PLATFORMS)}, open(out, "w"), indent=1)
    print(f"scan_sources: {len(all_decls)} declarations from {root} -> {out}; "
          f"#error platforms: {module_failing}")


if __name__ == "__main__":
    main()
