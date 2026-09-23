# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Swift System provides idiomatic Swift interfaces to system calls and low-level currency types (`FileDescriptor`, `Errno`, `FilePath`, …). It is deliberately **not** a cross-platform abstraction. Each platform gets API that closely mirrors its native interfaces, but a concept that platforms share under the same C name should get the same Swift name. A copy ships in Apple SDKs as the `System` module, which is why availability and ABI discipline matter.

This checkout is on `system-next`, the branch for prototyping the next major version. Read `Next/Vision.md` before any design work. It sets out the philosophy ("remove incidental unsafety and hazards, without being obstructive by trying, and failing, to remove inherent ones") and labels each section as settled intent, open exploration, or unconfirmed suggestion. Keep those apart. It refers to `Next/Roadmap.md` and `Next/Candidates.md`, which aren't in this checkout.

The package uses Swift tools 6.1, Swift 6 language mode, and the experimental `Lifetimes` feature. `Proposals/` holds the SYS-NNNN API proposals cited in docs and commits. For example, SYS-0006 introduced `Stat`, `UserID`, and `GroupID`.

## Commands

```sh
swift build
swift test
swift test --filter FileOperationsTest/testSetOwner       # one XCTest method
swift test --filter SocketOperationsTests/bindToAnyPort   # one swift-testing test
swift run system-samples --help

# CI variants (.github/workflows/pull_request.yml). A separate --scratch-path keeps
# the default .build from being rebuilt whenever the manifest flags change.
swift test --scratch-path /tmp/swift-system-ci -Xbuild-tools-swiftc -DSYSTEM_CI
swift build --build-tests --scratch-path /tmp/swift-system-abi \
  -Xbuild-tools-swiftc -DSYSTEM_CI -Xbuild-tools-swiftc -DSYSTEM_ABI_STABLE
```

- `SYSTEM_CI` adds `-require-explicit-availability=error`, so every public declaration needs an `@available`. The default build doesn't check this.
- `SYSTEM_ABI_STABLE` (a build-only macOS CI job) maps the `System x.y` availability macros to the Darwin OS releases that shipped them. `System 199` becomes `macOS 9999`, so any unannotated use of unreleased API fails to compile.
  - Known failures: `Samples` and `SystemSocketsTests` currently fail this build because they use `System 199` socket API without annotations. These aren't regressions. All other targets build.
- Mock tests compile only under `ENABLE_MOCKING`, which Package.swift defines for debug builds only. `swift test -c release` skips them.
- CI also builds with CMake on Linux and checks the CMake source lists against SwiftPM (see below).
- No formatter or linter is configured; CI's soundness format checks are disabled.

## Package layout

- **`CSystem`** (`Sources/CSystem`): C shims for things Swift can't import directly. These include `csystem_posix_pipe2`/`dup3`, WASI `_getConst_*` accessors for macros the Clang importer can't see, and `io_uring.h`.
- **`SystemPackage`** (`Sources/System`): the main library. The module name differs from the directory. Tests use `#if SYSTEM_PACKAGE` to `@testable import SystemPackage`, falling back to `System`.
  - Platform-limited code:
    - `IORing/` (io_uring) and its tests are excluded from the SwiftPM build on non-Linux hosts, so they can't be compiled on macOS.
    - `MachPort.swift` is Darwin-only.
    - `ErrnoWindows.swift`, `WinSDK+Overlay.swift`, and `Internals/WindowsSyscallAdapters.swift` are Windows-only.
  - `FilePath` parsing checks `_windowsPaths`, which the mocking driver can override. Tests use `withWindowsPaths(enabled:)` to exercise Windows path syntax on any host.
- **`SystemSockets`** (`Sources/SystemSockets`): the sockets module, merged in from `staging`.
  - It can't see SystemPackage internals, so it keeps its own copies of the ones it needs: `system_errno`, `valueOrErrno`, the mocking driver, and `_RawBuffer`.
  - It is Unix-only: its files `#error` outside Darwin, Glibc, Musl, and Android. CMake doesn't build it.
- **`Samples`**: the `system-samples` executable. Its ArgumentParser subcommands are registered in `Sources/Samples/main.swift`.
- **Tests**:
  - `SystemTests` is mostly XCTest, plus a few swift-testing suites.
  - `SystemSocketsTests` uses swift-testing and makes only real calls (no mock tests).
  - `MemberImportVisibility` is a compile-only canary (see below).

## Anatomy of a syscall wrapper

Every wrapper has three layers. For an example, see `synchronize` (wrapping `fsync`) in `FileOperations.swift`.

1. **`Internals/Syscalls.swift`**: `internal func system_foo(...)` is the only code that calls the C function. It starts with the mock hook:
   ```swift
   #if ENABLE_MOCKING
     if mockingEnabled { return _mock(fd, mode) }
   #endif
   ```
   - `_mock` records the call as `foo` (it strips `system_` from `#function`) along with its arguments. Use `_mockInt` or `_mockOffT` when the return type isn't `CInt`.
   - Record C-string paths by value, not as pointers. Pass `_mock(path: path, ...)`, or `String(_errorCorrectingPlatformString:)` when the path isn't the first argument (see `system_openat`).
   - C constants are re-exposed in `Internals/Constants.swift` as `internal var _FOO: CInt { FOO }`.
