/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && ENABLE_MOCKING

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
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
final class EntropyMockTests: XCTestCase {
  func testCallsAreAtMost256Bytes() throws {
    try MockingDriver.withMockingEnabled { mocking in
      _ = try Entropy.bytes(count: 600)
      _ = try Entropy.bytes(count: 0)
      var lengths: [Int] = []
      while let entry = mocking.trace.dequeue() {
        XCTAssertEqual(entry.name, "getentropy")
        lengths.append(entry.arguments[0] as! Int)
      }
      XCTAssertEqual(lengths, [256, 256, 88])

      // An error stops the fill, and isn't retried.
      mocking.forceErrno = .counted(errno: EIO, count: 1)
      XCTAssertThrowsError(try Entropy.bytes(count: 300)) {
        XCTAssertEqual($0 as? Errno, .ioError)
      }
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, [256])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
}

#endif // !os(Windows) && !os(WASI) && ENABLE_MOCKING
