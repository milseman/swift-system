/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for how OwnedFD's deinit handles an error from closing.
// It drops every error, EBADF included (see also
// testThrowingScopeDropsCloseError in OwnedFDTests.swift). Whether EBADF
// should trap instead is an open question; see Prototype/CloseErrors.
//
// The EBADF cases close a descriptor behind its owner's back, and then let
// the owner close the same number again. swift-testing runs tests in
// parallel in one process, where another test could have reused that
// number, so these run as exit tests, each in a child process of its own.

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
  @Test func destroyingAnOwnerExitsNormally() async {
    // The control for the EBADF cases. testDeinitClosesRealDescriptor in
    // OwnedFDTests.swift checks that destroying an owner closes it.
    await #expect(processExitsWith: .success) {
      let pipe = try FileDescriptor.pipe()
      _ = OwnedFD(taking: pipe.readEnd)
      _ = OwnedFD(taking: pipe.writeEnd)
    }
  }

  @Test func deinitDropsEBADFWhenVendedDescriptorIsClosed() async {
    await #expect(processExitsWith: .success) {
      let pipe = try FileDescriptor.pipe()
      try pipe.writeEnd.close()
      let owned = OwnedFD(taking: pipe.readEnd)
      try owned.fileDescriptor.close()
      // Destroying `owned` closes the number again, gets EBADF, and drops it.
    }
  }

  @Test func deinitDropsEBADFWhenAdoptedTwice() async {
    await #expect(processExitsWith: .success) {
      let pipe = try FileDescriptor.pipe()
      try pipe.writeEnd.close()
      let first = OwnedFD(taking: pipe.readEnd)
      let second = OwnedFD(taking: pipe.readEnd)
      try first.close()
      _ = consume second
    }
  }

  @Test func explicitCloseThrowsEBADF() {
    // The deinit drops EBADF, but `close()` reports it like any other error.
    #expect(throws: Errno.badFileDescriptor) {
      try OwnedFD(taking: FileDescriptor(rawValue: -1)).close()
    }
  }
}

#endif // os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)
