#!/usr/bin/env python3
"""Index the declarations of a source tree by extent: where each one starts
and ends, which top-level block holds it, and which tests are in it.

api-delta's scan_sources.py finds public declarations and their platforms,
but not where a declaration ends or which extension block it's in. Carving
needs both: a bundle cites line ranges, and the top-level block (one
`extension FilePath { ... }` per C function family, in this repository's
style) is the unit the graph clusters. This reuses scan_sources.py's lexer,
declaration pattern, and `#if` evaluation by importing it, rather than
copying them.

For every Swift file under the given directories it records:
  - blocks: the top-level declarations (types, extensions, free functions),
    with the type they declare or extend, their first and last lines
    (doc comment and attributes included), their `#if` conditions and the
    platforms those allow, and the `// MARK:` title above them;
  - decls: every declaration at any depth and access level, with its keyword
    line, extent, name, enclosing types, and whether it's a test (an XCTest
    `test...` method or a swift-testing `@Test` function).
For C files (Sources/CSystem) it records the extent of each top-level
function, macro, and declaration, for the C shims a wrapper needs.

Usage: source_index.py ROOT OUT.json DIR...
  DIRs are relative to ROOT, e.g. Sources/System Tests Sources/Samples.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "api-delta", "scripts"))
import scan_sources as ss  # noqa: E402  (api-delta's scanner, reused)

MODULES = {"Sources/System": "SystemPackage", "Sources/SystemSockets": "SystemSockets",
           "Sources/Samples": "Samples", "Sources/CSystem": "CSystem"}
TYPE_KWS = {"struct", "enum", "class", "protocol", "actor", "extension"}
MARK_RE = re.compile(r"^\s*//\s*MARK:\s*-?\s*(.*?)\s*$")
# A line that continues the statement on the line before it.
CONT_NEXT = re.compile(r"^(->|throws\b|rethrows\b|async\b|where\b|&|\.|:|=|\{|\()")
CONT_END = re.compile(r"(,|->|:|=|&|\(|\[|<)$")


def module_for(rel):
    for d, m in MODULES.items():
        if rel.startswith(d + "/"):
            return m
    if rel.startswith("Tests/"):
        return rel.split("/")[1]
    return None


def platforms_for(stack, in_linux_only_dir):
    out = []
    for p in ss.PLATFORMS:
        if in_linux_only_dir and p not in ("Linux", "Musl"):
            continue
        try:
            if all(ss.branch_active((tuple(b[0]), b[1]), ss.env_for(p)) for b in stack):
                out.append(p)
        except (ValueError, AssertionError):
            out.append("?" + p)
    return out


def subject_of(kw, rest):
    """The type a top-level `extension` extends or a type declaration names."""
    rest = rest.strip()
    m = re.match(r"([A-Za-z_][\w.]*)", rest)
    name = m.group(1) if m else rest[:40]
    if kw == "extension":
        return name
    return name


def index_swift(root, rel):
    raw = open(os.path.join(root, rel), encoding="utf-8").read()
    code, doc_lines = ss.strip_comments_and_strings(raw)
    raw_lines = raw.split("\n")
    lines = code.split("\n")
    n = len(lines)
    in_linux_only_dir = any(rel.startswith(d + "/") for d in ss.LINUX_ONLY_DIRS)

    # Brace depth at the start of each line, and the position of every brace.
    depth_at = [0] * (n + 1)
    d = 0
    for i, line in enumerate(lines):
        depth_at[i] = d
        for ch in line:
            if ch == "{":
                d += 1
            elif ch == "}":
                d -= 1
    depth_at[n] = d

    def find_end(i, col):
        """Last line of the declaration whose keyword is at (i, col)."""
        paren = 0
        k, c = i, col
        while k < n:
            line = lines[k]
            while c < len(line):
                ch = line[c]
                if ch in "([":
                    paren += 1
                elif ch in ")]":
                    paren -= 1
                elif ch == ";" and paren <= 0:
                    return k
                elif ch == "{" and paren <= 0:
                    # The body: find the matching brace.
                    bd = 0
                    kk, cc = k, c
                    while kk < n:
                        ln = lines[kk]
                        while cc < len(ln):
                            if ln[cc] == "{":
                                bd += 1
                            elif ln[cc] == "}":
                                bd -= 1
                                if bd == 0:
                                    return kk
                            cc += 1
                        kk += 1
                        cc = 0
                    return n - 1
                elif ch == "}" and paren <= 0:
                    # The enclosing scope closes, so the declaration ended.
                    return k if line[:c].strip() else max(i, k - 1)
                c += 1
            if paren <= 0:
                stripped = line.strip()
                nxt = k + 1
                while nxt < n and not lines[nxt].strip():
                    nxt += 1
                nxt_s = lines[nxt].strip() if nxt < n else ""
                if nxt_s.startswith("#"):
                    return k
                if not CONT_END.search(stripped) and not CONT_NEXT.match(nxt_s):
                    return k
            k += 1
            c = 0
        return n - 1

    blocks, decls = [], []
    cond_stack = []
    scopes = []          # open declarations: [decl index, index of their last line]
    lead = None          # first line of the doc comment / attributes above
    attr_open = 0        # unbalanced parentheses of a multi-line attribute
    attrs = []
    marks = {}           # depth -> last MARK title at that depth
    for i, line in enumerate(lines):
        s = line.strip()
        raw_s = raw_lines[i].strip() if i < len(raw_lines) else ""
        mk = MARK_RE.match(raw_lines[i]) if i < len(raw_lines) else None
        if mk:
            marks[depth_at[i]] = mk.group(1)
        # Close scopes that ended before this line.
        while scopes and i > scopes[-1][1]:
            scopes.pop()
        m = re.match(r"^#(if|elseif|else|endif)\b(.*)$", s)
        if m:
            dname, rest = m.group(1), m.group(2).strip()
            if dname == "if":
                cond_stack.append([[], rest])
            elif dname == "elseif":
                prev, cur = cond_stack[-1]
                cond_stack[-1] = [prev + [cur], rest]
            elif dname == "else":
                prev, cur = cond_stack[-1]
                cond_stack[-1] = [prev + [cur], None]
            elif cond_stack:
                cond_stack.pop()
            continue
        if (i + 1) in doc_lines and not s:
            if lead is None:
                lead = i
            continue
        if attr_open > 0:
            attr_open += s.count("(") - s.count(")")
            attrs[-1] += " " + raw_s
            continue
        if s.startswith("@") and s.count("(") > s.count(")"):
            if lead is None:
                lead = i
            attr_open = s.count("(") - s.count(")")
            attrs.append(raw_s)
            continue
        if s and ss.ATTR_ONLY_RE.match(s):
            if lead is None:
                lead = i
            attrs.extend(re.findall(ss.ATTR, raw_s))
            continue
        if not s:
            if lead is not None and (i + 1) not in doc_lines:
                lead, attrs = None, []
            continue
        dm = ss.DECL_RE.match(line)
        if dm and not s.startswith("#"):
            kw = dm.group("kw")
            rest = dm.group("rest")
            mods = (dm.group("mods") or "").split()
            if kw == "class" and re.match(r"\s*(func|var|let|subscript|init)\b", rest):
                m2 = re.match(r"\s*(func|var|let|subscript|init[?!]?)(?![\w])(.*)$", rest)
                kw, rest = m2.group(1), m2.group(2)
                mods.append("class")
            line_attrs = attrs + re.findall(ss.ATTR, raw_lines[i][dm.start("attrs"):dm.end("attrs")])
            col = dm.start("kw")
            end = find_end(i, col)
            sig = ss.collect_signature(lines, i)
            try:
                name, labels = ss.decl_name(kw, rest, sig)
            except Exception:
                name, labels = rest.strip()[:40], []
            depth = depth_at[i]
            enclosing = [decls[sc[0]] for sc in scopes]
            type_scopes = [e for e in enclosing if e["kw"] in TYPE_KWS]
            access = next((x.split("(")[0] for x in mods if x.split("(")[0] in
                           ("public", "open", "internal", "private", "fileprivate", "package")), None)
            rec = {
                "line": i + 1,
                "start": (lead if lead is not None else i) + 1,
                "end": end + 1,
                "kw": kw,
                "name": name,
                "labels": labels,
                "access": access,
                "modifiers": mods,
                "attributes": line_attrs,
                "scopes": [e["name"] for e in type_scopes],
                "scopeKinds": [e["kw"] for e in type_scopes],
                "parent": enclosing[-1]["id"] if enclosing else None,
                "block": enclosing[0]["block"] if enclosing else None,
                "depth": depth,
                "conditions": [ss.branch_text((tuple(b[0]), b[1])) for b in cond_stack],
                "platforms": platforms_for(cond_stack, in_linux_only_dir),
                "mark": marks.get(depth),
                "signature": sig[:300],
                "id": len(decls),
            }
            if kw in TYPE_KWS:
                rec["subject"] = subject_of(kw, rest)
                if kw != "extension":
                    rec["subject"] = ".".join(rec["scopes"] + [rec["subject"]])
                rec["inherits"] = header_inheritance(sig)
            if not enclosing:
                rec["block"] = len(blocks)
                blocks.append({
                    "id": len(blocks),
                    "decl": rec["id"],
                    "kind": kw,
                    "subject": rec.get("subject", name),
                    "name": name,
                    "line": i + 1,
                    "start": rec["start"],
                    "end": end + 1,
                    "conditions": rec["conditions"],
                    "platforms": rec["platforms"],
                    "availability": [a for a in line_attrs if a.startswith("@available")],
                    "access": access,
                    "mark": marks.get(0),
                })
            decls.append(rec)
            # A declaration that runs past this line encloses what follows,
            # up to its last line.
            if end > i:
                scopes.append([rec["id"], end])
            lead, attrs = None, []
            continue
        lead, attrs = None, []

    # Tests: XCTest methods named test... in an XCTestCase subclass, and
    # swift-testing @Test functions.
    for rec in decls:
        rec["isTest"] = False
        if rec["kw"] != "func":
            continue
        if any(a.startswith("@Test") for a in rec["attributes"]):
            rec["isTest"] = True
        elif rec["name"].startswith("test") and rec["parent"] is not None:
            p = decls[rec["parent"]]
            if p["kw"] == "class" and "XCTestCase" in " ".join(p.get("inherits") or []):
                rec["isTest"] = True
            elif p["kw"] == "extension":
                rec["isTest"] = True   # an extension of a test class
    return {"blocks": blocks, "decls": decls, "lines": n}


def header_inheritance(sig):
    m = re.search(r"^[^:{]*?\b(?:struct|enum|class|protocol|actor|extension)\s+[\w.]+(?:<[^>]*>)?\s*:\s*([^{]*)", sig)
    if not m:
        return []
    text = re.split(r"\bwhere\b", m.group(1))[0]
    return [t.strip() for t in text.split(",") if t.strip()]


C_DECL = re.compile(r"^\s*(?:static\s+|extern\s+|inline\s+|__attribute__\(\([^)]*\)\)\s*)*"
                    r"[A-Za-z_][\w\s\*]*?\b([A-Za-z_]\w*)\s*\(")
C_MACRO = re.compile(r"^\s*#\s*define\s+([A-Za-z_]\w*)")


def index_c(root, rel):
    """Top-level functions, macros and declarations of a C file, by extent."""
    raw = open(os.path.join(root, rel), encoding="utf-8", errors="replace").read()
    lines = raw.split("\n")
    out = []
    depth = 0
    i = 0
    comment_start = None
    in_block_comment = False
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if in_block_comment:
            if "*/" in s:
                in_block_comment = False
            i += 1
            continue
        if depth == 0 and (s.startswith("//") or s.startswith("/*")):
            if comment_start is None:
                comment_start = i
            if s.startswith("/*") and "*/" not in s:
                in_block_comment = True
            i += 1
            continue
        if depth == 0:
            mm = C_MACRO.match(line)
            if mm:
                end = i
                while lines[end].rstrip().endswith("\\") and end + 1 < len(lines):
                    end += 1
                out.append({"name": mm.group(1), "kind": "macro", "line": i + 1,
                            "start": (comment_start if comment_start is not None else i) + 1, "end": end + 1})
                comment_start = None
                i = end + 1
                continue
            mf = C_DECL.match(line)
            if mf and not s.startswith("#") and not s.startswith("typedef"):
                # Up to the ';' or the matching '}'.
                k, bd, seen_body = i, 0, False
                while k < len(lines):
                    for ch in lines[k]:
                        if ch == "{":
                            bd += 1
                            seen_body = True
                        elif ch == "}":
                            bd -= 1
                    if (seen_body and bd == 0) or (not seen_body and ";" in lines[k]):
                        break
                    k += 1
                out.append({"name": mf.group(1), "kind": "function", "line": i + 1,
                            "start": (comment_start if comment_start is not None else i) + 1, "end": k + 1})
                comment_start = None
                i = k + 1
                continue
        if s and not s.startswith("#"):
            comment_start = None
        if not s:
            comment_start = None
        depth += line.count("{") - line.count("}")
        i += 1
    return {"cdecls": out, "lines": len(lines)}


def main():
    root, out = sys.argv[1], sys.argv[2]
    dirs = sys.argv[3:]
    files = {}
    for d in dirs:
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        for dirpath, _, names in os.walk(base):
            for f in sorted(names):
                rel = os.path.relpath(os.path.join(dirpath, f), root)
                if f.endswith(".swift"):
                    info = index_swift(root, rel)
                elif f.endswith((".c", ".h")):
                    info = index_c(root, rel)
                else:
                    continue
                info["module"] = module_for(rel)
                files[rel] = info
    json.dump({"files": files}, open(out, "w"), indent=0)
    nd = sum(len(v.get("decls", [])) for v in files.values())
    nb = sum(len(v.get("blocks", [])) for v in files.values())
    nt = sum(1 for v in files.values() for x in v.get("decls", []) if x.get("isTest"))
    print(f"source_index: {len(files)} files, {nb} top-level blocks, {nd} declarations, {nt} tests -> {out}")


if __name__ == "__main__":
    main()
