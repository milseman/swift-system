#!/usr/bin/env python3
"""Removing a target's imports of platform C modules, in the scratch copy.

An import is removed in every form Swift has: plain, with attributes
(`@preconcurrency`, `@_implementationOnly`, `@_exported`, `@testable`,
`@_spi(X)`), with an access level (`public import`), scoped (`import func
Darwin.fopen`), of a submodule (`import Darwin.C`), with a trailing comment,
and inside any `#if` arm. Attribute-only lines directly above a removed
import go with it, so no attribute is left to attach to the next line.
Each removed line becomes a comment of the same line, so the compiler's
line numbers are the original file's.

Which modules: `should_remove(module)`, from modules.ini's [count] group
(adopter-coverage's `ledger.Modules`), plus a package's configured shims.
Everything else stays: `import SystemPackage`, Foundation, the package's
own modules.
"""

import sys

sys.dont_write_bytecode = True

import re  # noqa: E402

ATTR = r"@[A-Za-z_]\w*(?:\([^()\n]*\))?"
IMPORT = re.compile(
    rf"^(?P<indent>[ \t]*)(?P<attrs>(?:{ATTR}[ \t]+)*)"
    r"(?P<access>(?:(?:public|package|internal|fileprivate|private|open)[ \t]+)?)"
    r"import[ \t]+(?:(?P<kind>typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?"
    r"(?P<module>[A-Za-z_]\w*)(?P<rest>(?:\.[A-Za-z_]\w*)*)"
    r"[ \t]*;?[ \t]*(?P<comment>//.*)?$")
ATTR_ONLY = re.compile(rf"^[ \t]*(?:{ATTR}[ \t]*)+$")
MARK = "// import-probe removed: "


def imports(text):
    """[(line number, module, scoped name or None, the line)] for every
    import line."""
    out = []
    for i, line in enumerate(text.split("\n"), 1):
        m = IMPORT.match(line)
        if m:
            scoped = m.group("rest").split(".")[-1] if m.group("kind") else None
            out.append((i, m.group("module"), scoped, line))
    return out


def strip(text, should_remove):
    """(new text, removed): the text with every import of a module
    `should_remove` accepts commented out, and [{line, module, scoped,
    text, exported}] for each one removed, line numbers 1-based."""
    lines = text.split("\n")
    removed = []
    for i, line in enumerate(lines):
        m = IMPORT.match(line)
        if not m or not should_remove(m.group("module")):
            continue
        removed.append({"line": i + 1, "module": m.group("module"),
                        "scoped": m.group("rest").split(".")[-1] if m.group("kind") else None,
                        "text": line.strip(), "exported": "@_exported" in m.group("attrs")})
        lines[i] = m.group("indent") + MARK + line.strip()
        k = i - 1
        while k >= 0 and ATTR_ONLY.match(lines[k]):
            removed[-1]["exported"] |= "@_exported" in lines[k]
            lines[k] = re.match(r"^[ \t]*", lines[k]).group(0) + MARK + lines[k].strip()
            k -= 1
    return "\n".join(lines), removed


def module_matcher(modules, extra=()):
    """should_remove for adopter-coverage's ledger.Modules (its [count]
    group) and extra module names."""
    extra = set(extra)

    def should_remove(module):
        return module in extra or modules.group(module) == "count"
    return should_remove
