/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Tests that close a directory stream's descriptor behind its back, or change
// the process's descriptor limit. swift-testing runs tests in parallel in one
// process, where another test could reuse a closed descriptor's number, or
// run out of descriptors, so these run as exit tests, each in a child
// process of its own, as OwnedFDDeinitTests.swift's do.
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
      do throws(Errno) {
        _ = try DirectoryStream(OwnedFD(taking: pipe.readEnd))
        exit(1)
      } catch {
        if error != .notDirectory { exit(2) }
      }
      // The descriptor is closed, so the pipe has no reader, and a write
      // fails. Checking the descriptor's number with fcntl can be fooled:
      // with Swift 6.3 on Linux, something in the child process sometimes
      // reused it.
      _ = signal(SIGPIPE, SIG_IGN)
      var byte: UInt8 = 0
      if write(pipe.writeEnd.rawValue, &byte, 1) != -1 || errno != EPIPE { exit(3) }
    }
  }

  // Only on macOS: RLIMIT_NOFILE's type differs between the C libraries,
  // and this was only compiled against Darwin's.
  #if os(macOS)
  @available(System 199, *)
  @Test func aWalkDeeperThanTheDescriptorLimitReportsIt() async {
    await #expect(processExitsWith: .success) {
      try DirectoryFixture.withTemporaryDirectory("DirectoryWalk_tooDeep") { root in
        // 100 directories, each inside the last, made relative to each other.
        var parent = try FileDescriptor.open(root, .readOnly, options: .directory)
        for _ in 0..<100 {
          try FilePath("d").makeDirectory(
            relativeTo: parent, permissions: .ownerReadWriteExecute)
          let child = try FileDescriptor.open(
            "d", relativeTo: parent, .readOnly, options: .directory)
          try parent.close()
          parent = child
        }
        try parent.close()

        // A walk holds a descriptor for each level, so a limit of 40 more
        // than the lowest free descriptor stops it partway down. (A child
        // process can start with many descriptors open.)
        let probe = try FileDescriptor.open(root, .readOnly)
        let lowestFree = probe.rawValue
        try probe.close()
        var limit = rlimit()
        getrlimit(RLIMIT_NOFILE, &limit)
        let original = limit.rlim_cur
        limit.rlim_cur = rlim_t(lowestFree + 40)
        setrlimit(RLIMIT_NOFILE, &limit)
        var walk = try DirectoryWalk(root)
        var deepest = 0
        var tooMany = 0
        while let entry = try walk.next() {
          deepest = max(deepest, entry.depth)
          if entry.error == .tooManyOpenFiles { tooMany += 1 }
        }
        // Raise the limit again, so that the cleanup can remove the tree.
        limit.rlim_cur = original
        setrlimit(RLIMIT_NOFILE, &limit)
        // One directory didn't open, and the walk went no deeper.
        if tooMany != 1 { exit(1) }
        if deepest >= 100 || deepest < 10 { exit(2) }
      }
    }
  }
  #endif
}

#endif // os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)
