### Pipeline

`Utilities/adopter-coverage/check.sh` runs every step, and `scripts/package.sh` the steps for one package. It works in a scratch directory (`ADOPTER_COVERAGE_WORK`, default `.build/adopter-coverage-work`), files every result in the results store (`ADOPTER_COVERAGE_RESULTS`, default `coverage-results` next to the worktree), and copies the run's reports to `ADOPTER_COVERAGE_OUT` (default `.build/adopter-coverage`). It never touches tracked files, here or in any package's checkout.

1. **Scan System and derive what it covers.** `git archive` exports `SYSTEM_REF`'s `Sources`, and api-delta's `scan_sources.py` lists its public declarations with the platforms that compile each. `scripts/derive.py` then reads, for each public declaration, the *The corresponding C function is `x`.* sentences of its doc comment (and the constant, type, error, macro, field and global-variable ones) and the CInterop typealiases, and lists each C name with the declarations that cover it and where they compile. It also lists the names System's own code uses on each platform. Both are stored per System commit and tool (`systems/`), once for all packages.
2. **Export and build the package.** `git archive` exports the package's commit (a spec names it: `NAME`, `NAME@REF`, `NAME=PATH@REF`). A manifest's `.package(path:)` dependency is made absolute in the export, and one that points at a swift-system checkout becomes an export of the System commit being checked (`scripts/pathdeps.py`). `swift build` builds the export in debug, which on macOS writes an index store. The build follows the package's manifest, with what `packages/NAME.ini` adds: the targets to build (`:libraries` builds only library targets), extra flags, environment switches to unset, and `<P>_SWIFT_EXEC` for a package the default toolchain can't build. A manifest for newer tools than the toolchain's is read with its tools version lowered, in the export.
3. **Read the index.** `scripts/indexstore.py` reads the store through the toolchain's `libIndexStore.dylib` with ctypes. It dumps every reference from the package's sources, Swift and C alike, with the declaring module and file of each referenced symbol; the names each module declares; and the call graph of the dependencies' sources, for step 6. The dump, the export it was made from, the manifest dumps and what the dependencies re-export are stored by package commit and build settings (`index/`), and the build is deleted. When the build fails, that's stored too, and the extraction is lexical.
4. **Scan the package.** `scripts/swift_scan.py` and `scripts/c_scan.py` scan each file of its library targets. They work out, line by line, which platforms compile the line (`scripts/platforms.py`), and list the identifiers that could name an OS symbol. Each target's `#if` model comes from its manifest (see the design decisions).
5. **Extract.** `scripts/extract.py` combines the two into `interfaces.json`: every OS or C-library interface, with its sites (file, line, target, platforms, conditions) and how each was found.
   - On lines the Darwin build compiled, the index decides. The compiler resolved every reference there, so a symbol counts when its declaration is in an OS module (Darwin and its submodules, Dispatch, ObjectiveC, the SDK's frameworks, …) or in one of the package's C shim targets. The `#if` evaluation then says which other platforms compile the same line.
   - On other lines, lexical rules decide, in order. A name qualified by an OS or shim module (`Glibc.SOCK_CLOEXEC`, `CNIOLinux.epoll_create`) counts, as does one named by a scoped import (`import func WinSDK.inet_ntop`) or declared by a shim header. Otherwise, a name bound in an enclosing scope, declared by the package on the same platforms, or declared at top level by the Swift libraries or the dependencies doesn't count. A name the Darwin SDK declares counts. Inside an extension of an OS type, a name declared nowhere is that type's member. Anything left is *unresolved*: declared nowhere the package can see, so presumed to come from the platform's C library.
   - The lexical rules also run on the lines the Darwin build compiled, and are compared with the index there.
   - A package that didn't build is extracted lexically on every line, with the SDK's and Swift libraries' names from another build's index (`vocab/`), and *unresolved* names are dropped.
   - `scripts/darwin.py` works out how each Swift file sees the Darwin module on Darwin: by importing it, through a re-export in its own module, in the package or a dependency, or only through an SDK module's (Foundation's) re-export, which it asks the compiler about once per SDK (`sdk-probe/`).
