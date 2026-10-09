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

// Unix domain sockets. The round trip binds a socket file of the test's
// own, at a random name in the temporary directory, and deletes that file
// only if its bind created it; nothing else on disk is touched.
@Suite("Unix domain sockets (Winsock)")
private struct UnixSocketTests {
  @available(System 199, *)
  @Test func layoutMatchesTheSDK() {
    #expect(CInterop.SockAddrUn.pathCapacity == Int(WinSDK.UNIX_PATH_MAX) - 1)
    #expect(MemoryLayout<CInterop.SockAddrUn>.size == 2 + 108)
  }

  @available(System 199, *)
  @Test func addresses() throws {
    let address = try #require(UnixAddress(#"C:\Temp\a.sock"#))
    #expect(address.path == #"C:\Temp\a.sock"#)
    #expect(address.description == #"C:\Temp\a.sock"#)
    let socketAddress = SocketAddress(unix: address)
    #expect(socketAddress.family == .local)
    #expect(socketAddress.unix == address)
    #expect(socketAddress.length == 2 + address.path.utf8.count + 1)
    #expect(socketAddress.description == #"SocketAddress(C:\Temp\a.sock)"#)

    #expect(UnixAddress(String(repeating: "x", count: 107)) != nil)
    #expect(UnixAddress(String(repeating: "x", count: 108)) == nil)
    // UTF-8: two bytes each.
    #expect(UnixAddress(String(repeating: "é", count: 54)) == nil)
    #expect(UnixAddress("é.sock")?.path == "é.sock")

    var raw = CInterop.SockAddrUn(family: .local, path: FilePath("b.sock"))
    #expect(raw.sun_family == ADDRESS_FAMILY(WinSDK.AF_UNIX))
    #expect(raw.path == FilePath("b.sock"))
    raw.path = FilePath("c")
    #expect(UnixAddress(raw).path == "c")
  }

  @available(System 199, *)
  @Test func streamRoundTrip() throws {
    let name = "swt-\(String(UInt32.random(in: 0 ... .max), radix: 16)).sock"
    let path = FilePath.temporaryDirectory().appending(name)
    let address = try #require(UnixAddress(path.string))

    let listener = try SocketDescriptor.open(.local, .stream)
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(unix: address))
    // The bind created the file, so it's the test's to delete.
    defer { try? Win32.deleteFile(path) }
    try listener.listen(backlog: 1)

    let client = try SocketDescriptor.open(.local, .stream)
    defer { try? client.close() }
    try client.connect(to: SocketAddress(unix: address))
    let server = try listener.accept()
    defer { try? server.close() }

    var local = SocketAddress()
    try listener.getLocalAddress(into: &local)
    #expect(local.unix?.path == address.path)

    _ = try [UInt8(1), 2].withUnsafeBytes { bytes in try client.send(bytes) }
    var received = [UInt8](repeating: 0, count: 2)
    let count = try received.withUnsafeMutableBytes { buffer in
      try server.receive(into: buffer, flags: .waitForAll)
    }
    #expect(count == 2 && received == [1, 2])
  }

  // Windows' Unix domain sockets are streams alone.
  @available(System 199, *)
  @Test func noDatagrams() {
    #expect(throws: Win32.Error.self) {
      try SocketDescriptor.open(.local, .datagram)
    }
  }
}

#endif // os(Windows)
