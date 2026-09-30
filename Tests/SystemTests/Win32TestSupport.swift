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

// MARK: - File I/O

/// Runs `body` with a byte span of `bytes`.
///
/// `Array.span` needs a recent Apple OS, so this spells the span the way the
/// FileDescriptor span tests do.
internal func withRawSpan<R>(
  _ bytes: [UInt8], _ body: (RawSpan) throws -> R
) rethrows -> R {
  try bytes.withUnsafeBytes { try body(RawSpan(_unsafeBytes: $0)) }
}

// MARK: - Processes

/// A child process that `win32RawSpawn(_:suspended:)` started, as the raw
/// handles and ID that `CreateProcessW` reports. The caller closes both
/// handles.
internal struct Win32TestChild {
  internal var process: HANDLE
  internal var thread: HANDLE
  internal var id: DWORD
}

/// Starts `commandLine` with raw Win32 calls: no window, no inherited
/// handles, and the calling process's environment and current directory.
internal func win32RawSpawn(
  _ commandLine: String, suspended: Bool = false
) -> Result<Win32TestChild, Win32.Error> {
  var startupInfo = STARTUPINFOW()
  startupInfo.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)
  var information = PROCESS_INFORMATION()
  let flags = DWORD(0x0800_0000) | (suspended ? DWORD(0x4) : 0)  // CREATE_NO_WINDOW, CREATE_SUSPENDED
  // CreateProcessW can write to its command line, so it gets a copy.
  var command = Array(commandLine.utf16) + [0]
  let succeeded = command.withUnsafeMutableBufferPointer { command in
    CreateProcessW(
      nil, command.baseAddress, nil, nil, false, flags, nil, nil, &startupInfo, &information)
  }
  guard succeeded else { return .failure(Win32.Error(GetLastError())) }
  return .success(
    Win32TestChild(
      process: information.hProcess, thread: information.hThread, id: information.dwProcessId))
}

/// A command line for a child that runs for about a minute unless it's
/// ended, and needs no console input.
internal var win32LongRunningCommand: String { "ping.exe -n 60 127.0.0.1" }

/// Everything `handle`'s pipe delivers until its last writer closes.
@available(System 199, *)
internal func win32ReadToEnd(_ handle: borrowing Win32.FileHandle) throws -> [UInt8] {
  var contents: [UInt8] = []
  var chunk = [UInt8](repeating: 0, count: 4096)
  while true {
    let count: Int
    do {
      var span = chunk.mutableSpan
      count = try handle.read(into: &span)
    }
    if count == 0 { return contents }
    contents += chunk[..<count]
  }
}

/// The value of an environment variable of this process, read with a raw
/// Win32 call, or `nil`.
internal func win32RawEnvironmentValue(_ name: String) -> String? {
  name.withCString(encodedAs: UTF16.self) { name -> String? in
    var buffer = [WCHAR](repeating: 0, count: 32_768)
    let length = GetEnvironmentVariableW(name, &buffer, DWORD(buffer.count))
    guard length > 0, Int(length) < buffer.count else { return nil }
    return String(decoding: buffer[..<Int(length)], as: UTF16.self)
  }
}

#endif // os(Windows)
