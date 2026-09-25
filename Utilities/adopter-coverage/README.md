# adopter-coverage

`check.sh` lists every OS and C-library interface that swift-nio's library targets use, and checks how much of it the checked-out swift-system covers.
- **The extraction** is compiler-backed where it can be: a debug build of NIO on macOS, read through the index store.
- **The mapping** is `mapping.ini`, kept by hand. It says, for each interface, which System API covers it (the exact declaration), or that System covers it only partly, or not at all.
- **The check** reruns the extraction on every run. It fails when NIO uses an interface the mapping doesn't mention, or when the mapping cites System API the tip no longer has. The report says where each interface is covered, platform by platform.

## Running it

```sh
Utilities/adopter-coverage/check.sh                         # NIO at ../swift-nio HEAD, System at this HEAD
NIO_REF=1a2b3c4 Utilities/adopter-coverage/check.sh         # another NIO commit
SYSTEM_REF=system-next Utilities/adopter-coverage/check.sh  # another System commit
open .build/nio-coverage/COVERAGE.md
```

| Variable | Default | |
|---|---|---|
| `NIO_PATH` | `../swift-nio` next to this repository | The swift-nio checkout. It's only read: the commit is exported with `git archive`. |
| `NIO_REF` | `HEAD` of `NIO_PATH` | The NIO commit to extract from. |
| `SYSTEM_REF` | `HEAD` | The System commit to check against. |
| `NIO_COVERAGE_MAPPING` | `mapping.ini` here | The mapping file. |
| `NIO_COVERAGE_OUT` | `.build/nio-coverage` | The output. Each run replaces it. |
| `NIO_COVERAGE_WORK` | `.build/nio-coverage-work` | Scratch: NIO's export and build (about 800 MB), kept for the next run. |

- Refs resolve in the worktree you run the script from, as with api-delta.
- Only commits count, on both sides. Uncommitted changes aren't checked, and the script says so when there are some.
- Nothing tracked is modified, here or in `NIO_PATH`. The script refuses an output or scratch directory that git tracks or doesn't ignore, and deletes only directories it created.

Exit status:
- `0`: the mapping accounts for everything.
- `2`: the check found problems, listed at the top of the report.
- `1`: the tool itself failed.

## What it produces

In `NIO_COVERAGE_OUT`:

- `COVERAGE.md`: the report. It opens with both commits and the check's result. Then come a summary of covered, partial and missing interfaces by category and platform, the 20 largest gaps ranked by the NIO code they'd let NIO delete, and the full table by mapping entry and by interface. It ends with the System API NIO already calls, the extraction's measured accuracy, and how it was generated (`scripts/method.md`: pipeline, design decisions with the alternatives they rejected, blind spots).
- `coverage.json`, `nio-interfaces.json`, `system-api.json`: the data behind it (see the report's last section).
- `logs/`: NIO's build log, and its `swift package describe` and `dump-package` output.

## Keeping the mapping current

When the check fails, the report's Check section lists what to fix:

- **New NIO interfaces**: add each symbol to an entry in `mapping.ini`, an existing one if it belongs to the same concept, with a category, a status and a note. The file's header explains the keys.
- **Cited System API missing on the tip**: System renamed, changed or removed a declaration. The report lists the declarations of the same name that do exist. Update the citation, or change the status if the coverage went away.
- **System API NIO already calls, missing on the tip**: a System change that would break NIO's build as it stands.
- **Stale symbols**: NIO stopped using them. Remove them from their entry. This isn't an error.

When System gains an API that covers a missing entry, cite its declaration under `system` and change the status. The per-platform status follows from where the declaration compiles.

## Run time

On an M1 Max with Swift 6.2:
- **About 60 seconds** when the NIO commit is new. Most of that is NIO's debug build, plus dependency resolution the first time.
- **About 11 seconds** when NIO's build from the last run can be reused, the usual case when only System changed. Most of it is extraction.

## Requirements

- macOS with Xcode's toolchain. It needs `swift`, the toolchain's `libIndexStore.dylib` next to `swift` (in `usr/lib`), and `xcrun swift-demangle`. The tool was written and checked with Swift 6.2.
- `python3`, standard library only; the macOS system Python 3.9 works.
- Network access to fetch NIO's dependencies (swift-atomics, swift-collections, swift-system) the first time a NIO commit is built, unless SwiftPM's cache has them.
- `Utilities/api-delta/scripts/scan_sources.py` in this repository, which scans System's API. The Swift scanner also borrows its comment and string blanker.

## Why `--disable-sandbox`

As in api-delta: SwiftPM runs each manifest under `sandbox-exec`, and inside another sandbox, such as a coding agent's, applying that profile can fail with "sandbox_apply: Operation not permitted". The script passes `--disable-sandbox` to `swift build` and `swift package`, so NIO's manifest runs unsandboxed. Point `NIO_PATH` and `NIO_REF` only at code you trust.

## Scripts

| Script | |
|---|---|
| `check.sh` | Runs everything. |
| `scripts/indexstore.py` | Reads the index store through libIndexStore with ctypes. |
| `scripts/platforms.py` | Platform models, and a three-valued `#if` evaluator for Swift and C. |
| `scripts/swift_scan.py`, `scripts/c_scan.py` | Lexical scans of NIO's Swift and C sources. |
| `scripts/extract.py` | Combines the index and the scans into the interface list, and measures the scans against the index. |
| `scripts/check.py` | Checks the mapping against the extraction and System's API. `check.py --summary coverage.json` prints the totals. |
| `scripts/report.py` | Writes `COVERAGE.md`. |
