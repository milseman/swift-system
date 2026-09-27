/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class AttributeListTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() {
    let path: FilePath = "a path"
    let fd = FileDescriptor(rawValue: 42)
    let returned = UInt32(ATTR_CMN_RETURNED_ATTRS)
    let common = returned | UInt32(ATTR_CMN_FULLPATH) | UInt32(ATTR_CMN_OBJTYPE)
    let groups: [UInt32] = [common, 0, 0, UInt32(ATTR_FILE_DATALENGTH), 0]
    // Room for the header, the values, and a path.
    let size = 64 + 8 + 4 + 8 + Int(MAXPATHLEN)
    let options = UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_REPORT_FULLSIZE)
    let request: [FilePath.Attribute] = [.fullPath, .objectType, .fileDataLength]

    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "getattrlist", .interruptable, "a path", groups, size, options) {
        retryOnInterrupt in
        _ = try path.attributes(request, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "getattrlist", .interruptable, "a path", groups, size,
        options | UInt32(FSOPT_NOFOLLOW)
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.attributes($0, request, options: .noFollow, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(
        name: "getattrlistat", .interruptable, 42, "a path", groups, size, UInt(options)
      ) { retryOnInterrupt in
        _ = try path.attributes(relativeTo: fd, request, retryOnInterrupt: retryOnInterrupt)
      },

      MockTestCase(
        name: "getattrlistat", .interruptable, 42, "a path", groups, size, UInt(options)
      ) { retryOnInterrupt in
        _ = try "a path".withCString {
          try FilePath.attributes($0, relativeTo: fd, request, retryOnInterrupt: retryOnInterrupt)
        }
      },

      MockTestCase(name: "fgetattrlist", .interruptable, 42, groups, size, options) {
        retryOnInterrupt in
        _ = try fd.attributes(request, retryOnInterrupt: retryOnInterrupt)
      },

      // A volume attribute brings ATTR_VOL_INFO.
      MockTestCase(
        name: "fgetattrlist", .interruptable, 42,
        [returned, UInt32(ATTR_VOL_CAPABILITIES) | UInt32(ATTR_VOL_INFO), 0, 0, 0],
        64 + 32, options
      ) { retryOnInterrupt in
        _ = try fd.attributes([.volumeCapabilities], retryOnInterrupt: retryOnInterrupt)
      },

      // Reading entries always reads each one's name, and any error.
      MockTestCase(
        name: "getattrlistbulk", .interruptable, 42,
        [returned | UInt32(ATTR_CMN_NAME) | UInt32(ATTR_CMN_ERROR) | UInt32(ATTR_CMN_OBJTYPE),
         0, 0, 0, 0],
        4096, UInt64(FSOPT_ATTR_CMN_EXTENDED)
      ) { retryOnInterrupt in
        _ = try fd.readEntryAttributes(
          [.objectType], capacity: 4096, retryOnInterrupt: retryOnInterrupt)
      },
    ]
    for test in syscallTestCases { test.runAllTests() }
  }
  #endif // ENABLE_MOCKING

  func testCommonAttributes() throws {
    try withTemporaryFilePath(basename: "testCommonAttributes") { path in
      let file = path.appending("file")
      try write(Array(repeating: 1, count: 5000), to: file)
      let status = try file.stat()
      let attributes = try file.attributes([
        .name, .fullPath, .objectType, .deviceID, .owner, .group, .accessMask, .flags,
        .fileID, .parentID, .creationTime, .modificationTime, .dataProtectionClass,
        .fileDataLength, .fileAllocatedSize, .fileLinkCount,
      ])
      XCTAssertEqual(attributes.name, "file")
      XCTAssertEqual(attributes.objectType, .regular)
      XCTAssertEqual(attributes.deviceID, status.deviceID)
      XCTAssertEqual(attributes.owner, status.userID)
      XCTAssertEqual(attributes.group, status.groupID)
      XCTAssertEqual(attributes.permissions, status.permissions)
      XCTAssertEqual(attributes.flags, status.flags)
      XCTAssertEqual(attributes.fileID, status.inode)
      XCTAssertEqual(attributes.parentID, try path.stat().inode)
      XCTAssertEqual(attributes.fileDataLength, 5000)
      XCTAssertGreaterThanOrEqual(attributes.fileAllocatedSize ?? 0, 5000)
      XCTAssertEqual(attributes.fileLinkCount, 1)

      // The full path has symbolic links resolved, such as /var's.
      let fullPath = try XCTUnwrap(attributes.fullPath)
      XCTAssertTrue(fullPath.isAbsolute)
      XCTAssertEqual(try fullPath.stat().inode, status.inode)
      XCTAssertEqual(fullPath.lastComponent, "file")

      let modified = try XCTUnwrap(attributes.value(of: .modificationTime, as: timespec.self))
      XCTAssertEqual(modified.tv_sec, status.st_mtim.tv_sec)
      XCTAssertEqual(modified.tv_nsec, status.st_mtim.tv_nsec)
      let created = try XCTUnwrap(attributes.value(of: .creationTime, as: timespec.self))
      XCTAssertEqual(created.tv_sec, status.st_birthtim.tv_sec)

      // The name's data includes its null terminator.
      XCTAssertEqual(attributes.bytes(of: .name), Array("file\0".utf8))
      XCTAssertEqual(attributes.string(of: .name), "file")
      XCTAssertEqual(attributes.bytes(of: .fileLinkCount), [1, 0, 0, 0])
      XCTAssertTrue(attributes.contains(.fullPath))
      XCTAssertFalse(attributes.contains(.cloneID))
      XCTAssertNil(attributes.cloneID)
      XCTAssertNil(attributes.error)
    }
  }

  func testObjectsAndOptions() throws {
    try withTemporaryFilePath(basename: "testObjectsAndOptions") { path in
      try write([1, 2, 3], to: path.appending("target"))
      try path.appending("link").makeSymbolicLink(to: "target")
      try path.appending("directory").makeDirectory(permissions: .ownerReadWriteExecute)
      for name in ["a", "b", "c"] { try write([], to: path.appending("directory").appending(name)) }

      XCTAssertEqual(try path.appending("link").attributes([.objectType]).objectType, .regular)
      XCTAssertEqual(
        try path.appending("link").attributes([.objectType, .name], options: .noFollow).objectType,
        .symbolicLink)
      let directory = try path.appending("directory").attributes([.objectType, .directoryEntryCount])
      XCTAssertEqual(directory.objectType, .directory)
      XCTAssertEqual(directory.directoryEntryCount, 3)

      // A file has no directory attributes, which are missing.
      let file = try path.appending("target").attributes([.name, .directoryEntryCount, .fileDataLength])
      XCTAssertNil(file.directoryEntryCount)
      XCTAssertEqual(file.fileDataLength, 3)
      XCTAssertEqual(file.name, "target")

      // Relative to a directory, from a descriptor, and from a C string.
      let dir = try FileDescriptor.open(path.appending("directory"), .readOnly, options: .directory)
      try dir.closeAfter {
        XCTAssertEqual(try FilePath("a").attributes(relativeTo: dir, [.name]).name, "a")
        XCTAssertEqual(try dir.attributes([.name]).name, "directory")
        XCTAssertEqual(
          try "b".withCString { try FilePath.attributes($0, relativeTo: dir, [.name]).name }, "b")
      }
      XCTAssertEqual(
        try path.appending("target").withCString { try FilePath.attributes($0, [.name]).name },
        "target")

      XCTAssertThrowsError(try path.appending("missing").attributes([.name])) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      // Volume attributes can't be read with file attributes.
      XCTAssertThrowsError(
        try path.appending("target").attributes([.volumeCapabilities, .fileDataLength])
      ) {
        XCTAssertEqual($0 as? Errno, .invalidArgument)
      }
    }
  }

  func testVolumeAttributes() throws {
    try withTemporaryFilePath(basename: "testVolumeAttributes") { path in
      let volume = try path.attributes([
        .volumeCapabilities, .volumeFileSystemTypeName, .volumeName, .volumeMountPoint,
        .volumeAvailableSpace, .volumeUsedSpace, .volumeIOBlockSize,
      ])
      let capabilities = try XCTUnwrap(volume.volumeCapabilities)
      XCTAssertTrue(capabilities.format.contains(.symbolicLinks))
      XCTAssertTrue(capabilities.validFormat.contains(.symbolicLinks))
      XCTAssertTrue(capabilities.validInterfaces.contains(.clone))
      XCTAssertFalse(try XCTUnwrap(volume.volumeName).isEmpty)
      let mountPoint = try XCTUnwrap(volume.volumeMountPoint)
      XCTAssertTrue(mountPoint.isAbsolute)
      XCTAssertGreaterThan(volume.value(of: .volumeAvailableSpace, as: Int64.self) ?? 0, 0)
      XCTAssertGreaterThan(volume.value(of: .volumeIOBlockSize, as: UInt32.self) ?? 0, 0)

      // The values after ATTR_VOL_SPACEUSED, which isn't in bit order,
      // are where the order that getattrlist(2) documents puts them.
      var statistics = statfs()
      XCTAssertEqual(statfs(mountPoint.string, &statistics), 0)
      XCTAssertEqual(
        volume.value(of: .volumeAvailableSpace, as: Int64.self),
        Int64(statistics.f_bavail) * Int64(statistics.f_bsize))
      XCTAssertEqual(volume.value(of: .volumeIOBlockSize, as: UInt32.self), UInt32(statistics.f_iosize))
      let typeName = withUnsafeBytes(of: statistics.f_fstypename) {
        String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
      }
      XCTAssertEqual(volume.volumeFileSystemTypeName, typeName)

      if typeName == "apfs" {
        XCTAssertTrue(capabilities.interfaces.contains(.clone))
        XCTAssertTrue(capabilities.format.contains(.sparseFiles))
        XCTAssertNotNil(volume.value(of: .volumeUsedSpace, as: Int64.self))
      }
      XCTAssertEqual("\(FilePath.VolumeCapabilities.Interfaces([.clone, .renameSwap]))", "[.clone, .renameSwap]")
    }
  }

  func testExtendedAttributes() throws {
    try withTemporaryFilePath(basename: "testExtendedAttributes") { path in
      try write(Array(repeating: 7, count: 100_000), to: path.appending("source"))
      let source = try path.appending("source").attributes([.cloneID, .privateSize, .linkID])
      XCTAssertNotNil(source.value(of: .linkID, as: UInt64.self))
      guard let cloneID = source.cloneID else {
        throw XCTSkip("The temporary directory's file system doesn't have clone IDs")
      }
      do {
        try path.appending("source").clone(to: path.appending("clone"))
      } catch Errno.notSupported {
        throw XCTSkip("The temporary directory's file system can't clone")
      }
      let clone = try path.appending("clone").attributes([.cloneID, .privateSize])
      XCTAssertEqual(clone.cloneID, cloneID)
      // The clone shares all of its data.
      XCTAssertEqual(clone.privateSize, 0)
    }
  }

  func testReadEntryAttributes() throws {
    try withTemporaryFilePath(basename: "testReadEntryAttributes") { path in
      var names: Set<String> = []
      for index in 0..<200 {
        let name = "file-\(index)"
        names.insert(name)
        try write(Array(repeating: 0, count: index), to: path.appending(name))
      }
      try path.appending("subdirectory").makeDirectory(permissions: .ownerReadWriteExecute)
      names.insert("subdirectory")

      let dir = try FileDescriptor.open(path, .readOnly, options: .directory)
      try dir.closeAfter {
        // A small buffer takes several calls.
        var entries: [FilePath.Attributes] = []
        var calls = 0
        while true {
          let batch = try dir.readEntryAttributes(
            [.objectType, .fileDataLength], capacity: 2048)
          calls += 1
          if batch.isEmpty { break }
          entries += batch
        }
        XCTAssertGreaterThan(calls, 2)
        XCTAssertEqual(Set(entries.compactMap(\.name)), names)
        XCTAssertEqual(entries.count, names.count)
        XCTAssertTrue(entries.allSatisfy { $0.error == nil })
        for entry in entries {
          if entry.name == "subdirectory" {
            XCTAssertEqual(entry.objectType, .directory)
            XCTAssertNil(entry.fileDataLength)
          } else {
            XCTAssertEqual(entry.objectType, .regular)
            XCTAssertEqual(
              entry.fileDataLength, Int64(entry.name!.dropFirst("file-".count))!)
          }
        }
        // Once read, the directory has no more entries until it's rewound.
        XCTAssertEqual(try dir.readEntryAttributes([.name]).count, 0)
        _ = try dir.seek(offset: 0, from: .start)
        XCTAssertFalse(try dir.readEntryAttributes([.name]).isEmpty)
      }

      // A descriptor that isn't a directory's can't be read this way.
      let file = try FileDescriptor.open(path.appending("file-1"), .readOnly)
      try file.closeAfter {
        XCTAssertThrowsError(try file.readEntryAttributes([.name])) {
          XCTAssertEqual($0 as? Errno, .notDirectory)
        }
      }
    }
  }

  private func write(_ bytes: [UInt8], to path: FilePath) throws {
    let fd = try FileDescriptor.open(
      path, .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    try fd.closeAfter { _ = try fd.writeAll(bytes) }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
