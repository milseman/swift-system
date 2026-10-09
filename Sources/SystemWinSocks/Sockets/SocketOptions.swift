/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Option Level

@available(System 199, *)
extension SocketDescriptor {
  /// Socket option levels.
  @frozen
  public struct OptionLevel: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Socket-level options.
    ///
    /// The corresponding C constant is `SOL_SOCKET`.
    @_alwaysEmitIntoClient
    public static var socket: OptionLevel { OptionLevel(rawValue: 0xFFFF) }

    /// IPv4 protocol options.
    ///
    /// The corresponding C constant is `IPPROTO_IP`.
    @_alwaysEmitIntoClient
    public static var ip: OptionLevel { OptionLevel(rawValue: 0) }

    /// IPv6 protocol options.
    ///
    /// The corresponding C constant is `IPPROTO_IPV6`.
    @_alwaysEmitIntoClient
    public static var ipv6: OptionLevel { OptionLevel(rawValue: 41) }

    /// TCP protocol options.
    ///
    /// The corresponding C constant is `IPPROTO_TCP`.
    @_alwaysEmitIntoClient
    public static var tcp: OptionLevel { OptionLevel(rawValue: 6) }

    /// UDP protocol options.
    ///
    /// The corresponding C constant is `IPPROTO_UDP`.
    @_alwaysEmitIntoClient
    public static var udp: OptionLevel { OptionLevel(rawValue: 17) }
  }
}

// MARK: - Socket-Level Options

@available(System 199, *)
extension SocketDescriptor {
  /// Socket-level options for use with `getOption` and `setOption`.
  ///
  /// Winsock has no `SO_REUSEPORT`, `SO_NOSIGPIPE` or `SO_TIMESTAMP`, and
  /// its own providers don't support the low-water marks, so those are
  /// left out.
  @frozen
  public struct SocketOption: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Enable debugging.
    ///
    /// Windows' own providers accept it and record nothing.
    ///
    /// The corresponding C constant is `SO_DEBUG`.
    @_alwaysEmitIntoClient
    public static var debug: SocketOption { SocketOption(rawValue: 0x0001) }

    /// Allow local address reuse.
    ///
    /// On Windows, this lets a socket bind an address and port that another
    /// socket is bound to, even a listening one, which POSIX doesn't allow;
    /// a port whose connections are in `TIME_WAIT` can be bound again
    /// without it. ``exclusiveAddressUse`` keeps other sockets from doing
    /// this to a socket.
    ///
    /// The corresponding C constant is `SO_REUSEADDR`.
    @_alwaysEmitIntoClient
    public static var reuseAddress: SocketOption { SocketOption(rawValue: 0x0004) }

    /// Keep connections alive.
    ///
    /// The corresponding C constant is `SO_KEEPALIVE`.
    @_alwaysEmitIntoClient
    public static var keepAlive: SocketOption { SocketOption(rawValue: 0x0008) }

    /// Don't route, use direct interface.
    ///
    /// Windows' own providers ignore it.
    ///
    /// The corresponding C constant is `SO_DONTROUTE`.
    @_alwaysEmitIntoClient
    public static var dontRoute: SocketOption { SocketOption(rawValue: 0x0010) }

    /// Linger on close if data present.
    ///
    /// Its value is a ``CInterop/Linger``, whose time is in seconds.
    ///
    /// The corresponding C constant is `SO_LINGER`.
    @_alwaysEmitIntoClient
    public static var linger: SocketOption { SocketOption(rawValue: 0x0080) }

    /// Permit sending of broadcast messages.
    ///
    /// The corresponding C constant is `SO_BROADCAST`.
    @_alwaysEmitIntoClient
    public static var broadcast: SocketOption { SocketOption(rawValue: 0x0020) }

    /// Send buffer size.
    ///
    /// The corresponding C constant is `SO_SNDBUF`.
    @_alwaysEmitIntoClient
    public static var sendBufferSize: SocketOption { SocketOption(rawValue: 0x1001) }

