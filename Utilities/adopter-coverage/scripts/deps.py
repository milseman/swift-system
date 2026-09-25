#!/usr/bin/env python3
"""How much of a package's OS use goes through its dependencies.

The index store holds the dependencies' sources as well as the package's
(indexstore.py's `depGraph`): for every reference in a dependency, the
symbol it's contained in. That makes a call graph of the dependencies, with
protocol requirements linked to their implementations and properties to
their accessors, so a dependency symbol *reaches the OS* when its
implementation calls an OS function, directly or through other dependency
code. For each dependency package this reports:

  - its own OS use: the OS functions its sources call, and how often;
  - the package's boundary sites: lines in its library targets that
    reference the dependency's symbols, and how many of them reference a
    symbol that reaches the OS, with the symbols most used that way.

"May reach": a symbol counts however rarely the path is taken. A call the
package makes through a protocol requirement (or an overridable method)
counts if any implementation the build compiled reaches the OS; inside the
dependencies, calls are followed but dispatch isn't expanded again. That's
the primary count, and it misses OS work behind a dependency's own
protocols (TSC's WritableByteStream.send writes through its `write`
requirement). The upper bound expands dispatch everywhere, which
over-counts: linking every requirement to every implementation connects
nearly everything to something that does I/O. Process exit (exit, _exit,
abort) doesn't count as reaching the OS: it's what error paths do.

An OS function, for this measure, is a function the Darwin SDK's libc and
kernel interfaces declare (the Darwin module, its Swift overlays, MachO),
other than the C standard library's computation: strings, memory, math,
ctype and locale, and stdio's and stdlib's formatting, conversion, sorting
and allocation (malloc, memcpy, printf, strtol), and errno. File streams
count (fopen, fwrite, fflush), as do stdlib's realpath, mkstemp and getenv. Dispatch, the Apple
frameworks and C++'s standard library don't count, nor do uses of OS types
and constants, or their initializers. Nor do locks and thread-local storage
(pthread mutexes and keys, os_unfair_lock): a library takes them for its own
synchronization, and counting them would make nearly every symbol reach the
OS. What's left is OS work done for the caller, in System's scope.

Foundation from the SDK isn't in the index (it's a binary framework), so
nothing can be said about what reaches the OS through it; the report
counts the package's references to its types instead.
"""

import collections
import re
import subprocess

# indexstore_symbol_kind_t values that are called: functions and methods
# (not constructors: a C struct's zero initializer isn't OS use).
CALLED_KINDS = {12, 16, 17, 18}
LANG_CXX = 2
# The modules of the Darwin SDK's libc and kernel interfaces (and the other
# platforms', for a store made elsewhere); `<sdk>` is a header read
# textually.
OS_TOPS = {"Darwin", "_DarwinFoundation1", "_DarwinFoundation2", "_DarwinFoundation3", "MachO", "<sdk>", "Glibc",
           "Musl", "Android", "Bionic", "ucrt", "WinSDK", "WASILibc"}
# Synchronization: a library takes locks and thread-local storage for its own
# purposes, which isn't OS work done for its caller, and counting them would
# make nearly every symbol reach the OS.
SYNCHRONIZATION = re.compile(r"^(pthread_(mutex|cond|key|rwlock|once|getspecific|setspecific|spin)|os_unfair_lock|"
                             r"OSSpinLock|dispatch_)")
# The C standard library's computation-only headers, by module component or
# header name: strings, memory, math, ctype, locale. stdio.h and stdlib.h
# aren't among them, since they also hold file and process work (fopen,
# fwrite, rename, realpath, mkstemp, getenv, exit); their formatting,
# conversion, sorting and allocation functions are COMPUTATION.
C_LIBRARY = re.compile(r"(^|[./])_?(string|strings|math|ctype|wchar|wctype|stdint|stddef|assert|"
                       r"malloc|errno|inttypes|limits|float|locale|xlocale|stdarg|stdbool|secure|fenv|tgmath|"
                       r"_malloc|_types)(\.h)?($|[./])")
