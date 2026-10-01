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

// MARK: - Processes

internal func system_GetCurrentProcessId() -> DWORD {
  GetCurrentProcessId()
}

internal func system_OpenProcess(
  _ dwDesiredAccess: DWORD, _ bInheritHandle: Bool, _ dwProcessId: DWORD
) -> HANDLE? {
  OpenProcess(dwDesiredAccess, bInheritHandle, dwProcessId)
}

internal func system_GetProcessId(_ Process: HANDLE) -> DWORD {
  GetProcessId(Process)
}

internal func system_GetExitCodeProcess(
  _ hProcess: HANDLE, _ lpExitCode: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetExitCodeProcess(hProcess, lpExitCode)
}

internal func system_TerminateProcess(_ hProcess: HANDLE, _ uExitCode: UINT) -> Bool {
  TerminateProcess(hProcess, uExitCode)
}

internal func system_WaitForSingleObject(_ hHandle: HANDLE, _ dwMilliseconds: DWORD) -> DWORD {
  WaitForSingleObject(hHandle, dwMilliseconds)
}

// MARK: - Threads

internal func system_GetCurrentThread() -> HANDLE {
  GetCurrentThread()
}

internal func system_GetCurrentThreadId() -> DWORD {
  GetCurrentThreadId()
}

internal func system_OpenThread(
  _ dwDesiredAccess: DWORD, _ bInheritHandle: Bool, _ dwThreadId: DWORD
) -> HANDLE? {
  OpenThread(dwDesiredAccess, bInheritHandle, dwThreadId)
}

internal func system_GetThreadId(_ Thread: HANDLE) -> DWORD {
  GetThreadId(Thread)
}

internal func system_GetExitCodeThread(
  _ hThread: HANDLE, _ lpExitCode: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetExitCodeThread(hThread, lpExitCode)
}

internal func system_ResumeThread(_ hThread: HANDLE) -> DWORD {
  ResumeThread(hThread)
}

internal func system_SuspendThread(_ hThread: HANDLE) -> DWORD {
  SuspendThread(hThread)
}

// MARK: - Creating processes

internal func system_CreateProcessW(
  _ lpApplicationName: UnsafePointer<WCHAR>?,
  _ lpCommandLine: UnsafeMutablePointer<WCHAR>?,
  _ lpProcessAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES>?,
  _ lpThreadAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES>?,
  _ bInheritHandles: Bool,
  _ dwCreationFlags: DWORD,
  _ lpEnvironment: UnsafeMutableRawPointer?,
  _ lpCurrentDirectory: UnsafePointer<WCHAR>?,
  _ lpStartupInfo: UnsafeMutablePointer<STARTUPINFOW>,
  _ lpProcessInformation: UnsafeMutablePointer<PROCESS_INFORMATION>
) -> Bool {
  CreateProcessW(
    lpApplicationName, lpCommandLine, lpProcessAttributes, lpThreadAttributes,
    bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, lpStartupInfo,
    lpProcessInformation)
}

internal func system_InitializeProcThreadAttributeList(
  _ lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST?,
  _ dwAttributeCount: DWORD,
  _ dwFlags: DWORD,
  _ lpSize: UnsafeMutablePointer<SIZE_T>
) -> Bool {
  InitializeProcThreadAttributeList(lpAttributeList, dwAttributeCount, dwFlags, lpSize)
}

internal func system_UpdateProcThreadAttribute(
  _ lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
  _ dwFlags: DWORD,
  _ Attribute: DWORD_PTR,
  _ lpValue: UnsafeMutableRawPointer,
  _ cbSize: SIZE_T
) -> Bool {
  UpdateProcThreadAttribute(lpAttributeList, dwFlags, Attribute, lpValue, cbSize, nil, nil)
}

internal func system_DeleteProcThreadAttributeList(
  _ lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST
) {
  DeleteProcThreadAttributeList(lpAttributeList)
}

internal func system_GetStdHandle(_ nStdHandle: DWORD) -> HANDLE? {
  GetStdHandle(nStdHandle)
}

internal func system_CompareStringOrdinal(
  _ lpString1: UnsafePointer<WCHAR>,
  _ cchCount1: CInt,
  _ lpString2: UnsafePointer<WCHAR>,
  _ cchCount2: CInt,
  _ bIgnoreCase: Bool
) -> CInt {
  CompareStringOrdinal(lpString1, cchCount1, lpString2, cchCount2, bIgnoreCase)
}

// MARK: - Clocks and sleeping

internal func system_GetSystemTimePreciseAsFileTime(
  _ lpSystemTimeAsFileTime: UnsafeMutablePointer<FILETIME>
) {
  GetSystemTimePreciseAsFileTime(lpSystemTimeAsFileTime)
}

internal func system_GetSystemTimeAsFileTime(
  _ lpSystemTimeAsFileTime: UnsafeMutablePointer<FILETIME>
) {
  GetSystemTimeAsFileTime(lpSystemTimeAsFileTime)
}

internal func system_GetTickCount64() -> ULONGLONG {
  GetTickCount64()
}

internal func system_QueryInterruptTimePrecise(
  _ lpInterruptTimePrecise: UnsafeMutablePointer<ULONGLONG>
) {
  QueryInterruptTimePrecise(lpInterruptTimePrecise)
}

