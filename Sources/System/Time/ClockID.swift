/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// Must import here to use the C clockid_t type in @_alwaysEmitIntoClient
// APIs, and Darwin's _CLOCK_ constants; and CSystem on Linux, where
// timespec's members come from it.
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
extension CInterop {
  /// The C `clockid_t` type, which identifies a clock.
  public typealias ClockID = clockid_t
}

/// A clock that the system keeps,
/// such as its wall clock, or the processor time that a process has used.
///
/// Read a clock with ``currentTime()``:
///
///     let start = try ClockID.monotonic.currentTime()
///     doSomeWork()
///     let elapsed = try ClockID.monotonic.currentTime() - start
///
/// The standard library's `ContinuousClock` and `SuspendingClock`
/// read some of these clocks too;
/// this type names each of the system's clocks, and reads it directly.
///
/// The corresponding C type is `clockid_t`.
@frozen
@available(System 199, *)
public struct ClockID: RawRepresentable, Hashable, Sendable {
  /// The raw C clock ID.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.ClockID

  /// Creates a strongly-typed clock ID from a raw C clock ID.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.ClockID) { self.rawValue = rawValue }
}

@available(System 199, *)
extension ClockID {
  /// The system's wall clock: the time since the Unix epoch,
  /// 1970-01-01 00:00:00 UTC, not counting leap seconds.
  ///
  /// This clock jumps when someone, or a time daemon, sets the time,
  /// so it can go backward.
  /// To measure elapsed time, use ``monotonic``.
  ///
  /// The corresponding C constant is `CLOCK_REALTIME`.
  @_alwaysEmitIntoClient
  public static var realtime: ClockID { ClockID(rawValue: _CLOCK_REALTIME) }

  /// A clock that never jumps, for measuring elapsed time,
  /// from an unspecified moment such as when the system started.
  ///
  /// Whether this clock counts while the system is asleep
  /// differs by platform: Darwin's does, and Linux's doesn't.
  /// For the other behavior, use ``uptimeRaw`` on Darwin,
  /// or ``boottime`` on Linux.
  ///
  /// The corresponding C constant is `CLOCK_MONOTONIC`.
  @_alwaysEmitIntoClient
  public static var monotonic: ClockID { ClockID(rawValue: _CLOCK_MONOTONIC) }

  /// The processor time that the calling process has used,
  /// in all its threads.
  ///
  /// The corresponding C constant is `CLOCK_PROCESS_CPUTIME_ID`.
  @_alwaysEmitIntoClient
  public static var processCPUTime: ClockID {
    ClockID(rawValue: _CLOCK_PROCESS_CPUTIME_ID)
  }

  /// The processor time that the calling thread has used.
  ///
  /// The corresponding C constant is `CLOCK_THREAD_CPUTIME_ID`.
  @_alwaysEmitIntoClient
  public static var threadCPUTime: ClockID {
    ClockID(rawValue: _CLOCK_THREAD_CPUTIME_ID)
  }

  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
  /// A clock like ``monotonic``, without the adjustments
  /// that keep that clock's rate in step with the wall clock's.
  ///
  /// The corresponding C constant is `CLOCK_MONOTONIC_RAW`.
  /// - Note: Only available on Darwin, Linux, and Android.
  @_alwaysEmitIntoClient
  public static var monotonicRaw: ClockID { ClockID(rawValue: _CLOCK_MONOTONIC_RAW) }
  #endif

  #if SYSTEM_PACKAGE_DARWIN
  /// ``monotonicRaw``'s time as of the thread's last context switch,
  /// which is cheaper to read and less precise.
  ///
  /// The corresponding C constant is `CLOCK_MONOTONIC_RAW_APPROX`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var monotonicRawApproximate: ClockID {
    ClockID(rawValue: _CLOCK_MONOTONIC_RAW_APPROX)
  }

  /// A clock that never jumps, and stops while the system is asleep,
  /// without the adjustments that keep its rate in step with the wall clock's.
  ///
  /// The corresponding C constant is `CLOCK_UPTIME_RAW`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var uptimeRaw: ClockID { ClockID(rawValue: _CLOCK_UPTIME_RAW) }

  /// ``uptimeRaw``'s time as of the thread's last context switch,
  /// which is cheaper to read and less precise.
  ///
  /// The corresponding C constant is `CLOCK_UPTIME_RAW_APPROX`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var uptimeRawApproximate: ClockID {
    ClockID(rawValue: _CLOCK_UPTIME_RAW_APPROX)
  }
  #endif

  #if os(Linux) || os(Android)
  /// A clock like ``monotonic``, that keeps counting
  /// while the system is suspended.
  ///
  /// The corresponding C constant is `CLOCK_BOOTTIME`.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var boottime: ClockID { ClockID(rawValue: _CLOCK_BOOTTIME) }

  /// ``realtime``'s time as of the last timer tick,
  /// which is cheaper to read and less precise.
  ///
  /// The corresponding C constant is `CLOCK_REALTIME_COARSE`.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var realtimeCoarse: ClockID { ClockID(rawValue: _CLOCK_REALTIME_COARSE) }

  /// ``monotonic``'s time as of the last timer tick,
  /// which is cheaper to read and less precise.
  ///
  /// The corresponding C constant is `CLOCK_MONOTONIC_COARSE`.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var monotonicCoarse: ClockID { ClockID(rawValue: _CLOCK_MONOTONIC_COARSE) }

  /// International Atomic Time: ``realtime`` counting leap seconds,
  /// once a time daemon has told the system their number.
  ///
  /// The corresponding C constant is `CLOCK_TAI`.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public static var tai: ClockID { ClockID(rawValue: _CLOCK_TAI) }
  #endif
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ClockID {
  /// Returns the clock's current time.
  ///
  /// - Returns: The time since the clock's epoch:
  ///   the Unix epoch for ``realtime``,
  ///   the start of the process or thread for the processor-time clocks,
  ///   and an unspecified moment for the others.
  ///
  /// Subtract two readings of a clock to measure the time between them.
  /// If the system doesn't have the clock,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `clock_gettime`.
  @_alwaysEmitIntoClient
  public func currentTime() throws(Errno) -> Duration {
    try _currentTime().get()
  }

  @usableFromInline
  internal func _currentTime() -> Result<Duration, Errno> {
    var time = timespec()
    // clock_gettime can't be interrupted.
    return nothingOrErrno(retryOnInterrupt: false) {
      system_clock_gettime(rawValue, &time)
    }.map { _duration(time) }
  }

  /// Returns the clock's resolution:
  /// the smallest difference between two readings that it can report.
  ///
  /// If the system doesn't have the clock,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `clock_getres`.
  @_alwaysEmitIntoClient
  public func resolution() throws(Errno) -> Duration {
    try _resolution().get()
  }

  @usableFromInline
  internal func _resolution() -> Result<Duration, Errno> {
    var resolution = timespec()
    return nothingOrErrno(retryOnInterrupt: false) {
      system_clock_getres(rawValue, &resolution)
    }.map { _duration(resolution) }
  }
}

#endif // !os(Windows) && !os(WASI)
