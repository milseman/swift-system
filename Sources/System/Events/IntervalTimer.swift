/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned timerfd, on the pattern of OwnedFD.
// See Prototype/Events for the design.

// timerfd exists on Linux and Android.
#if os(Linux) || os(Android)

// Must import here to use the C itimerspec type in @_alwaysEmitIntoClient APIs.
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
  /// The C `itimerspec` type, which describes when a timer expires.
  public typealias ITimerSpec = itimerspec
}

/// A timer in the kernel, whose file descriptor becomes readable
/// when the timer expires.
///
/// Start the timer with ``setSchedule(_:options:)``,
/// and read how many times it has expired with
/// ``readExpirations(retryOnInterrupt:)``,
/// or watch its file descriptor with an ``EventPoll``:
///
///     let timer = try IntervalTimer(options: [.closeOnExec, .nonBlocking])
///     try timer.setSchedule(.init(nextExpiration: .milliseconds(10)))
///     try epoll.add(
///       timer.fileDescriptor, events: .readable,
///       data: .fileDescriptor(timer.fileDescriptor))
///
/// A timer owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does.
///
/// The corresponding C function is `timerfd_create`.
@frozen
@available(System 199, *)
public struct IntervalTimer: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates a timer, which doesn't run until you set its schedule.
  ///
  /// - Parameters:
  ///   - clock: The clock that the timer measures time with.
  ///     The default is ``Clock/monotonic``.
  ///   - options: Options for the timer's file descriptor.
  ///     The default is none.
  ///
  /// The corresponding C function is `timerfd_create`.
  @_alwaysEmitIntoClient
  public init(clock: Clock = .monotonic, options: Options = []) throws(Errno) {
    self._owner = OwnedFD(
      taking: try Self._create(clock.rawValue, options.rawValue).get())
  }

  @usableFromInline
  internal static func _create(
    _ clock: CInt, _ flags: CInt
  ) -> Result<FileDescriptor, Errno> {
    // timerfd_create can't be interrupted.
    valueOrErrno(retryOnInterrupt: false) {
      system_timerfd_create(clock, flags)
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that refers to a timer.
  ///
  /// This initializer doesn't check that `descriptor` refers to a timer.
  /// The descriptor is closed at the end of the timer's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The timer's file descriptor, for operations that `IntervalTimer`
  /// doesn't provide, such as watching it with an ``EventPoll``.
  ///
  /// The returned value is valid only while this timer is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the timer.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the timer's file descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

// MARK: - Clocks and options

@available(System 199, *)
extension IntervalTimer {
  /// A clock that a timer measures time with.
  @frozen
  public struct Clock: RawRepresentable, Hashable, Sendable {
    /// The raw C clock ID.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed clock from a raw C clock ID.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The system's wall-clock time,
    /// which jumps when someone sets the time.
    ///
    /// The corresponding C constant is `CLOCK_REALTIME`.
    @_alwaysEmitIntoClient
    public static var realtime: Clock { Clock(rawValue: _CLOCK_REALTIME) }

    /// A clock that never jumps, and stops while the system is suspended.
    ///
    /// The corresponding C constant is `CLOCK_MONOTONIC`.
    @_alwaysEmitIntoClient
    public static var monotonic: Clock { Clock(rawValue: _CLOCK_MONOTONIC) }

    /// A clock that never jumps, and keeps counting
    /// while the system is suspended.
    ///
    /// The corresponding C constant is `CLOCK_BOOTTIME`.
    @_alwaysEmitIntoClient
    public static var boottime: Clock { Clock(rawValue: _CLOCK_BOOTTIME) }

    /// The ``realtime`` clock, for a timer that wakes a suspended system.
    ///
    /// The process needs the `CAP_WAKE_ALARM` capability.
    ///
    /// The corresponding C constant is `CLOCK_REALTIME_ALARM`.
    @_alwaysEmitIntoClient
    public static var realtimeAlarm: Clock { Clock(rawValue: _CLOCK_REALTIME_ALARM) }

    /// The ``boottime`` clock, for a timer that wakes a suspended system.
    ///
    /// The process needs the `CAP_WAKE_ALARM` capability.
    ///
    /// The corresponding C constant is `CLOCK_BOOTTIME_ALARM`.
    @_alwaysEmitIntoClient
    public static var boottimeAlarm: Clock { Clock(rawValue: _CLOCK_BOOTTIME_ALARM) }
  }

  /// Options for a timer's file descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Closes the timer's file descriptor
    /// when the process executes a new program.
    ///
    /// The corresponding C constant is `TFD_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: Options { Options(rawValue: _TFD_CLOEXEC) }

    /// Makes reading a timer that hasn't expired
    /// throw ``Errno/resourceTemporarilyUnavailable`` rather than wait.
    ///
    /// The corresponding C constant is `TFD_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: Options { Options(rawValue: _TFD_NONBLOCK) }
  }

  /// Options for setting a timer's schedule.
  @frozen
  public struct ScheduleOptions: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The schedule's next expiration is a time on the timer's clock,
    /// rather than a time from now.
    ///
    /// The corresponding C constant is `TFD_TIMER_ABSTIME`.
    @_alwaysEmitIntoClient
    public static var absolute: ScheduleOptions {
      ScheduleOptions(rawValue: _TFD_TIMER_ABSTIME)
    }

    /// With ``absolute``, for a timer on a realtime clock,
    /// makes reading the timer throw ``Errno/canceled``
    /// if someone sets the clock before the timer expires.
    ///
    /// The corresponding C constant is `TFD_TIMER_CANCEL_ON_SET`.
    @_alwaysEmitIntoClient
    public static var cancelOnSet: ScheduleOptions {
      ScheduleOptions(rawValue: _TFD_TIMER_CANCEL_ON_SET)
    }
  }
}