6. **Follow the dependencies.** `scripts/deps.py` works out which dependency symbols reach an OS function, directly or through other dependency code, and counts the package's lines that use them.
7. **Check.** `scripts/check.py` decides each mapping entry's status on each platform from the derivation (its `Derivation` class; see the design decisions), unless `mapping.ini` gives a status, and reports where the two disagree. An interface no entry names gets an entry of its own. Every System declaration the mapping cites must exist in its scope at the commit. It writes `coverage.json`.
8. **Report and store.** `scripts/report.py` writes the package's `COVERAGE.md`. `scripts/results.py` files the result under the package commit, the System commit and the tool (`results/`), comparing it first with any result already there for the same three, and records the run (`runs/<run>/run.json`). `scripts/combine.py` writes the run's combined report.

### Design decisions

Each is listed with the alternative it rejected.

1. **Compiler-backed on Darwin, lexical elsewhere, and the lexical rules measured against the compiler.** The index store is the compiler's own resolution of every name, for Swift and C. It covers only what the macOS build compiles, so Linux-, Windows- and WASI-only code needs lexical rules, and running both on the macOS code gives those rules an error rate.
   *Rejected:*
   - Lexical rules alone: nothing would check them.
   - `swiftc -dump-parse -target <triple>`: in Swift 6.2 its output omits everything inside `#if`, so it can't show another platform's code.
   - Cross-compiling: no Linux, Windows or WASI SDK is installed (`swift sdk list` is empty).
   - A swift-syntax tool (SwiftIfConfig, SwiftLexicalLookup): a network dependency and a multi-minute build, and it still resolves no imported names.
2. **One tool, with a file per package.** `packages/NAME.ini` holds what the tool can't learn from a package's manifest or build (its C shims, test-support targets, platforms, build settings, syscall-layer files); everything else is the same code for every package.
   *Rejected:* a copy of nio-coverage per adopter, which would drift.
3. **One mapping for every package.** What System covers doesn't depend on who asks, so an entry's symbols, status and System citations are shared; `note` says what System has and lacks, and `note.<package>` what that package does with it. A package's report counts only the entries it uses; the combined report finds symbols no package uses.
   *Rejected:* a mapping per package, which would repeat each interface's coverage and let the copies disagree.
