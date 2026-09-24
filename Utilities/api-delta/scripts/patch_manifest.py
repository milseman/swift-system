#!/usr/bin/env python3
"""Patch a *scratch copy* of swift-system's Package.swift for API extraction.

Never run this on a tracked checkout; regenerate.sh runs it on a `git archive`
export under $WORK.

Two edits:

1. Availability marker. In the default build every `System x.y` availability
   macro expands to the same OS versions (macOS 10.10, iOS 8.0, ...), so a
   symbol graph can't tell `System 199` from `System 0.0.1`. This appends
   `OpenBSD <x.y>` to each macro's source availability. OpenBSD is not a
   compilation target here, so the macOS build (and its availability
   diagnostics) is unchanged, but symbol graphs record the extra domain, merged
   through enclosing extensions and types by the compiler. No declaration in
   the sources names OpenBSD in an @available, so the domain is free.

2. Drop the Samples executable and its swift-argument-parser dependency, which
   would otherwise need a network fetch. Samples is not part of the
   SystemPackage or SystemSockets API.
"""

import re
import sys

path = sys.argv[1]
text = open(path).read()

# 1. Availability marker.
old = 'self.sourceAvailability = "macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"'
new = 'self.sourceAvailability = "macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0, OpenBSD \\(version)"'
if text.count(old) != 1:
    sys.exit(f"patch_manifest: expected exactly one `{old}` in {path}")
text = text.replace(old, new)


# 2. Samples and swift-argument-parser (system-next only).
def remove_call(text, start_token):
    """Remove `start_token(...)` plus a trailing comma and the line it's on."""
    i = text.find(start_token)
    if i < 0:
        return text, False
    depth = 0
    j = i + len(start_token) - 1  # at the '('
    assert text[j] == "("
    while True:
        c = text[j]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                break
        j += 1
    j += 1
    if text[j] == ",":
        j += 1
    line_start = text.rfind("\n", 0, i) + 1
    if text[line_start:i].strip() == "":
        i = line_start
    if text[j] == "\n":
        j += 1
    return text[:i] + text[j:], True


text, _ = remove_call(text, ".executableTarget(")
text = re.sub(r'\n\s*\.executable\(name: "system-samples", targets: \["Samples"\]\),', "", text)
text = re.sub(
    r'dependencies: \[\s*\.package\(url: "https://github.com/apple/swift-argument-parser"[^\]]*\],',
    "dependencies: [],",
    text,
)
if "swift-argument-parser" in text or '"Samples"' in text:
    sys.exit(f"patch_manifest: Samples or swift-argument-parser still referenced in {path}")

open(path, "w").write(text)
print(f"patch_manifest: patched {path}")
