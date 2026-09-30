#!/usr/bin/env python3
"""Writes STATUS.md: where System's API stands against `main`, how far its
adopters have moved off the Darwin module, and what they still mark as
missing from System. status.sh runs it after api-delta; see README.md.

Usage: status.py --repo DIR --adopters DIR --api-delta DIR --out FILE
                 [--branch migrate-darwin] [--base main] [--system-next system-next]
                 [--vocab FILE] [--cache DIR] [--date YYYY-MM-DD] [--dump-markers]

Only commits are read, all through git: System's HEAD (its sources, and
mapping.ini for the answers outside System) and its integration branch, and
each package's migration branch and that branch's merge base with the
package's base branch. A package's targets come from `swift package
dump-package` run on its manifests at the commit, cached by the manifests'
blob ids. Two things are copied from each package's MIGRATION.md or
REPORT.md, verbatim and labeled as copied: the test totals, and the count of
files that reach Darwin through a re-export. Nothing else in those reports
is read.

The method, with the alternatives it rejected, is METHOD below; it's also
the report's last section.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import datetime  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "api-delta", "scripts"))
from scan_sources import strip_comments_and_strings  # noqa: E402

import check  # noqa: E402
import ecosystem  # noqa: E402
import platforms  # noqa: E402

SOURCE_EXTENSIONS = (".swift", ".c", ".h", ".cpp", ".hpp", ".m", ".mm")
# System's library modules; the samples and C shims aren't its API.
SYSTEM_SOURCES = ("Sources/System", "Sources/SystemSockets")


# ---------------------------------------------------------------- git

def git(repo, *args, ok=(0,), stdin=None, binary=False):
    p = subprocess.run(["git", "-C", repo, *args], input=stdin, capture_output=True, text=not binary)
    if p.returncode not in ok:
        err = p.stderr.decode("utf-8", "replace") if binary else p.stderr
        raise RuntimeError(f"git -C {repo} {' '.join(args)}: {err.strip()}")
    return p.stdout


def commit_of(repo, ref):
    out = git(repo, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", ok=(0, 1)).strip()
    return out or None


def subject(repo, commit):
    return git(repo, "log", "-1", "--format=%s", commit).strip()


def tree_files(repo, commit):
    return git(repo, "ls-tree", "-r", "--name-only", "-z", commit).split("\0")[:-1]


def read_blobs(repo, specs):
    """{spec: text} for `commit:path` specs, through one `git cat-file --batch`."""
    specs = list(dict.fromkeys(specs))
    if not specs:
        return {}
    out = git(repo, "cat-file", "--batch", stdin=("\n".join(specs) + "\n").encode(), binary=True)
    blobs, pos = {}, 0
    for spec in specs:
        nl = out.index(b"\n", pos)
        header = out[pos:nl].decode()
        pos = nl + 1
        if header.endswith(" missing"):
            continue
        size = int(header.split()[2])
        blobs[spec] = out[pos:pos + size].decode("utf-8", "replace")
        pos += size + 1
    return blobs


def grep_files(repo, commit, pattern, pathspecs=(), fixed=True):
    """Paths at `commit` whose contents match the fixed string `pattern`,
    or the extended regular expression with `fixed=False`."""
    out = git(repo, "grep", "-l", "-I", "-F" if fixed else "-E", "-e", pattern, commit, "--", *pathspecs, ok=(0, 1))
    prefix = commit + ":"
    return [line[len(prefix):] for line in out.splitlines()]


# ---------------------------------------------------------------- System

# "The corresponding C function is `fsync`." and its variants: every public
# declaration names what it wraps this way (see CLAUDE.md), sometimes over
# two lines, sometimes with a second platform's name ("or on Darwin
# `st_atimespec`").
DOC_SENTENCE = re.compile(r"The corresponding C (?:[a-z]+ )*?(?:functions?|constants?|types?|fields?|errors?|macros?|"
                          r"propert(?:y|ies)|variables?)\s+(?:is|are)\s+(.*?)(?:\.(?=\s|$)|$)")
TICKED = re.compile(r"`(?:struct |union |enum )?([A-Za-z_][A-Za-z0-9_]*)`")


# Interfaces System covers under another C name: the replacement POSIX
# recommends, which System wraps instead. usleep is obsolescent, and
# localtime and gmtime aren't reentrant.
EQUIVALENTS = {
    "usleep": ("nanosleep",), "sleep": ("nanosleep",),
    "localtime": ("localtime_r",), "gmtime": ("gmtime_r",),
    "mkstemp": ("mkostemp",), "mkstemps": ("mkostemps",), "time": ("clock_gettime",),
    "gettimeofday": ("clock_gettime",),
}


# Families that System answers with a design of its own rather than a wrapper
# of the C interface, so that matching names can't see them: (the names, the
# System API that answers them, a witness in System's sources that the answer
# has what the adopters' markers ask for, where the decision is recorded).
ANSWERED = [
    (r"^(fts_\w+|FTS\w*)$", "DirectoryWalk", "case preorderAndPostorder",
     "Prototype/Directories/README.md"),
    # The C union's fields are the identifier's bits; TypeDescriptor is the
    # identifier, with Swift-named properties for the fields.
    (r"^malloc_type_descriptor_v0_t members$", "Memory.TypeDescriptor", "public var callSiteFlags",
     "Sources/System/TypedAllocation/TypeDescriptor.swift"),
    # A marker that names no C interface: Subprocess's raw posix_spawn path,
    # for the C values its configurator gets (RawSpawn.swift) and for other
    # credentials, which System spawns with by forking first.
    (r"^raw posix_spawn path$", "ProcessID.spawn's C-values and credentials forms",
     "fileActionDescriptors: [FileDescriptor]", "Sources/System/SpawnCredentials/SpawnCredentials.swift"),
    # Subprocess's spawns with C values and arguments that aren't UTF-8: the
    # C-array forms of those spawns (REPORT.md section 29).
    (r"^C-string arguments for the C-values spawns$", "ProcessID.spawn's C-array forms with C values",
     "  /// C file actions and attributes, and other credentials.",
     "Sources/System/SpawnCredentials/SpawnCredentials.swift"),
    # Foundation's framework build, which can import only the SDK's System:
    # dlopen with its options, dlsym and dlclose are DynamicLibrary's, which
    # the marker names; it waits for an OS whose SDK has it.
    (r"^DynamicLibrary$", "DynamicLibrary", "public struct DynamicLibrary: ~Copyable",
     "Sources/System/DynamicLoading/DynamicLibrary.swift"),
]


# Interfaces that System's docs name, but where the adopters' markers ask for
# more than the API that names them gives: (the names, what the markers ask
# for, a witness in System's sources that the ask is met). Until the witness
# is there, such an interface counts as missing, though a doc names it.
STILL_NEEDED = [
    # TSC's public `extension dirent { var name }` extends the C type itself,
    # which needs a public name, with Swift-named accessors (decision 84);
    # DirectoryStream.Entry, which names struct dirent, is another type.
    (r"^dirent$", "a CInterop alias for struct dirent, with Swift-named accessors",
     "public typealias DirectoryEntry = dirent"),
    # TSC's public dlerror() returns and clears the loader's pending error;
    # LoaderError, which names dlerror, carries only the errors System throws.
    (r"^dlerror$", "a call that returns and clears the loader's pending error",
     "public static func takePendingError()"),
    # Subprocess's configurator test adds a working-directory action to C
    # file actions that Subprocess built; SpawnFileAction names addchdir_np,
    # but only for the C file actions System builds itself.
    (r"^posix_spawn_file_actions_addchdir(_np)?$", "adding a SpawnFileAction to C file actions that other code built",
     "public func add(to cFileActions: inout CInterop.SpawnFileActions)"),
]


class SystemNames:
    """What System's library modules name at a commit: the C names in their
    doc comments' "corresponding C" sentences, their public typealiases'
    targets (the CInterop aliases), and the C structures they give
    Swift-named accessors (`extension CInterop.IOVec`)."""

    def __init__(self, repo, commit):
        self.commit = commit
        self.names = set()
        out = git(repo, "grep", "-n", "-I", "-e", r"^[[:space:]]*///", commit, "--", *SYSTEM_SOURCES, ok=(0, 1))
        blocks = collections.defaultdict(list)
        prefix = commit + ":"
        for raw in out.splitlines():
            path, line, text = raw[len(prefix):].split(":", 2)
            blocks[path].append((int(line), text.strip()[3:].strip()))
        for lines in blocks.values():
            block, last = [], None
            for line, text in lines:
                if last is not None and line != last + 1:
                    self._doc(" ".join(block))
                    block = []
                block.append(text)
                last = line
            self._doc(" ".join(block))

        self.aliases = collections.defaultdict(set)
        out = git(repo, "grep", "-h", "-I", "-E", "-e", r"public[[:space:]]+typealias", commit, "--",
                  *SYSTEM_SOURCES, ok=(0, 1))
        for line in out.splitlines():
            m = re.search(r"\bpublic\s+typealias\s+(\w+)\s*=\s*(?:struct\s+)?([A-Za-z_][\w.]*)", line)
            if m:
                self.aliases[m.group(1)].add(m.group(2))
        self.alias_targets = {t for ts in self.aliases.values() for t in ts}

        self.answered = []
        for pattern, api, witness, _ in ANSWERED:
            found = subprocess.run(["git", "-C", repo, "grep", "-q", "-F", "-e", witness, commit, "--",
                                    *SYSTEM_SOURCES]).returncode == 0
            if found:
                self.answered.append((pattern, api))

        self.still_needed = []
        for pattern, ask, witness in STILL_NEEDED:
            found = subprocess.run(["git", "-C", repo, "grep", "-q", "-F", "-e", witness, commit, "--",
                                    *SYSTEM_SOURCES]).returncode == 0
            if not found:
                self.still_needed.append((pattern, ask))

        self.accessor_structs = set()
        out = git(repo, "grep", "-h", "-I", "-E", "-e", r"^[[:space:]]*extension[[:space:]]+CInterop\.", commit, "--",
                  *SYSTEM_SOURCES, ok=(0, 1))
        for line in out.splitlines():
            m = re.search(r"extension\s+CInterop\.(\w+)", line)
            if m:
                self.accessor_structs |= self.aliases.get(m.group(1), set())

    def _doc(self, text):
        for m in DOC_SENTENCE.finditer(text):
            self.names.update(TICKED.findall(m.group(1)))

    def unnamed(self, name):
        """Whether System doesn't name the interface at all: not covered,
        and not named while a marker asks for more (STILL_NEEDED)."""
        return self.covers(name) == (False, "")

    def covers(self, name):
        """(covered, how) for a gap interface's name."""
        for pattern, ask in self.still_needed:
            if re.search(pattern, name):
                return False, f"named, but the marker asks for {ask}"
        for pattern, api in self.answered:
            if re.search(pattern, name):
                return True, f"by {api}"
        if name.endswith(" members"):
            struct = name[:-len(" members")]
            return struct in self.accessor_structs, "Swift-named accessors" if struct in self.accessor_structs else ""
        if name.endswith("*"):
            hits = sorted(n for n in self.names | self.alias_targets if n.startswith(name[:-1]))
            return bool(hits), f"{len(hits)} names" if hits else ""
        if name in self.names:
            return True, "doc comment"
        if name in self.alias_targets:
            return True, "CInterop alias"
        for other in EQUIVALENTS.get(name, ()):
            if other in self.names:
                return True, f"as `{other}`"
        return False, ""


