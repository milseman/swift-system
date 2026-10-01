#!/usr/bin/env python3
"""Checks a pin (pin.sh's directory) against what a run recorded in its
adopters.json, and with --fix puts the pin back to it: the copies' refs
(each migration's branch tip and main, an adopters clone's branch, an
ecosystem clone's HEAD), ecosystem clones the run didn't have, and coverage
extractions that would now be picked instead of the recorded one (or where
the run had none and scanned lexically). Live clones move between runs; a
re-pin copies them as they are now.

  verify_pin.py ADOPTERS_JSON [PINNED_DIR] [--fix]

Prints each difference; exits 1 if any remains.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(ROOT, "Utilities", "api-graph", "scripts"))
import adopters as A  # noqa: E402


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def set_ref(repo, ref, commit):
    """Point ref (a branch name, or HEAD's branch) at commit."""
    if ref == "HEAD":
        sym = git(repo, "symbolic-ref", "-q", "HEAD")
        if sym:
            ref = sym
        else:
            subprocess.run(["git", "-C", repo, "update-ref", "--no-deref", "HEAD", commit], check=True)
            return
    elif not ref.startswith("refs/"):
        ref = ("refs/remotes/" + ref) if ref.startswith("origin/") else ("refs/heads/" + ref)
    subprocess.run(["git", "-C", repo, "update-ref", ref, commit], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("adopters_json")
    ap.add_argument("pinned", nargs="?", default=os.path.join(os.environ.get("TMPDIR", "/tmp/"), "api-graph-speed"))
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--branch", default="migrate-darwin")
    args = ap.parse_args()
    rec = json.load(open(args.adopters_json))
    adopters_dir = os.path.join(args.pinned, "adopters")
    eco_dir = os.path.join(args.pinned, "ecosystem")
    results = os.path.join(args.pinned, "coverage-results")
    want = {p["key"]: p for p in rec["packages"]}
    found = []

    def report(text):
        found.append(text)
        print(("fixing: " if args.fix else "") + text)

    # Clones the run didn't have.
    have = A.discover(adopters_dir, eco_dir, args.branch, ROOT)
    for key in sorted(set(have) - set(want)):
        for role in ("adopters", "ecosystem"):
            info = have[key][role]
            if info:
                report(f"{key}: a {role} clone the run didn't have ({info['dir']})")
                if args.fix:
                    shutil.rmtree(info["path"])

    # Refs.
    for key, p in sorted(want.items()):
        cur = have.get(key)
        if not cur:
            report(f"{key}: in the run, not in the pin")
            continue
        ad, cad = p.get("adopted"), cur["adopters"]
        if ad:
            path = cad["path"] if cad else None
            if not cad or (cad.get("commit"), cad.get("mainCommit"), cad.get("base"), cad.get("commits")) != \
                    (ad["commit"], ad["mainCommit"], ad["base"], ad["commits"]):
                report(f"{key}: migration {cad and cad.get('commit', '')[:10]} (main {cad and (cad.get('mainCommit') or '')[:10]}) "
                       f"instead of {ad['commit'][:10]} (main {ad['mainCommit'][:10]})")
                if args.fix and path:
                    set_ref(path, args.branch, ad["commit"])
                    set_ref(path, ad["mainRef"], ad["mainCommit"])
        if not ad and cad and cad.get("migrated"):
            # The run saw no commits past the merge base: put the branch back on it.
            report(f"{key}: {cad['commits']} migration commits the run didn't have")
            if args.fix:
                set_ref(cad["path"], args.branch, cad["base"])
        be = p.get("benefit")
        if be and be["role"] in ("adopters clone", "ecosystem clone"):
            info = cur["adopters" if be["role"] == "adopters clone" else "ecosystem"]
            now = (info.get("commit") or info.get("head")) if info else None
            if now != be["commit"]:
                report(f"{key}: {be['role']} at {(now or '?')[:10]} instead of {be['commit'][:10]}")
                if args.fix and info:
                    set_ref(info["path"], args.branch if be["role"] == "adopters clone" else "HEAD", be["commit"])

    # Coverage extractions: the one the run picked must still be the newest
    # for its commit, and a commit the run scanned lexically must have none.
    for key, p in sorted(want.items()):
        be = p.get("benefit")
        if not be:
            continue
        cands = glob.glob(os.path.join(results, "results", "*", be["commit"], "*", "*", "interfaces.json.gz"))
        keep = os.path.join(results, be["result"], "interfaces.json.gz") if be.get("result") else None
        if keep and not os.path.exists(keep):
            report(f"{key}: the run's extraction {be['result']} is gone from the pin")
            continue
        extra = [c for c in cands if c != keep and (keep is None or os.path.getmtime(c) >= os.path.getmtime(keep))]
        # A migration's merge base comes first: an extraction of it would win.
        ad = p.get("adopted")
        if ad and ad.get("base") and be["commit"] != ad["base"]:
            extra += glob.glob(os.path.join(results, "results", "*", ad["base"], "*", "*", "interfaces.json.gz"))
        for c in sorted(extra):
            report(f"{key}: extraction {os.path.relpath(os.path.dirname(c), results)} would be picked instead of "
                   f"{be.get('result') or 'a lexical scan'}")
            if args.fix:
                os.remove(c)

    if args.fix and found:
        # Check again, without fixing.
        os.execv(sys.executable, [sys.executable, os.path.abspath(__file__), args.adopters_json, args.pinned])
    print(f"{len(found)} difference{'s' if len(found) != 1 else ''}")
    raise SystemExit(1 if found else 0)


if __name__ == "__main__":
    main()
