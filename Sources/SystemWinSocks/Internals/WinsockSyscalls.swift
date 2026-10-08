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

internal func system_ioctlsocket(_ s: SOCKET, _ command: CInt, _ argument: UnsafeMutablePointer<u_long>) -> CInt {
  ioctlsocket(s, command, argument)
}

// MARK: - Connection operations

internal func system_bind(
  _ s: SOCKET,
  _ addr: UnsafePointer<SOCKADDR>?,
  _ len: CInt
) -> CInt {
  bind(s, addr, len)
}

internal func system_listen(_ s: SOCKET, _ backlog: CInt) -> CInt {
  listen(s, backlog)
}

internal func system_accept(
  _ s: SOCKET,
  _ addr: UnsafeMutablePointer<SOCKADDR>?,
  _ len: UnsafeMutablePointer<CInt>?
) -> SOCKET {
  accept(s, addr, len)
}

internal func system_connect(
  _ s: SOCKET,
  _ addr: UnsafePointer<SOCKADDR>?,
  _ len: CInt
) -> CInt {
  connect(s, addr, len)
}

// MARK: - Data transfer

internal func system_send(
  _ s: SOCKET,
  _ buffer: UnsafeRawPointer?,
  _ len: CInt,
  _ flags: CInt
) -> CInt {
  send(s, buffer?.assumingMemoryBound(to: CChar.self), len, flags)
}

internal func system_recv(
  _ s: SOCKET,
  _ buffer: UnsafeMutableRawPointer?,
  _ len: CInt,
  _ flags: CInt
) -> CInt {
  recv(s, buffer?.assumingMemoryBound(to: CChar.self), len, flags)
}

internal func system_sendto(
  _ s: SOCKET,
  _ buffer: UnsafeRawPointer?,
  _ len: CInt,
  _ flags: CInt,
  _ to: UnsafePointer<SOCKADDR>?,
  _ tolen: CInt
) -> CInt {
  sendto(s, buffer?.assumingMemoryBound(to: CChar.self), len, flags, to, tolen)
}

internal func system_recvfrom(
  _ s: SOCKET,
  _ buffer: UnsafeMutableRawPointer?,
  _ len: CInt,
  _ flags: CInt,
  _ from: UnsafeMutablePointer<SOCKADDR>?,
  _ fromlen: UnsafeMutablePointer<CInt>?
) -> CInt {
  recvfrom(s, buffer?.assumingMemoryBound(to: CChar.self), len, flags, from, fromlen)
}

// MARK: - Socket names

internal func system_getsockname(
  _ s: SOCKET,
  _ addr: UnsafeMutablePointer<SOCKADDR>?,
  _ len: UnsafeMutablePointer<CInt>?
) -> CInt {
  getsockname(s, addr, len)
}

internal func system_getpeername(
  _ s: SOCKET,
  _ addr: UnsafeMutablePointer<SOCKADDR>?,
  _ len: UnsafeMutablePointer<CInt>?
) -> CInt {
  getpeername(s, addr, len)
}

// MARK: - Socket options

internal func system_getsockopt(
  _ s: SOCKET,
  _ level: CInt,
  _ option: CInt,
  _ value: UnsafeMutableRawPointer?,
  _ length: UnsafeMutablePointer<CInt>?
) -> CInt {
  getsockopt(s, level, option, value?.assumingMemoryBound(to: CChar.self), length)
}

internal func system_setsockopt(
  _ s: SOCKET,
  _ level: CInt,
  _ option: CInt,
  _ value: UnsafeRawPointer?,
  _ length: CInt
) -> CInt {
  setsockopt(s, level, option, value?.assumingMemoryBound(to: CChar.self), length)
}

// MARK: - Polling

internal func system_WSAPoll(
  _ entries: UnsafeMutablePointer<WSAPOLLFD>?,
  _ count: ULONG,
  _ timeout: CInt
) -> CInt {
  WSAPoll(entries, count, timeout)
}

// MARK: - Handles

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
