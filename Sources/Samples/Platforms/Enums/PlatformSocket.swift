/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the multi-platform socket enum. Not API. See Platform.swift.

import SystemPackage
import SystemSockets

extension Platform {
  /// A connected stream socket, closed exactly once.
  ///
  /// A socket is a file descriptor on Unix, but not a file handle on
  /// Windows: `closesocket` closes it, and SYS-0011 says not to adopt one as
  /// a FileHandle. So the cases wrap different kinds of owner, OwnedSocket
  /// and Win32.Socket (both hypothetical).
  enum Socket: ~Copyable, Sendable {
    #if !os(Windows)
    /// A socket's file descriptor, on Unix.
    case fd(OwnedSocket)
    #endif

    #if os(Windows) || SIMULATE_PLATFORMS
    /// A WinSock socket, on Windows.
    case socket(Win32.Socket)
    #endif
  }

  /// Both ends of a connection. A tuple can't hold noncopyable values.
  struct SocketPair: ~Copyable, Sendable {
    var first: Socket
    var second: Socket
  }
}

extension Platform.Socket {
  /// Creates two connected stream sockets.
  ///
  /// - Unix: `socketpair`, in the local domain. On Darwin, both ends get
  ///   `SO_NOSIGPIPE`, so a send to a closed peer throws rather than raising
  ///   SIGPIPE. Linux's `send` passes `MSG_NOSIGNAL` instead.
  /// - Windows: a TCP connection over the loopback interface, since WinSock
  ///   has no `socketpair`. WinSock has no SIGPIPE.
  static func connectedPair() throws(Platform.Error) -> Platform.SocketPair {
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
    let pair = try Platform.typed { try OwnedSocket.pair(.local, .stream) }
    #if SYSTEM_PACKAGE_DARWIN
    try Platform.typed {
      try pair.first.socketDescriptor.setOption(
        .socket, SocketDescriptor.SocketOption.noSigPipe.rawValue, to: CInt(1))
      try pair.second.socketDescriptor.setOption(
        .socket, SocketDescriptor.SocketOption.noSigPipe.rawValue, to: CInt(1))
    }
    #endif
    return Platform.SocketPair(first: .fd(pair.first), second: .fd(pair.second))
    #endif
  }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Platform.Socket {
  /// Sends all of `data`.
  ///
  /// To a peer that closed, Unix throws `brokenPipe` (if SIGPIPE is
  /// suppressed; see `connectedPair()`), and Windows throws WSAECONNRESET
  /// or WSAECONNABORTED.
  func send(_ data: RawSpan) throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      #if SYSTEM_PACKAGE_DARWIN
      _ = try owner.fileDescriptor.writeAll(data)
      #else
      try Platform.typed {
        try data.withUnsafeBytes { bytes in
          var rest = bytes[...]
          while !rest.isEmpty {
            let sent = try owner.socketDescriptor.send(
              UnsafeRawBufferPointer(rebasing: rest), flags: .noSignal)
            rest = rest.dropFirst(sent)
          }
        }
      }
      #endif
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .socket(let socket):
      try socket.send(data)
    #endif
    }
  }

  /// Receives what has arrived, up to the buffer's free capacity. Zero means
  /// the peer shut down its sending side.
  func receive(into buffer: inout OutputRawSpan) throws(Platform.Error) -> Int {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return try owner.fileDescriptor.read(into: &buffer)
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .socket(let socket):
      return try socket.receive(into: &buffer)
    #endif
    }
  }
}

extension Platform.Socket {
  /// Ends this side's sending, so the peer receives zero.
  ///
  /// The corresponding C function is `shutdown` on both.
  func shutdownSending() throws(Platform.Error) {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      try Platform.typed { try owner.socketDescriptor.shutdown(.write) }
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .socket(let socket):
      try socket.shutdown(.sending)
    #endif
    }
  }

  /// Closes the socket, reporting any error.
  consuming func close() throws(Platform.Error) {
    switch consume self {
    #if !os(Windows)
    case .fd(let owner):
      try owner.close()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .socket(let socket):
      try socket.close()
    #endif
    }
  }

  /// The case and its raw value, for display.
  var summary: String {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return ".fd(\(owner.fileDescriptor.rawValue))"
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .socket(let socket):
      return ".socket(\(socket.unsafeRawSocket))"
    #endif
    }
  }
}
