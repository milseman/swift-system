#!/usr/bin/env python3
"""C names to the Darwin header that declares them, and its SDK module.

Two sources, used together:

- The coverage tools' SDK vocabulary (`../coverage-results/vocab/macosx*.json.gz`,
  written by Utilities/adopter-coverage/scripts/vocab.py from an index
  store): {clang module: {name: [kind mask, language mask]}}. It names the
  module a declaration was indexed in, but a name gets the module of the
  first declaration the index saw, which for a struct can be a forward
  declaration in another header (`struct sockaddr_in;` in bsm/audit_record.h),
  and it has no macros the index didn't record (O_SYNC).
- The SDK itself: its module maps, for each module's headers, and its
  headers' text, for the `#define`s and the struct, union and enum
  definitions.

So a macro or constant is looked up by its `#define` first, a struct by its
definition, and a function or anything else by the vocabulary's module,
confirmed against the module's headers. A name in neither is "not in the
macOS SDK". Only `usr/include` is indexed; a vocabulary module in a
framework (CoreFoundation.CFBase) maps to the framework's header of that
name.
"""

import sys

sys.dont_write_bytecode = True

import collections  # noqa: E402
import gzip  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

INDEX_FORMAT = 4

# C's own types, which no header declares.
BUILTIN_TYPES = {"int", "char", "short", "long", "unsigned", "signed", "float", "double", "void", "_Bool", "bool"}

# indexstore_symbol_kind_t bits, as vocab.py records them.
K_MACRO, K_ENUM, K_STRUCT, K_CLASS, K_UNION, K_TYPEALIAS = 4, 5, 6, 7, 10, 11
K_FUNCTION, K_VARIABLE, K_FIELD, K_ENUMCONSTANT = 12, 13, 14, 15
KIND_BITS = {
    "function": {K_FUNCTION},
    "constant": {K_ENUMCONSTANT, K_MACRO, K_VARIABLE},
    "macro": {K_MACRO},
    "type": {K_ENUM, K_STRUCT, K_CLASS, K_UNION, K_TYPEALIAS},
    "variable": {K_VARIABLE},
    "field": {K_FIELD},
    "error": {K_ENUMCONSTANT, K_MACRO},
}

COMMENT_RE = re.compile(r"/\*.*?\*/|//[^\n]*", re.S)
DEFINE_RE = re.compile(r"^[ \t]*#[ \t]*define[ \t]+([A-Za-z_]\w*)", re.M)
TAG_RE = re.compile(r"\b(?:struct|union|enum)\s+([A-Za-z_]\w*)\s*\{")
ENUM_BODY_RE = re.compile(r"\benum\b[^{;()]*\{([^{}]*)\}")
ENUMERATOR_RE = re.compile(r"(?:^|,)\s*([A-Za-z_]\w*)")
# A prototype whose return type starts its line: `pid_t getpid(void);`.
TYPEDEF_RES = [
    re.compile(r"\btypedef\b[^;{}()]*?\b([A-Za-z_]\w*)\s*(?:\[[^\]]*\]\s*)*;"),
    re.compile(r"\btypedef\s+(?:struct|union|enum)\b[^{;]*\{[^{}]*\}\s*([A-Za-z_]\w*)\s*;"),
    re.compile(r"\btypedef\b[^;{}]*?\(\s*\*\s*([A-Za-z_]\w*)\s*\)\s*\("),
]
INCLUDE_RE = re.compile(r'^[ \t]*#[ \t]*(?:include|import)[ \t]*[<"]([^>"]+)[>"]', re.M)
# Directories of the SDK's usr/include that hold Darwin's own headers; a
# header outside them and outside every module (apache2/, libxml2/, ...) is
# another library's, and a name it defines isn't Darwin's.
DARWIN_DIRS = {"sys", "mach", "machine", "net", "netinet", "netinet6", "arpa", "arm", "arm64", "i386",
               "libkern", "os", "malloc", "pthread", "secure", "xlocale", "_types", "bsm", "hfs", "kern",
               "mach-o", "miscfs", "nfs", "vfs", "voucher", "uuid", "device", "default_pager", "rpc", "rpcsvc",
               "servers", "atm", "bank", "corpses", "pexpert", "dispatch", "xpc", "objc", "architecture",
               "protocols", "_modules"}
