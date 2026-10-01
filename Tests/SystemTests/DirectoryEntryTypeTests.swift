/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import CSystem
import WASILibc
#elseif canImport(Android)
import Android
#endif

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Directory entry types")
private struct DirectoryEntryTypeTests {
  @available(System 199, *)
  @Test func everyTypeConvertsBothWays() {
    #if os(WASI)
    // wasi-libc's DT_ macros are casts, which Swift can't import; CSystem
    // returns them. They're WASI's file types, with DT_FIFO its stream
    // socket's and DT_SOCK one of wasi-libc's own.
    let types: [(UInt8, FileType)] = [
      (_getConst_DT_REG(), .regular),
      (_getConst_DT_DIR(), .directory),
      (_getConst_DT_LNK(), .symbolicLink),
      (_getConst_DT_FIFO(), .fifo),
      (_getConst_DT_SOCK(), .socket),
      (_getConst_DT_CHR(), .characterSpecial),
      (_getConst_DT_BLK(), .blockSpecial),
    ]
    #else
    var types: [(UInt8, FileType)] = [
      (UInt8(DT_REG), .regular),
      (UInt8(DT_DIR), .directory),
      (UInt8(DT_LNK), .symbolicLink),
      (UInt8(DT_FIFO), .fifo),
      (UInt8(DT_SOCK), .socket),
      (UInt8(DT_CHR), .characterSpecial),
      (UInt8(DT_BLK), .blockSpecial),
    ]
    #endif
    #if SYSTEM_PACKAGE_DARWIN
    types.append((UInt8(DT_WHT), .whiteout))
    #endif
    for (entryType, fileType) in types {
      #expect(FileType(directoryEntryType: entryType) == fileType, "\(entryType)")
      #expect(fileType.directoryEntryType == entryType, "\(fileType)")
      #if !os(WASI) // WASI's DTTOIF is a function: its entry types aren't the mode's
      // DTTOIF: the mode's type bits are the entry type shifted by 12.
      #expect(FileType(rawValue: CInterop.Mode(entryType) << 12) == fileType, "\(entryType)")
      #endif
    }
    #if os(WASI)
    #expect(FileType(directoryEntryType: _getConst_DT_UNKNOWN()) == nil)
    #expect(FileType(rawValue: 0).directoryEntryType == _getConst_DT_UNKNOWN())
    #else
    #expect(FileType(directoryEntryType: UInt8(DT_UNKNOWN)) == nil)
    #expect(FileType(directoryEntryType: 3) == nil)
    #expect(FileType(rawValue: 0).directoryEntryType == UInt8(DT_UNKNOWN))
    #endif
  }

  /// Entries that readdir reports have the types that lstat reports,
  /// unless the file system reports DT_UNKNOWN.
  @available(System 199, *)
  @Test func readdirTypesMatchLstat() throws {
    try withTemporaryFilePath(basename: "directoryEntryTypes") { directory in
      let file = try FileDescriptor.open(
        directory.appending("file"), .writeOnly, options: .create, permissions: .ownerReadWrite)
      try file.close()
      try directory.appending("directory").makeDirectory(permissions: .ownerReadWriteExecute)
      try directory.appending("link").makeSymbolicLink(to: "file")
      #if !os(WASI) // WASI has no FIFOs
      try directory.appending("fifo").makeFIFO(permissions: .ownerReadWrite)
      #endif

      #if os(WASI)
      // wasi-libc's dirent ends in a flexible array, which Swift doesn't
      // import, so read CSystem's copy of each entry, as DirectoryStream does.
      let descriptor = try FileDescriptor.open(directory, .readOnly, options: .directory)
      guard let stream = system_fdopendir(descriptor.rawValue) else {
        defer { try? descriptor.close() }
        throw Errno.current
      }
      defer { _ = system_closedir(stream) }
      func next() -> UnsafeMutablePointer<system_dirent>? { system_readdir(stream) }
      #else
      guard let stream = directory.withPlatformString({ opendir($0) }) else {
        throw Errno(rawValue: errno)
      }
      defer { closedir(stream) }
      func next() -> UnsafeMutablePointer<dirent>? { readdir(stream) }
      #endif
      var seen: [String: FileType] = [:]
      while let entry = next() {
        let name = withUnsafeBytes(of: entry.pointee.d_name) { bytes in
          String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        guard name != ".", name != ".." else { continue }
        guard let type = FileType(directoryEntryType: entry.pointee.d_type) else { continue }
        seen[name] = type
        #expect(type.directoryEntryType == entry.pointee.d_type)
      }
      // APFS and the usual Linux file systems report every entry's type.
      #if os(WASI)
      #expect(seen.keys.sorted() == ["directory", "file", "link"])
      #else
      #expect(seen.keys.sorted() == ["directory", "fifo", "file", "link"])
      #endif
      for (name, type) in seen {
        let status = try directory.appending(name).stat(followTargetSymlink: false)
        #expect(status.type == type, "\(name)")
      }
    }
  }

  #if !os(WASI) // WASI has no CInterop.DirectoryEntry: its d_name is a flexible array
  /// CInterop.DirectoryEntry's accessors read a C entry as DirectoryStream
  /// does, the dot entries included.
  @available(System 199, *)
  @Test func cEntryAccessors() throws {
    try withTemporaryFilePath(basename: "cEntryAccessors") { directory in
      try FileDescriptor.open(
        directory.appending("file"), .writeOnly, options: .create, permissions: .ownerReadWrite
      ).close()
      try directory.appending("directory").makeDirectory(permissions: .ownerReadWriteExecute)

      guard let stream = directory.withPlatformString({ opendir($0) }) else {
        throw Errno(rawValue: errno)
      }
      defer { closedir(stream) }
      var seen: [String: (FileType?, Inode)] = [:]
      while let raw = readdir(stream) {
        let entry: CInterop.DirectoryEntry = raw.pointee
        let name = try #require(entry.fileName)
        seen[name.string] = (entry.fileType, entry.inode)
      }
      #expect(seen.keys.sorted() == [".", "..", "directory", "file"])
      for name in ["directory", "file", "."] {
        let status = try directory.appending(name).stat(followTargetSymlink: false)
        #expect(seen[name]?.0 == status.type, "\(name)")
        #expect(seen[name]?.1 == status.inode, "\(name)")
      }
      // A zero entry has no name and no type.
      #expect(CInterop.DirectoryEntry().fileName == nil)
      #expect(CInterop.DirectoryEntry().fileType == nil)
    }
  }
  #endif
}

#endif // !os(Windows)
