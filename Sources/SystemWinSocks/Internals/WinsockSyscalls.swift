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

// MARK: - Address conversion

// Windows Vista and later. System calls these without starting Winsock:
// their documentation lists no WSANOTINITIALISED, and swift-certificates
// parses addresses with inet_pton without starting it (an exit test in
// SocketAddressTests checks it). inet_ntop reports its failures through
// WSAGetLastError, and takes the buffer's size as a size_t.

@available(System 199, *)
@usableFromInline
internal func system_inet_pton(
  _ af: CInt,
  _ src: UnsafePointer<CChar>,
  _ dst: UnsafeMutableRawPointer
) -> CInt {
  inet_pton(af, src, dst)
}

@available(System 199, *)
@usableFromInline
internal func system_inet_ntop(
  _ af: CInt,
  _ src: UnsafeRawPointer,
  _ dst: UnsafeMutablePointer<CChar>,
  _ size: Int
) -> UnsafePointer<CChar>? {
  inet_ntop(af, src, dst, size)
}

#endif // os(Windows)
