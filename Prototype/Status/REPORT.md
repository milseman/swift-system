# The coverage lane: status and gaps

The `coverage` worktree keeps the project's figures current (`Utilities/adopter-coverage/status.sh`, which
writes `STATUS.md` here) and adds the System API that adopters still mark as missing. Each section records
one step: what was done, the design calls with the alternative each rejected, and the checks. Linux is paused:
everything here is built and tested on Darwin only.

## Queue

The work list for packages to drop `import Darwin` in every form, kept current. Source: the ecosystem report's
*What the files that import Darwin still need* (section 25), which counts the interfaces that library files
importing Darwin in any form but through Apple Foundation's re-export use, per symbol, with System's coverage on
Darwin; grouped here into clusters and ranked by packages, then call sites. `ecosystem.sh report` writes it for the
toolchain's packages, and `ecosystem.sh --popular report` for popular.tsv's (section 37). Counts are in the runs'
reports and in STATUS.md, not here.

**Resume here** (coverage-4, worktree `../coverage-4`, from system-next `bb950db`; stopped 2026-10-01, done; STATUS.md
regenerated at the stop, section 52). Its brief, rows C1 to C4, and what they leave for others:

| # | Item | State |
|---|---|---|
| C1 | STATUS.md section 4 per platform, each adopter at its newest migration branch | done (section 49, `30007dd`) |
| C2 | Section 1: the symbols the built SystemPackage exports, and the added declarations that export one only to forward a C value | done (section 50, `c7b71cc`); a need for the Threads owner (its finding 2) |
| C3 | windows-2's patch P3, the Win32 sources in `Sources/System/CMakeLists.txt` | done (section 48, `8caa741`) |
| C4 | A `_SystemPackageForPlugin` product (O2 below) | done (section 51, `79ee4f7`), with a link under Sources/ |
| N1 | `Threads/PThreadReadWriteLock.swift`'s platform import block, which a library-evolution build needs (section 50, finding 2) | the Threads owner's file |
| N2 | SystemSockets' forwarding declarations without `@_alwaysEmitIntoClient` (STATUS.md section 1's list) | Michael's call; the sockets owner's files |
| N3 | sourcekit-lsp's and swift-tools-protocols' plugin copies on `_SystemPackageForPlugin`, with `-module-alias SystemPackage=_SystemPackageForPlugin` (section 51) | the adopters' lanes |

coverage-3 stopped 2026-09-30, done: section 40's rows are all closed (sections 41 to 43), both queues are empty and
popular.tsv needs no fourth batch (section 44), the `_version: 346` gates stay (section 45),
`Utilities/linux/build.sh --quiet` exists (section 46), and STATUS.md's section 4 tracks the platform imports
(section 47). Open from it:

| # | Item | State |
|---|---|---|
| O1 | Linux, Windows and WASI builds of sections 42 and 43's API: `CInterop.Offset` everywhere, PIPE_BUF and cancellation off Darwin | unbuilt; `Utilities/linux/build.sh --quiet test` when the container service runs |
| O2 | A `_SystemPackageForPlugin` product for sourcekit-lsp's plugins (the packages-5 lane's ask) | done: coverage-4's C4 (section 51) |
| O3 | A join that tells a cancelled thread from one that returned (section 43) | open |
| O4 | Why Foundation's build ignores `_version` (section 45) | open, Foundation's |
| O5 | A fourth popular batch | not needed now (section 44); the alternative is there |

sqlite-nio's extraction takes minutes on each run, scanning its vendored SQLite; a `skip.CSQLite` would speed runs,
but would drop SQLite's OS use from the package's table.

Left for Michael: this worktree's `.build` is deleted, but the permission classifier refused the deletion of the
lane's files in the temporary directory (`/var/folders/8l/z1y20ccj5g1087mk50sbcznr0000gn/T/`): SwiftPM's
`_Users_milseman_development_base_dir_system-next_coverage-3_*.lock` files from check.sh's package builds, and
`coverage-3-baseline.log` and `coverage-3-after.log`, the test runs' logs.

The toolchain's queue has been empty since run `a3a634eb2b19-06a7ddd5` (section 37), and popular.tsv's three
batches' queues since sections 38, 39 and 44. What follows is the toolchain's work, all done.

Ahead of the ranked clusters, the adopters' own asks (Michael, 2026-09-29), in this order:

| # | Ask | For | Plan |
|---|---|---|---|
| A1 | A public name for C's `struct dirent`: a CInterop alias with Swift-named accessors (decision 84) | TSC's public `extension dirent { var name }` (TSCBasic/FileSystem.swift:19) | done: `CInterop.DirectoryEntry` (section 34) |
| A2 | A call that returns and clears the dynamic loader's pending error (dlerror) | TSC's deprecated public `dlerror()` (TSCUtility/dlopen.swift:20) | done: `DynamicLibrary.takePendingError()` (section 34) |
| A3 | C-string argument and environment overloads of the C-values spawn and its `credentials:` form | Subprocess+Darwin.swift:618 | done (section 29) |
| A4 | Adding a SpawnFileAction to C file actions that other code built (`inout CInterop.SpawnFileActions`) | Subprocess's configurator test (DarwinTests.swift:15-20) | done: `SpawnFileAction.add(to:)` (section 34) |
| A5 | A DirectoryWalk option that opens a directory's stream when the walk goes into it, not when it reads the directory's entry; section 14's two corrections (on APFS an unreadable entry still has a type; fts's FTS_DNR also covers paths of PATH_MAX bytes or more) | Foundation's copy and link (its REPORT.md, "fts for copy and link: tried, kept") | done: `opening: .whenEntered`, corrections (section 35); one descriptor per level kept, a known difference |

status.sh's `STILL_NEEDED` (section 34) counts an interface that System names as missing while a marker asks for more;
dirent, dlerror and posix_spawn_file_actions_addchdir_np were, until A1, A2 and A4 landed.

| # | Cluster | Packages | Sites | Interfaces | Plan |
|---|---|---:|---:|---|---|
| 1 | string.h and ctype.h | 9 | 60 | strdup (7 packages), strlen, strnlen, strncmp, strlcpy, tolower, isspace | done: `CString` and `CType` (section 26) |
| 2 | C stdio beyond FileStream | 5 | 12 | fputs, perror, putc, snprintf | done: FileStream's write(cString:) and write(byte:), mapping (section 27) |
| 3 | Sockets | 4 | 104 | sockaddr_storage, inet_pton, freeaddrinfo, INADDR_ANY, NI_MAXHOST, NIO's options, nfds_t, AF_VSOCK | done: ExplicitCongestionNotification, docs, mapping (section 28) |
| 4 | C scalar types | 4 | 7 | suseconds_t, u_int, LONG_MAX, _POSIX_ARG_MAX | done: `guaranteedArgumentBytes`, `swift` answers (section 30) |
| 5 | File times | 4 | 5 | futimens, utimes | done: setTimes' sentences, `same.` (section 30) |
| 6 | Mach | 3 | 24 | mach_task_self_, KERN_SUCCESS, ERR_SUCCESS, vm_address_t, task_info with TASK_VM_INFO | done: docs, [task_info] (section 31); swift-build's own vm_prot_t and USEC_PER_SEC stay listed |
| 7 | ioctl | 3 | 3 | ioctl (terminal size, vsock CID) | done: both requests are System's (section 28) |
| 8 | MacTypes | 2 | 12 | OSStatus, UniChar, DarwinBoolean | done: `swift` answers (section 31) |
| 9 | sysctl process information | 2 | 9 | kinfo_proc's fields, P_TRACED, extern_proc | done: `CInterop.KernelProcessInfo` (section 31) |
| 10 | pthreads | 2 | 8 | pthread_attr_getstacksize, setdetachstate, setscope, PTHREAD_CREATE_DETACHED, PTHREAD_SCOPE_SYSTEM, pthread_exit, pthread_yield_np, the error-checking initializer | done: exit(), defaultStackSize(), static initializers, mapping (section 32) |
| 11 | Signals | 2 | 7 | signal, SIG_ERR, SIG_UNBLOCK, sigprocmask, NSIG | done: docs, mapping (section 33) |
| 12 | Spawn attributes | 2 | 6 | posix_spawnattr_setpgroup, setsigdefault, setsigmask | done: docs (section 33) |
| 13 | Mounts and quotas | 2 | 6 | getfsstat, quotactl, SUBCMDMASK, SUBCMDSHIFT, getmntinfo_r_np | done: docs, mapping (section 33) |
| 14 | Extended attribute names | 2 | 4 | XATTR_FINDERINFO_NAME, XATTR_RESOURCEFORK_NAME | done: `ExtendedAttributeName` (section 33) |
| 15 | CPU types | 1 | 22 | cpu_type_t, cpu_subtype_t, CPU_TYPE_*, CPU_ARCH_ABI64 (swift-build) | done: `Mach.CPUType`, `CPUSubtype` (section 36) |
| 16 | wait | 1 | 17 | siginfo_t, id_t, idtype_t, CLD_*, waitid (Subprocess) | done: enum cases' docs read, [wait] (section 36) |
| 17 | One-package gaps | 1 each | 1-3 each | dladdr and Dl_info, backtrace, strtod and strtof, AT_FDONLY and AT_REALDEV, sysdir's enumeration state, getiopolicy_np, ATTR_BIT_MAP_COUNT, execv, getdtablesize | done (section 36) |

Not counted, with the reason: the lexical scan's false positives (`index(after:)` read as strings.h's index;
Float80) and other modules' names it can't place (Logger, NSDictionary, CFRunLoopStop), which mapping.ini should
say; the standard library's answers (off_t, ssize_t, size_t and uintptr_t are Int64, Int, UInt; memcpy, memmove,
memset; round, sqrt, ceil, floor, fabs, modf); Dispatch and ObjectiveC names; the packages' own C shims
(CNIODarwin_*, c_nio_posix_*, _subprocess_*).

Done: step 0, what the tools couldn't see (section 25); clusters 1 (section 26), 2 (section 27), 3 and 7 (section 28), 4 and 5 (section 30), 6, 8 and 9 (section 31), 10 (section 32), 11 to 14 (section 33), the asks A1 to A5 (sections 34 and 35), 15 to 17 (section 36); and Subprocess's new marker, C arrays for the C-values spawns (section 29). New SYSTEM-GAP markers in `../adopters` come first: status.sh lists them.

## 1. status.sh and STATUS.md (2026-09-28)

`Utilities/adopter-coverage/status.sh` regenerates `STATUS.md` from commits: api-delta's Summary and *By
area* table (main → HEAD), a row per adopter in `../adopters` on `migrate-darwin` against its merge base with
`main`, and every `SYSTEM-GAP:` marker by interface, ranked and marked missing, covered, or not System's. The
logic is `scripts/status.py`; its METHOD text is also STATUS.md's last section. A run takes about 10 s when
api-delta's last run is current and about 80 s when System's sources changed; a package commit whose
manifest hasn't been seen adds a few seconds.

Design calls:
- **Reuse over new extraction.** API figures are api-delta's own report, copied; `#if` evaluation is
  adopter-coverage's `platforms.py`, comments and strings are blanked by api-delta's scanner, and the SDK
  vocabulary check.sh stored places names in C-library modules. Rejected: check.sh's compiler-backed Darwin
  metric, which needs a build of every package commit and knows only its four audited packages.
- **Package targets from the manifest.** `swift package dump-package` on the manifests at each commit, cached
  by their blob ids, with SwiftPM's default target paths. Swift 6.2 can't type-check swift-foundation's
  manifest in reasonable time, so installed toolchains are tried after the default one (the 2026-09-21
  snapshot evaluates it). Rejected: counting every tracked file (nested packages, Benchmarks, integration
  scaffolding), or only `Sources/` and `Tests/` (kept as the fallback when no toolchain evaluates the manifest).
- **Four import columns, not two.** `import Darwin.POSIX.sys.stat` is neither whole-module nor scoped, and
  NIO's report counts it as not whole-module, so submodule imports get their own column; a file is counted
  once, by its broadest import. Framework-only imports (`#if FOUNDATION_FRAMEWORK`) are counted separately.
