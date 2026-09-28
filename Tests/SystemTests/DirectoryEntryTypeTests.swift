/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

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

@Suite("Directory entry types")
private struct DirectoryEntryTypeTests {
  @available(System 199, *)
  @Test func everyTypeConvertsBothWays() {
    var types: [(UInt8, FileType)] = [
      (UInt8(DT_REG), .regular),
      (UInt8(DT_DIR), .directory),
      (UInt8(DT_LNK), .symbolicLink),
      (UInt8(DT_FIFO), .fifo),
      (UInt8(DT_SOCK), .socket),
      (UInt8(DT_CHR), .characterSpecial),
      (UInt8(DT_BLK), .blockSpecial),
    ]
    #if SYSTEM_PACKAGE_DARWIN
    types.append((UInt8(DT_WHT), .whiteout))
    #endif
    for (entryType, fileType) in types {
      #expect(FileType(directoryEntryType: entryType) == fileType, "\(entryType)")
      #expect(fileType.directoryEntryType == entryType, "\(fileType)")
      // DTTOIF: the mode's type bits are the entry type shifted by 12.
      #expect(FileType(rawValue: CInterop.Mode(entryType) << 12) == fileType, "\(entryType)")
    }
    #expect(FileType(directoryEntryType: UInt8(DT_UNKNOWN)) == nil)
    #expect(FileType(directoryEntryType: 3) == nil)
    #expect(FileType(rawValue: 0).directoryEntryType == UInt8(DT_UNKNOWN))
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
      try directory.appending("fifo").makeFIFO(permissions: .ownerReadWrite)

      guard let stream = directory.withPlatformString({ opendir($0) }) else {
        throw Errno(rawValue: errno)
      }
      defer { closedir(stream) }
      var seen: [String: FileType] = [:]
      while let entry = readdir(stream) {
        let name = withUnsafeBytes(of: entry.pointee.d_name) { bytes in
          String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        guard name != ".", name != ".." else { continue }
        guard let type = FileType(directoryEntryType: entry.pointee.d_type) else { continue }
        seen[name] = type
        #expect(type.directoryEntryType == entry.pointee.d_type)
      }
      // APFS and the usual Linux file systems report every entry's type.
      #expect(seen.keys.sorted() == ["directory", "fifo", "file", "link"])
      for (name, type) in seen {
        let status = try directory.appending(name).stat(followTargetSymlink: false)
        #expect(status.type == type, "\(name)")
      }
    }
  }
}

#endif // !os(Windows) && !os(WASI)
