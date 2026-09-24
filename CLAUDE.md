# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Swift System provides idiomatic Swift interfaces to system calls and low-level currency types (`FileDescriptor`, `Errno`, `FilePath`, …). It is deliberately **not** a cross-platform abstraction. Each platform gets API that closely mirrors its native interfaces, but a concept that platforms share under the same C name should get the same Swift name. A copy ships in Apple SDKs as the `System` module, which is why availability and ABI discipline matter.

This checkout is on `system-next`, the branch for prototyping the next major version. Read `Next/Vision.md` before any design work. It sets out the philosophy ("remove incidental unsafety and hazards, without being obstructive by trying, and failing, to remove inherent ones") and labels each section as settled intent, open exploration, or unconfirmed suggestion. Keep those apart. It refers to `Next/Roadmap.md` and `Next/Candidates.md`, which aren't in this checkout. The handoff notes it cites are at `../Claude outputs/system-next-handoff.md`. They summarize that roadmap, but their repo-state section is out of date.

The package uses Swift tools 6.1, Swift 6 language mode, and the experimental `Lifetimes` feature. `Proposals/` holds the SYS-NNNN API proposals cited in docs and commits. For example, SYS-0006 introduced `Stat`, `UserID`, and `GroupID`.

## Commands

```sh
swift build
swift test
swift test --filter FileOperationsTest/testSetOwner       # one XCTest method
swift test --filter SocketOperationsTests/bindToAnyPort   # one swift-testing test
swift run system-samples --help
Utilities/api-delta/regenerate.sh                         # public API delta, main vs system-next, into .build/api-delta (see its README.md)

# CI variants (.github/workflows/pull_request.yml). A separate --scratch-path keeps
# the default .build from being rebuilt whenever the manifest flags change.
swift test --scratch-path /tmp/swift-system-ci -Xbuild-tools-swiftc -DSYSTEM_CI
swift build --build-tests --scratch-path /tmp/swift-system-abi \
  -Xbuild-tools-swiftc -DSYSTEM_CI -Xbuild-tools-swiftc -DSYSTEM_ABI_STABLE

# The ABI-stable build for one target. --target can't be combined with --build-tests,
# but it accepts a test target.
swift build --target SystemTests --scratch-path /tmp/swift-system-abi \
  -Xbuild-tools-swiftc -DSYSTEM_CI -Xbuild-tools-swiftc -DSYSTEM_ABI_STABLE

# The explicit-availability check that SYSTEM_CI means to run, as warnings (see below).
# -Xswiftc reaches every Swift target, dependencies included, so name one.
swift build --target SystemPackage --scratch-path /tmp/swift-system-reqavail \
  -Xswiftc -Xfrontend -Xswiftc -require-explicit-availability=warn
```

- `SYSTEM_CI` adds `-require-explicit-availability=error`, which is meant to require an `@available` on every public declaration. The local Swift 6.2 driver drops that flag rather than passing it to the frontend (`swiftc -###` shows this), so locally the `SYSTEM_CI` build checks nothing the default build doesn't. Passed through `-Xfrontend`, as above, the check does run. Its existing warnings are in `OwnedFD.swift`, `ProcessID.swift`, the `CInterop.ProcessID` extension, and the termios wrappers in `Syscalls.swift`.
- `SYSTEM_ABI_STABLE` (a build-only macOS CI job) maps the `System x.y` availability macros to the Darwin OS releases that shipped them. `System 199` becomes `macOS 9999`, so any unannotated use of unreleased API fails to compile.
  - Known failures: `SystemPackage` itself fails this build, so every target does. `FileTimes.swift` and the rename and mkfifo sections of `FilePathOperations.swift` put explicit OS floors inside `System 199` extensions, and the `system_getuid` family in `Syscalls.swift` returns `CInterop.UserID` and `GroupID` (see Availability for both rules). Behind those, `SystemSocketsTests` and most of `Samples` use unreleased API without annotations: `System 199` socket, terminal, and file API, and `System 1.7.0` API such as `stat`, `UserID`, and `GroupID`.
  - A single build stops after the first failing target, which can hide the others, so check targets one at a time, as above. The known failures also hide new errors in the same targets; look for your own files in the output.
- Mock tests compile only under `ENABLE_MOCKING`, which Package.swift defines for debug builds only. `swift test -c release` skips them.
- Some tests skip here by design. The termios tests skip unless stdin and stdout are terminals, which they aren't under Claude Code. On Darwin, the `dup3`/`pipe2` tests need Darwin 27. Socket tests that bind carry `.requiresSocketBinding` (`SocketBindingPermission.swift`), which skips them in a sandbox that denies `bind`.
- CI also builds with CMake on Linux and checks the CMake source lists against SwiftPM (see below). Nothing here builds for Linux (`swift sdk list` is empty), so Linux-only code (`IORing/`, `CSystemLinux.h`, the MemberImportVisibility probe) can't be compiled locally.
- No formatter or linter is configured; CI's soundness format checks are disabled.

