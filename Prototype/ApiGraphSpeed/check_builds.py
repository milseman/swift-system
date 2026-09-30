#!/usr/bin/env python3
"""Checks adopters.py's persistent build directories on real migrations:
each package is built cold, then again with nothing changed, then against
another System commit, then against the first again, and last in the
scratch directory as before. Every build must index, the kept ones must be
incremental after the first, System's export must be synced in place, and
the references must match the cold build's (the packages checked here use
none of the declarations the two System commits differ in).

  check_builds.py DIR [--head C] [--other C] [--only swift-log,swift-driver]

DIR gets a cache, the build directories and a scratch directory, and is
deleted first. The adopters are pin.sh's copies.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import types

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(ROOT, "Utilities", "api-graph", "scripts"))
import adopters as A  # noqa: E402


def git(*args):
    return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True, check=True).stdout.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--head", default="3f9f9e1")
    ap.add_argument("--other", default="3f9f9e1^1", help="another System commit, with other Sources")
    ap.add_argument("--only", default="swift-log,swift-driver")
    ap.add_argument("--pinned", default=os.path.join(os.environ.get("TMPDIR", "/tmp/"), "api-graph-speed"))
    args = ap.parse_args()
    d = os.path.abspath(args.dir)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(d, "work"))
    head, other = git("rev-parse", args.head + "^{commit}"), git("rev-parse", args.other + "^{commit}")
    assert git("rev-parse", f"{head}:Sources") != git("rev-parse", f"{other}:Sources"), "the commits' Sources match"
    compiler = subprocess.run(["swift", "--version"], capture_output=True, text=True).stdout.split("\n")[0]
    A.SWIFT_VERSION = tuple(int(x) for x in re.search(r"Swift version (\d+)\.(\d+)", compiler).groups())
    pkgs = A.discover(os.path.join(args.pinned, "adopters"), None, "migrate-darwin", ROOT)
    keys = args.only.split(",")
    failures = []

    def check(cond, what):
        print(("  ok: " if cond else "  FAILED: ") + what, flush=True)
        if not cond:
            failures.append(what)

    def build(key, commit, builds_dir):
        a = types.SimpleNamespace(repo=ROOT, head=commit, work=os.path.join(d, "work"),
                                  cache=os.path.join(d, "cache"), builds="build", rebuild=True,
                                  validate="declarations", branch="migrate-darwin", min_free_gb=15,
                                  builds_dir=builds_dir)
        b = A.Builder(a, pkgs, compiler.replace("swift-driver version: ", "swift-driver "), None)
        t0 = time.time()
        r = b.index(pkgs[key], b.plan(pkgs[key]))
        refs = sum(len(f["references"]) for f in r["files"].values())
        print(f"{key} against {commit[:10]} ({'kept' if builds_dir else 'scratch'}): {r['status']}, "
              f"{r['build'].get('start')}, {round(time.time() - t0)} s, {len(r['files'])} files, {refs} references",
              flush=True)
        return r

    builds = os.path.join(d, "builds")
    system_file = os.path.join(builds, "system", "swift-system", "Package.swift")
    for key in keys:
        cold = build(key, head, builds)
        check(cold["status"] == "indexed" and cold["build"]["start"] == "cold", f"{key}: a cold build indexes")
        state = A.load_json(os.path.join(builds, key, "state.json"))
        check(state["commit"] == pkgs[key]["adopters"]["commit"] and state["kb"], f"{key}: state.json records it")
        m0 = os.stat(system_file).st_mtime_ns
        again = build(key, head, builds)
        check(again["status"] == "indexed" and again["build"]["start"] == "incremental"
              and again["files"] == cold["files"],
              f"{key}: nothing changed: incremental, the same references")
        check(os.stat(system_file).st_mtime_ns == m0, f"{key}: System's export untouched")
        moved = build(key, other, builds)
        check(moved["status"] == "indexed" and moved["build"]["start"] == "incremental"
              and moved["files"] == cold["files"],
              f"{key}: System moved: incremental, the same references")
        check(os.stat(system_file).st_mtime_ns == m0, f"{key}: System's unchanged manifest kept its date")
        back = build(key, head, builds)
        check(back["status"] == "indexed" and back["build"]["start"] == "incremental"
              and back["files"] == cold["files"],
              f"{key}: System back: incremental, the same references")
        scratch = build(key, head, None)
        check(scratch["status"] == "indexed" and scratch["build"]["start"] == "cold"
              and scratch["files"] == cold["files"]
              and not os.path.exists(os.path.join(d, "work", "adopters", key)),
              f"{key}: a scratch build: the same references, deleted once read")
    total = sum(A.load_json(os.path.join(builds, k, "state.json"))["kb"] for k in keys)
    print(f"build directories: {total / 1024:.0f} MB for {', '.join(keys)}")
    print(json.dumps({"failures": failures}))
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
