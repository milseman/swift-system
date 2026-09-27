# posix-more: portable POSIX API that adopters still call

The `posix-more` lane adds the POSIX interfaces that swift-nio,
swift-foundation, swift-package-manager and swift-subprocess still call
directly, found with `Utilities/adopter-coverage` and a grep of their sources.
Each cluster below is one commit. For each: the API, the design calls with
the alternatives they rejected, the adopter code it replaces, and what
couldn't be checked here.

All new API is `@available(System 199, *)`. Nothing here builds for Linux,
Android, FreeBSD, OpenBSD or WASI on this machine, so code for those
platforms was written from their headers, as noted per cluster.

## 1. Vectored I/O

`Sources/System/VectoredIO/VectoredIO.swift`,
`Sources/System/Internals/Syscalls+VectoredIO.swift`.

| API | C |
|---|---|
| `CInterop.IOVec` | `struct iovec` |
| `FileDescriptor.write(vectors:retryOnInterrupt:)` | `writev` |
| `FileDescriptor.read(intoVectors:retryOnInterrupt:)` | `readv` |
| `FileDescriptor.write(toAbsoluteOffset:vectors:retryOnInterrupt:)` | `pwritev` |
| `FileDescriptor.read(fromAbsoluteOffset:intoVectors:retryOnInterrupt:)` | `preadv` |
| `write(_:_:)`, `write(_:_:_:)`, and `toAbsoluteOffset:` forms, over `RawSpan`s | `writev`, `pwritev` |
| `writeAll(_:_:)`, `writeAll(_:_:_:)`, and `toAbsoluteOffset:` forms | `writev`, `pwritev`, looped |
| `read(into:_:)`, `read(into:_:_:)`, and `fromAbsoluteOffset:` forms, into `inout MutableRawSpan`s | `readv`, `preadv` |

Every method is also `retryOnInterrupt:`, and throws `Errno`.

Design calls:

- **The vector forms take `UnsafeBufferPointer<CInterop.IOVec>`**, the
  caller's own array, so a caller that pools its vectors, as NIO's
  `PendingWritesManager` does, allocates nothing per call. Rejected:
  `Span<CInterop.IOVec>`. Each element is a raw pointer, so a span adds no
  safety, and NIO's pool is already an `UnsafeMutableBufferPointer`.
- **Labels: `write(vectors:)` and `read(intoVectors:)`.** Rejected:
  overloading `write(_:)` and `read(into:)` by type. `fd.write(iovecs)` reads
  as if it wrote the vector array's own bytes, and `fd.read(into: iovecs)` as
  if it read into them. Also rejected: `gathering:` and `scattering:`, which
  are the concept's jargon; C's `v` is the name people search for.
- **No vectors return 0 without a call.** POSIX requires `readv` and `writev`
  to reject an `iovcnt` of 0 with `EINVAL`, and Darwin does; Linux returns 0.
  Found by the test for it. Rejected: passing the call through and
  documenting the difference, which makes portable code check for an empty
  batch per platform, for an edge case whose meaning is obvious. The cost is
  that an empty batch doesn't report a bad descriptor.
- **Span forms of fixed arity, two and three buffers.** A header and a
  payload, and a header, a payload and a trailer (a chunk, a record and its
  checksum), cover the common cases. They build the vectors on the stack.
  Rejected, as in the Span audit (`../Claude outputs/span-report.md`): a
  variadic `RawSpan...`, which crashes the 6.2 compiler; `[RawSpan]`, which
  isn't allowed; and a builder, which the 6.2 checker doesn't stop from
  outliving its spans.
- **`writeAll` over spans resumes inside whichever buffer a partial write
  stopped in** (`_advanceVectors`), which is the classic hand-written bug.
  There's no `writeAll(vectors:)`: resuming means rewriting the caller's
  vectors in place, and NIO does its own accounting.
- **Reads take `inout MutableRawSpan`**, which `ContiguousArray`, `Data` and
  `InlineArray` vend safely. Rejected: `OutputRawSpan`, which only unsafe
  code can create in 6.2 (the single-buffer `read(into:)` has that form).
  Two or more `inout` spans need explicit `@_lifetime(x: copy x)` in 6.2.
