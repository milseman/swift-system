/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned epoll instance, on the pattern of OwnedFD.
// See Prototype/Events for the design.

// epoll exists on Linux and Android.
#if os(Linux) || os(Android)

// Must import here to use the C epoll types in @_alwaysEmitIntoClient APIs.
// glibc's module doesn't include <sys/epoll.h>, so CSystem's header does.
import CSystem
#if canImport(Glibc)
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
  /// The C `epoll_event` type, which describes an event
  /// that an epoll instance watches for or reports.
  public typealias EPollEvent = epoll_event
}

/// An epoll instance, which reports when the file descriptors
/// that you add to it are ready for I/O.
///
/// Add each file descriptor to watch with ``add(_:events:data:)``,
/// and wait for events with ``wait(into:timeout:retryOnInterrupt:)``:
///
///     let epoll = try EventPoll(options: .closeOnExec)
///     try epoll.add(input, events: .readable, data: .fileDescriptor(input))
///     let events = try [EventPoll.Event](unsafeUninitializedCapacity: 16) {
///       buffer, count in
///       var output = OutputSpan(buffer: buffer, initializedCount: 0)
///       try epoll.wait(into: &output, timeout: .seconds(1))
///       count = output.finalize(for: buffer)
///     }
///
/// An instance owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does.
/// It doesn't own the file descriptors that it watches.
/// The kernel stops watching a file descriptor only when every descriptor
/// that refers to the same open file is closed,
/// so remove a descriptor that has duplicates,
/// such as from `dup` or in a child process, before closing it.
///
/// The kernel serializes adding, modifying, removing, and waiting,
/// and none of them mutates the `EventPoll` value,
/// so several threads can use an instance at once.
@frozen
@available(System 199, *)
public struct EventPoll: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates an epoll instance.
  ///
  /// - Parameter options: Options for the instance's file descriptor.
  ///   The default is none.
  ///
  /// The corresponding C function is `epoll_create1`.
  @_alwaysEmitIntoClient
  public init(options: Options = []) throws(Errno) {
    self._owner = OwnedFD(taking: try Self._create(options.rawValue).get())
  }

  @usableFromInline
  internal static func _create(_ flags: CInt) -> Result<FileDescriptor, Errno> {
    // epoll_create1 can't be interrupted.
    valueOrErrno(retryOnInterrupt: false) {
      system_epoll_create1(flags)
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that refers to an epoll instance.
  ///
  /// This initializer doesn't check that `descriptor` refers to an instance.
  /// The descriptor is closed at the end of the instance's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The instance's file descriptor, for operations that `EventPoll`
  /// doesn't provide, such as adding it to another instance.
  ///
  /// An instance's file descriptor is readable when it has events to report.
  /// The returned value is valid only while this instance is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the instance.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the instance's file descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

@available(System 199, *)
extension EventPoll {
  /// Options for an epoll instance's file descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Closes the instance's file descriptor
    /// when the process executes a new program.
    ///
    /// The corresponding C constant is `EPOLL_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: Options { Options(rawValue: _EPOLL_CLOEXEC) }
  }
}

// MARK: - Watching file descriptors

@available(System 199, *)
extension EventPoll {
  /// Starts watching a file descriptor for events.
  ///
  /// - Parameters:
  ///   - fileDescriptor: The file descriptor to watch.
  ///     The instance doesn't take ownership of it.
  ///     If the instance already watches it,
  ///     this method throws ``Errno/fileExists``;
  ///     to change its events, call ``modify(_:events:data:)``.
  ///   - events: The events to watch for,
  ///     and options such as ``Event/Mask/edgeTriggered``.
  ///     The instance reports ``Event/Mask/error``
  ///     and ``Event/Mask/hangUp`` whether or not they're included.
  ///   - data: The value that the instance reports with the events.
  ///
  /// The corresponding C function is `epoll_ctl`, with `EPOLL_CTL_ADD`.
  @_alwaysEmitIntoClient
  public func add(
    _ fileDescriptor: FileDescriptor, events: Event.Mask, data: Event.Data
  ) throws(Errno) {
    try _control(_EPOLL_CTL_ADD, fileDescriptor, Event(events: events, data: data)).get()
  }

  /// Changes the events that the instance watches a file descriptor for.
  ///
  /// - Parameters:
  ///   - fileDescriptor: A file descriptor that the instance watches.
  ///     If the instance doesn't watch it,
  ///     this method throws ``Errno/noSuchFileOrDirectory``.
  ///   - events: The events to watch for, in place of the current ones.
  ///   - data: The value to report with the events,
  ///     in place of the current one.
  ///
  /// The corresponding C function is `epoll_ctl`, with `EPOLL_CTL_MOD`.
  @_alwaysEmitIntoClient
  public func modify(
    _ fileDescriptor: FileDescriptor, events: Event.Mask, data: Event.Data
  ) throws(Errno) {
    try _control(_EPOLL_CTL_MOD, fileDescriptor, Event(events: events, data: data)).get()
  }

  /// Stops watching a file descriptor.
  ///
  /// If the instance doesn't watch `fileDescriptor`,
  /// this method throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `epoll_ctl`, with `EPOLL_CTL_DEL`.
  @_alwaysEmitIntoClient
  public func remove(_ fileDescriptor: FileDescriptor) throws(Errno) {
    // Kernels before 2.6.9 require an event, which they ignore.
    try _control(_EPOLL_CTL_DEL, fileDescriptor, Event(rawValue: CInterop.EPollEvent())).get()
  }

  @usableFromInline
  internal func _control(
    _ operation: CInt, _ fileDescriptor: FileDescriptor, _ event: Event
  ) -> Result<(), Errno> {
    var event = event.rawValue
    // epoll_ctl can't be interrupted.
    return nothingOrErrno(retryOnInterrupt: false) {
      system_epoll_ctl(
        _owner.fileDescriptor.rawValue, operation, fileDescriptor.rawValue, &event)
    }
  }
}

// MARK: - Waiting

@available(System 199, *)
extension EventPoll {
  /// Waits for events on the file descriptors that the instance watches.
  ///
  /// - Parameters:
  ///   - events: The span to append the reported events to.
  ///     The instance reports as many events as the span has room for,
  ///     and reports the rest to later calls.
  ///     If the span is full, this method throws ``Errno/invalidArgument``.
  ///   - timeout: The longest time to wait for an event,
  ///     or `nil` to wait until one arrives.
  ///     The default is `nil`.
  ///     A timeout of zero or less doesn't wait.
  ///     This method rounds a timeout up to a whole millisecond,
  ///     and waits no longer than about 24 days.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     A retried wait starts its timeout over.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The number of events that this call appended to `events`,
  ///   which is zero if the timeout expired.
  ///
  /// The corresponding C function is `epoll_wait`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func wait(
    into events: inout OutputSpan<Event>,
    timeout: Duration? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    let milliseconds = _milliseconds(timeout: timeout)
    return try events.withUnsafeMutableBufferPointer { buffer, initializedCount in
      let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
      let result = _wait(
        free, milliseconds: milliseconds, signalMask: nil,
        retryOnInterrupt: retryOnInterrupt)
      if case .success(let count) = result { initializedCount += count }
      return result
    }.get()
  }

  /// Waits for events on the file descriptors that the instance watches,
  /// with a different set of signals blocked.
  ///
  /// While it waits, this method replaces the thread's signal mask with
  /// `signalMask`, and it restores the thread's mask before it returns,
  /// in one step, so that no signal arrives between the two.
  /// For example, a thread that keeps a signal blocked can wait with a mask
  /// that unblocks it, so that only a wait can be interrupted by it.
  ///
  /// See ``wait(into:timeout:retryOnInterrupt:)`` for the other parameters.
  ///
  /// The corresponding C function is `epoll_pwait`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func wait(
    into events: inout OutputSpan<Event>,
    timeout: Duration? = nil,
    signalMask: CInterop.SignalSet,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    let milliseconds = _milliseconds(timeout: timeout)
    return try events.withUnsafeMutableBufferPointer { buffer, initializedCount in
      let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
      let result = withUnsafePointer(to: signalMask) {
        _wait(
          free, milliseconds: milliseconds, signalMask: $0,
          retryOnInterrupt: retryOnInterrupt)
      }
      if case .success(let count) = result { initializedCount += count }
      return result
    }.get()
  }

  @usableFromInline
  internal func _wait(
    _ events: UnsafeMutableBufferPointer<Event>,
    milliseconds: CInt,
    signalMask: UnsafePointer<CInterop.SignalSet>?,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    events.withMemoryRebound(to: CInterop.EPollEvent.self) { events in
      // A full span has no room, which the kernel rejects with EINVAL;
      // an empty one may have no address.
      guard let base = events.baseAddress, !events.isEmpty else {
        return .failure(.invalidArgument)
      }
      let count = CInt(clamping: events.count)
      return valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        if let signalMask {
          return system_epoll_pwait(
            _owner.fileDescriptor.rawValue, base, count, milliseconds, signalMask)
        }
        return system_epoll_wait(_owner.fileDescriptor.rawValue, base, count, milliseconds)
      }.map(Int.init)
    }
  }
}

