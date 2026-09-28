/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && ENABLE_MOCKING

import XCTest

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
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
final class ProcessExitMockTests: XCTestCase {
  func testAddExitHandlerCallsAtexit() throws {
    try MockingDriver.withMockingEnabled { mocking in
      try ProcessID.addExitHandler {}
      XCTAssertEqual(mocking.trace.dequeue()?.name, "atexit")
      XCTAssertNil(mocking.trace.dequeue())
    }
  }

  /// atexit reports only that it failed, and running out of memory is the
  /// only way it can.
  func testAFailedRegistrationIsNoMemory() throws {
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EINVAL)
      XCTAssertThrowsError(try ProcessID.addExitHandler {}) { error in
        XCTAssertEqual(error as? Errno, .noMemory)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.name, "atexit")
      XCTAssertNil(mocking.trace.dequeue())
    }
  }
}

#endif // !os(Windows) && ENABLE_MOCKING
