#!/usr/bin/env python3
"""Inventory FileDescriptor's API, and generate OwnedFD forwards for all of it.

  forwarding.py inventory [ROOT]         the public members of FileDescriptor
                                         extensions in ROOT/Sources, with their
                                         availability and #if conditions
  forwarding.py generate [ROOT] > file   an `extension OwnedFD` forward for
                                         every instance member that doesn't
                                         change ownership

ROOT defaults to the package root. The parser handles the regular layout of
this package's sources, not Swift in general: one declaration per line group,
`public` on the line that starts the declaration, and bodies in braces.
"""
import os, re, sys

# Members whose forwards would change ownership, so they need hand-written
# OwnedFD versions (or none), and members OwnedFD already defines.
OWNERSHIP = {
    "close": "OwnedFD.close() consumes the owner",
    "closeAfter": "an owner closes itself",
    "duplicate": "returns a new descriptor, which should come back owned",
}

def strip_comment(line):
    # Drops a trailing `//` comment, ignoring `//` inside string literals.
    out, in_string = [], False
    i = 0
    while i < len(line):
        c = line[i]
        if c == '"' and (i == 0 or line[i - 1] != "\\"):
            in_string = not in_string
        if not in_string and line.startswith("//", i):
            break
        out.append(c)
        i += 1
    return "".join(out)

def brace_delta(line):
    code = strip_comment(line)
    code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
    return code.count("{") - code.count("}")

class Member:
    def __init__(self, **kw): self.__dict__.update(kw)

def parse_file(path, rel):
    lines = open(path).read().split("\n")
    members = []
    conditions = []          # the #if stack, as strings
    pending_attrs = []       # attributes seen before a declaration
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        if line.startswith("#if "):
            conditions.append(line[4:].split("//")[0].strip()); i += 1; continue
        if line.startswith("#elseif "):
            conditions[-1] = "!(%s) && %s" % (conditions[-1], line[8:].split("//")[0].strip()); i += 1; continue
        if line.startswith("#else"):
            conditions[-1] = "!(%s)" % conditions[-1]; i += 1; continue
        if line.startswith("#endif"):
            conditions.pop(); i += 1; continue
        if line.startswith("@") and not raw.startswith(" "):
            pending_attrs.append(line); i += 1; continue
        if re.match(r"^extension FileDescriptor(\s*\{|\s*:|\s+where)", line):
            ext_attrs = pending_attrs
            pending_attrs = []
            ext_conditions = list(conditions)
            depth = brace_delta(raw)
            i += 1
            member_attrs = []
            inner_conditions = []
            while i < len(lines) and depth > 0:
                raw = lines[i]
                line = raw.strip()
                if line.startswith("///") or line.startswith("//") or not line:
                    i += 1; continue
                if line.startswith("#if "):
                    inner_conditions.append(line[4:].split("//")[0].strip()); i += 1; continue
                if line.startswith("#elseif "):
                    inner_conditions[-1] = "!(%s) && %s" % (inner_conditions[-1], line[8:].strip()); i += 1; continue
                if line.startswith("#else"):
                    inner_conditions[-1] = "!(%s)" % inner_conditions[-1]; i += 1; continue
                if line.startswith("#endif"):
                    inner_conditions.pop(); i += 1; continue
                if depth == 1 and line.startswith("@"):
                    member_attrs.append(line); i += 1; continue
                if depth == 1 and re.match(r"^public\b", line):
                    # Gather the declaration up to its body's opening brace.
                    decl_lines = [raw]
                    j = i
                    joined = strip_comment(raw)
                    while "{" not in joined and j + 1 < len(lines):
                        j += 1
                        decl_lines.append(lines[j])
                        joined += "\n" + strip_comment(lines[j])
                    decl = joined[: joined.index("{")].strip() if "{" in joined else joined.strip()
                    body_depth = sum(brace_delta(l) for l in decl_lines)
                    k = j
                    while body_depth > 0 and k + 1 < len(lines):
                        k += 1
                        body_depth += brace_delta(lines[k])
                    text = "\n".join(lines[i : k + 1])
                    body = text[text.index("{") + 1 : text.rindex("}")] if "{" in text else ""
                    members.append(Member(
                        file=rel, line=i + 1, decl=decl, attrs=member_attrs,
                        ext_attrs=ext_attrs, body=body,
                        conditions=ext_conditions + inner_conditions))
                    member_attrs = []
                    i = k + 1
                    continue
                if depth == 1 and not line.startswith("}"):
                    member_attrs = []
                depth += brace_delta(raw)
                i += 1
            continue
        if line and not line.startswith("//") and not line.startswith("@"):
            pending_attrs = []
        i += 1
    return members

