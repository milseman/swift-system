/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Open Options

@available(System 199, *)
extension SocketDescriptor {
  /// Options for a socket that `open`, `pair`, or `accept` creates.
  ///
  /// On Linux and Android, these are flags that `socket` and `socketpair`
  /// take with the socket type, and that `accept4` takes,
  /// which set them as the call creates the socket.
  /// Darwin has no such flags,
  /// so there System sets them with `fcntl` right after the call;
  /// see ``closeOnExec``.
  @frozen
  public struct OpenOptions: OptionSet, Sendable, Hashable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Makes the socket's operations nonblocking,
    /// as ``FileDescriptor/OpenOptions/nonBlocking`` does for a file.
    ///
    /// The corresponding C constant is `SOCK_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: OpenOptions { OpenOptions(rawValue: _SOCK_NONBLOCK) }

    /// Closes the socket when the process executes a program.
    ///
    /// On Darwin, which has no `SOCK_CLOEXEC`,
    /// this sets close-on-exec just after the call creates the socket,
    /// so a child process that another thread spawns in between
    /// can inherit the socket.
    /// A spawn with `SpawnAttributes.Flags.closeOnExecByDefault`
    /// passes a child only the descriptors it names.
    ///
    /// The corresponding C constant is `SOCK_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: OpenOptions { OpenOptions(rawValue: _SOCK_CLOEXEC) }

    public var description: String {
      _buildDescription([(.nonBlocking, ".nonBlocking"), (.closeOnExec, ".closeOnExec")])
    }
  }
}

#if SYSTEM_PACKAGE_DARWIN
// Darwin has no SOCK_NONBLOCK or SOCK_CLOEXEC. These stand-ins are FreeBSD's
// values, which no socket type uses; System sets the options with fcntl, and
// never passes them to a call.
@_alwaysEmitIntoClient
internal var _SOCK_NONBLOCK: CInt { 0x2000_0000 }

@_alwaysEmitIntoClient
internal var _SOCK_CLOEXEC: CInt { 0x1000_0000 }
#elseif os(Linux) && canImport(Glibc)
// glibc declares the SOCK_* constants in an enum.
@_alwaysEmitIntoClient
internal var _SOCK_NONBLOCK: CInt { CInt(bitPattern: SOCK_NONBLOCK.rawValue) }

@_alwaysEmitIntoClient
internal var _SOCK_CLOEXEC: CInt { CInt(bitPattern: SOCK_CLOEXEC.rawValue) }
#else
@_alwaysEmitIntoClient
internal var _SOCK_NONBLOCK: CInt { CInt(SOCK_NONBLOCK) }

