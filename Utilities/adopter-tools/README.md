# adopter-tools

The helper scripts for adopter-migration lanes: lanes that move a package, cloned in `../adopters`, off the Darwin module and onto System. They count and audit a clone's Darwin use, find what System has for a C name, and build and test with logs that can be compared test for test.

Run them in place, from this checkout (`../../swift-system/Utilities/adopter-tools/` from a clone in `../adopters`); don't copy them. They replace the copies the lanes kept in `../adopters/tools`, `tools-2`, `tools-3`, `tools-p2`, `tools-p3` and `tools-p4` (see [Where they came from](#where-they-came-from)). A fix belongs here, where every lane gets it.

## Which script answers what

| Script | Question | Needs | Time |
|---|---|---|---|
| `imports.py PACKAGE [REV]` | Which files import Darwin (whole module, submodule, scoped only, through a re-export), and what SYSTEM-GAP markers are there? `--base REV` for the start and now. | sources only: a working tree or a commit | 1–3 s |
| `darwin_audit.py PACKAGE` | Which files still use Darwin, including through another module's re-export (Foundation, XCTest, a C shim), and which are SYSTEM-GAP only? | a debug build's index store | 5–15 s; about 1–4 s with `--reuse` |
| `migration_table.py BASE.json NOW.json MIGRATION.md` | The per-file inventory table for MIGRATION.md, from two audits. | two `darwin_audit.py --json` files | instant |
| `dgrep.py PATH...` | Which lines name Darwin or libc interfaces? `--via Foundation,XCTest --no-darwin` for names reached through a re-export. | sources | 1–4 s |
| `freefuncs.py PACKAGE [SUBDIR...]` | Which free functions does the package call but not declare (C calls reached through an import)? | sources | 1–3 s |
| `cmap.py [REGEX]` | Which System declarations wrap these C names, by their "The corresponding C … is" sentences? | System's sources | 1–2 s |
| `cfuncs.py NAME...` | Which System declarations mention these names anywhere in their docs, or are named for them? | System's sources | 1–2 s |
| `sysapi.sh REGEX` | Which public declaration lines of System match? | System's sources | under 1 s |
| `step.sh PACKAGE LOGDIR LABEL [ARGS...]` | Does it build and pass its tests after this step? (logs, summary, optional audit) | a toolchain | the package's build and test |
| `test-summary.sh LOG` | What were a test run's totals and first failures? | a `swift test` log | under 1 s |
| `outcomes.sh LOG` | What was each test's outcome, so two runs can be diffed? | a `swift test` log | under 1 s |
| `tests-by-target.sh PACKAGE LOGDIR` | The tests, one target or one suite at a time, each stopped if it hangs. | a build | the tests' own time |
| `watchdog.py LOG IDLE LIMIT CMD...` | Run a command, stopping it after IDLE seconds without output or LIMIT in all. | | |

Times are on an M1 Max with Swift 6.2, for packages from swift-log's size to SwiftPM's.

## A migration step

```sh
T=../../swift-system/Utilities/adopter-tools        # from a clone in ../adopters
B=$(git merge-base main HEAD)

$T/imports.py . --base $B                           # Darwin imports and markers, at the start and now
$T/dgrep.py --via Foundation,XCTest --no-darwin Sources Tests   # names reached through re-exports
$T/freefuncs.py . Sources                           # C calls the package doesn't declare
$T/cmap.py '^(fsync|mkfifo|strerror)$'              # what System wraps them with
$T/cfuncs.py readlinkat                             # every mention, when cmap finds nothing

$T/step.sh --audit . ../logs-mylane/pkg step3       # build, test, audit, with logs
$T/darwin_audit.py . --reuse --files                # the audit's per-file detail
diff <($T/outcomes.sh ../logs-mylane/pkg/baseline-test.log) <($T/outcomes.sh ../logs-mylane/pkg/step3-test.log)
$T/migration_table.py ../logs-mylane/pkg/baseline-audit.json ../logs-mylane/pkg/step3-audit.json MIGRATION.md
```

The baseline audit comes from a build of the merge base: in a scratch export (`git archive $B | tar -x -C DIR`, with `../../swift-system` beside it if the manifest points there), or in the clone before the first change.

After committing a step, `Utilities/adopter-coverage/status.sh` counts every clone's `migrate-darwin` branch against its merge base for STATUS.md, from commits alone. `imports.py` counts the same way (`imports.py PACKAGE migrate-darwin --base BASE`) but works on uncommitted changes too, counts every Swift file rather than the manifest's targets, and doesn't evaluate `#if`, so its figures can be higher (Benchmarks, Fixtures, `#if FOUNDATION_FRAMEWORK` imports). `darwin_audit.py` is the compiler's view: what the build imports and resolves.