# ---------------------------------------------------------------- answers outside System

# What mapping.ini, at System's commit, answers for names System doesn't
# name: an entry with a `swift` answer is the standard library's, and one
# marked `wrap = no` is another module's or library's (the MachO module's
# file format, a framework's), not System's to wrap. The `swift` answer
# comes first, as in ecosystem.py's Darwin queue. Neither makes a name
# covered: that stays what System's sources document.
MAPPING = "Utilities/adopter-coverage/mapping.ini"
OUTSIDE = ("standard library", "not System's")


def outside_answers(repo, commit, scratch):
    """{C name: (kind, how)} from mapping.ini at `commit`, read through a
    copy in `scratch`, since check.py's reader takes a path."""
    spec = f"{commit}:{MAPPING}"
    text = read_blobs(repo, [spec]).get(spec)
    if text is None:
        return {}
    os.makedirs(scratch, exist_ok=True)
    path = os.path.join(scratch, "mapping.ini")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    _, entries, _ = check.load_mapping(path)
    out = {}
    for e in entries:
        if e["hand"] == "ignore":
            continue
        if e["swift"]:
            swift = e["swift"] if len(e["swift"]) <= 90 else e["swift"][:90].rsplit(" ", 1)[0].rstrip(",;:") + " …"
            answer = ("standard library", f"[{e['id']}]: {swift}")
        elif e["wrap"] == "no":
            answer = ("not System's", f"[{e['id']}]")
        else:
            continue
        for s in e["symbols"]:
            out.setdefault(s, answer)
    return out


def outside_answer(name, answers):
    """The answer for one gap name; `X members` is X's."""
    return answers.get(name[:-len(" members")] if name.endswith(" members") else name)


# ---------------------------------------------------------------- provisional families

# C-library layers above the OS that System wraps provisionally, in
# Sources/System/Provisional/, since they may move to the standard library:
# math, stdio, locales, and string.h and ctype.h. They count as missing until
# System covers them, as everything else does; the family only groups them,
# and names the file they go in. A name falls in one by these lists or by its
# SDK module (from adopter-coverage's stored vocabulary, when there is one).
# remove(3) and rename(2) are declared in stdio.h, but they're file-system
# calls, and System's.
PROVISIONAL = [
    ("libm", "Provisional+Math.swift",
     ("._math", "._tgmath", "._complex", "._fenv"),
     """sin cos tan asin acos atan atan2 sinh cosh tanh asinh acosh atanh exp exp2 expm1 log log2 log10 log1p
        pow sqrt cbrt hypot floor ceil round trunc rint nearbyint fmod remainder fabs fmin fmax fma ldexp frexp
        modf copysign nan erf erfc lgamma tgamma"""),
    ("C stdio", "Provisional+Stdio.swift",
     ("._stdio",),
     """FILE stdin stdout stderr fopen fdopen freopen fclose fflush fwrite fread fputs fputc fgets fgetc
        fprintf fscanf fseek fseeko ftell ftello rewind fileno flockfile funlockfile ftrylockfile setbuf setvbuf
        setlinebuf printf puts putchar getchar perror sprintf snprintf vfprintf vprintf getline getdelim popen
        pclose tmpfile ferror feof clearerr"""),
    ("locale", "Provisional+Locale.swift",
     ("._locale", ".xlocale", "locale.locale_t"),
     """locale_t setlocale newlocale uselocale freelocale duplocale localeconv querylocale LC_ALL LC_COLLATE
        LC_CTYPE LC_MONETARY LC_NUMERIC LC_TIME LC_MESSAGES LC_GLOBAL_LOCALE strtod_l strtof_l strtold_l
        strtol_l strtoll_l strtoul_l strtoull_l strncasecmp_l strcasecmp_l strcoll_l strxfrm_l strftime_l
        isspace_l isdigit_l toupper_l tolower_l"""),
    ("string.h and ctype.h", "Provisional+StringH.swift",
     ("._string", "._strings", "._ctype", "._wctype"),
     """memcpy memmove memset bcopy bzero strlen strnlen strcmp strncmp strcasecmp
        strncasecmp strcpy strncpy strlcpy strlcat strcat strncat strchr strrchr strstr strdup strndup strtok
        strtok_r strspn strcspn strpbrk isspace isalpha isdigit isalnum isupper islower isxdigit isprint
        ispunct iscntrl isgraph toupper tolower"""),
    ("C numeric conversion", "Provisional+Stdlib.swift",
     (),
     "strtod strtof strtold strtol strtoll strtoul strtoull atoi atol atoll atof"),
]
PROVISIONAL_BY_NAME = {n: fam for fam, _, _, names in PROVISIONAL for n in names.split()}


def load_vocab(path):
    """{name: {SDK modules}} from adopter-coverage's stored vocabulary, or {}."""
    if not path or not os.path.exists(path):
        return {}
    with gzip.open(path, "rt", encoding="utf-8") as f:
        data = json.load(f)
    where = collections.defaultdict(set)
    for module, names in data["vocab"].items():
        for n in names:
            where[n].add(module)
    return where


def provisional_family(name, vocab):
    """The provisional family a C name belongs to, or None."""
    if name in PROVISIONAL_BY_NAME:
        return PROVISIONAL_BY_NAME[name]
    modules = vocab.get(name, set())
    if not modules:
        return None
    families = set()
    for m in modules:
        fam = next((f for f, _, suffixes, _ in PROVISIONAL if any(m.endswith(s) or s in m for s in suffixes)), None)
        if fam is None:
            return None   # declared somewhere else too
        families.add(fam)
    return sorted(families)[0] if families else None


# ---------------------------------------------------------------- families

# Display families for the ranked gaps: which System cluster a name belongs
# to. Names outside these take the phrase of the marker that named them
# ("libm (sin, cos)" -> libm), or stand alone.
FAMILIES = [
    ("C struct members (MemberImportVisibility)", r" members$"),
    ("fts", r"^(fts_\w+|FTS\w*)$"),
    ("removefile", r"^(removefile\w*|REMOVEFILE_\w+)$"),
    ("sysdir", r"^sysdir_\w+$"),
    ("copyfile", r"^(f?copyfile|copyfile_\w+|COPYFILE_\w+)$"),
    ("extended attributes", r"(xattr|^XATTR_\w+)"),
    ("Mach virtual memory", r"^(vm_\w+|mach_task_self_?|mach_vm_\w+)$"),
    ("libmalloc", r"^malloc_\w+$"),
    ("the C heap", r"^(malloc|calloc|realloc|free|posix_memalign|aligned_alloc)$"),
    ("IP-level socket options", r"^(IP_\w*\*?|IPV6_\w*\*?|INADDR_\w+|in6?_pktinfo|ip(?:v6)?_mreq)$"),
    ("socket options", r"^(SO_\w+|TCP_\w+|TSI_\w+|linger|timeval|tcp_connection_info)$"),
    ("network interfaces", r"^(if_\w+|getifaddrs|freeifaddrs|ifaddrs|IFF_\w+)$"),
    ("address text", r"^(inet_\w+|INET6?_ADDRSTRLEN)$"),
    ("dynamic loader", r"^(dlopen|dlsym|dlclose|dlerror|dladdr|RTLD_\w+)$"),
    ("environment", r"^(getenv|setenv|unsetenv|environ)$"),
    ("compile-time limits", r"^(NAME_MAX|PATH_MAX|MAXSYMLINKS)$"),
    ("sysexits", r"^EX_\w+$"),
    ("calendar time", r"^(time|localtime\w*|gmtime\w*|strftime|mktime|timegm|tm|time_t)$"),
    ("temporary files", r"^(mkstemp|mkdtemp|mktemp)$"),
    ("vsock", r"^(sockaddr_vm|AF_VSOCK|PF_VSOCK)$"),
    ("posix_spawn", r"^(posix_spawn\w*|POSIX_SPAWN_\w+)$"),
    ("sleep", r"^(usleep|nanosleep|sleep)$"),
    ("confstr", r"^(confstr|_CS_\w+)$"),
    ("tzfile.h", r"^(TZDIR|TZDEFAULT)$"),
    ("file times", r"^UTIME_\w+$"),
    ("directory entry types", r"^DT_\w*\*?$"),
]


def family_of(name, phrase, vocab, provisional=True):
    fam = provisional_family(name, vocab) if provisional else None
    if fam:
        return fam + " (provisional)"
    for fam, pattern in FAMILIES:
        if re.search(pattern, name):
            return fam
    return phrase or name


# ---------------------------------------------------------------- markers