// MARK: - Schedules

@available(System 199, *)
extension IntervalTimer {
  /// When a timer expires next, and how often it expires after that.
  ///
  /// The corresponding C type is `struct itimerspec`.
  @frozen
  public struct Schedule: RawRepresentable, Sendable {
    /// The raw C schedule.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.ITimerSpec

    /// Creates a strongly-typed schedule from a raw C schedule.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.ITimerSpec) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension IntervalTimer.Schedule {
  /// Creates a schedule.
  ///
  /// - Parameters:
  ///   - nextExpiration: The time until the timer expires, or,
  ///     with the ``IntervalTimer/ScheduleOptions/absolute`` option,
  ///     the time on the timer's clock when it expires.
  ///     A schedule whose next expiration is zero or less stops the timer.
  ///   - interval: How often the timer expires after that,
  ///     or zero for a timer that expires once.
  ///     The default is zero.
  @_alwaysEmitIntoClient
  public init(nextExpiration: Duration, interval: Duration = .zero) {
    self.init(rawValue: CInterop.ITimerSpec())
    self.nextExpiration = nextExpiration
    self.interval = interval
  }

  /// A schedule that stops the timer.
  @_alwaysEmitIntoClient
  public static var disarmed: Self { Self(rawValue: CInterop.ITimerSpec()) }

  /// The time until the timer expires,
  /// or, when you set a schedule with the absolute option,
  /// the time on the timer's clock when it expires.
  ///
  /// Zero means that the timer isn't running.
  /// A positive time shorter than a nanosecond rounds up to one,
  /// so that it doesn't stop the timer.
  ///
  /// The corresponding C field is `it_value`.
  @_alwaysEmitIntoClient
  public var nextExpiration: Duration {
    get { _duration(rawValue.it_value) }
    set { rawValue.it_value = _timespec(newValue) }
  }

