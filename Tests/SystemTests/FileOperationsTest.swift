/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif
#if canImport(Android)
import Android
#elseif os(WASI)
import CSystem
#endif

@available(System 0.0.1, *)
final class FileOperationsTest: XCTestCase {
  #if ENABLE_MOCKING && !os(WASI) // Would need to use _getConst funcs from CSystem
  func testSyscalls() {
    let fd = FileDescriptor(rawValue: 1)

    let rawBuf = UnsafeMutableRawBufferPointer.allocate(byteCount: 100, alignment: 4)
    defer { rawBuf.deallocate() }
    let bufAddr = rawBuf.baseAddress
    let rawFD = fd.rawValue
    let bufCount = rawBuf.count
    let writeBuf = UnsafeRawBufferPointer(rawBuf)
    let writeBufAddr = writeBuf.baseAddress

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "open", .interruptable, "a path", O_RDWR | O_APPEND) {
        retryOnInterrupt in
        _ = try FileDescriptor.open(
          "a path", .readWrite, options: [.append], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "open", .interruptable, "a path", O_WRONLY | O_CREAT | O_APPEND, 0o777) {
        retryOnInterrupt in
        _ = try FileDescriptor.open(
          "a path", .writeOnly, options: [.create, .append],
          permissions: [.groupReadWriteExecute, .ownerReadWriteExecute, .otherReadWriteExecute],
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "read", .interruptable, rawFD, bufAddr, bufCount) {
        retryOnInterrupt in
        _ = try fd.read(into: rawBuf, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "pread", .interruptable, rawFD, bufAddr, bufCount, 5) {
        retryOnInterrupt in
        _ = try fd.read(fromAbsoluteOffset: 5, into: rawBuf, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "lseek", .noInterrupt, rawFD, -2, SEEK_END) {
        _ in
        _ = try fd.seek(offset: -2, from: .end)
      },

      MockTestCase(name: "write", .interruptable, rawFD, writeBufAddr, bufCount) {
        retryOnInterrupt in
        _ = try fd.write(writeBuf, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "pwrite", .interruptable, rawFD, writeBufAddr, bufCount, 7) {
        retryOnInterrupt in
        _ = try fd.write(toAbsoluteOffset: 7, writeBuf, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "close", .noInterrupt, rawFD) {
        _ in
        _ = try fd.close()
      },

      MockTestCase(name: "dup", .interruptable, rawFD) { retryOnInterrupt in
        _ = try fd.duplicate(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "dup2", .interruptable, rawFD, 42) { retryOnInterrupt in
        _ = try fd.duplicate(as: FileDescriptor(rawValue: 42),
                             retryOnInterrupt: retryOnInterrupt)
      },
    ]

    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING && !os(WASI)

  #if ENABLE_MOCKING && !os(WASI) && !os(Windows)
  @available(System 199, *)
  func testUnixSyscalls() {
    let fd = FileDescriptor(rawValue: 1)
    let rawFD = fd.rawValue

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "fsync", .interruptable, rawFD) { retryOnInterrupt in
        try fd.synchronize(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fchmod", .interruptable, rawFD, 0o644) { retryOnInterrupt in
        try fd.setPermissions(
          [.ownerReadWrite, .groupRead, .otherRead], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fchown", .interruptable, rawFD, 501, 20) { retryOnInterrupt in
        try fd.setOwner(
          user: UserID(501), group: GroupID(20), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fchown", .interruptable, rawFD, uid_t(truncatingIfNeeded: -1), 20
      ) { retryOnInterrupt in
        try fd.setOwner(group: GroupID(20), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fchown", .interruptable, rawFD, 501, gid_t(truncatingIfNeeded: -1)
      ) { retryOnInterrupt in
        try fd.setOwner(user: UserID(501), retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "openat", .interruptable, 42, "a path", O_RDWR | O_APPEND) {
        retryOnInterrupt in
        _ = try FileDescriptor.open(
          FilePath("a path"), relativeTo: FileDescriptor(rawValue: 42), .readWrite,
          options: [.append], retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "openat", .interruptable, 42, "a path", O_WRONLY | O_CREAT | O_APPEND, 0o777
      ) {
        retryOnInterrupt in
        _ = try FileDescriptor.open(
          "a path", relativeTo: FileDescriptor(rawValue: 42), .writeOnly,
          options: [.create, .append],
          permissions: [.groupReadWriteExecute, .ownerReadWriteExecute, .otherReadWriteExecute],
          retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETFD) { _ in
        _ = try fd.descriptorFlags()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETFD, FD_CLOEXEC) { _ in
        try fd.setDescriptorFlags(.closeOnExec)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETFL) { _ in
        _ = try fd.statusFlags()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETFL) { _ in
        _ = try fd.accessMode()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETFL, O_NONBLOCK | O_APPEND) { _ in
        try fd.setStatusFlags([.nonBlocking, .append])
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_DUPFD_CLOEXEC, 0) { _ in
        _ = try fd.duplicate(closeOnExec: true)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_DUPFD, 10) { _ in
        _ = try fd.duplicate(atLeast: FileDescriptor(rawValue: 10), closeOnExec: false)
      },

      MockTestCase(name: "flock", .interruptable, rawFD, LOCK_EX) { retryOnInterrupt in
        try fd.lockWholeFile(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "flock", .interruptable, rawFD, LOCK_SH | LOCK_NB) {
        retryOnInterrupt in
        try fd.lockWholeFile(shared: true, nonBlocking: true, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "flock", .interruptable, rawFD, LOCK_UN) { retryOnInterrupt in
        try fd.unlockWholeFile(retryOnInterrupt: retryOnInterrupt)
      },
    ]

    for test in syscallTestCases { test.runAllTests() }

    #if !SYSTEM_PACKAGE_DARWIN
    let fdatasync = MockTestCase(name: "fdatasync", .interruptable, rawFD) {
      retryOnInterrupt in
      try fd.synchronizeData(retryOnInterrupt: retryOnInterrupt)
    }
    fdatasync.runAllTests()
    #endif // !SYSTEM_PACKAGE_DARWIN

    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    let fchflags = MockTestCase(
      name: "fchflags", .interruptable, rawFD, UInt32(bitPattern: UF_NODUMP | UF_APPEND)
    ) { retryOnInterrupt in
      try fd.setFileFlags([.noDump, .userAppend], retryOnInterrupt: retryOnInterrupt)
    }
    fchflags.runAllTests()
    #endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

    #if SYSTEM_PACKAGE_DARWIN
    let fullSync = [
      MockTestCase(name: "fcntl", .interruptable, rawFD, F_FULLFSYNC) { retryOnInterrupt in
        try fd.synchronizeFully(retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_BARRIERFSYNC) {
        retryOnInterrupt in
        try fd.synchronizeWithBarrier(retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in fullSync { test.runAllTests() }
    #endif // SYSTEM_PACKAGE_DARWIN

    #if os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
    let fallocate = MockTestCase(
      name: "posix_fallocate", .interruptable, rawFD, 512, 4096
    ) { retryOnInterrupt in
      try fd.allocateSpace(offset: 512, length: 4096, retryOnInterrupt: retryOnInterrupt)
    }
    fallocate.runAllTests()

    let fadvise = [
      MockTestCase(
        name: "posix_fadvise", .noInterrupt, rawFD, 0, 0, POSIX_FADV_SEQUENTIAL
      ) { _ in
        try fd.advise(.sequential)
      },

      MockTestCase(
        name: "posix_fadvise", .noInterrupt, rawFD, 512, 4096, POSIX_FADV_DONTNEED
      ) { _ in
        try fd.advise(.dontNeed, offset: 512, length: 4096)
      },
    ]
    for test in fadvise { test.runAllTests() }
    #endif // os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
  }
  #endif // ENABLE_MOCKING && !os(WASI) && !os(Windows)

  func testWriteFromEmptyBuffer() throws {
    #if os(Windows)
    let fd = try FileDescriptor.open(FilePath("NUL"), .writeOnly)
    #else
    let fd = try FileDescriptor.open(FilePath("/dev/null"), .writeOnly)
    #endif
    let written1 = try fd.write(toAbsoluteOffset: 0, .init(start: nil, count: 0))
    XCTAssertEqual(written1, 0)

    let pointer = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
    defer { pointer.deallocate() }
    let empty = UnsafeRawBufferPointer(start: pointer, count: 0)
    let written2 = try fd.write(toAbsoluteOffset: 0, empty)
    XCTAssertEqual(written2, 0)
  }

  #if os(Windows)
  // Generate a file containing random bytes; this should not be used
  // for cryptography, it's just for testing.
  func generateRandomData(at path: FilePath, count: Int) throws {
    let fd = try FileDescriptor.open(path, .readWrite,
                                     options: [.create, .truncate])
    defer {
      try! fd.close()
    }
    let data = [UInt8](
      sequence(first: 0,
               next: {
                 _ in UInt8.random(in: UInt8.min...UInt8.max)
               }).dropFirst().prefix(count)
    )

    try data.withUnsafeBytes {
      _ = try fd.write($0)
    }
  }
  #endif

  func testReadToEmptyBuffer() throws {
    try withTemporaryFilePath(basename: "testReadToEmptyBuffer") { path in
      #if os(Windows)
      // Windows doesn't have an equivalent to /dev/random, so generate
      // some random bytes and write them to a file for the next step.
      let randomPath = path.appending("random.txt")
      try generateRandomData(at: randomPath, count: 16)
      let fd = try FileDescriptor.open(randomPath, .readOnly)
      #else // !os(Windows)
      let fd = try FileDescriptor.open(FilePath("/dev/random"), .readOnly)
      #endif
      let read1 = try fd.read(fromAbsoluteOffset: 0, into: .init(start: nil, count: 0))
      XCTAssertEqual(read1, 0)

      let pointer = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
      defer { pointer.deallocate() }
      let empty = UnsafeMutableRawBufferPointer(start: pointer, count: 0)
      let read2 = try fd.read(fromAbsoluteOffset: 0, into: empty)
      XCTAssertEqual(read2, 0)
    }
  }

  func testHelpers() {
    // TODO: Test writeAll, writeAll(toAbsoluteOffset), closeAfter
  }

#if !os(WASI) // WASI has no pipe
  @available(System 1.1.0, *)
  func testAdHocPipe() throws {
    // Ad-hoc test testing `Pipe` functionality.
    // We cannot test `Pipe` using `MockTestCase` because it calls `pipe` with a pointer to an array local to the `Pipe`, the address of which we do not know prior to invoking `Pipe`.
    let pipe = try FileDescriptor.pipe()
    try pipe.readEnd.closeAfter {
      try pipe.writeEnd.closeAfter {
        var abc = "abc"
        try abc.withUTF8 {
          _ = try pipe.writeEnd.write(UnsafeRawBufferPointer($0))
        }
        let readLen = 3
        let readBytes = try Array<UInt8>(unsafeUninitializedCapacity: readLen) { buf, count in
          count = try pipe.readEnd.read(into: UnsafeMutableRawBufferPointer(buf))
        }
        XCTAssertEqual(readBytes, Array(abc.utf8))
      }
    }
  }

  func testAdHocPipeWithOptions() throws {
    guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
      throw XCTSkip("pipe2 and PipeOptions require Darwin 27 or newer")
    }
    // Ad-hoc test testing `Pipe` functionality.
    // We cannot test `Pipe` using `MockTestCase` because it calls `pipe` with a pointer to an array local to the `Pipe`, the address of which we do not know prior to invoking `Pipe`.
    let options: FileDescriptor.PipeOptions = [.closeOnExec]
    let pipe: (readEnd: FileDescriptor, writeEnd: FileDescriptor)
    pipe = try FileDescriptor.pipe(options: options)
    try pipe.readEnd.closeAfter {
      try pipe.writeEnd.closeAfter {
        var abc = "abc"
        try abc.withUTF8 {
          _ = try pipe.writeEnd.write(UnsafeRawBufferPointer($0))
        }
        let readLen = 3
        let readBytes = try Array<UInt8>(unsafeUninitializedCapacity: readLen) { buf, count in
          count = try pipe.readEnd.read(into: UnsafeMutableRawBufferPointer(buf))
        }
        XCTAssertEqual(readBytes, Array(abc.utf8))
      }
    }
  }
#endif // !os(WASI)

#if !os(Windows)
  func testAdHocDuplicate2() throws {
    try withTemporaryFilePath(basename: "test") {
      let path = $0.appending("foo2.txt")
      let fd1 = try FileDescriptor.open(path, .readWrite,
                                        options: [.create, .truncate],
                                        permissions: .ownerReadWrite)

      let fd2 = FileDescriptor(rawValue: 731)
      let fd3 = try fd1.duplicate(as: fd2)
      XCTAssertEqual(fd2, fd3)

      try fd2.close()
      do {
        try fd3.close()
        XCTFail("Should be unreachable")
      } catch {
        if let error = try? XCTUnwrap(error as? Errno) {
          XCTAssertEqual(error, .badFileDescriptor)
        }
      }

      // dup2() accepts two equal parameters.
      let fd4 = try fd1.duplicate(as: fd1)
      XCTAssertEqual(fd4, fd1)

      try fd1.close()
      do {
        try fd4.close()
        XCTFail("Should be unreachable")
      } catch {
        if let error = try? XCTUnwrap(error as? Errno) {
          XCTAssertEqual(error, .badFileDescriptor)
        }
      }
    }
  }

  func testAdHocDuplicate3() throws {
    guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
      throw XCTSkip("dup3 and DuplicateOptions require Darwin 27 or newer")
    }

    try withTemporaryFilePath(basename: "test") {
      let path = $0.appending("foo3.txt")

      let fd1 = try FileDescriptor.open(path, .readWrite,
                                        options: [.create, .truncate],
                                        permissions: .ownerReadWrite)

      let fd2 = FileDescriptor(rawValue: 731)
      let fd3 = try fd1.duplicate(as: fd2, options: [.closeOnExec])
      XCTAssertEqual(fd2, fd3)

      try fd2.close()
      do {
        try fd3.close()
      } catch {
        if let error = try? XCTUnwrap(error as? Errno) {
          XCTAssertEqual(error, .badFileDescriptor)
        }
      }

      // dup3() does not accept two equal parameters.
      do {
        _ = try fd1.duplicate(as: fd1, options: [])
        XCTFail("Should be unreachable")
      } catch {
        if let error = try? XCTUnwrap(error as? Errno) {
          XCTAssertEqual(error, .invalidArgument)
        }
      }
    }
  }
#endif // !os(Windows)

  func testAdHocOpen() {
    // Ad-hoc test touching a file system.
    do {
      // TODO: Test this against a virtual in-memory file system
      try withTemporaryFilePath(basename: "testAdhocOpen") { path in
        let fd = try FileDescriptor.open(path.appending("b.txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
        try fd.closeAfter {
          try fd.writeAll("abc".utf8)
          var def = "def"
          try def.withUTF8 {
            _ = try fd.write(UnsafeRawBufferPointer($0))
          }
          try fd.seek(offset: 1, from: .start)

          let readLen = 3
          let readBytes = try Array<UInt8>(unsafeUninitializedCapacity: readLen) { (buf, count) in
            count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
          }
          let preadBytes = try Array<UInt8>(unsafeUninitializedCapacity: readLen) { (buf, count) in
            count = try fd.read(fromAbsoluteOffset: 1, into: UnsafeMutableRawBufferPointer(buf))
          }

          XCTAssertEqual(readBytes.first!, "b".utf8.first!)
          XCTAssertEqual(readBytes, preadBytes)

          // TODO: seek
        }
      }
    } catch let err as Errno {
      print("caught \(err))")
      // Should we assert? I'd be interested in knowing if this happened
      XCTAssert(false)
    } catch {
      fatalError("FATAL: `testAdHocOpen`")
    }
  }

  #if ENABLE_MOCKING
  func testGithubIssues() {
    // https://github.com/apple/swift-system/issues/26
    #if os(WASI)
    let openOptions = _getConst_O_WRONLY() | _getConst_O_CREAT()
    #else
    let openOptions = O_WRONLY | O_CREAT
    #endif
    let issue26 = MockTestCase(
      name: "open", .interruptable, "a path", openOptions, 0o020
    ) {
      retryOnInterrupt in
      _ = try FileDescriptor.open(
        "a path", .writeOnly, options: [.create],
        permissions: [.groupWrite],
        retryOnInterrupt: retryOnInterrupt)
    }
    issue26.runAllTests()
  }
  #endif // ENABLE_MOCKING

  @available(System 1.2.0, *)
  func testResizeFile() throws {
    try withTemporaryFilePath(basename: "testResizeFile") { path in 
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        // File should be empty initially.
        XCTAssertEqual(try fd.fileSize(), 0)
        // Write 3 bytes.
        try fd.writeAll("abc".utf8)
        // File should now be 3 bytes.
        XCTAssertEqual(try fd.fileSize(), 3)
        // Resize to 6 bytes.
        try fd.resize(to: 6)
        // File should now be 6 bytes.
        XCTAssertEqual(try fd.fileSize(), 6)
        // Read in the 6 bytes.
        let readBytes = try Array<UInt8>(unsafeUninitializedCapacity: 6) { (buf, count) in
          try fd.seek(offset: 0, from: .start)
          // Should have read all 6 bytes.
          count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
          XCTAssertEqual(count, 6)
        }
        // First 3 bytes should be unaffected by resize.
        XCTAssertEqual(Array(readBytes[..<3]), Array("abc".utf8))
        // Extension should be padded with zeros.
        XCTAssertEqual(Array(readBytes[3...]), Array(repeating: 0, count: 3))
        // File should still be 6 bytes.
        XCTAssertEqual(try fd.fileSize(), 6)
        // Resize to 2 bytes.
        try fd.resize(to: 2)
        // File should now be 2 bytes.
        XCTAssertEqual(try fd.fileSize(), 2)
        // Read in file with a buffer big enough for 6 bytes.
        let readBytesAfterTruncation = try Array<UInt8>(unsafeUninitializedCapacity: 6) { (buf, count) in
          try fd.seek(offset: 0, from: .start)
          count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
          // Should only have read 2 bytes.
          XCTAssertEqual(count, 2)
        }
        // Written content was trunctated.
        XCTAssertEqual(readBytesAfterTruncation, Array("ab".utf8))
      }
    }
  }

#if !os(Windows)
  @available(System 199, *)
  func testSynchronize() throws {
    try withTemporaryFilePath(basename: "testSynchronize") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)
        try fd.synchronize()
        XCTAssertEqual(try fd.fileSize(), 3)
      }
    }
  }

#if !SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  func testSynchronizeData() throws {
    try withTemporaryFilePath(basename: "testSynchronizeData") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)
        try fd.synchronizeData()
        XCTAssertEqual(try fd.fileSize(), 3)
      }
    }
  }
#endif // !SYSTEM_PACKAGE_DARWIN

  @available(System 199, *)
  func testOpenRelativeTo() throws {
    try withTemporaryFilePath(basename: "testOpenRelativeTo") { path in
      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        let fd = try FileDescriptor.open(
          "a.txt", relativeTo: dir, .readWrite,
          options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
        try fd.closeAfter {
          _ = try fd.writeAll("abc".utf8)
        }

        // The file was created inside the directory.
        let file = try FileDescriptor.open(path.appending("a.txt"), .readOnly)
        try file.closeAfter {
          let readBytes = try Array<UInt8>(unsafeUninitializedCapacity: 3) { buf, count in
            count = try file.read(into: UnsafeMutableRawBufferPointer(buf))
          }
          XCTAssertEqual(readBytes, Array("abc".utf8))

          #if !os(WASI) // WASI resolves paths only beneath the directory
          // An absolute path ignores the directory argument.
          let absolute = try FileDescriptor.open(
            path.appending("a.txt"), relativeTo: file, .readOnly)
          try absolute.close()
          #endif

          // A relative path is resolved against the directory argument.
          XCTAssertThrowsError(try FileDescriptor.open("a.txt", relativeTo: file, .readOnly)) {
            XCTAssertEqual($0 as? Errno, .notDirectory)
          }
        }
        XCTAssertThrowsError(try FileDescriptor.open("b.txt", relativeTo: dir, .readOnly)) {
          XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
        }
      }
    }
  }
#endif // !os(Windows)

#if !os(Windows) && !os(WASI)
  @available(System 199, *)
  func testSetPermissions() throws {
    try withTemporaryFilePath(basename: "testSetPermissions") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.setPermissions([.ownerRead, .groupRead])
        XCTAssertEqual(try fd.stat().permissions, [.ownerRead, .groupRead])
      }
    }
  }

  @available(System 199, *)
  func testSetOwner() throws {
    try withTemporaryFilePath(basename: "testSetOwner") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        let original = try fd.stat()

        // The owner can always pass the file's current IDs, or nil.
        try fd.setOwner()
        try fd.setOwner(user: original.userID, group: original.groupID)
        XCTAssertEqual(try fd.stat().userID, original.userID)
        XCTAssertEqual(try fd.stat().groupID, original.groupID)

        // The owner can change the group to another group they belong to.
        let count = getgroups(0, nil)
        var groups = [gid_t](repeating: 0, count: Int(max(count, 0)))
        let filled = Int(max(getgroups(count, &groups), 0))
        if let other = groups.prefix(filled).first(where: { $0 != original.groupID.rawValue }) {
          try fd.setOwner(group: GroupID(other))
          XCTAssertEqual(try fd.stat().groupID, GroupID(other))
          XCTAssertEqual(try fd.stat().userID, original.userID)
        }

        // Only a privileged process can give the file to another user.
        if geteuid() != 0 {
          XCTAssertThrowsError(try fd.setOwner(user: UserID(0))) {
            XCTAssertEqual($0 as? Errno, .notPermitted)
          }
        }
      }
    }
  }

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  @available(System 199, *)
  func testSetFileFlags() throws {
    try withTemporaryFilePath(basename: "testSetFileFlags") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        let original = try fd.stat().flags
        XCTAssertFalse(original.contains(.noDump))

        try fd.setFileFlags(original.union(.noDump))
        XCTAssertEqual(try fd.stat().flags, original.union(.noDump))

        try fd.setFileFlags(original)
        XCTAssertEqual(try fd.stat().flags, original)
      }
    }
  }
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

  @available(System 199, *)
  func testDescriptorFlags() throws {
    try withTemporaryFilePath(basename: "testDescriptorFlags") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        XCTAssertFalse(try fd.descriptorFlags().contains(.closeOnExec))
        try fd.setDescriptorFlags(fd.descriptorFlags().union(.closeOnExec))
        XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))

        // Each descriptor has its own flags.
        let duplicate = try fd.duplicate()
        try duplicate.closeAfter {
          XCTAssertFalse(try duplicate.descriptorFlags().contains(.closeOnExec))
        }

        try fd.setDescriptorFlags([])
        XCTAssertEqual(try fd.descriptorFlags(), [])
      }

      let closeOnExec = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .closeOnExec], permissions: .ownerReadWrite)
      try closeOnExec.closeAfter {
        XCTAssertTrue(try closeOnExec.descriptorFlags().contains(.closeOnExec))
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).descriptorFlags()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  @available(System 199, *)
  func testDuplicateAtLeast() throws {
    try withTemporaryFilePath(basename: "testDuplicateAtLeast") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        let minimum = FileDescriptor(rawValue: 100)
        let copy = try fd.duplicate(atLeast: minimum, closeOnExec: false)
        try copy.closeAfter {
          XCTAssertGreaterThanOrEqual(copy.rawValue, minimum.rawValue)
          XCTAssertFalse(try copy.descriptorFlags().contains(.closeOnExec))
          // The copy shares the open file, including its offset.
          try copy.writeAll("abc".utf8)
          XCTAssertEqual(try fd.seek(offset: 0, from: .current), 3)

          // The minimum is taken, so the next copy gets a higher descriptor.
          let next = try fd.duplicate(atLeast: copy, closeOnExec: true)
          try next.closeAfter {
            XCTAssertGreaterThan(next.rawValue, copy.rawValue)
            XCTAssertTrue(try next.descriptorFlags().contains(.closeOnExec))
          }
        }

        let lowest = try fd.duplicate(closeOnExec: true)
        try lowest.closeAfter {
          XCTAssertTrue(try lowest.descriptorFlags().contains(.closeOnExec))
        }

        XCTAssertThrowsError(
          try fd.duplicate(atLeast: FileDescriptor(rawValue: -1), closeOnExec: false)
        ) {
          XCTAssertEqual($0 as? Errno, .invalidArgument)
        }
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).duplicate(closeOnExec: true)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  @available(System 199, *)
  func testLock() throws {
    try withTemporaryFilePath(basename: "testLock") { path in
      let file = path.appending("\(UUID().uuidString).txt")
      // Locks belong to open files, so two opens of one file conflict,
      // even in one process.
      let first = try FileDescriptor.open(file, .readWrite, options: .create, permissions: .ownerReadWrite)
      try first.closeAfter {
        let second = try FileDescriptor.open(file, .readWrite)
        try second.closeAfter {
          try first.lockWholeFile()
          XCTAssertThrowsError(try second.lockWholeFile(nonBlocking: true)) {
            XCTAssertEqual($0 as? Errno, .wouldBlock)
          }
          XCTAssertThrowsError(try second.lockWholeFile(shared: true, nonBlocking: true)) {
            XCTAssertEqual($0 as? Errno, .wouldBlock)
          }

          // A duplicate shares the lock, so it can release it.
          let duplicate = try first.duplicate()
          try duplicate.closeAfter { try duplicate.unlockWholeFile() }
          try second.lockWholeFile(nonBlocking: true)
          try second.unlockWholeFile()

          // Shared locks coexist, and exclude an exclusive one.
          try first.lockWholeFile(shared: true, nonBlocking: true)
          try second.lockWholeFile(shared: true, nonBlocking: true)
          XCTAssertThrowsError(try first.lockWholeFile(nonBlocking: true)) {
            XCTAssertEqual($0 as? Errno, .wouldBlock)
          }
          try second.unlockWholeFile()
          // With the other shared lock gone, the shared lock can become exclusive.
          try first.lockWholeFile(nonBlocking: true)
          try first.unlockWholeFile()
        }
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).lockWholeFile()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

#if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  func testSynchronizeFully() throws {
    try withTemporaryFilePath(basename: "testSynchronizeFully") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)
        try fd.synchronizeFully()
        try fd.writeAll("def".utf8)
        try fd.synchronizeWithBarrier()
        XCTAssertEqual(try fd.fileSize(), 6)
      }
    }
  }