MARKER = re.compile(r"SYSTEM-GAP:\s*(.*?)\s*(?:\*/\s*)?$")
COMMENT = re.compile(r"^\s*(?://+|/\*+|\*+)\s?(.*?)\s*(?:\*/)?\s*$")
IMPORT = re.compile(r"^\s*(?:@\w+(?:\([^()\n]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private|open)\s+)*"
                    r"import\s+(?:(?P<kind>typealias|struct|class|enum|protocol|let|var|func)\s+)?"
                    r"(?P<module>[A-Za-z_]\w*)(?P<rest>(?:\.\w+)*)\s*;?\s*$")

# An identifier that reads as C whatever its position: it has an
# underscore or a digit after a letter, or is all capitals, or starts with
# an underscore; `IP_*` is a family of them. Capitalized words that are
# English or Swift acronyms aren't.
STRONG = re.compile(r"^(?:[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]*|[A-Z][A-Z0-9_]+|_[A-Za-z0-9_]+)\*?$")
WORD = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\*?$")
ACRONYMS = {"API", "ABI", "VM", "NIO", "IP", "TCP", "UDP", "UTC", "IO", "OS", "C", "POSIX", "SDK", "SPI", "MIV",
            "BSD", "ICU", "UUID", "URL", "CPU", "ID", "NOT", "AND", "OR", "TODO"}
# Words that name a family of interfaces rather than one.
FAMILY_WORDS = {"libm", "xlocale", "fts", "sysdir", "vsock", "libmalloc", "libc"}
# Formats and SDK modules that markers name before a C name, as they name a
# header: `MacTypes OSStatus`, `Mach-O load_command`.
QUALIFIERS = {"MacTypes", "Mach-O", "MachO"}
# Nouns that qualify a name without naming another: `IPV6_* socket options`,
# `POSIXErrorCode's cases`, `copyfile(3) flags`.
GENERIC = {"cases", "case", "values", "value", "fields", "field", "members", "member", "flags", "flag", "options",
           "option", "socket", "constants", "constant", "types", "type", "structs", "struct", "family", "functions",
           "function", "names", "name"}
MEMBER_WORDS = {"fields", "field", "members", "member"}
# Words that read as lowercase C names in a list's position but aren't.
ENGLISH = set("""its their the a an this that these those zero and or of for with to in on by as is are be not no all
    any some each every other raw same own it them they its we our see also e.g i.e""".split())
# Modules and Swift types that markers mention in their explanations.
SWIFT_NAMES = {"System", "SystemSockets", "SystemPackage", "NIO", "NIOPosix", "NIOCore", "Foundation", "Swift",
               "Darwin", "Glibc", "CInterop", "Errno", "XCTest", "FileDescriptor", "FilePath", "DynamicLibrary"}


def depths(s):
    """Nesting depth at each character: parentheses and backticks. A
    parenthesis has the depth of the text inside it."""
    out, depth, tick = [], 0, False
    for ch in s:
        if ch == "`":
            tick = not tick
            out.append(depth + 1)
            continue
        if ch == "(" and not tick:
            depth += 1
        out.append(depth + (1 if tick else 0))
        if ch == ")" and not tick:
            depth = max(0, depth - 1)
    return out


def split_top(s, pattern):
    """Pieces of s between matches of pattern outside parentheses and
    backticks, each with the text of the match that ended it."""
    d = depths(s)
    pieces, last = [], 0
    for m in re.finditer(pattern, s):
        if m.start() < last or d[m.start()] != 0 or d[max(m.end() - 1, m.start())] != 0:
            continue
        pieces.append((s[last:m.start()], m.group(0)))
        last = m.end()
    pieces.append((s[last:], ""))
    return pieces


def incomplete(text):
    """Whether a marker's text stops mid-list, so its next comment line
    continues it."""
    d = depths(text + " ")
    return d[-1] > 0 or bool(re.search(r"(,|'s|\band|\bor|\bof|\bthe|:|\(|/|&)$", text.strip()))


def groups(item):
    """(core, [(attached, content, words before)]): the item's text outside
    parentheses, and each top-level parenthesized group, noting whether it's
    attached to the word before it (a man-page section, `usleep(3)`, or an
    argument, `confstr(_CS_DARWIN_USER_TEMP_DIR)`)."""
    core, out, i = [], [], 0
    while i < len(item):
        if item[i] == "(":
            depth, j = 1, i + 1
            while j < len(item) and depth:
                depth += {"(": 1, ")": -1}.get(item[j], 0)
                j += 1
            attached = i > 0 and not item[i - 1].isspace()
            out.append((attached, item[i + 1:j - 1] if depth == 0 else item[i + 1:j],
                        len("".join(core).split())))
            core.append(" ")
            i = j
            continue
        core.append(item[i])
        i += 1
    return re.sub(r"\s+", " ", "".join(core)).strip(), out


def clean_word(w):
    return w.strip("`\"'.,;:").replace("struct ", "")


def is_c(w, strong_only=False):
    w = clean_word(w)
    if not WORD.match(w) or w in ACRONYMS or w in SWIFT_NAMES:
        return False
    if STRONG.match(w):
        return True
    return not strong_only and w not in ENGLISH


def parse_items(text, members=False):
    """Names in a comma-separated list of marker items. Returns (names,
    phrases, first): names as (name, phrase of the item that named it),
    phrases that name no C interface, and the kind of the first item
    ("name", "phrase" or "prose"), since only a name starts a list after a
    colon."""
    pieces = [p for p, _ in split_top(text, r",\s+|;\s+|\s+and\s+|\s+or\s+")]
    names, phrases, first = [], [], None
    distributive = False
    for piece in pieces:
        got, phrase, kind, member_suffix = parse_item(piece.strip(), members)
        distributive |= member_suffix
        if first is None:
            first = kind
        names += got
        if kind == "prose" and phrase:
            phrases.append(phrase)
    if distributive:
        names = [(n if n.endswith(" members") or n.endswith("*") else n + " members", p) for n, p in names]
    return names, phrases, first or "prose"


def parse_item(item, members=False):
    """(names, phrase, kind, member_suffix) for one marker item: kind is
    "name" when the item is a name (possibly qualified), "phrase" when a
    phrase lists names in parentheses, "prose" when it names none. See
    METHOD."""
    item = re.sub(r"^(?:the|and|or|a|an)\s+", "", item.strip().rstrip(".,;:"))
    if not item:
        return [], None, "prose", False
    core, grps = groups(item)
    cites = [(a, c, k) for a, c, k in grps if a and re.match(r"^\d[a-z]?$", c)]
    grps = [(a, c, k) for a, c, k in grps if not (a and re.match(r"^\d[a-z]?$", c))]
    words = core.replace("struct ", "").split()
    suffix = " members" if members else ""

    def from_groups(miv=members):
        got = []
        for attached, content, _ in grps:
            names, _, first = parse_items(content, miv)
            if first != "prose":
                got += names
        return got

    def with_phrase(names, phrase):
        return [(n, phrase if p is None else p) for n, p in names]

    if not words:
        return [], None, "prose", False
    # members of sockaddr_storage (ss_family) under MemberImportVisibility
    m = re.match(r"^members of (\w+)\b(?!-)", core)
    if m and is_c(m.group(1)) and m.group(1) != "System":
        return [(m.group(1) + " members", None)], None, "name", False
    # members of System-vended C structs under MemberImportVisibility (msghdr, iovec)
    if core.startswith("members of"):
        got = from_groups(miv=True)
        return with_phrase(got, None), core if not got else None, "phrase" if got else "prose", False
    one = clean_word(words[0])
    # A plural generic noun alone names none: `constants (FAT_CIGAM, LC_MAIN)`
    # is a phrase with a list.
    if len(words) == 1 and is_c(one) and not (one in GENERIC and one.endswith("s")):
        if one in FAMILY_WORDS:
            return with_phrase(from_groups(), one), one, "name", False
        names = [(one + suffix, None)]
        # confstr(_CS_...), strftime (tm, time_t), setlocale (LC_ALL); not
        # POSIXErrorCode (ENAMETOOLONG), whose group lists its members.
        if not (one[0].isupper() and re.search(r"[a-z]", one) and "_" not in one):
            names += from_groups()
        return names, None, "name", False
    # possessives: iovec's iov_len, libmalloc's malloc_good_size, POSIXErrorCode's cases
    m = re.match(r"^([^\s']+)'s(?:\s+(.*))?$", core)
    if m and is_c(m.group(1)):
        owner, owned = clean_word(m.group(1)), (m.group(2) or "").split()
        if members:
            return [(owner + " members", None)], None, "name", False
        if owner.startswith("lib") and len(owned) == 1 and is_c(owned[0]):
            # libmalloc's malloc_type_descriptor_v0_t (summary, layout_semantics): a type and its fields
            named = clean_word(owned[0])
            return [(named, owner)] + ([(named + " members", owner)] if grps else []), None, "name", False
        if not owned or (len(owned) == 1 and owned[0] in GENERIC):
            name = owner + (" members" if owned and owned[0] in MEMBER_WORDS else "")
            return [(name, None)], None, "name", False
        if len(owned) == 1 and is_c(owned[0], strong_only=True):
            return [(owner, None), (clean_word(owned[0]), None)], None, "name", False
        got = from_groups()
        return with_phrase(got, core), core, "phrase" if got else "prose", False
    # string.h memcmp, sysexits.h EX_USAGE, MacTypes OSStatus
    if len(words) == 2 and (re.match(r"^[\w/]+\.h$", words[0]) or words[0] in QUALIFIERS) and is_c(words[1]):
        return [(clean_word(words[1]) + suffix, words[0])], None, "name", False
    # timespec members, IPV6_* socket options, copyfile(3) flags, the sockaddr family
    if is_c(one) and len(words) > 1 and all(w in GENERIC for w in words[1:]):
        member = any(w in MEMBER_WORDS for w in words[1:])
        return [(one + (" members" if member or members else ""), None)], None, "name", member
    # writev(2) on a caller's iovec array: a man-page citation names the first word
    if cites and cites[0][2] == 1 and is_c(one):
        got = [(one + suffix, None)]
        if len(words) > 1 and words[1].startswith("/") and is_c(words[1][1:]):
            got.append((clean_word(words[1][1:]) + suffix, None))
        return got, None, "name", False
    # CInterop has no alias for sockaddr_storage
    if len(words) > 2 and words[-2] in ("for", "of", "as", "like") and is_c(words[-1], strong_only=True) and not grps:
        return [(clean_word(words[-1]) + suffix, None)], None, "name", False
    # a phrase with a list: libm (sin, cos, pow), the C heap (calloc, malloc, free)
    got = from_groups()
    return with_phrase(got, core), core, "phrase" if got else "prose", False


