/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// WSAPoll, Winsock's poll, which polls sockets alone. SystemPackage's poll,
// on other platforms, is FileDescriptor's; this one has its names on
// SocketDescriptor, since a Winsock socket isn't a file descriptor.

@available(System 199, *)
extension CInterop {
  /// The C `WSAPOLLFD` type, which describes a socket to poll.
  ///
  /// The corresponding C type is `WSAPOLLFD`.
  public typealias PollFD = WSAPOLLFD
}

@available(System 199, *)
extension SocketDescriptor {
  /// The events to poll a socket for, or that polling found.
  ///
  /// Polling always reports ``error``, ``hangUp``,
  /// and ``invalidDescriptor``, whether or not you ask for them.
  /// Winsock has no counterpart of POSIX's `POLLPRI`, which its own provider
  /// rejects.
  @frozen
  public struct PollEvents: OptionSet, Hashable, Sendable {
    /// The raw C events.
    @_alwaysEmitIntoClient
    public var rawValue: CShort

    /// Creates a strongly-typed set of events from raw C events.
    @_alwaysEmitIntoClient
    public init(rawValue: CShort) { self.rawValue = rawValue }

    /// There's data to read, or a connection to accept, or the other end
    /// closed: both normal and priority data.
    ///
    /// The corresponding C constant is `POLLIN`.
    @_alwaysEmitIntoClient
    public static var readable: PollEvents { PollEvents(rawValue: 0x0300) }

    /// Writing won't block.
    ///
    /// The corresponding C constant is `POLLOUT`.
    @_alwaysEmitIntoClient
    public static var writable: PollEvents { PollEvents(rawValue: 0x0010) }

    /// There's data other than priority data to read.
    ///
    /// The corresponding C constant is `POLLRDNORM`.
    @_alwaysEmitIntoClient
    public static var readableNormalData: PollEvents { PollEvents(rawValue: 0x0100) }

    /// There's priority data to read: out-of-band data.
    ///
    /// The corresponding C constant is `POLLRDBAND`.
    @_alwaysEmitIntoClient
    public static var readablePriorityData: PollEvents { PollEvents(rawValue: 0x0200) }

    /// Writing data other than priority data won't block.
    ///
    /// The corresponding C constant is `POLLWRNORM`.
    @_alwaysEmitIntoClient
    public static var writableNormalData: PollEvents { PollEvents(rawValue: 0x0010) }

    /// Writing priority data won't block.
    ///
    /// The corresponding C constant is `POLLWRBAND`.
    @_alwaysEmitIntoClient
    public static var writablePriorityData: PollEvents { PollEvents(rawValue: 0x0020) }

    /// In returned events, an error occurred on the socket.
    ///
    /// The corresponding C constant is `POLLERR`.
    @_alwaysEmitIntoClient
    public static var error: PollEvents { PollEvents(rawValue: 0x0001) }

    /// In returned events, a stream's connection was closed or reset.
    ///
    /// Data can remain to read after the other end hangs up.
    ///
    /// The corresponding C constant is `POLLHUP`.
    @_alwaysEmitIntoClient
    public static var hangUp: PollEvents { PollEvents(rawValue: 0x0002) }

    /// In returned events, the socket isn't one.
    ///
    /// The corresponding C constant is `POLLNVAL`.
    @_alwaysEmitIntoClient
    public static var invalidDescriptor: PollEvents { PollEvents(rawValue: 0x0004) }
  }

  /// A socket to poll, the events to poll it for,
  /// and the events that polling found.
  ///
  /// The corresponding C type is `WSAPOLLFD`.
  @frozen
  public struct PollEntry: RawRepresentable, Sendable {
    /// The raw C entry.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.PollFD

    /// Creates a strongly-typed entry from a raw C entry.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.PollFD) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension SocketDescriptor.PollEntry {
  /// Creates an entry that polls a socket for the given events.
  ///
  /// The entry doesn't take ownership of the socket.
  ///
  /// - Parameters:
  ///   - socket: The socket to poll.
  ///     Polling skips an entry whose socket is `INVALID_SOCKET`.
  ///   - events: The events to poll for.
  ///     Polling reports ``SocketDescriptor/PollEvents/error``,
  ///     ``SocketDescriptor/PollEvents/hangUp``,
  ///     and ``SocketDescriptor/PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  @_alwaysEmitIntoClient
  public init(_ socket: SocketDescriptor, events: SocketDescriptor.PollEvents) {
    self.init(rawValue: CInterop.PollFD(fd: socket.rawValue, events: events.rawValue, revents: 0))
  }

  /// The socket to poll.
  ///
  /// The corresponding C field is `fd`.
  @_alwaysEmitIntoClient
  public var socket: SocketDescriptor {
    get { SocketDescriptor(rawValue: rawValue.fd) }
    set { rawValue.fd = newValue.rawValue }
  }

  /// The events to poll the socket for.
  ///
  /// The corresponding C field is `events`.
  @_alwaysEmitIntoClient
  public var events: SocketDescriptor.PollEvents {
    get { SocketDescriptor.PollEvents(rawValue: rawValue.events) }
    set { rawValue.events = newValue.rawValue }
  }

