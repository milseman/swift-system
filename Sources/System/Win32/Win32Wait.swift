/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Waiting on a handle, for the owners whose objects become signaled and
// stay so, as a process or a thread does when it exits.

/// `duration` in whole milliseconds, rounded up so that a wait lasts at
/// least as long, and saturating at `UInt64.max`. A duration of zero or less
/// is zero.
internal func _win32Milliseconds(roundingUp duration: Duration) -> UInt64 {
  // The components share the duration's sign.
  let (seconds, attoseconds) = duration.components
  guard seconds > 0 || (seconds == 0 && attoseconds > 0) else { return 0 }
  let (whole, overflow) = UInt64(seconds).multipliedReportingOverflow(by: 1000)
  guard !overflow else { return .max }
  // A millisecond is 10^15 attoseconds.
  let fraction = UInt64((attoseconds + 999_999_999_999_999) / 1_000_000_000_000_000)
  let (total, sumOverflow) = whole.addingReportingOverflow(fraction)
  return sumOverflow ? .max : total
}

@available(System 199, *)
extension Win32 {
  /// Waits until `handle`'s object is signaled, for at most `timeout`, or
  /// with no limit if it's `nil`, and returns whether it was signaled.
  ///
  /// `WaitForSingleObject` takes a time-out of just under 50 days, since
  /// `INFINITE` is `DWORD.max`, so a longer one waits in parts.
  @usableFromInline
  internal static func _wait(
    _ handle: HANDLE, timeout: Duration?
  ) -> Result<Bool, Win32.Error> {
    guard let timeout else { return _waitOnce(handle, milliseconds: _INFINITE) }
    var remaining = _win32Milliseconds(roundingUp: timeout)
    while true {
      let part = DWORD(min(remaining, UInt64(_INFINITE - 1)))
      let result = _waitOnce(handle, milliseconds: part)
      guard case .success(false) = result, remaining > UInt64(part) else {
        return result
      }
      remaining -= UInt64(part)
    }
  }

  internal static func _waitOnce(
    _ handle: HANDLE, milliseconds: DWORD
  ) -> Result<Bool, Win32.Error> {
    switch system_WaitForSingleObject(handle, milliseconds) {
    case _WAIT_OBJECT_0:
      return .success(true)
    case _WAIT_TIMEOUT:
      return .success(false)
    case _WAIT_FAILED:
      return .failure(Win32.Error(GetLastError()))
    default:
      // WAIT_ABANDONED, which only a mutex reports, and which acquires it.
      return .success(true)
    }
  }
}

#endif // os(Windows)
