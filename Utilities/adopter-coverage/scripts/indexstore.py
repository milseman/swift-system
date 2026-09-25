#!/usr/bin/env python3
"""Read a Clang/Swift index store through libIndexStore and dump what
extract.py needs.

SwiftPM writes an index store during a debug build on macOS. It holds one
record per source file, listing every symbol occurrence with its USR, kind,
language and roles, for Swift and C alike. This script reads it with ctypes,
so it needs nothing beyond the toolchain's libIndexStore.dylib.

Output (JSON):
  refs    every reference occurrence in a file under SRC_ROOT:
          [usr, name, language, kind, file, line, column, roles]
  decls   for each referenced USR, the module and file that declare it
          ([module, file, whether that's a definition])
  vocab   names declared in each module, for the lexical scans:
          {module: {name: [kind mask, language mask]}}, with Swift names
          reduced to their base name; bit k of the kind mask is
          indexstore_symbol_kind_t k, and the language mask has bit 0 for C
          and bit 1 for Swift
  units   module name and main file of each non-system unit

Usage: indexstore.py LIBINDEXSTORE STORE_DIR SRC_ROOT OUT.json
"""

import ctypes
import json
import re
import sys

ROLE_DECLARATION = 1 << 0
ROLE_DEFINITION = 1 << 1
ROLE_REFERENCE = 1 << 2
DEP_RECORD = 2
LANG_SWIFT = 100


class StringRef(ctypes.Structure):
    _fields_ = [("data", ctypes.c_char_p), ("length", ctypes.c_size_t)]


def text(ref):
    return ctypes.string_at(ref.data, ref.length).decode("utf-8", "replace") if ref.length else ""


def load(path):
    lib = ctypes.CDLL(path)
    vp = ctypes.c_void_p
    for name, res, args in [
        ("indexstore_store_create", vp, [ctypes.c_char_p, ctypes.POINTER(vp)]),
        ("indexstore_store_dispose", None, [vp]),
        ("indexstore_error_get_description", ctypes.c_char_p, [vp]),
        ("indexstore_store_units_apply_f", ctypes.c_bool, [vp, ctypes.c_uint, vp, vp]),
        ("indexstore_unit_reader_create", vp, [vp, ctypes.c_char_p, ctypes.POINTER(vp)]),
        ("indexstore_unit_reader_dispose", None, [vp]),
        ("indexstore_unit_reader_get_module_name", StringRef, [vp]),
        ("indexstore_unit_reader_get_main_file", StringRef, [vp]),
        ("indexstore_unit_reader_is_system_unit", ctypes.c_bool, [vp]),
        ("indexstore_unit_reader_dependencies_apply_f", ctypes.c_bool, [vp, vp, vp]),
        ("indexstore_unit_dependency_get_kind", ctypes.c_int, [vp]),
        ("indexstore_unit_dependency_get_filepath", StringRef, [vp]),
        ("indexstore_unit_dependency_get_modulename", StringRef, [vp]),
        ("indexstore_unit_dependency_get_name", StringRef, [vp]),
        ("indexstore_record_reader_create", vp, [vp, ctypes.c_char_p, ctypes.POINTER(vp)]),
        ("indexstore_record_reader_dispose", None, [vp]),
        ("indexstore_record_reader_occurrences_apply_f", ctypes.c_bool, [vp, vp, vp]),
        ("indexstore_occurrence_get_symbol", vp, [vp]),
        ("indexstore_occurrence_get_roles", ctypes.c_uint64, [vp]),
        ("indexstore_occurrence_get_line_col", None,
         [vp, ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_uint)]),
        ("indexstore_symbol_get_language", ctypes.c_int, [vp]),
        ("indexstore_symbol_get_kind", ctypes.c_int, [vp]),
        ("indexstore_symbol_get_name", StringRef, [vp]),
        ("indexstore_symbol_get_usr", StringRef, [vp]),
    ]:
        f = getattr(lib, name)
        f.restype = res
        f.argtypes = args
    return lib


UNIT_CB = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, StringRef)
PTR_CB = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)


def base_name(name):
    """'write(_:_:_:)' -> 'write'; 'getter:errno' -> 'errno'."""
    name = re.sub(r"^(getter|setter|_modify|_read|willSet|didSet|init):", "", name)
    return name.split("(")[0]


