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

// Reparse points: junctions, which need no privilege, symbolic links, which
// need developer mode or elevation, and the parsing of their data.
@available(System 199, *)
final class Win32ReparsePointsTests: XCTestCase {
  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_FSCTL_GET_REPARSE_POINT, DWORD(WinSDK.FSCTL_GET_REPARSE_POINT))
    XCTAssertEqual(_MAXIMUM_REPARSE_DATA_BUFFER_SIZE, Int(WinSDK.MAXIMUM_REPARSE_DATA_BUFFER_SIZE))
    XCTAssertEqual(_SYMLINK_FLAG_RELATIVE, DWORD(WinSDK.SYMLINK_FLAG_RELATIVE))
  }

  func testJunctions() throws {
    try withTemporaryFilePath(basename: "testReparseJunctions") { directory in
      let target = directory.appending("target")
      try Win32.createDirectory(target)
      let link = directory.appending("link")
      let code = runCommand("mklink /J \"\(link)\" \"\(target)\"")
      XCTAssertEqual(code, 0)

      // No access rights, as for a junction that denies listing it.
      let handle = try Win32.DirectoryHandle.open(link, access: [], flags: .openReparsePoint)
      let point = try handle.reparsePoint()
      XCTAssertEqual(point.tag, .mountPoint)
      XCTAssertFalse(point.isRelative)
      XCTAssertEqual(point.substituteName?.hasPrefix("\\??\\"), true, "\(point)")
      // mklink gives a junction its target's full path as its print name.
      let full = try Win32.fullPath(of: target, extendedLengthPrefix: .never)
      XCTAssertEqual(point.printName.map { FilePath($0) }, full)
      XCTAssertEqual(point.target, full)
      let information = try handle.attributeTagInformation()
      XCTAssertEqual(information.reparseTag, .mountPoint)
      try handle.close()
      try Win32.removeDirectory(link)
    }
  }

  func testSymbolicLinks() throws {
    try withTemporaryFilePath(basename: "testReparseSymbolicLinks") { directory in
      try makeFile(directory.appending("target.txt"))
      let relative = directory.appending("relative.txt")
      do throws(Win32.Error) {
        try Win32.createSymbolicLink(relative, to: "target.txt", flags: .allowUnprivilegedCreate)
      } catch {
        // Developer mode or an administrator is needed.
        guard error == .privilegeNotHeld else { throw error }
        throw XCTSkip("creating symbolic links needs developer mode or elevation")
      }
      let point = try reparsePoint(of: relative)
      XCTAssertEqual(point.tag, .symbolicLink)
      XCTAssertTrue(point.isRelative)
      XCTAssertEqual(point.substituteName, "target.txt")
      XCTAssertEqual(point.printName, "target.txt")
      XCTAssertEqual(point.target, "target.txt")

      // Absolute targets, which needn't exist: a drive's path, a UNC path,
      // one past MAX_PATH, and one that Win32 would change without the
      // prefix, given verbatim so the link keeps its trailing dot.
      let full = try Win32.fullPath(of: directory, extendedLengthPrefix: .never)
      let long = "\\\\?\\C:\\" + String(repeating: "a", count: 300)
      let targets: [(FilePath, FilePath)] = [
        (full.appending("absolute.txt"), full.appending("absolute.txt")),
        ("\\\\server\\share\\file.txt", "\\\\server\\share\\file.txt"),
        (FilePath(long), FilePath(long)),
        ("\\\\?\\C:\\trailing-dot.", "\\\\?\\C:\\trailing-dot."),
      ]
      for (index, (target, expected)) in targets.enumerated() {
        let link = directory.appending("absolute-\(index).txt")
        try Win32.createSymbolicLink(link, to: target, flags: .allowUnprivilegedCreate)
        let point = try reparsePoint(of: link)
        XCTAssertFalse(point.isRelative, "\(target)")
        XCTAssertEqual(point.substituteName?.hasPrefix("\\??\\"), true, "\(target)")
        XCTAssertEqual(point.target, expected, "\(target)")
      }

      // A directory's symbolic link, through a directory handle.
      let realDirectory = directory.appending("real")
      try Win32.createDirectory(realDirectory)
      let linkedDirectory = directory.appending("linked")
      try Win32.createSymbolicLink(
        linkedDirectory, to: "real", flags: [.directory, .allowUnprivilegedCreate])
      let handle = try Win32.DirectoryHandle.open(
        linkedDirectory, access: [], flags: .openReparsePoint)
      let directoryPoint = try handle.reparsePoint()
      XCTAssertEqual(directoryPoint.tag, .symbolicLink)
      XCTAssertEqual(directoryPoint.target, "real")
    }
  }

  func testFilesThatArentReparsePoints() throws {
    try withTemporaryFilePath(basename: "testReparseNone") { directory in
      let path = directory.appending("file.txt")
      try makeFile(path)
      let file = try Win32.FileHandle.open(path, access: [], flags: .openReparsePoint)
      XCTAssertThrowsWin32Error(.notAReparsePoint) { try file.reparsePoint() }
      let opened = try Win32.DirectoryHandle.open(directory, access: [], flags: .openReparsePoint)
      XCTAssertThrowsWin32Error(.notAReparsePoint) { try opened.reparsePoint() }
    }
  }

  func testParsingTheData() throws {
    let absolute = try XCTUnwrap(parse(
      buffer(tag: 0xA000_000C, substitute: "\\??\\C:\\target", print: "C:\\target", flags: 0)))
    XCTAssertEqual(absolute.tag, .symbolicLink)
    XCTAssertFalse(absolute.isRelative)
    XCTAssertEqual(absolute.substituteName, Array("\\??\\C:\\target".utf16))
    XCTAssertEqual(absolute.printName, Array("C:\\target".utf16))

    let relative = try XCTUnwrap(parse(
      buffer(tag: 0xA000_000C, substitute: "..\\x", print: "..\\x", flags: 1)))
    XCTAssertTrue(relative.isRelative)

    // A mount point has no flags, and a junction may have no print name.
    let junction = try XCTUnwrap(parse(
      buffer(tag: 0xA000_0003, substitute: "\\??\\D:\\directory\\", print: "", flags: nil)))
    XCTAssertEqual(junction.tag, .mountPoint)
    XCTAssertEqual(junction.printName, [])

    // A tag that isn't Microsoft's has a GUID after its header.
    let other = try XCTUnwrap(parse(
      le32(0x0000_1234) + le16(3) + le16(0) + [UInt8](repeating: 0xEE, count: 16) + [1, 2, 3]))
    XCTAssertEqual(other.data, [1, 2, 3])
    XCTAssertNil(other.substituteName)
    let unixSocket = try XCTUnwrap(parse(le32(0x8000_0023) + le16(0) + le16(0)))
    XCTAssertEqual(unixSocket.tag, .unixDomainSocket)
    XCTAssertEqual(unixSocket.data, [])

    // Lengths out of their bounds.
    XCTAssertNil(parse([1, 2, 3]))
    XCTAssertNil(parse(le32(0xA000_000C) + le16(100) + le16(0)))
    XCTAssertNil(parse(le32(0xA000_000C) + le16(4) + le16(0) + [0, 0, 0, 0]))
    var past = buffer(tag: 0xA000_000C, substitute: "a", print: "b", flags: 0)
    past[8 + 2] = 0x7F
    XCTAssertNil(parse(past))
    var odd = buffer(tag: 0xA000_000C, substitute: "a", print: "b", flags: 0)
    odd[8] = 1
    XCTAssertNil(parse(odd))
  }

  func testTargets() {
    func target(
      _ name: String, isRelative: Bool = false,
      _ fullPath: ([UInt16]) -> [UInt16]? = { $0 }
    ) -> String {
      String(
        decoding: Win32.ReparsePoint._target(
          Array(name.utf16), isRelative: isRelative, fullPath: fullPath),
        as: UTF16.self)
    }
    XCTAssertEqual(target("\\??\\C:\\target"), "C:\\target")
    XCTAssertEqual(target("\\??\\UNC\\server\\share\\x"), "\\\\server\\share\\x")
    XCTAssertEqual(target("\\??\\Volume{1234}\\"), "\\\\?\\Volume{1234}\\")
    XCTAssertEqual(target("..\\x", isRelative: true), "..\\x")
    XCTAssertEqual(target("\\Device\\HarddiskVolume1\\x"), "\\Device\\HarddiskVolume1\\x")
    // A path that its full path changes keeps the prefix.
    let dropsTheDot: ([UInt16]) -> [UInt16]? = { Array($0.dropLast()) }
    XCTAssertEqual(target("\\??\\C:\\x.", dropsTheDot), "\\\\?\\C:\\x.")
    // MAX_PATH, with the terminator, is the limit.
    let shortEnough = target("\\??\\C:\\" + String(repeating: "a", count: 256))
    XCTAssertTrue(shortEnough.hasPrefix("C:\\"))
    let tooLong = target("\\??\\C:\\" + String(repeating: "a", count: 257))
    XCTAssertTrue(tooLong.hasPrefix("\\\\?\\"))
    // And the real GetFullPathNameW, for a path it keeps and one it trims.
    let kept = target("\\??\\C:\\directory\\file.txt", Win32._fullPathName)
    XCTAssertEqual(kept, "C:\\directory\\file.txt")
    let trimmed = target("\\??\\C:\\directory\\file.txt.", Win32._fullPathName)
    XCTAssertEqual(trimmed, "\\\\?\\C:\\directory\\file.txt.")
  }
}

