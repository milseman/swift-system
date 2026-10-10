/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import SystemPackage

// Polling sockets, with the names SystemWinSocks gives WSAPoll on Windows,
// so that code that polls sockets spells it once. POSIX polls a socket as it
// polls any file descriptor, so these are SystemPackage's poll and its
// types, with a socket's initializer and property on an entry; sockets and
// other file descriptors, such as a pipe that wakes a poll, can share one.

@available(System 199, *)
extension SocketDescriptor {
  /// The events to poll a socket for, or that polling found.
  ///
  /// These are ``FileDescriptor/PollEvents``: POSIX polls a socket as it
  /// polls any file descriptor. Polling always reports
  /// ``FileDescriptor/PollEvents/error``, ``FileDescriptor/PollEvents/hangUp``,
  /// and ``FileDescriptor/PollEvents/invalidDescriptor``, whether or not you
  /// ask for them.
  public typealias PollEvents = FileDescriptor.PollEvents

  /// A socket to poll, the events to poll it for,
  /// and the events that polling found.
  ///
  /// These are ``FileDescriptor/PollEntry``, so one poll can wait for sockets
  /// and other file descriptors together.
  public typealias PollEntry = FileDescriptor.PollEntry
}

@available(System 199, *)
extension FileDescriptor.PollEntry {
  /// Creates an entry that polls a socket for the given events.
  ///
  /// The entry doesn't take ownership of the socket.
  ///
  /// - Parameters:
  ///   - socket: The socket to poll.
  ///   - events: The events to poll for.
  ///     Polling reports ``FileDescriptor/PollEvents/error``,
  ///     ``FileDescriptor/PollEvents/hangUp``,
  ///     and ``FileDescriptor/PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  @_alwaysEmitIntoClient
  public init(_ socket: SocketDescriptor, events: FileDescriptor.PollEvents) {
    self.init(socket.fileDescriptor, events: events)
  }

  /// The socket to poll: the entry's file descriptor, as a socket.
  ///
  /// The corresponding C field is `fd`.
  @_alwaysEmitIntoClient
  public var socket: SocketDescriptor {
    get { SocketDescriptor(unchecked: fileDescriptor) }
    set { fileDescriptor = newValue.fileDescriptor }
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SocketDescriptor {
  /// Waits for any of a set of sockets, or other file descriptors,
  /// to be ready for I/O.
  ///
  /// This is ``FileDescriptor/poll(_:timeout:retryOnInterrupt:)``,
  /// under the name SystemWinSocks gives `WSAPoll` on Windows.
  ///
  /// - Parameters:
  ///   - entries: The sockets to poll,
  ///     each with the events to poll it for.
  ///     When this method returns,
  ///     each entry's ``FileDescriptor/PollEntry/returnedEvents``
  ///     are the events that polling found, if any.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until a socket is ready.
  ///     The default is `nil`.
  ///     A timeout of zero or less doesn't wait.
  ///     This method rounds a timeout up to a whole millisecond,
  ///     and waits no longer than about 24 days.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     A retried wait starts its timeout over.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The number of entries whose returned events aren't empty,
  ///   which is zero if the timeout expired.
  ///
  /// The corresponding C function is `poll`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func poll(
    _ entries: inout MutableSpan<PollEntry>,
    timeout: Duration? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try FileDescriptor.poll(&entries, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
  }

  /// Waits for this socket to be ready for I/O.
  ///
  /// - Parameters:
  ///   - events: The events to poll for.
  ///     Polling reports ``FileDescriptor/PollEvents/error``,
  ///     ``FileDescriptor/PollEvents/hangUp``,
  ///     and ``FileDescriptor/PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until the socket is ready.
  ///     A timeout of zero or less doesn't wait.
  ///     This method rounds a timeout up to a whole millisecond,
  ///     and waits no longer than about 24 days.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     A retried wait starts its timeout over.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The events that polling found,
  ///   which are empty if the timeout expired.
  ///
  /// The corresponding C function is `poll`.
  @_alwaysEmitIntoClient
  public func poll(
    for events: PollEvents,
    timeout: Duration?,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> PollEvents {
    try fileDescriptor.poll(for: events, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
  }
}

#endif // !os(Windows)
