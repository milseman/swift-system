#!/usr/bin/env python3
"""lint's conditionals check: platform conditionals an adopter branch adds
that call System in one arm and C in another.

Michael (2026-10-06): that can happen as an intermediate step of a
migration, but it should surprise us, so every one is reported, as a
warning at the `#if` line.

For each clone (--clone, default every clone in ../adopters), the branch
(default its newest migration branch) is diffed against its merge base with
--base (default main), Swift files only. A conditional is new when its
`#if` line is an added line; it's a platform conditional when its condition
names os(), canImport(), arch() or targetEnvironment(). Each arm of a new
one is then read at the branch's commit, comments and strings blanked:

- it calls System when it names one of System's public top-level types or
  modules (from api-delta's scan of System at --system), and the package
  doesn't declare that name itself;
- it calls C when the ledger's lexical reading (adopter-coverage's
  ledger.uses, with its vocabulary: the SDK's names from the coverage
  tools' stored vocabulary, when there is one, System's C names and
  mapping.ini's) finds a C name in it, or it's qualified (`Glibc.exit`).

  conditionals/mixed   warning   a new platform conditional with an arm that calls System and no C,
                                 and another arm that calls C
"""

import sys

sys.dont_write_bytecode = True

import glob  # noqa: E402
import gzip  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402

from lintcore import CheckError, Finding, commit_of, coverage, display, git, modules, newest_branch  # noqa: E402

RULES = [
    ("conditionals/mixed", "warning", "a new platform conditional that calls System in one arm and C in another"),
]
PLATFORM_COND = re.compile(r"\b(?:os|canImport|arch|targetEnvironment)\s*\(")
DIRECTIVE = re.compile(r"^\s*#(if|elseif|else|endif)\b(.*)$")
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
IDENT = re.compile(r"(?<![\w.$])([A-Za-z_]\w*)")


def added_lines(diff):
    """{path: {new line numbers added}} from `git diff -U0` output."""
    out, path, line = {}, None, 0
    for raw in diff.split("\n"):
        if raw.startswith("+++ "):
            p = raw[4:].rstrip("\t")
            path = p[2:] if p.startswith("b/") else None
            continue
        m = HUNK.match(raw)
        if m:
            line = int(m.group(1))
            continue
        if path is None or raw.startswith("---"):
            continue
        if raw.startswith("+"):
            out.setdefault(path, set()).add(line)
            line += 1
        elif raw.startswith(" "):
            line += 1
    return out


def blocks(code):
    """[(if line, [(condition or None, first, last)])], 1-based, for every
    #if block of blanked code: its arms' bodies, without the directives."""
    out, stack = [], []
    for n, line in enumerate(code, 1):
        m = DIRECTIVE.match(line)
        if not m:
            continue
        kw, rest = m.group(1), m.group(2).strip()
        if kw == "if":
            stack.append({"line": n, "arms": [[rest, n + 1, None]]})
        elif not stack:
            continue
        elif kw in ("elseif", "else"):
            stack[-1]["arms"][-1][2] = n - 1
            stack[-1]["arms"].append([rest if kw == "elseif" else None, n + 1, None])
        elif kw == "endif":
            b = stack.pop()
            b["arms"][-1][2] = n - 1
            out.append((b["line"], [tuple(a) for a in b["arms"]]))
    return sorted(out)


def system_types(scan):
    names = {"SystemPackage", "SystemSockets", "CInterop"}
    for d in scan["declarations"]:
        if d.get("access") in ("public", "open") and not d["scopes"] and d["kw"] in (
                "struct", "enum", "class", "protocol", "actor", "typealias"):
            names.add(d["name"])
    return names


def load_vocabulary(ctx, cov, mods):
    import ledger
    sdk = None
    results = os.environ.get("ADOPTER_COVERAGE_RESULTS") or os.path.join(os.path.dirname(ctx.repo),
                                                                         "coverage-results")
    paths = sorted(glob.glob(os.path.join(results, "vocab", "*.json.gz")), key=os.path.getmtime)
    if paths:
        with gzip.open(paths[-1], "rt", encoding="utf-8") as f:
            sdk = json.load(f)["vocab"]
    else:
        ctx.note("conditionals: no stored SDK vocabulary (coverage-results/vocab); C names are System's and "
                 "mapping.ini's only")
    return ledger.Vocabulary(sdk, mods, cov, ledger.windows_names(ctx.repo, ledger.rust_windows_bindings()),
                             ledger.swift_declared_names())


