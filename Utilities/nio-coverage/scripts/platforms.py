#!/usr/bin/env python3
"""Platform environments and a three-valued `#if` evaluator for NIO's Swift
and C sources.

Each line of a source file is active on a platform (T), inactive (F), or
active only in some configurations of it (M, "maybe"): opt-in flags such as
SWIFTNIO_USE_IO_URING, debug-only code, a secondary architecture, or a C
macro whose value depends on the SDK headers. M lines count as active, and
the report names the conditions that made them M.

Two environments per platform would be overkill, except on Darwin: the
index store comes from one concrete build (macOS, arm64, debug, Swift 6.2),
so `darwin_build` evaluates to T/F with no M, and says which lines the
compiler saw.
"""

import re

PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
T, F, M = "T", "F", "M"

COMPILER_VERSION = (6, 2)

# canImport() answers per platform. Darwin means macOS. FreeBSD and OpenBSD
# import the libc overlay named Glibc. `Bionic` is the older name of
# Android's libc module; NIO tests it alongside `Android`.
SWIFT_ENV = {
    "Darwin":  {"os": {"macOS"}, "import": {"Darwin", "Dispatch", "Foundation", "System", "ObjectiveC", "os"},
                "arch": {"arm64", "x86_64"}},
    "Linux":   {"os": {"Linux"}, "import": {"Glibc", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"x86_64", "arm64", "arm", "i386"}},
    "Musl":    {"os": {"Linux"}, "import": {"Musl", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"x86_64", "arm64"}},
    "Android": {"os": {"Android"}, "import": {"Android", "Bionic", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"arm64", "x86_64", "arm", "i386"}},
    "FreeBSD": {"os": {"FreeBSD"}, "import": {"Glibc", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"x86_64", "arm64"}},
    "OpenBSD": {"os": {"OpenBSD"}, "import": {"Glibc", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"x86_64", "arm64"}},
    "WASI":    {"os": {"WASI"}, "import": {"WASILibc", "Foundation", "FoundationEssentials"},
                "arch": {"wasm32"}},
    "Windows": {"os": {"Windows"}, "import": {"WinSDK", "ucrt", "Dispatch", "Foundation", "FoundationEssentials"},
                "arch": {"x86_64", "arm64"}},
}
DARWIN_BUILD = {"os": {"macOS"}, "import": SWIFT_ENV["Darwin"]["import"], "arch": {"arm64"}}

# Flags that are M everywhere: opt-in or debug-only code. The Darwin build
# is a debug build, so DEBUG and ENABLE_MOCKING (NIOFS defines it in debug)
# are T there.
DEBUG_FLAGS = {"DEBUG", "ENABLE_MOCKING"}

POINTER_32 = {"arm", "i386", "arm64_32", "wasm32"}


def _tri_not(v):
    return {T: F, F: T, M: M}[v]


def _tri_and(a, b):
    if a == F or b == F:
        return F
    if a == T and b == T:
        return T
    return M


def _tri_or(a, b):
    if a == T or b == T:
        return T
    if a == F and b == F:
        return F
    return M


def _version_cmp(arg, have):
    m = re.match(r"(>=|<)\s*([\d.]+)$", arg.replace(" ", ""))
    if not m:
        raise ValueError(f"can't read version condition {arg!r}")
    want = tuple(int(x) for x in m.group(2).split("."))
    ok = have >= want
    return T if (ok if m.group(1) == ">=" else not ok) else F


def swift_atom(tok, env, build):
    """Value of one Swift compilation-condition atom."""
    m = re.match(r"(\w+)\((.*)\)$", tok, re.S)
    if m:
        fn, arg = m.group(1), m.group(2).strip()
        if fn == "os":
            return T if arg in env["os"] else F
        if fn == "canImport":
            name = arg.split(",")[0].strip()
            return T if name in env["import"] else F
        if fn in ("compiler", "swift"):
            return _version_cmp(arg, COMPILER_VERSION)
        if fn == "arch":
            if arg not in env["arch"]:
                return F
            return T if len(env["arch"]) == 1 else M
        if fn == "_runtime":
            if arg == "_multithreaded":
                return F if "WASI" in env["os"] else T
            if arg == "_ObjC":
                return T if "macOS" in env["os"] else F
            return M
        if fn == "_pointerBitWidth":
            if env["arch"] <= POINTER_32:
                return T if arg == "_32" else F
            if env["arch"] & POINTER_32:
                return M
            return T if arg == "_64" else F
        if fn == "targetEnvironment":
            return F
        if fn in ("hasFeature", "hasAttribute"):
            return T
        return M
    if tok.startswith("$"):
        return T
    if tok == "true":
        return T
    if tok == "false":
        return F
    if tok in DEBUG_FLAGS:
        return T if build else M
    return F if build else M