def main():
    libpath, store_path, src_root, out = sys.argv[1:5]
    src_root = src_root.rstrip("/") + "/"
    lib = load(libpath)
    err = ctypes.c_void_p()
    store = lib.indexstore_store_create(store_path.encode(), ctypes.byref(err))
    if not store:
        sys.exit(f"indexstore: can't open {store_path}: "
                 f"{lib.indexstore_error_get_description(err).decode()}")

    unit_names = []

    @UNIT_CB
    def on_unit(_ctx, name):
        unit_names.append(text(name))
        return True

    lib.indexstore_store_units_apply_f(store, 0, None, on_unit)

    records = {}   # record name -> (file, module)
    units = []
    for u in unit_names:
        r = lib.indexstore_unit_reader_create(store, u.encode(), ctypes.byref(err))
        if not r:
            continue
        module = text(lib.indexstore_unit_reader_get_module_name(r))
        main_file = text(lib.indexstore_unit_reader_get_main_file(r))
        if not lib.indexstore_unit_reader_is_system_unit(r):
            units.append({"module": module, "mainFile": main_file})

        @PTR_CB
        def on_dep(_ctx, dep):
            if lib.indexstore_unit_dependency_get_kind(dep) == DEP_RECORD:
                name = text(lib.indexstore_unit_dependency_get_name(dep))
                path = text(lib.indexstore_unit_dependency_get_filepath(dep))
                # A header's record belongs to the Clang (sub)module that owns
                # it; a Swift file's record, to the unit's module.
                mod = text(lib.indexstore_unit_dependency_get_modulename(dep)) or module
                records.setdefault(name, (path, mod))
            return True

        lib.indexstore_unit_reader_dependencies_apply_f(r, None, on_dep)
        lib.indexstore_unit_reader_dispose(r)

    decls = {}     # usr -> [module, file]
    vocab = {}     # module -> {name: [kind mask, language mask]}
    refs = []
    line = ctypes.c_uint()
    col = ctypes.c_uint()
    for rec, (path, module) in sorted(records.items()):
        in_src = path.startswith(src_root)
        rr = lib.indexstore_record_reader_create(store, rec.encode(), ctypes.byref(err))
        if not rr:
            continue

        @PTR_CB
        def on_occ(_ctx, occ):
            sym = lib.indexstore_occurrence_get_symbol(occ)
            roles = lib.indexstore_occurrence_get_roles(occ)
            usr = text(lib.indexstore_symbol_get_usr(sym))
            if roles & (ROLE_DECLARATION | ROLE_DEFINITION):
                # Prefer a definition to a forward declaration, so that
                # `struct sockaddr` is attributed to <sys/socket.h>.
                if usr in decls and roles & ROLE_DEFINITION and not decls[usr][2]:
                    decls[usr] = [module, path, True]
                if usr not in decls:
                    decls[usr] = [module, path, bool(roles & ROLE_DEFINITION)]
                    entry = vocab.setdefault(module, {}).setdefault(
                        base_name(text(lib.indexstore_symbol_get_name(sym))), [0, 0])
                    entry[0] |= 1 << min(lib.indexstore_symbol_get_kind(sym), 62)
                    entry[1] |= 2 if lib.indexstore_symbol_get_language(sym) == LANG_SWIFT else 1
            elif in_src and roles & ROLE_REFERENCE:
                lib.indexstore_occurrence_get_line_col(occ, ctypes.byref(line), ctypes.byref(col))
                refs.append([usr, text(lib.indexstore_symbol_get_name(sym)),
                             lib.indexstore_symbol_get_language(sym), lib.indexstore_symbol_get_kind(sym),
                             path[len(src_root):], line.value, col.value, roles])
            return True

        lib.indexstore_record_reader_occurrences_apply_f(rr, None, on_occ)
        lib.indexstore_record_reader_dispose(rr)
    lib.indexstore_store_dispose(store)

    referenced = {r[0] for r in refs}
    json.dump({
        "refs": refs,
        "decls": {u: decls[u] for u in referenced if u in decls},
        "vocab": vocab,
        "units": units,
    }, open(out, "w"))
    print(f"indexstore: {len(unit_names)} units, {len(records)} records, "
          f"{len(refs)} references under {src_root}")


if __name__ == "__main__":
    main()