@_alwaysEmitIntoClient
internal var _SOCK_CLOEXEC: CInt { CInt(SOCK_CLOEXEC) }
#endif

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
  ///     ``OpenOptions/closeOnExec``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor.
  ///
  /// The corresponding C function is `socket`.
  @_alwaysEmitIntoClient
  public static func open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> SocketDescriptor {
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
  ) -> Result<SocketDescriptor, Errno> {
    #if SYSTEM_PACKAGE_DARWIN
    return _open(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options) }
    #else
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_socket(domain.rawValue, type.rawValue | options.rawValue, `protocol`.rawValue)
    }.map(SocketDescriptor.init(rawValue:))
    #endif
  }

  /// Creates a pair of connected sockets, with options.
  ///
  /// - Parameters:
  ///   - domain: The protocol family for communication.
  ///   - type: The semantics of communication.
  ///   - protocol: The particular protocol to use. The default is `.default`,
  ///     which typically selects the appropriate protocol for the domain/type
  ///     combination.
  ///   - options: Options for both sockets, such as
  ///     ``OpenOptions/closeOnExec``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: The pair of socket descriptors.
  ///
  /// See ``pair(_:_:protocol:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `socketpair`.
  @_alwaysEmitIntoClient
  public static func pair(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (SocketDescriptor, SocketDescriptor) {
    try _pair(
      domain, type, protocol: `protocol`, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _pair(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<(SocketDescriptor, SocketDescriptor), Errno> {
    #if SYSTEM_PACKAGE_DARWIN
    return _pair(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt)
      .flatMap { pair in
        pair.0._settingOptions(options, closingAlso: pair.1).flatMap { first in
          pair.1._settingOptions(options, closingAlso: first).map { (first, $0) }
        }
      }
    #else
    let type = ConnectionType(rawValue: type.rawValue | options.rawValue)
    return _pair(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt)
    #endif
  }

  /// Accepts a connection on the socket, with options for the new socket.
  ///
  /// - Parameters:
  ///   - options: Options for the new socket, such as
  ///     ``OpenOptions/closeOnExec``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// The new socket is nonblocking exactly when `options` includes
  /// ``OpenOptions/nonBlocking``,
  /// whether or not this socket is.
  /// (Without options, `accept` on Darwin, FreeBSD, and OpenBSD
  /// gives the new socket this one's nonblocking mode, and on Linux doesn't.)
  ///
  /// The corresponding C function is `accept4`.
  /// Darwin has no `accept4`, so there this method calls `accept`,
  /// then sets the options with `fcntl`.
  @_alwaysEmitIntoClient
  public func accept(
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> SocketDescriptor {
    try _accept(options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Errno> {
    #if SYSTEM_PACKAGE_DARWIN
    return _accept(retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options, exactly: true) }
    #else
    return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_accept4(self.rawValue, nil, nil, options.rawValue)
    }.map(SocketDescriptor.init(rawValue:))
    #endif
  }

  /// Accepts a connection, with options for the new socket,
  /// and returns the client's address.
  ///
  /// - Parameters:
  ///   - client: A socket address buffer to receive the client's address.
  ///   - options: Options for the new socket, such as
  ///     ``OpenOptions/closeOnExec``.
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor for the accepted connection.
  ///
  /// See ``accept(options:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `accept4`.
  /// Darwin has no `accept4`, so there this method calls `accept`,
  /// then sets the options with `fcntl`.
  @_alwaysEmitIntoClient
  public func accept(
    client: inout SocketAddress,
    options: OpenOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> SocketDescriptor {
    try _accept(client: &client, options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _accept(
    client: inout SocketAddress,
    options: OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Errno> {
    #if SYSTEM_PACKAGE_DARWIN
    return _accept(client: &client, retryOnInterrupt: retryOnInterrupt)
      .flatMap { $0._settingOptions(options, exactly: true) }
    #else
    return client._withUnsafeMutablePointer { addr, len in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_accept4(self.rawValue, addr, &len, options.rawValue)
      }.map(SocketDescriptor.init(rawValue:))
    }
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Sets the options on a socket that a call just created,
  /// since Darwin has no flags for the call to set them with,
  /// and closes it, and `other` if there is one, if that fails.
  ///
  /// With `exactly`, the socket is left blocking unless `options` makes it
  /// nonblocking, since `accept` gives it the listening socket's mode.
  internal func _settingOptions(
    _ options: OpenOptions,
    exactly: Bool = false,
    closingAlso other: SocketDescriptor? = nil
  ) -> Result<SocketDescriptor, Errno> {
    var result: Result<Void, Errno> = .success(())
    if options.contains(.closeOnExec) {
      result = nothingOrErrno(retryOnInterrupt: false) {
        system_fcntl(self.rawValue, F_SETFD, FD_CLOEXEC)
      }
    }
    let nonBlocking = options.contains(.nonBlocking)
    if case .success = result, nonBlocking || exactly {
      result = valueOrErrno(retryOnInterrupt: false) {
        system_fcntl(self.rawValue, F_GETFL)
      }.flatMap { flags in
        let wanted = nonBlocking ? flags | O_NONBLOCK : flags & ~O_NONBLOCK
        guard wanted != flags else { return .success(()) }
        return nothingOrErrno(retryOnInterrupt: false) {
          system_fcntl(self.rawValue, F_SETFL, wanted)
        }
      }
    }
    guard case .failure(let error) = result else { return .success(self) }
    _ = system_close(self.rawValue)
    if let other { _ = system_close(other.rawValue) }
    return .failure(error)
  }
  #endif
}
