/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt
import WinSDK

// The only code that calls these C functions. Win32 functions report failure
// through their return value and GetLastError rather than -1 and errno, so,
// like the Win32 calls in WindowsSyscallAdapters.swift, they have no mock
// hook. The C runtime calls report -1 and errno, and have one.

// MARK: - Errors

// The variadic `Arguments` parameter is always NULL here, as
// FORMAT_MESSAGE_IGNORE_INSERTS requires.
internal func system_FormatMessageW(
  _ dwFlags: DWORD,
  _ lpSource: UnsafeRawPointer?,
  _ dwMessageId: DWORD,
  _ dwLanguageId: DWORD,
  _ lpBuffer: UnsafeMutablePointer<WCHAR>?,
  _ nSize: DWORD
) -> DWORD {
  FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, nil)
}

internal func system_LocalFree(_ hMem: UnsafeMutableRawPointer?) -> HLOCAL? {
  LocalFree(hMem)
}

// MARK: - Handles

internal func system_CloseHandle(_ hObject: HANDLE) -> Bool {
  CloseHandle(hObject)
}

internal func system_CreateFileW(
  _ lpFileName: UnsafePointer<WCHAR>,
  _ dwDesiredAccess: DWORD,
  _ dwShareMode: DWORD,
  _ lpSecurityAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES>?,
  _ dwCreationDisposition: DWORD,
  _ dwFlagsAndAttributes: DWORD,
  _ hTemplateFile: HANDLE?
) -> HANDLE? {
  CreateFileW(
    lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
    dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
}

internal func system_ReOpenFile(
  _ hOriginalFile: HANDLE,
  _ dwDesiredAccess: DWORD,
  _ dwShareMode: DWORD,
  _ dwFlagsAndAttributes: DWORD
) -> HANDLE? {
  ReOpenFile(hOriginalFile, dwDesiredAccess, dwShareMode, dwFlagsAndAttributes)
}

internal func system_GetCurrentProcess() -> HANDLE {
  GetCurrentProcess()
}

internal func system_DuplicateHandle(
  _ hSourceProcessHandle: HANDLE,
  _ hSourceHandle: HANDLE,
  _ hTargetProcessHandle: HANDLE,
  _ lpTargetHandle: UnsafeMutablePointer<HANDLE?>,
  _ dwDesiredAccess: DWORD,
  _ bInheritHandle: Bool,
  _ dwOptions: DWORD
) -> Bool {
  DuplicateHandle(
    hSourceProcessHandle, hSourceHandle, hTargetProcessHandle, lpTargetHandle,
    dwDesiredAccess, bInheritHandle, dwOptions)
}

internal func system_GetHandleInformation(
  _ hObject: HANDLE, _ lpdwFlags: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetHandleInformation(hObject, lpdwFlags)
}

internal func system_SetHandleInformation(
  _ hObject: HANDLE, _ dwMask: DWORD, _ dwFlags: DWORD
) -> Bool {
  SetHandleInformation(hObject, dwMask, dwFlags)
}

internal func system_GetFileType(_ hFile: HANDLE) -> DWORD {
  GetFileType(hFile)
}

internal func system_GetFileInformationByHandleEx(
  _ hFile: HANDLE,
  _ FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
  _ lpFileInformation: UnsafeMutableRawPointer,
  _ dwBufferSize: DWORD
) -> Bool {
  GetFileInformationByHandleEx(hFile, FileInformationClass, lpFileInformation, dwBufferSize)
}

internal func system_GetFullPathNameW(
  _ lpFileName: UnsafePointer<WCHAR>,
  _ nBufferLength: DWORD,
  _ lpBuffer: UnsafeMutablePointer<WCHAR>?,
  _ lpFilePart: UnsafeMutablePointer<LPWSTR?>?
) -> DWORD {
  GetFullPathNameW(lpFileName, nBufferLength, lpBuffer, lpFilePart)
}

internal func system_PathAllocCanonicalize(
  _ pszPathIn: UnsafePointer<WCHAR>,
  _ dwFlags: ULONG,
  _ ppszPathOut: UnsafeMutablePointer<PWSTR?>
) -> HRESULT {
  PathAllocCanonicalize(pszPathIn, dwFlags, ppszPathOut)
}

internal func system_ConvertStringSecurityDescriptorToSecurityDescriptorW(
  _ StringSecurityDescriptor: UnsafePointer<WCHAR>,
  _ StringSDRevision: DWORD,
  _ SecurityDescriptor: UnsafeMutablePointer<PSECURITY_DESCRIPTOR?>,
  _ SecurityDescriptorSize: UnsafeMutablePointer<ULONG>?
) -> Bool {
  ConvertStringSecurityDescriptorToSecurityDescriptorW(
    StringSecurityDescriptor, StringSDRevision, SecurityDescriptor,
    SecurityDescriptorSize)
}

internal func system_GetModuleHandleW(_ lpModuleName: UnsafePointer<WCHAR>?) -> HMODULE? {
  GetModuleHandleW(lpModuleName)
}

internal func system_GetProcAddress(
  _ hModule: HMODULE, _ lpProcName: UnsafePointer<CChar>
) -> FARPROC? {
  GetProcAddress(hModule, lpProcName)
}

internal func system__get_osfhandle(_ fd: CInt) -> intptr_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockInt(fd) }
#endif
  return _get_osfhandle(fd)
}

