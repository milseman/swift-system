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

/// Writes `contents` to a new file at `path`.
@available(System 199, *)
private func makeFile(_ path: FilePath, _ contents: String = "") throws {
  let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
  _ = try win32RawWrite(file.unsafeRawHandle, Array(contents.utf8)).get()
  try file.close()
}

/// Asserts that `body` throws `expected`, with a catch-all.
@available(System 199, *)
private func XCTAssertThrowsErrno(
  _ expected: Errno, file: StaticString = #filePath, line: UInt = #line,
  _ body: () throws -> Void
) {
  do {
    try body()
    XCTFail("didn't throw \(expected)", file: file, line: line)
  } catch {
    XCTAssertEqual(error as? Errno, expected, "threw \(error)", file: file, line: line)
  }
}

// FilePath.remove() on Windows, in a temporary directory of its own.
@available(System 199, *)
final class Win32FilePathRemoveTests: XCTestCase {
  func testRemovingFilesAndEmptyDirectories() throws {
    try withTemporaryFilePath(basename: "testRemovingFilesAndEmptyDirectories") { directory in
      let file = directory.appending("file.txt")
      try makeFile(file)
      try file.remove()
      XCTAssertFalse(win32RawExists(file))

      let empty = directory.appending("empty")
      try Win32.createDirectory(empty)
      try empty.remove()
      XCTAssertFalse(win32RawExists(empty))

      // A directory that isn't empty stays.
      let full = directory.appending("full")
      try Win32.createDirectory(full)
      try makeFile(full.appending("inside.txt"))
      XCTAssertThrowsErrno(.directoryNotEmpty) { try full.remove() }
      XCTAssertTrue(win32RawExists(full.appending("inside.txt")))

      XCTAssertThrowsErrno(.noSuchFileOrDirectory) {
        try directory.appending("missing").remove()
      }
    }
  }

  func testRemovingWithACString() throws {
    try withTemporaryFilePath(basename: "testRemovingWithACString") { directory in
      let file = directory.appending("file.txt")
      try makeFile(file)
      try file.withPlatformString { try FilePath.remove($0) }
      XCTAssertFalse(win32RawExists(file))
    }
  }

  func testWhatCantBeRemoved() throws {
    try withTemporaryFilePath(basename: "testWhatCantBeRemoved") { directory in
      // A read-only file.
      let readOnly = directory.appending("read-only.txt")
      try makeFile(readOnly)
      try Win32.setFileAttributes(.readOnly, of: readOnly)
      XCTAssertThrowsErrno(.permissionDenied) { try readOnly.remove() }
      try Win32.setFileAttributes([], of: readOnly)
      try readOnly.remove()

      // A file that's open without sharing deletion.
      let open = directory.appending("open.txt")
      try makeFile(open)
      let exclusive = try Win32.FileHandle.open(open, access: .genericRead, shareMode: [.read])
      XCTAssertThrowsErrno(.permissionDenied) { try open.remove() }
      try exclusive.close()
      try open.remove()
    }
  }

  func testRemovingADirectoryLinkKeepsItsTarget() throws {
    try withTemporaryFilePath(basename: "testRemovingADirectoryLink") { directory in
      let target = directory.appending("target")
      try Win32.createDirectory(target)
      try makeFile(target.appending("inside.txt"))
      let link = directory.appending("link")
      do throws(Win32.Error) {
        try Win32.createSymbolicLink(link, to: target, flags: [.directory, .allowUnprivilegedCreate])
      } catch {
        // Developer mode or an administrator is needed.
        guard error == .privilegeNotHeld else { throw error }
        throw XCTSkip("creating symbolic links needs developer mode or elevation")
      }
      try link.remove()
      XCTAssertFalse(win32RawExists(link))
      XCTAssertTrue(win32RawExists(target.appending("inside.txt")))
    }
  }

  #if ENABLE_MOCKING
  func testRemoveCallsTheCRuntime() throws {
    MockingDriver.withMockingEnabled { mocking in
      let path: FilePath = "C:\\scratch\\file.txt"
      try? path.remove()
      let entry = mocking.trace.dequeue()
      XCTAssertEqual(entry?.name, "_wremove")
      XCTAssertEqual(entry?.arguments, [path.string])
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif
}

#endif // os(Windows)
