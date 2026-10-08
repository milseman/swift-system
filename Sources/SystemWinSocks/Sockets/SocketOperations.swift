/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Socket Creation and Lifecycle

@available(System 199, *)
extension SocketDescriptor {
  /// Creates an endpoint for communication.
  ///
  /// - Parameters:
  ///   - domain: The protocol family for communication.
  ///   - type: The semantics of communication.
  ///   - protocol: The particular protocol to use. The default is `.default`,
  ///     which typically selects the appropriate protocol for the domain/type
  ///     combination (e.g., TCP for IPv4/stream).
  ///   - retryOnInterrupt: Whether to retry if interrupted. The default is `true`.
  /// - Returns: A new socket descriptor.
  ///
  /// The socket supports overlapped I/O, so that it can be associated with
  /// a completion port, as `socket`'s sockets do; its blocking operations
  /// still block. Child processes don't inherit it, as POSIX's
  /// `SOCK_CLOEXEC` arranges.
  ///
  /// The first call in a process starts Winsock, with `WSAStartup`, and
  /// throws its error if that fails.
  ///
  /// The corresponding C function is `WSASocketW`, with `WSA_FLAG_OVERLAPPED`
  /// and `WSA_FLAG_NO_HANDLE_INHERIT`.
  @_alwaysEmitIntoClient
  public static func open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID = .default,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> SocketDescriptor {
    try _open(domain, type, protocol: `protocol`, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _open(
    _ domain: Domain,
    _ type: ConnectionType,
    protocol: ProtocolID,
    retryOnInterrupt: Bool
  ) -> Result<SocketDescriptor, Win32.Error> {
    _startWinsock().flatMap {
      socketOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_WSASocketW(
          domain.rawValue, type.rawValue, `protocol`.rawValue,
          _WSA_FLAG_OVERLAPPED | _WSA_FLAG_NO_HANDLE_INHERIT)
      }.map(SocketDescriptor.init(rawValue:))
    }
  }

  /// Closes the socket.
  ///
  /// On a nonblocking socket whose ``setLinger(_:)`` time isn't zero,
  /// closing throws ``Win32/Error/wouldBlock`` while unsent data remains,
  /// and the socket stays open.
  ///
  /// The corresponding C function is `closesocket`.
  @_alwaysEmitIntoClient
  public func close() throws(Win32.Error) {
    try _close().get()
  }

  @usableFromInline
  internal func _close() -> Result<(), Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_closesocket(self.rawValue)
    }
  }

  /// Shuts down part of a full-duplex connection.
  ///
  /// - Parameter how: Which parts of the connection to shut down.
  ///
  /// The corresponding C function is `shutdown`.
  @_alwaysEmitIntoClient
  public func shutdown(_ how: ShutdownKind) throws(Win32.Error) {
    try _shutdown(how).get()
  }

  @usableFromInline
  internal func _shutdown(_ how: ShutdownKind) -> Result<(), Win32.Error> {
    nothingOrWinsockError(retryOnInterrupt: false) {
      system_shutdown(self.rawValue, how.rawValue)
    }
  }
}

#endif // os(Windows)
