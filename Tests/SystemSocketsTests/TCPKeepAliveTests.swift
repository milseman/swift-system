/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

@testable import SystemSockets
import SystemPackage

// keepAliveIdle and keepAliveInterval are documented as seconds. Reading
// back a value that was just set can't show that, so these tests compare a
// new socket's values with the system-wide defaults, which each platform
// documents in its own unit.
@Suite("TCP keepalive")
private struct TCPKeepAliveTests {
  @available(System 199, *)
  @Test func keepAliveTimesAreInSeconds() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    defer { try? socket.close() }

    let defaults = try #require(systemKeepAliveDefaults())
    #expect(try socket.getTCPOption(.keepAliveIdle) == defaults.idle)
    #expect(try socket.getTCPOption(.keepAliveInterval) == defaults.interval)

    // Each value set, in seconds, reads back unchanged.
    for seconds: CInt in [1, 75, 7200] {
      try socket.setTCPOption(.keepAliveIdle, to: seconds)
      #expect(try socket.getTCPOption(.keepAliveIdle) == seconds)
      try socket.setTCPOption(.keepAliveInterval, to: seconds)
      #expect(try socket.getTCPOption(.keepAliveInterval) == seconds)
    }
  }
}

/// Returns the system's default keepalive idle time and interval, in seconds.
private func systemKeepAliveDefaults() -> (idle: CInt, interval: CInt)? {
  #if SYSTEM_PACKAGE_DARWIN
  // Darwin's sysctls give them in milliseconds.
  func milliseconds(_ name: String) -> CInt? {
    var value: CInt = 0
    var size = MemoryLayout<CInt>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
  }
  guard let idle = milliseconds("net.inet.tcp.keepidle"),
        let interval = milliseconds("net.inet.tcp.keepintvl")
  else { return nil }
  return (idle / 1000, interval / 1000)
  #else
  // Linux's files under /proc/sys give them in seconds.
  func seconds(_ name: String) -> CInt? {
    guard let fd = try? FileDescriptor.open(FilePath("/proc/sys/net/ipv4/\(name)"), .readOnly) else {
      return nil
    }
    defer { try? fd.close() }
    var bytes = [UInt8](repeating: 0, count: 32)
    guard let count = try? bytes.withUnsafeMutableBytes({ try fd.read(into: $0) }) else {
      return nil
    }
    let text = String(decoding: bytes.prefix(count), as: UTF8.self)
    return text.split(whereSeparator: \.isWhitespace).first.flatMap { CInt($0) }
  }
  guard let idle = seconds("tcp_keepalive_time"),
        let interval = seconds("tcp_keepalive_intvl")
  else { return nil }
  return (idle, interval)
  #endif
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux)
