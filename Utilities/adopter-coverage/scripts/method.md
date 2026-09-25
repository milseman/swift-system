### Pipeline

`Utilities/adopter-coverage/check.sh` runs every step, and `scripts/package.sh` the steps for one package. It works in a scratch directory (`ADOPTER_COVERAGE_WORK`, default `.build/adopter-coverage-work`) and replaces a package's output directory (in `ADOPTER_COVERAGE_OUT`, default `.build/adopter-coverage`) only when every step has run. It never touches tracked files, here or in the package's checkout.

1. **Export and build NIO.** `git archive` exports `NIO_REF` from `NIO_PATH`, and `swift build` builds the export in debug, which on macOS writes an index store. The build resolves NIO's dependencies as its manifest says, released swift-system included. The build and its index are kept, keyed by NIO commit, so a rerun against a new System tip skips this step.
2. **Read the index.** `scripts/indexstore.py` reads the store through the toolchain's `libIndexStore.dylib` with ctypes. It dumps every reference from NIO's sources, Swift and C alike, with the declaring module and file of each referenced symbol, and the names each module declares.
3. **Scan NIO.** `scripts/swift_scan.py` and `scripts/c_scan.py` scan each file of NIO's library targets. They work out, line by line, which platforms compile the line (`scripts/platforms.py`), and list the identifiers that could name an OS symbol.
4. **Extract.** `scripts/extract.py` combines the two into `nio-interfaces.json`: every OS or C-library interface, with its sites (file, line, target, platforms, conditions) and how each was found.
   - On lines the Darwin build compiled, the index decides. The compiler resolved every reference there, so a symbol counts when its declaration is in an OS module (Darwin and its submodules, Dispatch, ObjectiveC, …) or in one of NIO's C shim targets. The `#if` evaluation then says which other platforms compile the same line.
   - On other lines, lexical rules decide, in order. A name qualified by an OS or shim module (`Glibc.SOCK_CLOEXEC`, `CNIOLinux.epoll_create`) counts, as does one named by a scoped import (`import func WinSDK.inet_ntop`) or declared by a NIO shim header. Otherwise, a name bound in an enclosing scope, declared by NIO on the same platforms, or declared at top level by the Swift libraries doesn't count. A name the Darwin SDK declares counts. Anything left is *unresolved*: declared nowhere NIO can see, so presumed to come from the platform's C library.
   - The lexical rules also run on the lines the Darwin build compiled, and are compared with the index there.
5. **Scan System.** `git archive` exports `SYSTEM_REF`'s `Sources`, and api-delta's `scan_sources.py` lists its public declarations with the platforms that compile each.
6. **Check.** `scripts/check.py` checks `mapping.ini` against both and writes `coverage.json`. Every extracted interface must be in exactly one entry. Every System declaration an entry cites must exist in its scope on the tip. An entry's status holds on a platform only where one of its declarations compiles.
7. **Report.** `scripts/report.py` writes this file.

### Design decisions

Each is listed with the alternative it rejected.

1. **Compiler-backed on Darwin, lexical elsewhere, and the lexical rules measured against the compiler.** The index store is the compiler's own resolution of every name, for Swift and C. It covers only what the macOS build compiles, so Linux-, Windows- and WASI-only code needs lexical rules, and running both on the macOS code gives those rules an error rate.
   *Rejected:*
   - Lexical rules alone: nothing would check them.
   - `swiftc -dump-parse -target <triple>`: in Swift 6.2 its output omits everything inside `#if`, so it can't show another platform's code.
   - Cross-compiling NIO: no Linux, Windows or WASI SDK is installed (`swift sdk list` is empty).
   - A swift-syntax tool (SwiftIfConfig, SwiftLexicalLookup): a network dependency and a multi-minute build, and it still resolves no imported names.
2. **Build an export of NIO in a scratch directory, and cache the build by NIO commit.** The checkout stays read-only. A rerun against a new System tip, the common case, costs seconds.
   *Rejected:* building in `NIO_PATH`, which would write `Package.resolved` and `.build` into it; and rebuilding on every run.
3. **Build NIO as its manifest says, against released swift-system.** Extraction is about what NIO uses, and it shouldn't depend on whether NIO compiles against `system-next`, which is the adoption question.
   *Rejected:* pointing NIO's swift-system dependency at this repository.
4. **One interface per C name.** Struct fields fold into their struct, Swift overlay members into their type (DispatchQueue.async into DispatchQueue), and a C function Swift renames keeps its C name (`DispatchGroup.enter()` is `dispatch_group_enter`). A name used as both a function and a struct, like `stat`, is one interface.
   *Rejected:* one per USR, which splits a C declaration from the Swift accessors and overlays that mean the same thing, and splits a symbol by platform.
5. **A three-valued `#if` evaluation.** A line is active on a platform, inactive, or active only in some configurations (M). M covers opt-in flags (`SWIFTNIO_USE_IO_URING`), debug-only code (`DEBUG`, `ENABLE_MOCKING`), secondary architectures, and C macros the SDK headers define (`UDP_SEGMENT`). M lines count, and the report names their conditions.
   *Rejected:*
   - One fixed configuration per platform, which would drop the io_uring backend and the 32-bit branches.
   - Treating unknown conditions as false.
