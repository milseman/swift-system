/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for how OwnedFD's deinit handles an error from closing.
// It drops I/O errors (see testThrowingScopeDropsCloseError in
// OwnedFDTests.swift) and traps on EBADF, which exit tests check in a child
// process.

// Exit tests need swift-testing's support for child processes, which Darwin
// has only on macOS. WASI has neither pipes nor processes, and Windows' C
// runtime treats closing an invalid descriptor as an invalid parameter.
#if os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("OwnedFD deinit")
private struct OwnedFDDeinitTests {
  @Test func destroyingAnOwnerClosesWithoutTrapping() async {
    await #expect(processExitsWith: .success) {
      let pipe = try FileDescriptor.pipe()
      _ = OwnedFD(taking: pipe.readEnd)
      _ = OwnedFD(taking: pipe.writeEnd)
    }
  }

  @Test func deinitTrapsWhenClosedThroughWithDescriptor() async {
    await #expect(processExitsWith: .failure) {
      let pipe = try FileDescriptor.pipe()
      try pipe.writeEnd.close()
      let owned = OwnedFD(taking: pipe.readEnd)
      try owned.withDescriptor { try $0.close() }
    }
  }

  @Test func deinitTrapsWhenAdoptedTwice() async {
    await #expect(processExitsWith: .failure) {
      let pipe = try FileDescriptor.pipe()
      try pipe.writeEnd.close()
      let first = OwnedFD(taking: pipe.readEnd)
      let second = OwnedFD(taking: pipe.readEnd)
      try first.close()
      _ = consume second
    }
  }

  @Test func explicitCloseThrowsRatherThanTrapping() {
    // Only the deinit traps; `close()` reports EBADF like any other error.
    #expect(throws: Errno.badFileDescriptor) {
      try OwnedFD(taking: FileDescriptor(rawValue: -1)).close()
    }
  }
}

#endif // os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)
