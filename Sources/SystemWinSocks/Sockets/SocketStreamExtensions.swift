/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Winsock's overlapped stream functions, AcceptEx, ConnectEx and
// TransmitFile: Windows' own, with no POSIX counterparts but accept,
// connect and sendfile, so they're Windows-only API, under Swift names.
// They're extension functions, which System looks up once per process
// (WinsockExtensions.swift), and overlapped operations, with
// SocketOverlappedIO.swift's rules: the OVERLAPPED and the buffers must
// stay allocated until the operation finishes, and none is read once the
// call starts it.

@available(System 199, *)
extension SocketDescriptor {
  /// Options for ``transmitFile(_:byteCount:fromAbsoluteOffset:options:overlapped:)``.
  @frozen
  public struct TransmitFileOptions: OptionSet, Sendable, Hashable {
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Starts a transport-level disconnect once the data is queued.
    ///
    /// The corresponding C constant is `TF_DISCONNECT`.
    @_alwaysEmitIntoClient
    public static var disconnect: Self { Self(rawValue: 0x01) }

    /// Prepares the socket to be reused by `AcceptEx` or `ConnectEx` once
    /// the transmission finishes, with ``disconnect``.
    ///
    /// The corresponding C constant is `TF_REUSE_SOCKET`.
    @_alwaysEmitIntoClient
    public static var reuseSocket: Self { Self(rawValue: 0x02) }

    /// Finishes as soon as the data is buffered, before the peer
    /// acknowledges it.
    ///
    /// The corresponding C constant is `TF_WRITE_BEHIND`.
    @_alwaysEmitIntoClient
    public static var writeBehind: Self { Self(rawValue: 0x04) }

    /// Transmits from a system thread, for long transfers.
    ///
    /// The corresponding C constant is `TF_USE_SYSTEM_THREAD`.
    @_alwaysEmitIntoClient
    public static var useSystemThread: Self { Self(rawValue: 0x10) }

    /// Transmits through kernel asynchronous procedure calls, which suits a
    /// file that's mostly in the cache.
    ///
    /// The corresponding C constant is `TF_USE_KERNEL_APC`.
    @_alwaysEmitIntoClient
    public static var useKernelAPC: Self { Self(rawValue: 0x20) }
  }

  /// The number of bytes that ``accept(into:addresses:overlapped:)`` needs
  /// for the connection's addresses: room for two addresses of any family,
  /// each with the 16 bytes that `AcceptEx` requires beyond it.
  @_alwaysEmitIntoClient
  public static var acceptAddressesCapacity: Int {
    2 * (MemoryLayout<CInterop.SockAddrStorage>.size + 16)
  }

  /// Starts accepting a connection, overlapped, into a socket the caller
  /// opened.
  ///
  /// - Parameters:
  ///   - socket: The socket to accept the connection into: one that
  ///     ``open(_:_:protocol:retryOnInterrupt:)`` created, with this socket's
  ///     domain and type, neither bound nor connected.
  ///   - addresses: A buffer of at least ``acceptAddressesCapacity`` bytes,
  ///     which Windows writes the connection's local and remote addresses
  ///     into, in a form of its own; once the accept finishes,
  ///     ``updateAcceptContext(listener:)`` makes ``getLocalAddress(into:)``
  ///     and ``getPeerAddress(into:)`` report them instead. It must stay
  ///     allocated until the accept finishes.
  ///   - overlapped: The structure that identifies the accept, with the
  ///     requirements of ``send(_:flags:overlapped:)``. A completion port
  ///     that this listening socket is associated with reports it.
  /// - Returns: Whether the accept finished at once, rather than pending.
  ///
  /// Unlike ``accept(retryOnInterrupt:)``'s, the new socket is never
  /// inheritable, since `open` made it.
  ///
  /// The corresponding C function is `AcceptEx`, Winsock's extension
  /// function, with no initial data.
  @_alwaysEmitIntoClient
  @unsafe
  public func accept(
    into socket: SocketDescriptor,
    addresses: UnsafeMutableRawBufferPointer,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Bool {
    try _acceptEx(socket, addresses, overlapped).get()
  }

  /// Gives a socket that ``accept(into:addresses:overlapped:)`` connected
  /// the listening socket's properties, so that its names, ``shutdown(_:)``,
  /// and its options work.
  ///
  /// The corresponding C constant is `SO_UPDATE_ACCEPT_CONTEXT`.
  @_alwaysEmitIntoClient
  public func updateAcceptContext(listener: SocketDescriptor) throws(Win32.Error) {
    try _setValue(OptionLevel.socket.rawValue, _SO_UPDATE_ACCEPT_CONTEXT, listener.rawValue).get()
  }

  /// Starts connecting, overlapped.
  ///
  /// - Parameters:
  ///   - address: The address to connect to.
  ///   - overlapped: The structure that identifies the connect, with the
  ///     requirements of ``send(_:flags:overlapped:)``.
  /// - Returns: Whether the connect finished at once, rather than pending.
  ///
  /// The socket must be bound, which ``connect(to:)`` doesn't require:
  /// bind it to ``IPv4Address/any(port:)`` or ``IPv6Address/any(port:)``
  /// with port 0 for the system's choice. Once the connect finishes,
  /// ``updateConnectContext()`` makes its names and ``shutdown(_:)`` work.
  ///
  /// The corresponding C function is `ConnectEx`, Winsock's extension
  /// function, with no initial data.
  @_alwaysEmitIntoClient
  @unsafe
  public func connect(
    to address: SocketAddress,
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Bool {
    try _connectEx(address, overlapped).get()
  }

  /// Gives a socket that ``connect(to:overlapped:)`` connected the
  /// properties of a connected socket, so that its names,
  /// ``shutdown(_:)``, and its options work.
  ///
  /// The corresponding C constant is `SO_UPDATE_CONNECT_CONTEXT`.
  @_alwaysEmitIntoClient
  public func updateConnectContext() throws(Win32.Error) {
    try _updateConnectContext().get()
  }

  @usableFromInline
  internal func _updateConnectContext() -> Result<Void, Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_setsockopt(self.rawValue, OptionLevel.socket.rawValue, _SO_UPDATE_CONNECT_CONTEXT, nil, 0)
    }
  }