- **The Span floor is the one the existing Span I/O uses** (macOS 15 and
  its peers), on an extension that also carries `System 199`, so a later
  switch to a `SystemWithSpan` macro finds every such declaration.
  Rejected: the true floor, macOS 10.14.4, which the audit found is enough,
  but which should change for all the Span API at once.
- **`preadv` and `pwritev` carry macOS 11** (and iOS 14, watchOS 7, tvOS
  14), when Darwin added them, on an extension with `System 199`.
- **`OwnedFD` doesn't forward these.** The rule from `Prototype/Forwarding`
  is that new `FileDescriptor` API needs no `OwnedFD` change; use
  `owner.fileDescriptor`. Rejected: reading "OwnedFD forwards the byte I/O"
  as covering every new read and write.
- **`CInterop.IOVec` is declared in SystemPackage too.** SystemSockets
  declares the same alias; its declaration shadows this one inside
  SystemSockets and in clients that import both, which SystemSocketsTests
  confirms. Folding SystemSockets in should delete its copy.
- No convenience initializer on `iovec`: code that builds vectors is doing C
  interop, and imports the C library for `iovec`'s members anyway
  (MemberImportVisibility requires it; see `VectoredIOProbe.swift`).

Adopters: NIO's `Posix.writev` (`NIOPosix/System.swift`), used by
`BaseStreamSocketChannel`, `PipePair` and `NIOBSDSocket.writev`: NIO's
hottest write path, over a pooled `UnsafeMutableBufferPointer<IOVector>`.
NIO sizes that pool with `UIO_MAXIOV`; System has the runtime value,
`SystemConfig.value(.maxIOVectors)`, but no compile-time constant. No
adopter calls readv, preadv or pwritev.

Unverified off Darwin: WASI is excluded, although wasi-libc has all four
calls, because nothing here builds for it. On Android, `preadv` and
`pwritev` go through CSystem shims that fail with `ENOSYS` below API level
24, the pattern `pthread_getname_np`'s shim uses; the shim and its Swift
call are compiled only there.

## 2. Environment

`Sources/System/Environment/ProcessEnvironment.swift`,
`Sources/System/Internals/Syscalls+Environment.swift`, and
`csystem_environ` in CSystem.

| API | C |
|---|---|
| `ProcessEnvironment.value(of:) -> String?` | `getenv` |
| `ProcessEnvironment.set(_:to:overwrite:) throws(Errno)` | `setenv` |
| `ProcessEnvironment.remove(_:) throws(Errno)` | `unsetenv` |
| `ProcessEnvironment.entries() -> [(name: String, value: String)]` | `environ` |
| `ProcessEnvironment.withUnsafeEntries(_:)` | `environ`, as `posix_spawn` and `execve` take it |

Design calls:

- **The namespace is `ProcessEnvironment`.** Rejected: `Environment`, which
  swift-subprocess and SwiftPM's Basics each declare at top level.
  Subprocess's clients import System for `FilePath`, so a System
  `Environment` would make their `Environment.inherit` ambiguous.
- **Values are copied out**, as `String`s. `getenv`'s pointer dangles after
  the next `setenv` or `unsetenv` of that variable, which is the hazard to
  remove. The race with other threads is inherent, and documented: C gives
  the environment no lock.
- **No lock on Darwin.** Foundation and Subprocess take `environ_lock_np`
  when they can, but it's private SPI (`libc_private.h`), and System ships
  in the SDK. Rejected: declaring the SPI.
- **Names and values are checked before the call.** An empty name, or one
  with `=`, is `EINVAL` from `setenv` anyway; a null character in a Swift
  string would cut the C string short, and set or remove a different
  variable. `value(of:)` returns `nil` for an invalid name.
- **`entries()` keeps the environment's order and its duplicates**, and
  skips entries without `=`, as Foundation does. It splits each entry's
  bytes, not a `String`: a `String` splits only between characters, and a
  value can start with a combining mark. Rejected: a dictionary, which loses
  the order that `execve` passes on and hides duplicates.
