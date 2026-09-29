# Utilities

Scripts and tools for working on swift-system and its adopters. Each directory has a README with the details; this is the index. Every tool runs on macOS from a checkout of this repository (any worktree), reads commits or checkouts without modifying them unless its README says otherwise, and writes its output under `.build/` or a scratch directory outside the checkout.

| Tool | The question it answers | When to run it | How long | Output | Owner |
|---|---|---|---|---|---|
| [`api-delta/regenerate.sh`](api-delta/README.md) | What public API does one commit add, remove or change against another, and is each declaration annotated (availability, docs, SPI, ABI)? | Before merging a lane, to see what it adds; when preparing a pitch. `status.sh` reruns it when `Sources/` changes. | about 40 s | `.build/api-delta/`: `API-DELTA.md`, `api-delta.json`, DocC archives, symbol graphs, logs | `api-tool` (closed, merged 2026-09-23) |
| [`api-graph/regenerate.sh`](api-graph/README.md) | How does the API system-next adds break into small pitches, what open questions does each depend on, and in what order should they go? | After lanes merge, to see the map move; before a pitch session (a carve-out's `bundle.md`). | about 65 s | `.build/api-graph/`: `API-GRAPH.md`, `bundles/<id>/`, `api-graph.json`, Graphviz files | `api-graph` |
| [`adopter-coverage/check.sh`](adopter-coverage/README.md) | Which OS and C-library interfaces do swift-system's adopters (NIO, Foundation, SwiftPM, Subprocess) use, and which does a System commit cover? | When System gains API an adopter needs; when adding an adopter; after editing `mapping.ini`. | about 70 s with stored indexes, about 6 min for new commits of all four | the results store (`../coverage-results`); the last run's `COVERAGE.md` files in `.build/adopter-coverage/` | `coverage` |
| [`adopter-coverage/status.sh`](adopter-coverage/README.md#the-status-report) | Where do things stand: API-delta's summary, each migration branch's Darwin imports and SYSTEM-GAP markers, and the gaps by interface with what System covers now? | After every merge into system-next and every migration commit. | about 10 s, a minute more when api-delta must rerun | `Prototype/Status/STATUS.md` (committed by its owner); caches in `.build/status/` | `coverage` |
| [`adopter-coverage/results.sh`](adopter-coverage/README.md) | What changed between two coverage runs? Does a stored run reproduce? What did a migration branch gain? | After changing the tool or the mapping; to compare System commits. | under a second for `list`; about 80 s for `verify` | the results store; `delta --markdown` writes a file | `coverage` |
| [`adopter-coverage/ecosystem.sh`](adopter-coverage/README.md) | Which of the toolchain's other packages import Darwin, and what would they need? | Rarely: when the scheme's package list changes. | about 35 min the first time, 4 min with stored indexes | clones in `../ecosystem`; `ECOSYSTEM.md` in a run's directory | `coverage` |
| [`linux/build.sh`](linux/README.md) | Does the package build, and pass its tests, on Linux? | Before claiming Linux code works; after touching Linux-only code (`IORing/`, `CSystemLinux.h`, epoll, the MemberImportVisibility probes). | under 1 min for a clean build and test on arm64, over 2 min on amd64; the first run pulls a 3.7 GB image | `.build/linux-<tag>/` (scratch), `.build/linux-<tag>-<action>.log` | `linux-build` (closed, merged 2026-09-27) |
| [`adopter-tools/`](adopter-tools/README.md) | For a package being migrated off Darwin: which files import or leak Darwin, which SYSTEM-GAP markers it has, which System API wraps a C name, and did a step change any test's outcome? | During an adopter migration: at the start, after each step, before reporting. | 1–15 s each; `step.sh` and `tests-by-target.sh` take the package's build and test time | standard output; index dumps in `$TMPDIR/adopter-tools/`; logs where you say | `utilities` |

`Utilities/nio-coverage`, the first name of adopter-coverage, is retired: `adopter-coverage/check.sh nio` is what it ran.

## How they fit together

- **API.** api-delta diffs two commits' public API. api-graph runs api-delta and turns the additions into a ranked map of pitches. status.sh copies api-delta's summary into STATUS.md.
- **Adopters.** A migration lane works in a clone in `../adopters` and checks each step with `adopter-tools` (counts from source, the audit from the build's index, test outcomes from the logs). status.sh then counts every clone's committed `migrate-darwin` branch for STATUS.md, and check.sh measures the audited adopters against what System covers, by commit.
- **Platforms.** Everything else builds on macOS only; `linux/build.sh` is the only way to compile Linux code here.

## What they share

- **Commits, not working trees**, for the reports: api-delta, api-graph and adopter-coverage export the commits they read with `git archive`, so uncommitted changes don't count, and refs resolve in the worktree you run the script from. `adopter-tools` reads working trees as well, for migrations in progress.
- **Nothing tracked is modified.** Output goes under `.build/` or a scratch directory; api-delta, api-graph and adopter-coverage also refuse an output directory that git tracks. The exception is `status.sh`, whose report is committed.
- **`--disable-sandbox`.** Tools that run SwiftPM pass it: inside another sandbox, such as a coding agent's, SwiftPM's manifest sandbox fails. Point them only at packages you trust.
- **Requirements.** macOS with Xcode's toolchain, `python3` (the system's 3.9 works; standard library only), and git. `linux/build.sh` needs Apple's `container` tool. Run times above are from an M1 Max with Swift 6.2.

## Not here

Checks of one design decision live with the decision, under `Prototype/`: for example `Prototype/PlatformEnum/check.sh`, `Prototype/Subtypes/check.sh`, and the `check-linux.sh` harnesses in `Prototype/Events`, `Prototype/StatFS` and `Prototype/Processes`. Each prototype's README describes its own.
