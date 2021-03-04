
/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
#if SYSTEM_PACKAGE
import SystemPackage
#else
import System
#endif

private func _systemEcho(
  on socket: SocketDescriptor,
  _ buffer: UnsafeMutableRawBufferPointer
) throws {
  var client = SocketAddress()
  let conn = try socket.accept(client: &client)
  print("Connection from \(client.ipv4!)") // Prints as, e.g., "127.0.0.1:55255"
  try conn.closeAfter {
    var ancillary = SocketDescriptor.AncillaryMessageBuffer()
    while true {
      let (count, _) = try conn.receive(
        into: buffer, sender: &client, ancillary: &ancillary)
      guard count > 0 else { return }
      try FileDescriptor.standardOutput.writeAll(buffer[..<count])
    }
  }
}

import Darwin
private func _preSocketEcho(
  on socket: FileDescriptor,
  _ buffer: UnsafeMutableRawBufferPointer
) throws {
  var client = sockaddr_in()
  var length = socklen_t(MemoryLayout<sockaddr_in>.stride)
  try withUnsafeMutablePointer(to: &client) { clientPointer -> () in
    try clientPointer.withMemoryRebound(
      to: sockaddr.self, capacity: 1
    ) { sockaddrPtr -> () in
      let conn = accept(socket.rawValue, sockaddrPtr, &length)
      guard conn != -1 else { throw Errno(rawValue: errno) }
      print("Connection from \("<too complicated to show in this example>")")
      try FileDescriptor(rawValue: conn).closeAfter {
        while true {
          var m = msghdr()
          m.msg_name = UnsafeMutableRawPointer(sockaddrPtr)
          m.msg_namelen = length
          var iov = iovec()
          iov.iov_base = buffer.baseAddress
          iov.iov_len = buffer.count
          try withUnsafeMutablePointer(to: &iov) { iov in
            m.msg_iov = iov
            m.msg_iovlen = 1
            m.msg_control = nil // way too complicated to show in an example...
            m.msg_controllen = 0
            m.msg_flags = 0
            let count = withUnsafeMutablePointer(to: &m) { recvmsg(conn, $0, 0) }
            guard count != -1 else { throw Errno(rawValue: errno) }
            guard count > 0 else { return }
            try FileDescriptor.standardOutput.writeAll(buffer[..<count])
          }
        }
      }
    }
  }
}

//private func printClientMessageSystem(
//  on socket: SocketDescriptor,
//  useUPD: Bool
//) {
//
//}
//private func printClientMessage(
//  on socket: UInt32
//)

struct PrintExample: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "printExample",
    abstract: "Simple example of using System vs Darwin for TCP echo."
  )

  @Argument(help: "The port number (or service name) to listen on.")
  var service: String

  @Flag(help: "Use pre-socket-support System")
  var preSocket: Bool = false

  func prefix(
    client: SocketAddress,
    flags: SocketDescriptor.MessageFlags
  ) -> String {
    var prefix: [String] = []
    if client.family != .unspecified {
      prefix.append("client: \(client.niceDescription)")
    }
    if flags != .none {
      prefix.append("flags: \(flags)")
    }
    guard !prefix.isEmpty else { return "" }
    return "<\(prefix.joined(separator: ", "))> "
  }

  func run() throws {
    guard let (socket, address) = try Listen.startServer(
      hostname: nil,
      service: service,
      flags: .canonicalName,
      family: .ipv4,
      type: .stream
    ) else {
      complain("Can't listen on \(service)")
      throw ExitCode.failure
    }
    complain("Listening on \(address.address.niceDescription)")

    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
    defer { buffer.deallocate() }

    try socket.closeAfter {
      if preSocket {
        try _preSocketEcho(on: socket.fileDescriptor, buffer)
      } else {
        try _systemEcho(on: socket, buffer)
      }
    }
  }
}

