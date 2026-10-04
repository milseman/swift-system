/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt

// BrokenDownTime on Windows, over the C runtime's 64-bit time functions.
// BrokenDownTime.swift declares it for the other platforms, over gmtime_r,
// localtime_r, timegm, mktime and strftime. The declarations, the fields'
// arithmetic and the zone conversions' replacement are the same here; what
// differs is the C runtime's: its `struct tm` has no `tm_gmtoff` or
// `tm_zone`, its conversions cover 1970 through 3000, and its `strftime`
// rejects fields outside their usual ranges and conversions it doesn't know.
// The C names are spelled `ucrt.tm` and `ucrt.strftime`, which macOS's C
// library also declares, for Prototype/Win32/check-windows.sh.

/// A time broken down into a calendar date and a time of day,
/// in UTC or in the local time zone.
///
/// Break down a time, in seconds since the Unix epoch, into its fields,
/// and convert the fields back:
///
///     let seconds = Int(Win32.FileTime.now.durationSinceUnixEpoch.components.seconds)
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
/// years away, makes the conversions throw `EOVERFLOW`,
/// and ``weekday``, ``dayOfYear``, and ``formatted(_:)`` trap.
/// On Windows, the C runtime converts times from 1970 through 3000:
/// System computes UTC times outside that range itself,
/// and local times outside it throw `EOVERFLOW`.
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
  /// Windows' `struct tm` has no `tm_gmtoff`: for a local time, this is
  /// the C runtime's offset for its time zone, `_get_timezone`'s and, in
  /// daylight saving time, `_get_dstbias`'s.
  public var utcOffset: Int

  /// The abbreviation of the time's time zone, such as `"PDT"`,
  /// or `nil` if that isn't known.
  ///
  /// Converting to seconds ignores this field.
  /// Windows' `struct tm` has no `tm_zone`: for UTC this is `"UTC"`, and
  /// for a local time it's the C runtime's name for its time zone
  /// (`_get_tzname`), which is the `TZ` environment variable's
  /// abbreviation, such as `"PST"`, or if `TZ` is unset, the system time
  /// zone's name, such as `"Pacific Standard Time"`.
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
    let year = _civilDate(days).year
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

