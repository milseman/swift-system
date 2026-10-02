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

internal func system_PathCchStripPrefix(
  _ pszPath: UnsafeMutablePointer<WCHAR>, _ cchPath: Int
) -> HRESULT {
  PathCchStripPrefix(pszPath, cchPath)
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

// MARK: - Overlapped I/O

internal func system_GetOverlappedResult(
  _ hFile: HANDLE,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>,
  _ lpNumberOfBytesTransferred: UnsafeMutablePointer<DWORD>,
  _ bWait: Bool
) -> Bool {
  GetOverlappedResult(hFile, lpOverlapped, lpNumberOfBytesTransferred, bWait)
}

internal func system_GetOverlappedResultEx(
  _ hFile: HANDLE,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>,
  _ lpNumberOfBytesTransferred: UnsafeMutablePointer<DWORD>,
  _ dwMilliseconds: DWORD,
  _ bAlertable: Bool
) -> Bool {
  GetOverlappedResultEx(
    hFile, lpOverlapped, lpNumberOfBytesTransferred, dwMilliseconds, bAlertable)
}

internal func system_CancelIoEx(
  _ hFile: HANDLE, _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>?
) -> Bool {
  CancelIoEx(hFile, lpOverlapped)
}

internal func system_CreateIoCompletionPort(
  _ FileHandle: HANDLE,
  _ ExistingCompletionPort: HANDLE?,
  _ CompletionKey: UInt,
  _ NumberOfConcurrentThreads: DWORD
) -> HANDLE? {
  CreateIoCompletionPort(
    FileHandle, ExistingCompletionPort, ULONG_PTR(CompletionKey), NumberOfConcurrentThreads)
}

internal func system_PostQueuedCompletionStatus(
  _ CompletionPort: HANDLE,
  _ dwNumberOfBytesTransferred: DWORD,
  _ dwCompletionKey: UInt,
  _ lpOverlapped: UnsafeMutablePointer<OVERLAPPED>?
) -> Bool {
  PostQueuedCompletionStatus(
    CompletionPort, dwNumberOfBytesTransferred, ULONG_PTR(dwCompletionKey), lpOverlapped)
}

internal func system_GetQueuedCompletionStatus(
  _ CompletionPort: HANDLE,
  _ lpNumberOfBytesTransferred: UnsafeMutablePointer<DWORD>,
  _ lpCompletionKey: UnsafeMutablePointer<ULONG_PTR>,
  _ lpOverlapped: UnsafeMutablePointer<UnsafeMutablePointer<OVERLAPPED>?>,
  _ dwMilliseconds: DWORD
) -> Bool {
  GetQueuedCompletionStatus(
    CompletionPort, lpNumberOfBytesTransferred, lpCompletionKey, lpOverlapped, dwMilliseconds)
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

// MARK: - Ending the process

// exit and _exit never return, so they have no mock hook. macOS's C library
// declares all three too, which the qualified names keep the harness from
// calling.

internal func system_exit(_ status: CInt) -> Never {
  ucrt.exit(status)
}

internal func system__exit(_ status: CInt) -> Never {
  ucrt._exit(status)
}

// atexit returns a nonzero value, not necessarily -1, when it fails.
internal func system_atexit(_ function: @convention(c) () -> Void) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled { return _mock() }
#endif
  return ucrt.atexit(function)
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

// Starts a thread that runs `_win32ThreadStart(context)`, which
// Win32ThreadCreation.swift defines: a C function can't capture, so the
// closure travels as the argument. No mock hook, unlike the other C runtime
// calls: a mocked call would start no thread to run the closure.
internal func system__beginthreadex(
  _ security: UnsafeMutablePointer<SECURITY_ATTRIBUTES>,
  _ stackSize: UInt32,
  _ context: UnsafeMutableRawPointer,
  _ flags: UInt32
) -> UInt {
  _beginthreadex(UnsafeMutableRawPointer(security), stackSize, { context in
    _win32ThreadStart(context)
    return 0
  }, context, flags, nil)
}

internal func system_GetThreadDescription(
  _ hThread: HANDLE, _ ppszThreadDescription: UnsafeMutablePointer<PWSTR?>
) -> HRESULT {
  GetThreadDescription(hThread, ppszThreadDescription)
}

internal func system_SetThreadDescription(
  _ hThread: HANDLE, _ lpThreadDescription: UnsafePointer<WCHAR>
) -> HRESULT {
  SetThreadDescription(hThread, lpThreadDescription)
}

internal func system_SwitchToThread() -> Bool {
  SwitchToThread()
}

// MARK: - Fiber-local storage

// Allocates an index whose callback is `_win32FiberLocalDestructor`, which
// Win32FiberLocal.swift defines.
internal func system_FlsAlloc() -> DWORD {
  FlsAlloc({ value in _win32FiberLocalDestructor(value) })
}

internal func system_FlsFree(_ dwFlsIndex: DWORD) -> Bool {
  FlsFree(dwFlsIndex)
}

internal func system_FlsGetValue(_ dwFlsIndex: DWORD) -> UnsafeMutableRawPointer? {
  FlsGetValue(dwFlsIndex)
}

internal func system_FlsSetValue(_ dwFlsIndex: DWORD, _ lpFlsData: UnsafeMutableRawPointer?) -> Bool {
  FlsSetValue(dwFlsIndex, lpFlsData)
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

internal func system_InitializeCriticalSection(
  _ lpCriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>
) {
  InitializeCriticalSection(lpCriticalSection)
}

internal func system_EnterCriticalSection(
  _ lpCriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>
) {
  EnterCriticalSection(lpCriticalSection)
}

internal func system_TryEnterCriticalSection(
  _ lpCriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>
) -> Bool {
  TryEnterCriticalSection(lpCriticalSection)
}

internal func system_LeaveCriticalSection(
  _ lpCriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>
) {
  LeaveCriticalSection(lpCriticalSection)
}

internal func system_DeleteCriticalSection(
  _ lpCriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>
) {
  DeleteCriticalSection(lpCriticalSection)
}

internal func system_SleepConditionVariableCS(
  _ ConditionVariable: UnsafeMutablePointer<CONDITION_VARIABLE>,
  _ CriticalSection: UnsafeMutablePointer<CRITICAL_SECTION>,
  _ dwMilliseconds: DWORD
) -> Bool {
  SleepConditionVariableCS(ConditionVariable, CriticalSection, dwMilliseconds)
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

internal func system_SetStdHandle(_ nStdHandle: DWORD, _ hHandle: HANDLE) -> Bool {
  SetStdHandle(nStdHandle, hHandle)
}

internal func system_AttachConsole(_ dwProcessId: DWORD) -> Bool {
  AttachConsole(dwProcessId)
}

internal func system_FreeConsole() -> Bool {
  FreeConsole()
}

internal func system_AllocConsole() -> Bool {
  AllocConsole()
}

internal func system_GenerateConsoleCtrlEvent(
  _ dwCtrlEvent: DWORD, _ dwProcessGroupId: DWORD
) -> Bool {
  GenerateConsoleCtrlEvent(dwCtrlEvent, dwProcessGroupId)
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

// MARK: - Dynamic loading

internal func system_LoadLibraryExW(
  _ lpLibFileName: UnsafePointer<WCHAR>, _ hFile: HANDLE?, _ dwFlags: DWORD
) -> HMODULE? {
  LoadLibraryExW(lpLibFileName, hFile, dwFlags)
}

internal func system_FreeLibrary(_ hLibModule: HMODULE) -> Bool {
  FreeLibrary(hLibModule)
}

internal func system_GetModuleHandleExW(
  _ dwFlags: DWORD,
  _ lpModuleName: UnsafePointer<WCHAR>?,
  _ phModule: UnsafeMutablePointer<HMODULE?>
) -> Bool {
  GetModuleHandleExW(dwFlags, lpModuleName, phModule)
}

// MARK: - Environment variables

internal func system_GetEnvironmentVariableW(
  _ lpName: UnsafePointer<WCHAR>, _ lpBuffer: UnsafeMutablePointer<WCHAR>, _ nSize: DWORD
) -> DWORD {
  GetEnvironmentVariableW(lpName, lpBuffer, nSize)
}

internal func system_SetEnvironmentVariableW(
  _ lpName: UnsafePointer<WCHAR>, _ lpValue: UnsafePointer<WCHAR>?
) -> Bool {
  SetEnvironmentVariableW(lpName, lpValue)
}

internal func system_GetEnvironmentStringsW() -> UnsafeMutablePointer<WCHAR>? {
  GetEnvironmentStringsW()
}

internal func system_FreeEnvironmentStringsW(_ penv: UnsafeMutablePointer<WCHAR>) -> Bool {
  FreeEnvironmentStringsW(penv)
}

// Returns an error number, rather than setting errno.
internal func system__wputenv_s(
  _ varname: UnsafePointer<WCHAR>, _ value_string: UnsafePointer<WCHAR>
) -> CInt {
#if ENABLE_MOCKING
  if mockingEnabled {
    return _mockReturningErrno(
      path: varname, String(_errorCorrectingPlatformString: value_string))
  }
#endif
  return _wputenv_s(varname, value_string)
}

// MARK: - Broken-down time

// The C runtime's 64-bit time functions, which report errors as their
// result or as -1, without setting errno. The time is recorded by value, and
// the fields that _mkgmtime64 and _mktime64 read; a mocked success leaves
// the result as it was.

internal func system__gmtime64_s(
  _ result: UnsafeMutablePointer<ucrt.tm>, _ time: UnsafePointer<__time64_t>
) -> errno_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(Int(time.pointee)) }
#endif
  return _gmtime64_s(result, time)
}

internal func system__localtime64_s(
  _ result: UnsafeMutablePointer<ucrt.tm>, _ time: UnsafePointer<__time64_t>
) -> errno_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockReturningErrno(Int(time.pointee)) }
#endif
  return _localtime64_s(result, time)
}

#if ENABLE_MOCKING
private func _mockTimeFields(
  name: String = #function, _ time: UnsafeMutablePointer<ucrt.tm>
) -> __time64_t {
  let t = time.pointee
  return __time64_t(_mock(
    name: name, t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec,
    t.tm_isdst))
}
#endif

internal func system__mkgmtime64(_ time: UnsafeMutablePointer<ucrt.tm>) -> __time64_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockTimeFields(time) }
#endif
  return _mkgmtime64(time)
}