  /// The events that polling found, which are empty until you poll.
  ///
  /// The corresponding C field is `revents`.
  @_alwaysEmitIntoClient
  public var returnedEvents: SocketDescriptor.PollEvents {
    get { SocketDescriptor.PollEvents(rawValue: rawValue.revents) }
    set { rawValue.revents = newValue.rawValue }
  }
}

@available(System 199, *)
extension SocketDescriptor.PollEntry: Hashable {
  /// Returns whether two entries have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue.fd == rhs.rawValue.fd && lhs.rawValue.events == rhs.rawValue.events
      && lhs.rawValue.revents == rhs.rawValue.revents
  }

  /// Hashes the entry's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.fd)
    hasher.combine(rawValue.events)
    hasher.combine(rawValue.revents)
  }
}

@available(System 199, *)
extension SocketDescriptor.PollEvents: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the events.
  public var description: String {
    // readable and writable are unions of the others, so they come first.
    _buildDescription([
      (.readable, ".readable"),
      (.writable, ".writable"),
      (.readableNormalData, ".readableNormalData"),
      (.readablePriorityData, ".readablePriorityData"),
      (.writablePriorityData, ".writablePriorityData"),
      (.error, ".error"),
      (.hangUp, ".hangUp"),
      (.invalidDescriptor, ".invalidDescriptor"),
    ])
  }

  /// A textual representation of the events, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension SocketDescriptor.PollEntry: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the entry.
  @inline(never)
  public var description: String {
    "PollEntry(socket: \(socket.rawValue), events: \(events), "
      + "returnedEvents: \(returnedEvents))"
  }

  /// A textual representation of the entry, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Waits for any of a set of sockets to be ready for I/O.
  ///
  /// - Parameters:
  ///   - entries: The sockets to poll,
  ///     each with the events to poll it for.
  ///     When this method returns,
  ///     each entry's ``PollEntry/returnedEvents``
  ///     are the events that polling found, if any.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until a socket is ready.
  ///     The default is `nil`.
  ///     A timeout of zero or less doesn't wait.
  ///     This method rounds a timeout up to a whole millisecond,
  ///     and waits no longer than about 24 days.
  ///   - retryOnInterrupt: Whether to retry the wait if it's interrupted,
  ///     which Winsock 2 doesn't do. The default is `true`.
  /// - Returns: The number of entries whose returned events aren't empty,
  ///   which is zero if the timeout expired.
  ///
  /// Before Windows 10 version 2004, `WSAPoll` didn't report a nonblocking
  /// connect that failed: it waited out its timeout instead.
  ///
  /// The corresponding C function is `WSAPoll`, Winsock's `poll`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func poll(
    _ entries: inout MutableSpan<PollEntry>,
    timeout: Duration? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> Int {
    let milliseconds = _pollMilliseconds(timeout: timeout)
    return try entries.withUnsafeMutableBufferPointer {
      _poll($0, milliseconds: milliseconds, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Waits for this socket to be ready for I/O.
  ///
  /// - Parameters:
  ///   - events: The events to poll for.
  ///     Polling reports ``PollEvents/error``, ``PollEvents/hangUp``,
  ///     and ``PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until the socket is ready.
  ///     A timeout of zero or less doesn't wait.
  ///     This method rounds a timeout up to a whole millisecond,
  ///     and waits no longer than about 24 days.
  ///   - retryOnInterrupt: Whether to retry the wait if it's interrupted,
  ///     which Winsock 2 doesn't do. The default is `true`.
  /// - Returns: The events that polling found,
  ///   which are empty if the timeout expired.
  ///
  /// The corresponding C function is `WSAPoll`.
  @_alwaysEmitIntoClient
  public func poll(
    for events: PollEvents,
    timeout: Duration?,
    retryOnInterrupt: Bool = true
  ) throws(Win32.Error) -> PollEvents {
    var entry = PollEntry(self, events: events)
    let milliseconds = SocketDescriptor._pollMilliseconds(timeout: timeout)
    _ = try withUnsafeMutablePointer(to: &entry) {
      SocketDescriptor._poll(
        UnsafeMutableBufferPointer(start: $0, count: 1),
        milliseconds: milliseconds, retryOnInterrupt: retryOnInterrupt)
    }.get()
    return entry.returnedEvents
  }

  @usableFromInline
  internal static func _poll(
    _ entries: UnsafeMutableBufferPointer<PollEntry>,
    milliseconds: CInt,
    retryOnInterrupt: Bool
  ) -> Result<Int, Win32.Error> {
    guard let count = ULONG(exactly: entries.count) else { return .failure(.invalidArgument) }
    return entries.withMemoryRebound(to: CInterop.PollFD.self) { entries in
      valueOrWinsockError(retryOnInterrupt: retryOnInterrupt) {
        system_WSAPoll(entries.baseAddress, count, milliseconds)
      }.map(Int.init)
    }
  }

  /// A time-out for `WSAPoll`: -1 for none, 0 for a time of zero or less,
  /// otherwise rounded up to a millisecond, at most `Int32.max`.
  @usableFromInline
  internal static func _pollMilliseconds(timeout: Duration?) -> CInt {
    guard let timeout else { return -1 }
    guard timeout > .zero else { return 0 }
    // A positive duration's components are both nonnegative.
    let (seconds, attoseconds) = timeout.components
    var milliseconds = attoseconds / 1_000_000_000_000_000
    if attoseconds % 1_000_000_000_000_000 > 0 { milliseconds += 1 }
    let (scaled, overflow) = seconds.multipliedReportingOverflow(by: 1000)
    let (total, totalOverflow) = scaled.addingReportingOverflow(milliseconds)
    return overflow || totalOverflow ? CInt.max : CInt(clamping: total)
  }
}

#endif // os(Windows)
