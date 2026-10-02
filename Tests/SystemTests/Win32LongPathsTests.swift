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

/// Creates directories under `directory`, one component at a time through
/// `\\?\` paths, until the path has `length` characters, and returns it, or
/// `nil` if a creation fails.
private func win32RawDirectoryChain(in directory: FilePath, length: Int) -> FilePath? {
  var path = directory
  while path.length < length {
    // A component can have 255 characters; the last one takes the rest.
    let room = length - path.length - 1
    path = path.appending(String(repeating: "d", count: room <= 200 ? room : 100))
    let created = ("\\\\?\\" + path.string).withCString(encodedAs: UTF16.self) {
      CreateDirectoryW($0, nil)
    }
    guard created else { return nil }
  }
  return path
}

/// Runs `cmd.exe /c <command>` and returns its exit code, or `nil` if it
/// couldn't be started.
private func win32RawRunCommand(_ command: String) -> DWORD? {
  guard case .success(let child) = win32RawSpawn("cmd.exe /c " + command) else { return nil }
  defer {
    CloseHandle(child.process)
    CloseHandle(child.thread)
  }
  WaitForSingleObject(child.process, INFINITE)
  var code: DWORD = 0
  guard GetExitCodeProcess(child.process, &code) else { return nil }
  return code
}

