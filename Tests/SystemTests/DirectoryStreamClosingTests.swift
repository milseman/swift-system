/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Tests that close a directory stream's descriptor behind its back.
// swift-testing runs tests in parallel in one process, where another test
// could reuse a closed descriptor's number, so these run as exit tests, each
// in a child process of its own, as OwnedFDDeinitTests.swift's do.
//
// A failed #expect in a child process isn't reported, so each case exits
// with a status of its own instead.

// Exit tests need swift-testing's support for child processes, which Darwin
// has only on macOS.
#if os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("DirectoryStream closing")
private struct DirectoryStreamClosingTests {
  @available(System 199, *)
  @Test func readingAfterTheDescriptorIsClosedThrows() async {
    await #expect(processExitsWith: .success) {
      var stream = try DirectoryStream.open("/")
      try stream.fileDescriptor.close()
      // readdir returns NULL, as it does at the end, but sets errno.
      do throws(Errno) {
        _ = try stream.next()
        exit(1)
      } catch {
        if error != .badFileDescriptor { exit(2) }
      }
    }
  }

  @available(System 199, *)
  @Test func closeReportsAnEarlierClose() async {
    await #expect(processExitsWith: .success) {
      let stream = try DirectoryStream.open("/")
      try stream.fileDescriptor.close()
      do throws(Errno) {
        try stream.close()
        exit(1)
      } catch {
        if error != .badFileDescriptor { exit(2) }
      }
    }
  }

  @available(System 199, *)
  @Test func deinitDropsAnEarlierClose() async {
    // The status quo, which OwnedFD's deinit shares: see Prototype/CloseErrors.
    await #expect(processExitsWith: .success) {
      let stream = try DirectoryStream.open("/")
      try stream.fileDescriptor.close()
      // Destroying `stream` closes the number again, gets EBADF, and drops it.
      _ = consume stream
    }
  }

  @available(System 199, *)
  @Test func convertingAnOwnerThatIsntADirectoryClosesIt() async {
    await #expect(processExitsWith: .success) {
      let pipe = try FileDescriptor.pipe()
      try pipe.writeEnd.close()
      do throws(Errno) {
        _ = try DirectoryStream(OwnedFD(taking: pipe.readEnd))
        exit(1)
      } catch {
        if error != .notDirectory { exit(2) }
      }
      // The descriptor is closed.
      if fcntl(pipe.readEnd.rawValue, F_GETFD) != -1 || errno != EBADF { exit(3) }
    }
  }
}

#endif // os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)
