# adopter-coverage

`check.sh` lists every OS and C-library interface that swift-system's adopters use, and checks how much of it the checked-out swift-system covers. An adopter is a package in `packages/`, which says where its checkout is and what the tool needs to know about it.
- **The extraction** is compiler-backed where it can be: a debug build of the package on macOS, read through the index store.
- **The mapping** is `mapping.ini`, kept by hand and shared by every package, since what System covers doesn't depend on who asks. It says, for each interface, which System API covers it (the exact declaration), or that System covers it only partly, or not at all.
- **The check** reruns the extraction on every run. It fails when a package uses an interface the mapping doesn't mention, or when the mapping cites System API the tip no longer has. Each report says where each interface is covered, platform by platform.

## Running it

```sh
Utilities/adopter-coverage/check.sh                         # every package, System at this HEAD
Utilities/adopter-coverage/check.sh nio                     # one package
NIO_REF=1a2b3c4 Utilities/adopter-coverage/check.sh nio     # another NIO commit
SYSTEM_REF=system-next Utilities/adopter-coverage/check.sh  # another System commit
open .build/adopter-coverage/nio/COVERAGE.md
```

| Variable | Default | |
|---|---|---|
| `<P>_PATH` | the package file's `checkout` | A package's checkout. `P` is the package's `variable`: `NIO_PATH`. It's only read: the commit is exported with `git archive`. |
| `<P>_REF` | `HEAD` of `<P>_PATH` | The package commit to extract from. |
| `<P>_SWIFT_EXEC` | the default toolchain | A `swiftc` to build the package with, for a package the default toolchain can't build. The manifest is still compiled with the default one. |
| `SYSTEM_REF` | `HEAD` | The System commit to check against. |
| `ADOPTER_COVERAGE_MAPPING` | `mapping.ini` here | The mapping file. |
| `ADOPTER_COVERAGE_OUT` | `.build/adopter-coverage` | The output: a directory per package. Each run replaces the directories of the packages it ran. |
| `ADOPTER_COVERAGE_WORK` | `.build/adopter-coverage-work` | Scratch: each package's export and build, kept for the next run. |

- Refs resolve in the worktree you run the script from, as with api-delta.
- Only commits count, on both sides. Uncommitted changes aren't checked, and the script says so when there are some.
- Nothing tracked is modified, here or in any package's checkout. The script refuses an output or scratch directory that git tracks or doesn't ignore, and deletes only directories it created.
- `Utilities/nio-coverage/check.sh`, the tool's old name, runs it for `nio` alone.

Exit status:
- `0`: the mapping accounts for everything.
- `2`: a check found problems, listed at the top of the package's report.
- `1`: the tool itself failed, for at least one package. The other packages' reports are still written.

## What it produces

In `ADOPTER_COVERAGE_OUT`, a directory per package, holding:

- `COVERAGE.md`: the report. It opens with both commits and the check's result. Then come a summary of covered, partial and missing interfaces by category and platform, the 20 largest gaps ranked by the code they'd let the package delete, and the full table by mapping entry and by interface. It ends with the System API the package already calls, the extraction's measured accuracy, and how it was generated (`scripts/method.md`: pipeline, design decisions with the alternatives they rejected, blind spots).
- `coverage.json`, `interfaces.json`, `meta.json`: the data behind it (see the report's last section).
- `logs/`: the package's build log, and its `swift package describe` and `dump-package` output.

Next to them, `system-api.json` is the scan of System's API on the tip.

## Keeping the mapping current

When a check fails, the report's Check section lists what to fix:

- **New interfaces**: add each symbol to an entry in `mapping.ini`, an existing one if it belongs to the same concept, with a category, a status and a note. The file's header explains the keys.
- **Cited System API missing on the tip**: System renamed, changed or removed a declaration. The report lists the declarations of the same name that do exist. Update the citation, or change the status if the coverage went away.
- **System API a package already calls, missing on the tip**: a System change that would break that package's build as it stands.
- **Stale symbols**: the package stopped using them. Remove them from their entry. This isn't an error.

When System gains an API that covers a missing entry, cite its declaration under `system` and change the status. The per-platform status follows from where the declaration compiles.

## Adding a package

Add a file to `packages/` (its README lists the keys), run `check.sh NAME`, and map what the check reports as new. `scripts/compare.py OLD/coverage.json NEW/coverage.json` shows what a change to the tool or the mapping did to a package's results.

## Run time

On an M1 Max with Swift 6.2, for swift-nio:
- **About 50 seconds** when the NIO commit is new. Most of that is NIO's debug build, plus dependency resolution the first time.
- **About 12 seconds** when NIO's build from the last run can be reused, the usual case when only System changed. Most of it is extraction.

## Requirements

- macOS with Xcode's toolchain. It needs `swift`, the toolchain's `libIndexStore.dylib` next to `swift` (in `usr/lib`), and `xcrun swift-demangle`. The tool was written and checked with Swift 6.2.
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
| `scripts/check.py` | Checks the mapping against the extraction and System's API. `check.py --summary coverage.json` prints the totals. |
| `scripts/report.py` | Writes `COVERAGE.md`. |
| `scripts/compare.py` | Compares two runs of a package. |