PROTOTYPE_RE = re.compile(r"^[ \t]*(?:extern[ \t]+)?(?:[A-Za-z_]\w*[ \t\*]+)+\**([A-Za-z_]\w*)[ \t]*\(", re.M)
TOKEN_RE = re.compile(r'"(?:[^"\\]|\\.)*"|[{}\[\],]|[^\s{}\[\],"]+')


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


# ------------------------------------------------------------------ module maps

class ModuleMaps:
    """Headers per module, from an SDK's module maps (usr/include)."""

    def __init__(self, include):
        self.include = include
        self.headers = collections.defaultdict(list)    # module -> [header]
        self.umbrella_dir = {}                           # module -> directory
        self.seen_files = set()
        top = os.path.join(include, "module.modulemap")
        if os.path.exists(top):
            self.parse_file(top, None)
        for f in sorted(os.listdir(include)):
            if f.endswith(".modulemap"):
                self.parse_file(os.path.join(include, f), None)
        self.module_of = {}
        for m in sorted(self.headers, key=lambda m: (m.count("."), m)):
            for h in self.headers[m]:
                self.module_of.setdefault(h, m)

    def parse_file(self, path, prefix):
        path = os.path.realpath(path)
        if path in self.seen_files or not os.path.exists(path):
            return
        self.seen_files.add(path)
        text = COMMENT_RE.sub(" ", read_text(path))
        toks = TOKEN_RE.findall(text)
        self.parse_body(toks, 0, prefix, os.path.dirname(path), top=True)

    def parse_body(self, toks, i, prefix, base, top=False):
        n = len(toks)
        while i < n:
            t = toks[i]
            if t == "}":
                return i + 1
            if t in ("explicit", "framework"):
                i += 1
                continue
            if t == "extern" and i + 3 < n and toks[i + 1] == "module":
                self.parse_file(os.path.join(base, toks[i + 3].strip('"')), None)
                i += 4
                continue
            if t == "module":
                name = toks[i + 1]
                i += 2
                while i < n and toks[i] == "[":
                    while i < n and toks[i] != "]":
                        i += 1
                    i += 1
                if i >= n or toks[i] != "{":
                    continue
                if name == "*":
                    full = (prefix or "") + ".*"
                else:
                    full = name if top or not prefix else f"{prefix}.{name}"
                i = self.parse_body(toks, i + 1, full, base)
                if name == "*" and prefix:
                    self.infer_wildcard(prefix)
                continue
            if t in ("header", "textual", "private", "exclude", "umbrella"):
                mods = []
                while i < n and toks[i] in ("textual", "private", "exclude", "umbrella"):
                    mods.append(toks[i])
                    i += 1
                if i < n and toks[i] == "header":
                    i += 1
                    if i < n and toks[i].startswith('"'):
                        h = toks[i].strip('"')
                        if "exclude" not in mods and prefix:
                            self.headers[prefix].append(h)
                        i += 1
                        if i < n and toks[i] == "{":
                            while i < n and toks[i] != "}":
                                i += 1
                            i += 1
                    continue
                if "umbrella" in mods and i < n and toks[i].startswith('"'):
                    self.umbrella_dir[prefix] = toks[i].strip('"')
                    i += 1
                    continue
                continue
            if t in ("export", "export_as", "use"):
                i += 2
                continue
            if t == "link":
                i += 1
                if i < n and toks[i] == "framework":
                    i += 1
                i += 1
                continue
            if t in ("requires", "config_macros", "conflict"):
                i += 1
                while i < n and toks[i] == "[":
                    while i < n and toks[i] != "]":
                        i += 1
                    i += 1
                # A comma-separated list.
                while i < n:
                    i += 1
                    if i < n and toks[i] == ",":
                        i += 1
                        continue
                    break
                continue
            i += 1
        return i

    def infer_wildcard(self, parent):
        """`module * { export * }` under an umbrella directory: a submodule per header."""
        d = self.umbrella_dir.get(parent)
        if not d:
            return
        full = os.path.join(self.include, d)
        if not os.path.isdir(full):
            return
        for f in sorted(os.listdir(full)):
            if f.endswith(".h"):
                self.headers[f"{parent}.{f[:-2]}"].append(f"{d}/{f}")


# ------------------------------------------------------------------ the SDK index

def sdk_path():
    p = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True, text=True)
    v = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-version"], capture_output=True, text=True)
    return p.stdout.strip(), v.stdout.strip()