    /// Receive buffer size.
    ///
    /// The corresponding C constant is `SO_RCVBUF`.
    @_alwaysEmitIntoClient
    public static var receiveBufferSize: SocketOption { SocketOption(rawValue: 0x1002) }

    /// Get socket error.
    ///
    /// Its value is a Winsock error code, such as `WSAECONNREFUSED` after a
    /// nonblocking connect fails; `Win32.Error(rawValue:)` names it.
    ///
    /// The corresponding C constant is `SO_ERROR`.
    @_alwaysEmitIntoClient
    public static var error: SocketOption { SocketOption(rawValue: 0x1007) }

    /// Get socket type.
    ///
    /// The corresponding C constant is `SO_TYPE`.
    @_alwaysEmitIntoClient
    public static var type: SocketOption { SocketOption(rawValue: 0x1008) }

    /// Keeps other sockets from binding this socket's address and port,
    /// even with ``reuseAddress``.
    ///
    /// Set it before binding. Windows' own option, which POSIX has no need
    /// for, since its ``reuseAddress`` never takes a bound address.
    ///
    /// The corresponding C constant is `SO_EXCLUSIVEADDRUSE`,
    /// `~SO_REUSEADDR`.
    @_alwaysEmitIntoClient
    public static var exclusiveAddressUse: SocketOption { SocketOption(rawValue: ~0x0004) }

    /// Lets an outbound connection share a local port with other
    /// connections to different destinations, rather than taking a port of
    /// its own, when the socket's port is chosen at connect.
    ///
    /// Windows 10 version 1703 and later; Windows' own option.
    ///
    /// The corresponding C constant is `SO_REUSE_UNICASTPORT`.
    @_alwaysEmitIntoClient
    public static var reuseUnicastPort: SocketOption { SocketOption(rawValue: 0x3007) }
  }
}

// MARK: - TCP Options

@available(System 199, *)
extension SocketDescriptor {
  /// TCP-level options for use with `getOption` and `setOption`.
  @frozen
  public struct TCPOption: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Disable Nagle algorithm.
    ///
    /// The corresponding C constant is `TCP_NODELAY`.
    @_alwaysEmitIntoClient
    public static var noDelay: TCPOption { TCPOption(rawValue: 0x0001) }

    /// Maximum segment size.
    ///
    /// Windows 10 and later.
    ///
    /// The corresponding C constant is `TCP_MAXSEG`.
    @_alwaysEmitIntoClient
    public static var maxSegmentSize: TCPOption { TCPOption(rawValue: 4) }

    /// The time a connection is idle, in seconds,
    /// before TCP sends the first keepalive probe.
    ///
    /// The keepalive options take effect
    /// when ``SocketDescriptor/SocketOption/keepAlive`` is enabled.
    /// Windows 10 version 1709 and later.
    ///
    /// The corresponding C constant is `TCP_KEEPIDLE`, Winsock's
    /// `TCP_KEEPALIVE`.
    @_alwaysEmitIntoClient
    public static var keepAliveIdle: TCPOption { TCPOption(rawValue: 3) }

    /// The time between keepalive probes, in seconds,
    /// while the peer doesn't answer.
    ///
    /// Windows 10 version 1709 and later.
    ///
    /// The corresponding C constant is `TCP_KEEPINTVL`.
    @_alwaysEmitIntoClient
    public static var keepAliveInterval: TCPOption { TCPOption(rawValue: 17) }

    /// The number of unanswered keepalive probes
    /// after which TCP drops the connection.
    ///
    /// Windows 10 version 1703 and later, which allows up to 255.
    ///
    /// The corresponding C constant is `TCP_KEEPCNT`.
    @_alwaysEmitIntoClient
    public static var keepAliveCount: TCPOption { TCPOption(rawValue: 16) }
  }
}

// MARK: - Get and Set Options

