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

/// Throws `result` if it's a failure, as code that calls a COM-style
/// function would.
@available(System 199, *)
private func check(_ result: Win32.HResult) throws(Win32.HResult) {
  guard result.isSuccess else { throw result }
}

// Win32.HResult. The SDK's failure codes don't import (see
// Win32HResult.swift), so they're checked against winerror.h's values, and
// those in FACILITY_WIN32 against the Win32 codes they carry.
@available(System 199, *)
final class Win32HResultTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    XCTAssertEqual(Win32.HResult.ok.rawValue, WinSDK.S_OK)
    XCTAssertEqual(Win32.HResult.false.rawValue, WinSDK.S_FALSE)
    let failures: [(Win32.HResult, UInt32)] = [
      (.notImplemented, 0x8000_4001),
      (.noInterface, 0x8000_4002),
      (.invalidPointer, 0x8000_4003),
      (.aborted, 0x8000_4004),
      (.unspecifiedFailure, 0x8000_4005),
      (.unexpectedFailure, 0x8000_FFFF),
      (.accessDenied, 0x8007_0005),
      (.invalidHandle, 0x8007_0006),
      (.outOfMemory, 0x8007_000E),
      (.invalidArgument, 0x8007_0057),
    ]
    for (result, value) in failures {
      XCTAssertEqual(UInt32(bitPattern: result.rawValue), value, result.debugDescription)
      XCTAssertTrue(result.isFailure, result.debugDescription)
    }
    XCTAssertEqual(Win32.HResult.accessDenied.win32Error, .accessDenied)
    XCTAssertEqual(Win32.HResult.invalidHandle.win32Error, .invalidHandle)
    XCTAssertEqual(Win32.HResult.invalidArgument.win32Error, .invalidParameter)
    XCTAssertEqual(
      Win32.HResult.outOfMemory.win32Error, Win32.Error(DWORD(WinSDK.ERROR_OUTOFMEMORY)))
  }

  func testParts() {
    let denied = Win32.HResult.accessDenied
    XCTAssertTrue(denied.isFailure)
    XCTAssertFalse(denied.isSuccess)
    XCTAssertEqual(DWORD(denied.facility), DWORD(WinSDK.FACILITY_WIN32))
    XCTAssertEqual(denied.code, 5)

    let failure = Win32.HResult.unspecifiedFailure
    XCTAssertEqual(DWORD(failure.facility), DWORD(WinSDK.FACILITY_NULL))
    XCTAssertEqual(failure.code, 0x4005)
    XCTAssertNil(failure.win32Error)

    // Both successes succeed, and carry no error.
    XCTAssertTrue(Win32.HResult.ok.isSuccess)
    XCTAssertTrue(Win32.HResult.false.isSuccess)
    XCTAssertNil(Win32.HResult.false.win32Error)
    XCTAssertEqual(Win32.HResult.false.code, 1)
  }

  func testFromWin32Errors() {
    XCTAssertEqual(Win32.HResult(win32Error: .accessDenied), .accessDenied)
    XCTAssertEqual(Win32.HResult(win32Error: .invalidParameter), .invalidArgument)
    XCTAssertEqual(Win32.HResult(win32Error: .success), .ok)
    let notFound = Win32.HResult(win32Error: .fileNotFound)
    XCTAssertEqual(UInt32(bitPattern: notFound.rawValue), 0x8007_0002)
    XCTAssertEqual(notFound.win32Error, .fileNotFound)
    // A code with bit 31 set is an HRESULT's bit pattern already.
    let synthesized = Win32.HResult(win32Error: .incompleteTransfer)
    XCTAssertEqual(UInt32(bitPattern: synthesized.rawValue), Win32.Error.incompleteTransfer.rawValue)
  }

  func testDescriptions() {
    XCTAssertEqual(Win32.HResult.accessDenied.debugDescription, "E_ACCESSDENIED (0x80070005)")
    XCTAssertEqual(Win32.HResult.ok.debugDescription, "S_OK (0x0)")
    XCTAssertEqual(
      Win32.HResult(win32Error: .fileNotFound).debugDescription,
      "HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) (0x80070002)")
    XCTAssertEqual(
      Win32.HResult(rawValue: HRESULT(bitPattern: 0x8004_1234)).debugDescription, "0x80041234")

    // The system's message for E_ACCESSDENIED is the Win32 code's.
    let message = Win32.HResult.accessDenied.description
    XCTAssertEqual(message, Win32.Error.accessDenied.description)
    XCTAssertFalse(message.isEmpty)
    let unknown = Win32.HResult(rawValue: HRESULT(bitPattern: 0xA004_1234)).description
    XCTAssertEqual(unknown, "Unknown error 0xA0041234")
  }

  func testTypedThrows() {
    do throws(Win32.HResult) {
      try check(.false)
      try check(.notImplemented)
      XCTFail("didn't throw")
    } catch {
      XCTAssertEqual(error, .notImplemented)
    }
  }

  func testWin32ErrorsFromHRESULTs() {
    // The conversion System's Win32 API applies to a failed HRESULT.
    XCTAssertEqual(_win32Error(fromHRESULT: Win32.HResult.accessDenied.rawValue), 5)
    XCTAssertEqual(
      _win32Error(fromHRESULT: Win32.HResult.unspecifiedFailure.rawValue), 0x8000_4005)
  }
}

#endif // os(Windows)