// MARK: - Events

@available(System 199, *)
extension EventPoll {
  /// An event that an epoll instance watches for, or reports.
  ///
  /// The corresponding C type is `struct epoll_event`.
  @frozen
  public struct Event: RawRepresentable, @unchecked Sendable {
    // The data can hold a pointer, which the kernel passes back unchanged;
    // nothing here dereferences it, so it's safe to send.

    /// The raw C event.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.EPollEvent

    /// Creates a strongly-typed event from a raw C event.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.EPollEvent) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension EventPoll.Event {
  /// Creates an event.
  ///
  /// - Parameters:
  ///   - events: The events to watch for, and options such as
  ///     ``Mask/edgeTriggered``.
  ///   - data: The value that the instance reports with the events.
  @_alwaysEmitIntoClient
  public init(events: Mask, data: Data) {
    self.init(rawValue: CInterop.EPollEvent())
    self.events = events
    self.data = data
  }

  /// The events to watch for, or, in a reported event, the events that
  /// happened.
  ///
  /// The corresponding C field is `events`.
  @_alwaysEmitIntoClient
  public var events: Mask {
    get { Mask(rawValue: rawValue.events) }
    set { rawValue.events = newValue.rawValue }
  }

  /// The value that the instance reports with the events.
  ///
  /// The corresponding C field is `data`.
  @_alwaysEmitIntoClient
  public var data: Data {
    get { Data(rawValue: rawValue.data.u64) }
    set { rawValue.data.u64 = newValue.rawValue }
  }
}

@available(System 199, *)
extension EventPoll.Event: Hashable {
  /// Returns whether two events have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.events == rhs.events && lhs.data == rhs.data
  }

