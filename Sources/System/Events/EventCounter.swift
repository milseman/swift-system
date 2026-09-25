/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned eventfd, on the pattern of OwnedFD.
// See Prototype/Events for the design.

// eventfd exists on Linux and Android.
#if os(Linux) || os(Android)

/// A counter in the kernel that a file descriptor reads and adds to,
/// such as to wake a thread that waits for the descriptor.
///
/// Adding to a counter that's zero makes its file descriptor readable,
/// so an ``EventPoll`` that watches it reports an event,
/// and reading the counter resets it:
///
///     let wakeUp = try EventCounter(options: [.closeOnExec, .nonBlocking])
///     try epoll.add(
///       wakeUp.fileDescriptor, events: .readable,
///       data: .fileDescriptor(wakeUp.fileDescriptor))
///     // On another thread:
///     try wakeUp.increment()
///     // On the waiting thread, after the event:
///     _ = try wakeUp.read()
///
/// A counter owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does.
///
/// The corresponding C function is `eventfd`.
@frozen
@available(System 199, *)
public struct EventCounter: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates an event counter.
  ///
  /// - Parameters:
  ///   - initialValue: The counter's value to start with.
  ///     The default is `0`.
  ///   - options: Options for the counter and its file descriptor.
  ///     The default is none.
  ///
  /// The corresponding C function is `eventfd`.
  @_alwaysEmitIntoClient
  public init(initialValue: UInt32 = 0, options: Options = []) throws(Errno) {
    self._owner = OwnedFD(
      taking: try Self._create(initialValue, options.rawValue).get())
  }

  @usableFromInline
  internal static func _create(
    _ initialValue: UInt32, _ flags: CInt
  ) -> Result<FileDescriptor, Errno> {
    // eventfd can't be interrupted.
    valueOrErrno(retryOnInterrupt: false) {
      system_eventfd(initialValue, flags)
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that refers to an event counter.
  ///
  /// This initializer doesn't check that `descriptor` refers to a counter.
  /// The descriptor is closed at the end of the counter's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The counter's file descriptor, for operations that `EventCounter`
  /// doesn't provide, such as watching it with an ``EventPoll``.
  ///
  /// The returned value is valid only while this counter is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the counter.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the counter's file descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

@available(System 199, *)
extension EventCounter {
  /// Options for an event counter and its file descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Closes the counter's file descriptor
    /// when the process executes a new program.
    ///
    /// The corresponding C constant is `EFD_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: Options { Options(rawValue: _EFD_CLOEXEC) }

    /// Makes reading a counter that's zero, or adding more than it can hold,
    /// throw ``Errno/resourceTemporarilyUnavailable`` rather than wait.
    ///
    /// The corresponding C constant is `EFD_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: Options { Options(rawValue: _EFD_NONBLOCK) }

    /// Makes each read return one and subtract one,
    /// rather than return the whole count and reset it,
    /// so that the counter works as a semaphore.
    ///
    /// The corresponding C constant is `EFD_SEMAPHORE`.
    @_alwaysEmitIntoClient
    public static var semaphore: Options { Options(rawValue: _EFD_SEMAPHORE) }
  }
}

@available(System 199, *)
extension EventCounter {
  /// Adds to the counter, which makes its file descriptor readable.
  ///
  /// A counter holds at most `UInt64.max - 1`.
  /// If adding `value` would exceed that, this method waits for a read to
  /// make room, or, with the ``Options/nonBlocking`` option,
  /// throws ``Errno/resourceTemporarilyUnavailable``.
  ///
  /// - Parameters:
  ///   - value: The number to add, which must be less than `UInt64.max`.
  ///     The default is `1`.
  ///   - retryOnInterrupt: Whether to retry the write
  ///     if a signal interrupts it.
  ///     The default is `true`.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `write`, with the 8 bytes of `value`.
  @_alwaysEmitIntoClient
  public func increment(by value: UInt64 = 1, retryOnInterrupt: Bool = true) throws(Errno) {
    _ = try withUnsafeBytes(of: value) {
      _owner.fileDescriptor._write($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Reads the counter, and resets it to zero.
  ///
  /// If the counter is zero, this method waits for it to be incremented,
  /// or, with the ``Options/nonBlocking`` option,
  /// throws ``Errno/resourceTemporarilyUnavailable``.
  /// With the ``Options/semaphore`` option,
  /// this method returns one, and subtracts one from the counter.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the read
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The counter's value before the read,
  ///   or one, with the `semaphore` option.
  ///
  /// The corresponding C function is `read`, of 8 bytes.
  @_alwaysEmitIntoClient
  public func read(retryOnInterrupt: Bool = true) throws(Errno) -> UInt64 {
    var value: UInt64 = 0
    _ = try withUnsafeMutableBytes(of: &value) {
      _owner.fileDescriptor._read(into: $0, retryOnInterrupt: retryOnInterrupt)
    }.get()
    return value
  }
}
#endif // os(Linux) || os(Android)