4. **Build an export of each package in a scratch directory; keep its index dump in the results store, by commit, compiler, build settings, index reader and the path dependencies in use; delete the build once it's read.** The checkouts stay read-only, a rerun against a new System commit costs seconds, and a run needs only the largest package's build on disk at once (SwiftPM's full debug build is 6 GB).
   *Rejected:* building in the checkout; rebuilding on every run; keeping the builds, which the tool never reuses (a new commit is exported afresh).
5. **Build as the manifest says, against the swift-system it names (released, for the audited adopters).** Extraction is about what the package uses, and it shouldn't depend on whether it compiles against `system-next`, which is the adoption question. Where the manifest's default build can't run here, the package file says what changes and why: SwiftPM builds its library targets only (`:libraries`), Subprocess raises its deployment target to macOS 26 for `Span.bytes`, Foundation raises the manifest's type-checker limit and builds with a newer compiler.
   *Rejected:* pointing the packages' swift-system dependency at this repository. (A migration that points it at a local checkout gets the System commit being checked; see 31.)
6. **A newer compiler for a package whose main branch needs one, named per package (`<P>_SWIFT_EXEC`), and reuse of its dump when the compiler is gone (`<P>_REUSE_INDEX`).** swift-foundation's main branch uses Swift 6.3 features; its report records the compiler that built its index.
   *Rejected:* auditing an older commit, which isn't the code in question; lexical rules alone for that package, with no compiler resolution and no accuracy estimate.
7. **One interface per C name.** Struct fields fold into their struct, Swift overlay members into their type (DispatchQueue.async into DispatchQueue), C enumerators Swift renames into their enum (`POSIXErrorCode.E2BIG`), an overlay's global operators into their operand's type, and a C function Swift renames keeps its C name (`DispatchGroup.enter()` is `dispatch_group_enter`). A name used as both a function and a struct, like `stat`, is one interface.
   *Rejected:* one per USR, which splits a C declaration from the Swift accessors and overlays that mean the same thing, and splits a symbol by platform.
8. **A three-valued `#if` evaluation, modeled per target from the manifest.** A line is active on a platform, inactive, or active only in some configurations (M). Each target's flags come from its manifest settings, with their platform and configuration conditions; traits are T where enabled by default; SWIFT_PACKAGE is T; `canImport` finds the package's own modules and everything its build built; and the compiler's version answers `compiler(>=)`. Flags the manifest doesn't know are M: opt-in flags (`SWIFTNIO_USE_IO_URING`), and C macros the SDK headers define. `__has_include` is decided by the SDK on Darwin and by a table of headers whose presence doesn't depend on what's installed elsewhere; integer macros the package's own headers define (`TARGET_OS_LINUX`) get a value per platform. M lines count, and the report names their conditions.
   *Rejected:* one fixed configuration per platform, which would drop the io_uring backend and the 32-bit branches; treating unknown conditions as false; one global set of flags for every package.
9. **Flags only builds the tool doesn't model define are false (`false-flags`), and the report counts what they hide.** Foundation's FOUNDATION_FRAMEWORK is Apple's Foundation.framework build, whose CoreFoundation and Objective-C calls aren't the package's.
   *Rejected:* M, which would count the framework's code as the package's.
10. **Drop references the index attributes to a line without the name being written there.** In Swift these come through a typealias; the alias declaration is recorded where it's written. In C they come from a macro's expansion. The package's own macros are kept (CNIOAtomics' `MAKE(type)` expands to C11 atomics), and an SDK macro's internals are dropped (`CMSG_DATA` expands to `__DARWIN_ALIGN32`). A renamed C declaration counts when its Swift name is written (`CFDictionary` for CFDictionaryRef).
    *Rejected:* keeping them, which lists SDK implementation details as interfaces.
11. **An Apple framework's symbol counts only on Darwin.** Where a line that uses one compiles elsewhere too, the name means something else there: SwiftPM's SHA256 is CryptoKit's on Darwin and swift-crypto's elsewhere.
    *Rejected:* giving it every platform the line compiles on, as for C library names, which every libc spells alike.
12. **The mapping is an INI file read by Python's configparser.** It allows comments, multi-line notes and lists of declarations, and diffs cleanly; `scripts/mapping_edit.py` edits it without reformatting.
    *Rejected:*
    - JSON: no comments, and hand edits break on commas.
    - TOML: `tomllib` needs Python 3.11, and macOS ships 3.9.
    - A Markdown table: it can't hold multi-line fields.
13. **Cite System API by declaration text in its scope**, where the mapping cites any (its hand statuses), matched after dropping attributes, access modifiers and layout. A reader can review it, and the check catches signature changes that adoption has to know about, such as `throws` to `throws(Errno)`.
    *Rejected:*
    - USRs: opaque to a reader.
    - Names with argument labels only: signature changes pass silently.
14. **Derive each entry's per-platform status from where the declarations that cover it compile** (named by System's doc comments, or cited by a hand status), per api-delta's scan, less the platforms an `@available(<platform>, unavailable)` takes away.
    *Rejected:* hand-kept per-platform statuses, which go stale as System gains platforms.
15. **"Covered" allows differences of convention; "partial" means lost capability.** Every NIO wrapper turns errors into `IOError` and EAGAIN into `.wouldBlock`, where System throws `Errno`; that's an adapter of a few lines, not a gap. Partial is kept for a missing flag or option, lost partial-progress information, a forced copy or allocation, or a platform the API skips.
    *Rejected:* marking every wrapper partial for an adopter's error conventions, which would bury the real gaps under one label.
16. **What isn't System's to wrap is still counted, and marked (`wrap = no`)**: Dispatch, Apple's frameworks, SQLite. The gap ranking leaves those entries out, as it does entries with a Swift standard library alternative.
    *Rejected:* `ignore`, which would hide real OS use.