class SwiftCond:
    TOKEN = re.compile(r"\s*(\|\||&&|!|\(|\)|[A-Za-z_$][\w$]*(?:\((?:[^()]|\([^()]*\))*\))?)")

    def __init__(self, text):
        self.text = text.strip()
        self.toks = []
        pos = 0
        s = self.text
        while pos < len(s):
            if s[pos].isspace():
                pos += 1
                continue
            m = self.TOKEN.match(s, pos)
            if not m:
                raise ValueError(f"can't tokenize #if condition {s!r}")
            self.toks.append(m.group(1))
            pos = m.end()

    def atoms(self):
        return [t for t in self.toks if t not in ("||", "&&", "!", "(", ")")]

    def evaluate(self, env, build=False):
        self.k = 0
        self.maybes = []
        v = self._or(env, build)
        if self.k != len(self.toks):
            raise ValueError(f"trailing tokens in #if condition {self.text!r}")
        return v

    def _peek(self):
        return self.toks[self.k] if self.k < len(self.toks) else None

    def _or(self, env, build):
        v = self._and(env, build)
        while self._peek() == "||":
            self.k += 1
            v = _tri_or(v, self._and(env, build))
        return v

    def _and(self, env, build):
        v = self._not(env, build)
        while self._peek() == "&&":
            self.k += 1
            v = _tri_and(v, self._not(env, build))
        return v

    def _not(self, env, build):
        tok = self._peek()
        if tok == "!":
            self.k += 1
            return _tri_not(self._not(env, build))
        if tok == "(":
            self.k += 1
            v = self._or(env, build)
            if self._peek() != ")":
                raise ValueError(f"unbalanced #if condition {self.text!r}")
            self.k += 1
            return v
        self.k += 1
        v = swift_atom(tok, env, build)
        if v == M:
            self.maybes.append(tok)
        return v


# ---------------------------------------------------------------- C

# Macros the compiler predefines, per platform. A macro in C_PLATFORM_MACROS
# that a platform doesn't list is known to be undefined there.
C_ENV = {
    "Darwin":  {"__APPLE__", "__MACH__", "__LP64__", "__aarch64__", "__arm64__", "__ARM_NEON__", "__ARM_NEON"},
    "Linux":   {"__linux__", "__gnu_linux__", "__unix__", "__LP64__", "__x86_64__"},
    "Musl":    {"__linux__", "__unix__", "__LP64__", "__x86_64__"},
    "Android": {"__linux__", "__ANDROID__", "__BIONIC__", "__unix__", "__LP64__", "__aarch64__", "__ARM_NEON"},
    "FreeBSD": {"__FreeBSD__", "__unix__", "__LP64__", "__x86_64__"},
    "OpenBSD": {"__OpenBSD__", "__unix__", "__LP64__", "__x86_64__"},
    "WASI":    {"__wasi__", "__wasm__", "__wasm32__", "__wasm32"},
    "Windows": {"_WIN32", "_WIN64", "_MSC_VER", "__x86_64__"},
}
C_PLATFORM_MACROS = set().union(*C_ENV.values()) | {"__cplusplus", "__arm__", "__i386__", "__wasm64__"}
# Maybe-defined per platform: SIMD features that depend on -m flags, and the
# secondary architectures.
C_MAYBE = {
    "Darwin":  {"__x86_64__", "__SSE4_2__"},
    "Linux":   {"__aarch64__", "__arm__", "__i386__", "__SSE4_2__", "__ARM_NEON__", "__ARM_NEON"},
    "Musl":    {"__aarch64__", "__SSE4_2__", "__ARM_NEON"},
    "Android": {"__x86_64__", "__arm__", "__i386__", "__SSE4_2__"},
    "FreeBSD": {"__aarch64__", "__SSE4_2__"},
    "OpenBSD": {"__aarch64__", "__SSE4_2__"},
    "WASI":    {"__wasm_simd128__"},
    "Windows": {"__aarch64__", "__SSE4_2__"},
}


