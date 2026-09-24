/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

struct UDPEcho: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "udp-echo",
    abstract: "Echo datagrams between two UDP sockets on the loopback interface"
  )

  @Argument(help: "The messages to send")
  var messages: [String] = ["ping", "pong"]

  func run() throws {
    let server = try SocketDescriptor.open(.ipv4, .datagram, protocol: .udp)
    defer { try? server.close() }
    // Port 0 lets the system choose a free port, and getLocalAddress
    // reports which one it chose.
    try server.bind(to: SocketAddress(ipv4: .loopback(port: 0)))
    var serverAddress = SocketAddress()
    try server.getLocalAddress(into: &serverAddress)
    print("Server bound to \(serverAddress.niceDescription), a port the system chose")

    // The client's first send binds it to a port of its own.
    let client = try SocketDescriptor.open(.ipv4, .datagram, protocol: .udp)
    defer { try? client.close() }

    for message in messages {
      _ = try Array(message.utf8).withUnsafeBytes { try client.send($0, to: serverAddress) }
      // Each datagram comes with the address it was sent from,
      // which is where the reply goes.
      var sender = SocketAddress()
      let request = try receiveText(from: server, sender: &sender)
      print("Server received \"\(request)\" from \(sender.niceDescription)")
      _ = try Array(request.utf8).withUnsafeBytes { try server.send($0, to: sender) }

      var replier = SocketAddress()
      let reply = try receiveText(from: client, sender: &replier)
      print("Client received \"\(reply)\" from \(replier.niceDescription)")
    }
  }
}

/// Receives one datagram of up to 1 KiB, as UTF-8 text,
/// and the address it was sent from.
private func receiveText(
  from socket: SocketDescriptor, sender: inout SocketAddress
) throws -> String {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = try buffer.withUnsafeMutableBytes { try socket.receive(into: $0, sender: &sender) }
  return String(decoding: buffer[..<count], as: UTF8.self)
}