def parse_marker(text):
    """(names, phrases) for a marker's text: names as (name, phrase)."""
    pieces = split_top(text, r"\.(?=\s|$)|;|\s—\s|\s--\s|:(?=\s|$)")
    head, end = pieces[0]
    names, phrases, _ = parse_items(head)
    # After a colon, a list continues the head (vsock: sockaddr_vm, AF_VSOCK);
    # prose explains it (errno: the C calls below...). A list after "members
    # of System-vended C structs:" names structs whose fields are missing.
    members = head.strip().startswith("members of")
    i = 0
    while end == ":" and i + 1 < len(pieces):
        nxt, nend = pieces[i + 1]
        more, more_phrases, first = parse_items(nxt, members=members)
        if first != "name" or not more:
            break
        names += more
        phrases += more_phrases
        i, end = i + 1, nend
    return names, phrases


def file_markers(text):
    """(line, marker text, Darwin names imported under it) for each
    SYSTEM-GAP marker in a source file. The names are the scoped imports
    (and submodule-less imports) between the marker's comment and the next
    code line."""
    lines = text.split("\n")
    found = []
    for i, line in enumerate(lines):
        m = MARKER.search(line)
        if not m:
            continue
        before = line[:m.start()]
        if not ("//" in before or "/*" in before or before.strip().startswith("*")):
            continue
        body = m.group(1)
        j = i + 1
        while j < len(lines) and j - i <= 8:
            cm = COMMENT.match(lines[j])
            if not cm or not cm.group(1) or "SYSTEM-GAP" in lines[j] or "MIGRATE-DARWIN" in lines[j]:
                break
            # A parenthesized list on the next line continues the last item
            # (`and constants` / `(FAT_CIGAM, LC_MAIN)`).
            if not incomplete(body) and not cm.group(1).startswith("("):
                break
            body += " " + cm.group(1)
            j += 1
        imported = []
        # A marker can trail the import it's for: `import func Darwin.fopen  // SYSTEM-GAP: C stdio`.
        code = before[:before.find("//")] if "//" in before else ""
        im = IMPORT.match(code.rstrip())
        if im and im.group("module") == "Darwin" and im.group("kind"):
            found.append((i + 1, body, [im.group("rest").split(".")[-1]]))
            continue
        k = j
        while k < len(lines) and lines[k].strip() and COMMENT.match(lines[k]) and "SYSTEM-GAP" not in lines[k]:
            k += 1
        while k < len(lines):
            s = lines[k].strip()
            im = IMPORT.match(s)
            if im:
                if im.group("module") == "Darwin" and im.group("kind"):
                    imported.append(im.group("rest").split(".")[-1])
                k += 1
                continue
            if s.startswith("//") and "SYSTEM-GAP" not in s:
                k += 1
                continue
            break
        found.append((i + 1, body, imported))
    return found


def marker_interfaces(body, imported):
    """[(interface, phrase, names for its status)] for one marker. An
    interface is a C name the marker's text gives, or, when its text names
    none, the phrase it uses, with the names imported under it."""
    names, phrases = parse_marker(body)
    out = []
    seen = set()
    for name, phrase in names:
        if name.endswith("*"):
            expanded = [n for n in imported if n.startswith(name[:-1])]
            if expanded:
                for n in expanded:
                    if n not in seen:
                        seen.add(n)
                        out.append((n, phrase, [n]))
                continue
        if name not in seen:
            seen.add(name)
            out.append((name, phrase, [name]))
    if out:
        return out
    miv = body.strip().startswith("members of")
    if miv:
        structs = imported or [n for n in TICKED.findall(body) if is_c(n)]
        return [(s + " members", None, [s + " members"]) for s in dict.fromkeys(structs)]
    head = split_top(body, r"\.(?=\s|$)|;|\s—\s|\s--\s|:(?=\s|$)")[0][0]
    phrase = split_top(head, r",\s+")[0][0].strip()
    phrase = re.sub(r"^(?:the|a|an)\s+", "", re.sub(r"\s+", " ", phrase))[:90]
    return [(phrase, phrase, list(dict.fromkeys(imported)))]


# ---------------------------------------------------------------- packages

MANIFEST = re.compile(r"^Package(@swift-[\d.]+)?\.swift$")
PREDEFINED = {"test": ("Tests", "Sources", "Source", "src", "srcs"), "plugin": ("Plugins",)}
DEFAULT_DIRS = ("Sources", "Source", "src", "srcs")


def swift_candidates():
    """`swift` executables to evaluate manifests with: the default one, then
    any installed toolchain's, newest first. Swift 6.2 can't type-check
    swift-foundation's manifest in reasonable time; a main-branch snapshot
    can."""
    found = ["swift"]
    extra = os.environ.get("STATUS_SWIFT", "")
    found += [x for x in extra.split(":") if x]
    root = os.path.expanduser("~/Library/Developer/Toolchains")
    if os.path.isdir(root):
        for t in sorted(os.listdir(root), reverse=True):
            exe = os.path.join(root, t, "usr", "bin", "swift")
            if t.endswith(".xctoolchain") and not os.path.islink(os.path.join(root, t)) and os.path.exists(exe):
                found.append(exe)
    return list(dict.fromkeys(found))


def manifest_targets(repo, commit, files, cache, name):
    """The root package's targets at a commit, from `swift package
    dump-package` of its manifests (cached by their blob ids), or None."""
    manifests = sorted(f for f in files if MANIFEST.match(f))
    if not manifests:
        return None, "no Package.swift"
    ids = git(repo, "rev-parse", *[f"{commit}:{m}" for m in manifests]).split()
    key = hashlib.sha1(" ".join(f"{m}={i}" for m, i in zip(manifests, ids)).encode()).hexdigest()[:16]
    path = os.path.join(cache, f"{name}-{key}.json")
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
        return data.get("targets"), data.get("error")
    os.makedirs(cache, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix=f"{name}-", dir=cache)
    try:
        blobs = read_blobs(repo, [f"{commit}:{m}" for m in manifests])
        for m in manifests:
            with open(os.path.join(tmp, m), "w") as f:
                f.write(blobs[f"{commit}:{m}"])
        data, errors = None, []
        for swift in swift_candidates():
            p = subprocess.run([swift, "package", "--disable-sandbox", "dump-package"], cwd=tmp,
                               capture_output=True, text=True)
            if p.returncode == 0:
                dump = json.loads(p.stdout)
                targets = [{k: t.get(k) for k in ("name", "type", "path", "exclude", "sources")}
                           for t in dump["targets"]]
                data = {"targets": targets, "error": None, "swift": swift}
                break
            lines = [x for x in p.stderr.strip().splitlines() if "error:" in x] or ["dump-package failed"]
            errors.append(f"{swift}: {lines[0].strip()[:160]}")
        if data is None:
            data = {"targets": None, "error": "; ".join(errors)}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if data["targets"] is not None:
        with open(path, "w") as f:
            json.dump(data, f)
    return data["targets"], data["error"]


def target_files(files, targets):
    """{path: target name} for the source files of the targets."""
    dirs = {f.split("/")[0] + "/" + f.split("/")[1] for f in files if f.count("/") >= 2}
    out = {}
    if targets is None:
        # Without the manifest, SwiftPM's default layout.
        for f in files:
            if f.endswith(SOURCE_EXTENSIONS) and f.split("/")[0] in ("Sources", "Tests") and f.count("/") >= 2:
                out[f] = f.split("/")[1]
        return out
    for t in targets:
        if t["type"] in ("system", "binary"):
            continue
        root = t.get("path")
        if not root:
            for d in PREDEFINED.get(t["type"], DEFAULT_DIRS):
                if f"{d}/{t['name']}" in dirs:
                    root = f"{d}/{t['name']}"
                    break
        if not root:
            continue
        root = root.strip("/")
        prefix = "" if root in ("", ".") else root + "/"
        sources = [prefix + s.strip("/") for s in (t.get("sources") or [])]
        exclude = [prefix + s.strip("/") for s in (t.get("exclude") or [])]
        for f in files:
            if not f.startswith(prefix) or not f.endswith(SOURCE_EXTENSIONS):
                continue
            if sources and not any(f == s or f.startswith(s + "/") for s in sources):
                continue
            if any(f == e or f.startswith(e + "/") for e in exclude):
                continue
            out.setdefault(f, t["name"])
    return out


PACKAGE_MODEL = platforms.model(flags={"FOUNDATION_FRAMEWORK": {p: platforms.F for p in platforms.PLATFORMS}})
FRAMEWORK_MODEL = platforms.model(flags={"FOUNDATION_FRAMEWORK": {p: platforms.T for p in platforms.PLATFORMS}})


def darwin_imports(text):
    """How a Swift file's macOS package build imports Darwin, at its
    broadest: "whole" (`import Darwin`), "submodule" (`import Darwin.C`),
    "scoped" (`import func Darwin.usleep` only), "framework" (only imports
    that FOUNDATION_FRAMEWORK builds alone compile), or None."""
    code, _ = strip_comments_and_strings(text)
    lines = code.split("\n")
    found = [(i, "scoped" if im.group("kind") else "submodule" if im.group("rest") else "whole")
             for i, line in enumerate(lines)
             for im in [IMPORT.match(line)] if im and im.group("module") == "Darwin"]
    if not found:
        return None
    try:
        pkg, _, _ = platforms.swift_line_states(lines, PACKAGE_MODEL)
        fw, _, _ = platforms.swift_line_states(lines, FRAMEWORK_MODEL)
    except (ValueError, IndexError):
        pkg = fw = [{"Darwin": (platforms.M, [])}] * len(lines)
    kinds = {kind for i, kind in found if "Darwin" in pkg[i]}
    for kind in ("whole", "submodule", "scoped"):
        if kind in kinds:
            return kind
    return "framework" if any("Darwin" in fw[i] for i, _ in found) else None