def all_members(root):
    # `rawValue` is declared in the struct itself, not in an extension.
    members = [Member(
        file="Sources/System/FileDescriptor.swift", line=21, body="",
        decl="public let rawValue: CInt", attrs=["@_alwaysEmitIntoClient"],
        ext_attrs=["@available(System 0.0.1, *)"], conditions=[])]
    for base in ("Sources/System", "Sources/SystemSockets"):
        for dirpath, _, files in os.walk(os.path.join(root, base)):
            for name in sorted(files):
                if name.endswith(".swift"):
                    path = os.path.join(dirpath, name)
                    members += parse_file(path, os.path.relpath(path, root))
    return members

def kind(m):
    if re.match(r"public (struct|enum|class|typealias)\b", m.decl): return "type"
    if re.search(r"\bstatic\b", m.decl): return "static"
    if re.search(r"\b(var|let)\b", m.decl): return "property"
    if re.search(r"\binit\b", m.decl): return "init"
    return "method"

def name(m):
    match = re.search(r"\b(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)", m.decl)
    return match.group(1) if match else "init"

def unavailable(m):
    return any(re.match(r"@available\(\*\s*,\s*unavailable", a) for a in m.attrs)

def availability(m):
    attrs = [a for a in m.attrs if a.startswith("@available")]
    attrs = attrs or [a for a in m.ext_attrs if a.startswith("@available")]
    return " ".join(a.replace("@available(", "").rstrip(")") for a in attrs) or "-"

def signature_label(m):
    """`name(label:label:)` for a func declaration."""
    decl = m.decl
    n = name(m)
    if kind(m) == "type":
        return re.match(r"public \w+ (\w+)", decl).group(1)
    if re.search(r"\b(var|let)\b", decl):
        return n
    params = split_params(param_list(decl))
    labels = []
    for p in params:
        first = p.split(":")[0].split()
        labels.append(first[0] if first else "_")
    return "%s(%s)" % (n, "".join(l + ":" for l in labels))

def param_list(decl):
    start = decl.index("(", decl.index(name_token(decl)))
    depth, i = 0, start
    while True:
        c = decl[i]
        if c in "([<": depth += 1
        elif c in ")]>": depth -= 1
        if depth == 0: break
        i += 1
    return decl[start + 1 : i], i

def name_token(decl):
    return re.search(r"\bfunc\s+[A-Za-z_][A-Za-z0-9_]*|\binit\b", decl).group(0)

def split_params(text):
    if isinstance(text, tuple): text = text[0]
    parts, depth, cur = [], 0, ""
    for c in text:
        if c in "([<": depth += 1
        elif c in ")]>": depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip()); cur = ""
        else:
            cur += c
    if cur.strip(): parts.append(cur.strip())
    return parts

NESTED_TYPES = set()

def qualify(text):
    # Names like `AccessMode` resolve inside `extension FileDescriptor`, but
    # not inside `extension OwnedFD`.
    for t in NESTED_TYPES:
        text = re.sub(r"(?<![.\w])%s\b" % t, "FileDescriptor." + t, text)
    return text

