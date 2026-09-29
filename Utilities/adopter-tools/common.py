"""What the adopter tools share: the Swift comment and string blanker, import
and SYSTEM-GAP marker parsing, file listing (a working tree or a commit), where
swift-system's sources are, and the scratch directory. Not a tool itself.

Standard library only, for the macOS system Python 3.9.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def fail(message):
    sys.exit(f"{os.path.basename(sys.argv[0])}: {message}")


# ---------------------------------------------------------------- scratch

def scratch(*parts):
    """A directory under $ADOPTER_TOOLS_TMP (default: adopter-tools in the
    system temporary directory), created if needed. Nothing in a checkout."""
    base = os.environ.get("ADOPTER_TOOLS_TMP") or os.path.join(tempfile.gettempdir(), "adopter-tools")
    path = os.path.join(base, *parts)
    os.makedirs(path, exist_ok=True)
    return path


def path_key(path):
    """A short name for a directory, unique per absolute path: two clones
    with the same name get different scratch files."""
    real = os.path.realpath(path)
    return f"{os.path.basename(real)}-{hashlib.sha1(real.encode()).hexdigest()[:8]}"


# ---------------------------------------------------------------- git

def git(repo, *args, binary=False, check=True, stdin=None):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, input=stdin)
    if check and r.returncode != 0:
        fail(f"git {' '.join(args)} in {repo}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def is_git(path):
    return subprocess.run(["git", "-C", path, "rev-parse", "--git-dir"], capture_output=True).returncode == 0


def commit_of(repo, ref):
    return git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}").strip()


def read_blobs(repo, specs):
    """{"rev:path": text} through one `git cat-file --batch`."""
    out = {}
    if not specs:
        return out
    data = git(repo, "cat-file", "--batch", binary=True, stdin=("\n".join(specs) + "\n").encode())
    i = 0
    for spec in specs:
        j = data.index(b"\n", i)
        header = data[i:j].decode()
        i = j + 1
        if header.endswith(" missing"):
            continue
        size = int(header.rsplit(" ", 1)[1])
        out[spec] = data[i:i + size].decode("utf-8", "replace")
        i += size + 1
    return out


# ---------------------------------------------------------------- files

SKIP_DIRS = {".build", ".git", ".swiftpm", "node_modules"}


def swift_files(root, rev=None, paths=None, extensions=(".swift",)):
    """Relative paths of the Swift files in `root`: at a commit (`rev`), in
    the working tree (tracked and untracked files git doesn't ignore), or,
    outside a git checkout, every file below `root` except build and hidden
    directories. `paths` keeps only files under those top-level paths."""
    if rev:
        names = git(root, "ls-tree", "-r", "--name-only", rev).split("\n")
    elif is_git(root):
        # Relative to `root`, which may be a directory inside the checkout; a
        # deleted file that's still in the index isn't there.
        names = git(root, "ls-files", "--cached", "--others", "--exclude-standard").split("\n")
        names = [n for n in names if n and os.path.exists(os.path.join(root, n))]
    else:
        names = []
        for dp, dns, fns in os.walk(root):
            dns[:] = sorted(d for d in dns if d not in SKIP_DIRS and not d.startswith("."))
            for fn in fns:
                names.append(os.path.relpath(os.path.join(dp, fn), root))
    roots = [p.strip("/") for p in paths] if paths else None
    return sorted(n for n in names if n.endswith(extensions)
                  and (roots is None or any(n == r or n.startswith(r + "/") for r in roots)))


def read_sources(root, files, rev=None):
    """{path: text} for the files, at `rev` or in the working tree."""
    if rev:
        # `rev:./path` is relative to `root`, as swift_files' paths are.
        blobs = read_blobs(root, [f"{rev}:./{f}" for f in files])
        return {f: blobs.get(f"{rev}:./{f}", "") for f in files}
    out = {}
    for f in files:
        try:
            with open(os.path.join(root, f), encoding="utf-8", errors="replace") as h:
                out[f] = h.read()
        except OSError:
            out[f] = ""
    return out


# ---------------------------------------------------------------- Swift source

_RAW_OPEN = re.compile(r'(#*)("""|")')


def blank_swift(text):
    """`text` with comments and string literals' contents blanked to spaces,
    keeping newlines, quotes, and the code of string interpolations (`\\(...)`),
    so line and column numbers still match. Handles nested block comments,
    multi-line and raw strings (`#"..."#`). The approach of api-delta's
    scan_sources.strip_comments_and_strings."""
    out = list(text)
    n = len(text)

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    def code(i, interpolation):
        depth = 0
        while i < n:
            if text.startswith("//", i):
                j = text.find("\n", i)
                j = n if j < 0 else j
                blank(i, j)
                i = j
                continue
            if text.startswith("/*", i):
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
                blank(i, j)
                i = j
                continue
            c = text[i]
            if c in "\"#":
                m = _RAW_OPEN.match(text, i)
                if m and (c == '"' or m.group(1)):
                    i = string(m.end(), m.group(2), len(m.group(1)))
                    continue
            if interpolation:
                if c == "(":
                    depth += 1
                elif c == ")":
                    if depth == 0:
                        return i + 1
                    depth -= 1
            i += 1
        return i

    def string(i, delimiter, hashes):
        close = delimiter + "#" * hashes
        escape = "\\" + "#" * hashes
        while i < n:
            if text.startswith(escape, i):
                k = i + len(escape)
                if k < n and text[k] == "(":
                    i = code(k + 1, True)
                    continue
                blank(i, k + 1)
                i = k + 1
                continue
            if text.startswith(close, i):
                return i + len(close)
            if delimiter == '"' and text[i] == "\n":
                return i       # an unterminated one-line string: don't swallow the file
            if text[i] != "\n":
                out[i] = " "
            i += 1
        return i

    # Deep interpolation nesting is rare, but recursion is per level of it.
    sys.setrecursionlimit(max(sys.getrecursionlimit(), 10000))
    code(0, False)
    return "".join(out)


IMPORT = re.compile(
    r"^\s*(?P<attrs>(?:@\w+(?:\([^()\n]*\))?\s+)*)(?:(?:public|package|internal|fileprivate|private|open)\s+)*"
    r"import\s+(?:(?P<kind>typealias|struct|class|enum|protocol|let|var|func)\s+)?"
    r"(?P<module>[A-Za-z_]\w*)(?P<rest>(?:\.\w+)*)\s*;?\s*$")


class Import:
    """One import line: `line` is 1-based; `kind` is None for a module
    import; `rest` is the dotted path after the module (`.C`, `.fopen`)."""

    __slots__ = ("line", "text", "module", "kind", "rest", "exported", "marker")

    def __init__(self, line, text, m):
        self.line = line
        self.text = text.strip()
        self.module = m.group("module")
        self.kind = m.group("kind")
        self.rest = m.group("rest").lstrip(".")
        self.exported = "@_exported" in (m.group("attrs") or "")
        self.marker = None      # the SYSTEM-GAP marker that covers it, if any

    @property
    def name(self):
        """The declaration a scoped import names (`fopen`), else None."""
        return self.rest.split(".")[-1] if self.kind and self.rest else None

    @property
    def form(self):
        """"scoped", "submodule" (`import Darwin.C`) or "whole"."""
        return "scoped" if self.kind else "submodule" if self.rest else "whole"


def imports(text, blanked=None):
    """The file's import lines, found in its code (not in comments or
    strings), with the SYSTEM-GAP marker that covers each."""
    code = (blanked if blanked is not None else blank_swift(text)).split("\n")
    raw = text.split("\n")
    found = []
    for i, line in enumerate(code):
        if "import" in line:
            m = IMPORT.match(line)
            if m:
                found.append(Import(i + 1, raw[i], m))
    by_line = {im.line: im for im in found}
    for mk in markers(text):
        for ln in mk.import_lines:
            if ln in by_line and by_line[ln].marker is None:
                by_line[ln].marker = mk
    return found


MARKER = re.compile(r"SYSTEM-GAP:\s*(.*?)\s*(?:\*/\s*)?$")
_COMMENT = re.compile(r"^\s*(?://+|/\*+|\*+)\s?(.*?)\s*(?:\*/)?\s*$")
_RAW_IMPORT = re.compile(IMPORT.pattern.replace(r"\s*;?\s*$", r"\s*;?\s*(?://.*)?$"))


class Marker:
    """A `SYSTEM-GAP:` marker: its first line, its text (continued onto the
    comment lines after it), and the lines of the imports it covers."""

    __slots__ = ("line", "text", "import_lines", "trailing")

    def __init__(self, line, text, import_lines, trailing):
        self.line = line
        self.text = text
        self.import_lines = import_lines
        self.trailing = trailing

    @property
    def head(self):
        """The marker's first line: what it's grouped by."""
        return self.text.split("\n")[0]


def markers(text):
    """Every SYSTEM-GAP marker in a comment of the file, as status.sh reads
    them: a marker's text continues onto the comment lines right after it,
    and it covers the imports right after its comment (comment lines and
    `#if`/`#else`/`#endif` lines may come between them), or the import it
    trails on the same line (`import func Darwin.fopen  // SYSTEM-GAP: C
    stdio`). status.sh doesn't look past an `#if` line."""
    lines = text.split("\n")
    found = []
    for i, line in enumerate(lines):
        m = MARKER.search(line)
        if not m:
            continue
        before = line[:m.start()]
        if not ("//" in before or "/*" in before or before.strip().startswith("*")):
            continue
        body = [m.group(1)]
        code = before[:before.find("//")] if "//" in before else ""
        if _RAW_IMPORT.match(code.rstrip()) or IMPORT.match(code.rstrip()):
            found.append(Marker(i + 1, m.group(1), [i + 1], True))
            continue
        j = i + 1
        while j < len(lines) and j - i <= 12:
            cm = _COMMENT.match(lines[j])
            if not cm or "SYSTEM-GAP" in lines[j] or not cm.group(1):
                break
            body.append(cm.group(1))
            j += 1
        k = j
        while k < len(lines) and _COMMENT.match(lines[k]) and lines[k].strip() and "SYSTEM-GAP" not in lines[k]:
            k += 1
        covered = []
        while k < len(lines):
            s = lines[k].strip()
            if _RAW_IMPORT.match(s):
                if "SYSTEM-GAP" in s:
                    break        # it has a marker of its own
                covered.append(k + 1)
                k += 1
                continue
            # Comments and compiler directives may come between: markers often sit above an
            # `#if compiler(>=6)` that picks the import's form.
            if (s.startswith("//") and "SYSTEM-GAP" not in s) or re.match(r"#(if|elseif|else|endif)\b", s):
                k += 1
                continue
            break
        found.append(Marker(i + 1, "\n".join(body), covered, False))
    return found


IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


# ---------------------------------------------------------------- swift-system

def system_checkout(explicit=None):
    """The swift-system checkout whose sources the lookups read: `--system`,
    then $ADOPTER_TOOLS_SYSTEM, then the checkout these tools are in."""
    path = os.path.abspath(explicit or os.environ.get("ADOPTER_TOOLS_SYSTEM") or os.path.join(HERE, "..", ".."))
    if not os.path.isdir(os.path.join(path, "Sources", "System")):
        fail(f"{path} isn't a swift-system checkout (no Sources/System); pass --system")
    return path


def system_sources(checkout, ref=None):
    """(the directory holding System's `Sources`, a description). With `ref`,
    Sources at that commit, exported once into the scratch directory; else
    the checkout's working tree, uncommitted changes included."""
    if not ref:
        return os.path.join(checkout, "Sources"), f"{checkout} (working tree)"
    commit = commit_of(checkout, ref)
    if not commit:
        fail(f"{ref}: no such commit in {checkout}")
    dest = os.path.join(scratch("system"), commit[:12])
    if not os.path.isdir(os.path.join(dest, "Sources")):
        tmp = f"{dest}.tmp-{os.getpid()}"
        shutil.rmtree(tmp, ignore_errors=True)
        os.makedirs(tmp)
        archive = git(checkout, "archive", commit, "Sources", binary=True)
        subprocess.run(["tar", "-x", "-C", tmp], input=archive, check=True)
        try:
            os.rename(tmp, dest)
        except OSError:
            shutil.rmtree(tmp, ignore_errors=True)   # another run made it first
    return os.path.join(dest, "Sources"), f"{checkout} at {commit[:10]} ({ref})"


def system_swift_files(sources):
    """System's library sources: SystemPackage's and SystemSockets'."""
    for top in ("System", "SystemSockets"):
        for dp, dns, fns in os.walk(os.path.join(sources, top)):
            dns.sort()
            for fn in sorted(fns):
                if fn.endswith(".swift"):
                    yield os.path.join(dp, fn)


_TYPE_DECL = re.compile(r"\b(?:extension|struct|enum|class|actor|protocol)\s+([A-Za-z_][\w.]*)")
_PUBLIC = re.compile(r"^\s*(?:@\w+(?:\([^()]*(?:\([^()]*\)[^()]*)*\))?\s+)*(?:(?:nonisolated|final|static|class|mutating"
                     r"|nonmutating|override|convenience|required|indirect|dynamic|optional|lazy|borrowing|consuming)\s+)*"
                     r"(?:public|open)\s")
_DIRECTIVE = re.compile(r"^\s*#(if|elseif|else|endif)\b\s*(.*)$")


class Declaration:
    """A public declaration of System's: where it is, its signature on one
    line, its doc comment's text, the type or extension it's in, and the
    `#if` conditions around it."""

    __slots__ = ("path", "line", "signature", "doc", "scope", "conditions")

    def __init__(self, path, line, signature, doc, scope, conditions):
        self.path, self.line, self.signature = path, line, signature
        self.doc, self.scope, self.conditions = doc, scope, conditions

    def where(self, sources):
        return f"{os.path.relpath(self.path, sources)}:{self.line}"

    def describe(self, sources, width=240):
        conds = [f"({c})" if "||" in c and len(self.conditions) > 1 else c for c in self.conditions]
        cond = f"  #if {' && '.join(conds)}" if conds else ""
        sig = self.signature if len(self.signature) <= width else self.signature[:width - 1] + "…"
        return f"{self.where(sources)}  [{self.scope or '-'}] {sig}{cond}"


def system_declarations(sources):
    """Every public declaration in System's library sources (see
    system_swift_files), with its doc comment. Scopes come from brace
    nesting in the code with comments and strings blanked; a `public`
    member of a type or extension is attributed to it."""
    for path in system_swift_files(sources):
        try:
            with open(path, encoding="utf-8", errors="replace") as h:
                text = h.read()
        except OSError:
            continue
        raw = text.split("\n")
        code = blank_swift(text).split("\n")
        doc, scopes, pending, conditions = [], [], None, []
        i = 0
        while i < len(raw):
            s = raw[i].strip()
            d = _DIRECTIVE.match(raw[i])
            if d:
                kind, cond = d.group(1), d.group(2).strip()
                if kind == "if":
                    conditions.append(cond)
                elif kind == "elseif" and conditions:
                    conditions[-1] = cond
                elif kind == "else" and conditions:
                    conditions[-1] = f"!({conditions[-1]})"
                elif kind == "endif" and conditions:
                    conditions.pop()
                i += 1
                continue
            if s.startswith("///"):
                doc.append(s[3:].strip())
                i += 1
                continue
            line = code[i]
            if _PUBLIC.match(line):
                # The signature: up to its body's brace, or its end.
                sig, j, depth = [s], i, line.count("(") - line.count(")")
                while depth > 0 and j + 1 < len(raw) and j - i < 20:
                    j += 1
                    sig.append(raw[j].strip())
                    depth += code[j].count("(") - code[j].count(")")
                signature = re.sub(r"\s+", " ", " ".join(sig))
                signature = re.sub(r"\s*\{.*$", "", signature).strip()
                scope = ".".join(n for n in scopes if n)
                yield Declaration(path, i + 1, signature, " ".join(doc), scope, list(conditions))
                doc = []
                for k in range(i, j + 1):
                    pending = _braces(code[k], scopes, pending)
                i = j + 1
                continue
            if s and not s.startswith("//") and not s.startswith("@"):
                doc = []
            pending = _braces(line, scopes, pending)
            i += 1


def _braces(line, scopes, pending):
    """Track the types and extensions a line opens and closes."""
    m = _TYPE_DECL.search(line)
    if m:
        pending = m.group(1)
    for c in line:
        if c == "{":
            scopes.append(pending)
            pending = None
        elif c == "}" and scopes:
            scopes.pop()
    return pending


# ---------------------------------------------------------------- #if, for macOS

_OTHER_OS = {"iOS", "tvOS", "watchOS", "visionOS", "xrOS", "Linux", "Windows", "FreeBSD", "OpenBSD", "Android",
             "WASI", "Cygwin", "PS4", "Haiku", "none"}
# Modules a macOS package build can import, and modules it can't.
_MAC_MODULES = {"Darwin", "Foundation", "Dispatch", "os", "ObjectiveC", "MachO", "XCTest", "CoreFoundation",
                "Security", "Combine", "OSLog", "Network", "AppKit", "Testing", "Synchronization", "_Concurrency"}
_OTHER_MODULES = {"Glibc", "Musl", "WinSDK", "ucrt", "CRT", "Android", "Bionic", "WASILibc", "wasi_pthread",
                  "Foundation_Windows", "WinSDK_Private"}
_COND_TOKEN = re.compile(r"\s*(\|\||&&|!|\(|\)|[A-Za-z_]\w*(?:\s*\((?:[^()]|\([^()]*\))*\))?)")
T, F, U = True, False, None


def _atom(tok):
    m = re.match(r"(\w+)\s*\((.*)\)$", tok, re.S)
    if not m:
        return {"true": T, "false": F, "SWIFT_PACKAGE": T}.get(tok, U)
    fn, arg = m.group(1), m.group(2).split(",")[0].strip()
    if fn == "os":
        return T if arg in ("macOS", "OSX") else F if arg in _OTHER_OS else U
    if fn == "canImport":
        top = arg.split(".")[0]
        return T if top in _MAC_MODULES else F if top in _OTHER_MODULES else U
    if fn == "targetEnvironment":
        return F
    return U


def evaluate_condition(text):
    """A `#if` condition for a macOS package build: True, False, or None
    when it depends on something unknown here (a flag, the compiler's
    version, an architecture, a module the package might provide)."""
    toks = _COND_TOKEN.findall(text.split("//")[0])
    pos = [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def take():
        pos[0] += 1
        return toks[pos[0] - 1]

    def primary():
        t = take() if peek() else None
        if t == "!":
            v = primary()
            return None if v is None else not v
        if t == "(":
            v = disjunction()
            if peek() == ")":
                take()
            return v
        return _atom(t) if t else U

    def conjunction():
        v = primary()
        while peek() == "&&":
            take()
            w = primary()
            v = F if (v is F or w is F) else (T if v is T and w is T else U)
        return v

    def disjunction():
        v = conjunction()
        while peek() == "||":
            take()
            w = conjunction()
            v = T if (v is T or w is T) else (F if v is F and w is F else U)
        return v

    try:
        return disjunction()
    except IndexError:
        return U


def macos_lines(text):
    """For each line of `text`, whether a macOS build might compile it:
    False only inside an `#if` branch that's certainly not taken there
    (`#if os(Linux)`, `#elseif canImport(Glibc)`, the `#else` of
    `#if canImport(Darwin)`)."""
    out = []
    stack = []      # [branch value, some branch certainly taken, every branch so far false]
    for line in text.split("\n"):
        d = _DIRECTIVE.match(line)
        if d:
            kind, cond = d.group(1), d.group(2)
            if kind == "if":
                v = evaluate_condition(cond)
                stack.append([v, v is T, v is F])
            elif kind == "elseif" and stack:
                fr = stack[-1]
                v = F if fr[1] else evaluate_condition(cond)
                fr[0], fr[1], fr[2] = v, fr[1] or v is T, fr[2] and v is F
            elif kind == "else" and stack:
                fr = stack[-1]
                fr[0] = F if fr[1] else (T if fr[2] else U)
            elif kind == "endif" and stack:
                stack.pop()
            out.append(all(fr[0] is not F for fr in stack))
            continue
        out.append(all(fr[0] is not F for fr in stack))
    return out
