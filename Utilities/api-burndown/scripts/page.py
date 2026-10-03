#!/usr/bin/env python3
"""Write the self-contained burn-down page from burndown.json.

The page is one HTML file: page.css, page.js and a compact form of the
data, all inline. It makes no network request: it has no external
scripts, styles, fonts or images, and it works opened as a file.

Usage: page.py BURNDOWN.json OUT.html
"""

import sys

sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
ROLES = ["subject", "alternative", "argument"]
LIMIT = 5_000_000


class Strings:
    def __init__(self):
        self.index, self.items = {}, []

    def __call__(self, s):
        if s is None:
            return -1
        if s not in self.index:
            self.index[s] = len(self.items)
            self.items.append(s)
        return self.index[s]


def compact(data):
    S = Strings()
    flags = list(data["flags"])
    fbit = {f: 1 << i for i, f in enumerate(flags)}

    def pmask(ps):
        m = 0
        for p in ps or []:
            if p in PLATFORMS:
                m |= 1 << PLATFORMS.index(p)
        return m

    def fmask(fs):
        m = 0
        for f in fs or []:
            m |= fbit.get(f, 0)
        return m

    rows = []
    for u in data["declarations"]:
        rows.append([
            u["state"], fmask(u["flags"]), S(u["module"]), u["path"], S(u["kindName"]), S(u["area"]),
            S(u["file"]), u["line"] or 0, pmask(u["platforms"]), S(u["pitch"]),
            [S(p) for p in u["pitches"][1:]], S(u["cName"]), S(u["header"]), S(u["sdkModule"]),
            S(u["sdkSubmodule"]), u["decl"], S(u["availability"]), u["docSummary"],
            [[S(x["package"]), [[S(s[0]), s[1] or 0, s[2] or 0, 1 if s[3] == "precise" else 0] for s in x["sites"]]]
             for x in u["usedBy"]],
            u["couldUse"], [[S(c["name"]), ROLES.index(c["role"]) if c["role"] in ROLES else 0,
                             1 if c["restricted"] else 0, 1 if c.get("code") else 0] for c in u["cNames"]],
            S(u["headerHow"]), 1 if u["excluded"] else 0, 1 if u.get("cNameFromCode") else 0,
        ])
    # Declarations merged by now: in the list and the groups, as merged.
    for g in data["merged"]:
        rows.append([
            5, fmask(g.get("flags")), S(g["module"]), g["path"], S(g.get("kindName")), S(g.get("area")),
            S(g.get("file")), g.get("line") or 0, pmask(g.get("platforms")), -1, [], -1, -1, -1, -1,
            g.get("decl") or "", -1, "", [], 0, [], -1, 1 if g.get("excluded") else 0, 0,
        ])
    # The days' history isn't on the page: it shows what the lanes added each
    # day, not what landed. It still decides what's merged.
    m = data["meta"]
    meta = {
        "generated": m["generated"], "baseRef": m["baseRef"], "baseCommit": m["baseCommit"],
        "baseSubject": m["baseSubject"], "headRef": m["headRef"], "headCommit": m["headCommit"],
        "headSubject": m["headSubject"],
        "graph": {k: m["graph"].get(k) for k in ("headCommit", "date", "matchesHead", "source", "unitsWithoutNode")},
        "pitchFiles": m["pitches"]["files"], "pitchesDirty": m["pitches"]["dirty"],
        "pitchProblems": m["pitches"]["problems"],
        "states": m["states"]["entries"], "stateProblems": m["states"]["problems"],
        "unknownPitches": m["states"]["unknownPitches"],
        "upstream": m["upstream"], "sdkVersion": m["headers"]["sdkVersion"],
        "vocab": os.path.basename(m["headers"]["vocab"] or ""),
        "apiDelta": {k: m["apiDelta"][k] for k in ("added", "hidden", "date", "swift")},
        "tool": m["tool"], "storeCommits": [c[:10] for c in data["history"]["storeCommits"]],
    }
    return {
        "digest": data["digest"], "meta": meta, "states": data["states"], "flags": flags,
        "flagText": data["flags"], "excluded": data["excludedFlags"], "platforms": PLATFORMS, "roles": ROLES,
        "S": S.items, "D": rows, "totals": data["totals"],
    }


def main():
    src, out = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        data = json.load(f)
    page = compact(data)
    blob = json.dumps(page, separators=(",", ":"), ensure_ascii=False)
    # Inline <script>: keep "</" from closing it.
    blob = blob.replace("</", "<\\/")

    def read(name):
        with open(os.path.join(HERE, name), encoding="utf-8") as f:
            return f.read()

    html = read("page.html")
    html = html.replace("/*PAGE_CSS*/", read("page.css"))
    html = html.replace("/*PAGE_JS*/", read("page.js"))
    html = html.replace("/*PAGE_DATA*/", blob)
    html = html.replace("<!--PAGE_TITLE-->", f"System API burn-down, {data['meta']['generated']}")
    size = len(html.encode("utf-8"))
    if size >= LIMIT:
        sys.exit(f"page: {size} bytes, over the {LIMIT}-byte limit")
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(html)
    os.replace(tmp, out)
    print(f"page: {size / 1e6:.2f} MB -> {out}")


if __name__ == "__main__":
    main()
