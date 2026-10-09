/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// MARK: - Socket-Level Option Names

@available(System 199, *)
extension SocketDescriptor.SocketOption {
  /// The time a receive waits before failing.
  ///
  /// Its value is a `DWORD` of milliseconds on Windows, where POSIX's is a
  /// `timeval`.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public static var receiveTimeout: Self { Self(rawValue: 0x1006) }

  /// The time a send waits before failing.
  ///
  /// Its value is a `DWORD` of milliseconds on Windows, where POSIX's is a
  /// `timeval`.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public static var sendTimeout: Self { Self(rawValue: 0x1005) }
}

// MARK: - Timeouts and Linger

@available(System 199, *)
extension SocketDescriptor {
  /// Returns how long a receive waits for data before it fails
  /// with ``Win32/Error/timedOut``, or `nil` if it waits indefinitely.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public func receiveTimeout() throws(Win32.Error) -> Duration? {
    try _timeout(SocketOption.receiveTimeout.rawValue).get()
  }

  /// Sets how long a receive waits for data before it fails
  /// with ``Win32/Error/timedOut``,
  /// or `nil` to have it wait indefinitely, the default.
  ///
  /// The time is rounded up to a millisecond, Winsock's unit,
  /// so a duration of zero or less times out at once,
  /// rather than meaning no timeout, as C's zero does.
  ///
  /// Winsock reports a time-out as `WSAETIMEDOUT`, where POSIX reports
  /// `EWOULDBLOCK`, and a receive that timed out leaves the socket in an
  /// indeterminate state, which Winsock says not to use further.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public func setReceiveTimeout(_ timeout: Duration?) throws(Win32.Error) {
    try _setTimeout(SocketOption.receiveTimeout.rawValue, timeout).get()
  }

  /// Returns how long a send waits for room before it fails
  /// with ``Win32/Error/timedOut``, or `nil` if it waits indefinitely.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public func sendTimeout() throws(Win32.Error) -> Duration? {
    try _timeout(SocketOption.sendTimeout.rawValue).get()
  }

  /// Sets how long a send waits for room before it fails
  /// with ``Win32/Error/timedOut``,
  /// or `nil` to have it wait indefinitely, the default.
  ///
  /// The time is rounded up to a millisecond, Winsock's unit,
  /// so a duration of zero or less times out at once,
  /// rather than meaning no timeout, as C's zero does.
  ///
  /// As with ``setReceiveTimeout(_:)``, a send that timed out leaves the
  /// socket in an indeterminate state.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public func setSendTimeout(_ timeout: Duration?) throws(Win32.Error) {
    try _setTimeout(SocketOption.sendTimeout.rawValue, timeout).get()
  }

  @usableFromInline
  internal func _timeout(_ name: CInt) -> Result<Duration?, Win32.Error> {
    _value(OptionLevel.socket.rawValue, name, DWORD(0)).map { milliseconds in
      milliseconds == 0 ? nil : .milliseconds(Int64(milliseconds))
    }
  }

  @usableFromInline
  internal func _setTimeout(_ name: CInt, _ timeout: Duration?) -> Result<Void, Win32.Error> {
    var milliseconds: DWORD = 0
    if let timeout {
      if timeout <= .zero {
        // C's zero is no timeout; the shortest timeout is a millisecond.
        milliseconds = 1
      } else {
        // A positive duration's components are both nonnegative.
        let (seconds, attoseconds) = timeout.components
        var total = attoseconds / 1_000_000_000_000_000
        if attoseconds % 1_000_000_000_000_000 > 0 { total += 1 }
        let (scaled, overflow) = seconds.multipliedReportingOverflow(by: 1000)
        let (sum, sumOverflow) = scaled.addingReportingOverflow(total)
        milliseconds = overflow || sumOverflow ? DWORD.max : DWORD(clamping: sum)
      }
    }
    return _setValue(OptionLevel.socket.rawValue, name, milliseconds)
  }

  /// Returns how long closing the socket waits for unsent data to be sent,
  /// or `nil` if closing returns at once and the system sends it afterward,
  /// the default.
  ///
  /// The corresponding C constant is `SO_LINGER`.
  /// The corresponding C type is `LINGER`.
  @_alwaysEmitIntoClient
  public func linger() throws(Win32.Error) -> Duration? {
    try _linger().get()
  }

  /// Sets how long closing the socket waits for unsent data to be sent,
  /// or `nil` to have closing return at once and the system send it
  /// afterward, the default.
  ///
  /// When the time runs out, closing discards what's left.
  /// A time of zero discards it at once,
  /// and resets a TCP connection rather than closing it in order.
  /// The time is rounded up to a whole second, and is at most 65,535
  /// seconds, since Winsock's field is a `u_short`. On a nonblocking
  /// socket, a time other than zero makes ``close()`` throw
  /// ``Win32/Error/wouldBlock`` while data remains, leaving the socket open.
  ///
  /// The corresponding C constant is `SO_LINGER`.
  /// The corresponding C type is `LINGER`.
  @_alwaysEmitIntoClient
  public func setLinger(_ timeout: Duration?) throws(Win32.Error) {
    try _setLinger(timeout).get()
  }

  @usableFromInline
  internal func _linger() -> Result<Duration?, Win32.Error> {
    _value(OptionLevel.socket.rawValue, SocketOption.linger.rawValue, CInterop.Linger()).map {
      value in
      value.l_onoff == 0 ? nil : .seconds(Int64(value.l_linger))
    }
  }

  @usableFromInline
  internal func _setLinger(_ timeout: Duration?) -> Result<Void, Win32.Error> {
    var value = CInterop.Linger()
    if let timeout {
      value.l_onoff = 1
      if timeout > .zero {
        // A positive duration's components are both nonnegative.
        let (seconds, attoseconds) = timeout.components
        let rounded = attoseconds > 0 && seconds < Int64(u_short.max) ? seconds + 1 : seconds
        value.l_linger = u_short(clamping: rounded)
      }
    }
    return _setValue(OptionLevel.socket.rawValue, SocketOption.linger.rawValue, value)
  }
}

#endif // os(Windows)
