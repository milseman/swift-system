/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// Must import here to use the C itimerval type in @_alwaysEmitIntoClient
// APIs, and CSystem on Linux, whose copy of timeval can own its members.
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
  /// The C `struct itimerval` type, an interval timer's schedule.
  public typealias ITimerVal = itimerval
}

/// One of the calling process's three interval timers,
/// each of which sends the process a signal when it expires.
///
///     // Send SIGALRM in two seconds, and every half second after that.
///     try ProcessTimer.real.setSchedule(
///       .init(nextExpiration: .seconds(2), interval: .milliseconds(500)))
///
/// A timer's signal ends the process
/// unless the process handles, ignores, or blocks it.
/// The timers belong to the process, not to a thread,
/// so any thread can receive the signal.
/// A child process doesn't inherit its parent's timers,
/// and a program that `execve` runs keeps them.
///
/// For a timer that a file descriptor reports on Linux,
/// see `IntervalTimer`.
///
/// The corresponding C type is the `int` that names a timer,
/// such as `ITIMER_REAL`.
@frozen
@available(System 199, *)
public struct ProcessTimer: RawRepresentable, Hashable, Sendable {
  /// The raw C timer.
  @_alwaysEmitIntoClient
  public var rawValue: CInt

  /// Creates a strongly-typed timer from a raw C timer.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }
}

@available(System 199, *)
extension ProcessTimer {
  /// The timer that counts real time,
  /// and sends ``Signal/alarm`` when it expires.
  ///
  /// ``setAlarm(seconds:)`` sets this timer too.
  ///
  /// The corresponding C constant is `ITIMER_REAL`.
  @_alwaysEmitIntoClient
  public static var real: Self { Self(rawValue: _ITIMER_REAL) }

  /// The timer that counts the processor time
  /// that the process spends running its own code,
  /// and sends ``Signal/virtualAlarm`` when it expires.
  ///
  /// The corresponding C constant is `ITIMER_VIRTUAL`.
  @_alwaysEmitIntoClient
  public static var virtual: Self { Self(rawValue: _ITIMER_VIRTUAL) }

  /// The timer that counts the processor time that the process uses,
  /// running its own code and the system's code for it,
  /// and sends ``Signal/profilingAlarm`` when it expires.
  ///
  /// Profilers sample a program with this timer.
  ///
  /// The corresponding C constant is `ITIMER_PROF`.
  @_alwaysEmitIntoClient
  public static var profiling: Self { Self(rawValue: _ITIMER_PROF) }
}

// MARK: - Schedules

@available(System 199, *)
extension ProcessTimer {
  /// When a timer expires next, and how often it expires after that.
  ///
  /// The corresponding C type is `struct itimerval`.
  @frozen
  public struct Schedule: RawRepresentable, Sendable {
    /// The raw C schedule.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.ITimerVal

    /// Creates a strongly-typed schedule from a raw C schedule.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.ITimerVal) { self.rawValue = rawValue }

    /// A schedule that stops the timer.
    @_alwaysEmitIntoClient
    public static var disarmed: Self { Self(rawValue: CInterop.ITimerVal()) }
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ProcessTimer.Schedule {
  /// Creates a schedule.
  ///
  /// - Parameters:
  ///   - nextExpiration: The time until the timer expires.
  ///     A schedule whose next expiration is zero or less stops the timer.
  ///   - interval: How often the timer expires after that,
  ///     or zero for a timer that expires once.
  ///     The default is zero.
  @_alwaysEmitIntoClient
  public init(nextExpiration: Duration, interval: Duration = .zero) {
    self.init(rawValue: CInterop.ITimerVal())
    self.nextExpiration = nextExpiration
    self.interval = interval
  }

  /// The time until the timer expires, in microseconds.
  ///
  /// Zero means that the timer isn't running.
  /// A negative time is zero,
  /// and a positive one rounds up to a whole microsecond,
  /// so that a time shorter than a microsecond doesn't stop the timer.
  ///
  /// The corresponding C field is `it_value`.
  @_alwaysEmitIntoClient
  public var nextExpiration: Duration {
    get { _duration(rawValue.it_value) }
    set { rawValue.it_value = _timeval(newValue) }
  }

  /// How often the timer expires after its next expiration,
  /// or zero for a timer that expires once, in microseconds.
  ///
  /// The corresponding C field is `it_interval`.
  @_alwaysEmitIntoClient
  public var interval: Duration {
    get { _duration(rawValue.it_interval) }
    set { rawValue.it_interval = _timeval(newValue) }
  }
}

@available(System 199, *)
extension ProcessTimer.Schedule: Hashable {
  /// Returns whether two schedules have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: Self, rhs: Self) -> Bool {
    let (l, r) = (lhs.rawValue, rhs.rawValue)
    return l.it_value.tv_sec == r.it_value.tv_sec
      && l.it_value.tv_usec == r.it_value.tv_usec
      && l.it_interval.tv_sec == r.it_interval.tv_sec
      && l.it_interval.tv_usec == r.it_interval.tv_usec
  }

