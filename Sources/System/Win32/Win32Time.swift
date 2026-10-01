/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - File times

@available(System 199, *)
extension Win32 {
  /// A time, as Windows records system and file times: a count of
  /// 100-nanosecond intervals since the start of January 1, 1601, in UTC.
  ///
  /// The corresponding C type is `FILETIME`, which splits the count into
  /// two 32-bit halves.
  @frozen
  public struct FileTime: RawRepresentable, Sendable, Hashable, Codable, Comparable {
    /// The number of 100-nanosecond intervals since the start of January 1,
    /// 1601, in UTC.
    @_alwaysEmitIntoClient
    public var rawValue: Int64

    /// Creates a strongly-typed time from a count of 100-nanosecond
    /// intervals since the start of January 1, 1601, in UTC.
    @_alwaysEmitIntoClient
    public init(rawValue: Int64) { self.rawValue = rawValue }

    /// Creates a time from the C structure.
    ///
    /// Windows produces no `FILETIME` with its high bit set, which would
    /// be after the year 30827; one becomes a negative ``rawValue``.
    @_alwaysEmitIntoClient
    public init(_ fileTime: FILETIME) {
      self.rawValue = Int64(
        bitPattern: UInt64(fileTime.dwHighDateTime) << 32 | UInt64(fileTime.dwLowDateTime))
    }

    /// The time as the C structure.
    @_alwaysEmitIntoClient
    public var fileTime: FILETIME {
      let bits = UInt64(bitPattern: rawValue)
      return FILETIME(
        dwLowDateTime: DWORD(truncatingIfNeeded: bits),
        dwHighDateTime: DWORD(truncatingIfNeeded: bits >> 32))
    }

    @_alwaysEmitIntoClient
    public static func < (lhs: FileTime, rhs: FileTime) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }
}

@available(System 199, *)
extension Win32.FileTime {
  /// The time since the Unix epoch, the start of January 1, 1970, in UTC.
  ///
  /// A time before the epoch is a negative duration.
  @_alwaysEmitIntoClient
  public var durationSinceUnixEpoch: Duration {
    // The components share rawValue's sign, which Duration accepts.
    let (seconds, intervals) = rawValue.quotientAndRemainder(dividingBy: 10_000_000)
    return Duration(
      secondsComponent: seconds - Win32.FileTime._unixEpochSeconds,
      attosecondsComponent: intervals * 100_000_000_000)
  }

  /// Creates a time from the time since the Unix epoch, the start of
  /// January 1, 1970, in UTC.
  ///
  /// The duration rounds down to a whole 100-nanosecond interval. Returns
  /// `nil` for a time that a `FileTime` can't hold, about 29,000 years
  /// before or after 1601.
  @_alwaysEmitIntoClient
  public init?(durationSinceUnixEpoch duration: Duration) {
    guard let rawValue = Win32.FileTime._intervals(sinceUnixEpoch: duration) else {
      return nil
    }
    self.rawValue = rawValue
  }

  /// The seconds from the start of 1601 to the Unix epoch.
  @_alwaysEmitIntoClient
  internal static var _unixEpochSeconds: Int64 { 11_644_473_600 }

  @usableFromInline
  internal static func _intervals(sinceUnixEpoch duration: Duration) -> Int64? {
    // The components share the duration's sign. An interval is 10^11
    // attoseconds; the division truncates toward zero, so a negative
    // remainder rounds down by one more.
    let (seconds, attoseconds) = duration.components
    var intervals = attoseconds / 100_000_000_000
    if attoseconds % 100_000_000_000 < 0 { intervals -= 1 }
    let (since1601, secondsOverflow) = seconds.addingReportingOverflow(_unixEpochSeconds)
    let (scaled, scaleOverflow) = since1601.multipliedReportingOverflow(by: 10_000_000)
    let (total, sumOverflow) = scaled.addingReportingOverflow(intervals)
    guard !secondsOverflow, !scaleOverflow, !sumOverflow else { return nil }
    return total
  }
}

// MARK: - Clocks

@available(System 199, *)
extension Win32.FileTime {
  /// The current system time, in UTC, as precisely as the system can tell
  /// it: to within a microsecond.
  ///
  /// The system time is the wall clock, which synchronization and the user
  /// can set forward or back. To measure elapsed time, use a clock that
  /// only advances, such as ``Win32/unbiasedInterruptTime()``.
  ///
  /// The corresponding C function is `GetSystemTimePreciseAsFileTime`.
  @_alwaysEmitIntoClient
  public static var now: Win32.FileTime { Win32.FileTime(Win32._systemTime(precise: true)) }

  /// The system time, in UTC, as of the latest tick of the system timer.
  ///
  /// This is cheaper to read than ``now``, and as coarse as the timer's
  /// period, typically 15.6 milliseconds.
  ///
  /// The corresponding C function is `GetSystemTimeAsFileTime`.
  @_alwaysEmitIntoClient
  public static var coarseNow: Win32.FileTime {
    Win32.FileTime(Win32._systemTime(precise: false))
  }
}

