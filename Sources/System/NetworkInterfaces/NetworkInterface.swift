/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// CSystem on Linux, in case its headers declare sockaddr's members.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

/// A namespace for the system's network interfaces:
/// their addresses, their flags, and their indexes.
@available(System 199, *)
public enum NetworkInterface {}

// MARK: - Flags

@available(System 199, *)
extension NetworkInterface {
  /// The state and the capabilities of a network interface.
  @frozen
  public struct Flags: OptionSet, Hashable, Sendable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CUnsignedInt

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }

    /// The interface is up.
    ///
    /// The corresponding C constant is `IFF_UP`.
    @_alwaysEmitIntoClient
    public static var up: Flags { Flags(rawValue: _IFF_UP) }

    /// The interface has a broadcast address.
    ///
    /// The corresponding C constant is `IFF_BROADCAST`.
    @_alwaysEmitIntoClient
    public static var broadcast: Flags { Flags(rawValue: _IFF_BROADCAST) }

    /// The interface's driver is logging for debugging.
    ///
    /// The corresponding C constant is `IFF_DEBUG`.
    @_alwaysEmitIntoClient
    public static var debug: Flags { Flags(rawValue: _IFF_DEBUG) }

    /// The interface is the loopback interface, which sends to the host itself.
    ///
    /// The corresponding C constant is `IFF_LOOPBACK`.
    @_alwaysEmitIntoClient
    public static var loopback: Flags { Flags(rawValue: _IFF_LOOPBACK) }

    /// The interface is a link to a single other host,
    /// which its destination address names.
    ///
    /// The corresponding C constant is `IFF_POINTOPOINT`.
    @_alwaysEmitIntoClient
    public static var pointToPoint: Flags { Flags(rawValue: _IFF_POINTOPOINT) }

    /// The interface's resources are allocated, so it can send and receive.
    ///
    /// The corresponding C constant is `IFF_RUNNING`.
    @_alwaysEmitIntoClient
    public static var running: Flags { Flags(rawValue: _IFF_RUNNING) }

    /// The interface doesn't use the address resolution protocol.
    ///
    /// The corresponding C constant is `IFF_NOARP`.
    @_alwaysEmitIntoClient
    public static var noARP: Flags { Flags(rawValue: _IFF_NOARP) }

    /// The interface receives every packet on its network.
    ///
    /// The corresponding C constant is `IFF_PROMISC`.
    @_alwaysEmitIntoClient
    public static var promiscuous: Flags { Flags(rawValue: _IFF_PROMISC) }

    /// The interface receives every multicast packet on its network.
    ///
    /// The corresponding C constant is `IFF_ALLMULTI`.
    @_alwaysEmitIntoClient
    public static var allMulticast: Flags { Flags(rawValue: _IFF_ALLMULTI) }

    /// The interface supports multicast.
    ///
    /// The corresponding C constant is `IFF_MULTICAST`.
    @_alwaysEmitIntoClient
    public static var multicast: Flags { Flags(rawValue: _IFF_MULTICAST) }
  }
}

// MARK: - Indexes

@available(System 199, *)
extension NetworkInterface {
  /// The number that the system gives a network interface,
  /// which socket options that name an interface take, such as the ones
  /// that choose where to send or join a multicast group.
  @frozen
  public struct Index: RawRepresentable, Hashable, Sendable {
    /// The raw C index.
    @_alwaysEmitIntoClient
    public var rawValue: CUnsignedInt

    /// Creates a strongly-typed index from a raw C index.
    @_alwaysEmitIntoClient
    public init(rawValue: CUnsignedInt) { self.rawValue = rawValue }

    /// Looks up the index of the interface with the given name.
    ///
    /// - Parameter name: The interface's name, such as `"en0"` or `"eth0"`.
    ///
    /// This initializer returns `nil` if no interface has the name,
    /// and throws for other errors, such as running out of descriptors,
    /// since the system can open a socket to look the name up.
    ///
    /// The corresponding C function is `if_nametoindex`.
    @_alwaysEmitIntoClient
    public init?(name: String) throws(Errno) {
      guard let index = try Index._index(named: name).get() else { return nil }
      self.init(rawValue: index)
    }

    @usableFromInline
    internal static func _index(named name: String) -> Result<CUnsignedInt?, Errno> {
      system_errno = 0
      let index = name.withCString { system_if_nametoindex($0) }
      guard index == 0 else { return .success(index) }
      return _isNoSuchInterface(system_errno) ? .success(nil) : .failure(.current)
    }

