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

// SYS-0016: the final path name of a handle.
@available(System 199, *)
final class Win32FinalPathTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(Win32.VolumeNameFormat.dos.rawValue, DWORD(WinSDK.VOLUME_NAME_DOS))
    XCTAssertEqual(Win32.VolumeNameFormat.guid.rawValue, DWORD(WinSDK.VOLUME_NAME_GUID))
    XCTAssertEqual(Win32.VolumeNameFormat.nt.rawValue, DWORD(WinSDK.VOLUME_NAME_NT))
    XCTAssertEqual(
      Win32.VolumeNameFormat.volumeRelative.rawValue, DWORD(WinSDK.VOLUME_NAME_NONE))
    XCTAssertEqual(_FILE_NAME_NORMALIZED, DWORD(WinSDK.FILE_NAME_NORMALIZED))
    XCTAssertEqual(_FILE_NAME_OPENED, DWORD(WinSDK.FILE_NAME_OPENED))
  }

  func testVolumeNameFormats() throws {
    try withTemporaryFilePath(basename: "testVolumeNameFormats") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: .genericWrite, disposition: .createNew)
      let dos = try file.finalPath().string
      XCTAssertTrue(dos.hasPrefix("\\\\?\\"), dos)
      XCTAssertTrue(dos.hasSuffix("\\file.txt"), dos)
      let nt = try file.finalPath(volumeName: .nt).string
      XCTAssertTrue(nt.hasPrefix("\\Device\\"), nt)
      let relative = try file.finalPath(volumeName: .volumeRelative).string
      XCTAssertTrue(relative.hasPrefix("\\") && !relative.hasPrefix("\\\\"), relative)
      XCTAssertTrue(relative.hasSuffix("\\file.txt"), relative)
      // The temporary directory is on a local volume, which has a GUID.
      let guid = try file.finalPath(volumeName: .guid).string
      XCTAssertTrue(guid.hasPrefix("\\\\?\\Volume{"), guid)
      try file.close()
    }
  }

  func testNormalizedAndOpenedNames() throws {
    try withTemporaryFilePath(basename: "testNormalizedNames") { directory in
      try Win32.FileHandle.open(
        directory.appending("MixedCase.txt"), access: .genericWrite, disposition: .createNew
      ).close()
      let file = try Win32.FileHandle.open(directory.appending("mixedcase.txt"), access: [])
      let normalized = try file.finalPath().string
      XCTAssertTrue(normalized.hasSuffix("\\MixedCase.txt"), normalized)
      let opened = try file.finalPath(normalized: false).string
      XCTAssertTrue(opened.hasSuffix("\\mixedcase.txt"), opened)
      try file.close()
    }
  }

  func testRenamedWhileOpen() throws {
    try withTemporaryFilePath(basename: "testRenamedWhileOpen") { directory in
      let before = directory.appending("before.txt")
      let after = directory.appending("after.txt")
      let file = try Win32.FileHandle.open(before, access: .genericWrite, disposition: .createNew)
      // The default share mode includes FILE_SHARE_DELETE, which a rename needs.
      let renamed = before.withPlatformString { from in
        after.withPlatformString { to in MoveFileExW(from, to, 0) }
      }
      XCTAssertTrue(renamed)
      let path = try file.finalPath().string
      XCTAssertTrue(path.hasSuffix("\\after.txt"), path)
      try file.close()
    }
  }

  func testDirectory() throws {
    try withTemporaryFilePath(basename: "testFinalPathDirectory") { directory in
      let subdirectory = directory.appending("subdirectory")
      let created = subdirectory.withPlatformString { CreateDirectoryW($0, nil) }
      XCTAssertTrue(created)
      let handle = try Win32.DirectoryHandle.open(subdirectory)
      let path = try handle.finalPath().string
      XCTAssertTrue(path.hasPrefix("\\\\?\\"), path)
      XCTAssertTrue(path.hasSuffix("\\subdirectory"), path)
      try handle.close()
    }
  }

  func testPathLongerThanMaxPath() throws {
    try withTemporaryFilePath(basename: "testFinalPathLong") { directory in
      var path = directory
      while path.string.utf16.count <= _win32MaxPath {
        path = path.appending(String(repeating: "d", count: 50))
        let created = ("\\\\?\\" + path.string).withCString(encodedAs: UTF16.self) {
          CreateDirectoryW($0, nil)
        }
        XCTAssertTrue(created)
      }
      let file = try Win32.FileHandle.open(
        path.appending("file.txt"), access: .genericWrite, disposition: .createNew)
      // The first buffer holds MAX_PATH + 1 characters, so this needs a retry.
      let finalPath = try file.finalPath().string
      XCTAssertGreaterThan(finalPath.utf16.count, _win32MaxPath + 1)
      XCTAssertTrue(finalPath.hasSuffix("\\file.txt"), finalPath)
      try file.close()
    }
  }

  func testHandlesWithNoPath() throws {
    let pipe = try Win32TestPipe()
    XCTAssertThrowsWin32Error(.badPathName) { try pipe.readEnd.finalPath() }
    let null = try Win32.FileHandle.open("NUL", access: .genericWrite)
    XCTAssertThrowsWin32Error(.invalidParameter) { try null.finalPath() }
    try null.close()
  }
}

#endif // os(Windows)