internal func system__open_osfhandle(_ osfhandle: intptr_t, _ flags: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(osfhandle, flags) }
#endif
  return _open_osfhandle(osfhandle, flags)
}

internal func system__setmode(_ fd: CInt, _ mode: CInt) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(fd, mode) }
#endif
  return _setmode(fd, mode)
}

// MARK: - File I/O

internal func system_ReadFile(
  _ hFile: HANDLE,
  _ lpBuffer: UnsafeMutableRawPointer?,
  _ nNumberOfBytesToRead: DWORD,
  _ lpNumberOfBytesRead: UnsafeMutablePointer<DWORD>,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>?
) -> Bool {
  ReadFile(hFile, lpBuffer, nNumberOfBytesToRead, lpNumberOfBytesRead, lpOverlapped)
}

internal func system_WriteFile(
  _ hFile: HANDLE,
  _ lpBuffer: UnsafeRawPointer?,
  _ nNumberOfBytesToWrite: DWORD,
  _ lpNumberOfBytesWritten: UnsafeMutablePointer<DWORD>,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>?
) -> Bool {
  WriteFile(hFile, lpBuffer, nNumberOfBytesToWrite, lpNumberOfBytesWritten, lpOverlapped)
}

internal func system_SetFilePointerEx(
  _ hFile: HANDLE,
  _ liDistanceToMove: LARGE_INTEGER,
  _ lpNewFilePointer: UnsafeMutablePointer<LARGE_INTEGER>?,
  _ dwMoveMethod: DWORD
) -> Bool {
  SetFilePointerEx(hFile, liDistanceToMove, lpNewFilePointer, dwMoveMethod)
}

internal func system_FlushFileBuffers(_ hFile: HANDLE) -> Bool {
  FlushFileBuffers(hFile)
}

internal func system_GetFileSizeEx(
  _ hFile: HANDLE, _ lpFileSize: UnsafeMutablePointer<LARGE_INTEGER>
) -> Bool {
  GetFileSizeEx(hFile, lpFileSize)
}

internal func system_SetEndOfFile(_ hFile: HANDLE) -> Bool {
  SetEndOfFile(hFile)
}

internal func system_SetFileInformationByHandle(
  _ hFile: HANDLE,
  _ FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
  _ lpFileInformation: UnsafeMutableRawPointer,
  _ dwBufferSize: DWORD
) -> Bool {
  SetFileInformationByHandle(hFile, FileInformationClass, lpFileInformation, dwBufferSize)
}

// MARK: - Byte-range locking

internal func system_LockFileEx(
  _ hFile: HANDLE,
  _ dwFlags: DWORD,
  _ dwReserved: DWORD,
  _ nNumberOfBytesToLockLow: DWORD,
  _ nNumberOfBytesToLockHigh: DWORD,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>
) -> Bool {
  LockFileEx(
    hFile, dwFlags, dwReserved, nNumberOfBytesToLockLow, nNumberOfBytesToLockHigh,
    lpOverlapped)
}

internal func system_UnlockFileEx(
  _ hFile: HANDLE,
  _ dwReserved: DWORD,
  _ nNumberOfBytesToUnlockLow: DWORD,
  _ nNumberOfBytesToUnlockHigh: DWORD,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>
) -> Bool {
  UnlockFileEx(
    hFile, dwReserved, nNumberOfBytesToUnlockLow, nNumberOfBytesToUnlockHigh, lpOverlapped)
}

// MARK: - Volume information

internal func system_GetVolumeInformationByHandleW(
  _ hFile: HANDLE,
  _ lpVolumeNameBuffer: UnsafeMutablePointer<WCHAR>?,
  _ nVolumeNameSize: DWORD,
  _ lpVolumeSerialNumber: UnsafeMutablePointer<DWORD>?,
  _ lpMaximumComponentLength: UnsafeMutablePointer<DWORD>?,
  _ lpFileSystemFlags: UnsafeMutablePointer<DWORD>?,
  _ lpFileSystemNameBuffer: UnsafeMutablePointer<WCHAR>?,
  _ nFileSystemNameSize: DWORD
) -> Bool {
  GetVolumeInformationByHandleW(
    hFile, lpVolumeNameBuffer, nVolumeNameSize, lpVolumeSerialNumber,
    lpMaximumComponentLength, lpFileSystemFlags, lpFileSystemNameBuffer,
    nFileSystemNameSize)
}

// MARK: - Final path name

internal func system_GetFinalPathNameByHandleW(
  _ hFile: HANDLE,
  _ lpszFilePath: UnsafeMutablePointer<WCHAR>?,
  _ cchFilePath: DWORD,
  _ dwFlags: DWORD
) -> DWORD {
  GetFinalPathNameByHandleW(hFile, lpszFilePath, cchFilePath, dwFlags)
}

#endif // os(Windows)