internal func system__mktime64(_ time: UnsafeMutablePointer<ucrt.tm>) -> __time64_t {
#if ENABLE_MOCKING
  if mockingEnabled { return _mockTimeFields(time) }
#endif
  return _mktime64(time)
}

// The zone's queries and tzset can't fail on valid arguments, and strftime
// reports only a result that doesn't fit, or fields it rejects, so they have
// no mock hook, as on the other platforms.

internal func system__tzset() {
  _tzset()
}

// Windows' long is 32 bits.
internal func system__get_timezone(_ seconds: UnsafeMutablePointer<Int32>) -> errno_t {
  _get_timezone(seconds)
}

internal func system__get_dstbias(_ seconds: UnsafeMutablePointer<Int32>) -> errno_t {
  _get_dstbias(seconds)
}

internal func system__get_tzname(
  _ returnValue: UnsafeMutablePointer<Int>,
  _ buffer: UnsafeMutablePointer<CChar>?,
  _ sizeInBytes: Int,
  _ index: CInt
) -> errno_t {
  _get_tzname(returnValue, buffer, sizeInBytes, index)
}

internal func system_strftime(
  _ buffer: UnsafeMutablePointer<CChar>, _ capacity: Int,
  _ format: UnsafePointer<CChar>, _ time: UnsafePointer<ucrt.tm>
) -> Int {
  ucrt.strftime(buffer, capacity, format, time)
}

