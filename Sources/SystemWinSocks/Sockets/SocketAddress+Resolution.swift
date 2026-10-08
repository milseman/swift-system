/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// SystemSockets' name resolution, over the wide forms of getaddrinfo and
// getnameinfo, GetAddrInfoW and GetNameInfoW, which take and return UTF-16
// names: getaddrinfo's are in the ANSI code page. Their error codes are
// Winsock's (EAI_NONAME is WSAHOST_NOT_FOUND), which FormatMessageW
// describes.

// MARK: - Address Resolution Error

/// An error returned by address resolution functions.
@frozen
@available(System 199, *)
public struct AddressResolutionError: Error, Hashable, Sendable {
  /// The error code returned by `GetAddrInfoW` or `GetNameInfoW`: a
  /// Winsock code, such as `WSAHOST_NOT_FOUND`, which `EAI_NONAME` names.
  public let code: CInt

  @_alwaysEmitIntoClient
  public init(code: CInt) {
    self.code = code
  }

  /// A human-readable error message.
  ///
  /// The corresponding C function is `FormatMessageW`, which the SDK's
  /// `gai_strerrorW` calls.
  public var message: String {
    Win32.Error(rawValue: DWORD(bitPattern: code)).description
  }
}

@available(System 199, *)
extension AddressResolutionError: CustomStringConvertible {
  public var description: String {
    "AddressResolutionError(\(code)): \(message)"
  }
}

// MARK: - Resolution Hints

@available(System 199, *)
extension SocketAddress {
  /// Hints for address resolution.
  public struct ResolutionHints: Sendable {
    /// The protocol family to search for.
    public var family: SocketDescriptor.Domain?

    /// The socket type to search for.
    public var socketType: SocketDescriptor.ConnectionType?

    /// The protocol to search for.
    public var `protocol`: SocketDescriptor.ProtocolID?

    /// Resolution flags.
    public var flags: ResolutionFlags

    /// Creates resolution hints with the given parameters.
    public init(
      family: SocketDescriptor.Domain? = nil,
      socketType: SocketDescriptor.ConnectionType? = nil,
      protocol: SocketDescriptor.ProtocolID? = nil,
      flags: ResolutionFlags = []
    ) {
      self.family = family
      self.socketType = socketType
      self.protocol = `protocol`
      self.flags = flags
    }
  }

  /// Flags for address resolution, whose values are Windows' own.
  @frozen
  public struct ResolutionFlags: OptionSet, Sendable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) {
      self.rawValue = rawValue
    }

    /// Use passive socket for binding.
    ///
    /// The corresponding C constant is `AI_PASSIVE`.
    @_alwaysEmitIntoClient
    public static var passive: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0001) }

    /// Return canonical name.
    ///
    /// The corresponding C constant is `AI_CANONNAME`.
    @_alwaysEmitIntoClient
    public static var canonicalName: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0002) }

    /// Address must be numeric.
    ///
    /// The corresponding C constant is `AI_NUMERICHOST`.
    @_alwaysEmitIntoClient
    public static var numericHost: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0004) }

    /// Service must be numeric.
    ///
    /// The corresponding C constant is `AI_NUMERICSERV`.
    @_alwaysEmitIntoClient
    public static var numericService: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0008) }

    /// Return IPv4-mapped IPv6 addresses.
    ///
    /// The corresponding C constant is `AI_V4MAPPED`.
    @_alwaysEmitIntoClient
    public static var v4Mapped: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0800) }

    /// Return both IPv4 and IPv6 addresses.
    ///
    /// The corresponding C constant is `AI_ALL`.
    @_alwaysEmitIntoClient
    public static var all: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0100) }

    /// Return addresses only if configured.
    ///
    /// The corresponding C constant is `AI_ADDRCONFIG`.
    @_alwaysEmitIntoClient
    public static var addressConfigured: ResolutionFlags { ResolutionFlags(rawValue: 0x0000_0400) }
  }
}