def forward(m):
    """The source of an OwnedFD method that forwards to `m`."""
    decl = qualify(re.sub(r"\s+", " ", m.decl.replace("\n", " ")))
    n = name(m)
    if kind(m) == "property":
        type_ = decl.split(":", 1)[1].strip()
        body = "_descriptor.%s" % n
        sig = "public var %s: %s" % (n, type_.split("{")[0].strip())
        return sig, body
    params_text, close_index = param_list(decl)
    after = decl[close_index + 1 :].strip()           # throws, return type, where
    head = decl[: decl.index("(", decl.index(name_token(decl)))]
    args = []
    for p in split_params(params_text):
        before_colon, type_ = p.split(":", 1)
        words = before_colon.split()
        label, local = (words[0], words[-1]) if len(words) > 1 else (words[0], words[0])
        value = ("&" + local) if type_.strip().startswith("inout") else local
        args.append(value if label == "_" else "%s: %s" % (label, value))
    throws = re.search(r"\bthrows\b|\brethrows\b", after) is not None
    call = "_descriptor.%s(%s)" % (n, ", ".join(args))
    body = ("try " if throws else "") + call
    # An untyped-throws method whose body is the usual `try _foo(...).get()`
    # can forward to `_foo` and throw Errno, as the hand-written forwards do.
    layered = re.fullmatch(
        r"\s*(?:return\s+)?try\s+(_\w+\((?:.|\n)*\))\s*\.get\(\)\s*", m.body)
    if re.search(r"\bthrows\b(?!\s*\()", after) and layered:
        after = re.sub(r"\bthrows\b(?!\s*\()", "throws(Errno)", after, count=1)
        body = "try _descriptor.%s.get()" % re.sub(r"\s+", " ", layered.group(1)).strip()
    sig = "%s(%s) %s" % (head.strip(), params_text.strip(), after)
    return re.sub(r"\s+", " ", sig).strip(), body

def is_forwardable(m):
    return kind(m) in ("method", "property") and not unavailable(m) and name(m) not in OWNERSHIP

def inventory(root):
    members = [m for m in all_members(root) if not unavailable(m)]
    rows = []
    for m in members:
        cond = " && ".join("(%s)" % c for c in m.conditions) or "all"
        note = OWNERSHIP.get(name(m), "")
        rows.append((kind(m), signature_label(m),
                     availability(m), cond, "%s:%d" % (m.file, m.line), note))
    rows.sort(key=lambda r: (r[0], r[1]))
    print("| kind | member | availability | platforms (#if) | declared at | ownership |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(c.replace("|", "\\|") for c in r) + " |")
    counts = {}
    for r in rows: counts[r[0]] = counts.get(r[0], 0) + 1
    print()
    print("Totals: " + ", ".join("%d %s" % (v, k) for k, v in sorted(counts.items())) +
          "; %d instance members to forward" % sum(1 for m in members if is_forwardable(m)))

IMPORTS = """\
// For C types in forwarded signatures, such as `timespec`, as in FileTimes.swift.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import CSystem
import Android
#endif
"""

def generate(root):
    everything = all_members(root)
    NESTED_TYPES.update(signature_label(m) for m in everything if kind(m) == "type")
    members = [m for m in everything if is_forwardable(m)]
    print("// GENERATED by Prototype/Forwarding/forwarding.py from the FileDescriptor")
    print("// extensions in Sources. Each member forwards to the FileDescriptor")
    print("// member of the same name; see it for documentation.")
    print()
    print(IMPORTS)
    for m in members:
        conds = m.conditions
        for c in conds: print("#if %s" % c)
        for a in m.ext_attrs:
            if a.startswith("@available"): print(a)
        print("extension OwnedFD {")
        print("  /// Forwards to `FileDescriptor.%s`." % signature_label(m))
        attrs = [a for a in m.attrs if not a.startswith("@usableFromInline")]
        if "@_alwaysEmitIntoClient" not in attrs: attrs.insert(0, "@_alwaysEmitIntoClient")
        for a in attrs: print("  " + a)
        sig, body = forward(m)
        if kind(m) == "property":
            print("  %s { %s }" % (sig, body))
        else:
            print("  %s {" % sig)
            print("    %s" % body)
            print("  }")
        print("}")
        for c in reversed(conds): print("#endif // %s" % c)
        print()

if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "inventory"
    root = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..")
    {"inventory": inventory, "generate": generate}[command](os.path.abspath(root))