  /// Hashes the event's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(events)
    hasher.combine(data)
  }
}

@available(System 199, *)
extension EventPoll.Event {
  /// The events to watch a file descriptor for, and how to report them,
  /// or the events that happened.
  @frozen
  public struct Mask: OptionSet, Hashable, Sendable {
    /// The raw C events.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed set of events from raw C events.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// There's data to read,
    /// or a connection to accept, or the other end closed.
    ///
    /// The corresponding C constant is `EPOLLIN`.
    @_alwaysEmitIntoClient
    public static var readable: Mask { Mask(rawValue: _EPOLLIN) }

    /// Writing won't block.
    ///
    /// The corresponding C constant is `EPOLLOUT`.
    @_alwaysEmitIntoClient
    public static var writable: Mask { Mask(rawValue: _EPOLLOUT) }

    /// There's urgent data to read,
    /// such as a socket's out-of-band data.
    ///
    /// The corresponding C constant is `EPOLLPRI`.
    @_alwaysEmitIntoClient
    public static var priority: Mask { Mask(rawValue: _EPOLLPRI) }

    /// The other end of a stream socket closed, or shut down writing.
    ///
    /// The corresponding C constant is `EPOLLRDHUP`.
    @_alwaysEmitIntoClient
    public static var readHangUp: Mask { Mask(rawValue: _EPOLLRDHUP) }

    /// In a reported event, an error occurred on the file descriptor.
    ///
    /// An instance always reports this event,
    /// whether or not you include it.
    ///
    /// The corresponding C constant is `EPOLLERR`.
    @_alwaysEmitIntoClient
    public static var error: Mask { Mask(rawValue: _EPOLLERR) }

    /// In a reported event, the other end hung up,
    /// such as the other end of a pipe closing.
    ///
    /// An instance always reports this event,
    /// whether or not you include it.
    ///
    /// The corresponding C constant is `EPOLLHUP`.
    @_alwaysEmitIntoClient
    public static var hangUp: Mask { Mask(rawValue: _EPOLLHUP) }