// MARK: - File information

internal func system_GetFileInformationByHandle(
  _ hFile: HANDLE, _ lpFileInformation: UnsafeMutablePointer<BY_HANDLE_FILE_INFORMATION>
) -> Bool {
  GetFileInformationByHandle(hFile, lpFileInformation)
}

internal func system_GetFileAttributesW(_ lpFileName: UnsafePointer<WCHAR>) -> DWORD {
  GetFileAttributesW(lpFileName)
}

internal func system_GetFileAttributesExW(
  _ lpFileName: UnsafePointer<WCHAR>,
  _ fInfoLevelId: GET_FILEEX_INFO_LEVELS,
  _ lpFileInformation: UnsafeMutablePointer<WIN32_FILE_ATTRIBUTE_DATA>
) -> Bool {
  GetFileAttributesExW(lpFileName, fInfoLevelId, lpFileInformation)
}

internal func system_SetFileAttributesW(
  _ lpFileName: UnsafePointer<WCHAR>, _ dwFileAttributes: DWORD
) -> Bool {
  SetFileAttributesW(lpFileName, dwFileAttributes)
}

// MARK: - System information

internal func system_GetSystemInfo(_ lpSystemInfo: UnsafeMutablePointer<SYSTEM_INFO>) {
  GetSystemInfo(lpSystemInfo)
}

