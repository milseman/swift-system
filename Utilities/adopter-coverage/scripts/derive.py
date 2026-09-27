#!/usr/bin/env python3
"""Derive which C interfaces System covers at a commit, from its own
sources, so the mapping needn't say.

System's doc comments name what each declaration wraps: "The corresponding
C function is `fsync`.", "The corresponding C constant is `O_CLOEXEC`.",
"The corresponding C type is `struct flock`.", and the like for errors,
macros, fields and global variables. Its CInterop typealiases name C types
(`typealias Stat = stat`). This script reads both, for every public
declaration api-delta's scan found, and says for each C name which
declarations cover it and where they compile.

A sentence's first name is its subject. The words before each later name
give that name's role:
  - an alternative spelling of the subject, after `or`, `and`, a comma or
    `also known as` (`chmod`, or `lchmod` if ...; `RENAME_EXCL` on Darwin,
    and `RENAME_NOREPLACE` on Linux);
  - an argument the declaration passes, after `with`, `at` or `for` (`fcntl`,
    with the `F_GETFL` command): covered, since the declaration spares the
    caller it;
  - a condition, after `if`, `when`, `is` or `which` (`if `wait` is
    `false``): not a C interface, dropped.
A name after a list separator keeps the role of the name before it, except
that a lowercase name after an argument starts a new subject in a sentence
about functions (`pthread_attr_setinheritsched`, with
`PTHREAD_EXPLICIT_SCHED`, `pthread_attr_setschedpolicy`, ...).

A function subject whose sentence restricts it (`fcntl`, with the
`F_GETFL` command; `read`, of 8 bytes; `sched_getaffinity`, for the calling
thread) covers the function only for that use: the name is *partly*
covered unless another declaration names it without a restriction.
Constants, types, errors and macros are covered by any mention.

Usage: derive.py SYSTEM_EXPORT SYSTEM_API.json OUT.json
       derive.py --summary DERIVED.json
"""

import sys

sys.dont_write_bytecode = True

import argparse
import collections
import json
import os
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402

HEAD = re.compile(r"The corresponding C (function|constant|type|error|field|property|macro|global variable|"
                  r"structure|struct|enumeration|enum|union|flag|option)s?\s+(is|are)\b", re.I)
KIND = {"function": "function", "constant": "constant", "type": "type", "error": "error", "field": "field",
        "property": "field", "macro": "macro", "global variable": "variable", "structure": "type",
        "struct": "type", "enumeration": "type", "enum": "type", "union": "type", "flag": "constant",
        "option": "constant"}
NAME = re.compile(r"`([^`]+)`")
CONDITION = re.compile(r"\b(if|when|unless|whether|is|are|which|returns?|equals?)\b", re.I)
ARGUMENT = re.compile(r"\b(with|at|for|using|via|in)\b", re.I)
ALTERNATIVE = re.compile(r"(\bor\b|\band\b|,|\balso known as\b|\bthen\b)", re.I)
# Words that restrict a function subject to one use of it.
RESTRICTS = re.compile(r"\b(with|for|of|at|using)\b", re.I)
C_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def c_name(raw):
    """`struct flock` -> 'flock', `stat()` -> 'stat', `sched_param.sched_priority`
    -> ('sched_priority', 'sched_param'); None for what isn't a C name."""
    s = raw.strip()
    s = re.sub(r"^(struct|union|enum)\s+", "", s)
    s = re.sub(r"\(\s*\w?\s*\)$", "", s)   # `stat()`, `strerror(3)`
    parent = None
    if "." in s:
        parent, _, s = s.rpartition(".")
    if not C_IDENT.match(s):
        return None, None
    return s, parent


def is_upper(name):
    return bool(re.match(r"^_*[A-Z][A-Z0-9_]*$", name))


def sentences(doc):
    """The "The corresponding C ..." sentences of a doc comment, joined
    across lines: from the head to the first period outside backticks that
    ends a sentence."""
    text = " ".join(doc)
    out = []
    for m in HEAD.finditer(text):
        i, tick = m.end(), False
        while i < len(text):
            ch = text[i]
            if ch == "`":
                tick = not tick
            elif ch == "." and not tick and (i + 1 == len(text) or text[i + 1].isspace()):
                break
            i += 1
        out.append((m.group(1).lower(), m.group(2).lower(), text[m.start():i + 1].strip(), text[m.end():i]))
    return out


