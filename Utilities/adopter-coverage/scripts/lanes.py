#!/usr/bin/env python3
"""Which System lane should take a gap.

mapping.ini's [config] `lanes` key lists rules, one per line, `WHAT: lane`,
the first that matches deciding:
  symbol REGEX       one of the entry's symbols matches REGEX in full
  category NAME      the entry's category
  only PLATFORM...   every platform the gap is on is one of these
  default            anything
A lane of `-` means no lane takes it (Windows-only gaps, with no Windows
lane), and the report says why after the dash: `- (Windows)`.

Usage (as a module): lanes.load(mapping), lanes.assign(gap_row, rules)
"""

import sys

sys.dont_write_bytecode = True

import configparser
import re


def load(mapping):
    cp = configparser.ConfigParser(interpolation=None, delimiters=("=",), comment_prefixes=("#",),
                                   inline_comment_prefixes=None, strict=True, empty_lines_in_values=False,
                                   default_section="__none__")
    cp.optionxform = str
    cp.read(mapping, encoding="utf-8")
    text = cp.get("config", "lanes", fallback="")
    rules = []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue
        what, _, lane = line.rpartition(":")
        what, lane = what.strip(), lane.strip()
        kind, _, arg = what.partition(" ")
        if kind not in ("symbol", "category", "only", "default"):
            raise SystemExit(f"mapping.ini: bad lane rule {line!r}")
        rules.append((kind, arg.strip(), lane))
    return rules


def assign(row, rules):
    """The lane for a gap row: {"symbols", "category", "platforms": {pkg: [platform]}}."""
    plats = {p for ps in row.get("platforms", {}).values() for p in ps}
    for kind, arg, lane in rules:
        if kind == "symbol" and any(re.fullmatch(arg, s) for s in row.get("symbols", [])):
            return lane
        if kind == "category" and row.get("category") == arg:
            return lane
        if kind == "only" and plats and plats <= set(arg.split()):
            return lane
        if kind == "default":
            return lane
    return "?"
