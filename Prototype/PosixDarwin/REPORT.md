# posix-darwin: more POSIX and Darwin API, breadth first

The `posix-darwin` lane adds POSIX and Darwin calls that System still lacks,
in the queue's order: a correct, tested, documented wrapper per call, in the
package's patterns. One section per cluster, appended as each is committed:
the API, the design calls with the alternatives they rejected, what was found
on the way, the adopter code it replaces, and what couldn't be checked here.

All new API is `@available(System 199, *)`, throws `Errno` (typed), and says
"The corresponding C function is `x`." Darwin comes first. Linux is paused:
code for other platforms is written from their headers and gated with care,
but nothing here builds it, so every non-Darwin branch is unverified.

**To resume:** read the last section. The lane's rules: new directories under
`Sources/System/`, `Internals/Syscalls+<Cluster>.swift` and
`Constants+<Cluster>.swift`, new tests and samples; the shared files
(`Sources/System/CMakeLists.txt`, CSystem, `Sources/Samples/main.swift`,
where the lane's group is "More POSIX and Darwin samples") only in sorted
position; grep `Sources/` and `Tests/` for every new name, and the four
adopters for every new public top-level name. After each cluster:
`swift build && swift test`, the duplicate check, a commit, and a section
here. Not this lane's: the malloc family and `Sources/System/Memory/`,
sockets, processes, spawn and signals, and anything Linux-only.

## Baseline

`system-next` at `620808f`, macOS 26.3, Swift 6.2 (swiftlang-6.2.0.19.9):
442 XCTests (4 skipped) and 373 swift-testing tests in 57 suites.
`KernelQueueTests.testOneShotTimer` fails now and then in a full run (a
10 ms one-shot timer reports 4 or 10 expirations instead of 1) and passes
alone; it isn't this lane's.

## 1. Broken-down time

`Sources/System/BrokenDownTime/BrokenDownTime.swift`,
`Sources/System/Internals/Syscalls+BrokenDownTime.swift`; the `date` sample.

| API | C |
|---|---|
| `BrokenDownTime`: `year`, `month`, `day`, `hour`, `minute`, `second`, `isDaylightSavingTime: Bool?`, `utcOffset`, `timeZoneAbbreviation: String?`, and a memberwise `init` | `struct tm` |
| `weekday: BrokenDownTime.Weekday` (`.sunday` … `.saturday`), `dayOfYear` | `tm_wday`, `tm_yday` |
| `BrokenDownTime.Zone`: `.utc`, `.local` | |
| `init(secondsSinceEpoch:in:) throws(Errno)` | `gmtime_r`; `tzset` and `localtime_r` |
| `secondsSinceEpoch(in:) throws(Errno) -> Int` | `timegm`, `mktime` |
| `normalized(in:) throws(Errno) -> BrokenDownTime` | `timegm`, `mktime` |
| `formatted(_:) -> String` | `strftime` |

Design calls:

- **The type is `BrokenDownTime`**, POSIX's name for what `struct tm` holds
  ("convert … into a broken-down time"). Rejected: `CalendarTime`, which is
  C's name for the opposite, `time_t`; `DateComponents`, `Calendar` and
  `TimeZone`, which are Foundation's; and a wrapper of `struct tm` with a
  `rawValue`, as `Stat` is, whose `tm_zone` pointer would dangle.
- **Fields count the way people do**: `year` is the year (2026, not 126),
  and `month`, `day` and `dayOfYear` start at 1. The 1900 offset and the
  0-based month are the classic `struct tm` bugs. Each field's documentation
  names the C field and its convention.
- **`weekday` and `dayOfYear` are computed** from the other fields, by exact
  64-bit arithmetic (Hinnant's `days_from_civil`), so they're never out of
  date: C's are stale after any change to the other fields until `mktime`
  runs, and `strftime` prints them anyway. Rejected: storing them as C does.
  Tests compare the computation with `gmtime_r` and `timegm` over 4,000
  random values, many of them out of range.
- **`Weekday` is an enum** with C's raw values (days since Sunday). A number
  would carry one of three conventions (C's 0 = Sunday, Foundation's
  1 = Sunday, ISO's 1 = Monday).
- **`isDaylightSavingTime` is `Bool?`**, for C's positive, zero and negative,
  and it stays an input to `mktime`, as in C: that's what makes a round trip
  of the hour that repeats when clocks go back exact. Its documentation warns
  that a value left over from another date moves the time by an hour, and a
  test shows it. Rejected: ignoring the field and taking a `nil`-defaulting
  parameter, which is safer for arithmetic but breaks those round trips.
- **The time zone's abbreviation is copied into a `String`**: `tm_zone`
  points into the C library's storage, which the next `tzset` can change.
- **One `Zone` parameter picks `gmtime_r`/`localtime_r` and
  `timegm`/`mktime`**, since the C library knows only UTC and the local zone.
  Rejected: four separately named members (`init(utc:)`, `init(local:)`,
  `utcSeconds()`, `localSeconds()`), which spread one choice over four names;
  and a `TimeZone` type, which would shadow Foundation's.
- **Seconds are `Int`**, `time_t`'s width on every platform System builds
  for, converted with `exactly:` so a narrower `time_t` fails with
  `.overflow` rather than trapping. Rejected: `Duration`, which needs
  macOS 13 and carries fractions these calls ignore (and which truncate the
  wrong way before 1970).
- **The local conversion calls `tzset` first**, because glibc's
  `localtime_r` reads `TZ` only once, while `mktime` rereads it: without it,
  a program that changes `TZ` gets breakdowns and conversions in different
  zones. Darwin's `localtime_r` rereads `TZ` itself (checked).
- **-1 from `timegm` and `mktime` is checked against the fields**, not
  `errno`: -1 is also 1969-12-31 23:59:59 UTC, and on Darwin both calls fail
  without setting `errno`, while `timegm` sets `EOVERFLOW` when it succeeds
  (probed on macOS 26.3). A successful call normalizes the fields, and a
  failed one leaves them, so the fields say which happened. A failure throws
  the call's `errno`, or `.overflow` if it set none; fields that don't fit
  C's `int` throw `.overflow` without a call.
- **Darwin's `timegm` and `mktime` fail for every time before 1900**
  (found by the tests; `gmtime_r` and `localtime_r` break those times down).
  For UTC, a silent `timegm` failure falls back to the fields' own
  arithmetic, checked by `gmtime_r`, so UTC round trips work for any year.
  For local time the limit stays and is documented: working around it means
  reimplementing `mktime` over the zone's rules. Rejected: passing the UTC
  failure through, and computing UTC without `timegm` at all, which would
  diverge from glibc's `timegm` under a leap-second (`right/`) zone.
- **`normalized(in:)`** returns what `timegm` and `mktime` write back into
  their argument, which C gives for free: the fields carried into range and
  the zone's fields filled in. That's calendar arithmetic (`day += 7`).
- **`formatted(_:)` fills in `%z`, `%Z` and `%s` from the value's own
  fields.** Darwin's `strftime` prints the *local* zone's offset for `%z`,
  whatever `tm_gmtoff` says (a `gmtime_r` result prints `-0700` in Denver,
  as C99 and old POSIX specify and POSIX 2024 no longer does); Darwin and
  glibc fall back to the local zone's name for a missing `tm_zone`; and `%s`
  reads the fields as local time everywhere. A value carries its own offset
  and abbreviation, so formatting uses them: `%z` is `utcOffset` (always,
  where C prints nothing when `tm_isdst` is negative), `%Z` the abbreviation
  or nothing, and `%s` the fields less `utcOffset`. Only the plain
  conversions are replaced; `%%` and flagged forms such as `%-z` go to
  `strftime`. Rejected: passing the format through and documenting the
  differences.
- **`formatted` grows its buffer until the result fits**, and appends a space
  to the format (dropped afterward) so that the result is never empty: C's 0
  means both "too small" and "empty". It doesn't throw.
- **Fields that don't fit C's `int` trap in `weekday`, `dayOfYear` and
  `formatted`**, and throw `.overflow` from the conversions, which throw
  anyway. Rejected: making `formatted` throw, which would put a `try` on
  every call for years two billion years away.
- Not added: `strptime` (no adopter), `strftime_l` and other locales (the
  names come from the C library's locale, which the documentation says),
  `tzname`/`timezone`/`daylight`, and a `time()` convenience, since
  `ClockID.realtime.currentTime()` reads the same clock.

Adopters: Foundation's `Date.description` (`gmtime_r` and `strftime`, with
`+0000` written into the format rather than `%z`, which this API makes
unnecessary) and `TimeZone`'s current-zone lookup on Linux (`tzset`,
`localtime_r` and `tm_zone`, which becomes `timeZoneAbbreviation`). NIO,
SwiftPM and Subprocess don't convert times.

Unverified off Darwin: glibc's and Musl's `tm_gmtoff` and `tm_zone` (Musl's
spelling is a guess from Foundation's use of `tm_zone` on Linux), Bionic's
nullable `tm_zone`, the `const char *` versus `char *` setter, glibc's
leap-second behavior, and the claim that glibc's `mktime` moves a skipped
time forward.

Tests: `BrokenDownTimeTests` (swift-testing, UTC only),
`BrokenDownTimeZoneTests` (XCTest, since they set `TZ`), and
`BrokenDownTimeMockTests`. Totals after it: 453 XCTests (4 skipped) and 384
swift-testing tests in 58 suites, all passing but the flaky kqueue timer.
