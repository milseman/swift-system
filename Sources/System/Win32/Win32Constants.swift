/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Win32 constants that the Win32 namespace uses internally, spelled as their
// values like its public constants: Win32 values are fixed ABI, and literals
// don't depend on which Windows SDK builds System. The Win32 tests check
// each one against the SDK. The names here, unlike the ones in
// WinSDK+Overlay.swift, begin with an underscore, as Constants.swift's do.

// MARK: - Errors

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_ALLOCATE_BUFFER: DWORD { 0x0000_0100 }

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_FROM_SYSTEM: DWORD { 0x0000_1000 }

@_alwaysEmitIntoClient
internal var _FORMAT_MESSAGE_IGNORE_INSERTS: DWORD { 0x0000_0200 }

// MARK: - Handles

@_alwaysEmitIntoClient
internal var _DUPLICATE_SAME_ACCESS: DWORD { 0x0000_0002 }

@_alwaysEmitIntoClient
internal var _FACILITY_WIN32: DWORD { 7 }

@_alwaysEmitIntoClient
internal var _FILE_FLAG_OVERLAPPED: DWORD { 0x4000_0000 }

@_alwaysEmitIntoClient
internal var _FILE_SYNCHRONOUS_IO_ALERT: ULONG { 0x0000_0010 }

@_alwaysEmitIntoClient
internal var _FILE_SYNCHRONOUS_IO_NONALERT: ULONG { 0x0000_0020 }

@_alwaysEmitIntoClient
internal var _FILE_TYPE_UNKNOWN: DWORD { 0x0 }

@_alwaysEmitIntoClient
internal var _HANDLE_FLAG_INHERIT: DWORD { 0x0000_0001 }

@_alwaysEmitIntoClient
internal var _SDDL_REVISION_1: DWORD { 1 }

// MAX_PATH. The C runtime's own `_MAX_PATH` has the same value.
@_alwaysEmitIntoClient
internal var _win32MaxPath: Int { 260 }

// MARK: - File I/O

@_alwaysEmitIntoClient
internal var _FILE_TYPE_DISK: DWORD { 0x1 }

// MARK: - Byte-range locking

@_alwaysEmitIntoClient
internal var _LOCKFILE_EXCLUSIVE_LOCK: DWORD { 0x0000_0002 }

@_alwaysEmitIntoClient
internal var _LOCKFILE_FAIL_IMMEDIATELY: DWORD { 0x0000_0001 }

// MARK: - Final path name

@_alwaysEmitIntoClient
internal var _FILE_NAME_NORMALIZED: DWORD { 0x0 }

@_alwaysEmitIntoClient
internal var _FILE_NAME_OPENED: DWORD { 0x8 }

// MARK: - Processes and waiting

@_alwaysEmitIntoClient
internal var _INFINITE: DWORD { 0xFFFF_FFFF }

@_alwaysEmitIntoClient
internal var _WAIT_FAILED: DWORD { 0xFFFF_FFFF }

@_alwaysEmitIntoClient
internal var _WAIT_OBJECT_0: DWORD { 0x0 }

@_alwaysEmitIntoClient
internal var _WAIT_TIMEOUT: DWORD { 0x102 }

// MARK: - Creating processes

@_alwaysEmitIntoClient
internal var _CREATE_UNICODE_ENVIRONMENT: DWORD { 0x0000_0400 }

@_alwaysEmitIntoClient
internal var _CSTR_EQUAL: CInt { 2 }

@_alwaysEmitIntoClient
internal var _CSTR_GREATER_THAN: CInt { 3 }

@_alwaysEmitIntoClient
internal var _CSTR_LESS_THAN: CInt { 1 }

@_alwaysEmitIntoClient
internal var _EXTENDED_STARTUPINFO_PRESENT: DWORD { 0x0008_0000 }

// ProcThreadAttributeValue(ProcThreadAttributeHandleList, FALSE, TRUE,
// FALSE): attribute 2, an input. The SDK spells it with a function-like
// macro, which doesn't import.
@_alwaysEmitIntoClient
internal var _PROC_THREAD_ATTRIBUTE_HANDLE_LIST: DWORD_PTR { 0x0002_0002 }

@_alwaysEmitIntoClient
internal var _STARTF_USESTDHANDLES: DWORD { 0x0000_0100 }

@_alwaysEmitIntoClient
internal var _STD_ERROR_HANDLE: DWORD { DWORD(bitPattern: -12) }

@_alwaysEmitIntoClient
internal var _STD_INPUT_HANDLE: DWORD { DWORD(bitPattern: -10) }

@_alwaysEmitIntoClient
internal var _STD_OUTPUT_HANDLE: DWORD { DWORD(bitPattern: -11) }

// MARK: - Condition variables

@_alwaysEmitIntoClient
internal var _CONDITION_VARIABLE_LOCKMODE_SHARED: ULONG { 0x1 }

@_alwaysEmitIntoClient
internal var _ERROR_TIMEOUT: DWORD { 1460 }

#endif // os(Windows)