    /// Reports each event once, when it happens,
    /// rather than for as long as the file descriptor stays ready.
    ///
    /// With this option, read or write until the call would block
    /// before waiting again.
    ///
    /// The corresponding C constant is `EPOLLET`.
    @_alwaysEmitIntoClient
    public static var edgeTriggered: Mask { Mask(rawValue: _EPOLLET) }

    /// Stops watching the file descriptor after reporting an event,
    /// until you modify it with new events.
    ///
    /// The corresponding C constant is `EPOLLONESHOT`.
    @_alwaysEmitIntoClient
    public static var oneShot: Mask { Mask(rawValue: _EPOLLONESHOT) }

    /// Keeps the system from suspending while an event is pending,
    /// until the next wait.
    ///
    /// The process needs the `CAP_BLOCK_SUSPEND` capability,
    /// or the instance ignores this option.
    ///
    /// The corresponding C constant is `EPOLLWAKEUP`.
    @_alwaysEmitIntoClient
    public static var wakeUp: Mask { Mask(rawValue: _EPOLLWAKEUP) }

    /// Wakes only one of the instances that watch the file descriptor
    /// with this option, rather than all of them.
    ///
    /// Use this option only when adding a file descriptor.
    ///
    /// The corresponding C constant is `EPOLLEXCLUSIVE`.
    @_alwaysEmitIntoClient
    public static var exclusive: Mask { Mask(rawValue: _EPOLLEXCLUSIVE) }
  }

  /// A value that an epoll instance reports unchanged
  /// with a file descriptor's events.
  ///
  /// The data holds 64 bits, which you can use for a file descriptor,
  /// a pointer, or a number that you choose, such as an index.
  ///
  /// The corresponding C type is `epoll_data_t`, a union.
  @frozen
  public struct Data: RawRepresentable, Hashable, Sendable {
    /// The data's 64 bits, as the C `u64` member holds them.
    @_alwaysEmitIntoClient
    public var rawValue: UInt64

    /// Creates data from 64 bits, as the C `u64` member holds them.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    /// Data that holds a file descriptor, as the C `fd` member does.
    @_alwaysEmitIntoClient
    public static func fileDescriptor(_ fileDescriptor: FileDescriptor) -> Data {
      // A union's members start at the same address, so on a big-endian
      // machine, `fd` is the high half of `u64`. Converting through the
      // union puts it where C code expects it.
      Data(rawValue: epoll_data(fd: fileDescriptor.rawValue).u64)
    }

    /// Data that holds a pointer, as the C `ptr` member does.
    @_alwaysEmitIntoClient
    public static func pointer(_ pointer: UnsafeMutableRawPointer?) -> Data {
      Data(rawValue: epoll_data(ptr: pointer).u64)
    }

    /// The data, as a file descriptor, as the C `fd` member holds it.
    @_alwaysEmitIntoClient
    public var fileDescriptor: FileDescriptor {
      FileDescriptor(rawValue: epoll_data(u64: rawValue).fd)
    }

    /// The data, as a pointer, as the C `ptr` member holds it.
    @_alwaysEmitIntoClient
    public var pointer: UnsafeMutableRawPointer? {
      epoll_data(u64: rawValue).ptr
    }
  }
}

// MARK: - Descriptions

@available(System 199, *)
extension EventPoll.Event: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the event.
  @inline(never)
  public var description: String {
    "EventPoll.Event(events: \(events), data: 0x\(String(data.rawValue, radix: 16)))"
  }

  /// A textual representation of the event, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension EventPoll.Event.Mask: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the events.
  @inline(never)
  public var description: String {
    let descriptions: [(Element, StaticString)] = [
      (.readable, ".readable"),
      (.writable, ".writable"),
      (.priority, ".priority"),
      (.readHangUp, ".readHangUp"),
      (.error, ".error"),
      (.hangUp, ".hangUp"),
      (.edgeTriggered, ".edgeTriggered"),
      (.oneShot, ".oneShot"),
      (.wakeUp, ".wakeUp"),
      (.exclusive, ".exclusive"),
    ]
    return _buildDescription(descriptions)
  }

  /// A textual representation of the events, suitable for debugging.
  public var debugDescription: String { self.description }
}
#endif // os(Linux) || os(Android)
