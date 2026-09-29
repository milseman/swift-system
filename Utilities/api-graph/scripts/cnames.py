#!/usr/bin/env python3
"""The C names the graph's declarations wrap, as the coverage tools read
them, with the C function families they form.

System's doc comments name what each declaration wraps: "The corresponding
C function is `fsync`.", "The corresponding C constant is `O_CLOEXEC`.",
and the like. Utilities/adopter-coverage's derive.py reads those sentences
with a small grammar (a subject, its alternatives, the arguments a
declaration passes, restrictions to one use), and its reading decides what
the coverage reports call covered. This runs that reading, imported
read-only, on both commits' exports, and attributes each C name to the
graph's nodes by the declaration's file and line:

  wraps     one record per (node, C name): the role (subject, alternative,
            argument), whether the sentence restricts the subject to one use
            (`fcntl`, with the `F_GETFL` command), the source (a doc sentence,
            or a CInterop typealias) and the sentence
  names     per C name: its kinds, whether the base commit already covers it,
            and its C function family

A family is the set of C functions some declaration's sentences name as
another spelling of one call (`chmod`, or `lchmod` if ...; not `openat` and
`fdopendir`, which are two calls), joined
with POSIX's variants of the same call among the functions the graph wraps
(`mkdir` and `mkdirat`; `stat`, `fstat`, `lstat` and `fstatat`; `futimens`
and `utimensat`), closed transitively, and named for the function the most
declarations wrap. Two declarations wrapping functions of one family are in
the same C function family.

Left out, as derivation artifacts: Swift words (`nil` in "with `UTIME_OMIT`
for a `nil` time") and a declaration's own parameter names read as
arguments (`value` in "the 8 bytes of `value`").

Usage: cnames.py --graph graph.json --head-src DIR --base-src DIR
                 --head-scan F --base-scan F --out cnames.json
"""

import sys

sys.dont_write_bytecode = True   # nothing written into the coverage tool's scripts directory

import argparse  # noqa: E402
import collections  # noqa: E402
import importlib.util  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
UTILITIES = os.path.dirname(os.path.dirname(HERE))
COVERAGE = os.path.join(UTILITIES, "adopter-coverage")

SWIFT_WORDS = {"nil", "true", "false", "self", "Self", "super", "init", "Void", "Any", "some", "any", "inout"}
IDENT = r"[A-Za-z_][A-Za-z0-9_]*"


def coverage_module(name):
    """A script of Utilities/adopter-coverage, imported read-only from its
    file under a prefixed name, so it can't shadow this tool's own scripts."""
    key = "coverage_" + name
    if key in sys.modules:
        return sys.modules[key]
    spec = importlib.util.spec_from_file_location(key, os.path.join(COVERAGE, "scripts", name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[key] = mod
    spec.loader.exec_module(mod)
    return mod


def top_level_split(text):
    """Split at the commas outside brackets; `->` isn't a closing `>`."""
    parts, depth, cur, prev = [], 0, [], ""
    for ch in text:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}" or (ch == ">" and prev != "-"):
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
        prev = ch
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


def param_names(decl):
    """The labels and parameter names a declaration's text spells."""
    out = set()
    m = re.search(r"\((.*)\)", decl or "")
    if m:
        for prm in top_level_split(m.group(1)):
            out.update(re.findall(IDENT, prm.partition(":")[0]))
    return out


def derive_wraps(nodes, head_src, head_scan, base_src, base_scan):
    derive = coverage_module("derive")
    head = derive.derive(head_src, head_scan)
    base = derive.derive(base_src, base_scan)
    base_covered = {name for name, v in base["names"].items() if v["status"] == "covered"}
    at = collections.defaultdict(list)
    for nid, n in nodes.items():
        for f, ln in n.get("sites") or [[n["file"], n["line"]]]:
            if f:
                at[(f, ln)].append(nid)
    wraps, seen = [], set()
    for name, v in sorted(head["names"].items()):
        if name in SWIFT_WORDS:
            continue
        for d in v["declarations"]:
            for nid in at.get((d["file"], d["line"]), []):
                if d["role"] == "argument" and not name.isupper() and name in param_names(nodes[nid]["decl"]):
                    continue
                key = (nid, name, d["role"])
                if key in seen:
                    continue
                seen.add(key)
                wraps.append({"node": nid, "name": name, "role": d["role"], "restricted": d["restricted"],
                              "cKind": d["cKind"], "source": d["source"], "sentence": d["sentence"],
                              "joiner": joiner(d["sentence"], name) if d["role"] == "alternative" else None})
    names = {}
    for w in wraps:
        v = head["names"][w["name"]]
        names.setdefault(w["name"], {"kinds": v["kinds"], "baseCovered": w["name"] in base_covered,
                                     "platforms": v["platforms"], "family": None})
    # Families: functions named together as subject and alternative.
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    # A sentence's `or` names another spelling of one call (`chmod`, or
    # `lchmod` if ...); its `and` names another call it makes (`openat` and
    # `fdopendir`), which doesn't make them one family.
    by_node = collections.defaultdict(set)
    for w in wraps:
        if w["cKind"] == "function" and (w["role"] == "subject" or (w["role"] == "alternative"
                                                                       and w["joiner"] == "or")):
            by_node[w["node"]].add(w["name"])
        if w["cKind"] == "function" and w["role"] in ("subject", "alternative"):
            find(w["name"])
    def union(x, y):
        ra, rb = find(x), find(y)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)
    for fs in by_node.values():
        fs = sorted(fs)
        for f in fs[1:]:
            union(fs[0], f)
    # POSIX's variants of one call: `x` and `xat` (mkdir, mkdirat), `x` and
    # `fx` or `lx` (chmod, fchmod, lchmod), and `fx` and `xat` (futimens,
    # utimensat), for the functions some declaration wraps.
    by_form = collections.defaultdict(set)
    for f in list(parent):
        for form in base_forms(f):
            by_form[form].add(f)
    for fs in by_form.values():
        fs = sorted(fs)
        for f in fs[1:]:
            union(fs[0], f)
    users = collections.Counter(n for fs in by_node.values() for n in fs)
    members = collections.defaultdict(list)
    for f in parent:
        members[find(f)].append(f)
    for fs in members.values():
        fam = sorted(fs, key=lambda f: (-users[f], len(f), f))[0]
        for f in fs:
            names[f]["family"] = fam
    return wraps, names