2. **`@usableFromInline internal func _foo(...) -> Result<T, Errno>`** wraps the call in `valueOrErrno(retryOnInterrupt:)` or `nothingOrErrno(retryOnInterrupt:)` (in `Util.swift`). These turn a `-1` return into `Errno.current` and retry on `EINTR` when asked.
3. **`@_alwaysEmitIntoClient public func foo(..., retryOnInterrupt: Bool = true) throws(Errno)`** returns `try _foo(...).get()`. New API uses typed `throws(Errno)`; older API uses untyped `throws`.

Conventions:
- **Naming:** API gets Swift names, not C names: `synchronize` for `fsync`, `setPermissions` for `fchmod`.
  - Doc comments end with "The corresponding C function is `foo`." (or "The corresponding C constant is `FOO`.").
  - Old C-style spellings remain as `@available(*, unavailable, renamed:)` stubs.
- **Optionals:** `nil` means "omit" or "leave unchanged", as in `permissions: nil`, `duplicate(as: nil)`, and `setOwner(user: nil)`.
- **Paths:** path-taking API gets both a `FilePath` overload and an `UnsafePointer<CChar>` overload (`CInterop.PlatformChar` on Windows).
- **Platform gating:** use one `#if` condition for a feature's syscall wrapper, its API, and its tests, limited to the platforms that have the call.
  - Darwin is `SYSTEM_PACKAGE_DARWIN`, never `os(macOS)`.
  - The others are `os(Linux)`, `os(Android)`, `os(FreeBSD)`, `os(OpenBSD)`, `os(WASI)`, and `os(Windows)`.
  - Each `#endif` repeats its condition in a comment.
- **Sockets:** socket wrappers follow the same layering, in `Sources/SystemSockets/Internals/SocketSyscalls.swift` and `Sockets/SocketOperations.swift`.

## Availability

- `@available(System X.Y.Z, *)` is an availability macro defined by the `availability` array in `Package.swift`. `Sources/System/CMakeLists.txt` keeps a mirror of that list, which must stay in sync.
- `System 199` is the placeholder for unreleased API. New API on this branch goes in an extension marked `@available(System 199, *)`, and so do the tests that call it.
  - Annotate the test method itself.
  - Don't put `if #available(System 199, *)` inside an unannotated test. It warns "always true" in the default build.
- Some API uses explicit OS availability instead: the Span-based I/O (`macOS 15, iOS 18, …`) and `dup3`/`pipe2` (`macOS 27.0, …`).

## Tests

- **Mock tests** are defined in `TestingInfrastructure.swift` and wrapped in `#if ENABLE_MOCKING`. The pattern is `MockTestCase(name: "foo", .interruptable, args...) { retryOnInterrupt in try ... }.runAllTests()`.
  - It checks the recorded syscall name and arguments. It then forces `EINTR` to check that `.interruptable` calls retry only when asked and `.noInterrupt` calls (`close`, `lseek`) never retry. Use `.noError` for calls that can't fail.
  - `Wildcard()` matches any argument.
  - The mock cases in `FileOperationsTest` skip WASI, because C constants there need the `_getConst_*` shims.
- **Real-call tests** create scratch files with `withTemporaryFilePath(basename:)`. It's an internal SystemPackage helper, reachable through `@testable import`.

## CMake and MemberImportVisibility

- `Sources/System/CMakeLists.txt` lists every `SystemPackage` source file, and CI fails if a SwiftPM source is missing from it. Add new files there; Linux-only `IORing` files go in their conditional block.
- The package enables the `MemberImportVisibility` upcoming feature.
  - The risk: SystemPackage imports the private `CSystem` module, so a C member of a type it vends (such as a field of `CInterop.Stat`) can get attributed to `CSystem` and break clients.
  - When exposing a new C type through `CInterop`, access its raw members in `Tests/MemberImportVisibility/Probe.swift` the way a client would.

## Branches and neighbors

- **Upstream flow** (from the README): `release/1.7.0` → `release/1.8.x` → `main`. Each change lands on the earliest release branch that needs it. `system-next` builds on `main` and merges in `staging`, which brought the Sockets and Span I/O work.
- **Prototypes:** the directions in `Next/Vision.md` are prototyped in sibling git worktrees on branches off `system-next`: `../owned-fd`, `../descriptor-conversions`, and `../process-id` (see `git worktree list`).
- **Adoption work:** `../swift-foundation`, `../swift-nio`, `../swift-package-manager`, and `../swift-subprocess` are checkouts for adopting system-next in those projects.
- **Commit messages** are detailed.
  - The subject names the API and what it wraps, e.g. "Add FileDescriptor.setOwner(user:group:retryOnInterrupt:) wrapping fchown".
  - The body covers the API's shape and precedent, naming, availability, platforms, and tests.