def parse(kind_word, body):
    """[(name, parent, cKind, role)] for one sentence's body (the text after
    `is`/`are`), and whether its subject is restricted."""
    kind = KIND[kind_word]
    found = []
    pos, prev_role, restricted = 0, None, False
    for m in NAME.finditer(body):
        before = body[pos:m.start()]
        pos = m.end()
        name, parent = c_name(m.group(1))
        if prev_role is None:
            role = "subject"
        elif CONDITION.search(before):
            role = "condition"
        elif ARGUMENT.search(before):
            role = "argument"
        elif ALTERNATIVE.search(before) or not before.strip():
            role = prev_role if prev_role in ("argument", "condition") else "alternative"
            if role == "argument" and kind == "function" and name and not is_upper(name) and \
                    not re.search(r"\bwith\b", before, re.I):
                role = "alternative"
            if role == "condition" and re.search(r"(,|\bor\b)", before) and not CONDITION.search(before):
                role = "alternative"
        else:
            role = "argument"
        if prev_role is not None and role == "argument" and found and found[0][3] == "subject":
            restricted = True
        prev_role = role
        if name is None or role == "condition":
            continue
        if role == "argument":
            ck = "constant" if is_upper(name) else ("function" if kind in ("function", "type") else kind)
        else:
            ck = "constant" if kind == "function" and is_upper(name) else kind
        found.append((name, parent, ck, role))
    # `read`, of 8 bytes; `kevent`, with an empty event list: a restriction
    # that names nothing.
    if found and not restricted:
        first = NAME.search(body)
        rest = body[first.end():] if first else ""
        nxt = NAME.search(rest)
        head = rest[:nxt.start()] if nxt else rest
        if RESTRICTS.search(head) and not ALTERNATIVE.match(head.strip()[:3] or " "):
            restricted = True
    return found, restricted


def doc_comment(lines, decl_line):
    """The `///` lines directly above a declaration, past its attributes."""
    k = decl_line - 2
    while k >= 0 and lines[k].strip().startswith("@"):
        k -= 1
    doc = []
    while k >= 0 and lines[k].strip().startswith("///"):
        doc.append(re.sub(r"^\s*///\s?", "", lines[k]))
        k -= 1
    return list(reversed(doc))


def typealias_target(signature):
    """`typealias Stat = stat` -> 'stat'; None for anything but a plain name."""
    m = re.search(r"\btypealias\s+\w+(?:<[^>]*>)?\s*=\s*(?:struct\s+)?([A-Za-z_][\w.]*)\s*$", signature.strip())
    return m.group(1).split(".")[-1] if m else None


IDENT = re.compile(r"(?<![\w.$])[A-Za-z_][A-Za-z0-9_]*")
DECLARES = re.compile(r"\b(?:func|var|let|case|typealias|struct|enum|class|protocol|actor|associatedtype)\s+"
                      r"([A-Za-z_]\w*)")


