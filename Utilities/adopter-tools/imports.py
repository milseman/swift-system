#!/usr/bin/env python3
"""Count a package's Swift files that import Darwin, and list its SYSTEM-GAP markers.

Usage: imports.py PACKAGE [REV] [--base REV] [--paths Sources,Tests] [--reexporters M,N]
                  [--markdown] [--json OUT] [--quiet]

Reads the sources only, with no build: at REV, or in PACKAGE's working tree when REV is omitted
(uncommitted and untracked files included). A file counts by its broadest Darwin import, in
STATUS.md's terms:

  whole      `import Darwin`, with any attributes (`@_exported`, `@preconcurrency`, ...)
  submodule  `import Darwin.C`, `import Darwin.POSIX.sys.stat`
  scoped     only scoped imports: `import func Darwin.fopen`, `import struct Darwin.stat`
  re-export  no Darwin import, but an import of a module that re-exports Darwin: a package target
             whose sources have an `@_exported import Darwin` (found under Sources/<target>/, and
             the targets that re-export those), or one named with --reexporters

Comments and string literals don't count. Unlike status.sh (Utilities/adopter-coverage), it counts
every Swift file under PACKAGE, or under --paths, rather than the manifest's targets, and it doesn't
evaluate `#if`: an import under `#if FOUNDATION_FRAMEWORK` counts. darwin_audit.py counts from a
build's index instead, and sees what reaches Darwin without an import.

SYSTEM-GAP markers are read as status.sh reads them: `SYSTEM-GAP:` in a comment, its text continued
onto the comment lines right after it, covering the imports right after its comment or the import it
trails. Each is listed by its first line, with the Darwin names it covers; a scoped Darwin import no
marker covers is flagged.

--base REV adds the counts at REV, for a MIGRATION.md's "at start" and "now" (REV is often the merge
base: `--base $(git -C PACKAGE merge-base main HEAD)`). --markdown prints the tables in Markdown.
--json writes everything, file by file.
"""

import argparse
import collections
import json
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

FORMS = ("whole", "submodule", "scoped", "re-export")
RANK = {"whole": 0, "submodule": 1, "scoped": 2, "re-export": 3}
LABEL = {"whole": "whole module", "submodule": "submodule", "scoped": "scoped only", "re-export": "through a re-export"}
HEAD_WIDTH = 150


def scan(root, rev, paths, extra_reexporters):
    files = common.swift_files(root, rev=rev, paths=paths)
    texts = common.read_sources(root, files, rev)
    parsed = {}

    def parse(f):
        if f not in parsed:
            text = texts[f]
            parsed[f] = (common.imports(text), common.markers(text) if "SYSTEM-GAP" in text else [])
        return parsed[f]

    # Package targets that re-export Darwin, by SwiftPM's Sources/<target>/ convention.
    reexporters = set(extra_reexporters)
    exported = [(f.split("/")[1], im.module) for f in files if "@_exported" in texts[f]
                and len(f.split("/")) > 2 and f.split("/")[0] in ("Sources", "Source")
                for im in parse(f)[0] if im.exported]
    while True:     # and the targets that re-export those
        more = {target for target, mod in exported if mod == "Darwin" or mod in reexporters}
        if more <= reexporters:
            break
        reexporters |= more
    # Only a file that mentions Darwin, a re-exporter or a marker can count.
    words = re.compile(r"\b(?:" + "|".join(map(re.escape, sorted(reexporters | {"Darwin"}))) + r")\b|SYSTEM-GAP")
    for f in files:
        if words.search(texts[f]):
            parse(f)
    report = {}
    all_markers = []
    for f, (ims, mks) in sorted(parsed.items()):
        darwin = [im for im in ims if im.module == "Darwin" or im.module in reexporters]
        for mk in mks:
            # The scoped imports it covers: Darwin's by name, another module's qualified.
            names = list(dict.fromkeys(im.name if im.module == "Darwin" else f"{im.module}.{im.name}"
                                       for im in ims if im.line in mk.import_lines and im.name))
            all_markers.append({"file": f, "line": mk.line, "head": mk.head, "text": mk.text, "imports": names})
        if not darwin:
            continue
        form = min((im.form if im.module == "Darwin" else "re-export" for im in darwin), key=RANK.get)
        report[f] = {
            "form": form,
            "imports": [{"line": im.line, "text": im.text, "form": im.form if im.module == "Darwin" else "re-export",
                         "module": im.module, "name": im.name,
                         "marker": im.marker.line if im.marker else None} for im in darwin],
        }
    return {"files": report, "markers": all_markers, "reexporters": sorted(reexporters), "count": len(files)}


def summary(result):
    by = collections.OrderedDict()
    for f, v in sorted(result["files"].items()):
        top = f.split("/")[0] if "/" in f else "."
        by.setdefault(top, collections.Counter())[v["form"]] += 1
    return by


