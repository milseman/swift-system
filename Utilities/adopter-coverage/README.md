# adopter-coverage

`check.sh` lists every OS and C-library interface that swift-system's adopters use, and checks how much of it the checked-out swift-system covers. An adopter is a package in `packages/`, which says where its checkout is and what the tool needs to know about it.
- **The extraction** is compiler-backed where it can be: a debug build of the package on macOS, read through the index store.
- **The mapping** is `mapping.ini`, kept by hand and shared by every package, since what System covers doesn't depend on who asks. It says, for each interface, which System API covers it (the exact declaration), or that System covers it only partly, or not at all.
- **The check** reruns the extraction on every run. It fails when a package uses an interface the mapping doesn't mention, or when the mapping cites System API the tip no longer has. Each report says where each interface is covered, platform by platform, and how much of the package's OS use goes through its dependencies instead.
- **The combined report** puts the packages side by side: which gaps block how many adopters, and the gaps ranked by the code all of them could delete.

The packages are swift-nio (`nio`), swift-foundation (`foundation`), swift-package-manager (`swiftpm`) and swift-subprocess (`subprocess`).

## Running it

```sh
Utilities/adopter-coverage/check.sh                         # every package, System at this HEAD
Utilities/adopter-coverage/check.sh nio                     # one package
NIO_REF=1a2b3c4 Utilities/adopter-coverage/check.sh nio     # another NIO commit
SYSTEM_REF=system-next Utilities/adopter-coverage/check.sh  # another System commit
open .build/adopter-coverage/COVERAGE.md           # the combined report
open .build/adopter-coverage/nio/COVERAGE.md       # one package's
FOUNDATION_SWIFT_EXEC=/path/to/newer/usr/bin/swiftc Utilities/adopter-coverage/check.sh foundation
FOUNDATION_REUSE_INDEX=1 Utilities/adopter-coverage/check.sh foundation   # without that compiler, the last dump
```

| Variable | Default | |
|---|---|---|
| `<P>_PATH` | the package file's `checkout` | A package's checkout. `P` is the package's `variable`: `NIO_PATH`. It's only read: the commit is exported with `git archive`. |
| `<P>_REF` | `HEAD` of `<P>_PATH` | The package commit to extract from. |
| `<P>_SWIFT_EXEC` | the default toolchain | A `swiftc` to build the package with, for a package the default toolchain can't build (swift-foundation's main branch needs a newer compiler than Swift 6.2). The manifest is still compiled with the default one. |
| `<P>_REUSE_INDEX` | unset | `1` reuses the package's index dump from an earlier run of the same commit, whatever compiler and index reader made it: for a package whose compiler this machine no longer has. The report records which made it. |
| `SYSTEM_REF` | `HEAD` | The System commit to check against. |
| `ADOPTER_COVERAGE_MAPPING` | `mapping.ini` here | The mapping file. |
| `ADOPTER_COVERAGE_OUT` | `.build/adopter-coverage` | The output: a directory per package. Each run replaces the directories of the packages it ran. |
| `ADOPTER_COVERAGE_WORK` | `.build/adopter-coverage-work` | Scratch: each package's export and a dump of its index store, kept for the next run. A build is deleted as soon as its index has been read (SwiftPM's is 6 GB), so the most a run needs at once is the largest package's build. |

- Refs resolve in the worktree you run the script from, as with api-delta.
- Only commits count, on both sides. Uncommitted changes aren't checked, and the script says so when there are some.
- Nothing tracked is modified, here or in any package's checkout. The script refuses an output or scratch directory that git tracks or doesn't ignore, and deletes only directories it created.
- `Utilities/nio-coverage/check.sh`, the tool's old name, runs it for `nio` alone.

Exit status:
- `0`: the mapping accounts for everything.
- `2`: a check found problems, listed at the top of the package's report.
- `1`: the tool itself failed, for at least one package. The other packages' reports are still written.

## What it produces

In `ADOPTER_COVERAGE_OUT`, `COVERAGE.md` and `coverage.json` are the combined report, written from every package directory there, including ones an earlier run wrote. A directory per package holds:

- `COVERAGE.md`: the report. It opens with both commits and the check's result. Then come a summary of covered, partial and missing interfaces by category and platform, the 20 largest gaps ranked by the code they'd let the package delete, and the full table by mapping entry and by interface. It ends with the System API the package already calls, the extraction's measured accuracy, and how it was generated (`scripts/method.md`: pipeline, design decisions with the alternatives they rejected, blind spots).
- `coverage.json`, `interfaces.json`, `meta.json`: the data behind it (see the report's last section).
- The report's *OS use through dependencies* section, for a package whose dependencies do OS work for it (SwiftPM's swift-tools-support-core, llbuild and swift-driver): how many of its lines use a dependency symbol that reaches the OS, bounded both ways, against the lines where it names an OS interface itself.
- `logs/`: the package's build log, and its `swift package describe` and `dump-package` output.

