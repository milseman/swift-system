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

// A path longer than Windows' limit of 32,767 characters fails to open with
// an error from each path canonicalization: FileDescriptor's
// (`withCanonicalPathRepresentation`, which trapped before patch P2 in
// Prototype/Win32/REPORT.md) and the Win32 namespace's.
@available(System 199, *)
final class Win32OverlongPathTests: XCTestCase {
  private var overlongPath: FilePath {
    FilePath("C:\\" + String(repeating: "a\\", count: 20_000) + "file")
  }

  func testFileDescriptorOpenThrows() {
    XCTAssertThrowsError(try FileDescriptor.open(overlongPath, .readOnly)) { error in
      // Expected: ERROR_FILENAME_EXCED_RANGE, from GetFullPathNameW or
      // PathAllocCanonicalize, which the C runtime's table maps to ENOENT.
      // Only the type is checked, since Windows doesn't document which.
      XCTAssertTrue(error is Errno, "\(error)")
    }
  }

  func testWin32OpenThrows() {
    do throws(Win32.Error) {
      let file = try Win32.FileHandle.open(overlongPath, access: .genericRead)
      XCTFail("opened an overlong path")
      try file.close()
    } catch {
      XCTAssertNotEqual(error, .success, error.debugDescription)
    }
  }
}

#endif // os(Windows)