COMPUTATION = re.compile(r"^(v?[fsd]?n?printf|v?as?printf|v?[fs]?scanf|ato[fil]l?|strto\w*|qsort\w*|bsearch|"
                         r"l?l?abs|l?l?div|s?rand\w*|random|srandom|arc4random\w*|malloc|calloc|realloc|reallocf|"
                         r"free|posix_memalign|valloc|aligned_alloc|mblen|mbtowc|wctomb|mbstowcs|wcstombs|perror|"
                         r"setvbuf|setbuf|setlinebuf)$")


def os_function(nd):
    """Whether an external symbol is an OS function for this measure."""
    module, name, kind, lang = nd[1] or "", nd[2], nd[3], nd[4]
    header = nd[5] if len(nd) > 5 else ""
    if kind not in CALLED_KINDS or lang == LANG_CXX or name in ("errno", "") or name.startswith("__"):
        return False
    if module.split(".")[0] not in OS_TOPS:
        return False
    # The macOS 26 SDK's _DarwinFoundation1 overlay, without a submodule,
    # holds the C library's math functions and POSIXErrorCode.
    if module == "_DarwinFoundation1":
        return False
    if header.startswith("c++/") or C_LIBRARY.search(header or "") or C_LIBRARY.search(module):
        return False
    if SYNCHRONIZATION.match(name) or COMPUTATION.match(name) or header.startswith(("dispatch/", "os/lock")) \
            or name in ("stdin", "stdout", "stderr", "exit", "_exit", "abort"):
        return False
    return True


def reach_sets(n, succ, os_bit, roots):
    """Bitsets of the OS functions reachable from each node reachable from
    `roots`: an iterative Tarjan's algorithm, whose strongly connected
    components come out sinks first, so each one's successors are done
    before it."""
    index, low, comp = {}, {}, {}
    on, stack, reach_c = set(), [], []
    counter = [0]
    for root in roots:
        if root in index:
            continue
        work = [(root, iter(succ.get(root, ())))]
        index[root] = low[root] = counter[0]
        counter[0] += 1
        stack.append(root)
        on.add(root)
        while work:
            v, it = work[-1]
            advanced = False
            for w in it:
                if w not in index:
                    index[w] = low[w] = counter[0]
                    counter[0] += 1
                    stack.append(w)
                    on.add(w)
                    work.append((w, iter(succ.get(w, ()))))
                    advanced = True
                    break
                if w in on:
                    low[v] = min(low[v], index[w])
            if advanced:
                continue
            work.pop()
            if work:
                u = work[-1][0]
                low[u] = min(low[u], low[v])
            if low[v] == index[v]:
                members = []
                while True:
                    w = stack.pop()
                    on.discard(w)
                    members.append(w)
                    if w == v:
                        break
                c = len(reach_c)
                bits = 0
                for m in members:
                    comp[m] = c
                for m in members:
                    bits |= os_bit.get(m, 0)
                    for w in succ.get(m, ()):
                        if comp.get(w, c) != c:
                            bits |= reach_c[comp[w]]
                reach_c.append(bits)
    return {v: reach_c[c] for v, c in comp.items()}


def bit_names(bits, names, limit):
    out = []
    k = 0
    while bits and len(out) < limit:
        if bits & 1:
            out.append(names[k])
        bits >>= 1
        k += 1
    return out


def demangle(usrs):
    usrs = sorted(usrs)
    if not usrs:
        return {}
    try:
        out = subprocess.run(["xcrun", "swift-demangle", "--simplified"], capture_output=True, text=True,
                             input="\n".join("$s" + u[2:] for u in usrs)).stdout.split("\n")
    except OSError:
        return {}
    return dict(zip(usrs, out))


