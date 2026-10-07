#!/usr/bin/env python3
"""Write a carve-out bundle for each cluster, ranked part, and batch.

A bundle is the input an AI pitch-writing session needs for one carve-out,
self-contained so the session doesn't have to search the repository:

  bundle.md    the brief: what's in it, the open questions it depends on,
               what it needs first, its declarations with their C
               counterparts, source ranges, tests, samples, and prior text
               (proposals, prototype write-ups, Win32 drafts, and the
               commits that wrote the code, whose bodies in this repository
               already discuss shape, naming and precedent)
  bundle.json  the same data, machine-readable
  sources.md   the code: every block of the carve-out's API, and the new
               internal declarations and C shims it needs
  tests.md     the test functions that exercise it
  samples.md   the samples that use it

It isn't a pitch and doesn't draft one; `Proposals/` has the house format.

Usage: bundles.py --graph graph.json --clusters clusters.json --root DIR
                  --repo DIR --base COMMIT --head COMMIT --out DIR
                  [--drafts DIR]
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
import reach  # noqa: E402

PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]
MAX_TESTS_MD = 60          # test functions quoted in tests.md
MAX_COMMITS_FULL = 6       # commit messages quoted in full
MAX_SAMPLES_MD = 8         # samples quoted in samples.md
MAX_ADOPTED_MD = 30        # adopted sites listed per package in bundle.md (adopters.md has all)
MAX_HUNKS_MD = 6           # hunks quoted per package in bundle.md
MAX_HUNK_LINES = 40        # a longer hunk is quoted around its sites
MAX_BENEFIT_MD = 30        # would-benefit sites listed per package in bundle.md


def load(p):
    return json.load(open(p))


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True).stdout


def md_code(s):
    s = s.replace("`", "'")
    return f"`{s}`"


def fence_lang(path):
    return "swift" if path.endswith(".swift") else "c" if path.endswith((".c", ".h")) else ""


def platform_text(ps):
    ps = [p for p in PLATFORMS if p in (ps or [])]
    return ", ".join(ps) if ps else "?"


class Source:
    def __init__(self, root):
        self.root = root
        self.cache = {}

    def lines(self, rel):
        if rel not in self.cache:
            p = os.path.join(self.root, rel)
            self.cache[rel] = open(p, encoding="utf-8", errors="replace").read().split("\n") if os.path.exists(p) else []
        return self.cache[rel]

    def excerpt(self, rel, start, end):
        return "\n".join(self.lines(rel)[start - 1:end])


def merge_ranges(ranges):
    """[(file, start, end, label)] -> merged per file, labels joined."""
    by_file = collections.defaultdict(list)
    for f, s, e, label in ranges:
        by_file[f].append([s, e, [label]])
    out = []
    for f in sorted(by_file):
        rs = sorted(by_file[f])
        merged = [rs[0]]
        for s, e, labels in rs[1:]:
            if s <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], e)
                merged[-1][2] += [l for l in labels if l not in merged[-1][2]]
            else:
                merged.append([s, e, labels])
        out += [(f, s, e, labels) for s, e, labels in merged]
    return out


def plural(n, word):
    return f"{n} {word}{'' if n == 1 else 's'}"


def cell(s):
    """Code in a table cell: backticks and pipes can't appear inside."""
    return "`" + s.replace("`", "'").replace("|", "\\|") + "`"


def hunk_excerpt(h, site_lines, context=5, limit=MAX_HUNK_LINES):
    """A hunk's lines, header first; a long one only within `context` lines
    of its sites, with the rest elided."""
    lines = h["lines"]
    if len(lines) <= limit:
        return [h["header"]] + lines
    nums, n = [], h["newStart"]
    for line in lines:
        nums.append(n)
        if not line.startswith("-"):
            n += 1
    keep = [i for i, num in enumerate(nums) if any(abs(num - x) <= context for x in site_lines)]
    out, last = [h["header"]], -1
    for i in keep:
        if i != last + 1:
            out.append(f"… ({i - last - 1} lines)")
        out.append(lines[i])
        last = i
    if last != len(lines) - 1:
        out.append(f"… ({len(lines) - 1 - last} lines)")
    return out


def adopters_data(agg, adopters, nodes, nids):
    """The bundle.json form of a carve-out's adopters."""
    info = {p["key"]: p for p in adopters["packages"]}
    names = {"joined": set(), "baseCovered": set(), "restricted": set()}
    for nid in nids:
        cn = adopters["cNames"].get(nid) or {}
        names["joined"] |= set(cn.get("names", []))
        names["baseCovered"] |= set(cn.get("baseCovered", []))
        names["restricted"] |= set(cn.get("restricted", []))
    pkgs = []
    for key, v in agg["packages"].items():
        p = info.get(key, {"key": key, "name": key})
        rec = {"key": key, "name": p["name"], "remote": p.get("remote")}
        if v["adopted"] or v["qualifiers"]:
            ad = p.get("adopted") or {}
            hids = list(dict.fromkeys(s["hunk"] for s in v["adopted"] if s["hunk"]))
            rec["adopted"] = {
                "branch": ad.get("branch"), "commit": ad.get("commit"), "subject": ad.get("subject"),
                "base": ad.get("base"), "mainRef": ad.get("mainRef"), "resolution": ad.get("resolution"),
                "build": (ad.get("build") or {}).get("status"),
                "declarationsUsed": sorted(nodes[x]["path"] for x in v["declarationsUsed"]),
                "qualifiers": v["qualifiers"],
                "sites": [dict(s, declaration=nodes[s["node"]]["path"]) for s in v["adopted"]],
                "hunks": [dict(adopters["hunks"][h], id=h) for h in hids],
            }
        if v["benefit"]:
            b = p.get("benefit") or {}
            rec["benefit"] = {
                "commit": b.get("commit"), "subject": b.get("subject"), "role": b.get("role"),
                "source": b.get("source"), "extraction": b.get("extraction"), "result": b.get("result"),
                "interfaces": dict(v["interfaces"].most_common()),
                "sites": [dict(s, declarations=sorted(nodes[x]["path"] for x in s["nodes"] if x in set(nids)))
                          for s in v["benefit"]],
            }
        pkgs.append(rec)
    return {"reach": agg["reach"], "using": agg["using"], "benefiting": agg["benefiting"],
            "cNames": {k: sorted(v) for k, v in names.items()}, "packages": pkgs}


