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

import ucrt
import WinSDK

// SYS-0011: Win32.FileHandle and Win32.DirectoryHandle.
@available(System 199, *)
final class Win32FileHandleTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let access: [(Win32.AccessMask, DWORD)] = [
      (.genericRead, DWORD(WinSDK.GENERIC_READ)),
      (.genericWrite, DWORD(WinSDK.GENERIC_WRITE)),
      (.genericExecute, DWORD(WinSDK.GENERIC_EXECUTE)),
      (.genericAll, DWORD(WinSDK.GENERIC_ALL)),
      (.maximumAllowed, DWORD(WinSDK.MAXIMUM_ALLOWED)),
      (.delete, DWORD(WinSDK.DELETE)),
      (.readControl, DWORD(WinSDK.READ_CONTROL)),
      (.writeDAC, DWORD(WinSDK.WRITE_DAC)),
      (.writeOwner, DWORD(WinSDK.WRITE_OWNER)),
      (.synchronize, DWORD(WinSDK.SYNCHRONIZE)),
      (.readData, DWORD(WinSDK.FILE_READ_DATA)),
      (.listDirectory, DWORD(WinSDK.FILE_LIST_DIRECTORY)),
      (.writeData, DWORD(WinSDK.FILE_WRITE_DATA)),
      (.addFile, DWORD(WinSDK.FILE_ADD_FILE)),
      (.appendData, DWORD(WinSDK.FILE_APPEND_DATA)),
      (.addSubdirectory, DWORD(WinSDK.FILE_ADD_SUBDIRECTORY)),
      (.readExtendedAttributes, DWORD(WinSDK.FILE_READ_EA)),
      (.writeExtendedAttributes, DWORD(WinSDK.FILE_WRITE_EA)),
      (.execute, DWORD(WinSDK.FILE_EXECUTE)),
      (.traverse, DWORD(WinSDK.FILE_TRAVERSE)),
      (.deleteChild, DWORD(WinSDK.FILE_DELETE_CHILD)),
      (.readAttributes, DWORD(WinSDK.FILE_READ_ATTRIBUTES)),
      (.writeAttributes, DWORD(WinSDK.FILE_WRITE_ATTRIBUTES)),
    ]
    for (mask, value) in access {
      XCTAssertEqual(mask.rawValue, value)
    }
    // Each directory spelling names the same bit as its file spelling.
    XCTAssertEqual(Win32.AccessMask.readData, .listDirectory)
    XCTAssertEqual(Win32.AccessMask.writeData, .addFile)
    XCTAssertEqual(Win32.AccessMask.appendData, .addSubdirectory)
    XCTAssertEqual(Win32.AccessMask.execute, .traverse)

    XCTAssertEqual(Win32.ShareMode.read.rawValue, DWORD(WinSDK.FILE_SHARE_READ))
    XCTAssertEqual(Win32.ShareMode.write.rawValue, DWORD(WinSDK.FILE_SHARE_WRITE))
    XCTAssertEqual(Win32.ShareMode.delete.rawValue, DWORD(WinSDK.FILE_SHARE_DELETE))

    XCTAssertEqual(Win32.CreationDisposition.createNew.rawValue, DWORD(WinSDK.CREATE_NEW))
    XCTAssertEqual(Win32.CreationDisposition.createAlways.rawValue, DWORD(WinSDK.CREATE_ALWAYS))
    XCTAssertEqual(Win32.CreationDisposition.openExisting.rawValue, DWORD(WinSDK.OPEN_EXISTING))
    XCTAssertEqual(Win32.CreationDisposition.openAlways.rawValue, DWORD(WinSDK.OPEN_ALWAYS))
    XCTAssertEqual(
      Win32.CreationDisposition.truncateExisting.rawValue, DWORD(WinSDK.TRUNCATE_EXISTING))

    let flags: [(Win32.FileFlags, DWORD)] = [
      (.backupSemantics, DWORD(WinSDK.FILE_FLAG_BACKUP_SEMANTICS)),
      (.noBuffering, DWORD(WinSDK.FILE_FLAG_NO_BUFFERING)),
      (.writeThrough, DWORD(WinSDK.FILE_FLAG_WRITE_THROUGH)),
      (.sequentialScan, DWORD(WinSDK.FILE_FLAG_SEQUENTIAL_SCAN)),
      (.randomAccess, DWORD(WinSDK.FILE_FLAG_RANDOM_ACCESS)),
      (.deleteOnClose, DWORD(WinSDK.FILE_FLAG_DELETE_ON_CLOSE)),
      (.openReparsePoint, DWORD(WinSDK.FILE_FLAG_OPEN_REPARSE_POINT)),
      (.posixSemantics, DWORD(WinSDK.FILE_FLAG_POSIX_SEMANTICS)),
      (.openNoRecall, DWORD(WinSDK.FILE_FLAG_OPEN_NO_RECALL)),
      (.sessionAware, DWORD(WinSDK.FILE_FLAG_SESSION_AWARE)),
    ]
    for (flag, value) in flags {
      XCTAssertEqual(flag.rawValue, value)
    }

    let attributes: [(Win32.FileAttributes, DWORD)] = [
      (.normal, DWORD(WinSDK.FILE_ATTRIBUTE_NORMAL)),
      (.readOnly, DWORD(WinSDK.FILE_ATTRIBUTE_READONLY)),
      (.hidden, DWORD(WinSDK.FILE_ATTRIBUTE_HIDDEN)),
      (.system, DWORD(WinSDK.FILE_ATTRIBUTE_SYSTEM)),
      (.archive, DWORD(WinSDK.FILE_ATTRIBUTE_ARCHIVE)),
      (.temporary, DWORD(WinSDK.FILE_ATTRIBUTE_TEMPORARY)),
      (.offline, DWORD(WinSDK.FILE_ATTRIBUTE_OFFLINE)),
      (.encrypted, DWORD(WinSDK.FILE_ATTRIBUTE_ENCRYPTED)),
    ]
    for (attribute, value) in attributes {
      XCTAssertEqual(attribute.rawValue, value)
    }

    XCTAssertEqual(FileDescriptor.TranslationMode.binary.rawValue, _O_BINARY)
    XCTAssertEqual(FileDescriptor.TranslationMode.text.rawValue, _O_TEXT)
    XCTAssertEqual(FileDescriptor.TranslationMode.wideText.rawValue, _O_WTEXT)
  }

  func testInternalConstantsMatchTheSDK() {
    XCTAssertEqual(_DUPLICATE_SAME_ACCESS, DWORD(WinSDK.DUPLICATE_SAME_ACCESS))
    XCTAssertEqual(_FACILITY_WIN32, DWORD(WinSDK.FACILITY_WIN32))
    XCTAssertEqual(_FILE_FLAG_OVERLAPPED, DWORD(WinSDK.FILE_FLAG_OVERLAPPED))
    XCTAssertEqual(_FILE_SYNCHRONOUS_IO_ALERT, ULONG(WinSDK.FILE_SYNCHRONOUS_IO_ALERT))
    XCTAssertEqual(_FILE_SYNCHRONOUS_IO_NONALERT, ULONG(WinSDK.FILE_SYNCHRONOUS_IO_NONALERT))
    XCTAssertEqual(_FILE_TYPE_UNKNOWN, DWORD(WinSDK.FILE_TYPE_UNKNOWN))
    XCTAssertEqual(_HANDLE_FLAG_INHERIT, WinSDK.HANDLE_FLAG_INHERIT)
    XCTAssertEqual(_SDDL_REVISION_1, DWORD(WinSDK.SDDL_REVISION_1))
    XCTAssertEqual(_win32MaxPath, Int(WinSDK.MAX_PATH))
  }

  func testHRESULTConversion() {
    // HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE) carries the code.
    XCTAssertEqual(_win32Error(fromHRESULT: HRESULT(bitPattern: 0x8007_00CE)), 206)
    // E_OUTOFMEMORY is in FACILITY_WIN32 too.
    XCTAssertEqual(_win32Error(fromHRESULT: HRESULT(bitPattern: 0x8007_000E)), 14)
    // E_FAIL isn't, so it's kept whole.
    XCTAssertEqual(_win32Error(fromHRESULT: HRESULT(bitPattern: 0x8000_4005)), 0x8000_4005)
  }

  func testOpenOrCreateReportsWhetherTheFileExisted() throws {
    try withTemporaryFilePath(basename: "testOpenOrCreate") { directory in
      let path = directory.appending("file.txt")
      let first = try Win32.FileHandle.openOrCreate(path, access: .genericWrite)
      let firstExisted = first.existed
      XCTAssertFalse(firstExisted)
      let raw = first.handle.unsafeRawHandle
      XCTAssertEqual(try win32RawWrite(raw, Array("hello".utf8)).get(), 5)
      try first.handle.close()

      let second = try Win32.FileHandle.openOrCreate(path, access: .genericRead)
      let secondExisted = second.existed
      XCTAssertTrue(secondExisted)
      try second.handle.close()
      XCTAssertEqual(win32RawContents(of: path), Array("hello".utf8))

      // CREATE_ALWAYS overwrites the file, and reports that it existed.
      let third = try Win32.FileHandle.openOrCreate(
        path, access: .genericWrite, overwriteExisting: true)
      let thirdExisted = third.existed
      XCTAssertTrue(thirdExisted)
      try third.handle.close()
      XCTAssertEqual(win32RawContents(of: path), [])
    }
  }

  func testOpenFailures() throws {
    try withTemporaryFilePath(basename: "testOpenFailures") { directory in
      XCTAssertThrowsWin32Error(.fileNotFound) {
        try Win32.FileHandle.open(directory.appending("missing.txt"), access: .genericRead)
      }
      XCTAssertThrowsWin32Error(.pathNotFound) {
        try Win32.FileHandle.open(
          directory.appending("missing").appending("file.txt"), access: .genericRead)
      }
      let path = directory.appending("file.txt")
      try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew).close()
      XCTAssertThrowsWin32Error(.fileExists) {
        try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      }
      // Without FILE_FLAG_BACKUP_SEMANTICS, CreateFileW can't open a directory.
      XCTAssertThrowsWin32Error(.accessDenied) {
        try Win32.FileHandle.open(directory, access: .genericRead)
      }
    }
  }

  func testExclusiveShareMode() throws {
    try withTemporaryFilePath(basename: "testExclusiveShareMode") { directory in
      let path = directory.appending("file.txt")
      let exclusive = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], shareMode: [], disposition: .createNew)
      XCTAssertThrowsWin32Error(.sharingViolation) {
        try Win32.FileHandle.open(path, access: .readAttributes)
      }
      try exclusive.close()
      try Win32.FileHandle.open(path, access: .genericRead).close()
    }
  }

  func testDefaultShareModeAllowsDeletion() throws {
    try withTemporaryFilePath(basename: "testDefaultShareMode") { directory in
      let path = directory.appending("file.txt")
      let first = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      let second = try Win32.FileHandle.open(path, access: .genericRead)
      let deleted = path.withPlatformString { DeleteFileW($0) }
      XCTAssertTrue(deleted)
      try second.close()
      try first.close()
      XCTAssertFalse(win32RawExists(path))
    }
  }

  func testMetadataOnlyOpen() throws {
    try withTemporaryFilePath(basename: "testMetadataOnlyOpen") { directory in
      let path = directory.appending("file.txt")
      try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew).close()
      let metadata = try Win32.FileHandle.open(path, access: [])
      let raw = metadata.unsafeRawHandle
      XCTAssertThrowsWin32Error(.accessDenied) {
        try win32RawWrite(raw, [1]).get()
      }
      try metadata.close()
    }
  }

  func testOverlappedIsRejected() throws {
    try withTemporaryFilePath(basename: "testOverlappedIsRejected") { directory in
      let path = directory.appending("file.txt")
      let overlapped = Win32.FileFlags(rawValue: DWORD(WinSDK.FILE_FLAG_OVERLAPPED))
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try Win32.FileHandle.open(
          path, access: .genericWrite, disposition: .createNew, flags: overlapped)
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try Win32.FileHandle.openOrCreate(path, access: .genericWrite, flags: overlapped)
      }
      // The bit is rejected wherever it's carried.
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try Win32.FileHandle.open(
          path, access: .genericWrite, disposition: .createNew,
          attributes: Win32.FileAttributes(rawValue: overlapped.rawValue))
      }
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try Win32.DirectoryHandle.open(directory, flags: overlapped)
      }
      // Each was rejected before CreateFileW.
      XCTAssertFalse(win32RawExists(path))

      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      XCTAssertThrowsWin32Error(.invalidParameter) {
        try file.reopen(access: .genericRead, flags: overlapped)
      }
      try file.close()
    }
  }

  func testDirectoryHandle() throws {
    try withTemporaryFilePath(basename: "testDirectoryHandle") { directory in
      try Win32.DirectoryHandle.open(directory).close()

      let path = directory.appending("file.txt")
      try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew).close()
      XCTAssertThrowsWin32Error(.notADirectory) {
        try Win32.DirectoryHandle.open(path)
      }
      // An exclusive open fails if any handle to the file is open, so this
      // shows the handle that DirectoryHandle.open made was closed.
      try Win32.FileHandle.open(path, access: .genericRead, shareMode: []).close()

      let opened = try Win32.DirectoryHandle.open(directory)
      let duplicate = try opened.duplicate()
      let reopened = try opened.reopen(access: .listDirectory)
      try reopened.close()
      try duplicate.close()
      try opened.close()
    }
  }

  func testAdoptionRejectsSentinels() {
    let fromNull = Win32.FileHandle(unsafelyAdopting: nil)
    XCTAssertTrue(fromNull == nil)
    let fromInvalid = Win32.FileHandle(unsafelyAdopting: INVALID_HANDLE_VALUE)
    XCTAssertTrue(fromInvalid == nil)
    let directoryFromNull = Win32.DirectoryHandle(unsafelyAdopting: nil)
    XCTAssertTrue(directoryFromNull == nil)
    let directoryFromInvalid = Win32.DirectoryHandle(unsafelyAdopting: INVALID_HANDLE_VALUE)
    XCTAssertTrue(directoryFromInvalid == nil)
  }

  func testRelinquish() throws {
    try withTemporaryFilePath(basename: "testRelinquish") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      let raw = file.relinquish()
      // The handle is still open, and ours to close.
      XCTAssertEqual(try win32RawWrite(raw, [1, 2]).get(), 2)
      XCTAssertTrue(CloseHandle(raw))
      let adopted = Win32.FileHandle(unsafelyAdopting: try openRaw(path))!
      try adopted.close()
    }
  }

  func testDuplicateAndReopen() throws {
    try withTemporaryFilePath(basename: "testDuplicateAndReopen") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)

      // The same access as the original, which can write.
      let duplicate = try file.duplicate()
      let duplicateRaw = duplicate.unsafeRawHandle
      XCTAssertEqual(try win32RawWrite(duplicateRaw, [1, 2, 3]).get(), 3)

      // Narrower access.
      let readOnly = try file.duplicate(access: .genericRead)
      let readOnlyRaw = readOnly.unsafeRawHandle
      XCTAssertThrowsWin32Error(.accessDenied) { try win32RawWrite(readOnlyRaw, [4]).get() }

      let reopened = try file.reopen(access: .readData)
      let reopenedRaw = reopened.unsafeRawHandle
      XCTAssertThrowsWin32Error(.accessDenied) { try win32RawWrite(reopenedRaw, [4]).get() }

      try reopened.close()
      try readOnly.close()
      try duplicate.close()
      try file.close()
      XCTAssertEqual(win32RawContents(of: path), [1, 2, 3])
    }
  }

  func testInheritance() throws {
    try withTemporaryFilePath(basename: "testInheritance") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericRead, disposition: .createNew)
      let initially = try file.isInheritable()
      XCTAssertFalse(initially)
      try file.setInheritable(true)
      let afterSetting = try file.isInheritable()
      XCTAssertTrue(afterSetting)
      try file.setInheritable(false)
      let afterClearing = try file.isInheritable()
      XCTAssertFalse(afterClearing)

      let inheritable = try Win32.FileHandle.open(path, access: .genericRead, inheritable: true)
      let opened = try inheritable.isInheritable()
      XCTAssertTrue(opened)
      let duplicate = try inheritable.duplicate()
      let duplicated = try duplicate.isInheritable()
      XCTAssertFalse(duplicated)
      let inheritableDuplicate = try file.duplicate(inheritable: true)
      let duplicatedInheritable = try inheritableDuplicate.isInheritable()
      XCTAssertTrue(duplicatedInheritable)

      let directoryHandle = try Win32.DirectoryHandle.open(directory, inheritable: true)
      let directoryInheritable = try directoryHandle.isInheritable()
      XCTAssertTrue(directoryInheritable)
      try directoryHandle.setInheritable(false)
      let directoryCleared = try directoryHandle.isInheritable()
      XCTAssertFalse(directoryCleared)
    }
  }

  func testSecurityDescriptor() throws {
    try withTemporaryFilePath(basename: "testSecurityDescriptor") { directory in
      // Everyone gets all access, so the test can still delete the file.
      let descriptor: Win32.SecurityDescriptor? =
        try Win32.SecurityDescriptor(sddl: "D:(A;;GA;;;WD)")
      let path = directory.appending("file.txt")
      try Win32.FileHandle.open(
        path, access: .genericWrite, disposition: .createNew, securityDescriptor: descriptor
      ).close()
      XCTAssertTrue(win32RawExists(path))

      do {
        _ = try Win32.SecurityDescriptor(sddl: "not SDDL")
        XCTFail("parsed an invalid SDDL string")
      } catch {
        let error = error as? Win32.Error
        XCTAssertNotNil(error)
        XCTAssertNotEqual(error, .success)
      }
    }
  }

  func testTemplateFile() throws {
    try withTemporaryFilePath(basename: "testTemplateFile") { directory in
      let templatePath = directory.appending("template.txt")
      let template: Win32.FileHandle? = try Win32.FileHandle.open(
        templatePath, access: .genericRead, disposition: .createNew, attributes: .hidden)
      let path = directory.appending("file.txt")
      try Win32.FileHandle.open(
        path, access: .genericWrite, disposition: .createNew, templateFile: template
      ).close()
      let attributes = path.withPlatformString { GetFileAttributesW($0) }
      XCTAssertNotEqual(attributes & DWORD(WinSDK.FILE_ATTRIBUTE_HIDDEN), 0)
    }
  }

  func testDevicePaths() throws {
    // Both are passed through: "NUL" resolves to \\.\NUL.
    try Win32.FileHandle.open("NUL", access: .genericWrite).close()
    try Win32.FileHandle.open("\\\\.\\NUL", access: .genericWrite).close()
  }

  func testLongAndVerbatimPaths() throws {
    try withTemporaryFilePath(basename: "testLongPaths") { directory in
      // A directory whose path is longer than MAX_PATH, created one level at a
      // time through \\?\ paths.
      var path = directory
      while path.string.utf16.count <= _win32MaxPath {
        path = path.appending(String(repeating: "d", count: 50))
        let created = ("\\\\?\\" + path.string).withCString(encodedAs: UTF16.self) {
          CreateDirectoryW($0, nil)
        }
        XCTAssertTrue(created)
      }
      let file = path.appending("file.txt")
      // The canonicalized path gets the \\?\ prefix.
      try Win32.FileHandle.open(file, access: .genericWrite, disposition: .createNew).close()
      // A \\?\ path is used as it is.
      try Win32.FileHandle.open(FilePath("\\\\?\\" + file.string), access: .genericRead).close()
    }
  }

  // MARK: - Bridging with FileDescriptor

  func testAdoptingIntoADescriptor() throws {
    try withTemporaryFilePath(basename: "testAdopting") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(
        path, access: [.genericRead, .genericWrite], disposition: .createNew)
      let descriptor = try FileDescriptor(adopting: file)
      let written = try Array("abc".utf8).withUnsafeBytes { try descriptor.write($0) }
      XCTAssertEqual(written, 3)
      // The descriptor owns the handle, and closing it closes the handle.
      try descriptor.close()
      try Win32.FileHandle.open(path, access: .genericRead, shareMode: []).close()
      XCTAssertEqual(win32RawContents(of: path), Array("abc".utf8))
    }
  }

  func testTextTranslation() throws {
    try withTemporaryFilePath(basename: "testTextTranslation") { directory in
      let path = directory.appending("file.txt")
      let descriptor = try FileDescriptor(
        adopting: try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew),
        translation: .text)
      _ = try Array("a\nb".utf8).withUnsafeBytes { try descriptor.write($0) }
      try descriptor.close()
      XCTAssertEqual(win32RawContents(of: path), Array("a\r\nb".utf8))
    }
  }

  func testWideTextTranslation() throws {
    try withTemporaryFilePath(basename: "testWideTextTranslation") { directory in
      let path = directory.appending("file.txt")
      let descriptor = try FileDescriptor(
        adopting: try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew),
        translation: .wideText)
      // "a\n" in UTF-16. In a binary descriptor, the newline would stay as it
      // is; `_setmode` makes the descriptor expand it, in UTF-16.
      let units: [UInt16] = [0x61, 0x0A]
      _ = try units.withUnsafeBytes { try descriptor.write($0) }
      try descriptor.close()
      XCTAssertEqual(win32RawContents(of: path), [0x61, 0x00, 0x0D, 0x00, 0x0A, 0x00])
    }
  }

  func testAppendingDescriptor() throws {
    try withTemporaryFilePath(basename: "testAppendingDescriptor") { directory in
      let path = directory.appending("file.txt")
      let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
      let raw = file.unsafeRawHandle
      XCTAssertEqual(try win32RawWrite(raw, Array("abc".utf8)).get(), 3)
      let descriptor = try FileDescriptor(adopting: file, append: true)
      try descriptor.seek(offset: 0, from: .start)
      _ = try Array("de".utf8).withUnsafeBytes { try descriptor.write($0) }
      try descriptor.close()
      XCTAssertEqual(win32RawContents(of: path), Array("abcde".utf8))
    }
  }

  func testAdoptingAnUnclassifiedHandleFails() {
    // An event is no file: GetFileType reports FILE_TYPE_UNKNOWN.
    let event = Win32.FileHandle(unsafelyAdopting: CreateEventW(nil, true, false, nil))!
    do {
      _ = try FileDescriptor(adopting: event)
      XCTFail("adopted an event")
    } catch {
      XCTAssertEqual(error, .invalidArgument)
    }
  }

  func testLendingADescriptorsHandle() throws {
    try withTemporaryFilePath(basename: "testLending") { directory in
      let path = directory.appending("file.txt")
      let descriptor = try FileDescriptor.open(
        path, .readWrite, options: [.create], permissions: .ownerReadWrite)
      let written = try descriptor.withWin32HandleIfAvailable { handle in
        try win32RawWrite(handle.unsafeRawHandle, Array("xyz".utf8)).get()
      }
      XCTAssertEqual(written, 3)
      // The descriptor still owns the handle, which shares its file pointer.
      try descriptor.seek(offset: 0, from: .start)
      var buffer = [UInt8](repeating: 0, count: 8)
      let read = try buffer.withUnsafeMutableBytes { try descriptor.read(into: $0) }
      XCTAssertEqual(Array(buffer[..<read]), Array("xyz".utf8))
      try descriptor.close()
    }
  }

  func testLendingFromInvalidDescriptors() {
    // `_get_osfhandle` would call the invalid parameter handler, which
    // terminates the process by default, for each of these.
    for number: CInt in [-1, 12345] {
      let called = FileDescriptor(rawValue: number).withWin32HandleIfAvailable { _ in true }
      XCTAssertNil(called, "descriptor \(number)")
    }
  }

  #if ENABLE_MOCKING
  func testAdoptingPassesTheCRuntimeFlags() throws {
    try withTemporaryFilePath(basename: "testAdoptingFlags") { directory in
      let path = directory.appending("file.txt")
      try MockingDriver.withMockingEnabled { mocking in
        // CreateFileW and GetFileType aren't mocked.
        let file = try Win32.FileHandle.open(path, access: .genericWrite, disposition: .createNew)
        let raw = file.unsafeRawHandle
        let descriptor = try FileDescriptor(adopting: file, translation: .wideText, append: true)
        // The mock took nothing, so the handle is still open, and ours.
        XCTAssertEqual(descriptor.rawValue, 0)
        let open = mocking.trace.dequeue()
        XCTAssertEqual(open?.name, "_open_osfhandle")
        let openArguments: [AnyHashable] = [Int(bitPattern: raw), _O_BINARY | _O_APPEND]
        XCTAssertEqual(open?.arguments, openArguments)
        let setMode = mocking.trace.dequeue()
        XCTAssertEqual(setMode?.name, "_setmode")
        let setModeArguments: [AnyHashable] = [CInt(0), _O_WTEXT]
        XCTAssertEqual(setMode?.arguments, setModeArguments)
        XCTAssertTrue(CloseHandle(raw))
      }
    }
  }
  #endif
}

/// Opens `path` with raw Win32 calls, for adopting.
private func openRaw(_ path: FilePath) throws -> HANDLE {
  try path.withPlatformString { path in
    let handle = CreateFileW(
      path, DWORD(WinSDK.GENERIC_READ), DWORD(WinSDK.FILE_SHARE_READ), nil,
      DWORD(WinSDK.OPEN_EXISTING), 0, nil)
    guard let handle, handle != INVALID_HANDLE_VALUE else {
      throw Win32.Error(GetLastError())
    }
    return handle
  }
}

#endif // os(Windows)
