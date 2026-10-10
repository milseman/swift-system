# import-probe

`probe.sh` asks the compiler what a package still takes from the platform C modules. It exports one branch of the package, removes one target's imports of those modules, builds the target, and reads the names the compiler can't find. It repeats this for each target in turn and classifies each name against what System covers. The ledger (`Utilities/adopter-coverage/status.sh`, section 5 of STATUS.md) reads the same imports lexically; comparing the two is the point (see [the comparison](#the-comparison-with-the-ledger)). Two more passes find what those builds can't see: the C names a file reaches through a C module of its own package ([`--own-modules`](#names-through-the-packages-own-c-modules)), and the names a package gets only through another module's `@_exported import` of the C library ([`--reexport`](#the-re-export-run)).

```sh
Utilities/import-probe/probe.sh ../adopters/swift-log                       # macOS, the newest migration branch
Utilities/import-probe/probe.sh --linux ../adopters-unix/swift-nio          # Linux, in a container
Utilities/import-probe/probe.sh --branch main ../adopters/swift-log         # another branch
Utilities/import-probe/probe.sh --targets NIOCore,NIOPosix --keep ../adopters-unix/swift-nio
Utilities/import-probe/probe.sh --nested ../adopters/swift-nio-imap         # the root and each nested package
Utilities/import-probe/probe.sh --package-dir Examples/IMAPTool ../adopters/swift-nio-imap
Utilities/import-probe/probe.sh --linux --own-modules ../adopters/swift-nio-ssl
Utilities/import-probe/probe.sh --linux --reexport --branch main ../adopters/swift-nio-extras
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
| `--nested` | off | Also probes each nested package of the branch: a directory, other than the root, with a `Package.swift` of its own (examples, benchmarks). Each is probed in place in the clone's export and reported on its own, in `out/<package>-<directory>`, its `/`s as `-`s. |
| `--package-dir DIR,...` | `.`, the root | Probes these package directories of the clone instead: `.` is the root, `Examples/IMAPTool` a nested package. Repeatable. |
| `--path-dep IDENTITY=REF`, `IDENTITY=REPO@REF` | the checkout's HEAD | Exports the local path dependency of that identity at REF, in the checkout the manifest names, or in REPO. Repeatable. |
| `--own-modules` | off | Also finds the C names a file reaches through a C module of its own package: two more builds of each target that imports one ([below](#names-through-the-packages-own-c-modules)). |
| `--reexport` | off | The re-export run, instead of the per-target probes ([below](#the-re-export-run)). |
| `--work DIR`, `--out DIR` | `.build/import-probe/work`, `.build/import-probe/out` | Scratch and output; both must be ignored by git. |

## What it does

For each package of a clone (its root, or the directories `--nested` and `--package-dir` give), on one platform:

1. **The copy.** The branch is exported with `git archive` into `work/<package>-<platform>/src/<package>`, the whole branch even for a nested package, which is probed in place there, so that its `../..` is the root package at the same commit. The clone is never edited, checked out or built in.
2. **Dependencies** (`scripts/manifests.py`). The *local packages* are the probed one, the packages of its own branch it takes by path (a nested package's `../..`), and its local path dependencies, transitively. Each dependency a local package's manifests name becomes a path dependency on an export in `work/.../deps/<identity>`, and the local packages' manifests are rewritten to point there; one within the branch stays as it is.
   - **System** is exported at `--system`, with its manifest's Samples and swift-argument-parser dropped. Every dependency whose identity is `swift-system` gets it.
   - **A remote package** is exported from SwiftPM's repository cache (`~/Library/Caches/org.swift.swiftpm/repositories`), at the revision the package's `Package.resolved` pins, or else at the highest cached tag its requirement allows. A `traits:` argument isn't part of the requirement, and it stays on the path dependency that replaces the call: `traits: []` turns a package's default traits off. A dependency that isn't cached stops the run, and that includes one in a branch of the manifest that isn't taken, since remote dependencies are read from the manifest's text.
   - **A local path dependency** is exported from its checkout's HEAD (`--path-dep` gives another ref; the record notes uncommitted changes, which the export doesn't have), and its own dependencies are followed in turn. Which path dependencies a manifest takes is SwiftPM's answer, `swift package dump-package`, which evaluates the manifest and resolves nothing: the text also has the ones in branches it doesn't take, such as `SWIFTCI_USE_LOCAL_DEPS`'s `../swift-nio`, which exists beside the NIO family's clones.
   - **An identity goes to the first declaration met**, the probed package's own first, as SwiftPM gives a root's; the record's `conflicts` lists any other.
   - **A remote package keeps its own manifest**, so SwiftPM resolves that package's remote dependencies itself: swift-certificates' swift-crypto and swift-asn1, upstream swift-nio's swift-system. On macOS it does that through its repository cache, which it updates from the network; in a container, from the network. These are read-only fetches. Before probe-2 this README said nothing was fetched, which held only for the package's own dependencies.
   - All paths are relative to the scratch directory, so the same copy builds on macOS and in a container that sees only that directory.
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

8. **Output.** It writes `out/<package>/<platform>.json` with everything, `out/<package>/import-probe.json` and `out/import-probe.json` with one record per site, and `out/<package>/SUMMARY.md` for the package. A record has the package, branch, commit, platform, target, file, line, column, name, kind, defining module, class, System's answer and the diagnostic; a nested package's records also have its directory (`nested`), and their files are relative to it. The scratch directory is deleted unless `--keep`.

## Names through the package's own C modules

A C target's module re-exports the system headers it includes: SwiftPM's module map for it has `export *`, and on Linux a header the C target includes textually can even belong to its module. So a file that imports `CNIOBoringSSL` or `CAsyncHTTPClient` can use `size_t` or `strptime` without importing the C library, and the ordinary builds can't see it (eco-nio-1's F4). `--own-modules` builds each target that imports one of the package's own C modules (its `ClangTarget` and `SystemLibraryTarget` modules, configured shims aside) twice more, each target alone and restored after, as the ordinary builds are:

1. Without its imports of those modules, as well as its C imports.
2. The same, with the platform's C library (`Darwin`, `Glibc`) imported first in each of its files.

A name the first build can't find in a file, the second can, and the ordinary build could (it isn't one of the file's ordinary records) is one the file took from the C library through its own C module. It's recorded with the modules the file imported (`via`) and classified like any other. A name the second build can't find either is the C module's own, such as `CNIOBoringSSL_SSL_new`; those are counted, by file, in the JSON. Both answers are the compiler's. No list of names is consulted: BoringSSL's names come from prefix macros (`CNIOBoringSSL_SSL_new` is written in no header), and the ledger's vocabulary is Darwin's, and it calls any name it doesn't know a gap. A name the C module gets from a header the C library's module doesn't cover (a Linux kernel header's) counts as the module's own.

The results are `ownModules` in `<platform>.json` (`records`, `ownNames`, and each target's two builds) and a section of SUMMARY.md, with each file's names. `import-probe.json` keeps the ordinary records only.

## The re-export run

`--reexport` (`scripts/reexport.py`) runs instead of the per-target probes. It answers which names a package gets only through an `@_exported import` of a C module, such as NIOPosix's `@_exported @preconcurrency import Glibc` on Linux, which the ordinary builds can't remove for a dependency. In the same scratch copy:

1. **The re-exports** are found in the target directories of the package and of each package in the copy (`describe` for the probed one, `dump-package` for the others): `@_exported` on an import of a counted module, on its own line or on an attribute line above. One the platform doesn't compile (by the `#if` evaluator; a *maybe* counts) gives nothing; if none is left, nothing is built.
2. **The baseline**, the copy as it is, `--build-tests`. A re-export counts only in a module the baseline built (`<triple>/debug/Modules`), since a manifest's text names targets and packages the graph doesn't take.
3. **Demoted.** Each re-export becomes a plain import, with the line count kept. A re-export serves its whole module, so each other file of the re-exporting target gets the import first, under `#if canImport(...)`: the module builds as before, and only its clients lose the C module. Then every Swift file of every target the baseline built is touched, so each module is compiled again, all of it, the next time the build reaches it. An incremental build misses the demotion twice over. A module's compile takes only its direct dependencies' modules as inputs, and one that re-exports the demoted module comes out byte for byte the same (NIO's `@_exported import NIOPosix`), so swift-nio-imap's `CLI`, which imports `NIO`, wasn't compiled again at all. And the driver recompiles a file only for a change to a declaration it uses from another module, which a re-export isn't. The first round therefore costs about a baseline's Swift compiles.
4. **Rounds.** The copy is built again, `--build-tests`. SwiftPM stops at a failed target and builds nothing that depends on one, so each file with errors gets the same import first and the build is repeated, until a build succeeds or no file it hasn't given the import has errors (30 rounds at most). The errors in the probed package's own targets' files, less the baseline's, are the names it gets only through a re-export, read as in the per-target probe. A file given the import isn't read again: the import shifts its lines. A dependency's files that fail get the import too, uncounted (eco-nio-1's F10). That covers swift-nio's `_NIOFileSystem`, which reaches the C library through NIOPosix, and a nested package's root package, whose names are its own run's.

It writes `out/<package>/<platform>-reexport.json`: the re-exports found and demoted, the rounds, the files given the import, the records (each with its round), and the errors left in files given the import. SUMMARY.md has a section for it after the platforms' probes. The run takes the same options as the probe, `--nested`, `--package-dir` and `--path-dep` included.

On Darwin the migrated NIOPosix re-exports nothing, so a macOS run of a package built on it builds nothing. Upstream NIOPosix re-exports `Darwin.C` there, but Foundation re-exports Darwin too ([below](#known-limits)).

## Comparing runs

```sh
python3 Utilities/import-probe/scripts/compare.py --before OUT-BEFORE --after OUT-AFTER \
  [--other-before DIR --other-after DIR --label A --other-label B] [--output FILE]
```

`scripts/compare.py` reads two `--out` directories, before and after a migration. It writes eco-nio-1's table (`tools-en1/probe_counts.py`'s): a package's sites, distinct names and classes for each platform's probe and for the Linux re-export run, before and after. With `--own-modules` results it adds each file's names through the package's own C modules. Given a second pair of directories, of the same packages, it lists for each cell what differs: the sites (file, line, name) and names only one has, the names they classify differently, and the commits and System they were run at. It only reads.

## The comparison with the ledger

With a ledger.json (`STATUS_OUT=... STATUS_LEDGER_JSON=... Utilities/adopter-coverage/status.sh`, which can write both outside `Prototype/Status`), each platform's section of SUMMARY.md compares the ledger's import sites, the ones compiled on that platform, with the imports the probe removed and the names the compiler then needed. It first checks that the ledger read the same commit. It lists:

- the ledger's sites outside every target the probe builds: nested packages (each of which `--nested` compares on its own, with the ledger's sites in its directory), benchmarks, integration tests, scripts;
- sites the ledger says the platform compiles and the probe's evaluation says it doesn't, or the reverse;
- imports only one of them has;
- imports whose file built without them (removable now). An import whose target still reaches the C module through another target's `@_exported` import is listed apart, since its names may come through there;
- for each import both have, the names only the ledger gives (the compiler found them without the import, through another import, a re-export or the package's own declarations, or the lexical scan misread them), the names only the compiler needed, and names the two classify differently;
- an `@_exported` import's names in the rest of its module, which the ledger gives no site.

## Known limits

- **Foundation re-exports the C library**: Darwin on Darwin, and Glibc on Linux, where `import Foundation` alone gives `getpid`, `strerror`, `errno` and `usleep` (checked with Swift 6.2's swift-corelibs-foundation; XCTest re-exports Foundation, and Dispatch re-exports neither). A file that imports Foundation still sees every C name after its own imports go, so names it uses are invisible here, to all three passes, on both platforms. The summary counts these files; that's most test targets.
- **A package's own C targets** (CNIOLinux) have modules that re-export the system headers they include. Names a file takes through one aren't seen by the ordinary builds; `--own-modules` finds them, and the summary counts the files that import one. A *dependency's* C module (CNIOLinux to a client of swift-nio) isn't removed by either.
- **Re-exports by other targets.** When target A `@_exported import`s Glibc, a target that imports A still sees Glibc while it's probed. The summary lists those targets. The probe can't demote the re-export for the whole build, since that fails every target that relies on it and SwiftPM won't build their dependents. `--reexport` does exactly that, in rounds.
- **Only the platform built.** Code under `#if` for a platform not built isn't compiled, so it isn't seen: Windows, WASI, the BSDs and Android here. **Musl and WASI** need `Utilities/linux/cross.sh`, which builds only its own package (no `--root`/`--dir` as build.sh has), so they aren't run; that's recorded as a need.
- **Cross-file follow-ons**, such as a call whose callee's signature failed in another file (`'nil' requires a contextual type`), aren't recognized. They're listed as other errors.
- **Targets come from macOS's `describe`**, for Linux too. A manifest whose targets differ by platform would need the container's.
- **Path dependencies are SwiftPM's on macOS.** `dump-package` evaluates a manifest on the host, so a path dependency only a Linux branch of a manifest takes isn't followed for `--linux`.
- **A remote package's own remote dependencies** are SwiftPM's to resolve, and it fetches them (read-only); see step 2. Their versions are then SwiftPM's choice, not the cache's highest tag.
- MemberImportVisibility errors appear only in packages that enable it (swift-log and swift-nio do; swift-tools-support-core doesn't). Without it, a C field reached through a System type's value resolves anyway.

## Per-package settings

`packages.ini` names a package's **shims**, modules that exist to re-export the C library (TSCLibc, SWBLibc, swift-testing's `_TestingInternals`). Their imports are removed from the probed target like a C module's, and a name a shim declares itself is classed `shim's own`. A re-export that isn't a shim, such as NIOPosix's, stays (above), except in `--reexport`'s run. A note for the summary can go there too. A nested package takes its clone's section, or a section of its own, `[<package>/<directory>]`.

## Run time and disk

On an M1 Max with Swift 6.2. These are the full runs on the three packages the tool was tested on, including the export, the System build and the baseline:

| Package | macOS | Linux (container) |
|---|---|---|
| swift-log `migrate-all` | 2 s (nothing to build) | 1 s (nothing to build) |
| swift-log `main` (upstream) | 17 s | |
| swift-tools-support-core `migrate-unix` | 58 s | 53 s |
| swift-nio `migrate-unix` | 8 s (nothing to build) | 116 s, 82 of them the baseline |

swift-nio's scratch directory reaches about 1.2 GB on Linux. It's deleted when the package is done.

## Requirements

- macOS with Xcode's toolchain (`swift`), git and `python3` (the system's 3.9 works; standard library only).
- For `--linux`, Apple's `container` tool and the image `Utilities/linux/build.sh` uses, already pulled. The image isn't fetched; a remote package's own remote dependencies are (step 2).
- Read-only imports from `Utilities/adopter-coverage/scripts` (ledger, check, derive, platforms, status), `Utilities/api-delta/scripts/scan_sources.py`, and `Utilities/linux/build.sh`. Bytecode is off, so nothing is written into their directories.
- `--disable-sandbox`, as every tool here passes, since SwiftPM's manifest sandbox fails inside another sandbox. Only probe packages you trust.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'
```

`test_probe.py` covers import removal in every form, diagnostics and follow-ons, the manifests' dependencies, rewrites, version requirements (`traits:` included) and System's manifest, the ledger comparison (re-exports, reaching through one, and a nested package's directory included), the summary's sections for `--own-modules` and `--reexport`, the re-export run's demotion, and `compare.py`'s table and differences, over text fixtures. Three of its tests write files in a temporary directory, and one makes a git repository there as a stand-in for SwiftPM's cache; each deletes it.

`test_packages.py` makes fixture packages, small git repositories, in a temporary directory and deletes it after. Without building it covers path dependencies (followed transitively from their checkouts' HEAD, an inactive branch's not taken, `--path-dep`'s ref, the local packages' manifests rewritten) and nested packages (found, and prepared in place). It also checks that a remote dependency's `traits: []` survives the rewrite, using a stand-in cache. Four tests build on macOS (about 45 s): a nested package probed on its own, `--own-modules` over a C target that includes `<unistd.h>`, `--reexport` over a dependency that re-exports Darwin (three rounds), and `--reexport` of a nested package whose root package uses the re-export too (fixed up uncounted). They pass SwiftPM `--cache-path`, `--config-path`, `--security-path` and `--manifest-cache local` in the temporary directory, and point TMPDIR there. They read this worktree (System's export, modules.ini) and run `swift`, never a product they build. No fixture has a remote dependency, so nothing reaches the network. `IMPORT_PROBE_SKIP_BUILDS=1` skips the builds.

The runs on real packages are the end-to-end test: the first three tools' in `Prototype/Tooling/REPORT.md`, and probe-2's comparison with eco-nio-1's figures in `Prototype/Tooling/PROBE-2-REPORT.md`.

## Design calls

- **Commit the copy, not the clone.** The export is the only thing edited. *Rejected*: building in the clone with its imports patched and restored, which a crash would leave half-edited.
- **Path dependencies on exports** for every dependency. *Rejected*: `--skip-update` resolution from SwiftPM's cache, which works on macOS but not in a fresh container; and the clone's own `.build/checkouts`, which may not exist or match.
- **One target at a time, every file of it recompiled.** *Rejected*: all targets' imports removed at once, since SwiftPM builds no target whose dependency failed; and a plain incremental build, which on swift-nio missed the files that NIOPosix's re-export served (18 of 56 files compiled, 69 names instead of 78).
- **Skipping targets the platform doesn't compile an import of**, by adopter-coverage's evaluator. *Rejected*: building every target with a textual removal, which on a migrated branch is mostly Windows-only imports: minutes for nothing (`--no-skip` does it).
- **The ledger's classification**, not a new one, so that the comparison differs only in which names are found.
- **Path dependencies as SwiftPM evaluates the manifest** (`dump-package`), followed from their checkouts. *Rejected*: the manifest's text, which also follows the branches it doesn't take; and eco-nio-1's `--path-dep LOCATION=IDENTITY:REPO@REF` for each, which every lane would have to give again for the same graph. `--path-dep` is kept, as an override.
- **A path dependency at its checkout's HEAD**, what SwiftPM would build if the checkout is clean. *Rejected*: its newest migration branch (the probe's rule for the clone itself), which can differ from what's checked out; and the working tree, which isn't a commit.
- **A local path dependency treated like the root**: its remote dependencies exported from the cache, its manifests rewritten. *Rejected*: leaving them to SwiftPM, as eco-nio-1 did, which fetches them.
- **A nested package probed in place** in the whole branch's export. *Rejected*: exporting its directory alone (eco-nio-1's `git archive COMMIT:DIR`), whose `../..` then needs a second export of the same commit and a rewrite.
- **`traits:` kept** when a dependency is rewritten. *Rejected*: dropping it (eco-nio-1's fix of F8), which turns a package's default traits back on. async-http-client's `traits: []` on swift-configuration is there to keep Foundation out.
- **The re-export run demotes every re-export of a counted module** in the copy, the package's own included, in the modules the baseline built. *Rejected*: NIOPosix's alone, by name (eco-nio-1's); and every file's text, which demoted System's `Prototype/Win32` model files.
- **The re-export run touches every built target's Swift files** after demoting, at the cost of compiling them all again. *Rejected*, each tried: `-Xswiftc -disable-incremental-imports`, after which the driver still judged a client up to date; and deleting each module's `master.priors`, which recompiles a module llbuild reruns but not one whose direct dependencies' modules didn't change (`CLI`, through NIO's re-export). Also rejected: touching only the dependents of the demoted modules, from SwiftPM's build plan (`debug.yaml`), which would save the compiles the re-export doesn't reach but read a file SwiftPM doesn't document; and no baseline, eco-nio-1's way, which avoids the problem by building from clean but would count a package's own errors.
- **The re-export run's import given per failing file, after a baseline.** *Rejected*: per failing target (eco-nio-1's), which edits more files for the same rounds; and no baseline, which would count a package's own build errors as re-export names.
- **`--own-modules` asks the compiler twice**, without the C module and then with the C library instead. *Rejected*: reading the C module's headers for its own names, which misses BoringSSL's macro-made ones; and the ledger's vocabulary, which is Darwin's. It's an option, not the default, since it adds two builds for each target that imports a C module of its own: on swift-nio, NIOPosix and the rest of CNIOLinux's importers.
- **`--reexport` a run of its own**, as eco-nio-1's was, with its own JSON beside the probe's and its own section of SUMMARY.md. *Rejected*: a pass after the per-target probes in one run, which would share the export and the baseline but need the build directory put back between them.

## Next

- An offline graph: a remote package's own remote dependencies exported from the cache too, by `dump-package`'s active dependencies and versions that meet every requirement in the graph, so that SwiftPM fetches nothing.
- A dependency's C modules (CNIOLinux, CNIOBoringSSL to swift-nio-ssl's clients), as `--own-modules` does the package's own.
- Musl and WASI, once `cross.sh` takes `--root` and `--dir` as build.sh does.
- A Foundation-free view on Darwin: in files that import Foundation, also remove Foundation and keep only the names that don't belong to it.
- The container's own `swift package describe`, for manifests whose targets differ on Linux.
- Run every adopter in `../adopters` on both platforms and file the results by commit, as adopter-coverage's results store does.