class Snapshot:
    """One package commit: its Darwin-importing files and SYSTEM-GAP markers."""

    def __init__(self, repo, commit, cache, name):
        self.commit = commit
        files = tree_files(repo, commit)
        self.targets, self.manifest_error = manifest_targets(repo, commit, files, cache, name)
        self.in_targets = target_files(files, self.targets)
        self.swift_files = sum(1 for f in self.in_targets if f.endswith(".swift"))
        darwin = [f for f in grep_files(repo, commit, "Darwin", ["*.swift"]) if f in self.in_targets]
        gaps = grep_files(repo, commit, "SYSTEM-GAP", [f"*{e}" for e in SOURCE_EXTENSIONS])
        blobs = read_blobs(repo, [f"{commit}:{f}" for f in set(darwin) | set(gaps)])
        self.imports = {k: set() for k in ("whole", "submodule", "scoped", "framework")}
        for f in darwin:
            kind = darwin_imports(blobs.get(f"{commit}:{f}", ""))
            if kind:
                self.imports[kind].add(f)
        self.markers = []   # (path, line, text, imported, in targets)
        for f in sorted(gaps):
            for line, body, imported in file_markers(blobs.get(f"{commit}:{f}", "")):
                self.markers.append((f, line, body, imported, f in self.in_targets))

    def marker_count(self, targets_only=True):
        ms = [m for m in self.markers if m[4] or not targets_only]
        return len(ms), len({m[0] for m in ms})


# ---------------------------------------------------------------- platform imports

# The platform C modules that no library of the toolchain should import, on
# any platform, in any form; ecosystem.py's import pattern, widened to them.
PLATFORM_MODULES = ("Darwin", "Glibc", "Musl", "Bionic", "Android", "WASILibc", "ucrt", "WinSDK", "CRT", "visualc")
IMPORT_PLATFORM = ecosystem.import_of(PLATFORM_MODULES)
IMPORT_KINDS = ("library", "tests", "other", "nested package")
# The scheme's repositories the tracker leaves out.
NOT_TRACKED = {"swift-system": "System itself, whose imports are what it wraps",
               "swift": "the compiler, the runtime, and the platform modules' own overlays"}
# The adopters' checkouts, by the scheme's name where theirs differs.
ADOPTER_DIRS = {"wasmkit": "WasmKit", "llbuild": "swift-llbuild", "swiftpm": "swift-package-manager"}
# Where library code lives: SwiftPM's default target directories, and
# llbuild's lib and products. Anything else at the top is other code:
# benchmarks, examples, tools, plugins, docs, utilities.
LIBRARY_ROOTS = {"Sources", "Source", "src", "srcs", "lib", "products"}
TEST_DIR = re.compile(r"^(tests?|unittests|perftests|integrationtests|fixtures|testinputs|testsupport|inputs)$", re.I)


def import_kind(path, nested):
    """A file's kind for the tracker: in a nested package (a directory with
    its own manifest), else tests (under a test directory at any depth),
    else library (under a library root), else other."""
    dirs = path.split("/")[:-1]
    if any("/".join(dirs[:i]) in nested for i in range(1, len(dirs) + 1)):
        return "nested package"
    if any(TEST_DIR.match(d) for d in dirs):
        return "tests"
    if dirs and dirs[0] in LIBRARY_ROOTS and not any(d.endswith(".docc") for d in dirs):
        return "library"
    return "other"


def platform_imports(repo, commit):
    """{path: (kind, {modules})} for the Swift files at `commit` that import
    a platform C module, read lexically with comments and strings blanked."""
    files = tree_files(repo, commit)
    nested = {os.path.dirname(f) for f in files if MANIFEST.match(os.path.basename(f)) and "/" in f}
    candidates = grep_files(repo, commit, "|".join(PLATFORM_MODULES), ["*.swift"], fixed=False)
    blobs = read_blobs(repo, [f"{commit}:{f}" for f in candidates])
    out = {}
    for f in candidates:
        code, _ = strip_comments_and_strings(blobs.get(f"{commit}:{f}", ""))
        modules = {m.group(1) for m in IMPORT_PLATFORM.finditer(code)}
        if modules:
            out[f] = (import_kind(f, nested), modules)
    return out


def scheme_repos(eco):
    """The main scheme's repositories, from ecosystem.py's list of them."""
    path = os.path.join(eco, "scheme-main.tsv")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return [line.split("\t")[0] for line in f if line.strip() and not line.startswith("#")]


def import_cell(files, kind):
    """`n (Darwin a, Glibc b)` for one kind of a repository's files."""
    of_kind = [mods for k, mods in files.values() if k == kind]
    if not of_kind:
        return "—"
    counts = collections.Counter(m for mods in of_kind for m in mods)
    return f"{len(of_kind)} (" + ", ".join(f"{m} {counts[m]}" for m in PLATFORM_MODULES if counts[m]) + ")"


# ---------------------------------------------------------------- copies from the packages' reports

LEADING_INT = re.compile(r"^\s*\**\s*(\d[\d,]*)")


def md_tables(lines):
    """(header index, header cells, [(index, cells)]) for each table."""
    out, i = [], 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            header = cells(lines[i])
            body, j = [], i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                body.append((j, cells(lines[j])))
                j += 1
            out.append((i, header, body))
            i = j
            continue
        i += 1
    return out


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def leading_int(text):
    m = LEADING_INT.match(text or "")
    return int(m.group(1).replace(",", "")) if m else None


def copied_reexports(text):
    """(start, now, [(index, line)]) from a MIGRATION.md's tables: rows
    labeled as reaching Darwin through a re-export in an `| | start | now |`
    table (summed), or else a column labeled that way (its first and last
    rows). Rows that count re-exports *among* others ("incl.") don't count."""
    lines = text.split("\n")
    tables = md_tables(lines)
    start = now = None
    quoted = []
    for hi, header, body in tables:
        if len(header) != 3:
            continue
        for bi, row in body:
            label = row[0].lower()
            if "re-export" in label and "darwin" in label and "incl." not in label and len(row) >= 3:
                a, b = leading_int(row[1]), leading_int(row[2])
                if a is None or b is None:
                    continue
                start, now = (start or 0) + a, (now or 0) + b
                if (hi, lines[hi]) not in quoted:
                    quoted.append((hi, lines[hi]))
                quoted.append((bi, lines[bi]))
    if quoted:
        return start, now, quoted
    for hi, header, body in tables:
        cols = [k for k, h in enumerate(header) if "through a re-export" in h.lower()]
        if not cols or len(body) < 1:
            continue
        k = cols[0]
        first, last = body[0], body[-1]
        a = leading_int(first[1][k]) if k < len(first[1]) else None
        b = leading_int(last[1][k]) if k < len(last[1]) else None
        if a is None or b is None:
            continue
        return a, b, [(hi, lines[hi]), (first[0], lines[first[0]]), (last[0], lines[last[0]])]
    return None


# A test total: "572 tests in 57 suites, all passed", "358 tests, 0 failures",
# "2454 run, 43 skipped"; not "4 tests, 3 other" (a count of test files).
TEST_COUNT = re.compile(r"\b\d[\d,]*\s+(?:tests?\b[^|]*?\b(?:pass\w*|fail\w*|suites?|skipped)|run\b)")
START_WORDS = re.compile(r"\b(before|baseline|at start|at the start|unmodified|start)\b", re.I)
NOW_WORDS = re.compile(r"\b(after|now|done|every step|final)\b", re.I)


def copied_tests(text):
    """[(index, line)] from a report: the line (or table row) giving the
    test totals at the start, and the latest one; a table row comes with its
    header."""
    lines = text.split("\n")
    hits = [i for i, line in enumerate(lines) if TEST_COUNT.search(line)
            and (line.lstrip().startswith(("|", "-", "*")) or "Tests" in line[:40])]
    if not hits:
        return []
    header_of = {}
    for hi, header, body in md_tables(lines):
        for bi, _ in body:
            header_of[bi] = hi

    def label(i):
        line = lines[i].strip()
        return cells(line)[0] if line.startswith("|") else line[:60]

    both = [i for i in hits if i in header_of and START_WORDS.search(lines[header_of[i]])
            and NOW_WORDS.search(lines[header_of[i]])]
    if both:
        chosen = [both[0]]
    else:
        start = next((i for i in hits if START_WORDS.search(label(i))), hits[0])
        now = next((i for i in reversed(hits) if NOW_WORDS.search(label(i)) and i != start), None)
        if now is None:
            now = hits[-1] if hits[-1] != start else None
        chosen = [start] + ([now] if now is not None else [])
    out = []
    for i in chosen:
        if i in header_of and (header_of[i], lines[header_of[i]]) not in out:
            out.append((header_of[i], lines[header_of[i]]))
        out.append((i, lines[i]))
        # the rest of a wrapped bullet or paragraph
        j = i + 1
        while i not in header_of and j < len(lines) and j - i <= 3 and lines[j].strip() and \
                not lines[j].lstrip().startswith(("|", "- ", "* ", "#")) and (j, lines[j]) not in out:
            out.append((j, lines[j]))
            j += 1
    return out


# ---------------------------------------------------------------- the report

def code_block(lines):
    fence = "~~~~" if any("```" in text for _, text in lines) else "```"
    return "\n".join([fence + "text"] + lines_text(lines) + [fence])


def lines_text(lines):
    return [text for _, text in lines]


def short(c):
    return c[:8] if c else "—"


def shown(iface):
    """An interface as the tables show it: a C name in code voice, a phrase as text."""
    return f"`{iface}`" if WORD.match(iface.replace(" members", "")) else cell(iface)


def cell(text):
    return text.replace("|", "\\|")


def marker_cell(markers, files):
    return f"{markers} ({files})"


def arrow(before, after):
    return f"{before} → {after}" if before != after else f"{after}"