  /// How often the timer expires after its next expiration,
  /// or zero for a timer that expires once.
  ///
  /// The corresponding C field is `it_interval`.
  @_alwaysEmitIntoClient
  public var interval: Duration {
    get { _duration(rawValue.it_interval) }
    set { rawValue.it_interval = _timespec(newValue) }
  }
}

@available(System 199, *)
extension IntervalTimer.Schedule: Hashable {
  /// Returns whether two schedules have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.nextExpiration == rhs.nextExpiration && lhs.interval == rhs.interval
  }

  /// Hashes the schedule's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(nextExpiration)
    hasher.combine(interval)
  }
}

// MARK: - Operations

@available(System 199, *)
extension IntervalTimer {
  /// Starts, changes, or stops the timer.
  ///
  /// Setting a schedule discards expirations that haven't been read.
  ///
  /// - Parameters:
  ///   - schedule: When the timer expires next, and how often after that.
  ///     To stop the timer, pass ``Schedule/disarmed``.
  ///   - options: Options for the schedule, such as whether its next
  ///     expiration is a time on the timer's clock.
  ///     The default is none.
  /// - Returns: The timer's schedule before this call.
  ///
  /// The corresponding C function is `timerfd_settime`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func setSchedule(
    _ schedule: Schedule, options: ScheduleOptions = []
  ) throws(Errno) -> Schedule {
    try _setSchedule(schedule.rawValue, options.rawValue).get()
  }

  @usableFromInline
  internal func _setSchedule(
    _ new: CInterop.ITimerSpec, _ flags: CInt
  ) -> Result<Schedule, Errno> {
    var new = new
    var old = CInterop.ITimerSpec()
    // timerfd_settime can't be interrupted.
    return nothingOrErrno(retryOnInterrupt: false) {
      system_timerfd_settime(_owner.fileDescriptor.rawValue, flags, &new, &old)
    }.map { Schedule(rawValue: old) }
  }

  /// Returns the timer's schedule: the time until it expires next,
  /// and its interval.
  ///
  /// The next expiration is always a time from now,
  /// even for a schedule that you set with the absolute option.
  ///
  /// The corresponding C function is `timerfd_gettime`.
  @_alwaysEmitIntoClient
  public func schedule() throws(Errno) -> Schedule {
    try _schedule().get()
  }

  @usableFromInline
  internal func _schedule() -> Result<Schedule, Errno> {
    var current = CInterop.ITimerSpec()
    // timerfd_gettime can't be interrupted.
    return nothingOrErrno(retryOnInterrupt: false) {
      system_timerfd_gettime(_owner.fileDescriptor.rawValue, &current)
    }.map { Schedule(rawValue: current) }
  }

  /// Reads the number of times the timer has expired since the last read,
  /// or since the schedule was set, and resets it.
  ///
  /// If the timer hasn't expired, this method waits for it to,
  /// or, with the ``Options/nonBlocking`` option,
  /// throws ``Errno/resourceTemporarilyUnavailable``.
  /// It throws ``Errno/canceled`` if the schedule has the
  /// ``ScheduleOptions/cancelOnSet`` option and someone set the clock.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the read
  ///   if a signal interrupts it.
  ///   The default is `true`.
  ///   Pass `false` to throw ``Errno/interrupted`` instead.
  /// - Returns: The number of expirations, which is at least one.
  ///
  /// The corresponding C function is `read`, of 8 bytes.
  @_alwaysEmitIntoClient
  public func readExpirations(retryOnInterrupt: Bool = true) throws(Errno) -> UInt64 {
    var expirations: UInt64 = 0
    _ = try withUnsafeMutableBytes(of: &expirations) {
      _owner.fileDescriptor._read(into: $0, retryOnInterrupt: retryOnInterrupt)
    }.get()
    return expirations
  }
}

// MARK: - Descriptions

@available(System 199, *)
extension IntervalTimer.Schedule: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the schedule.
  @inline(never)
  public var description: String {
    "Schedule(nextExpiration: \(nextExpiration), interval: \(interval))"
  }

  /// A textual representation of the schedule, suitable for debugging.
  public var debugDescription: String { self.description }
}
#endif // os(Linux) || os(Android)
