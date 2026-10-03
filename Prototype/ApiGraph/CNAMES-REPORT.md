# cnames: C names from field sentences and from code

Lane `cnames`, worktree `../cnames`, branch `cnames`, made from system-next `d5541b6` (system-next hasn't moved since). It owns `Utilities/api-graph/`, `Utilities/api-burndown/`, `Prototype/Burndown/`, `Prototype/ApiGraph/REPORT.md` and this report. It changed tools only: `git diff system-next -- Sources Utilities/adopter-coverage` is empty.

## Resume here

Done, 2026-10-03. Nothing in the lane is open; section 5 lists what's next for other lanes.

- `c281af4`: api-graph: doc links for field and property sentences, code links, `sources`, schema 2, `graphq.py` sources and `doc-sentences`, tests.
- `f2e7e8e`: api-burndown: both sources, Swift-only, grouping by header, no history chart or stale-`main` banner.
- `095333c`: api-graph: a synthesized member reaches no C; the work list's types section.
- The last commit: `Prototype/Burndown/burndown.html`, from runs of both tools at `095333c`, and this report.

**To rerun:** `Utilities/api-graph/regenerate.sh`, then `Utilities/api-burndown/regenerate.sh`. After this lane merges, run api-graph before the burn-down in any worktree: until the snapshot store has a schema-2 snapshot of the head commit, the burn-down's `auto` choice can take a schema-1 graph, which has no code links and no `reachesC` (the page still works: every C name is stated, and nothing is Swift-only).

**The snapshot store wasn't written:** every run here had `API_GRAPH_SNAPSHOTS=` and diffed with a copy of the store's `d5541b6` snapshot. The first default run after the merge files a schema-2 snapshot, and its `DIFF.md` shows the one-time jump (section 4).

**Kept in `.build`:** `api-graph/` (the output at the tip, which the burn-down's `auto` choice reads), `api-graph-cache/`, `api-burndown/`. **Deleted:** `api-graph-builds/` (14 GB of my own; the next run that has to rebuild a migration builds it cold), the scratch directories, and a `Utilities/api-delta/scripts/__pycache__` one of my runs left.

## 1. What changed

- **Cause A, field and property sentences.** `cnames.py` reads them with derive.py's own grammar (`sentences`, `parse`, `c_name`, imported read-only), which derive.py reads but leaves out of what it covers. Each is a `doc` link of C kind `field`, named for its struct where one can be found (`qualify`), so the coverage reports are unchanged.
- **Cause B, C reached only through code.** `build_graph.py` walks each declaration's code through the internal code it calls (`walk_c`) and records `cRefs` (functions, macros, enum constants, variables, fields as `struct.field`, each with its C kind), `cCalls` (the functions) and `reachesC`. `cnames.py` makes a `code` link of each, merged with the doc link to the same C name.
- **Links.** A `wraps` link has `sources` (`doc`, `typealias`, `code`) and `cKind`; the snapshot schema is `api-graph-snapshot/2`. Only stated links (doc or typealias) feed reach, families, domains, pitch rules and adopters' would-benefit join (`graphq.stated`, `graphq.could_use`). Schema: `Prototype/ApiGraph/REPORT.md` section 1; decisions 40 and 41 in `Utilities/api-graph/scripts/method.md`.
- **`graphq.py`** prints each wraps link's sources (`show`, `cname`, `type --members`); `GRAPH.md` counts wraps links by source.
- **The work list,** `DOC-SENTENCES.md` in the api-graph output, from `graphq.py doc-sentences`: declarations whose code reaches C that no doc sentence of theirs names, with what it reaches; types whose members reach C that no sentence names a C type for; declarations with no doc comment (marked when they inherit one). All by file and line, fix-it stubs and underscored declarations left out.
- **The burn-down** reads both sources and marks code-only C names "code"; labels declarations that reach no C "Swift-only"; groups by header, with the SDK module in small print, then by C name; and has no history chart and no stale-`main` banner (`upstream` stays a row flag). README design calls 5, 12, 13 and 17-19.

## 2. Design calls

Each with the alternative it rejected. The ones that are judgment calls are open questions, implemented as defaults.

1. **Field sentences through derive.py's grammar, in api-graph.** *Rejected:* `build_graph.py`'s `cNames` (the suggested default): they have no roles, and its pattern didn't match "C property" sentences (it does now, for `cNames` too). *Rejected:* editing derive.py, which would change what coverage calls covered.
2. **A field's struct, in order** (`qualify`): the declaration's own code reference to a field of that name; the sentence's spelling (`sched_param.sched_priority`); the struct whose field of that name the declaration's type's code references (a stored property its initializer fills); the one struct its other field references name; the C struct it extends. Else the bare name (a field read through a CSystem shim, `si_pid`). A "field" that's a function, constant or type elsewhere, or spelled `x_t`, is a misreading and is dropped; so is the path after ", of". *Rejected:* the host type's own "C type is" sentence, which often names a typedef (`rusage_info_current`), not the struct.
3. **The walk follows internal code of any age, not public API.** *Rejected:* following public API, which gives the `attributes(...)` calls over 100 C names each; only new internal code, as the `implementation` walk does, which misses the old `system_` wrappers new API calls.
4. **A fix-it stub follows public API one level,** into the declaration it renames, so `Signal.SIGTTIN` reaches `SIGTTIN` through `backgroundRead`. The coordinator's description had the stub reaching `_SIGTTIN` itself; its body is `{ backgroundRead }`.
5. **The debug build's mock hooks aren't code** (`mock_only_lines`): every syscall wrapper starts with `#if ENABLE_MOCKING`, whose thread-local state is `pthread_getspecific`'s, and the index is a debug build's. Leaving them in gave most wrappers three C names instead of one. *Rejected:* skipping `Mocking.swift` by name, which misses the hooks inlined in each wrapper.
6. **CSystem shims are known by where the index saw them declared** (`c_shim`), and a header-scoped macro by its USR's file. They make a declaration reach C, without a C name. *Rejected:* by name (`_SC_CHILD_MAX` starts with `_`); following a shim's C body lexically (8 declarations reach C only through a shim, and the index has no references in shim bodies).
7. **A type gets no code links** (its lines hold its members); it reaches C if any member does. *Rejected:* a type's members' C names as its own, which would make `FileDescriptor.StatusFlags` wrap every `O_` flag.
8. **One link per (declaration, C name, role), with `sources`.** A merged link keeps the doc sentence's role. A code-only link is `subject` when the code reaches that one C name, else `argument`. *Rejected:* keeping a single `source` string, which can't say both; a separate link kind, which every reader of C names would have to join.
9. **Only stated links feed derived facts** (reach, families, domains, pitch rules, the would-benefit join): a code link says what an implementation touches. So reach, pitch membership, suggestions and `adopters.json` are unchanged (section 4). Field links don't count for `couldUse` either: the coverage tools record a field as a member of its struct's interface. *Open:* letting a code link with role `subject` (a thin wrapper reaching one C name) count as wrapping.
10. **A C name's `cKinds` are its doc sentences'** (a macro the sentence calls a constant stays a constant), or for a code-only name, its USR's. *Rejected:* the union, which changed 352 existing cname nodes. A code-only name's `platforms` are `["Darwin"]`, the index's.
11. **`reachesC` is `null` off Darwin** (the index is Darwin's), and false for a member the compiler synthesizes, which has no source.
12. **The work list is its own file,** for the lane that adds sentences. *Rejected:* a section of `GRAPH.md`, which is the graph's summary.
13. **The burn-down orders a declaration's C names stated first, then code-only ones with functions first.** *Rejected:* by name, which put `SignalSet.update(with:)` under `NSIG`'s header, not `sigaddset`'s. A field named `struct.field` is in its struct's header.
14. **Swift-only means the code reaches no C at all**, a shim included; "(no C name)" is what reaches C that no C name says. *Rejected:* one bucket for both.

## 3. Tests

- Before, at `d5541b6`: api-burndown `Ran 14 tests … OK`; api-graph had no tests.
- After, at `095333c`: api-graph `Ran 14 tests … OK` (new `scripts/test_cnames.py`: C references, shim exclusion, mock lines, the walk and the stub hop, the doc and code merge, field qualification and misreadings, stated links, the work list); api-burndown `Ran 15 tests … OK` (C-name order and the code flag, an old snapshot's links, a field's header, Swift-only, the page's rows).
- Both run as `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s <scripts dir> -p 'test_*.py'`. `swift build` is unaffected: no Swift changed.

## 4. Findings

1. **The five examples** (`graphq.py show`): `ProcessID.ResourceUsageInfo.pageIns` → `rusage_info_v6.ri_pageins` and `linger.isEnabled` → `linger.l_onoff`, both `subject`, `field`, from doc and code; `Signal.SIGTTIN` → `SIGTTIN` and `SystemConfig.Name._SC_CHILD_MAX` → `_SC_CHILD_MAX`, `subject`, from code; `SignalSet.update(with:)` → `sigaddset` and `NSIG`, `argument`, from code.
2. **"(no C name)" on the page went from 1,417 (the page at `d5541b6`) to 120.** Of the 1,417, 601 are now under a header, 694 are Swift-only and 2 have C names the macOS SDK doesn't declare (the page's Darwin header view has the current counts). Of a random 25 of the 120 (seed 25), **none truly reaches no C reference**: all 25 are types whose members reach C and that no doc sentence names a C type for, such as `SocketDescriptor.SocketOption` (`SO_` constants), `IPv4Address` (`AF_INET`, `INADDR_ANY`), `DirectoryWalk` (`closedir`) and `Memory` (`malloc`). Of all 120, 118 are types; the other 2, `ExitStatus.init(waitStatus:)` and `ProcessStateChange.init(waitStatus:)`, reach C only through the CSystem shims for the `W*` macros. `DOC-SENTENCES.md` lists them all.
3. **The diff's one-time jump.** `.build/api-graph/DIFF.md` against the store's `d5541b6` snapshot: every existing wraps link changed (it gained `sources` and `cKind`), the code and field links and their cname nodes were added, and no other node or link changed. Against the baseline run's outputs, `adopters.json`'s sites and hunks, `PITCHES.md`'s coverage and SUGGESTIONS.md's clusters ("No cluster changed membership, contingencies, or its place in the top of the ranking") are unchanged.
4. **derive.py's grammar misreads some field sentences:** "`f_favail`, reported on the `statvfs` platforms and by OpenBSD's `statfs`" reads `statvfs` and `statfs` as alternative fields, and "`msg_controllen`, a `size_t`" reads `size_t` as one. Harmless to coverage, which doesn't count fields; api-graph drops them (design call 2). "The corresponding C field of `X` is `Y`." (one Windows sentence) isn't read at all.
5. **Code links include what an implementation touches incidentally,** such as `strlen` for a C string or an error path's `close`; they're shown and marked, and don't count for reach.

## 5. Next, outside this lane

1. **Doc sentences** (a later lane): `DOC-SENTENCES.md` is its input. In its first section, about half the declarations reach only fields, mostly accessors that need a "C field" sentence; the `==`, `hash(into:)` and `Codable` members there reach a field and need none. Its types section is what the page's "(no C name)" is.
2. **Code links as wrapping** (design call 9) if reach should count thin wrappers that no sentence names.
3. **Linux and Windows header grouping,** and the porting burn-down chart: not started, as asked.
