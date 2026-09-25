/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// SIMULATED C API, simulated configuration only: Win32 C functions that no
// draft wraps, which samples call through `unsafeRawHandle`, as real code
// would through WinSDK. Declared with their C names and shapes; simulated
// with fstat.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#endif

/// The C `BY_HANDLE_FILE_INFORMATION` structure. (Its times are left out.)
struct BY_HANDLE_FILE_INFORMATION {
  var dwFileAttributes: DWORD = 0
  var dwVolumeSerialNumber: DWORD = 0
  var nFileSizeHigh: DWORD = 0
  var nFileSizeLow: DWORD = 0
  var nNumberOfLinks: DWORD = 0
  var nFileIndexHigh: DWORD = 0
  var nFileIndexLow: DWORD = 0
}

nonisolated(unsafe) private var lastError: DWORD = 0

/// The C function `GetLastError`.
func GetLastError() -> DWORD { lastError }

/// The C function `GetFileInformationByHandle`: the file's volume, index
/// (the counterpart of an inode number), size, and link count. SYS-0010
/// leaves querying file information to a future proposal.
func GetFileInformationByHandle(
  _ hFile: HANDLE, _ lpFileInformation: UnsafeMutablePointer<BY_HANDLE_FILE_INFORMATION>
) -> Bool {
  guard let descriptor = Win32Simulation.descriptor(of: hFile) else {
    lastError = Win32.Error.invalidHandle.rawValue
    return false
  }
  var status = stat()
  guard fstat(descriptor, &status) == 0 else {
    lastError = Win32Simulation.error(from: Errno(rawValue: errno)).rawValue
    return false
  }
  lpFileInformation.pointee = BY_HANDLE_FILE_INFORMATION(
    dwFileAttributes: 0x20,  // FILE_ATTRIBUTE_ARCHIVE
    dwVolumeSerialNumber: DWORD(truncatingIfNeeded: status.st_dev),
    nFileSizeHigh: DWORD(truncatingIfNeeded: status.st_size >> 32),
    nFileSizeLow: DWORD(truncatingIfNeeded: status.st_size),
    nNumberOfLinks: DWORD(status.st_nlink),
    nFileIndexHigh: DWORD(truncatingIfNeeded: status.st_ino >> 32),
    nFileIndexLow: DWORD(truncatingIfNeeded: status.st_ino))
  return true
}

#endif // SIMULATE_PLATFORMS
