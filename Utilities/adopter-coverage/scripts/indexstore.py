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

With DEPS_ROOT (the build's `checkouts` directory), also `depGraph`, the
call graph of the package's dependencies, for deps.py. Its symbols are
numbered:
  packages    the dependency packages (the directories of DEPS_ROOT)
  nodes       per symbol: [package index] for one declared in a dependency,
              [-1, module, name, kind, language] for one declared elsewhere
              (the OS, the Swift libraries, Foundation), [-2] if unknown
  edges       [container, referenced] pairs, one per pair, from each
              reference's containedBy or calledBy relation
  overrides   [base, override] pairs (a protocol requirement and a type's
              implementation of it, or a method and its override), from
              the overrideOf relations of definitions
  accessors   [property, accessor] pairs, from accessorOf relations
  boundary    {USR: symbol} for the dependency symbols the package's own
              sources reference
  sites       for each dependency package, how many references its sources
              make to each symbol declared outside the checkouts:
              {package: {symbol: count}}

Usage: indexstore.py LIBINDEXSTORE STORE_DIR SRC_ROOT OUT.json [DEPS_ROOT]
"""

import ctypes
import json
import re
import sys

ROLE_DECLARATION = 1 << 0
ROLE_DEFINITION = 1 << 1
ROLE_REFERENCE = 1 << 2
REL_CALLEDBY = 1 << 13
REL_CONTAINEDBY = 1 << 16
REL_OVERRIDEOF = 1 << 11
REL_ACCESSOROF = 1 << 15
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
        ("indexstore_occurrence_relations_apply_f", ctypes.c_bool, [vp, vp, vp]),
        ("indexstore_symbol_relation_get_roles", ctypes.c_uint64, [vp]),
        ("indexstore_symbol_relation_get_symbol", vp, [vp]),
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
    deps_root = sys.argv[5].rstrip("/") + "/" if len(sys.argv) > 5 else None
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
                # it; a Swift file's record, to the unit's module. A header
                # that a non-modular C unit includes textually has no module
                # there, so a later unit's module name wins over none.
                mod = text(lib.indexstore_unit_dependency_get_modulename(dep)) or module
                if name not in records or (mod and not records[name][1]):
                    records[name] = (path, mod)
            return True

        lib.indexstore_unit_reader_dependencies_apply_f(r, None, on_dep)
        lib.indexstore_unit_reader_dispose(r)

    decls = {}     # usr -> [module, file]
    vocab = {}     # module -> {name: [kind mask, language mask]}
    refs = []
    line = ctypes.c_uint()
    col = ctypes.c_uint()
    # The dependencies' call graph, with symbols numbered.
    dep_ids, dep_usrs, dep_info = {}, [], []
    dep_edges, dep_over, dep_acc = set(), set(), set()
    dep_sites = {}

    def intern(u, sym=None):
        k = dep_ids.get(u)
        if k is None:
            k = dep_ids[u] = len(dep_usrs)
            dep_usrs.append(u)
            dep_info.append(None)
        if sym is not None and dep_info[k] is None:
            dep_info[k] = (base_name(text(lib.indexstore_symbol_get_name(sym))), lib.indexstore_symbol_get_kind(sym),
                           lib.indexstore_symbol_get_language(sym))
        return k

    related = []

    @PTR_CB
    def on_rel(_ctx, rel):
        related.append((lib.indexstore_symbol_relation_get_roles(rel),
                        text(lib.indexstore_symbol_get_usr(lib.indexstore_symbol_relation_get_symbol(rel)))))
        return True

    for rec, (path, module) in sorted(records.items()):
        in_src = path.startswith(src_root)
        # A header no unit read as part of a module: name it by where it is,
        # so the vocabulary can tell the package's own names ("") from a
        # dependency's ("<dependency>/swift-foundation-icu") and the SDK's
        # ("<sdk>").
        if not module and not in_src:
            if deps_root and path.startswith(deps_root):
                module = "<dependency>/" + path[len(deps_root):].split("/")[0]
            elif ".sdk/" in path:
                module = "<sdk>"
        dep_pkg = path[len(deps_root):].split("/")[0] if deps_root and path.startswith(deps_root) else None
        rr = lib.indexstore_record_reader_create(store, rec.encode(), ctypes.byref(err))
        if not rr:
            continue

        @PTR_CB
        def on_occ(_ctx, occ):
            sym = lib.indexstore_occurrence_get_symbol(occ)
            roles = lib.indexstore_occurrence_get_roles(occ)
            usr = text(lib.indexstore_symbol_get_usr(sym))
            if dep_pkg is not None and roles & (REL_CONTAINEDBY | REL_CALLEDBY | REL_OVERRIDEOF | REL_ACCESSOROF):
                del related[:]
                lib.indexstore_occurrence_relations_apply_f(occ, None, on_rel)
                if roles & ROLE_REFERENCE:
                    container = next((u for r, u in related if r & REL_CONTAINEDBY), None) \
                        or next((u for r, u in related if r & REL_CALLEDBY), None)
                    if container:
                        dep_edges.add((intern(container), intern(usr, sym)))
                if roles & (ROLE_DECLARATION | ROLE_DEFINITION):
                    for r, u in related:
                        if r & REL_OVERRIDEOF:
                            dep_over.add((intern(u), intern(usr)))
                        if r & REL_ACCESSOROF:
                            dep_acc.add((intern(u), intern(usr)))
            if dep_pkg is not None and roles & ROLE_REFERENCE:
                sites = dep_sites.setdefault(dep_pkg, {})
                k = intern(usr, sym)
                sites[k] = sites.get(k, 0) + 1
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
    graph = None
    if deps_root:
        packages = sorted({decls[u][1][len(deps_root):].split("/")[0] for u in dep_usrs
                           if u in decls and decls[u][1].startswith(deps_root)})
        pkg_index = {p: k for k, p in enumerate(packages)}
        nodes = []
        for k, u in enumerate(dep_usrs):
            d = decls.get(u)
            if d is None:
                nodes.append([-2])
            elif d[1].startswith(deps_root):
                nodes.append([pkg_index[d[1][len(deps_root):].split("/")[0]]])
            else:
                name, kind, lang = dep_info[k] or ("", 0, 0)
                nodes.append([-1, d[0], name, kind, lang])
        # Site counts only for symbols declared outside the checkouts: what
        # each dependency uses of the OS, the Swift libraries and Foundation.
        graph = {"packages": packages, "nodes": nodes, "edges": sorted(dep_edges),
                 "overrides": sorted(dep_over), "accessors": sorted(dep_acc),
                 "boundary": {u: dep_ids[u] for u in sorted(referenced) if u in dep_ids},
                 "sites": {p: {str(k): n for k, n in sorted(v.items()) if nodes[k][0] == -1}
                           for p, v in sorted(dep_sites.items())}}
    json.dump({
        "refs": refs,
        "decls": {u: decls[u] for u in referenced if u in decls},
        "vocab": vocab,
        "units": units,
        "depGraph": graph,
    }, open(out, "w"))
    print(f"indexstore: {len(unit_names)} units, {len(records)} records, "
          f"{len(refs)} references under {src_root}"
          + (f"; dependencies: {len(dep_edges)} call-graph edges among {len(dep_usrs)} symbols" if deps_root else ""))


if __name__ == "__main__":
    main()
