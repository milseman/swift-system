/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - IPv4 Option Names

@available(System 199, *)
extension SocketDescriptor {
  /// IPv4-level options, at the ``OptionLevel/ip`` level,
  /// for use with `getOption` and `setOption`.
  ///
  /// Most have a typed method on ``SocketDescriptor``,
  /// such as ``setTimeToLive(_:)``, which is the easier way to use them.
  @frozen
  public struct IPOption: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The time-to-live of the unicast packets the socket sends.
    ///
    /// The corresponding C constant is `IP_TTL`.
    @_alwaysEmitIntoClient
    public static var timeToLive: IPOption { IPOption(rawValue: 4) }

    /// The type-of-service byte of the packets the socket sends.
    ///
    /// Windows ignores the value it's set to unless its
    /// `DisableUserTOSSetting` registry value says otherwise, and
    /// recommends its quality-of-service API instead.
    ///
    /// The corresponding C constant is `IP_TOS`.
    @_alwaysEmitIntoClient
    public static var typeOfService: IPOption { IPOption(rawValue: 3) }

    /// Whether the socket receives each datagram's type-of-service byte
    /// as an ancillary message.
    ///
    /// The corresponding C constant is `IP_RECVTOS`.
    @_alwaysEmitIntoClient
    public static var receiveTypeOfService: IPOption { IPOption(rawValue: 40) }

    /// The packet information of a datagram, in an ancillary message:
    /// its destination address and the interface it arrived on.
    ///
    /// The corresponding C constant is `IP_PKTINFO`.
    @_alwaysEmitIntoClient
    public static var packetInfo: IPOption { IPOption(rawValue: 19) }

    /// Whether the socket receives each datagram's packet information
    /// as an ancillary message.
    ///
    /// The corresponding C constant is `IP_PKTINFO`, which on Windows, as on
    /// Linux, also names the option.
    @_alwaysEmitIntoClient
    public static var receivePacketInfo: IPOption { IPOption(rawValue: 19) }

    /// Whether the packets the socket sends include their own IP header,
    /// for a raw socket.
    ///
    /// The corresponding C constant is `IP_HDRINCL`.
    @_alwaysEmitIntoClient
    public static var headerIncluded: IPOption { IPOption(rawValue: 2) }

    /// The interface to send multicast datagrams from.
    ///
    /// The corresponding C constant is `IP_MULTICAST_IF`.
    @_alwaysEmitIntoClient
    public static var multicastInterface: IPOption { IPOption(rawValue: 9) }

    /// The time-to-live of the multicast datagrams the socket sends.
    ///
    /// The corresponding C constant is `IP_MULTICAST_TTL`.
    @_alwaysEmitIntoClient
    public static var multicastTimeToLive: IPOption { IPOption(rawValue: 10) }

    /// Whether the multicast datagrams the socket sends loop back to this host.
    ///
    /// The corresponding C constant is `IP_MULTICAST_LOOP`.
    @_alwaysEmitIntoClient
    public static var multicastLoopback: IPOption { IPOption(rawValue: 11) }

    /// Joins a multicast group.
    ///
    /// The corresponding C constant is `IP_ADD_MEMBERSHIP`.
    @_alwaysEmitIntoClient
    public static var addMembership: IPOption { IPOption(rawValue: 12) }

    /// Leaves a multicast group.
    ///
    /// The corresponding C constant is `IP_DROP_MEMBERSHIP`.
    @_alwaysEmitIntoClient
    public static var dropMembership: IPOption { IPOption(rawValue: 13) }
  }
}

// MARK: - IPv6 Option Names

@available(System 199, *)
extension SocketDescriptor {
  /// IPv6-level options, at the ``OptionLevel/ipv6`` level,
  /// for use with `getOption` and `setOption`.
  ///
  /// Most have a typed method on ``SocketDescriptor``,
  /// such as ``setIPv6Only(_:)``, which is the easier way to use them.
  @frozen
  public struct IPv6Option: RawRepresentable, Hashable, Sendable {
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Whether the socket is restricted to IPv6,
    /// rather than also sending and receiving IPv4 through mapped addresses.
    ///
    /// The corresponding C constant is `IPV6_V6ONLY`.
    @_alwaysEmitIntoClient
    public static var v6Only: IPv6Option { IPv6Option(rawValue: 27) }