def also_uses(adopters, hunk_id, mine, owners, nodes):
    """The other new declarations a hunk uses, by the pitch that owns each
    ("no pitch" for none), for a pitch bundle's adopter examples."""
    by = collections.defaultdict(set)
    for s in adopters["adoptedSites"]:
        if s["hunk"] == hunk_id and not s["qualifier"] and s["node"] not in mine:
            for o in owners.get(s["node"]) or ["no pitch yet"]:
                by[o].add(nodes[s["node"]]["path"] if s["node"] in nodes else s["node"])
    return by


def adopters_md(w, data, adopters, full=False, owners=None, mine=None, nodes=None):
    """The Adopters section of bundle.md, or (full) all of adopters.md. With
    owners (a pitch bundle's), each hunk says what else it uses, and which
    pitch has it."""
    meta = adopters["meta"]
    branch = reach.branch_words(meta)
    info = {p["key"]: p for p in adopters["packages"]}
    n_migrated = sum(1 for p in adopters["packages"] if p["adopted"])
    n_data = sum(1 for p in adopters["packages"] if p["benefit"])
    pk = data["packages"]
    w(f"{len(data['using'])} of the {n_migrated} packages read on their {branch} use this carve-out's "
      f"declarations, and {len(data['benefiting'])} of the {n_data} packages with C interface data call C "
      "interfaces it newly wraps."
      + ("" if full else " `adopters.md` lists every site and quotes every hunk."))
    w("")
    cn = data["cNames"]
    if cn["joined"] or cn["baseCovered"] or cn["restricted"]:
        w("C names its doc comments give, joined with the packages' C interfaces: "
          + (", ".join(f"`{x}`" for x in cn["joined"][:30]) or "none")
          + (f", and {len(cn['joined']) - 30} more" if len(cn["joined"]) > 30 else "") + "."
          + (" Left out because the base commit already covers them: "
             + ", ".join(f"`{x}`" for x in cn["baseCovered"][:20]) + "." if cn["baseCovered"] else "")
          + (" Left out because the declaration covers only one use of them: "
             + ", ".join(f"`{x}`" for x in cn["restricted"][:20]) + "." if cn["restricted"] else ""))
    else:
        w("Its doc comments give no C names, so no package's C interfaces can be joined with it.")
    w("")
    if not pk:
        return
    w("| Package | Uses on the branch read | Declarations used | Would benefit | C interfaces |")
    w("|---|---:|---:|---:|---|")
    for p in pk:
        ad, be = p.get("adopted"), p.get("benefit")
        uses = "—"
        if ad and ad["sites"]:
            prec = sum(1 for s in ad["sites"] if s["resolution"] == "precise")
            uses = f"{len(ad['sites'])} ({prec} precise)"
        elif ad:
            uses = f"qualifier only ({ad['qualifiers']})"
        ben = "—"
        itf = "—"
        if be:
            prec = sum(1 for s in be["sites"] if s["resolution"] == "precise")
            ben = f"{len(be['sites'])} ({prec} precise)"
            itf = ", ".join(f"`{k}` ×{v}" for k, v in list(be["interfaces"].items())[:5]) + (
                f", +{len(be['interfaces']) - 5}" if len(be["interfaces"]) > 5 else "")
        w(f"| `{p['name']}` | {uses} | {len(ad['declarationsUsed']) if ad else 0} | {ben} | {itf} |")
    w("")
    for p in pk:
        ad, be = p.get("adopted"), p.get("benefit")
        w(f"{'###' if not full else '##'} `{p['name']}`")
        w("")
        if ad and ad["sites"]:
            pinfo = info.get(p["key"], {}).get("adopted") or {}
            how = {"index": "the index of a build against this head commit",
                   "partial index": "the index of a build against this head commit that failed partway "
                                    f"({(pinfo.get('build') or {}).get('reason') or ''}); lexical where it has no record",
                   "lexical": "lexical matching: the build didn't run or failed "
                              f"({(pinfo.get('build') or {}).get('reason') or ''})"}.get(ad["resolution"], ad["resolution"])
            since = ("all its own: the examples, written on System" if pinfo.get("examples") else
                     f"{pinfo.get('commits', '?')} commit{'s' if pinfo.get('commits') != 1 else ''} past "
                     f"`{ad['mainRef']}` @ `{(ad['base'] or '')[:10]}`")
            w(f"**Adopted** on `{ad['branch']}` @ `{(ad['commit'] or '')[:10]}` ({since}): "
              f"{plural(len(ad['sites']), 'site')} using {plural(len(ad['declarationsUsed']), 'declaration')}, "
              f"resolved by {how}"
              + (f"; {ad['qualifiers']} more only name a type to qualify a nested one" if ad["qualifiers"] else "")
              + ".")
            w("")
            limit = None if full else MAX_ADOPTED_MD
            w("| Site | Declaration | | Code |")
            w("|---|---|---|---|")
            for s in ad["sites"][:limit]:
                flag = s["resolution"] + ("" if s["introduced"] else ", line not added by the migration")
                w(f"| `{s['file']}:{s['line']}` | {cell(s['declaration'])} | {flag} | {cell(s['text'][:120])} |")
            if limit and len(ad["sites"]) > limit:
                w(f"| … and {len(ad['sites']) - limit} more | | | |")
            w("")
            hunks = ad["hunks"] if full else ad["hunks"][:MAX_HUNKS_MD]
            if hunks:
                w("The hunks of the migration that introduced them"
                  + ("" if full or len(ad["hunks"]) <= MAX_HUNKS_MD else
                     f" (the first {MAX_HUNKS_MD} of {len(ad['hunks'])})") + ":")
                w("")
                for h in hunks:
                    lines_here = sorted({s["line"] for s in ad["sites"] if s["hunk"] == h["id"]})
                    w(f"`{h['file']}`, sites at line{'s' if len(lines_here) != 1 else ''} "
                      + ", ".join(map(str, lines_here)) + ":")
                    w("")
                    w("```diff")
                    for line in (h["lines"] and ([h["header"]] + h["lines"]) if full else
                                 hunk_excerpt(h, lines_here)):
                        w(line)
                    w("```")
                    w("")
                    if owners is not None:
                        others = also_uses(adopters, h["id"], mine, owners, nodes)
                        if others:
                            w("This hunk also uses " + "; ".join(
                                f"{', '.join('`' + x + '`' for x in sorted(v)[:6])}"
                                + (f" and {len(v) - 6} more" if len(v) > 6 else "")
                                + (f" (pitch `{o}`)" if o != "no pitch yet" else " (no pitch yet)")
                                for o, v in sorted(others.items())) + ".")
                            w("")
        elif ad:
            w(f"**Adopted** on `{ad['branch']}` only by name: {ad['qualifiers']} sites name one of its types to "
              "qualify a nested type from another carve-out.")
            w("")
        if be:
            src = {"coverage": f"the coverage tools' extraction ({be['extraction']})",
                   "lexical": "a lexical scan of its library sources, since the coverage store has no extraction "
                              "of this commit"}.get(be["source"], be["source"])
            w(f"**Would benefit**: at `{(be['commit'] or '')[:10]}` ({be['role']}"
              + (f", \"{be['subject']}\"" if be.get("subject") else "") + f"), from {src}: "
              f"{plural(len(be['sites']), 'site')} of {plural(len(be['interfaces']), 'C interface')}.")
            w("")
            mapped = any("onBranch" in s for s in be["sites"])
            limit = None if full else MAX_BENEFIT_MD
            w("| Site | C interface | Declarations | |" + (f" On `{branch}` |" if mapped else ""))
            w("|---|---|---|---|" + ("---|" if mapped else ""))
            for s in be["sites"][:limit]:
                decls = ", ".join(cell(x) for x in s["declarations"][:3]) + (
                    f" +{len(s['declarations']) - 3}" if len(s["declarations"]) > 3 else "")
                itf = f"`{s['interface']}`" + (f" (wraps {', '.join('`' + v + '`' for v in s['via'])})"
                                               if s.get("via") else "")
                row = f"| `{s['file']}:{s['line']}` | {itf} | {decls} | {s['resolution']} |"
                if mapped:
                    ob = s.get("onBranch", "?")
                    row += (" changed by the migration |" if ob is None else
                            f" line {ob['line']}, unchanged |" if isinstance(ob, dict) else " ? |")
                w(row)
            if limit and len(be["sites"]) > limit:
                w(f"| … and {len(be['sites']) - limit} more | | | |" + (" |" if mapped else ""))
            w("")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", required=True)
    ap.add_argument("--clusters", help="cluster.py's clusters.json: a bundle per cluster, ranked part and batch")
    ap.add_argument("--units", help="pitches.py's units: a bundle per pitch file")
    ap.add_argument("--root", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--drafts")
    ap.add_argument("--adopters", help="adopters.json, from adopters.py")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    g = load(a.graph)
    if bool(a.clusters) == bool(a.units):
        raise SystemExit("bundles: pass --clusters or --units")
    cl = load(a.clusters) if a.clusters else load(a.units)
    nodes, atoms, tests, samples = g["nodes"], g["atoms"], g["tests"], g["samples"]
    conts = {c["id"]: c for c in cl["contingencies"]}
    src = Source(a.root)
    adopters = json.load(open(a.adopters)) if a.adopters and os.path.exists(a.adopters) else None
    os.makedirs(a.out, exist_ok=True)

    units = {}
    owners = {}
    if a.units:
        for u in cl["units"]:
            units[u["id"]] = u
        owners = cl.get("owners", {})
        cl.setdefault("candidates", [])
    else:
        for c in cl["clusters"]:
            units[c["id"]] = c
            for p in c["parts"]:
                units[p["id"]] = p
        for b in cl["batches"]:
            units[b["id"]] = b
    ranked = {x["id"]: x for x in cl["candidates"]}

    def rank_of(uid):
        if uid in ranked:
            return ranked[uid]["rank"]
        return units.get(uid, {}).get("rank") or "—"

    # Commits: every one between the two commits, and who last touched each
    # line of the files the bundles cite.
    log = git(a.repo, "log", "--no-show-signature", "--format=%H%x00%an%x00%ad%x00%s%x00%b%x1e", "--date=short",
              f"{a.base}..{a.head}")
    commits = {}
    for rec in log.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        h, author, date, subject, body = (rec.split("\x00") + ["", "", "", "", ""])[:5]
        commits[h] = {"hash": h, "author": author, "date": date, "subject": subject, "body": body.strip()}
    blame_cache = {}

    def blame(rel):
        if rel not in blame_cache:
            out = git(a.repo, "blame", "--porcelain", "-w", a.head, "--", rel)
            lines, cur = {}, None
            for line in out.split("\n"):
                m = re.match(r"^([0-9a-f]{40}) \d+ (\d+)", line)
                if m:
                    cur = m.group(1)
                    lines[int(m.group(2))] = cur
            blame_cache[rel] = lines
        return blame_cache[rel]

    # CMake: which line lists each SystemPackage file.
    cmake_path = "Sources/System/CMakeLists.txt"
    cmake_lines = src.lines(cmake_path)

    def cmake_entry(rel):
        if not rel.startswith("Sources/System/"):
            return None
        short = rel[len("Sources/System/"):]
        for i, line in enumerate(cmake_lines, 1):
            if line.strip() == short:
                return i
        return None

    # House format, from the proposals on the head commit.
    proposals_dir = os.path.join(a.root, "Proposals")
    house = []
    if os.path.isdir(proposals_dir):
        for f in sorted(os.listdir(proposals_dir)):
            if f.endswith(".md"):
                heads = [l.strip() for l in open(os.path.join(proposals_dir, f), encoding="utf-8")
                         if re.match(r"^##\s", l)]
                title = next((l.strip("# \n") for l in open(os.path.join(proposals_dir, f), encoding="utf-8")
                              if l.startswith("# ")), f)
                house.append({"file": f"Proposals/{f}", "title": title, "sections": [h[3:] for h in heads]})

    index = []
    for uid, u in sorted(units.items()):
        nids = u["nodes"]
        ns = [nodes[i] for i in nids]
        api = [n for n in ns if n["hiddenClass"] != "unavailable"]
        stubs = [n for n in ns if n["hiddenClass"] == "unavailable"]
        m = u["metrics"]
        d = os.path.join(a.out, uid)
        os.makedirs(d, exist_ok=True)

        # --------------------------------------------------------- ranges
        api_ranges = [tuple(r) for r in u.get("ranges", [])]
        for x in u["atoms"]:
            at = atoms[x]
            label = (f"{at['kind']} {at['subject']}" if not at["loose"] else nodes[at["nodes"][0]]["path"])
            if at["mark"]:
                label += f" (MARK: {at['mark']})"
            api_ranges.append((at["file"], at["start"], at["end"], label))
        pieces = {}
        shared_pieces = collections.defaultdict(set)
        mine = set(nids)
        for n in ns:
            for p in n.get("implementation", []):
                key = (p["file"], p["start"], p["end"])
                pieces.setdefault(key, dict(p, usedBy=set()))["usedBy"].add(n["path"])
        # A piece another carve-out's API also reaches is shared: whichever
        # lands first brings it.
        for nid, n in nodes.items():
            if nid in mine:
                continue
            for p in n.get("implementation", []):
                key = (p["file"], p["start"], p["end"])
                if key in pieces:
                    shared_pieces[key].add(n["path"])
        impl_ranges = [(f, s, e, f"{p['kind']} {p['name']}") for (f, s, e), p in pieces.items()]
        cmake = sorted({(f, cmake_entry(f)) for f, _, _, _ in api_ranges + impl_ranges if cmake_entry(f)})

        # --------------------------------------------------------- tests and samples
        test_ids = sorted({t for n in ns for t in n["tests"]})
        covers = collections.defaultdict(list)
        for n in api:
            for t in n["tests"]:
                covers[t].append(n["path"])
        test_recs = [dict(tests[t], covers=sorted(covers.get(t, []))) for t in test_ids if t in tests]
        test_recs.sort(key=lambda t: (-len(t["covers"]), t["file"], t["line"]))
        sample_uses = collections.defaultdict(list)
        for n in api:
            for s in n["samples"]:
                sample_uses[s].append(n["path"])
        # The samples that use most of it first: many use ProcessID.current
        # only to name a scratch file.
        sample_recs = [dict(samples[s], uses=sorted(set(v))) for s, v in sorted(sample_uses.items()) if s in samples]
        sample_recs.sort(key=lambda s: (-len(s["uses"]), s["file"]))
        untested = [n["path"] for n in api if not n["tests"]]

        # --------------------------------------------------------- commits
        touch = collections.Counter()
        for f, s, e, _ in api_ranges + impl_ranges:
            b = blame(f)
            for ln in range(s, e + 1):
                h = b.get(ln)
                if h in commits:
                    touch[h] += 1
        top_commits = [dict(commits[h], lines=cnt) for h, cnt in touch.most_common()]
        total_lines = sum(touch.values()) or 1
        # Quote a commit in full when it wrote a real share of these lines.
        quoted = [c for c in top_commits if c["lines"] >= 5 and c["lines"] * 20 >= total_lines][:MAX_COMMITS_FULL]

        # --------------------------------------------------------- prior text
        prior = list(u["prior"])
        for cid in list(u["direct"]) + list(u["inherited"]):
            for w in conts[cid].get("writeups", []):
                if not any(p["file"] == w for p in prior):
                    prior.append({"file": w, "kind": "contingency write-up", "score": 0,
                                  "names": [conts[cid]["title"]]})

        # --------------------------------------------------------- bundle.json
        data = {
            "id": uid, "kind": u["kind"], "name": u["name"], "cluster": u.get("cluster"),
            "rank": ranked.get(uid, {}).get("rank", u.get("rank")), "score": u.get("score"),
            "reason": u.get("reason"), "batch": u.get("batch"), "members": u.get("members"),
            "metrics": m,
            "contingencies": {"direct": u["direct"], "inherited": u["inherited"]},
            "prerequisites": u["prerequisites"], "allPrerequisites": u["allPrerequisites"],
            "implementationPrerequisites": u.get("implPrerequisites", {}),
            "dependents": u.get("dependents", []),
            "parts": [{"id": p["id"], "name": p["name"], "declarations": p["metrics"]["declarations"],
                       "prerequisites": list(p["prerequisites"])} for p in u.get("parts", [])],
            "declarations": [{k: n.get(k) for k in ("path", "kind", "decl", "availability", "platforms", "hasDoc",
                                                    "docSummary", "cNames", "cCalls", "file", "line", "start", "end",
                                                    "tests", "samples", "status", "hiddenClass", "renamedTo",
                                                    "module", "usr")} for n in ns],
            "sourceRanges": [{"file": f, "start": s, "end": e, "what": l} for f, s, e, l in merge_ranges(api_ranges)],
            "implementationRanges": [{"file": f, "start": s, "end": e, "what": p["kind"] + " " + p["name"],
                                      "usedBy": sorted(p["usedBy"]),
                                      "alsoUsedBy": sorted(shared_pieces.get((f, s, e), []))[:10]}
                                     for (f, s, e), p in sorted(pieces.items())],
            "cmake": [{"file": cmake_path, "line": ln, "entry": f} for f, ln in cmake],
            "tests": test_recs, "untested": untested, "samples": sample_recs,
            "prior": prior, "commits": [{k: c[k] for k in ("hash", "date", "author", "subject", "lines")}
                                        for c in top_commits],
            "sharedAliases": u.get("sharedAliases", []),
            "vocabulary": u.get("vocabulary", {}),
            "houseFormat": house,
        }
        if u["kind"] == "pitch":
            data["pitch"] = {k: u.get(k) for k in ("file", "pattern", "status", "notes", "rules", "problems",
                                                   "patternReport", "requires", "unownedTypes")}
        if adopters:
            agg = reach.aggregate(adopters, [n for n in nids if nodes[n]["hiddenClass"] != "unavailable"])
            data["adopters"] = adopters_data(agg, adopters, nodes, nids)
        json.dump(data, open(os.path.join(d, "bundle.json"), "w"), indent=1, default=sorted)

        # --------------------------------------------------------- bundle.md
        L = []
        w = L.append
        if u["kind"] == "pitch":
            w(f"# Pitch bundle: {u['name']}")
            w("")
            w(f"`{uid}`, a hand-curated pitch (`{u['file']}`): pattern `{u['pattern']}`, status {u['status']}.")
            w("")
        else:
            kind_text = {"cluster": "cluster", "part": f"part of cluster `{u.get('cluster')}`",
                         "batch": "batch of small clusters"}[u["kind"]]
            w(f"# Carve-out bundle: {u['name']}")
            w("")
            w(f"`{uid}`, a suggested {kind_text}" + (f", ranked {data['rank']} of {len(cl['candidates'])}"
                                                     if data["rank"] else "")
              + (f" (in batch `{u['batch']}`)" if u.get("batch") else "") + ".")
            w("")
        w("This is input for writing a pitch, not a pitch. It was generated by `Utilities/api-graph` from "
          f"`{a.head[:10]}` against `{a.base[:10]}`. The open questions below are open: don't settle them in the "
          "pitch, and don't present a current default as a decision.")
        w("")
        w("| | |")
        w("|---|---|")
        w(f"| Declarations | {m['declarations']} ({m['types']} types)"
          + (f", plus {m['stubs']} `unavailable` fix-it stubs" if m["stubs"] else "") + " |")
        w(f"| Modules | {', '.join(m['modules'])} |")
        w(f"| Platforms (from `#if`) | {platform_text(m['platforms'])} |")
        ver = "; ".join(f"{', '.join(v['platforms'])}: {v['level']} by `{v['source']}`" for v in m["verifiedOffDarwin"])
        w(f"| Checked off Darwin | {ver or 'nothing: no evidence that any of it has been compiled off Darwin'} |")
        if m["offDarwinOnly"]:
            w(f"| Not compiled on Darwin | {m['offDarwinOnly']} declarations, never compiled by this tool's build |")
        w("| Availability | " + ", ".join(f"{k} ×{v}" for k, v in m["availability"].items()) + " |")
        w(f"| Documented | {m['documented']} of {m['declarations']} |")
        w(f"| Tested | {m['tested']} of {m['declarations']}"
          + (f" ({m['lexicallyTested']} matched by name, since they aren't compiled here)" if m["lexicallyTested"] else "")
          + f", by {len(m['tests'])} tests ({len(m['mockTests'])} mock) |")
        w(f"| Samples | {len(m['samples'])} |")
        if adopters:
            ad = data["adopters"]
            pname = {p["key"]: p["name"] for p in adopters["packages"]}
            w(f"| Adopters | {len(ad['using'])} using it on their {reach.branch_words(adopters['meta'])}"
              + (f" ({', '.join(pname.get(k, k) for k in ad['using'])})" if ad["using"] else "")
              + f"; {len(ad['benefiting'])} would benefit"
              + (f" ({', '.join(pname.get(k, k) for k in ad['benefiting'][:8])}"
                 f"{', …' if len(ad['benefiting']) > 8 else ''})" if ad["benefiting"] else "") + " |")
        w(f"| C API | {', '.join('`' + c + '`' for c in m['cNames'][:24]) or '—'} |")
        w("")
        if u.get("reason"):
            w(f"**Ranking:** {u['reason']}.")
            w("")
        if u.get("parts"):
            w(f"**This cluster has {len(u['parts'])} parts** that could be pitched separately, each with a bundle "
              "of its own, listed under Parts below. A pitch session is better off starting from one of them.")
            w("")
        if u.get("members"):
            w("**Members of this batch**, each a cluster with its own bundle: "
              + ", ".join(f"`{x}`" for x in u["members"]) + ".")
            w("")
        if u["kind"] == "pitch":
            w("## The pitch file")
            w("")
            if u.get("notes"):
                w(u["notes"])
                w("")
            w("Its rules, and what each matched in this run's graph (fix-it stubs follow what they rename):")
            w("")
            for r in u["rules"]:
                w(f"- {r['part']} `{json.dumps(r['rule'])}`: {r['matches']} declarations"
                  + ("; " + "; ".join(r["problems"]) if r["problems"] else ""))
            w("")
            fits = "; ".join(("" if ok else "**doesn't fit**: ") + txt for ok, txt in u.get("patternReport", []))
            if fits:
                w(f"Pattern `{u['pattern']}`: {fits}.")
                w("")
            if u.get("problems"):
                w("Problems: " + "; ".join(u["problems"]) + ".")
                w("")
            if u.get("unownedTypes"):
                w("New types its declarations name that no pitch owns yet: "
                  + ", ".join(f"`{k}`" for k in u["unownedTypes"]) + ".")
                w("")

        w("## Open questions it depends on")
        w("")
        if not u["direct"] and not u["inherited"]:
            w("None of the tracked contingencies applies to this carve-out, or to anything it needs.")
            w("")
        for cid, info in u["direct"].items():
            c = conts[cid]
            w(f"### {c['title']} (decisions {c['decisions']})")
            w("")
            w(c["question"])
            w("")
            if c.get("deliberatelyOpen"):
                w(f"**Deliberately open.** {c['deliberatelyOpen']}")
                w("")
            w(f"Why it applies ({info['count']} declarations):")
            w("")
            for ev in info["evidence"]:
                w(f"- {ev}")
            if c.get("writeups"):
                w("")
                w("Write-ups: " + ", ".join(f"`{x}`" for x in c["writeups"]) + ".")
            w("")
        for cid, info in u["inherited"].items():
            c = conts[cid]
            how = {"api": "through its signatures", "implementation": "through its implementation only",
                   "nesting": "through nesting only: it needs the name, not the answer"}[info["through"]]
            w(f"### {c['title']} (decisions {c['decisions']}), inherited")
            w("")
            w(f"From `{info['via']}`, {how}. {c['question']}")
            if c.get("deliberatelyOpen"):
                w("")
                w(f"**Deliberately open.** {c['deliberatelyOpen']}")
            w("")

        w("## What it needs, and what needs it")
        w("")
        if u["allPrerequisites"]:
            w("Land these first, or include them. Shared vocabulary that's new on this branch counts:")
            w("")
            for pid, info in u["allPrerequisites"].items():
                direct = u["prerequisites"].get(pid)
                how = ""
                if direct:
                    how = " — " + "; ".join(f"`{e[0]}` {e[2]} `{e[1]}`" for e in direct["edges"][:4])
                w(f"- `{pid}` (rank {rank_of(pid)})"
                  + (", nesting only" if info["namespaceOnly"] else "") + how)
            w("")
        else:
            w("Nothing new on this branch: only API that's already on the base commit.")
            w("")
        if u.get("implPrerequisites"):
            w("Its implementation also uses new public API from these, which no signature shows:")
            w("")
            for pid, evs in u["implPrerequisites"].items():
                w(f"- `{pid}` — " + "; ".join(f"`{x}` uses `{y}`" for x, y in evs[:4]))
            w("")
        if u.get("dependents"):
            w("Carve-outs that need this one: " + ", ".join(f"`{x}`" for x in u["dependents"]) + ".")
            w("")
        if u.get("vocabulary"):
            w("Existing API it builds on: " + ", ".join(f"`{k}` ×{v}" for k, v in u["vocabulary"].items()) + ".")
            w("")
        if u.get("sharedAliases"):
            w("CInterop aliases it shares with other carve-outs: " + "; ".join(
                f"`{s['alias']}` (also {', '.join(s['alsoUsedBy'])})" for s in u["sharedAliases"]) + ".")
            w("")

        if u.get("parts"):
            w("## Parts")
            w("")
            w("The pieces of this cluster that could be pitched separately, each with what it needs within "
              "the cluster. Each ranked part has a bundle of its own.")
            w("")
            w("| Part | Declarations | Needs |")
            w("|---|---:|---|")
            for p in u["parts"]:
                w(f"| `{p['id']}` — {p['name']} | {p['metrics']['declarations']} | "
                  + (", ".join(f"`{x}`" for x in p["prerequisites"]) or "—") + " |")
            w("")

        w("## Declarations")
        w("")
        by_group = collections.OrderedDict()
        for n in sorted(api, key=lambda n: (n["file"] or "", n["line"] or 0)):
            grp = n["path"] if n["isType"] else (n["parentPath"] or "(top level)")
            by_group.setdefault(grp, []).append(n)
        for grp, items in by_group.items():
            w(f"### `{grp}`")
            w("")
            for n in items:
                bits = [n["availability"]]
                if set(n["platforms"] or []) != set(m["platforms"]):
                    bits.append(platform_text(n["platforms"]))
                if n["source"] == "scan":
                    bits.append("not compiled on Darwin" if n["hiddenClass"] == "platform" else n["hiddenClass"])
                if not n["hasDoc"]:
                    bits.append("**no doc comment**")
                if n["cNames"]:
                    bits.append("C: " + ", ".join(n["cNames"]))
                bits.append(f"{len(n['tests'])} tests" if n["tests"] else "**untested**")
                w(f"- {md_code(n['decl'])} — {' · '.join(bits)} — `{n['file']}:{n['line']}`")
                if n["docSummary"]:
                    w(f"  {n['docSummary']}")
            w("")
        if stubs:
            w(f"**Fix-it stubs** ({len(stubs)}): `@available(*, unavailable, renamed:)` spellings of the C "
              "names: " + ", ".join(f"`{n['title']}` → `{n.get('renamedTo')}`" for n in stubs[:40])
              + (f", and {len(stubs) - 40} more" if len(stubs) > 40 else "") + ".")
            w("")

        mapping = [(n["path"], n["cNames"] or n["cCalls"]) for n in api if n["cNames"] or n["cCalls"]]
        if mapping:
            w("## Swift API to C mapping")
            w("")
            w("From each declaration's \"The corresponding C ...\" doc line, else the C functions its "
              "implementation calls.")
            w("")
            w("| Swift | C |")
            w("|---|---|")
            for p, cs in mapping:
                w(f"| {md_code(p)} | {', '.join('`' + c + '`' for c in cs)} |")
            w("")

        w("## Source")
        w("")
        w("The API's blocks (a block is a type declaration or one `extension`, doc comments and attributes "
          "included), then the new internal code they reach. `sources.md` quotes all of it.")
        w("")
        for f, s, e, labels in merge_ranges(api_ranges):
            w(f"- `{f}:{s}-{e}` — {'; '.join(labels)}")
        if impl_ranges:
            w("")
            w("New internal code it needs (layer 1 and 2 of each wrapper, constants, C shims):")
            w("")
            for (f, s, e), p in sorted(pieces.items()):
                shared = shared_pieces.get((f, s, e))
                w(f"- `{f}:{s}-{e}` — {p['kind']} `{p['name']}`"
                  + (f"; also used by {len(shared)} declarations outside this carve-out, such as `{sorted(shared)[0]}`"
                     if shared else ""))
        if cmake:
            w("")
            w("CMake: " + ", ".join(f"`{cmake_path}:{ln}` lists `{f[len('Sources/System/'):]}`" for f, ln in cmake) + ".")
        w("")

        w("## Tests")
        w("")
        if not test_recs:
            w("No test references this carve-out's API.")
        else:
            w(f"{len(test_recs)} tests reference its API, found from the index store"
              + (" (and, for code not compiled here, by name)" if m["lexicallyTested"] else "")
              + ". `tests.md` quotes them.")
            w("")
            w("| Test | Framework | Covers |")
            w("|---|---|---|")
            for t in test_recs[:80]:
                cov = ", ".join(md_code(x.split(".")[-1]) for x in t["covers"][:6]) + (
                    f" +{len(t['covers']) - 6}" if len(t["covers"]) > 6 else "")
                w(f"| `{t['file'].split('/')[-1]}` {md_code(t['scope'] + '.' + t['name'] if t['scope'] else t['name'])}"
                  f" | {t['framework']}{', mock' if t['mock'] else ''} | {cov} |")
            if len(test_recs) > 80:
                w(f"| … and {len(test_recs) - 80} more | | |")
        if untested:
            w("")
            w(f"Untested declarations ({len(untested)}): " + ", ".join(md_code(x) for x in untested[:40])
              + (f", and {len(untested) - 40} more" if len(untested) > 40 else "") + ".")
        w("")

        w("## Samples")
        w("")
        if not sample_recs:
            w("No sample uses this carve-out's API.")
        else:
            for s in sample_recs:
                cmd = ", ".join(f"`system-samples {c}`" for c in s["commands"]) or "(no command)"
                w(f"- `{s['file']}` — {cmd}: {s['abstract'] or ''} Uses "
                  + ", ".join(md_code(x) for x in s["uses"][:8]) + (f" +{len(s['uses']) - 8}" if len(s["uses"]) > 8 else "")
                  + ".")
            w("")
            w(f"`samples.md` quotes the first {min(MAX_SAMPLES_MD, len(sample_recs))}.")
        w("")

        pitch_view = dict(owners=owners, mine=set(nids), nodes=nodes) if u["kind"] == "pitch" else {}
        if adopters:
            w("## Adopters")
            w("")
            adopters_md(w, data["adopters"], adopters, **pitch_view)
        if u.get("related"):
            w("## Related API, by domain")
            w("")
            w("New declarations in this pitch's domains (`Utilities/api-graph/domains.json`, after the chapters of "
              "*Advanced Programming in the UNIX Environment*) that the graph doesn't link to it: no link to or "
              "from its declarations, and no shared C family or block. Candidates to include, to leave to "
              "another pitch, or to mention:")
            w("")
            for dom, fams in u["related"].items():
                w(f"- **{dom}**: " + "; ".join(
                    f"{fam}: " + ", ".join(f"`{x['path']}`" + (f" ({', '.join(x['pitches'])})" if x["pitches"] else "")
                                           for x in xs) for fam, xs in fams.items()))
            w("")
        w("## Prior text")
        w("")
        if prior:
            for p in prior:
                w(f"- `{p['file']}` ({p['kind']})" + (f": mentions {', '.join('`' + x + '`' for x in p['names'])}"
                                                    if p.get("names") and p["kind"] != "contingency write-up" else ""))
        else:
            w("No proposal, prototype write-up or draft mentions this carve-out's types or C calls.")
        if cl.get("gists"):
            w("")
            w("Gists named in the docs: " + ", ".join(cl["gists"]))
        w("")
        if top_commits:
            w(f"Commits that last touched its lines ({len(top_commits)}), by lines touched. The messages of "
              f"the {len(quoted)} that wrote at least 5 lines and 5% of them are quoted in full below.")
            w("")
            for c in top_commits[:25]:
                w(f"- `{c['hash'][:10]}` {c['date']} ({c['lines']} lines) {c['subject']}")
            if len(top_commits) > 25:
                w(f"- … and {len(top_commits) - 25} more")
            w("")
            for c in quoted:
                w(f"#### `{c['hash'][:10]}` {c['subject']}")
                w("")
                if c["body"]:
                    w("> " + c["body"].replace("\n", "\n> "))
                else:
                    w("(no body)")
                w("")
        w("## House format")
        w("")
        w("The proposals in `Proposals/` use these sections. SYS-0007 is the closest model for a small set of "
          "wrappers, and SYS-0006 for new types; SYS-0006's appendix maps Swift API to C as the table above does.")
        w("")
        for h in house:
            w(f"- `{h['file']}` ({h['title']}): " + " · ".join(h["sections"]))
        w("")
        open(os.path.join(d, "bundle.md"), "w").write("\n".join(L) + "\n")

        # --------------------------------------------------------- excerpts
        S = [f"# Sources: {u['name']}", ""]
        for f, s, e, labels in merge_ranges(api_ranges) + merge_ranges(impl_ranges):
            S += [f"## `{f}:{s}-{e}`", "", "; ".join(labels), "", f"```{fence_lang(f)}", src.excerpt(f, s, e), "```", ""]
        open(os.path.join(d, "sources.md"), "w").write("\n".join(S) + "\n")
        T = [f"# Tests: {u['name']}", ""]
        for t in test_recs[:MAX_TESTS_MD]:
            T += [f"## `{t['file']}:{t['start']}-{t['end']}` {t['scope'] + '.' if t['scope'] else ''}{t['name']}", "",
                  f"{t['framework']}{', mock' if t['mock'] else ''}; covers " + ", ".join(md_code(x) for x in t["covers"]),
                  "", "```swift", src.excerpt(t["file"], t["start"], t["end"]), "```", ""]
        if len(test_recs) > MAX_TESTS_MD:
            T.append(f"… and {len(test_recs) - MAX_TESTS_MD} more tests, listed in bundle.json.")
        open(os.path.join(d, "tests.md"), "w").write("\n".join(T) + "\n")
        P = [f"# Samples: {u['name']}", ""]
        for s in sample_recs[:MAX_SAMPLES_MD]:
            lines = src.lines(s["file"])
            P += [f"## `{s['file']}`", "", "```swift", "\n".join(lines).rstrip(), "```", ""]
        open(os.path.join(d, "samples.md"), "w").write("\n".join(P) + "\n")
        if adopters:
            D = [f"# Adopters: {u['name']}", ""]
            adopters_md(D.append, data["adopters"], adopters, full=True, **pitch_view)
            open(os.path.join(d, "adopters.md"), "w").write("\n".join(D) + "\n")
        index.append({"id": uid, "kind": u["kind"], "name": u["name"], "rank": data["rank"],
                      "declarations": m["declarations"], "path": os.path.join(uid, "bundle.md")})

    json.dump(sorted(index, key=lambda x: (x["rank"] or 10 ** 6, x["id"])), open(os.path.join(a.out, "index.json"), "w"),
              indent=1)
    print(f"bundles: {len(index)} bundles -> {a.out}")


if __name__ == "__main__":
    main()
