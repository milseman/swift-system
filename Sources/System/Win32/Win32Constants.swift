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

// MARK: - Long paths

// The longest path CreateDirectoryW takes without the \\?\ prefix, with its
// terminator: MAX_PATH less 12, room for an 8.3 file name. The SDK has no
// name for it.
@_alwaysEmitIntoClient
internal var _win32DirectoryMaxPath: Int { 248 }

@_alwaysEmitIntoClient
internal var _PATHCCH_ALLOW_LONG_PATHS: ULONG { 0x0000_0001 }

@_alwaysEmitIntoClient
internal var _PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH: ULONG { 0x0000_0010 }

@_alwaysEmitIntoClient
internal var _S_OK: HRESULT { 0 }

@_alwaysEmitIntoClient
internal var _S_FALSE: HRESULT { 1 }

// MARK: - File I/O

@_alwaysEmitIntoClient
internal var _FILE_TYPE_DISK: DWORD { 0x1 }

// MARK: - System information

@_alwaysEmitIntoClient
internal var _ALL_PROCESSOR_GROUPS: WORD { 0xFFFF }

// MARK: - Overlapped I/O

@_alwaysEmitIntoClient
internal var _ERROR_IO_INCOMPLETE: DWORD { 996 }

@_alwaysEmitIntoClient
internal var _ERROR_NOT_FOUND: DWORD { 1168 }

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

// MARK: - C standard I/O

@_alwaysEmitIntoClient
internal var _EOF: CInt { -1 }

// MARK: - Ending the process

// stdlib.h's, which Constants+ExitCodes.swift spells for the other
// platforms.
@_alwaysEmitIntoClient
internal var _EXIT_SUCCESS: CInt { 0 }

@_alwaysEmitIntoClient
internal var _EXIT_FAILURE: CInt { 1 }

// MARK: - Creating threads

@_alwaysEmitIntoClient
internal var _CREATE_SUSPENDED: DWORD { 0x0000_0004 }

@_alwaysEmitIntoClient
internal var _STACK_SIZE_PARAM_IS_A_RESERVATION: DWORD { 0x0001_0000 }

// MARK: - Fiber-local storage

@_alwaysEmitIntoClient
internal var _FLS_OUT_OF_INDEXES: DWORD { 0xFFFF_FFFF }

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

// MARK: - Consoles

@_alwaysEmitIntoClient
internal var _ATTACH_PARENT_PROCESS: DWORD { DWORD(bitPattern: -1) }

// MARK: - Condition variables

@_alwaysEmitIntoClient
internal var _CONDITION_VARIABLE_LOCKMODE_SHARED: ULONG { 0x1 }

@_alwaysEmitIntoClient
internal var _ERROR_TIMEOUT: DWORD { 1460 }

// MARK: - Environment variables

@_alwaysEmitIntoClient
internal var _ERROR_ENVVAR_NOT_FOUND: DWORD { 203 }

// MARK: - Events and waits

// The SDK's is ((STATUS_ABANDONED_WAIT_0) + 0), which doesn't import.
@_alwaysEmitIntoClient
internal var _WAIT_ABANDONED_0: DWORD { 0x80 }

@_alwaysEmitIntoClient
internal var _MAXIMUM_WAIT_OBJECTS: Int { 64 }

// MARK: - Reparse points

// winioctl.h computes it with CTL_CODE, a function-like macro, which
// doesn't import; Swift's WinSDK overlay declares it.
@_alwaysEmitIntoClient
internal var _FSCTL_GET_REPARSE_POINT: DWORD { 0x0009_00A8 }

@_alwaysEmitIntoClient
internal var _MAXIMUM_REPARSE_DATA_BUFFER_SIZE: Int { 16 * 1024 }

@_alwaysEmitIntoClient
internal var _SYMLINK_FLAG_RELATIVE: DWORD { 0x0000_0001 }

// MARK: - Pipes

@_alwaysEmitIntoClient
internal var _FILE_FLAG_FIRST_PIPE_INSTANCE: DWORD { 0x0008_0000 }

@_alwaysEmitIntoClient
internal var _PIPE_NOWAIT: DWORD { 0x0000_0001 }

@_alwaysEmitIntoClient
internal var _PIPE_READMODE_MESSAGE: DWORD { 0x0000_0002 }

@_alwaysEmitIntoClient
internal var _PIPE_REJECT_REMOTE_CLIENTS: DWORD { 0x0000_0008 }

@_alwaysEmitIntoClient
internal var _PIPE_UNLIMITED_INSTANCES: DWORD { 255 }

@_alwaysEmitIntoClient
internal var _ERROR_PIPE_CONNECTED: DWORD { 535 }

// MARK: - Job objects

// The limits that JobOptions sets; the others, which need values, a job
// keeps as they are.
@_alwaysEmitIntoClient
internal var _JOB_OBJECT_OPTION_FLAGS: DWORD { 0x0000_3C00 }

// MARK: - Security identifiers and accounts

@_alwaysEmitIntoClient
internal var _SID_REVISION: UInt8 { 1 }

@_alwaysEmitIntoClient
internal var _SID_MAX_SUB_AUTHORITIES: Int { 15 }

// winnt.h computes it, with sizeof, so it doesn't import: the 8 bytes of a
// SID's header, and 15 subauthorities of 4.
@_alwaysEmitIntoClient
internal var _SECURITY_MAX_SID_SIZE: Int { 68 }

// The longest user name, in characters, without the terminator.
@_alwaysEmitIntoClient
internal var _UNLEN: Int { 256 }

#endif // os(Windows)