def build_index(sdk):
    include = os.path.join(sdk, "usr", "include")
    maps = ModuleMaps(include)
    macros = collections.defaultdict(list)
    tags = collections.defaultdict(list)
    enumerators = collections.defaultdict(list)
    functions = collections.defaultdict(list)
    includes = {}
    typedefs = collections.defaultdict(list)
    for dirpath, _, files in os.walk(include):
        for f in sorted(files):
            if not f.endswith(".h"):
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, include)
            try:
                text = COMMENT_RE.sub(" ", read_text(full))
            except OSError:
                continue
            for m in set(DEFINE_RE.findall(text)):
                macros[m].append(rel)
            for m in set(TAG_RE.findall(text)):
                tags[m].append(rel)
            names = set()
            for body in ENUM_BODY_RE.findall(text):
                names.update(ENUMERATOR_RE.findall(re.sub(r"=[^,]*", "", body)))
            for m in names:
                enumerators[m].append(rel)
            for m in set(PROTOTYPE_RE.findall(text)):
                functions[m].append(rel)
            names = set()
            for r in TYPEDEF_RES:
                names.update(r.findall(text))
            for m in names:
                typedefs[m].append(rel)
            inc = sorted(set(INCLUDE_RE.findall(text)))
            if inc:
                includes[rel] = inc
    return {"format": INDEX_FORMAT, "sdk": sdk, "headers": dict(maps.headers), "macros": dict(macros),
            "tags": dict(tags), "enumerators": dict(enumerators), "functions": dict(functions),
            "includes": includes, "typedefs": dict(typedefs)}


def load_index(sdk, cache):
    key = hashlib.sha1(f"{sdk} {INDEX_FORMAT}".encode()).hexdigest()[:12]
    path = os.path.join(cache, f"sdk-{key}.json.gz") if cache else None
    if path and os.path.exists(path):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    idx = build_index(sdk)
    if path:
        os.makedirs(cache, exist_ok=True)
        tmp = path + ".tmp"
        with gzip.open(tmp, "wt", encoding="utf-8") as f:
            json.dump(idx, f, separators=(",", ":"))
        os.replace(tmp, path)
    return idx


# ------------------------------------------------------------------ lookups

def header_rank(h):
    """Prefer a plain header to an architecture's or a wrapper's."""
    arch = h.split("/")[0] in ("i386", "arm", "arm64", "ppc", "machine", "_modules")
    return (arch, h.count("/"), len(h), h)