- **Strings are repaired** (U+FFFD) where the bytes aren't UTF-8;
  `withUnsafeEntries` reaches the bytes, and is what `posix_spawn` needs.
  Rejected: a lossless value type. `SystemString` is internal, and a public
  byte-string type is a bigger question than this lane.
- **The `environ` array comes from a C shim**: Darwin's `_NSGetEnviron`,
  since a library can't link `environ` there, and `environ` elsewhere, which
  glibc declares only with `_GNU_SOURCE`. An empty array (glibc's
  `clearenv` sets `environ` to NULL) is passed as one null entry.
- **Unix only, not WASI or Windows.** On Windows the CRT's copy of the
  environment and the Win32 block diverge (`_putenv` changes both,
  `SetEnvironmentVariableW` only the latter), and SwiftPM uses both; that's
  for the Win32 work to design. wasi-libc builds `environ` lazily
  (`__wasilibc_get_environ`), which nothing here can test.
- Not added: `secure_getenv` and `issetugid` (Foundation's `getEnvSecure`),
  `clearenv` (not on Darwin), and `putenv` (which keeps the caller's
  string).

Adopters:
- NIO: `getenv` for `SWIFTNIO_STRICT`, NIOSingletons' and NIOEmbedded's
  settings, and NIOFS's `HOME`, `USERPROFILE` and `TMPDIR` (8 lines).
- SwiftPM: Basics' `Environment` calls `setenv` and `unsetenv` (6 lines).
- Subprocess: `Environment.inherit` copies the environment block
  (`_subprocess_get_environ`, 3 lines).
- Foundation, by grep: `ProcessInfo.environment` reads `_NSGetEnviron` or
  `environ`, and `String+Path` reads `HOME` and `CFFIXED_USER_HOME`.

Unverified off Darwin: the `environ` shim on Linux, Android, FreeBSD and
OpenBSD, which declares `extern char **environ` itself.

## 3. Time

`Sources/System/Time/ClockID.swift`, `Sources/System/Time/Sleep.swift`,
`Sources/System/Internals/Syscalls+Time.swift` and `Constants+Time.swift`.

| API | C |
|---|---|
| `CInterop.ClockID`, `ClockID` | `clockid_t` |
| `.realtime`, `.monotonic`, `.processCPUTime`, `.threadCPUTime` | `CLOCK_REALTIME`, `CLOCK_MONOTONIC`, `CLOCK_PROCESS_CPUTIME_ID`, `CLOCK_THREAD_CPUTIME_ID` |
| `.monotonicRaw` (Darwin, Linux, Android) | `CLOCK_MONOTONIC_RAW` |
| `.monotonicRawApproximate`, `.uptimeRaw`, `.uptimeRawApproximate` (Darwin) | `CLOCK_MONOTONIC_RAW_APPROX`, `CLOCK_UPTIME_RAW`, `CLOCK_UPTIME_RAW_APPROX` |
| `.boottime`, `.realtimeCoarse`, `.monotonicCoarse`, `.tai` (Linux, Android) | `CLOCK_BOOTTIME`, `CLOCK_REALTIME_COARSE`, `CLOCK_MONOTONIC_COARSE`, `CLOCK_TAI` |
| `ClockID.currentTime() throws(Errno) -> Duration` | `clock_gettime` |
| `ClockID.resolution() throws(Errno) -> Duration` | `clock_getres` |
| `PThread.sleep(for:retryOnInterrupt:) throws(Errno)` | `nanosleep` |

Design calls:

- **The type is `ClockID`,** after `clockid_t`, as `ProcessID` and `UserID`
  are after theirs. Rejected: `Clock`, which would shadow the standard
  library's `Clock` protocol in every client that imports System.
  `IntervalTimer.Clock` (the events lane's, for timerfd) is nested, so it
  doesn't; it could take a `ClockID` later.
- **Readings are `Duration`s,** so these methods carry macOS 13.
  Rejected: returning `timespec`, which back-deploys further but hands the
  caller the normalization rules; and offering both, which doubles the API.
- **No `timespec` and `Duration` conversions.** The platform overlays
  already declare `Duration(timespec)` and `timespec(Duration)` (and
  `timeval`'s): Darwin's from macOS 13, and Glibc's under `os(Linux)`,
  which covers Musl. The same initializers in System would make every use
  of them ambiguous there. Rejected: declaring them for Android, FreeBSD
  and OpenBSD only, where an overlay could add them later and break
  clients the same way. System's own `_timespec(_:)` and `_duration(_:)`
  (`Events/Timeouts.swift`) do the work inside; note that the overlay's
  `timespec(Duration)` gives a negative duration a negative `tv_nsec`.
- **The `_CLOCK_` constants reuse what exists**: `_CLOCK_REALTIME` and
  `_CLOCK_MONOTONIC` from `Constants+Threads.swift` (`clockid_t`, not on
  Darwin), and Linux's `_CLOCK_BOOTTIME` from `Constants+Events.swift` (a
  `CInt`, the same type as `clockid_t` there). Darwin's C library names its
  enumerators `_CLOCK_REALTIME` and so on, but Swift renames them to the
  macros' `CLOCK_` names and makes the underscored ones unavailable, so
  `Constants+Time.swift` defines the Darwin set. The linux-build lane's
  `e63b366` removes the Events copies of `_CLOCK_REALTIME` and
  `_CLOCK_MONOTONIC`, which collide with the Threads ones on Linux today.
  Linux-only values are the kernel's, the same on every architecture, as
  the Events lane's are.
- **`.monotonic`'s meaning differs by platform, and says so.** Darwin's
  counts while the system sleeps, Linux's doesn't; `.uptimeRaw` and
  `.boottime` are the other behavior on each. Rejected: renaming either to
  hide it, since it's the same C name.
- **Sleeping is `PThread.sleep(for:)`**, beside `PThread.yield()`, and
  `noasync` like it: it blocks the calling thread. Rejected: a static on
  `ClockID` (`nanosleep` measures no chosen clock) and a new namespace.
  `clock_nanosleep`, which does take a clock, isn't on Darwin, and isn't
  added.
- **An interrupted sleep resumes with the time the kernel says is left**,
  not the original request, which would oversleep once per signal. Without
  `retryOnInterrupt` it throws `.interrupted`, as other System calls do,
  and the time left is lost. A negative duration sleeps for none; a
  positive one rounds up to a nanosecond.
- Files that use `timespec()` or its members import CSystem on Linux,
  where glibc's `timespec` comes through CSystem's headers (the linux-build
  lane's `9d8e5bf`).
- Not added: `clock_settime`, `clock_getcpuclockid` and
  `pthread_getcpuclockid` (another process's or thread's CPU clock; not on
  Darwin), and FreeBSD's and OpenBSD's own clocks, such as `CLOCK_UPTIME`.

Adopters:
- NIO: `clock_gettime(CLOCK_MONOTONIC)` for `NIODeadline.now()`
  (`NIOCore/EventLoop.swift`), `usleep` in io_uring's backoff,
  `gettimeofday` for `ConditionLock`'s deadline, and `timespec` in 51
  lines, mostly kqueue and io_uring timeouts, which System's own event API
  takes as `Duration`.
- Foundation, by grep: `clock_gettime` for `Date.now`, UUID timestamps, and
  `ProcessInfo.systemUptime` (`CLOCK_MONOTONIC_RAW` on Linux).
- Subprocess: `timespec` for a kqueue timeout.

Unverified off Darwin: the Linux, Android, FreeBSD and OpenBSD clock
constants, and `clockid_t`'s being `CInt` there (which reusing
`_CLOCK_BOOTTIME` assumes).

## Public errno (a prototype; the decision stays open)

`Errno.current` in `Sources/System/Errno.swift`, and
`Sources/System/Errno/ErrnoAccess.swift`. Done out of order, on request:
adopter lanes mark `SYSTEM-GAP: errno` for it.

| API | C |
|---|---|
| `Errno.current { get set }` | `errno` |
| `Errno.check(retryOnInterrupt:_:) throws(Errno) -> Value`, for a `FixedWidthInteger` result | a call that returns -1 (or `(size_t)-1`) and sets `errno` |
| `Errno.check(retryOnInterrupt:_:) throws(Errno) -> Value`, for an `Optional` result | a call that returns `NULL` and sets `errno` |
| `Errno.checkOptional(retryOnInterrupt:_:) throws(Errno) -> Value?` | a call like `readdir`, which returns `NULL` both for nothing and on failure: `errno` is cleared first |

This is a default to try, not a decision. Whether System should vend
`errno` at all is still open: the TODO it replaces said that safe access
"needs a release barrier", and no such barrier exists.

What the prototype does:

- **`current` is public, with a getter and a setter.** Its documentation
  says the value is reliable only when read immediately after the C call,
  because Swift can run code between the call and the read: a release can
  run a deinitializer that calls `free` or `close`. A test and the `errno`
  sample show it happening (`aReleaseBeforeTheReadCanChangeErrno`). The
  setter exists to clear `errno` before calls like `readdir`, `getpriority`
  and `strtol`, whose result can't say whether they failed.
- **The helpers read `errno` the moment the closure returns,** so callers
  don't need the getter, in the shapes of System's internal `valueOrErrno`
  and NIO's `syscall(blocking:)`, pointer `syscall`, and `syscallOptional`.
  They retry `EINTR` unless told not to, as the rest of System does, and
  throw `Errno`. The closure is non-throwing, to keep it to the C call. Its
  documentation names what it can't prevent: a value whose last use is in
  the call can be released inside the closure, after the call.
- **Integer failure is all bits set** (`Value(truncatingIfNeeded: -1)`), so
  a `size_t` result fails at `(size_t)-1`, as C's do, rather than trapping
  on a negative literal.
- **`current` is `@_alwaysEmitIntoClient`, over a new inlinable accessor,
  and keeps its extension's `System 0.0.1` availability.** System's own
  code of older availability uses it: with a `System 199` annotation, the
  ABI-stable build rejects six uses (`Util.swift`'s `valueOrErrno`,
  `SystemConfig.swift`, and four in `FilePathTempPosix.swift`), checked by
  adding the annotation. With no symbol, the older availability is honest:
  the code runs wherever the client does. The helpers are new, so they're
  `System 199`.

Alternatives, for the decision:

1. No public getter or setter, only the helpers. Closes the late-read
   hazard, except inside the closure, but leaves calls with other failure
   values (`mmap`'s `MAP_FAILED`, `sysconf`'s -1 with `errno` unchanged)
   without a way in, so their callers keep reading C's `errno`.
2. A getter but no setter, with a `checkOptional`-style helper for every
   clear-first case, including integer ones like `getpriority`.
3. Helpers that return `Result<Value, Errno>`, as `valueOrErrno` does,
   rather than throwing. It composes the way System's own layers do, but
   Swift 6.2 makes typed `Result` closures awkward to write.
4. A sentinel argument (`check(failingWith: MAP_FAILED)`), generic over
   `Equatable`, instead of or beside the -1 and `nil` forms.
5. Names: `check` and `checkOptional` follow what System's tests already
   call such helpers. Alternatives: `valueOrThrow`, `withErrno`, or NIO's
   `syscall`.

Adopters: NIO reads `errno` in 54 lines (its `syscall` helpers, NIOFS's own
`valueOrErrno`), Subprocess in 55 (Swift and its C shims), SwiftPM in 14,
and Foundation's Swift sources in about 140, by grep.

Unverified off Darwin: the accessor's Windows (`_get_errno`), WASI and
Android branches, which copy `system_errno`'s in `Exports.swift`.

## 4. System identity

`Sources/System/SystemIdentity/SystemIdentity.swift` and
`Sources/System/Internals/Syscalls+SystemIdentity.swift`.

| API | C |
|---|---|
| `SystemIdentity`: `systemName`, `nodeName`, `release`, `version`, `machine` | `struct utsname`: `sysname`, `nodename`, `release`, `version`, `machine` |
| `SystemIdentity.current() throws(Errno)` | `uname` |
| `SystemIdentity.hostName() throws(Errno) -> String` | `gethostname` (Android: `uname`) |
| `SystemIdentity.loginName() throws(Errno) -> String` | `getlogin_r` (Android: `getlogin`) |
| (already there) `SystemConfig.value(.pageSize)` | `getpagesize`, `sysconf(_SC_PAGESIZE)` |

Design calls:

- **`SystemIdentity` is a value of `String`s**, decoded up to each array's
  first null character or its end, rather than a wrapper of the C struct
  as `Stat` is. `utsname` is five or six fixed character arrays (1.3 KB on
  Darwin) with nothing to reach but the names. Rejected: `SystemName`
  (POSIX's "get the name of the current system"), which reads as the host
  name; and Linux's `domainname` field, which glibc declares only with
  `_GNU_SOURCE`.
- **Field names are the C ones, camel-cased**: `systemName`, `nodeName`,
  `release`, `version`, `machine`. Rejected: coreutils' `kernelName` and
  `kernelRelease`, which are more precise on Linux but not what POSIX calls
  them.
- **`hostName()` wraps `gethostname`**, though `uname`'s `nodename` is the
  same value on Darwin, glibc and Bionic, because that's what adopters
  call. On Android, where Bionic has `gethostname` only from API level 23,
  it reads `uname`, as Bionic's `gethostname` does. Its buffer is 256
  bytes, one more than the longest name Darwin and FreeBSD allow, and it
  leaves the last byte zero, since `gethostname` needn't terminate a name
  it truncates.
- **`loginName()` throws when there's no login name**, as for a daemon,
  with the platform's error (`ENXIO`, `ENOTTY` or `ENOENT`), rather than
  returning `nil`: callers can `try?`, and the error says why. It uses
  `getlogin_r`, which returns its error rather than setting `errno`, and
  grows its buffer on `ERANGE`; Android has `getlogin_r` only from API
  level 28, so there it's `getlogin`. It's on `SystemIdentity` with the
  host name. Rejected: a static on `UserEntry`, since the login name
  belongs to the session, not to a user ID.
- **No page-size API**: `SystemConfig.value(.pageSize)` already covers
  `getpagesize`, and the `uname` sample uses it.
- Not added: `sethostname` (needs privileges), `getdomainname`, and
  Darwin's `sysctl` names such as `hw.model`.

Adopters: Foundation, by grep: `uname` for `operatingSystemVersion` and
`operatingSystemVersionString` (`ProcessInfo.swift`), `gethostname` for
`hostName` (`Platform.swift`), and `getpagesize`. NIO calls `uname` only
from its C shims' `system_info` functions, which no Swift code calls.
Subprocess's `getpagesize` is covered already. SwiftPM runs the `uname`
program rather than calling it.

Unverified off Darwin: the Android branches, `getlogin_r`'s `int` length
on older FreeBSD (it's passed with `numericCast`), and glibc's `getlogin`
errors without a controlling terminal.

## 5. Paths and files

`Sources/System/PathsAndFiles/` (`FilePath+Resolution.swift`,
`UniqueFiles.swift`, `ProcessDefaults.swift`),
`Sources/System/Internals/Syscalls+PathsAndFiles.swift`, and two CSystem
shims for Linux.

| API | C |
|---|---|
| `FilePath.canonicalized() throws(Errno) -> FilePath`, and a C-string form | `realpath` |
| `FilePath.remove(retryOnInterrupt:)`, and a C-string form | `remove` |
| `FilePath.makeUniqueFile(options:retryOnInterrupt:) -> (path:, descriptor:)`, and a C-string form that rewrites the template | `mkostemp` |
| `FilePath.makeUniqueDirectory(retryOnInterrupt:) -> FilePath`, and a C-string form | `mkdtemp` |
| `FilePath.temporaryDirectory() -> FilePath` | `TMPDIR`, then Darwin's `confstr(_CS_DARWIN_USER_TEMP_DIR)`, then `/data/local/tmp` or `/tmp` |
| `FilePermissions.setCreationMask(_:) -> FilePermissions` | `umask` |
| `FileDescriptor.currentWorkingDirectory` | `AT_FDCWD` |

Design calls:

- **`canonicalized()`** for `realpath`, after the "canonical, absolute"
  form it returns, and beside `lexicallyNormalized()`, whose doc it
  contrasts with. Rejected: `realPath()` (the C name), and
  `resolvingSymbolicLinks()`, which undersells making the path absolute and
  removing `..`.
- **`remove()`** is C's name. It's a file system call beside `unlink()` and
  `removeDirectory()`, and it throws, which keeps it apart from
  `removeLastComponent()`, which edits the path. Rejected: `removeItem()`,
  which is recursive in Foundation.
- **Templates must end in six X's, on every platform.** POSIX requires it,
  and glibc enforces it; Darwin's `mkstemp` accepted `report-XX`, and its
  `mkdtemp` made a directory named exactly `scratch` from a template
  without X's: a name anyone can guess. Found by the tests. Rejected:
  passing Darwin's leniency through.
- **`makeUniqueFile` is `mkostemp`**, so `options: .closeOnExec` makes the
  descriptor without a window in which a child could inherit it. The
  default is no options, as for `open`. glibc declares `mkostemp` only with
  `_GNU_SOURCE`, and Bionic only from API level 23, so Linux goes through a
  CSystem shim, which on older Android calls `mkstemp` for no options and
  fails with `ENOSYS` for others. It returns the new path and the
  descriptor, as `pipe()` returns its two. Rejected: returning an
  `OwnedFD`, which `open` doesn't either; and a `permissions:` parameter,
  which `mkstemp` doesn't have (the file is 0600 less the mask).
- **A retried call starts from the original template**: a failed call can
  leave the X's replaced, so `_retryingTemplate` saves and restores it.
- **`temporaryDirectory()` reads `TMPDIR` first,** as POSIX and NIO do,
  then Darwin's per-user directory, then `/data/local/tmp` on Android, as
  NIO and Foundation do, then `/tmp`. A set-user-ID program ignores
  `TMPDIR` (`issetugid`, or `getauxval(AT_SECURE)` through a shim on
  Linux), as Foundation's `getEnvSecure` does. It's a method, not a
  property, since `confstr` can create the directory. Rejected:
  Foundation's order, which ignores the user's `TMPDIR` on Darwin. It
  calls the existing `system_confstr`; the darwin-more lane's
  `SystemConfig.string(.userTemporaryDirectory)` reads the same value, and
  this should use it once both are merged.
- **`setCreationMask(_:)` is `umask`'s exact shape**: it sets the mask and
  returns the old one, with a discardable result. There's no getter,
  because C has none: reading the mask means setting it and setting it
  back, which another thread can see, and the documentation says so.
  Foundation needs the value (to `fchmod` after `mkstemp`, its comment
  says), which this leaves racy. `FileOperations.swift` already has an
  internal `creationMask` property and `withCreationMask(_:body:)`, which
  this lane didn't edit; making those public, or reading Linux's
  `/proc/self/status`, is the choice left. Not on Windows, where System's
  `umask` is its own emulation.
- **`FileDescriptor.currentWorkingDirectory`** reads well where it's used,
  `relativeTo: .currentWorkingDirectory`. Its documentation says it isn't
  an open descriptor, and other calls on it throw `EBADF`. No `renamed:`
  stub for `AT_FDCWD`, as the standard streams have none for
  `STDIN_FILENO`.
- Not added: `mkstemps` and `mkostemps` (a template with a suffix),
  `mkdtempat` and a `realpath` relative to a directory, which don't exist
  everywhere.

Adopters:
- NIO: `remove` in NIOFS and `NonBlockingFileIO` (3 lines); `AT_FDCWD` for
  NIOFS's Linux paths (2); NIOFS's `temporaryDirectory`, which reads
  `TMPDIR` and `confstr(_CS_DARWIN_USER_TEMP_DIR)` (3).
- Foundation, by grep: `mkstemp` and `umask` in `Data+Writing`, `AT_FDCWD`,
  and `NSTemporaryDirectory`'s `confstr` and `TMPDIR`.
- SwiftPM: `mkdtemp` (1), and the per-user temporary directory for its
  sandbox profile.

Unverified off Darwin: the `mkostemp` and `getauxval` shims, glibc's
`EINVAL` for bad templates (now caught first anyway), and Linux's `remove`
error for a directory that isn't empty (the test accepts any `Errno`).

## 6. Dynamic loading

`Sources/System/DynamicLoading/DynamicLibrary.swift`,
`Sources/System/Internals/Syscalls+DynamicLoading.swift` and
`Constants+DynamicLoading.swift`.

| API | C |
|---|---|
| `DynamicLibrary: ~Copyable`, `init(_:options:) throws(LoaderError)` (`FilePath` and C string) | `dlopen` |
| `DynamicLibrary.mainProgram(options:)` | `dlopen(NULL, …)` |
| `address(of:) -> UnsafeMutableRawPointer?` (`String` and C string) | `dlsym` |
| `close() throws(LoaderError)`, `deinit`, `relinquish()`, `init(taking:)`, `handle` | `dlclose` |
| `DynamicLibrary.LoaderError` (`message`) | `dlerror` |
| `DynamicLibrary.OpenOptions`: `.lazy`, `.now`, `.global`, `.local`, `.noLoad`, `.noDelete` (not OpenBSD), `.first` (Darwin) | `RTLD_*` |

Design calls:

- **An owned handle, on `OwnedFD`'s pattern**: `init(taking:)`, a consuming
  `close()` that reports an error, a `deinit` that drops one, `relinquish()`,
  and a `handle` property for calls it doesn't wrap. Whether a deinit should
  drop close errors is `OwnedFD`'s open question (`Prototype/CloseErrors`);
  this follows its current default without deciding it. It's
  `@unchecked Sendable`, since the dl* calls are thread-safe and the handle
  is a raw pointer.
- **Errors are `LoaderError`s with `dlerror`'s message, not `Errno`**: the
  dynamic linker doesn't report through `errno`. SwiftPM's `PackagePlugin`
  keeps the same message in its own `LibraryOpenError`. For the same reason
  the wrappers have no mock hooks, which set `errno`.
- **A missing symbol is `nil`, not an error**, as NIO, SwiftPM and
  Foundation treat it. `address(of:)` clears `dlerror` first, so a caller can
  still tell a symbol whose value is null from a missing one.
- **The default options are `[.now, .local]` everywhere.** Darwin makes a
  library global when neither `.local` nor `.global` is given, and Linux
  local, so the default names one; and `.now` fails at load rather than
  crashing at a lazy call later. Rejected: `.lazy` (C's usual choice).
- **`mainProgram()` is `dlopen(NULL)`**, which NIO and SwiftPM use to find
  symbols in the running process. Rejected: `RTLD_DEFAULT` (a pseudo-handle
  glibc declares only with `_GNU_SOURCE`, and whose value differs by
  platform).
- **Addresses are raw pointers**, and the documentation says a function's
  must be cast with `unsafeBitCast(_:to:)`, which nothing checks. Rejected:
  a generic `address<T>(of:as:)` that casts, which hides the unchecked
  cast.
- Not added: `dladdr` (glibc declares it only with `_GNU_SOURCE`), `dlinfo`,
  `dlvsym`, and `RTLD_NEXT`. Glibc's module links `libdl`, which glibc
  before 2.34, on Ubuntu 20.04, still needs.

Adopters:
- NIO: `dlopen(nil, RTLD_NOW)` and `dlsym` to find
  `swift_task_enqueueGlobal_hook` (`PosixSingletons+ConcurrencyTakeOver`).
- SwiftPM: `PackagePlugin`'s `LibraryHandle` (`dlopen(nil, RTLD_NOW | RTLD_LOCAL)`,
  `dlsym`, `dlerror`), and the testing helper's `dlopen` of a test bundle,
  `dlsym(image, "main")` and `dlclose`.
- Foundation: `AttributeScope`'s `dlopen(path, RTLD_NOLOAD | RTLD_FIRST)`,
  `dlsym` and `dlclose`.

Unverified off Darwin: the `RTLD_NOLOAD` and `RTLD_NODELETE` values on
FreeBSD and Bionic, OpenBSD's lack of them, and Android's linking of
`libdl`.
