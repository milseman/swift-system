/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// Must import here to use C's struct tm in @usableFromInline API;
// and CSystem on Linux, in case its headers declare tm's members.
//
// The C library first: this is SystemPackage's first file, and the first
// module Swift loads owns the C types that it and CSystem's headers both
// declare, such as timespec and timeval. If that's CSystem, their members
// are hidden from clients, which don't import it (MemberImportVisibility;
// Tests/MemberImportVisibility/TimespecProbe.swift).
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
import CSystem
#elseif canImport(Musl)
import Musl
import CSystem
#elseif canImport(Android)
import Android
import CSystem
#else
#error("Unsupported Platform")
#endif

/// A time broken down into a calendar date and a time of day,
/// in UTC or in the local time zone.
///
/// Break down a time, in seconds since the Unix epoch, into its fields,
/// and convert the fields back:
///
///     let seconds = Int(try ClockID.realtime.currentTime().components.seconds)
///     let now = try BrokenDownTime(secondsSinceEpoch: seconds, in: .local)
///     print(now.year, now.month, now.day, now.weekday)
///     // Prints "2026 9 28 monday"
///     print(now.formatted("%Y-%m-%d %H:%M:%S %z"))
///     // Prints "2026-09-28 09:41:00 -0600"
///
/// The fields count the way people do:
/// ``year`` is the year itself, such as 2026,
/// and ``month``, ``day``, and ``dayOfYear`` start at 1.
/// C's `struct tm` counts years from 1900,
/// and months and days of the year from 0; this type converts.
///
/// Fields can be outside their usual ranges.
/// ``secondsSinceEpoch(in:)`` and ``normalized(in:)``
/// carry them into the others, as C's `mktime` does:
/// the 32nd of January is the 1st of February,
/// and day 0 is the last day of the month before.
/// That's how to do calendar arithmetic:
///
///     var meeting = try BrokenDownTime(secondsSinceEpoch: seconds, in: .local)
///     meeting.day += 7
///     meeting.isDaylightSavingTime = nil
///     let nextWeek = try meeting.secondsSinceEpoch(in: .local)
///
/// The calendar is the Gregorian calendar,
/// extended back before its adoption in 1582,
/// and there are no leap seconds, as in the count of seconds since the epoch.
///
/// C's `struct tm` holds each field in an `int`.
/// A field that doesn't fit one, such as a year more than two billion
/// years away, makes the conversions throw ``Errno/overflow``,
/// and ``weekday``, ``dayOfYear``, and ``formatted(_:)`` trap.
///
/// The corresponding C type is `struct tm`.
@frozen
@available(System 199, *)
public struct BrokenDownTime: Hashable, Sendable {
  /// The year, such as 2026.
  ///
  /// The year before 1 is 0, and the one before that is -1,
  /// as in ISO 8601.
  ///
  /// The corresponding C field is `tm_year`, which counts years from 1900.
  public var year: Int

  /// The month, from 1 for January through 12 for December.
  ///
  /// The corresponding C field is `tm_mon`, which counts months from 0.
  public var month: Int

  /// The day of the month, from 1 through 31.
  ///
  /// The corresponding C field is `tm_mday`.
  public var day: Int

  /// The hour, from 0 through 23.
  ///
  /// The corresponding C field is `tm_hour`.
  public var hour: Int

  /// The minute, from 0 through 59.
  ///
  /// The corresponding C field is `tm_min`.
  public var minute: Int

  /// The second, from 0 through 59,
  /// or 60 for a leap second, which the conversions carry into the next minute.
  ///
  /// The corresponding C field is `tm_sec`.
  public var second: Int

  /// Whether the time is in daylight saving time,
  /// or `nil` if that isn't known.
  ///
  /// Converting a local time to seconds reads this field.
  /// When the clocks go back at the end of daylight saving time,
  /// they show an hour's times twice;
  /// `true` picks the first of the two, in daylight saving time,
  /// and `false` the second, and `nil` lets the system choose.
  /// A value that's wrong for the date moves the time
  /// by the difference between the two offsets, usually an hour,
  /// so after changing other fields, set this one to `nil`.
  ///
  /// The corresponding C field is `tm_isdst`,
  /// which is positive for `true`, zero for `false`, and negative for `nil`.
  public var isDaylightSavingTime: Bool?

