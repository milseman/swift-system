/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

import Testing

#if canImport(Glibc)
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

@Suite("Unnamed temporary files")
private struct UnnamedTemporaryFileTests {
  @available(System 199, *)
  @Test func theFlags() {
    // O_TMPFILE is its own bit and O_DIRECTORY.
    #expect(FileDescriptor.OpenOptions.temporaryFile.contains(.directory))
    #expect(FileDescriptor.OpenOptions.temporaryFile != .directory)
    // AT_EMPTY_PATH is 0x1000 on every architecture.
    #expect(FilePath.ResolutionFlags.emptyPath.rawValue == 0x1000)
  }

  /// A file opened with no name has no links, until linking it through its
  /// descriptor names it.
  @available(System 199, *)
  @Test func anUnnamedFileGetsAName() throws {
    try withTemporaryFilePath(basename: "anUnnamedFileGetsAName") { dir in
      let fd: FileDescriptor
      do {
        fd = try FileDescriptor.open(
          dir, .readWrite, options: .temporaryFile, permissions: .ownerReadWrite)
      } catch {
        // The directory's file system has no unnamed files.
        #expect((error as? Errno) == Errno.notSupported)
        return
      }
      defer { try? fd.close() }
      _ = try fd.writeAll("unnamed".utf8)
      #expect(try fd.stat().linkCount == 0)

      let named = dir.appending("named")
      do {
        try named.makeHardLink(
          relativeTo: .currentWorkingDirectory, to: "", relativeTo: fd, flags: .emptyPath)
      } catch {
        // Without CAP_DAC_READ_SEARCH, which an unprivileged user lacks.
        #expect((error as? Errno) == Errno.noSuchFileOrDirectory)
        try named.makeHardLink(
          relativeTo: .currentWorkingDirectory,
          to: FilePath("/proc/self/fd/\(fd.rawValue)"),
          relativeTo: .currentWorkingDirectory,
          flags: .symlinkFollow)
      }
      #expect(try fd.stat().linkCount == 1)
      let status = try named.stat()
      #expect(status.inode == (try fd.stat()).inode)
      #expect(status.size == 7)
    }
  }

  /// With exclusiveCreate, the file can't be named.
  @available(System 199, *)
  @Test func anExclusiveUnnamedFileStaysUnnamed() throws {
    try withTemporaryFilePath(basename: "anExclusiveUnnamedFileStaysUnnamed") { dir in
      let fd: FileDescriptor
      do {
        fd = try FileDescriptor.open(
          dir, .writeOnly, options: [.temporaryFile, .exclusiveCreate],
          permissions: .ownerReadWrite)
      } catch {
        #expect((error as? Errno) == Errno.notSupported)
        return
      }
      defer { try? fd.close() }
      #expect(throws: Errno.self) {
        try dir.appending("named").makeHardLink(
          relativeTo: .currentWorkingDirectory,
          to: FilePath("/proc/self/fd/\(fd.rawValue)"),
          relativeTo: .currentWorkingDirectory,
          flags: .symlinkFollow)
      }
    }
  }

  /// Unnamed files are regular files, so the directory must be opened for
  /// writing.
  @available(System 199, *)
  @Test func readOnlyIsInvalid() throws {
    try withTemporaryFilePath(basename: "readOnlyIsInvalid") { dir in
      #expect(throws: Errno.invalidArgument) {
        try FileDescriptor.open(dir, .readOnly, options: .temporaryFile).close()
      }
    }
  }
}

#endif // os(Linux) || os(Android)