17. **Rank gaps by the code System API would let the package delete.** That's the code lines of thin wrapper functions (up to 40 lines) in the package's syscall-layer files (`wrapper-files`), plus the C shim definitions an entry would retire. The combined report ranks entries by how many adopters they block, then by those lines summed.
    *Rejected:* ranking by call-site count, which measures how often a package uses an interface rather than what it could delete.
18. **Measure OS use through the dependencies with their call graph, and bound it both ways.** The index covers the dependencies' sources, so a dependency symbol reaches the OS when its implementation calls an OS function: one the Darwin SDK's libc and kernel interfaces declare, other than the C library's computation, locks and thread-local storage, and process exit. Dispatch the package calls through a protocol is expanded to every implementation the build compiled; dispatch inside the dependencies isn't, and an upper bound expands it everywhere.
    *Rejected:* counting every function the SDK declares, which counted libc++'s templates and Dispatch's `sync`; expanding dispatch everywhere only, which connected swift-argument-parser's option initializers to printing; mapping the dependencies, which is another lane's.
19. **Reuse api-delta's source scanner** for System's API, and its comment and string blanker for the packages' Swift.
    *Rejected:*
    - Symbol graphs: macOS only, and a second build.
    - A copy of the scanner: it would drift from the original.
20. **Leave out Foundation, the Swift libraries and the packages' dependencies; check System API a package already calls.** Foundation isn't an OS interface; NIO's `*FoundationCompat` targets exist to bridge its types. SystemPackage references are looked up on the tip, since adoption needs them to keep working.
    *Rejected:* listing Foundation, and ignoring existing System uses.

21. **Derive what System covers from its own sources at each commit: the *The corresponding C ...* sentences of its public doc comments and its CInterop typealiases.** Every wrapper's doc comment names what it wraps, by convention, so the coverage follows System's commits with no one keeping it. On 0d91e78, 18 of the hand mapping's 194 entries still said `missing` for API the threads, events, directories and sockets lanes had added, and one said `covered` for an option that isn't built on two platforms.
    *Rejected:*
    - Hand-kept statuses: they go stale whenever a lane merges.
    - Symbol graphs' doc comments: macOS only, and a build of System per commit.
    - What System's syscall layer calls: that's what System uses, not what its API offers (EventCounter calls read; nothing makes it a read wrapper).
22. **Read each sentence with a small grammar: its first name is its subject, and the words before each later name make it an alternative, an argument or a condition.** `fcntl`, with the `F_GETFL` command covers F_GETFL and covers fcntl only for that use; `chmod`, or `lchmod` if `followTargetSymlink` is `false` covers chmod and lchmod and drops the condition's names.
    *Rejected:* taking every backticked name: `wait` (a parameter in a condition) would cover wait(2), and `fcntl` would count as covered by each command's accessor.
23. **Decide by entry, not by symbol: the symbols a package uses on a platform decide, less its own shims and the C names only its shims use; when nothing else is left, the entry's other spellings, then what the shims wrap.** An entry groups one concept's symbols, and System can never name a package's shims (CNIOLinux_renameat2), so an entry is covered where the concept is.
    *Rejected:* deciding each symbol alone, which makes every entry with a shim partial; the section name as the only anchor, which many entries don't have.
24. **What System's implementation uses completes an entry but never decides one.** pthread_mutex_destroy (a deinit's), UTIME_OMIT and freeaddrinfo are handled for the adopter by API that names their companions.
    *Rejected:* counting System's own uses as coverage, which would make ioctl covered because TerminalDescriptor calls it for two requests.
25. **An operation needs one of its functions named.** System names CLOCK_MONOTONIC for its condition variables and QoS classes for its threads, which covers neither clock_gettime nor posix_spawn.
    *Rejected:* partial for any named symbol, which labels most missing entries partial.
