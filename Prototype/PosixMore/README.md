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
