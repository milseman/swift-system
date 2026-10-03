/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// A network adapter: one of the computer's network interfaces, with its
  /// addresses.
  ///
  /// This is a copy of what Windows reported when
  /// ``networkAdapters()`` read it.
  ///
  /// The corresponding C type is `IP_ADAPTER_ADDRESSES`.
  public struct NetworkAdapter: Sendable, Hashable {
    /// The adapter's name: a GUID in braces, which stays the same when the
    /// computer restarts.
    ///
    /// The corresponding C field is `AdapterName`.
    public var name: String

    /// The name the adapter is shown by, such as `Ethernet` or `Wi-Fi`,
    /// which its user can change.
    ///
    /// The corresponding C field is `FriendlyName`.
    public var friendlyName: String

    /// A description of the adapter, such as its product's name.
    ///
    /// The corresponding C field is `Description`.
    public var adapterDescription: String

    /// The adapter's interface index for IPv4, or 0 if IPv4 isn't enabled
    /// on it.
    ///
    /// The corresponding C field is `IfIndex`.
    public var index: UInt32

    /// The adapter's interface index for IPv6, or 0 if IPv6 isn't enabled
    /// on it.
    ///
    /// The corresponding C field is `Ipv6IfIndex`.
    public var ipv6Index: UInt32

    /// The adapter's type of interface, such as Ethernet.
    ///
    /// The corresponding C field is `IfType`.
    public var type: Win32.NetworkAdapter.InterfaceType

    /// Whether the adapter is up.
    ///
    /// The corresponding C field is `OperStatus`.
    public var operationalStatus: Win32.NetworkAdapter.OperationalStatus

    /// The largest packet the adapter sends, in bytes.
    ///
    /// The corresponding C field is `Mtu`.
    public var mtu: Int

    /// The adapter's link-layer address, such as an Ethernet adapter's MAC
    /// address, or no bytes for an adapter without one.
    ///
    /// The corresponding C fields are `PhysicalAddress` and
    /// `PhysicalAddressLength`.
    public var physicalAddress: [UInt8]

    /// Whether the adapter receives multicast packets.
    ///
    /// The corresponding C constant is `IP_ADAPTER_NO_MULTICAST`, in
    /// `Flags`, when it doesn't.
    public var supportsMulticast: Bool

    /// The adapter's unicast addresses, IPv4 and IPv6, in Windows' order.
    ///
    /// The corresponding C field is `FirstUnicastAddress`.
    public var unicastAddresses: [Win32.NetworkAdapter.UnicastAddress]
  }

  /// The computer's network adapters, and their unicast addresses.
  ///
  /// The list includes adapters that are down, and the loopback adapter, of
  /// type ``NetworkAdapter/InterfaceType/softwareLoopback``. It's a
  /// snapshot, which adapters that change don't update.
  ///
  /// The corresponding C function is `GetAdaptersAddresses`, for both IPv4
  /// and IPv6, without anycast, multicast or DNS server addresses.
  @_alwaysEmitIntoClient
  public static func networkAdapters() throws(Win32.Error) -> [Win32.NetworkAdapter] {
    try _networkAdapters().get()
  }
}

@available(System 199, *)
extension Win32.NetworkAdapter {
  /// One of an adapter's unicast addresses.
  ///
  /// The corresponding C type is `IP_ADAPTER_UNICAST_ADDRESS`.
  public struct UnicastAddress: Sendable, Hashable {
    /// The address's bytes: a C `sockaddr_in` for an IPv4 address, or a
    /// `sockaddr_in6` for an IPv6 one.
    ///
    /// The corresponding C field is `Address`, a `SOCKET_ADDRESS`.
    public var bytes: [UInt8]

    /// The address's family: `AF_INET`, 2, or `AF_INET6`, 23 on Windows.
    ///
    /// The corresponding C field is the address's `sa_family`.
    public var family: CInt

    /// The length, in bits, of the prefix that the address's subnet shares:
    /// the number of ones in its netmask.
    ///
    /// The corresponding C field is `OnLinkPrefixLength`.
    public var prefixLength: Int
  }