// The date that is a number of days from 1970-01-01. Howard Hinnant's
// civil_from_days.
private func _civilDate(_ days: Int64) -> (year: Int64, month: Int64, day: Int64) {
  let days = days + 719_468
  let era = _floorDiv(days, 146_097)
  let dayOfEra = days - era * 146_097
  let yearOfEra =
    (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
  let dayOfMarchYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
  let monthFromMarch = (5 * dayOfMarchYear + 2) / 153
  let day = dayOfMarchYear - (153 * monthFromMarch + 2) / 5 + 1
  let month = monthFromMarch < 10 ? monthFromMarch + 3 : monthFromMarch - 9
  // January and February belong to the next year.
  return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
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
    /// On Windows, `TZ` takes the C runtime's form, such as `PST8PDT`, and
    /// the C runtime applies a zone's current daylight saving rules to
    /// every year.
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
  /// this initializer throws `EOVERFLOW`.
  ///
  /// It calls `_gmtime64_s` for ``Zone/utc`` and `_localtime64_s` for
  /// ``Zone/local``, after `_tzset`, so that it uses the `TZ` environment
  /// variable's current value. The C runtime breaks down times from 1970
  /// through 3000 only: for ``Zone/utc``, this initializer computes any
  /// other time's fields itself, and for ``Zone/local``, it throws
  /// `EOVERFLOW`.
  ///
  /// The corresponding C functions are `_gmtime64_s` and `_localtime64_s`.
  @_alwaysEmitIntoClient
  public init(secondsSinceEpoch seconds: Int, in zone: Zone) throws(Errno) {
    self = try Self._breakDown(seconds, zone).get()
  }

  @usableFromInline
  internal static func _breakDown(
    _ seconds: Int, _ zone: Zone
  ) -> Result<BrokenDownTime, Errno> {
    var time = __time64_t(seconds)
    var result = ucrt.tm()
    switch zone {
    case .utc:
      let error = system__gmtime64_s(&result, &time)
      guard error == 0 else {
        // EINVAL is the C runtime's answer for a time outside its range,
        // whose fields the arithmetic gives.
        guard error == ucrt.EINVAL else { return .failure(Errno(rawValue: error)) }
        return _utcBreakDown(Int64(seconds))
      }
      return .success(BrokenDownTime(result, zone: .utc))
    case .local:
      system__tzset()
      let error = system__localtime64_s(&result, &time)
      guard error == 0 else {
        return .failure(error == ucrt.EINVAL ? _overflow : Errno(rawValue: error))
      }
      return .success(BrokenDownTime(result, zone: .local))
    }
  }

  /// Returns the time that the fields name, read as a time in UTC
  /// or in the local time zone, in seconds since the Unix epoch.
  ///
  /// Fields outside their usual ranges carry into the others.
  /// This method ignores ``weekday``, ``dayOfYear``, ``utcOffset``,
  /// and ``timeZoneAbbreviation``, and for ``Zone/utc``,
  /// ``isDaylightSavingTime``.
  /// For ``Zone/local``, ``isDaylightSavingTime`` picks between
  /// the times that the clock shows twice when it goes back.
  ///
  /// If a field doesn't fit C's `int`, this method throws `EOVERFLOW`.
  /// The C runtime converts times from 1970 through 3000 only: for
  /// ``Zone/utc``, this method computes any other time itself, and for
  /// ``Zone/local``, it throws `EOVERFLOW`.
  ///
  /// It calls `_mkgmtime64` for ``Zone/utc`` and `_mktime64` for
  /// ``Zone/local``.
  ///
  /// The corresponding C functions are `_mkgmtime64` and `_mktime64`.
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
  /// It throws as ``secondsSinceEpoch(in:)`` does.
  ///
  /// It calls `_mkgmtime64` for ``Zone/utc`` and `_mktime64` for
  /// ``Zone/local``.
  ///
  /// The corresponding C functions are `_mkgmtime64` and `_mktime64`.
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
    guard var time = _cFields else { return .failure(Self._overflow) }
    let result: __time64_t
    switch zone {
    case .utc:
      result = system__mkgmtime64(&time)
      // -1, 1969-12-31 23:59:59 UTC, is outside the C runtime's range, so
      // it's always a failure, after which the arithmetic gives the time.
      guard result != -1 else {
        guard let seconds = _secondsAsUTC, let exact = Int(exactly: seconds) else {
          return .failure(Self._overflow)
        }
        return Self._utcBreakDown(seconds).map { (exact, $0) }
      }
    case .local:
      system__tzset()
      result = system__mktime64(&time)
      guard result != -1 else { return .failure(Self._overflow) }
    }
    // A successful call normalizes the fields.
    return .success((Int(result), BrokenDownTime(time, zone: zone)))
  }

  /// `EOVERFLOW`, which the C runtime defines and `Errno` names only on
  /// other platforms.
  internal static var _overflow: Errno { Errno(rawValue: ucrt.EOVERFLOW) }

  // The fields of a time in UTC, from the arithmetic, for a time that the C
  // runtime doesn't convert.
  internal static func _utcBreakDown(_ seconds: Int64) -> Result<BrokenDownTime, Errno> {
    let days = _floorDiv(seconds, 86_400)
    let secondOfDay = seconds - days * 86_400
    let date = _civilDate(days)
    // C's struct tm holds the year, less 1900, in an int.
    guard let year = Int(exactly: date.year), CInt(exactly: date.year - 1900) != nil else {
      return .failure(_overflow)
    }
    return .success(
      BrokenDownTime(
        year: year, month: Int(date.month), day: Int(date.day),
        hour: Int(secondOfDay / 3_600), minute: Int(secondOfDay / 60 % 60),
        second: Int(secondOfDay % 60), isDaylightSavingTime: false, utcOffset: 0,
        timeZoneAbbreviation: "UTC"))
  }
}

// MARK: - C's struct tm

@available(System 199, *)
extension BrokenDownTime {
  // The fields as C's struct tm holds them; nil if a field doesn't fit C's
  // int.
  internal var _cFields: ucrt.tm? {
    guard let fields = _intFields else { return nil }
    var time = ucrt.tm()
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
    // _mkgmtime64 and _mktime64 ignore these, but strftime reads them.
    time.tm_wday = CInt(_weekday.rawValue)
    time.tm_yday = CInt(_dayOfYear - 1)
    return time
  }

