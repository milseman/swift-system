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

"May reach": a call through a protocol counts if any implementation the
build compiled reaches the OS, whichever one runs, and a symbol counts
however rarely the path is taken. Only calls of functions count, not uses
of OS types or constants.

Foundation from the SDK isn't in the index (it's a binary framework), so
nothing can be said about what reaches the OS through it; the report
counts the package's references to its types instead.
"""

import collections
import re
import subprocess

# indexstore_symbol_kind_t values that are called: functions, methods,
# constructors.
CALLED_KINDS = {12, 16, 17, 18, 22}


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
    for base, over in graph["overrides"]:
        succ[base].append(over)
    for prop, acc in graph["accessors"]:
        succ[prop].append(acc)

    os_nodes = [k for k, nd in enumerate(nodes) if nd[0] == -1 and nd[3] in CALLED_KINDS and is_os_module(nd[1])]
    os_bit = {k: 1 << b for b, k in enumerate(os_nodes)}
    os_names = [nodes[k][2] for k in os_nodes]
    boundary = graph["boundary"]
    reach = reach_sets(len(nodes), succ, os_bit, sorted(set(boundary.values())))

    # The package's references to dependency symbols, per line.
    decls = index["decls"]
    per_pkg = {p: {"sites": set(), "reachingSites": set(), "symbols": collections.Counter(),
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
            if nd[3] in CALLED_KINDS and is_os_module(nd[1]):
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
            "top": top,
        }
    types = collections.Counter()
    for usr, n in foundation.items():
        head = short(usr)
        comps = head.split("(")[0].split(".")
        types[comps[1] if len(comps) > 1 and comps[0] == "Foundation" else comps[0]] += n
    out["foundation"] = {"sites": sum(foundation.values()), "types": types.most_common(15)}
    out["graph"] = {"symbols": len(nodes), "edges": len(graph["edges"]), "osFunctions": len(os_nodes),
                    "reached": sum(1 for v in reach.values() if v)}
    return out
