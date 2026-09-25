/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring a typed pthread layer. Not API. See Prototype/Threads
// for the design and Sources/Samples/Threads*.swift for uses.

#if !os(Windows) && !os(WASI)

/// A thread of execution that the caller owns, and must join or detach.
///
/// Creating a `PThread` starts a new thread running a closure:
///
///     let worker = try PThread {
///       process(batch)
///     }
///     try worker.join()
///
/// `PThread` can't be copied. Its owner either waits for the thread to
/// finish, by calling ``join()``, or lets it finish on its own, by calling
/// ``detach()``. To identify the thread without owning it, use its ``id``.
///
/// Destroying a `PThread` that hasn't been joined or detached joins it:
/// the destruction waits for the thread to finish, so a thread started in a
/// scope finishes before the scope ends, even when an error ends it early.
/// Destroying a `PThread` on its own thread, which can't wait for itself,
/// detaches it instead. Whether destruction should join, detach, or trap is
/// an open question, the same one as `OwnedFD`'s close policy;
/// see Prototype/ThreadDeinit.
///
/// The corresponding C type is `pthread_t`, created with `pthread_create`.
@available(System 199, *)
@frozen
public struct PThread: ~Copyable, Sendable {
  @usableFromInline
  internal let _id: ID

  /// Creates a thread that runs a closure.
  ///
  /// - Parameters:
  ///   - attributes: Options for the new thread,
  ///     such as the size of its stack.
  ///     The default options use the system's defaults.
  ///   - body: The closure for the new thread to run.
  ///     The thread finishes when the closure returns.
  ///
  /// The closure is sent to the new thread,
  /// so it can capture values that aren't `Sendable`,
  /// as long as the caller doesn't use them afterward.
  ///
  /// The corresponding C function is `pthread_create`.
  @_alwaysEmitIntoClient
  public init(
    attributes: Attributes = Attributes(),
    _ body: sending @escaping () -> Void
  ) throws(Errno) {
    self._id = try PThread._create(attributes: attributes, body).get()
  }

  /// Takes ownership of a joinable thread.
  ///
  /// The thread must not have been joined or detached,
  /// and nothing else may join or detach it.
  @_alwaysEmitIntoClient
  public init(taking id: ID) {
    self._id = id
  }

  deinit {
    PThread._destroy(_id)
  }
}

@available(System 199, *)
extension PThread {
  /// The identifier of the thread.
  ///
  /// The identifier is valid until the thread is joined,
  /// or, for a detached thread, until it finishes.
  /// After that, the system can reuse it for another thread.
  @_alwaysEmitIntoClient
  public var id: ID { _id }

  /// Waits for the thread to finish.
  ///
  /// When this method returns, the thread has finished,
  /// and the system has released its resources.
  /// If the calling thread is the thread itself,
  /// which can't wait for itself,
  /// this method detaches the thread instead,
  /// so that its resources are released when it finishes,
  /// and throws ``Errno/deadlock``.
  ///
  /// The corresponding C function is `pthread_join`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Joining blocks the calling thread")
  public consuming func join() throws(Errno) {
    let id = _id
    discard self
    try PThread._join(id).get()
  }

  /// Lets the thread finish on its own.
  ///
  /// The system releases the thread's resources when it finishes.
  /// After this call, the thread's ``id`` is valid only until it finishes.
  ///
  /// The corresponding C function is `pthread_detach`.
  @_alwaysEmitIntoClient
  public consuming func detach() throws(Errno) {
    let id = _id
    discard self
    try PThread._detach(id).get()
  }

  /// Transfers ownership of the thread to the caller,
  /// without joining or detaching it.
  ///
  /// After this method returns,
  /// the caller is responsible for joining or detaching the thread.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> ID {
    let id = _id
    discard self
    return id
  }
}

// MARK: - Calling thread

@available(System 199, *)
extension PThread {
  /// Offers the processor to other threads.
  ///
  /// The calling thread goes to the end of the queue of threads
  /// waiting to run at its priority.
  ///
  /// The corresponding C function is `sched_yield`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task.yield(), or await a condition instead of spinning")
  public static func yield() {
    _yield()
  }

  @usableFromInline
  internal static func _yield() {
    // sched_yield can't fail on the platforms System supports.
    _ = system_sched_yield()
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// Whether the calling thread is the process's main thread.
  ///
  /// The corresponding C function is `pthread_main_np`.
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var isMainThread: Bool { _isMainThread() }

  @usableFromInline
  internal static func _isMainThread() -> Bool {
    // FreeBSD returns -1 if the threads library isn't initialized yet.
    system_pthread_main_np() == 1
  }
  #endif
}

// MARK: - Implementation

@available(System 199, *)
extension PThread {
  @usableFromInline
  internal static func _create(
    attributes: Attributes, _ body: sending @escaping () -> Void
  ) -> Result<ID, Errno> {
    let context = Unmanaged.passRetained(_PThreadStart(body)).toOpaque()
    var thread = _pthreadCreateZero
    let result = attributes._withUnsafeAttributes { attributes in
      nothingOrReturnedErrno(retryOnInterrupt: false) {
        system_pthread_create(&thread, attributes, context)
      }
    }
    if case .failure(let error) = result {
      // The thread didn't start, so nothing else will release the closure.
      _pthreadDiscardContext(context)
      return .failure(error)
    }
    return .success(ID(rawValue: _pthreadCreated(thread)))
  }

  @usableFromInline
  internal static func _join(_ id: ID) -> Result<(), Errno> {
    // Not every C library detects a thread joining itself: Musl waits
    // forever.
    guard id != .current else {
      _ = system_pthread_detach(id.rawValue)
      return .failure(.deadlock)
    }
    let result = nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_join(id.rawValue)
    }
    if case .failure(.deadlock) = result {
      // glibc also reports two threads joining each other. The thread is
      // still running, and nothing else will join it.
      _ = system_pthread_detach(id.rawValue)
    }
    return result
  }

  @usableFromInline
  internal static func _detach(_ id: ID) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_detach(id.rawValue)
    }
  }

  // Called by the deinit, which can't throw, so errors are dropped. They
  // mean that something else joined or detached the thread through its ID.
  internal static func _destroy(_ id: ID) {
    _ = _join(id)
  }
}

// The closure that a new thread runs, passed to it through `pthread_create`'s
// argument.
internal final class _PThreadStart {
  internal let body: () -> Void

  internal init(_ body: @escaping () -> Void) {
    self.body = body
  }
}

// The body of every thread that `PThread` starts; see system_pthread_create.
internal func _pthreadStart(_ context: UnsafeMutableRawPointer?) {
  let start = Unmanaged<_PThreadStart>.fromOpaque(context!).takeRetainedValue()
  start.body()
}

// Releases the closure of a thread that didn't start.
internal func _pthreadDiscardContext(_ context: UnsafeMutableRawPointer) {
  Unmanaged<_PThreadStart>.fromOpaque(context).release()
}

#endif // !os(Windows) && !os(WASI)