  /// The type of a network interface, as IANA numbers them.
  ///
  /// The corresponding C type is `IFTYPE`, and the constants `IF_TYPE_*`.
  @frozen
  public struct InterfaceType: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed interface type from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Another type of interface.
    ///
    /// The corresponding C constant is `IF_TYPE_OTHER`.
    @_alwaysEmitIntoClient
    public static var other: InterfaceType { InterfaceType(rawValue: 1) }

    /// An Ethernet interface.
    ///
    /// The corresponding C constant is `IF_TYPE_ETHERNET_CSMACD`.
    @_alwaysEmitIntoClient
    public static var ethernet: InterfaceType { InterfaceType(rawValue: 6) }

    /// A token ring interface.
    ///
    /// The corresponding C constant is `IF_TYPE_ISO88025_TOKENRING`.
    @_alwaysEmitIntoClient
    public static var tokenRing: InterfaceType { InterfaceType(rawValue: 9) }

    /// A point-to-point protocol interface.
    ///
    /// The corresponding C constant is `IF_TYPE_PPP`.
    @_alwaysEmitIntoClient
    public static var pointToPoint: InterfaceType { InterfaceType(rawValue: 23) }

    /// The loopback interface.
    ///
    /// The corresponding C constant is `IF_TYPE_SOFTWARE_LOOPBACK`.
    @_alwaysEmitIntoClient
    public static var softwareLoopback: InterfaceType { InterfaceType(rawValue: 24) }

    /// An ATM interface.
    ///
    /// The corresponding C constant is `IF_TYPE_ATM`.
    @_alwaysEmitIntoClient
    public static var atm: InterfaceType { InterfaceType(rawValue: 37) }

    /// A wireless interface.
    ///
    /// The corresponding C constant is `IF_TYPE_IEEE80211`.
    @_alwaysEmitIntoClient
    public static var wireless: InterfaceType { InterfaceType(rawValue: 71) }

    /// A tunnel, such as Teredo's or ISATAP's.
    ///
    /// The corresponding C constant is `IF_TYPE_TUNNEL`.
    @_alwaysEmitIntoClient
    public static var tunnel: InterfaceType { InterfaceType(rawValue: 131) }

