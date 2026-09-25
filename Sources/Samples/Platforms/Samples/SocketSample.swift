/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: sockets through Platform.Socket. The common subset (send,
// receive, shutdownSending, close) carries a conversation, and the
// platform-specific operation is keeping a send to a closed peer from
// raising SIGPIPE, which would end this process.
//
// That operation has a different shape on each platform: a socket option on
// Darwin, a flag on every send on Linux (which Platform.Socket.send passes),
// and nothing on Windows, which has no SIGPIPE. So the switch has an arm
// with nothing in it, which says so, where `#if` would say nothing.
//
// The sockets come from outside the enum, as an accepted connection or
// another library's socket would, so nothing has suppressed SIGPIPE yet.

import ArgumentParser
import SystemPackage
import SystemSockets

struct PlatformSocket: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "socket",
    abstract: "Talk over a connected pair through Platform.Socket, and send to a closed peer"
  )

  @OptionGroup var simulation: SimulationOptions

  func run() throws {
    simulation.apply()
    guard #available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *) else {
      complain("The platform samples use Span, which requires macOS 15 or later")
      throw ExitCode.failure
    }
    let pair = try adoptedPair()
    let client = pair.first
    let server = pair.second
    print("client \(client.summary), server \(server.summary)")
    try keepSendsFromRaisingSIGPIPE(client)

    // The common subset carries the conversation.
    try withSpan(of: "hello") { try client.send($0) }
    try client.shutdownSending()
    print("server received \"\(try receiveAll(server))\", then the end of the stream")

    // A send to a peer that closed throws, on each platform its own way:
    // brokenPipe (EPIPE) on Unix, WSAECONNRESET on Windows.
    try server.close()
    do {
      try withSpan(of: "anyone there?") { try client.send($0) }
      print("the send to a closed peer succeeded")
    } catch {
      print("the send to a closed peer threw \(describe(error))")
    }
    try client.close()
  }
}

/// A connected pair from each platform's own API, as another library might
/// hand over. Unlike `Platform.Socket.connectedPair()`, it leaves SIGPIPE
/// alone.
func adoptedPair() throws -> Platform.SocketPair {
  #if SIMULATE_PLATFORMS
  if Simulation.platform == .windows {
    let pair = try Win32.Socket.loopbackPair()
    return Platform.SocketPair(first: .socket(pair.first), second: .socket(pair.second))
  }
  #endif
  #if os(Windows)
  let pair = try Win32.Socket.loopbackPair()
  return Platform.SocketPair(first: .socket(pair.first), second: .socket(pair.second))
  #else
  let pair = try OwnedSocket.pair(.local, .stream)
  return Platform.SocketPair(first: .fd(pair.first), second: .fd(pair.second))
  #endif
}

/// Makes a send to a closed peer throw, rather than raise SIGPIPE: the
/// platform-specific operation.
func keepSendsFromRaisingSIGPIPE(_ socket: borrowing Platform.Socket) throws {
  switch socket {
  #if !os(Windows)
  case .fd(let owner):
    #if SYSTEM_PACKAGE_DARWIN
    // A per-socket option. `setOption` is generic over the value's type.
    try owner.socketDescriptor.setOption(
      .socket, SocketDescriptor.SocketOption.noSigPipe.rawValue, to: CInt(1))
    print("set SO_NOSIGPIPE on \(socket.summary)")
    #else
    // Linux has no such option; Platform.Socket.send passes MSG_NOSIGNAL.
    _ = owner
    #endif
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .socket:
    // WinSock never raises SIGPIPE. Nothing to do, and this arm says so.
    print("nothing to do for \(socket.summary): Windows has no SIGPIPE")
  #endif
  }
}

/// Receives until the peer shuts down its sending side.
@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
func receiveAll(_ socket: borrowing Platform.Socket) throws -> String {
  let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  defer { storage.deallocate() }
  var received: [UInt8] = []
  while true {
    var buffer = OutputRawSpan(buffer: storage, initializedCount: 0)
    let count = try socket.receive(into: &buffer)
    if count == 0 { break }
    buffer.bytes.withUnsafeBytes { received.append(contentsOf: $0) }
  }
  return String(decoding: received, as: UTF8.self)
}
