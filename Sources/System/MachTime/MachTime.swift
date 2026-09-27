/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Mach time: the kernel's monotonic clocks, in the units of the machine's
// timebase, which are nanoseconds on Intel processors but not on Apple
// silicon.
//
// The standard library's clocks read the same counters, as SuspendingClock
// and ContinuousClock, but give no way to use the raw values that the
// kernel reports elsewhere, such as a process's start time. These types
// hold such values, and convert them to and from Duration.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

// MARK: - Absolute time

@available(System 199, *)
extension Mach {
  /// A time on the clock that counts up from boot
  /// and stops while the system sleeps,
  /// in the units of the machine's ``Timebase``.
  ///
  /// The kernel reports some times in these units,
  /// such as when a process started.
  /// To measure the time between two, call ``duration(to:)``.
  ///
  /// This is the clock that `SuspendingClock` reads.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct AbsoluteTime: RawRepresentable, Hashable, Comparable, Sendable {
    /// The number of timebase units since boot.
    @_alwaysEmitIntoClient
    public var rawValue: UInt64

    /// Creates a time from a number of timebase units since boot.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    /// The current time.
    ///
    /// The corresponding C function is `mach_absolute_time`.
    @_alwaysEmitIntoClient
    public static var now: AbsoluteTime { AbsoluteTime(rawValue: _now()) }

    /// The current time, as of the last context switch or timer interrupt,
    /// which is less precise than ``now`` but faster to read.
    ///
    /// The corresponding C function is `mach_approximate_time`.
    @_alwaysEmitIntoClient
    public static var approximateNow: AbsoluteTime {
      AbsoluteTime(rawValue: _approximateNow())
    }

    @_alwaysEmitIntoClient
    public static func < (lhs: AbsoluteTime, rhs: AbsoluteTime) -> Bool {
      lhs.rawValue < rhs.rawValue
    }

    @usableFromInline
    internal static func _now() -> UInt64 { system_mach_absolute_time() }

    @usableFromInline
    internal static func _approximateNow() -> UInt64 { system_mach_approximate_time() }
  }
}

// MARK: - Continuous time

@available(System 199, *)
extension Mach {
  /// A time on the clock that counts up from boot,
  /// including while the system sleeps,
  /// in the units of the machine's ``Timebase``.
  ///
  /// This is the clock that `ContinuousClock` reads.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct ContinuousTime: RawRepresentable, Hashable, Comparable, Sendable {
    /// The number of timebase units since boot.
    @_alwaysEmitIntoClient
    public var rawValue: UInt64

    /// Creates a time from a number of timebase units since boot.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    @_alwaysEmitIntoClient
    public static func < (lhs: ContinuousTime, rhs: ContinuousTime) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }
}

// The calls need a newer OS than System 199 means in the default build, so
// this extension carries both.
@available(System 199, *)
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension Mach.ContinuousTime {
  /// The current time.
  ///
  /// The corresponding C function is `mach_continuous_time`.
  @_alwaysEmitIntoClient
  public static var now: Mach.ContinuousTime { Mach.ContinuousTime(rawValue: _now()) }

  /// The current time, as of the last context switch or timer interrupt,
  /// which is less precise than ``now`` but faster to read.
  ///
  /// The corresponding C function is `mach_continuous_approximate_time`.
  @_alwaysEmitIntoClient
  public static var approximateNow: Mach.ContinuousTime {
    Mach.ContinuousTime(rawValue: _approximateNow())
  }

  @usableFromInline
  internal static func _now() -> UInt64 { system_mach_continuous_time() }

  @usableFromInline
  internal static func _approximateNow() -> UInt64 {
    system_mach_continuous_approximate_time()
  }
}

// MARK: - Timebase

@available(System 199, *)
extension Mach {
  /// The ratio of the machine's Mach time units to nanoseconds.
  ///
  /// A number of units is a number of nanoseconds times
  /// ``denominator`` over ``numerator``.
  /// Intel processors count nanoseconds, a ratio of 1 to 1;
  /// Apple silicon counts at 24 MHz, a ratio of 125 to 3.
  ///
  /// The conversions saturate, rather than trapping,
  /// for a result too large for a `UInt64`.
  ///
  /// The corresponding C type is `mach_timebase_info_data_t`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Timebase: Hashable, Sendable {
    /// The number of nanoseconds in ``denominator`` units.
    public var numerator: UInt32

    /// The number of units in ``numerator`` nanoseconds.
    public var denominator: UInt32

    /// Creates a timebase from its ratio.
    @_alwaysEmitIntoClient
    public init(numerator: UInt32, denominator: UInt32) {
      self.numerator = numerator
      self.denominator = denominator
    }