C_MAYBE_ALL = set().union(*C_MAYBE.values())


def c_env(platform, target_defines=(), build=False):
    defined = set(C_ENV[platform]) | set(target_defines)
    maybe = set() if build else set(C_MAYBE[platform])
    return {"defined": defined, "maybe": maybe - defined, "build": build}


def c_macro(name, env):
    if name in env["defined"]:
        return T
    if name in env["maybe"]:
        return M
    if name in C_PLATFORM_MACROS or name in C_MAYBE_ALL:
        return F
    return F if env["build"] else M


class CCond:
    """A tolerant evaluator for `#if` expressions: defined(), !, &&, ||,
    parentheses, and integer literals. Anything else (comparisons,
    __has_include, macro values) is M."""

    TOKEN = re.compile(r"\s*(\|\||&&|==|!=|<=|>=|[!()<>+\-*/%]|__has_include\s*\([^)]*\)|"
                       r"__has_include_next\s*\([^)]*\)|[A-Za-z_]\w*|0[xX][0-9a-fA-F]+|\d+[uUlL]*)")

    def __init__(self, text):
        self.text = text.strip()
        self.toks = []
        pos = 0
        s = self.text
        while pos < len(s):
            if s[pos].isspace():
                pos += 1
                continue
            m = self.TOKEN.match(s, pos)
            if not m:
                self.toks = None
                return
            self.toks.append(m.group(1))
            pos = m.end()

    def evaluate(self, env):
        self.maybes = []
        if self.toks is None:
            self.maybes.append(self.text)
            return M
        # Split on the lowest-precedence operators; anything with other
        # binary operators at the top level is M.
        self.k = 0
        try:
            v = self._or(env)
        except (IndexError, ValueError):
            self.maybes.append(self.text)
            return M
        if self.k != len(self.toks):
            self.maybes.append(self.text)
            return M
        return v

    def _peek(self):
        return self.toks[self.k] if self.k < len(self.toks) else None

    def _or(self, env):
        v = self._and(env)
        while self._peek() == "||":
            self.k += 1
            v = _tri_or(v, self._and(env))
        return v

    def _and(self, env):
        v = self._cmp(env)
        while self._peek() == "&&":
            self.k += 1
            v = _tri_and(v, self._cmp(env))
        return v

    def _cmp(self, env):
        v = self._unary(env)
        while self._peek() in ("==", "!=", "<", ">", "<=", ">=", "+", "-", "*", "/", "%"):
            self.k += 1
            self._unary(env)
            v = M
            self.maybes.append(self.text)
        return v

    def _unary(self, env):
        tok = self._peek()
        self.k += 1
        if tok == "!":
            return _tri_not(self._unary(env))
        if tok == "(":
            v = self._or(env)
            if self._peek() != ")":
                raise ValueError("unbalanced")
            self.k += 1
            return v
        if tok == "defined":
            if self._peek() == "(":
                self.k += 1
                name = self._peek()
                self.k += 2
            else:
                name = self._peek()
                self.k += 1
            v = c_macro(name, env)
            if v == M:
                self.maybes.append(f"defined({name})")
            return v
        if tok.startswith("__has_include"):
            self.maybes.append(tok)
            return M
        if re.match(r"\d|0[xX]", tok):
            return F if int(re.sub(r"[uUlL]+$", "", tok), 0) == 0 else T
        # A bare macro: undefined macros are 0; a defined one's value is unknown.
        v = c_macro(tok, env)
        if v == T:
            v = M
            self.maybes.append(tok)
        elif v == M:
            self.maybes.append(tok)
        return v


# ---------------------------------------------------------------- per line

