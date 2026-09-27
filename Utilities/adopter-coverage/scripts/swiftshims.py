#!/usr/bin/env python3
"""Count the C library and OS interfaces the Swift standard library uses,
and how many of them System covers.

The standard library reaches the C library through SwiftShims (the shim
headers in stdlib/public/SwiftShims, whose functions the stubs implement)
and directly from its C++ runtime, its stubs, Concurrency's C++, and the
threading layer (lib/Threading, include/swift/Threading); its Swift code
calls a few C functions itself. This scans those sources lexically, in a
sparse clone of swiftlang/swift, and counts the names they use that the
Darwin SDK declares in C, from the vocabulary a package build's index
stored (vocab.py):
  - C and C++: an identifier, not after `.`, `->` or `::`; a function only
    where it's called;
  - Swift: the same, less the names the Swift libraries declare.
Each name then gets System's coverage at the checked commit, from
derive.py's output: named by a public declaration, named only for some
uses, or not named. Names only other platforms declare (Linux's futex) are
outside the Darwin vocabulary, so they aren't counted: these are counts of
Darwin's interfaces. Counts only; no mapping.

Usage: swiftshims.py SWIFT_CLONE VOCAB.json.gz DERIVED.json OUT.json
"""

import sys

sys.dont_write_bytecode = True

import collections
import gzip
import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "api-delta", "scripts"))
from scan_sources import strip_comments_and_strings  # noqa: E402

COMPONENTS = [
    ("SwiftShims", ["stdlib/public/SwiftShims"], (".h",)),
    ("stubs", ["stdlib/public/stubs"], (".c", ".cpp", ".mm", ".m", ".h")),
    ("runtime", ["stdlib/public/runtime"], (".c", ".cpp", ".mm", ".m", ".h")),
    ("Concurrency (C++)", ["stdlib/public/Concurrency"], (".c", ".cpp", ".h")),
    ("threading", ["lib/Threading", "include/swift/Threading"], (".c", ".cpp", ".h")),
    ("core (Swift)", ["stdlib/public/core"], (".swift",)),
    ("Concurrency (Swift)", ["stdlib/public/Concurrency"], (".swift",)),
    ("Synchronization (Swift)", ["stdlib/public/Synchronization"], (".swift",)),
]
# The C library and the kernel's interfaces; the rest of the SDK's modules
# are counted apart (MachO, os, Dispatch, ObjectiveC: Darwin's, but not a C
# library's).
LIBC = re.compile(r"^(Darwin|_DarwinFoundation\d*|_Builtin_[a-z]+|SwiftGlibc)(\.|$)")
OTHER_OS = re.compile(r"^(MachO|os|Dispatch|ObjectiveC|CoreFoundation)(\.|$)")
FUNCTION_KINDS = sum(1 << k for k in (12, 16, 17, 18, 22, 23))
FIELD_KINDS = 1 << 14
MACRO_OR_CONSTANT = (1 << 4) | (1 << 15)
TYPE_KINDS = sum(1 << k for k in (5, 6, 7, 8, 10, 11))
VARIABLE_KINDS = 1 << 13
# The C library's lowercase globals and macros that code names bare.
LOWER_GLOBALS = {"errno", "environ", "stdin", "stdout", "stderr", "optarg", "optind", "timezone", "daylight",
                 "tzname", "offsetof", "va_start", "va_end", "va_arg", "va_copy", "assert", "alloca"}
C_KEYWORDS = set("""auto break case char const continue default do double else enum extern float for goto if inline
int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while
bool true false nullptr class namespace template typename public private protected virtual using new delete this
operator friend explicit mutable constexpr noexcept decltype static_assert thread_local alignas alignof""".split())


def blank_c(text):
    """C and C++ without comments, string and character literals, or
    preprocessor lines other than conditions."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text)
    text = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", text)
    text = re.sub(r"^\s*#\s*(include|import|pragma|error|warning)[^\n]*", "", text, flags=re.M)
    return text


TOKEN = re.compile(r"(\.|->|::|\bstruct\s+|\bunion\s+|\benum\s+)?\b([A-Za-z_]\w*)\b(\s*\()?")


def names_in(code):
    """{name: (called?, tagged?)} for the identifiers of blanked code that
    aren't members or qualified; tagged is `struct x`."""
    out = {}
    for m in TOKEN.finditer(code):
        pre = (m.group(1) or "").strip()
        if pre in (".", "->", "::"):
            continue
        n = m.group(2)
        if n in C_KEYWORDS:
            continue
        called, tagged = out.get(n, (False, False))
        out[n] = (called or bool(m.group(3)), tagged or pre in ("struct", "union", "enum"))
    return out