def api_section(api_dir):
    path = os.path.join(api_dir, "API-DELTA.md")
    with open(path) as f:
        report = f.read().split("\n")
    start = next(i for i, line in enumerate(report) if line.startswith("## Summary"))
    end = next(i for i, line in enumerate(report) if i > start and line.startswith("### By source file"))
    with open(os.path.join(api_dir, "api-delta.json")) as f:
        meta = json.load(f)["meta"]
    return meta, "\n".join(report[start:end]).rstrip()


def platform_section(w, a, packages):
    """Section 4, the platform imports of the main scheme's repositories;
    returns how many were read."""
    w("# 4. Platform imports")
    w("")
    repos = scheme_repos(a.ecosystem) if a.ecosystem else None
    if repos is None:
        w("No ecosystem checkout with a `scheme-main.tsv` was given (`STATUS_ECOSYSTEM`), so nothing was counted.")
        w("")
        return 0
    adopters = {p["name"]: p for p in packages}
    eco = os.path.relpath(a.ecosystem, a.repo)
    left_out = [r for r in repos if r in NOT_TRACKED]
    w("The goal: no library of the repositories that swift's update-checkout clones for the main scheme imports a "
      "platform C module (" + ", ".join(PLATFORM_MODULES) + ") in any form, on any platform. Each repository is "
      f"read at its migrated clone in `{os.path.relpath(a.adopters, a.repo)}`, on its migration branch (as in "
      f"*Adopters* above), else at its clone in `{eco}` as it is, else it's *not cloned*. Left out: " +
      "; ".join(f"{r} ({NOT_TRACKED[r]})" for r in left_out) + ". Each cell is the number of Swift files of that "
      "kind that import any of the modules, then how many import each; a file under `#if` branches for several "
      "platforms counts once per module. Kinds are by path (see [How this is computed](#how-this-is-computed)): "
      "*library* is under `Sources` (or `src`, `lib`, `products`), *tests* under a test directory, *other* the "
      "rest (benchmarks, examples, tools, plugins, docs, utilities), and a *nested package* is under a "
      "directory with its own `Package.swift`.")
    w("")
    w("| Repository | Read at | Library | Tests | Other | Nested packages | Files |")
    w("|---|---|---|---|---|---|---:|")
    totals = {k: collections.Counter() for k in IMPORT_KINDS}
    any_files = collections.Counter()
    read, with_library = 0, []
    for r in repos:
        if r in NOT_TRACKED:
            continue
        p = adopters.get(ADOPTER_DIRS.get(r, r))
        clone = os.path.join(a.ecosystem, r)
        if p:
            where = f"`{os.path.relpath(p['path'], a.repo)}` `{p['branch']}` @ `{short(p['tip'])}`"
            files = platform_imports(p["path"], p["tip"])
        elif os.path.exists(os.path.join(clone, ".git")) and commit_of(clone, "HEAD"):
            commit = commit_of(clone, "HEAD")
            where = f"`{os.path.relpath(clone, a.repo)}` @ `{short(commit)}`"
            files = platform_imports(clone, commit)
        else:
            w(f"| {r} | not cloned | | | | | |")
            continue
        read += 1
        for kind, mods in files.values():
            any_files[kind] += 1
            totals[kind].update(mods)
        if any(kind == "library" for kind, _ in files.values()):
            with_library.append(r)
        cells = " | ".join(import_cell(files, k) for k in IMPORT_KINDS)
        w(f"| {r} | {where} | {cells} | {len(files)} |")
    w("")
    w(f"{read} repositories read; {len(with_library)} import a platform module in library code"
      + (": " + ", ".join(with_library) if with_library else "") + ".")
    w("")
    w("All repositories, files by module and kind:")
    w("")
    w("| Module | Library | Tests | Other | Nested packages | All |")
    w("|---|---:|---:|---:|---:|---:|")
    for m in PLATFORM_MODULES:
        counts = [totals[k][m] for k in IMPORT_KINDS]
        w(f"| {m} | " + " | ".join(str(c) for c in counts) + f" | {sum(counts)} |")
    counts = [any_files[k] for k in IMPORT_KINDS]
    w("| **Any** | " + " | ".join(str(c) for c in counts) + f" | {sum(counts)} |")
    w("")
    return read


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--adopters", required=True)
    ap.add_argument("--api-delta", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--branch", default="migrate-darwin")
    ap.add_argument("--branch-for", action="append", default=[], metavar="PACKAGE=BRANCH",
                    help="a package's migration branch, where it isn't --branch")
    ap.add_argument("--ecosystem", help="the ecosystem's clones and scheme-main.tsv, for the platform imports")
    ap.add_argument("--base", default="main")
    ap.add_argument("--system-next", default="system-next")
    ap.add_argument("--vocab")
    ap.add_argument("--cache", required=True)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--dump-markers", action="store_true", help="print each marker's interfaces and stop")
    a = ap.parse_args()

    vocab = load_vocab(a.vocab)
    branch_for = dict(x.split("=", 1) for x in a.branch_for)
    head = commit_of(a.repo, "HEAD")
    branch = git(a.repo, "rev-parse", "--abbrev-ref", "HEAD").strip()
    nxt = commit_of(a.repo, a.system_next)
    sys_head = SystemNames(a.repo, head)
    sys_next = SystemNames(a.repo, nxt) if nxt and nxt != head else sys_head
    answers = outside_answers(a.repo, head, a.cache)
    dirty = git(a.repo, "status", "--porcelain", "--", *SYSTEM_SOURCES, "Package.swift").strip()
    dirty_mapping = git(a.repo, "status", "--porcelain", "--", MAPPING).strip()

    # The packages: each git checkout in the adopters directory with the branch.
    packages = []
    for d in sorted(os.listdir(a.adopters)):
        path = os.path.join(a.adopters, d)
        if not os.path.isdir(path):
            continue
        top = subprocess.run(["git", "-C", path, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if top.returncode != 0 or os.path.realpath(top.stdout.strip()) != os.path.realpath(path):
            continue
        pkg_branch = branch_for.get(d, a.branch)
        tip = commit_of(path, pkg_branch)
        if not tip:
            continue
        base_ref = a.base if commit_of(path, a.base) else f"origin/{a.base}"
        base = git(path, "merge-base", tip, base_ref, ok=(0, 1)).strip() or None
        packages.append({"name": d, "path": path, "branch": pkg_branch, "tip": tip, "base": base,
                         "base_ref": base_ref, "dirty": bool(git(path, "status", "--porcelain", "-uno").strip())})

    for p in packages:
        p["now"] = Snapshot(p["path"], p["tip"], a.cache, p["name"])
        p["then"] = Snapshot(p["path"], p["base"], a.cache, p["name"]) if p["base"] and p["base"] != p["tip"] else p["now"]
        docs = read_blobs(p["path"], [f"{p['tip']}:MIGRATION.md", f"{p['tip']}:REPORT.md"])
        p["migration"] = docs.get(f"{p['tip']}:MIGRATION.md")
        p["report"] = docs.get(f"{p['tip']}:REPORT.md")

    if a.dump_markers:
        for p in packages:
            for f, line, body, imported, _ in p["now"].markers:
                print(f"{p['name']}:{f}:{line}: {body[:150]}")
                for iface, phrase, names in marker_interfaces(body, imported):
                    print(f"    -> {iface!r} [{family_of(iface, phrase, vocab)}]" +
                          (f" via {len(names)} imports" if names != [iface] else ""))
        return

    meta, api_text = api_section(a.api_delta)
    out = []
    w = out.append
    w("# Status: System's API and its adopters")
    w("")
    w(f"Generated {a.date} by `Utilities/adopter-coverage/status.sh`, from commits only; rerun it rather than "
      "editing this file. How each figure is made, and what it can't see, is in "
      "[How this is computed](#how-this-is-computed).")
    w("")
    contains = "contains" if nxt and subprocess.run(["git", "-C", a.repo, "merge-base", "--is-ancestor", nxt, head]
                                                    ).returncode == 0 else "doesn't contain"
    ahead = git(a.repo, "rev-list", "--count", f"{nxt}..{head}").strip() if nxt else "?"
    w(f"- **System**: `{branch}` @ `{short(head)}` ({cell(subject(a.repo, head))}), which {contains} "
      f"`{a.system_next}` @ `{short(nxt)}` ({cell(subject(a.repo, nxt)) if nxt else '—'}); {ahead} commit(s) "
      f"of `{branch}` aren't in `{a.system_next}`.")
    if dirty:
        w("  Uncommitted changes to System's sources aren't counted.")
    if dirty_mapping:
        w("  Uncommitted changes to mapping.ini aren't counted.")
    w(f"- **API delta**: `{meta['baseRef']}` @ `{short(meta['baseCommit'])}` → `{meta['headRef']}` @ "
      f"`{short(meta['headCommit'])}`" + (" (api-delta's last run; nothing it reads has changed since)"
                                         if meta["headCommit"] != head else "") + ".")
    w(f"- **Adopters** (`{os.path.relpath(a.adopters, a.repo)}`, branch `{a.branch}`, against its merge base "
      f"with `{a.base}`):")
    for p in packages:
        note = " (uncommitted changes in the checkout aren't counted)" if p["dirty"] else ""
        same = " (no commits beyond the merge base yet)" if p["base"] == p["tip"] else ""
        other = f" (branch `{p['branch']}`)" if p["branch"] != a.branch else ""
        w(f"  - {p['name']} @ `{short(p['tip'])}`{other}, base `{short(p['base'])}`{same}{note}")
    w("")

    # ---- 1. API
    w("# 1. API")
    w("")
    w(f"Copied verbatim from `Utilities/api-delta/regenerate.sh` (`BASE_REF={meta['baseRef']}`, "
      f"`HEAD_REF={meta['headRef']}`); its links point into that run's API-DELTA.md.")
    w("")
    w(api_text)
    w("")

    # ---- 2. Adoption
    w("# 2. Adoption")
    w("")
    w("Swift files of each package's own targets (from its manifest; not nested packages, benchmarks, or "
      "integration-test scaffolding), counted at the merge base → now, by the broadest Darwin import the macOS "
      "package build compiles in each. *Whole module*: `import Darwin`. *Submodule*: `import Darwin.C` or "
      "`import Darwin.POSIX.sys.stat`. *Scoped only*: every Darwin import names one declaration "
      "(`import func Darwin.usleep`). *Framework only*: its Darwin imports are all under "
      "`#if FOUNDATION_FRAMEWORK`, which the package never builds; they're in no other column. "
      "*Through a re-export*: copied from the package's MIGRATION.md where it gives the number (start → now), "
      "else —. *Markers*: `SYSTEM-GAP:` comments in the targets' sources, and the files that have them.")
    w("")
    kinds = ("whole", "submodule", "scoped", "framework")
    w("| Package | Swift files | Whole module | Submodule | Scoped only | Framework only | "
      "Through a re-export (copied) | Markers (files) |")
    w("|---|---:|---:|---:|---:|---:|---:|---:|")
    totals = collections.Counter()
    notes = []
    for p in packages:
        now, then = p["now"], p["then"]
        rex = copied_reexports(p["migration"]) if p["migration"] else None
        p["reexports"] = rex
        m_now, f_now = now.marker_count()
        m_then, f_then = then.marker_count()
        counts = " | ".join(arrow(len(then.imports[k]), len(now.imports[k])) for k in kinds)
        rex_cell = arrow(rex[0], rex[1]) if rex else "—"
        w(f"| {p['name']} | {now.swift_files} | {counts} | {rex_cell} | "
          f"{arrow(marker_cell(m_then, f_then), marker_cell(m_now, f_now))} |")
        totals["files"] += now.swift_files
        for k in kinds:
            totals[k + "0"] += len(then.imports[k])
            totals[k] += len(now.imports[k])
        totals["m0"] += m_then
        totals["f0"] += f_then
        totals["m"] += m_now
        totals["f"] += f_now
        for snap, when in ((then, "base"), (now, "now")):
            if snap.manifest_error:
                notes.append(f"{p['name']} ({when}): the manifest didn't evaluate ({snap.manifest_error}); "
                             "counted Sources/ and Tests/ instead.")
    counts = " | ".join(arrow(totals[k + "0"], totals[k]) for k in kinds)
    w(f"| **All** | {totals['files']} | {counts} | | "
      f"{arrow(marker_cell(totals['m0'], totals['f0']), marker_cell(totals['m'], totals['f']))} |")
    w("")
    for n in notes:
        w(f"- {n}")
    if notes:
        w("")
    outside = [(p["name"], m) for p in packages for m in p["now"].markers if not m[4]]
    if outside:
        w(f"{len(outside)} more marker(s) are in files outside the targets (they're in the gaps below): " +
          ", ".join(sorted({f'{n}: `{m[0].split("/")[0]}/`' for n, m in outside})) + ".")
        w("")
    left = [(p["name"], f, k) for p in packages for k in ("whole", "submodule") for f in sorted(p["now"].imports[k])]
    if left:
        w("Files whose imports aren't narrow yet: " +
          ", ".join(f"{n}: `{f}` ({'whole module' if k == 'whole' else 'submodule'})" for n, f, k in left) + ".")
        w("")
    w("## Copied from the packages' reports")
    w("")
    w("Verbatim, not rerun: each package's own test totals (at the start, and the latest it reports), and the "
      "rows behind the re-export column. Line numbers are 1-based, in the file at the package's commit above.")
    w("")
    for p in packages:
        w(f"**{p['name']}**")
        w("")
        blocks = []
        if p["migration"]:
            t = copied_tests(p["migration"])
            if t:
                blocks.append(("MIGRATION.md, tests", t))
            if p["reexports"]:
                blocks.append(("MIGRATION.md, re-exports", p["reexports"][2]))
        if p["report"]:
            t = copied_tests(p["report"])
            if t:
                blocks.append(("REPORT.md, tests", t[-2:] if len(t) > 1 else t))
        if not blocks:
            w("- No MIGRATION.md or REPORT.md with test totals at this commit.")
            w("")
            continue
        for title, lines in blocks:
            w(f"- {title} (lines {', '.join(str(i + 1) for i, _ in lines)}):")
            w("")
            w("\n".join("  " + x for x in code_block(lines).split("\n")))
            w("")

    # ---- 3. Gaps
    gaps = collections.OrderedDict()   # interface -> dict
    unread = []
    for p in packages:
        for f, line, body, imported, in_targets in p["now"].markers:
            for iface, phrase, names in marker_interfaces(body, imported):
                g = gaps.setdefault(iface, {"names": set(), "phrase": phrase, "files": set(), "where": []})
                g["names"].update(names)
                g["files"].add((p["name"], f))
                g["where"].append((p["name"], f, line, in_targets))
                if not g["phrase"] and phrase:
                    g["phrase"] = phrase
                if iface == phrase and not names:
                    unread.append((p["name"], f, line, body))

    def status(iface, g):
        names = sorted(g["names"])
        if not names:
            # Only an ANSWERED entry can speak for a phrase.
            answered, how = sys_head.covers(iface)
            if answered and how.startswith("by "):
                late = not sys_next.covers(iface)[0]
                return "covered", how + (f"; not yet in `{a.system_next}`" if late else "")
            return "unread", ""
        covered = [n for n in names if sys_head.covers(n)[0]]
        if len(covered) == len(names):
            late = [n for n in names if not sys_next.covers(n)[0]]
            how = sys_head.covers(names[0])[1] if len(names) == 1 else f"all {len(names)} names"
            return "covered", how + (f"; not yet in `{a.system_next}`" if late else "")
        # Names System doesn't name at all may have an answer outside it;
        # when every one has, the interface takes the first kind among them.
        rest = [n for n in names if n not in covered]
        found = [outside_answer(n, answers) for n in rest] if all(sys_head.unnamed(n) for n in rest) else []
        if found and all(found):
            kind = next(k for k in OUTSIDE if any(f[0] == k for f in found))
            how = "; ".join(dict.fromkeys(f[1] for f in found if f[0] == kind))
            return kind, how + (f"; {len(covered)} of {len(names)} names covered by System" if covered else "")
        if covered:
            return "missing", f"{len(covered)} of {len(names)} names covered"
        asks = [how for how in (sys_head.covers(n)[1] for n in names) if how.startswith("named, but")]
        return "missing", asks[0] if asks else ""

    rows = []
    for iface, g in gaps.items():
        st, how = status(iface, g)
        pkgs = {n for n, _ in g["files"]}
        # A covered interface keeps its own family: memcmp is System's Memory's,
        # not a provisional string.h wrapper; so does one answered outside
        # System. A phrase takes its names' family, when they share one.
        provisional = st not in ("covered",) + OUTSIDE
        if iface != g["phrase"]:
            fam = family_of(iface, g["phrase"], vocab, provisional=provisional)
        else:
            shared = {family_of(n, None, vocab, provisional=provisional) for n in g["names"]}
            fam = shared.pop() if len(shared) == 1 and not (shared & set(g["names"])) else g["phrase"]
        rows.append((len(g["files"]), len(pkgs), iface, fam, st, how, sorted(pkgs), g))
    rows.sort(key=lambda r: (-r[0], -r[1], r[2].lower()))

    w("# 3. Gaps")
    w("")
    n_markers = sum(len(p["now"].markers) for p in packages)
    n_files = len({(p["name"], m[0]) for p in packages for m in p["now"].markers})
    w(f"Every `SYSTEM-GAP:` marker in the packages' sources at the commits above: {n_markers} markers in "
      f"{n_files} files, of which {len(outside)} are outside the packages' targets. Each marker's text is read "
      "for the C interfaces it names (see [How this is computed](#how-this-is-computed)); a marker that names "
      "none is counted under its phrase, with the Darwin names imported under it deciding its status. "
      f"Status is against System at `{short(head)}`:")
    w("")
    w("- **missing**: System documents none of it (or only some: *k of n*), and `mapping.ini` has no answer "
      "outside System for it.")
    w("- **covered**: a System declaration's doc comment names it as the corresponding C interface, a CInterop "
      "alias names it, or, for `X members`, System gives `CInterop` alias of `X` Swift-named accessors. The "
      "marker is stale, or the package hasn't adopted the API yet." +
      (f" *Not yet in `{a.system_next}`* means only this branch has it." if sys_next is not sys_head else ""))
    w("- **unread**: the marker names no C interface, nothing is imported under it, and no `ANSWERED` entry "
      "speaks for it; read the marker.")
    w("- **standard library**: System doesn't name it, and its entry in `mapping.ini` gives the standard "
      "library's answer (`swift`), shown with the entry's name.")
    w("- **not System's**: System doesn't name it, and its entry in `mapping.ini` is marked `wrap = no`: another "
      "module's or library's interface, such as the MachO module's file format, which System doesn't wrap.")
    w("")
    w("The last two are answers outside System, read from `mapping.ini` at System's commit as the Darwin queue of "
      "`ecosystem.sh report` reads them; they aren't in the work list below.")
    w("")
    counts = collections.Counter(r[4] for r in rows)
    w("A family marked *(provisional)* is a C-library layer above the OS (math, stdio, locales, string.h and "
      "ctype.h) that System wraps provisionally, in `Sources/System/Provisional/`, since it may move to the "
      "standard library; it counts like everything else.")
    w("")
    w("Interfaces: " + ", ".join(f"{counts[k]} {k}" for k in ("missing", "covered", "unread") + OUTSIDE
                                 if counts[k]) + f", {len(rows)} in all.")
    w("")
    w("| # | Interface | Status | Files | Packages | Family |")
    w("|---:|---|---|---:|---|---|")
    for k, (nf, npk, iface, fam, st, how, pkgs, g) in enumerate(rows, 1):
        st_cell = st + (f" ({cell(how)})" if how else "")
        w(f"| {k} | {shown(iface)} | {st_cell} | {nf} | {', '.join(pkgs)} | {cell(fam)} |")
    w("")

    # The work list: missing interfaces by family, largest first.
    fams = collections.OrderedDict()
    for nf, npk, iface, fam, st, how, pkgs, g in rows:
        if st != "missing":
            continue
        e = fams.setdefault(fam, {"ifaces": [], "files": set(), "pkgs": set()})
        e["ifaces"].append(iface)
        e["files"] |= g["files"]
        e["pkgs"] |= set(pkgs)
    ranked = sorted(fams.items(), key=lambda kv: (-len(kv[1]["files"]), -len(kv[1]["pkgs"]), kv[0].lower()))
    w("## Missing, by family")
    w("")
    w("The missing interfaces above, grouped, largest first: the order to fill them in.")
    w("")
    w("| # | Family | Files | Packages | Interfaces |")
    w("|---:|---|---:|---|---|")
    for k, (fam, e) in enumerate(ranked, 1):
        names = ", ".join(shown(i) for i in e["ifaces"])
        w(f"| {k} | {cell(fam)} | {len(e['files'])} | {', '.join(sorted(e['pkgs']))} | {names} |")
    w("")

    if unread:
        w("## Markers that name no C interface")
        w("")
        for n, f, line, body in unread:
            w(f"- {n}: `{f}:{line}`: {cell(body[:200])}")
        w("")

    w("## Where")
    w("")
    w("<details><summary>Each interface's markers (package: file:line)</summary>")
    w("")
    for nf, npk, iface, fam, st, how, pkgs, g in rows:
        where = "; ".join(f"{n}: `{f}:{line}`" + ("" if inside else " (outside the targets)")
                          for n, f, line, inside in g["where"])
        w(f"- {shown(iface)} ({st}): {where}")
    w("")
    w("</details>")
    w("")

    # ---- 4. Platform imports
    tracked = platform_section(w, a, packages)

    w("# How this is computed")
    w("")
    w(METHOD.strip())
    w("")

    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w") as f:
        f.write("\n".join(out))
    print(f"status: wrote {a.out}: {len(packages)} packages, {n_markers} markers, {len(rows)} interfaces, "
          f"{tracked} repositories' platform imports "
          f"({', '.join(f'{counts[k]} {k}' for k in counts)})")


METHOD = """
`Utilities/adopter-coverage/status.sh` makes this file from commits, with git and the existing tools, and no
reading of reports for meaning. It takes about as long as api-delta when System's sources have changed since
api-delta's last run, and a few seconds when they haven't.

- **API** is api-delta's own report (`BASE_REF=main HEAD_REF=HEAD`), its Summary and *By area* table copied
  verbatim. api-delta reruns only when `Sources/`, `Package.swift` or the tool changed since its last run.
- **Package targets** come from `swift package dump-package` on the package's manifests at each commit, cached
  by the manifests' blob ids, with SwiftPM's default paths (`Sources/<target>`, `Tests/<target>`) where a
  target gives none, and its `sources` and `exclude`. A manifest that doesn't evaluate falls back to
  `Sources/` and `Tests/`, and the Adoption section says so. Rejected: counting every file in the repository,
  which mixes in nested packages (Benchmarks, SwiftParserCLI) and scaffolding the package doesn't build.
- **Darwin imports** are read from each file with comments and strings blanked (api-delta's blanker), and
  each `#if` evaluated for macOS by adopter-coverage's `platforms.py`, with FOUNDATION_FRAMEWORK false for the
  package's counts and true for the *framework only* count. An unknown flag counts as maybe, so a line it
  guards is counted. `import Darwin.POSIX.sys.stat` counts as whole: a submodule import isn't scoped to one
  declaration. Rejected: adopter-coverage's compiler-backed Darwin metric (`check.sh`), which needs a build
  of every package commit (a minute or more each, and only for the four audited packages), where this needs
  only git.
- **Copied figures** (test totals, files reaching Darwin through a re-export) are lines of the package's
  MIGRATION.md or REPORT.md at its commit, quoted with their line numbers: the table rows or bullets with a
  test count that are labeled as the start and as the latest, and the rows labeled as reaching Darwin through
  a re-export in a start/now table (or a column so labeled). A package whose reports don't match these
  patterns shows —, never a guess.
- **Markers** are `SYSTEM-GAP:` in a comment of a Swift or C source. Its text continues onto the next comment
  lines while a parenthesis is open or it ends mid-list. Its head is the text before the first sentence
  end, semicolon or dash, and before a colon unless a list follows the colon (`vsock: sockaddr_vm, AF_VSOCK`).
  The head is split into items at commas and *and*/*or*, and an item names:
  - itself, when it's one identifier (`getenv(3)`, `O_SEARCH`, `struct ifaddrs`), plus the names in an
    attached or following list (`confstr(_CS_DARWIN_USER_TEMP_DIR)`, `strftime (tm, time_t)`), except after
    a Swift type (`POSIXErrorCode (ENAMETOOLONG)` names POSIXErrorCode);
  - the names in its parenthesized list, for a phrase (`libm (sin, cos, pow)`, `the C heap (calloc,
    malloc, free)`); the phrase becomes their family;
  - `X members`, for `members of X`, `X members`, `X fields`, `X's field`, and every name in a *members of
    System-vended C structs* list: what's missing is the struct's fields, not its name, which CInterop has;
  - the name before generic nouns (`IPV6_* socket options`, `copyfile(3) flags`) or after a header
    (`string.h memcmp`), and the possessed name after a library (`libmalloc's malloc_good_size`).
  A marker can also trail the import it's for (`import func Darwin.fopen  // SYSTEM-GAP: C stdio`).
  A wildcard (`IP_*`, `DT_*`) becomes the names imported under the marker that match it. A marker whose head
  names nothing (`posix_spawn's raw attributes and file actions`) is counted under its phrase, and the scoped
  Darwin imports right under it (the file's own list of what the gap costs) decide its status; with none, it
  is *unread*, unless an `ANSWERED` entry matches its phrase. Rejected: recognizing names by an SDK vocabulary alone, since the explanations are English
  and `time`, `free`, `sleep` and `remove` are C functions; and taking the imports as the interfaces
  everywhere, since `import struct Darwin.msghdr` is there for msghdr's fields, not for the name CInterop
  already has.
- **Covered** means System's library modules (`Sources/System`, `Sources/SystemSockets`, not the samples) name
  the interface in a doc comment's *The corresponding C … is* sentence, or a public typealias targets it, or, for
  `X members`, an `extension CInterop.<alias of X>` exists. A few interfaces count as covered by the replacement
  System wraps instead (`EQUIVALENTS` in `scripts/status.py`: usleep and sleep by nanosleep, localtime and gmtime
  by their `_r` forms, mkstemp and mkstemps by mkostemp(s), time and gettimeofday by clock_gettime), and the table
  says so. A family that System answers with a design of its own, rather than a wrapper, counts as covered once a
  witness in System's sources shows the answer has what the markers ask for (`ANSWERED`: fts is DirectoryWalk, with
  its two-visit order, `malloc_type_descriptor_v0_t`'s members are `Memory.TypeDescriptor`'s properties, and
  Subprocess's raw posix_spawn path, a marker that names no C interface, is `ProcessID.spawn`'s C-values and
  credentials forms). The other way round, an interface that System's docs name counts as missing while the
  markers ask for more than the naming API gives, until a witness shows the ask is met (`STILL_NEEDED`: struct
  dirent needs a public name with accessors, dlerror a call that takes the pending error, and addchdir_np a way to
  add an action to C file actions that other code built). This sees what System documents, not whether the API
  fits the adopter's use: a partial wrapper counts as covered, and an API whose doc comments don't name the C
  interface counts as missing.
- **Answers outside System** come from `mapping.ini` at System's commit, and only for names System doesn't name at
  all (not for one it names while a marker asks for more): a name in an entry with a `swift` answer is *standard
  library*, and a name in an entry marked `wrap = no` is *not System's*, the `swift` answer first, as the Darwin
  queue of `ecosystem.sh report` decides them. `X members` takes X's entry. An interface whose uncovered names all
  have an answer takes the first kind among them, and the table gives the entries. Such interfaces aren't in the
  work list; *covered* is still only what System's sources document, and a `status` in mapping.ini changes nothing
  here. Rejected: counting them as covered, which would say System has what it doesn't; and leaving them missing,
  which kept the MachO module's file format and the standard library's answers in the work list for good.
- **Provisional families** (libm, C stdio, locale and xlocale, string.h and ctype.h, numeric conversion) are a
  fixed list in `scripts/status.py`, matched by name or by the name's SDK module in adopter-coverage's stored
  vocabulary when there is one. They're C-library layers above the OS that System wraps provisionally, in
  `Sources/System/Provisional/`, and they count as missing until covered, like everything else; the family
  only groups them in the work list.
- **Families** group the ranked interfaces for the work list: the provisional families, then a fixed map of
  name patterns to System's clusters, else the marker's phrase, else the name itself.
- **Platform imports** (section 4) are lexical, like ecosystem.py's survey: each Swift file, with comments and
  string literals blanked, is matched against the survey's import pattern (`import_of` in `scripts/ecosystem.py`),
  widened to Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT and visualc, in every form: the whole
  module, a submodule, one declaration, with `@_exported` or another attribute, and with an access modifier. It
  doesn't evaluate `#if`: an import under `#if os(Linux)` counts as Glibc's, since the goal is none on any
  platform. Each repository of `scheme-main.tsv` is read at a commit: its migrated clone's migration branch (the
  adopters' branch, or its `--branch-for` override: swift-foundation's `no-darwin`), else the ecosystem clone's
  HEAD. A file's kind is by its path: in a nested package if a directory above it, below the root, has a
  `Package.swift`; else tests if a directory in its path is a test directory (`Tests`, `IntegrationTests`,
  `Fixtures`, `unittests` and the like); else library under a top-level `Sources`, `Source`, `src`, `srcs`, `lib`
  or `products`, outside a `.docc` catalog; else other. Rejected: the manifests' targets, as the Adoption section
  uses them, which needs every clone's manifest evaluated (swift-foundation's needs a newer compiler than 6.2)
  and says nothing of nested packages; and platforms.py's `#if` evaluation, which answers what one platform's
  build compiles, not whether any does.
"""


if __name__ == "__main__":
    main()