/// The reparse point at `path`, opened as itself, with no access rights.
@available(System 199, *)
private func reparsePoint(of path: FilePath) throws -> Win32.ReparsePoint {
  let file = try Win32.FileHandle.open(
    path, access: [], flags: [.openReparsePoint, .backupSemantics])
  return try file.reparsePoint()
}

/// Creates an empty file.
@available(System 199, *)
private func makeFile(_ path: FilePath) throws {
  try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew).close()
}

/// Runs a command with cmd.exe, and returns its exit code.
private func runCommand(_ command: String) -> DWORD? {
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

// MARK: - Reparse data, as Windows lays it out

@available(System 199, *)
private func parse(_ bytes: [UInt8]) -> (
  tag: Win32.ReparseTag, data: [UInt8], substituteName: [UInt16]?, printName: [UInt16]?,
  isRelative: Bool
)? {
  bytes.withUnsafeBytes { Win32.ReparsePoint._parse($0) }
}

private func le16(_ value: Int) -> [UInt8] {
  [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
}

private func le32(_ value: UInt32) -> [UInt8] {
  (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * UInt32($0))) }
}

/// A `REPARSE_DATA_BUFFER`, with the print name before the substitute name,
/// and, for a symbolic link, its flags.
private func buffer(tag: UInt32, substitute: String, print: String, flags: UInt32?) -> [UInt8] {
  let printBytes = Array(print.utf16).flatMap { le16(Int($0)) }
  let substituteBytes = Array(substitute.utf16).flatMap { le16(Int($0)) }
  var data = le16(printBytes.count) + le16(substituteBytes.count) + le16(0) + le16(printBytes.count)
  if let flags { data += le32(flags) }
  data += printBytes + substituteBytes
  return le32(tag) + le16(data.count) + le16(0) + data
}

#endif // os(Windows)
