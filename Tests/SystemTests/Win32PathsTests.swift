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

/// The path a raw Win32 call writes into a buffer of `MAX_PATH` characters
/// and more, for comparing with System's.
private func win32RawPath(_ call: (UnsafeMutablePointer<WCHAR>, DWORD) -> DWORD) -> FilePath? {
  var buffer = [WCHAR](repeating: 0, count: 32_768)
  let length = buffer.withUnsafeMutableBufferPointer { call($0.baseAddress!, DWORD($0.count)) }
  guard length > 0, Int(length) < buffer.count else { return nil }
  return buffer.withUnsafeBufferPointer { FilePath(platformString: $0.baseAddress!) }
}

/// Whether `path` names a directory, by a raw Win32 call.
private func win32RawIsDirectory(_ path: FilePath) -> Bool {
  path.withPlatformString { path in
    let attributes = GetFileAttributesW(path)
    return attributes != INVALID_FILE_ATTRIBUTES
      && attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0
  }
}

// The current working directory, the temporary directory and the current
// executable on Windows, and Win32's Windows and system directories. The
// working-directory test changes the process's, which XCTest allows, since
// it runs one test at a time.
@available(System 199, *)
final class Win32PathsTests: XCTestCase {
  func testCurrentWorkingDirectory() throws {
    let original = try FilePath.currentWorkingDirectory()
    XCTAssertEqual(original, win32RawPath { GetCurrentDirectoryW($1, $0) })
    XCTAssertTrue(original.isAbsolute)

    try withTemporaryFilePath(basename: "testCurrentWorkingDirectory") { directory in
      try FilePath.setCurrentWorkingDirectory(directory)
      defer { try? FilePath.setCurrentWorkingDirectory(original) }
      let changed = try FilePath.currentWorkingDirectory()
      XCTAssertEqual(changed, win32RawPath { GetCurrentDirectoryW($1, $0) })
      // A relative path now resolves in the directory.
      let file = try Win32.FileHandle.open(
        "relative.txt", access: .genericWrite, disposition: .createNew)
      try file.close()
      XCTAssertTrue(win32RawExists(directory.appending("relative.txt")))

      // The C-string overload.
      try original.withPlatformString { try FilePath.setCurrentWorkingDirectory($0) }
      let restored = try FilePath.currentWorkingDirectory()
      XCTAssertEqual(restored, original)
    }
  }

  func testSettingAMissingWorkingDirectoryFails() throws {
    let original = try FilePath.currentWorkingDirectory()
    XCTAssertThrowsError(
      try FilePath.setCurrentWorkingDirectory("C:\\system-tests-no-such-directory")
    ) { error in
      XCTAssertEqual(error as? Errno, .noSuchFileOrDirectory)
    }
    let unchanged = try FilePath.currentWorkingDirectory()
    XCTAssertEqual(unchanged, original)
  }

  #if ENABLE_MOCKING
  func testSettingTheWorkingDirectoryCallsTheCRuntime() throws {
    try MockingDriver.withMockingEnabled { mocking in
      try FilePath.setCurrentWorkingDirectory("C:\\Some\\Directory")
      let change = mocking.trace.dequeue()
      XCTAssertEqual(change?.name, "_wchdir")
      let arguments: [AnyHashable] = ["C:\\Some\\Directory"]
      XCTAssertEqual(change?.arguments, arguments)
    }
  }
  #endif

  func testTemporaryDirectory() {
    let directory = FilePath.temporaryDirectory()
    XCTAssertTrue(directory.isAbsolute, "\(directory)")
    XCTAssertTrue(win32RawIsDirectory(directory), "\(directory)")
    // GetTempPathW's choice, unless this process runs as SYSTEM.
    let fromGetTempPathW = win32RawPath { GetTempPathW($1, $0) }
    XCTAssertTrue(
      directory == fromGetTempPathW || directory.string.lowercased().hasSuffix("systemtemp"),
      "\(directory), GetTempPathW: \(String(describing: fromGetTempPathW))")
  }

  func testCurrentExecutable() {
    let executable = FilePath.currentExecutable()
    XCTAssertFalse(executable.isEmpty)
    XCTAssertEqual(executable, win32RawPath { GetModuleFileNameW(nil, $0, $1) })
    XCTAssertTrue(win32RawExists(executable), "\(executable)")
    XCTAssertFalse(win32RawIsDirectory(executable), "\(executable)")
  }

  func testWindowsAndSystemDirectories() throws {
    let windows = try Win32.windowsDirectory()
    let system = try Win32.systemDirectory()
    XCTAssertTrue(win32RawIsDirectory(windows), "\(windows)")
    XCTAssertTrue(win32RawIsDirectory(system), "\(system)")
    // Windows doesn't promise these paths' case.
    let root = try XCTUnwrap(win32RawEnvironmentValue("SystemRoot"))
    XCTAssertEqual(windows.string.lowercased(), FilePath(root).string.lowercased())
    XCTAssertEqual(
      system.string.lowercased(), windows.appending("System32").string.lowercased())
  }
}

#endif // os(Windows)
