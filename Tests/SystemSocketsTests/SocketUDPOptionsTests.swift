/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Linux) || os(Android)

import Testing

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

import SystemPackage
import SystemSockets

@Suite("UDP socket options")
private struct SocketUDPOptionsTests {
  /// Segmentation offload's size and receive offload's flag read back as
  /// they were set, on a kernel that has them (4.18 and 5.0).
  @available(System 199, *)
  @Test func offloadOptions() throws {
    let socket = try SocketDescriptor.open(.ipv4, .datagram, options: .closeOnExec)
    defer { try? socket.close() }
    for (option, value) in [(SocketDescriptor.UDPOption.segmentSize, CInt(1200)), (.receiveOffload, 1)] {
      do throws(Errno) {
        try socket.setUDPOption(option, to: value)
      } catch {
        // An older kernel.
        #expect(error == .protocolNotAvailable)
        continue
      }
      #expect(try socket.getUDPOption(option) == value)
      let raw: CInt = try socket.getOption(.udp, option.rawValue)
      #expect(raw == value)
    }
  }

  /// Neither option is a TCP socket's.
  @available(System 199, *)
  @Test func notOnATCPSocket() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream, options: .closeOnExec)
    defer { try? socket.close() }
    #expect(throws: Errno.self) { try socket.setUDPOption(.segmentSize, to: 1200) }
  }
}

#endif // os(Linux) || os(Android)
