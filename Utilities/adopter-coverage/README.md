# adopter-coverage

`check.sh` lists every OS and C-library interface that swift-system's adopters use, and checks how much of it a swift-system commit covers. An adopter is a package in `packages/`, which says where its checkout is and what the tool needs to know about it.
- **The extraction** is compiler-backed where it can be: a debug build of the package on macOS, read through the index store. A package that doesn't build with the compiler at hand is extracted lexically, and its report says so.
- **The coverage is derived** from System's sources at the commit: every public declaration's doc comment names what it wraps (*The corresponding C function is `fsync`.*), and the CInterop typealiases name C types. `scripts/derive.py` reads them, and the check decides each interface from that.
- **The mapping**, `mapping.ini`, keeps only what can't be derived: which symbols make up one concept, categories, notes, `ignore`s, and a status where the derivation can't see the truth (a partial judgment, or an override where System's doc comments don't name what the API covers). Every report says which entries the derivation decided and where a hand status disagrees with it.
- **The results** are stored by commit, outside every worktree, so any run can be repeated, verified, and compared with any other.
- **The Darwin metric** says, for every library file, how it sees the Darwin module: by importing it, through a re-export (NIOPosix's, TSCLibc's), or only through Apple Foundation's.

The audited adopters are swift-nio (`nio`), swift-foundation (`foundation`), swift-package-manager (`swiftpm`) and swift-subprocess (`subprocess`). `ecosystem.sh` audits the rest of the toolchain's packages that import Darwin (`packages/ecosystem/`).

## Running it

```sh
Utilities/adopter-coverage/check.sh                          # every audited adopter, System at this HEAD
Utilities/adopter-coverage/check.sh nio                      # one package
Utilities/adopter-coverage/check.sh nio@1a2b3c4              # another commit of its checkout
Utilities/adopter-coverage/check.sh nio=../adopters/swift-nio@migrate-darwin   # another checkout and ref
SYSTEM_REF=be8a64f Utilities/adopter-coverage/check.sh       # another System commit
open .build/adopter-coverage/COVERAGE.md                     # the run's combined report (a copy)
open .build/adopter-coverage/nio/COVERAGE.md                 # one package's

Utilities/adopter-coverage/results.sh list                   # the stored runs
Utilities/adopter-coverage/results.sh delta RUN_A RUN_B      # what changed between two runs
Utilities/adopter-coverage/results.sh verify RUN             # repeat a run with the tool it recorded, and compare
Utilities/adopter-coverage/results.sh rerun RUN              # repeat its commits with this tool
Utilities/adopter-coverage/results.sh migration nio ../adopters/swift-nio migrate-darwin   # a branch against its base

Utilities/adopter-coverage/ecosystem.sh clone                # the toolchain's packages, into ../ecosystem
Utilities/adopter-coverage/ecosystem.sh survey               # which import Darwin; their package files
Utilities/adopter-coverage/ecosystem.sh run                  # check.sh over all of them
Utilities/adopter-coverage/ecosystem.sh report               # ECOSYSTEM.md for the latest ecosystem run
```

A package spec is `NAME`, `NAME@REF`, `NAME=PATH` or `NAME=PATH@REF`: the package file's settings, at any checkout and ref. A run's id (`<System commit>-<hash>`) comes from its System commit, the tool and the package commits; RUN can be an id or a prefix of one, `latest`, or a System commit (its latest run).

| Variable | Default | |
|---|---|---|
| `<P>_PATH` | the package file's `checkout` | A package's checkout, when the spec doesn't give one. `P` is the package's `variable`: `NIO_PATH`. It's only read: the commit is exported with `git archive`. |
| `<P>_REF` | `HEAD` of `<P>_PATH` | The package commit to extract from, when the spec doesn't give one. |
| `<P>_SWIFT_EXEC` | the default toolchain | A `swiftc` to build the package with, for a package the default toolchain can't build (swift-foundation's main branch needs a newer compiler than Swift 6.2). The manifest is still compiled with the default one. |
| `<P>_REUSE_INDEX` | unset | `1` reuses any stored index dump of the same commit, whatever compiler and index reader made it: for a package whose compiler this machine no longer has. The report records which made it. |
| `<P>_LEXICAL` | unset | `1` skips the build and extracts lexically. |
| `SYSTEM_REF` | `HEAD` | The System commit to check. |
| `ADOPTER_COVERAGE_RESULTS` | `coverage-results` next to the worktree | The results store (see its `README.md`). |
| `ADOPTER_COVERAGE_OUT` | `.build/adopter-coverage` | A copy of the last run's reports. |
| `ADOPTER_COVERAGE_WORK` | `.build/adopter-coverage-work` | Scratch: exports and builds, deleted as soon as their index is stored. The most a run needs at once is the largest package's build (SwiftPM's is 6 GB). |
| `ADOPTER_COVERAGE_MAPPING` | `mapping.ini` here | The mapping file. |
| `ADOPTER_COVERAGE_REBUILD` | unset | `1` rebuilds packages even when the store has their index. |
| `ADOPTER_COVERAGE_ECOSYSTEM` | `ecosystem` next to the worktree | The toolchain packages' clones (`ecosystem.sh`). |