#endif // SYSTEM_PACKAGE_DARWIN
#endif // !os(Windows) && !os(WASI)

#if !os(Windows)
  @available(System 199, *)
  func testStatusFlags() throws {
    try withTemporaryFilePath(basename: "testStatusFlags") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .writeOnly, options: [.create, .append], permissions: .ownerReadWrite)
      try fd.closeAfter {
        XCTAssertEqual(try fd.accessMode(), .writeOnly)
        XCTAssertTrue(try fd.statusFlags().contains(.append))
        XCTAssertFalse(try fd.statusFlags().contains(.nonBlocking))

        try fd.setStatusFlags(fd.statusFlags().union(.nonBlocking))
        XCTAssertTrue(try fd.statusFlags().contains(.nonBlocking))
        XCTAssertTrue(try fd.statusFlags().contains(.append))
        XCTAssertEqual(try fd.accessMode(), .writeOnly)

        #if !os(WASI) // WASI has no dup
        // Duplicates share the open file, and so its status flags.
        let duplicate = try fd.duplicate()
        try duplicate.closeAfter {
          XCTAssertTrue(try duplicate.statusFlags().contains(.nonBlocking))
          try duplicate.setStatusFlags(duplicate.statusFlags().subtracting(.nonBlocking))
        }
        XCTAssertFalse(try fd.statusFlags().contains(.nonBlocking))
        #endif
      }

      let readWrite = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .nonBlocking], permissions: .ownerReadWrite)
      try readWrite.closeAfter {
        XCTAssertEqual(try readWrite.accessMode(), .readWrite)
        // Linux can report flags with no name here, such as O_LARGEFILE.
        XCTAssertTrue(try readWrite.statusFlags().contains(.nonBlocking))
        XCTAssertFalse(try readWrite.statusFlags().contains(.append))
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).statusFlags()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }
#endif // !os(Windows)