    /// The hop limit of the unicast packets the socket sends.
    ///
    /// The corresponding C constant is `IPV6_UNICAST_HOPS`.
    @_alwaysEmitIntoClient
    public static var unicastHops: IPv6Option { IPv6Option(rawValue: 4) }

    /// The traffic class of the packets the socket sends.
    ///
    /// The corresponding C constant is `IPV6_TCLASS`.
    @_alwaysEmitIntoClient
    public static var trafficClass: IPv6Option { IPv6Option(rawValue: 39) }

    /// Whether the socket receives each datagram's traffic class
    /// as an ancillary message.
    ///
    /// The corresponding C constant is `IPV6_RECVTCLASS`.
    @_alwaysEmitIntoClient
    public static var receiveTrafficClass: IPv6Option { IPv6Option(rawValue: 40) }

    /// The packet information of a datagram, in an ancillary message:
    /// its destination address and the interface it arrived on.
    ///
    /// The corresponding C constant is `IPV6_PKTINFO`.
    @_alwaysEmitIntoClient
    public static var packetInfo: IPv6Option { IPv6Option(rawValue: 19) }

    /// Whether the socket receives each datagram's packet information
    /// as an ancillary message.
    ///
    /// The corresponding C constant is `IPV6_PKTINFO`: Winsock has no
    /// `IPV6_RECVPKTINFO`, and its `IPV6_PKTINFO` also names the option.
    @_alwaysEmitIntoClient
    public static var receivePacketInfo: IPv6Option { IPv6Option(rawValue: 19) }

    /// The interface to send multicast datagrams from, by index.
    ///
    /// The corresponding C constant is `IPV6_MULTICAST_IF`.
    @_alwaysEmitIntoClient
    public static var multicastInterface: IPv6Option { IPv6Option(rawValue: 9) }

    /// The hop limit of the multicast datagrams the socket sends.
    ///
    /// The corresponding C constant is `IPV6_MULTICAST_HOPS`.
    @_alwaysEmitIntoClient
    public static var multicastHops: IPv6Option { IPv6Option(rawValue: 10) }

    /// Whether the multicast datagrams the socket sends loop back to this host.
    ///
    /// The corresponding C constant is `IPV6_MULTICAST_LOOP`.
    @_alwaysEmitIntoClient
    public static var multicastLoopback: IPv6Option { IPv6Option(rawValue: 11) }

    /// Joins a multicast group.
    ///
    /// The corresponding C constant is `IPV6_JOIN_GROUP`.
    @_alwaysEmitIntoClient
    public static var joinGroup: IPv6Option { IPv6Option(rawValue: 12) }

    /// Leaves a multicast group.
    ///
    /// The corresponding C constant is `IPV6_LEAVE_GROUP`.
    @_alwaysEmitIntoClient
    public static var leaveGroup: IPv6Option { IPv6Option(rawValue: 13) }
  }
}

// MARK: - Options by Name

@available(System 199, *)
extension SocketDescriptor {
  /// Gets an IPv4-level option whose value is an integer.
  ///
  /// The corresponding C function is `getsockopt`, at the `IPPROTO_IP` level.
  @_alwaysEmitIntoClient
  public func getIPOption(_ option: IPOption) throws(Win32.Error) -> CInt {
    try _value(OptionLevel.ip.rawValue, option.rawValue, CInt(0)).get()
  }

  /// Sets an IPv4-level option whose value is an integer.
  ///
  /// The corresponding C function is `setsockopt`, at the `IPPROTO_IP` level.
  @_alwaysEmitIntoClient
  public func setIPOption(_ option: IPOption, to value: CInt) throws(Win32.Error) {
    try _setValue(OptionLevel.ip.rawValue, option.rawValue, value).get()
  }

