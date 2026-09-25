/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// HYPOTHETICAL Unix API, compiled in both configurations. An owned socket,
// as Prototype/Subtypes/Sketch.swift sketches it for SystemSockets: it holds
// an OwnedFD, has no deinit of its own, and vends its SocketDescriptor
// rather than forwarding. SystemSockets doesn't have it.

import SystemPackage
import SystemSockets

/// A socket that is closed exactly once. The owned form of SocketDescriptor.
struct OwnedSocket: ~Copyable, Sendable {
  private var owner: OwnedFD

  /// Takes ownership of a socket descriptor.
  init(taking socket: SocketDescriptor) {
    owner = OwnedFD(taking: socket.fileDescriptor)
  }

  /// The socket, for socket operations. Valid only while this owner is alive.
  var socketDescriptor: SocketDescriptor {
    SocketDescriptor(unchecked: owner.fileDescriptor)
  }

  /// The socket as a file descriptor. Valid only while this owner is alive.
  var fileDescriptor: FileDescriptor { owner.fileDescriptor }

  consuming func close() throws(Errno) { try owner.close() }

  consuming func relinquish() -> SocketDescriptor {
    SocketDescriptor(unchecked: owner.relinquish())
  }

  /// Both ends of a connected socket pair.
  struct Pair: ~Copyable, Sendable {
    var first: OwnedSocket
    var second: OwnedSocket
  }

  /// Creates a pair of connected sockets.
  ///
  /// The corresponding C function is `socketpair`.
  static func pair(
    _ domain: SocketDescriptor.Domain, _ type: SocketDescriptor.ConnectionType
  ) throws -> Pair {
    let (first, second) = try SocketDescriptor.pair(domain, type)
    return Pair(first: OwnedSocket(taking: first), second: OwnedSocket(taking: second))
  }
}