def counts(name, kinds, called, tagged):
    """Whether a use of an SDK name is likely the C library's, by its kind
    and its spelling: a common word that some header also declares
    (`entry`, `label`, `buf`) isn't."""
    if len(name) < 2:
        return False
    if kinds & FUNCTION_KINDS and called:
        return True
    if kinds & MACRO_OR_CONSTANT and (re.fullmatch(r"_*[A-Z][A-Z0-9_]+", name) or name in LOWER_GLOBALS):
        return True
    if kinds & TYPE_KINDS and (name.endswith("_t") or tagged or name in ("FILE", "DIR")):
        return True
    if kinds & VARIABLE_KINDS and name in LOWER_GLOBALS:
        return True
    return False


def main():
    swift, vocab_path, derived_path, out_path = sys.argv[1:5]
    with gzip.open(vocab_path, "rt", encoding="utf-8") as f:
        vocab = json.load(f)["vocab"]
    libc, other, swift_names = {}, {}, set()
    for module, names in vocab.items():
        top = module.split(".")[0]
        for n, (kinds, langs) in names.items():
            if module.startswith("Swift") or top in ("_Concurrency", "Synchronization", "_StringProcessing"):
                swift_names.add(n)
            if not langs & 1 or kinds & FIELD_KINDS and not kinds & ~FIELD_KINDS:
                continue
            if LIBC.match(module):
                libc[n] = libc.get(n, 0) | kinds
            elif OTHER_OS.match(module):
                other[n] = other.get(n, 0) | kinds
    derived = json.load(open(derived_path))["names"]
    commit = subprocess.run(["git", "-C", swift, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()

    per = {}
    all_libc = collections.defaultdict(set)
    all_other = collections.defaultdict(set)
    for comp, dirs, exts in COMPONENTS:
        used_l, used_o, files = set(), set(), 0
        for d in dirs:
            base = os.path.join(swift, d)
            for dirpath, _, fs in os.walk(base):
                for f in fs:
                    if not f.endswith(exts):
                        continue
                    files += 1
                    text = open(os.path.join(dirpath, f), encoding="utf-8", errors="replace").read()
                    if f.endswith(".swift"):
                        code, _ = strip_comments_and_strings(text)
                        code = re.sub(r"^\s*import\s+[^\n]*", "", code, flags=re.M)
                    else:
                        code = blank_c(text)
                    for n, (called, tagged) in names_in(code).items():
                        for table, used, everywhere in ((libc, used_l, all_libc), (other, used_o, all_other)):
                            kinds = table.get(n)
                            if kinds is None or not counts(n, kinds, called, tagged):
                                continue
                            if f.endswith(".swift") and n in swift_names:
                                continue
                            used.add(n)
                            everywhere[n].add(comp)
        per[comp] = {"files": files, "libc": sorted(used_l), "otherOS": sorted(used_o)}

    sys.path.insert(0, HERE)
    import check
    config, _entries, _p = check.load_mapping(os.path.join(HERE, "..", "mapping.ini"))
    category = {n: check.auto_category({"name": n, "headers": []}, config) for n in all_libc}

    def status(n):
        d = derived.get(n)
        return d["status"] if d else "missing"

    def tally(names):
        c = collections.Counter(status(n) for n in names)
        inscope = [n for n in names if category[n] not in check.OUT_OF_SCOPE]
        ci = collections.Counter(status(n) for n in inscope)
        return {"used": len(names), "covered": c["covered"], "partial": c["partial"], "missing": c["missing"],
                "inScope": len(inscope), "inScopeCovered": ci["covered"], "inScopePartial": ci["partial"],
                "inScopeMissing": ci["missing"]}

    out = {
        "swiftCommit": commit, "method": __doc__.split("Usage:")[0].strip(),
        "components": {k: dict(v, counts=tally(v["libc"]), otherOSCount=len(v["otherOS"])) for k, v in per.items()},
        "total": tally(sorted(all_libc)),
        "otherOS": len(all_other),
        "missingNames": sorted((n for n in all_libc if status(n) == "missing" and category[n] not in check.OUT_OF_SCOPE),
                               key=lambda n: (-len(all_libc[n]), n)),
        "outOfScope": sorted(n for n in all_libc if category[n] in check.OUT_OF_SCOPE),
        "coveredNames": sorted(n for n in all_libc if status(n) != "missing"),
        "byName": {n: {"components": sorted(v), "status": status(n), "category": category[n]}
                   for n, v in sorted(all_libc.items())},
    }
    json.dump(out, open(out_path, "w"), indent=1)
    t = out["total"]
    print(f"swiftshims: swift {commit[:10]}: {t['used']} C library and kernel interfaces ({t['inScope']} in System's "
          f"scope): {t['covered']} covered by System, {t['partial']} partly, {t['missing']} not (in scope "
          f"{t['inScopeCovered']}/{t['inScopePartial']}/{t['inScopeMissing']}); {out['otherOS']} other OS names "
          f"(MachO, os, Dispatch, ObjectiveC, CoreFoundation)")
    for k, v in out["components"].items():
        c = v["counts"]
        print(f"    {k:26s} {v['files']:4d} files: {c['used']:4d} used ({c['inScope']} in scope), {c['covered']} "
              f"covered, {c['partial']} partly, {c['missing']} not; {v['otherOSCount']} other OS")


if __name__ == "__main__":
    main()