  /// Hashes the schedule's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(Int64(rawValue.it_value.tv_sec))
    hasher.combine(Int64(rawValue.it_value.tv_usec))
    hasher.combine(Int64(rawValue.it_interval.tv_sec))
    hasher.combine(Int64(rawValue.it_interval.tv_usec))
  }
}

/// Converts a duration to a `timeval`: a negative duration becomes zero,
/// and a positive one rounds up to a whole microsecond.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@_alwaysEmitIntoClient
internal func _timeval(_ duration: Duration) -> timeval {
  guard duration > .zero else { return timeval(tv_sec: 0, tv_usec: 0) }
  var (seconds, attoseconds) = duration.components
  var microseconds = (attoseconds + 999_999_999_999) / 1_000_000_000_000
  if microseconds == 1_000_000 {
    seconds = seconds == .max ? .max : seconds + 1
    microseconds = 0
  }
  return timeval(tv_sec: .init(clamping: seconds), tv_usec: .init(microseconds))
}

/// Converts a `timeval` to a duration.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@_alwaysEmitIntoClient
internal func _duration(_ time: timeval) -> Duration {
  .seconds(Int64(time.tv_sec)) + .microseconds(Int64(time.tv_usec))
}

// MARK: - Operations

@available(System 199, *)
extension ProcessTimer {
  /// Returns the timer's schedule:
  /// the time left until it expires, and its interval.
  ///
  /// The corresponding C function is `getitimer`.
  @_alwaysEmitIntoClient
  public func schedule() throws(Errno) -> Schedule {
    try _schedule().get()
  }

  @usableFromInline
  internal func _schedule() -> Result<Schedule, Errno> {
    var value = CInterop.ITimerVal()
    return nothingOrErrno(retryOnInterrupt: false) {
      system_getitimer(rawValue, &value)
    }.map { Schedule(rawValue: value) }
  }

  /// Starts, changes, or stops the timer.
  ///
  /// - Parameter schedule: When the timer expires next,
  ///   and how often after that.
  ///   To stop the timer, pass ``Schedule/disarmed``.
  /// - Returns: The timer's schedule before this call.
  ///
  /// The system can round the times up to its timer's resolution.
  /// Linux adds a scheduler tick, 1 to 10 ms,
  /// to the ``virtual`` and ``profiling`` timers' next expiration.
  ///
  /// The corresponding C function is `setitimer`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func setSchedule(_ schedule: Schedule) throws(Errno) -> Schedule {
    try _setSchedule(schedule).get()
  }

  @usableFromInline
  internal func _setSchedule(_ schedule: Schedule) -> Result<Schedule, Errno> {
    var old = CInterop.ITimerVal()
    return withUnsafePointer(to: schedule.rawValue) { new in
      nothingOrErrno(retryOnInterrupt: false) {
        system_setitimer(rawValue, new, &old)
      }
    }.map { Schedule(rawValue: old) }
  }

  /// Sets the real timer to expire once, after a number of seconds,
  /// or stops it.
  ///
  /// - Parameter seconds: The seconds until the process gets
  ///   ``Signal/alarm``, which can't be negative,
  ///   or zero to stop the timer.
  /// - Returns: The seconds that were left before this call,
  ///   rounded up, or zero if the timer wasn't running.
  ///
  /// This sets the same timer as ``real``,
  /// with a whole number of seconds and no interval.
  ///
  /// The corresponding C function is `alarm`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func setAlarm(seconds: Int) -> Int {
    _setAlarm(seconds: seconds)
  }

  @usableFromInline
  internal static func _setAlarm(seconds: Int) -> Int {
    precondition(seconds >= 0, "seconds can't be negative")
    return Int(system_alarm(CUnsignedInt(clamping: seconds)))
  }
}

#endif // !os(Windows) && !os(WASI)
