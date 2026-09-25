/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Conversions from Duration to the timeouts that the event notification
// calls take. Each rounds up, so that a positive timeout doesn't become zero,
// which means "don't wait".

#if !os(Windows) && !os(WASI)

// Must import here to use the C timespec type in @_alwaysEmitIntoClient code.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// The longest timeout that kevent accepts everywhere: Darwin's kevent rejects
// one of more than 2^31 - 1 seconds with EINVAL, and older Darwin kernels
// limit timers to this many seconds, which is over three years.
@_alwaysEmitIntoClient
internal var _maximumTimeoutSeconds: Int64 { 100_000_000 }

/// Converts a timeout to a `timespec`,
/// clamping it to between zero and `_maximumTimeoutSeconds`.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@_alwaysEmitIntoClient
internal func _timespec(timeout: Duration) -> timespec {
  guard timeout > .zero else { return timespec(tv_sec: 0, tv_nsec: 0) }
  var (seconds, nanoseconds) = _nanosecondComponents(timeout)
  if seconds >= _maximumTimeoutSeconds {
    (seconds, nanoseconds) = (_maximumTimeoutSeconds, 0)
  }
  return timespec(tv_sec: .init(seconds), tv_nsec: .init(nanoseconds))
}

/// Splits a nonnegative duration into seconds and nanoseconds,
/// rounding up to a whole nanosecond.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@_alwaysEmitIntoClient
internal func _nanosecondComponents(
  _ duration: Duration
) -> (seconds: Int64, nanoseconds: Int64) {
  let (seconds, attoseconds) = duration.components
  let nanoseconds = (attoseconds + 999_999_999) / 1_000_000_000
  guard nanoseconds == 1_000_000_000 else { return (seconds, nanoseconds) }
  return (seconds == .max ? .max : seconds + 1, 0)
}
#endif // !os(Windows) && !os(WASI)