26. **A hand status in the mapping overrides the derivation, and every report lists where they disagree.** The derivation can't see equivalences the docs don't state (`same.<symbol>` states them), doc gaps (FilePermissions doesn't name S_IRUSR), or a judgment of lost capability (an option only through the generic setOption). `mapping_edit.py prune` drops the hand statuses a run shows are redundant or stale.
    *Rejected:* derivation only, which would be wrong for those; hand only, which is what went stale.
27. **An interface no entry names gets an entry of its own, derived, in a category from its header or name** (`[config]` in mapping.ini), and fails the check only for packages that are `strict`.
    *Rejected:* failing for every package, which makes auditing a package without mapping entries (the ecosystem's) impossible.
28. **Store results by commit, outside every worktree: `results/<package>/<package commit>/<System commit>/<tool>/`, with the tool a hash of its git trees.** A run can be repeated for any pair of commits and compared with any other, and survives the worktree's removal. A run's id comes from its inputs, so a repeat lands on the same id, and its stored results are compared with the new ones first.
    *Rejected:*
    - `.build` only: lost with the worktree, and each run overwrites the last.
    - Run ids from dates: a repeat can't be told from a new run.
    - The tool's commit as its identity: any commit to System would be a new tool.
29. **Store each build's index dump with the export it was built from, and relocate the dump's paths when it's read elsewhere.** A rerun, for any System commit, needs neither the build nor the checkout.
    *Rejected:* rebuilding on every run; requiring the checkout for a rerun.
30. **Verify a run with the tool it recorded, exported from git into a temporary directory.** Differences are then nondeterminism or an environment change, not tool changes; `rerun` uses the current tool, and `delta` compares any two runs.
    *Rejected:* verifying with the current tool, which can't tell a tool change from a failure to reproduce.
31. **Rewrite a manifest's path dependencies in the export; one that points at swift-system becomes an export of the System commit being checked, and only the ones the evaluated manifest uses key the build.** The ../adopters migrations point swift-system at a local checkout. NIO's and SwiftPM's manifests name local checkouts in a branch they don't take, which mustn't key their builds.
    *Rejected:* building against the working tree the manifest names, which isn't a commit; symlinks in the scratch directory, which collide.
32. **Extract a package that doesn't build lexically, with the SDK's names from another build's index, dropping names declared nowhere.** Without the build, the dependencies' declarations are unknown, and counting what they declare would be false positives. On NIO, against its index, this finds 395 of the 422 Darwin interfaces, with none wrong.
    *Rejected:* leaving such packages out (swift-foundation, which needs a newer compiler); counting unresolved names.
33. **Count how each file sees Darwin, not only who imports it.** An `@_exported import` makes Darwin visible in every file of its module and in its clients, and Apple Foundation re-exports it, which a compile check confirmed; the SDK modules that re-export it are asked of the compiler, once per SDK.
    *Rejected:* counting `import Darwin` lines, which misses NIOPosix's module-wide re-export and SwiftPM's hundreds of files that see Darwin through Foundation; a hardcoded list of SDK re-exporters.
34. **Audit the toolchain's packages at the refs its update-checkout scheme names, from shallow clones and generated package files; the audited adopters keep their own files.**
    *Rejected:* the sister clones' commits, which aren't the toolchain's; tuning every package file by hand first.
35. **Count the standard library's C interfaces lexically, against the Darwin SDK's C vocabulary, filtered by kind and spelling.**
    *Rejected:* building the runtime to index it, which takes a toolchain build.
36. **Assign lanes by ordered rules in mapping.ini (`lanes`): by symbol, category or the platforms a gap is on.**
    *Rejected:* a lane key per entry, which interfaces with no entry can't have.

### Blind spots

- **The derivation reads what System's doc comments say.** A declaration whose doc comment doesn't name the C interface it wraps (FilePermissions' S_IRUSR, FileDescriptor.standardInput's STDIN_FILENO, EventCounter's eventfd_read) covers nothing until the mapping says so, and every report lists those overrides; a sentence that names an interface the declaration doesn't really wrap would cover it. What System's implementation uses is found lexically.

- **Darwin means one build**: macOS, arm64, debug, with the compiler the report names. Code only for iOS, tvOS, watchOS or visionOS is evaluated as inactive, and x86_64-only and release-only code is M: lexical, not indexed. Emscripten, which Foundation supports, isn't modeled.
- **The lexical rules** miss or over-count where a scanner can't follow Swift:
  - Members inherited from types outside the package, and member calls on OS types' instances (`group.leave()` is `dispatch_group_leave`).
  - Declaration order: a binding hides a name throughout its scope.
  - Type inference: a C name reached only through the package's typealias on Linux is attributed to the typealias.
  - Names that exist only off Darwin and coincide with a package or library declaration are dropped (`pow` is also Foundation's Decimal function), and a name the Darwin SDK declares for something else is counted (ncurses' `filter`).
  - A name declared nowhere, used inside an extension of an OS type, is taken for that type's member.
- **C code** gets no macro expansion beyond the package's own token-pasting macros, and no header contents, so SDK-defined macros decide `#if` branches only as M. The index also misses some macros from textual headers (`assert`), which the C scan adds back.
- **Kinds** of lexically found names are guessed from the Darwin SDK's declaration of the same name or from their spelling.
- **Platform models**: `canImport` answers are fixed per platform (FreeBSD and OpenBSD import `Glibc`, Android has `Android` and `Bionic`, WASI is single-threaded), and a wrong model misattributes sites. A target that reaches `#error` on a platform is treated as not building there (NIOPosix on FreeBSD), and a package's `platforms` leave out the ones it doesn't support.
- **Sites** count source lines, so NIOFS and its twin _NIOFileSystem count twice, and a generic helper called from many places counts once.
- **System's side** is api-delta's lexical scan. It loses some scopes (IORing's members appear at the top level), which the check tolerates by accepting a top-level match and marking it.
- **Foundation**: its macros (FoundationMacros) run at build time and aren't audited; what they expand to in Foundation's own code is indexed where it's used. `_FoundationCShims` declares data tables as well as shims (the Unicode bitmaps, BPlistTrailer), which are mapped as ignored. The code only FOUNDATION_FRAMEWORK and the other false flags compile is counted, not audited. ICU is a dependency: Foundation's calls into it are the dependency's, and ICU's own OS use is counted in the dependency section.
- **SwiftPM**: much of its OS work is other programs, run through AsyncProcess or TSC's Process (git, the compilers, `xcrun`, `codesign`, and `sandbox-exec`, which applies the sandbox profile Sandbox.swift writes as text for plugins and manifests); the extraction sees the spawn, not what the program does. Its use of Foundation (FileManager, Process, URLSession) can't be followed, since the SDK's Foundation is binary. TSC, llbuild and swift-driver are measured, not mapped.
- **The dependencies' reach** is what a symbol may reach, however rarely: an error path counts like the main one, and protocol dispatch is bounded, not resolved. Calls through a dependency's re-export of an SDK framework count as the framework's.
- **Out of scope:** each package's tests, examples, benchmarks, test fixtures and executables (listed under *Extraction*), and the separate packages nested in its checkout. Code reached only at runtime (`dlsym` lookups, environment variables) shows up only as the call that reaches it.

- **Lexical extractions** (a package that didn't build) see only the names the Darwin SDK declares, or that are qualified or imported explicitly: names only Linux, Windows or WASI declare are dropped, so those platforms are undercounted.
- **The ecosystem's packages** have no mapping entries: their interfaces are grouped by name, and categorized, and so given lanes, by header and name rules.
- **The Darwin metric** reads imports lexically, and dependencies' re-exports from their sources' `@_exported import` lines, without their `#if` conditions.

### Outputs

| Path | What |
|---|---|
| `COVERAGE.md` | This report. |
| `coverage.json` | The check's data: entries with per-platform status and matched declarations, the problems, the summaries, the gap ranking. |
| `interfaces.json` | The extraction: every interface with all of its sites, the cross-check, the dependency measure, and the scanned files' function spans. |
| `meta.json` | Commits, date, host, the compiler, and the index dump's key. |
| `logs/` | The package's build log and its `swift package describe` and `dump-package` output. |
| `derived.json` (with the System scan) | What System covers at the commit: each C name, its covering declarations and where they compile, and the names its implementation uses. |
| `system-api.json` | api-delta's scan of System's public declarations at the commit. |
| The run's `COVERAGE.md`, `coverage.json` | The combined report over the run's packages. |
