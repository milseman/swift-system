#!/usr/bin/env python3
"""Reconcile the master view's page with its inputs, and its two views with
each other. Exits 1 on any mismatch, after listing every one.

  1. The page: one file, under its size limit, loading nothing from the
     network, embedding master.json's digest.
  2. New API: the page's declarations are api-delta's added set: as many in
     all and in each module, in master.json and in the page.
  3. C uses left: the page's update-checkout total, and each category's, are
     the ledger's in ledger.json and in its STATUS.md's section 5.
  4. The two ways in: every declaration's uses (package and sites) appear
     under that package, and the reverse, in master.json; and the page's
     uses are the API graph's usedBy sites, each once.
  5. The page's own counts: its model (model.js, run in node on the page's
     data) gives By API and By package the same sums, with and without each
     cluster's, kind's, pitch state's and use's filter; its headline (the
     intersection) is master.json's; master.json's headline is recounted
     from the By API side and from ledger.json; the history's last points
     are the headline's.
  6. The packages are universe.tsv's, and the history file has today's
     points as the figures end.

Usage: check.py --master M --page P --delta API_DELTA_JSON [--ledger-json J]
                [--status-md S] [--universe U] [--history H] [--graph G]
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import collections  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import assemble as asm  # noqa: E402
import page as pg  # noqa: E402
import universe as uv  # noqa: E402

DATA_RE = re.compile(r'<script type="application/json" id="data">(.*?)</script>', re.S)
MODEL_RE = re.compile(r'<script id="model">(.*?)</script>', re.S)
NETWORK_RE = re.compile(r"""<[^>]*\s(?:src|href)\s*=\s*["']?(?:https?:)?//""", re.I)
NODE_HARNESS = r"""
const vm = require('vm'), fs = require('fs');
const input = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
const ctx = {console: console};
vm.createContext(ctx);
vm.runInContext(input.model + '\nthis.Model = Model;', ctx);
const Model = ctx.Model;
const M = Model.build(JSON.parse(input.data));
const out = {headline: Model.headline(M), sums: {}};
const filters = [['all', Model.defaults()]];
for (let c = 0; c < 4; c++) filters.push(['cluster ' + c, Object.assign(Model.defaults(), {cluster: String(c)})]);
for (let k = 0; k < 5; k++) filters.push(['kind ' + k, Object.assign(Model.defaults(), {kind: String(k)})]);
for (let s = 1; s <= 5; s++) filters.push(['state ' + s, Object.assign(Model.defaults(), {state: String(s)})]);
for (const u of ['used', 'adopters', 'examples', 'none'])
  filters.push(['use ' + u, Object.assign(Model.defaults(), {use: u})]);
filters.push(['use adopters, cluster 0', Object.assign(Model.defaults(), {use: 'adopters', cluster: '0'})]);
// One package's declarations, and one declaration's packages, as the
// detail panels' buttons set them: each migrated package, and the
// declaration with the most users.
M.pkgs.forEach(function (p) { if (p.uses.length) filters.push(['used by ' + p.n, Object.assign(Model.defaults(), {onlyPkg: p.i})]); });
const top = M.decls.slice().sort((a, b) => b.uses.length - a.uses.length)[0];
if (top) filters.push(['users of ' + top.path, Object.assign(Model.defaults(), {onlyDecl: top.i})]);
for (const [name, f] of filters) out.sums[name] = Model.sums(M, f);
const t = Model.tree(M, Model.view(M, Model.defaults()).decls);
out.tree = {areas: t.length, declarations: t.reduce((n, a) => n + a.n, 0)};
process.stdout.write(JSON.stringify(out));
"""


def load(path):
    return asm.load_json(path)


class Check:
    def __init__(self):
        self.problems, self.passes, self.warnings = [], [], []

    def eq(self, what, got, want):
        if got == want:
            text = repr(got) if not isinstance(got, (int, str)) else str(got)
            self.passes.append(f"{what}: {text if len(text) <= 160 else text[:150] + ' …'}")
        else:
            self.problems.append(f"{what}: {got}, expected {want}")

    def fail(self, text):
        self.problems.append(text)

    def warn(self, text):
        self.warnings.append(text)


def page_data(page_text):
    m = DATA_RE.search(page_text)
    if not m:
        return None
    return json.loads(m.group(1))


