/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Open Options

@available(System 199, *)
extension SocketDescriptor {
  /// Options for a socket that `open` or `accept` creates.
  ///
  /// Winsock has no flags for the call to set these with, so System sets
  /// them right after the call, as SystemSockets does on Darwin. There's no
  /// `closeOnExec`: Windows has no `exec`, and child processes never
  /// inherit System's sockets.
  @frozen
  public struct OpenOptions: OptionSet, Sendable, Hashable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Makes the socket's operations nonblocking: they throw
    /// ``Win32/Error/wouldBlock`` rather than wait.
    ///
    /// Winsock has no `SOCK_NONBLOCK`. Its value here is FreeBSD's, as on
    /// Darwin, which no socket type uses; System sets the mode with
    /// ``setNonBlocking(_:)`` and never passes the value to a call.
    @_alwaysEmitIntoClient
    public static var nonBlocking: OpenOptions { OpenOptions(rawValue: 0x2000_0000) }

    public var description: String {
      _buildDescription([(.nonBlocking, ".nonBlocking")])
    }
  }
}

// MARK: - Creating Sockets with Options

@available(System 199, *)
extension SocketDescriptor {
  /// Creates an endpoint for communication, with options.
  ///
  /// - Parameters:
  ///   - domain: The protocol family for communication.
  ///   - type: The semantics of communication.
  ///   - protocol: The particular protocol to use. The default is `.default`,
  ///     which typically selects the appropriate protocol for the domain/type
  ///     combination (e.g., TCP for IPv4/stream).
  ///   - options: Options for the new socket, such as
  ///     ``OpenOptions/nonBlocking``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor.
  ///
  /// See ``open(_:_:protocol:retryOnInterrupt:)``. If setting the options
  /// fails, this method closes the socket and throws.
  ///
  /// The corresponding C function is `WSASocketW`, followed by `ioctlsocket`
  /// with `FIONBIO` for a nonblocking socket.
  @_alwaysEmitIntoClient
  public static func open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _open(
      domain, type, protocol: `protocol`, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    _open(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options) }
  }

  /// Accepts a connection on the socket, with options for the new socket.
  ///
  /// - Parameters:
  ///   - options: Options for the new socket, such as
  ///     ``OpenOptions/nonBlocking``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// The new socket is nonblocking exactly when `options` includes
  /// ``OpenOptions/nonBlocking``,
  /// whether or not this socket is.
  /// (Without options, Winsock's `accept` gives the new socket this one's
  /// properties, its nonblocking mode among them.)
  /// If setting the mode fails, this method closes the new socket and
  /// throws.
  ///
  /// The corresponding C function is `accept`, followed by `ioctlsocket`
  /// with `FIONBIO`.
  @_alwaysEmitIntoClient
  public func accept(
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _accept(options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    _accept(retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options, exactly: true) }
  }

  /// Accepts a connection, with options for the new socket,
  /// and returns the client's address.
  ///
  /// - Parameters:
  ///   - client: A socket address buffer to receive the client's address.
  ///   - options: Options for the new socket, such as
  ///     ``OpenOptions/nonBlocking``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// See ``accept(options:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `accept`, followed by `ioctlsocket`
  /// with `FIONBIO`.
  @_alwaysEmitIntoClient
  public func accept(
    client: inout SocketAddress,
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _accept(client: &client, options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    client: inout SocketAddress,
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    _accept(client: &client, retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options, exactly: true) }
  }

  /// Sets the options on a socket that a call just created,
  /// since Winsock has no flags for the call to set them with,
  /// and closes it if that fails.
  ///
  /// With `exactly`, the socket is left blocking unless `options` makes it
  /// nonblocking, since `accept` gives it the listening socket's mode.
  internal func _settingOptions(
    _ options: OpenOptions,
    exactly: Bool = false
  ) -> Result<SocketDescriptor, Win32.Error> {
    let nonBlocking = options.contains(.nonBlocking)
    guard nonBlocking || exactly else { return .success(self) }
    let result = _setNonBlocking(nonBlocking)
    guard case .failure(let error) = result else { return .success(self) }
    _ = system_closesocket(self.rawValue)
    return .failure(error)
  }
}

// MARK: - Nonblocking Mode

@available(System 199, *)
extension SocketDescriptor {
  /// Sets whether the socket's operations are nonblocking: whether they
  /// throw ``Win32/Error/wouldBlock`` rather than wait.
  ///
  /// - Parameter enabled: Whether the socket is nonblocking. The default
  ///   is `true`.
  ///
  /// A socket starts out blocking, unless ``OpenOptions/nonBlocking`` opened
  /// or accepted it. Winsock can set the mode but not report it. A socket
  /// that `WSAEventSelect` or `WSAAsyncSelect` watches is nonblocking until
  /// that stops, and making it blocking throws
  /// ``Win32/Error/invalidArgument``.
  ///
  /// On POSIX systems, a socket's file status flags hold the mode, which
  /// `FileDescriptor.setStatusFlags(_:)` sets.
  ///
  /// The corresponding C function is `ioctlsocket`, with `FIONBIO`.
  @_alwaysEmitIntoClient
  public func setNonBlocking(_ enabled: Bool = true) throws(Win32.Error) {
    try _setNonBlocking(enabled).get()
  }

  @usableFromInline
  internal func _setNonBlocking(_ enabled: Bool) -> Result<Void, Win32.Error> {
    var mode: u_long = enabled ? 1 : 0
    return nothingOrWinsockError(retryOnInterrupt: false) {
      system_ioctlsocket(self.rawValue, _FIONBIO, &mode)
    }
  }
}

#endif // os(Windows)