def swift_line_states(code_lines):
    """For blanked Swift source lines, return (states, build, errors):
    states[i] = {platform: (T|M, [maybe atoms])} for active platforms,
    build[i] = whether the Darwin build compiles line i,
    errors = list of (line index, states) for active `#error` lines."""
    stack = []       # each level: list of SwiftCond clauses so far, current is last; None = #else
    states, build, errors = [], [], []

    def clause_value(level, env, is_build):
        prev, cur = level
        v, maybes = T, []
        for c in prev:
            cv = c.evaluate(env, is_build)
            maybes += c.maybes
            v = _tri_and(v, _tri_not(cv))
        if cur is not None:
            cv = cur.evaluate(env, is_build)
            maybes += cur.maybes
            v = _tri_and(v, cv)
        return v, maybes

    def current(is_build, env):
        v, maybes = T, []
        for level in stack:
            lv, lm = clause_value(level, env, is_build)
            v = _tri_and(v, lv)
            if lv == M:
                maybes += lm
            if v == F:
                break
        return v, maybes

    cache = {}
    for idx, line in enumerate(code_lines):
        s = line.strip()
        m = re.match(r"^#(if|elseif|else|endif)\b(.*)$", s)
        if m:
            d, rest = m.group(1), m.group(2).strip()
            if d == "if":
                stack.append(([], SwiftCond(rest)))
            elif d == "elseif":
                prev, cur = stack[-1]
                stack[-1] = (prev + [cur], SwiftCond(rest))
            elif d == "else":
                prev, cur = stack[-1]
                stack[-1] = (prev + [cur], None)
            elif d == "endif":
                stack.pop()
            cache = {}
        if "st" not in cache:
            st = {}
            for p in PLATFORMS:
                v, maybes = current(False, SWIFT_ENV[p])
                if v != F:
                    st[p] = (v, sorted(set(maybes)))
            cache["st"] = st
            cache["b"] = current(True, DARWIN_BUILD)[0] == T
        states.append(cache["st"])
        build.append(cache["b"])
        if s.startswith("#error") and cache["st"]:
            errors.append((idx, cache["st"]))
    return states, build, errors


def c_line_states(code_lines, target_defines=()):
    """Like swift_line_states, for C source, without #error: (states,
    build). Include guards count as T."""
    stack = []
    envs = {p: c_env(p, target_defines) for p in PLATFORMS}
    benv = c_env("Darwin", target_defines, build=True)
    # Directives continue onto the next line after a backslash.
    joined = []
    k = 0
    while k < len(code_lines):
        line = code_lines[k]
        n = 1
        while line.rstrip().endswith("\\") and k + n < len(code_lines):
            line = line.rstrip()[:-1] + " " + code_lines[k + n]
            n += 1
        joined.append((k, line, n))
        k += n

    def level_value(level, env):
        prev, cur = level
        v, maybes = T, []
        for c in prev:
            cv = c.evaluate(env)
            maybes += c.maybes
            v = _tri_and(v, _tri_not(cv))
        if cur is not None:
            cv = cur.evaluate(env)
            maybes += cur.maybes
            v = _tri_and(v, cv)
        return v, maybes

    def current(env):
        v, maybes = T, []
        for level in stack:
            lv, lm = level_value(level, env)
            v = _tri_and(v, lv)
            if lv == M:
                maybes += lm
            if v == F:
                break
        return v, maybes

    out_states = [None] * len(code_lines)
    out_build = [False] * len(code_lines)
    for pos, (k, line, n) in enumerate(joined):
        s = line.strip()
        m = re.match(r"^#\s*(if|ifdef|ifndef|elif|else|endif)\b(.*)$", s)
        if m:
            d, rest = m.group(1), m.group(2).strip()
            if d == "ifndef":
                name = rest.split()[0] if rest.split() else ""
                # An include guard: `#ifndef X` followed by `#define X`.
                nxt = joined[pos + 1][1].strip() if pos + 1 < len(joined) else ""
                if re.match(rf"^#\s*define\s+{re.escape(name)}\b", nxt):
                    rest = "1"
                else:
                    rest = f"!defined({name})"
                stack.append(([], CCond(rest)))
            elif d == "ifdef":
                stack.append(([], CCond(f"defined({rest.split()[0]})")))
            elif d == "if":
                stack.append(([], CCond(rest)))
            elif d == "elif":
                prev, cur = stack[-1]
                stack[-1] = (prev + [cur], CCond(rest))
            elif d == "else":
                prev, cur = stack[-1]
                stack[-1] = (prev + [cur], None)
            elif d == "endif":
                if stack:
                    stack.pop()
        st = {}
        for p in PLATFORMS:
            v, maybes = current(envs[p])
            if v != F:
                st[p] = (v, sorted(set(maybes)))
        b = current(benv)[0] == T
        for j in range(k, k + n):
            out_states[j] = st
            out_build[j] = b
    return out_states, out_build