## Package layout

- **`CSystem`** (`Sources/CSystem`): C shims for things Swift can't import directly. These include `csystem_posix_pipe2`/`dup3`, `csystem_renameat2`, the `TIOCGWINSZ`/`TIOCSWINSZ` ioctls, WASI `_getConst_*` accessors for macros the Clang importer can't see, and `io_uring.h`.
- **`SystemPackage`** (`Sources/System`): the main library. The module name differs from the directory. Tests use `#if SYSTEM_PACKAGE` to `@testable import SystemPackage`, falling back to `System`.
  - `FileSystem/` holds the file metadata API: `Stat`, `FileTimes` (`futimens`, `utimensat`), `UserID` and `GroupID`, and `FilePathOperations.swift`. That file has the path-based calls (mkdir, unlink, rename, link, symlink, readlink, truncate, access, chdir, chmod, chown, mkfifo, chflags), one extension of `FilePath` per C function family.
  - `Terminal/` wraps termios. `TerminalDescriptor` hosts the operations (`attributes()`, `setAttributes`, `withRawMode`, `windowSize()`), and `TerminalAttributes` wraps `termios` in typed flag sets, `BaudRate`, and `ControlCharacters`.
  - Platform-limited code:
    - `IORing/` (io_uring) and its tests are excluded from the SwiftPM build on non-Linux hosts, so they can't be compiled on macOS.
    - `MachPort.swift` is Darwin-only.
    - `ErrnoWindows.swift`, `WinSDK+Overlay.swift`, and `Internals/WindowsSyscallAdapters.swift` are Windows-only.
    - `Terminal/` and `UserDatabase.swift` (`getpwuid_r` and friends) exist on neither Windows nor WASI.
  - `FilePath` parsing checks `_windowsPaths`, which the mocking driver can override. Tests use `withWindowsPaths(enabled:)` to exercise Windows path syntax on any host.
- **`SystemSockets`** (`Sources/SystemSockets`): the sockets module, merged in from `staging`.
  - It can't see SystemPackage internals, so it keeps its own copies of the ones it needs: `system_errno`, `valueOrErrno`, the mocking driver, and `_RawBuffer`.
  - It is Unix-only: its files `#error` outside Darwin, Glibc, Musl, and Android. Package.swift doesn't exclude it on other platforms, so SwiftPM builds for Windows or WASI stop at those errors, as they did on `staging`. CMake doesn't build it.
- **`Samples`**: the `system-samples` executable. Its ArgumentParser subcommands are registered in `Sources/Samples/main.swift`.
- **Tests**:
  - `SystemTests` is mostly XCTest, plus a few swift-testing suites.
  - `SystemSocketsTests` uses swift-testing. Its mock tests (`SocketMockTests.swift`) drive SystemSockets' own `MockingDriver` through `@testable import SystemSockets`.
  - `MemberImportVisibility` is a compile-only canary (see below).
- **`Prototype/Verify/`**: compiler-check snippets that belong to no target (see the next section).

## Prototypes on this branch

The first three directions in `Next/Vision.md` have prototypes merged into `system-next`:

1. **Owned descriptors.** `OwnedFD.swift` is a noncopyable file descriptor that closes itself, marked "PROTOTYPE… Not API". It forwards the read, write, and seek methods, lends its `FileDescriptor` through `withDescriptor(body:)`, and gives up ownership with `relinquish()`. The standard streams are static lets, so they're never destroyed or consumed. Samples are in `Sources/Samples/Owned*.swift`, and tests are in `OwnedFDTests.swift` and `OwnedFDOwnershipTests.swift`.
2. **Descriptor sub-types.** `Terminal/TerminalDescriptor.swift` and `SocketDescriptor` share one conversion pattern: a `fileDescriptor` property, `init(unchecked:)`, and a checked `init(_:) throws(Errno)` that verifies with `isatty` or `getsockopt(SO_TYPE)`. Terminals also get `FileDescriptor.isTerminal` and `asTerminal`, which returns `nil` rather than throwing; sockets have no equivalent.
3. **Process IDs.** `ProcessID.swift` wraps `pid_t` on the model of `UserID` and `GroupID`, with `.current` and `.parent`.

`Prototype/Verify/` holds the compiler checks behind the `OwnedFD` design, as run with Swift 6.2. Each snippet checks one claim, and most open with a comment stating it. Subdirectories are multi-file or cross-module checks, and the `V10*` snippets (and `V1e`) import `SystemPackage`. Several are expected not to compile. To rerun one:

```sh
# After `swift build`. Use -emit-sil: the move checker runs in SIL, so -typecheck
# misses ownership errors. Add -parse-as-library for a snippet with @main, and
# -enable-experimental-feature Lifetimes for the lifetime checks.
swiftc -emit-sil -o /dev/null -swift-version 6 -I .build/debug/Modules \
  -Xcc -fmodule-map-file=Sources/CSystem/include/module.modulemap \
  Prototype/Verify/V10b_prototype_misuse.swift
```

## Anatomy of a syscall wrapper

Every wrapper has three layers. For an example, see `synchronize` (wrapping `fsync`) in `FileOperations.swift`.

1. **`Internals/Syscalls.swift`**: `internal func system_foo(...)` is the only code that calls the C function. It starts with the mock hook:
   ```swift
   #if ENABLE_MOCKING
     if mockingEnabled { return _mock(fd, mode) }
   #endif
   ```
   - `_mock` records the call as `foo` (it strips `system_` from `#function`, and a precondition requires that prefix) along with its arguments. Use `_mockInt` or `_mockOffT` when the return type isn't `CInt`.
   - Calls that return an error number rather than setting `errno`, such as `posix_fallocate` and `getpwuid_r`, use `_mockReturningErrno` here and `nothingOrReturnedErrno(retryOnInterrupt:)` in layer 2.
   - Record C-string paths by value, not as pointers. Pass `_mock(path: path, ...)`, or `String(_errorCorrectingPlatformString:)` when the path isn't the first argument (see `system_openat`).
   - Some wrappers skip the hook, so they have no mock tests. Mostly these are calls that can't fail or don't report failure as `-1` and `errno`, such as `getpid`, `umask`, `isatty`, and `readdir`.
   - C constants are re-exposed in `Internals/Constants.swift` as `internal var _FOO: CInt { FOO }`.
2. **`@usableFromInline internal func _foo(...) -> Result<T, Errno>`** wraps the call in `valueOrErrno(retryOnInterrupt:)` or `nothingOrErrno(retryOnInterrupt:)` (in `Util.swift`). These turn a `-1` return into `Errno.current` and retry on `EINTR` when asked.
3. **`@_alwaysEmitIntoClient public func foo(..., retryOnInterrupt: Bool = true) throws(Errno)`** returns `try _foo(...).get()`. New API uses typed `throws(Errno)`; older API uses untyped `throws`.

Conventions:
- **Naming:** API gets Swift names, not C names: `synchronize` for `fsync`, `setPermissions` for `fchmod`.
  - Doc comments end with "The corresponding C function is `foo`." (or "The corresponding C constant is `FOO`.").
  - Old C-style spellings remain as `@available(*, unavailable, renamed:)` stubs.
- **Optionals:** `nil` means "omit" or "leave unchanged", as in `permissions: nil`, `duplicate(as: nil)`, and `setOwner(user: nil)`.
- **Paths:** path-taking API gets both a `FilePath` overload and an `UnsafePointer<CChar>` overload (`CInterop.PlatformChar` on Windows). In `FilePathOperations.swift` these are an instance method on `FilePath` and a `static` method taking the C string. Each `*at` call adds a `relativeTo fd: FileDescriptor` variant of both, and `AT_*` flags are `FilePath.ResolutionFlags`.
- **Platform gating:** use one `#if` condition for a feature's syscall wrapper, its API, and its tests, limited to the platforms that have the call.
  - Darwin is `SYSTEM_PACKAGE_DARWIN`, never `os(macOS)`. A constant that only newer SDKs define is gated on the SDK version, as `canImport(Darwin, _version: 346)` does for `AT_RESOLVE_BENEATH`.
  - The others are `os(Linux)`, `os(Android)`, `os(FreeBSD)`, `os(OpenBSD)`, `os(WASI)`, and `os(Windows)`.
  - An `#endif` that closes a long block, such as a whole extension, repeats its condition in a comment.
- **Sockets:** socket wrappers follow the same layering, in `Sources/SystemSockets/Internals/SocketSyscalls.swift` and `Sockets/SocketOperations.swift`.

## Availability

- `@available(System X.Y.Z, *)` is an availability macro defined by the `availability` array in `Package.swift`. `Sources/System/CMakeLists.txt` keeps a mirror of that list, which must stay in sync.
- `System 199` is the placeholder for unreleased API. New API on this branch goes in an extension marked `@available(System 199, *)`, and so do the tests that call it.
  - Annotate the test method, or its whole XCTest class.
  - Don't put `if #available(System 199, *)` inside an unannotated test. It warns "always true" in the default build.
  - The default build can't catch a missing annotation, because every macro maps to the same old OS versions there. The ABI-stable build catches unannotated uses of unreleased API, and the explicit-availability check in Commands catches unannotated public declarations. `OwnedFD` and `ProcessID` have no `@available` at all.
