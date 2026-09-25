/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// Must import here to use the C pollfd type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// The C `pollfd` type, which describes a file descriptor to poll.
  public typealias PollFD = pollfd
}

@available(System 199, *)
extension FileDescriptor {
  /// The events to poll a file descriptor for, or that polling found.
  ///
  /// Polling always reports ``error``, ``hangUp``,
  /// and ``invalidDescriptor``, whether or not you ask for them.
  @frozen
  public struct PollEvents: OptionSet, Hashable, Sendable {
    /// The raw C events.
    @_alwaysEmitIntoClient
    public var rawValue: CShort

    /// Creates a strongly-typed set of events from raw C events.
    @_alwaysEmitIntoClient
    public init(rawValue: CShort) { self.rawValue = rawValue }

    /// There's data to read,
    /// or a connection to accept, or the other end closed.
    ///
    /// The corresponding C constant is `POLLIN`.
    @_alwaysEmitIntoClient
    public static var readable: PollEvents { PollEvents(rawValue: _POLLIN) }

    /// There's urgent data to read,
    /// such as a socket's out-of-band data.
    ///
    /// The corresponding C constant is `POLLPRI`.
    @_alwaysEmitIntoClient
    public static var priority: PollEvents { PollEvents(rawValue: _POLLPRI) }

    /// Writing won't block.
    ///
    /// The corresponding C constant is `POLLOUT`.
    @_alwaysEmitIntoClient
    public static var writable: PollEvents { PollEvents(rawValue: _POLLOUT) }

    /// There's data other than priority data to read.
    ///
    /// The corresponding C constant is `POLLRDNORM`.
    @_alwaysEmitIntoClient
    public static var readableNormalData: PollEvents { PollEvents(rawValue: _POLLRDNORM) }

    /// There's priority data to read.
    ///
    /// The corresponding C constant is `POLLRDBAND`.
    @_alwaysEmitIntoClient
    public static var readablePriorityData: PollEvents { PollEvents(rawValue: _POLLRDBAND) }

    /// Writing data other than priority data won't block.
    ///
    /// The corresponding C constant is `POLLWRNORM`.
    @_alwaysEmitIntoClient
    public static var writableNormalData: PollEvents { PollEvents(rawValue: _POLLWRNORM) }

    /// Writing priority data won't block.
    ///
    /// The corresponding C constant is `POLLWRBAND`.
    @_alwaysEmitIntoClient
    public static var writablePriorityData: PollEvents { PollEvents(rawValue: _POLLWRBAND) }

    #if os(Linux) || os(Android)
    /// The other end of a stream socket closed, or shut down writing.
    ///
    /// The corresponding C constant is `POLLRDHUP`.
    ///
    /// - Note: Only available on Linux and Android.
    @_alwaysEmitIntoClient
    public static var readHangUp: PollEvents { PollEvents(rawValue: _POLLRDHUP) }
    #endif

    /// In returned events, an error occurred on the file descriptor.
    ///
    /// The corresponding C constant is `POLLERR`.
    @_alwaysEmitIntoClient
    public static var error: PollEvents { PollEvents(rawValue: _POLLERR) }

    /// In returned events, the other end hung up,
    /// such as the other end of a pipe closing.
    ///
    /// Data can remain to read after the other end hangs up.
    ///
    /// The corresponding C constant is `POLLHUP`.
    @_alwaysEmitIntoClient
    public static var hangUp: PollEvents { PollEvents(rawValue: _POLLHUP) }

    /// In returned events, the file descriptor isn't open.
    ///
    /// The corresponding C constant is `POLLNVAL`.
    @_alwaysEmitIntoClient
    public static var invalidDescriptor: PollEvents { PollEvents(rawValue: _POLLNVAL) }
  }

