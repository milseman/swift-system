#!/usr/bin/env python3
"""Read the references out of a clang/Swift index store, with libIndexStore.

A build with `-index-store-path` records every occurrence of every symbol,
by USR: the same identifiers the symbol graphs use. This reads the store
through the toolchain's libIndexStore.dylib, with ctypes, and keeps:

  - references to SystemPackage and SystemSockets symbols, from every file
    of the package (Sources, Tests, Samples), by file and line;
  - references to C symbols (`c:` USRs) from the package's own Sources, so
    that a wrapper can be traced to the C function or CSystem shim it calls;
  - the definition sites of the package's symbols, internal ones included.

Only the `_f` (function pointer) variants of the store's apply functions are
used, since Python can't make blocks, and units are listed from the store's
directory rather than with `indexstore_store_units_apply_f`, whose callback
takes a struct by value.

Usage: index_refs.py STORE ROOT OUT.json
  ROOT is the source root the build compiled; paths are made relative to it.
"""

import ctypes
import json
import os
import subprocess
import sys

KEEP_SWIFT = ("s:13SystemPackage", "s:13SystemSockets")
KIND_PARAMETER = 25
ROLE_DECLARATION, ROLE_DEFINITION, ROLE_REFERENCE = 1 << 0, 1 << 1, 1 << 2
ROLE_CALL, ROLE_IMPLICIT = 1 << 5, 1 << 8
DEP_RECORD = 2


class StringRef(ctypes.Structure):
    _fields_ = [("data", ctypes.c_void_p), ("length", ctypes.c_size_t)]


def text(ref):
    return ctypes.string_at(ref.data, ref.length).decode("utf-8", "replace") if ref.length else ""


def load_library():
    dev = subprocess.run(["xcode-select", "-p"], capture_output=True, text=True).stdout.strip()
    candidates = [os.path.join(dev, "Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")]
    swiftc = subprocess.run(["xcrun", "--find", "swiftc"], capture_output=True, text=True).stdout.strip()
    if swiftc:
        candidates.append(os.path.join(os.path.dirname(os.path.dirname(swiftc)), "lib", "libIndexStore.dylib"))
    for path in candidates:
        if os.path.exists(path):
            return ctypes.CDLL(path)
    sys.exit("index_refs: libIndexStore.dylib not found in " + ", ".join(candidates))


def bind(lib):
    vp, cp, cu = ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint
    sig = {
        "indexstore_store_create": (vp, [cp, ctypes.POINTER(vp)]),
        "indexstore_error_get_description": (cp, [vp]),
        "indexstore_unit_reader_create": (vp, [vp, cp, ctypes.POINTER(vp)]),
        "indexstore_unit_reader_dispose": (None, [vp]),
        "indexstore_unit_reader_is_system_unit": (ctypes.c_bool, [vp]),
        "indexstore_unit_reader_get_module_name": (StringRef, [vp]),
        "indexstore_unit_reader_get_main_file": (StringRef, [vp]),
        "indexstore_unit_dependency_get_kind": (ctypes.c_int, [vp]),
        "indexstore_unit_dependency_get_filepath": (StringRef, [vp]),
        "indexstore_unit_dependency_get_name": (StringRef, [vp]),
        "indexstore_record_reader_create": (vp, [vp, cp, ctypes.POINTER(vp)]),
        "indexstore_record_reader_dispose": (None, [vp]),
        "indexstore_occurrence_get_symbol": (vp, [vp]),
        "indexstore_occurrence_get_roles": (ctypes.c_uint64, [vp]),
        "indexstore_occurrence_get_line_col": (None, [vp, ctypes.POINTER(cu), ctypes.POINTER(cu)]),
        "indexstore_symbol_get_usr": (StringRef, [vp]),
        "indexstore_symbol_get_name": (StringRef, [vp]),
        "indexstore_symbol_get_kind": (ctypes.c_int, [vp]),
    }
    for name, (res, args) in sig.items():
        fn = getattr(lib, name)
        fn.restype = res
        fn.argtypes = args
    cb = ctypes.CFUNCTYPE(ctypes.c_bool, vp, vp)
    lib.indexstore_unit_reader_dependencies_apply_f.argtypes = [vp, vp, cb]
    lib.indexstore_unit_reader_dependencies_apply_f.restype = ctypes.c_bool
    lib.indexstore_record_reader_occurrences_apply_f.argtypes = [vp, vp, cb]
    lib.indexstore_record_reader_occurrences_apply_f.restype = ctypes.c_bool
    return cb