#if os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
  @available(System 199, *)
  func testAllocateSpace() throws {
    try withTemporaryFilePath(basename: "testAllocateSpace") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll("abc".utf8)
        do {
          try fd.allocateSpace(offset: 0, length: 1 << 16)
        } catch let error as Errno
          where [Errno.invalidArgument, .notSupported, .notSupportedOnSocket, .noFunction]
            .contains(error)
        {
          throw XCTSkip("The file system doesn't support preallocation: \(error)")
        }
        // The file is extended, its contents are kept, and the offset is unchanged.
        XCTAssertEqual(try fd.stat().size, 1 << 16)
        XCTAssertEqual(try fd.seek(offset: 0, from: .current), 3)
        let bytes = try Array<UInt8>(unsafeUninitializedCapacity: 8) { buf, count in
          count = try fd.read(fromAbsoluteOffset: 0, into: UnsafeMutableRawBufferPointer(buf))
        }
        XCTAssertEqual(bytes, Array("abc".utf8) + [0, 0, 0, 0, 0])

        // A range within the file leaves its size alone.
        try fd.allocateSpace(offset: 16, length: 16)
        XCTAssertEqual(try fd.stat().size, 1 << 16)
      }

      let readOnly = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readOnly, options: .create, permissions: .ownerReadWrite)
      try readOnly.closeAfter {
        XCTAssertThrowsError(try readOnly.allocateSpace(offset: 0, length: 16)) {
          XCTAssertEqual($0 as? Errno, .badFileDescriptor)
        }
      }
    }
  }

  @available(System 199, *)
  func testAdvise() throws {
    try withTemporaryFilePath(basename: "testAdvise") { path in
      let fd = try FileDescriptor.open(path.appending("\(UUID().uuidString).txt"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
      try fd.closeAfter {
        try fd.writeAll(Array(repeating: UInt8(ascii: "a"), count: 1 << 14))
        for advice in [
          FileDescriptor.Advice.sequential, .random, .willNeed, .dontNeed, .noReuse, .normal,
        ] {
          try fd.advise(advice)
          try fd.advise(advice, offset: 4096, length: 4096)
        }
        // Advice doesn't change the file.
        XCTAssertEqual(try fd.stat().size, 1 << 14)
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).advise(.normal)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    #if !os(WASI) // WASI has no pipe
    let pipe = try FileDescriptor.pipe()
    try pipe.readEnd.closeAfter {
      try pipe.writeEnd.closeAfter {
        XCTAssertThrowsError(try pipe.readEnd.advise(.sequential)) {
          XCTAssertEqual($0 as? Errno, .illegalSeek)
        }
      }
    }
    #endif
  }
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
}

