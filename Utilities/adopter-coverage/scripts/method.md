### Pipeline

`Utilities/adopter-coverage/check.sh` runs every step, and `scripts/package.sh` the steps for one package. It works in a scratch directory (`ADOPTER_COVERAGE_WORK`, default `.build/adopter-coverage-work`) and replaces a package's output directory (in `ADOPTER_COVERAGE_OUT`, default `.build/adopter-coverage`) only when every step has run. It never touches tracked files, here or in the package's checkout.

1. **Scan System.** `git archive` exports `SYSTEM_REF`'s `Sources`, and api-delta's `scan_sources.py` lists its public declarations with the platforms that compile each. This happens once for all packages.
2. **Export and build the package.** `git archive` exports the package's commit, and `swift build` builds the export in debug, which on macOS writes an index store. The build follows the package's manifest, with what `packages/NAME.ini` adds: the targets to build (`:libraries` builds only library targets), extra flags, environment switches to unset, and `<P>_SWIFT_EXEC` for a package the default toolchain can't build. The dependencies resolve as the manifest says, so a package that depends on swift-system builds against a released System. Once the index has been read, the build is deleted; the export and the index dump are kept, keyed by commit, compiler, build settings and index reader, so a rerun against a new System tip skips this step.
3. **Read the index.** `scripts/indexstore.py` reads the store through the toolchain's `libIndexStore.dylib` with ctypes. It dumps every reference from the package's sources, Swift and C alike, with the declaring module and file of each referenced symbol; the names each module declares; and the call graph of the dependencies' sources, for step 6.
4. **Scan the package.** `scripts/swift_scan.py` and `scripts/c_scan.py` scan each file of its library targets. They work out, line by line, which platforms compile the line (`scripts/platforms.py`), and list the identifiers that could name an OS symbol. Each target's `#if` model comes from its manifest (see the design decisions).
5. **Extract.** `scripts/extract.py` combines the two into `interfaces.json`: every OS or C-library interface, with its sites (file, line, target, platforms, conditions) and how each was found.
   - On lines the Darwin build compiled, the index decides. The compiler resolved every reference there, so a symbol counts when its declaration is in an OS module (Darwin and its submodules, Dispatch, ObjectiveC, the SDK's frameworks, …) or in one of the package's C shim targets. The `#if` evaluation then says which other platforms compile the same line.
   - On other lines, lexical rules decide, in order. A name qualified by an OS or shim module (`Glibc.SOCK_CLOEXEC`, `CNIOLinux.epoll_create`) counts, as does one named by a scoped import (`import func WinSDK.inet_ntop`) or declared by a shim header. Otherwise, a name bound in an enclosing scope, declared by the package on the same platforms, or declared at top level by the Swift libraries or the dependencies doesn't count. A name the Darwin SDK declares counts. Inside an extension of an OS type, a name declared nowhere is that type's member. Anything left is *unresolved*: declared nowhere the package can see, so presumed to come from the platform's C library.
   - The lexical rules also run on the lines the Darwin build compiled, and are compared with the index there.
6. **Follow the dependencies.** `scripts/deps.py` works out which dependency symbols reach an OS function, directly or through other dependency code, and counts the package's lines that use them.
7. **Check.** `scripts/check.py` checks `mapping.ini` against the extraction and System's API and writes `coverage.json`. Every extracted interface must be in exactly one entry. Every System declaration an entry cites must exist in its scope on the tip. An entry's status holds on a platform only where one of its declarations compiles.
8. **Report.** `scripts/report.py` writes the package's `COVERAGE.md`, and `scripts/combine.py` the combined report over every package in the output directory.

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
4. **Build an export of each package in a scratch directory, and cache the index dump by commit, compiler, build settings and index reader; delete the build once it's read.** The checkouts stay read-only, a rerun against a new System tip costs seconds, and a run needs only the largest package's build on disk at once (SwiftPM's full debug build is 6 GB).
   *Rejected:* building in the checkout; rebuilding on every run; keeping the builds, which the tool never reuses (a new commit is exported afresh).
5. **Build as the manifest says, against released swift-system.** Extraction is about what the package uses, and it shouldn't depend on whether it compiles against `system-next`, which is the adoption question. Where the manifest's default build can't run here, the package file says what changes and why: SwiftPM builds its library targets only (`:libraries`), Subprocess raises its deployment target to macOS 26 for `Span.bytes`, Foundation raises the manifest's type-checker limit and builds with a newer compiler.
   *Rejected:* pointing the packages' swift-system dependency at this repository.
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
13. **Cite System API by declaration text in its scope**, matched after dropping attributes, access modifiers and layout. A reader can review it, and the check catches signature changes that adoption has to know about, such as `throws` to `throws(Errno)`.
    *Rejected:*
    - USRs: opaque to a reader.
    - Names with argument labels only: signature changes pass silently.
14. **Derive each entry's per-platform status from where its cited declarations compile**, per api-delta's scan of the tip, less the platforms an `@available(<platform>, unavailable)` takes away.
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

### Blind spots

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

### Outputs

| Path | What |
|---|---|
| `COVERAGE.md` | This report. |
| `coverage.json` | The check's data: entries with per-platform status and matched declarations, the problems, the summaries, the gap ranking. |
| `interfaces.json` | The extraction: every interface with all of its sites, the cross-check, the dependency measure, and the scanned files' function spans. |
| `meta.json` | Commits, date, host, the compiler, and the index dump's key. |
| `logs/` | The package's build log and its `swift package describe` and `dump-package` output. |
| `../system-api.json` | api-delta's scan of System's public declarations on the tip. |
| `../COVERAGE.md`, `../coverage.json` | The combined report over every package in the output directory. |