  /// Gets an IPv6-level option whose value is an integer.
  ///
  /// The corresponding C function is `getsockopt`, at the `IPPROTO_IPV6` level.
  @_alwaysEmitIntoClient
  public func getIPv6Option(_ option: IPv6Option) throws(Win32.Error) -> CInt {
    try _value(OptionLevel.ipv6.rawValue, option.rawValue, CInt(0)).get()
  }

  /// Sets an IPv6-level option whose value is an integer.
  ///
  /// The corresponding C function is `setsockopt`, at the `IPPROTO_IPV6` level.
  @_alwaysEmitIntoClient
  public func setIPv6Option(_ option: IPv6Option, to value: CInt) throws(Win32.Error) {
    try _setValue(OptionLevel.ipv6.rawValue, option.rawValue, value).get()
  }

  /// Gets an option whose value is a `T`, starting from `initial`.
  @usableFromInline
  internal func _value<T>(_ level: CInt, _ name: CInt, _ initial: T) -> Result<T, Win32.Error> {
    var value = initial
    var length = CInterop.SockLen(MemoryLayout<T>.size)
    return withUnsafeMutableBytes(of: &value) { bytes in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_getsockopt(self.rawValue, level, name, bytes.baseAddress, &length)
      }
    }.map { value }
  }

  /// Sets an option whose value is a `T`.
  @usableFromInline
  internal func _setValue<T>(_ level: CInt, _ name: CInt, _ value: T) -> Result<Void, Win32.Error> {
    withUnsafeBytes(of: value) { bytes in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_setsockopt(self.rawValue, level, name, bytes.baseAddress, CInterop.SockLen(bytes.count))
      }
    }
  }

  // Winsock's boolean options are BOOLs, ints, though it writes some, such
  // as TCP_NODELAY, as a single byte; the zeroed int reads either.
  @usableFromInline
  internal func _flag(_ level: CInt, _ name: CInt) -> Result<Bool, Win32.Error> {
    _value(level, name, CInt(0)).map { $0 != 0 }
  }

  @usableFromInline
  internal func _setFlag(_ level: CInt, _ name: CInt, _ value: Bool) -> Result<Void, Win32.Error> {
    _setValue(level, name, CInt(value ? 1 : 0))
  }
}

// MARK: - IPv4 Options

@available(System 199, *)
extension SocketDescriptor {
  /// Returns the time-to-live of the unicast packets the socket sends:
  /// the number of routers they can pass through.
  ///
  /// The corresponding C constant is `IP_TTL`.
  @_alwaysEmitIntoClient
  public func timeToLive() throws(Win32.Error) -> Int {
    Int(try _value(OptionLevel.ip.rawValue, IPOption.timeToLive.rawValue, CInt(0)).get())
  }

  /// Sets the time-to-live of the unicast packets the socket sends,
  /// from 1 through 255.
  ///
  /// The corresponding C constant is `IP_TTL`.
  @_alwaysEmitIntoClient
  public func setTimeToLive(_ timeToLive: Int) throws(Win32.Error) {
    try _setValue(OptionLevel.ip.rawValue, IPOption.timeToLive.rawValue, CInt(timeToLive)).get()
  }

  /// Returns the type-of-service byte of the packets the socket sends,
  /// whose low 2 bits are the explicit congestion notification (ECN) field
  /// and whose high 6 are the differentiated services code point.
  ///
  /// The corresponding C constant is `IP_TOS`.
  @_alwaysEmitIntoClient
  public func typeOfService() throws(Win32.Error) -> UInt8 {
    UInt8(truncatingIfNeeded: try _value(
      OptionLevel.ip.rawValue, IPOption.typeOfService.rawValue, CInt(0)).get())
  }

