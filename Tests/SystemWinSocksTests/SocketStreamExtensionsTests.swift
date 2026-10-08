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

// AcceptEx, ConnectEx and TransmitFile over loopback connections of the
// test's own, reported through completion ports of its own. The file that
// TransmitFile sends is a temporary file at a name of the test's own
// choosing, which the system deletes when its handle closes. Each
// OVERLAPPED and buffer is freed only after its packet has been dequeued,
// and every dequeue has a time-out.
@Suite("Stream extension functions (Winsock)")
private struct SocketStreamExtensionsTests {
  @available(System 199, *)
  @Test func constantsMatchTheSDK() throws {
    typealias Options = SocketDescriptor.TransmitFileOptions
    #expect(Options.disconnect.rawValue == DWORD(WinSDK.TF_DISCONNECT))
    #expect(Options.reuseSocket.rawValue == DWORD(WinSDK.TF_REUSE_SOCKET))
    #expect(Options.writeBehind.rawValue == DWORD(WinSDK.TF_WRITE_BEHIND))
    #expect(Options.useSystemThread.rawValue == DWORD(WinSDK.TF_USE_SYSTEM_THREAD))
    #expect(Options.useKernelAPC.rawValue == DWORD(WinSDK.TF_USE_KERNEL_APC))
    #expect(_SO_UPDATE_ACCEPT_CONTEXT == WinSDK.SO_UPDATE_ACCEPT_CONTEXT)
    #expect(_SO_UPDATE_CONNECT_CONTEXT == WinSDK.SO_UPDATE_CONNECT_CONTEXT)
    #expect(SocketDescriptor.acceptAddressesCapacity == 2 * (128 + 16))
    _ = try _winsockStreamFunctions.get()
  }

  /// A zeroed OVERLAPPED, to free with `deallocate()`.
  private static func overlapped() -> UnsafeMutablePointer<OVERLAPPED> {
    let overlapped = UnsafeMutablePointer<OVERLAPPED>.allocate(capacity: 1)
    overlapped.initialize(to: OVERLAPPED())
    return overlapped
  }

  @available(System 199, *)
  @Test func acceptingAndConnectingOverlapped() throws {
    let listener = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    let accepted = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? accepted.close() }
    // ConnectEx needs a bound socket.
    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? client.close() }
    try client.bind(to: SocketAddress(ipv4: .loopback(port: 0)))

    let port = try Win32.CompletionPort.create()
    try port.associate(listener, key: 1)
    try port.associate(client, key: 2)
    let addresses = UnsafeMutableRawBufferPointer.allocate(
      byteCount: SocketDescriptor.acceptAddressesCapacity, alignment: 8)
    let acceptOverlapped = Self.overlapped()
    let connectOverlapped = Self.overlapped()
    defer {
      addresses.deallocate()
      acceptOverlapped.deallocate()
      connectOverlapped.deallocate()
    }

    _ = try listener.accept(into: accepted, addresses: addresses, overlapped: acceptOverlapped)
    _ = try client.connect(to: address, overlapped: connectOverlapped)
    // Both queue a packet, whether they finished at once or not.
    var keys: Set<UInt> = []
    for _ in 0 ..< 2 {
      let completion = try #require(try port.dequeue(timeout: .seconds(5)))
      #expect(completion.error == nil)
      keys.insert(completion.key)
    }
    #expect(keys == [1, 2])

    try accepted.updateAcceptContext(listener: listener)
    try client.updateConnectContext()
    var clientAddress = SocketAddress()
    try client.getLocalAddress(into: &clientAddress)
    var peer = SocketAddress()
    try accepted.getPeerAddress(into: &peer)
    #expect(peer == clientAddress)
    try client.getPeerAddress(into: &peer)
    #expect(peer == address)
  }

  @available(System 199, *)
  @Test func transmittingAFile() throws {
    let listener = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? listener.close() }
    try listener.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    try listener.listen(backlog: 4)
    var address = SocketAddress()
    try listener.getLocalAddress(into: &address)
    let client = try SocketDescriptor.open(.ipv4, .stream)
    defer { try? client.close() }
    try client.connect(to: address)
    let server = try listener.accept()
    defer { try? server.close() }

    let contents = (0 ..< 1000).map { UInt8(truncatingIfNeeded: $0) }
    let name = "SystemWinSocksTests-\(ProcessID.current.rawValue)-\(UInt64.random(in: 0 ... .max)).tmp"
    let file = try Win32.FileHandle.open(
      FilePath.temporaryDirectory().appending(name),
      access: [.genericRead, .genericWrite], shareMode: [], disposition: .createNew,
      attributes: .temporary, flags: .deleteOnClose)
    try contents.withUnsafeBytes { bytes in
      try file.write(RawSpan(_unsafeBytes: bytes), toAbsoluteOffset: 0)
    }

    let port = try Win32.CompletionPort.create()
    try port.associate(server, key: 3)
    let overlapped = Self.overlapped()
    defer { overlapped.deallocate() }
    // The 900 bytes after the first 100.
    _ = try server.transmitFile(
      file.unsafeRawHandle, byteCount: 900, fromAbsoluteOffset: 100, overlapped: overlapped)
    let completion = try #require(try port.dequeue(timeout: .seconds(5)))
    #expect(completion.key == 3 && completion.error == nil)
    #expect(completion.bytesTransferred == 900)

    var received = [UInt8](repeating: 0, count: 900)
    let count = try received.withUnsafeMutableBytes { buffer in
      try client.receive(into: buffer, flags: .waitForAll)
    }
    #expect(count == 900 && received[...] == contents[100...])
    try file.close()
  }
}

#endif // os(Windows)