  /// The time's offset from UTC, in seconds:
  /// positive east of Greenwich, as in Asia,
  /// and negative west of it, as in the Americas.
  ///
  /// Converting to seconds ignores this field.
  ///
  /// The corresponding C field is `tm_gmtoff`.
  public var utcOffset: Int

  /// The abbreviation of the time's time zone, such as `"PDT"`,
  /// or `nil` if that isn't known.
  ///
  /// Converting to seconds ignores this field.
  /// The abbreviation for UTC differs by platform:
  /// Darwin's is `"UTC"`, and glibc's `"GMT"`.
  ///
  /// The corresponding C field is `tm_zone`.
  public var timeZoneAbbreviation: String?

  /// Creates a broken-down time from its fields.
  ///
  /// The time of day defaults to midnight,
  /// and the time zone to an unknown one, with an offset of zero.
  @_alwaysEmitIntoClient
  public init(
    year: Int, month: Int, day: Int,
    hour: Int = 0, minute: Int = 0, second: Int = 0,
    isDaylightSavingTime: Bool? = nil,
    utcOffset: Int = 0,
    timeZoneAbbreviation: String? = nil
  ) {
    self.year = year
    self.month = month
    self.day = day
    self.hour = hour
    self.minute = minute
    self.second = second
    self.isDaylightSavingTime = isDaylightSavingTime
    self.utcOffset = utcOffset
    self.timeZoneAbbreviation = timeZoneAbbreviation
  }
}

// MARK: - Weekday and day of the year

@available(System 199, *)
extension BrokenDownTime {
  /// A day of the week.
  ///
  /// The raw values are C's, the days since Sunday.
  @frozen
  public enum Weekday: Int, CaseIterable, Hashable, Sendable {
    case sunday = 0
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
  }

  /// The day of the week.
  ///
  /// It's computed from the other fields, so it's never out of date,
  /// as C's is after a change to them.
  /// For fields outside their usual ranges,
  /// it's the weekday of the date they carry to.
  ///
  /// The corresponding C field is `tm_wday`.
  @_alwaysEmitIntoClient
  public var weekday: Weekday { _weekday }

  @usableFromInline
  internal var _weekday: Weekday {
    // 1970-01-01 was a Thursday.
    Weekday(rawValue: Int(_floorMod(_days + 4, 7)))!
  }

  /// The day of the year, from 1 for January 1st
  /// through 365, or 366 in a leap year, for December 31st.
  ///
  /// It's computed from the other fields, so it's never out of date,
  /// as C's is after a change to them.
  /// For fields outside their usual ranges,
  /// it's the day of the year of the date they carry to.
  ///
  /// The corresponding C field is `tm_yday`, which counts from 0.
  @_alwaysEmitIntoClient
  public var dayOfYear: Int { _dayOfYear }

  @usableFromInline
  internal var _dayOfYear: Int {
    let days = _days
    let year = _civilYear(days)
    return Int(days - _daysSinceEpoch(year: year, month: 1, day: 1)) + 1
  }

  // The days from 1970-01-01 to the date that the fields carry to.
  private var _days: Int64 {
    guard let seconds = _secondsAsUTC else {
      preconditionFailure("A field of the broken-down time doesn't fit C's struct tm")
    }
    return _floorDiv(seconds, 86_400)
  }

  // The seconds since the epoch of the time that the fields name, read as
  // UTC; nil if a field doesn't fit C's int.
  internal var _secondsAsUTC: Int64? {
    guard let fields = _intFields else { return nil }
    // Each field fits an int, so none of this overflows 64 bits.
    let days = _daysSinceEpoch(
      year: Int64(fields.year) + 1900, month: Int64(fields.month) + 1,
      day: Int64(fields.day))
    return days * 86_400 + Int64(fields.hour) * 3_600
      + Int64(fields.minute) * 60 + Int64(fields.second)
  }

