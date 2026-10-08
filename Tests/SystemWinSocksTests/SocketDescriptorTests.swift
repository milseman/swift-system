/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import Testing
import WinSDK

@testable import SystemWinSocks
import SystemPackage

// Each test opens and closes its own sockets, and none binds or connects:
// nothing here reaches the network.
@Suite("Socket Descriptor (Winsock)")
private struct SocketDescriptorTests {
  @available(System 199, *)
  @Test func openAndClose() throws {
    let tcp = try SocketDescriptor.open(.ipv4, .stream, protocol: .tcp)
    #expect(tcp.rawValue != WinSDK.INVALID_SOCKET)
    try tcp.close()

    let udp = try SocketDescriptor.open(.ipv4, .datagram, protocol: .udp)
    #expect(udp.rawValue != WinSDK.INVALID_SOCKET)
    try udp.close()

    let tcp6 = try SocketDescriptor.open(.ipv6, .stream)
    #expect(tcp6.rawValue != WinSDK.INVALID_SOCKET)
    try tcp6.close()
  }

  // WSA_FLAG_NO_HANDLE_INHERIT, as SOCK_CLOEXEC would on POSIX.
  @available(System 199, *)
  @Test func socketsAreNotInherited() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    let handle = try #require(HANDLE(bitPattern: UInt(socket.rawValue)))
    var flags: DWORD = 0
    #expect(WinSDK.GetHandleInformation(handle, &flags))
    #expect(flags & WinSDK.HANDLE_FLAG_INHERIT == 0)
  }

  @available(System 199, *)
  @Test func openingAnUnknownFamilyFails() {
    #expect(throws: Win32.Error.addressFamilyNotSupported) {
      try SocketDescriptor.open(SocketDescriptor.Domain(rawValue: 9999), .stream)
    }
  }

  @available(System 199, *)
  @Test func closingANonSocketFails() {
    #expect(throws: Win32.Error.notSocket) {
      try SocketDescriptor(rawValue: WinSDK.INVALID_SOCKET).close()
    }
  }

  @available(System 199, *)
  @Test func shuttingDownAnUnconnectedSocketFails() throws {
    let socket = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? socket.close() }
    #expect(throws: Win32.Error.socketNotConnected) {
      try socket.shutdown(.readWrite)
    }
  }
}

#endif // os(Windows)
