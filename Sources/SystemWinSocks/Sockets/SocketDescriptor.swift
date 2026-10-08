/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

/// A Winsock socket.
///
/// A `SocketDescriptor` is a type-safe wrapper around a Winsock `SOCKET`.
/// It has the names and signatures that SystemSockets gives a socket on
/// POSIX systems, so that code written against them compiles on Windows
/// too, where the concept holds; what Winsock lacks, such as `socketpair`
/// and passing descriptors, it lacks too. Its operations throw
/// ``Win32/Error``, whose Winsock codes, such as ``Win32/Error/wouldBlock``,
/// have `Errno`'s names.
///
/// A Winsock socket isn't a file descriptor: close it with ``close()``,
/// which calls `closesocket`, rather than with the C runtime's `close`.
///
/// System starts Winsock (`WSAStartup`) the first time it creates a socket,
/// and leaves it started.
@frozen
@available(System 199, *)
public struct SocketDescriptor: RawRepresentable, Hashable, Codable, Sendable {
  /// The raw Winsock socket handle.
  ///
  /// It's a `SOCKET`, a `UINT_PTR`, where it's a `CInt` on other
  /// platforms. `INVALID_SOCKET` is no socket.
  @_alwaysEmitIntoClient
  public let rawValue: SOCKET

  /// Creates a strongly-typed socket from a raw Winsock socket handle.
  @_alwaysEmitIntoClient
  public init(rawValue: SOCKET) { self.rawValue = rawValue }
}

// MARK: - Domain (Protocol Family)

@available(System 199, *)
extension SocketDescriptor {
  /// Communications domain, identifying the protocol family.
  ///
  /// The domain specifies the protocol family to be used for communication.
  /// Windows has `.ipv4`, `.ipv6`, and, for stream sockets, `.local`.
  @frozen
  public struct Domain: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Unspecified protocol.
    ///
    /// The corresponding C constant is `PF_UNSPEC`.
    @_alwaysEmitIntoClient
    public static var unspecified: Domain { Domain(rawValue: 0) }

    /// Local (Unix domain) communication.
    ///
    /// Windows has local stream sockets, named by a path, but no local
    /// datagram sockets, no `socketpair`, and no passing descriptors.
    ///
    /// The corresponding C constant is `PF_UNIX`.
    @_alwaysEmitIntoClient
    public static var local: Domain { Domain(rawValue: 1) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "local")
    public static var unix: Domain { local }

    /// Internet Protocol version 4.
    ///
    /// The corresponding C constant is `PF_INET`.
    @_alwaysEmitIntoClient
    public static var ipv4: Domain { Domain(rawValue: 2) }

    /// Internet Protocol version 6.
    ///
    /// Its value is 23 on Windows, where it's 30 on Darwin and 10 on Linux.
    ///
    /// The corresponding C constant is `PF_INET6`.
    @_alwaysEmitIntoClient
    public static var ipv6: Domain { Domain(rawValue: 23) }

    public var description: String {
      switch self {
      case .unspecified: return "unspecified"
      case .local: return "local"
      case .ipv4: return "ipv4"
      case .ipv6: return "ipv6"
      default: return "Domain(\(rawValue))"
      }
    }
  }
}

// MARK: - Connection Type (Socket Type)

@available(System 199, *)
extension SocketDescriptor {
  /// The socket type, specifying the semantics of communication.
  ///
  /// The connection type determines how data is transmitted. Stream sockets
  /// provide reliable, ordered byte streams, while datagram sockets provide
  /// connectionless, unreliable messages.
  @frozen
  public struct ConnectionType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Sequenced, reliable, two-way, connection-based byte streams.
    ///
    /// The corresponding C constant is `SOCK_STREAM`.
    @_alwaysEmitIntoClient
    public static var stream: ConnectionType { ConnectionType(rawValue: 1) }

    /// Connectionless, unreliable datagrams of a fixed maximum length.
    ///
    /// The corresponding C constant is `SOCK_DGRAM`.
    @_alwaysEmitIntoClient
    public static var datagram: ConnectionType { ConnectionType(rawValue: 2) }

    /// Raw network protocol access.
    ///
    /// Creating a raw socket requires administrator rights.
    ///
    /// The corresponding C constant is `SOCK_RAW`.
    @_alwaysEmitIntoClient
    public static var raw: ConnectionType { ConnectionType(rawValue: 3) }

    /// Reliably-delivered message.
    ///
    /// On Windows, the reliable multicast protocol (PGM) provides these,
    /// when it's installed.
    ///
    /// The corresponding C constant is `SOCK_RDM`.
    @_alwaysEmitIntoClient
    public static var reliablyDeliveredMessage: ConnectionType {
      ConnectionType(rawValue: 4)
    }

    /// Sequenced packet stream.
    ///
    /// Windows' own protocols don't provide these.
    ///
    /// The corresponding C constant is `SOCK_SEQPACKET`.
    @_alwaysEmitIntoClient
    public static var sequencedPacketStream: ConnectionType {
      ConnectionType(rawValue: 5)
    }

    public var description: String {
      switch self {
      case .stream: return "stream"
      case .datagram: return "datagram"
      case .raw: return "raw"
      case .reliablyDeliveredMessage: return "rdm"
      case .sequencedPacketStream: return "seqpacket"
      default: return "ConnectionType(\(rawValue))"
      }
    }
  }
}

// MARK: - Protocol ID

