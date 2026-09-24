/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

struct UnixSocket: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "unix-socket",
    abstract: "Connect a client to a server through a socket file, in one process"
  )

  @Argument(help: "Where to make the socket file, which is removed afterward")
  var directory: String

  @Argument(help: "The messages for the client to send")
  var messages: [String] = ["hello", "goodbye"]

  func run() throws {
    let path = FilePath(directory).appending("unix-socket-demo-\(ProcessID.current.rawValue)")
    // UnixAddress takes a String, and fails for a path too long to fit.
    guard let unixAddress = UnixAddress(path.string) else {
      complain("Error: \(path) is too long for a socket address")
      throw ExitCode.failure
    }
    let address = SocketAddress(unix: unixAddress)
    defer { try? path.unlink() }

    let server = try SocketDescriptor.open(.local, .stream)
    try server.closeAfter {
      try server.bind(to: address)
      try server.listen(backlog: 1)
      // FileType has no description, so compare it.
      let isSocket = try path.stat().type == .socket
      print("Server listening on \(path), which bind made: "
        + (isSocket ? "a socket file" : "a file that isn't a socket"))

      let client = try SocketDescriptor.open(.local, .stream)
      try client.closeAfter {
        // The connection waits in the listen queue, so connect returns
        // before the server accepts it, and one thread can do both.
        try client.connect(to: address)
        var clientAddress = SocketAddress()
        let connection = try server.accept(client: &clientAddress)
        try connection.closeAfter {
          var peer = SocketAddress()
          try client.getPeerAddress(into: &peer)
          print("Client connected to \(name(peer)), from \(name(clientAddress))")

          for message in messages {
            try send(message, on: client)
            let request = try receive(from: connection)
            print("Server received \"\(request)\"")
            try send(request.uppercased(), on: connection)
            print("Client received \"\(try receive(from: client))\"")
          }
        }
      }
    }
    print("Closed the sockets")

    // The file outlives the socket, so a new server can't bind to the path
    // until the file is removed.
    let second = try SocketDescriptor.open(.local, .stream)
    try second.closeAfter {
      do {
        try second.bind(to: address)
      } catch let error as Errno where error == .addressInUse {
        print("A new server's bind to the same path fails: \(error)")
      }
      try path.unlink()
      try second.bind(to: address)
      print("After removing the file, it succeeds")
    }

    let longest = (1...1024).last { UnixAddress(String(repeating: "x", count: $0)) != nil } ?? 0
    print("A socket address holds a path of up to \(longest) bytes; "
      + "UnixAddress(_:) returns nil for a longer one")
  }
}

/// Describes a Unix domain socket's address, which is a path
/// if the socket was bound to one.
private func name(_ address: SocketAddress) -> String {
  guard let path = address.unix?.path, !path.isEmpty else { return "an unnamed socket" }
  return path
}

private func send(_ text: String, on socket: SocketDescriptor) throws {
  _ = try Array(text.utf8).withUnsafeBytes { try socket.send($0) }
}

/// Receives up to 1 KiB as UTF-8 text.
private func receive(from socket: SocketDescriptor) throws -> String {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = try buffer.withUnsafeMutableBytes { try socket.receive(into: $0) }
  return String(decoding: buffer[..<count], as: UTF8.self)
}