// MARK: - Resolution Result

@available(System 199, *)
extension SocketAddress {
  /// A result from address resolution.
  public struct ResolvedAddress: Sendable {
    /// The socket domain.
    public let family: SocketDescriptor.Domain

    /// The socket type.
    public let socketType: SocketDescriptor.ConnectionType

    /// The socket protocol.
    public let `protocol`: SocketDescriptor.ProtocolID

    /// The resolved socket address.
    public let address: SocketAddress

    /// The canonical name, if requested and available.
    public let canonicalName: String?

    internal init(
      family: SocketDescriptor.Domain,
      socketType: SocketDescriptor.ConnectionType,
      protocol: SocketDescriptor.ProtocolID,
      address: SocketAddress,
      canonicalName: String?
    ) {
      self.family = family
      self.socketType = socketType
      self.protocol = `protocol`
      self.address = address
      self.canonicalName = canonicalName
    }
  }
}

// MARK: - Address Resolution

@available(System 199, *)
extension SocketAddress {
  /// Resolves a hostname and service to a list of socket addresses.
  ///
  /// - Parameters:
  ///   - hostname: The hostname to resolve, or `nil` for the local host.
  ///   - service: The service name or port number, or `nil`.
  ///   - hints: Hints to narrow the search.
  /// - Returns: An array of resolved addresses.
  /// - Throws: ``AddressResolutionError`` if resolution fails, with a
  ///   Winsock code, or the code of starting Winsock, which this method
  ///   does first, if that fails.
  ///
  /// This method copies the system's list of results, and frees it. It
  /// passes the names as UTF-16, which an internationalized domain name
  /// needs, and Windows encodes such a name for DNS itself.
  ///
  /// The corresponding C functions are `GetAddrInfoW` and `FreeAddrInfoW`,
  /// the wide forms of `getaddrinfo` and `freeaddrinfo`.
  public static func resolve(
    hostname: String? = nil,
    service: String? = nil,
    hints: ResolutionHints = ResolutionHints()
  ) throws(AddressResolutionError) -> [ResolvedAddress] {
    if case .failure(let error) = _startWinsock() {
      throw AddressResolutionError(code: CInt(bitPattern: error.rawValue))
    }
    var hintsStruct = CInterop.AddrInfo()
    hintsStruct.ai_flags = hints.flags.rawValue
    if let family = hints.family {
      hintsStruct.ai_family = family.rawValue
    }
    if let socketType = hints.socketType {
      hintsStruct.ai_socktype = socketType.rawValue
    }
    if let proto = hints.protocol {
      hintsStruct.ai_protocol = proto.rawValue
    }

    var result: UnsafeMutablePointer<CInterop.AddrInfo>?

    let errorCode: CInt = hostname._withOptionalWideCString { hostnamePtr in
      service._withOptionalWideCString { servicePtr in
        system_GetAddrInfoW(hostnamePtr, servicePtr, &hintsStruct, &result)
      }
    }

    guard errorCode == 0 else {
      throw AddressResolutionError(code: errorCode)
    }

    defer { system_FreeAddrInfoW(result) }

    var addresses: [ResolvedAddress] = []
    var current = result

    while let info = current {
      let family = SocketDescriptor.Domain(rawValue: info.pointee.ai_family)
      let socketType = SocketDescriptor.ConnectionType(rawValue: info.pointee.ai_socktype)
      let proto = SocketDescriptor.ProtocolID(rawValue: info.pointee.ai_protocol)

      let address: SocketAddress
      if let addr = info.pointee.ai_addr {
        address = SocketAddress(
          address: addr,
          length: CInterop.SockLen(clamping: info.pointee.ai_addrlen)
        )
      } else {
        address = SocketAddress()
      }

      let canonicalName: String?
      if let name = info.pointee.ai_canonname {
        canonicalName = String(decodingCString: name, as: UTF16.self)
      } else {
        canonicalName = nil
      }

      addresses.append(ResolvedAddress(
        family: family,
        socketType: socketType,
        protocol: proto,
        address: address,
        canonicalName: canonicalName
      ))

      current = info.pointee.ai_next
    }

    return addresses
  }
}

