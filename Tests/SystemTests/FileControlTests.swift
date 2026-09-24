/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if !os(Windows) && !os(WASI)

// Tests for the `control` methods and `Command`, the low-level interface to
// fcntl, and for the methods that wrap particular commands.
@available(System 199, *)
final class FileControlTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let fd = FileDescriptor(rawValue: 1)
    let rawFD = fd.rawValue
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
    defer { pointer.deallocate() }

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "fcntl", .interruptable, rawFD, F_GETFD) { retryOnInterrupt in
        _ = try fd.control(.getDescriptorFlags, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_SETFL, O_NONBLOCK) {
        retryOnInterrupt in
        try fd.control(.setStatusFlags, O_NONBLOCK, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_DUPFD, 10) { retryOnInterrupt in
        try fd.control(.duplicate, 10, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_GETLK, pointer) {
        retryOnInterrupt in
        try fd.control(.getLock, pointer, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "fcntl", .interruptable, rawFD, F_SETLKW, _F_WRLCK, CShort(SEEK_CUR),
        Int64(-4), Int64(4), CInterop.ProcessID(0)
      ) { retryOnInterrupt in
        var lock = FileDescriptor.FileLock(
          kind: .write, start: -4, length: 4, origin: .current)
        try fd.control(.setLockWait, &lock, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETOWN) { _ in
        _ = try fd.signalOwner()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETOWN, 42) { _ in
        try fd.setSignalOwner(ProcessID(42))
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETOWN, -42) { _ in
        try fd.setSignalOwner(ProcessID(42), isGroup: true)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETOWN, 0) { _ in
        try fd.setSignalOwner(nil)
      },
    ]
    for test in syscallTestCases { test.runAllTests() }

    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
    let ofd = MockTestCase(
      name: "fcntl", .interruptable, rawFD, _F_OFD_GETLK, _F_RDLCK, CShort(SEEK_SET),
      Int64(3), Int64(0), CInterop.ProcessID(0)
    ) { retryOnInterrupt in
      var lock = FileDescriptor.FileLock(kind: .read, start: 3)
      try fd.control(.getOFDLock, &lock, retryOnInterrupt: retryOnInterrupt)
    }
    ofd.runAllTests()
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    let darwinTestCases: Array<MockTestCase> = [
      MockTestCase(name: "fcntl", .interruptable, rawFD, F_PREALLOCATE, Wildcard()) {
        retryOnInterrupt in
        var store = FileDescriptor.ControlTypes.Store(
          positionMode: .physicalEndOfFile, length: 4096)
        try fd.control(.preallocate, &store, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_PUNCHHOLE, Wildcard()) {
        retryOnInterrupt in
        var hole = FileDescriptor.ControlTypes.PunchHole(offset: 0, length: 4096)
        try fd.control(.punchHole, &hole, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_RDADVISE, Wildcard()) {
        retryOnInterrupt in
        var advisory = FileDescriptor.ControlTypes.ReadAdvisory(offset: 0, count: 4096)
        try fd.control(.readAdvise, &advisory, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .interruptable, rawFD, F_LOG2PHYS_EXT, Wildcard()) {
        retryOnInterrupt in
        var location = FileDescriptor.ControlTypes.LogicalToPhysical(
          contiguousBytes: 4096, deviceOffset: 0)
        try fd.control(
          .logicalToPhysicalExtended, &location, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_NOCACHE, 1) { _ in
        try fd.setNoCache(true)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_NOCACHE, 0) { _ in
        try fd.setNoCache(false)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETNOSIGPIPE) { _ in
        _ = try fd.noSigPipe()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_SETNOSIGPIPE, 1) { _ in
        try fd.setNoSigPipe(true)
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETPATH, Wildcard()) { _ in
        _ = try fd.path()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, F_GETPATH_NOFIRMLINK, Wildcard()) {
        _ in
        _ = try fd.path(resolvingFirmlinks: true)
      },
    ]
    for test in darwinTestCases { test.runAllTests() }
    #endif // SYSTEM_PACKAGE_DARWIN

    #if os(Linux) || os(Android)
    let linuxTestCases: Array<MockTestCase> = [
      MockTestCase(name: "fcntl", .noInterrupt, rawFD, _F_GETPIPE_SZ) { _ in
        _ = try fd.pipeCapacity()
      },

      MockTestCase(name: "fcntl", .noInterrupt, rawFD, _F_SETPIPE_SZ, 1 << 20) { _ in
        try fd.setPipeCapacity(atLeast: 1 << 20)
      },

      // A capacity too large for fcntl's argument is clamped, so that
      // fcntl rejects it, rather than trapping.
      MockTestCase(name: "fcntl", .noInterrupt, rawFD, _F_SETPIPE_SZ, CInt.max) { _ in
        try fd.setPipeCapacity(atLeast: .max)
      },
    ]
    for test in linuxTestCases { test.runAllTests() }
    #endif // os(Linux) || os(Android)
  }
  #endif // ENABLE_MOCKING

  func testCommandValues() {
    XCTAssertEqual(FileDescriptor.Command.duplicate.rawValue, F_DUPFD)
    XCTAssertEqual(FileDescriptor.Command.duplicateCloseOnExec.rawValue, F_DUPFD_CLOEXEC)
    XCTAssertEqual(FileDescriptor.Command.getDescriptorFlags.rawValue, F_GETFD)
    XCTAssertEqual(FileDescriptor.Command.setDescriptorFlags.rawValue, F_SETFD)
    XCTAssertEqual(FileDescriptor.Command.getStatusFlags.rawValue, F_GETFL)
    XCTAssertEqual(FileDescriptor.Command.setStatusFlags.rawValue, F_SETFL)
    XCTAssertEqual(FileDescriptor.Command.getSignalOwner.rawValue, F_GETOWN)
    XCTAssertEqual(FileDescriptor.Command.setSignalOwner.rawValue, F_SETOWN)
    XCTAssertEqual(FileDescriptor.Command.getLock.rawValue, F_GETLK)
    XCTAssertEqual(FileDescriptor.Command.setLock.rawValue, F_SETLK)
    XCTAssertEqual(FileDescriptor.Command.setLockWait.rawValue, F_SETLKW)
    #if SYSTEM_PACKAGE_DARWIN
    XCTAssertEqual(FileDescriptor.Command.getOFDLock.rawValue, F_OFD_GETLK)
    XCTAssertEqual(FileDescriptor.Command.setOFDLock.rawValue, F_OFD_SETLK)
    XCTAssertEqual(FileDescriptor.Command.setOFDLockWait.rawValue, F_OFD_SETLKW)
    XCTAssertEqual(FileDescriptor.Command.setOFDLockWaitTimeout.rawValue, F_OFD_SETLKWTIMEOUT)
    XCTAssertEqual(FileDescriptor.Command.getPath.rawValue, F_GETPATH)
    XCTAssertEqual(FileDescriptor.Command.noCache.rawValue, F_NOCACHE)
    XCTAssertEqual(FileDescriptor.Command.synchronizeFully.rawValue, F_FULLFSYNC)
    XCTAssertEqual(FileDescriptor.Command.getSignatureInfo.rawValue, F_GETSIGSINFO)
    #elseif os(Linux) || os(Android)
    // Linux's values, which the C library may not declare.
    XCTAssertEqual(FileDescriptor.Command.getOFDLock.rawValue, 36)
    XCTAssertEqual(FileDescriptor.Command.setOFDLock.rawValue, 37)
    XCTAssertEqual(FileDescriptor.Command.setOFDLockWait.rawValue, 38)
    XCTAssertEqual(FileDescriptor.Command.setPipeCapacity.rawValue, 1031)
    XCTAssertEqual(FileDescriptor.Command.getPipeCapacity.rawValue, 1032)
    #endif
  }

  func testControl() throws {
    try withTemporaryFilePath(basename: "testControl") { path in
      let fd = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: [.create, .append],
        permissions: .ownerReadWrite)
      defer { try? fd.close() }

      // The low-level methods agree with the ones that wrap each command.
      XCTAssertEqual(
        try fd.control(.getDescriptorFlags), try fd.descriptorFlags().rawValue)
      try fd.control(.setDescriptorFlags, FD_CLOEXEC)
      XCTAssertTrue(try fd.descriptorFlags().contains(.closeOnExec))
      let status = try fd.control(.getStatusFlags)
      XCTAssertEqual(status & O_ACCMODE, O_RDWR)
      XCTAssertNotEqual(status & O_APPEND, 0)

      let copy = FileDescriptor(rawValue: try fd.control(.duplicateCloseOnExec, 50))
      defer { try? copy.close() }
      XCTAssertGreaterThanOrEqual(copy.rawValue, 50)
      XCTAssertTrue(try copy.descriptorFlags().contains(.closeOnExec))

      // A pointer argument, here a raw lock description.
      var raw = FileDescriptor.FileLock(kind: .write).rawValue
      try withUnsafeMutablePointer(to: &raw) {
        _ = try fd.control(.getLock, UnsafeMutableRawPointer($0))
      }
      XCTAssertEqual(FileDescriptor.FileLock(rawValue: raw).kind, .none)

      XCTAssertThrowsError(try fd.control(.init(rawValue: -1))) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).control(.getDescriptorFlags)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  func testRecordLockCommands() throws {
    try withTemporaryFilePath(basename: "testRecordLockCommands") { path in
      let file = path.appending("file.txt")
      let a = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      defer { try? a.close() }
      let b = try FileDescriptor.open(file, .readWrite)
      defer { try? b.close() }

      // A process's own process-owned locks never block it,
      // even through another open of the file.
      var lock = FileDescriptor.FileLock(kind: .write, length: 10)
      try a.control(.setLock, &lock)
      var query = FileDescriptor.FileLock(kind: .write, start: 5, length: 1)
      try b.control(.getLock, &query)
      XCTAssertEqual(query.kind, .none)
      lock.kind = .none
      try a.control(.setLock, &lock)

      #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
      // Open file description locks do block other opens,
      // and a query reports them without a process.
      XCTAssertTrue(try a.lock(.write, byteRange: 0..<10))
      query = FileDescriptor.FileLock(kind: .read, start: 5, length: 1)
      try b.control(.getOFDLock, &query)
      XCTAssertEqual(query.kind, .write)
      XCTAssertEqual(query.start, 0)
      XCTAssertEqual(query.length, 10)
      XCTAssertEqual(query.processID, ProcessID(-1))
      // Nothing is in the way of the range after the lock.
      query = FileDescriptor.FileLock(kind: .write, start: 10)
      try b.control(.getOFDLock, &query)
      XCTAssertEqual(query.kind, .none)
      try a.unlock()
      #endif
    }
  }

  func testSignalOwner() throws {
    // Sockets keep the owner as given on every platform.
    var sockets: [CInt] = [-1, -1]
    #if os(Linux) && canImport(Glibc)
    let streamType = CInt(SOCK_STREAM.rawValue)
    #else
    let streamType = SOCK_STREAM
    #endif
    XCTAssertEqual(socketpair(AF_UNIX, streamType, 0, &sockets), 0)
    let socket = FileDescriptor(rawValue: sockets[0])
    defer {
      try? socket.close()
      try? FileDescriptor(rawValue: sockets[1]).close()
    }
    XCTAssertNil(try socket.signalOwner())
    try socket.setSignalOwner(.current)
    XCTAssertEqual(try socket.signalOwner()?.id, .current)
    XCTAssertEqual(try socket.signalOwner()?.isGroup, false)
    let group = ProcessID(getpgrp())
    try socket.setSignalOwner(group, isGroup: true)
    XCTAssertEqual(try socket.signalOwner()?.id, group)
    XCTAssertEqual(try socket.signalOwner()?.isGroup, true)
    // Process group 1 is reported as -1, which isn't taken for a failure.
    try socket.setSignalOwner(ProcessID(1), isGroup: true)
    XCTAssertEqual(try socket.signalOwner()?.id, ProcessID(1))
    XCTAssertEqual(try socket.signalOwner()?.isGroup, true)
    // Duplicates share the open file's owner.
    let duplicate = try socket.duplicate()
    try duplicate.closeAfter {
      XCTAssertEqual(try duplicate.signalOwner()?.id, ProcessID(1))
    }
    try socket.setSignalOwner(nil)
    XCTAssertNil(try socket.signalOwner())

    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    try pipe.readEnd.setSignalOwner(.current)
    #if SYSTEM_PACKAGE_DARWIN
    // Darwin reports a pipe's owner with the sign reversed.
    XCTAssertEqual(try pipe.readEnd.signalOwner()?.id, .current)
    XCTAssertEqual(try pipe.readEnd.signalOwner()?.isGroup, true)
    #else
    XCTAssertEqual(try pipe.readEnd.signalOwner()?.id, .current)
    XCTAssertEqual(try pipe.readEnd.signalOwner()?.isGroup, false)
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    // Darwin's regular files have no owner.
    try withTemporaryFilePath(basename: "testSignalOwner") { path in
      let file = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: .create,
        permissions: .ownerReadWrite)
      defer { try? file.close() }
      XCTAssertThrowsError(try file.signalOwner()) {
        XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
      }
      XCTAssertThrowsError(try file.setSignalOwner(.current)) {
        XCTAssertEqual($0 as? Errno, .inappropriateIOCTLForDevice)
      }
    }
    #endif
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).signalOwner()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).setSignalOwner(.current)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  func testNoCache() throws {
    try withTemporaryFilePath(basename: "testNoCache") { path in
      let fd = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: .create,
        permissions: .ownerReadWrite)
      defer { try? fd.close() }
      try fd.setNoCache(true)
      try fd.writeAll("uncached".utf8)
      try fd.setNoCache(false)
      XCTAssertEqual(try fd.fileSize(), 8)
    }
    // Only regular files have a cache to bypass.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    XCTAssertThrowsError(try pipe.readEnd.setNoCache(true)) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  func testNoSigPipe() throws {
    let pipe = try FileDescriptor.pipe()
    defer { try? pipe.writeEnd.close() }
    XCTAssertFalse(try pipe.writeEnd.noSigPipe())
    try pipe.writeEnd.setNoSigPipe(true)
    XCTAssertTrue(try pipe.writeEnd.noSigPipe())
    // The setting belongs to the open file.
    let duplicate = try pipe.writeEnd.duplicate()
    try duplicate.closeAfter {
      XCTAssertTrue(try duplicate.noSigPipe())
    }
    // So the write fails without a signal, which would end the test.
    try pipe.readEnd.close()
    XCTAssertThrowsError(try pipe.writeEnd.writeAll("x".utf8)) {
      XCTAssertEqual($0 as? Errno, .brokenPipe)
    }
    try pipe.writeEnd.setNoSigPipe(false)
    XCTAssertFalse(try pipe.writeEnd.noSigPipe())

    // For a socket, it's the SO_NOSIGPIPE option.
    var sockets: [CInt] = [-1, -1]
    XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets), 0)
    defer {
      _ = Darwin.close(sockets[0])
      _ = Darwin.close(sockets[1])
    }
    try FileDescriptor(rawValue: sockets[0]).setNoSigPipe(true)
    var option: CInt = 0
    var length = socklen_t(MemoryLayout<CInt>.size)
    XCTAssertEqual(getsockopt(sockets[0], SOL_SOCKET, SO_NOSIGPIPE, &option, &length), 0)
    XCTAssertEqual(option, 1)

    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).noSigPipe()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  func testPath() throws {
    func canonical(_ path: FilePath) throws -> FilePath {
      guard let resolved = realpath(path.string, nil) else { throw Errno.current }
      defer { free(resolved) }
      return FilePath(String(cString: resolved))
    }

    try withTemporaryFilePath(basename: "testPath") { directory in
      let file = directory.appending("file.txt")
      let fd = try FileDescriptor.open(
        file, .readWrite, options: .create, permissions: .ownerReadWrite)
      defer { try? fd.close() }
      // The path is the canonical one, with symbolic links resolved.
      let expected = try canonical(file)
      XCTAssertEqual(try fd.path(), expected)
      // Resolving firmlinks can only add to the start of the path.
      XCTAssertTrue(try fd.path(resolvingFirmlinks: true).string.hasSuffix(expected.string))

      // The path follows the file when it's renamed.
      try file.rename(to: directory.appending("renamed.txt"))
      XCTAssertEqual(try fd.path().lastComponent, "renamed.txt")

      let directoryFD = try FileDescriptor.open(directory, .readOnly)
      defer { try? directoryFD.close() }
      XCTAssertEqual(try directoryFD.path(), try canonical(directory))
    }

    // A pipe has no path.
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    XCTAssertThrowsError(try pipe.readEnd.path()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
    XCTAssertThrowsError(try FileDescriptor(rawValue: -1).path()) {
      XCTAssertEqual($0 as? Errno, .badFileDescriptor)
    }
  }

  func testControlTypes() throws {
    try withTemporaryFilePath(basename: "testControlTypes") { path in
      let fd = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: .create,
        permissions: .ownerReadWrite)
      defer { try? fd.close() }

      // Preallocating storage leaves the file's size alone.
      var store = FileDescriptor.ControlTypes.Store(
        positionMode: .physicalEndOfFile, length: 1 << 20, flags: .allOrNone)
      do {
        try fd.control(.preallocate, &store)
        XCTAssertEqual(store.bytesAllocated, 1 << 20)
      } catch Errno.notSupported {
        // Not every file system supports preallocation.
      }
      XCTAssertEqual(try fd.fileSize(), 0)
      // Allocating after the end of the storage requires a zero offset.
      store.offset = 5
      XCTAssertThrowsError(try fd.control(.preallocate, &store)) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }

      let bytes = [UInt8](repeating: 0x61, count: 1 << 16)
      try fd.writeAll(bytes)
      try fd.synchronize()

      var advisory = FileDescriptor.ControlTypes.ReadAdvisory(offset: 0, count: 4096)
      try fd.control(.readAdvise, &advisory)

      var location = FileDescriptor.ControlTypes.LogicalToPhysical(
        contiguousBytes: 4096, deviceOffset: 0)
      do {
        try fd.control(.logicalToPhysicalExtended, &location)
        XCTAssertGreaterThan(location.contiguousBytes, 0)
      } catch Errno.notSupported {
        // Not every file system can report device offsets.
      }

      // A hole reads as zeros, and must be aligned to the block size.
      var hole = FileDescriptor.ControlTypes.PunchHole(offset: 0, length: 16384)
      do {
        try fd.control(.punchHole, &hole)
        var readBack = [UInt8](repeating: 0xFF, count: 2)
        _ = try readBack.withUnsafeMutableBytes {
          try fd.read(fromAbsoluteOffset: 16383, into: $0)
        }
        XCTAssertEqual(readBack, [0, 0x61])
      } catch Errno.notSupported {
        // Not every file system supports holes.
      }
      hole.offset = 1
      XCTAssertThrowsError(try fd.control(.punchHole, &hole))
    }
  }
  #endif // SYSTEM_PACKAGE_DARWIN

  #if os(Linux) || os(Android)
  func testPipeCapacity() throws {
    let pipe = try FileDescriptor.pipe()
    defer {
      try? pipe.readEnd.close()
      try? pipe.writeEnd.close()
    }
    let original = try pipe.readEnd.pipeCapacity()
    XCTAssertGreaterThan(original, 0)
    // The capacity rounds up, and belongs to the pipe, not to one end.
    let capacity = try pipe.writeEnd.setPipeCapacity(atLeast: original + 1)
    XCTAssertGreaterThan(capacity, original)
    XCTAssertEqual(try pipe.readEnd.pipeCapacity(), capacity)

    try withTemporaryFilePath(basename: "testPipeCapacity") { path in
      let file = try FileDescriptor.open(
        path.appending("file.txt"), .readWrite, options: .create,
        permissions: .ownerReadWrite)
      defer { try? file.close() }
      XCTAssertThrowsError(try file.pipeCapacity()) {
        XCTAssertEqual($0 as? Errno, .badFileDescriptor)
      }
    }
  }
  #endif // os(Linux) || os(Android)
}

#endif // !os(Windows) && !os(WASI)