  /// A file descriptor to poll, the events to poll it for,
  /// and the events that polling found.
  ///
  /// The corresponding C type is `struct pollfd`.
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
extension FileDescriptor.PollEntry {
  /// Creates an entry that polls a file descriptor for the given events.
  ///
  /// The entry doesn't take ownership of the file descriptor.
  ///
  /// - Parameters:
  ///   - fileDescriptor: The file descriptor to poll.
  ///     Polling skips an entry with a negative file descriptor.
  ///   - events: The events to poll for.
  ///     Polling reports ``FileDescriptor/PollEvents/error``,
  ///     ``FileDescriptor/PollEvents/hangUp``,
  ///     and ``FileDescriptor/PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  @_alwaysEmitIntoClient
  public init(_ fileDescriptor: FileDescriptor, events: FileDescriptor.PollEvents) {
    self.init(rawValue: CInterop.PollFD(
      fd: fileDescriptor.rawValue, events: events.rawValue, revents: 0))
  }

  /// The file descriptor to poll.
  ///
  /// The corresponding C field is `fd`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor {
    get { FileDescriptor(rawValue: rawValue.fd) }
    set { rawValue.fd = newValue.rawValue }
  }

  /// The events to poll the file descriptor for.
  ///
  /// The corresponding C field is `events`.
  @_alwaysEmitIntoClient
  public var events: FileDescriptor.PollEvents {
    get { FileDescriptor.PollEvents(rawValue: rawValue.events) }
    set { rawValue.events = newValue.rawValue }
  }

  /// The events that polling found, which are empty until you poll.
  ///
  /// The corresponding C field is `revents`.
  @_alwaysEmitIntoClient
  public var returnedEvents: FileDescriptor.PollEvents {
    get { FileDescriptor.PollEvents(rawValue: rawValue.revents) }
    set { rawValue.revents = newValue.rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.PollEntry: Hashable {
  /// Returns whether two entries have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.fileDescriptor == rhs.fileDescriptor
      && lhs.events == rhs.events
      && lhs.returnedEvents == rhs.returnedEvents
  }

  /// Hashes the entry's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(fileDescriptor)
    hasher.combine(events)
    hasher.combine(returnedEvents)
  }
}

// Duration and MutableSpan need newer OSes than System 199 means in the
// default build, so each member carries both.
extension FileDescriptor {
  /// Waits for any of a set of file descriptors to be ready for I/O.
  ///
  /// - Parameters:
  ///   - entries: The file descriptors to poll,
  ///     each with the events to poll it for.
  ///     When this method returns,
  ///     each entry's ``PollEntry/returnedEvents``
  ///     are the events that polling found, if any.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until a file descriptor is ready.
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
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @_alwaysEmitIntoClient
  @discardableResult
  public static func poll(
    _ entries: inout MutableSpan<PollEntry>,
    timeout: Duration? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    let milliseconds = _milliseconds(timeout: timeout)
    return try entries.withUnsafeMutableBufferPointer {
      _poll($0, milliseconds: milliseconds, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Waits for this file descriptor to be ready for I/O.
  ///
  /// - Parameters:
  ///   - events: The events to poll for.
  ///     Polling reports ``PollEvents/error``, ``PollEvents/hangUp``,
  ///     and ``PollEvents/invalidDescriptor``
  ///     whether or not they're included.
  ///   - timeout: The longest time to wait,
  ///     or `nil` to wait until the file descriptor is ready.
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
  @available(System 199, *)
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @_alwaysEmitIntoClient
  public func poll(
    for events: PollEvents,
    timeout: Duration?,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> PollEvents {
    var entry = PollEntry(self, events: events)
    let milliseconds = _milliseconds(timeout: timeout)
    _ = try withUnsafeMutablePointer(to: &entry) {
      FileDescriptor._poll(
        UnsafeMutableBufferPointer(start: $0, count: 1),
        milliseconds: milliseconds, retryOnInterrupt: retryOnInterrupt)
    }.get()
    return entry.returnedEvents
  }

  @available(System 199, *)
  @usableFromInline
  internal static func _poll(
    _ entries: UnsafeMutableBufferPointer<PollEntry>,
    milliseconds: CInt,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    entries.withMemoryRebound(to: CInterop.PollFD.self) { entries in
      valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_poll(entries.baseAddress, entries.count, milliseconds)
      }.map(Int.init)
    }
  }
}
#endif // !os(Windows) && !os(WASI)
