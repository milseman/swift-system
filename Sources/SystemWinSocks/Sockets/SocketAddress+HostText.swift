/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Converting host addresses to and from text in memory the caller manages,
// without a String or a SocketAddress.

@available(System 199, *)
extension IPv4Address.Host {
  /// The number of characters that holds the text form of any IPv4 host
  /// address and a terminating null character: 22 on Windows, which
  /// allows for a port, where POSIX's is 16.
  ///
  /// The corresponding C constant is `INET_ADDRSTRLEN`.
  @_alwaysEmitIntoClient
  public static var descriptionCapacity: Int { 22 }

  /// Parses a host address in dotted-decimal form, such as `"192.0.2.1"`,
  /// from a null-terminated C string,
  /// or returns `nil` if the string isn't one.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET`.
  public init?(cString: UnsafePointer<CChar>) {
    var address = CInterop.InAddr()
    guard system_inet_pton(SocketDescriptor.Domain.ipv4.rawValue, cString, &address) == 1 else {
      return nil
    }
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
  /// This method throws ``Win32/Error/invalidParameter`` if the text
  /// doesn't fit, as Windows' `inet_ntop` does, where POSIX's reports
  /// `ENOSPC`.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET`.
  public func description(into buffer: UnsafeMutableBufferPointer<CChar>) throws(Win32.Error) -> Int {
    try _describeHostAddress(SocketDescriptor.Domain.ipv4.rawValue, rawValue, into: buffer).get()
  }
}

@available(System 199, *)
extension IPv6Address.Host {
  /// The number of characters that holds the text form of any IPv6 host
  /// address and a terminating null character: 65 on Windows, which
  /// allows for a scope and a port, where POSIX's is 46.
  ///
  /// The corresponding C constant is `INET6_ADDRSTRLEN`.
  @_alwaysEmitIntoClient
  public static var descriptionCapacity: Int { 65 }

  /// Parses a host address in the text form of RFC 4291,
  /// such as `"2001:db8::1"`, from a null-terminated C string,
  /// or returns `nil` if the string isn't one.
  ///
  /// As with ``init(_:)``, a string with a scope, such as `"fe80::1%4"`,
  /// returns `nil`.
  ///
  /// The corresponding C function is `inet_pton`, with `AF_INET6`.
  public init?(cString: UnsafePointer<CChar>) {
    var next = cString
    while next.pointee != 0 {
      if next.pointee == CChar(UInt8(ascii: "%")) { return nil }
      next += 1
    }
    var address = CInterop.In6Addr()
    guard system_inet_pton(SocketDescriptor.Domain.ipv6.rawValue, cString, &address) == 1 else {
      return nil
    }
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
  /// This method throws ``Win32/Error/invalidParameter`` if the text
  /// doesn't fit, as Windows' `inet_ntop` does, where POSIX's reports
  /// `ENOSPC`.
  ///
  /// The corresponding C function is `inet_ntop`, with `AF_INET6`.
  public func description(into buffer: UnsafeMutableBufferPointer<CChar>) throws(Win32.Error) -> Int {
    try _describeHostAddress(SocketDescriptor.Domain.ipv6.rawValue, rawValue, into: buffer).get()
  }
}

/// Writes a C host address of the given family as text into `buffer`.
@available(System 199, *)
internal func _describeHostAddress<A>(
  _ family: CInt, _ address: A, into buffer: UnsafeMutableBufferPointer<CChar>
) -> Result<Int, Win32.Error> {
  // inet_ntop reports a buffer too small for the text, even an empty one,
  // as ERROR_INVALID_PARAMETER.
  guard let base = buffer.baseAddress, buffer.count > 0 else { return .failure(.invalidParameter) }
  var address = address
  let result = withUnsafePointer(to: &address) {
    system_inet_ntop(family, $0, base, buffer.count)
  }
  guard result != nil else { return .failure(_lastWinsockError()) }
  // inet_ntop wrote a null-terminated string that fits.
  return .success(buffer.firstIndex(of: 0) ?? buffer.count)
}

#endif // os(Windows)
