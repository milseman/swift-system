/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

@available(System 199, *)
extension SocketAddress {
  @frozen
  /// The address family identifier
  public struct Family: RawRepresentable, Hashable {
    public let rawValue: CInterop.SAFamily

    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.SAFamily) { self.rawValue = rawValue }

    /// Unspecified address family.
    ///
    /// The corresponding C constant is `AF_UNSPEC`.
    @_alwaysEmitIntoClient
    public static var unspecified: Family { Family(rawValue: 0) }

    /// Local address family.
    ///
    /// The corresponding C constant is `AF_UNIX`, Winsock's only spelling.
    @_alwaysEmitIntoClient
    public static var local: Family { Family(rawValue: 1) }

    /// UNIX address family. (Renamed `local`.)
    ///
    /// The corresponding C constant is `AF_UNIX`.
    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "local")
    public static var unix: Family { Family(rawValue: 1) }

    /// IPv4 address family.
    ///
    /// The corresponding C constant is `AF_INET`.
    @_alwaysEmitIntoClient
    public static var ipv4: Family { Family(rawValue: 2) }

    /// IPv6 address family.
    ///
    /// The corresponding C constant is `AF_INET6`.
    @_alwaysEmitIntoClient
    public static var ipv6: Family { Family(rawValue: 23) }
  }
}

@available(System 199, *)
extension SocketAddress.Family: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unspecified: return "unspecified"
    case .local: return "local"
    case .ipv4: return "ipv4"
    case .ipv6: return "ipv6"
    default:
      return rawValue.description
    }
  }
}

#endif // os(Windows)