@available(System 199, *)
extension SocketDescriptor {
  /// Gets a socket option value.
  ///
  /// - Parameters:
  ///   - level: The protocol level.
  ///   - option: The option to get.
  /// - Returns: The option value.
  ///
  /// Winsock's options take the types its documentation gives, which aren't
  /// always POSIX's: `DWORD` milliseconds for the time-outs, and `DWORD`s for
  /// the IPv4 multicast loop and time-to-live, for example.
  ///
  /// The corresponding C function is `getsockopt`.
  @_alwaysEmitIntoClient
  public func getOption<T>(
    _ level: OptionLevel,
    _ option: CInt
  ) throws(Win32.Error) -> T {
    try _getOption(level, option).get()
  }

  @usableFromInline
  internal func _getOption<T>(
    _ level: OptionLevel,
    _ option: CInt
  ) -> Result<T, Win32.Error> {
    // Zeroed storage for the option value: Winsock writes some options'
    // values, such as TCP_NODELAY's, as a single byte.
    var storage = [UInt8](repeating: 0, count: MemoryLayout<T>.size)
    var length = CInterop.SockLen(MemoryLayout<T>.size)

    let result = storage.withUnsafeMutableBytes { buffer in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_getsockopt(
          self.rawValue,
          level.rawValue,
          option,
          buffer.baseAddress,
          &length
        )
      }
    }

    return result.map {
      storage.withUnsafeBytes { buffer in
        buffer.loadUnaligned(as: T.self)
      }
    }
  }

  /// Sets a socket option value.
  ///
  /// - Parameters:
  ///   - level: The protocol level.
  ///   - option: The option to set.
  ///   - value: The value to set.
  ///
  /// The corresponding C function is `setsockopt`.
  @_alwaysEmitIntoClient
  public func setOption<T>(
    _ level: OptionLevel,
    _ option: CInt,
    to value: T
  ) throws(Win32.Error) {
    try _setOption(level, option, to: value).get()
  }

  @usableFromInline
  internal func _setOption<T>(
    _ level: OptionLevel,
    _ option: CInt,
    to value: T
  ) -> Result<(), Win32.Error> {
    withUnsafePointer(to: value) { valuePtr in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_setsockopt(
          self.rawValue,
          level.rawValue,
          option,
          valuePtr,
          CInterop.SockLen(MemoryLayout<T>.size)
        )
      }
    }
  }
}

// MARK: - Convenience Methods

@available(System 199, *)
extension SocketDescriptor {
  /// Gets a socket-level option as an integer.
  @_alwaysEmitIntoClient
  public func getSocketOption(_ option: SocketOption) throws(Win32.Error) -> CInt {
    try getOption(.socket, option.rawValue)
  }

  /// Sets a socket-level option as an integer.
  @_alwaysEmitIntoClient
  public func setSocketOption(_ option: SocketOption, to value: CInt) throws(Win32.Error) {
    try setOption(.socket, option.rawValue, to: value)
  }

  /// Gets a TCP-level option as an integer.
  @_alwaysEmitIntoClient
  public func getTCPOption(_ option: TCPOption) throws(Win32.Error) -> CInt {
    try getOption(.tcp, option.rawValue)
  }

  /// Sets a TCP-level option as an integer.
  @_alwaysEmitIntoClient
  public func setTCPOption(_ option: TCPOption, to value: CInt) throws(Win32.Error) {
    try setOption(.tcp, option.rawValue, to: value)
  }

  /// Enables reuse of local addresses.
  ///
  /// See ``SocketOption/reuseAddress`` for how Windows' differs.
  @_alwaysEmitIntoClient
  public func setReuseAddress(_ enabled: Bool = true) throws(Win32.Error) {
    try setSocketOption(.reuseAddress, to: enabled ? 1 : 0)
  }

  /// Disables the Nagle algorithm.
  @_alwaysEmitIntoClient
  public func setNoDelay(_ enabled: Bool = true) throws(Win32.Error) {
    try setTCPOption(.noDelay, to: enabled ? 1 : 0)
  }
}

#endif // os(Windows)
