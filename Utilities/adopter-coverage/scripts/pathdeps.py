#!/usr/bin/env python3
"""Make an exported package's local dependencies build from where it was
exported.

A manifest can name a local package by a path relative to its checkout:
`.package(path: "../../swift-system")`, as the migrations in ../adopters do.
The tool builds an export of the checkout in a scratch directory, where
that path leads nowhere, so each such path is rewritten in the export's
Package.swift (never the checkout's):
  - a path to a swift-system checkout (a worktree of this repository, or a
    package named swift-system) becomes an export of the System commit the
    run checks, made once per commit under SYSTEM_EXPORTS: the build then
    depends on commits, not on a worktree's state, and the index key says
    which commit;
  - any other path becomes absolute, against the checkout. It's a working
    tree, so the report says so.

Usage: pathdeps.py rewrite PACKAGE.swift CHECKOUT REPO SYSTEM_COMMIT SYSTEM_EXPORTS
       prints the rewrites as JSON: [{"from", "to", "kind", "checkout", "key"}]; `key` is what
       the build's cache key records: the System commit, or the path
"""

import sys

sys.dont_write_bytecode = True

import json
import os
import re
import subprocess

PATH_DEP = re.compile(r'(\.package\s*\((?:\s*name\s*:\s*"[^"]*"\s*,)?\s*path\s*:\s*)"([^"]+)"')


def common_dir(path):
    r = subprocess.run(["git", "-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def is_swift_system(path, repo):
    cd = common_dir(path)
    if cd and cd == common_dir(repo):
        return True
    manifest = os.path.join(path, "Package.swift")
    if os.path.isfile(manifest):
        return re.search(r'name\s*:\s*"swift-system"', open(manifest, encoding="utf-8", errors="replace").read()) \
            is not None
    return False


def system_export(repo, commit, exports):
    dest = os.path.join(exports, commit)
    if not os.path.isfile(os.path.join(dest, "Package.swift")):
        os.makedirs(dest, exist_ok=True)
        archive = subprocess.run(["git", "-C", repo, "archive", commit], capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)
    return dest


def rewrite(manifest, checkout, repo, commit, exports):
    text = open(manifest, encoding="utf-8").read()
    done = []

    def sub(m):
        rel = m.group(2)
        if os.path.isabs(rel):
            target = rel
        else:
            target = os.path.normpath(os.path.join(checkout, rel))
        if os.path.isdir(target) and is_swift_system(target, repo):
            new, kind = system_export(repo, commit, exports), "swift-system"
        else:
            new, kind = target, "local"
        done.append({"from": rel, "to": new, "kind": kind,
                     "checkout": target if kind == "swift-system" else None,
                     "key": f"swift-system@{commit}" if kind == "swift-system" else f"path:{new}"})
        return m.group(1) + json.dumps(new)

    new_text = PATH_DEP.sub(sub, text)
    if new_text != text:
        open(manifest, "w", encoding="utf-8").write(new_text)
    return done


def main():
    if len(sys.argv) != 7 or sys.argv[1] != "rewrite":
        sys.exit(__doc__)
    _, _, manifest, checkout, repo, commit, exports = sys.argv
    print(json.dumps(rewrite(manifest, checkout, repo, commit, exports)))


if __name__ == "__main__":
    main()