def analyze(index, cls, lib_names, is_os_module, foundation_modules, through):
    """The `dependencies` section of interfaces.json. `cls` is extract.py's
    Classifier; `is_os_module(module)` says whether a module is the OS's;
    `through` names the dependency packages the report dwells on."""
    graph = index.get("depGraph")
    if not graph:
        return None
    packages, nodes = graph["packages"], graph["nodes"]
    succ = collections.defaultdict(list)
    for a, b in graph["edges"]:
        succ[a].append(b)
    for prop, acc in graph["accessors"]:
        succ[prop].append(acc)
    overrides = collections.defaultdict(list)
    for base, over in graph["overrides"]:
        overrides[base].append(over)

    os_nodes = [k for k, nd in enumerate(nodes) if nd[0] == -1 and os_function(nd) and is_os_module(nd[1])]
    os_bit = {k: 1 << b for b, k in enumerate(os_nodes)}
    os_names = [nodes[k][2] for k in os_nodes]
    boundary = graph["boundary"]
    # One level of dispatch, at the package's call site: a boundary symbol
    # reaches what it and every override or implementation of it reach.
    roots = set(boundary.values())
    for b in list(roots):
        roots.update(overrides.get(b, ()))
        for acc in succ.get(b, ()):
            roots.update(overrides.get(acc, ()))
    calls = reach_sets(len(nodes), succ, os_bit, sorted(roots))
    # The upper bound: dispatch expanded everywhere.
    succ_all = collections.defaultdict(list)
    for a, bs in succ.items():
        succ_all[a].extend(bs)
    for base, overs in overrides.items():
        succ_all[base].extend(overs)
    upper = reach_sets(len(nodes), succ_all, os_bit, sorted(set(boundary.values())))
    reach = {}
    for b in set(boundary.values()):
        bits = calls.get(b, 0)
        for o in overrides.get(b, ()):
            bits |= calls.get(o, 0)
        for acc in succ.get(b, ()):
            for o in overrides.get(acc, ()):
                bits |= calls.get(o, 0)
        reach[b] = bits

    # The package's references to dependency symbols, per line.
    decls = index["decls"]
    per_pkg = {p: {"sites": set(), "reachingSites": set(), "upperSites": set(), "symbols": collections.Counter(),
                   "reaching": collections.Counter()} for p in packages}
    usr_pkg = {}
    foundation = collections.Counter()
    foundation_usrs = set()
    for usr, name, lang, kind, f, line, col, roles in index["refs"]:
        if cls.target_of(f) not in lib_names or usr.startswith("c:@M@"):
            continue
        d = decls.get(usr)
        if d is None:
            continue
        m = re.search(r"/checkouts/([^/]+)/", d[1] or "")
        if m and m.group(1) in per_pkg:
            p = m.group(1)
            ent = per_pkg[p]
            ent["sites"].add((f, line))
            ent["symbols"][usr] += 1
            usr_pkg[usr] = p
            k = boundary.get(usr)
            if k is not None and reach.get(k):
                ent["reachingSites"].add((f, line))
                ent["reaching"][usr] += 1
            if k is not None and upper.get(k):
                ent["upperSites"].add((f, line))
        elif (d[0] or "").split(".")[0] in foundation_modules and usr.startswith("s:"):
            foundation[usr] += 1
            foundation_usrs.add(usr)

    names = demangle(set(usr_pkg) | foundation_usrs)

    def short(usr):
        dn = names.get(usr) or usr
        dn = re.sub(r"^\(extension in [^)]*\):", "", dn)
        return re.sub(r"^(static |class )", "", dn).split(" : ")[0]

    out = {"packages": {}, "through": through}
    for p in packages:
        ent = per_pkg[p]
        own_os = collections.Counter()
        for k, n in graph["sites"].get(p, {}).items():
            nd = nodes[int(k)]
            if os_function(nd) and is_os_module(nd[1]):
                own_os[nd[2]] += n
        top = []
        for usr, n in ent["reaching"].most_common(15):
            bits = reach.get(boundary[usr], 0)
            top.append({"symbol": short(usr), "sites": n, "reachCount": bin(bits).count("1"),
                        "reaches": bit_names(bits, os_names, 8)})
        out["packages"][p] = {
            "osFunctions": len(own_os), "osSites": sum(own_os.values()),
            "topOs": own_os.most_common(12),
            "boundarySites": len(ent["sites"]), "boundarySymbols": len(ent["symbols"]),
            "reachingSites": len(ent["reachingSites"]), "reachingSymbols": len(ent["reaching"]),
            "upperSites": len(ent["upperSites"]),
            "top": top,
        }
    types = collections.Counter()
    for usr, n in foundation.items():
        head = short(usr)
        comps = head.split("(")[0].split(".")
        types[comps[1] if len(comps) > 1 and comps[0] == "Foundation" else comps[0]] += n
    out["foundation"] = {"sites": sum(foundation.values()), "types": types.most_common(15)}
    out["graph"] = {"symbols": len(nodes), "edges": len(graph["edges"]), "osFunctions": len(os_nodes),
                    "reached": sum(1 for v in calls.values() if v)}
    return out
