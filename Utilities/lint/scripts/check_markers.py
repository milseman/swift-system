#!/usr/bin/env python3
"""lint's markers check: the SYSTEM-GAP markers on adopter branches.

Each clone is read at its newest migration branch (migrate-all, then
migrate-unix, then migrate-darwin; --branch picks another), through git
only. A marker is a `SYSTEM-GAP:` in a Swift or C source; a mention of
SYSTEM-GAP without the colon is prose about markers and isn't one.

  markers/format          error    the marker isn't `// SYSTEM-GAP: <interface>`: another comment form
                                   (block, doc), spacing, case, text before it in the comment, code before
                                   it other than the import it's for, or no interface
  markers/one-interface   warning  its text is more than one interface: a list, prose, a platform
                                   qualifier, a continuation line
  markers/stale           warning  System now covers every C name the marker gives, on every platform the
                                   marker's line (or the import under it) is compiled for and its text
                                   names

The marker's text is read with adopter-coverage's status.py (file_markers,
parse_marker, marker_interfaces), the reading STATUS.md's section 3 and
the ledger use, and its platforms with platforms.py's `#if` evaluator, as
the ledger does. Coverage is the ledger's (ledger.Coverage at --system,
default system-next); a name that's System API rather than C (`PThread.Key`,
`SystemSockets`) is covered where its declaration, or module, is built.
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import re  # noqa: E402

from lintcore import CheckError, Finding, commit_of, coverage, display, newest_branch  # noqa: E402

RULES = [
    ("markers/format", "error", "a SYSTEM-GAP marker that isn't `// SYSTEM-GAP: <interface>`"),
    ("markers/one-interface", "warning", "a marker whose text is more than one interface"),
    ("markers/stale", "warning", "a marker whose interface System now covers on the marker's platforms"),
]
EXACT = re.compile(r"^(?P<code>.*?)// SYSTEM-GAP: (?P<body>\S.*?)\s*$")
ANY = re.compile(r"system[-_ ]?gap\s*:", re.I)
ONE = re.compile(r"^`?[A-Za-z_][\w.]*\*?(?:\(\))?`?$")
PLATFORM_OF = {"Darwin": "Darwin", "macOS": "Darwin", "iOS": "Darwin", "Linux": "Linux", "Musl": "Musl",
               "Android": "Android", "Bionic": "Android", "WASI": "WASI", "FreeBSD": "FreeBSD",
               "OpenBSD": "OpenBSD", "Windows": "Windows"}


def format_problem(line, import_re):
    """Why a line with a marker isn't `// SYSTEM-GAP: <interface>`, or None."""
    if re.search(r"///\s*SYSTEM-GAP", line, re.I):
        return "a doc comment; write `// SYSTEM-GAP: <interface>`"
    m = EXACT.match(line)
    if not m:
        s = line.strip()
        if re.search(r"/\*", s) or s.startswith("*"):
            return "a block comment; write `// SYSTEM-GAP: <interface>`"
        if re.search(r"///\s*SYSTEM-GAP", s, re.I):
            return "a doc comment; write `// SYSTEM-GAP: <interface>`"
        if "SYSTEM-GAP:" not in line:
            return "spelled otherwise; write `SYSTEM-GAP:` exactly"
        if re.search(r"SYSTEM-GAP:\s*$", line):
            return "no interface after `SYSTEM-GAP:`"
        if re.search(r"//+\s*\S.*?SYSTEM-GAP:", line) and not re.search(r"//+\s*SYSTEM-GAP:", line):
            return "text before `SYSTEM-GAP:` in its comment; start the comment with it"
        return "spacing: write `// SYSTEM-GAP: <interface>`, one space after `//` and after the colon"
    code = m.group("code")
    if code.strip():
        before = code.rstrip()
        if before.endswith("//") or "//" in before:
            return "text before `SYSTEM-GAP:` in its comment; start the comment with it"
        if not import_re.match(before):
            return "after code that isn't an import; put the marker on a line of its own above what it's for"
    return None


def marker_platforms(states, line, imports_under):
    """The platforms a marker's line, or the imports it sits over, are
    compiled for."""
    plats = set()
    rows = [k - 1 for k in imports_under] or [line - 1]
    for i in rows:
        if 0 <= i < len(states):
            plats |= set(states[i])
    return plats


def named_platforms(body):
    found = set()
    for w in re.findall(r"\b(?:on|off|for|in)\s+([A-Z]\w+(?:(?:,\s*|\s+and\s+|\s+or\s+)[A-Z]\w+)*)", body):
        for p in re.split(r",\s*|\s+and\s+|\s+or\s+", w):
            if p in PLATFORM_OF:
                found.add(PLATFORM_OF[p])
    return found


