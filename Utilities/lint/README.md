# lint

`lint.sh` runs convention checks over swift-system and its adopters. Each check is separate; one entry point runs any of them. Findings print as `file:line: rule: message`. The exit status is 1 when any finding is an error, 2 when a check couldn't run, and 0 otherwise. A summary on standard error gives what each check read and the counts by rule.

```sh
Utilities/lint/lint.sh                                   # every check
Utilities/lint/lint.sh cmake api                         # some
Utilities/lint/lint.sh markers --clone ../adopters/swift-nio
Utilities/lint/lint.sh conditionals --clone ../adopters-unix/swift-nio --base main
Utilities/lint/lint.sh --json pitches                    # findings with their levels and details
Utilities/lint/lint.sh --rules                           # every rule and its level
```

| Option | Default | |
|---|---|---|
| `CHECK...` | all | `cmake`, `api`, `markers`, `conditionals`, `pitches`. |
| `--clone PATH` | every clone in `../adopters` | An adopter checkout, for markers and conditionals. Repeatable. |
| `--branch B` | each clone's newest migration branch | `migrate-all`, else `migrate-unix`, else `migrate-darwin`. |
| `--base REF` | `main` | conditionals: the branch is diffed against its merge base with this. |
| `--system REF` | `system-next` | markers and conditionals: the System commit whose coverage and API they read. |
| `--api-delta DIR` | `.build/api-delta`, if it's `main`..HEAD | api: api-delta's output to read. Otherwise api-delta runs into `.build/lint/api-delta` (about 40 s). |
| `--no-run` | off | api: fail instead of running api-delta. |
| `--graph FILE` | see the pitches check | pitches: api-graph's `graph.json.gz`. |
| `--pitches DIR` | `Prototype/Pitches` | pitches: the pitch files. |
| `--json` | off | JSON: every finding with its level and the details behind it. |

## The checks

| Rule | Level | What it finds |
|---|---|---|
| `cmake/missing` | error | A Swift file of `Sources/System` (tracked, or untracked and not ignored) that `Sources/System/CMakeLists.txt` doesn't list; the same for `Sources/SystemWinSocks` and its list. |
| `cmake/stale` | error | A `.swift` path the list names that doesn't exist. |
| `api/availability` | error | An added public declaration with no `@available(System 199, *)` on it or an enclosing scope. |
| `api/doc-sentence` | error | A "corresponding C" sentence the coverage tools can't read: adopter-coverage's `derive.py` reads no C name from it, or it's in a form they don't read ("The corresponding C parameter of `X` is `y`."). |
| `api/doc-sentence-missing` | warning | A declaration that wraps C by System's conventions, but whose doc names no C interface. It wraps C if its code calls a `system_*` wrapper or reads a `_CONSTANT` of `Constants*.swift`, directly or through a `_helper(...)` whose name is unique in its module, or if it's a Swift-named accessor in an `extension CInterop.X`. |
| `api/aeic` | error | A header constant that isn't `@_alwaysEmitIntoClient`: a static property whose short body forwards a C constant, a `_CONSTANT` or the one its doc sentence names, and calls nothing. |
| `api/typed-throws` | error | A throwing declaration whose own effect isn't `throws(Errno)`. `rethrows`, and a generic `throws(E)`, pass. |
| `api/c-struct-property` | error | A public stored property whose type is a C struct or union with no Swift-named accessors, other than a `rawValue`. |
| `markers/format` | error | A `SYSTEM-GAP:` marker that isn't `// SYSTEM-GAP: <interface>`. That covers a block or doc comment, other spacing or case, text before it in its comment, code before it other than the import it's for, and no interface. |
| `markers/one-interface` | warning | A marker whose text is more than one interface: a list, prose, a platform qualifier, a continuation line. |
| `markers/stale` | warning | System now covers every C name the marker gives, on every platform the marker's line or the import under it is compiled for (narrowed to the platforms its text names). |
| `conditionals/mixed` | warning | A platform conditional (`os()`, `canImport()`, `arch()`, `targetEnvironment()`) that the adopter branch adds, with one arm that calls System and no C and another that calls C. |
| `pitches/file` | error | A pitch file api-graph can't use: not JSON, an `id` other than its name, a missing or unknown field, pattern or status. |
| `pitches/missing` | error | A rule naming a declaration that isn't in the added set, naming several, or matching nothing. |
| `pitches/overlap` | error | A declaration two pitches include. |
| `pitches/requires` | error | `requires` naming a pitch that doesn't exist. |
| `pitches/cycle` | error | Pitches that need each other. |
| `pitches/prerequisite` | warning | A pitch whose declarations need a new type that no pitch owns. |

