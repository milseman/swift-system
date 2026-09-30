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

// SYS-0015: volume information.
@available(System 199, *)
final class Win32VolumeInformationTests: XCTestCase {
  func testConstantsMatchTheSDK() {
    let flags: [(Win32.FileSystemFlags, DWORD)] = [
      (.caseSensitiveSearch, DWORD(WinSDK.FILE_CASE_SENSITIVE_SEARCH)),
      (.casePreservedNames, DWORD(WinSDK.FILE_CASE_PRESERVED_NAMES)),
      (.unicodeOnDisk, DWORD(WinSDK.FILE_UNICODE_ON_DISK)),
      (.persistentACLs, DWORD(WinSDK.FILE_PERSISTENT_ACLS)),
      (.fileCompression, DWORD(WinSDK.FILE_FILE_COMPRESSION)),
      (.volumeQuotas, DWORD(WinSDK.FILE_VOLUME_QUOTAS)),
      (.supportsSparseFiles, DWORD(WinSDK.FILE_SUPPORTS_SPARSE_FILES)),
      (.supportsReparsePoints, DWORD(WinSDK.FILE_SUPPORTS_REPARSE_POINTS)),
      (.supportsRemoteStorage, DWORD(WinSDK.FILE_SUPPORTS_REMOTE_STORAGE)),
      (.returnsCleanupResultInfo, DWORD(WinSDK.FILE_RETURNS_CLEANUP_RESULT_INFO)),
      (.supportsPOSIXUnlinkRename, DWORD(WinSDK.FILE_SUPPORTS_POSIX_UNLINK_RENAME)),
      (.supportsBypassIO, DWORD(WinSDK.FILE_SUPPORTS_BYPASS_IO)),
      (.supportsStreamSnapshots, DWORD(WinSDK.FILE_SUPPORTS_STREAM_SNAPSHOTS)),
      (.supportsCaseSensitiveDirectories, DWORD(WinSDK.FILE_SUPPORTS_CASE_SENSITIVE_DIRS)),
      (.volumeIsCompressed, DWORD(WinSDK.FILE_VOLUME_IS_COMPRESSED)),
      (.supportsObjectIDs, DWORD(WinSDK.FILE_SUPPORTS_OBJECT_IDS)),
      (.supportsEncryption, DWORD(WinSDK.FILE_SUPPORTS_ENCRYPTION)),
      (.namedStreams, DWORD(WinSDK.FILE_NAMED_STREAMS)),
      (.readOnlyVolume, DWORD(WinSDK.FILE_READ_ONLY_VOLUME)),
      (.sequentialWriteOnce, DWORD(WinSDK.FILE_SEQUENTIAL_WRITE_ONCE)),
      (.supportsTransactions, DWORD(WinSDK.FILE_SUPPORTS_TRANSACTIONS)),
      (.supportsHardLinks, DWORD(WinSDK.FILE_SUPPORTS_HARD_LINKS)),
      (.supportsExtendedAttributes, DWORD(WinSDK.FILE_SUPPORTS_EXTENDED_ATTRIBUTES)),
      (.supportsOpenByFileID, DWORD(WinSDK.FILE_SUPPORTS_OPEN_BY_FILE_ID)),
      (.supportsUSNJournal, DWORD(WinSDK.FILE_SUPPORTS_USN_JOURNAL)),
      (.supportsIntegrityStreams, DWORD(WinSDK.FILE_SUPPORTS_INTEGRITY_STREAMS)),
      (.supportsBlockRefcounting, DWORD(WinSDK.FILE_SUPPORTS_BLOCK_REFCOUNTING)),
      (.supportsSparseVDL, DWORD(WinSDK.FILE_SUPPORTS_SPARSE_VDL)),
      (.daxVolume, DWORD(WinSDK.FILE_DAX_VOLUME)),
      (.supportsGhosting, DWORD(WinSDK.FILE_SUPPORTS_GHOSTING)),
    ]
    for (flag, value) in flags {
      XCTAssertEqual(flag.rawValue, value)
    }
    // One flag per bit, in bit order, with bit 14 and bit 31 unused.
    XCTAssertEqual(flags.count, 30)
    XCTAssertEqual(flags.map(\.1), flags.map(\.1).sorted())
  }

  func testVolumeOfATemporaryFile() throws {
    try withTemporaryFilePath(basename: "testVolumeInformation") { directory in
      let file = try Win32.FileHandle.open(
        directory.appending("file.txt"), access: .genericWrite, disposition: .createNew)
      let volume = try file.volumeInformation()
      XCTAssertFalse(volume.fileSystemName.isEmpty)
      XCTAssertGreaterThan(volume.maximumComponentLength, 0)
      try file.close()

      // A directory on the same volume reports the same volume. No access
      // rights are needed.
      let directoryHandle = try Win32.DirectoryHandle.open(directory, access: [])
      let directoryVolume = try directoryHandle.volumeInformation()
      XCTAssertEqual(directoryVolume, volume)
      try directoryHandle.close()
    }
  }

  func testPipesAreOnTheNamedPipeFileSystem() throws {
    let pipe = try Win32TestPipe()
    let volume = try pipe.readEnd.volumeInformation()
    XCTAssertEqual(volume.fileSystemName, "NPFS")
  }

  func testNullDeviceHasNoVolume() throws {
    let null = try Win32.FileHandle.open("NUL", access: .genericWrite)
    XCTAssertThrowsWin32Error(.invalidFunction) { try null.volumeInformation() }
    try null.close()
  }
}

#endif // os(Windows)
