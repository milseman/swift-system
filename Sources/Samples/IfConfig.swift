/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

#if !os(Windows) && !os(WASI)

// For the address families, AF_INET and AF_INET6.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

struct IfConfig: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ifconfig",
    abstract: "List the network interfaces, with their flags, indexes and IP addresses"
  )

  @Argument(help: "Show only this interface")
  var interface: String?

  func run() throws {
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("ifconfig uses Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    // The list has an entry per address, so gather each interface's.
    var names: [String] = []
    var flags: [String: NetworkInterface.Flags] = [:]
    var lines: [String: [String]] = [:]
    let addresses = try NetworkInterface.Addresses()
    addresses.forEach { entry in
      let name = entry.name
      guard interface == nil || interface == name else { return }
      if flags[name] == nil {
        names.append(name)
        flags[name] = entry.flags
      }
      if let line = describe(entry) { lines[name, default: []].append(line) }
    }
    if let interface, names.isEmpty {
      complain("No interface is named \(interface)")
      throw ExitCode.failure
    }

    for name in names {
      let index = (try NetworkInterface.Index(name: name)).map { "\($0.rawValue)" } ?? "none"
      print("\(name): index \(index), \(describe(flags[name]!))")
      for line in lines[name, default: []] { print("    \(line)") }
    }
  }

  /// An entry's IP address and its prefix length, or nil for other families.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func describe(_ entry: borrowing NetworkInterface.Addresses.Entry) -> String? {
    // SystemSockets' SocketAddress reads the sockaddr's bytes.
    guard let text = address(entry.address) else { return nil }
    let prefix = prefixLength(entry.netmask, family: entry.addressFamily)
    var line = text + (prefix.map { "/\($0)" } ?? "")
    if let broadcast = address(entry.broadcastAddress) { line += " broadcast \(broadcast)" }
    if let destination = address(entry.destinationAddress) { line += " destination \(destination)" }
    return line
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func address(_ bytes: RawSpan?) -> String? {
    guard let bytes else { return nil }
    let address = bytes.withUnsafeBytes { SocketAddress($0) }
    return address.ipv4?.addressString ?? address.ipv6?.addressString
  }

  /// The number of leading one bits in a netmask, which on Darwin and the
  /// BSDs can be shorter than its family's sockaddr, without trailing zeros.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  private func prefixLength(_ netmask: RawSpan?, family: CInt?) -> Int? {
    guard let netmask else { return nil }
    let range: Range<Int>
    switch family {
    case AF_INET?: range = 4..<8
    case AF_INET6?: range = 8..<24
    default: return nil
    }
    return netmask.withUnsafeBytes { bytes in
      range.reduce(0) { $0 + ($1 < bytes.count ? bytes[$1].nonzeroBitCount : 0) }
    }
  }

  private func describe(_ flags: NetworkInterface.Flags) -> String {
    let names: [(NetworkInterface.Flags, String)] = [
      (.up, "up"), (.broadcast, "broadcast"), (.loopback, "loopback"),
      (.pointToPoint, "point-to-point"), (.running, "running"), (.noARP, "no-arp"),
      (.promiscuous, "promiscuous"), (.allMulticast, "all-multicast"), (.multicast, "multicast"),
    ]
    return "flags <" + names.filter { flags.contains($0.0) }.map(\.1).joined(separator: ",") + ">"
  }
}

#else
struct IfConfig: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ifconfig",
    abstract: "Unavailable: System has no getifaddrs on Windows or WASI"
  )

  func run() throws {
    complain("ifconfig isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