def counts(c):
    return " / ".join(str(c.get(k, 0)) for k in FORMS)


def short(rev):
    return rev[:10] if rev and re.fullmatch(r"[0-9a-f]{40}", rev) else rev


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("package")
    ap.add_argument("rev", nargs="?", help="a commit of PACKAGE (default: its working tree)")
    ap.add_argument("--base", help="also count at this commit")
    ap.add_argument("--paths", help="comma-separated top-level paths to count (default: all)")
    ap.add_argument("--reexporters", default="", help="comma-separated modules that re-export Darwin")
    ap.add_argument("--markdown", action="store_true", help="print the summary tables in Markdown")
    ap.add_argument("--json", help="write the full result here")
    ap.add_argument("--quiet", action="store_true", help="only the summaries, not each file")
    a = ap.parse_args()
    root = os.path.abspath(a.package)
    if not os.path.isdir(root):
        common.fail(f"{root}: no such directory")
    if (a.rev or a.base) and not common.is_git(root):
        common.fail(f"{root} isn't a git checkout, so it has no commits to read")
    paths = [p for p in (a.paths or "").split(",") if p] or None
    extra = [m for m in a.reexporters.split(",") if m]
    now = scan(root, a.rev, paths, extra)
    base = scan(root, a.base, paths, extra) if a.base else None
    where = short(a.rev) or "working tree"
    base_name = short(a.base)

    if a.json:
        with open(a.json, "w") as h:
            json.dump({"package": root, "rev": a.rev, "now": now, "base": base, "baseRev": a.base}, h, indent=1)

    s_now = summary(now)
    s_base = summary(base) if base else {}
    areas = list(s_now) + [k for k in s_base if k not in s_now]
    gaps = collections.OrderedDict()
    for m in now["markers"]:
        head = m["head"] if len(m["head"]) <= HEAD_WIDTH else m["head"][:HEAD_WIDTH - 1] + "…"
        gaps.setdefault(head, []).append(m)
    unmarked = [(f, im) for f, v in now["files"].items() for im in v["imports"]
                if im["form"] == "scoped" and im["marker"] is None]

    if a.markdown:
        head = "| Area | " + " | ".join(LABEL[k].capitalize() for k in FORMS) + " |"
        print(f"Files importing Darwin ({where}{', against ' + base_name if base else ''}):\n")
        print(head)
        print("|---|" + "---:|" * len(FORMS))
        for top in areas:
            cells = []
            for k in FORMS:
                n = s_now.get(top, {}).get(k, 0)
                cells.append(f"{s_base.get(top, {}).get(k, 0)} → {n}" if base else str(n))
            print(f"| {top} | " + " | ".join(cells) + " |")
        if gaps:
            print("\n| SYSTEM-GAP marker | Files | Darwin names it covers |")
            print("|---|---|---|")
            for headline, ms in gaps.items():
                files = ", ".join(sorted({f"`{m['file']}`" for m in ms}))
                names = ", ".join(f"`{n}`" for n in dict.fromkeys(n for m in ms for n in m["imports"]))
                cell = headline.replace("|", "\\|")
                print(f"| {cell} | {files} | {names} |")
        return

    print(f"{os.path.basename(root)} ({where}): {now['count']} Swift files; re-exporting modules: "
          f"{', '.join(now['reexporters']) or 'none'}")
    if not a.quiet:
        for f, v in sorted(now["files"].items()):
            print(f"{v['form']:9} {f}")
            for im in v["imports"]:
                note = "" if im["form"] != "scoped" else ("  [SYSTEM-GAP]" if im["marker"] else "  [no SYSTEM-GAP marker]")
                print(f"            {im['line']}: {im['text']}{note}")
    print("--- files importing Darwin, by top-level directory (whole module / submodule / scoped only / "
          "through a re-export)"
          + (f"; {base_name} → {where}" if base else ""))
    if not areas:
        print("  none")
    for top in areas:
        line = f"  {top}: {counts(s_now.get(top, {}))}"
        if base:
            line = f"  {top}: {counts(s_base.get(top, {}))} → {counts(s_now.get(top, {}))}"
        print(line)
    print(f"--- SYSTEM-GAP markers: {len(now['markers'])} in {len({m['file'] for m in now['markers']})} files"
          + (f" ({len(base['markers'])} at {base_name})" if base else ""))
    for headline, ms in gaps.items():
        print(f"  {headline}")
        for m in ms:
            names = " ".join(m["imports"])
            print(f"      {m['file']}:{m['line']}" + (f"  {names}" if names else ""))
    if unmarked:
        print(f"--- scoped Darwin imports no SYSTEM-GAP marker covers: {len(unmarked)}")
        for f, im in unmarked:
            print(f"  {f}:{im['line']}: {im['text']}")


if __name__ == "__main__":
    main()
