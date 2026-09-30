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

// Helpers for the Win32 namespace's tests. They check results with raw
// Win32 calls where the API under test can't check itself.

// MARK: - Errors

/// Asserts that `body` throws `expected`.
///
/// `body` throws untyped errors: Swift 6.2 doesn't infer a closure's thrown
/// type, so a `throws(Win32.Error)` parameter would need every closure
/// annotated. It catches with a catch-all rather than a pattern, which
/// Swift 6.2 can crash on in a function that handles owners.
@available(System 199, *)
internal func XCTAssertThrowsWin32Error<R: ~Copyable>(
  _ expected: Win32.Error,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  _ body: () throws -> R
) {
  do {
    _ = try body()
    XCTFail(
      "didn't throw \(expected.debugDescription). \(message())", file: file, line: line)
  } catch {
    guard let error = error as? Win32.Error else {
      XCTFail("threw \(error), not a Win32.Error. \(message())", file: file, line: line)
      return
    }
    XCTAssertEqual(
      error, expected, "threw \(error.debugDescription). \(message())",
      file: file, line: line)
  }
}

// MARK: - Handles

/// The two ends of an anonymous pipe, owned.
@available(System 199, *)
internal struct Win32TestPipe: ~Copyable {
  internal var readEnd: Win32.FileHandle
  internal var writeEnd: Win32.FileHandle

  /// Creates a pipe with `CreatePipe`.
  internal init() throws {
    var readEnd: HANDLE? = nil
    var writeEnd: HANDLE? = nil
    guard CreatePipe(&readEnd, &writeEnd, nil, 0) else {
      throw Win32.Error(GetLastError())
    }
    self.readEnd = Win32.FileHandle(unsafelyAdopting: readEnd)!
    self.writeEnd = Win32.FileHandle(unsafelyAdopting: writeEnd)!
  }
}

/// Writes `bytes` with one `WriteFile` at the file pointer, returning the
/// count written or the last error.
internal func win32RawWrite(_ handle: HANDLE, _ bytes: [UInt8]) -> Result<Int, Win32.Error> {
  var written: DWORD = 0
  let succeeded = bytes.withUnsafeBytes { buffer in
    WriteFile(handle, buffer.baseAddress, DWORD(buffer.count), &written, nil)
  }
  guard succeeded else { return .failure(Win32.Error(GetLastError())) }
  return .success(Int(written))
}

/// The contents of the file at `path`, read with raw Win32 calls, which
/// share every access.
internal func win32RawContents(of path: FilePath) -> [UInt8]? {
  path.withPlatformString { path -> [UInt8]? in
    let access = DWORD(0x8000_0000)  // GENERIC_READ
    let share = DWORD(0x7)  // FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
    let openExisting = DWORD(3)  // OPEN_EXISTING
    guard let handle = CreateFileW(path, access, share, nil, openExisting, 0, nil),
      handle != INVALID_HANDLE_VALUE
    else { return nil }
    defer { CloseHandle(handle) }
    var contents: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
      var count: DWORD = 0
      let succeeded = chunk.withUnsafeMutableBytes { buffer in
        ReadFile(handle, buffer.baseAddress, DWORD(buffer.count), &count, nil)
      }
      guard succeeded else { return nil }
      if count == 0 { return contents }
      contents += chunk[..<Int(count)]
    }
  }
}

/// Whether anything exists at `path`.
internal func win32RawExists(_ path: FilePath) -> Bool {
  path.withPlatformString { GetFileAttributesW($0) != INVALID_FILE_ATTRIBUTES }
}

#endif // os(Windows)