- Refs resolve in the worktree you run the script from, as with api-delta.
- Only commits count, on both sides. Uncommitted changes aren't checked, and the script says so when there are some. A tool with uncommitted changes makes a *dirty* tool id, whose runs are stored but can't be verified.
- Nothing tracked is modified, here or in any package's checkout. The script refuses an output, scratch or results directory that holds tracked files, or that's inside this repository's or a package's worktree without being ignored, and deletes only directories it created.
- A manifest's `.package(path:)` is made absolute in the export; one that points at a swift-system checkout gets an export of the System commit being checked instead, so the build depends on commits only.
- `Utilities/nio-coverage/check.sh`, the tool's old name, runs it for `nio` alone.

Exit status:
- `0`: the mapping accounts for everything.
- `2`: a check found problems, listed at the top of the package's report.
- `1`: the tool itself failed, for at least one package. The other packages' reports are still written.

## What it produces

Everything goes to the results store; see its `README.md` (a copy of `results-README.md` here). A run's directory, `runs/<run>/`, holds `run.json` (the System commit, the tool, each package's commit, extraction and result) and the combined `COVERAGE.md` and `coverage.json`; `.build/adopter-coverage` gets a copy. Each package's result, `results/<package>/<commit>/<System commit>/<tool>/`, holds:

- `COVERAGE.md`: the report. It opens with the commits, the extraction and the check's result. Then come what the derivation decided (and where a hand status disagrees), a summary of covered, partial and missing interfaces by category and platform, the 20 largest gaps ranked by the code they'd let the package delete, and the full table by entry and by interface. It ends with the Darwin module, the System API the package already calls, the extraction's measured accuracy, and how it was generated (`scripts/method.md`: pipeline, design decisions with the alternatives they rejected, blind spots).
- `coverage.json`, `interfaces.json.gz`, `meta.json`: the data behind it (see the report's last section).
- The report's *OS use through dependencies* section, for a package whose dependencies do OS work for it (SwiftPM's swift-tools-support-core, llbuild and swift-driver): how many of its lines use a dependency symbol that reaches the OS, bounded both ways, against the lines where it names an OS interface itself.
- `logs/`: the package's build log, and its `swift package describe` and `dump-package` output.

`results.sh delta` writes, per package and combined: interfaces newly covered, from missing to partial, regressed and still missing; new and gone interfaces; and Darwin-importing files. `ecosystem.sh report` writes `ECOSYSTEM.md` into a run's directory: the toolchain's packages side by side, the standard library's C interfaces (SwiftShims and the runtime), and the top gaps, each with the System lane that should take it.

## Keeping the mapping current

Most of it keeps itself: when System gains an API whose doc comment names what it wraps, the next run covers every entry that uses it. When a check fails, or a report's *Derivation* section disagrees, the report lists what to look at:

- **New interfaces** (packages that are `strict`, the default): add each symbol to an entry in `mapping.ini`, an existing one if it belongs to the same concept, with a category and, where it helps, a note. Its status is derived; give one only if the derivation can't see the truth (see the file's header). Until then the interface is counted in an entry of its own, derived, in a category its header or name suggests.
- **A hand status that disagrees with the derivation**: each is a judgment the derivation can't make (partial: an option only through the generic setOption), an override where System's doc comments don't name what its API covers (FilePermissions and S_IRUSR: better fixed with a doc sentence in System), or stale. `scripts/mapping_edit.py prune MAPPING COVERAGE.json...` drops the hand statuses a run shows are redundant (the derivation agrees on every platform) or stale (a hand `missing` for an entry System now covers). Check the entry's notes then: a note that says System lacks something may be stale too.
- **An equivalence the derivation can't know**: `same.<symbol> = <C name>` in the entry (ucrt's _chsize_s is ftruncate). ucrt's `_x` reads as `x` on Windows without one.
- **Cited System API missing**: a hand status cites a declaration System renamed, changed or removed. The report lists the declarations of the same name that do exist.
- **System API a package already calls, missing**: a System change that would break that package's build as it stands.
- **Stale notes**: an entry has a `note.<package>`, but the package uses none of its symbols. Drop the note. The combined report lists the symbols no package uses. Neither is an error.