// MARK: - Reverse Resolution

@available(System 199, *)
extension SocketAddress {
  /// Flags for reverse resolution.
  @frozen
  public struct ReverseResolutionFlags: OptionSet, Sendable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) {
      self.rawValue = rawValue
    }

    /// Return numeric host.
    ///
    /// The corresponding C constant is `NI_NUMERICHOST`.
    @_alwaysEmitIntoClient
    public static var numericHost: ReverseResolutionFlags { ReverseResolutionFlags(rawValue: 0x02) }

    /// Return numeric service.
    ///
    /// The corresponding C constant is `NI_NUMERICSERV`.
    @_alwaysEmitIntoClient
    public static var numericService: ReverseResolutionFlags { ReverseResolutionFlags(rawValue: 0x08) }

    /// Look up datagram service.
    ///
    /// The corresponding C constant is `NI_DGRAM`.
    @_alwaysEmitIntoClient
    public static var datagram: ReverseResolutionFlags { ReverseResolutionFlags(rawValue: 0x10) }

    /// Return only the hostname part of FQDN.
    ///
    /// The corresponding C constant is `NI_NOFQDN`.
    @_alwaysEmitIntoClient
    public static var noFullyQualified: ReverseResolutionFlags { ReverseResolutionFlags(rawValue: 0x01) }

    /// Fail if name cannot be determined.
    ///
    /// The corresponding C constant is `NI_NAMEREQD`.
    @_alwaysEmitIntoClient
    public static var nameRequired: ReverseResolutionFlags { ReverseResolutionFlags(rawValue: 0x04) }
  }

  /// A result from reverse resolution.
  public struct ReverseLookupResult: Sendable {
    /// The hostname.
    public let hostname: String?

    /// The service name.
    public let service: String?
  }

  /// Resolves this address to a hostname and service.
  ///
  /// - Parameter flags: Flags controlling the resolution.
  /// - Returns: The hostname and service.
  /// - Throws: ``AddressResolutionError`` if resolution fails.
  ///
  /// The names can be as long as the system's limits,
  /// the sizes of the buffers this method passes;
  /// the corresponding C constants are `NI_MAXHOST` and `NI_MAXSERV`.
  ///
  /// The corresponding C function is `GetNameInfoW`, the wide form of
  /// `getnameinfo`.
  public func reverseLookup(
    flags: ReverseResolutionFlags = []
  ) throws(AddressResolutionError) -> ReverseLookupResult {
    if case .failure(let error) = _startWinsock() {
      throw AddressResolutionError(code: CInt(bitPattern: error.rawValue))
    }
    // NI_MAXHOST and NI_MAXSERV.
    var hostname = [WCHAR](repeating: 0, count: 1025)
    var service = [WCHAR](repeating: 0, count: 32)

    let errorCode = withUnsafePointer { addr, len in
      system_GetNameInfoW(
        addr,
        len,
        &hostname,
        DWORD(hostname.count),
        &service,
        DWORD(service.count),
        flags.rawValue
      )
    }

    guard errorCode == 0 else {
      throw AddressResolutionError(code: errorCode)
    }

    func decode(_ name: [WCHAR]) -> String? {
      name[0] == 0 ? nil : String(decoding: name.prefix { $0 != 0 }, as: UTF16.self)
    }
    return ReverseLookupResult(hostname: decode(hostname), service: decode(service))
  }
}

// MARK: - Helpers

extension Optional where Wrapped == String {
  func _withOptionalWideCString<R>(_ body: (UnsafePointer<WCHAR>?) throws -> R) rethrows -> R {
    switch self {
    case .none:
      return try body(nil)
    case .some(let string):
      return try string.withCString(encodedAs: UTF16.self, body)
    }
  }
}

#endif // os(Windows)