    /// Returns the name of the interface with this index.
    ///
    /// - Returns: The interface's name, or `nil` if no interface has this index.
    ///
    /// The name can be as long as the C library's limit,
    /// the size of the buffer this method passes;
    /// the corresponding C constant is `IF_NAMESIZE`.
    ///
    /// The corresponding C function is `if_indextoname`.
    @_alwaysEmitIntoClient
    public func name() throws(Errno) -> String? {
      try _name().get()
    }

    @usableFromInline
    internal func _name() -> Result<String?, Errno> {
      withUnsafeTemporaryAllocation(of: CChar.self, capacity: _IF_NAMESIZE) { buffer in
        buffer.initialize(repeating: 0)
        system_errno = 0
        guard system_if_indextoname(rawValue, buffer.baseAddress!) != nil else {
          return _isNoSuchInterface(system_errno) ? .success(nil) : .failure(.current)
        }
        return .success(String(platformString: buffer.baseAddress!))
      }
    }
  }
}

// Darwin reports a missing interface with ENXIO, and Linux with ENODEV;
// a failure that sets neither, such as one that leaves errno at zero,
// is one too.
@available(System 199, *)
internal func _isNoSuchInterface(_ error: CInt) -> Bool {
  error == 0 || Errno(rawValue: error) == .noSuchAddressOrDevice
    || Errno(rawValue: error) == .operationNotSupportedByDevice
}

// MARK: - Addresses

@available(System 199, *)
extension NetworkInterface {
  /// The addresses of the system's network interfaces,
  /// in a list that this value owns.
  ///
  /// The list has an entry for each address of each interface,
  /// and for Darwin's and the BSDs' link-layer addresses too,
  /// so an interface can appear more than once, and in no particular order:
  ///
  ///     let addresses = try NetworkInterface.Addresses()
  ///     addresses.forEach { entry in
  ///       print(entry.name, entry.flags.contains(.up))
  ///     }
  ///
  /// An entry, and the spans of its addresses, can't outlive the list.
  /// The list is a snapshot, which interfaces that change don't update.
  /// Destroying the list frees it;
  /// the corresponding C function is `freeifaddrs`.
  ///
  /// The corresponding C function is `getifaddrs`.
  @frozen
  public struct Addresses: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _list: UnsafeMutablePointer<ifaddrs>?

    /// Reads the addresses of every network interface.
    ///
    /// The corresponding C function is `getifaddrs`.
    @_alwaysEmitIntoClient
    public init() throws(Errno) {
      self._list = try Addresses._read().get()
    }

    @usableFromInline
    internal static func _read() -> Result<UnsafeMutablePointer<ifaddrs>?, Errno> {
      var list: UnsafeMutablePointer<ifaddrs>? = nil
      return nothingOrErrno(retryOnInterrupt: false) {
        system_getifaddrs(&list)
      }.map { list }
    }

    deinit {
      if let _list { system_freeifaddrs(_list) }
    }
  }
}

@available(System 199, *)
extension NetworkInterface.Addresses {
  /// One address of a network interface, in an ``NetworkInterface/Addresses``
  /// list, which it can't outlive.
  ///
  /// The corresponding C type is `struct ifaddrs`.
  @frozen
  public struct Entry: ~Escapable {
    @usableFromInline
    internal let _node: UnsafeMutablePointer<ifaddrs>

    @usableFromInline
    @_lifetime(borrow list)
    internal init(_node: UnsafeMutablePointer<ifaddrs>, in list: borrowing NetworkInterface.Addresses) {
      self._node = _node
    }
  }

  /// The number of entries.
  @_alwaysEmitIntoClient
  public var count: Int {
    var count = 0
    var node = _list
    while let current = node {
      count += 1
      node = current.pointee.ifa_next
    }
    return count
  }

  /// Calls a closure with each entry, in the list's order.
  @_alwaysEmitIntoClient
  public func forEach<E: Error>(_ body: (borrowing Entry) throws(E) -> Void) throws(E) {
    var node = _list
    while let current = node {
      try body(Entry(_node: current, in: self))
      node = current.pointee.ifa_next
    }
  }
}

@available(System 199, *)
extension NetworkInterface.Addresses.Entry {
  /// The name of the entry's interface, such as `"en0"` or `"lo"`.
  ///
  /// The corresponding C field is `ifa_name`.
  @_alwaysEmitIntoClient
  public var name: String { String(platformString: _node.pointee.ifa_name) }

