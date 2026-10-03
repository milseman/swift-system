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

// SYS-0010: the Win32 namespace and Win32.Error.
@available(System 199, *)
final class Win32ErrorTests: XCTestCase {
  func testCodesMatchTheSDK() {
    let codes: [(Win32.Error, DWORD)] = [
      (.success, DWORD(WinSDK.ERROR_SUCCESS)),
      (.invalidFunction, DWORD(WinSDK.ERROR_INVALID_FUNCTION)),
      (.fileNotFound, DWORD(WinSDK.ERROR_FILE_NOT_FOUND)),
      (.pathNotFound, DWORD(WinSDK.ERROR_PATH_NOT_FOUND)),
      (.accessDenied, DWORD(WinSDK.ERROR_ACCESS_DENIED)),
      (.invalidHandle, DWORD(WinSDK.ERROR_INVALID_HANDLE)),
      (.notEnoughMemory, DWORD(WinSDK.ERROR_NOT_ENOUGH_MEMORY)),
      (.notSameDevice, DWORD(WinSDK.ERROR_NOT_SAME_DEVICE)),
      (.deviceNotReady, DWORD(WinSDK.ERROR_NOT_READY)),
      (.cyclicRedundancyCheck, DWORD(WinSDK.ERROR_CRC)),
      (.writeFault, DWORD(WinSDK.ERROR_WRITE_FAULT)),
      (.sharingViolation, DWORD(WinSDK.ERROR_SHARING_VIOLATION)),
      (.lockViolation, DWORD(WinSDK.ERROR_LOCK_VIOLATION)),
      (.notLocked, DWORD(WinSDK.ERROR_NOT_LOCKED)),
      (.negativeSeek, DWORD(WinSDK.ERROR_NEGATIVE_SEEK)),
      (.endOfFile, DWORD(WinSDK.ERROR_HANDLE_EOF)),
      (.brokenPipe, DWORD(WinSDK.ERROR_BROKEN_PIPE)),
      (.notSupported, DWORD(WinSDK.ERROR_NOT_SUPPORTED)),
      (.fileExists, DWORD(WinSDK.ERROR_FILE_EXISTS)),
      (.invalidParameter, DWORD(WinSDK.ERROR_INVALID_PARAMETER)),
      (.insufficientBuffer, DWORD(WinSDK.ERROR_INSUFFICIENT_BUFFER)),
      (.invalidName, DWORD(WinSDK.ERROR_INVALID_NAME)),
      (.moduleNotFound, DWORD(WinSDK.ERROR_MOD_NOT_FOUND)),
      (.procedureNotFound, DWORD(WinSDK.ERROR_PROC_NOT_FOUND)),
      (.directoryNotEmpty, DWORD(WinSDK.ERROR_DIR_NOT_EMPTY)),
      (.badPathName, DWORD(WinSDK.ERROR_BAD_PATHNAME)),
      (.alreadyExists, DWORD(WinSDK.ERROR_ALREADY_EXISTS)),
      (.fileTooLarge, DWORD(WinSDK.ERROR_FILE_TOO_LARGE)),
      (.diskFull, DWORD(WinSDK.ERROR_DISK_FULL)),
      (.pipeBusy, DWORD(WinSDK.ERROR_PIPE_BUSY)),
      (.noData, DWORD(WinSDK.ERROR_NO_DATA)),
      (.pipeNotConnected, DWORD(WinSDK.ERROR_PIPE_NOT_CONNECTED)),
      (.moreData, DWORD(WinSDK.ERROR_MORE_DATA)),
      (.notADirectory, DWORD(WinSDK.ERROR_DIRECTORY)),
      (.operationAborted, DWORD(WinSDK.ERROR_OPERATION_ABORTED)),
      (.ioPending, DWORD(WinSDK.ERROR_IO_PENDING)),
      (.userMappedFile, DWORD(WinSDK.ERROR_USER_MAPPED_FILE)),
      (.privilegeNotHeld, DWORD(WinSDK.ERROR_PRIVILEGE_NOT_HELD)),
      (.noneMapped, DWORD(WinSDK.ERROR_NONE_MAPPED)),
      (.invalidSecurityIdentifier, DWORD(WinSDK.ERROR_INVALID_SID)),
      (.noSuchDomain, DWORD(WinSDK.ERROR_NO_SUCH_DOMAIN)),
      (.cannotResolveFileName, DWORD(WinSDK.ERROR_CANT_RESOLVE_FILENAME)),
    ]
    for (error, code) in codes {
      XCTAssertEqual(error.rawValue, code, error.debugDescription)
      XCTAssertFalse(error.isSynthesized, error.debugDescription)
    }
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_FORMAT_MESSAGE_ALLOCATE_BUFFER, DWORD(WinSDK.FORMAT_MESSAGE_ALLOCATE_BUFFER))
    XCTAssertEqual(_FORMAT_MESSAGE_FROM_SYSTEM, DWORD(WinSDK.FORMAT_MESSAGE_FROM_SYSTEM))
    XCTAssertEqual(_FORMAT_MESSAGE_IGNORE_INSERTS, DWORD(WinSDK.FORMAT_MESSAGE_IGNORE_INSERTS))
  }

  func testSynthesizedCode() {
    let error = Win32.Error.incompleteTransfer
    XCTAssertEqual(error.rawValue, 0xA053_5901)
    XCTAssertTrue(error.isSynthesized)
    // APPLICATION_ERROR_MASK, and the bit that makes HRESULT_FROM_WIN32 leave
    // the code unchanged.
    XCTAssertNotEqual(error.rawValue & (1 << 29), 0)
    XCTAssertNotEqual(error.rawValue & (1 << 31), 0)
    XCTAssertTrue(Win32.Error(rawValue: 0xA053_59FF).isSynthesized)
    XCTAssertFalse(Win32.Error(rawValue: 0xA053_5A01).isSynthesized)
  }

  func testRawValues() {
    let code: DWORD = 0x0012_3456
    XCTAssertEqual(Win32.Error(code).rawValue, code)
    XCTAssertEqual(Win32.Error(rawValue: code), Win32.Error(code))
    XCTAssertNotEqual(Win32.Error.sharingViolation, Win32.Error.accessDenied)
  }

  func testDebugDescription() {
    XCTAssertEqual(
      Win32.Error.sharingViolation.debugDescription, "ERROR_SHARING_VIOLATION (32, 0x20)")
    XCTAssertEqual(Win32.Error.success.debugDescription, "ERROR_SUCCESS (0, 0x0)")
    XCTAssertEqual(
      Win32.Error.cannotResolveFileName.debugDescription,
      "ERROR_CANT_RESOLVE_FILENAME (1921, 0x781)")
    XCTAssertEqual(Win32.Error(rawValue: 12345).debugDescription, "12345 (0x3039)")
    XCTAssertEqual(
      Win32.Error.incompleteTransfer.debugDescription,
      "incompleteTransfer (2689882369, 0xA0535901)")
  }

  func testDescription() {
    // The message is localized, so check only its shape.
    let message = Win32.Error.accessDenied.description
    XCTAssertFalse(message.isEmpty)
    XCTAssertFalse(message.last!.isWhitespace, "trailing whitespace: \(message.debugDescription)")
    XCTAssertFalse(message.contains("\r"))
    XCTAssertNotEqual(message, Win32.Error.sharingViolation.description)

    // A customer code (bit 29) has no system message.
    XCTAssertEqual(
      Win32.Error(rawValue: 0x2000_0001).description, "Unknown error 536870913 (0x20000001)")
    // System's own code has a message of its own.
    XCTAssertEqual(
      Win32.Error.incompleteTransfer.description,
      "The transfer ended before all of the data was transferred.")
  }

  func testUntypedPatternMatching() {
    let thrown: any Error = Win32.Error.sharingViolation
    XCTAssertTrue(Win32.Error.sharingViolation ~= thrown)
    XCTAssertFalse(Win32.Error.lockViolation ~= thrown)
    XCTAssertFalse(Win32.Error.fileExists ~= (Errno.fileExists as any Error))
  }

  // The pattern catches are in helpers with no variables and no string
  // interpolation: Swift 6.3.3 crashes on a pattern catch in a function
  // with either.
  func testCatchingSpelledOutCodes() {
    XCTAssertTrue(catchesSpelledOutFileExists(), "a typed pattern for a name Errno shares")
  }

  func testTypedCatchOfAWin32OnlyName() {
    XCTAssertTrue(catchesImplicitSharingViolation())
  }

  func testTypedCatchOfASharedName() {
    XCTAssertTrue(catchesImplicitFileExists())
  }

  func testErrnoApproximation() {
    // The C runtime's _dosmaperr table, as `_mapWindowsErrorToErrno` has it.
    XCTAssertEqual(Errno(approximating: .fileNotFound), .noSuchFileOrDirectory)
    XCTAssertEqual(Errno(approximating: .pathNotFound), .noSuchFileOrDirectory)
    XCTAssertEqual(Errno(approximating: .accessDenied), .permissionDenied)
    // Codes 19 through 36 all become EACCES.
    XCTAssertEqual(Errno(approximating: .sharingViolation), .permissionDenied)
    XCTAssertEqual(Errno(approximating: .lockViolation), .permissionDenied)
    XCTAssertEqual(Errno(approximating: .deviceNotReady), .permissionDenied)
    XCTAssertEqual(Errno(approximating: .brokenPipe), .brokenPipe)
    XCTAssertEqual(Errno(approximating: .fileExists), .fileExists)
    XCTAssertEqual(Errno(approximating: .alreadyExists), .fileExists)
    XCTAssertEqual(Errno(approximating: .diskFull), .noSpace)
    // Unmapped codes become EINVAL, including ones POSIX has names for.
    XCTAssertEqual(Errno(approximating: .noData), .invalidArgument)
    XCTAssertEqual(Errno(approximating: .fileTooLarge), .invalidArgument)
    XCTAssertEqual(Errno(approximating: .moreData), .invalidArgument)
    XCTAssertEqual(Errno(approximating: Win32.Error(rawValue: 0x2000_0001)), .invalidArgument)
    XCTAssertEqual(Errno(approximating: .success).rawValue, 0)
  }
}

@available(System 199, *)
private func catchesSpelledOutFileExists() -> Bool {
  do {
    throw Win32.Error.fileExists
  } catch Win32.Error.fileExists {
    return true
  } catch {
    return false
  }
}

@available(System 199, *)
private func catchesImplicitSharingViolation() -> Bool {
  do throws(Win32.Error) {
    throw .sharingViolation
  } catch .sharingViolation {
    return true
  } catch {
    return false
  }
}

@available(System 199, *)
private func catchesImplicitFileExists() -> Bool {
  do throws(Win32.Error) {
    throw .fileExists
  } catch .fileExists {
    return true
  } catch {
    return false
  }
}

#endif // os(Windows)
