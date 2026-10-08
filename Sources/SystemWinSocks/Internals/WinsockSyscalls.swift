/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// The only code that calls these C functions. Winsock reports failure
// through its return value (SOCKET_ERROR or INVALID_SOCKET) and
// WSAGetLastError, as Win32 does through GetLastError, so like SystemPackage's
// Win32 calls these have no mock hook. Winsock types its buffers `char *`;
// these take raw pointers and bind them for the call alone.

// MARK: - Startup and errors

internal func system_WSAStartup(_ version: WORD, _ data: UnsafeMutablePointer<WSADATA>) -> CInt {
  WSAStartup(version, data)
}

internal func system_WSAGetLastError() -> CInt {
  WSAGetLastError()
}

// MARK: - Socket creation and management

internal func system_WSASocketW(
  _ af: CInt, _ type: CInt, _ protocol: CInt, _ flags: DWORD
) -> SOCKET {
  WSASocketW(af, type, `protocol`, nil, 0, flags)
}

internal func system_closesocket(_ s: SOCKET) -> CInt {
  closesocket(s)
}

internal func system_shutdown(_ s: SOCKET, _ how: CInt) -> CInt {
  shutdown(s, how)
}

internal func system_SetHandleInformation(_ handle: HANDLE, _ mask: DWORD, _ flags: DWORD) -> Bool {
  SetHandleInformation(handle, mask, flags)
}

#endif // os(Windows)
