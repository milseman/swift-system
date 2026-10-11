# probe-2: what eco-nio-1 added around import-probe, in the tool

Lane `probe-2`, branch `probe-2` from system-next `32208c4` (2026-10-10). eco-nio-1 had to wrap `Utilities/import-probe` (`../adopters/tools-en1/probe_en1.py`) to probe the NIO family: path dependencies, nested packages, `traits:` requirements, and a run that demotes NIOPosix's re-export of the C library. Its F4 named a blind spot the wrapper didn't address: names a file reaches through a C module of its own package. This lane moves all of that into the tool, so the next adopter lanes don't each rebuild it. The tool's options, method, limits and design calls are in `Utilities/import-probe/README.md`; this report gives what isn't there.

## Resume here

- **Done.** All four items are in the tool (section 1), with 31 tests, all passing, up from 17 (section 3). The comparison with eco-nio-1's figures is complete (section 4): every cell of swift-nio-ssl and swift-nio-extras is the same, before and after, on macOS and Linux and in the re-export runs, by site, name and class. So are swift-nio-imap's `CLI` and `Proxy` under `--reexport`, F10's nested case.
- **Committed** on `probe-2`: `66a2e52`, `531063c`, and this report's commit. system-next hasn't moved from `32208c4`, so there was nothing to merge.
- **Deleted**: this lane's runs, logs and outputs (`.build/probe-2`); the figures below are copied from them.
- **Open**: the needs outside this lane's files (section 6) and Next (section 7).

## 1. What

| Item | Where | How |
|---|---|---|
| 1. Path dependencies, nested packages | `scripts/probe.py` (`prepare`, `nested_packages`, `package_dirs`), `scripts/manifests.py` (`active_dependencies`) | The local packages are the probed one, the packages of its branch it takes by path, and its local path dependencies, transitively. Each has its remote dependencies exported from SwiftPM's cache, its path dependencies followed as `swift package dump-package` evaluates its manifest, and its manifests rewritten to point at the exports. An outside path dependency is exported from its checkout's HEAD, or at the ref `--path-dep IDENTITY=[REPO@]REF` gives. `--nested` probes each directory of the branch with a `Package.swift` of its own, and `--package-dir` chosen ones. Each is probed in place in the branch's export and reported in `out/<package>-<dir>`, and its ledger comparison takes the ledger's sites in its directory. |
| 2. `traits:` (F8) | `scripts/manifests.py` (`arguments`, `dependencies`, `allowed`, `rewrite`) | A call's arguments are split at the top level, leaving strings, brackets and comments whole. `traits:` isn't part of the requirement, and it stays on the path dependency that replaces the call. |
| 3. The re-export run (F10) | `scripts/reexport.py`, `--reexport` | First a baseline build. Then every `@_exported import` of a counted module in a target the baseline built is demoted, in the package and every package in the copy. The re-exporting target's other files get the import, and every built target's Swift files are touched. Rounds follow: in each, every failing file gets the import. The probed package's errors, less the baseline's, are the names. A dependency's failing files are fixed up uncounted: swift-nio's `_NIOFileSystem`, or a nested package's root package. Everything happens in the scratch copy under the tool's work directory. |
| 4. Names through the package's own C modules (F4) | `scripts/probe.py` (`own_pass`), `--own-modules` | Each target that imports one of its package's own C modules is built twice more. The first build drops those imports as well as the C imports. The second also imports the platform's C library first in each file. A name the first can't find, the second can, and the ordinary build could is one the file took from the C library through its own C module. The compiler answers both questions; no list of names is consulted (section 2). |
| Comparison tables | `scripts/compare.py` | eco-nio-1's `probe_counts.py` table, from any two output directories. Given a second pair, it lists every difference by site, name and class. |

The interface is unchanged, and every new behavior is an option, with two exceptions where the old behavior was wrong:

