/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import SystemPackage
import SystemSockets

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
// glibc and Bionic declare stdin, stdout, and stderr as mutable globals,
// which disableBuffering() uses.
@preconcurrency import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
@preconcurrency import Android
#else
#error("Unsupported Platform")
#endif

/// Turn off libc's input/output buffering.
internal func disableBuffering() {
  setbuf(stdin, nil)
  setbuf(stdout, nil)
  setbuf(stderr, nil)
}

/// Prints rows of cells in left-aligned columns, indented.
internal func printTable(_ rows: [[String]]) {
  let columns = rows.map(\.count).max() ?? 0
  let widths = (0..<columns).map { column in
    rows.map { column < $0.count ? $0[column].count : 0 }.max()! + 2
  }
  for row in rows {
    var line = "  "
    for (column, text) in row.enumerated() {
      let isLast = column == row.count - 1
      line += isLast ? text : text + String(repeating: " ", count: widths[column] - text.count)
    }
    print(line)
  }
}

/// Formats an offset in a file, which is a number of bytes.
internal func position(_ offset: Int64) -> String {
  offset == 0 ? "0" : amount(offset)
}

/// Formats a number of bytes as a sum of units, such as "512 MiB + 4 KiB".
internal func amount(_ bytes: Int64) -> String {
  var parts: [String] = []
  var rest = bytes
  for (unit, shift) in [("GiB", 30), ("MiB", 20), ("KiB", 10)] where rest >> shift > 0 {
    parts.append("\(rest >> shift) \(unit)")
    rest &= (1 << shift) - 1
  }
  if rest > 0 || parts.isEmpty { parts.append(rest == 1 ? "1 byte" : "\(rest) bytes") }
  return parts.joined(separator: " + ")
}

internal func complain(_ message: String) {
  var message = message + "\n"
  message.withUTF8 { buffer in
    _ = try? FileDescriptor.standardError.writeAll(buffer)
  }
}

extension SocketAddress.ResolvedAddress {
  var niceDescription: String {
    var proto = ""
    switch self.protocol {
    case .udp: proto = "udp"
    case .tcp: proto = "tcp"
    default: proto = "\(self.protocol)"
    }
    return "\(address.niceDescription) (\(proto))"
  }
}

extension SocketAddress {
  var niceDescription: String {
    if let ipv4 = self.ipv4 { return ipv4.description }
    if let ipv6 = self.ipv6 { return ipv6.description }
    if let unix = self.unix { return unix.description }
    return self.description
  }
}

extension SocketDescriptor.ConnectionType {
  var isConnectionless: Bool {
    self == .datagram || self == .reliablyDeliveredMessage
  }
}
