/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Winsock constants that SystemWinSocks uses internally, spelled as their
// values like its public constants and SystemPackage's Win32 ones: they're
// fixed ABI, and literals don't depend on which Windows SDK builds System.
// WinsockConstantsTests checks each one against the SDK.

// MARK: - Sockets

@_alwaysEmitIntoClient
internal var _INVALID_SOCKET: SOCKET { SOCKET(bitPattern: -1) }

@_alwaysEmitIntoClient
internal var _SOCKET_ERROR: CInt { -1 }

@_alwaysEmitIntoClient
internal var _WSA_FLAG_OVERLAPPED: DWORD { 0x01 }

@_alwaysEmitIntoClient
internal var _WSA_FLAG_NO_HANDLE_INHERIT: DWORD { 0x80 }

// _IOW('f', 126, u_long), which the SDK computes with function-like macros.
@_alwaysEmitIntoClient
internal var _FIONBIO: CInt { CInt(bitPattern: 0x8004_667E) }

// MAKEWORD(2, 2): Winsock 2.2, the version since Windows 95's Winsock 2.
@_alwaysEmitIntoClient
internal var _WINSOCK_VERSION: WORD { 0x0202 }

// MARK: - Extension functions

// _WSAIORW(IOC_WS2, 6): IOC_IN | IOC_OUT | IOC_WS2 | 6, which the SDK
// computes with a function-like macro.
@_alwaysEmitIntoClient
internal var _SIO_GET_EXTENSION_FUNCTION_POINTER: DWORD { 0xC800_0006 }

// The SDK's WSAID_ macros are initializer lists, which don't import.
@_alwaysEmitIntoClient
internal var _WSAID_WSARECVMSG: GUID {
  GUID(Data1: 0xF689_D7C8, Data2: 0x6F1F, Data3: 0x436B,
       Data4: (0x8A, 0x53, 0xE5, 0x4F, 0xE3, 0x51, 0xC3, 0x22))
}

@_alwaysEmitIntoClient
internal var _WSAID_WSASENDMSG: GUID {
  GUID(Data1: 0xA441_E712, Data2: 0x754F, Data3: 0x43CA,
       Data4: (0x84, 0xA7, 0x0D, 0xEE, 0x44, 0xCF, 0x60, 0x6D))
}

// MARK: - Handles

@_alwaysEmitIntoClient
internal var _HANDLE_FLAG_INHERIT: DWORD { 0x0000_0001 }

#endif // os(Windows)