  /// Starts sending a file's bytes on this connected socket, overlapped.
  ///
  /// - Parameters:
  ///   - file: The open file's handle, which must stay open until the
  ///     transmission finishes. It's borrowed: this method doesn't close it.
  ///   - byteCount: How many bytes to send, at most 2,147,483,646, or 0 for
  ///     the rest of the file. The default is 0.
  ///   - offset: Where in the file to start.
  ///   - options: Options for the transmission.
  ///   - overlapped: The structure that identifies the transmission, with the
  ///     requirements of ``send(_:flags:overlapped:)``; this method writes
  ///     `offset` into it.
  /// - Returns: Whether the transmission finished at once, rather than
  ///   pending.
  ///
  /// Windows' client releases run at most two transmissions at a time, and
  /// queue the rest.
  ///
  /// The corresponding C function is `TransmitFile`, Winsock's extension
  /// function and `sendfile`'s counterpart.
  @_alwaysEmitIntoClient
  @unsafe
  public func transmitFile(
    _ file: HANDLE,
    byteCount: Int = 0,
    fromAbsoluteOffset offset: Int64,
    options: TransmitFileOptions = [],
    overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) throws(Win32.Error) -> Bool {
    try _transmitFile(file, byteCount, offset, options, overlapped).get()
  }

  @usableFromInline
  internal func _acceptEx(
    _ socket: SocketDescriptor,
    _ addresses: UnsafeMutableRawBufferPointer,
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) -> Result<Bool, Win32.Error> {
    // Each address's part of the buffer is its storage and 16 bytes more.
    let part = MemoryLayout<CInterop.SockAddrStorage>.size + 16
    guard addresses.count >= 2 * part else { return .failure(.invalidParameter) }
    return _winsockStreamFunctions.flatMap { functions in
      overlapped.pointee.Internal = 0
      overlapped.pointee.InternalHigh = 0
      var received: DWORD = 0
      let finished = functions.acceptEx(
        self.rawValue, socket.rawValue, addresses.baseAddress, 0,
        DWORD(part), DWORD(part), &received, overlapped) != 0
      return _overlappedStarted(finished)
    }
  }

  @usableFromInline
  internal func _connectEx(
    _ address: SocketAddress,
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) -> Result<Bool, Win32.Error> {
    _winsockStreamFunctions.flatMap { functions in
      overlapped.pointee.Internal = 0
      overlapped.pointee.InternalHigh = 0
      // ConnectEx reads the address during the call.
      let finished = address.withUnsafePointer { name, nameLength in
        functions.connectEx(self.rawValue, name, nameLength, nil, 0, nil, overlapped) != 0
      }
      return _overlappedStarted(finished)
    }
  }

  @usableFromInline
  internal func _transmitFile(
    _ file: HANDLE,
    _ byteCount: Int,
    _ offset: Int64,
    _ options: TransmitFileOptions,
    _ overlapped: UnsafeMutablePointer<OVERLAPPED>
  ) -> Result<Bool, Win32.Error> {
    guard (0 ... 2_147_483_646).contains(byteCount), offset >= 0 else {
      return .failure(.invalidParameter)
    }
    return _winsockStreamFunctions.flatMap { functions in
      overlapped.pointee.Internal = 0
      overlapped.pointee.InternalHigh = 0
      overlapped.pointee.Offset = DWORD(truncatingIfNeeded: offset)
      overlapped.pointee.OffsetHigh = DWORD(truncatingIfNeeded: offset >> 32)
      let finished = functions.transmitFile(
        self.rawValue, file, DWORD(byteCount), 0, overlapped, nil, options.rawValue) != 0
      return _overlappedStarted(finished)
    }
  }

  /// The result of starting an overlapped operation that reports failure
  /// as `FALSE` and `WSAGetLastError`, read at once: `true` if it finished,
  /// `false` if it's pending.
  @usableFromInline
  internal func _overlappedStarted(_ finished: Bool) -> Result<Bool, Win32.Error> {
    guard !finished else { return .success(true) }
    let error = _lastWinsockError()
    if error == .ioPending { return .success(false) }
    return .failure(error)
  }
}

#endif // os(Windows)
