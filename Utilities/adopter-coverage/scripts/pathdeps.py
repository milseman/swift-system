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
       the build's cache key records: the trees of System's Sources and manifest, or the path
       pathdeps.py in-use REWRITES.json DUMP.json
       the rewrites the evaluated manifest uses
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


def system_export(repo, commit, exports, name):
    """An export of System at commit, in a directory named `name`: SwiftPM
    takes a path package's identity from its directory's name, and the
    manifest's targets refer to it by that (`package: "swift-system"`)."""
    dest = os.path.join(exports, commit, name)
    if not os.path.isfile(os.path.join(dest, "Package.swift")):
        os.makedirs(dest, exist_ok=True)
        archive = subprocess.run(["git", "-C", repo, "archive", commit], capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", dest], input=archive, check=True)
    return dest


def build_tree(repo, commit):
    """What a package that depends on System at commit builds against: the
    trees of its Sources and manifest, so commits that change neither
    (this tool's, say) share a build."""
    trees = subprocess.run(["git", "-C", repo, "rev-parse", f"{commit}:Sources", f"{commit}:Package.swift"],
                           capture_output=True, text=True, check=True).stdout.split()
    return "-".join(t[:12] for t in trees)


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
            new, kind = system_export(repo, commit, exports, os.path.basename(target.rstrip("/"))), "swift-system"
        else:
            new, kind = target, "local"
        done.append({"from": rel, "to": new, "kind": kind,
                     "checkout": target if kind == "swift-system" else None,
                     "key": f"swift-system@{build_tree(repo, commit)}" if kind == "swift-system" else f"path:{new}"})
        return m.group(1) + json.dumps(new)

    new_text = PATH_DEP.sub(sub, text)
    if new_text != text:
        open(manifest, "w", encoding="utf-8").write(new_text)
    return done


def in_use(rewrites, dump):
    """The rewrites the evaluated manifest uses: its `fileSystem`
    dependencies in `swift package dump-package`'s output. A path in a
    branch the manifest doesn't take (NIO's SWIFTCI_USE_LOCAL_DEPS) isn't
    one, and mustn't key the build."""
    paths = set()
    for d in json.load(open(dump)).get("dependencies", []):
        for fs in d.get("fileSystem", []) or []:
            p = fs.get("path")
            if p:
                paths.add(os.path.realpath(p))
    return [r for r in rewrites if os.path.realpath(r["to"]) in paths]


def main():
    if len(sys.argv) == 7 and sys.argv[1] == "rewrite":
        _, _, manifest, checkout, repo, commit, exports = sys.argv
        print(json.dumps(rewrite(manifest, checkout, repo, commit, exports)))
    elif len(sys.argv) == 4 and sys.argv[1] == "in-use":
        print(json.dumps(in_use(json.load(open(sys.argv[2])), sys.argv[3])))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
