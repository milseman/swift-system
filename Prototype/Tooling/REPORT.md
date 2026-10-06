# tooling-1: lanes, lint and import-probe

Lane `tooling-1`, branch `tooling-1` from system-next `0e339dc` (2026-10-06). Three deterministic tools that need no network and no quota, moving bookkeeping that LLM sessions did by hand: `Utilities/lanes/lanes.sh`, `Utilities/lint/lint.sh` and `Utilities/import-probe/probe.sh`. Each has a README with its options, method, design calls, tests and next steps. This report gives what isn't there: the probe against the ledger (section 4), what the tools found (section 5), and the needs outside the lane's files (section 6).

## Resume here

- **Done**, all committed on `tooling-1`, with every test passing (section 3). system-next hasn't moved since `0e339dc`, so there was nothing to merge.
- The import-probe ran on swift-log, swift-tools-support-core and swift-nio, macOS and Linux, and on swift-log's upstream `main` on macOS. The summaries are in section 4. The runs' scratch directories are deleted; their outputs are in `.build/import-probe/out` and `out-main` in this worktree (not committed).
- Open for Michael: the questions in section 7. Nothing was pushed, and nothing outside the lane's files was edited. Prototype/Status wasn't touched: status.sh ran with `STATUS_OUT` and `STATUS_LEDGER_JSON` in `.build/tooling`.

## 1. What

| Tool | What it answers | Commits |
|---|---|---|
| `Utilities/lanes/lanes.sh` | The state of every lane, read-only: swift-system's and the examples' worktrees, the adopter clones and worktrees, and the two adopter workspaces. For each: its branch, head, ahead/behind, uncommitted files, a merge in progress, a trial merge's conflicts, its newest report and its "Resume here" line, its newest Linux log's totals, its Claude Code session, and free disk. Markdown or `--json`. | `bf598d4` |
| `Utilities/lint/lint.sh [check...]` | Convention checks, each separate: `cmake`, `api`, `markers`, `conditionals`, `pitches`. 19 rules, each with a fixture test. Findings print as `file:line: rule: message`; an error-level finding exits non-zero. `allowlist.ini` exempts api findings, with reasons. | `62a4ef7`, `679946f`, `e0a10be` |
| `Utilities/import-probe/probe.sh` | The compiler's list of what an adopter still takes from C. It exports the branch, removes one target's C imports at a time, builds the target, reads the diagnostics and classifies each name against System. On macOS, or `--linux` through `Utilities/linux/build.sh`. Each run is compared with the ledger. | `1171398`, `872bad4` |

## 2. Design calls

Each README's "Design calls" section has the full list, each with the alternative it rejected. The ones that shaped the tools:

- **lanes: discovered, not configured.** Lanes come from `git worktree list` and the adopter directories, so the list can't go stale: `examples-info`'s worktree was removed while the tool was being written. *Rejected*: a lane list in a file.
- **lanes: owned reports by the branch's diff** since its merge base. *Rejected*: the newest report anywhere in the worktree. Every worktree has every lane's merged reports, so the newest would be whichever a checkout touched last.
- **lanes: trial merges into a scratch object directory** (`GIT_OBJECT_DIRECTORY` plus alternates). *Rejected*: plain `git merge-tree --write-tree`, which leaves loose objects in the repository; and its old trivial-merge mode, which misses renames.
- **lanes: paths that moved.** A recorded path that doesn't exist is found under the root by its longest existing suffix, and git then runs with `--git-dir` and `--work-tree`. A tested move of the whole folder reads the same as in place; sessions still resolve from the recorded root.
- **lint api: api-delta's output, not source text.** The added set and the effective availability come from the symbol graphs; source text only gives what the graphs can't (attributes, bodies, the docs of declarations other platforms compile). *Rejected*: a scan of the source alone, which can't tell new from old.
- **lint api: "wraps C" by System's conventions** (`system_*`, `Constants*.swift`, `extension CInterop.X`), followed through one uniquely named `_helper`. *Rejected*: following every `_` name transitively. On this tree that gave 97 warnings, most of them wrong, because overloaded helpers lead anywhere. Also rejected: api-graph's code links, which need an indexed build of minutes; its `DOC-SENTENCES.md` stays the fuller list.
- **lint markers: three rules.** The spelling (`markers/format`) is an error. One interface per marker (`markers/one-interface`) is a warning, because no adopter marker meets it today. Stale (`markers/stale`) is a warning, and notes when the marker names System API it can't judge.
- **probe: path dependencies on exports** for every dependency: System at a commit, remote packages from SwiftPM's cache. *Rejected*: `--skip-update` resolution, which needs the host's cache and fails in a fresh container.
- **probe: one target at a time, every file recompiled.** *Rejected*: everything at once, since SwiftPM builds no target whose dependency failed; and a plain incremental build, which on swift-nio compiled 18 of NIOPosix's 56 files, missing what its `@_exported import Glibc` served (69 names instead of 78).
- **probe: the ledger's classification** (`ledger.Coverage`), so the comparison differs only in which names are found. *Rejected*: a classification of its own.
- **probe: re-exports left in place** and reported, for a library that also re-exports C (NIOPosix). *Rejected*: demoting `@_exported` for the whole build, which fails every dependent target that relies on it.