def joiner(sentence, name):
    """How a sentence joins a name to the one before it: `or` (also known
    as), `and`, or a comma."""
    k = sentence.find("`" + name)
    if k < 0:
        k = sentence.find(name)
    before = sentence[:k]
    prev = before.rfind("`", 0, len(before) - 1) if before.endswith("`") else before.rfind("`")
    between = before[prev + 1:] if prev >= 0 else before
    if re.search(r"\bor\b|also known as", between):
        return "or"
    if re.search(r"\band\b", between):
        return "and"
    return ","


# The C library's streams, whose `f` isn't a descriptor's (fread isn't read's).
STDIO = set("""fopen fclose fread fwrite fflush fseek fseeko ftell ftello fgetc fputc fgets fputs fprintf fscanf
    fileno fdopen freopen fgetpos fsetpos feof ferror fpurge fmemopen funopen flockfile funlockfile ftrylockfile
    fwide fgetwc fputwc fgetln fork free flock fnmatch fts_open fts_read fts_close""".split())


def base_forms(name):
    """The name, less an `at` or `at2` suffix, less an `f` or `l` prefix, and
    less both: the forms two variants of one call share."""
    forms = {name}
    stems = [name]
    for suffix in ("at2", "at"):
        if name.endswith(suffix) and len(name) - len(suffix) >= 3:
            stems.append(name[:-len(suffix)])
            break
    for st in list(stems):
        forms.add(st)
        if st[:1] in ("f", "l") and name not in STDIO and len(st) - 1 >= 3:
            forms.add(st[1:])
    return forms


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--head-src", required=True)
    ap.add_argument("--base-src", required=True)
    ap.add_argument("--head-scan", required=True)
    ap.add_argument("--base-scan", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    nodes = json.load(open(a.graph))["nodes"]
    wraps, names = derive_wraps(nodes, a.head_src, json.load(open(a.head_scan)), a.base_src,
                                json.load(open(a.base_scan)))
    json.dump({"wraps": wraps, "names": names}, open(a.out, "w"), indent=0)
    fams = {v["family"] for v in names.values() if v["family"]}
    print(f"cnames: {len(names)} C names ({sum(1 for v in names.values() if v['baseCovered'])} covered on the "
          f"base commit) wrapped by {len({w['node'] for w in wraps})} declarations, {len(fams)} C function "
          f"families -> {a.out}")


if __name__ == "__main__":
    main()