  /// Sets the type-of-service byte of the packets the socket sends.
  ///
  /// Windows ignores the value unless its `DisableUserTOSSetting` registry
  /// value says otherwise; see ``IPOption/typeOfService``.
  ///
  /// The corresponding C constant is `IP_TOS`.
  @_alwaysEmitIntoClient
  public func setTypeOfService(_ typeOfService: UInt8) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ip.rawValue, IPOption.typeOfService.rawValue, CInt(typeOfService)).get()
  }

  /// Returns whether the socket receives each datagram's type-of-service byte.
  ///
  /// The corresponding C constant is `IP_RECVTOS`.
  @_alwaysEmitIntoClient
  public func receivesTypeOfService() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ip.rawValue, IPOption.receiveTypeOfService.rawValue).get()
  }

  /// Sets whether the socket receives each datagram's type-of-service byte,
  /// as an ancillary message, which `WSARecvMsg` delivers.
  ///
  /// The corresponding C constant is `IP_RECVTOS`.
  @_alwaysEmitIntoClient
  public func setReceivesTypeOfService(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ip.rawValue, IPOption.receiveTypeOfService.rawValue, enabled).get()
  }

  /// Returns whether the socket receives each datagram's packet information.
  ///
  /// The corresponding C constant is `IP_PKTINFO`.
  @_alwaysEmitIntoClient
  public func receivesIPv4PacketInfo() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ip.rawValue, IPOption.receivePacketInfo.rawValue).get()
  }

  /// Sets whether the socket receives each datagram's packet information,
  /// its destination address and the interface it arrived on,
  /// as an ancillary message, which `WSARecvMsg` delivers.
  ///
  /// The corresponding C constant is `IP_PKTINFO`.
  @_alwaysEmitIntoClient
  public func setReceivesIPv4PacketInfo(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ip.rawValue, IPOption.receivePacketInfo.rawValue, enabled).get()
  }

  /// Returns whether the packets that this raw socket sends
  /// include their own IP header.
  ///
  /// The corresponding C constant is `IP_HDRINCL`.
  @_alwaysEmitIntoClient
  public func includesIPHeader() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ip.rawValue, IPOption.headerIncluded.rawValue).get()
  }

  /// Sets whether the packets that this raw socket sends
  /// include their own IP header, rather than having the system add one.
  ///
  /// The corresponding C constant is `IP_HDRINCL`.
  @_alwaysEmitIntoClient
  public func setIncludesIPHeader(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ip.rawValue, IPOption.headerIncluded.rawValue, enabled).get()
  }

  /// Returns the time-to-live of the multicast datagrams the socket sends.
  /// It's 1 by default, which keeps them on the local network.
  ///
  /// Winsock's value is a `DWORD`, where POSIX's is a byte.
  ///
  /// The corresponding C constant is `IP_MULTICAST_TTL`.
  @_alwaysEmitIntoClient
  public func multicastTimeToLive() throws(Win32.Error) -> UInt8 {
    UInt8(truncatingIfNeeded: try _value(
      OptionLevel.ip.rawValue, IPOption.multicastTimeToLive.rawValue, DWORD(0)).get())
  }

  /// Sets the time-to-live of the multicast datagrams the socket sends.
  ///
  /// The corresponding C constant is `IP_MULTICAST_TTL`.
  @_alwaysEmitIntoClient
  public func setMulticastTimeToLive(_ timeToLive: UInt8) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ip.rawValue, IPOption.multicastTimeToLive.rawValue, DWORD(timeToLive)
    ).get()
  }

  /// Returns whether the IPv4 multicast datagrams the socket sends
  /// loop back to this host's own sockets in the group.
  /// It's `true` by default.
  ///
  /// Winsock's value is a `DWORD`, where POSIX's is a byte.
  ///
  /// The corresponding C constant is `IP_MULTICAST_LOOP`.
  @_alwaysEmitIntoClient
  public func ipv4MulticastLoopback() throws(Win32.Error) -> Bool {
    try _value(OptionLevel.ip.rawValue, IPOption.multicastLoopback.rawValue, DWORD(0)).get() != 0
  }

  /// Sets whether the IPv4 multicast datagrams the socket sends
  /// loop back to this host's own sockets in the group.
  ///
  /// The corresponding C constant is `IP_MULTICAST_LOOP`.
  @_alwaysEmitIntoClient
  public func setIPv4MulticastLoopback(_ enabled: Bool) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ip.rawValue, IPOption.multicastLoopback.rawValue, DWORD(enabled ? 1 : 0)
    ).get()
  }

  /// Returns the address of the interface that the socket sends
  /// IPv4 multicast datagrams from,
  /// or ``IPv4Address/Host/any`` for the system's choice.
  ///
  /// The corresponding C constant is `IP_MULTICAST_IF`.
  @_alwaysEmitIntoClient
  public func ipv4MulticastInterface() throws(Win32.Error) -> IPv4Address.Host {
    IPv4Address.Host(rawValue: try _value(
      OptionLevel.ip.rawValue, IPOption.multicastInterface.rawValue, CInterop.InAddr()).get())
  }

  /// Sets the interface to send IPv4 multicast datagrams from, by its address,
  /// or ``IPv4Address/Host/any`` for the system's choice.
  ///
  /// The corresponding C constant is `IP_MULTICAST_IF`.
  @_alwaysEmitIntoClient
  public func setIPv4MulticastInterface(_ interface: IPv4Address.Host) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ip.rawValue, IPOption.multicastInterface.rawValue, interface.rawValue
    ).get()
  }

  /// Joins an IPv4 multicast group, so that the socket receives
  /// the datagrams sent to it.
  ///
  /// - Parameters:
  ///   - group: The group's address, from 224.0.0.0 through 239.255.255.255.
  ///   - interface: The address of the interface to join the group on,
  ///     or ``IPv4Address/Host/any``, the default, for the system's choice.
  ///     Windows also reads an address from 0.0.0.1 through 0.255.255.255
  ///     as an interface index.
  ///
  /// The corresponding C constant is `IP_ADD_MEMBERSHIP`.
  /// The corresponding C type is `IP_MREQ`.
  @_alwaysEmitIntoClient
  public func joinMulticastGroup(
    _ group: IPv4Address.Host, interface: IPv4Address.Host = .any
  ) throws(Win32.Error) {
    try _membership(IPOption.addMembership.rawValue, group, interface).get()
  }

  /// Leaves an IPv4 multicast group that the socket joined.
  ///
  /// - Parameters:
  ///   - group: The group's address.
  ///   - interface: The address of the interface the socket joined it on,
  ///     or ``IPv4Address/Host/any``, the default.
  ///
  /// The corresponding C constant is `IP_DROP_MEMBERSHIP`.
  /// The corresponding C type is `IP_MREQ`.
  @_alwaysEmitIntoClient
  public func leaveMulticastGroup(
    _ group: IPv4Address.Host, interface: IPv4Address.Host = .any
  ) throws(Win32.Error) {
    try _membership(IPOption.dropMembership.rawValue, group, interface).get()
  }

  @usableFromInline
  internal func _membership(
    _ name: CInt, _ group: IPv4Address.Host, _ interface: IPv4Address.Host
  ) -> Result<Void, Win32.Error> {
    var request = IP_MREQ()
    request.imr_multiaddr = group.rawValue
    request.imr_interface = interface.rawValue
    return _setValue(OptionLevel.ip.rawValue, name, request)
  }
}

