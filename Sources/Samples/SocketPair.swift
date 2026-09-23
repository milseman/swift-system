/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage
import SystemSockets

struct SocketPair: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "socket-pair",
    abstract: "Send messages between the two ends of a socket pair"
  )

  enum Kind: String, CaseIterable, ExpressibleByArgument {
    case stream, datagram
  }

  @Option(name: .shortAndLong, help: "The kind of socket")
  var kind: Kind = .stream

  @Argument(help: "The messages to send")
  var messages: [String] = ["ping", "pong"]

  func run() throws {
    let (first, second) = try SocketDescriptor.pair(
      .local, kind == .stream ? .stream : .datagram)
    defer {
      try? first.close()
      try? second.close()
    }

    for message in messages {
      let sent = try Array(message.utf8).withUnsafeBytes { try first.send($0) }
      print("first sent \(sent) bytes: \(message)")
    }

    // A stream has no message boundaries, so one receive can return
    // several messages. A datagram socket returns one message per receive.
    if kind == .stream {
      try first.shutdown(.write)
      while let text = try receive(from: second) {
        print("second received: \(text)")
      }
      print("second received end of file")
    } else {
      for _ in messages {
        print("second received: \(try receive(from: second) ?? "")")
      }
    }

    // A socket is a file descriptor, so FileDescriptor API works on it.
    try second.fileDescriptor.writeAll("done".utf8)
    print("first received: \(try receive(from: first) ?? "")")

    // Going back from a FileDescriptor checks that it's a socket.
    let checked = try SocketDescriptor(second.fileDescriptor)
    print("descriptor \(checked.rawValue) is a socket")
    do {
      _ = try SocketDescriptor(FileDescriptor.standardInput)
      print("standard input is a socket too")
    } catch {
      guard error == .notSocket else { throw error }
      print("standard input isn't a socket")
    }
  }
}

/// Receives up to 1 KiB as UTF-8 text, or returns `nil` at end of file.
private func receive(from socket: SocketDescriptor) throws -> String? {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = try buffer.withUnsafeMutableBytes { try socket.receive(into: $0) }
  return count == 0 ? nil : String(decoding: buffer[..<count], as: UTF8.self)
}
