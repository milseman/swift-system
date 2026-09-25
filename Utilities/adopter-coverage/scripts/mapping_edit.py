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
"""

import re


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