Next to them, `system-api.json` is the scan of System's API on the tip.

## Keeping the mapping current

When a check fails, the report's Check section lists what to fix:

- **New interfaces**: add each symbol to an entry in `mapping.ini`, an existing one if it belongs to the same concept, with a category, a status and a note. The file's header explains the keys.
- **Cited System API missing on the tip**: System renamed, changed or removed a declaration. The report lists the declarations of the same name that do exist. Update the citation, or change the status if the coverage went away.
- **System API a package already calls, missing on the tip**: a System change that would break that package's build as it stands.
- **Stale notes**: an entry has a `note.<package>`, but the package uses none of its symbols. Drop the note. The combined report lists the symbols no package uses. Neither is an error.

When System gains an API that covers a missing entry, cite its declaration under `system` and change the status. The per-platform status follows from where the declaration compiles. `scripts/system_api.py REGEX` prints the matching declarations of the last run's tip in the form `system` takes, with their platforms and availability.

## Adding a package

Add a file to `packages/` (its README lists the keys), run `check.sh NAME`, and map what the check reports as new. `scripts/compare.py OLD/coverage.json NEW/coverage.json` shows what a change to the tool or the mapping did to a package's results.

## Run time

On an M1 Max with Swift 6.2, when the package's commit is new (its debug build and index read; SwiftPM's repository cache held every dependency), and when its index dump from the last run can be reused, the usual case when only System changed:

| Package | New commit | Reused |
|---|---|---|
| swift-nio | about 50 s | about 13 s |
| swift-subprocess | about 20 s | about 4 s |
| swift-package-manager | about 200 s (library targets) | about 21 s |
| swift-foundation | about 180 s (with a 6.5-dev compiler) | about 18 s |
| all four | | about 55 s |

## Requirements

- macOS with Xcode's toolchain. It needs `swift`, the toolchain's `libIndexStore.dylib` next to `swift` (in `usr/lib`), and `xcrun swift-demangle`. The tool was written and checked with Swift 6.2.
- For swift-foundation's main branch, a newer compiler (`FOUNDATION_SWIFT_EXEC`), such as a swift.org main-branch snapshot's `usr/bin/swiftc`.
- About 2 GB of scratch space: a package's build is deleted once its index is read, and SwiftPM's library build is the largest, at 1.5 GB.
- `python3`, standard library only; the macOS system Python 3.9 works.
- Network access to fetch each package's dependencies the first time a commit is built, unless SwiftPM's cache has them.
- `Utilities/api-delta/scripts/scan_sources.py` in this repository, which scans System's API. The Swift scanner also borrows its comment and string blanker.

## Why `--disable-sandbox`

As in api-delta: SwiftPM runs each manifest under `sandbox-exec`, and inside another sandbox, such as a coding agent's, applying that profile can fail with "sandbox_apply: Operation not permitted". The script passes `--disable-sandbox` to `swift build` and `swift package`, so each package's manifest runs unsandboxed. Point `<P>_PATH` and `<P>_REF` only at code you trust.

## Scripts

| Script | |
|---|---|
| `check.sh` | Runs everything: scans System, then runs `scripts/package.sh` for each package. |
| `scripts/package.sh` | One package: export, build, index, extraction, check and report. |
| `scripts/common.sh` | Shell helpers the two share. |
| `scripts/package.py` | Reads a package's file. |
| `scripts/indexstore.py` | Reads the index store through libIndexStore with ctypes. |
| `scripts/platforms.py` | Platform models, and a three-valued `#if` evaluator for Swift and C. |
| `scripts/swift_scan.py`, `scripts/c_scan.py` | Lexical scans of a package's Swift and C sources. |
| `scripts/extract.py` | Combines the index and the scans into the interface list, and measures the scans against the index. |
| `scripts/deps.py` | Follows the package's calls into its dependencies through their call graph. |
| `scripts/check.py` | Checks the mapping against the extraction and System's API. `check.py --summary coverage.json` prints the totals. |
| `scripts/report.py` | Writes a package's `COVERAGE.md`. |
| `scripts/combine.py` | Writes the combined report. |
| `scripts/mapping_edit.py` | Edits `mapping.ini`'s entries without reformatting it. |
| `scripts/compare.py` | Compares two runs of a package. |
| `scripts/system_api.py` | Finds System declarations to cite in the mapping, printed the way `system` cites them. |