`scripts/system_api.py REGEX` prints System's declarations in the form `system` takes; `scripts/derive.py --summary DERIVED.json` what a commit's derivation found.

## Adding a package

Add a file to `packages/` (its README lists the keys), run `check.sh NAME`, and map what the check reports as new, or set `strict = no` to let the derivation classify it. `results.sh delta` shows what a change to the tool or the mapping did to a run.

## Run time

On an M1 Max with Swift 6.2. A package's first run at a commit builds it and reads its index; every later run of that commit, for any System commit, reuses the stored index.

| Package | New commit | Stored index |
|---|---|---|
| swift-nio | about 60 s | about 15 s |
| swift-subprocess | about 20 s | about 5 s |
| swift-package-manager | about 210 s (library targets) | about 25 s |
| swift-foundation | about 120 s (lexical, after the build fails with 6.2) | about 15 s |
| all four | about 6 minutes | about 70 s; `results.sh verify` about 80 s |

The ecosystem report gives the ecosystem run's times.

## Requirements

- macOS with Xcode's toolchain. It needs `swift`, the toolchain's `libIndexStore.dylib` next to `swift` (in `usr/lib`), and `xcrun swift-demangle`. The tool was written and checked with Swift 6.2.
- For swift-foundation's main branch, a newer compiler (`FOUNDATION_SWIFT_EXEC`), such as a swift.org main-branch snapshot's `usr/bin/swiftc`; without one it's extracted lexically.
- About 2 GB of scratch space, and the results store: tens of MB per package commit (the compressed index dump and export).
- `python3`, standard library only; the macOS system Python 3.9 works.
- Network access to fetch each package's dependencies the first time a commit is built, unless SwiftPM's cache has them, and for `ecosystem.sh clone`.
- `Utilities/api-delta/scripts/scan_sources.py` in this repository, which scans System's API. The Swift scanner also borrows its comment and string blanker.

## Why `--disable-sandbox`

As in api-delta: SwiftPM runs each manifest under `sandbox-exec`, and inside another sandbox, such as a coding agent's, applying that profile can fail with "sandbox_apply: Operation not permitted". The script passes `--disable-sandbox` to `swift build` and `swift package`, so each package's manifest runs unsandboxed. Point specs and `<P>_PATH` only at code you trust.

## Scripts

| Script | |
|---|---|
| `check.sh` | Runs everything: scans System and derives its coverage, runs `scripts/package.sh` for each package, stores the results and writes the combined report. |
| `results.sh` | The results store: list, delta, verify, rerun, migration. |
| `ecosystem.sh` | The toolchain's packages: clone, survey, run, report. |
| `scripts/package.sh` | One package: export, build, index, extraction, check and report. |
| `scripts/common.sh` | Shell helpers the scripts share. |
| `scripts/package.py` | Reads a package's file. |
| `scripts/derive.py` | What System covers at a commit, from its doc comments and CInterop typealiases. |
| `scripts/indexstore.py` | Reads the index store through libIndexStore with ctypes. |
| `scripts/platforms.py` | Platform models, and a three-valued `#if` evaluator for Swift and C. |
| `scripts/swift_scan.py`, `scripts/c_scan.py` | Lexical scans of a package's Swift and C sources. |
| `scripts/extract.py` | Combines the index and the scans into the interface list, and measures the scans against the index. |
| `scripts/darwin.py` | How each file sees the Darwin module. |
| `scripts/vocab.py` | Keeps the SDK's names from a build's index, for lexical extraction. |
| `scripts/pathdeps.py` | Makes an export's local dependencies build from where it was exported. |
| `scripts/deps.py` | Follows the package's calls into its dependencies through their call graph. |
| `scripts/check.py` | Decides each entry from the derivation and the mapping, and checks both. `check.py --summary coverage.json` prints the totals. |
| `scripts/report.py` | Writes a package's `COVERAGE.md`. |
| `scripts/results.py` | Files results in the store; list, delta, compare. |
| `scripts/combine.py` | Writes a run's combined report. |
| `scripts/lanes.py` | The System lane for a gap, from mapping.ini's `lanes`. |
| `scripts/ecosystem.py` | The toolchain's packages: scheme, clones, survey, package files, report. |
| `scripts/swiftshims.py` | Counts the standard library's C interfaces and System's coverage of them. |
| `scripts/mapping_edit.py` | Edits `mapping.ini`'s entries without reformatting it; `prune` drops redundant hand statuses. |
| `scripts/compare.py` | Compares two results of a package in detail. |
| `scripts/system_api.py` | Finds System declarations to cite in the mapping, printed the way `system` cites them. |