@available(System 199, *)
extension Win32 {
  /// The time since the system started, in whole milliseconds, including
  /// time it spent asleep or hibernating.
  ///
  /// The count advances at each tick of the system timer, typically every
  /// 10 to 16 milliseconds.
  ///
  /// The corresponding C function is `GetTickCount64`.
  @_alwaysEmitIntoClient
  public static func tickCount() -> Duration {
    .milliseconds(Int64(truncatingIfNeeded: _tickCount()))
  }

  /// The time since the system started, including time it spent asleep or
  /// hibernating, as precisely as the system can tell it.
  ///
  /// The corresponding C function is `QueryInterruptTimePrecise`.
  @_alwaysEmitIntoClient
  public static func interruptTime() -> Duration {
    _duration(intervals: _interruptTime(unbiased: false))
  }

  /// The time since the system started, not including time it spent asleep
  /// or hibernating, as precisely as the system can tell it.
  ///
  /// This is the clock to measure elapsed time with when the measurement
  /// shouldn't include a sleep.
  ///
  /// The corresponding C function is `QueryUnbiasedInterruptTimePrecise`.
  @_alwaysEmitIntoClient
  public static func unbiasedInterruptTime() -> Duration {
    _duration(intervals: _interruptTime(unbiased: true))
  }

  /// The current value of the performance counter, the system's
  /// highest-resolution clock that only advances.
  ///
  /// The counter counts ticks of ``performanceFrequency()`` per second from
  /// an unspecified start, so only differences between its values are
  /// meaningful.
  ///
  /// The corresponding C function is `QueryPerformanceCounter`.
  @_alwaysEmitIntoClient
  public static func performanceCounter() -> Int64 {
    _performanceCounter(frequency: false)
  }

  /// The performance counter's frequency, in ticks per second.
  ///
  /// The frequency is fixed when the system starts, so it can be read once.
  ///
  /// The corresponding C function is `QueryPerformanceFrequency`.
  @_alwaysEmitIntoClient
  public static func performanceFrequency() -> Int64 {
    _performanceCounter(frequency: true)
  }
}

// MARK: - Sleeping

@available(System 199, *)
extension Win32 {
  /// Suspends the calling thread for a duration.
  ///
  /// - Parameter duration: How long to sleep. A positive duration rounds up
  ///   to a whole millisecond. A duration of zero or less gives the rest of
  ///   the thread's time slice to another thread that's ready to run, if
  ///   there is one, and otherwise returns at once.
  ///
  /// The thread wakes at a tick of the system timer, so a sleep usually
  /// lasts longer than `duration`, by up to the timer's period, typically
  /// 15.6 milliseconds; Windows can also end a sleep shorter than the
  /// period early.
  ///
  /// This method blocks the thread. In asynchronous code, call
  /// `Task.sleep(for:)`, which suspends the task instead.
  ///
  /// The corresponding C function is `Sleep`.
  @_alwaysEmitIntoClient
  @available(*, noasync, message: "Use Task.sleep(for:), which suspends the task rather than blocking its thread")
  public static func sleep(for duration: Duration) {
    _sleep(for: duration)
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _systemTime(precise: Bool) -> FILETIME {
    var time = FILETIME()
    if precise {
      system_GetSystemTimePreciseAsFileTime(&time)
    } else {
      system_GetSystemTimeAsFileTime(&time)
    }
    return time
  }

  @usableFromInline
  internal static func _tickCount() -> ULONGLONG {
    system_GetTickCount64()
  }

  @usableFromInline
  internal static func _interruptTime(unbiased: Bool) -> ULONGLONG {
    var time: ULONGLONG = 0
    if unbiased {
      system_QueryUnbiasedInterruptTimePrecise(&time)
    } else {
      system_QueryInterruptTimePrecise(&time)
    }
    return time
  }

  /// A count of 100-nanosecond intervals as a duration.
  @_alwaysEmitIntoClient
  internal static func _duration(intervals: ULONGLONG) -> Duration {
    let (seconds, remainder) = intervals.quotientAndRemainder(dividingBy: 10_000_000)
    return Duration(
      secondsComponent: Int64(truncatingIfNeeded: seconds),
      attosecondsComponent: Int64(truncatingIfNeeded: remainder) * 100_000_000_000)
  }

  @usableFromInline
  internal static func _performanceCounter(frequency: Bool) -> Int64 {
    // Neither call fails on Windows XP or later.
    var value = LARGE_INTEGER()
    if frequency {
      _ = system_QueryPerformanceFrequency(&value)
    } else {
      _ = system_QueryPerformanceCounter(&value)
    }
    return value.QuadPart
  }

  @usableFromInline
  internal static func _sleep(for duration: Duration) {
    var remaining = _win32Milliseconds(roundingUp: duration)
    // Sleep(INFINITE) never returns, so a longer sleep takes parts of one
    // millisecond less. A sleep of zero still calls Sleep once, to yield.
    repeat {
      let part = DWORD(min(remaining, UInt64(_INFINITE - 1)))
      system_Sleep(part)
      remaining -= UInt64(part)
    } while remaining > 0
  }
}

#endif // os(Windows)