  /// The interface's flags.
  ///
  /// The corresponding C field is `ifa_flags`.
  @_alwaysEmitIntoClient
  public var flags: NetworkInterface.Flags {
    NetworkInterface.Flags(rawValue: _node.pointee.ifa_flags)
  }

  /// The family of the entry's address, such as `AF_INET` or `AF_INET6`,
  /// or `nil` if the entry has no address.
  ///
  /// The corresponding C field is `sa_family`, of `ifa_addr`.
  @_alwaysEmitIntoClient
  public var addressFamily: CInt? {
    _node.pointee.ifa_addr.map { CInt($0.pointee.sa_family) }
  }

  /// The C structure, for fields that `Entry` doesn't provide,
  /// such as `ifa_data`.
  ///
  /// The pointer is valid only while the list is alive: don't keep it.
  @_alwaysEmitIntoClient
  public var unsafeNode: UnsafeMutablePointer<ifaddrs> { _node }
}

@available(System 199, *)
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension NetworkInterface.Addresses.Entry {
  /// The bytes of the entry's address, a C `sockaddr` of its family,
  /// or `nil` if the entry has no address.
  ///
  /// The corresponding C field is `ifa_addr`.
  @_alwaysEmitIntoClient
  public var address: RawSpan? {
    @_lifetime(copy self)
    get { _bytes(of: _node.pointee.ifa_addr) }
  }

  /// The bytes of the address's netmask, or `nil` if it has none.
  ///
  /// On Darwin and the BSDs, a netmask can be shorter than
  /// a `sockaddr` of its family, without its trailing zero bytes.
  ///
  /// The corresponding C field is `ifa_netmask`.
  @_alwaysEmitIntoClient
  public var netmask: RawSpan? {
    @_lifetime(copy self)
    get { _bytes(of: _node.pointee.ifa_netmask) }
  }

  /// The bytes of the interface's broadcast address,
  /// if its flags include ``NetworkInterface/Flags/broadcast``.
  ///
  /// The corresponding C field is `ifa_broadaddr`.
  @_alwaysEmitIntoClient
  public var broadcastAddress: RawSpan? {
    @_lifetime(copy self)
    get { flags.contains(.broadcast) ? _bytes(of: _otherAddress) : nil }
  }

  /// The bytes of the address at the other end of a point-to-point link,
  /// if the interface's flags include ``NetworkInterface/Flags/pointToPoint``.
  ///
  /// The corresponding C field is `ifa_dstaddr`.
  @_alwaysEmitIntoClient
  public var destinationAddress: RawSpan? {
    @_lifetime(copy self)
    get { flags.contains(.pointToPoint) ? _bytes(of: _otherAddress) : nil }
  }

  // The broadcast and destination addresses share a field.
  @usableFromInline
  internal var _otherAddress: UnsafeMutablePointer<sockaddr>? {
    #if os(Linux) || os(Android)
    _node.pointee.ifa_ifu.ifu_dstaddr
    #else
    _node.pointee.ifa_dstaddr
    #endif
  }

  @usableFromInline
  @_lifetime(copy self)
  internal func _bytes(of address: UnsafeMutablePointer<sockaddr>?) -> RawSpan? {
    guard let address else { return nil }
    let span = RawSpan(_unsafeStart: address, byteCount: _socketAddressLength(address))
    return _overrideLifetime(span, copying: self)
  }
}

/// The length of a socket address: its own length field on Darwin and the
/// BSDs, and its family's size on Linux, which has no such field.
@available(System 199, *)
@usableFromInline
internal func _socketAddressLength(_ address: UnsafeMutablePointer<sockaddr>) -> Int {
  #if os(Linux) || os(Android)
  switch CInt(address.pointee.sa_family) {
  case _AF_INET: return MemoryLayout<sockaddr_in>.size
  case _AF_INET6: return MemoryLayout<sockaddr_in6>.size
  // struct sockaddr_ll, from <netpacket/packet.h>, which Glibc's module
  // doesn't include; it's 20 bytes on every architecture.
  case _AF_PACKET: return 20
  default: return MemoryLayout<sockaddr>.size
  }
  #else
  return Int(address.pointee.sa_len)
  #endif
}

#endif // !os(Windows) && !os(WASI)
