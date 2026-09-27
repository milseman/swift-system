#!/usr/bin/env python3
"""Edit mapping.ini's sections in place, keeping its layout.

A helper for whoever maps: move symbols between entries, add keys to an
entry, or add entries before a section heading, without reformatting the
rest of the file.

  import mapping_edit as m
  ini = m.Mapping("Utilities/adopter-coverage/mapping.ini")
  ini.remove_symbols("rename with options", ["syscall"])
  ini.add_symbols("errno values", ["ECHILD"])
  ini.set_key("Dispatch", "wrap", "no")
  ini.add_entry(TEXT, before="[read]")       # or after="[close]"
  ini.save()

As a command, `prune` drops the hand statuses a derivation makes
redundant, from check.py's coverage.json for every package that uses the
entries:

  mapping_edit.py prune MAPPING.ini COVERAGE.json...

A hand status goes when the derivation reaches the same status on every
platform each package uses the entry on (its `system` citations go with
it), and a hand `missing` goes when the derivation finds System's API for
the entry: the hand status is stale. Hand statuses the derivation doesn't
reproduce stay, as overrides, and are printed with the reason.
"""

import collections
import json
import re
import sys


class Mapping:
    def __init__(self, path):
        self.path = path
        self.text = open(path, encoding="utf-8").read()

    def _span(self, name):
        m = re.search(r"^\[" + re.escape(name) + r"\]\n", self.text, flags=re.M)
        if not m:
            raise KeyError(name)
        end = re.search(r"^(\[|# =)", self.text[m.end():], flags=re.M)
        stop = m.end() + end.start() if end else len(self.text)
        # Trailing blank lines belong between entries.
        body = self.text[m.start():stop]
        body_stripped = body.rstrip("\n") + "\n"
        return m.start(), m.start() + len(body_stripped)

    def section(self, name):
        a, b = self._span(name)
        return self.text[a:b]

    def _replace(self, name, new):
        a, b = self._span(name)
        self.text = self.text[:a] + new + self.text[b:]

    def symbols(self, name):
        sec = self.section(name)
        m = re.search(r"^symbols = (.*(?:\n[ \t]+.*)*)", sec, flags=re.M)
        return m.group(1).split() if m else [name]

    def _set_symbols(self, name, syms):
        sec = self.section(name)
        line = "symbols = " + " ".join(syms)
        if re.search(r"^symbols = ", sec, flags=re.M):
            sec = re.sub(r"^symbols = .*(?:\n[ \t]+.*)*", lambda _m: line, sec, count=1, flags=re.M)
        else:
            sec = re.sub(r"^(\[[^\]]+\]\n)", lambda m_: m_.group(1) + line + "\n", sec, count=1)
        self._replace(name, sec)

    def remove_symbols(self, name, syms):
        cur = self.symbols(name)
        missing = [s for s in syms if s not in cur]
        if missing:
            raise ValueError(f"[{name}] has no {missing}")
        self._set_symbols(name, [s for s in cur if s not in syms])

    def add_symbols(self, name, syms):
        cur = self.symbols(name)
        self._set_symbols(name, cur + [s for s in syms if s not in cur])

    def set_key(self, name, key, value):
        """Set a one-line or continued key: value may hold newlines, indented
        by four spaces after the first."""
        sec = self.section(name)
        lines = value.split("\n")
        text = (f"{key} =" if lines[0] == "" else f"{key} = {lines[0]}") + "".join("\n    " + x for x in lines[1:])
        pat = r"^" + re.escape(key) + r" =(?: .*)?(?:\n[ \t]+.*)*"
        if re.search(pat, sec, flags=re.M):
            sec = re.sub(pat, lambda _m: text, sec, count=1, flags=re.M)
        else:
            sec = sec.rstrip("\n") + "\n" + text + "\n"
        self._replace(name, sec)

    def remove_key(self, name, key):
        """Remove a key, with its continuation lines, if the entry has it."""
        sec = self.section(name)
        pat = r"^" + re.escape(key) + r" =(?: .*)?\n(?:[ \t]+.*\n?)*"
        self._replace(name, re.sub(pat, "", sec, count=1, flags=re.M))

    def add_system(self, name, decls):
        """Append System declarations to an entry's `system` key."""
        sec = self.section(name)
        m = re.search(r"^system =\n((?:[ \t]+.*\n?)*)", sec, flags=re.M)
        cur = [x.strip() for x in m.group(1).split("\n") if x.strip()] if m else []
        self.set_key(name, "system", "\n" + "\n".join(cur + [d for d in decls if d not in cur]))

    def add_entry(self, text, before=None, after=None):
        text = text.strip("\n") + "\n\n"
        if before:
            k = self.text.index(before + "\n") if before.startswith("#") else self._span(before[1:-1])[0]
            self.text = self.text[:k] + text + self.text[k:]
        elif after:
            _a, b = self._span(after[1:-1])
            self.text = self.text[:b] + "\n" + text.rstrip("\n") + "\n" + self.text[b:]
        else:
            self.text = self.text.rstrip("\n") + "\n\n" + text

    def save(self):
        open(self.path, "w", encoding="utf-8").write(re.sub(r"\n{3,}", "\n\n", self.text))


def prune(mapping, coverages):
    """(dropped, kept): entry ids with the reason for each."""
    views = collections.defaultdict(list)
    for path in coverages:
        cov = json.load(open(path))
        for e in cov["entries"]:
            if e.get("used") and e.get("hand") and e["hand"] != "ignore":
                views[e["id"]].append((cov["package"]["key"], e))
    ini = Mapping(mapping)
    dropped, kept = [], []
    for eid, seen in sorted(views.items()):
        hand = seen[0][1]["hand"]
        # The hand status per platform is where its cited API is built;
        # compare that with the derivation's.
        diff = {(k, p): v for k, e in seen for p, v in e.get("disagree", {}).items()}
        found = any(d["status"] in ("covered", "partial") for _k, e in seen for d in e["derived"].values())
        if not diff or (hand == "missing" and found):
            ini.remove_key(eid, "status")
            ini.remove_key(eid, "system")
            dropped.append((eid, hand, "agrees" if not diff else "stale: " + ", ".join(
                sorted({f"{k} {p} {v['derived']}" for (k, p), v in diff.items()})[:6])))
        else:
            kept.append((eid, hand, "; ".join(sorted({f"{k} {p}: {v['hand']} vs derived {v['derived']} ({v['reason']})"
                                                      for (k, p), v in diff.items()}))[:400]))
    ini.save()
    return dropped, kept


if __name__ == "__main__":
    if len(sys.argv) < 4 or sys.argv[1] != "prune":
        sys.exit(__doc__)
    dropped, kept = prune(sys.argv[2], sys.argv[3:])
    for eid, hand, why in dropped:
        print(f"dropped [{eid}] status = {hand}: {why}")
    for eid, hand, why in kept:
        print(f"kept    [{eid}] status = {hand}: {why}")
    print(f"{len(dropped)} hand statuses dropped, {len(kept)} kept")
