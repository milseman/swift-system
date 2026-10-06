# import-probe

`probe.sh` asks the compiler what a package still takes from the platform C modules. It exports one branch of the package, removes one target's imports of those modules, builds the target, and reads the names the compiler can't find. It repeats this for each target in turn and classifies each name against what System covers. The ledger (`Utilities/adopter-coverage/status.sh`, section 5 of STATUS.md) reads the same imports lexically; comparing the two is the point (see [the comparison](#the-comparison-with-the-ledger)).

```sh
Utilities/import-probe/probe.sh ../adopters/swift-log                       # macOS, the newest migration branch
Utilities/import-probe/probe.sh --linux ../adopters-unix/swift-nio          # Linux, in a container
Utilities/import-probe/probe.sh --branch main ../adopters/swift-log         # another branch
Utilities/import-probe/probe.sh --targets NIOCore,NIOPosix --keep ../adopters-unix/swift-nio
open .build/import-probe/out/swift-nio/SUMMARY.md
```

| Option | Default | |
|---|---|---|
| `CLONE...` | | Checkouts of packages, clones or worktrees. Only their commits are read. |
| `--branch B` | the newest migration branch | The branch to probe. By default, the first of `migrate-all`, `migrate-unix` and `migrate-darwin` the clone has. |
| `--linux` | macOS | Builds in a Linux container through `Utilities/linux/build.sh`. |
| `--swift V` | build.sh's (6.2) | The Linux image's Swift version. |
| `--system REF` | `system-next` | The System commit to build against and to classify with, in this worktree. |
| `--targets T,...` | every Swift target | Only these targets. |
| `--ledger FILE` | `.build/status/ledger.json` if it exists | The ledger's JSON (`STATUS_LEDGER_JSON` of a `status.sh` run), for the comparison. |
| `--keep` | off | Keeps the scratch directory, whose build a rerun then reuses. |
| `--no-skip` | off | Builds a target even when the platform compiles none of its removed imports. |
| `--min-free-gb N` | 15 | Refuses to start a package with less free disk than this. |
| `--work DIR`, `--out DIR` | `.build/import-probe/work`, `.build/import-probe/out` | Scratch and output; both must be ignored by git. |

## What it does

For each clone, on one platform:

1. **The copy.** The branch is exported with `git archive` into `work/<package>-<platform>/src/<package>`. The clone is never edited, checked out or built in.
2. **Dependencies, offline.** Each dependency becomes a path dependency on an export in `work/.../deps/<identity>` (`scripts/manifests.py`). System is exported at `--system`, with its manifest's Samples and swift-argument-parser dropped. A remote package is exported from SwiftPM's repository cache (`~/Library/Caches/org.swift.swiftpm/repositories`), at the revision the package's `Package.resolved` pins, or else at the highest cached tag its requirement allows. A dependency that isn't cached stops the run: nothing is fetched. All paths are relative to the scratch directory, so the same copy builds on macOS and in a container that sees only that directory.
3. **Targets.** `swift package describe` (on macOS, for both platforms) gives the targets and their dependencies. Swift targets are probed in dependency order; C targets aren't.
4. **Imports removed** (`scripts/strip.py`). In a target's files, every import of a module in `modules.ini`'s `[count]` group is commented out on its own line, so the compiler's line numbers stay the original's. That covers Darwin, Glibc, Musl, Android, WASILibc, ucrt, WinSDK, MachO, the C library's `*_h` modules and the rest, read with adopter-coverage's `ledger.Modules`. The package's configured shims go too (`packages.ini`). Every form counts: plain, `@preconcurrency`, `@_implementationOnly`, `@_exported`, access levels, scoped (`import func Darwin.fopen`), submodules, trailing comments, any `#if` arm. An attribute on the line above goes with its import. `import SystemPackage`, Foundation and the package's own modules stay.
5. **Builds.** A target is built only if the platform compiles at least one of its removed imports. That's decided by adopter-coverage's three-valued `#if` evaluator (`platforms.py`); a *maybe* counts as compiled. When any target is built, the unmodified copy is built first (the baseline, `--build-tests`). Then each such target is built alone with `swift build --target T -Xswiftc -continue-building-after-errors`, with the other targets as they are, in one build directory, so dependencies aren't rebuilt. Every file of the target is touched first, so all of it recompiles: an `@_exported` import in one file serves the whole module, and an incremental build would recompile only the files it thinks changed. Then the target's files are restored. SwiftPM won't build a target whose dependency failed, hence one target at a time.
6. **Diagnostics** (`scripts/diags.py`). Errors in the target's files, less any the baseline already had, are read:

   | Diagnostic | Kind |
   |---|---|
   | `cannot find 'X' in scope` | value |
   | `cannot find type 'X' in scope` | type |
   | `property 'X' is not available due to missing import of defining module 'M'` | member (MemberImportVisibility) |
   | `value of type 'T' has no member 'X'`, `type 'T' has no member 'X'` | member |
   | `no such module 'X'` | module |
   | `cannot find 'Glibc' in scope`, for a removed module | qualified: the name after `Glibc.` in the source |

   A diagnostic that two jobs print (emit-module and compile) is kept once. A follow-on is an error the probe can tell another one caused: one with `<<error type>>`, one naming a name the file can't find, one inside the same function, initializer or subscript as a primary error, or a declaration that holds one (a type whose stored property's type is unresolved can't conform). Follow-ons are counted apart. Every other error is listed, unclassified.
7. **Classes** (`scripts/classify.py`), from adopter-coverage's ledger, imported read-only: `ledger.Coverage.answer` at the System commit built against, with `mapping.ini` and `modules.ini` read at this worktree's HEAD.

   | Class | Meaning |
   |---|---|
   | `covered` | System covers the name on this platform: work for the adopter. |
   | `gap` | System lacks it there: a System gap. |
   | `not System's` | mapping.ini's `wrap = no`, a lane's verdict. |
   | `standard library` | mapping.ini's `swift` answer. |
   | `shim's own` | Declared by one of the package's shims (`packages.ini`). |
   | `module` | A module the file can't find, not a name. |

8. **Output.** It writes `out/<package>/<platform>.json` with everything, `out/<package>/import-probe.json` and `out/import-probe.json` with one record per site, and `out/<package>/SUMMARY.md` for the package. A record has the package, branch, commit, platform, target, file, line, column, name, kind, defining module, class, System's answer and the diagnostic. The scratch directory is deleted unless `--keep`.

## The comparison with the ledger

With a ledger.json (`STATUS_OUT=... STATUS_LEDGER_JSON=... Utilities/adopter-coverage/status.sh`, which can write both outside `Prototype/Status`), each platform's section of SUMMARY.md compares the ledger's import sites, the ones compiled on that platform, with the imports the probe removed and the names the compiler then needed. It first checks that the ledger read the same commit. It lists:

- the ledger's sites outside every target the probe builds: nested packages, benchmarks, integration tests, scripts;
- sites the ledger says the platform compiles and the probe's evaluation says it doesn't, or the reverse;
- imports only one of them has;
- imports whose file built without them (removable now). An import whose target still reaches the C module through another target's `@_exported` import is listed apart, since its names may come through there;
- for each import both have, the names only the ledger gives (the compiler found them without the import, through another import, a re-export or the package's own declarations, or the lexical scan misread them), the names only the compiler needed, and names the two classify differently;
- an `@_exported` import's names in the rest of its module, which the ledger gives no site.

## Known limits

- **Foundation re-exports Darwin** on Darwin. A file that imports Foundation still sees every C name after its own imports go, so names it uses are invisible here. The summary counts these files; on macOS that's most test targets. On Linux, a name Foundation's own imports make visible is invisible the same way.
- **A package's own C targets** (CNIOLinux) have modules that re-export the system headers they include. Names a file takes through one aren't seen; the summary counts the files that import one.
- **Re-exports by other targets.** When target A `@_exported import`s Glibc, a target that imports A still sees Glibc while it's probed. The summary lists those targets. Demoting the re-export for the whole build would fail every target that relies on it, and SwiftPM wouldn't build their dependents.
- **Only the platform built.** Code under `#if` for a platform not built isn't compiled, so it isn't seen: Windows, WASI, the BSDs and Android here. **Musl and WASI** need `Utilities/linux/cross.sh`, which builds only its own package (no `--root`/`--dir` as build.sh has), so they aren't run; that's recorded as a need.
- **Cross-file follow-ons**, such as a call whose callee's signature failed in another file (`'nil' requires a contextual type`), aren't recognized. They're listed as other errors.
- **Targets come from macOS's `describe`**, for Linux too. A manifest whose targets differ by platform would need the container's.
- MemberImportVisibility errors appear only in packages that enable it (swift-log and swift-nio do; swift-tools-support-core doesn't). Without it, a C field reached through a System type's value resolves anyway.

## Per-package settings

`packages.ini` names a package's **shims**, modules that exist to re-export the C library (TSCLibc, SWBLibc, swift-testing's `_TestingInternals`). Their imports are removed from the probed target like a C module's, and a name a shim declares itself is classed `shim's own`. A re-export that isn't a shim, such as NIOPosix's, stays (above). A note for the summary can go there too.

## Run time and disk

On an M1 Max with Swift 6.2. These are the full runs on the three packages the tool was tested on, including the export, the System build and the baseline:

| Package | macOS | Linux (container) |
|---|---|---|
| swift-log `migrate-all` | 1 s (nothing to build) | 2 s (nothing to build) |
| swift-log `main` (upstream) | 17 s | |
| swift-tools-support-core `migrate-unix` | 58 s | 54 s |
| swift-nio `migrate-unix` | 8 s (nothing to build) | 109 s, 75 of them the baseline |

swift-nio's scratch directory reaches about 1.2 GB on Linux. It's deleted when the package is done.

## Requirements

- macOS with Xcode's toolchain (`swift`), git and `python3` (the system's 3.9 works; standard library only).
- For `--linux`, Apple's `container` tool and the image `Utilities/linux/build.sh` uses, already pulled. Nothing is fetched.
- Read-only imports from `Utilities/adopter-coverage/scripts` (ledger, check, derive, platforms, status), `Utilities/api-delta/scripts/scan_sources.py`, and `Utilities/linux/build.sh`. Bytecode is off, so nothing is written into their directories.
- `--disable-sandbox`, as every tool here passes, since SwiftPM's manifest sandbox fails inside another sandbox. Only probe packages you trust.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'
```

They cover import removal in every form, diagnostics and follow-ons, the manifests' dependencies, rewrites, version requirements and System's manifest, and the ledger comparison (re-exports and reaching through one included), over text fixtures. One test makes a git repository in a temporary directory as a stand-in for SwiftPM's cache, and deletes it. Nothing is built and nothing reaches the network. The runs on the three packages are the end-to-end test; their summaries are in `Prototype/Tooling/REPORT.md`.

## Design calls

- **Commit the copy, not the clone.** The export is the only thing edited. *Rejected*: building in the clone with its imports patched and restored, which a crash would leave half-edited.
- **Path dependencies on exports** for every dependency. *Rejected*: `--skip-update` resolution from SwiftPM's cache, which works on macOS but not in a fresh container; and the clone's own `.build/checkouts`, which may not exist or match.
- **One target at a time, every file of it recompiled.** *Rejected*: all targets' imports removed at once, since SwiftPM builds no target whose dependency failed; and a plain incremental build, which on swift-nio missed the files that NIOPosix's re-export served (18 of 56 files compiled, 69 names instead of 78).
- **Skipping targets the platform doesn't compile an import of**, by adopter-coverage's evaluator. *Rejected*: building every target with a textual removal, which on a migrated branch is mostly Windows-only imports: minutes for nothing (`--no-skip` does it).
- **The ledger's classification**, not a new one, so that the comparison differs only in which names are found.

## Next

- Musl and WASI, once `cross.sh` takes `--root` and `--dir` as build.sh does.
- A Foundation-free view on Darwin: in files that import Foundation, also remove Foundation and keep only the names that don't belong to it.
- The container's own `swift package describe`, for manifests whose targets differ on Linux.
- Run every adopter in `../adopters` on both platforms and file the results by commit, as adopter-coverage's results store does.