  // The fields of C's struct tm, with the zone's fields, which it doesn't
  // hold: UTC's, or the C runtime's for its local time zone.
  internal init(_ time: ucrt.tm, zone: Zone) {
    let isDaylightSavingTime: Bool?
    let utcOffset: Int
    let abbreviation: String?
    switch zone {
    case .utc:
      isDaylightSavingTime = false
      utcOffset = 0
      abbreviation = "UTC"
    case .local:
      isDaylightSavingTime = time.tm_isdst < 0 ? nil : time.tm_isdst > 0
      (utcOffset, abbreviation) = BrokenDownTime._localZone(
        daylightSavingTime: time.tm_isdst > 0)
    }
    self.init(
      year: Int(time.tm_year) + 1900, month: Int(time.tm_mon) + 1,
      day: Int(time.tm_mday),
      hour: Int(time.tm_hour), minute: Int(time.tm_min), second: Int(time.tm_sec),
      isDaylightSavingTime: isDaylightSavingTime,
      utcOffset: utcOffset,
      timeZoneAbbreviation: abbreviation)
  }

  // The C runtime's local offset, east of UTC, and name, for standard or
  // daylight saving time, as of its last _tzset.
  internal static func _localZone(daylightSavingTime: Bool) -> (Int, String?) {
    // Seconds west of UTC, and daylight saving time's change to them,
    // which is negative. Windows' long is 32 bits.
    var west: Int32 = 0
    var bias: Int32 = 0
    _ = system__get_timezone(&west)
    _ = system__get_dstbias(&bias)
    let offset = -(Int(west) + (daylightSavingTime ? Int(bias) : 0))
    return (offset, _timeZoneName(daylightSavingTime ? 1 : 0))
  }