## What each reads, and whose reading it reuses

- **cmake** reads the working tree through git (`git ls-files`, tracked and untracked-not-ignored), so a new file is caught before it's committed. It compares paths as the list writes them, relative to its directory, past `#` and `#[[ ]]` comments. CI's check (`.github/workflows/pull_request.yml`) compares SwiftPM's sources with CMake's configured list instead, which needs CMake. SystemWinSocks' list is `Sources/SystemWinSocks/CMakeLists.txt`, which CMake configures only for Windows, so CI's Linux job never reads it. SystemSockets has no CMakeLists.txt; the check says so and checks it once it has one.
- **api** reads api-delta's `api-delta.json`: its symbol-graph entries, with the scanner's attributes joined by file and line, and `hiddenFromGraphs`, the scanner's declarations for code Darwin doesn't compile. It also reads the symbol graphs api-delta keeps (`symbolgraphs/head`) and api-delta's scanner run on HEAD's commit (adopter-coverage's `ledger.system_api`, cached in `.build/lint/system`). System's sources at HEAD (`Sources/System`, `Sources/SystemSockets` and `Sources/SystemWinSocks`) are read through git; SystemWinSocks' declarations are all `hiddenFromGraphs`, since only Windows compiles them. The output is current if it compares `main` with HEAD, or with a commit whose `Sources` tree is HEAD's. Fix-it stubs, underscored, deprecated and SPI declarations, and public members of non-public types, aren't judged.
  - Doc sentences are read with `derive.py`'s `sentences` and `parse`, the reading adopter-coverage, api-graph's `cnames.py` and through it api-burndown derive coverage from.
  - C struct types come from the symbol graphs: a property's type, or the CInterop typealias it names, resolves to a `c:@S@`, `c:@SA@`, `c:@U@` or `c:@UA@` USR. A typedef's USR (`c:@T@fsid_t`) doesn't say whether it's a struct, so those aren't judged; neither are the declarations only other platforms compile, which have no graph.
  - The header-constant rule finds the 12 constants that adopter-coverage's `abi.py` lists as forwarding a C header value (STATUS.md's "Candidates for `@_alwaysEmitIntoClient`"). abi.py also lists raw-value initializers and field accessors, which this rule leaves alone.
- **markers** reads each clone's branch through git and parses markers with adopter-coverage's `status.py` (`file_markers`, `parse_marker`, `marker_interfaces`), the reading of STATUS.md's section 3 and the ledger. A marker's platforms come from `platforms.py`'s `#if` evaluator, as the ledger reads them, and its coverage from `ledger.Coverage` at `--system`. A name that's System API (`PThread.Key`, `SystemSockets`) is covered where its declaration or module is built, a module where it also declares API: SystemWinSocks builds everywhere, but declares nothing outside Windows. A stale marker whose text also names System API says so, since the check can't judge what an adopter needs of that API, such as a manifest condition PackageDescription can't express.
- **conditionals** diffs the branch against its merge base with `--base` (Swift files, `git diff -U0`). A conditional is new when its `#if` line is added. Each arm is read at the branch's commit, with comments and strings blanked. It calls System when it names one of System's public top-level types or modules that the package doesn't declare itself. It calls C when the ledger's lexical reading (`ledger.uses`, with `ledger.Vocabulary`: the SDK's names from the coverage tools' stored vocabulary in `../coverage-results/vocab`, System's C names and mapping.ini's) finds a C name in it.
- **pitches** reads the pitch files from the working tree, as api-graph does, and checks them with api-graph's own `pitches.py` (`load_pitches`, `check`). The graph is `--graph`; else this worktree's `.build/api-graph/graph.json.gz`, or the snapshot store's graph of HEAD (`../api-graph-snapshots`), when it maps HEAD or a commit with HEAD's `Sources`; else the newest of them, with a note that it isn't HEAD's.

Every other tool's script is imported read-only, with bytecode off, so nothing is written into their directories. Git runs with `--no-optional-locks` and `GIT_NO_LAZY_FETCH=1`.

