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

// Win32.handlesReferToSameObject(_:_:), CompareObjectHandles, on handles
// the test opens in its own temporary directory, and on the calling
// thread's.
@available(System 199, *)
final class Win32HandleComparisonTests: XCTestCase {
  func testDuplicatesReferToTheSameObject() throws {
    try withTemporaryFilePath(basename: "testDuplicatesReferToTheSameObject") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      let duplicate = try file.duplicate()
      XCTAssertTrue(Win32.handlesReferToSameObject(file.unsafeRawHandle, duplicate.unsafeRawHandle))
      // A second open is a second file object.
      let other = try Win32.FileHandle.open(
        path, access: .genericRead, shareMode: [.read, .write, .delete])
      XCTAssertFalse(Win32.handlesReferToSameObject(file.unsafeRawHandle, other.unsafeRawHandle))
      try other.close()
      try duplicate.close()
      try file.close()
    }
  }

  func testTheCallingThreadsPseudoHandle() throws {
    var real: HANDLE? = nil
    let duplicated = DuplicateHandle(
      GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(), &real, 0, false,
      DWORD(DUPLICATE_SAME_ACCESS))
    XCTAssertTrue(duplicated)
    let thread = try XCTUnwrap(real)
    defer { CloseHandle(thread) }
    XCTAssertTrue(Win32.handlesReferToSameObject(thread, GetCurrentThread()))
  }
}

#endif // os(Windows)
