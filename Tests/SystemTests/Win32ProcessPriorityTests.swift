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

// Win32.PriorityClass, and the test process's own priority class, which
// the one test that changes it restores. XCTest runs one test at a time.
@available(System 199, *)
final class Win32ProcessPriorityTests: XCTestCase {
  func testClassesMatchTheSDK() {
    let classes: [(Win32.PriorityClass, DWORD)] = [
      (.idle, DWORD(WinSDK.IDLE_PRIORITY_CLASS)),
      (.belowNormal, DWORD(WinSDK.BELOW_NORMAL_PRIORITY_CLASS)),
      (.normal, DWORD(WinSDK.NORMAL_PRIORITY_CLASS)),
      (.aboveNormal, DWORD(WinSDK.ABOVE_NORMAL_PRIORITY_CLASS)),
      (.high, DWORD(WinSDK.HIGH_PRIORITY_CLASS)),
      (.realtime, DWORD(WinSDK.REALTIME_PRIORITY_CLASS)),
    ]
    for (priorityClass, value) in classes {
      XCTAssertEqual(priorityClass.rawValue, value)
    }
  }

  func testSettingTheProcesssClass() throws {
    let process = Win32.ProcessHandle.current
    let original = try process.priorityClass()
    defer { try? process.setPriorityClass(original) }
    try process.setPriorityClass(.belowNormal)
    XCTAssertEqual(try process.priorityClass(), .belowNormal)
    try process.setPriorityClass(original)
    XCTAssertEqual(try process.priorityClass(), original)
  }
}

#endif // os(Windows)
