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

/// Whether `path` names a directory, by GetFileAttributesW.
private func isDirectory(_ path: FilePath) -> Bool {
  let attributes = path.withPlatformString { GetFileAttributesW($0) }
  return attributes != INVALID_FILE_ATTRIBUTES
    && attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0
}

// Known folders, and the local heap's free. Nothing here creates a folder:
// the paths are read, and the one allocation is the test's own.
@available(System 199, *)
final class Win32KnownFoldersTests: XCTestCase {
  func testGUIDsMatchTheSDK() {
    let folders: [(Win32.KnownFolder, KNOWNFOLDERID)] = [
      (.programFiles, WinSDK.FOLDERID_ProgramFiles),
      (.programFilesX86, WinSDK.FOLDERID_ProgramFilesX86),
      (.userProgramFiles, WinSDK.FOLDERID_UserProgramFiles),
      (.programData, WinSDK.FOLDERID_ProgramData),
      (.system, WinSDK.FOLDERID_System),
      (.windows, WinSDK.FOLDERID_Windows),
      (.localAppData, WinSDK.FOLDERID_LocalAppData),
      (.roamingAppData, WinSDK.FOLDERID_RoamingAppData),
      (.profile, WinSDK.FOLDERID_Profile),
      (.userProfiles, WinSDK.FOLDERID_UserProfiles),
      (.desktop, WinSDK.FOLDERID_Desktop),
      (.documents, WinSDK.FOLDERID_Documents),
      (.downloads, WinSDK.FOLDERID_Downloads),
      (.music, WinSDK.FOLDERID_Music),
      (.pictures, WinSDK.FOLDERID_Pictures),
      (.videos, WinSDK.FOLDERID_Videos),
      (.publicFolder, WinSDK.FOLDERID_Public),
    ]
    for (folder, guid) in folders {
      XCTAssertEqual(folder, Win32.KnownFolder(rawValue: guid))
    }
    // Different folders differ, in equality and in a set.
    XCTAssertNotEqual(Win32.KnownFolder.programFiles, .programFilesX86)
    XCTAssertEqual(Set(folders.map { $0.0 }).count, folders.count)
  }

  func testOptionsMatchTheSDK() {
    XCTAssertEqual(Win32.KnownFolderOptions().rawValue, DWORD(WinSDK.KF_FLAG_DEFAULT.rawValue))
    XCTAssertEqual(Win32.KnownFolderOptions.create.rawValue, DWORD(WinSDK.KF_FLAG_CREATE.rawValue))
    XCTAssertEqual(
      Win32.KnownFolderOptions.doNotVerify.rawValue, DWORD(WinSDK.KF_FLAG_DONT_VERIFY.rawValue))
    XCTAssertEqual(
      Win32.KnownFolderOptions.defaultPath.rawValue, DWORD(WinSDK.KF_FLAG_DEFAULT_PATH.rawValue))
    XCTAssertEqual(Win32.KnownFolderOptions.noAlias.rawValue, DWORD(WinSDK.KF_FLAG_NO_ALIAS.rawValue))
  }

  func testPaths() throws {
    // The system and Windows directories are the ones their functions give,
    // whose case Windows doesn't promise.
    let system = try Win32.KnownFolder.system.path()
    XCTAssertEqual(system.string.lowercased(), try Win32.systemDirectory().string.lowercased())
    let windows = try Win32.KnownFolder.windows.path()
    XCTAssertEqual(windows.string.lowercased(), try Win32.windowsDirectory().string.lowercased())
    // Every Windows has Program Files, and every user a profile.
    XCTAssertTrue(isDirectory(try Win32.KnownFolder.programFiles.path()))
    XCTAssertTrue(isDirectory(try Win32.KnownFolder.profile.path()))
  }

  func testAGUIDThatNamesNoFolder() {
    let unknown = Win32.KnownFolder(rawValue: KNOWNFOLDERID(
      Data1: 0x0123_4567, Data2: 0x89AB, Data3: 0xCDEF, Data4: (1, 2, 3, 4, 5, 6, 7, 8)))
    XCTAssertThrowsError(try unknown.path()) { error in
      XCTAssertNotNil(error as? Win32.Error, "\(error)")
    }
  }

  func testFreeingLocalMemory() throws {
    // LMEM_FIXED, 0: a block whose handle is its address.
    let block = try XCTUnwrap(LocalAlloc(0, 64))
    Win32.freeLocalMemory(block)
    Win32.freeLocalMemory(nil)
  }

  func testMaxPathLength() {
    XCTAssertEqual(Win32.maxPathLength, Int(WinSDK.MAX_PATH))
  }
}

#endif // os(Windows)
