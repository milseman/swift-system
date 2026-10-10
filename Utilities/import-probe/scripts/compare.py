#!/usr/bin/env python3
"""Tables of probe runs: each package's counts before and after (as
eco-nio-1's tools-en1/probe_counts.py made them), and, given a second set
of runs of the same packages, what differs between the two.

Usage: compare.py --before OUT --after OUT [--other-before OUT --other-after OUT]
                  [--label NAME --other-label NAME] [--output FILE]

Each OUT is a probe.py --out directory: OUT/<package>/<platform>.json and
<platform>-reexport.json. A cell is `sites (distinct names): classes`; `-`
means no run, `0` a run that found nothing. With a second set, each
package's cells are compared: the sites (file, line, name) and names only
one set has, and the names the two classify differently. A cell also lists
the names --own-modules found through the package's own C modules, which
the first set's runs may have and the second's not.

Only reads the JSON files; writes the Markdown to --output, or prints it.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402

KINDS = [("macos", "macOS"), ("linux", "Linux"), ("macos-reexport", "re-export, macOS"),
         ("linux-reexport", "re-export, Linux")]


def load(out, package, kind):
    if not out:
        return None
    p = os.path.join(out, package, f"{kind}.json")
    if not os.path.isfile(p):
        return None
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def packages(*outs):
    names = set()
    for out in outs:
        if out and os.path.isdir(out):
            names |= {d for d in os.listdir(out) if os.path.isdir(os.path.join(out, d))}
    return sorted(names)


def cell(doc):
    if doc is None:
        return "-"
    recs = doc["records"]
    if not recs:
        return "0"
    by = collections.Counter(r["class"] for r in recs)
    return f"{len(recs)} ({len({r['name'] for r in recs})}): " + ", ".join(f"{n} {c}" for c, n in by.most_common())


def own(doc):
    om = (doc or {}).get("ownModules")
    if om is None:
        return None
    return om["records"]


def differences(a, b):
    """What differs between two runs' records, as Markdown fragments, [] if
    nothing does."""
    if a is None or b is None:
        return []
    sa = collections.Counter((r["file"], r["line"], r["name"]) for r in a["records"])
    sb = collections.Counter((r["file"], r["line"], r["name"]) for r in b["records"])
    na, nb = {r["name"] for r in a["records"]}, {r["name"] for r in b["records"]}
    ca = {r["name"]: r["class"] for r in a["records"]}
    cb = {r["name"]: r["class"] for r in b["records"]}
    out = []
    if na - nb:
        out.append("names only the first has: " + ", ".join(f"`{n}`" for n in sorted(na - nb)))
    if nb - na:
        out.append("names only the second has: " + ", ".join(f"`{n}`" for n in sorted(nb - na)))
    only_a, only_b = sa - sb, sb - sa
    if only_a or only_b:
        def sites(c):
            items = sorted(c.elements())
            return ", ".join(f"`{f}:{line}` `{n}`" for f, line, n in items[:12]) + (
                f" and {len(items) - 12} more" if len(items) > 12 else "")
        if only_a:
            out.append(f"sites only the first has ({sum(only_a.values())}): {sites(only_a)}")
        if only_b:
            out.append(f"sites only the second has ({sum(only_b.values())}): {sites(only_b)}")
    moved = sorted(n for n in na & nb if ca[n] != cb[n])
    if moved:
        out.append("classified differently: " + ", ".join(f"`{n}` ({ca[n]} / {cb[n]})" for n in moved))
    return out


def table(w, before, after, title):
    names = packages(before, after)
    w(f"## {title}")
    w("")
    w("Sites (distinct names): classes. `-` is no run, `0` a run that found nothing.")
    w("")
    w("| Package | macOS before | macOS after | Linux before | Linux after | Re-export before (Linux) | "
      "Re-export after (Linux) |")
    w("|---|---|---|---|---|---|---|")
    for pkg in names:
        row = [cell(load(o, pkg, k)) for k in ("macos", "linux") for o in (before, after)]
        row += [cell(load(o, pkg, "linux-reexport")) for o in (before, after)]
        w(f"| {pkg} | " + " | ".join(row) + " |")
    w("")
    rows = []
    for pkg in names:
        for k, label in KINDS[:2]:
            for phase, o in (("before", before), ("after", after)):
                recs = own(load(o, pkg, k))
                if recs is not None:
                    by = collections.defaultdict(set)
                    for r in recs:
                        by[r["file"]].add(r["name"])
                    rows.append(f"| {pkg} | {label} {phase} | {len(recs)} ({len({r['name'] for r in recs})}) | "
                                + ("; ".join(f"`{f}`: {', '.join(sorted(v))}" for f, v in sorted(by.items())) or "—")
                                + " |")
    if rows:
        w("Names through the package's own C modules (`--own-modules`):")
        w("")
        w("| Package | Run | Sites (names) | By file |")
        w("|---|---|---|---|")
        for r in rows:
            w(r)
        w("")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--before", required=True)
    ap.add_argument("--after", required=True)
    ap.add_argument("--other-before")
    ap.add_argument("--other-after")
    ap.add_argument("--label", default="these runs")
    ap.add_argument("--other-label", default="the other runs")
    ap.add_argument("--output")
    a = ap.parse_args()
    lines = []
    w = lines.append
    w("# import-probe: runs compared")
    w("")
    table(w, a.before, a.after, a.label)
    if a.other_before or a.other_after:
        table(w, a.other_before, a.other_after, a.other_label)
        w(f"## Differences: the first is {a.label}, the second {a.other_label}")
        w("")
        for pkg in packages(a.before, a.after, a.other_before, a.other_after):
            for phase, mine, theirs in (("before", a.before, a.other_before), ("after", a.after, a.other_after)):
                for k, label in KINDS:
                    x, y = load(mine, pkg, k), load(theirs, pkg, k)
                    if x is None and y is None:
                        continue
                    if x is None or y is None:
                        w(f"- **{pkg}, {label} {phase}**: only {'the second' if x is None else 'the first'} has a run.")
                        continue
                    d = differences(x, y)
                    mx, my = x["meta"], y["meta"]
                    commits = "" if mx["commit"] == my["commit"] else \
                        f" (commits `{mx['commit'][:10]}` / `{my['commit'][:10]}`)"
                    systems = "" if mx.get("system") == my.get("system") else \
                        f" (System `{(mx.get('system') or '')[:10]}` / `{(my.get('system') or '')[:10]}`)"
                    w(f"- **{pkg}, {label} {phase}**{commits}{systems}: " + ("; ".join(d) if d else "the same."))
        w("")
    text = "\n".join(lines).rstrip() + "\n"
    if a.output:
        with open(a.output, "w", encoding="utf-8") as f:
            f.write(text)
        print(a.output)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