    /// The machine's timebase.
    ///
    /// The timebase doesn't change while the system runs,
    /// so this property reads it once.
    ///
    /// The corresponding C function is `mach_timebase_info`.
    @_alwaysEmitIntoClient
    public static var current: Timebase { _current() }

    @usableFromInline
    internal static func _current() -> Timebase {
      Timebase(numerator: _machTimebase.numer, denominator: _machTimebase.denom)
    }

    /// Returns the number of nanoseconds in a number of units.
    @_alwaysEmitIntoClient
    public func nanoseconds(ofTicks ticks: UInt64) -> UInt64 {
      Timebase._scale(ticks, by: numerator, over: denominator)
    }

    /// Returns the number of units in a number of nanoseconds.
    @_alwaysEmitIntoClient
    public func ticks(inNanoseconds nanoseconds: UInt64) -> UInt64 {
      Timebase._scale(nanoseconds, by: denominator, over: numerator)
    }

    // Returns value * numerator / denominator, rounding down, or UInt64.max
    // if it doesn't fit.
    @usableFromInline
    internal static func _scale(
      _ value: UInt64, by numerator: UInt32, over denominator: UInt32
    ) -> UInt64 {
      let product = value.multipliedFullWidth(by: UInt64(numerator))
      guard product.high < UInt64(denominator) else { return .max }
      return UInt64(denominator).dividingFullWidth(product).quotient
    }
  }
}

// The machine's timebase, read once. It's the C structure, since a stored
// global can't carry the availability that Mach.Timebase has.
private let _machTimebase: mach_timebase_info_data_t = {
  var info = mach_timebase_info_data_t()
  let result = system_mach_timebase_info(&info)
  precondition(result == KERN_SUCCESS && info.numer != 0 && info.denom != 0)
  return info
}()

// MARK: - Durations

// Duration needs a newer OS than System 199 means in the default build, so
// these extensions carry both.

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Mach.Timebase {
  /// Returns the duration of a number of units.
  @_alwaysEmitIntoClient
  public func duration(ofTicks ticks: UInt64) -> Duration {
    .nanoseconds(nanoseconds(ofTicks: ticks))
  }

  /// Returns the number of units in a duration, rounding down.
  ///
  /// - Precondition: `duration` isn't negative.
  @_alwaysEmitIntoClient
  public func ticks(in duration: Duration) -> UInt64 {
    precondition(duration >= .zero, "A negative duration has no ticks")
    let (seconds, attoseconds) = duration.components
    let (nanoseconds, overflow) = UInt64(seconds).multipliedReportingOverflow(
      by: 1_000_000_000)
    guard !overflow else { return .max }
    let (total, sumOverflow) = nanoseconds.addingReportingOverflow(
      UInt64(attoseconds / 1_000_000_000))
    return sumOverflow ? .max : ticks(inNanoseconds: total)
  }

  // Converts a signed duration to a magnitude in units and a direction.
  @usableFromInline
  internal func _ticks(_ duration: Duration) -> (ticks: UInt64, negative: Bool) {
    duration < .zero
      ? (ticks(in: .zero - duration), true) : (ticks(in: duration), false)
  }

  @usableFromInline
  internal func _duration(from start: UInt64, to end: UInt64) -> Duration {
    end >= start
      ? duration(ofTicks: end - start) : .zero - duration(ofTicks: start - end)
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Mach.AbsoluteTime: InstantProtocol {
  /// Returns the time a duration after this one,
  /// or before it for a negative duration.
  ///
  /// The time traps if the result is out of range, as integer arithmetic does.
  @_alwaysEmitIntoClient
  public func advanced(by duration: Duration) -> Mach.AbsoluteTime {
    let (ticks, negative) = Mach.Timebase.current._ticks(duration)
    return Mach.AbsoluteTime(rawValue: negative ? rawValue - ticks : rawValue + ticks)
  }

  /// Returns the duration from this time to another,
  /// which is negative if the other time is earlier.
  @_alwaysEmitIntoClient
  public func duration(to other: Mach.AbsoluteTime) -> Duration {
    Mach.Timebase.current._duration(from: rawValue, to: other.rawValue)
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Mach.ContinuousTime: InstantProtocol {
  /// Returns the time a duration after this one,
  /// or before it for a negative duration.
  ///
  /// The time traps if the result is out of range, as integer arithmetic does.
  @_alwaysEmitIntoClient
  public func advanced(by duration: Duration) -> Mach.ContinuousTime {
    let (ticks, negative) = Mach.Timebase.current._ticks(duration)
    return Mach.ContinuousTime(rawValue: negative ? rawValue - ticks : rawValue + ticks)
  }

  /// Returns the duration from this time to another,
  /// which is negative if the other time is earlier.
  @_alwaysEmitIntoClient
  public func duration(to other: Mach.ContinuousTime) -> Duration {
    Mach.Timebase.current._duration(from: rawValue, to: other.rawValue)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
