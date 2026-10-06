#!/usr/bin/env python3
"""Write the master view's page from master.json: one HTML file with its
CSS, JavaScript and data inline (page.html, page.css, model.js, ui.js in
this directory), which makes no network request and works opened as a file.

The data is a compact form of master.json (`encode`): a string table, and
arrays for the declarations, their uses and the ledger's sites. The page
records master.json's digest, which `check.py` compares.

Usage: page.py MASTER_JSON PAGE_HTML
"""

import sys

sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_BYTES = 8_000_000
PLATFORMS = ("Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows")
FLAG_BITS = ("outside", "stub", "deprecated", "underscored", "spi", "overload", "upstream", "pitches",
             "unexplained", "nograph", "hidden")
CLUSTERS = ("update-checkout", "swiftlang and apple", "ecosystem", "Unix tools")
KINDS = ("migrated", "scanned", "not-scanned", "no-swift")
CATEGORIES = ("unexplained", "System gap", "queued", "exception", "undecided", "not System's", "standard library")
HOW = {"p": 0, "l": 1, "q": 2}


class Strings:
    def __init__(self):
        self.table, self.index = [], {}

    def __call__(self, s):
        if s is None:
            return -1
        s = str(s)
        k = self.index.get(s)
        if k is None:
            k = self.index[s] = len(self.table)
            self.table.append(s)
        return k


def plat_mask(ps):
    m = 0
    for p in ps or []:
        if p in PLATFORMS:
            m |= 1 << PLATFORMS.index(p)
    return m


def flag_mask(d):
    names = set(d.get("flags") or [])
    if d.get("excluded"):
        names.add("outside")
    if d.get("origin") == "scan":
        names.add("hidden")
    m = 0
    for i, f in enumerate(FLAG_BITS):
        if f in names:
            m |= 1 << i
    return m


def encode(master):
    S = Strings()
    areas, area_index = [], {}
    D, U = [], []
    for i, d in enumerate(master["declarations"]):
        akey = (d["area"], d["module"])
        if akey not in area_index:
            area_index[akey] = len(areas)
            name = d["area"].split("/", 1)[1] if "/" in d["area"] else d["area"]
            areas.append([S(name), S(d["module"])])
        D.append([S(d["path"]), S(d["kindName"]), area_index[akey], S(d["type"]), d["state"], S(d.get("pitch")),
                  flag_mask(d), plat_mask(d.get("platforms")), S(d.get("file")), d.get("line") or 0,
                  S(d.get("availability") or ""), S(d.get("decl") or ""), S(d.get("doc") or ""),
                  S(d.get("cName")), d["sameAs"] if d.get("sameAs") is not None else -1, S(d["module"])])
        for pi, sites in d["usedBy"]:
            U.append([i, pi, [[S(s[0]), s[1], s[2], HOW[s[3]], S(s[4])] for s in sites]])
    P = []
    for p in master["packages"]:
        rec = {"n": p["name"], "c": CLUSTERS.index(p["cluster"]), "k": KINDS.index(p["kind"]), "s": p["source"],
               "r": p.get("remote") or "", "cl": p.get("clone"), "sw": p.get("swift"), "no": p.get("note") or ""}
        mig = p.get("migration")
        if mig:
            nw, rd = mig["newest"], mig.get("readAt")
            rec["mig"] = {"nb": nw["branch"], "nc": nw["commit"], "nn": nw["commits"], "ns": nw.get("subject"),
                          "br": mig["branches"], "rb": rd["branch"] if rd else None,
                          "rc": rd["commit"] if rd else None, "rr": rd.get("resolution") if rd else None,
                          "rs": rd.get("subject") if rd else None, "bs": rd.get("build") if rd else None}
        u = p.get("usage")
        if u:
            rec["use"] = {"b": u.get("branch"), "c": u.get("commit"), "res": u.get("resolution"),
                          "link": u.get("link"), "cache": bool(u.get("cache")),
                          "main": [[S(m["path"]), 1 if m.get("changed") else 0,
                                    [[S(s[0]), s[1], s[2]] for s in m["sites"]]] for m in u.get("main") or []]}
        c = p.get("cUse")
        if c:
            src = c["source"]
            if src == "ledger" and c.get("notRead") and not c.get("sites"):
                rec["cu"] = {"src": "ledger", "notRead": c["notRead"]}
            elif src == "ledger":
                rec["cu"] = {"src": "ledger", "where": c.get("where"), "commit": c.get("commit"),
                             "link": c.get("link"), "partial": c.get("partial"), "scope": c.get("scope"),
                             "lacks": c.get("lacks") or [],
                             "sites": [[S(s["file"]), s["line"], S(s.get("module")), CATEGORIES.index(s["category"]),
                                        plat_mask(s["platforms"]), [S(n) for n in s["names"]],
                                        [S(n) for n in s["lacks"]], S(s["reason"]), S(s.get("text")),
                                        S(s.get("type")), S(s.get("importKind"))] for s in c["sites"]]}
            elif src == "scan":
                run = c.get("run")
                rec["cu"] = {"src": "scan", "files": c.get("files"), "fileList": [S(f) for f in c.get("fileList") or []],
                             "commit": c.get("commit"), "link": c.get("link"), "date": c.get("surveyDate"),
                             "scan": c.get("scan"),
                             "run": [run["id"], run["date"], run["systemCommit"], run.get("extraction")] if run else None,
                             "names": [[S(x["name"]), S(x["kind"]), x["sites"], [S(f) for f in x["files"]]]
                                       for x in c.get("names") or []]}
            elif src == "GAPS.md":
                rec["cu"] = {"src": "GAPS.md", "commit": c.get("commit"),
                             "gaps": [[S(g.get("what") or ", ".join(g["names"])), S(g["where"]), S(g["platforms"]),
                                       S(g["note"])] for g in c.get("gaps") or []]}
        P.append(rec)
    meta = dict(master["meta"])
    return {"v": 1, "digest": master.get("digest"), "meta": meta, "S": S.table, "A": areas, "D": D, "U": U,
            "P": P, "charts": master["charts"], "notes": master["notes"]}


def script_json(obj):
    """JSON for a <script type="application/json"> element: `</` can't end it."""
    text = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
    return text.replace("</", "<\\/").replace("<!--", "<\\!--")


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def render(master):
    """The page: page.html with each placeholder replaced once, in one pass
    over the template, so that no inserted text is searched again."""
    parts = {"/*CSS*/": read("page.css"), "/*MODEL*/": read("model.js"), "/*UI*/": read("ui.js"),
             "/*DATA*/": script_json(encode(master))}
    page = read("page.html")
    pattern = re.compile("|".join(re.escape(k) for k in parts))
    found = pattern.findall(page)
    if sorted(found) != sorted(parts):
        raise SystemExit(f"page.py: page.html should have each of {', '.join(parts)} once; it has {found}")
    return pattern.sub(lambda m: parts[m.group(0)], page)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        master = json.load(f)
    page = render(master)
    size = len(page.encode())
    if size > MAX_BYTES:
        raise SystemExit(f"page.py: the page would be {size} bytes, over {MAX_BYTES}")
    os.makedirs(os.path.dirname(os.path.abspath(sys.argv[2])), exist_ok=True)
    tmp = sys.argv[2] + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(page)
    os.replace(tmp, sys.argv[2])
    print(f"page: {size:,} bytes -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