## The allowlist

`allowlist.ini` holds the api check's exceptions: a section per rule; a key per declaration path (a shell glob; `[` matches itself), or for `api/typed-throws` a thrown type (`throws:Win32.Error`); and a value that's the reason, which must say what makes it an exception and where that's decided. An entry with no reason is an error. The summary says how many findings each rule's entries exempted. It's seeded with the exceptions CLAUDE.md records (the Span-based I/O's explicit OS availability) and with facts about declarations (Codable's untyped requirements, closures whose errors a declaration rethrows with its own). The entries marked *proposed* await Michael.

## Run time

On this machine, from a current api-delta output: cmake under a second; api about 2 s; markers and conditionals over the 23 clones in `../adopters` about 15 s together, most of it reading System's coverage the first time; pitches about a second. Every check, every clone: about 17 s.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/lint/scripts -p 'test_*.py'
```

Each rule has a fixture test: a CMakeLists.txt with comments and an untracked file in a temporary git repository; marker lines in every wrong form, and a file with markers over and away from imports, against a stand-in for System's coverage; a diff and a file with new, old, mixed and non-platform conditionals, against a stand-in vocabulary; pitch files and a small graph in a temporary directory (an overlap, a missing path, a missing prerequisite, a bad `requires`, a file that isn't JSON); and an api-delta document, scanner declarations, sources, constants, syscall wrappers and symbol-graph fragments for every api rule and the allowlist. Nothing outside the temporary directories is written, and nothing reaches the network.

## Design calls

- **The api check reads api-delta's output, not source text**, as asked: the added set and the effective availability come from the symbol graphs, the hidden declarations from api-delta's scanner. Source text is read only where the graphs can't help: attributes, bodies and the doc comments of declarations only other platforms compile. *Rejected*: a scan of the source text alone, which can't tell which declarations are new.
- **"Wraps C" by System's own conventions** (the `system_*` layer, `Constants*.swift`, `extension CInterop.X`), followed through one `_helper` whose name is unique in the declaration's module (one module can't call another's internal helpers, and SystemWinSocks repeats SystemSockets' names). *Rejected*: following every `_`-prefixed name transitively, which on this tree reached unrelated syscalls through overloaded helpers (97 warnings, most of them wrong). Also rejected: api-graph's code links (`DOC-SENTENCES.md`), which come from an indexed build of minutes; that list stays the fuller work list.
- **`api/doc-sentence` as an error**: a sentence the coverage tools can't read counts as no sentence there. That includes wildcard families (`VOL_CAP_FMT_*`) and pointer types (`malloc_zone_t *`), which `derive.py` rejects; teaching it those would end these findings.
- **Levels.** The rules the conventions state outright are errors. The ones whose reading is a heuristic are warnings: wrapping C, stale markers, mixed conditionals, missing prerequisites. One-interface is a warning too, because no adopter marker meets it today.

## Open questions

- **One interface per marker.** All 361 markers on the adopters' newest branches carry prose (a platform, a reason, a list). If the convention is literally `// SYSTEM-GAP: <one interface>`, they all need rewriting. If the prose is the point, as status.py's parser assumes, drop `markers/one-interface` and keep `markers/format`.
- **Typed throws in SystemSockets.** The 27 `api/typed-throws` errors left are SystemSockets' operations and options, which came from `staging` with untyped `throws`, plus `Win32.FileHandle.open` and `SocketAddress.resolve`/`reverseLookup`.
- **The proposed allowlist entries**: the typed errors of their own (`Win32.Error`, `DynamicLibrary.LoaderError`, `Mach.KernelError`) and the closure-taking declarations.

## Next

- `api/doc-sentence` could suggest the sentence from api-graph's code links when a current graph exists.
- A `docs` check: the CLAUDE.md conventions on doc comments ("The corresponding C function is `foo`." last; `@available(*, unavailable, renamed:)` fix-its for C spellings).
- An `availability` check of explicit OS floors inside `System 199` extensions (api-delta's `osFloorInSystem199Extension`), the ABI-stable build's known failure.
- A `tests` check: each new syscall wrapper has a mock test (`MockTestCase(name: "foo"`).
- `markers`: model Embedded Swift and the "before macOS 27" qualifiers, which the stale rule ignores now.
- `conditionals`: an arm's System and C names per platform, rather than the first platform the arm compiles for.
