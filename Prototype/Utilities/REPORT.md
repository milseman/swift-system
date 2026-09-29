# utilities: one checked set of tools for every lane

The `utilities` lane (worktree `../utilities`, branch `utilities`, based on system-next `7b0875f`) organizes the project's scripts: an index of everything under `Utilities/`, one set of adopter-migration helpers in place of the lanes' copies in `../adopters`, and the retirement of `Utilities/nio-coverage`. Nothing was pushed, rebased or reset; `../adopters`, `Utilities/adopter-coverage/`, `Utilities/api-graph/` and `CLAUDE.md` weren't edited.

**Status (2026-09-29): all three jobs are done.** Commits, oldest first:

| Commit | What |
|---|---|
| `f5ad1be` | `Utilities/adopter-tools/`: 14 scripts, a shared module and a README (section 2) |
| `39960fd` | `Utilities/nio-coverage/` deleted; the Events and Threads write-ups point at adopter-coverage's mapping (section 3) |
| `86ecdbb` | `Utilities/README.md`, the index (section 1) |
| this commit | this report |

Local system-next hasn't moved since `7b0875f`, so there was nothing to merge.

## For Michael

**The line for adopter-lane prompts, from now on:**

> Use the helper scripts in `Utilities/adopter-tools/` of the swift-system checkout your clones build against (`../../swift-system/Utilities/adopter-tools/`; its README says which answers what): run them in place, don't copy them into `../adopters`, and put any fix they need in your report instead of editing a copy.

Until `utilities` is merged into system-next, that directory exists only here: use `../../utilities/Utilities/adopter-tools/`, and pass `--system ../../swift-system` to `cmap.py`, `cfuncs.py` and `sysapi.sh`, which otherwise read the System checkout they're in (this worktree, at `7b0875f`).

**Changes CLAUDE.md needs** (your file, so not made here):
- Commands: `Utilities/adopter-coverage/check.sh nio   # one of them; Utilities/nio-coverage/check.sh still runs this` loses its last clause: the wrapper is gone.
- Commands: add `Utilities/README.md` (the index of every tool) and, for adopter lanes, `Utilities/adopter-tools/` (its README), next to the adopter-coverage lines.
- Not from this lane, but next to it: "Adoption work" still says NIO's adoption is `../adopt-nio`, pinned to `3ea0746`. The clones are in `../adopters`, and they build against `../../swift-system`, the live system-next checkout.

**For other owners** (their files, so not edited):
- coverage lane: `Utilities/adopter-coverage/README.md` line 56 ("`Utilities/nio-coverage/check.sh`, the tool's old name, runs it for `nio` alone.") is stale now; drop it. Its tool id doesn't change (it hashes only `Utilities/adopter-coverage` and api-delta's scanner).
- coverage lane, for status.py's markers: it doesn't look past an `#if` line between a marker and its imports, so swift-syntax's `JSONDecoding.swift` marker ("string.h memcmp, as in SyntaxText", above `#if compiler(>=6)`) covers no import there. `adopter-tools` lets `#if`/`#else`/`#endif` lines come between. The marker's text names `memcmp`, so status.sh's count is right either way.
- coverage lane, not needed: `check.sh` builds fresh exports, so it never sees the stale index units that `adopter-tools/indexstore.py` filters out; its reader needs no change.
- api-graph lane: its unmerged branch changes api-graph's run time (about two minutes) and adds adopter reach; the index's row describes what's merged, so it needs a touch when that lands.