- **"Nothing is fetched"** (README step 2, `probe.sh`) held only for the package's own dependencies (P1). The README now says so.
- **A manifest with a local path dependency stopped at `describe`.** It's now followed. One in a branch the manifest doesn't take is still harmless, since SwiftPM's evaluation decides.

## 2. Design calls, with the alternatives rejected

The README's design calls cover each item's choices. In short, and what isn't there:

- **Path dependencies as SwiftPM evaluates the manifest.** *Rejected*: the manifest's text. The NIO family's `SWIFTCI_USE_LOCAL_DEPS` branch names `../swift-nio`, which exists beside the clones in `../adopters`, so a text reader would export the upstream checkout as `swift-nio`. *Rejected*: eco-nio-1's explicit `--path-dep LOCATION=IDENTITY:REPO@REF` for each dependency. It's kept as an override, simplified to `IDENTITY=[REPO@]REF`.
- **A path dependency at its checkout's HEAD** (open question). That's what SwiftPM builds if the checkout is clean; the record notes uncommitted changes, which the export doesn't have. *Alternatives*: the newest migration branch, the probe's rule for the clone itself; and the working tree, which isn't a commit. For eco-nio-1's checkouts they agree, since every one has its migration branch checked out.
- **A local path dependency treated like the root.** Its remote dependencies come from the cache, so migrate-unix swift-nio's swift-atomics and swift-collections are exported, not fetched. *Rejected*: leaving them to SwiftPM (eco-nio-1's). A remote package's own remote dependencies are still SwiftPM's to fetch (P1); closing the graph is in Next.
- **An identity goes to the first declaration met**, the probed package's own first, as SwiftPM gives a root's; the record lists the others as `conflicts`. On swift-nio-ssl's `Benchmarks`, that gives `swift-nio` to its URL dependency over the root package's path to the migrated worktree (P5), which is what SwiftPM does with that package as root. *Rejected*: preferring a path dependency to a URL one, which would probe a graph SwiftPM doesn't build.
- **A nested package in place** in the branch's export, its `../..` left as it is, and its output in `<package>-<dir>` with each `/` as `-`. eco-nio-1 named its links by the last component (`swift-nio-imap-IMAPTool`); the full path can't collide. *Rejected*: exporting the directory alone (eco-nio-1's `git archive COMMIT:DIR`), which then needs a second export of the same commit and a rewrite.
- **`traits:` kept on the rewrite.** *Rejected*: dropping it (eco-nio-1's fix for F8), which turns default traits back on. async-http-client's `traits: []` on swift-configuration is there "to prevent linking Foundation".
- **The re-export run demotes every re-export of a counted module**, the package's own included, in targets the baseline built. *Rejected*: NIOPosix's by name (eco-nio-1's). *Rejected*: every Swift file's text, which on the first try demoted `deps/swift-system/Prototype/Win32/WindowsModel/WinSDK.swift`, a model no target builds (P6).
- **The re-export run's baseline, and then every built target's Swift files touched** (P8). *Rejected*: no baseline (eco-nio-1's), which counts a package's own build errors as re-export names, though it sidesteps P8 by building from clean. *Rejected*, each tried: `-Xswiftc -disable-incremental-imports`, and deleting each module's `master.priors`. Neither recompiles a client that reaches the demoted module through another module's re-export. *Alternative*: touching only the demoted modules' dependents, from SwiftPM's undocumented `debug.yaml`, which saves compiles of modules the re-export doesn't reach.
- **The re-export run's fix-up per failing file.** *Rejected*: per failing target (eco-nio-1's), which edits more files for the same rounds.
- **`--own-modules` asks the compiler twice.** *Rejected*: reading the C module's headers for its own names. BoringSSL's names come from prefix macros: `CNIOBoringSSL_SSL_new` is written in no header. *Rejected*: the ledger's vocabulary, which is Darwin's and calls any unknown name a gap. A name the module gets from a header the C library's module doesn't cover counts as the module's own, which errs toward fewer names (zlib's, for `CNIOExtrasZlib`).
- **`--own-modules` is an option** (open question). It adds two builds of each target that imports a C module of its own: 2 to 30 s a build on swift-nio-ssl, more on swift-nio, where NIOPosix and the rest import CNIOLinux. The alternative is on by default, which would retire the summary's "names these files take through it aren't seen" line.
- **`--reexport` is a run of its own**, as eco-nio-1's was, with `<platform>-reexport.json` beside the probe's JSON and its own section of SUMMARY.md. *Rejected*: one run doing both passes, which shares the export and baseline but needs the build directory put back between them.
- **Test fixtures stay in their temporary directory.** They pass SwiftPM `--cache-path`, `--config-path`, `--security-path` and `--manifest-cache local` (a test-only `args.swiftpm`) and set TMPDIR. *Rejected*: SwiftPM's defaults, which write its shared manifest cache in `~/Library/Caches`.

## 3. Tests

Before: 17 tests in `test_probe.py`, all passing (0.4 s). After: 31, all passing, clean under `-W error::ResourceWarning`. They took 60 to 100 s here, most of it four macOS builds:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'
```

No existing test was changed. These were added; what each can touch was checked before it ran:

| Test | Item | What it can touch |
|---|---|---|
| `ManifestTests.test_traits_are_not_the_requirement`, `test_arguments` | 2 | Nothing: text. |
| `LedgerComparisonTests.test_a_nested_package_takes_its_directorys_sites` | 1 | Nothing: dictionaries. |
| `SummaryTests.test_sections` | 3, 4 | Writes two JSON files, SUMMARY.md and import-probe.json in its own `mkdtemp` directory, then deletes the directory. |
| `CompareTests.test_table_and_differences` | compare.py | Writes JSON files and the table in its own `mkdtemp` directory, then deletes it. Sets `sys.argv` and restores it; captures stdout. |
| `ReexportTextTests.test_find_demote_and_fix_up` | 3 | Writes and edits one Swift file in its own `mkdtemp` directory, then deletes it. |
| `test_packages.PathDependencyTests` (4) | 1, 2 | Makes git repositories in its own `mkdtemp` directory, with no global or system git configuration (so no hooks, signing or credential helpers), `--no-verify` and `--no-gpg-sign`. Exports them, and this worktree's HEAD as System, into a scratch directory there. Runs `swift package dump-package` with SwiftPM's caches and TMPDIR in that directory, and reads git status. One test sets an environment variable of its own, restored in tearDown. A stand-in for SwiftPM's repository cache is a repository there, so its `https://example.invalid/...` URL is never fetched. Deletes the directory. |
| `test_packages.BuildTests` (4, macOS) | 1, 3, 4 | The same, plus `swift package describe` and `swift build` of the fixture packages there. It compiles C and Swift the test wrote, and never runs a product. The probe's own cleanup deletes only its marked work directory there. |

No test signals a process, changes a permission or reaches the network, loopback included. Nothing is written outside each test's temporary directory. After the new tests' first run, nothing under `~/Library/Caches/org.swift.swiftpm`, `~/Library/org.swift.swiftpm` or `~/.swiftpm` had changed in the minutes before (checked with `find -newermt`). `BuildTests.test_reexport_run_of_a_nested_package` fails with `reexport.touch_sources` disabled (checked), so it guards P8's fix.

## 4. The comparison with eco-nio-1's figures

Inputs, against eco-nio-1's (`logs-en1/probe-{before,after}`, their JSON `meta`):

- **Commits.** Before: `main` (swift-nio-ssl `2232048`, swift-nio-extras `4eaac9f`, swift-nio-imap `14ad388`), as theirs. After: the `migrate-all` heads (`d2683eb`, `b164c02`, `2c5a594`), where eco-nio-1 probed the code commits (`0fbefac`, `69587b5`, `92f67c3`). Each head adds only MIGRATION.md.
- **System**: system-next `32208c4`, against their `5d0b151`. The 15 commits between them change Package.swift (SystemWinSocks on every host), SystemSockets' poll and Windows code, and mapping.ini's Windows socket rows.
- **Dependencies**, now the probe's own choice. Before: the same revisions as theirs, every one (swift-nio 2.104.0, swift-nio-ssl 2.37.5, and the rest). After: swift-nio is `../../adopters-unix/swift-nio` at HEAD, `b2f3c6c9` (migrate-unix), the commit eco-nio-1 named with `--path-dep`. For swift-nio-extras, swift-nio-ssl is at `d2683eb`, as theirs was, and swift-nio-http2 at `fb6910a` against their `9988a49`. Between those two, only swift-nio-http2's tests, executables and a test target's System dependency changed, not the NIOHTTP2 library extras builds. The migrated swift-nio's own remote dependencies come from the cache now: swift-atomics 1.3.1 and swift-collections 1.7.2. eco-nio-1 left those to SwiftPM, so its record has no versions for them.

The figures (`scripts/compare.py`; sites (distinct names): classes):

| Package | | macOS before | macOS after | Linux before | Linux after | Re-export before | Re-export after |
|---|---|---|---|---|---|---|---|
| swift-nio-ssl | probe-2 | 32 (22): 30 covered, 2 standard library | 0 | 56 (33): 51 covered, 5 standard library | 0 | 6 (4): 6 covered | 0 |
| | eco-nio-1 | the same | the same | the same | the same | the same | the same |
| swift-nio-extras | probe-2 | 6 (4): 6 covered | 2 (2): 2 covered | 22 (9): 22 covered | 14 (7): 14 covered | 15 (9): 15 covered | 0 |
| | eco-nio-1 | the same | the same | the same | the same | the same | the same |
| swift-nio-imap `Examples/CLI` | probe-2 | | | | | 3 (1): 3 covered | 0 |
| | eco-nio-1 | | | | | the same | the same |
| swift-nio-imap `Examples/Proxy` | probe-2 | | | | | 5 (3): 5 covered | 0 |
| | eco-nio-1 | | | | | the same | the same |
| swift-nio-ssl `Benchmarks` | probe-2 | 0 | 0 | 0 | 0 | | |
| | eco-nio-1 | no run | | | | | |

"The same" is `compare.py`'s comparison: the same sites (file, line, name, counted), the same names, and each name in the same class. swift-nio-imap's two were compared the same way, from the JSON, since eco-nio-1 named their outputs differently. So the differences to explain are only these:

- **The commits, System and the after runs' dependencies change nothing in these cells.** The `migrate-all` heads add only MIGRATION.md to the probed commits. System's changes since `5d0b151` touch no name these packages use: there's no `poll`, and no Windows code is built here. swift-nio-http2's change is in code extras doesn't build, and swift-atomics' and swift-collections' versions don't bear on the C library.
- **The re-export runs' mechanics**, which reach the same names:
  - Demotion: eco-nio-1 demoted NIOPosix by name and fixed whole targets up, from a clean build. This tool demotes what it finds in the modules the baseline built, fixes up files, and recompiles every target after demoting (P8). Only NIOPosix's Glibc re-export is demoted: `System.swift:28` before, `:75` after. Five more that Linux doesn't compile are listed but left alone.
  - Rounds: the same as eco-nio-1's. swift-nio-ssl `main`: 2, NIOTLSServer's 6 names. swift-nio-extras `main`: 4, one demo target a round (2, 2, 11). swift-nio-imap `CLI` and `Proxy` `main`: 3, the first fixing the root package's NIOIMAP file uncounted, the second finding the 3 and 5 names. Every after run: 1, clean.
  - Before the P8 fix, one swift-nio-extras run reached the same 15 names in 3 rounds, two demos failing at once. swift-nio-imap's `CLI` and `Proxy` came out at 0 then, which is how P8 was found.
- **swift-nio-ssl's `Benchmarks`** is a nested package eco-nio-1 didn't run. Its one target has no C import at either commit, so it has no names. Its graph takes upstream swift-nio (P5).
- **New: `--own-modules`**, which eco-nio-1 couldn't run (its F4). The table gives sites (distinct names) found through the package's own C modules:

| Package | Run | Sites (names) | Files (`Sources/NIOSSL/`) and names |
|---|---|---|---|
| swift-nio-ssl | macOS before | 33 (20) | `ByteBufferBIO.swift`, `SSLCallbacks.swift`: `strlen`. `CustomPrivateKey.swift`: `size_t`. `SSLCertificate.swift`: `fclose`, `time_t` ×3. `SSLContext.swift`: `DIR`, `S_IFDIR`, `S_IFLNK`, `S_IFMT`, `closedir`, `dirent`, `memcpy` ×3, `opendir`, `readdir`, `stat` ×2. `SSLPKCS12Bundle.swift`: `fclose`. `SubjectAlternativeName.swift`: `AF_INET`, `AF_INET6`, `in6_addr`, `in_addr`, `inet_ntop`, `socklen_t` |
| | macOS after | 1 (1) | `CustomPrivateKey.swift:246`: `size_t` |
| | Linux before | 6 (3) | `CustomPrivateKey.swift`: `size_t`. `SSLCertificate.swift`: `fclose`, `time_t`. `SSLPKCS12Bundle.swift`: `fclose` |
| | Linux after | 1 (1) | `CustomPrivateKey.swift:246`: `size_t` |
| swift-nio-extras | each run | 0 | `CNIOExtrasZlib` gives NIOHTTPCompression and its tests only zlib's own names (20 and 24) |
| swift-nio-ssl `Benchmarks` | each run | 0 | No C module of its own |

NIOSSLTests import `CNIOBoringSSL` too, but also Foundation, which re-exports the C library on both platforms (P2), so nothing in them can be seen. The macOS row explains a difference within eco-nio-1's own figures (P3).

## 5. Findings

- **P1. The probe's runs fetch, read-only.** A remote package keeps its manifest, so SwiftPM resolves that package's remote dependencies itself: swift-certificates' swift-crypto and swift-asn1, upstream swift-nio's swift-system. On macOS it goes through `~/Library/Caches/org.swift.swiftpm/repositories` and updates it from GitHub: the cached clones' FETCH_HEAD was rewritten today from `https://github.com/apple/swift-asn1`. In a container it fetches from the network. The README said nothing was fetched. The fetches are read-only, as the standing rules allow, but they leave those versions to SwiftPM's resolution of the day. The README now says so, and an offline graph is in Next.
- **P2. Foundation re-exports Glibc on Linux, not just Darwin on Darwin.** In Swift 6.2's image, a file with only `import Foundation` compiles `getpid()`, `strerror(errno)` and `usleep(1)`. `import XCTest` does too, and `import Dispatch` doesn't. The README said a Linux file sees "a name Foundation's own imports make visible". It sees the whole C library, so the Foundation limit is as wide on Linux, for all three passes. That's why swift-nio-ssl's test names (`unlink` ×17 and the rest, eco-nio-1's section 7) are invisible to every pass: the files import Foundation.
- **P3. On macOS, `CNIOBoringSSL` hid 11 of swift-nio-ssl's names.** eco-nio-1's before figures were 22 distinct names on macOS and 33 on Linux. The 11 only Linux's probe found (`S_IFMT`, `S_IFDIR`, `S_IFLNK`, `opendir`, `readdir`, `closedir`, `dirent`, `memcpy`, `strlen`, `inet_ntop` and `socklen_t`) reach the same files on macOS through `CNIOBoringSSL`'s module, whose headers include Darwin's. `--own-modules` finds every one of them there, with `DIR` and `time_t` besides. On Linux the module doesn't give them, so the ordinary probe saw them. Linux's own-module names are `size_t`, `fclose` and `time_t`.
- **P4. A name is left after migration that no tool saw.** At `migrate-all`, `size_t` at `Sources/NIOSSL/CustomPrivateKey.swift:246` reaches the C library only through `CNIOBoringSSL`, on both platforms. Its class is standard library, Swift's `Int`. By the compiler's account it's the one C name left in NIOSSL; whether to change it is the swift-nio-ssl lane's call.
- **P5. swift-nio-ssl's `Benchmarks` builds against upstream swift-nio.** Its manifest takes `swift-nio` by URL (`from: "2.54.0"`) and the root package by `../`. As the root, its URL declaration wins the identity over the root package's path to the migrated worktree, as SwiftPM gives a root's; the record lists the conflict. The migration didn't touch this package. It has no C import, so its probe finds no names either way.
- **P6. A text scan for re-exports finds files no target builds.** The first re-export run demoted System's `Prototype/Win32/WindowsModel/WinSDK.swift` re-exports (`@_exported import WinSDK` and `ucrt`, under no `#if`). That was harmless but reported wrongly. Fixed before the comparison: the scan now reads target directories only, and counts only modules the baseline built.
- **P7. Disk.** Other work took free space from 46 GiB at the start to 13 GiB at 13:25. The probe's own `--min-free-gb 15` refused four runs; this lane held 38 MB then. They ran after it recovered (eco-nio-1's F11 again). The machine's load average was 145 to 209 for the afternoon's runs, so their times are slow.
- **P8. An incremental build misses a demoted re-export, twice over.** After the baseline, the first round is an incremental build. SwiftPM gives a module's compile only its direct dependencies' modules as inputs. A module that re-exports the demoted one, as NIO's `@_exported import NIOPosix` does, comes out byte for byte the same, and the frontend leaves its file and mtime alone. So llbuild never reran swift-nio-imap's `CLI`, which imports `NIO`. And for a client llbuild does rerun, the driver recompiles a file only for a change to a declaration it uses from another module, which a re-export isn't. swift-nio-imap's `CLI` and `Proxy` came out at 0 names where eco-nio-1, building from clean, had 3 and 5. Fixed in `531063c`: every built target's Swift files are touched after demoting. swift-nio-ssl's and swift-nio-extras' figures were the same before and after the fix, since their failing targets import NIOPosix directly. It's the blind spot the per-target probe already works around by touching every file of the target it builds (the README's design calls: on swift-nio, 69 names instead of 78 without it).

## 6. Needs outside this lane's files

- **`Utilities/README.md`** (the utilities lane's index) has no row for import-probe or tooling-1's other tools. A suggested row for `import-probe/probe.sh`: "What does a package still take from the C library, by the compiler's account? Before and after a migration; `--nested`, `--own-modules`, `--reexport`."
- **CLAUDE.md**'s Commands could list `Utilities/import-probe/probe.sh` and its new options, as it lists adopter-coverage's tools.
- **`../adopters/tools-en1/`** (eco-nio-1's): `probe_en1.py`, `probe.sh` and `reexport-queue.sh` are superseded by the tool's `--path-dep`, `--nested`/`--package-dir` and `--reexport`, and `probe_counts.py` by `scripts/compare.py`. Whether to retire them is that lane's call. `reexport-queue.sh`'s loop is now `--reexport --nested`, or `--package-dir .,Examples/CLI,...`.
- **swift-nio-ssl** (eco-nio-1's clone): `size_t` at `CustomPrivateKey.swift:246` (P4).

## 7. Next

- **An offline graph**: a remote package's own remote dependencies exported from the cache too (P1). That needs `dump-package`'s active dependencies for each remote package, and versions that meet every requirement in the graph, since path dependencies carry none.
- **A dependency's C modules** (CNIOLinux to a client of swift-nio, CNIOBoringSSL to swift-nio-ssl's), as `--own-modules` does the package's own.
- **A Foundation-free view on both platforms** now (P2): in files that import Foundation, remove it too, and keep the names Foundation itself doesn't declare.
- **The NIO family's other packages, with the tool alone**, against eco-nio-1's other rows. This lane ran swift-nio-imap's two re-export cases only.
- The README's other Next items stand: Musl and WASI through `cross.sh`, and the container's own `describe`.