## 3. Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lanes/scripts -p 'test_*.py'          # 9
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lint/scripts -p 'test_*.py'           # 15
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'   # 17
```

All 41 pass at the lane's last commit. Each tool's tests ran before and after each of its later commits, and none failed after a commit. Every test was checked for what it can write, delete or reach. Each writes only in its own `tempfile.mkdtemp` directory and deletes it. The git fixtures run with no global or system configuration, so no hooks, signing or credential helpers. Nothing signals a process, changes permissions or uses the network. The one test that moves a directory (lanes' "mounted elsewhere") moves its own fixture folder within its temporary directory.

The end-to-end tests are real runs: lanes on this machine's 45 lanes, lint on HEAD and the 23 clones in `../adopters`, and the probe on the three packages below. None of them writes outside `.build` in this worktree. The probe only ever edits its scratch copy.

## 4. The probe against the ledger

Each package was probed by the tool at `e0a10be`, at the commit the ledger read (status.sh's section 5 at this worktree's HEAD, its JSON in `.build/tooling/ledger.json`), against System at `0e339dc`. The full summaries are `.build/import-probe/out/<package>/SUMMARY.md`; what follows is each one's substance.

### swift-log, `migrate-all` @ `7e49107b`

- **macOS** and **Linux**: no target has a C import either platform compiles. Of the 5 Swift targets, 2 import only Windows' (CRT, ucrt, WinSDK) and WASI's modules, and 3 import none, so nothing was built. The ledger has no site on either platform. They agree.
- Its 8 ledger sites are all on Windows (7) and WASI (1). The probe can't see those platforms (section 6, need 1).
- **Upstream `main` @ `9c9acde6`, macOS** (a check that the macOS path finds names): `Logging` built without its 3 Darwin imports, and the compiler couldn't find 25 names at 29 sites, every one covered by System. They're `fflush`, `flockfile`, `funlockfile`, `fwrite`, `stdout` and `stderr` (FileStream), the pthread mutex and rwlock calls and types (PThread.Mutex, PThread.ReadWriteLock), `localtime`, `strftime` and `time` (BrokenDownTime, clock_gettime). That's the work the migration did. `LoggingTests` built without its imports, but its 5 files import Foundation, which re-exports Darwin.

### swift-tools-support-core, `migrate-unix` @ `5f85e38e`

- **macOS** and **Linux**: 5 targets were built without their 19 `import TSCLibc` lines (TSCLibc is a configured shim). The compiler needed nothing from them, on either platform: TSCLibc re-exports CRT and WinSDK only on Windows. No other C import compiles on either platform.
- **Against the ledger**: the ledger has no site on either platform. It counts a shim's re-export, not the imports of the shim, so the 19 imports have no site there. The probe adds that they serve nothing off Windows.
- Not seen: 40 files in 5 targets import Foundation, and 4 import the package's C target `TSCclibc`.

### swift-nio, `migrate-unix` @ `6f4e78e4`

- **macOS**: no target has a C import Darwin compiles (15 targets import only other platforms' modules, 36 none). The ledger has no Darwin site. They agree.
- **Linux**: 3 targets built without their C imports: NIOCore, NIOPosix and NIOFSTests. The baseline build of the unmodified copy took 82 s, the whole run 116 s. The compiler couldn't find 15 names at 79 sites. 14 names, 65 sites, are covered by System: `socklen_t`, `sockaddr`, `sockaddr_in`, `sockaddr_in6`, `sockaddr_storage`, `msghdr`, `cmsghdr`, `off_t`, `timespec`, `itimerspec`, `pollfd`, `nfds_t`, `IP_TOS`, `TCP_INFO`. `size_t` (14 sites) is the standard library's answer. 8 errors were follow-ons. The 4 others are all `'nil' requires a contextual type`, at calls whose callee's signature failed in another file.
- **Against the ledger** (Linux): the ledger has 7 import sites and 5 marker sites compiled there. The probe removed 4 imports, all of them the ledger's:

  | Site | The ledger | The compiler | |
  |---|---|---|---|
  | `Sources/NIOPosix/System.swift:75` `@_exported @preconcurrency import Glibc` | no names on Linux in its own file | 14 names at 78 sites in 7 other NIOPosix files (`BSDSocketAPICommon.swift`, `ControlMessage.swift`, `Pool.swift`, `VsockAddress.swift`, `Linux.swift`, `SocketProtocols.swift`, `PipePair.swift`) | A re-export serves its whole module. None of those files imports Glibc itself, and the ledger gives them no site. It also serves the 40 targets that depend on NIOPosix. Every name but `size_t` is covered by System. |
  | `Tests/NIOFSTests/FileInfoTests.swift:27` `import Glibc` | 14 names: `S_IFREG` and the `stat` fields | none: the target built without it | NIOFSTests sees Glibc through NIOPosix's re-export, so the import is redundant now. The ledger's names for it are really served by the re-export. |
  | `Sources/NIOCore/SocketOptionProvider.swift:22` `@preconcurrency import Glibc` | no names, unexplained | none: built without it | Compiled only on Linux (the ledger agrees), so it can go now. |
  | `Sources/NIOCore/BSDSocketAPI.swift:74` `@preconcurrency import Glibc` | `TCP_INFO` | `TCP_INFO` (line 576) | Agree. System covers it (`SocketDescriptor.TCPOption.info`): adopter work. |

  The ledger's other 3 Linux sites are outside every target the probe builds: `Benchmarks/` (a nested package), `IntegrationTests/allocation-counter-tests-framework/template/scaffolding.swift`, and `dev/stackdiff` (a nested package). Its 5 marker sites aren't compared.
- Not seen: 30 files importing Foundation, and 63 files importing the package's C targets (CNIOLinux and the rest), whose modules re-export the glibc headers they include.

### Where they disagree, in short

1. **Module-wide re-exports.** An `@_exported import` in one file serves every file of its module, which the ledger's per-file reading can't see: NIOPosix's System.swift serves 78 sites in 7 other files.
2. **Re-exports through dependencies.** A target that imports a re-exporting module doesn't need its own C import, so the ledger's names for that import are really served elsewhere: NIOFSTests' 14.
3. **Imports that serve nothing**, which the ledger lists as unexplained sites with no names: NIOCore's SocketOptionProvider.swift:22 on Linux. The probe confirms they can go.
4. **Shim imports**, which the ledger doesn't count: TSC's 19 imports of TSCLibc serve nothing off Windows.
5. **Outside the targets**: nested packages and scaffolding, which the ledger reads and the probe doesn't build.

Where both read the same import, the names agree (`TCP_INFO`), and the classes agree by construction: both use `ledger.Coverage`.

## 5. Findings

### From the probe

- **F1. `@_exported import` serves its whole module.** Removing NIOPosix's re-export broke 7 files that never import Glibc. The ledger (status.sh's section 5) attributes an import's names to its own file only (section 4, row 1).
- **F2. An incremental build misses that.** After System.swift's import changed, SwiftPM recompiled 18 of NIOPosix's 56 files, and the probe found 69 names instead of 78. The probe now touches every file of the target it builds.
- **F3. swift-nio's `Sources/NIOCore/SocketOptionProvider.swift:22`** (`@preconcurrency import Glibc`, compiled only on Linux) serves nothing on Linux.
- **F4. swift-nio's `Tests/NIOFSTests/FileInfoTests.swift:27`** builds without its `import Glibc` only because of NIOPosix's re-export. If the re-export goes, its 14 C names need System's `Stat` instead.
- **F5. swift-tools-support-core's 19 `import TSCLibc` lines** serve nothing on macOS or Linux at `migrate-unix`. They're needed only where TSCLibc re-exports something, on Windows.

### From lint, at HEAD (`e0a10be`, the API of system-next `0e339dc`)

`lint.sh` over HEAD and the 23 clones in `../adopters` takes about 17 s. `api` reports 69 errors and 12 warnings, after the allowlist's 18 availability and 198 typed-throws exemptions:

- **api/availability (4)**: `Errno.notCapable` and `Errno.current` are new, in a `System 0.0.1` extension. `Stat.Flags.realDevice` and `Stat.Flags.descriptorOnly` are new, in a `System 1.7.0` one. api-delta's `unreleasedWithoutSystem199` lists the same four.
- **api/doc-sentence (26)**: 21 Win32 docs say "The corresponding C parameter of `X` is `y`." (or "C field of", "C values are"), a form no coverage tool reads. 5 sentences derive.py reads no name from: wildcard families (`VOL_CAP_FMT_*`, `VOL_CAP_INT_*`, `PROX_FDTYPE_*`, `JOB_OBJECT_MSG_*`) and a pointer type (`malloc_zone_t *`). Either the docs change or derive.py learns the forms (section 6, need 3).
- **api/aeic (12)**: `SocketAddress.ResolutionFlags`' 7 constants and `ReverseResolutionFlags`' 5 aren't `@_alwaysEmitIntoClient`. These are the 12 constants that STATUS.md's "Candidates for `@_alwaysEmitIntoClient`" (abi.py) lists.
- **api/typed-throws (27)**: SystemSockets' socket operations and options throw untyped (from `staging`), and so do `Win32.FileHandle.open`, `SocketAddress.resolve` and `SocketAddress.reverseLookup`.
- **api/c-struct-property (0)**: every stored C-struct property is a `rawValue`, or has Swift-named accessors (`CInterop.MMsgHdr.msg_hdr`).
- **api/doc-sentence-missing (12 warnings)**: among them `IPv4Address.init(_:port:)` and `IPv6Address.init(_:port:)` (`inet_pton`), their `addressString` (`inet_ntop`), and `FileWatcher.minimumReadByteCount` (`NAME_MAX`).
- **A stale local `main`.** `IORing.Request.PollEvents` and its members are counted as new because local `main` is 27 commits behind `origin/main`, which has them (`b62bce1`, #273). api-burndown flags them `upstream`; the allowlist exempts them with that reason.
- **markers**: no format errors: every marker is spelled `// SYSTEM-GAP: `. All 361 markers carry prose (`markers/one-interface`, section 7). 18 may be stale: System now covers what they name on their platforms. Among them, swift-build's `SWBBuildServiceConnection.swift:23` (`abort` on Windows: `ProcessID.abort`, coverage-7), swift-subprocess's `DarwinTests.swift:15` (`posix_spawn_file_actions_addchdir_np`: `SpawnFileAction.setWorkingDirectory`), and three in WasmKit's `PALFileDescriptor.swift` (`O_RSYNC` on Linux: `OpenOptions.readSync`). swift-testing's 4 `EXIT_*` markers are about Embedded Swift, which the check doesn't model.
- **conditionals**: 158 new platform conditionals call System in one arm and C in another, 77 of them in swift-nio, such as BSDSocketAPI.swift's `#if canImport(Darwin) || os(Linux) || os(Android)` → `SocketDescriptor`, `#else` → `PF_INET`. Michael expects these as an intermediate step; each is listed.
- **pitches**: no errors. 12 prerequisites are in no pitch (CInterop aliases, BaudRate, the terminal flag types, FilePath.ResolutionFlags), against the graph api-graph made for HEAD (`.build/api-graph`, adopters and the snapshot store off).

