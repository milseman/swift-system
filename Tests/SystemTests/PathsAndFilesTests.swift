/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@Suite("Paths and files")
private struct PathsAndFilesTests {
  @available(System 199, *)
  @Test func canonicalizedResolvesLinksAndDots() throws {
    try withTemporaryFilePath(basename: "canonicalized") { directory in
      let target = directory.appending("target")
      try FileDescriptor.open(target, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      try directory.appending("sub").makeDirectory(permissions: .ownerReadWriteExecute)
      try directory.appending("link").makeSymbolicLink(to: "sub/../target")

      // The temporary directory can itself be behind a link, as /var is on Darwin.
      let base = try directory.canonicalized()
      #expect(base.isAbsolute)
      #expect(try directory.appending("link").canonicalized() == base.appending("target"))
      #expect(try directory.appending("sub/./../sub//").canonicalized() == base.appending("sub"))
      #expect(throws: Errno.noSuchFileOrDirectory) {
        try directory.appending("missing").canonicalized()
      }
      // A relative path resolves against the working directory.
      #expect(try FilePath(".").canonicalized() == (try FilePath.currentWorkingDirectory().canonicalized()))
    }
  }

  @available(System 199, *)
  @Test func removeTakesFilesAndEmptyDirectories() throws {
    try withTemporaryFilePath(basename: "remove") { directory in
      let file = directory.appending("file")
      try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()
      let link = directory.appending("link")
      try link.makeSymbolicLink(to: "file")
      let empty = directory.appending("empty")
      try empty.makeDirectory(permissions: .ownerReadWriteExecute)
      let full = directory.appending("full")
      try full.makeDirectory(permissions: .ownerReadWriteExecute)
      try FileDescriptor.open(full.appending("x"), .writeOnly, options: .create, permissions: .ownerReadWrite)
        .close()

      // A link goes, and its target stays.
      try link.remove()
      try file.stat()
      try file.remove()
      try empty.remove()
      for path in [link, file, empty] {
        #expect(throws: Errno.noSuchFileOrDirectory) { try path.stat(followTargetSymlink: false) }
      }
      #expect(throws: Errno.self) { try full.remove() }
      try full.stat()
      #expect(throws: Errno.noSuchFileOrDirectory) { try directory.appending("missing").remove() }
    }
  }

  @available(System 199, *)
  @Test func makeUniqueFile() throws {
    try withTemporaryFilePath(basename: "makeUniqueFile") { directory in
      let template = directory.appending("report-XXXXXX")
      let (path, fd) = try template.makeUniqueFile(options: .closeOnExec)
      defer { try? fd.close() }
      let (other, otherFD) = try template.makeUniqueFile()
      try otherFD.close()

      #expect(path != other)
      #expect(path.removingLastComponent() == directory)
      let name = try #require(path.lastComponent?.string)
      #expect(name.hasPrefix("report-") && name.count == "report-XXXXXX".count)
      #expect(!name.hasSuffix("XXXXXX"))

      let status = try fd.stat()
      #expect(status.type == .regular)
      #expect(status.permissions.intersection([.groupReadWriteExecute, .otherReadWriteExecute]).isEmpty)
      #expect(try fd.descriptorFlags().contains(.closeOnExec))
      #expect(try other.stat().type == .regular)
      #expect(try fd.writeAll("hello".utf8) == 5)
      #expect(try path.stat().size == 5)

      // A template without six X's is invalid.
      #expect(throws: Errno.invalidArgument) {
        try directory.appending("report-XX").makeUniqueFile()
      }
    }
  }

  @available(System 199, *)
  @Test func makeUniqueFileRewritesACTemplate() throws {
    try withTemporaryFilePath(basename: "makeUniqueFileC") { directory in
      var template = Array(directory.appending("c-XXXXXX").string.utf8CString)
      let fd = try template.withUnsafeMutableBufferPointer {
        try FilePath.makeUniqueFile($0.baseAddress!)
      }
      try fd.close()
      let path = FilePath(String(cString: template))
      #expect(!path.string.hasSuffix("XXXXXX"))
      #expect(try path.stat().type == .regular)
    }
  }

  @available(System 199, *)
  @Test func makeUniqueDirectory() throws {
    try withTemporaryFilePath(basename: "makeUniqueDirectory") { directory in
      let template = directory.appending("scratch.XXXXXXXX")
      let path = try template.makeUniqueDirectory()
      let other = try template.makeUniqueDirectory()
      #expect(path != other)
      let status = try path.stat()
      #expect(status.type == .directory)
      #expect(status.permissions.intersection([.groupReadWriteExecute, .otherReadWriteExecute]).isEmpty)
      #expect(status.permissions.contains(.ownerReadWriteExecute))

      var cTemplate = Array(directory.appending("c.XXXXXX").string.utf8CString)
      try cTemplate.withUnsafeMutableBufferPointer {
        try FilePath.makeUniqueDirectory($0.baseAddress!)
      }
      #expect(try FilePath(String(cString: cTemplate)).stat().type == .directory)

      #expect(throws: Errno.invalidArgument) {
        try directory.appending("scratch").makeUniqueDirectory()
      }
    }
  }

  @available(System 199, *)
  @Test func currentWorkingDirectoryResolvesRelativePaths() throws {
    #expect(FileDescriptor.currentWorkingDirectory.rawValue == AT_FDCWD)
    let fd = try FileDescriptor.open(
      ".", relativeTo: .currentWorkingDirectory, .readOnly, options: .directory)
    defer { try? fd.close() }
    let viaDescriptor = try fd.stat()
    let viaPath = try FilePath(".").stat()
    #expect(viaDescriptor.inode == viaPath.inode)
    #expect(viaDescriptor.deviceID == viaPath.deviceID)
    // It isn't an open descriptor.
    #expect(throws: Errno.badFileDescriptor) { try FileDescriptor.currentWorkingDirectory.stat() }
  }
}

#endif // !os(Windows) && !os(WASI)