// MARK: - IPv6 Options

@available(System 199, *)
extension SocketDescriptor {
  /// Returns whether the socket is restricted to IPv6.
  ///
  /// The corresponding C constant is `IPV6_V6ONLY`.
  @_alwaysEmitIntoClient
  public func isIPv6Only() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ipv6.rawValue, IPv6Option.v6Only.rawValue).get()
  }

  /// Sets whether the socket is restricted to IPv6.
  ///
  /// An IPv6 socket that isn't can also send to and receive from IPv4 hosts,
  /// through IPv4-mapped addresses such as `::ffff:192.0.2.1`,
  /// and one bound to `::` then receives connections for both.
  /// Windows' default is `true`, as Darwin's and the BSDs' is, where
  /// Linux's is `false`, so set it before binding
  /// to get the same behavior everywhere.
  ///
  /// The corresponding C constant is `IPV6_V6ONLY`.
  @_alwaysEmitIntoClient
  public func setIPv6Only(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ipv6.rawValue, IPv6Option.v6Only.rawValue, enabled).get()
  }

  /// Returns the hop limit of the unicast packets the socket sends.
  ///
  /// The corresponding C constant is `IPV6_UNICAST_HOPS`.
  @_alwaysEmitIntoClient
  public func unicastHops() throws(Win32.Error) -> Int {
    Int(try _value(OptionLevel.ipv6.rawValue, IPv6Option.unicastHops.rawValue, CInt(0)).get())
  }

  /// Sets the hop limit of the unicast packets the socket sends,
  /// from 0 through 255.
  ///
  /// The corresponding C constant is `IPV6_UNICAST_HOPS`.
  @_alwaysEmitIntoClient
  public func setUnicastHops(_ hops: Int) throws(Win32.Error) {
    try _setValue(OptionLevel.ipv6.rawValue, IPv6Option.unicastHops.rawValue, CInt(hops)).get()
  }

  /// Returns the traffic class of the packets the socket sends,
  /// whose low 2 bits are the explicit congestion notification (ECN) field
  /// and whose high 6 are the differentiated services code point.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`.
  @_alwaysEmitIntoClient
  public func trafficClass() throws(Win32.Error) -> UInt8 {
    UInt8(truncatingIfNeeded: try _value(
      OptionLevel.ipv6.rawValue, IPv6Option.trafficClass.rawValue, CInt(0)).get())
  }

  /// Sets the traffic class of the packets the socket sends.
  ///
  /// The corresponding C constant is `IPV6_TCLASS`.
  @_alwaysEmitIntoClient
  public func setTrafficClass(_ trafficClass: UInt8) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ipv6.rawValue, IPv6Option.trafficClass.rawValue, CInt(trafficClass)).get()
  }

  /// Returns whether the socket receives each datagram's traffic class.
  ///
  /// The corresponding C constant is `IPV6_RECVTCLASS`.
  @_alwaysEmitIntoClient
  public func receivesTrafficClass() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ipv6.rawValue, IPv6Option.receiveTrafficClass.rawValue).get()
  }

  /// Sets whether the socket receives each datagram's traffic class,
  /// as an ancillary message, which `WSARecvMsg` delivers.
  ///
  /// The corresponding C constant is `IPV6_RECVTCLASS`.
  @_alwaysEmitIntoClient
  public func setReceivesTrafficClass(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ipv6.rawValue, IPv6Option.receiveTrafficClass.rawValue, enabled).get()
  }

  /// Returns whether the socket receives each datagram's packet information.
  ///
  /// The corresponding C constant is `IPV6_PKTINFO`.
  @_alwaysEmitIntoClient
  public func receivesIPv6PacketInfo() throws(Win32.Error) -> Bool {
    try _flag(OptionLevel.ipv6.rawValue, IPv6Option.receivePacketInfo.rawValue).get()
  }

  /// Sets whether the socket receives each datagram's packet information,
  /// its destination address and the interface it arrived on,
  /// as an ancillary message, which `WSARecvMsg` delivers.
  ///
  /// The corresponding C constant is `IPV6_PKTINFO`.
  @_alwaysEmitIntoClient
  public func setReceivesIPv6PacketInfo(_ enabled: Bool) throws(Win32.Error) {
    try _setFlag(OptionLevel.ipv6.rawValue, IPv6Option.receivePacketInfo.rawValue, enabled).get()
  }

  /// Returns the hop limit of the multicast datagrams the socket sends.
  /// It's 1 by default, which keeps them on the local network.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_HOPS`.
  @_alwaysEmitIntoClient
  public func multicastHops() throws(Win32.Error) -> Int {
    Int(try _value(OptionLevel.ipv6.rawValue, IPv6Option.multicastHops.rawValue, CInt(0)).get())
  }

  /// Sets the hop limit of the multicast datagrams the socket sends,
  /// from 0 through 255.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_HOPS`.
  @_alwaysEmitIntoClient
  public func setMulticastHops(_ hops: Int) throws(Win32.Error) {
    try _setValue(OptionLevel.ipv6.rawValue, IPv6Option.multicastHops.rawValue, CInt(hops)).get()
  }

  /// Returns whether the IPv6 multicast datagrams the socket sends
  /// loop back to this host's own sockets in the group.
  /// It's `true` by default.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_LOOP`.
  @_alwaysEmitIntoClient
  public func ipv6MulticastLoopback() throws(Win32.Error) -> Bool {
    try _value(
      OptionLevel.ipv6.rawValue, IPv6Option.multicastLoopback.rawValue, DWORD(0)
    ).get() != 0
  }

  /// Sets whether the IPv6 multicast datagrams the socket sends
  /// loop back to this host's own sockets in the group.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_LOOP`.
  @_alwaysEmitIntoClient
  public func setIPv6MulticastLoopback(_ enabled: Bool) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ipv6.rawValue, IPv6Option.multicastLoopback.rawValue, DWORD(enabled ? 1 : 0)
    ).get()
  }

  /// Returns the index of the interface that the socket sends
  /// IPv6 multicast datagrams from, or 0 for the system's choice.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_IF`.
  @_alwaysEmitIntoClient
  public func ipv6MulticastInterface() throws(Win32.Error) -> UInt32 {
    try _value(
      OptionLevel.ipv6.rawValue, IPv6Option.multicastInterface.rawValue, DWORD(0)
    ).get()
  }

  /// Sets the interface to send IPv6 multicast datagrams from, by its index,
  /// or 0 for the system's choice.
  ///
  /// The corresponding C constant is `IPV6_MULTICAST_IF`.
  @_alwaysEmitIntoClient
  public func setIPv6MulticastInterface(_ interfaceIndex: UInt32) throws(Win32.Error) {
    try _setValue(
      OptionLevel.ipv6.rawValue, IPv6Option.multicastInterface.rawValue, DWORD(interfaceIndex)
    ).get()
  }

  /// Joins an IPv6 multicast group, so that the socket receives
  /// the datagrams sent to it.
  ///
  /// - Parameters:
  ///   - group: The group's address, such as `ff02::1`.
  ///   - interfaceIndex: The index of the interface to join the group on,
  ///     or 0, the default, for the system's choice.
  ///
  /// The corresponding C constant is `IPV6_JOIN_GROUP`.
  /// The corresponding C type is `IPV6_MREQ`.
  @_alwaysEmitIntoClient
  public func joinMulticastGroup(
    _ group: IPv6Address.Host, interfaceIndex: UInt32 = 0
  ) throws(Win32.Error) {
    try _membership(IPv6Option.joinGroup.rawValue, group, interfaceIndex).get()
  }

  /// Leaves an IPv6 multicast group that the socket joined.
  ///
  /// - Parameters:
  ///   - group: The group's address.
  ///   - interfaceIndex: The index of the interface the socket joined it on,
  ///     or 0, the default.
  ///
  /// The corresponding C constant is `IPV6_LEAVE_GROUP`.
  /// The corresponding C type is `IPV6_MREQ`.
  @_alwaysEmitIntoClient
  public func leaveMulticastGroup(
    _ group: IPv6Address.Host, interfaceIndex: UInt32 = 0
  ) throws(Win32.Error) {
    try _membership(IPv6Option.leaveGroup.rawValue, group, interfaceIndex).get()
  }

  @usableFromInline
  internal func _membership(
    _ name: CInt, _ group: IPv6Address.Host, _ interfaceIndex: UInt32
  ) -> Result<Void, Win32.Error> {
    var request = IPV6_MREQ()
    request.ipv6mr_multiaddr = group.rawValue
    request.ipv6mr_interface = interfaceIndex
    return _setValue(OptionLevel.ipv6.rawValue, name, request)
  }
}

#endif // os(Windows)