def check_page(c, master, page_path):
    try:
        with open(page_path, encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        c.fail(f"can't read the page {page_path}: {e}")
        return None, None
    size = len(text.encode())
    if size > pg.MAX_BYTES:
        c.fail(f"the page is {size} bytes, over {pg.MAX_BYTES}")
    if NETWORK_RE.search(text):
        c.fail("the page's markup loads something from the network (a src or href to http)")
    if "default-src 'none'" not in text:
        c.fail("the page has no Content-Security-Policy that blocks the network")
    for tag in ("<link", "<iframe", "<img "):
        if tag in text.split('<script type="application/json"')[0]:
            c.fail(f"the page's markup has {tag}")
    pd = page_data(text)
    if pd is None:
        c.fail("the page has no embedded data")
        return text, None
    c.eq("page: the digest of the master.json it embeds", pd.get("digest"), master.get("digest"))
    return text, pd


def check_api(c, master, pd, delta):
    added = [e for e in delta["entries"] if e["status"] == "added"]
    hidden = delta["hiddenFromGraphs"]["added"]
    want = len(added) + len(hidden)
    c.eq("new API: master.json's declarations = api-delta's added + hidden", len(master["declarations"]), want)
    if pd is not None:
        c.eq("new API: the page's declarations = api-delta's added + hidden", len(pd["D"]), want)
    by_mod = collections.Counter(e["module"] for e in added) + collections.Counter(x["module"] for x in hidden)
    got = collections.Counter(d["module"] for d in master["declarations"])
    c.eq("new API: by module", dict(sorted(got.items())), dict(sorted(by_mod.items())))
    keys = collections.Counter((d["module"], d["path"], d.get("file"), d.get("line")) for d in master["declarations"])
    want_keys = collections.Counter([(e["module"], e["path"], e.get("file"), e.get("line")) for e in added] +
                                    [(x["module"], ".".join(x["scopes"] + [x["name"]]), x["file"], x["line"])
                                     for x in hidden])
    if keys != want_keys:
        miss, extra = want_keys - keys, keys - want_keys
        c.fail(f"new API: {sum(miss.values())} of api-delta's declarations aren't the page's, and "
               f"{sum(extra.values())} of the page's aren't api-delta's, such as "
               f"{(list(miss) or list(extra))[0]}")
    else:
        c.passes.append("new API: each of api-delta's declarations is one of the page's, by module, path, file, line")


def check_ledger(c, master, pd, ledger_json, status_md):
    meta_led = master["meta"].get("ledger")
    page_sites = None
    page_cats = collections.Counter()
    if pd is not None:
        page_sites = 0
        for p in pd["P"]:
            cu = p.get("cu") or {}
            if cu.get("src") == "ledger" and cu.get("sites"):
                page_sites += len(cu["sites"])
                for s in cu["sites"]:
                    page_cats[pg.CATEGORIES[s[3]]] += 1
    if not ledger_json:
        c.warn("no ledger JSON given: C uses not reconciled")
        return
    led = asm.ledger_from_json(load(ledger_json))
    c.eq("C uses: master.json's total = ledger.json's (excluded sites aside)", (meta_led or {}).get("total"), led["total"])
    if page_sites is not None:
        c.eq("C uses: the page's update-checkout sites = ledger.json's", page_sites, led["total"])
        c.eq("C uses: the page's sites by category = ledger.json's", dict(sorted(page_cats.items())),
             dict(sorted(led["byCategory"].items())))
    if status_md:
        with open(status_md, encoding="utf-8") as f:
            st = asm.parse_status_md(f.read())
        if not st:
            c.fail(f"C uses: {status_md} has no section 5 to compare with")
        else:
            c.eq("C uses: the page's total = STATUS.md's section 5 total", page_sites if page_sites is not None
                 else (meta_led or {}).get("total"), st["total"])
            c.eq("C uses: STATUS.md's categories = ledger.json's", dict(sorted(st["byCategory"].items())),
                 dict(sorted(led["byCategory"].items())))
            c.eq("C uses: excluded, STATUS.md and ledger.json", st["excluded"], led["excluded"])


def check_views(c, master, pd, graph_path, delta):
    decls, pkgs = master["declarations"], master["packages"]
    fwd = collections.Counter()
    for di, d in enumerate(decls):
        for pi, sites in d["usedBy"]:
            for s in sites:
                fwd[(di, pi, tuple(s[:4]))] += 1
    rev = collections.Counter()
    for pi, p in enumerate(pkgs):
        for di, sites in ((p.get("usage") or {}).get("new") or []):
            for s in sites:
                rev[(di, pi, tuple(s[:4]))] += 1
    if fwd != rev:
        a, b = fwd - rev, rev - fwd
        c.fail(f"the two ways in: {sum(a.values())} sites By API has that By package doesn't, {sum(b.values())} the "
               f"other way, such as {(list(a) or list(b))[0]}")
    else:
        c.passes.append(f"the two ways in: master.json's {sum(fwd.values())} sites are each under their declaration "
                        f"and their package")
    for pi, p in enumerate(pkgs):
        n_api = sum(1 for d in decls for x in d["usedBy"] if x[0] == pi)
        n_pkg = len((p.get("usage") or {}).get("new") or [])
        if n_api != n_pkg:
            c.fail(f"the two ways in: {p['name']} uses {n_pkg} declarations By package, {n_api} By API")
    if pd is not None:
        page_sites = sum(len(u[2]) for u in pd["U"])
        c.eq("the two ways in: the page's sites = master.json's", page_sites, sum(fwd.values()))
        pairs = collections.Counter((u[0], u[1]) for u in pd["U"])
        dup = [k for k, v in pairs.items() if v > 1]
        if dup:
            c.fail(f"the page lists {len(dup)} declaration-package pairs twice, such as {dup[0]}")
    if graph_path and os.path.exists(graph_path):
        # The graph's uses of a declaration api-delta lists as changed, not
        # added (FileDescriptor.close(), whose USR changed), are uses of API
        # already on main: the page counts them there.
        changed = {e["usr"] for e in delta["entries"] if e["status"] == "changed" and e.get("usr")}
        g = load(graph_path)
        remotes = {(p.get("remote") or "").lower() for p in pkgs}
        # A clone whose rows each cover a directory (the examples' tools)
        # has the sites in those directories only.
        dirs = collections.defaultdict(list)
        for p in pkgs:
            if p.get("subdir"):
                dirs[(p.get("remote") or "").lower()].append(p["subdir"].rstrip("/") + "/")
        pk = {nid: n for nid, n in g["nodes"].items() if n["kind"] == "package"}
        total = on_changed = by_dir = 0
        for ln in g["links"]:
            remote = (pk.get(ln["to"], {}).get("remote") or "").lower()
            if ln["kind"] != "usedBy" or remote not in remotes:
                continue
            ss = ln.get("sites") or []
            if remote in dirs:
                ss = [x for x in ss if any((x.get("file") or "").startswith(d) for d in dirs[remote])]
                by_dir += len(ss)
            if ln["from"] in changed:
                on_changed += len(ss)
            else:
                total += len(ss)
        c.eq("the two ways in: master.json's sites = the API graph's usedBy sites, each once, but those of changed "
             f"declarations ({on_changed}, counted as already on main); {by_dir} of them the examples', in their "
             "rows' directories", sum(fwd.values()), total)


def run_model(c, page_text, node):
    if not node:
        c.warn("node isn't installed: the page's own model wasn't run (its data was recounted in Python only)")
        return None
    m = MODEL_RE.search(page_text)
    d = DATA_RE.search(page_text)
    if not m or not d:
        c.fail("the page has no model script or no data to run it on")
        return None
    tmp = tempfile.mkdtemp(prefix="master-view-check-")
    try:
        inp = os.path.join(tmp, "input.json")
        with open(inp, "w", encoding="utf-8") as f:
            json.dump({"model": m.group(1), "data": d.group(1).replace("<\\/", "</").replace("<\\!--", "<!--")}, f)
        p = subprocess.run([node, "-e", NODE_HARNESS, inp], capture_output=True, text=True, timeout=300)
        if p.returncode != 0:
            c.fail(f"the page's model failed in node: {p.stderr.strip()[-600:]}")
            return None
        return json.loads(p.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def check_model(c, master, out):
    if out is None:
        return
    h = out["headline"]
    decls = master["declarations"]
    c.eq("page model: declarations", h["declarations"], len(decls))
    c.eq("page model: in the main count", h["mainCount"], sum(1 for d in decls if not d["excluded"]))
    want_state = collections.Counter(d["state"] for d in decls if not d["excluded"])
    c.eq("page model: by state", {int(k): v for k, v in h["byState"].items()}, {k: want_state.get(k, 0) for k in range(1, 6)})
    c.eq("page model: declarations used", h["used"], sum(1 for d in decls if d["usedBy"]))
    led = master["meta"].get("ledger") or {}
    c.eq("page model: C uses left", h["cuses"], led.get("total"))
    c.eq("page model: packages", h["packages"], len(master["packages"]))
    c.eq("page model: the By API tree's declarations", out["tree"]["declarations"], len(decls))
    for name, s in out["sums"].items():
        a, p = s["api"], s["packages"]
        if (a["pairs"], a["sites"]) != (p["pairs"], p["sites"]):
            c.fail(f"page model, {name}: By API has {a['pairs']} uses at {a['sites']} sites, By package "
                   f"{p['pairs']} at {p['sites']}")
        elif a["byPkg"] != p["byPkg"]:
            diff = sorted(k for k in set(a["byPkg"]) | set(p["byPkg"]) if a["byPkg"].get(k) != p["byPkg"].get(k))
            c.fail(f"page model, {name}: the views disagree about {', '.join(diff[:5])}")
        else:
            c.passes.append(f"page model, {name}: By API and By package both have {a['pairs']} uses at {a['sites']} sites")
    for name, s in out["sums"].items():
        if name.startswith("used by "):
            pkg = name[len("used by "):]
            want_p = next(p for p in master["packages"] if p["name"] == pkg)
            n = len((want_p.get("usage") or {}).get("new") or [])
            if s["api"]["declarations"] != n or set(s["api"]["byPkg"]) != {pkg}:
                c.fail(f"page model, {name}: By API lists {s['api']['declarations']} declarations used by "
                       f"{sorted(s['api']['byPkg'])}; {pkg} uses {n}")
    all_sites = sum(len(s) for d in decls for _, s in d["usedBy"])
    c.eq("page model: sites with no filter = master.json's", out["sums"]["all"]["api"]["sites"], all_sites)
    # The use filters: by anyone is by adopters or by the examples, and the
    # rest is by no one.
    sm = out["sums"]
    if all(k in sm for k in ("use used", "use none", "all")):
        c.eq("page model: declarations used by anyone + by no one = all", sm["use used"]["api"]["declarations"] +
             sm["use none"]["api"]["declarations"], sm["all"]["api"]["declarations"])
    # The headline: the page's model recounts it from the page's own data.
    mh = h.get("intersection")
    if mh is None:
        c.fail("page model: no headline (intersection) in the model's output")
    else:
        hl = master.get("headline") or {}
        for part in ("use", "cuses"):
            got, want = mh.get(part), hl.get(part)
            if got != want:
                keys = sorted(k for k in set(got or {}) | set(want or {}) if (got or {}).get(k) != (want or {}).get(k))
                c.fail(f"page model: the headline's {part} isn't master.json's: they differ in {', '.join(keys[:6])}")
            else:
                c.passes.append(f"page model: the headline's {part} is master.json's")


def check_headline(c, master, ledger_json):
    """master.json's headline, recounted another way: the declarations in use
    from By API's side (each declaration's users), and update-checkout's C
    uses from ledger.json, every site in one part of the split or in a
    set-aside package; the history's last points are the headline's."""
    hl = master.get("headline")
    if not hl:
        c.fail("master.json has no headline")
        return
    pkgs, decls = master["packages"], master["declarations"]
    aside = {i for i, p in enumerate(pkgs) if p.get("aside")}
    groups = collections.defaultdict(set)
    for di, d in enumerate(decls):
        for pi, _sites in d["usedBy"]:
            if pi not in aside:
                groups[pkgs[pi]["cluster"]].add(di)
    adopters = set().union(*(groups[g] for g in asm.ADOPTER_CLUSTERS))
    examples = groups[asm.EXAMPLES_CLUSTER]
    u = hl["use"]
    c.eq("headline: in use, from By API's side", u["any"], len(adopters | examples))
    c.eq("headline: in use by the adopters and by the examples, from By API's side",
         (u["adopters"], u["examples"], u["both"]), (len(adopters), len(examples), len(adopters & examples)))
    c.eq("headline: in use by each cluster, from By API's side",
         {g: u["groups"][g]["declarations"] for g in asm.CLUSTERS}, {g: len(groups[g]) for g in asm.CLUSTERS})
    unp = sum(1 for di in adopters | examples if decls[di]["state"] == 1 and not decls[di]["excluded"])
    c.eq("headline: in use and in no pitch, from By API's side", u["unpitched"], unp)
    for g, row in hl["cuses"].items():
        if sum(row["parts"].values()) != row["covers"] + row["lacks"] + row["other"]:
            c.fail(f"headline: {g}'s parts add up to {sum(row['parts'].values())}, its split to "
                   f"{row['covers'] + row['lacks'] + row['other']}")
    if ledger_json:
        led = asm.ledger_from_json(load(ledger_json))
        uc = hl["cuses"]["update-checkout"]
        c.eq("headline: update-checkout's C uses, split, and set aside = ledger.json's total",
             uc["covers"] + uc["lacks"] + uc["other"] + uc["aside"], led["total"])
        names = {p["name"] for p in pkgs if p.get("aside")}
        want = collections.Counter()
        for repo, ss in led["sites"].items():
            if repo in names:
                continue
            for x in ss:
                want[asm.ledger_bucket(x, led["work"])[0]] += 1
        c.eq("headline: update-checkout's split, recounted from ledger.json",
             {b: uc[b] for b in asm.SPLIT}, {b: want.get(b, 0) for b in asm.SPLIT})
    ch = master["charts"]
    last = lambda k: (ch.get(k) or [{}])[-1].get("count")  # noqa: E731
    c.eq("history: in use, today", last("used"), u["any"])
    c.eq("history: in use, not in a pitch, today", last("unpitched-used"), u["unpitched"])
    led_total = (master["meta"].get("ledger") or {}).get("total")
    c.eq("history: C uses left in update-checkout (set-aside ones too), today", last("cuses"), led_total)


def check_recount(c, master, pd):
    """The page's data, decoded in Python: what the model is given."""
    if pd is None:
        return
    S = pd["S"]
    c.eq("page data: packages", len(pd["P"]), len(master["packages"]))
    names = [p["n"] for p in pd["P"]]
    c.eq("page data: package names, in order", names, [p["name"] for p in master["packages"]])
    st = collections.Counter(d[4] for d in pd["D"] if not d[6] & 1)
    want = collections.Counter(d["state"] for d in master["declarations"] if not d["excluded"])
    c.eq("page data: declarations by state, in the main count", dict(sorted(st.items())), dict(sorted(want.items())))
    paths = [S[d[0]] for d in pd["D"]]
    c.eq("page data: declarations, in order", paths == [d["path"] for d in master["declarations"]], True)


def check_universe(c, master, universe):
    if not universe:
        return
    rows = [r for r in uv.read(universe) if r["cluster"] in uv.CLUSTERS]
    c.eq("packages: the page's are universe.tsv's", [p["name"] for p in master["packages"]], [r["name"] for r in rows])


def check_history(c, master, history):
    if not history:
        return
    rows = asm.read_history(history)
    today = master["meta"]["generated"]
    for k in asm.CHARTS:
        r = [x for x in rows if x["chart"] == k and x["date"] == today]
        series = master["charts"].get(k) or []
        if not r:
            c.fail(f"history: {history} has no point for {k} today ({today})")
        elif series and r[0]["count"] != series[-1]["count"]:
            c.fail(f"history: {k} today is {r[0]['count']} in the file, {series[-1]['count']} on the page")
        else:
            c.passes.append(f"history: {k} today, {r[0]['count']}")


def run(a):
    c = Check()
    master = load(a.master)
    body = {k: v for k, v in master.items() if k != "digest"}
    if asm.digest(body) != master.get("digest"):
        c.fail(f"{a.master}'s digest isn't its content's: edited after it was written?")
    text, pd = check_page(c, master, a.page)
    check_api(c, master, pd, load(a.delta))
    check_ledger(c, master, pd, a.ledger_json, a.status_md)
    delta = load(a.delta)
    check_views(c, master, pd, a.graph or (master["meta"].get("graph") or {}).get("path"), delta)
    check_recount(c, master, pd)
    check_headline(c, master, a.ledger_json)
    if text is not None:
        node = a.node if a.node != "auto" else shutil.which("node")
        check_model(c, master, run_model(c, text, node))
    check_universe(c, master, a.universe)
    check_history(c, master, a.history)
    return c


def main():
    ap = argparse.ArgumentParser(description="Reconcile the master view's page with its inputs.")
    ap.add_argument("--master", required=True)
    ap.add_argument("--page", required=True)
    ap.add_argument("--delta", required=True, help="api-delta.json")
    ap.add_argument("--ledger-json")
    ap.add_argument("--status-md")
    ap.add_argument("--universe")
    ap.add_argument("--history")
    ap.add_argument("--graph")
    ap.add_argument("--node", default="auto", help="node, to run the page's model (default: from PATH; '' skips)")
    ap.add_argument("--verbose", action="store_true")
    a = ap.parse_args()
    c = run(a)
    if a.verbose:
        for p in c.passes:
            print(f"pass  {p}")
    for w in c.warnings:
        print(f"warn  {w}")
    for p in c.problems:
        print(f"FAIL  {p}", file=sys.stderr)
    if c.problems:
        print(f"check: FAILED, {len(c.problems)} problem(s), {len(c.passes)} passed", file=sys.stderr)
        return 1
    print(f"check: OK, {len(c.passes)} checks passed" + (f", {len(c.warnings)} warning(s)" if c.warnings else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