internal func system_GetNativeSystemInfo(_ lpSystemInfo: UnsafeMutablePointer<SYSTEM_INFO>) {
  GetNativeSystemInfo(lpSystemInfo)
}

internal func system_GetActiveProcessorCount(_ GroupNumber: WORD) -> DWORD {
  GetActiveProcessorCount(GroupNumber)
}

internal func system_GetLogicalProcessorInformation(
  _ Buffer: UnsafeMutablePointer<SYSTEM_LOGICAL_PROCESSOR_INFORMATION>?,
  _ ReturnedLength: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetLogicalProcessorInformation(Buffer, ReturnedLength)
}

internal func system_GetPhysicallyInstalledSystemMemory(
  _ TotalMemoryInKilobytes: UnsafeMutablePointer<ULONGLONG>
) -> Bool {
  GetPhysicallyInstalledSystemMemory(TotalMemoryInKilobytes)
}

internal func system_GetComputerNameExW(
  _ NameType: CInt, _ lpBuffer: UnsafeMutablePointer<WCHAR>?, _ nSize: UnsafeMutablePointer<DWORD>
) -> Bool {
  GetComputerNameExW(COMPUTER_NAME_FORMAT(rawValue: NameType), lpBuffer, nSize)
}

// MARK: - Path operations

internal func system_CreateDirectoryW(
  _ lpPathName: UnsafePointer<WCHAR>,
  _ lpSecurityAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES>?
) -> Bool {
  CreateDirectoryW(lpPathName, lpSecurityAttributes)
}

internal func system_RemoveDirectoryW(_ lpPathName: UnsafePointer<WCHAR>) -> Bool {
  RemoveDirectoryW(lpPathName)
}

internal func system_DeleteFileW(_ lpFileName: UnsafePointer<WCHAR>) -> Bool {
  DeleteFileW(lpFileName)
}

internal func system_MoveFileExW(
  _ lpExistingFileName: UnsafePointer<WCHAR>,
  _ lpNewFileName: UnsafePointer<WCHAR>?,
  _ dwFlags: DWORD
) -> Bool {
  MoveFileExW(lpExistingFileName, lpNewFileName, dwFlags)
}

internal func system_CopyFile2(
  _ pwszExistingFileName: UnsafePointer<WCHAR>,
  _ pwszNewFileName: UnsafePointer<WCHAR>,
  _ pExtendedParameters: UnsafeMutablePointer<COPYFILE2_EXTENDED_PARAMETERS>?
) -> HRESULT {
  CopyFile2(pwszExistingFileName, pwszNewFileName, pExtendedParameters)
}

internal func system_CreateSymbolicLinkW(
  _ lpSymlinkFileName: UnsafePointer<WCHAR>,
  _ lpTargetFileName: UnsafePointer<WCHAR>,
  _ dwFlags: DWORD
) -> BOOLEAN {
  CreateSymbolicLinkW(lpSymlinkFileName, lpTargetFileName, dwFlags)
}

// The security attributes parameter is reserved, and always NULL.
internal func system_CreateHardLinkW(
  _ lpFileName: UnsafePointer<WCHAR>,
  _ lpExistingFileName: UnsafePointer<WCHAR>
) -> Bool {
  CreateHardLinkW(lpFileName, lpExistingFileName, nil)
}

#endif // os(Windows)