6. **Drop references the index attributes to a line without the name being written there.** In Swift these come through a typealias; the alias declaration is recorded where it's written. In C they come from a macro's expansion. NIO's own macros are kept (CNIOAtomics' `MAKE(type)` expands to C11 atomics), and an SDK macro's internals are dropped (`CMSG_DATA` expands to `__DARWIN_ALIGN32`).
   *Rejected:* keeping them, which lists SDK implementation details as NIO interfaces.
7. **The mapping is an INI file read by Python's configparser.** It allows comments, multi-line notes and lists of declarations, and diffs cleanly.
   *Rejected:*
   - JSON: no comments, and hand edits break on commas.
   - TOML: `tomllib` needs Python 3.11, and macOS ships 3.9.
   - A Markdown table: it can't hold multi-line fields.
8. **Cite System API by declaration text in its scope**, matched after dropping attributes, access modifiers and layout. A reader can review it, and the check catches signature changes that adoption has to know about, such as `throws` to `throws(Errno)`.
   *Rejected:*
   - USRs: opaque to a reader.
   - Names with argument labels only: signature changes pass silently.
9. **Derive each entry's per-platform status from where its cited declarations compile**, per api-delta's scan of the tip.
   *Rejected:* hand-kept per-platform statuses, which go stale as System gains platforms.
10. **"Covered" allows differences of convention; "partial" means lost capability.** Every NIO wrapper turns errors into `IOError` and EAGAIN into `.wouldBlock`, where System throws `Errno`; that's an adapter of a few lines, not a gap. Partial is kept for a missing flag or option, lost partial-progress information, a forced copy or allocation, or a platform the API skips.
    *Rejected:* marking every wrapper partial for NIO's error conventions, which would bury the real gaps under one label.
11. **Rank gaps by the NIO code System API would let NIO delete.** That's the code lines of thin wrapper functions (up to 40 lines) in NIO's syscall-layer files (listed in `mapping.ini`), plus the C shim definitions an entry would retire.
    *Rejected:* ranking by call-site count, which measures how often NIO uses an interface rather than what it could delete.
12. **Reuse api-delta's source scanner** for System's API, and its comment and string blanker for NIO's Swift.
    *Rejected:*
    - Symbol graphs: macOS only, and a second build.
    - A copy of the scanner: it would drift from the original.
13. **Leave out Foundation, the Swift libraries and NIO's package dependencies; check System API NIO already calls.** Foundation isn't an OS interface; NIO's `*FoundationCompat` targets exist to bridge its types. NIOFS's SystemPackage references are looked up on the tip, since adoption needs them to keep working.
    *Rejected:* listing Foundation, and ignoring existing System uses.

### Blind spots

- **Darwin means one build**: macOS, arm64, debug, Swift 6.2. Code only for iOS, tvOS, watchOS or visionOS is evaluated as inactive. x86_64-only and release-only code is M: lexical, not indexed.
- **The lexical rules** miss or over-count where a scanner can't follow Swift:
  - Members inherited from types outside NIO. A C-named member of a library protocol called unqualified reads as a C call, though the library-vocabulary filter catches most of these.
  - Declaration order: a binding hides a name throughout its scope.
  - Type inference: a C name reached only through a NIO typealias on Linux is attributed to the typealias.
  - Names that exist only off Darwin and coincide with a NIO or library declaration are dropped. `_read` and `_write` on Windows survive only because nothing else declares them at top level.
- **C code** gets no macro expansion beyond NIO's own token-pasting macros, and no header contents, so SDK-defined macros decide `#if` branches only as M. The index also misses some macros from textual headers (`assert`), which the C scan adds back.
- **Kinds** of lexically found names are guessed from the Darwin SDK's declaration of the same name or from their spelling.
- **Platform models**: `canImport` answers are fixed per platform (FreeBSD and OpenBSD import `Glibc`, Android has `Android` and `Bionic`, WASI is single-threaded), and a wrong model misattributes sites. A target that reaches `#error` on a platform is treated as not building there (NIOPosix on FreeBSD).
- **Sites** count source lines, so NIOFS and its twin _NIOFileSystem count twice, and a generic helper called from many places counts once.
- **System's side** is api-delta's lexical scan. It loses some scopes (IORing's members appear at the top level), which the check tolerates by accepting a top-level match and marking it.
- **Out of scope:** NIO's tests, examples, benchmarks and snippets. Code reached only at runtime (`dlsym` lookups, environment variables) shows up only as the call that reaches it.

### Outputs

| Path | What |
|---|---|
| `COVERAGE.md` | This report. |
| `coverage.json` | The check's data: entries with per-platform status and matched declarations, the problems, the summaries, the gap ranking. |
| `nio-interfaces.json` | The extraction: every interface with all of its sites, the cross-check, and the scanned files' function spans. |
| `system-api.json` | api-delta's scan of System's public declarations on the tip. |
| `meta.json` | Commits, date, host and toolchain. |
| `logs/` | NIO's build log and its `swift package describe` and `dump-package` output. |