**Decisions I made that you may want to revisit** (section 2 has the evidence):
- The audit no longer counts MachO, Dispatch, os (other than `Darwin.os.*`), ObjectiveC, SQLite3 or libc++ declarations as Darwin's. `--darwin-modules MachO` restores MachO for swift-build's lane, whose markers cover Mach-O structures.
- A file whose only Darwin names are C struct fields reached through a type it names another way is *fields*, not *leak*, as the old tools' docstring said; the old code only did that for synthesized accessors. It moves one file of NIO's merge base (`PendingWritesManager.swift`, `iov_base` through NIO's `IOVector` alias) from leak to fields.
- A module that re-exports a re-exporter counts as one (NIO's `NIO` re-exports `NIOPosix`), so `import NIO` counted in NIO's merge base.

## 1. The index: `Utilities/README.md` (`86ecdbb`)

One table for every tool under `Utilities/`: the question it answers, when to run it, how long it takes, where its output goes, and which lane owns it. Then how they fit together, what they share, and a pointer to the one-decision checks under `Prototype/`.

| Tool | Owner, from the merges that brought it in |
|---|---|
| `api-delta/` | `api-tool` (merged `f9ab015`, 2026-09-23; closed). api-graph owns the one README line that points at it; status.sh runs it. |
| `api-graph/` | `api-graph` (merged `dfe83cb`, 2026-09-27; its worktree has unmerged commits) |
| `adopter-coverage/` (check, status, results, ecosystem) | `coverage`. Written as `nio-coverage` (merged `be8a64f`), generalized by `adopter-coverage` (`704c1e0`). |
| `linux/` | `linux-build` (merged `f76e0d1` and `9f5b261`, 2026-09-27; closed) |
| `adopter-tools/`, `README.md` | `utilities` |

The figures come from each tool's README (M1 Max, Swift 6.2) except two measured here: adopter-tools' (section 2) and `results.sh list` (0.8 s). The tools weren't changed. Unowned tools (api-delta, linux) have no lane to take fixes; that's yours to assign.

## 2. `Utilities/adopter-tools/` (`f5ad1be`)

### What's there, and where it came from

The seven directories in `../adopters` hold two lines of copies: `tools` (the `adopters` lane, for NIO), and `tools-2` (lane 2) → `tools-3` (the swift-foundation lane) → `tools-p2`, `tools-p3` → `tools-p4` (packages-2 to -4). `tools-tools` (the tools lane) holds scratch packages, no scripts. I read every copy, compared them (checksums, then diffs), and took the best of each, with fixes. The README's "Where they came from" table lists each script's sources and changes; in short:

| Script | Question | From |
|---|---|---|
| `imports.py` | Darwin imports and SYSTEM-GAP markers, from source | `tools-p2`/`p3`/`p4` (identical), `tools/gaps.py` |
| `darwin_audit.py`, `indexstore.py` | The compiler's view: import, gap, leak, fields, not built | `tools/darwin_audit.py`, `tools-p4/darwin_audit.py`, `tools-3/indexstore.py` |
| `migration_table.py` | MIGRATION.md's inventory from two audits | `tools`, `tools-2` |
| `dgrep.py` | Darwin and libc names, through re-exports | `tools-p2`/`p3`/`p4`, `tools-p2/dgrep.sh` |
| `freefuncs.py` | Free functions the package calls but doesn't declare | `tools-p2` |
| `cmap.py`, `cfuncs.py`, `sysapi.sh` | System declarations for C names | `tools-p2`, `tools-p3`/`p4`, `tools-p2`/`p3`/`p4` |
| `step.sh`, `test-summary.sh`, `outcomes.sh` | Build and test with logs; per-test outcomes to diff | `tools-2`, `tools-3`, `tools-p3`, `tools-p4` |
| `watchdog.py`, `tests-by-target.sh` | Tests one target or suite at a time, stopped if they hang | `tools-p4` (`swb-tests.sh` and `swb-suites.sh`, generalized) |
| `common.py` | The shared Swift blanker, import and marker parser, file lists, System lookup | new |

Left out: `wasmkit-cli-compare.sh`, `gdb-probe.py` and `mig.py` (one package each), `lexical_inventory.py` and `render_lexical.py` (superseded by adopter-coverage's lexical extraction; their vocabulary file has no recipe), `darwin_block.py` and `errno_names.json` (one lane's editing style; `cmap.py '^EBADF$'` gives an errno's name), `watch-products.sh` (a one-off diagnostic), `dgrep.sh` (in `dgrep.py`).

Generalized: paths (`/Users/milseman/.../adopters`, `../../swift-system`, `/tmp/adopters-pN/`) became arguments, `--system`/`--ref`/`$ADOPTER_TOOLS_SYSTEM`, and a scratch directory (`$ADOPTER_TOOLS_TMP`, default `$TMPDIR/adopter-tools`, one file per checkout path); package names and lists (swift-build's targets and suites, swift-foundation's MIGRATION.md, logs-pN) became arguments or come from the manifest.

### How each was checked

Read-only against `../adopters` throughout: sources through `git ls-files`, `git cat-file` and file reads, index stores through libIndexStore (units are copied to scratch when filtered). Builds were of `git archive` exports under `$TMPDIR/adopter-tools-check/`, with `../../swift-system` an export of `7b0875f`: swift-log, swift-tools-support-core (TSC) and swift-nio, each at its merge base and its `migrate-darwin` head, plus `../ecosystem/swift-log` (upstream main, `e97a6fc`) and this worktree. Afterwards every clone in `../adopters` was as clean as before, and no `__pycache__` was written. The "package" check for each script used a checkout outside `../adopters`: `../ecosystem/sourcekit-lsp`, `../ecosystem/swift-log`, or swift-system itself.

**`imports.py`.** Every clone's `migrate-darwin` against its merge base (1–3 s each; 25 s for swift-build before prefiltering, 2.9 s after). Counting Sources and Tests, which is close to the manifests' targets, the figures match STATUS.md for 12 of the 13 packages at the commits STATUS.md read; WasmKit counts two files it doesn't. swift-build and swift-foundation have moved since STATUS.md was made; swift-foundation's remaining whole and submodule imports are its three `#if FOUNDATION_FRAMEWORK` files, which STATUS.md counts as framework only (status.sh evaluates `#if`, imports.py doesn't).

| Package @ migrate-darwin | Whole | Submodule | Scoped only | Via re-export | Markers (files) | Sources+Tests: whole, submodule, scoped |
|---|---|---|---|---|---|---|
| WasmKit @ `4917e06` | 17 → 1 | 0 → 0 | 0 → 1 | 0 → 0 | 0 → 1 (1) | 16 → 0, 0 → 0, 0 → 1 |
| indexstore-db @ `cc966b8` | 1 → 0 | 1 → 0 | 0 → 0 | 0 → 0 | 0 → 0 (0) | 1 → 0, 1 → 0, 0 → 0 |
| swift-argument-parser @ `0fbda27` | 1 → 0 | 0 → 0 | 0 → 1 | 0 → 0 | 0 → 1 (1) | 1 → 0, 0 → 0, 0 → 1 |
| swift-async-algorithms @ `bd5f6f4` | 2 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 (0) | 2 → 0, 0 → 0, 0 → 0 |
| swift-build @ `56ad2d9` | 2 → 0 | 1 → 0 | 0 → 10 | 86 → 0 | 0 → 17 (12) | 2 → 0, 1 → 0, 0 → 10 |
| swift-certificates @ `0df6bd1` | 2 → 0 | 0 → 0 | 0 → 1 | 0 → 0 | 0 → 1 (1) | 2 → 0, 0 → 0, 0 → 1 |
| swift-driver @ `ddb51ccd` | 11 → 0 | 1 → 0 | 0 → 0 | 0 → 0 | 0 → 0 (0) | 11 → 0, 1 → 0, 0 → 0 |
| swift-foundation @ `763e42cd` | 37 → 4 | 2 → 1 | 0 → 3 | 0 → 0 | 0 → 4 (3) | 35 → 2, 2 → 1, 0 → 3 |
| swift-log @ `4d6d77f` | 5 → 0 | 0 → 0 | 0 → 2 | 0 → 0 | 0 → 3 (2) | 5 → 0, 0 → 0, 0 → 2 |
| swift-nio @ `e1623fbf` | 43 → 0 | 4 → 0 | 0 → 0 | 120 → 0 | 0 → 0 (0) | 41 → 0, 3 → 0, 0 → 0 |
| swift-package-manager @ `dbe05ec1e` | 3 → 0 | 3 → 1 | 0 → 0 | 0 → 0 | 0 → 0 (0) | 3 → 0, 2 → 0, 0 → 0 |
| swift-subprocess @ `d6b5866` | 17 → 0 | 0 → 0 | 0 → 1 | 0 → 0 | 0 → 2 (2) | 17 → 0, 0 → 0, 0 → 1 |
| swift-syntax @ `961f0b723` | 3 → 1 | 1 → 0 | 0 → 2 | 0 → 0 | 0 → 3 (2) | 2 → 0, 0 → 0, 0 → 2 |
| swift-tools-protocols @ `18e8a9f9` | 2 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 (0) | 2 → 0, 0 → 0, 0 → 0 |
| swift-tools-support-core @ `1ad4129` | 0 → 0 | 1 → 0 | 0 → 2 | 19 → 0 | 0 → 2 (2) | 0 → 0, 1 → 0, 0 → 2 |

The rest outside Sources and Tests is out of the builds: WasmKit's `Examples/embedded-wat`, swift-syntax's `EditorExtension`, SwiftPM's `Fixtures/`, swift-foundation's `Benchmarks`. swift-build's lane committed `56ad2d9` while this ran; STATUS.md still shows its merge base. The old counter found none of swift-log's three markers: it read only markers trailing an import on the same line, the style of the lanes that used it (TSC). Package: `../ecosystem/sourcekit-lsp`, 454 files, 8 whole-module imports in Sources, 0.6 s.

**`darwin_audit.py` and `indexstore.py`.** Statuses of the old `tools` copy (A), the old `tools-p4` copy (B) and the new script (N), on the same dumps:

| Build | A | B | N |
|---|---|---|---|
| swift-log, merge base | import 5, leak 1 | same | same |
| swift-log, migrated | gap 2 | same | same |
| TSC, merge base | import 20, leak 3 | + fields 1 | = A |
| TSC, migrated | gap 2, leak 1 | import 1, gap 1, leak 1, fields 3 | = A |
| NIO, merge base | import 166, leak 35 | + fields 1 | import 134, leak 34, fields 1, not built 33 |
| NIO, migrated | none | leak 11, fields 1 | none |

- B's extra *fields* are Foundation's own accessors (`NSFileAttributeKey.size`) taken for Darwin fields, and B's TSC *import* is `FileSystem.swift`, whose `d_name` B wants named in the marker although the file imports `struct Darwin.dirent`. B's 11 NIO leaks are NIO's aliases of System's types (`typealias sockaddr_in = CInterop.SockAddrIn`): A and N skip a name written where a non-Darwin typealias resolves.
- N's differences from A, on NIO's merge base: the 33 *not built* files are `Benchmarks`, `IntegrationTests` and `dev`, which the root package doesn't build (A counted them as imports). `PendingWritesManager.swift` is *fields* (`iov_base` and `iov_len` through NIO's alias). `Tests/NIOTests/NIOTests.swift` is *import*, through `NIO`'s re-export of `NIOPosix`'s re-export.
- In-place stores (read-only): swift-argument-parser gap 1; swift-async-algorithms none; swift-certificates gap 1 (A and N; B says import, the same field rule as TSC's `dirent`); swift-syntax gap 2, where A and B say import 1 and gap 1. `JSONDecoding.swift`'s marker sits above `#if compiler(>=6)`, and only the `#if` branch the build compiled counts; the `#else` import has no module reference in the index and is listed as inactive. `EditorExtension/` is *not built*.
- SDK headers, on the lanes' own dumps (`/tmp/adopters-p4/swift-build-index.json`, `/tmp/adopters-3/swift-foundation-index.json`, NIO's baseline): the module-map rule and `tools-p4`'s rule differ on MachO (88 declarations in swift-build), SQLite3 (40), libc++ (638 and 187, all C++ overloads), and the `os/` headers Darwin's module map owns (8 and 5: `os_unfair_lock`, `OS_CONCAT` and an availability macro, which `tools-p4` dropped). The packages-4 lane fixed the `os_unfair_lock` case in its own copy at 12:05, while this ran. NIO's baseline dump classifies the same both ways.
- The reader: on the in-place stores of swift-log, swift-argument-parser, swift-nio, swift-syntax, swift-certificates and swift-async-algorithms, `indexstore.py`'s dump equals the `tools-3` copy's. swift-argument-parser's store has stale units: 686 units, 428 of them newest.
- Package: swift-system itself (this worktree's build, 8.6 s). Sources: import 208, leak 1 (`TimeZoneFiles.swift`: `TZDIR` and `TZDEFAULT` through CSystem's `<tzfile.h>`, which no module map lists). Tests: import 113, leak 15, fields 1. Prototype: not built 25. Samples: 5 files whose `import Darwin` is inactive (`#if SIMULATE_PLATFORMS`). Also `../ecosystem/swift-log` (upstream main): import 5, leak 1.
- Times: 9–15 s from a store (swift-log 9 s, NIO 13.5 s), 0.5–4 s from a dump.

**`migration_table.py`.** TSC merge base → migrated: the same per-file statuses as the old `tools/migration_table.py` over A's audits (Sources 18 → 0, +2 gap; Tests 5 → 1). Package: `../ecosystem/swift-log` (upstream main) → the migrated clone: Sources 3 → 0 (+1 gap), Tests 3 → 0 (+1 gap).

**`dgrep.py`.** TSC with `--via Foundation,XCTest --no-darwin`: 13 files, all but one for their `import TSCLibc` lines; the one is `FileSystemTests.swift`'s `mkfifo`, `strerror` and `errno`, the audit's leak. The `strerror(errno)` is inside `"\(...)"`, which the old copy blanked, and the `#if` filter and labels took it from 16 files to 13 (`FSWatch.swift`'s `inotify` calls are under `#if os(Linux)`; `errno:` labels aren't uses). NIO migrated: 13 files (25 without the `#if` filter), which the audit clears: NIO's own aliases and helpers with C names (`sockaddr_in`, `ssize_t`, `usleep`), declared in other files. swift-log migrated: none (its `TestLogger.swift` hit is under `#elseif os(FreeBSD)`). Package: `../ecosystem/sourcekit-lsp`, 18 files (`dup`, `dup2`, `strerror`, `dlopen`, `signal`, `strcmp`, `pow`, `sysctlbyname`).

**`freefuncs.py`.** TSC: the old copy's top entries were `#if` conditions (`os` ×130, `canImport` ×80), and its C calls included the Linux and Windows branches' (`inotify_*`, `_wunlink`, `_strdup`). Now the only C call left is `mkfifo`, the audit's leak, among Swift methods called with an implicit `self` (31 names with `--all-platforms`, 8 without). Package: `../ecosystem/sourcekit-lsp` (`free` ×7, `setpriority` ×3, `pow` ×3, and the dependencies' functions such as `orLog`, which it can't tell from C's). 1–3 s.

**`cmap.py`, `cfuncs.py`, `sysapi.sh`.** Against the system-next checkout (`7b0875f`): `cmap.py` finds 3,170 mappings where the old copy found 2,953, including sentences split across lines (`posix_spawn_file_actions_addclosefrom_np`, `sysdir_get_next_search_path_enumeration`, `COPYFILE_STATE_FORBID_DST_EXISTING_SYMLINKS`). `cfuncs.py dirent` finds `DirectoryStream.Entry` ("The corresponding C type is `struct dirent`"), which the old copy missed. `sysapi.sh` prints the same 4,464 declaration lines as the old copy, and `--ref HEAD` the same through `git grep`. With the adopters' open gaps: swift-build's markers name `dladdr`, `getiopolicy_np`, `cpu_type_t` and `XATTR_FINDERINFO_NAME`, which `cmap.py --ref coverage` finds in the coverage lane's unmerged commits (`DynamicLibrary.symbolInfo(containing:)`, `IOPolicy`, `Mach.CPUType`, `ExtendedAttributeName.finderInfo`), and `tolower`, which system-next already has (`CType.lowercased`, provisional). TSC's `dlerror` gap is `DynamicLibrary.LoaderError.message`, which covers only System's own errors, as the tools lane's report says.

**`step.sh`, `test-summary.sh`, `outcomes.sh`.** `step.sh --audit` on the swift-log exports: 170 Swift Testing tests pass at both ends, with the same outcomes test for test, and the audit is written. On swift-system (this worktree): 472 Swift Testing tests and 556 XCTest (4 skipped) pass. On the lanes' logs, the counts match their reports, and the outcomes of the two runs they compared are identical except where the reports say:

| Logs (lane) | Outcomes | Differences |
|---|---|---|
| WasmKit migrated → final (p4) | 590 passed, 16 skipped, 5 failed, 2 suites skipped | none |
| TSC baseline → migrated (p2, tools) | 211 XCTest passed | none |
| SwiftPM baseline → migrated (p2, tools) | Swift Testing 1296 passed, 101 skipped, 318 failed; XCTest `--parallel` 1541 passed, 1 failed | none |
| NIO baseline → tests-full (adopters) | 303 passed; XCTest 2411 → 2396 passed, 43 skipped | the 15 NIOFS mock tests the report says were removed |
| Subprocess baseline → cvalues-final-2 (2) | 160 passed, 11 skipped | none |
| driver baseline → migrated (p2, tools) | 449 passed, 21 skipped, 1 failed; XCTest 3 | none |

The old `outcomes.sh` ignored `--parallel` XCTest runs (SwiftPM's 1,542 XCTest tests) and skipped XCTest tests.

**`tests-by-target.sh`, `watchdog.py`.** swift-log by target (164 + 6 tests) and by suite (16 suites, 170 tests); joined with `outcomes.sh -`, the same outcomes as the single run. swift-system by target: SystemTests (329 Swift Testing, 556 XCTest), MemberImportVisibility (none), SystemSocketsTests (143). The joined outcomes differ from the single run by one test (below). `watchdog.py` passes a command's status through (3), stops on idle (124, with the command's background child killed) and on the limit (124).

### Findings for other lanes

- **TSC's tests still reach Darwin through XCTest**: `Tests/TSCBasicTests/FileSystemTests.swift` calls `mkfifo`, `strerror` and `errno` with no Darwin import (its `import TSCLibc` is empty on Darwin now). The audit calls it *leak*. The tools lane's report lists no Darwin imports left in TSC's tests; imports are all it counted.
- **`setCurrentQualityOfService()` can time out under load** (`Tests/SystemTests/PThreadTests.swift:271`): run with SystemTests alone while other lanes were building, the background-QoS thread didn't open its latch within 10 s (two issues: `ready.wait()` false, and the QoS read the default class, raw 21, not `.background`). It passed in the full run just before. For the test-hygiene lane.
- **packages-4** (active on swift-build, now swift-docc): the audit here doesn't count MachO as Darwin (`--darwin-modules MachO` does), and its markers for `dladdr`, `getiopolicy_np`, `cpu_type_t` and the `XATTR_*` names are covered on the coverage branch.

## 3. `Utilities/nio-coverage` retired (`39960fd`)

`nio-coverage/check.sh` ran `adopter-coverage/check.sh nio`, mapping its old `NIO_COVERAGE_*` variables. References found with `git grep nio-coverage`, outside CLAUDE.md:
- `Prototype/Events/README.md` and `Prototype/Threads/README.md` cited `Utilities/nio-coverage/mapping.ini`; they now name `Utilities/adopter-coverage/mapping.ini` and say it was nio-coverage's then.
- `Utilities/adopter-coverage/README.md` line 56 mentions the wrapper: listed above for the coverage lane.
- `packages/nio.ini`, `scripts/compare.py` and `scripts/method.md` in adopter-coverage mention nio-coverage as history ("first written for", "a run of nio-coverage compares"); still true.

## Where to resume

Nothing is in progress. If Michael asks for more:
- After `utilities` merges: update the index's api-graph row when api-graph's branch lands, and apply the CLAUDE.md lines above if he wants them.
- If lanes report fixes to `adopter-tools`, make them here, rerun the checks in section 2 (the exports are rebuilt with `git archive` as described there; they aren't kept), and commit.
- The copies in `../adopters/tools*` stay until Michael says otherwise; `../adopters/TOOLS-REPORT.md` and the PACKAGES reports still cite them.