## The scripts

**`imports.py PACKAGE [REV] [--base REV] [--paths A,B] [--reexporters M,N] [--markdown] [--json OUT] [--quiet]`** reads the sources at REV, or the working tree (uncommitted and untracked files included). A file counts by its broadest Darwin import: *whole* (`import Darwin`), *submodule* (`import Darwin.C`), *scoped* only (`import func Darwin.fopen`), or *through a re-export*: an import of a package target with an `@_exported import Darwin` (found under `Sources/<target>/`, with the targets that re-export those) or of a module `--reexporters` names. Comments and strings don't count. It lists every SYSTEM-GAP marker by its first line, with the scoped imports it covers, and flags a scoped Darwin import no marker covers. Markers are read as status.sh reads them (the text continues onto the comment lines after it; it covers the imports right after its comment, or the import it trails), except that `#if`/`#else`/`#endif` lines may come between a marker and its imports. `--markdown` prints the tables for MIGRATION.md.

**`darwin_audit.py PACKAGE [--build DIR | --store DIR] [--reuse | --dump FILE] [--files] [--refs SUBSTR] [--json OUT] [--reexporters M,N] [--darwin-modules M,N] [--scope A,B] [--all-units]`** needs a debug build (`swift build --build-tests`, or `step.sh`), found under `PACKAGE/.build` or `--build`. Its docstring defines each status:
- *import*: a compiled import of Darwin or of a module that re-exports it (found from `@_exported` imports, transitively), not *gap*. Unmigrated.
- *gap*: every such import is under a SYSTEM-GAP marker, and every Darwin name the file uses is accounted for: named in a marker's text, imported by a scoped import under a marker (a struct's import covers its fields), or declared in a submodule imported under one.
- *leak*: no Darwin import, but names written in the file resolve to Darwin. Unmigrated.
- *fields*: no Darwin import, and only fields of C structs it names another way (`CInterop.Stat`'s `st_mode`). Listed, not unmigrated.
- *not built*: it has Darwin imports, but the build compiled no unit of it (Benchmarks, Fixtures, a nested package, a target this build skips).

An import under an `#if` the build didn't take has no module reference in the index; it's listed as *inactive* and doesn't count. Darwin means the Darwin module and the modules it's built from; an SDK C header counts by the SDK's module maps, so Dispatch, os, ObjectiveC, MachO, SQLite3 and libc++ aren't Darwin, even when a package's C target includes them textually (`--darwin-modules MachO` counts one anyway). A name written where the package's own typealias of a Darwin type, or one of System's CInterop aliases, resolves is the alias's. The index is dumped to `$ADOPTER_TOOLS_TMP/dumps/`; `--reuse` reads the last dump of the same checkout.

**`indexstore.py`** is what `darwin_audit.py` reads the store with: adopter-coverage's reader (`Utilities/adopter-coverage/scripts/indexstore.py`, run, not copied) over the newest unit of each source file. A clone built more than once, or two ways (`--build-system native` and swiftbuild), keeps stale units whose records can match today's lines by accident. `--all-units` reads them all.

**`migration_table.py [--stdout] [--max-names N] BASE.json NOW.json MIGRATION.md`** replaces the text between `<!-- inventory:begin -->` and `<!-- inventory:end -->` in MIGRATION.md (or appends it): files unmigrated at the start and now, and SYSTEM-GAP only now, per top-level directory, then a row per file with the Darwin names it used.

**`dgrep.py [--via M,N] [--no-darwin] [--files] [--all-platforms] PATH...`** lists `file:line: [hits] source` for lines that import Darwin (or TSCLibc or MachO) or name one of a few hundred Darwin and libc functions, types and constants. Comments and strings are skipped, but not the code in string interpolations. Names the file declares itself (functions, variables, cases, parameters, argument labels) don't count, and neither do `#if` lines or the code in an `#if` branch a macOS build certainly doesn't compile (`#if os(Linux)`, `#elseif canImport(Glibc)`, the `#else` of `#if canImport(Darwin)`; `--all-platforms` keeps them). A branch that depends on a flag or the compiler's version counts. A grep: it misses names not in its lists, and flags a package's own functions and aliases that share a C name if another file declares them.

**`freefuncs.py [--min N] [--all] [--all-platforms] PACKAGE [SUBDIR...]`** lists calls `name(` that aren't members, whose names no Swift file of the package declares and that aren't in a list of standard library, Foundation, XCTest and Swift Testing functions, most called first. A package's own C functions (declared at the top level of its headers) are left out unless `--all`, and so are calls in `#if` branches a macOS build certainly doesn't compile, unless `--all-platforms`. Methods called with an implicit `self`, and functions of the package's dependencies, show up too.

**`cmap.py [--system DIR] [--ref REF] [REGEX]`** prints `C name -> file:line  [scope] declaration  #if conditions` from System's corresponding-C sentences, which may span lines and list several names; these are what status.sh counts as covered. **`cfuncs.py [--system DIR] [--ref REF] NAME...`** prints the declarations whose docs mention a name in backticks (`fsync`, `fsync(2)`, `struct dirent`) or that are named for it. **`sysapi.sh [--system DIR] [--ref REF] REGEX`** greps System's public declaration lines. All three read the checkout the tools are in, or `--system DIR`, or `$ADOPTER_TOOLS_SYSTEM`: its working tree, or the commit `--ref` names (`--ref system-next`), which `cmap.py` and `cfuncs.py` export once into the scratch directory and `sysapi.sh` reads with `git grep`. The `#if` conditions are printed as written, not evaluated.

**`step.sh [--no-test] [--audit] PACKAGE LOGDIR LABEL [SWIFT ARGS...]`** runs `swift build --build-tests` and `swift test --skip-build` with the same SWIFT ARGS (`-Xswiftc -target -Xswiftc arm64-apple-macosx26.0`, `--build-system native`), logs them to `LOGDIR/LABEL-build.log` and `LABEL-test.log`, and prints the build's errors and test-summary.sh's summary. `TEST_ARGS` go to the test only (`--parallel`); `--audit` writes `LOGDIR/LABEL-audit.json` (`AUDIT_ARGS` for darwin_audit.py). It builds in the package's directory, as `swift build` does.

**`test-summary.sh LOG [LINES]`** prints the Swift Testing and XCTest totals, the count of each outcome, and the first failure lines. **`outcomes.sh LOG`** prints `passed|failed|skipped NAME` for Swift Testing tests, `suite-skipped`, `xctest-passed|failed|skipped Module.Class/test` (from the `[n/m] Testing` lines of a `--parallel` run too), and `unfinished` for tests that started but never ended, sorted: `diff <(outcomes.sh a.log) <(outcomes.sh b.log)`. Swift Testing names a test without its suite, so compare counts. `-` reads standard input, so split runs can be joined: `cat LOGDIR/*.log | outcomes.sh -`.

**`tests-by-target.sh [--idle S] [--limit S] [--suites] PACKAGE LOGDIR [TARGET...] [-- SWIFT ARGS...]`** runs each test target (default: the manifest's) as `swift test --skip-build --filter '^TARGET\.'`, or with `--suites` each suite `swift test list` finds, under watchdog.py (defaults: 600 s idle, 3600 s in all), into `LOGDIR/<name>.log`, and prints one line per run into `LOGDIR/summary.txt` too. **`watchdog.py LOG IDLE LIMIT CMD...`** runs CMD in its own process group with its output appended to LOG, stops the group on the timeouts (SIGTERM, then SIGKILL), kills what the command left running, and exits with the command's status or 124.

## Conventions

- **Read-only.** Nothing but `step.sh` and `tests-by-target.sh` writes in a package, and they write what `swift build` and `swift test` would. Scratch (index dumps, filtered stores, System exports) goes to `$ADOPTER_TOOLS_TMP`, by default `adopter-tools` in the system's temporary directory, one file per checkout path.
- **System.** The lookups read the swift-system checkout the tools are in unless told otherwise, so run them from the checkout your clones build against (`../../swift-system`), or pass `--system` or `--ref`.
- **`--disable-sandbox`.** `step.sh` and `tests-by-target.sh` pass it to SwiftPM, since inside another sandbox, such as a coding agent's, the manifest sandbox fails ("sandbox_apply: Operation not permitted"). `ADOPTER_TOOLS_SANDBOX=1` leaves it off. It means manifests run unsandboxed: point them only at packages you trust.
- **`common.py`** is what the Python scripts share, not a tool: the Swift comment and string blanker, the import and marker parser, the `#if` evaluator for macOS, file lists, and System's declarations.
- **Requirements.** macOS with Xcode's toolchain (`xcrun`, and `libIndexStore.dylib` next to `swift`, or `--libindexstore`/`$LIBINDEXSTORE`; `TOOLCHAINS` picks a snapshot), `python3` 3.9 or later with the standard library only, bash 3.2, git.

## Where they came from

The lanes copied their helpers from one lane to the next and fixed them along the way, so each script here is the best of its copies (read and compared, 2026-09-29), with paths and package names made arguments. What changed, beyond that:

| Here | From | Changes |
|---|---|---|
| `imports.py` | `tools-p2`, `-p3`, `-p4` (identical) | Finds markers on their own lines above the imports, which the copies missed (they read only trailing markers, the tools lane's style); counts submodule and re-export imports apart, as STATUS.md does; follows re-exports transitively; `--base`, `--markdown`, `--json`; lists uncovered scoped imports. Absorbs `tools/gaps.py`. |
| `darwin_audit.py` | `tools` and `tools-p4` (`tools-2` → `tools-3` → `tools-p3` → `tools-p4` is one line of copies, `tools` another) | Merges both lines: `tools`' import coverage (a struct's scoped import covers its fields, a submodule import its declarations) and its skipping of a package's own typealiases, which `tools-p4` lacks (11 of migrated NIO's files read *leak* there for its `sockaddr_in` aliases of CInterop); `tools-p4`'s SYSTEM-GAP naming rule, multi-line strings, marker continuation lines and MachO gap imports; the `tools-3` `<sdk>` rule, replaced by the SDK's module maps (it made MachO, SQLite3 and libc++ Darwin, and `tools-p4`'s fix for it dropped `os_unfair_lock`, which is `Darwin.os.lock`). New: only compiled imports count (*inactive*, *not built*), C fields through another type are *fields* as the docstring always said, and markers may sit above an `#if`. |
| `indexstore.py` | `tools-3`, `-p3`, `-p4` (identical) | Runs adopter-coverage's reader instead of carrying a copy of it; keeps the copies' newest-unit fix, applied to a scratch store. Same dumps as the `tools-3` copy on every store checked. |
| `migration_table.py` | `tools`, `tools-2` | Arguments for everything; `--stdout`; the new statuses; `--max-names`. |
| `dgrep.py` | `tools-p2`, `-p3`, `-p4` (identical); `tools-p2/dgrep.sh` | Keeps code in string interpolations (it blanked `strerror(errno)` inside `"\(...)"`); skips `#if` lines, branches macOS doesn't compile, parameters and labels; adds the names only `dgrep.sh` had (`size_t`, `tm`, `fsetxattr`) and `errno` as a name; `--via`, `--no-darwin`, `--files`. |
| `freefuncs.py` | `tools-p2` | Shares the scanner instead of `exec`-ing part of dgrep.py; skips `#if` conditions, branches macOS doesn't compile, and keywords; leaves out the package's own C functions. |
| `cmap.py` | `tools-p2` | Reads sentences that span lines (`posix_spawn_file_actions_addclosefrom_np`, `sysdir_get_next_search_path_enumeration` were missed); prints the scope and `#if` conditions; `--system`, `--ref`. |
| `cfuncs.py` | `tools-p3`, `-p4` (identical) | Matches `` `struct dirent` ``; real scopes from brace nesting; `#if` conditions; says which names nothing mentions; `--system`, `--ref`. |
| `sysapi.sh` | `tools-p2`, `-p3`, `-p4` (identical) | bash instead of zsh; `--system`, `--ref` (`git grep`). |
| `step.sh` | `tools-2`, `tools-3`, `-p3`, `-p4` | One script for all of them: a log directory argument instead of a lane's, `--disable-sandbox` (the `tools-3` copy failed in the sandbox for want of it), `--audit`, `TEST_ARGS`. |
| `test-summary.sh` | `tools-p4` (the `tools-2` copies are its older form) | Glyph-independent, parallel XCTest, outcome counts; skips Swift Testing's detail lines. |
| `outcomes.sh` | `tools-p4` | XCTest skipped tests, `--parallel` runs, Linux names, suite skips, unfinished tests, `-` for standard input. |
| `watchdog.py` | `tools-p4` | Returns as soon as the command ends; a usage message. |
| `tests-by-target.sh` | `tools-p4/swb-tests.sh`, `swb-suites.sh` | Targets from the manifest and suites from `swift test list`, instead of swift-build's lists. |

Left out:
- **One-package probes:** `tools-p4/wasmkit-cli-compare.sh` (WasmKit's CLI), `gdb-probe.py` (WasmKit's debugger stub), `tools-3/mig.py` (inserts lines into swift-foundation's MIGRATION.md).
- **Superseded:** `tools-2/lexical_inventory.py` and `render_lexical.py`, for a package that can't be built: `Utilities/adopter-coverage/check.sh` extracts lexically (`<P>_LEXICAL=1`), and the vocabulary file they read (`/tmp/adopters-2/darwin-vocab.txt`) has no recipe. `tools/gaps.py` is in `imports.py`. `tools-p2/dgrep.sh` is in `dgrep.py`.
- **One lane's editing helpers:** `tools/darwin_block.py` and `errno_names.json`, which insert import blocks and errno aliases in NIO's style. `cmap.py '^EBADF$'` gives an errno's System name.
- **One-off diagnostics:** `tools-p2/watch-products.sh`, which watched for a build product to disappear.
- `tools-tools/` holds scratch packages, not scripts.

The copies in `../adopters` stay where they are.