- **Markers are read for the interfaces they name.** A marker's head (before its first sentence end, or a
  colon not followed by a list) is split into items; an item names itself, the list after a phrase (`libm
  (sin, cos)`), `X members` for MemberImportVisibility struct gaps, and so on (METHOD has the rules). A marker
  that names nothing is counted under its phrase, and the scoped imports under it decide its status; with
  none, it's *unread* (one now). Rejected: an SDK vocabulary alone (the explanations are English, and `time`,
  `free`, `sleep`, `remove` are C functions), and the imports alone (`import struct Darwin.msghdr` is there
  for msghdr's fields, which CInterop's alias doesn't give).
- **Covered is what System documents.** A doc comment's *The corresponding C … is* names, public typealias
  targets, and `extension CInterop.<alias>` for struct members, at HEAD and at `system-next` (the table says
  when only this branch has an interface). A short table of replacements (usleep and sleep by nanosleep,
  localtime by localtime_r, mkstemp by mkostemp, time by clock_gettime) counts the obsolescent forms as covered.
  Rejected: mapping.ini's entries, which group symbols by concept but don't say usleep is nanosleep's.
- **Not System's**, fixed in `status.py` with reasons: libm, C stdio, locale and xlocale, string.h and ctype.h
  (memcpy, memmove, memset are the standard library's copyMemory and initializeMemory; memcmp and memchr are
  System's Memory, as the malloc lane decided), numeric conversion, and the Darwin overlay's POSIXErrorCode.
- **Copies are verbatim and few.** Only the test totals (the start and latest lines, with a table's header)
  and the re-export counts are copied from MIGRATION.md or REPORT.md, quoted with line numbers; a report whose
  lines don't match the patterns shows —.

First run, at `ebc1231` with 10 adopters: 142 markers in 96 files, 175 interfaces: 85 covered (the markers
predate the lanes that merged since), 23 not System's, 66 missing, 1 unread. The missing ones by family,
largest first: compile-time limits (5 files), fts (3), XATTR_MAXNAMELEN, UTIME_OMIT, posix_spawn's raw
attributes and file actions, tzfile.h (2 each), then one-file gaps (malloc_type_*, time_t, dlerror,
mkstemps, nfds_t, O_SEARCH, removefile, timeval, EX_USAGE, mktemp, AF_VSOCK).

Limits: name matching can't see an API whose doc comments don't name the C interface (System's `nil` file
time is UTIME_OMIT, undocumented), and counts a partial wrapper as covered (`linger` is named by
`SocketDescriptor.linger()`, but NIO's public API needs the C type).

## 2. CInterop.TimeVal and CInterop.Linger: `0e1defa`

NIO's SocketOptionProvider takes and returns C `timeval` and `linger` values in its public API, so it keeps
Darwin imports until System names them and makes them usable without the C library.

- `CInterop.TimeVal` (SystemPackage, next to TimeSpec) copies TimeSpec's shape: `init(seconds:microseconds:)`
  with zero defaults (the zero value too), `seconds`, `microseconds`, and from macOS 13 `init(duration:)` and
  `duration`, normalized and rounded down to a microsecond. Rejected: rounding up, as the socket timeouts and
  ProcessTimer do internally so that a positive time never becomes C's "none"; the general conversion
  matches TimeSpec's, and its doc points out the zero case.
- `CInterop.Linger` (SystemSockets) has `init(isEnabled:time:)`, `isEnabled` and `time`. Rejected names:
  `seconds` (Darwin's `SO_LINGER` counts clock ticks; only `SO_LINGER_SEC` is seconds) and `timeout` (reads
  as a Duration, and as a failure). SocketDescriptor's `linger()` now uses the alias; the internal `_CLinger`
  it replaced is gone.

Tests: accessors against the C fields, the duration conversions, a `CInterop.Linger` through
`setOption`/`getOption` on a TCP socket agreeing with `linger()`, and both in the MemberImportVisibility
probe. XCTest 471 (4 skipped), swift-testing 437 in 65 suites, all passing.

## 3. Compile-time limits and O_SEARCH: `040169c`

Foundation's gaps with the most files (5): NAME_MAX, PATH_MAX and MAXSYMLINKS as compile-time constants, for
buffers sized before there's a path to ask `pathconf` about; and O_SEARCH for directory descriptors.

- `SystemConfig.maxFileNameBytes`, `maxPathBytes`, and on Darwin `maxSymbolicLinks`, as `Int`s. They reuse the
  names of the `pathconf` names in `SystemConfig.PathName`, so `value(.maxFileNameBytes, for: dir)` is the
  directory's limit and `SystemConfig.maxFileNameBytes` the headers'. Rejected: `FilePath` members (a path
  can be longer; calls fail with ENAMETOOLONG) and a new namespace. `maxSymbolicLinks` is Darwin-only:
  glibc's MAXSYMLINKS (20) isn't the Linux kernel's limit (40).
- `FileDescriptor.AccessMode.search` and `.execute`, Darwin-only, with the renamed `O_SEARCH`/`O_EXEC` stubs.
  Darwin's O_EXEC is outside O_ACCMODE's bits and F_GETFL reports it for both modes, so Darwin's internal
  access-mode mask now includes it: `accessMode()` returns `.execute` for either (it said `.readOnly`), and
  `statusFlags()` drops the stray bit. Rejected: leaving the mask alone, which misreports every such
  descriptor; a separate `.search` from `accessMode()`, which F_GETFL can't tell apart.

Found on macOS 26.3: O_SEARCH opens only directories (ENOTDIR); its descriptor reads fail (EBADF) but
`openat`, `fchdir` and `fstat` work; O_EXEC needs execute permission (EACCES); a path resolves through 32
links and fails on the 33rd, counting links in the path itself (the temporary directory's `/var`), so the test
opens its chains relative to a directory descriptor.

Tests: CompileTimeLimitsTest, SearchAccessModeTest. XCTest 478 (4 skipped), swift-testing 437, all passing.

## 4. Exit codes: `7416b21`, `d630505`

swift-argument-parser imports Darwin for `EX_USAGE`, the code its validation failures exit with.

- `ProcessID.ExitCode`, a `RawRepresentable` over `CInt`: `.success` and `.failure` (EXIT_SUCCESS,
  EXIT_FAILURE; EX_OK is `.success`) and the fifteen `<sysexits.h>` codes (64 through 78) under Swift names
  (`usageError`, `dataError`, `cannotOpenInput`, `unknownUser`, `unknownHost`, `serviceUnavailable`,
  `internalError`, `systemError`, `systemFileError`, `cannotCreateOutput`, `ioError`, `temporaryFailure`,
  `protocolError`, `permissionDenied`, `configurationError`), each with its renamed `EX_*` stub; the
  description is the name and number. `ProcessID.exit(_:)` and `exitImmediately(_:)` gained overloads that
  take one.
- Nested in `ProcessID`, next to `exit(_:)`. Rejected: a top-level `ExitCode`, which ArgumentParser has
  (public), and which System's own samples use, so every file importing both would be ambiguous; and constants
  without a type, which `exit(_:)` couldn't take.
- The overloads make DocC's `exit(_:)` links ambiguous, so ProcessExit.swift's now say ``exit(_:)-(CInt)``;
  DocC 6.2 wants the nested type qualified (``exit(_:)-(ProcessID.ExitCode)``), which `d630505` fixed after
  api-delta's DocC diagnostics showed it.
- The sysexits codes are off on WASI, whose libc may lack `<sysexits.h>`.

Tests: ExitCodeTests (values against the C constants, descriptions, exit tests of both overloads). XCTest 478
(4 skipped), swift-testing 441 in 66 suites. One full run failed PThreadTests' `setCurrentQualityOfService`,
whose background-QoS thread didn't run within 10 s with the machine's load average near 65; it passed alone
three times and in the full rerun. It isn't this lane's.

## 5. removefile: `a545dcc`, `b514cb4`, `819d780`

Foundation's `FileManager.removeItem` calls removefile with confirm and error callbacks for its delegate, and
reaches `<removefile.h>` through `_FoundationCShims`, since the Darwin module doesn't declare it. CSystem's
Darwin header now includes it, as it does `<sys/random.h>`.

- `FilePath.removeRecursively(options:)`, with static C-string and `relativeTo:` (removefileat) forms. It
  always passes `REMOVEFILE_RECURSIVE`, and is named for it: without it removefile leaves every directory in
  place, even an empty one, and returns success. Rejected: `remove(options:)` next to `remove()` (remove(3)),
  which would make `[]` a silent no-op on directories.
- `RemoveOptions`: `keepDirectory` (KEEP_PARENT), `crossMountPoints`, `allowLongPaths` (documented as changing
  the process's working directory for the call). Rejected: the `SECURE_*` overwrite passes (they can't reach old
  blocks on APFS or an SSD) and the undocumented CLEAR_PURGEABLE, SYSTEM_DISCARDED and RECURSIVE_SLIM.
- `removeRecursively(options:progress:)` takes a non-escaping handler, as FileCopy's progress does:
  `RemoveProgress` (stage `.start`/`.finish`/`.error` from the confirm/status/error callbacks, the path, the
  error) → `.proceed`/`.skip`/`.stop`. removefile *succeeds* when a callback stops it anywhere but at an error,
  so a stop throws `Errno.canceled`, or the error it stopped at. Rejected: FileCopy's rule that a stop always
  throws `.canceled`, which would make Foundation's delegate path capture the error itself, as it does today.
- No `retryOnInterrupt`: calling it again removes what's left.
- `b514cb4` and `819d780` name `removefile_flags_t`, `removefile_state_t`, its four calls and its context keys in
  the doc comments, in the standard *corresponding C* phrasing, which status.sh and adopter-coverage read.

Found on macOS 26.3: callbacks get absolute real paths (`/private/var` for `/var`, relative paths from the
root); confirm runs before each file and status after, depth first; skipping a file makes its directory fail
with ENOTEMPTY; a link is removed, not its target; an invalid callback result acts as a skip.

Tests: RemoveRecursivelyTest. XCTest 489 (4 skipped), swift-testing 441 in 66 suites, all passing.

## 6. Memory locking: `e9198ce`

The posix-darwin lane's unstarted cluster 6.

- `Memory.lockPages(_:)` and `unlockPages(_:)` (mlock, munlock) take any `UnsafeRawBufferPointer`, in the malloc
  lane's `Memory` namespace; `MemoryMapping.lockPages(range:)` and `unlockPages(range:)` take offsets, like its
  `setProtection(_:range:)`. Named for pages: the system locks every page a buffer touches, and a bare `lock`
  reads as a mutex's.
- `Memory.lockAllPages(_:)` with `PageLockOptions` (`.current`, `.future`, Linux's `.onFault`) and
  `unlockAllPages()` exist everywhere but Darwin, where mlockall and munlockall always fail with ENOSYS.
  Rejected: declaring them on Darwin too, as an API that can only throw. That code is unbuilt (Linux paused).
- No `retryOnInterrupt`: the calls don't report EINTR.

Found on macOS 26.3: RLIMIT_MEMLOCK is unlimited; ranges round out to pages; locking faults every page in (4 GiB
took 0.7 s) and unlocking leaves them resident; unmapped memory fails with ENOMEM; PROT_NONE pages lock.

Tests: MemoryLockingTest. XCTest 494 (4 skipped), swift-testing 441. One full run failed SocketOpenOptionsTests'
`acceptSetsExactlyTheOptions` with EAGAIN (a nonblocking accept racing the connection it expects, at a load
average near 66); it passed alone three times and in the full rerun. It isn't this lane's.

## 7. The not-System's families are in scope

Michael's call (2026-09-28): what status.sh marked *not System's* (libm, C stdio, locale, string.h and ctype.h,
the Darwin overlay's POSIXErrorCode) is in scope. System wraps those families provisionally, in
`Sources/System/Provisional/` files named for them, each with a note that it may move to the standard library;
POSIXErrorCode gets a CInterop typealias. status.sh now counts them as missing until covered, like everything
else: the *not System's* status and section are gone, the families are marked *(provisional)* in the work
list, and the reasons they were set apart move to the provisional files' notes. A covered name keeps its own
family (memcmp is System's `Memory`), and a phrase interface takes its names' family, so TSC's "C stdio FILE
streams" joins C stdio.

The work list then, by files affected: C stdio (5 files: swift-log, swift-nio, swift-tools-support-core),
POSIXErrorCode (3), then two files each for XATTR_MAXNAMELEN, UTIME_OMIT, fts, libm, locale, posix_spawn's raw
attributes and tzfile.h, and one-file gaps. The order from here: C stdio, POSIXErrorCode, the remaining early
items (shared memory and named semaphores, os_unfair_lock and arc4random, sync and chroot), then the two-file
families.

## 8. C stdio, provisionally: `768516e`

The first provisional family, and the largest gap (5 files in swift-log, swift-nio, swift-tools-support-core; 4
more in swiftpm by the next run). `Sources/System/Provisional/Provisional+Stdio.swift` holds it; its header says
why it's provisional, and each type's doc notes that it may move to the standard library.

- `CInterop.File` (FILE), for TSC's public `FILEPointer`.
- `FileStream`, a `RawRepresentable` handle over `UnsafeMutablePointer<FILE>`, as FileDescriptor is over an fd:
  the standard streams; `open(_:mode:)` for a path or C string (fopen) and a descriptor (fdopen), with C's mode
  strings; `close()`, `fileDescriptor()`, `write(_:)` (bytes, or a String's UTF-8; a short fwrite throws),
  `read(into:)` (short only at the end), `flush()`, `flushAll()`, `hasError`/`isAtEnd`/`clearError()`,
  `Buffering` with `setBuffering(_:buffer:)` (setvbuf, so `setbuf(stdout, nil)` is
  `setBuffering(.unbuffered)`), and off WASI `lock()`/`unlock()`/`tryLock()`/`withLock(_:)`.
- Rejected: an owner that closes in its deinit (item 54's policy, left open; a handle matches FileDescriptor);
  a typed mode (C's strings are what adopters pass); `retryOnInterrupt` (an interrupted stream call can have
  written part of a buffer); passing C function values as swift-log does (`write: fwrite`), which the handle's
  methods replace. The name avoids Foundation's `Stream`/`OutputStream`; no sister clone declares `FileStream`.
- Mock tests run every fallible call over a placeholder stream address; the calls that can't fail have no hooks.

Tests: ProvisionalStdioTest. XCTest 501 (4 skipped), swift-testing 441, all passing.

## 9. POSIXErrorCode, provisionally: `8a1cc64`

`CInterop.POSIXErrorCode` aliases the Darwin overlay's enum (Darwin only), in
`Sources/System/Provisional/Provisional+POSIXErrorCode.swift`, as Michael asked, so Foundation can name
`POSIXError.Code` without importing Darwin.

Found: the alias alone doesn't reach the enum's members under MemberImportVisibility, which Foundation
enables: its cases, `rawValue` and `init(rawValue:)` still need their defining module (`_DarwinFoundation1` in
the macOS 26 SDK), checked with a client compiled with the feature. So the alias also gets two
System-declared, Swift-named members that such a client can use, `init?(_: Errno)` and `errno`. Rejected:
re-declaring the cases as static members, which would be ambiguous wherever Darwin is imported. Foundation's
static `POSIXError.EPERM`-style properties can then be `CInterop.POSIXErrorCode(.notPermitted)!`.

Tests: ProvisionalPOSIXErrorCodeTests, and the MemberImportVisibility probe. XCTest 501, swift-testing 443 in 67
suites. One full run failed AttributeListTests' `testVolumeAttributes`, which compares a volume's free space from
getattrlist with statfs's a moment later; it fails alone too, two runs in three, while other sessions write to
the disk. It isn't this lane's.

## 10. Shared memory and named semaphores: `be36a44`

The posix-darwin lane's unstarted cluster 7.

- `FileDescriptor.openSharedMemory(named:_:options:permissions:)` and `removeSharedMemory(named:)` (shm_open,
  shm_unlink) reuse FileDescriptor's AccessMode and OpenOptions and, like `open`, trap for `.create` without
  permissions. shm_open is variadic, so CSystem's `csystem_shm_open` passes the mode. Rejected: a SharedMemory
  owner type; the result is a descriptor, which mapping and `resize(to:)` already take.
- `NamedSemaphore`, a handle over `sem_t *` (`CInterop.Semaphore`), with its own OpenOptions (create,
  exclusiveCreate), `open(named:options:permissions:value:)`, `close()`, `remove(named:)`,
  `wait(retryOnInterrupt:)`, `tryWait()` (false for EAGAIN), `post()` and `maxValue`. Rejected: `signal()`,
  DispatchSemaphore's word, which reads as System's `Signal`; an owner closing in its deinit (item 54);
  `sem_init`/`sem_getvalue`, which Darwin lacks (ENOSYS).
- Not on Android (no shm_open or sem_open in bionic); Linux code unbuilt.

Found on macOS 26.3: shm names over 31 bytes fail ENAMETOOLONG; O_TRUNC fails EINVAL; a second ftruncate fails
EINVAL; read/write fail ENXIO; the descriptor is close-on-exec; mappings outlive the name. Reopening a
semaphore's name gives another handle on the same count; sem_post at SEM_VALUE_MAX (32,767) doesn't fail; a
larger initial value fails EINVAL.

Tests: SharedMemoryTest. XCTest 506 (4 skipped), swift-testing 443, all passing.

## 11. os_unfair_lock and arc4random: `83b795d`

The posix-darwin lane's unstarted cluster 8.

- `UnfairLock` (Darwin): a noncopyable lock keeping its `os_unfair_lock` at one heap address, as `PThread.Mutex`
  does its mutex: `lock()`, `tryLock()`, `unlock()` (noasync), `withLock(_:)`, `assertOwned()`, `assertNotOwned()`,
  `init(unsafeAddress:)` for a lock in C memory, and from macOS 15 `lock(options: .adaptiveSpin)`
  (`os_unfair_lock_lock_with_flags`; Swift can't import the flag, so its value is spelled out). Nothing throws.
  Its doc sends value protection to `Synchronization.Mutex` (this lock on Darwin, from macOS 15), pthread kinds,
  process sharing and conditions to `PThread.Mutex`, and notes that `os`'s `OSAllocatedUnfairLock` re-exports
  Darwin. Rejected: a generic lock over a value (Mutex's job); the name `OSUnfairLock`.
- `Entropy.generate()`, `generate(below:)`, `generate(into:)` (arc4random, arc4random_uniform, arc4random_buf),
  on Darwin, FreeBSD, OpenBSD and Android, next to Entropy's throwing getentropy calls. Rejected: a
  `RandomNumberGenerator` type, which `SystemRandomNumberGenerator` already is over the same generator.

Found on macOS 26.3: misusing an unfair lock ends the process with SIGKILL, not a trap; the owner's `tryLock()`
returns false.

Tests: UnfairLockTests, RandomGeneratorTests. XCTest 506, swift-testing 452 in 69 suites, all passing.

## 12. chroot and sync: `87f36ab`

The posix-darwin lane's unstarted cluster 9; truncating a path was already `FilePath.resize(to:)`.

- `FilePath.setRootDirectory(_:retryOnInterrupt:)` (chroot), for a FilePath and a C string, after
  `setCurrentWorkingDirectory` (chdir), retrying on EINTR as path calls do. Its doc: the root is inherited,
  needs privileges (EPERM), and leaves the working directory alone.
- `FileDescriptor.synchronizeAllFileSystems()` (sync), the system-wide `synchronize()`, noting that it can
  return before the writes finish, as Darwin's does; it can't fail. Rejected: a namespace for one call; syncfs,
  Linux-only, until Linux resumes.

That ends the early list: posix-darwin's clusters 6 to 9 are done. Tests: RootAndSyncTest. XCTest 509,
swift-testing 452, all passing.

## 13. UTIME markers and the xattr name limit: `1be2f2b`

NIO's file system module imported Darwin for UTIME_NOW and UTIME_OMIT (the values its public
`FileInfo.Timespec.now`/`.omit` expose) and XATTR_MAXNAMELEN (quoted in its errors).

- `CInterop.TimeSpec.fileTimeNow` and `.fileTimeUnchanged`: the timespecs whose nanoseconds are UTIME_NOW and
  UTIME_OMIT, for code that passes futimens/utimensat their C structures. Rejected: `.now`/`.omit` (read as a
  timestamp and a verb) and bare Int constants.
- `SystemConfig.maxExtendedAttributeNameBytes` (Darwin's XATTR_MAXNAMELEN, 127), with the other compile-time
  limits; Linux's XATTR_NAME_MAX lives in a kernel header the Glibc module lacks.
- `setTimes`' doc comments now name UTIME_OMIT for a nil time, which the API already passed: UTIME_OMIT was
  covered but invisible to name matching (section 1's example).

Tests: the markers through futimens, and 127- and 128-byte attribute names. XCTest 510, swift-testing 453.

## 14. fts, answered by DirectoryWalk: `c37d638`

Foundation's marker is specific: its copy and link keep fts for "each directory's preorder and postorder visits
in one walk (to create it, then to copy its metadata), the root as an entry, and an unreadable directory
(FTS_D, then FTS_DNR) told apart from an entry that can't be stat'ed (FTS_NS)". The Directories lane chose a
walker of System's own over fts (Prototype/Directories/README.md), so this extends DirectoryWalk rather than
wrapping fts, which would reverse that decision.

- `DirectoryWalk.Order.preorderAndPostorder` visits each directory before and after its contents;
  `Entry.isPostorderVisit` marks the second visit (and every directory's visit in a postorder walk). An
  unopenable directory is visited once, with its error; `skipDescendants()` also skips the second visit.
  Rejected: fts's balancing of a skipped directory's visits, which makes callers read past an extra entry.
- The other two needs were there: the caller has the root's path (the walk visits its entries); an unreadable
  directory is an entry with `type == .directory` and an error, an unstat-able one has no type. (Corrected in
  section 35: where a file system records types in its directories, as APFS does, an entry whose status can't be
  read still has its type, since the walk doesn't read the status then, so fts's FTS_NS needs the caller's own
  fstatat; and fts's FTS_DNR also covers a directory whose path is PATH_MAX bytes or longer, which the walk reads.)
- status.py gains `ANSWERED`: fts names count as covered by DirectoryWalk once its two-visit order is in the
  sources, since no *corresponding C* sentence could truthfully name fts.

Tests: DirectoryWalkVisitsTests. XCTest 510, swift-testing 457 in 70 suites (one full run hit the known
`acceptSetsExactlyTheOptions` EAGAIN flake; the rerun passed).

## 15. libm, provisionally: `9166bd5`

Foundation's calendar astronomy (sin, cos, pow) and a test utility (pow, log).
`Sources/System/Provisional/Provisional+Math.swift`: a `Math` namespace of 54 static functions, each for Double
(`sin`) and Float (`sinf`): the trigonometric, hyperbolic, exponential, logarithmic, power (pow, cbrt, hypot),
error and gamma functions. The namespace's doc lists what the standard library already has (squareRoot,
rounded, the remainders, magnitude, minimum/maximum, addingProduct, sign/exponent/significand), which isn't
repeated. Rejected: members of Double and Float, which swift-numerics' RealModule extends with the same names (a
file importing both would be ambiguous); generics over BinaryFloatingPoint, which libm isn't.

Tests: ProvisionalMathTests. XCTest 510, swift-testing 460 in 71 suites (one full run hit the known accept
flake; the rerun passed).

## 16. C locales, provisionally: `63f97d8`

Foundation parses and compares in the POSIX locale (strtod_l, strtof_l, strncasecmp_l, locale_t), and its tests
set the global locale (setlocale, LC_ALL). `Sources/System/Provisional/Provisional+Locale.swift`, Darwin only:

- `CInterop.Locale` (locale_t) and `CLocale`, a handle over `locale_t?`: `.posix` (LC_C_LOCALE) and `.global`
  (LC_GLOBAL_LOCALE); `named(_:categories:base:)` (newlocale) and `free()`; `Category` and `Categories` (the
  LC_*_MASKs, with `.all` for LC_ALL_MASK, which Swift can't import); `globalName(for:)` and `setGlobal(_:for:)`
  (setlocale); `parseDouble`, `parseFloat` (value and bytes taken) and `compareIgnoringCase(_:_:maxByteCount:)`.
  Rejected: the name `Locale` (Foundation's); a Swift `String` API, which Foundation's C-string callers don't
  want.
- Found: in the macOS 26 SDK these calls sit in explicit submodules of `_DarwinFoundation2`/`_DarwinFoundation3`
  that `import Darwin` leaves out, so CSystem's Darwin header includes `<locale.h>` and the `<xlocale.h>`
  headers.

Tests: ProvisionalLocaleTest. XCTest 515, swift-testing 460. One full run failed the malloc lane's
`reallocateFreeingOnFailureFreesTheBlock` (a zone's block count, under parallel tests); it passed alone three
times and in the rerun. It isn't this lane's.

## 17. posix_spawn's raw attributes and file actions: `32ec619`

swift-subprocess keeps raw posix_spawn to hand `posix_spawnattr_t`/`posix_spawn_file_actions_t` to its public
`preSpawnProcessConfigurator`, and to pass them to its own `_subprocess_spawn` (which forks first, for other
credentials). `Sources/System/RawSpawn/RawSpawn.swift`:

- `CInterop.SpawnAttributes`/`SpawnFileActions`: what posix_spawn takes a pointer to (`posix_spawnattr_t?` on
  Darwin and the BSDs, where it's a pointer, the structure elsewhere), so an `inout` of it matches Subprocess's
  public signature on Darwin.
- `SpawnAttributes.withCAttributes(_:)` and `SpawnFileAction.withCFileActions(_:_:)` build the C values from
  System's types and let a closure change and pass them; `ProcessID.spawn(...cFileActions:cAttributes:)` (and
  `searchingPathFor:`) spawns with them. The internal builders now pass mutable pointers.
- Rejected: a spawn that calls a configurator mid-way (serves only the first need); public setters for the
  SETSIGMASK/SETSIGDEF/SETPGROUP flags that System's properties imply, which the closure can set.

Status: 17 of the marker's 18 names are now documented; the 18th, `posix_spawnattr_getflags` (a test's), isn't
wrapped, and the closure can call it. Tests: RawSpawnTests. XCTest 519, swift-testing 460, all passing.

## 18. tzfile.h's paths: `68c6bec`

Foundation reads TZDIR and TZDEFAULT through `_FoundationCShims`, since no Darwin module declares `<tzfile.h>`.
CSystem's Darwin header now includes it; `FilePath.timeZoneDirectory` (TZDIR, `/var/db/timezone/zoneinfo`) and
`FilePath.defaultTimeZoneFile` (TZDEFAULT, `/etc/localtime`), Darwin only. Rejected: counting them as the C
library's (they're paths the system keeps).

Also fixed: SocketOpenOptionsTests' `acceptSetsExactlyTheOptions` (syscalls-4's) accepted on a nonblocking
listener right after `connect()` and failed with EAGAIN when the connection hadn't queued yet, in four recent
full runs at a load average near 65; it now retries EAGAIN for up to two seconds (with a catch-all: pattern
catches of `Errno.wouldBlock` in loops have crashed the compiler).

Tests: TimeZoneFilesTests. XCTest 519, swift-testing 461 in 72 suites, all passing.

## 19. One-file gaps: `d0031c5`

- `FilePath.makeUniqueFile(suffixLength:...)` (mkostemps, Darwin and the BSDs) for TSC's mkstemps, and on Darwin
  `makeUniqueFile(relativeTo:suffixLength:...)` (mkostempsat_np) for Foundation's temporary file relative to a
  directory; the mode stays 0600 and the doc points to `setPermissions`. Rejected: a `permissions:` parameter,
  which mkostempsat_np doesn't take (it would be a second call anyway).
- `OpenOptions`/`StatusFlags` `.sync` and `.dataSync` (O_SYNC, O_DSYNC) on Darwin, for WasmKit.
- `ClockID.currentTimeSpec()`: clock_gettime's timespec, without `currentTime()`'s macOS-13 `Duration`, for
  swift-driver's pre-13 time of day (status.py counts gettimeofday as clock_gettime's).
- `CInterop.Time` (time_t, swift-certificates' tests); `Signal.message` (strsignal, swift-driver), which I put
  on Signal rather than in Provisional+StringH though string.h declares it, since it's about signals.
- `DynamicLibrary.LoaderError.message`'s doc names dlerror (TSC).

Tests: SmallGapsTest. XCTest 525, swift-testing 461, all passing.

## 20. Typed allocation: `a795ce4`

First, local system-next moved to `e8762dd`, Michael's merge of coverage up to `be36a44`; merging it back
(`824a929`) changed nothing. The RawSpawn doc link that DocC found ambiguous between spawn's FilePath and
C-string overloads now names `-(FilePath,_,_,_,_)` (`53286c2`); the same link in the processes lane's
`Spawn.swift` and `ChildProcess.swift` is left to that lane.

Foundation's Data allocates with libmalloc's typed calls, describing its buffers as generic data.

- `Memory.TypeDescriptor`: the `malloc_type_id_t`, with Swift-named properties for the version 0 descriptor's
  fields, read and set through the C union: `layout` (an option set for `layout_semantics`), `kind`,
  `callSiteFlags`, `typeHash` (C's `hash`) and a read-only `version`.
- `Memory` and `Memory.Zone`: `allocate(byteCount:type:)`, `allocateZeroed(byteCount:type:)` and
  `(count:stride:type:)`, `allocate(byteCount:alignment:type:)`, `allocatePageAligned(byteCount:type:)` and
  `reallocate(_:byteCount:type:)`, with the untyped methods' rules. macOS 14 and its peers, 64-bit only.
- Rejected: a CInterop alias of the union with accessors (its own `hash`, `summary` and `type_id` would sit beside
  them, and the allocations would take a C union); wrapping `malloc_type_free`, which C compilers never call for
  `free` and `Memory.free` covers.
- status.py: `ANSWERED` counts the union's members as answered by `Memory.TypeDescriptor`, and now applies to
  `X members` too, which returned before reaching it.

Status: 72 of 76 interfaces covered; missing are posix_spawn's 18th name, `mktemp` and `readpassphrase`.
Tests: TypedAllocationTest. XCTest 532 (4 skipped), swift-testing 461 in 72 suites, all passing.

## 21. The last three names: `34aa3c3`

- `TerminalDescriptor.readPassphrase(prompt:into:options:)` (readpassphrase, SwiftPM's registry login) reads into
  the caller's buffer, so it can be cleared with `Memory.secureZero`; `readPassphrase(prompt:maxByteCount:options:)`
  returns a String and clears its own buffer. `PassphraseOptions` for the RPP_* flags. No `retryOnInterrupt`:
  readpassphrase restores the terminal and runs the handler of a SIGINT or the like, and if that returns, EINTR
  means the user asked to stop; retrying, the convention's default, would prompt again.
- `FilePath.makeUniqueFile(options:permissions:retryOnInterrupt:)` and `(relativeTo:...)`, for Foundation's
  temporary file with a chosen mode relative to a directory: mktemp makes the name, open or openat creates the
  file with O_EXCL, and a taken name is tried again (up to 100 times), as mkstemp does inside; the permissions
  pass through the creation mask, which mkostemp's 0600 and a later fchmod don't. Relative to a directory, mktemp
  makes only the last component, since it checks names against the working directory. mktemp goes through a
  CSystem shim, since the SDK deprecates it. Darwin only: glibc's and OpenBSD's linkers warn at every link of a
  program that calls mktemp. Rejected: `makeUniqueName()` for mktemp alone; looping forever, as Foundation does.
- `SpawnAttributes.Flags(of:)` and `store(in:)` (posix_spawnattr_getflags, setflags) read and replace C
  attributes' flags, as Subprocess's configurator test does to add POSIX_SPAWN_SETSID.

Status: 75 of 76 interfaces covered, none missing; the one left is *unread*: Subprocess's "raw posix_spawn path"
marker, whose other half is spawning with other credentials (section 22). Tests: ReadPassphraseTest,
UniqueFilesWithPermissionsTest, RawSpawnTests. XCTest 544 (4 skipped), swift-testing 461, all passing.

## 22. Spawning with other credentials: `042d0cf`

The other half of Subprocess's raw posix_spawn path marker: running a child as another user or group, which
posix_spawn can't do, and which Subprocess does in a C shim of its own by forking first.

- `SpawnCredentials` (user, group, supplementaryGroups, each `nil` for the caller's) and `ProcessID.spawn(...,
  credentials:)`, with System's file actions and attributes or with C values (`cFileActions:`, `cAttributes:`,
  `fileActionDescriptors:`), and `searchingPathFor:` forms. Darwin only, the one platform with
  POSIX_SPAWN_SETEXEC.
- A CSystem shim forks, so that the child runs only async-signal-safe C: signals are blocked across the fork and
  the child resets its handlers; setgroups, setgid, setuid, in that order; close-on-exec is cleared on the
  descriptors the file actions use, since with SETEXEC Darwin closes close-on-exec descriptors before applying
  the actions (checked with a C probe: the dup2 fails with EBADF until the flag is cleared); SETEXEC goes on the
  child's copy of the attributes, so the caller's keep their flags; a failure comes back through a close-on-exec
  pipe and the child is reaped.
- Rejected: a credentials property on SpawnAttributes (the C attributes can't hold it, and it would hide the
  fork); separate `user:`/`group:` parameters, whose defaults would make calls ambiguous with spawn; forking in
  Swift, which can't promise the child calls only async-signal-safe functions.
- status.py (`ae3049a`): an `ANSWERED` entry can now speak for a phrase marker that names no C interface; the
  raw posix_spawn path is answered by these forms and section 17's.

Status: all 76 interfaces covered. Tests: SpawnCredentialsTest. XCTest 550 (4 skipped), swift-testing 461, all
passing.

## 23. Explicit availability: `02390d5`

A clean run of the explicit-availability check (`-require-explicit-availability=warn`, CLAUDE.md's command) flagged
section 18's `_TZDIR` and `_TZDEFAULT`, which as `@usableFromInline` were ABI without an `@available`; they're now
`@_alwaysEmitIntoClient`, as Constants.swift's constants are. The check now warns only in Syscalls.swift's termios
wrappers and in posix-darwin's `system_exit` and `system__exit` (Syscalls+ProcessExit.swift), left to their
owners. None of this branch's other additions draw a warning, and the ABI-stable build fails only in its known
places (FileTimes.swift, FilePathOperations.swift, Syscalls.swift's UserID and GroupID wrappers).

Where the branch stands: every interface that the adopters' 51 markers name is covered (76 of 76), 12 DocC
diagnostics remain (none in this branch's files; the processes lane's ambiguous spawn links are two of them), and
local system-next is still `e8762dd`.

## 24. Spawning with other credentials: two fixes from review: `06c9245`

- **Close-on-exec sources.** The child clears close-on-exec on every descriptor that the file actions use (section
  22), so one used only as a source stayed open in the program, where a spawn's exec closes it. Found on macOS
  26.3 with a C probe (fork, then posix_spawn with SETEXEC): a close-on-exec pipe end duplicated as the standard
  output, a working directory's descriptor, and a descriptor duplicated onto itself (Darwin's adddup2 keeps its
  flag then) all stayed open; POSIX_SPAWN_CLOEXEC_DEFAULT still closes what the actions don't install; a close
  action on a descriptor that isn't open fails the spawn with EBADF, so closes can't be added blindly. For
  System's file actions, the parent now appends a close action for each descriptor that the actions use as a
  source, that has close-on-exec set, and that no action closes, replaces or inherits. Rejected: adding the
  closes in the child (adding to C file actions allocates, which the forked child of a threaded process
  mustn't); always setting CLOEXEC_DEFAULT, as Subprocess does, which also closes the descriptors without
  close-on-exec that a spawn passes on; following each descriptor's state action by action (an action that
  closes, replaces or inherits one settles it whatever comes after, so a set does). The C-values forms can't read
  their actions, so their doc says what the caller must do: a close action after each descriptor's last use, or
  CLOEXEC_DEFAULT.
- **The error pipe's window.** Where pipe2 is missing (macOS 26, or a build with an older SDK), the pipe becomes
  close-on-exec in a second step; a program that another thread starts in between inherits it, and the parent's
  read, which ends when every write end has closed, waits until that program exits or closes it. Nothing in the
  macOS 26 SDK makes a pipe or a socket pair close-on-exec at once (no SOCK_CLOEXEC), so the shim's comment and
  the spawn doc state the window and its consequence. Rejected: watching the child with a kqueue (EVFILT_PROC,
  NOTE_EXEC and NOTE_EXIT), which no inherited descriptor can delay, but which misses an exec that comes before
  the registration unless the child waits for the parent: a second channel and a round trip in every spawn, for
  a window that pipe2 closes from macOS 27.

Tests: SpawnCredentialsTest's `testTheProgramGetsTheDescriptorsASpawnWould` (a shell reports which of seven
descriptors are open, spawned with and without credentials; before the fix three more were open with them) and
`testCValuesKeepTheDescriptorsTheyUse`; `testCalls` now expects the parent's F_GETFD. XCTest 551 (4 skipped, and
testVolumeAttributes skipped), swift-testing 461 in 72 suites, all passing.

## 25. What the tools couldn't see: `128dcc8`, `6e784c6`

The first ecosystem run of this stage (`05d4974d68bb-8ed49538`) ranked 259 interfaces as gaps of the files that import
Darwin. Checked against System's sources, many weren't: System covered them, but the coverage tools couldn't tell.
Fixing that came first, since every later rank depends on it.

- **Doc sentences** (`128dcc8`, doc comments only): FilePermissions' members name their constants (S_IRUSR through
  S_IRWXO, S_ISUID, S_ISGID, S_ISVTX) and FileMode.type names S_IFMT; PThread's Mutex, Condition, ReadWriteLock and
  Key name what their deinits call (pthread_mutex_destroy, pthread_cond_destroy, pthread_rwlock_destroy,
  pthread_key_delete), and each Attributes type the init and destroy calls that creating the object makes;
  DT_UNKNOWN, XATTR_NOFOLLOW, LOCK_EX/LOCK_SH/LOCK_NB, PROT_NONE, MAP_FAILED, AT_EACCESS, freeifaddrs and struct
  ifaddrs, the sysctl MIB constants behind SystemControl's names (CTL_KERN, KERN_PROC, KERN_PROC_PID, CTL_HW, HW_NCPU,
  HW_AVAILCPU: a C probe showed HW_AVAILCPU is `hw.activecpu`'s MIB), _NSGetEnviron, and AF_UNIX (only
  `.local`'s unavailable renamed stub named it). BrokenDownTime's sentences named gmtime_r and timegm "for
  ``Zone/utc``": DocC's doubled backticks paired with the C names', so localtime_r and mktime were never read and
  gmtime_r and timegm read as restricted to one use; the zones now have a sentence of their own.
- **derive.py** (`6e784c6`): reads "The corresponding C variable is" (FileStream's stdout and stderr and
  ProcessEnvironment's environ used it; only "global variable" was read), and blanks DocC links before pairing
  backticks. Rejected: rewording those doc comments to fit the parser, which already read "global variable".
- **mapping.ini** (`6e784c6`): fts is covered by DirectoryWalk, as section 14 decided and status.py already said;
  PATH_MAX's and linger's hand partials predate SystemConfig.maxPathBytes and CInterop.Linger; the old calls that a
  reentrant or newer one System wraps answers read as it (`same.`: gettimeofday and time as clock_gettime, usleep as
  nanosleep, localtime and gmtime, getpwuid, getpwnam, getgrgid and getgrnam as their _r forms, mkstemp(s) as
  mkostemp(s), strerror_r as strerror), as status.py's replacements did. The standard library's answers get entries
  with a `swift` key (memory copies; rounding and roots), and string.h and stdio lose theirs, since section 7 put
  those families in scope. Rejected: hand `covered` statuses, which need System declarations and hide what answers.
- **ecosystem.py** (`6e784c6`): the report's new section *What the files that import Darwin still need* ranks, per
  symbol, the interfaces that files importing Darwin in any form but through Apple Foundation use, by packages and
  then sites, with coverage from the derivation's evidence for that symbol (an entry's status is its worst symbol's);
  the standard library's answers, Dispatch and ObjectiveC names, and the packages' own C shims are set apart.
  ECOSYSTEM.json keeps every row. Rejected: the report's existing top-30 gaps, which rank entries over every platform,
  so Windows' dominate, and don't say which gaps a Darwin import waits on.

Result, run `6e784c6e7026-4676fb13`: 756 interfaces, 567 covered, 131 gaps, 24 of them in two or more packages (259
gaps before). The Queue above is ranked from it. No tests changed: the build is unchanged but for doc comments.

## 26. C strings and character classes, provisionally: `f29fa08`

The top of the Queue: string.h's C-string functions are the gap that the most packages' Darwin-importing files share
(9 packages, 60 sites; strdup alone 7, and four of the migrations each wrote a strdup of their own), with ctype.h's
tolower (swift-build's header maps) and isspace (Foundation's property list scanner).
`Sources/System/Provisional/Provisional+StringH.swift` and `Provisional+CType.swift`:

- `CString`, a namespace, as `Math` is for libm: `length(of:)` and `length(of:maxLength:)` (strlen, strnlen),
  `duplicate(_:)` and `duplicate(_:maxLength:)` (strdup, strndup; `throws(Errno)`), whose copies `Memory.free`
  frees, `compare(_:_:)` and `compare(_:_:maxLength:)` (strcmp, strncmp, returning the sign as an `Int`), and
  `copy(_:into:)` (strlcpy, into a buffer pointer, returning the source's length). A `String` argument converts to a
  temporary C string, as it does for the C functions. Negative lengths trap.
- `CType`: `isSpace`, `isBlank`, `isDigit`, `isHexDigit`, `isLetter`, `isLetterOrDigit`, `isUppercase`, `isLowercase`,
  `isPunctuation`, `isPrintable`, `isGraphic`, `isControl`, `lowercased`, `uppercased`, on `UInt8`, so C's undefined
  behavior for a negative `char` can't arise; they follow the C library's current locale, as C's do.
- memcpy, memmove and memset stay the standard library's (section 1), and memcmp and memchr `Memory`'s.
- Rejected: members of `UnsafePointer<CChar>` or `UInt8`, which would sit on every pointer and byte and read as the
  standard library's; a `String`-only duplicate, since callers also copy from C memory; `Bool` results for
  `compare`, which serve equality but not ordering; `CCharacter` for the ctype namespace (`CType` is the header's
  name, as `Math` is libm's role). Where glibc (before 2.38) or WASI's libc may lack strlcpy, it's strlen and a copy.
  Not on Windows, whose C library names several of these differently.
- strdup and strndup are mocked (a success copies for real, as mocked allocations do); the others can't fail.

Tests: ProvisionalStringTests (CString: lengths, duplicates, comparisons, copies; CType: every ASCII byte's classes
and case, and agreement with the C functions for all 256 bytes) and ProvisionalStringMockTest. XCTest 552 (4
skipped, and testVolumeAttributes skipped), swift-testing 468 in 74 suites, all passing.

Local system-next moved to `3d1e67d` (Michael's merge of coverage up to `0a3c801`); merging it back (`a87b3be`)
changed nothing.

## 27. C stdio beyond FileStream: `d522202`, `fb536a2`

Queue cluster 2 (5 packages, 12 sites): swift-syntax and swift-tools-protocols write messages to the standard error
with fputs, swift-argument-parser writes it byte by byte with putc, swift-build calls perror, and Subprocess builds
`NAME=value` strings with snprintf.

- `FileStream.write(cString:)` (fputs) writes a C string's bytes up to its null byte, for a message in C memory; a
  Swift `String` goes through `write(_:)`. `write(byte:)` (fputc, and putc, its macro form) writes one byte. Both
  throw the stream's error, as the fwrite forms do, and don't retry.
- mapping.ini: perror is covered by `Errno.description` (strerror's text) written with `FileStream.write(_:)`, a
  hand status that cites both; C's formatted output (printf, fprintf, snprintf and the like) gets an entry of its own
  whose answer is the standard library's: Swift can't call C's variadic functions directly, and what they format is
  what string interpolation builds.
- Rejected: a `TextOutputStream` conformance for `print(_:to:)`, whose non-throwing `write(_:)` would clash with
  the throwing one and drop its error; an unlabeled `write(_ byte: UInt8)`, which reads as a count at the call site;
  a perror wrapper, which would compose the two calls that already exist.

Tests: ProvisionalStdioTest's mock cases for fputs and fputc, a C string cut at its null byte and a byte in the file
round trip, and both writes' EBADF on a read-only stream. XCTest 552 (4 skipped, and testVolumeAttributes skipped),
swift-testing 468 in 74 suites, all passing.

## 28. Sockets: `9bf8bb5`, `e4196f7`

Queue cluster 3 (4 packages, 104 sites, most of them NIO's). Checked against SystemSockets, most of it was covered: the
syscalls-4 lane named the options, structures and constants (IP_TOS through IPV6_MULTICAST_LOOP, ip_mreq and
ipv6_mreq, in_pktinfo and in6_pktinfo, INADDR_ANY, the address-string lengths, SO_RCVTIMEO, SO_TIMESTAMP,
CInterop.SockAddrStorage), and mapping.ini's hand partials, which cited the generic setOption, predated it.

- `SocketDescriptor.ExplicitCongestionNotification` (`9bf8bb5`): an ECN codepoint, `RawRepresentable` over `UInt8`,
  with `init(typeOfService:)` taking the low 2 bits of a type-of-service byte or traffic class (IPTOS_ECN_MASK), and
  `notCapableTransport`, `capableTransport1`, `capableTransport0` and `congestionExperienced` (IPTOS_ECN_NOTECT, _ECT1,
  _ECT0, _CE), with RFC 3168's values, so the Linux code needn't import netinet/ip.h. NIO maps received TOS and TCLASS
  values to its own state with these constants. Rejected: a message-level `explicitCongestionNotification` property
  on both message types, which `typeOfService.map(ECN.init(typeOfService:))` already is.
- Docs (`9bf8bb5`): `Domain.vsock` names AF_VSOCK (PF_VSOCK's value, and what `SocketAddress.family` compares with;
  rejected: a `SocketAddress.Family.vsock`, a second spelling that no API takes); `resolve` names freeaddrinfo;
  `reverseLookup` names NI_MAXHOST and NI_MAXSERV, its buffers' sizes; `poll` names nfds_t.
- mapping.ini (`e4196f7`): the stale hand partials go; inet_pton and inet_ntop are covered by the IPv4 and IPv6 host
  forms together (the derivation reads each as restricted to its family, and those are the two families the calls
  take); ioctl is covered by the requests the packages make: TIOCGWINSZ (`TerminalDescriptor.windowSize()`, for
  swift-argument-parser and swift-tools-support-core) and NIO's vsock context ID (`SocketDescriptor.localContextID()`),
  which also answers cluster 7.

Tests: SocketIPMessagesTests' codepoints against the C constants and from type-of-service bytes; SocketVMSocketTests'
AF_VSOCK. XCTest 552 (4 skipped, and testVolumeAttributes skipped), swift-testing 468 in 74 suites, all passing with
PThreadTests' `setCurrentQualityOfService` skipped: at a load average near 70 (other sessions' builds) it fails alone
too, since its background-QoS thread doesn't run within 10 s (section 4 saw the same). It isn't this lane's.

## 29. C arrays for the C-values and credentials spawns: `52d8c03`, `97d00c6`

A new SYSTEM-GAP marker in swift-subprocess's migration (status.sh read it as *unread*): "C-string arguments for the
C-values spawns". `ProcessID.spawn` with `cFileActions:` and `cAttributes:`, and with `credentials:`, took the
arguments and the environment only as `[String]`, which can't carry bytes that aren't UTF-8, so Subprocess kept its
own `_subprocess_spawn` for them. The plain spawn already had a C-array form.

- `spawn(_:arguments:environment:cFileActions:cAttributes:)`,
  `spawn(_:arguments:environment:fileActions:attributes:credentials:)` and
  `spawn(_:arguments:environment:cFileActions:cAttributes:credentials:fileActionDescriptors:)`, each with a C-string
  path and null-terminated C arrays of C strings (the environment `nil` for the calling process's), as the plain
  spawn's C-array form takes. The internals convert `[String]` once and share one core per form, so the close
  actions of section 24 apply to the new form with System's actions too.
- Only path-given forms, as the plain spawn's: Subprocess resolves the executable itself. Rejected: `searchingPathFor:`
  C-array forms, which no caller needs yet; a `[[UInt8]]` form, which would copy what callers already hold as C arrays.
- The overloads made the existing doc links ambiguous; they now name the `FilePath` forms.
- status.py (`97d00c6`): an `ANSWERED` entry for the marker's phrase.

Tests: RawSpawnTests' `testSpawningWithCArrays` and SpawnCredentialsTest's `testCArrays` run a shell that compares
its argument and an environment variable with a lone 0xFF byte (and fails for 0xFE); `testCalls` records a C-array
credentials spawn as the others. XCTest 554 (4 skipped, and testVolumeAttributes skipped), swift-testing 468 in 74
suites, passing with `setCurrentQualityOfService` skipped (section 28).

## 30. C scalar types and file times: `56e3f1d`, `f81f8d1`

Queue clusters 4 (suseconds_t, u_int, LONG_MAX, _POSIX_ARG_MAX; 4 packages) and 5 (futimens, utimes; 4 packages).

- `SystemConfig.guaranteedArgumentBytes` (`56e3f1d`, _POSIX_ARG_MAX, 4096): POSIX's least limit on a new program's
  arguments and environment, the floor that swift-driver puts under sysconf's, next to section 3's compile-time
  limits. Rejected: `minimumMaxArgumentBytes`, which reads as a setting; leaving callers the literal.
- The typedefs and limits are the standard library's (`f81f8d1`): mapping.ini's [C scalar types] gains u_char,
  u_short, u_int, u_long, suseconds_t and the integer limits (Swift's integer types and their `min` and `max`); u_long
  and u_short leave [Winsock addresses], since the BSD headers declare them too.
- futimens and utimensat read as partly covered because of section 13: its "with `UTIME_OMIT` for a `nil` time"
  made the tools read setTimes' sentences as restricting both calls to that use. UTIME_OMIT now has a sentence of its
  own. utimes, futimes and lutimes read as the timespec calls (`same.`), which setTimes covers.

Tests: CompileTimeLimitsTest's `testGuaranteedArgumentBytes`, against the C constant and the system's own limit.
XCTest 555 (4 skipped, and testVolumeAttributes skipped), swift-testing 468 in 74 suites, passing with
`setCurrentQualityOfService` skipped (section 28).

## 31. Mach, MacTypes and the kernel's process information: `a800132`, `b3dee42`, `b08bf19`

The ecosystem run after section 30 (`b64ee9f1591b-d229d468`) counted 78 gaps, from 131: clusters 1 to 5 and 7 have no
interfaces left. This section takes the Queue's clusters 6, 8 and 9.

- **Mach** (`a800132`, docs; `b3dee42`, mapping): Foundation and swift-corelibs-foundation call vm_copy and
  vm_deallocate on `mach_task_self_` with `vm_address_t` arguments and compare with KERN_SUCCESS or ERR_SUCCESS, which
  is what `Mach.VirtualMemory`'s `copy` and `deallocate` do, throwing `Mach.KernelError` for any other code; their docs
  now name those. swift-build reads its memory footprint with `task_info(TASK_VM_INFO)`'s `phys_footprint`, which
  `ProcessID.resourceUsageInfo()`'s `physicalFootprint` reports: the same kernel value (a C probe read 68174784 bytes
  both ways). mapping.ini's [task_info] cites it, covered for that flavor. swift-build's `vm_prot_t` and `USEC_PER_SEC`
  are its own declarations, which the scan reads as Darwin's; they stay listed, with that reason.
- **MacTypes** (`b3dee42`): OSStatus, UniChar, DarwinBoolean and Boolean are the standard library's (Int32, UInt16,
  Bool); the lexical scan's `index` (Collection's `index(after:)`) and `Float80` get an ignore entry, and os's
  `Logger`, Foundation's `NSDictionary` and CoreFoundation's `CFRunLoopStop` an Apple-frameworks entry.
- **The kernel's process information** (`b08bf19`): Foundation reads the saved set-user ID, which Darwin has no call
  for, and swift-build whether a debugger traces the process, from SystemControl's `kinfo_proc`, whose nested fields
  a client can't reach without Darwin under MemberImportVisibility. `CInterop.KernelProcessInfo` names it, with
  read-only Swift-named accessors: `processID`, `parentProcessID`, `processGroupID`, `realUserID`,
  `effectiveUserID`, `savedUserID`, `realGroupID`, `savedGroupID`, `isTraced` (P_TRACED) and `commandName`. Rejected:
  a Swift structure copying the fields, which would drop the rest of kinfo_proc; a raw flags accessor, since P_TRACED is
  the one flag a package reads.

Tests: SystemControlTest's `testProcesses` checks each accessor against the calling process. XCTest 555 (4 skipped,
and testVolumeAttributes skipped), swift-testing 468 in 74 suites, passing with `setCurrentQualityOfService`
skipped (section 28).

## 32. pthreads: `2e3cd54`, `bd9fd0e`

Queue cluster 10 (NIO and swift-corelibs-foundation).

- `PThread.exit()` (pthread_exit) ends the calling thread, as Foundation's `Thread.exit()` does; its doc says what it
  abandons (the stack's `defer` blocks and values, which leak) and that thread-specific values are still destroyed.
  `noasync`, since a task can't end the thread it runs on.
- `PThread.Attributes.defaultStackSize()` (pthread_attr_getstacksize on default attributes): the size a thread gets
  when `stackSize` is `nil` (512 KiB on macOS 26.3, where a thread reports a little more), which Foundation's
  `Thread.stackSize` reports until it's set.
- `CInterop.PThreadMutex.initializer`, `errorCheckingInitializer` and `recursiveInitializer`, and
  `CInterop.PThreadCondition`'s and `CInterop.PThreadReadWriteLock`'s `initializer`: the values of the C static
  initializers, which Swift can't import. swift-corelibs-foundation builds an error-checking mutex from Darwin's
  private `_PTHREAD_ERRORCHECK_MUTEX_SIG_init` for a lock in a CoreFoundation structure. Darwin only for now; glibc's
  differ in the kind field of the error-checking and recursive ones.
- mapping.ini (`bd9fd0e`): pthread_yield_np is sched_yield (`PThread.yield()`); detached creation is
  `PThread.detach()` (PThread creates joinable threads); system contention scope is every thread's on Darwin and Linux,
  which fail the process scope; the private `_SIG_init` constants read as the macros. Rejected: attributes for detached
  creation and scope, which would add a second way to do the first and nothing for the second; `exit(_ value:)`,
  since System's joins return nothing.

Tests: PThreadTests' `defaultStackSize` and `exitEndsTheThread`; PThreadMutexTests' `staticInitializers` (trylock,
EDEADLK and EPERM for error checking, relocking the recursive mutex, a condition and a read-write lock). XCTest 555 (4
skipped, and testVolumeAttributes skipped), swift-testing 471 in 74 suites, passing with `setCurrentQualityOfService`
skipped (section 28).

## 33. Signals, spawn attributes, mounts and quotas, xattr names: `470bf2c`, `52d74d3`

Queue clusters 11 to 14 (two packages each).

- **Signals**: swiftpm resets every signal with `signal()` from 1 to NSIG and unblocks them with `sigprocmask`;
  swift-tools-protocols ignores SIGPIPE with `signal`. `SignalSet.all`, a sequence of every signal, `Signal`'s
  `setAction(_:)` and `PThread.unblockSignals(_:)` do that; the mask calls now name SIG_SETMASK, SIG_BLOCK and
  SIG_UNBLOCK, `unblockSignals` says it's sigprocmask's effect with one thread, and `SignalSet.all` names NSIG. In
  mapping.ini, signal and SIG_ERR read as sigaction and sigprocmask as pthread_sigmask, and the notes that said System
  has no signal API go.
- **Spawn attributes**: `processGroup`, `signalMask` and `defaultSignals` named their functions "with the
  POSIX_SPAWN_* flag", which the tools read as restricting each function to one use; the flags have sentences of
  their own now. Rejected: rewording all 25 such sentences, most of which are real restrictions (fcntl with one
  command).
- **Mounts and quotas**: `StatFS.mountedFileSystems` named getfsstat "with MNT_NOWAIT, or with MNT_WAIT", read the
  same way; getmntinfo and getmntinfo_r_np read as getfsstat; quotactl is covered for the commands Foundation uses
  (Q_QUOTASTAT, Q_GETQUOTA), each form of which the tools read as restricted to its command, and DiskQuota names QCMD's
  SUBCMDSHIFT and SUBCMDMASK.
- **`ExtendedAttributeName`** (Darwin): `finderInfo` and `resourceFork` (XATTR_FINDERINFO_NAME,
  XATTR_RESOURCEFORK_NAME), for Foundation's and swift-build's copies. Rejected: static members of FilePath, which the
  names aren't about.

Tests: ExtendedAttributesTests' `darwinsNames`. XCTest 555, swift-testing 472 in 74 suites, passing with
`setCurrentQualityOfService` skipped.

## 34. The adopters' asks: a dirent name, the pending loader error, adding to C file actions: `3b21234`, `f7b06e3`, `a3012f9`, `273f560`

Michael's asks A1 to A4, ahead of the ranked clusters. A3, C-string arguments for the C-values spawns, was section 29.

- **status.py** (`3b21234`): `STILL_NEEDED` lists interfaces that System's docs name but whose markers ask for more,
  each with a witness in System's sources; until the witness is there, the interface counts as missing, with the
  ask as the reason. dirent (DirectoryStream.Entry names it, but it's another type), dlerror (LoaderError names it,
  but carries only the errors System throws) and posix_spawn_file_actions_addchdir_np (named for System's own C file
  actions) went from covered to missing, and STATUS.md then showed 47 of 50 interfaces covered.
- **`CInterop.DirectoryEntry`** (`f7b06e3`, A1): the alias for struct dirent, with Swift-named accessors
  `fileName` (`FilePath.Component?`, nil only for an entry without a name, such as a zero one), `fileType` and
  `inode`, for TSC's public `extension dirent { var name }`, which can now extend the alias and read `fileName`.
  Rejected: `name` and `type`, DirectoryStream.Entry's names, since TSC's own public `dirent.name: String?` would make
  every use ambiguous for a client importing both. The MemberImportVisibility probes read the accessors, and the
  accessors probe gains section 31's kinfo_proc ones, which had none.
- **`DynamicLibrary.takePendingError()`** (`a3012f9`, A2): dlerror, the calling thread's pending loader error, taken
  and cleared, as a `LoaderError?`, for TSC's deprecated public `dlerror()`. `address(of:)` clears the pending
  error before dlsym, so after a `nil` it's dlsym's reason. Rejected: `pendingError`, a property-like name for a
  read that clears; `String?`, when LoaderError is what the other calls throw.
- **`SpawnFileAction.add(to:)`** (`273f560`, A4): adds an action to `inout CInterop.SpawnFileActions` that other code
  built, such as the ones Subprocess's `preSpawnProcessConfigurator` hands its closure, with the C call for the
  action's kind and its error. Rejected: a static form over an array, which a loop is.

Tests: DirectoryEntryTypeTests' `cEntryAccessors` (readdir's entries against Stat, the dot entries, a zero entry),
DynamicLibraryTests' `takingThePendingError`, RawSpawnTests' `testAddingActionsToCFileActions` (/bin/pwd with a
working directory, a duplicate and a close added to empty C file actions; an invalid close throws EBADF). XCTest
556, swift-testing 474 in 74 suites, passing with `setCurrentQualityOfService` skipped. STATUS.md after these: every
interface the markers name is covered again (48 of 48, as the adopters remove markers).

## 35. DirectoryWalk's opening option, and section 14's corrections: `6666fbe`

Michael's ask A5, for Foundation's copy and link, which keep fts. Foundation's REPORT.md ("fts for copy and link:
tried, kept") compared the two in 382 runs: 366 identical, and 16 differing in two properties of DirectoryWalk. It
opened a directory when it read the directory's entry, and Darwin's fdopendir reads the entries then, before the
copy has handled the directory's first visit, so copying a directory into its own tree copied it as it was, where
fts recursed until ENAMETOOLONG (12 runs); and it holds a descriptor per level, where fts with FTS_NOCHDIR holds
none (4 runs, EMFILE at about level 250 under a 256-descriptor limit).

- `DirectoryWalk.DirectoryOpening`: `.whenRead`, the default, as before, and `.whenEntered`, an `opening:` parameter
  of both initializers. With `.whenEntered`, a walk opens a directory on the next call after the directory's first
  visit, relative to its parent, unless `skipDescendants()` forgets it; one it can't open then gets a second visit,
  marked `isPostorderVisit`, with the error, in place of its contents (fts's FTS_D and FTS_DNR). A postorder walk
  opens a directory before its contents whichever the option. Rejected: a Bool parameter; throwing the open's error
  from `next()`, which ends the walk's directory as a read error does, where fts goes on.
- Kept, as Michael asked: one descriptor per level. The type's doc now names it as a known difference from fts,
  with the other one: fts opens each directory by its path, so it reports a directory whose path is PATH_MAX bytes
  or longer as FTS_DNR, which the walk reads.
- Section 14's two corrections, made there: on a file system that records types in its directories, as APFS does,
  an entry whose status can't be read still has its type (the walk reads the status only when the directory records
  no type), so FTS_NS needs the caller's own fstatat; and FTS_DNR also covers paths of PATH_MAX bytes or more.

Tests: DirectoryWalkVisitsTests' `openingWhenEnteredVisitsTheSame` (every order, and skipping),
`openingWhenEnteredReadsWhatTheFirstVisitAdded` (a file created on a directory's first visit is walked with
`.whenEntered`, and on Darwin not with `.whenRead`), `anUnreadableDirectoryWhenEntered` (both preorder orders: the two
visits, the directory the error's visit is in, and skipping). XCTest 556 (4 skipped, and testVolumeAttributes
skipped), swift-testing 477 in 74 suites, passing with `setCurrentQualityOfService` skipped (section 28).

## 36. CPU types, wait, and the one-package gaps: `90b1273`, `d3f786a`, `ea3c54b`, `c36731b`, `73ea160`

Queue clusters 15 to 17.

- **CPU types** (`90b1273`, swift-build): `Mach.CPUType` (cpu_type_t) with `any`, `x86` (CPU_TYPE_X86 and its old name
  CPU_TYPE_I386), `x86_64`, `arm`, `arm64`, `arm64_32`, and the 64-bit ABI bit (`has64BitABI`, `with64BitABI`,
  `without64BitABI`); `Mach.CPUSubtype` (cpu_subtype_t) with `featureFlags` and `withoutFeatureFlags`
  (CPU_SUBTYPE_MASK). SystemControl's `cpuType` and `cpuSubtype` keep their raw values, which these take. Rejected:
  Mach-O's header types, which are the MachO module's.
- **wait** (`d3f786a`, `ea3c54b`, Subprocess): System's `wait(for:)` and `waitForAnyChild` are waitid, with the state
  change decoded; the tools missed it twice. The CLD_* codes shared sentences with the W* macros ("and the C constant
  is"), and derive.py read no enum case's doc at all, since api-delta's scan lists no case (a case has no access
  modifier): it now reads each public enum's own cases as the enum's (37 cases, 17 names, among them the W* macros and
  PRIO_*). mapping.ini's [wait] is covered, since waitid's forms, each read as restricted to its idtype, take every
  idtype together.
- **One-package gaps** (`c36731b`, `73ea160`): `Stat.Flags.realDevice` and `.descriptorOnly` (AT_REALDEV, AT_FDONLY,
  fstatat-only, for WasmKit; rejected: members of ResolutionFlags, which the other `*at` calls take);
  `DynamicLibrary.symbolInfo(containing:)` (dladdr, for swift-build; Darwin only, since glibc declares it only with
  _GNU_SOURCE; the nearest symbol can be an alias, such as `__getpid`); `CallStack`, provisionally (backtrace and
  backtrace_symbols, for swift-corelibs-foundation's call-stack properties; Darwin only, musl has neither);
  `IOPolicy` (getiopolicy_np and setiopolicy_np with kinds and scopes, a raw kind for swift-build's private case
  sensitivity type); SearchPaths' iterator names sysdir_search_path_enumeration_state and getattrlist's forms
  ATTR_BIT_MAP_COUNT (Foundation); strtod and strtof read as CLocale's `_l` forms, execv as execve, getdtablesize as
  _SC_OPEN_MAX. swift-build's `vm_prot_t` and `USEC_PER_SEC` are its own declarations, which the scan reads as
  Darwin's.

Tests: MachCPUTypeTests (constants, the ABI bit, the host's type, feature flags), SmallDarwinGapsTest (the stat
flags against fstat, dladdr, the call stack, a thread's disk policy, mocks). XCTest 561 (4 skipped, and
testVolumeAttributes skipped), swift-testing 481 in 75 suites, passing with `setCurrentQualityOfService` skipped.

## 37. The toolchain's queue is empty; popular packages beyond it: `4365a83`, `9541436`, `d3c7a3a`, `55841f0`

The ecosystem run after section 36 left four gaps, all swift-build's, and `4365a83` mapped them: extern_proc and
eproc read as kinfo_proc, whose kp_proc and kp_eproc CInterop.KernelProcessInfo's accessors read; dl_info is
Dl_info's structure tag; USEC_PER_SEC and vm_prot_t, which swift-build declares only off Darwin, get the standard
library's answers (Duration's units or the literal, and Int32).

The toolchain's queue is now empty. In run `a3a634eb2b19-06a7ddd5` (System `a3a634e`), System covers on Darwin every
interface that the toolchain's library files importing Darwin use, except the ones set apart: the standard
library's answers, other modules' names, and the packages' own C shims. Its ECOSYSTEM.md has the counts. Step 4
extends the survey:

- `Utilities/adopter-coverage/popular.tsv` lists the packages beyond the toolchain, with why each is there. They're
  cloned shallowly into `../ecosystem`, next to the toolchain's, each at `main`. The first batch has 21:
  - swift-server's own: async-http-client (the HTTP client), swift-service-lifecycle (service lifecycle and signal
    handling), swift-aws-lambda-runtime;
  - the server APIs and a backend: swift-metrics, swift-distributed-tracing, swift-otel (OpenTelemetry);
  - NIO's libraries beyond swift-nio: swift-nio-ssl, swift-nio-http2, swift-nio-extras,
    swift-nio-transport-services, swift-nio-ssh;
  - OpenAPI and gRPC: swift-openapi-generator, swift-openapi-runtime, swift-protobuf, grpc-swift-2,
    grpc-swift-nio-transport;
  - the web frameworks and their database client: vapor, hummingbird, postgres-nio;
  - swiftlang's packages outside update-checkout's scheme: swiftly, swift-java.

  Why these: they're the swift-server ecosystem's most used packages and the libraries under them, plus swiftlang's
  packages that the toolchain doesn't clone. None is in the main scheme. Three import Darwin in no library file
  (swift-nio-http2, swift-openapi-generator, swiftly), so they get no package file; the report's table lists them.
- `ecosystem.sh --popular` (`9541436`) runs clone, survey, run and report over that list. Its survey is
  `survey-popular.json`, its package files are generated into `packages/popular/`, and its report is a run's
  POPULAR.md, without the standard library's section. Rejected: folding the list into the main scheme's survey,
  which would mix the toolchain's figures with the others'.
- Three packages don't build with Swift 6.2, so they're extracted lexically: vapor's main (Vapor 5, tools 6.4),
  swift-aws-lambda-runtime's main (a Sendable conversion 6.2 rejects), and swift-java's JExtractSwiftLib.
- The run needed two tool fixes. `d3c7a3a` lowers a newer tools version anywhere in the manifest's first three
  lines, because vapor's opens with an import; it also cites DirectoryWalk's path initializer with section 35's
  `opening:`, whose absence every run had reported as a cited declaration missing on the tip. `55841f0` makes the
  Darwin metric count a lexical name that a site qualifies with Darwin (`Darwin.write`). That found
  swift-aws-lambda-runtime's write and, in the toolchain, a calloc, both covered.

Tests: the runs at `a3a634e`, the toolchain's and the popular set's.

## 38. The popular packages' first queue: gai_strerror, IF_NAMESIZE, frexp, M_LOG2E: `a3a634e`

The popular set's first run (at `d3c7a3a`) found four interfaces that its library files importing Darwin use and
System didn't cover on Darwin, each in one package:

- **gai_strerror** (grpc-swift-nio-transport's DNS resolver): `AddressResolutionError.message` calls it, and now
  says so.
- **IF_NAMESIZE** (grpc-swift-nio-transport sizes an if_indextoname buffer with it, for an IPv6 scope's name):
  `NetworkInterface.Index.name()` now says its buffer is IF_NAMESIZE bytes, as `reverseLookup` says of NI_MAXHOST
  and NI_MAXSERV. The call spares its caller both.
- **frexp and M_LOG2E** (swift-otel's exponential histogram): the standard library answers both. mapping.ini's
  `[floating-point parts]` gives frexp as `significand / 2` and `exponent + 1` for a finite, nonzero value, which
  is how the Darwin overlay's own frexp computes it. `[math constants]` gives M_LOG2E as the literal. Math's doc
  now names the frexp conversion next to the other standard-library answers. Rejected: `Math.frexp`, and math.h's
  M_ constants as Math members, each for one call site the standard library already answers.

After this commit the popular set's queue is empty too (run `a3a634eb2b19-67e0cd30`).

Tests: SocketAddressResolutionTests, the first tests of `SocketAddress.resolve`. A numeric host and service
resolve to the loopback address and port, and a non-numeric host under `.numericHost` fails with EAI_NONAME and
gai_strerror's message. The full suite passes with testVolumeAttributes skipped.

## 39. The popular list's second batch, and its queue: getline, MAP_FILE, timespec_get: `7a5b6bc`, `6953d40`

With the first batch's queue empty, `7a5b6bc` adds 25 more swift-server ecosystem packages to popular.tsv, each at
`main`:

- the database and cache clients: RediStack, valkey-swift, swift-memcache-gsoc, swift-cassandra-client, MongoKitten,
  mysql-nio, sqlite-nio, fluent-kit;
- the metrics API's backends: swift-prometheus, swift-statsd-client;
- messaging: swift-kafka-client, mqtt-nio, APNSwift;
- the rest: soto-core (the AWS SDK's core), swift-profile-recorder (the in-process sampling profiler),
  swift-configuration, swift-http-types, swift-async-dns-resolver, swift-nio-imap, websocket-kit, swift-websocket,
  jwt-kit, swift-openapi-async-http-client, swift-webauthn, swift-container-plugin.

Eight of them import Darwin in library code: soto-core, swift-prometheus, swift-memcache-gsoc, valkey-swift,
swift-profile-recorder, swift-configuration, swift-nio-imap and sqlite-nio. The report's per-package table is much
larger than the queue. It counts every platform and the packages' C targets, which is where swift-profile-recorder's
sampler and sqlite-nio's vendored SQLite do their OS work. The queue counts only what Swift files importing Darwin
use on Darwin.

Their queue (run `7a5b6bcd3804-48fa9ade`) had four gaps, in two packages, and `6953d40` closes them:

- **getline** (swift-profile-recorder reads its sampler's messages from a stream, line by line):
  `FileStream.readLine(strippingNewline:)`. It reads any stream the way the standard library's
  `readLine(strippingNewline:)` reads the standard input, and has its name and parameter: the line is decoded as
  UTF-8 with invalid bytes repaired, the newline (and a carriage return before it) is stripped by default, and the
  end of the file is `nil`. A failure throws without retrying, as FileStream's other reads do; the stream's error
  indicator is set. Rejected: a bytes result, and reusing a caller's buffer across calls as getline can, since the
  adopter decodes each line.
- **MAP_FILE** (swift-profile-recorder maps an image with `MAP_FILE|MAP_PRIVATE`): `MemoryMapping(file:)` now says
  a file mapping needs no option, and that MAP_FILE is zero.
- **timespec_get and TIME_UTC** (swift-memcache-gsoc's timestamps): `ClockID.currentTimeSpec()` now says they give
  realtime's reading.
- `system_free` moves to Exports.swift. It was in Syscalls+PathsAndFiles.swift, which WASI doesn't compile, and
  FileStream, which now calls it, exists on WASI.

Tests: ProvisionalStdioTest's `testReadingLines` covers lines with and without a newline, CRLF, an empty line, a
line longer than getline's first buffer, a NUL byte, an invalid UTF-8 byte, the end of the file, and a write-only
stream's EBADF. The getline mock case is new too. SmallGapsTest checks timespec_get against realtime, and checks
that MAP_FILE is zero. The full suite passes with testVolumeAttributes skipped.

## 40. coverage-2: the Resume-here rows, part done: `5e89235`, `b583bdf`

The coverage-2 lane (worktree `../coverage-2`, from system-next `3f9f9e1`) took the Resume-here rows and stopped
on quota partway; the table above says what's left.

- **B2** (`5e89235`): the README bullet naming `Utilities/nio-coverage/check.sh` goes.
- **P3b** (`5e89235`): `skip._TestUtilities` in swift-homomorphic-encryption's package file. The lexical scan read
  swift-testing's `Comment` there as an OS name. The survey's test-support pattern,
  `(Test|Testing)(Support|Utilities|Utils|Helpers)$`, already matches `_TestUtilities`; the generated file just
  doesn't carry that to check.sh. Rejected for now: the generator writing `skip.<Target>` for every target its
  pattern matches, which would keep the survey and the check agreeing, but only for files it generates later (it
  never rewrites one).
- **status.py's marker parser** (`b583bdf`): `MacTypes OSStatus` and `Mach-O load_command` name OSStatus and
  load_command, as `string.h memcmp` names memcmp; a plural generic noun alone (`constants (FAT_CIGAM, ...)`)
  isn't a C name; a comment line opening with a parenthesis continues a marker. `--dump-markers` over every
  adopter changed only swift-build's three markers that need it.

**M1, per marker** (swift-build's, and swift-docc's PIPE_BUF). Section 36's call holds where the names are the
MachO module's; the files already import them from MachO.

| Marker | Answer |
|---|---|
| MachO.swift:16, Mach-O file structures | not System's: the MachO module's (section 36); the marker says so too |
| MachOTests.swift:20, MergeableLibrariesBuildOperationTests.swift:23 (load_command, segment_command, FAT_\*, LC_\*) | not System's: MachO's, as above |
| Architecture.swift:29, mach-o/utils.h's three functions | not System's: libdyld's, in `MachO.dyld.utils`; Mach.CPUType has the types they take |
| Architecture.swift:18 and MachO.swift:69, CPU types | covered: `Mach.CPUType` and `CPUSubtype` (section 36) |
| MachO.swift:69, vm_prot_t | the standard library's `Int32` (section 37): it types segment_command's `maxprot` and `initprot`, and swift-build declares it so off Darwin already |
| MachO.swift:76, ar.h (ar_hdr, ar_name, ar_size, SARMAG, AR_EFMT1) | section 36's call doesn't cover it: `Darwin.ar` is an explicit submodule of Darwin, and no other module declares it. Default: not System's, a file format as Mach-O's are, with the standard library's answer (the 60-byte header's fields read from the buffer; SARMAG is 8, AR_EFMT1 the literal `#1/`), which would also let swift-build parse archives off Darwin, where its `canImport(Darwin.ar)` path throws. Alternative: `CInterop.ArchiveHeader` with Swift-named accessors and ARMAG, SARMAG, ARFMAG and AR_EFMT1, if the C library's file-format headers belong with section 7's families; one adopter, and no call takes it |
| Error.swift:21 and PbxCp.swift:21, MacTypes OSStatus | the standard library's `Int32` (section 31) |
| SWBBuildServiceConnection.swift:23, abort | `fatalError(_:)` (mapping.ini's `[termination]`): an opt-in crash of the IDE when the build service fails. fatalError traps where abort raises SIGABRT; both leave a crash report, and fatalError's has the message |
| SWBDispatch.swift:22, off_t | new: `CInterop.Offset` (off_t), as `CInterop.Time` is time_t. The marker asks for an alias, and `Int64` doesn't serve cross-platform code: 64-bit Linux's off_t is `Int` |
| swift-docc's OutOfProcessReferenceResolver.swift:16, PIPE_BUF | new: `SystemConfig.maxAtomicPipeWriteBytes: Int` (PIPE_BUF, 512 on Darwin), next to `maxFileNameBytes` (NAME_MAX), as `PathName.maxAtomicPipeWriteBytes` is `_PC_PIPE_BUF` (section 3's pattern) |

**P3a, PThread cancellation, designed** (not in code): `PThread.ID.cancel() throws(Errno)` (pthread_cancel), on the
ID as `setName`, `setAffinity` and `setScheduling` are, since swift-distributed-actors cancels a detached thread; not
`noasync`, as Darwin doesn't mark pthread_cancel. For the calling thread, `PThread.testCancellation()`
(pthread_testcancel) and `PThread.withCancellationDisabled(_:)` (pthread_setcancelstate, restoring the previous
state however the body ends), both `noasync` as Darwin marks them. The docs say that a cancelled thread ends at a
cancellation point (System's blocking calls among them) as `PThread.exit()` ends it: no `defer` runs, and what the
stack holds leaks. Rejected: asynchronous cancellation (no Swift code is async-cancel-safe; the runtime allocates
and retains anywhere), a bare enable/disable toggle that code can forget to restore, a method on the owner. Not on
Android, whose Bionic has no pthread_cancel. Mocks: pthread_cancel and pthread_setcancelstate return error
numbers. Test without timing: the thread disables cancellation, signals, and waits on a pipe while the test cancels
it; after the scope, `testCancellation()` must end it, and a flag set after that call must stay false. Open: a join
can't tell a cancelled thread from one that returned (System's joins return nothing).

**Finding: the tool never saw swift-build's ar.h.** platforms.py's Darwin `canImport` set has `Darwin.uuid` but not
`Darwin.ar`, so `#if canImport(Darwin.ar)` is false everywhere, and the code under it isn't extracted: swift-build's
index at `4df9fdd` has `c:@S@ar_hdr` in module `Darwin.ar`, but no run lists it, so section 37's empty toolchain queue
missed it. The ecosystem clones' submodule `canImport`s: Darwin.ar (4), MachO.dyld.utils (3), os.log and os.signpost
(3 each), Darwin.C (1), Foundation.Process (12) and Foundation.NSTask (3). The last two may really be false on
Darwin; check before adding them.

Files: the brief allows new files only under Sources/System and Tests/SystemTests (and sorted inserts in
CMakeLists.txt, CSystem and Samples/main.swift), so the new API goes in new files, its syscalls and constants
included.

Tests: before any change, at `3f9f9e1`: XCTest 565 tests, 4 skipped (dup3, pipe2 twice, the controlling terminal),
0 failures; swift-testing 496 tests in 80 suites, passed. Nothing under Sources has changed since, so there was no
second run.

## 41. Answers outside System, and what the extraction couldn't see: `419fd1b`, `1c054a2`, `6b6c307`, `3e4e890`, `d5137df`

The coverage-3 lane (worktree `../coverage-3`, from system-next `6a9833f`) took section 40's rows M1b, M1c and M1d
as designed there.

- **M1b** (`419fd1b`): status.py takes answers outside System from mapping.ini at System's commit, for the gap names
  System doesn't name at all. A name in an entry with a `swift` answer is *standard library*, and one in an entry
  marked `wrap = no` is *not System's*, the `swift` answer first, as ecosystem.py's Darwin queue decides them. `X
  members` takes X's entry, and a phrase whose uncovered names all have answers takes the first kind among them; the
  table gives the entries. Neither status is in the work list. *Covered* is still only what System's sources
  document, and a name that System names while a marker asks for more keeps its gap (`STILL_NEEDED`). Section 3's
  header and METHOD say so, and the header notes uncommitted changes to mapping.ini, which aren't read. Rejected:
  counting the answers as covered, which would say System has what it doesn't; and leaving them missing, which kept
  the MachO module's file format and the standard library's answers in the work list for good.
- **M1c** (`6b6c307`): `[Mach-O file format]` (`wrap = no`), with every Mach-O name swift-build's extraction finds,
  and LC_MAIN and LC_SYMTAB from its tests' marker; `[Mach-O architecture names]` (`wrap = no`), mach-o/utils.h's
  three functions, libdyld's (`MachO.dyld.utils`); `[ar archive header]` (`swift` and `wrap = no`: the header's
  fields read from the archive's bytes, with section 40's alternative, `CInterop.ArchiveHeader`, in its note as
  rejected); a shared note in `[termination]` for swift-build's abort; and off_t out of `[C scalar types]`, into an
  entry of its own that the derivation decides (section 42). The Mach-O entries take mapping.ini's header rule for
  `mach-o/*`, dynamic loading; ar.h has none, and takes C libraries, beside SQLite.
- **M1d** (`1c054a2`): platforms.py's Darwin `canImport` set now has Darwin.ar, Darwin.C, MachO, MachO.dyld.utils,
  os.log and os.signpost, each true on macOS 26 (checked with `swiftc -typecheck`, as are Darwin.uuid and
  MachO.dyld). Foundation.Process and Foundation.NSTask, which the ecosystem's clones also test for, are false there
  and stay out; the comment says so.
- The runs showed two more mapping fixes. `[fts]` cited DirectoryWalk's path initializer without the `options:`
  that the foundation-gaps lane added, so every package reported it as cited but missing on the tip (`3e4e890`; the
  entry stayed covered through its other declarations). And with os.log and os.signpost true, swift-build's
  OSLogPrivacy and WasmKit's OSSignposter and OSSignpostIntervalState join `[os_log and signposts]` (`d5137df`).

Finding: importing the tool's scripts from a Python harness without PYTHONDONTWRITEBYTECODE left an untracked
`scripts/__pycache__`, and check.sh counts any untracked file under the tool as a dirty tool. The first two runs,
`4b7e79411e68-aa87d610` and `3e4e8900f8cf-ed65a0b5`, are stored as dirty, so they can't be verified. Python ignored
the stale bytecode, whose sources were newer, so their results stand; section 44's runs are clean reruns.

## 42. CInterop.Offset and SystemConfig.maxAtomicPipeWriteBytes: `12c5ac9`

Row M1e, as section 40 designed it, in new files, since another lane is editing the existing ones:

- `CInterop.Offset` is C's off_t, as `CInterop.Time` is time_t, for code whose own API names it: swift-build's
  DispatchIO offsets (SWBDispatch.swift:22). It's on every platform, as System's internal `_COffT` is, and its doc
  gives the widths: Int64 on Darwin and WASI, Int on Linux and Android, Int32 on Windows. Rejected: `Int64` alone,
  which 64-bit Linux's off_t isn't.
- `SystemConfig.maxAtomicPipeWriteBytes: Int` is the headers' PIPE_BUF (512 on Darwin, 4096 on Linux), for
  swift-docc's out-of-process resolver (OutOfProcessReferenceResolver.swift:16). It sits beside `maxFileNameBytes`
  and has the name of the pathconf name, `PathName.maxAtomicPipeWriteBytes` (_PC_PIPE_BUF), as section 3's limits do:
  `value(.maxAtomicPipeWriteBytes, for: pipe)` is a pipe's own limit. Gated `!os(Windows) && !os(WASI)`, as
  CompileTimeLimits.swift is.

Tests: OffsetAndPipeLimitTest checks the alias against off_t (and Int64 on Darwin, Int on Linux), PIPE_BUF against
POSIX's least (512) and Darwin's 512, and a pipe's fpathconf limit against the constant on Darwin and Linux.
Linux, Windows and WASI are unbuilt here.

## 43. PThread cancellation: `4b7e794`

Row P3a, as section 40 designed it:

- `PThread.ID.cancel() throws(Errno)` wraps pthread_cancel, on the ID, since swift-distributed-actors cancels a
  detached thread; not `noasync`.
- `PThread.testCancellation()` wraps pthread_testcancel, and `PThread.withCancellationDisabled(_:)` wraps
  pthread_setcancelstate; both are `noasync` with Darwin's own message, "Use Task cancellation instead". The scope is
  `rethrows`, with `R: ~Copyable`, as UnfairLock's `withLock` is, and restores the state it found (enabled, or
  disabled by an enclosing scope) however its body ends. pthread_setcancelstate fails only for a state other than
  the two it's given, so the scope doesn't throw of its own.
- The docs say that a cancelled thread ends at its next cancellation point (System's blocking calls among them,
  `open` and `close` included) as `PThread.exit()` ends it: no `defer` runs, what the stack holds leaks, and a lock
  it holds stays locked.
- Rejected, as designed: asynchronous cancellation, a bare enable/disable toggle, and a method on the owner. Not on
  Android. Open, as designed: a join can't tell a cancelled thread from one that returned.
- pthread_cancel's and pthread_setcancelstate's mocks return error numbers; pthread_testcancel has none.

Tests (PThreadCancellationTests.swift), none waiting for time:
- The designed one: a thread cancelled inside the scope finishes it, through a pipe read that blocks until after the
  cancel, and ends at `testCancellation()`, not after it.
- A thread blocked in a pipe read, with cancellation enabled, ends there. A thread-specific value's destructor reports
  the end, waited for up to the hang guard; after that, a byte ends the read, so a broken cancel fails the test
  instead of hanging it.
- The scope restores the states it found, nested and after a throw, and an uncancelled thread runs on.
- The mocks. `stress.sh` ran the new tests 20 times under CPU load, all passing.

Finding: System's read, which retries EINTR, doesn't hide a cancel on Darwin: a thread blocked in it ends there.

The full suite, before any change (`6a9833f`) and after the last change to Sources (`4b7e794`): XCTest 565 tests, 4
skipped (dup3, pipe2 twice, the controlling terminal), 0 failures, then 570, the same 4 skipped, 0 failures;
swift-testing 496 tests in 80 suites, passed, then 500 in 81, passed.

## 44. The queues after the rows, the new markers, and no fourth batch: `cddd4d2`

- The popular set's queue is empty (run `cddd4d209dce-0e679bef`): pthread_cancel is covered, and swift-homomorphic-encryption's
  `Comment` went with P3b's skip.
- The toolchain's queue is still empty (run `cddd4d209dce-c62022b2`). M1d brought swift-build's ar.h names into it, which
  `[ar archive header]` answers as the standard library's, and off_t, the standard library's before, is covered by
  `CInterop.Offset`. The run exits with check.sh's status 2, as before: the audited packages' names that no mapping
  entry has are the same as in run `a3a634eb2b19-06a7ddd5`.
- popular.tsv doesn't need a fourth batch now. The three batches' queues were short and one package each (sections
  38 to 40), the third's is empty, and the swift-server and swiftlang lists they came from are used up. A fourth
  would reach app-side packages, whose OS use comes mostly through Foundation, which the queue sets apart.
  Alternative, if wanted: the Swift Package Index's most-depended-on packages outside those lists.
- **The new markers.** status.py reads swift-foundation at `no-darwin`, where the foundation lanes continue
  (`STATUS_BRANCHES`, by default `swift-foundation=no-darwin`). The foundation-walk lane's three markers there are
  for Foundation's framework build, which can import only the SDK's System, and system-next has each: DynamicLibrary
  (dlopen with `.noLoad` and `.first`, dlsym, dlclose), `_dyld_image_count` (`DynamicLibrary.loadedImageCount`), and
  `CInterop.POSIXErrorCode`. Nothing is left for System to add; they wait for an OS whose SDK ships System 199. The
  first marker names System's DynamicLibrary, which the parser read as a C name, so DynamicLibrary joins
  `SWIFT_NAMES` and an `ANSWERED` entry covers the phrase. The packages-5 lane's sourcekit-lsp migration
  (`cb2881c5`) left no markers. Its one ask, a `_SystemPackageForPlugin` product so that sourcekit-lsp's plugins don't
  each carry a SystemPackage, is Package.swift's, outside this lane's files.

## 45. The `_version: 346` gates: System's own build reads the version

swift-foundation's package build warns "cannot find user version number for module 'Darwin'; version number
ignored" on `#if canImport(Darwin, _version: 346)` (its REPORT.md, foundation-walk, Findings). System's own build
doesn't ignore it:

- A clean, verbose build of SystemPackage (`swift build --target SystemPackage -v`, a fresh scratch path) has no such
  warning, with Xcode's Swift 6.2 or with the 6.5-dev snapshot that Foundation builds with (`org.swift.65202609211a`,
  `--build-system native`).
- A probe in a scratch copy of System, an `#error` under `canImport(Darwin, _version: 9999)` and another under
  `canImport(Darwin) && !canImport(Darwin, _version: 346)`, compiles with both toolchains, with System as the root
  package and as a client's dependency, and the same probe compiles in the client, whose module imports no Darwin.
  The version is read and compared: 346 is true and 9999 false (the SDK's Darwin interface says 347.0.12).
- So the ten gate lines stay as they are: there's no miscompile. Alternative, noted: a plain `canImport(Darwin)`,
  which needs the macOS 26 SDK (the package needs it already) and can't warn.
- Foundation's warning didn't reproduce outside its build: not standalone, not with its flags (`-library-level api`,
  MemberImportVisibility, ImportMacroAliases, AccessLevelOnImport, BuiltinModule), and not in a module that reaches
  Darwin's headers only through a C target. Its cause is still open, and Foundation's.
- The same condition gates code the brief didn't list, with the same answer: AttributeLists/VolumeCapabilities.swift
  (397 and 479), AttributeLists/Attribute.swift:408, and Sources/Samples/Beneath.swift:17.

## 46. Utilities/linux/build.sh --quiet: `43b1859`

With `--quiet`, a run writes its output only to the log and prints its two `==` lines, then a summary, then the
exit status line. The summary has the number of distinct error lines and the first 40 of them, and for `test`, the
totals and the failing tests' lines: swift-testing's lines with ✘, but its total, and XCTest's error lines under
Tests/, which have a line number but no column. An error line is a line with `error:`, but not the `` | `- error: ``
annotation under a diagnostic's source excerpt, which would count each error twice. Each list keeps the log's
order, drops repeats, and takes `/code/` out of paths. The default output is unchanged, and README.md documents the
option.

Checks, with no containers here: `bash -n`; the summary functions run over ../linux-logs (a clean run, build
errors, a crash, and failures in both test frameworks); and both scripts, before and after, run with a stand-in
`container` that replays a recorded log. Their default outputs are identical but for the date, and the quiet run's
log holds the whole output.

## 47. STATUS.md's platform imports: `cddd4d2`

STATUS.md's new section 4 tracks the long-term goal: no library of the repositories that update-checkout clones
for the main scheme imports a platform C module (Darwin, Glibc, Musl, Bionic, Android, WASILibc, ucrt, WinSDK, CRT,
visualc), in any form, on any platform. swift-system and swift are left out. Each repository of
`../ecosystem/scheme-main.tsv` is read at its migrated clone's branch in `../adopters` (migrate-darwin;
swift-foundation's no-darwin; wasmkit, llbuild and swiftpm under their adopters' names), else at its ecosystem
clone's HEAD, else it's *not cloned*. A per-repository table gives the Swift files that import one, per module and
per kind, and a module-by-kind table the totals. The counts are there, not here.

- The scan is lexical: ecosystem.py's survey pattern, now `import_of(modules)` so that both use it, widened to the
  ten modules, over each file with comments and strings blanked, since a fixture in a string literal isn't an
  import. It doesn't evaluate `#if`, and METHOD says so: an import under `#if os(Windows)` counts as one outside any
  condition does.
- Kinds are by path: a nested package (under a directory, below the root, with its own Package.swift) first, then
  tests (a test directory anywhere in the path: Tests, IntegrationTests, Fixtures, unittests and the like), then
  library (under a top-level Sources, Source, src, srcs, lib or products, outside a `.docc` catalog), else other
  (benchmarks, examples, tools, plugins, docs, utilities, and the root's manifest).
- Rejected: the manifests' targets, as the Adoption section uses them, which needs every clone's manifest evaluated
  (swift-foundation's needs a newer compiler than 6.2) and says nothing of nested packages; and platforms.py's `#if`
  evaluation, which answers what one platform's build compiles, not whether any does.
- `--branch-for` (`STATUS_BRANCHES`) sets a package's migration branch for the adoption and gaps sections too, whose
  header names it when it isn't the default; `STATUS_ECOSYSTEM` points at the clones.

## 48. coverage-4: windows-2's P3, the Win32 sources in CMake: `8caa741`

The coverage-4 lane (worktree `../coverage-4`, from system-next `bb950db`, after the 2026-10-01 convergence merge) took
four rows: STATUS.md's section 4 per platform, ABI symbols in section 1, windows-2's CMake patch, and the plugin
product (the Resume-here table's C1 to C4).

`Sources/System/CMakeLists.txt` now lists the twelve Win32 sources that windows-2 added after `b63bce9`: its patch P3
(Prototype/Win32/REPORT.md section 22), applied with `git apply` as it stands. They are DynamicLibraryWindows,
PathsWindows, ProcessEnvironmentWindows, ProcessIDWindows, Win32Console, Win32FileInformation, Win32Process,
Win32ProcessCreation, Win32Synchronization, Win32Thread, Win32Time and Win32Wait. The block stays in byte order, as
the others are (Win32FileIO before Win32FileInformation).

Check: CI's comparison (`.github/workflows/pull_request.yml`, CMake Validation), redone here with `swift package
describe` and the file's `add_library` and `target_sources` lists. Before, the twelve were SwiftPM's only sources
missing from CMake; after, none is, and CMake's only extras are the Linux-only IORing files in its conditional block.
Nothing builds CMake here.

## 49. STATUS.md's section 4, per platform: `30007dd`

Section 4 now counts what each platform's build compiles, not each import in any branch.

- **Branches.** Each adopter is read at its newest migration branch, the first of migrate-all, migrate-unix and
  migrate-darwin that its checkout in `../adopters` has (swift-foundation: migrate-unix, else no-darwin), named in the
  table's *Read at*. `../adopters-unix`'s checkouts are worktrees of `../adopters`' and share their branches, so
  nothing reads them. `--platform-branches` and `--platform-branches-for` (`STATUS_PLATFORM_BRANCHES`,
  `STATUS_PLATFORM_BRANCHES_FOR`) set the lists. Sections 2 and 3 stay on migrate-darwin (swift-foundation's
  no-darwin) against main: they measure the Darwin migration and its markers. Rejected: moving them to the newest
  branches too, which would mix other platforms' work into the Darwin migration's merge-base comparison.
- **Evaluation.** Each library file's `#if`s are evaluated by platforms.py for its eight families (Darwin as macOS,
  Linux as glibc, Musl, Android, WASI, FreeBSD, OpenBSD, Windows), with FOUNDATION_FRAMEWORK false as in section 2.
  A file counts for a platform when that platform's build compiles one of its platform-module imports. An unknown
  flag or trait makes an import *maybe*, which counts, and the cell says how many: the evaluator's own rule, and
  the goal's, since an import that some configuration compiles is still there. Rejected: counting only what surely
  compiles, which would drop WasmKit's trait-gated files that its default builds compile. A file whose conditions
  don't parse counts as maybe everywhere, as section 2's fallback does.
- **The lexical count stands beside it**: per repository, the library files with any import; per platform, in the
  summary, the files that import the platform's own modules (Glibc for Linux, FreeBSD and OpenBSD), so the
  difference is the dead branches. Tests, other code and nested packages stay lexical, as counts, and the
  module-by-kind table stays as it was.
- **A summary by platform** opens the section: the library files whose build imports one, the repositories with
  any, and the lexical count. The per-repository module lists are gone; the platform columns say more.
- `canImport` finds the platform's own modules and platforms.py's cross-platform ones, but not a package's own or
  its dependencies' (no manifest is read). Checked at the adopters' commits of 2026-10-01: the only `canImport` of
  any other module that guards a platform import is swift-foundation's EmscriptenLibc, false on all eight, rightly.
- Spot checks: swift-nio's NIOLock.swift imports Glibc only under `#elseif canImport(Glibc)`, after a branch for
  `canImport(Darwin) || os(Linux) || os(Android)`, so it counts for FreeBSD and OpenBSD, not Linux;
  Subprocess+BSD.swift's Glibc is FreeBSD's and OpenBSD's; swift-foundation's three Darwin imports that Darwin doesn't
  compile are under FOUNDATION_FRAMEWORK.

**Finding: platforms.py read `$Embedded` as true.** It took every `$Feature` atom as true, and WasmKit guards its
platform code with `#if !$Embedded`, so those files were dead on every platform, here and in section 2's macOS count.
`$Feature` now answers as hasFeature does: false for FALSE_FEATURES (Embedded), true otherwise. check.sh's and
ecosystem.sh's extractions of WasmKit change the same way at their next runs, which are full runs anyway: these edits
change adopter-coverage's tool id.

## 50. Section 1's ABI symbols: `c7b71cc`

Michael's ask: beside the API points, the number of symbols the built SystemPackage exports, and the added public
declarations that export a symbol although they only forward a C header value, the candidates for
`@_alwaysEmitIntoClient`. Sources are unchanged; the list is STATUS.md's.

- **What's counted.** `scripts/abi.py` builds HEAD and api-delta's base commit (`swift build -c release --target
  SystemSockets`, from a `git archive` export patched as api-delta patches it, so no network), and `nm -gUm` lists
  each module's external symbols, less the private externs. A result is cached by the commit's `Sources` and
  `Package.swift` trees, so main builds again only when it moves. The table sorts them by their demangled form:
  property descriptors, conformances, types, and code (functions and accessors), public when it belongs to a
  declaration of api-delta's symbol graphs (by USR) and other when it doesn't (`@usableFromInline` internals,
  synthesized Equatable and Hashable members, deinitializers, initial values). SystemSockets is counted too, since
  it holds a fifth of the additions.
- **nm, not swift-api-digester.** The digester's ABI mode (`-dump-sdk -abi`) runs with Swift 6.2, but it lists
  declarations, not what the build exports: no property descriptors, conformance records or metadata, and the
  `@_alwaysEmitIntoClient` declarations that export nothing are in it. A release build, since a debug build's
  `-enable-testing` exports internal declarations too.
- **Not library evolution.** The SDK's System is built with it, but SystemPackage doesn't build with
  `-enable-library-evolution` (finding 2). With that file patched in a scratch copy, it exported nearly the same set
  as the plain release build: only the plain build exports stored properties' initial values, OwnedFD's three
  addressors, a few protocol witnesses and the synthesized `__derived_*_equals` functions, and only the evolution
  build those types' `==` operators. Alternative, once the file is fixed: count the library-evolution build, which
  would match the SDK's own.
- **Candidates.** An added declaration that exports code and whose body, on the lines the macOS release build
  compiles, is one expression (a getter and a setter for a property; stores into `rawValue` or a delegation to
  `init(rawValue:)` for an initializer) that calls nothing but conversions (a type's initializer, `numericCast`,
  Duration's unit factories) and reads a C name: an all-caps macro or enumerator, System's `_`-prefixed accessor
  for one, or a snake_case field. Each row says which kind, the C names, what it exports and where. Rejected: a
  list of every exporting declaration without AEIC, which would put stored properties (which can't be AEIC) and
  `description`s beside the constants.

Findings:

1. **A property descriptor comes with every public property, `@_alwaysEmitIntoClient` or not**, and they're most of
   what System exports. The SDK's own `libswiftSystem.tbd` (macOS 26) has them for `Errno`'s and
   `FileDescriptor.AccessMode`'s constants, which are AEIC. AEIC removes a property's accessors, not its descriptor.
2. **SystemPackage doesn't build with library evolution.** `Threads/PThreadReadWriteLock.swift` uses
   `CInterop.PThreadReadWriteLock` (Darwin's `pthread_rwlock_t`, from `_DarwinFoundation2`) in `@usableFromInline`
   and `@_alwaysEmitIntoClient` code without importing a platform module, and library evolution requires the file
   to import the module its inlinable code names. Seven errors, that file only. Its siblings, such as
   PThreadMutex.swift, have the `#if SYSTEM_PACKAGE_DARWIN import Darwin ... #endif` block it lacks. A need outside
   this lane's files, for the Threads owner; nothing in CI builds with library evolution.
3. **Every candidate is SystemSockets'.** SystemPackage's additions mark their forwarding code
   `@_alwaysEmitIntoClient`; what they export is stored properties' accessors, `description`s, attribute-buffer
   readers and the like. SystemSockets' candidates are `ResolutionFlags`' and `ReverseResolutionFlags`' constants
   and raw-value initializers, `TCPConnectionInfo`'s fields, and the ancillary message header's level and type.
   They stay as they are: the brief asked for the list, and SystemSockets is outside this lane's files.

Checks: no Swift changed. A run of status.py into a scratch file printed both parts, and the candidate rules were
read against every added declaration that exports code: those they turn down are buffer readers, string
conversions, `description`s, memberwise and failable initializers, and stored properties.

## 51. `_SystemPackageForPlugin`: `79ee4f7`

The packages-5 lane's ask (O2): each of sourcekit-lsp's plugin dylibs links a SystemPackage, and a process that loads
a plugin beside its host holds two copies, whose Swift classes the Objective-C runtime reports as implemented in
both (PACKAGES-5-REPORT.md, "Two copies of SystemPackage"). swift-tools-protocols answers the same problem for
SKLogging with `_SKLoggingForPlugin`: the same sources as a module of another name.

- **Shape.** A `_SystemPackageForPlugin` library product and target, with SystemPackage's dependency, excludes and
  settings, whose path, `Sources/_SystemPackageForPlugin`, is a symbolic link to `System`, as swift-tools-protocols'
  `Sources/_SKLoggingForPlugin` links to `SKLogging/`. SwiftPM refuses two targets with one path ("has overlapping
  sources", checked in a scratch package), so the link is what lets the sources build twice. A plugin target depends
  on the product and imports it as SystemPackage with `-module-alias SystemPackage=_SystemPackageForPlugin`, as
  `_SKLoggingForPlugin` aliases its own dependency; swift-tools-protocols' `systemPackageForPlugin`
  (Package.swift:31) would name the product, and sourcekit-lsp's `…ForPlugin` targets would add the alias. The
  manifest's comment gives the recipe.
- **Not on Windows.** Git for Windows checks a symbolic link out as a plain file unless it's set to make links, and
  SwiftPM then rejects the target's path, so the whole package would fail to load for those Windows clients. The
  manifest declares the product only when the host evaluating it isn't Windows. sourcekit-lsp's dependency on
  System is Darwin's only. Alternatives: declare it everywhere, as swift-tools-protocols does (its Windows CI makes
  links); or declare it wherever the link is a directory, read with FileManager in the manifest.
- **Cost.** swift-system's own builds compile its sources twice, since a root package builds all its targets: on
  this machine, about 10 s more of a debug build's wall time (33 s of CPU) whenever Sources/System changes. No
  SwiftPM setting keeps a root package from building a target, and declaring it only on request (an environment
  variable) would hide it from clients too.
- **Files.** The link is the one new file outside this lane's files, and the product needs it; it can't collide
  with the lanes editing Sources/. CMake is unchanged (it adds only `CSystem` and `System`), and CI's CMake
  comparison reads the SystemPackage target by name.

Checks:
- `swift build` builds `_SystemPackageForPlugin`, its symbols mangled under the new name
  (`$s23_SystemPackageForPlugin5ErrnoV…`), and `swift package describe` gives it SystemPackage's sources.
- A scratch client (in `.build`, deleted after) with a host target on SystemPackage and a plugin target on
  `_SystemPackageForPlugin` with the alias, linked into one executable: it builds and runs, printing `FilePath` from
  the host and `_SystemPackageForPlugin.FilePath` from the plugin, two types, as the plugin's copy needs.
- api-delta's `patch_manifest.py` still applies to the manifest (it drops Samples).

## 52. coverage-4's stop: tests and STATUS.md: this commit

STATUS.md is regenerated once, here, at `79ee4f7`: section 1 with the ABI table and the candidates, section 4 per
platform at the adopters' newest branches. The run rebuilt api-delta (Sources and Package.swift changed) and HEAD's
release build; main's came from the cache.

Tests, `swift build && swift test`: before any change (`bb950db`) and after the last change to Package.swift and
Sources (`79ee4f7`), the same both times: XCTest 572 tests, 5 skipped (dup3, pipe2 twice, the root-only credentials
spawn, the controlling terminal), 0 failures; swift-testing 502 tests in 82 suites, passed. Only the plugin target
is new to the build; no Swift source changed.

Scratch: the probes, the scratch client and the logs under `.build/c4-scratch` are deleted, and so is this worktree's
`.build` (status.sh's caches included; the next run rebuilds them).