- The default build accepts these mistakes, and the ABI-stable build rejects them:
  - An extension doesn't take on the availability of the type it extends, so each extension of a `System 199` type needs its own annotation.
  - The `CInterop` typealiases carry availability too (`UserID` and `GroupID` are `System 1.7.0`; the termios types are `System 199`). Unannotated internals such as `Syscalls.swift` and `Constants.swift` spell the C types (`uid_t`, `tcflag_t`) instead.
  - A member of a `System 199` extension can't carry an explicit OS floor such as `@available(macOS 10.13, *)`: once `System 199` means `macOS 9999`, the member is "more available than enclosing scope". Put both attributes on the member instead, in an extension without `System 199`. Each build then applies the stricter of the two.
- Some API uses explicit OS availability instead: the Span-based I/O (`macOS 15, iOS 18, …`) and `dup3`/`pipe2` (`macOS 27.0, …`), in extensions with older `System` versions.

## Tests

- **Mock tests** are defined in `TestingInfrastructure.swift` and wrapped in `#if ENABLE_MOCKING`. The pattern is `MockTestCase(name: "foo", .interruptable, args...) { retryOnInterrupt in try ... }.runAllTests()`.
  - It checks the recorded syscall name and arguments. It then forces `EINTR` to check that `.interruptable` calls retry only when asked and `.noInterrupt` calls (`close`, `lseek`) never retry. A third mode, `.noError`, is for calls that can't fail at all, but no test uses it.
  - `Wildcard()` matches any argument.
  - The mock cases in `FileOperationsTest` skip WASI, because C constants there need the `_getConst_*` shims.
- **Real-call tests** create scratch files with `withTemporaryFilePath(basename:)`. It's an internal SystemPackage helper, reachable through `@testable import`.
- **Parallelism:** swift-testing runs its tests in parallel, in one process shared by both test targets. XCTest runs one test at a time, in a separate process. So a test that touches process-wide state, such as a signal handler, the working directory, or a closed descriptor's number (which another test can reuse), belongs in XCTest. To get `EBADF`, use descriptor `-1` rather than a closed one. The header comment in `WriteAllInterruptTests.swift` describes one such case.

## CMake and MemberImportVisibility

- `Sources/System/CMakeLists.txt` lists every `SystemPackage` source file, and CI fails if a SwiftPM source is missing from it. Add new files there; Linux-only `IORing` files go in their conditional block.
- The package enables the `MemberImportVisibility` upcoming feature.
  - The risk: SystemPackage imports the private `CSystem` module, so a C member of a type it vends (such as a field of `CInterop.Stat`) can get attributed to `CSystem` and break clients.
  - On Glibc, that happens when a CSystem header includes the system header that defines the type. So `CSystemLinux.h` includes neither `<sys/stat.h>` nor `<termios.h>`. A shim that needs such a type takes `void *` there, and `shims.c` includes the real header. Darwin is immune, since its SDK headers are modules.
  - When exposing a new C type through `CInterop`, access its raw members in `Tests/MemberImportVisibility/Probe.swift` the way a client would. The probe compiles only on Glibc, Musl, and Android (FreeBSD's overlay is also named Glibc), so on macOS it checks nothing. To typecheck new probe code here, temporarily widen its `#if` to Darwin.

## Branches and neighbors

- **Upstream flow** (from the README): `release/1.7.0` → `release/1.8.x` → `main`. Each change lands on the earliest release branch that needs it. `system-next` builds on `main` and merges in `staging`, which brought the Sockets and Span I/O work.
- **Prototypes:** directions from `Next/Vision.md` are prototyped on branches off `system-next`, each in a sibling git worktree, and merged back when ready. `git worktree list` shows the ones in progress.
- **Adoption work:** `../swift-foundation`, `../swift-nio`, `../swift-package-manager`, and `../swift-subprocess` are checkouts for adopting system-next in those projects.
  - To build one against this checkout, point its swift-system dependency at `../swift-system`. The `SWIFTCI_USE_LOCAL_DEPS` switches in NIO and SwiftPM do that, but they also expect sibling checkouts of other packages, which aren't here.
  - swift-foundation doesn't depend on swift-system yet.
- **Commit messages** are detailed.
  - The subject names the API and what it wraps, e.g. "Add FileDescriptor.setOwner(user:group:retryOnInterrupt:) wrapping fchown".
  - The body covers the API's shape and precedent, naming, availability, platforms, and tests.