def arm_uses(code, first, last, vocab, own, qualified, shims, plat, sys_types):
    import ledger
    active = [set() for _ in code]
    for i in range(first - 1, min(last, len(code))):
        active[i] = {plat}
    c_names = ledger.uses(code, active, vocab, own, plat, qualified, shims)
    system = set()
    for i in range(first - 1, min(last, len(code))):
        line = code[i]
        if DIRECTIVE.match(line):
            continue
        for m in IDENT.finditer(line):
            w = m.group(1)
            if w in sys_types and w not in own:
                system.add(w)
    return sorted(c_names), sorted(system)


def clone_findings(prefix, added, texts, vocab, own, qualified, shims, sys_types, **record):
    """The findings for one clone: `added` is {path: added line numbers},
    `texts` {path: text at the branch}."""
    import ledger
    import status as st
    from scan_sources import strip_comments_and_strings
    findings = []
    for path, lines in sorted(added.items()):
        text = texts.get(path)
        if text is None:
            continue
        code = strip_comments_and_strings(text)[0].split("\n")
        states = ledger.line_states(code, st.PACKAGE_MODEL)
        for if_line, arms in blocks(code):
            if if_line not in lines or len(arms) < 2:
                continue
            if not PLATFORM_COND.search(arms[0][0] or ""):
                continue
            reads = []
            for c, first, last in arms:
                plats = states[first - 1] if 0 < first <= len(states) else {}
                plat = "Windows" if (c and "Windows" in c and "!" not in c) else (
                    next((p for p in ("Linux", "Darwin", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows")
                          if p in plats), "Linux"))
                cn, sn = arm_uses(code, first, last, vocab, own, qualified, shims, plat, sys_types)
                reads.append((c, first, cn, sn))
            sys_arms = [r for r in reads if r[3] and not r[2]]
            c_arms = [r for r in reads if r[2]]
            pairs = [(a, b) for a in sys_arms for b in c_arms if a is not b]
            if not pairs:
                continue
            a, b = pairs[0]

            def arm(r):
                return f"`#if {r[0]}`" if r is reads[0] else (f"`#elseif {r[0]}`" if r[0] else "`#else`")
            findings.append(Finding(
                os.path.join(prefix, path), if_line, "conditionals/mixed", "warning",
                f"a new platform conditional calls System in its {arm(a)} arm "
                f"({', '.join(f'`{x}`' for x in a[3][:4])}) and C in its {arm(b)} arm "
                f"({', '.join(f'`{x}`' for x in b[2][:4])}" + (" …" if len(b[2]) > 4 else "") + ")",
                arms=[{"condition": r[0], "line": r[1], "c": r[2], "system": r[3]} for r in reads], **record))
    return findings


def run(ctx):
    import ledger
    import status as st
    cov, scan, _ = coverage(ctx, ctx.args.system)
    mods = modules(ctx)
    vocab = load_vocabulary(ctx, cov, mods)
    qualified = ledger.qualified_re(mods)
    sys_types = system_types(scan)
    clones = ctx.clones()
    if not clones:
        raise CheckError("no clones: give --clone, or put them in ../adopters")
    findings = []
    for clone in clones:
        branch = ctx.args.branch or newest_branch(clone)
        commit = commit_of(clone, branch) if branch else None
        base = commit_of(clone, ctx.args.base)
        if not commit or not base:
            ctx.note(f"conditionals: {display(clone)} lacks {branch or 'a migration branch'} or {ctx.args.base}; "
                     "skipped")
            continue
        mb = git(clone, "merge-base", base, commit, ok=(0, 1)).strip()
        if not mb:
            ctx.note(f"conditionals: {display(clone)}: {branch} and {ctx.args.base} share no history; skipped")
            continue
        ctx.note(f"conditionals: {display(clone)} at {branch} ({commit[:10]}) against its merge base with "
                 f"{ctx.args.base} ({mb[:10]})")
        diff = git(clone, "diff", "-U0", "--no-color", "--no-renames", "--no-ext-diff", mb, commit, "--", "*.swift")
        added = added_lines(diff)
        if not added:
            continue
        own = ledger.own_names(clone, commit)
        files = st.tree_files(clone, commit)
        shims = {f.split("/")[1] for f in files if f.startswith("Sources/C") and f.count("/") >= 2}
        blobs = st.read_blobs(clone, [f"{commit}:{f}" for f in added])
        texts = {f: blobs[f"{commit}:{f}"] for f in added if f"{commit}:{f}" in blobs}
        findings += clone_findings(display(clone), added, texts, vocab, own, qualified, shims, sys_types,
                                   branch=branch, commit=commit, base=mb)
    return findings
