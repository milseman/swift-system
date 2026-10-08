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

// Win32.NTStatus. The SDK's status codes are in ntstatus.h, which
// <windows.h> doesn't include, so they're checked against its values.
@available(System 199, *)
final class Win32NTStatusTests: XCTestCase {
  func testSuccess() {
    XCTAssertEqual(Win32.NTStatus.success.rawValue, 0)
    XCTAssertTrue(Win32.NTStatus.success.isSuccess)
    XCTAssertFalse(Win32.NTStatus.success.isError)
  }

  func testSeverities() {
    // STATUS_ACCESS_VIOLATION, an error.
    let violation = Win32.NTStatus(NTSTATUS(bitPattern: 0xC000_0005))
    XCTAssertFalse(violation.isSuccess)
    XCTAssertTrue(violation.isError)
    // STATUS_BUFFER_OVERFLOW, a warning: neither a success nor an error.
    let overflow = Win32.NTStatus(NTSTATUS(bitPattern: 0x8000_0005))
    XCTAssertFalse(overflow.isSuccess)
    XCTAssertFalse(overflow.isError)
    // STATUS_PENDING, a success.
    let pending = Win32.NTStatus(NTSTATUS(bitPattern: 0x0000_0103))
    XCTAssertTrue(pending.isSuccess)
    XCTAssertFalse(pending.isError)
    // An informational status is a success too.
    let information = Win32.NTStatus(NTSTATUS(bitPattern: 0x4000_0000))
    XCTAssertTrue(information.isSuccess)
    XCTAssertFalse(information.isError)
  }

  func testDescriptions() {
    let violation = Win32.NTStatus(rawValue: NTSTATUS(bitPattern: 0xC000_0005))
    XCTAssertEqual(violation.debugDescription, "0xC0000005")
    // ntdll's message table has a message for it, localized.
    let message = violation.description
    XCTAssertFalse(message.isEmpty)
    XCTAssertFalse(message.hasPrefix("Unknown status"), message)
    XCTAssertFalse(message.last!.isWhitespace, "trailing whitespace: \(message.debugDescription)")
    // A customer code (bit 29) has none.
    let customer = Win32.NTStatus(rawValue: NTSTATUS(bitPattern: 0xE000_1234))
    XCTAssertEqual(customer.description, "Unknown status 0xE0001234")
  }

  func testThrowing() {
    do throws(Win32.NTStatus) {
      throw Win32.NTStatus(NTSTATUS(bitPattern: 0xC000_0022))
    } catch {
      XCTAssertEqual(UInt32(bitPattern: error.rawValue), 0xC000_0022)
    }
  }
}

#endif // os(Windows)
