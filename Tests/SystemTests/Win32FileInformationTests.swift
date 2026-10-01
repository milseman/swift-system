/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import XCTest

#if os(Windows)

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

import WinSDK

// Querying and setting file information, through handles and by path.
@available(System 199, *)
final class Win32FileInformationTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let attributes: [(Win32.FileAttributes, DWORD)] = [
      (.directory, DWORD(WinSDK.FILE_ATTRIBUTE_DIRECTORY)),
      (.device, DWORD(WinSDK.FILE_ATTRIBUTE_DEVICE)),
      (.sparseFile, DWORD(WinSDK.FILE_ATTRIBUTE_SPARSE_FILE)),
      (.reparsePoint, DWORD(WinSDK.FILE_ATTRIBUTE_REPARSE_POINT)),
      (.compressed, DWORD(WinSDK.FILE_ATTRIBUTE_COMPRESSED)),
      (.notContentIndexed, DWORD(WinSDK.FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)),
      (.integrityStream, DWORD(WinSDK.FILE_ATTRIBUTE_INTEGRITY_STREAM)),
      (.noScrubData, DWORD(WinSDK.FILE_ATTRIBUTE_NO_SCRUB_DATA)),
      (.recallOnOpen, DWORD(WinSDK.FILE_ATTRIBUTE_RECALL_ON_OPEN)),
      (.pinned, DWORD(WinSDK.FILE_ATTRIBUTE_PINNED)),
      (.unpinned, DWORD(WinSDK.FILE_ATTRIBUTE_UNPINNED)),
      (.recallOnDataAccess, DWORD(WinSDK.FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS)),
    ]
    for (attribute, value) in attributes {
      XCTAssertEqual(attribute.rawValue, value, "\(attribute)")
    }
    let tags: [(Win32.ReparseTag, DWORD)] = [
      (.symbolicLink, DWORD(WinSDK.IO_REPARSE_TAG_SYMLINK)),
      (.mountPoint, DWORD(WinSDK.IO_REPARSE_TAG_MOUNT_POINT)),
      (.appExecutionLink, DWORD(WinSDK.IO_REPARSE_TAG_APPEXECLINK)),
      (.unixDomainSocket, DWORD(WinSDK.IO_REPARSE_TAG_AF_UNIX)),
    ]
    for (tag, value) in tags {
      XCTAssertEqual(tag.rawValue, value, "\(tag)")
    }
    XCTAssertTrue(Win32.ReparseTag.symbolicLink.isMicrosoft)
    XCTAssertTrue(Win32.ReparseTag.symbolicLink.isNameSurrogate)
    XCTAssertTrue(Win32.ReparseTag.mountPoint.isNameSurrogate)
    XCTAssertFalse(Win32.ReparseTag.unixDomainSocket.isNameSurrogate)
  }

  func testFileInformation() throws {
    try withTemporaryFilePath(basename: "testFileInformation") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      try withRawSpan(Array("hello".utf8)) { try file.write($0) }

      let information = try file.information()
      XCTAssertEqual(information.size, 5)
      XCTAssertEqual(information.linkCount, 1)
      XCTAssertFalse(information.attributes.contains(.directory))
      XCTAssertGreaterThan(information.creationTime.durationSinceUnixEpoch, .seconds(1_767_225_600))
      XCTAssertGreaterThanOrEqual(information.lastWriteTime, information.creationTime)

      let basic = try file.basicInformation()
      XCTAssertEqual(basic.attributes, information.attributes)
      XCTAssertEqual(basic.creationTime, information.creationTime)
      let standard = try file.standardInformation()
      XCTAssertEqual(standard.size, 5)
      XCTAssertEqual(standard.linkCount, 1)
      XCTAssertFalse(standard.isDirectory)
      XCTAssertFalse(standard.isDeletePending)
      let tag = try file.attributeTagInformation()
      XCTAssertNil(tag.reparseTag)

      // Two opens of one file have one ID; another file has another.
      let reopened = try Win32.FileHandle.open(path, access: [])
      let id = try file.fileID()
      let reopenedID = try reopened.fileID()
      XCTAssertEqual(id, reopenedID)
      let reopenedInformation = try reopened.information()
      XCTAssertEqual(reopenedInformation.fileIndex, information.fileIndex)
      XCTAssertEqual(reopenedInformation.volumeSerialNumber, information.volumeSerialNumber)
      let other = try Win32.FileHandle.open(
        directory.appending("other.txt"), access: .genericWrite, disposition: .createNew)
      let otherID = try other.fileID()
      XCTAssertNotEqual(otherID, id)
      try other.close()
      try reopened.close()
      try file.close()
    }
  }

  func testDirectoryInformation() throws {
    try withTemporaryFilePath(basename: "testDirectoryInformation") { directory in
      let handle = try Win32.DirectoryHandle.open(directory)
      let information = try handle.information()
      XCTAssertTrue(information.attributes.contains(.directory))
      let basic = try handle.basicInformation()
      XCTAssertTrue(basic.attributes.contains(.directory))
      let tag = try handle.attributeTagInformation()
      XCTAssertNil(tag.reparseTag)
      _ = try handle.fileID()
      try handle.close()
    }
  }

  func testSettingTimesAndAttributes() throws {
    try withTemporaryFilePath(basename: "testSettingTimesAndAttributes") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      let y2k = Win32.FileTime(rawValue: 125_911_584_000_000_000)
      let before = try file.basicInformation()
      try file.setTimes(lastWrite: y2k)
      let after = try file.basicInformation()
      XCTAssertEqual(after.lastWriteTime, y2k)
      // The times not given are unchanged.
      XCTAssertEqual(after.creationTime, before.creationTime)

      try file.setAttributes([.hidden, .readOnly])
      let attributes = try file.information().attributes
      XCTAssertTrue(attributes.contains([.hidden, .readOnly]))
      // An empty set clears them.
      try file.setAttributes([])
      let cleared = try file.information().attributes
      XCTAssertFalse(cleared.contains(.hidden))
      XCTAssertFalse(cleared.contains(.readOnly))
      try file.close()
    }
  }

  func testQueriesByPath() throws {
    try withTemporaryFilePath(basename: "testQueriesByPath") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      try withRawSpan(Array("abc".utf8)) { try file.write($0) }
      try file.close()

      let attributes = try Win32.fileAttributes(of: path)
      XCTAssertFalse(attributes.contains(.directory))
      let directoryAttributes = try Win32.fileAttributes(of: directory)
      XCTAssertTrue(directoryAttributes.contains(.directory))
      let data = try Win32.fileAttributeData(of: path)
      XCTAssertEqual(data.size, 3)
      XCTAssertEqual(data.attributes, attributes)

      try Win32.setFileAttributes(.hidden, of: path)
      let hidden = try Win32.fileAttributes(of: path)
      XCTAssertTrue(hidden.contains(.hidden))
      try Win32.setFileAttributes([], of: path)
      let cleared = try Win32.fileAttributes(of: path)
      XCTAssertFalse(cleared.contains(.hidden))

      XCTAssertThrowsWin32Error(.fileNotFound) {
        try Win32.fileAttributes(of: directory.appending("missing.txt"))
      }
      XCTAssertThrowsWin32Error(.pathNotFound) {
        try Win32.fileAttributeData(of: directory.appending("missing\\file.txt"))
      }
    }
  }

  func testFileIDBytes() {
    var info = FILE_ID_INFO()
    info.VolumeSerialNumber = 0x1234
    withUnsafeMutableBytes(of: &info.FileId.Identifier) { bytes in
      for index in bytes.indices { bytes[index] = UInt8(index + 1) }
    }
    let id = Win32.FileID(info)
    XCTAssertEqual(id.volumeSerialNumber, 0x1234)
    // Little-endian: the first byte is the lowest.
    XCTAssertEqual(id.identifier & 0xFF, 1)
    XCTAssertEqual(id.identifier >> 120, 16)
  }
}

#endif // os(Windows)
