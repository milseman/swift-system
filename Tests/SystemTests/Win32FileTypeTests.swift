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

// SYS-0012: Win32.FileType.
@available(System 199, *)
final class Win32FileTypeTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(Win32.FileType.disk.rawValue, DWORD(WinSDK.FILE_TYPE_DISK))
    XCTAssertEqual(Win32.FileType.character.rawValue, DWORD(WinSDK.FILE_TYPE_CHAR))
    XCTAssertEqual(Win32.FileType.pipe.rawValue, DWORD(WinSDK.FILE_TYPE_PIPE))
    XCTAssertEqual(Win32.FileType.unknown.rawValue, DWORD(WinSDK.FILE_TYPE_UNKNOWN))
    XCTAssertEqual(Win32.FileType(DWORD(WinSDK.FILE_TYPE_CHAR)), .character)
  }

  func testDiskFile() throws {
    try withTemporaryFilePath(basename: "testDiskFile") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      let type = try file.fileType()
      XCTAssertEqual(type, .disk)
      try file.close()

      // No access rights are needed.
      let metadata = try Win32.FileHandle.open(path, access: [])
      let metadataType = try metadata.fileType()
      XCTAssertEqual(metadataType, .disk)
      try metadata.close()
    }
  }

  func testCharacterDevice() throws {
    let null = try Win32.FileHandle.open("NUL", access: .genericWrite)
    let type = try null.fileType()
    XCTAssertEqual(type, .character)
    try null.close()
  }

  func testPipe() throws {
    let pipe = try Win32TestPipe()
    let readType = try pipe.readEnd.fileType()
    XCTAssertEqual(readType, .pipe)
    let writeType = try pipe.writeEnd.fileType()
    XCTAssertEqual(writeType, .pipe)
  }

  func testConsole() throws {
    guard let console = try? Win32.FileHandle.open("CONOUT$", access: .genericWrite) else {
      throw XCTSkip("This process has no console.")
    }
    let type = try console.fileType()
    XCTAssertEqual(type, .character)
    try console.close()
  }

  func testUnclassifiedDevice() throws {
    // The mount manager is a usable device that Windows doesn't classify,
    // which GetFileType reports with no error.
    guard let manager = try? Win32.FileHandle.open("\\\\.\\MountPointManager", access: [])
    else {
      throw XCTSkip("The mount manager can't be opened here.")
    }
    let type = try manager.fileType()
    XCTAssertEqual(type, .unknown)
    try manager.close()
  }
}

#endif // os(Windows)