  // The fields as C's ints, with the year counted from 1900 and the month
  // from 0; nil if one doesn't fit.
  private var _intFields: (
    year: CInt, month: CInt, day: CInt, hour: CInt, minute: CInt, second: CInt
  )? {
    let (year, yearOverflow) = year.subtractingReportingOverflow(1900)
    let (month, monthOverflow) = month.subtractingReportingOverflow(1)
    guard !yearOverflow, !monthOverflow,
      let year = CInt(exactly: year), let month = CInt(exactly: month),
      let day = CInt(exactly: day), let hour = CInt(exactly: hour),
      let minute = CInt(exactly: minute), let second = CInt(exactly: second)
    else { return nil }
    return (year, month, day, hour, minute, second)
  }
}

private func _floorDiv(_ x: Int64, _ y: Int64) -> Int64 {
  let (quotient, remainder) = x.quotientAndRemainder(dividingBy: y)
  return remainder < 0 ? quotient - 1 : quotient
}

private func _floorMod(_ x: Int64, _ y: Int64) -> Int64 {
  let remainder = x % y
  return remainder < 0 ? remainder + y : remainder
}

// The days from 1970-01-01 to a date in the proleptic Gregorian calendar,
// carrying a month outside 1 through 12 into the year, and any day into the
// month. Howard Hinnant's days_from_civil.
private func _daysSinceEpoch(year: Int64, month: Int64, day: Int64) -> Int64 {
  let year = year + _floorDiv(month - 1, 12)
  let month = _floorMod(month - 1, 12) + 1
  // Years that start in March, so that a leap day is a year's last.
  let marchYear = month <= 2 ? year - 1 : year
  let era = _floorDiv(marchYear, 400)
  let yearOfEra = marchYear - era * 400
  let monthFromMarch = (month + 9) % 12
  let dayOfMarchYear = (153 * monthFromMarch + 2) / 5
  let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfMarchYear
  return era * 146_097 + dayOfEra - 719_468 + (day - 1)
}

