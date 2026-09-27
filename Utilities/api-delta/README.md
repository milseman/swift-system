# api-delta

`regenerate.sh` reports the public API delta between two commits for the `SystemPackage` and `SystemSockets` modules, and builds DocC archives for both commits. The report lists every added, removed, and changed declaration. It also flags missing availability and doc comments, underscored and SPI API, new ABI surface, and public API that only other platforms compile.

`Utilities/api-graph` builds on this report: it clusters the added declarations into carve-outs for pitches, tags the open design questions each depends on, and ranks them.

## Running it

```sh
Utilities/api-delta/regenerate.sh                                     # main vs system-next
BASE_REF=main HEAD_REF=HEAD Utilities/api-delta/regenerate.sh         # main vs your HEAD
BASE_REF=system-next HEAD_REF=HEAD Utilities/api-delta/regenerate.sh  # what your branch adds
open .build/api-delta/API-DELTA.md
```

| Variable | Default | |
|---|---|---|
| `BASE_REF` | `main` | The commit to compare against: a branch, a tag, a hash, or an expression such as `HEAD~3`. |
| `HEAD_REF` | `system-next` | The commit to report on, spelled the same ways. |
| `API_DELTA_OUT` | `.build/api-delta` | The output. Each successful run replaces it. |
| `API_DELTA_WORK` | `.build/api-delta-work` | Scratch: both exports and their builds, about 270 MB. The next run deletes it. |

- Refs resolve in the worktree you run the script from, so `HEAD` is that worktree's HEAD, and the default directories are in its `.build`. That holds even if the script comes from another worktree, say one whose branch has the tool when yours doesn't. Run from outside this repository, refs resolve in the worktree that holds the script.
- Only commits count. Each one is exported with `git archive`, so uncommitted changes aren't in the report.
- Nothing tracked is modified. The script refuses an output or scratch directory that git tracks or doesn't ignore, and deletes only directories it created. A second run refuses a scratch directory that a live run is using.

## What it produces

In `API_DELTA_OUT`:

- `API-DELTA.md`: the report. It opens with both commit hashes, and its last section, "How this was generated" (`scripts/method.md`), records the pipeline, each design decision with the alternative it rejected, and the limitations.
- `api-delta.json`: the same data in machine-readable form.
- `docs/base.doccarchive` and `docs/head.doccarchive`: DocC for each commit. DocC archives have to be served; the report says how.
- `symbolgraphs/` and `logs/`: the symbol graphs the diff read, and the logs of each build and tool.

## Run time

About 40 seconds on an M1 Max with Swift 6.2, and the same again for a rerun, since each run starts from an empty scratch directory. Nearly half is the four builds: for each commit, one for the symbol graphs and one for the explicit-availability check. DocC takes about a quarter, and deleting the previous run's scratch directory a few seconds.

## Requirements

- macOS with Xcode's toolchain: `swift`, `xcrun docc`, and `xcrun swift-api-digester`. The package needs Swift 6.1 or later; the tool was written and checked with Swift 6.2.
- `python3`. The scripts use only the standard library, and the macOS system Python 3.9 works.
- No network. The scratch copy of `Package.swift` drops the `Samples` executable and its swift-argument-parser dependency, so there's nothing to fetch.

## Why `--disable-sandbox`

On macOS, SwiftPM runs each `Package.swift` under `/usr/bin/sandbox-exec`. Inside another sandbox, such as a coding agent's, applying that second profile can be refused with "sandbox_apply: Operation not permitted", and then no manifest loads. The script passes `--disable-sandbox` to `swift package` and `swift build` so that it runs the same way inside a sandbox and out. The cost is that the manifests run unsandboxed. They're this repository's own `Package.swift` at the two commits, patched as `scripts/patch_manifest.py` describes, so only point `BASE_REF` and `HEAD_REF` at commits you trust.
