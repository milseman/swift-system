/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// CSystem on Linux, where timespec's members come from it.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension PThread {
  /// Suspends the calling thread for a duration.
  ///
  /// - Parameters:
  ///   - duration: How long to sleep. A duration of zero or less
  ///     doesn't sleep; a positive one rounds up to a whole nanosecond.
  ///   - retryOnInterrupt: Whether to keep sleeping, for the time that's left,
  ///     if a signal interrupts the sleep.
  ///     The default is `true`.
  ///     Pass `false` to throw ``Errno/interrupted`` instead.
  ///
  /// The thread sleeps for at least `duration`, unless a signal
  /// interrupts it and `retryOnInterrupt` is `false`,
  /// and can sleep longer, as the system schedules it.
  /// Resuming after an interruption sleeps for the time that the system
  /// reports as left, rather than starting over.
  ///
  /// This method blocks the thread.
  /// In asynchronous code, call `Task.sleep(for:)`,
  /// which suspends the task instead.
  ///
  /// The corresponding C function is `nanosleep`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task.sleep(for:), which suspends the task rather than blocking its thread")
  public static func sleep(
    for duration: Duration, retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _sleep(for: duration, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _sleep(
    for duration: Duration, retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    var request = _timespec(duration)
    var remaining = timespec()
    while system_nanosleep(&request, &remaining) != 0 {
      let error = Errno.current
      guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
      request = remaining
    }
    return .success(())
  }
}

#endif // !os(Windows) && !os(WASI)
