/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned kernel event queue, on the pattern of OwnedFD.
// See Prototype/Events for the design.

// kqueue exists on Darwin, FreeBSD, and OpenBSD.
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

// Must import here to use the C timespec type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported Platform")
#endif

/// A kernel event queue, which reports events on file descriptors,
/// processes, signals, timers, and other sources that you register with it.
///
/// Register the events to watch for with ``register(_:)-(KernelEvent)``,
/// wait for them with ``poll(into:timeout:retryOnInterrupt:)``,
/// or do both in one call with
/// ``registerAndPoll(_:into:timeout:retryOnInterrupt:)``:
///
///     let queue = try KernelQueue()
///     try queue.register(KernelEvent(input, filter: .read, flags: .add))
///     let events = try [KernelEvent](unsafeUninitializedCapacity: 16) {
///       buffer, count in
///       var output = OutputSpan(buffer: buffer, initializedCount: 0)
///       try queue.poll(into: &output, timeout: .seconds(1))
///       count = output.finalize(for: buffer)
///     }
///
/// A queue owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does.
/// It doesn't own the file descriptors that it watches:
/// closing one of those removes its events from every queue.
///
/// A queue isn't inherited by a child process that `fork` creates.
/// On Darwin, its file descriptor is also closed when the process
/// executes a new program.
///
/// Registering and polling don't change the queue,
/// so several threads can use a queue at once:
/// for example, one thread can wait for events
/// while another triggers a user event to wake it.
@frozen
@available(System 199, *)
public struct KernelQueue: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates a kernel event queue.
  ///
  /// The corresponding C function is `kqueue`.
  @_alwaysEmitIntoClient
  public init() throws(Errno) {
    self._owner = OwnedFD(taking: try Self._create().get())
  }

  @usableFromInline
  internal static func _create() -> Result<FileDescriptor, Errno> {
    // kqueue can't be interrupted.
    valueOrErrno(retryOnInterrupt: false) {
      system_kqueue()
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that refers to a kernel queue.
  ///
  /// This initializer doesn't check that `descriptor` refers to a queue.
  /// The descriptor is closed at the end of the queue's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The queue's file descriptor, for operations that `KernelQueue`
  /// doesn't provide, such as registering it with another queue.
  ///
  /// A queue's file descriptor is readable when the queue has events
  /// to report.
  /// The returned value is valid only while this queue is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the queue.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the queue's file descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

// MARK: - Registering

@available(System 199, *)
extension KernelQueue {
  /// Changes one of the events that the queue watches for, without waiting.
  ///
  /// The change adds, updates, enables, disables, or deletes
  /// the queue's event with the same identifier and filter,
  /// as its ``KernelEvent/flags`` say.
  ///
  /// A signal can't interrupt this method,
  /// since the queue applies changes before it would wait.
  ///
  /// The corresponding C function is `kevent`, with an empty event list.
  @_alwaysEmitIntoClient
  public func register(_ change: KernelEvent) throws(Errno) {
    try withUnsafePointer(to: change) {
      _register(UnsafeBufferPointer(start: $0, count: 1))
    }.get()
  }

  @usableFromInline
  internal func _register(
    _ changes: UnsafeBufferPointer<KernelEvent>
  ) -> Result<(), Errno> {
    var noWait = timespec(tv_sec: 0, tv_nsec: 0)
    let result = _kevent(
      changes, UnsafeMutableBufferPointer(start: nil, count: 0), &noWait,
      retryOnInterrupt: false)
    switch result {
    case .success, .failure(.interrupted):
      // kevent applies every change before it checks for a signal,
      // so a call that a signal interrupted applied them all.
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  // Calls kevent, and returns the number of events it reported.
  @usableFromInline
  internal func _kevent(
    _ changes: UnsafeBufferPointer<KernelEvent>,
    _ events: UnsafeMutableBufferPointer<KernelEvent>,
    _ timeout: UnsafePointer<timespec>?,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    changes.withMemoryRebound(to: CInterop.KEvent.self) { changes in
      events.withMemoryRebound(to: CInterop.KEvent.self) { events in
        var changes = changes
        repeat {
          let count = system_kevent(
            _owner.fileDescriptor.rawValue,
            changes.baseAddress, CInt(changes.count),
            events.baseAddress, CInt(clamping: events.count),
            timeout)
          if count >= 0 { return .success(Int(count)) }
          let error = Errno.current
          guard retryOnInterrupt && error == .interrupted else {
            return .failure(error)
          }
          // kevent applies every change before it waits, so a call that
          // a signal interrupted applied them all. Retry without them.
          changes = UnsafeBufferPointer(start: nil, count: 0)
        } while true
      }
    }
  }
}

// MARK: - Registering with a span

// Span needs a newer OS than System 199 means in the default build,
// so this extension carries both.
@available(System 199, *)
@available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, visionOS 1.0, *)
extension KernelQueue {
  /// Changes the events that the queue watches for, without waiting.
  ///
  /// Each change adds, updates, enables, disables, or deletes
  /// the queue's event with the same identifier and filter,
  /// as its ``KernelEvent/flags`` say.
  ///
  /// The queue applies the changes in order.
  /// If one fails, this method throws its error:
  /// the changes before it stay applied,
  /// and the queue doesn't apply the changes after it.
  /// To apply every change and learn the result of each,
  /// include ``KernelEvent/Flags/receipt`` in each change's flags,
  /// and pass the changes to
  /// ``registerAndPoll(_:into:timeout:retryOnInterrupt:)``
  /// with room for a receipt for each one.
  ///
  /// A signal can't interrupt this method,
  /// since the queue applies changes before it would wait.
  ///
  /// The corresponding C function is `kevent`, with an empty event list.
  @_alwaysEmitIntoClient
  public func register(_ changes: Span<KernelEvent>) throws(Errno) {
    try changes.withUnsafeBufferPointer { _register($0) }.get()
  }
}

// MARK: - Polling

// Span and Duration need newer OSes than System 199 means in the default
// build, so this extension carries both.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension KernelQueue {

  /// Changes the events that the queue watches for,
  /// and then waits for events to report.
  ///
  /// - Parameters:
  ///   - changes: The changes to apply first, as for ``register(_:)-(Span<KernelEvent>)``.
  ///     A change that fails is reported in `events`
  ///     with its ``KernelEvent/registrationError``, if `events` has room,
  ///     and otherwise thrown, as `register` does.
  ///     Include ``KernelEvent/Flags/receipt`` in a change's flags
  ///     to report its result whether or not it fails.
  ///     If this method reports the result of a change,
  ///     it reports no other events.
  ///   - events: The span to append the reported events to.
  ///     The queue reports as many events as the span has room for,
  ///     and reports the rest to later calls.
  ///     If the span is full, this method applies the changes
  ///     and returns without waiting.
  ///   - timeout: The longest time to wait for an event,
  ///     or `nil` to wait until one arrives.
  ///     A timeout of zero or less doesn't wait.
  ///     A timeout longer than about three years waits about three years.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     A retried wait doesn't apply the changes again,
  ///     since the queue applies them before it waits,
  ///     and it starts its timeout over.
  ///     Pass `false` to throw ``Errno/interrupted`` instead,
  ///     after the queue has applied the changes.
  /// - Returns: The number of events that this call appended to `events`,
  ///   which is zero if the timeout expired.
  ///
  /// The corresponding C function is `kevent`.
  @_alwaysEmitIntoClient
  @_lifetime(events: copy events)
  @discardableResult
  public func registerAndPoll(
    _ changes: Span<KernelEvent>,
    into events: inout OutputSpan<KernelEvent>,
    timeout: Duration?,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try changes.withUnsafeBufferPointer { changes in
      events.withUnsafeMutableBufferPointer { buffer, initializedCount in
        let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
        let result = _poll(
          changes, into: free, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
        if case .success(let count) = result { initializedCount += count }
        return result
      }
    }.get()
  }

  @available(*, unavailable, renamed: "registerAndPoll(_:into:timeout:retryOnInterrupt:)")
  @_alwaysEmitIntoClient
  @_lifetime(events: copy events)
  public func kevent(
    registering changes: Span<KernelEvent>,
    into events: inout OutputSpan<KernelEvent>,
    timeout: Duration?,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try registerAndPoll(
      changes, into: &events, timeout: timeout, retryOnInterrupt: retryOnInterrupt)
  }

  /// Waits for events to report.
  ///
  /// - Parameters:
  ///   - events: The span to append the reported events to.
  ///     The queue reports as many events as the span has room for,
  ///     and reports the rest to later calls.
  ///     If the span is full, this method returns without waiting.
  ///   - timeout: The longest time to wait for an event,
  ///     or `nil` to wait until one arrives.
  ///     The default is `nil`.
  ///     A timeout of zero or less doesn't wait.
  ///     A timeout longer than about three years waits about three years.
  ///   - retryOnInterrupt: Whether to retry the wait
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     A retried wait starts its timeout over.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The number of events that this call appended to `events`,
  ///   which is zero if the timeout expired.
  ///
  /// The corresponding C function is `kevent`, with an empty change list.
  @_alwaysEmitIntoClient
  @discardableResult
  public func poll(
    into events: inout OutputSpan<KernelEvent>,
    timeout: Duration? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try events.withUnsafeMutableBufferPointer { buffer, initializedCount in
      let free = UnsafeMutableBufferPointer(rebasing: buffer[initializedCount...])
      let result = _poll(
        UnsafeBufferPointer(start: nil, count: 0), into: free,
        timeout: timeout, retryOnInterrupt: retryOnInterrupt)
      if case .success(let count) = result { initializedCount += count }
      return result
    }.get()
  }

  @_alwaysEmitIntoClient
  internal func _poll(
    _ changes: UnsafeBufferPointer<KernelEvent>,
    into events: UnsafeMutableBufferPointer<KernelEvent>,
    timeout: Duration?,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    guard let timeout else {
      return _kevent(changes, events, nil, retryOnInterrupt: retryOnInterrupt)
    }
    return withUnsafePointer(to: _timespec(timeout: timeout)) {
      _kevent(changes, events, $0, retryOnInterrupt: retryOnInterrupt)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
