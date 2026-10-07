#!/usr/bin/env python3
"""lint's cmake check: every Swift file of SystemPackage's sources is
listed in Sources/System/CMakeLists.txt, and every Swift file listed there
exists; the same for SystemSockets once it has a CMakeLists.txt.

The files are the working tree's (git's tracked files and its untracked
ones that aren't ignored), so a new file is caught before it's committed.
CI's check compares SwiftPM's sources with CMake's configured list; this
compares paths as written, which needs no CMake. A list's entries are
paths relative to its directory.
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import re  # noqa: E402

from lintcore import Finding, git  # noqa: E402

RULES = [
    ("cmake/missing", "error", "a Swift file of the module's sources that its CMakeLists.txt doesn't list"),
    ("cmake/stale", "error", "a Swift file a CMakeLists.txt lists that doesn't exist"),
]
MODULES = (("Sources/System", "SystemPackage"), ("Sources/SystemSockets", "SystemSockets"))
ENTRY = re.compile(r"(?<![\w/.+-])([\w+.-][\w+/.-]*\.swift)\b")


def listed(text):
    """{relative path: line} of every .swift path in a CMakeLists.txt, past
    its comments."""
    out = {}
    in_block = False
    for n, line in enumerate(text.split("\n"), 1):
        s = line
        if in_block:
            if "#]]" in s:
                in_block = False
                s = s.split("#]]", 1)[1]
            else:
                continue
        if "#[[" in s:
            in_block = "#]]" not in s.split("#[[", 1)[1]
            s = s.split("#[[", 1)[0]
        s = s.split("#", 1)[0]
        for m in ENTRY.finditer(s):
            out.setdefault(m.group(1), n)
    return out


def files(repo, directory):
    tracked = git(repo, "ls-files", "-z", "--", directory).split("\0")
    untracked = git(repo, "ls-files", "-z", "--others", "--exclude-standard", "--", directory).split("\0")
    return sorted({f for f in tracked + untracked if f.endswith(".swift")
                   and os.path.exists(os.path.join(repo, f))})


def check(repo, directory, cmake_rel):
    findings = []
    cmake = os.path.join(repo, cmake_rel)
    with open(cmake, encoding="utf-8") as f:
        text = f.read()
    entries = listed(text)
    have = {os.path.relpath(f, directory): f for f in files(repo, directory)}
    for rel, path in sorted(have.items()):
        if rel not in entries:
            findings.append(Finding(path, 1, "cmake/missing", "error",
                                    f"not in {cmake_rel}; add `{rel}` to its list"))
    for rel, line in sorted(entries.items(), key=lambda kv: kv[1]):
        if rel not in have and not os.path.exists(os.path.join(repo, directory, rel)):
            findings.append(Finding(cmake_rel, line, "cmake/stale", "error",
                                    f"`{rel}` doesn't exist in {directory}"))
    return findings


def run(ctx):
    out = []
    for directory, module in MODULES:
        cmake_rel = f"{directory}/CMakeLists.txt"
        if not os.path.isfile(os.path.join(ctx.repo, cmake_rel)):
            ctx.note(f"cmake: {module} has no {cmake_rel}; nothing to check (CMake doesn't build it)")
            continue
        out += check(ctx.repo, directory, cmake_rel)
    return out