class Headers:
    def __init__(self, vocab_path, sdk, cache):
        self.sdk = sdk
        self.include = os.path.join(sdk, "usr", "include")
        with gzip.open(vocab_path, "rt", encoding="utf-8") as f:
            vocab = json.load(f)
        self.vocab_note = vocab.get("note")
        self.by_name = collections.defaultdict(list)    # name -> [(module, kind mask)]
        for module, names in vocab["vocab"].items():
            for name, (kinds, lang) in names.items():
                if lang & 1 and module:
                    self.by_name[name].append((module, kinds))
        idx = load_index(sdk, cache)
        self.headers = idx["headers"]
        self.macros = idx["macros"]
        self.tags = idx["tags"]
        self.enumerators = idx["enumerators"]
        self.functions = idx["functions"]
        self.typedefs = idx["typedefs"]
        self.module_of = {}
        for m in sorted(self.headers, key=lambda m: (m.count("."), m)):
            for h in self.headers[m]:
                self.module_of.setdefault(h, m)
        # A header no module lists, but one of a module's headers includes
        # (netinet6/in6.h, from netinet/in.h), is in that module: the first
        # found going breadth-first from the modules' headers, in name order.
        self.included_by = {}
        frontier = sorted(self.module_of)
        seen = set(frontier)
        while frontier:
            nxt = []
            for h in frontier:
                for x in sorted(idx["includes"].get(h, ())):
                    if x not in seen:
                        seen.add(x)
                        self.included_by[x] = self.module_of.get(h) or self.included_by.get(h)
                        nxt.append(x)
            frontier = nxt
        self.text_cache = {}
        self.memo = {}

    def text(self, h):
        if h not in self.text_cache:
            p = os.path.join(self.include, h)
            try:
                self.text_cache[h] = COMMENT_RE.sub(" ", read_text(p))
            except OSError:
                self.text_cache[h] = ""
        return self.text_cache[h]

    def module_headers(self, module):
        """A module's own headers, or, for one with none, its submodules'."""
        own = self.headers.get(module)
        if own:
            return own
        return [h for m, hs in sorted(self.headers.items()) if m.startswith(module + ".") for h in hs]

    def framework_header(self, module):
        top, _, sub = module.partition(".")
        fw = os.path.join(self.sdk, "System", "Library", "Frameworks", f"{top}.framework", "Headers")
        name = (sub.split(".")[-1] if sub else top) + ".h"
        if os.path.exists(os.path.join(fw, name)):
            return f"{top}/{name}"
        return None

    def in_module(self, name, module, call=False):
        pat = re.compile(rf"\b{re.escape(name)}\b" + (r"\s*\(" if call else ""))
        for h in self.module_headers(module):
            if pat.search(self.text(h)):
                return h
        return None

    def darwin_header(self, h):
        """Whether a header is Darwin's: in a module, included by one, or in Darwin's directories."""
        if h in self.module_of or h in self.included_by:
            return True
        return "/" not in h or h.split("/")[0] in DARWIN_DIRS

    def result(self, header, module, how):
        if module is None and header:
            module = self.module_of.get(header) or self.included_by.get(header)
        return {"header": header, "module": module, "sdkModule": module.split(".")[0] if module else None,
                "how": how}

    def vocab_hit(self, name, bits, call=False):
        cands = [(m, k) for m, k in self.by_name.get(name, []) if not bits or any(k & (1 << b) for b in bits)]
        cands.sort(key=lambda mk: (not mk[0].startswith(("Darwin", "_DarwinFoundation")),
                                   "_tgmath" in mk[0], mk[0]))
        for m, _ in cands:
            if m.split(".")[0] in self.top_modules():
                h = self.in_module(name, m, call=call)
                if h:
                    return self.result(h, m, "vocabulary")
                hs = self.module_headers(m)
                if hs:
                    return self.result(sorted(hs, key=header_rank)[0], m, "vocabulary (module's header)")
            else:
                h = self.framework_header(m)
                return self.result(h, m, "vocabulary (framework)")
        return None

    def top_modules(self):
        if not hasattr(self, "_tops"):
            self._tops = {m.split(".")[0] for m in self.headers}
        return self._tops

    def prefer(self, hs, name):
        mods = {m for m, _ in self.by_name.get(name, [])}
        return sorted(hs, key=lambda h: (self.module_of.get(h) not in mods,) + header_rank(h))[0]

    def locate(self, name, ckinds):
        key = (name, tuple(ckinds or ()))
        if key in self.memo:
            return self.memo[key]
        r = self._locate(name, set(ckinds or ()))
        self.memo[key] = r
        return r

    def _locate(self, name, ckinds):
        """The vocabulary first for what an index records reliably (functions,
        variables, enumerators); the headers' text first for macros and
        struct definitions, which it can misattribute or miss."""
        texts = (("#define", self.macros), ("definition", self.tags), ("typedef", self.typedefs),
                 ("enumerator", self.enumerators), ("prototype", self.functions))
        if name in BUILTIN_TYPES:
            return {"header": None, "module": None, "sdkModule": None, "how": "a C built-in type"}
        macros = [h for h in self.macros.get(name, ()) if self.darwin_header(h)]
        tags = [h for h in self.tags.get(name, ()) if self.darwin_header(h)]
        if ckinds & {"constant", "macro", "error"} and macros:
            return self.result(self.prefer(macros, name), None, "#define")
        if "type" in ckinds and tags:
            return self.result(self.prefer(tags, name), None, "definition")
        for ck in sorted(ckinds):
            r = self.vocab_hit(name, KIND_BITS.get(ck, set()), call=(ck == "function"))
            if r:
                return r
        r = self.vocab_hit(name, set())
        if r:
            return r
        for how, table in texts:
            hs = [h for h in table.get(name, ()) if self.darwin_header(h)]
            if hs:
                return self.result(self.prefer(hs, name), None, how)
        return {"header": None, "module": None, "sdkModule": None, "how": "not in the macOS SDK"}


def newest_vocab(results_store):
    d = os.path.join(results_store, "vocab")
    if not os.path.isdir(d):
        return None
    files = sorted(f for f in os.listdir(d) if f.startswith("macosx") and f.endswith(".json.gz"))
    return os.path.join(d, files[-1]) if files else None