def read_store(store_path, root, keep, definitions_too=True):
    """The occurrences in a store's records for files under root that
    `keep(usr, rel, is_c)` accepts: {rel: {"module", "references": [[line,
    col, usr, flags]]}}, the symbols' names and kinds, their definition
    sites, and every file under root the store has a record for (a file the
    build compiled), whether or not anything in it was kept. A record of a
    file that's gone is skipped: a store an incremental build kept still
    has the units of files since deleted."""
    root = os.path.realpath(root) + os.sep
    lib = load_library()
    callback = bind(lib)
    err = ctypes.c_void_p()
    store = lib.indexstore_store_create(store_path.encode(), ctypes.byref(err))
    if not store:
        sys.exit("index_refs: can't open the store: " + lib.indexstore_error_get_description(err).decode())

    # Units name the records they depend on, and each record's source file.
    records = {}
    version_dirs = sorted(d for d in os.listdir(store_path) if d.startswith("v"))
    unit_names = sorted(os.listdir(os.path.join(store_path, version_dirs[-1], "units")))
    for unit in unit_names:
        reader = lib.indexstore_unit_reader_create(store, unit.encode(), ctypes.byref(err))
        if not reader:
            continue
        if lib.indexstore_unit_reader_is_system_unit(reader):
            lib.indexstore_unit_reader_dispose(reader)
            continue
        module = text(lib.indexstore_unit_reader_get_module_name(reader))

        def on_dependency(_ctx, dep, module=module):
            if lib.indexstore_unit_dependency_get_kind(dep) == DEP_RECORD:
                path = os.path.realpath(text(lib.indexstore_unit_dependency_get_filepath(dep)))
                if path.startswith(root) and os.path.exists(path):
                    records[text(lib.indexstore_unit_dependency_get_name(dep))] = (path[len(root):], module)
            return True

        keep_dep = callback(on_dependency)
        lib.indexstore_unit_reader_dependencies_apply_f(reader, None, keep_dep)
        lib.indexstore_unit_reader_dispose(reader)

    files, symbols, definitions = {}, {}, {}
    for record, (rel, module) in sorted(records.items(), key=lambda kv: kv[1]):
        reader = lib.indexstore_record_reader_create(store, record.encode(), ctypes.byref(err))
        if not reader:
            continue
        occurrences = []
        line, col = ctypes.c_uint(), ctypes.c_uint()

        def on_occurrence(_ctx, occ, rel=rel):
            sym = lib.indexstore_occurrence_get_symbol(occ)
            usr = text(lib.indexstore_symbol_get_usr(sym))
            if not keep(usr, rel, usr.startswith("c:")):
                return True
            kind = lib.indexstore_symbol_get_kind(sym)
            if kind == KIND_PARAMETER:
                return True
            roles = lib.indexstore_occurrence_get_roles(occ)
            lib.indexstore_occurrence_get_line_col(occ, ctypes.byref(line), ctypes.byref(col))
            if usr not in symbols:
                symbols[usr] = {"name": text(lib.indexstore_symbol_get_name(sym)), "kind": kind}
            if definitions_too and roles & (ROLE_DEFINITION | ROLE_DECLARATION):
                definitions.setdefault(usr, []).append([rel, line.value, col.value])
            if roles & ROLE_REFERENCE:
                occurrences.append([line.value, col.value, usr, int(roles & (ROLE_CALL | ROLE_IMPLICIT))])
            return True

        keep_occ = callback(on_occurrence)
        lib.indexstore_record_reader_occurrences_apply_f(reader, None, keep_occ)
        lib.indexstore_record_reader_dispose(reader)
        entry = files.setdefault(rel, {"module": module, "references": []})
        entry["references"].extend(occurrences)

    for v in definitions.values():
        v.sort()
    for f in files.values():
        # A file compiled into several units (a test helper, say) repeats.
        f["references"] = sorted(set(map(tuple, f["references"])))
    return files, symbols, definitions, len(records)


def main():
    store_path, root, out = sys.argv[1:4]

    def keep(usr, rel, is_c):
        in_sources = rel.startswith("Sources/") and not rel.startswith("Sources/Samples/")
        return usr.startswith(KEEP_SWIFT) or (is_c and in_sources)

    files, symbols, definitions, n_records = read_store(store_path, root, keep)
    json.dump({"files": files, "symbols": symbols, "definitions": definitions}, open(out, "w"))
    n = sum(len(f["references"]) for f in files.values())
    print(f"index_refs: {n_records} records, {len(files)} files, {n} references, "
          f"{len(definitions)} defined symbols -> {out}")


if __name__ == "__main__":
    main()
