#!/usr/bin/env python3
"""The C names the graph's declarations wrap, as the coverage tools read
them and as their code reaches them, with the C function families they
form.

System's doc comments name what each declaration wraps: "The corresponding
C function is `fsync`.", "The corresponding C constant is `O_CLOEXEC`.",
and the like. Utilities/adopter-coverage's derive.py reads those sentences
with a small grammar (a subject, its alternatives, the arguments a
declaration passes, restrictions to one use), and its reading decides what
the coverage reports call covered. This runs that reading, imported
read-only, on both commits' exports, and attributes each C name to the
graph's nodes by the declaration's file and line. Field and property
sentences ("The corresponding C field is `ri_pageins`."), which derive.py
reads but leaves out of what it covers, are read here with its grammar too.

Then the code: the C each declaration's code reaches (build_graph.py's
`cRefs`: functions, macros, enum constants, variables, fields), through the
internal code it calls.

  wraps     one record per (node, C name, role): the role (subject,
            alternative, argument), whether the sentence restricts the
            subject to one use (`fcntl`, with the `F_GETFL` command), its
            sources (`doc`, a doc sentence; `typealias`, a CInterop
            typealias; `code`, what the code reaches), the C kind, and the
            sentence. A code link's role is `subject` when the declaration's
            code reaches exactly one C name, else `argument`; a doc link and
            a code link to the same C name are one record with both sources,
            and the doc sentence's role.
  names     per C name: its kinds, whether the base commit already covers it,
            and its C function family

A field is named for its struct where one can be found (`stat.st_size`;
qualify() says how), and a "field" the grammar misreads is dropped
(add_doc_fields). A type wraps nothing through code: its lines hold its
members.

Only the stated links, from a doc sentence or a typealias, say what a
declaration stands for: they're what reach (`couldUse`), the families, the
domains and the pitch rules read (`stated`). A code-only link says what its
implementation touches; a `description` can list every constant of a type.

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
# "`p_pid`, of `kp_proc`": the second name is the path to the field's
# struct, not another field.
OF_PATH = re.compile(r"`([^`]+)`,?\s+of\s+`([^`]+)`")
C_RECORD = re.compile(r"^c:@(?:S|SA|U|UA)@([A-Za-z_]\w*)$")
STATED = ("doc", "typealias")
PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]


def stated(w):
    """Whether a wraps record or link says what the declaration stands for:
    a doc sentence or a CInterop typealias names it, not only its code."""
    return any(s in STATED for s in w.get("sources") or ["doc"])


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


def sites_of(n):
    return [(f, ln) for f, ln in n.get("sites") or [[n["file"], n["line"]]] if f]


def doc_fields(derive, root, sites):
    """{(file, line): [(name, parent, role, sentence)]} for the field and
    property sentences of the doc comments at those declarations' sites, in
    derive.py's grammar: the names it reads as fields (an argument such as
    `CLD_EXITED` is a constant, which derive.py's own names have), less the
    path after ", of" (`kp_eproc` in "`e_ppid`, of `kp_eproc`")."""
    files, out = {}, {}
    for f, ln in sites:
        if f not in files:
            try:
                with open(os.path.join(root, f), encoding="utf-8") as fh:
                    files[f] = fh.read().split("\n")
            except OSError:
                files[f] = []
        found_here = []
        for kind_word, _verb, text, body in derive.sentences(derive.doc_comment(files[f], ln)):
            if derive.KIND[kind_word] != "field":
                continue
            found, _restricted = derive.parse(kind_word, body)
            paths = {derive.c_name(m.group(2)) for m in OF_PATH.finditer(body)}
            for name, parent, ck, role in found:
                if ck == "field" and name not in SWIFT_WORDS and (role == "subject" or (name, parent) not in paths):
                    found_here.append((name, parent, role, text))
        if found_here:
            out[(f, ln)] = found_here
    return out


def qualify(name, parent, own_fields, kin_fields, own_structs, host):
    """A doc sentence's field, named for its struct where one can be found:
    the struct of the declaration's own code reference to a field of that
    name; else the sentence's spelling (`sched_param.sched_priority`); else
    the struct whose field of that name its type's code references (a
    stored property its type's initializer fills from `tm.tm_sec`); else
    the one struct the declaration's other field references name; else the
    C struct the declaration extends."""
    def pick(qs):
        qs = sorted(qs)
        return next((q for q in qs if q.rsplit(".", 1)[0] in (parent, host)), qs[0])
    if own_fields.get(name):
        return pick(own_fields[name])
    if parent:
        return f"{parent}.{name}"
    if kin_fields.get(name):
        return pick(kin_fields[name])
    if len(own_structs) == 1:
        return f"{next(iter(own_structs))}.{name}"
    if host:
        return f"{host}.{name}"
    return name


class Links:
    """The wraps records, one per (node, C name, role), each with its sources."""

    def __init__(self):
        self.records, self.index = [], {}

    def add(self, nid, name, role, restricted, ck, source, sentence=None, joined=None):
        w = self.index.get((nid, name, role))
        if w:
            w["sources"] = sorted(set(w["sources"]) | {source})
            return w
        w = {"node": nid, "name": name, "role": role, "restricted": restricted, "cKind": ck,
             "sources": [source], "sentence": sentence,
             "joiner": joiner(sentence, joined or name) if role == "alternative" else None}
        self.index[(nid, name, role)] = w
        self.records.append(w)
        return w

    def add_code(self, nodes):
        """A link per C name a declaration's code reaches (not a type's, whose
        lines hold its members), merged into the doc links that name it: role
        `subject` when the code reaches that one C name, else `argument`."""
        by_name = collections.defaultdict(list)
        for w in self.records:
            by_name[(w["node"], w["name"])].append(w)
        for nid, n in sorted(nodes.items()):
            refs = [] if n.get("isType") else n.get("cRefs") or []
            for r in refs:
                for w in by_name.get((nid, r["name"])) or [None]:
                    if w:
                        w["sources"] = sorted(set(w["sources"]) | {"code"})
                    else:
                        self.add(nid, r["name"], "subject" if len(refs) == 1 else "argument", False, r["cKind"],
                                 "code")


def field_refs(n):
    """{field: {struct.field}} for the fields a node's code references."""
    out = collections.defaultdict(set)
    for r in n.get("cRefs") or []:
        if r["cKind"] == "field" and "." in r["name"]:
            out[r["name"].rsplit(".", 1)[1]].add(r["name"])
    return out