class SystemNames:
    """Where System's declarations and modules are built, from api-delta's
    scan: for markers that name System API."""

    def __init__(self, scan):
        import platforms
        self.all = set(platforms.PLATFORMS)
        self.paths = {}
        declared = {}
        for d in scan["declarations"]:
            if d.get("access") not in ("public", "open", "public (from public extension)"):
                continue
            p = ".".join(d["scopes"] + [d["name"]])
            ps = {x for x in d["platforms"] if not x.startswith("?")}
            for key in (p, p.split("(")[0]):
                self.paths.setdefault(key, set()).update(ps)
            if d.get("module"):
                declared.setdefault(d["module"], set()).update(ps)
        # A module counts where it builds and declares API: SystemWinSocks
        # builds everywhere, and is empty but on Windows.
        self.modules = {m: (self.all - set(v)) & declared.get(m, self.all)
                        for m, v in scan.get("moduleUnsupportedPlatforms", {}).items()}
        for m in ("SystemPackage", "SystemSockets"):
            self.modules.setdefault(m, set(self.all))

    def platforms(self, name):
        if name in self.modules:
            return self.modules[name]
        return self.paths.get(name)

    def mentioned(self, text):
        """System modules and declarations a marker's text names:
        `SystemSockets`, `PThread.Key`, `SocketDescriptor`."""
        out = []
        for m in re.finditer(r"(?<![\w.`])`?([A-Z]\w*(?:\.[A-Za-z_]\w*)*)", text):
            w = m.group(1).rstrip(".")
            if w in self.modules or (w in self.paths and ("." in w or w[0].isupper())):
                if w not in out:
                    out.append(w)
        return out


def clone_findings(prefix, texts, branch, commit, cov, system_names):
    """The findings for one clone's files ({path: text}), each printed under
    prefix. `cov` answers (kind, unit, how) for a C name on a platform, as
    ledger.Coverage does."""
    import ledger
    import status as st
    from scan_sources import strip_comments_and_strings
    findings = []
    for f in sorted(texts):
        text = texts[f]
        where = os.path.join(prefix, f)
        raw = text.split("\n")
        for n, line in enumerate(raw, 1):
            if not ANY.search(line):
                continue
            problem = format_problem(line, st.IMPORT)
            if problem:
                findings.append(Finding(where, n, "markers/format", "error", problem, branch=branch, commit=commit,
                                        text=line.strip()))
        markers = st.file_markers(text)
        if not markers:
            continue
        swift = f.endswith(".swift")
        code = strip_comments_and_strings(text)[0].split("\n") if swift else raw
        states = ledger.line_states(code, st.PACKAGE_MODEL) if swift else None
        for line, body, imported in markers:
            own_line = EXACT.match(raw[line - 1])
            continued = body != (own_line.group("body") if own_line else body)
            names, phrases = st.parse_marker(body)
            if continued or phrases or len(names) != 1 or not ONE.match(body.strip()):
                what = []
                if names:
                    what.append("reads as " + ", ".join(f"`{x}`" for x, _ in names[:6])
                                + (f" and {len(names) - 6} more" if len(names) > 6 else ""))
                if phrases:
                    what.append("prose: " + "; ".join(f"“{p}”" for p in phrases[:2]))
                if continued:
                    what.append("continues on the next line")
                findings.append(Finding(where, line, "markers/one-interface", "warning",
                                        ("one interface per marker; " + "; ".join(what)) if what else
                                        "one interface per marker", branch=branch, commit=commit, text=body))
            if not swift or states is None:
                continue
            under = ledger.marker_imports(raw, line - 1)
            plats = marker_platforms(states, line, under)
            named = named_platforms(body)
            if named:
                plats = plats & named if plats & named else named
            checks = []
            for _iface, _phrase, ns in st.marker_interfaces(body, imported) or []:
                for nm in ns:
                    if nm.endswith(" members") or nm.endswith("*"):
                        checks = None
                        break
                    checks.append(nm)
                if checks is None:
                    break
            if not checks or not plats:
                continue
            how, stale = [], True
            for nm in checks:
                sys_plats = system_names.platforms(nm)
                if sys_plats is not None:
                    if plats <= sys_plats:
                        how.append(f"`{nm}` is built on {', '.join(sorted(plats))}")
                        continue
                    stale = False
                    break
                answers = [cov.answer(nm, p) for p in sorted(plats)]
                if all(a[0] == "covered" for a in answers):
                    how.append(f"`{nm}`: {answers[0][2] or 'covered'}")
                    continue
                stale = False
                break
            if stale:
                api = system_names.mentioned(body)
                findings.append(Finding(where, line, "markers/stale", "warning",
                                        f"System covers it on {', '.join(sorted(plats))}: " + "; ".join(how)
                                        + (f" (the marker also names System's {', '.join(f'`{a}`' for a in api)},"
                                           " which this check doesn't judge)" if api else ""),
                                        branch=branch, commit=commit, text=body))
    return findings


def run(ctx):
    import status as st
    cov, scan, system_commit = coverage(ctx, ctx.args.system)
    system_names = SystemNames(scan)
    clones = ctx.clones()
    if not clones:
        raise CheckError("no clones: give --clone, or put them in ../adopters")
    findings = []
    for clone in clones:
        branch = ctx.args.branch or newest_branch(clone)
        commit = commit_of(clone, branch) if branch else None
        if not commit:
            ctx.note(f"markers: {display(clone)} has no {branch or 'migration branch'}; skipped")
            continue
        ctx.note(f"markers: {display(clone)} at {branch} ({commit[:10]}), against System {system_commit[:10]}")
        files = st.grep_files(clone, commit, "SYSTEM-GAP", [f"*{e}" for e in st.SOURCE_EXTENSIONS])
        blobs = st.read_blobs(clone, [f"{commit}:{f}" for f in files])
        texts = {f: blobs[f"{commit}:{f}"] for f in files if f"{commit}:{f}" in blobs}
        findings += clone_findings(display(clone), texts, branch, commit, cov, system_names)
    return findings