  // _get_tzname's name, in the C runtime's code page, decoded as UTF-8,
  // which an ASCII name is.
  internal static func _timeZoneName(_ index: CInt) -> String? {
    var size = 0
    // The first call reports the size, terminator included.
    guard system__get_tzname(&size, nil, 0, index) == 0, size > 0 else { return nil }
    return withUnsafeTemporaryAllocation(of: CChar.self, capacity: size) { buffer -> String? in
      var written = 0
      guard system__get_tzname(&written, buffer.baseAddress, buffer.count, index) == 0,
        written > 0
      else { return nil }
      return String(
        decoding: UnsafeRawBufferPointer(start: buffer.baseAddress, count: written - 1),
        as: UTF8.self)
    }
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
  /// These conversions with a flag, such as `%#z`, are `strftime`'s own,
  /// which describe the local time zone.
  ///
  /// Like C's `strftime`, this method reads ``weekday`` and ``dayOfYear``,
  /// which are always up to date.
  ///
  /// On Windows, the C runtime's `strftime` supports C99's conversions,
  /// with its `#` flag and the `E` and `O` modifiers, and rejects others,
  /// such as `%k` or `%-d`, which this method prints as they're written.
  /// It also rejects a field outside its usual range: for such fields,
  /// this method formats the time they carry to, as UTC, so the 32nd of
  /// January is formatted as `02-01`. A year before 0 or after 9999 can't
  /// be formatted at all, and gives an empty string.
  ///
  /// The corresponding C function is `strftime`.
  @_alwaysEmitIntoClient
  public func formatted(_ format: String) -> String {
    _formatted(format)
  }

  @usableFromInline
  internal func _formatted(_ format: String) -> String {
    guard let time = _cFields else {
      preconditionFailure("A field of the broken-down time doesn't fit C's struct tm")
    }
    // A space after the format means that what strftime writes is never
    // empty, so a result of 0 means that the buffer was too small, or, with
    // EINVAL, that strftime rejected the fields.
    let format = _replacingZoneConversions(in: format) + " "
    return format.withCString { format -> String in
      if let formatted = Self._strftime(format, time) { return formatted }
      // A field outside its range: the time the fields carry to.
      guard let seconds = _secondsAsUTC,
        case .success(let carried) = Self._utcBreakDown(seconds),
        var normalized = carried._cFields
      else { return "" }
      normalized.tm_isdst = time.tm_isdst
      return Self._strftime(format, normalized) ?? ""
    }
  }

  // strftime's result, growing the buffer as it needs, or nil if strftime
  // rejects the fields. The C runtime's strftime reports a field outside
  // its range to the invalid parameter handler, whose default ends the
  // process, so a handler that returns stands in during the call.
  internal static func _strftime(_ format: UnsafePointer<CChar>, _ time: ucrt.tm) -> String? {
    var time = time
    var capacity = 256
    // A format's output is a few times its length, so this ends.
    while capacity <= 1 << 24 {
      let outcome = withUnsafeTemporaryAllocation(
        of: CChar.self, capacity: capacity
      ) { buffer -> String?? in
        Errno.current = Errno(rawValue: 0)
        let previous = _set_thread_local_invalid_parameter_handler { _, _, _, _, _ in }
        let count = system_strftime(buffer.baseAddress!, buffer.count, format, &time)
        let error = Errno.current
        _ = _set_thread_local_invalid_parameter_handler(previous)
        guard count > 0 else {
          // Rejected, or too small.
          return error.rawValue == ucrt.EINVAL ? .some(nil) : nil
        }
        // Without the space.
        return String(
          decoding: UnsafeRawBufferPointer(start: buffer.baseAddress!, count: count - 1),
          as: UTF8.self)
      }
      if let outcome { return outcome }
      capacity *= 2
    }
    return nil
  }

  // Replaces the plain %z, %Z and %s conversions with the time's own
  // values, and escapes the conversions that the C runtime's strftime
  // rejects, so that they print as they're written, leaving %% and the
  // rest to strftime. The fields must fit C's ints.
  internal func _replacingZoneConversions(in format: String) -> String {
    var result = String.UnicodeScalarView()
    var scalars = format.unicodeScalars.makeIterator()
    while let scalar = scalars.next() {
      guard scalar == "%" else {
        result.append(scalar)
        continue
      }
      // A conversion: %, an optional # flag, an optional E or O modifier,
      // and a letter.
      var conversion = String.UnicodeScalarView([scalar])
      var next = scalars.next()
      if next == "#" {
        conversion.append("#")
        next = scalars.next()
      }
      var modifier: Unicode.Scalar? = nil
      if let candidate = next, candidate == "E" || candidate == "O" {
        modifier = candidate
        conversion.append(candidate)
        next = scalars.next()
      }
      guard let letter = next else {
        // A format that ends in the middle of a conversion.
        result.append(contentsOf: Self._escaped(conversion))
        break
      }
      conversion.append(letter)
      let isPlain = conversion.count == 2
      if isPlain, let replacement = _zoneConversion(letter) {
        result.append(contentsOf: replacement.unicodeScalars)
      } else if Self._isSupportedConversion(letter, modifier: modifier) {
        result.append(contentsOf: conversion)
      } else {
        result.append(contentsOf: Self._escaped(conversion))
      }
    }
    return String(result)
  }

  // The time's own %z, %Z, or %s, as a format; nil for any other letter.
  private func _zoneConversion(_ letter: Unicode.Scalar) -> String? {
    switch letter {
    case "z":
      return _utcOffsetText
    case "Z":
      // As a format, where % stands for itself only when doubled.
      var escaped = String.UnicodeScalarView()
      for scalar in (timeZoneAbbreviation ?? "").unicodeScalars {
        escaped.append(scalar)
        if scalar == "%" { escaped.append(scalar) }
      }
      return String(escaped)
    case "s":
      let (seconds, overflow) = _secondsAsUTC!.subtractingReportingOverflow(
        Int64(utcOffset))
      return overflow ? "%%s" : String(seconds)
    default:
      return nil
    }
  }

  // Whether the C runtime's strftime supports a conversion: C99's letters,
  // and the E and O modifiers for the letters C99 allows them with.
  internal static func _isSupportedConversion(
    _ letter: Unicode.Scalar, modifier: Unicode.Scalar?
  ) -> Bool {
    switch modifier {
    case "E"?: return "cCxXyY".unicodeScalars.contains(letter)
    case "O"?: return "deHImMSuUVwWy".unicodeScalars.contains(letter)
    default: return "aAbBcCdDeFgGhHIjmMnprRStTuUVwWxXyYzZ%".unicodeScalars.contains(letter)
    }
  }

  // A conversion that prints as it's written: its % doubled.
  private static func _escaped(_ conversion: String.UnicodeScalarView) -> String.UnicodeScalarView {
    var escaped = String.UnicodeScalarView(["%"])
    escaped.append(contentsOf: conversion)
    return escaped
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

#endif // os(Windows)