    /// A FireWire interface.
    ///
    /// The corresponding C constant is `IF_TYPE_IEEE1394`.
    @_alwaysEmitIntoClient
    public static var ieee1394: InterfaceType { InterfaceType(rawValue: 144) }
  }

  /// Whether a network interface is up, as RFC 2863 names its states.
  ///
  /// The corresponding C type is `IF_OPER_STATUS`.
  @frozen
  public struct OperationalStatus: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed status from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The interface can pass packets.
    ///
    /// The corresponding C constant is `IfOperStatusUp`.
    @_alwaysEmitIntoClient
    public static var up: OperationalStatus { OperationalStatus(rawValue: 1) }

    /// The interface can't pass packets.
    ///
    /// The corresponding C constant is `IfOperStatusDown`.
    @_alwaysEmitIntoClient
    public static var down: OperationalStatus { OperationalStatus(rawValue: 2) }

    /// The interface is in a test mode.
    ///
    /// The corresponding C constant is `IfOperStatusTesting`.
    @_alwaysEmitIntoClient
    public static var testing: OperationalStatus { OperationalStatus(rawValue: 3) }

    /// The interface's state isn't known.
    ///
    /// The corresponding C constant is `IfOperStatusUnknown`.
    @_alwaysEmitIntoClient
    public static var unknown: OperationalStatus { OperationalStatus(rawValue: 4) }

    /// The interface is waiting for something outside it, such as a call.
    ///
    /// The corresponding C constant is `IfOperStatusDormant`.
    @_alwaysEmitIntoClient
    public static var dormant: OperationalStatus { OperationalStatus(rawValue: 5) }

    /// A part of the interface, typically its hardware, is missing.
    ///
    /// The corresponding C constant is `IfOperStatusNotPresent`.
    @_alwaysEmitIntoClient
    public static var notPresent: OperationalStatus { OperationalStatus(rawValue: 6) }

    /// An interface that this one runs over is down.
    ///
    /// The corresponding C constant is `IfOperStatusLowerLayerDown`.
    @_alwaysEmitIntoClient
    public static var lowerLayerDown: OperationalStatus { OperationalStatus(rawValue: 7) }
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _networkAdapters() -> Result<[Win32.NetworkAdapter], Win32.Error> {
    // Microsoft's suggested first size; the list can grow between the
    // calls, so a retry takes the size the last call asked for.
    var size = ULONG(15 * 1024)
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        byteCount: Int(size), alignment: MemoryLayout<IP_ADAPTER_ADDRESSES>.alignment
      ) { buffer -> _Win32SizedResult<[Win32.NetworkAdapter]> in
        let list = buffer.baseAddress!.bindMemory(
          to: IP_ADAPTER_ADDRESSES.self, capacity: 1)
        var needed = ULONG(buffer.count)
        let error = system_GetAdaptersAddresses(_AF_UNSPEC, _GAA_FLAGS_UNICAST_ONLY, list, &needed)
        switch error {
        case Win32.Error.success.rawValue:
          return .success(_copyAdapters(list))
        case Win32.Error.noData.rawValue:
          // No adapters at all.
          return .success([])
        case _ERROR_BUFFER_OVERFLOW:
          return .retry(capacity: max(Int(needed), buffer.count + 1))
        default:
          return .failure(Win32.Error(error))
        }
      }
      switch outcome {
      case .success(let adapters): return .success(adapters)
      case .failure(let error): return .failure(error)
      case .retry(let needed): size = ULONG(needed)
      }
    }
  }

  /// The adapters of the list that `GetAdaptersAddresses` wrote, copied.
  internal static func _copyAdapters(
    _ list: UnsafeMutablePointer<IP_ADAPTER_ADDRESSES>
  ) -> [Win32.NetworkAdapter] {
    var adapters: [Win32.NetworkAdapter] = []
    var node: UnsafeMutablePointer<IP_ADAPTER_ADDRESSES>? = list
    while let adapter = node {
      let entry = adapter.pointee
      var addresses: [Win32.NetworkAdapter.UnicastAddress] = []
      var unicast = entry.FirstUnicastAddress
      while let address = unicast {
        let socketAddress = address.pointee.Address
        if let raw = socketAddress.lpSockaddr, socketAddress.iSockaddrLength >= 2 {
          let bytes = Array(
            UnsafeRawBufferPointer(start: raw, count: Int(socketAddress.iSockaddrLength)))
          addresses.append(Win32.NetworkAdapter.UnicastAddress(
            bytes: bytes,
            family: CInt(raw.pointee.sa_family),
            prefixLength: Int(address.pointee.OnLinkPrefixLength)))
        }
        unicast = address.pointee.Next
      }
      let physicalAddress = withUnsafeBytes(of: entry.PhysicalAddress) { bytes in
        Array(bytes.prefix(min(Int(entry.PhysicalAddressLength), bytes.count)))
      }
      adapters.append(Win32.NetworkAdapter(
        name: entry.AdapterName.map { String(cString: $0) } ?? "",
        friendlyName: entry.FriendlyName.map { String(decodingCString: $0, as: UTF16.self) } ?? "",
        adapterDescription:
          entry.Description.map { String(decodingCString: $0, as: UTF16.self) } ?? "",
        index: UInt32(entry.IfIndex),
        ipv6Index: UInt32(entry.Ipv6IfIndex),
        type: Win32.NetworkAdapter.InterfaceType(rawValue: UInt32(entry.IfType)),
        operationalStatus:
          Win32.NetworkAdapter.OperationalStatus(rawValue: CInt(entry.OperStatus.rawValue)),
        mtu: Int(entry.Mtu),
        physicalAddress: physicalAddress,
        supportsMulticast: entry.Flags & _IP_ADAPTER_NO_MULTICAST == 0,
        unicastAddresses: addresses))
      node = entry.Next
    }
    return adapters
  }
}

#endif // os(Windows)
