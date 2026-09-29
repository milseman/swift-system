#!/usr/bin/env python3
"""Dump an index store for darwin_audit.py: adopter-coverage's reader, over each file's newest unit.

Usage: indexstore.py [--all-units] LIBINDEXSTORE STORE_DIR SRC_ROOT OUT.json

The JSON is what Utilities/adopter-coverage/scripts/indexstore.py writes (its docstring describes
it): this runs that reader, read-only, rather than keeping a copy of it.

A store keeps the units of earlier builds. A file built two ways (`--build-system native` and
swiftbuild, or for two triples) has more than one, and a unit written before the file's last edit
describes source that has changed since: its records can match today's lines by accident. So
unless --all-units, only the newest unit of each source file is read, by the unit file's time:
those units are copied into a scratch store (under $ADOPTER_TOOLS_TMP) next to a link to the
original records, and the reader reads that. Units without a source file (modules) are all kept.
A store written by one build, as a fresh clone's is, dumps the same either way.
"""

import ctypes
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

READER = os.path.join(common.HERE, "..", "adopter-coverage", "scripts", "indexstore.py")


class StringRef(ctypes.Structure):
    _fields_ = [("data", ctypes.c_char_p), ("length", ctypes.c_size_t)]


def text(ref):
    return ctypes.string_at(ref.data, ref.length).decode("utf-8", "replace") if ref.length else ""


def newest_units(libpath, store_path):
    """(units to keep, how many the store has)."""
    lib = ctypes.CDLL(libpath)
    vp = ctypes.c_void_p
    for name, res, args in [
        ("indexstore_store_create", vp, [ctypes.c_char_p, ctypes.POINTER(vp)]),
        ("indexstore_store_dispose", None, [vp]),
        ("indexstore_error_get_description", ctypes.c_char_p, [vp]),
        ("indexstore_store_units_apply_f", ctypes.c_bool, [vp, ctypes.c_uint, vp, vp]),
        ("indexstore_unit_reader_create", vp, [vp, ctypes.c_char_p, ctypes.POINTER(vp)]),
        ("indexstore_unit_reader_dispose", None, [vp]),
        ("indexstore_unit_reader_get_main_file", StringRef, [vp]),
    ]:
        f = getattr(lib, name)
        f.restype, f.argtypes = res, args
    err = vp()
    store = lib.indexstore_store_create(store_path.encode(), ctypes.byref(err))
    if not store:
        common.fail(f"can't open {store_path}: {lib.indexstore_error_get_description(err).decode()}")
    names = []

    @ctypes.CFUNCTYPE(ctypes.c_bool, vp, StringRef)
    def on_unit(_ctx, name):
        names.append(text(name))
        return True

    lib.indexstore_store_units_apply_f(store, 0, None, on_unit)
    units_dir = os.path.join(store_path, "v5", "units")
    newest, keep = {}, []
    for u in names:
        r = lib.indexstore_unit_reader_create(store, u.encode(), ctypes.byref(err))
        if not r:
            continue
        main = text(lib.indexstore_unit_reader_get_main_file(r))
        lib.indexstore_unit_reader_dispose(r)
        if not main:
            keep.append(u)
            continue
        try:
            mtime = os.path.getmtime(os.path.join(units_dir, u))
        except OSError:
            mtime = 0
        if main not in newest or mtime > newest[main][0]:
            newest[main] = (mtime, u)
    lib.indexstore_store_dispose(store)
    return keep + [u for _, u in newest.values()], len(names)


def main():
    args = sys.argv[1:]
    all_units = "--all-units" in args
    args = [a for a in args if a != "--all-units"]
    if len(args) != 4:
        sys.exit(__doc__)
    libpath, store_path, src_root, out = args
    if not os.path.isfile(READER):
        common.fail(f"no index reader at {READER}")
    store_path = os.path.abspath(store_path)
    read_from = store_path
    note = ""
    if not all_units:
        keep, total = newest_units(libpath, store_path)
        if len(keep) < total:
            read_from = os.path.join(common.scratch("stores"), common.path_key(store_path))
            shutil.rmtree(read_from, ignore_errors=True)
            units = os.path.join(read_from, "v5", "units")
            os.makedirs(units)
            for u in keep:
                shutil.copy2(os.path.join(store_path, "v5", "units", u), units)
            os.symlink(os.path.join(store_path, "v5", "records"), os.path.join(read_from, "v5", "records"))
            note = f"indexstore: read the newest unit of each file: {len(keep)} of the store's {total} units"
    r = subprocess.run([sys.executable, "-B", READER, libpath, read_from, src_root, out])
    if note:
        print(note)
        shutil.rmtree(read_from, ignore_errors=True)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