def add_doc_fields(links, nodes, edges, fields, not_fields):
    """The doc links of field and property sentences (`fields`, from
    doc_fields), each field named for its struct where one can be found
    (qualify). A "field" in `not_fields` (a function, constant or type
    elsewhere) or spelled as a type (`size_t`) is the grammar's misreading:
    "`f_favail`, reported on the `statvfs` platforms"; "`msg_controllen`, a
    `size_t`". Returns {name: platforms of its declarations}."""
    host, parent_of = {}, {}
    for e in edges:
        if e["kind"] in ("memberOf", "nestedIn"):
            parent_of[e["from"]] = e["to"]
            m = C_RECORD.match(e["to"])
            if m:
                host[e["from"]] = m.group(1)
    kin = collections.defaultdict(lambda: collections.defaultdict(set))
    for nid, n in nodes.items():
        for t in (parent_of.get(nid), nid if n.get("isType") else None):
            if t:
                for f, qs in field_refs(n).items():
                    kin[t][f] |= qs
    platforms = collections.defaultdict(set)
    for nid, n in sorted(nodes.items()):
        mine = [m for site in sites_of(n) for m in fields.get(site, ())
                if m[0] not in not_fields and not m[0].endswith("_t")]
        own = field_refs(n)
        structs = {q.rsplit(".", 1)[0] for qs in own.values() for q in qs}
        for name, parent, role, sentence in mine:
            q = qualify(name, parent, own, kin.get(parent_of.get(nid), {}), structs, host.get(nid))
            links.add(nid, q, role, False, "field", "doc", sentence, name)
            platforms[q] |= set(n.get("platforms") or [])
    return platforms


