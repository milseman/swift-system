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

// Path operations by path, and deleting and renaming by handle.
@available(System 199, *)
final class Win32PathOperationsTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let move: [(Win32.MoveFileFlags, DWORD)] = [
      (.replaceExisting, DWORD(WinSDK.MOVEFILE_REPLACE_EXISTING)),
      (.copyAllowed, DWORD(WinSDK.MOVEFILE_COPY_ALLOWED)),
      (.delayUntilReboot, DWORD(WinSDK.MOVEFILE_DELAY_UNTIL_REBOOT)),
      (.writeThrough, DWORD(WinSDK.MOVEFILE_WRITE_THROUGH)),
      (.failIfNotTrackable, DWORD(WinSDK.MOVEFILE_FAIL_IF_NOT_TRACKABLE)),
    ]
    for (flag, value) in move { XCTAssertEqual(flag.rawValue, value, "\(flag)") }
    let copy: [(Win32.CopyFileFlags, DWORD)] = [
      (.failIfExists, DWORD(WinSDK.COPY_FILE_FAIL_IF_EXISTS)),
      (.restartable, DWORD(WinSDK.COPY_FILE_RESTARTABLE)),
      (.openSourceForWrite, DWORD(WinSDK.COPY_FILE_OPEN_SOURCE_FOR_WRITE)),
      (.allowDecryptedDestination, DWORD(WinSDK.COPY_FILE_ALLOW_DECRYPTED_DESTINATION)),
      (.directory, DWORD(WinSDK.COPY_FILE_DIRECTORY)),
      (.copySymbolicLink, DWORD(WinSDK.COPY_FILE_COPY_SYMLINK)),
      (.noBuffering, DWORD(WinSDK.COPY_FILE_NO_BUFFERING)),
      (.noOffload, DWORD(WinSDK.COPY_FILE_NO_OFFLOAD)),
      (.openAndCopyReparsePoint, DWORD(WinSDK.COPY_FILE_OPEN_AND_COPY_REPARSE_POINT)),
    ]
    for (flag, value) in copy { XCTAssertEqual(flag.rawValue, value, "\(flag)") }
    let link: [(Win32.SymbolicLinkFlags, DWORD)] = [
      (.directory, DWORD(WinSDK.SYMBOLIC_LINK_FLAG_DIRECTORY)),
      (.allowUnprivilegedCreate, DWORD(WinSDK.SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)),
    ]
    for (flag, value) in link { XCTAssertEqual(flag.rawValue, value, "\(flag)") }
    let disposition: [(Win32.DispositionFlags, DWORD)] = [
      (.delete, DWORD(WinSDK.FILE_DISPOSITION_FLAG_DELETE)),
      (.posixSemantics, DWORD(WinSDK.FILE_DISPOSITION_FLAG_POSIX_SEMANTICS)),
      (.forceImageSectionCheck, DWORD(WinSDK.FILE_DISPOSITION_FLAG_FORCE_IMAGE_SECTION_CHECK)),
      (.onClose, DWORD(WinSDK.FILE_DISPOSITION_FLAG_ON_CLOSE)),
      (.ignoreReadOnlyAttribute, DWORD(WinSDK.FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE)),
    ]
    for (flag, value) in disposition { XCTAssertEqual(flag.rawValue, value, "\(flag)") }
    XCTAssertEqual(Win32.DispositionFlags().rawValue, DWORD(WinSDK.FILE_DISPOSITION_FLAG_DO_NOT_DELETE))
    let rename: [(Win32.RenameFlags, DWORD)] = [
      (.replaceIfExists, DWORD(WinSDK.FILE_RENAME_FLAG_REPLACE_IF_EXISTS)),
      (.posixSemantics, DWORD(WinSDK.FILE_RENAME_FLAG_POSIX_SEMANTICS)),
      (.suppressPinStateInheritance, DWORD(WinSDK.FILE_RENAME_FLAG_SUPPRESS_PIN_STATE_INHERITANCE)),
      (.ignoreReadOnlyAttribute, DWORD(WinSDK.FILE_RENAME_FLAG_IGNORE_READONLY_ATTRIBUTE)),
    ]
    for (flag, value) in rename { XCTAssertEqual(flag.rawValue, value, "\(flag)") }
  }

  func testDirectories() throws {
    try withTemporaryFilePath(basename: "testDirectories") { directory in
      let child = directory.appending("child")
      try Win32.createDirectory(child)
      let attributes = try Win32.fileAttributes(of: child)
      XCTAssertTrue(attributes.contains(.directory))
      XCTAssertThrowsWin32Error(.alreadyExists) { try Win32.createDirectory(child) }
      XCTAssertThrowsWin32Error(.pathNotFound) {
        try Win32.createDirectory(directory.appending("missing").appending("child"))
      }

      try makeFile(child.appending("file.txt"))
      XCTAssertThrowsWin32Error(.directoryNotEmpty) { try Win32.removeDirectory(child) }
      try Win32.deleteFile(child.appending("file.txt"))
      try Win32.removeDirectory(child)
      XCTAssertFalse(win32RawExists(child))
      XCTAssertThrowsWin32Error(.fileNotFound) { try Win32.removeDirectory(child) }
    }
  }

  func testCreatingADirectoryWithASecurityDescriptor() throws {
    try withTemporaryFilePath(basename: "testDirectorySecurity") { directory in
      // Everyone gets all access, so the test can still remove the directory.
      let descriptor: Win32.SecurityDescriptor? =
        try Win32.SecurityDescriptor(sddl: "D:P(A;OICI;GA;;;WD)")
      try Win32.createDirectory(directory.appending("private"), securityDescriptor: descriptor)
      XCTAssertTrue(win32RawExists(directory.appending("private")))
    }
  }

  func testDeletingFiles() throws {
    try withTemporaryFilePath(basename: "testDeletingFiles") { directory in
      let file = directory.appending("file.txt")
      try makeFile(file)
      try Win32.deleteFile(file)
      XCTAssertFalse(win32RawExists(file))
      XCTAssertThrowsWin32Error(.fileNotFound) { try Win32.deleteFile(file) }

      // A read-only file and a directory are refused.
      try makeFile(file)
      try Win32.setFileAttributes(.readOnly, of: file)
      XCTAssertThrowsWin32Error(.accessDenied) { try Win32.deleteFile(file) }
      try Win32.setFileAttributes([], of: file)
      try Win32.deleteFile(file)
      XCTAssertThrowsWin32Error(.accessDenied) { try Win32.deleteFile(directory) }

      // An open that doesn't share deletion blocks it.
      try makeFile(file)
      let exclusive = try Win32.FileHandle.open(file, access: .genericRead, shareMode: [.read])
      XCTAssertThrowsWin32Error(.sharingViolation) { try Win32.deleteFile(file) }
      try exclusive.close()
      try Win32.deleteFile(file)
    }
  }

  func testMovingFiles() throws {
    try withTemporaryFilePath(basename: "testMovingFiles") { directory in
      let source = directory.appending("source.txt")
      let destination = directory.appending("destination.txt")
      try makeFile(source, "first")
      try Win32.moveFile(source, to: destination)
      XCTAssertFalse(win32RawExists(source))
      XCTAssertEqual(win32RawContents(of: destination), Array("first".utf8))

      try makeFile(source, "second")
      XCTAssertThrowsWin32Error(.alreadyExists) { try Win32.moveFile(source, to: destination) }
      try Win32.moveFile(source, to: destination, flags: .replaceExisting)
      XCTAssertEqual(win32RawContents(of: destination), Array("second".utf8))

      // A directory moves too, with its contents.
      let subdirectory = directory.appending("sub")
      try Win32.createDirectory(subdirectory)
      try Win32.moveFile(destination, to: subdirectory.appending("file.txt"))
      try Win32.moveFile(subdirectory, to: directory.appending("moved"))
      XCTAssertTrue(win32RawExists(directory.appending("moved").appending("file.txt")))
    }
  }

  func testCopyingFiles() throws {
    try withTemporaryFilePath(basename: "testCopyingFiles") { directory in
      let source = directory.appending("source.txt")
      let destination = directory.appending("copy.txt")
      try makeFile(source, "contents")
      try Win32.copyFile(source, to: destination)
      XCTAssertEqual(win32RawContents(of: destination), Array("contents".utf8))
      XCTAssertTrue(win32RawExists(source))

      // A copy replaces a file, unless it's asked not to.
      try Win32.FileHandle.open(source, access: .genericWrite, disposition: .truncateExisting)
        .close()
      try Win32.copyFile(source, to: destination)
      XCTAssertEqual(win32RawContents(of: destination), [])
      XCTAssertThrowsWin32Error(.fileExists) {
        try Win32.copyFile(source, to: destination, flags: .failIfExists)
      }

      // Attributes come along.
      try Win32.setFileAttributes(.readOnly, of: source)
      try Win32.copyFile(source, to: directory.appending("readonly.txt"))
      let attributes = try Win32.fileAttributes(of: directory.appending("readonly.txt"))
      XCTAssertTrue(attributes.contains(.readOnly))
      try Win32.setFileAttributes([], of: source)
      try Win32.setFileAttributes([], of: directory.appending("readonly.txt"))
      XCTAssertThrowsWin32Error(.fileNotFound) {
        try Win32.copyFile(directory.appending("missing.txt"), to: destination)
      }
    }
  }

  func testSymbolicLinks() throws {
    try withTemporaryFilePath(basename: "testSymbolicLinks") { directory in
      let target = directory.appending("target.txt")
      try makeFile(target, "linked")
      let link = directory.appending("link.txt")
      do throws(Win32.Error) {
        try Win32.createSymbolicLink(link, to: "target.txt", flags: .allowUnprivilegedCreate)
      } catch {
        // Developer mode or an administrator is needed.
        guard error == .privilegeNotHeld else { throw error }
        throw XCTSkip("creating symbolic links needs developer mode or elevation")
      }
      // The link resolves against its own directory, and is a reparse point.
      XCTAssertEqual(win32RawContents(of: link), Array("linked".utf8))
      let attributes = try Win32.fileAttributes(of: link)
      XCTAssertTrue(attributes.contains(.reparsePoint))
      XCTAssertThrowsWin32Error(.alreadyExists) {
        try Win32.createSymbolicLink(link, to: "target.txt", flags: .allowUnprivilegedCreate)
      }

      let realDirectory = directory.appending("real")
      try Win32.createDirectory(realDirectory)
      try makeFile(realDirectory.appending("inside.txt"), "inside")
      let linkedDirectory = directory.appending("linked-directory")
      try Win32.createSymbolicLink(
        linkedDirectory, to: realDirectory, flags: [.directory, .allowUnprivilegedCreate])
      XCTAssertEqual(
        win32RawContents(of: linkedDirectory.appending("inside.txt")), Array("inside".utf8))

      // Deleting a link deletes the link alone.
      try Win32.deleteFile(link)
      try Win32.removeDirectory(linkedDirectory)
      XCTAssertTrue(win32RawExists(target))
      XCTAssertTrue(win32RawExists(realDirectory.appending("inside.txt")))
    }
  }

  func testHardLinks() throws {
    try withTemporaryFilePath(basename: "testHardLinks") { directory in
      let original = directory.appending("original.txt")
      let link = directory.appending("link.txt")
      try makeFile(original, "shared")
      try Win32.createHardLink(link, to: original)
      XCTAssertEqual(win32RawContents(of: link), Array("shared".utf8))
      let file = try Win32.FileHandle.open(link, access: [])
      let information = try file.information()
      XCTAssertEqual(information.linkCount, 2)
      try file.close()
      XCTAssertThrowsWin32Error(.alreadyExists) { try Win32.createHardLink(link, to: original) }
      XCTAssertThrowsWin32Error(.accessDenied) {
        try Win32.createHardLink(directory.appending("directory-link"), to: directory)
      }
    }
  }

  // MARK: - By handle

  func testPOSIXDeletion() throws {
    try withTemporaryFilePath(basename: "testPOSIXDeletion") { directory in
      let path = directory.appending("file.txt")
      try makeFile(path, "still readable")
      let reader = try Win32.FileHandle.open(path, access: .genericRead)
      let deleter = try Win32.FileHandle.open(path, access: .delete)
      try deleter.setDisposition([.delete, .posixSemantics])
      try deleter.close()
      // The name is gone at once, and free for a new file, while the other
      // handle still reads the old one.
      XCTAssertFalse(win32RawExists(path))
      try makeFile(path, "new")
      XCTAssertEqual(try win32ReadToEnd(reader), Array("still readable".utf8))
      try reader.close()
      XCTAssertEqual(win32RawContents(of: path), Array("new".utf8))
    }
  }

  func testDeletionOnLastClose() throws {
    try withTemporaryFilePath(basename: "testDeletionOnLastClose") { directory in
      let path = directory.appending("file.txt")
      try makeFile(path)
      let other = try Win32.FileHandle.open(path, access: .genericRead)
      let deleter = try Win32.FileHandle.open(path, access: .delete)
      try deleter.setDisposition(.delete)
      let pending = try deleter.standardInformation()
      XCTAssertTrue(pending.isDeletePending)
      try deleter.close()
      // The name stays while a handle is open, and can't be opened.
      XCTAssertThrowsWin32Error(.accessDenied) {
        try Win32.FileHandle.open(path, access: .genericRead)
      }
      try other.close()
      XCTAssertFalse(win32RawExists(path))
    }
  }

  func testClearingTheDisposition() throws {
    try withTemporaryFilePath(basename: "testClearingTheDisposition") { directory in
      let path = directory.appending("file.txt")
      try makeFile(path)
      let file = try Win32.FileHandle.open(path, access: .delete)
      try file.setDisposition(.delete)
      try file.setDisposition([])
      try file.close()
      XCTAssertTrue(win32RawExists(path))
      // Deleting needs the right.
      let reader = try Win32.FileHandle.open(path, access: .genericRead)
      XCTAssertThrowsWin32Error(.accessDenied) { try reader.setDisposition(.delete) }
      try reader.close()
    }
  }

  func testRenamingByHandle() throws {
    try withTemporaryFilePath(basename: "testRenamingByHandle") { directory in
      let path = directory.appending("file.txt")
      let renamed = directory.appending("renamed.txt")
      try makeFile(path, "moving")
      let file = try Win32.FileHandle.open(path, access: [.delete, .genericRead])
      try file.rename(to: renamed)
      XCTAssertFalse(win32RawExists(path))
      // The handle follows the file.
      let finalPath = try file.finalPath()
      XCTAssertTrue(finalPath.string.lowercased().hasSuffix("renamed.txt"), "\(finalPath)")
      try file.close()

      try makeFile(path, "replacement")
      let replacing = try Win32.FileHandle.open(path, access: .delete)
      XCTAssertThrowsWin32Error(.alreadyExists) { try replacing.rename(to: renamed) }
      // With POSIX semantics, an open destination is replaced too, and its
      // handle keeps reading the old file.
      let reader = try Win32.FileHandle.open(renamed, access: .genericRead)
      try replacing.rename(to: renamed, flags: [.replaceIfExists, .posixSemantics])
      try replacing.close()
      XCTAssertEqual(win32RawContents(of: renamed), Array("replacement".utf8))
      XCTAssertEqual(try win32ReadToEnd(reader), Array("moving".utf8))
      try reader.close()
    }
  }

  func testDirectoryHandles() throws {
    try withTemporaryFilePath(basename: "testDirectoryHandles") { directory in
      let path = directory.appending("before")
      try Win32.createDirectory(path)
      let handle = try Win32.DirectoryHandle.open(path, access: [.delete, .listDirectory])
      try handle.rename(to: directory.appending("after"))
      XCTAssertTrue(win32RawExists(directory.appending("after")))
      try handle.setDisposition([.delete, .posixSemantics])
      try handle.close()
      XCTAssertFalse(win32RawExists(directory.appending("after")))
    }
  }
}

#endif // os(Windows)
