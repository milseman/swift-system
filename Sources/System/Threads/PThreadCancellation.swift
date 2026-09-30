/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: thread cancellation, deferred only. Another thread asks with
// `PThread.ID.cancel()`, on the ID as the other operations on any thread
// are; the thread ends at its next cancellation point, as `PThread.exit()`
// ends it. The calling thread's side is `PThread.testCancellation()` and
// `PThread.withCancellationDisabled(_:)`, a scope that restores the state
// however its body ends.
//
// Rejected: asynchronous cancellation (PTHREAD_CANCEL_ASYNCHRONOUS), since
// no Swift code is async-cancel-safe: the runtime allocates and retains
// anywhere; a bare enable/disable toggle, which code can forget to restore;
// and a method on the owner, since swift-distributed-actors cancels a
// detached thread, which has none. Open: a join can't tell a cancelled
// thread from one that returned, since System's joins return nothing.
// Android's Bionic has no thread cancellation.

#if !os(Windows) && !os(WASI) && !os(Android)

@available(System 199, *)
extension PThread.ID {
  /// Asks the thread to end at its next cancellation point.
  ///
  /// The thread ends when it next reaches a cancellation point
  /// with its cancellation enabled:
  /// a call to ``PThread/testCancellation()``,
  /// or to one of the C functions that POSIX makes cancellation points,
  /// which include most calls that can block,
  /// such as reads and writes, waits and sleeps, `open` and `close`,
  /// and joining a thread.
  /// System's wrappers of those functions are cancellation points too.
  /// Until the thread reaches one,
  /// and while it runs code in ``PThread/withCancellationDisabled(_:)``,
  /// the request stays pending.
  ///
  /// This method doesn't wait for the thread to end:
  /// join the thread to wait for it.
  /// Joining a cancelled thread returns as joining any other thread does.
  ///
  /// A cancelled thread ends as ``PThread/exit()`` ends it.
  /// The code on its stack doesn't finish:
  /// its `defer` blocks don't run,
  /// and the values it holds aren't destroyed, so what they own leaks,
  /// and a lock it holds stays locked.
  /// Cancel only a thread whose code is written for it,
  /// with nothing to clean up at the cancellation points
  /// it reaches with its cancellation enabled.
  ///
  /// The corresponding C function is `pthread_cancel`.
  /// - Note: Not available on Android, whose C library has no thread cancellation.
  @_alwaysEmitIntoClient
  public func cancel() throws(Errno) {
    try _cancel().get()
  }

  @usableFromInline
  internal func _cancel() -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_pthread_cancel(rawValue)
    }
  }
}

@available(System 199, *)
extension PThread {
  /// Ends the calling thread if another thread has asked it to end.
  ///
  /// This is a cancellation point that does nothing else.
  /// If ``PThread/ID/cancel()`` has asked the calling thread to end,
  /// and the thread's cancellation isn't disabled,
  /// the thread ends here, as ``exit()`` ends it.
  /// Otherwise this function returns at once.
  ///
  /// The corresponding C function is `pthread_testcancel`.
  /// - Note: Not available on Android, whose C library has no thread cancellation.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task cancellation instead")
  public static func testCancellation() {
    _testCancellation()
  }

  @usableFromInline
  internal static func _testCancellation() {
    system_pthread_testcancel()
  }

  /// Calls a closure with the calling thread's cancellation disabled,
  /// and then restores it.
  ///
  /// - Parameter body: The closure to call.
  /// - Returns: The value that `body` returns.
  ///
  /// While `body` runs, a request to end the thread stays pending,
  /// and the cancellation points that `body` reaches don't end it.
  /// When `body` returns or throws,
  /// the thread's cancellation is what it was before the call:
  /// enabled, unless an enclosing call disabled it.
  /// A pending request then ends the thread
  /// at its next cancellation point, such as ``testCancellation()``.
  ///
  /// Use this around code that has to finish,
  /// such as code that holds a lock, or that owns memory it must free,
  /// when it makes calls that are cancellation points.
  ///
  /// The corresponding C function is `pthread_setcancelstate`.
  /// - Note: Not available on Android, whose C library has no thread cancellation.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task cancellation instead")
  public static func withCancellationDisabled<R: ~Copyable>(
    _ body: () throws -> R
  ) rethrows -> R {
    let previous = _disableCancellation()
    defer { _restoreCancellation(previous) }
    return try body()
  }

  // pthread_setcancelstate fails only for a state other than these two, so
  // neither of these can fail.
  @usableFromInline
  internal static func _disableCancellation() -> CInt {
    var previous = _PTHREAD_CANCEL_ENABLE
    _ = system_pthread_setcancelstate(_PTHREAD_CANCEL_DISABLE, &previous)
    return previous
  }

  @usableFromInline
  internal static func _restoreCancellation(_ state: CInt) {
    var previous = state
    _ = system_pthread_setcancelstate(state, &previous)
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
