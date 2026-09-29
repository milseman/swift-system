# The foundation-gaps lane

What swift-foundation's `no-darwin` branch still needs from System, from its REPORT.md ("No Darwin: what it
takes", "What System needs (for the coverage lane)"), in the order Michael gave: `Errno.notCapable` on Darwin,
DirectoryWalk with a bounded number of descriptors, DirectoryWalk visiting the root and giving each entry's
status, and the number of loaded images. Out of scope: the environment lock (`environ_lock_np`, a private
interface) and swift-foundation itself. Base: system-next at `eee1da2`, after the coverage merge. Built and tested
on Darwin only.

Before any change: XCTest 565 tests (4 skipped), swift-testing 485 tests in 76 suites, all passing.

**Resume here:** section 1 is done; next is item 2, DirectoryWalk with a bounded number of descriptors.

## 1. `Errno.notCapable` on Darwin

What: `Errno.notCapable` (and its `ENOTCAPABLE` fix-it, and the internal `_ENOTCAPABLE`) is now declared on Darwin
as well as FreeBSD. `capabilityMode` (ECAPMODE) and `integrityCheckFailed` (EINTEGRITY) stay FreeBSD-only: the `#if`
in Errno.swift and Internals/Constants.swift is split in two. It was the one `POSIXError.Code` value that
Foundation's deprecation left without a replacement.

Design calls:
- The condition is `canImport(Darwin, _version: 346) || os(FreeBSD)`, not `SYSTEM_PACKAGE_DARWIN`. The macOS 26.0
  SDK is the first whose `<sys/errno.h>` defines `ENOTCAPABLE` (107, unconditionally, and `ELAST` moved from 106 to
  107); the 15.x SDKs don't, so `SYSTEM_PACKAGE_DARWIN` would break a build with them. This is the gate the package
  already uses for `AT_RESOLVE_BENEATH`, which arrived in the same SDK (Darwin module 347.0.12 in 26.0).
- It stays in Errno's `System 0.0.1` extension with the other platform-gated values, as the FreeBSD values were
  added. It's `@_alwaysEmitIntoClient` and a C constant, so it has no symbol and back-deploys; rejected: a
  `System 199` extension, which would restrict clients for no runtime reason.
- Samples/Beneath.swift still spells `Errno(rawValue: ENOTCAPABLE)`, with a comment that System names it only on
  FreeBSD: that's the demos lane's file, so it's left for them (coverage's Queue row B1 said so too).

Tests: ErrnoTest's `testConstants` checks `ENOTCAPABLE == Errno.notCapable.rawValue` on Darwin (and FreeBSD).
Coverage's Queue row B1 (Prototype/Status/REPORT.md) is marked done.

Next: item 2.