@available(System 199, *)
extension SocketDescriptor {
  /// Identifies a particular protocol to use for communication.
  ///
  /// Protocol numbers are specific to the communication domain. Some symbolic
  /// names may have the same underlying value in different contexts.
  @frozen
  public struct ProtocolID: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Default protocol for the socket type.
    @_alwaysEmitIntoClient
    public static var `default`: ProtocolID { ProtocolID(rawValue: 0) }

    /// Internet Protocol (IP).
    ///
    /// The corresponding C constant is `IPPROTO_IP`.
    @_alwaysEmitIntoClient
    public static var ip: ProtocolID { ProtocolID(rawValue: 0) }

    /// Transmission Control Protocol (TCP).
    ///
    /// The corresponding C constant is `IPPROTO_TCP`.
    @_alwaysEmitIntoClient
    public static var tcp: ProtocolID { ProtocolID(rawValue: 6) }

    /// User Datagram Protocol (UDP).
    ///
    /// The corresponding C constant is `IPPROTO_UDP`.
    @_alwaysEmitIntoClient
    public static var udp: ProtocolID { ProtocolID(rawValue: 17) }

    /// IPv4 encapsulation.
    ///
    /// The corresponding C constant is `IPPROTO_IPV4`.
    @_alwaysEmitIntoClient
    public static var ipv4: ProtocolID { ProtocolID(rawValue: 4) }

    /// IPv6 header.
    ///
    /// The corresponding C constant is `IPPROTO_IPV6`.
    @_alwaysEmitIntoClient
    public static var ipv6: ProtocolID { ProtocolID(rawValue: 41) }

    /// Raw IP packet.
    ///
    /// The corresponding C constant is `IPPROTO_RAW`.
    @_alwaysEmitIntoClient
    public static var raw: ProtocolID { ProtocolID(rawValue: 255) }

    public var description: String {
      rawValue.description
    }
  }
}

// MARK: - Message Flags

@available(System 199, *)
extension SocketDescriptor {
  /// Flags for send and receive operations.
  ///
  /// Winsock has no `MSG_EOR` or `MSG_NOSIGNAL`: Windows has no `SIGPIPE`,
  /// and a send on a broken connection throws ``Win32/Error/connectionReset``
  /// or ``Win32/Error/socketShutdown``.
  @frozen
  public struct MessageFlags: OptionSet, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// No flags.
    @_alwaysEmitIntoClient
    public static var none: MessageFlags { MessageFlags(rawValue: 0) }

    /// Process out-of-band data.
    ///
    /// The corresponding C constant is `MSG_OOB`.
    @_alwaysEmitIntoClient
    public static var outOfBand: MessageFlags { MessageFlags(rawValue: 0x1) }

    /// Bypass routing, use direct interface.
    ///
    /// Windows' own providers ignore it.
    ///
    /// The corresponding C constant is `MSG_DONTROUTE`.
    @_alwaysEmitIntoClient
    public static var doNotRoute: MessageFlags { MessageFlags(rawValue: 0x4) }

    /// Peek at incoming message without removing it.
    ///
    /// The corresponding C constant is `MSG_PEEK`.
    @_alwaysEmitIntoClient
    public static var peek: MessageFlags { MessageFlags(rawValue: 0x2) }

    /// Wait for full request or error.
    ///
    /// On Windows, a receive with this flag on a nonblocking socket, or of a
    /// protocol that doesn't support it, throws
    /// ``Win32/Error/notSupportedOnSocket``.
    ///
    /// The corresponding C constant is `MSG_WAITALL`.
    @_alwaysEmitIntoClient
    public static var waitForAll: MessageFlags { MessageFlags(rawValue: 0x8) }

    /// Data was truncated.
    ///
    /// Only a received message's flags have it. A plain receive of a
    /// datagram that doesn't fit throws ``Win32/Error/messageTooLong``
    /// instead.
    ///
    /// The corresponding C constant is `MSG_TRUNC`.
    @_alwaysEmitIntoClient
    public static var dataTruncated: MessageFlags { MessageFlags(rawValue: 0x0100) }

    /// Control data was truncated.
    ///
    /// The corresponding C constant is `MSG_CTRUNC`.
    @_alwaysEmitIntoClient
    public static var controlTruncated: MessageFlags { MessageFlags(rawValue: 0x0200) }

    public var description: String {
      _buildDescription([
        (.outOfBand, ".outOfBand"),
        (.doNotRoute, ".doNotRoute"),
        (.peek, ".peek"),
        (.waitForAll, ".waitForAll"),
        (.dataTruncated, ".dataTruncated"),
        (.controlTruncated, ".controlTruncated"),
      ])
    }
  }
}

// MARK: - Shutdown Kind

@available(System 199, *)
extension SocketDescriptor {
  /// Specifies which parts of a full-duplex connection to shut down.
  @frozen
  public struct ShutdownKind: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Disallow further receives.
    ///
    /// The corresponding C constant is `SD_RECEIVE`.
    @_alwaysEmitIntoClient
    public static var read: ShutdownKind { ShutdownKind(rawValue: 0x00) }

    /// Disallow further sends.
    ///
    /// The corresponding C constant is `SD_SEND`.
    @_alwaysEmitIntoClient
    public static var write: ShutdownKind { ShutdownKind(rawValue: 0x01) }

    /// Disallow further sends and receives.
    ///
    /// The corresponding C constant is `SD_BOTH`.
    @_alwaysEmitIntoClient
    public static var readWrite: ShutdownKind { ShutdownKind(rawValue: 0x02) }

    public var description: String {
      switch self {
      case .read: return "read"
      case .write: return "write"
      case .readWrite: return "readWrite"
      default: return "ShutdownKind(\(rawValue))"
      }
    }
  }
}

#endif // os(Windows)
