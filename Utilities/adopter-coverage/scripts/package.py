#!/usr/bin/env python3
"""Read a package's configuration (packages/NAME.ini).

Each adopter the tool audits has one file there. The `[package]` section
says where the checkout is, how to build it, which of its targets to
audit, and what the platform model needs to know about it; the keys are
documented in packages/README.md. check.sh reads a package's settings
through `package.py shell`, and the other scripts import `load`.

Usage: package.py shell PACKAGES_DIR NAME   shell assignments, for eval
       package.py list PACKAGES_DIR         the packages `all` runs
       package.py roots PACKAGES_DIR NAME DUMP.json
                                            the library targets no other
                                            library target depends on, for
                                            `build-targets = :libraries`
"""

import sys

sys.dont_write_bytecode = True  # no __pycache__, here or in api-delta's scripts

import configparser
import os
import re
import shlex

PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"]

LIST_KEYS = {"shim-targets", "skip-targets", "build-targets", "build-flags", "unset-env", "platforms",
             "false-flags", "wrapper-files", "twin-targets", "through"}
# Lists of paths, which can hold spaces: one per line.
LINE_KEYS = {"wrapper-files"}
KEYS = LIST_KEYS | {"title", "name", "variable", "checkout", "in-all", "build-hint", "swift-exec-note"}


def load(path):
    """The package's settings as a dict. Lists are split on whitespace;
    `skip.<Target>` keys are collected into `skipReasons`."""
    cp = configparser.ConfigParser(interpolation=None, delimiters=("=",), comment_prefixes=("#",),
                                   inline_comment_prefixes=None, strict=True, empty_lines_in_values=False,
                                   default_section="__none__")
    cp.optionxform = str
    with open(path, encoding="utf-8") as f:
        cp.read_file(f)
    if not cp.has_section("package"):
        raise SystemExit(f"{path}: no [package] section")
    items = dict(cp.items("package"))
    key = os.path.splitext(os.path.basename(path))[0]
    pkg = {"key": key, "skipReasons": {}}
    for k, v in items.items():
        m = re.match(r"^skip\.(.+)$", k)
        if m:
            pkg["skipReasons"][m.group(1)] = " ".join(v.split())
            continue
        if k not in KEYS:
            raise SystemExit(f"{path}: unknown key {k!r}")
        if k in LINE_KEYS:
            pkg[k] = [line.strip() for line in v.split("\n") if line.strip()]
        else:
            pkg[k] = v.split() if k in LIST_KEYS else " ".join(v.split())
    for k in LIST_KEYS:
        pkg.setdefault(k, [])
    pkg.setdefault("title", key)
    pkg.setdefault("name", pkg["title"])
    pkg.setdefault("variable", re.sub(r"\W", "_", key).upper())
    pkg.setdefault("in-all", "yes")
    pkg["platforms"] = pkg["platforms"] or list(PLATFORMS)
    bad = [p for p in pkg["platforms"] if p not in PLATFORMS]
    if bad:
        raise SystemExit(f"{path}: unknown platforms {', '.join(bad)}")
    pkg["skip-targets"] = sorted(set(pkg["skip-targets"]) | set(pkg["skipReasons"]))
    return pkg


def library_roots(pkg, dump):
    """The package's library targets (regular ones it doesn't skip) that no
    other library target depends on: building them builds every library
    target, and no executable."""
    libs = {t["name"]: t for t in dump["targets"] if t["type"] == "regular" and t["name"] not in pkg["skip-targets"]}
    used = set()
    for t in libs.values():
        for d in t.get("dependencies", []):
            for kind in ("byName", "target"):
                if kind in d and d[kind] and d[kind][0] in libs:
                    used.add(d[kind][0])
    return sorted(set(libs) - used)


def main():
    cmd, packages = sys.argv[1], sys.argv[2]
    if cmd == "roots":
        import json
        pkg = load(os.path.join(packages, sys.argv[3] + ".ini"))
        print("\n".join(library_roots(pkg, json.load(open(sys.argv[4])))))
        return
    if cmd == "list":
        for f in sorted(os.listdir(packages)):
            if f.endswith(".ini") and load(os.path.join(packages, f))["in-all"] == "yes":
                print(f[:-4])
        return
    pkg = load(os.path.join(packages, sys.argv[3] + ".ini"))
    out = {"PKG_TITLE": pkg["title"], "PKG_NAME": pkg["name"], "PKG_VAR": pkg["variable"],
           "PKG_CHECKOUT": pkg.get("checkout", ""), "PKG_BUILD_HINT": pkg.get("build-hint", "")}
    for k, v in out.items():
        print(f"{k}={shlex.quote(v)}")
    for k, var in (("build-targets", "PKG_BUILD_TARGETS"), ("build-flags", "PKG_BUILD_FLAGS"),
                   ("unset-env", "PKG_UNSET_ENV")):
        print(f"{var}=({' '.join(shlex.quote(x) for x in pkg[k])})")


if __name__ == "__main__":
    main()