// The year of the date that is a number of days from 1970-01-01.
// Howard Hinnant's civil_from_days.
private func _civilYear(_ days: Int64) -> Int64 {
  let days = days + 719_468
  let era = _floorDiv(days, 146_097)
  let dayOfEra = days - era * 146_097
  let yearOfEra =
    (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
  let dayOfMarchYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
  let monthFromMarch = (5 * dayOfMarchYear + 2) / 153
  // January and February belong to the next year.
  return yearOfEra + era * 400 + (monthFromMarch >= 10 ? 1 : 0)
}

// MARK: - Converting

@available(System 199, *)
extension BrokenDownTime {
  /// The time zones that the C library converts times in.
  @frozen
  public enum Zone: Hashable, Sendable {
    /// Coordinated Universal Time.
    case utc

    /// The local time zone: the one that the `TZ` environment variable names,
    /// or if it's unset, the system's.
    ///
    /// Changing `TZ` while another thread converts a time is a data race,
    /// as for any environment variable.
    case local
  }

  /// Breaks down a time in UTC or in the local time zone.
  ///
  /// - Parameters:
  ///   - seconds: The time, in seconds since the Unix epoch,
  ///     1970-01-01 00:00:00 UTC.
  ///   - zone: The time zone to break the time down in.
  ///
  /// If the year doesn't fit C's `struct tm`,
  /// which happens only for times billions of years away,
  /// this initializer throws ``Errno/overflow``.
  ///
  /// It calls `gmtime_r` for ``Zone/utc`` and `localtime_r` for ``Zone/local``.
  /// For ``Zone/local``, it calls `tzset` first,
  /// so that it uses the `TZ` environment variable's current value
  /// on every platform, as `mktime` does;
  /// glibc's `localtime_r` otherwise reads it only once.
  ///
  /// The corresponding C functions are `gmtime_r` and `localtime_r`.
  @_alwaysEmitIntoClient
  public init(secondsSinceEpoch seconds: Int, in zone: Zone) throws(Errno) {
    self = try Self._breakDown(seconds, zone).get()
  }

  @usableFromInline
  internal static func _breakDown(
    _ seconds: Int, _ zone: Zone
  ) -> Result<BrokenDownTime, Errno> {
    guard var time = time_t(exactly: seconds) else { return .failure(.overflow) }
    var result = tm()
    system_errno = 0
    let converted: UnsafeMutablePointer<tm>?
    switch zone {
    case .utc:
      converted = system_gmtime_r(&time, &result)
    case .local:
      system_tzset()
      converted = system_localtime_r(&time, &result)
    }
    guard converted != nil else {
      return .failure(system_errno == 0 ? .overflow : Errno.current)
    }
    return .success(BrokenDownTime(result))
  }

  /// Returns the time that the fields name, read as a time in UTC
  /// or in the local time zone, in seconds since the Unix epoch.
  ///
  /// Fields outside their usual ranges carry into the others.
  /// This method ignores ``weekday``, ``dayOfYear``, ``utcOffset``,
  /// and ``timeZoneAbbreviation``, and for ``Zone/utc``,
  /// ``isDaylightSavingTime``.
  /// For ``Zone/local``, ``isDaylightSavingTime`` picks between
  /// the times that the clock shows twice when it goes back;
  /// a time that the clock skips when it goes forward,
  /// such as 2:30 on the night daylight saving time starts,
  /// moves forward by the time skipped on Darwin and glibc.
  ///
  /// If the time doesn't fit C's `time_t`, or a field doesn't fit C's `int`,
  /// this method throws ``Errno/overflow``.
  /// Darwin's `timegm` and `mktime` also fail for times before 1900:
  /// for ``Zone/utc``, this method computes such a time itself,
  /// and for ``Zone/local``, it throws ``Errno/overflow``.
  ///
  /// It calls `timegm` for ``Zone/utc`` and `mktime` for ``Zone/local``.
  ///
  /// The corresponding C functions are `timegm` and `mktime`.
  @_alwaysEmitIntoClient
  public func secondsSinceEpoch(in zone: Zone) throws(Errno) -> Int {
    try _secondsSinceEpoch(zone).get()
  }

  @usableFromInline
  internal func _secondsSinceEpoch(_ zone: Zone) -> Result<Int, Errno> {
    _convert(zone).map(\.seconds)
  }

  /// Returns the same time, read as a time in UTC or in the local time zone,
  /// with each field in its usual range, and the time zone's fields filled in.
  ///
  /// This method reads the fields as ``secondsSinceEpoch(in:)`` does,
  /// and returns the fields of the time that method returns:
  /// the 32nd of January becomes the 1st of February,
  /// and ``isDaylightSavingTime``, ``utcOffset``,
  /// and ``timeZoneAbbreviation`` become the zone's for that time.
  ///
  /// If the time doesn't fit C's `time_t`, or a field doesn't fit C's `int`,
  /// this method throws ``Errno/overflow``,
  /// and like ``secondsSinceEpoch(in:)``, it throws it on Darwin
  /// for local times before 1900.
  ///
  /// It calls `timegm` for ``Zone/utc`` and `mktime` for ``Zone/local``.
  ///
  /// The corresponding C functions are `timegm` and `mktime`.
  @_alwaysEmitIntoClient
  public func normalized(in zone: Zone) throws(Errno) -> BrokenDownTime {
    try _normalized(zone).get()
  }

  @usableFromInline
  internal func _normalized(_ zone: Zone) -> Result<BrokenDownTime, Errno> {
    _convert(zone).map(\.normalized)
  }

  private func _convert(
    _ zone: Zone
  ) -> Result<(seconds: Int, normalized: BrokenDownTime), Errno> {
    guard var time = _cFields else { return .failure(.overflow) }
    // The calls ignore the offset. Zeroed, it doesn't count in the check
    // below when a failed call leaves the fields as they were.
    time.tm_gmtoff = 0
    system_errno = 0
    let result: time_t
    switch zone {
    case .utc: result = system_timegm(&time)
    case .local: result = system_mktime(&time)
    }
    // A successful call normalizes the fields, and a failed one leaves them.
    let normalized = BrokenDownTime(time)
    if result == -1 {
      // -1 is also a time, 1969-12-31 23:59:59 UTC. Darwin's timegm and
      // mktime don't set errno when they fail, and its timegm can set it
      // when it succeeds, so the fields say which it was.
      guard let seconds = normalized._secondsAsUTC,
        seconds - Int64(normalized.utcOffset) == -1
      else {
        let error = system_errno
        // Darwin's timegm fails, without setting errno, for times before
        // 1900, which its gmtime_r breaks down. The time it would have
        // returned is the fields' arithmetic.
        if zone == .utc, error == 0,
          let seconds = _secondsAsUTC.flatMap({ Int(exactly: $0) })
        {
          return Self._breakDown(seconds, .utc).map { (seconds, $0) }
        }
        return .failure(error == 0 ? .overflow : Errno(rawValue: error))
      }
    }
    guard let seconds = Int(exactly: result) else { return .failure(.overflow) }
    return .success((seconds, normalized))
  }
}

// MARK: - C's struct tm

@available(System 199, *)
extension BrokenDownTime {
  // The fields as C's struct tm holds them, without the zone's abbreviation,
  // which is a pointer; nil if a field doesn't fit C's int.
  internal var _cFields: tm? {
    guard let fields = _intFields else { return nil }
    var time = tm()
    time.tm_year = fields.year
    time.tm_mon = fields.month
    time.tm_mday = fields.day
    time.tm_hour = fields.hour
    time.tm_min = fields.minute
    time.tm_sec = fields.second
    switch isDaylightSavingTime {
    case nil: time.tm_isdst = -1
    case false?: time.tm_isdst = 0
    case true?: time.tm_isdst = 1
    }
    time.tm_gmtoff = .init(utcOffset)
    // timegm and mktime ignore these, but strftime reads them.
    time.tm_wday = CInt(_weekday.rawValue)
    time.tm_yday = CInt(_dayOfYear - 1)
    return time
  }

  // The fields of C's struct tm, copying the zone's abbreviation, which
  // points to storage that the next call can change.
  internal init(_ time: tm) {
    self.init(
      year: Int(time.tm_year) + 1900, month: Int(time.tm_mon) + 1,
      day: Int(time.tm_mday),
      hour: Int(time.tm_hour), minute: Int(time.tm_min), second: Int(time.tm_sec),
      isDaylightSavingTime: time.tm_isdst < 0 ? nil : time.tm_isdst > 0,
      utcOffset: Int(time.tm_gmtoff),
      timeZoneAbbreviation: time.tm_zone.map {
        String(platformString: UnsafePointer($0))
      })
  }
}

// MARK: - Formatting

@available(System 199, *)
extension BrokenDownTime {
  /// Returns the time formatted as a format string says.
  ///
  ///     let time = try BrokenDownTime(secondsSinceEpoch: 1_790_000_000, in: .utc)
  ///     print(time.formatted("%A, %B %d, %Y at %H:%M %Z"))
  ///     // Prints "Monday, September 21, 2026 at 14:13 UTC"
  ///
  /// A `%` and a letter stand for a field, such as `%Y` for the year,
  /// `%m` for the month, and `%d` for the day;
  /// `%%` stands for `%`, and other text stands for itself.
  /// See the C library's `strftime` documentation
  /// for the conversions it supports.
  /// Names such as `%A`'s and `%B`'s are in the C library's locale,
  /// which is English unless the program calls `setlocale`.
  ///
  /// Three conversions describe the time's own zone,
  /// from its fields, on every platform:
  /// `%z` is ``utcOffset``, as `+hhmm` or `-hhmm`;
  /// `%Z` is ``timeZoneAbbreviation``, or nothing if it's `nil`;
  /// and `%s` is the time in seconds since the epoch,
  /// computed with ``utcOffset``.
  /// C's `strftime` can describe the local time zone instead:
  /// Darwin's `%z` prints the local zone's offset,
  /// Darwin and glibc print the local zone's abbreviation for a missing one,
  /// and `%s` reads the fields as a local time.
  /// These conversions with a flag or a width, such as `%-z`,
  /// are `strftime`'s own.
  ///
  /// Like C's `strftime`, this method reads ``weekday`` and ``dayOfYear``,
  /// which are always up to date,
  /// but doesn't normalize fields outside their usual ranges:
  /// the 32nd of January is formatted as `01-32`.
  ///
  /// The corresponding C function is `strftime`.
  @_alwaysEmitIntoClient
  public func formatted(_ format: String) -> String {
    _formatted(format)
  }

  @usableFromInline
  internal func _formatted(_ format: String) -> String {
    guard var time = _cFields else {
      preconditionFailure("A field of the broken-down time doesn't fit C's struct tm")
    }
    // A space after the format means that what strftime writes is never
    // empty, so a result of 0 always means that the buffer was too small.
    let format = _replacingZoneConversions(in: format) + " "
    return format.withCString { format -> String in
      _withCStringOrNull(timeZoneAbbreviation) { abbreviation -> String in
        _setTimeZoneAbbreviation(&time, abbreviation)
        var capacity = 256
        while true {
          let formatted = withUnsafeTemporaryAllocation(
            of: CChar.self, capacity: capacity
          ) { buffer -> String? in
            let count = system_strftime(buffer.baseAddress!, buffer.count, format, &time)
            guard count > 0 else { return nil }
            // Without the space.
            return String(
              decoding: UnsafeRawBufferPointer(start: buffer.baseAddress!, count: count - 1),
              as: UTF8.self)
          }
          if let formatted { return formatted }
          capacity *= 2
        }
      }
    }
  }

  // Replaces the plain %z, %Z and %s conversions with the time's own
  // values, leaving %% and everything else to strftime. The fields must fit
  // C's ints.
  internal func _replacingZoneConversions(in format: String) -> String {
    var result = String.UnicodeScalarView()
    var scalars = format.unicodeScalars.makeIterator()
    while let scalar = scalars.next() {
      guard scalar == "%" else {
        result.append(scalar)
        continue
      }
      guard let next = scalars.next() else {
        result.append(scalar)
        break
      }
      let replacement: String
      switch next {
      case "z":
        replacement = _utcOffsetText
      case "Z":
        // As a format, where % stands for itself only when doubled.
        var escaped = String.UnicodeScalarView()
        for scalar in (timeZoneAbbreviation ?? "").unicodeScalars {
          escaped.append(scalar)
          if scalar == "%" { escaped.append(scalar) }
        }
        replacement = String(escaped)
      case "s":
        let (seconds, overflow) = _secondsAsUTC!.subtractingReportingOverflow(
          Int64(utcOffset))
        replacement = overflow ? "%s" : String(seconds)
      default:
        replacement = "%" + String(next)
      }
      result.append(contentsOf: replacement.unicodeScalars)
    }
    return String(result)
  }

  // The offset as %z formats it: +hhmm or -hhmm, dropping any seconds.
  internal var _utcOffsetText: String {
    let minutes = utcOffset.magnitude / 60
    let hours = String(minutes / 60)
    let remainder = String(minutes % 60)
    return (utcOffset < 0 ? "-" : "+")
      + String(repeating: "0", count: max(0, 2 - hours.count)) + hours
      + String(repeating: "0", count: 2 - remainder.count) + remainder
  }
}

private func _withCStringOrNull<R>(
  _ string: String?, _ body: (UnsafePointer<CChar>?) -> R
) -> R {
  guard let string else { return body(nil) }
  return string.withCString(body)
}

// Darwin and the BSDs declare tm_zone as char *, and Linux as const char *.
private func _setTimeZoneAbbreviation(
  _ time: inout tm, _ abbreviation: UnsafePointer<CChar>?
) {
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  time.tm_zone = UnsafeMutablePointer(mutating: abbreviation)
  #else
  time.tm_zone = abbreviation
  #endif
}

#endif // !os(Windows) && !os(WASI)
