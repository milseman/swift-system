/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(WASI)

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

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

// MARK: - Connection States and Options

@available(System 199, *)
extension SocketDescriptor {
  /// The state of a TCP connection, from ``TCPConnectionInfo`` on Darwin
  /// or ``TCPInfo`` on Linux.
  ///
  /// The states are RFC 793's; their numbers differ between platforms.
  @frozen
  public struct TCPState: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: UInt8

    @_alwaysEmitIntoClient
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    #if SYSTEM_PACKAGE_DARWIN
    @_alwaysEmitIntoClient
    internal init(_ value: CInt) { self.init(rawValue: UInt8(value)) }
    #else
    @_alwaysEmitIntoClient
    internal init(_ value: Int) { self.init(rawValue: UInt8(value)) }
    #endif

    /// No connection.
    ///
    /// The corresponding C constant is `TSI_S_CLOSED`, or on Linux `TCP_CLOSE`.
    @_alwaysEmitIntoClient
    public static var closed: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_CLOSED)
      #else
      Self(TCP_CLOSE)
      #endif
    }

    /// Listening for connections.
    ///
    /// The corresponding C constant is `TSI_S_LISTEN`, or on Linux `TCP_LISTEN`.
    @_alwaysEmitIntoClient
    public static var listen: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_LISTEN)
      #else
      Self(TCP_LISTEN)
      #endif
    }

    /// Connecting: a SYN was sent.
    ///
    /// The corresponding C constant is `TSI_S_SYN_SENT`, or on Linux `TCP_SYN_SENT`.
    @_alwaysEmitIntoClient
    public static var synSent: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_SYN_SENT)
      #else
      Self(TCP_SYN_SENT)
      #endif
    }

    /// Accepting: a SYN was received, and one sent.
    ///
    /// The corresponding C constant is `TSI_S_SYN_RECEIVED`, or on Linux `TCP_SYN_RECV`.
    @_alwaysEmitIntoClient
    public static var synReceived: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_SYN_RECEIVED)
      #else
      Self(TCP_SYN_RECV)
      #endif
    }

    /// Connected.
    ///
    /// The corresponding C constant is `TSI_S_ESTABLISHED`, or on Linux `TCP_ESTABLISHED`.
    @_alwaysEmitIntoClient
    public static var established: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_ESTABLISHED)
      #else
      Self(TCP_ESTABLISHED)
      #endif
    }

    /// The peer closed its side; waiting for this side to close.
    ///
    /// The corresponding C constant is `TSI_S__CLOSE_WAIT`, or on Linux `TCP_CLOSE_WAIT`.
    @_alwaysEmitIntoClient
    public static var closeWait: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S__CLOSE_WAIT)
      #else
      Self(TCP_CLOSE_WAIT)
      #endif
    }

    /// This side closed, and sent a FIN.
    ///
    /// The corresponding C constant is `TSI_S_FIN_WAIT_1`, or on Linux `TCP_FIN_WAIT1`.
    @_alwaysEmitIntoClient
    public static var finWait1: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_FIN_WAIT_1)
      #else
      Self(TCP_FIN_WAIT1)
      #endif
    }

    /// Both sides closed at once; waiting for the peer to acknowledge.
    ///
    /// The corresponding C constant is `TSI_S_CLOSING`, or on Linux `TCP_CLOSING`.
    @_alwaysEmitIntoClient
    public static var closing: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_CLOSING)
      #else
      Self(TCP_CLOSING)
      #endif
    }

    /// Closed after the peer; waiting for it to acknowledge.
    ///
    /// The corresponding C constant is `TSI_S_LAST_ACK`, or on Linux `TCP_LAST_ACK`.
    @_alwaysEmitIntoClient
    public static var lastAck: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_LAST_ACK)
      #else
      Self(TCP_LAST_ACK)
      #endif
    }

    /// This side's FIN was acknowledged; waiting for the peer's.
    ///
    /// The corresponding C constant is `TSI_S_FIN_WAIT_2`, or on Linux `TCP_FIN_WAIT2`.
    @_alwaysEmitIntoClient
    public static var finWait2: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_FIN_WAIT_2)
      #else
      Self(TCP_FIN_WAIT2)
      #endif
    }

    /// Closed, and waiting out stray segments.
    ///
    /// The corresponding C constant is `TSI_S_TIME_WAIT`, or on Linux `TCP_TIME_WAIT`.
    @_alwaysEmitIntoClient
    public static var timeWait: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(TSI_S_TIME_WAIT)
      #else
      Self(TCP_TIME_WAIT)
      #endif
    }

    public var description: String {
      switch self {
      case .closed: return "closed"
      case .listen: return "listen"
      case .synSent: return "synSent"
      case .synReceived: return "synReceived"
      case .established: return "established"
      case .closeWait: return "closeWait"
      case .finWait1: return "finWait1"
      case .closing: return "closing"
      case .lastAck: return "lastAck"
      case .finWait2: return "finWait2"
      case .timeWait: return "timeWait"
      default: return "TCPState(\(rawValue))"
      }
    }
  }

  /// The TCP options that a connection uses,
  /// from ``TCPConnectionInfo`` on Darwin or ``TCPInfo`` on Linux.
  @frozen
  public struct TCPConnectionOptions: OptionSet, Hashable, Sendable, CustomStringConvertible {
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Timestamps (RFC 7323).
    ///
    /// The corresponding C constant is `TCPCI_OPT_TIMESTAMPS`,
    /// or on Linux `TCPI_OPT_TIMESTAMPS`.
    @_alwaysEmitIntoClient
    public static var timestamps: Self { Self(rawValue: 0x1) }

    /// Selective acknowledgments (RFC 2018).
    ///
    /// The corresponding C constant is `TCPCI_OPT_SACK`, or on Linux `TCPI_OPT_SACK`.
    @_alwaysEmitIntoClient
    public static var selectiveAcknowledgments: Self { Self(rawValue: 0x2) }

    /// Window scaling (RFC 7323).
    ///
    /// The corresponding C constant is `TCPCI_OPT_WSCALE`, or on Linux `TCPI_OPT_WSCALE`.
    @_alwaysEmitIntoClient
    public static var windowScaling: Self { Self(rawValue: 0x4) }

    /// Explicit congestion notification (RFC 3168).
    ///
    /// The corresponding C constant is `TCPCI_OPT_ECN`, or on Linux `TCPI_OPT_ECN`.
    @_alwaysEmitIntoClient
    public static var explicitCongestionNotification: Self { Self(rawValue: 0x8) }

    #if os(Linux) || os(Android)
    /// The peer set an ECN bit in at least one segment.
    ///
    /// The corresponding C constant is `TCPI_OPT_ECN_SEEN`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var explicitCongestionNotificationSeen: Self { Self(rawValue: 0x10) }

    /// The SYN carried data, or its SYN-ACK acknowledged data (TCP Fast Open).
    ///
    /// The corresponding C constant is `TCPI_OPT_SYN_DATA`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var synData: Self { Self(rawValue: 0x20) }
    #endif

    public var description: String {
      var names: [(Self, String)] = [
        (.timestamps, ".timestamps"),
        (.selectiveAcknowledgments, ".selectiveAcknowledgments"),
        (.windowScaling, ".windowScaling"),
        (.explicitCongestionNotification, ".explicitCongestionNotification"),
      ]
      #if os(Linux) || os(Android)
      names.append((.explicitCongestionNotificationSeen, ".explicitCongestionNotificationSeen"))
      names.append((.synData, ".synData"))
      #endif
      var rest = self
      var parts: [String] = []
      for (option, name) in names where rest.contains(option) {
        parts.append(name)
        rest.remove(option)
      }
      if !rest.isEmpty { parts.append("TCPConnectionOptions(rawValue: \(rest.rawValue))") }
      return "[" + parts.joined(separator: ", ") + "]"
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

// MARK: - Darwin: tcp_connection_info

#if SYSTEM_PACKAGE_DARWIN

@available(System 199, *)
extension CInterop {
  /// The corresponding C type is `struct tcp_connection_info`.
  public typealias TCPConnectionInfo = tcp_connection_info
}

@available(System 199, *)
extension SocketDescriptor.TCPOption {
  /// The state and statistics of a TCP connection, read-only.
  ///
  /// The corresponding C constant is `TCP_CONNECTION_INFO`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var connectionInfo: Self { Self(rawValue: TCP_CONNECTION_INFO) }
}

@available(System 199, *)
extension SocketDescriptor {
  /// The state and statistics of a TCP connection, as Darwin reports them.
  ///
  /// ``SocketDescriptor/tcpConnectionInfo()`` returns one.
  /// Sizes are in bytes, and times are milliseconds, as Darwin keeps them.
  ///
  /// The corresponding C type is `struct tcp_connection_info`.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct TCPConnectionInfo: RawRepresentable, Sendable {
    /// The C structure.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.TCPConnectionInfo

    /// Creates connection information from the C structure.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.TCPConnectionInfo) { self.rawValue = rawValue }

    /// The connection's state.
    ///
    /// The corresponding C field is `tcpi_state`.
    public var state: TCPState { TCPState(rawValue: rawValue.tcpi_state) }

    /// The options that the connection uses.
    ///
    /// The corresponding C field is `tcpi_options`.
    public var options: TCPConnectionOptions {
      TCPConnectionOptions(rawValue: rawValue.tcpi_options)
    }

    /// The shift count of the send window's scale.
    ///
    /// The corresponding C field is `tcpi_snd_wscale`.
    public var sendWindowScale: UInt8 { rawValue.tcpi_snd_wscale }

    /// The shift count of the receive window's scale.
    ///
    /// The corresponding C field is `tcpi_rcv_wscale`.
    public var receiveWindowScale: UInt8 { rawValue.tcpi_rcv_wscale }

    /// Whether the connection is recovering from lost segments.
    ///
    /// The corresponding C constant is `TCPCI_FLAG_LOSSRECOVERY`.
    public var isRecoveringFromLoss: Bool {
      rawValue.tcpi_flags & UInt32(TCPCI_FLAG_LOSSRECOVERY) != 0
    }

    /// Whether the connection has seen segments arrive out of order.
    ///
    /// The corresponding C constant is `TCPCI_FLAG_REORDERING_DETECTED`.
    public var hasDetectedReordering: Bool {
      rawValue.tcpi_flags & UInt32(TCPCI_FLAG_REORDERING_DETECTED) != 0
    }

    /// The largest segment the connection sends.
    ///
    /// The corresponding C field is `tcpi_maxseg`.
    public var maximumSegmentSize: Int { Int(rawValue.tcpi_maxseg) }

    /// The slow-start threshold, in bytes.
    ///
    /// The corresponding C field is `tcpi_snd_ssthresh`.
    public var sendSlowStartThreshold: Int { Int(rawValue.tcpi_snd_ssthresh) }

    /// The congestion window, in bytes.
    ///
    /// The corresponding C field is `tcpi_snd_cwnd`.
    public var sendCongestionWindow: Int { Int(rawValue.tcpi_snd_cwnd) }

    /// The peer's receive window, in bytes.
    ///
    /// The corresponding C field is `tcpi_snd_wnd`.
    public var sendWindow: Int { Int(rawValue.tcpi_snd_wnd) }

    /// The bytes in the socket's send buffer, including those sent but not
    /// yet acknowledged.
    ///
    /// The corresponding C field is `tcpi_snd_sbbytes`.
    public var sendBufferedBytes: Int { Int(rawValue.tcpi_snd_sbbytes) }

    /// This side's receive window, in bytes.
    ///
    /// The corresponding C field is `tcpi_rcv_wnd`.
    public var receiveWindow: Int { Int(rawValue.tcpi_rcv_wnd) }

    /// The packets sent.
    ///
    /// The corresponding C field is `tcpi_txpackets`.
    public var packetsSent: UInt64 { rawValue.tcpi_txpackets }

    /// The bytes sent.
    ///
    /// The corresponding C field is `tcpi_txbytes`.
    public var bytesSent: UInt64 { rawValue.tcpi_txbytes }

    /// The packets retransmitted.
    ///
    /// The corresponding C field is `tcpi_txretransmitpackets`.
    public var packetsRetransmitted: UInt64 { rawValue.tcpi_txretransmitpackets }

    /// The bytes retransmitted.
    ///
    /// The corresponding C field is `tcpi_txretransmitbytes`.
    public var bytesRetransmitted: UInt64 { rawValue.tcpi_txretransmitbytes }

    /// The packets received.
    ///
    /// The corresponding C field is `tcpi_rxpackets`.
    public var packetsReceived: UInt64 { rawValue.tcpi_rxpackets }

    /// The bytes received.
    ///
    /// The corresponding C field is `tcpi_rxbytes`.
    public var bytesReceived: UInt64 { rawValue.tcpi_rxbytes }

    /// The bytes received out of order.
    ///
    /// The corresponding C field is `tcpi_rxoutoforderbytes`.
    public var bytesReceivedOutOfOrder: UInt64 { rawValue.tcpi_rxoutoforderbytes }
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SocketDescriptor.TCPConnectionInfo {
  /// The retransmission timeout.
  ///
  /// It was 0 for an idle loopback connection on macOS 26.3.
  ///
  /// The corresponding C field is `tcpi_rto`.
  public var retransmitTimeout: Duration { .milliseconds(rawValue.tcpi_rto) }

  /// The most recent round-trip time.
  ///
  /// The corresponding C field is `tcpi_rttcur`.
  public var roundTripTime: Duration { .milliseconds(rawValue.tcpi_rttcur) }

  /// The smoothed round-trip time.
  ///
  /// The corresponding C field is `tcpi_srtt`.
  public var smoothedRoundTripTime: Duration { .milliseconds(rawValue.tcpi_srtt) }

  /// The round-trip time's variance.
  ///
  /// The corresponding C field is `tcpi_rttvar`.
  public var roundTripTimeVariance: Duration { .milliseconds(rawValue.tcpi_rttvar) }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Returns the state and statistics of this TCP socket's connection.
  ///
  /// The corresponding C constant is `TCP_CONNECTION_INFO`,
  /// at the `IPPROTO_TCP` level.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func tcpConnectionInfo() throws(Errno) -> TCPConnectionInfo {
    TCPConnectionInfo(rawValue: try _value(
      OptionLevel.tcp.rawValue, TCPOption.connectionInfo.rawValue,
      CInterop.TCPConnectionInfo()
    ).get())
  }
}

#endif // SYSTEM_PACKAGE_DARWIN

// MARK: - Linux: tcp_info

#if os(Linux) || os(Android)

@available(System 199, *)
extension CInterop {
  /// The C library's declaration of `struct tcp_info`,
  /// which can be older, and shorter, than the kernel's.
  ///
  /// The corresponding C type is `struct tcp_info`.
  public typealias TCPInfo = tcp_info
}

@available(System 199, *)
extension SocketDescriptor.TCPOption {
  /// The state and statistics of a TCP connection, read-only.
  ///
  /// The corresponding C constant is `TCP_INFO`.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var info: Self { Self(rawValue: TCP_INFO) }
}

// The kernel's struct tcp_info, which only grows. glibc declares its first
// 104 bytes; System reads those through glibc's declaration, and the rest
// by their offsets in <linux/tcp.h>, when the kernel supplies them.
@usableFromInline
internal typealias _TCPInfoBytes = (
  UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
  UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
  UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
  UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64
)

@available(System 199, *)
extension SocketDescriptor {
  /// The state and statistics of a TCP connection, as Linux reports them.
  ///
  /// ``SocketDescriptor/tcpInfo()`` returns one.
  /// Sizes are in bytes or segments, as each property says,
  /// and times are microseconds or milliseconds, as Linux keeps them.
  /// Properties whose type is optional are the kernel's newer fields,
  /// which are `nil` when the running kernel doesn't report them.
  ///
  /// The corresponding C type is `struct tcp_info`.
  ///
  /// - Note: Only available on Linux and Android.
  @frozen
  public struct TCPInfo: Sendable {
    @usableFromInline
    internal var _bytes: _TCPInfoBytes

    /// The number of bytes the kernel filled in.
    @usableFromInline
    internal var _count: Int

    @usableFromInline
    internal init(_bytes: _TCPInfoBytes, count: Int) {
      self._bytes = _bytes
      self._count = count
    }

    /// The fields that the C library declares.
    ///
    /// Only the bytes the kernel filled in are copied, and no more than this
    /// buffer holds, since a C library can declare a longer structure than
    /// either: glibc's newest is 280 bytes. The rest are zero.
    public var rawValue: CInterop.TCPInfo {
      var info = CInterop.TCPInfo()
      withUnsafeMutableBytes(of: &info) { destination in
        withUnsafeBytes(of: _bytes) { source in
          let count = min(_count, source.count, destination.count)
          destination.copyMemory(from: UnsafeRawBufferPointer(rebasing: source.prefix(count)))
        }
      }
      return info
    }

    /// A newer field, at its offset in the kernel's structure,
    /// or `nil` if the kernel didn't fill it in.
    internal func _field<T: FixedWidthInteger>(_ offset: Int, as type: T.Type) -> T? {
      guard offset + MemoryLayout<T>.size <= _count else { return nil }
      return withUnsafeBytes(of: _bytes) { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }

    /// The connection's state.
    ///
    /// The corresponding C field is `tcpi_state`.
    public var state: TCPState { TCPState(rawValue: rawValue.tcpi_state) }

    /// The congestion-avoidance state: open, disorder, congestion window
    /// reduced, recovery, or loss, from 0 through 4.
    ///
    /// The corresponding C field is `tcpi_ca_state`.
    public var congestionState: UInt8 { rawValue.tcpi_ca_state }

    /// The retransmission timeouts since the last acknowledgment.
    ///
    /// The corresponding C field is `tcpi_retransmits`.
    public var retransmits: Int { Int(rawValue.tcpi_retransmits) }

    /// The unanswered zero-window probes.
    ///
    /// The corresponding C field is `tcpi_probes`.
    public var probes: Int { Int(rawValue.tcpi_probes) }

    /// The exponential backoff of the retransmission timer.
    ///
    /// The corresponding C field is `tcpi_backoff`.
    public var backoff: Int { Int(rawValue.tcpi_backoff) }

    /// The options that the connection uses.
    ///
    /// The corresponding C field is `tcpi_options`.
    public var options: TCPConnectionOptions {
      TCPConnectionOptions(rawValue: UInt32(rawValue.tcpi_options))
    }

    /// The shift count of the send window's scale.
    ///
    /// The corresponding C field is `tcpi_snd_wscale`.
    public var sendWindowScale: UInt8 { UInt8(rawValue.tcpi_snd_wscale) }

    /// The shift count of the receive window's scale.
    ///
    /// The corresponding C field is `tcpi_rcv_wscale`.
    public var receiveWindowScale: UInt8 { UInt8(rawValue.tcpi_rcv_wscale) }

    /// The largest segment this side sends.
    ///
    /// The corresponding C field is `tcpi_snd_mss`.
    public var sendMaximumSegmentSize: Int { Int(rawValue.tcpi_snd_mss) }

    /// The largest segment this side has received, as it estimates it.
    ///
    /// The corresponding C field is `tcpi_rcv_mss`.
    public var receiveMaximumSegmentSize: Int { Int(rawValue.tcpi_rcv_mss) }

    /// The segments sent but not yet acknowledged.
    ///
    /// The corresponding C field is `tcpi_unacked`.
    public var unacknowledgedSegments: Int { Int(rawValue.tcpi_unacked) }

    /// The segments selectively acknowledged.
    ///
    /// The corresponding C field is `tcpi_sacked`.
    public var selectivelyAcknowledgedSegments: Int { Int(rawValue.tcpi_sacked) }

    /// The segments thought lost.
    ///
    /// The corresponding C field is `tcpi_lost`.
    public var lostSegments: Int { Int(rawValue.tcpi_lost) }

    /// The segments retransmitted and not yet acknowledged.
    ///
    /// The corresponding C field is `tcpi_retrans`.
    public var retransmittedSegments: Int { Int(rawValue.tcpi_retrans) }

    /// The path's maximum transmission unit.
    ///
    /// The corresponding C field is `tcpi_pmtu`.
    public var pathMTU: Int { Int(rawValue.tcpi_pmtu) }

    /// The receive slow-start threshold, in bytes.
    ///
    /// The corresponding C field is `tcpi_rcv_ssthresh`.
    public var receiveSlowStartThreshold: Int { Int(rawValue.tcpi_rcv_ssthresh) }

    /// The send slow-start threshold, in segments.
    ///
    /// The corresponding C field is `tcpi_snd_ssthresh`.
    public var sendSlowStartThreshold: Int { Int(rawValue.tcpi_snd_ssthresh) }

    /// The congestion window, in segments.
    ///
    /// The corresponding C field is `tcpi_snd_cwnd`.
    public var sendCongestionWindow: Int { Int(rawValue.tcpi_snd_cwnd) }

    /// The maximum segment size this side advertises.
    ///
    /// The corresponding C field is `tcpi_advmss`.
    public var advertisedMaximumSegmentSize: Int { Int(rawValue.tcpi_advmss) }

    /// How far segments can be reordered before they're taken as lost,
    /// in segments.
    ///
    /// The corresponding C field is `tcpi_reordering`.
    public var reordering: Int { Int(rawValue.tcpi_reordering) }

    /// The space this side has for received data, in bytes.
    ///
    /// The corresponding C field is `tcpi_rcv_space`.
    public var receiveSpace: Int { Int(rawValue.tcpi_rcv_space) }

    /// The segments retransmitted over the connection's life.
    ///
    /// The corresponding C field is `tcpi_total_retrans`.
    public var totalRetransmissions: Int { Int(rawValue.tcpi_total_retrans) }

    /// The pacing rate, in bytes a second (Linux 3.15).
    ///
    /// The corresponding C field is `tcpi_pacing_rate`.
    public var pacingRate: UInt64? { _field(104, as: UInt64.self) }

    /// The maximum pacing rate, in bytes a second (Linux 3.15).
    ///
    /// The corresponding C field is `tcpi_max_pacing_rate`.
    public var maximumPacingRate: UInt64? { _field(112, as: UInt64.self) }

    /// The bytes sent that the peer acknowledged (Linux 4.1).
    ///
    /// The corresponding C field is `tcpi_bytes_acked`.
    public var bytesAcknowledged: UInt64? { _field(120, as: UInt64.self) }

    /// The bytes received (Linux 4.1).
    ///
    /// The corresponding C field is `tcpi_bytes_received`.
    public var bytesReceived: UInt64? { _field(128, as: UInt64.self) }

    /// The segments sent (Linux 4.2).
    ///
    /// The corresponding C field is `tcpi_segs_out`.
    public var segmentsSent: Int? { _field(136, as: UInt32.self).map(Int.init) }

    /// The segments received (Linux 4.2).
    ///
    /// The corresponding C field is `tcpi_segs_in`.
    public var segmentsReceived: Int? { _field(140, as: UInt32.self).map(Int.init) }

    /// The bytes written that haven't been sent yet (Linux 4.6).
    ///
    /// The corresponding C field is `tcpi_notsent_bytes`.
    public var notSentBytes: Int? { _field(144, as: UInt32.self).map(Int.init) }

    /// The segments with data received (Linux 4.6).
    ///
    /// The corresponding C field is `tcpi_data_segs_in`.
    public var dataSegmentsReceived: Int? { _field(152, as: UInt32.self).map(Int.init) }

    /// The segments with data sent (Linux 4.6).
    ///
    /// The corresponding C field is `tcpi_data_segs_out`.
    public var dataSegmentsSent: Int? { _field(156, as: UInt32.self).map(Int.init) }

    /// The most recent delivery rate, in bytes a second (Linux 4.9).
    ///
    /// The corresponding C field is `tcpi_delivery_rate`.
    public var deliveryRate: UInt64? { _field(160, as: UInt64.self) }

    /// The segments delivered, retransmissions included (Linux 4.18).
    ///
    /// The corresponding C field is `tcpi_delivered`.
    public var deliveredSegments: Int? { _field(192, as: UInt32.self).map(Int.init) }

    /// The segments delivered with the ECN congestion-experienced mark
    /// (Linux 4.18).
    ///
    /// The corresponding C field is `tcpi_delivered_ce`.
    public var deliveredCongestionExperiencedSegments: Int? {
      _field(196, as: UInt32.self).map(Int.init)
    }

    /// The bytes sent, retransmissions included (Linux 4.19).
    ///
    /// The corresponding C field is `tcpi_bytes_sent`.
    public var bytesSent: UInt64? { _field(200, as: UInt64.self) }

    /// The bytes retransmitted (Linux 4.19).
    ///
    /// The corresponding C field is `tcpi_bytes_retrans`.
    public var bytesRetransmitted: UInt64? { _field(208, as: UInt64.self) }

    /// The duplicate segments that the peer reported (Linux 4.19).
    ///
    /// The corresponding C field is `tcpi_dsack_dups`.
    public var duplicateSegmentsReported: Int? { _field(216, as: UInt32.self).map(Int.init) }

    /// The reordering events seen (Linux 4.19).
    ///
    /// The corresponding C field is `tcpi_reord_seen`.
    public var reorderingEvents: Int? { _field(220, as: UInt32.self).map(Int.init) }

    /// The packets received out of order (Linux 5.4).
    ///
    /// The corresponding C field is `tcpi_rcv_ooopack`.
    public var packetsReceivedOutOfOrder: Int? { _field(224, as: UInt32.self).map(Int.init) }

    /// The peer's receive window, in bytes (Linux 5.4).
    ///
    /// The corresponding C field is `tcpi_snd_wnd`.
    public var sendWindow: Int? { _field(228, as: UInt32.self).map(Int.init) }
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SocketDescriptor.TCPInfo {
  /// The retransmission timeout.
  ///
  /// The corresponding C field is `tcpi_rto`, in microseconds.
  public var retransmitTimeout: Duration { .microseconds(rawValue.tcpi_rto) }

  /// The delayed-acknowledgment timeout.
  ///
  /// The corresponding C field is `tcpi_ato`, in microseconds.
  public var acknowledgmentTimeout: Duration { .microseconds(rawValue.tcpi_ato) }

  /// The time since data was last sent.
  ///
  /// The corresponding C field is `tcpi_last_data_sent`, in milliseconds.
  public var timeSinceDataSent: Duration { .milliseconds(rawValue.tcpi_last_data_sent) }

  /// The time since data was last received.
  ///
  /// The corresponding C field is `tcpi_last_data_recv`, in milliseconds.
  public var timeSinceDataReceived: Duration { .milliseconds(rawValue.tcpi_last_data_recv) }

  /// The time since an acknowledgment was last received.
  ///
  /// The corresponding C field is `tcpi_last_ack_recv`, in milliseconds.
  public var timeSinceAcknowledgmentReceived: Duration {
    .milliseconds(rawValue.tcpi_last_ack_recv)
  }

  /// The smoothed round-trip time.
  ///
  /// The corresponding C field is `tcpi_rtt`, in microseconds.
  public var roundTripTime: Duration { .microseconds(rawValue.tcpi_rtt) }

  /// The round-trip time's mean deviation.
  ///
  /// The corresponding C field is `tcpi_rttvar`, in microseconds.
  public var roundTripTimeVariance: Duration { .microseconds(rawValue.tcpi_rttvar) }

  /// The round-trip time that the receiver estimates.
  ///
  /// The corresponding C field is `tcpi_rcv_rtt`, in microseconds.
  public var receiveRoundTripTime: Duration { .microseconds(rawValue.tcpi_rcv_rtt) }

  /// The smallest round-trip time seen (Linux 4.6).
  ///
  /// The corresponding C field is `tcpi_min_rtt`, in microseconds.
  public var minimumRoundTripTime: Duration? {
    _field(148, as: UInt32.self).map { .microseconds($0) }
  }

  /// The time spent sending data (Linux 4.10).
  ///
  /// The corresponding C field is `tcpi_busy_time`, in microseconds.
  public var busyTime: Duration? { _field(168, as: UInt64.self).map { .microseconds($0) } }

  /// The time sending was limited by the peer's receive window (Linux 4.10).
  ///
  /// The corresponding C field is `tcpi_rwnd_limited`, in microseconds.
  public var receiveWindowLimitedTime: Duration? {
    _field(176, as: UInt64.self).map { .microseconds($0) }
  }

  /// The time sending was limited by the send buffer (Linux 4.10).
  ///
  /// The corresponding C field is `tcpi_sndbuf_limited`, in microseconds.
  public var sendBufferLimitedTime: Duration? {
    _field(184, as: UInt64.self).map { .microseconds($0) }
  }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Returns the state and statistics of this TCP socket's connection.
  ///
  /// The corresponding C constant is `TCP_INFO`, at the `IPPROTO_TCP` level.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func tcpInfo() throws(Errno) -> TCPInfo {
    try _tcpInfo().get()
  }

  @usableFromInline
  internal func _tcpInfo() -> Result<TCPInfo, Errno> {
    var bytes: _TCPInfoBytes = (
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
    var length = CInterop.SockLen(MemoryLayout<_TCPInfoBytes>.size)
    return nothingOrErrno(retryOnInterrupt: false) {
      system_getsockopt(
        self.rawValue, OptionLevel.tcp.rawValue, TCPOption.info.rawValue, &bytes, &length)
    }.map { TCPInfo(_bytes: bytes, count: Int(length)) }
  }
}

#endif // os(Linux) || os(Android)

#endif // !os(WASI)