def implementation(root, scan):
    """The names System's own code uses, with the platforms that compile
    each use: {name: [platform]}. The C functions its wrappers call and the
    constants and types they read are among them. Names System declares
    itself (`func read`, `case wait`) are left out, since a use of one can't
    be told from a use of the C name."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "api-delta", "scripts"))
    import scan_sources as ss
    used = collections.defaultdict(set)
    declared = set()
    unsupported = scan.get("moduleUnsupportedPlatforms", {})
    for d, module in ss.MODULE_DIRS.items():
        base = os.path.join(root, d)
        gone = set(unsupported.get(module, []))
        for dirpath, _, fs in os.walk(base):
            for f in sorted(fs):
                if not f.endswith(".swift"):
                    continue
                path = os.path.join(dirpath, f)
                rel = os.path.relpath(path, root)
                linux_only = any(rel.startswith(x + "/") for x in ss.LINUX_ONLY_DIRS)
                code, _ = ss.strip_comments_and_strings(open(path, encoding="utf-8").read())
                stack = []
                for line in code.split("\n"):
                    s = line.strip()
                    m = re.match(r"^#(if|elseif|else|endif)\b(.*)$", s)
                    if m:
                        kw, rest = m.group(1), m.group(2).strip()
                        if kw == "if":
                            stack.append([[], rest])
                        elif kw == "elseif" and stack:
                            stack[-1] = [stack[-1][0] + [stack[-1][1]], rest]
                        elif kw == "else" and stack:
                            stack[-1] = [stack[-1][0] + [stack[-1][1]], None]
                        elif kw == "endif" and stack:
                            stack.pop()
                        continue
                    if not s or s.startswith("#") or s.startswith("import "):
                        continue
                    declared.update(DECLARES.findall(line))
                    plats = []
                    for p in ss.PLATFORMS:
                        if p in gone or (linux_only and p not in ("Linux", "Musl")):
                            continue
                        try:
                            if all(ss.branch_active((tuple(b[0]), b[1]), ss.env_for(p)) for b in stack):
                                plats.append(p)
                        except ValueError:
                            plats.append(p)
                    if plats:
                        for name in IDENT.findall(line):
                            used[name].update(plats)
    return {n: sorted(ps, key=check.PLATFORMS.index) for n, ps in sorted(used.items()) if n not in declared}


def derive(root, scan):
    api = check.SystemAPI(scan)
    files = {}
    mentions = []
    stats = collections.Counter()
    odd = []
    for d, e in zip(scan["declarations"], api.entries):
        # Public API only: not @usableFromInline internals, renamed stubs, or
        # underscored declarations that are public only to be inlined.
        if d.get("access") in (None, "internal") or e["unavailable"] or d.get("underscored"):
            continue
        stats["declarations"] += 1
        if d["file"] not in files:
            try:
                files[d["file"]] = open(os.path.join(root, d["file"]), encoding="utf-8").read().split("\n")
            except OSError:
                files[d["file"]] = []
        ref = {"module": e["module"], "scope": e["scope"], "declaration": e["declaration"], "file": e["file"],
               "line": e["line"], "platforms": e["platforms"], "availability": e["availability"],
               "unavailableOn": e["unavailableOn"]}
        doc = doc_comment(files[d["file"]], d["line"])
        said = sentences(doc)
        if said:
            stats["documented"] += 1
        for kind_word, _verb, text, body in said:
            stats["sentences"] += 1
            stats["sentences: " + KIND[kind_word]] += 1
            found, restricted = parse(kind_word, body)
            if not found:
                odd.append({"sentence": text, "file": e["file"], "line": e["line"]})
                continue
            for name, parent, ck, role in found:
                mentions.append({"name": name, "parent": parent, "cKind": ck, "role": role,
                                 "restricted": restricted and role == "subject" and ck == "function",
                                 "source": "doc", "sentence": text, "decl": ref})
        # CInterop's typealiases name the C type they stand for.
        if e["scope"] == "CInterop" and d["kw"] == "typealias":
            target = typealias_target(d["signature"])
            if target and not target[0].isupper():
                stats["typealiases"] += 1
                mentions.append({"name": target, "parent": None, "cKind": "type", "role": "subject",
                                 "restricted": False, "source": "typealias", "sentence": d["signature"],
                                 "decl": ref})
    names = {}
    by_name = collections.defaultdict(list)
    for m in mentions:
        if m["cKind"] != "field":
            by_name[m["name"]].append(m)
    for name, ms in sorted(by_name.items()):
        full = [m for m in ms if not m["restricted"]]
        covered = sorted({p for m in full for p in m["decl"]["platforms"]}, key=check.PLATFORMS.index)
        partly = sorted({p for m in ms if m["restricted"] for p in m["decl"]["platforms"]} - set(covered),
                        key=check.PLATFORMS.index)
        decls = []
        seen = set()
        for m in sorted(ms, key=lambda m: (m["restricted"], m["decl"]["file"], m["decl"]["line"])):
            key = (m["decl"]["file"], m["decl"]["line"])
            if key in seen:
                continue
            seen.add(key)
            decls.append(dict(m["decl"], role=m["role"], restricted=m["restricted"], source=m["source"],
                              cKind=m["cKind"], sentence=m["sentence"]))
        names[name] = {
            "status": "covered" if full else "partial",
            "platforms": covered, "partialPlatforms": partly,
            "kinds": sorted({m["cKind"] for m in ms}),
            "unreleased": all(d["availability"].get("system") == "199" for d in decls if not d["restricted"])
            if full else all(d["availability"].get("system") == "199" for d in decls),
            "declarations": decls,
        }
    fields = collections.defaultdict(set)
    for m in mentions:
        if m["cKind"] == "field":
            fields[m["name"]].add(m["parent"] or "")
    impl = implementation(root, scan)
    stats["implementationNames"] = len(impl)
    return {"stats": dict(sorted(stats.items())), "names": names,
            "fields": {k: sorted(v) for k, v in sorted(fields.items())}, "implementation": impl, "unparsed": odd}


def summary(der):
    st = der["stats"]
    names = der["names"]
    by = collections.Counter(n["status"] for n in names.values())
    kinds = collections.Counter(k for n in names.values() for k in n["kinds"])
    print(f"{st.get('declarations', 0)} public declarations, {st.get('documented', 0)} with a corresponding-C "
          f"sentence ({st.get('sentences', 0)} sentences), {st.get('typealiases', 0)} CInterop typealiases")
    print(f"{len(names)} C names: {by['covered']} covered, {by['partial']} only partly (restricted uses); "
          + ", ".join(f"{k} {v}" for k, v in kinds.most_common()))
    if der["unparsed"]:
        print(f"{len(der['unparsed'])} sentences name no C interface:")
        for u in der["unparsed"][:10]:
            print(f"    {u['file']}:{u['line']}: {u['sentence']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--summary")
    ap.add_argument("args", nargs="*")
    a = ap.parse_args()
    if a.summary:
        return summary(json.load(open(a.summary)))
    root, scan_path, out = a.args
    der = derive(root, json.load(open(scan_path)))
    json.dump(der, open(out, "w"), indent=1)
    summary(der)


if __name__ == "__main__":
    main()
