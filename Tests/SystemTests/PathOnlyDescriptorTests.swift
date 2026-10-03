/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android) || os(FreeBSD)

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

@Suite("Path-only descriptors")
private struct PathOnlyDescriptorTests {
  @available(System 199, *)
  @Test func theFlag() {
    #expect(FileDescriptor.OpenOptions.pathOnly.rawValue != 0)
    #expect(!FileDescriptor.OpenOptions.pathOnly.contains(.directory))
    #if os(Linux) && (arch(x86_64) || arch(arm64))
    // The kernel's generic value, which these architectures use.
    #expect(FileDescriptor.OpenOptions.pathOnly.rawValue == 0o10000000)
    #endif
  }

  /// A directory's descriptor resolves paths, and has the directory's
  /// status, but can't be read.
  @available(System 199, *)
  @Test func aDirectorysLocation() throws {
    try withTemporaryFilePath(basename: "aDirectorysLocation") { dir in
      let file = try FileDescriptor.open(
        dir.appending("file"), .writeOnly, options: [.create, .exclusiveCreate],
        permissions: .ownerReadWrite)
      _ = try file.closeAfter { try file.writeAll("contents".utf8) }

      let location = try FileDescriptor.open(dir, .readOnly, options: [.pathOnly, .directory])
      defer { try? location.close() }
      #expect(try location.stat().type == .directory)
      let status = try FilePath("file").stat(relativeTo: location, flags: [])
      #expect(status.type == .regular && status.size == 8)
      let opened = try FileDescriptor.open("file", relativeTo: location, .readOnly)
      defer { try? opened.close() }
      var buffer = [UInt8](repeating: 0, count: 8)
      #expect(try buffer.withUnsafeMutableBytes { try opened.read(into: $0) } == 8)
      #expect(throws: Errno.badFileDescriptor) {
        try buffer.withUnsafeMutableBytes { try location.read(into: $0) }
      }
    }
  }

  /// A file's descriptor needs no permission on the file, and can't be read
  /// or written.
  @available(System 199, *)
  @Test func aFilesLocation() throws {
    try withTemporaryFilePath(basename: "aFilesLocation") { dir in
      let path = dir.appending("file")
      let file = try FileDescriptor.open(
        path, .writeOnly, options: [.create, .exclusiveCreate], permissions: [])
      try file.close()

      let location = try FileDescriptor.open(path, .readOnly, options: .pathOnly)
      defer { try? location.close() }
      let status = try location.stat()
      #expect(status.type == .regular && status.permissions == [])
      #expect(throws: Errno.badFileDescriptor) { try location.writeAll("data".utf8) }
      var buffer = [UInt8](repeating: 0, count: 4)
      #expect(throws: Errno.badFileDescriptor) {
        try buffer.withUnsafeMutableBytes { try location.read(into: $0) }
      }
      let duplicate = try location.duplicate()
      defer { try? duplicate.close() }
      #expect(try duplicate.stat().inode == status.inode)
    }
  }

  /// With noFollow, a symbolic link's descriptor refers to the link.
  @available(System 199, *)
  @Test func aSymbolicLinksLocation() throws {
    try withTemporaryFilePath(basename: "aSymbolicLinksLocation") { dir in
      let link = dir.appending("link")
      try link.makeSymbolicLink(to: "target that doesn't exist")

      let location = try FileDescriptor.open(link, .readOnly, options: [.pathOnly, .noFollow])
      defer { try? location.close() }
      #expect(try location.stat().type == .symbolicLink)
      #expect(throws: Errno.noSuchFileOrDirectory) {
        _ = try FileDescriptor.open(link, .readOnly, options: .pathOnly)
      }
    }
  }
}

#endif // os(Linux) || os(Android) || os(FreeBSD)