// Full paths with and without the extended-length prefix, removing the
// prefix, and FilePath.canonicalized() on Windows. The tests that resolve
// relative paths change the process's current directory, which XCTest
// allows, since it runs one test at a time.
@available(System 199, *)
final class Win32LongPathsTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(
      _PATHCCH_ALLOW_LONG_PATHS, ULONG(truncatingIfNeeded: PATHCCH_ALLOW_LONG_PATHS.rawValue))
    XCTAssertEqual(
      _PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH,
      ULONG(truncatingIfNeeded: PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH.rawValue))
    XCTAssertEqual(_S_OK, WinSDK.S_OK)
    XCTAssertEqual(_S_FALSE, WinSDK.S_FALSE)
    // CreateDirectoryW's documented limit, which has no macro.
    XCTAssertEqual(_win32DirectoryMaxPath, Int(MAX_PATH) - 12)
  }

  /// Runs `body` with a new temporary directory as the current directory,
  /// and restores the original.
  private func withTemporaryCurrentDirectory(
    _ basename: FilePath.Component, _ body: (FilePath) throws -> Void
  ) throws {
    let original = try FilePath.currentWorkingDirectory()
    try withTemporaryFilePath(basename: basename) { directory in
      try FilePath.setCurrentWorkingDirectory(directory)
      defer { try? FilePath.setCurrentWorkingDirectory(original) }
      // The current directory as Windows spells it, which can differ from
      // the temporary directory's spelling.
      try body(try FilePath.currentWorkingDirectory())
    }
  }

  func testRelativePathsResolveAgainstTheCurrentDirectory() throws {
    try withTemporaryCurrentDirectory("testRelativePaths") { current in
      let expected = current.appending("a").appending("c")
      let resolved = try Win32.fullPath(of: "a/./b/../c")
      XCTAssertEqual(resolved, expected)
      // Trailing dots and spaces leave the last component.
      let trimmed = try Win32.fullPath(of: "a\\c. .")
      XCTAssertEqual(trimmed, expected)
      // A full path resolves to itself, in every form.
      let again = try Win32.fullPath(of: resolved)
      XCTAssertEqual(again, resolved)
      let never = try Win32.fullPath(of: "a\\b\\..\\c", extendedLengthPrefix: .never)
      XCTAssertEqual(never, expected)
      let always = try Win32.fullPath(of: "a\\c", extendedLengthPrefix: .always)
      XCTAssertEqual(always, FilePath("\\\\?\\" + expected.string))
    }
  }

  func testThePrefixStartsAtCreateDirectorysLimit() throws {
    try withTemporaryCurrentDirectory("testPrefixLimit") { current in
      // Full paths of 246 and 247 characters, with one more for the
      // terminator.
      let shorter = String(repeating: "s", count: 246 - current.length - 1)
      let atLimit = String(repeating: "l", count: 247 - current.length - 1)
      let short = try Win32.fullPath(of: FilePath(shorter))
      XCTAssertEqual(short, current.appending(shorter))
      let long = try Win32.fullPath(of: FilePath(atLimit))
      XCTAssertEqual(long, FilePath("\\\\?\\" + current.appending(atLimit).string))
      let unprefixed = try Win32.fullPath(of: FilePath(atLimit), extendedLengthPrefix: .never)
      XCTAssertEqual(unprefixed, current.appending(atLimit))
    }
  }

  func testDirectoriesAtTheLimitCanBeCreated() throws {
    try withTemporaryFilePath(basename: "testDirectoryLimit") { directory in
      // 250 characters: under MAX_PATH, and over CreateDirectoryW's limit.
      let parent = try XCTUnwrap(win32RawDirectoryChain(in: directory, length: 240))
      let child = parent.appending(String(repeating: "c", count: 250 - parent.length - 1))
      let resolved = try Win32.fullPath(of: child)
      XCTAssertTrue(resolved.string.hasPrefix("\\\\?\\"), "\(resolved)")
      let created = resolved.withPlatformString { CreateDirectoryW($0, nil) }
      XCTAssertTrue(created, "\(GetLastError())")
    }
  }

  func testUNCPaths() throws {
    // Lexical, so the server needn't exist.
    let short = try Win32.fullPath(of: "\\\\server\\share\\dir")
    XCTAssertEqual(short, "\\\\server\\share\\dir")
    let always = try Win32.fullPath(of: "\\\\server\\share\\dir", extendedLengthPrefix: .always)
    XCTAssertEqual(always, "\\\\?\\UNC\\server\\share\\dir")
  }

  func testVerbatimAndDevicePathsAreUnchanged() throws {
    let prefixes: [Win32.ExtendedLengthPrefix] = [.never, .whenNeeded, .always]
    for prefix in prefixes {
      let verbatim = try Win32.fullPath(of: "\\\\?\\C:\\a\\..\\b", extendedLengthPrefix: prefix)
      XCTAssertEqual(verbatim, "\\\\?\\C:\\a\\..\\b", "\(prefix)")
      let device = try Win32.fullPath(of: "\\\\.\\COM1", extendedLengthPrefix: prefix)
      XCTAssertEqual(device, "\\\\.\\COM1", "\(prefix)")
      // A device name resolves to a device path, which gets no prefix.
      let null = try Win32.fullPath(of: "NUL", extendedLengthPrefix: prefix)
      XCTAssertEqual(null, "\\\\.\\NUL", "\(prefix)")
    }
  }

  func testRemovingThePrefix() {
    XCTAssertEqual(
      Win32.removingExtendedLengthPrefix(from: "\\\\?\\C:\\dir\\file"), "C:\\dir\\file")
    XCTAssertEqual(
      Win32.removingExtendedLengthPrefix(from: "\\\\?\\UNC\\server\\share\\dir"),
      "\\\\server\\share\\dir")
    XCTAssertEqual(Win32.removingExtendedLengthPrefix(from: "C:\\dir"), "C:\\dir")
    // A volume GUID path has no other spelling.
    let volume: FilePath = "\\\\?\\Volume{00000000-0000-0000-0000-000000000000}\\dir"
    XCTAssertEqual(Win32.removingExtendedLengthPrefix(from: volume), volume)
  }

  func testCurrentDirectoriesOfNewProcessesHaveNoPrefix() throws {
    try withTemporaryFilePath(basename: "testCurrentDirectoryPrefix") { directory in
      // Past CreateDirectoryW's limit, where other paths get the prefix,
      // and under MAX_PATH, so cmd.exe can use it.
      let current = try XCTUnwrap(win32RawDirectoryChain(in: directory, length: 250))
      let marker = try Win32.FileHandle.open(
        current.appending("marker.txt"), access: .genericWrite, disposition: .createNew)
      try marker.close()
      let child = try Win32.ProcessHandle.create(
        commandLine: "cmd.exe /c if exist marker.txt (exit 5) else (exit 6)",
        currentDirectory: current, flags: .noWindow)
      try child.process.waitForExit()
      let code = try child.process.exitCode()
      XCTAssertEqual(code, 5)
    }
  }

  // MARK: - FilePath.canonicalized()

  func testCanonicalizedFiles() throws {
    try withTemporaryCurrentDirectory("testCanonicalized") { current in
      let file = try Win32.FileHandle.open(
        "File.txt", access: .genericWrite, disposition: .createNew)
      try file.close()
      // The temporary directory can have short (8.3) names, which the
      // final path spells out, so the expected path is its own.
      let directory = try current.canonicalized()
      XCTAssertFalse(directory.string.hasPrefix("\\\\?\\"), "\(directory)")
      // Relative, in the wrong case, and through a dot segment.
      let resolved = try FilePath("sub\\..\\file.TXT").canonicalized()
      XCTAssertEqual(resolved, directory.appending("File.txt"))
      let fromCString = try FilePath("file.txt").withPlatformString {
        try FilePath.canonicalized($0)
      }
      XCTAssertEqual(fromCString, resolved)
      XCTAssertThrowsError(try FilePath("missing.txt").canonicalized()) { error in
        XCTAssertEqual(error as? Errno, .noSuchFileOrDirectory)
      }
    }
  }

  func testCanonicalizedResolvesJunctions() throws {
    try withTemporaryCurrentDirectory("testCanonicalizedJunction") { current in
      let target = try current.canonicalized().appending("target")
      let created = target.withPlatformString { CreateDirectoryW($0, nil) }
      XCTAssertTrue(created)
      try Win32.FileHandle.open(
        target.appending("file.txt"), access: .genericWrite, disposition: .createNew
      ).close()
      // A junction needs no privilege, unlike a symbolic link.
      let code = win32RawRunCommand("mklink /J link target")
      XCTAssertEqual(code, 0)
      let resolved = try FilePath("link\\file.txt").canonicalized()
      XCTAssertEqual(resolved, target.appending("file.txt"))
      let directory = try FilePath("link").canonicalized()
      XCTAssertEqual(directory, target)
    }
  }

  func testCanonicalizedKeepsThePrefixWhereNeeded() throws {
    try withTemporaryFilePath(basename: "testCanonicalizedLong") { directory in
      let long = try XCTUnwrap(win32RawDirectoryChain(in: directory, length: 300))
      let resolved = try long.canonicalized()
      XCTAssertTrue(resolved.string.hasPrefix("\\\\?\\"), "\(resolved)")
      XCTAssertGreaterThanOrEqual(resolved.length, 300 + 4)
    }
  }
}

#endif // os(Windows)
