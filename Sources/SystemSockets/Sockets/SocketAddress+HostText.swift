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
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported Platform")
#endif

// Converting host addresses to and from text in memory the caller manages,
// without a String or a SocketAddress.

@available(System 199, *)
extension IPv4Address.Host {
  /// The number of characters that holds the text form of any IPv4 host
  /// address and a terminating null character: 16.
  ///
  /// The corresponding C constant is `INET_ADDRSTRLEN`.
  @_alwaysEmitIntoClient
  public static var descriptionCapacity: Int { Int(INET_ADDRSTRLEN) }

  /// Parses a host address in dotted-decimal form, such as `"192.0.2.1"`,
  /// from a null-terminated C string,
  /// or returns `nil` if the string isn't one.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET`.
  public init?(cString: UnsafePointer<CChar>) {
    var address = in_addr()
    guard system_inet_pton(AF_INET, cString, &address) == 1 else { return nil }
    self.init(rawValue: address)
  }

  /// Writes the host address in dotted-decimal form,
  /// and a terminating null character, into a buffer.
  ///
  /// - Parameter buffer: The buffer to write into.
  ///   ``descriptionCapacity`` characters hold any address.
  /// - Returns: The number of characters written, not counting the null
  ///   character.
  ///
  /// This method throws ``Errno/noSpace`` if the text doesn't fit.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET`.
  public func description(into buffer: UnsafeMutableBufferPointer<CChar>) throws(Errno) -> Int {
    try _describeHostAddress(AF_INET, rawValue, into: buffer).get()
  }
}

@available(System 199, *)
extension IPv6Address.Host {
  /// The number of characters that holds the text form of any IPv6 host
  /// address and a terminating null character: 46.
  ///
  /// The corresponding C constant is `INET6_ADDRSTRLEN`.
  @_alwaysEmitIntoClient
  public static var descriptionCapacity: Int { Int(INET6_ADDRSTRLEN) }

  /// Parses a host address in the text form of RFC 4291,
  /// such as `"2001:db8::1"`, from a null-terminated C string,
  /// or returns `nil` if the string isn't one.
  ///
  /// As with ``init(_:)``, a string with a scope, such as `"fe80::1%en0"`,
  /// returns `nil`.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET6`.
  public init?(cString: UnsafePointer<CChar>) {
    var next = cString
    while next.pointee != 0 {
      if next.pointee == CChar(UInt8(ascii: "%")) { return nil }
      next += 1
    }
    var address = in6_addr()
    guard system_inet_pton(AF_INET6, cString, &address) == 1 else { return nil }
    self.init(rawValue: address)
  }

  /// Writes the host address in the text form of RFC 5952,
  /// and a terminating null character, into a buffer.
  ///
  /// - Parameter buffer: The buffer to write into.
  ///   ``descriptionCapacity`` characters hold any address.
  /// - Returns: The number of characters written, not counting the null
  ///   character.
  ///
  /// This method throws ``Errno/noSpace`` if the text doesn't fit.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET6`.
  public func description(into buffer: UnsafeMutableBufferPointer<CChar>) throws(Errno) -> Int {
    try _describeHostAddress(AF_INET6, rawValue, into: buffer).get()
  }
}

/// Writes a C host address of the given family as text into `buffer`.
@available(System 199, *)
internal func _describeHostAddress<A>(
  _ family: CInt, _ address: A, into buffer: UnsafeMutableBufferPointer<CChar>
) -> Result<Int, Errno> {
  // inet_ntop reports a buffer too small for the text, even an empty one,
  // as ENOSPC.
  guard let base = buffer.baseAddress, buffer.count > 0 else { return .failure(.noSpace) }
  // A mocked inet_ntop writes nothing, so leave a string to measure.
  base.pointee = 0
  var address = address
  let result = withUnsafePointer(to: &address) {
    system_inet_ntop(family, $0, base, CInterop.SockLen(clamping: buffer.count))
  }
  guard result == 0 else { return .failure(.current) }
  return .success(system_strlen(base))
}