internal func system_QueryUnbiasedInterruptTimePrecise(
  _ lpUnbiasedInterruptTimePrecise: UnsafeMutablePointer<ULONGLONG>
) {
  QueryUnbiasedInterruptTimePrecise(lpUnbiasedInterruptTimePrecise)
}

internal func system_QueryPerformanceCounter(
  _ lpPerformanceCount: UnsafeMutablePointer<LARGE_INTEGER>
) -> Bool {
  QueryPerformanceCounter(lpPerformanceCount)
}

internal func system_QueryPerformanceFrequency(
  _ lpFrequency: UnsafeMutablePointer<LARGE_INTEGER>
) -> Bool {
  QueryPerformanceFrequency(lpFrequency)
}

internal func system_Sleep(_ dwMilliseconds: DWORD) {
  Sleep(dwMilliseconds)
}

// MARK: - Locks and condition variables

internal func system_InitializeSRWLock(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) {
  InitializeSRWLock(SRWLock)
}

internal func system_AcquireSRWLockExclusive(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) {
  AcquireSRWLockExclusive(SRWLock)
}

internal func system_AcquireSRWLockShared(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) {
  AcquireSRWLockShared(SRWLock)
}

internal func system_TryAcquireSRWLockExclusive(
  _ SRWLock: UnsafeMutablePointer<SRWLOCK>
) -> BOOLEAN {
  TryAcquireSRWLockExclusive(SRWLock)
}

internal func system_TryAcquireSRWLockShared(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) -> BOOLEAN {
  TryAcquireSRWLockShared(SRWLock)
}

internal func system_ReleaseSRWLockExclusive(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) {
  ReleaseSRWLockExclusive(SRWLock)
}

internal func system_ReleaseSRWLockShared(_ SRWLock: UnsafeMutablePointer<SRWLOCK>) {
  ReleaseSRWLockShared(SRWLock)
}

internal func system_InitializeConditionVariable(
  _ ConditionVariable: UnsafeMutablePointer<CONDITION_VARIABLE>
) {
  InitializeConditionVariable(ConditionVariable)
}

internal func system_SleepConditionVariableSRW(
  _ ConditionVariable: UnsafeMutablePointer<CONDITION_VARIABLE>,
  _ SRWLock: UnsafeMutablePointer<SRWLOCK>,
  _ dwMilliseconds: DWORD,
  _ Flags: ULONG
) -> Bool {
  SleepConditionVariableSRW(ConditionVariable, SRWLock, dwMilliseconds, Flags)
}

internal func system_WakeConditionVariable(
  _ ConditionVariable: UnsafeMutablePointer<CONDITION_VARIABLE>
) {
  WakeConditionVariable(ConditionVariable)
}

internal func system_WakeAllConditionVariable(
  _ ConditionVariable: UnsafeMutablePointer<CONDITION_VARIABLE>
) {
  WakeAllConditionVariable(ConditionVariable)
}

// MARK: - Consoles

internal func system_GetConsoleMode(
  _ hConsoleHandle: HANDLE, _ lpMode: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetConsoleMode(hConsoleHandle, lpMode)
}

internal func system_SetConsoleMode(_ hConsoleHandle: HANDLE, _ dwMode: DWORD) -> Bool {
  SetConsoleMode(hConsoleHandle, dwMode)
}

internal func system_GetConsoleScreenBufferInfo(
  _ hConsoleOutput: HANDLE,
  _ lpConsoleScreenBufferInfo: UnsafeMutablePointer<CONSOLE_SCREEN_BUFFER_INFO>
) -> Bool {
  GetConsoleScreenBufferInfo(hConsoleOutput, lpConsoleScreenBufferInfo)
}

internal func system_SetConsoleCtrlHandler(_ HandlerRoutine: PHANDLER_ROUTINE?, _ Add: Bool) -> Bool {
  SetConsoleCtrlHandler(HandlerRoutine, Add)
}

// MARK: - Directories and paths

internal func system__wgetcwd(
  _ buffer: UnsafeMutablePointer<WCHAR>, _ size: CInt
) -> UnsafeMutablePointer<WCHAR>? {
#if ENABLE_MOCKING
  if mockingEnabled {
    guard _mock(buffer, size) == 0 else { return nil }
    buffer.initialize(to: 0)
    return buffer
  }
#endif
  return _wgetcwd(buffer, size)
}

internal func system__wchdir(_ path: UnsafePointer<WCHAR>) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock(path: path) }
#endif
  return _wchdir(path)
}

internal func system_GetModuleFileNameW(
  _ hModule: HMODULE?, _ lpFilename: UnsafeMutablePointer<WCHAR>, _ nSize: DWORD
) -> DWORD {
  GetModuleFileNameW(hModule, lpFilename, nSize)
}

internal func system_GetTempPathW(
  _ nBufferLength: DWORD, _ lpBuffer: UnsafeMutablePointer<WCHAR>
) -> DWORD {
  GetTempPathW(nBufferLength, lpBuffer)
}

internal func system_GetWindowsDirectoryW(
  _ lpBuffer: UnsafeMutablePointer<WCHAR>, _ uSize: UINT
) -> UINT {
  GetWindowsDirectoryW(lpBuffer, uSize)
}

internal func system_GetSystemDirectoryW(
  _ lpBuffer: UnsafeMutablePointer<WCHAR>, _ uSize: UINT
) -> UINT {
  GetSystemDirectoryW(lpBuffer, uSize)
}

#endif // os(Windows)