### From lanes

Nothing to report as a finding: it reads what exists. The trial-merge counts were checked by hand on one lane (tools-dirs: 2 conflicts, `Package.swift` and `Tests/ToolTests/Harness.swift`), with the objects in a temporary directory.

## 6. Needs outside the lane's files

1. **`Utilities/linux/cross.sh`: `--root` and `--dir`**, as `build.sh` has, so the probe can run Musl and WASI. Today it builds only its own package.
2. **`Utilities/api-delta/scripts/patch_manifest.py`: an importable function** for "drop Samples and swift-argument-parser". It patches on import, so the probe has its own copy (`manifests.drop_samples`).
3. **`Utilities/adopter-coverage/scripts/derive.py`: the forms it can't read.** It can't read wildcard families (`` `VOL_CAP_FMT_*` ``), pointer types (`` `malloc_zone_t *` ``), or "The corresponding C parameter (field) of `X` is `y`.", which 21 Win32 declarations use. Either derive.py learns them or the docs move to forms it reads (section 7).
4. **`Utilities/adopter-coverage/scripts/ledger.py`: module-wide and inherited re-exports** (findings F1 and F4). An `@_exported` import's names should include the rest of its module, and a target that imports a re-exporter has those names already.
5. **`Utilities/api-graph/scripts/pitches.py`**: `load_pitches` leaves its files open (a ResourceWarning in tests), and `unownedTypes` keeps examples in a set's order. lint sorts them and fixes the hash seed.
6. **`Utilities/README.md`**: index rows for lanes, lint and import-probe (the utilities lane's file).
7. **CLAUDE.md** (Michael's): the three tools in Commands.

## 7. Open questions

These stay open, each with the default the tools implement:

- **One interface per marker?** All 361 markers carry prose. The default reports each as a `markers/one-interface` warning. If the prose is the point, as status.py's parser assumes, drop the rule and keep `markers/format`.
- **Typed throws.** 27 untyped `throws` remain (SystemSockets' operations and options, `Win32.FileHandle.open`, `SocketAddress.resolve`/`reverseLookup`). `allowlist.ini`'s *proposed* entries (Win32.Error, LoaderError, KernelError, and the closure-taking declarations) await confirmation.
- **The Win32 drafts' doc sentences**: change them to a form derive.py reads, or teach it "parameter of"?
- **NIOPosix's re-export** serves 14 names, every one but `size_t` covered by System. Whether to keep it is NIO's source-compatibility question. Until it goes, F4's import stays redundant.

## 8. Next

- **lanes**: a `--since` view for a coordinator's catch-up.
- **lint**: the checks in its README's "Next": doc-comment conventions, OS floors inside `System 199` extensions, a mock test per new wrapper, Embedded Swift and version qualifiers for stale markers.
- **probe**: every adopter on both platforms, filed by commit as adopter-coverage's results store does; a Foundation-free view on Darwin; the container's own `describe`; Musl and WASI once need 1 is met.