def derive_wraps(nodes, edges, head_src, head_scan, base_src, base_scan):
    derive = coverage_module("derive")
    head = derive.derive(head_src, head_scan)
    base = derive.derive(base_src, base_scan)
    base_covered = {name for name, v in base["names"].items() if v["status"] == "covered"}
    at = collections.defaultdict(list)
    for nid, n in nodes.items():
        for site in sites_of(n):
            at[site].append(nid)
    links = Links()
    # Doc sentences and typealiases, as derive.py reads them.
    for name, v in sorted(head["names"].items()):
        if name in SWIFT_WORDS:
            continue
        for d in v["declarations"]:
            for nid in at.get((d["file"], d["line"]), []):
                if d["role"] == "argument" and not name.isupper() and name in param_names(nodes[nid]["decl"]):
                    continue
                links.add(nid, name, d["role"], d["restricted"], d["cKind"], d["source"], d["sentence"])
    # Field and property sentences, which derive.py leaves out of its names.
    not_fields = set(head["names"]) | {r["name"] for n in nodes.values() for r in n.get("cRefs") or []
                                       if r["cKind"] != "field"}
    field_platforms = add_doc_fields(links, nodes, edges, doc_fields(derive, head_src, sorted(set(at))), not_fields)
    links.add_code(nodes)
    wraps = links.records
    base_fields = {name for ms in doc_fields(derive, base_src, sorted({(d["file"], d["line"])
                                                                        for d in base_scan["declarations"]
                                                                        if d.get("access") in ("public", "open")
                                                                        and not d.get("underscored")})).values()
                   for name, _p, _r, _s in ms}
    # A name's kinds are the ones its doc sentences give it (a macro the
    # sentence calls a constant stays a constant), or for a name only code
    # reaches, the one its USR says.
    names, code_kinds = {}, collections.defaultdict(set)
    for w in wraps:
        v = head["names"].get(w["name"])
        rec = names.setdefault(w["name"], {
            "kinds": set(v["kinds"] if v else ()),
            "baseCovered": (w["name"].rsplit(".", 1)[-1] in base_fields) if w["cKind"] == "field" and not v
            else w["name"] in base_covered,
            "platforms": v["platforms"] if v else sorted(field_platforms.get(w["name"]) or {"Darwin"},
                                                         key=lambda p: (PLATFORMS + [p]).index(p)),
            "family": None})
        if w["sources"] == ["code"]:
            code_kinds[w["name"]].add(w["cKind"])
        elif not v:
            rec["kinds"].add(w["cKind"])
    for name, rec in names.items():
        rec["kinds"] = sorted(rec["kinds"] or code_kinds[name])
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
    for w in filter(stated, wraps):
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
    g = json.load(open(a.graph))
    wraps, names = derive_wraps(g["nodes"], g["edges"], a.head_src, json.load(open(a.head_scan)), a.base_src,
                                json.load(open(a.base_scan)))
    json.dump({"wraps": wraps, "names": names}, open(a.out, "w"), indent=0)
    fams = {v["family"] for v in names.values() if v["family"]}
    by = collections.Counter("+".join(w["sources"]) for w in wraps)
    print(f"cnames: {len(names)} C names ({sum(1 for v in names.values() if v['baseCovered'])} covered on the "
          f"base commit) wrapped by {len({w['node'] for w in wraps})} declarations "
          f"({len({w['node'] for w in wraps if stated(w)})} by a doc sentence or typealias), "
          f"{len(wraps)} links ({', '.join(f'{v} {k}' for k, v in sorted(by.items()))}), "
          f"{len(fams)} C function families -> {a.out}")


if __name__ == "__main__":
    main()
