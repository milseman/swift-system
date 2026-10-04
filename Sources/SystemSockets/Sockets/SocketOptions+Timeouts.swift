/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(WASI)

import SystemPackage

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

// MARK: - Socket-Level Option Names

@available(System 199, *)
extension SocketDescriptor.SocketOption {
  /// The time a receive waits before failing.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public static var receiveTimeout: Self { Self(rawValue: SO_RCVTIMEO) }

  /// The time a send waits before failing.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public static var sendTimeout: Self { Self(rawValue: SO_SNDTIMEO) }

  /// Whether the socket receives the time each datagram arrived,
  /// as an ancillary message.
  ///
  /// The corresponding C constant is `SO_TIMESTAMP`.
  @_alwaysEmitIntoClient
  public static var timestamp: Self { Self(rawValue: SO_TIMESTAMP) }

  #if SYSTEM_PACKAGE_DARWIN
  /// Linger on close if data is present, with a time in seconds.
  ///
  /// Darwin's ``linger`` measures its time in clock ticks,
  /// hundredths of a second, rather than seconds.
  ///
  /// The corresponding C constant is `SO_LINGER_SEC`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var lingerSeconds: Self { Self(rawValue: SO_LINGER_SEC) }
  #endif
}

// MARK: - Timeouts, Linger, and Timestamps

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SocketDescriptor {
  /// Returns how long a receive waits for data before it fails
  /// with ``Errno/wouldBlock``, or `nil` if it waits indefinitely.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public func receiveTimeout() throws(Errno) -> Duration? {
    try _timeout(SocketOption.receiveTimeout.rawValue).get()
  }

  /// Sets how long a receive waits for data before it fails
  /// with ``Errno/wouldBlock``,
  /// or `nil` to have it wait indefinitely, the default.
  ///
  /// A receive that has received some data returns it when the time runs out.
  /// The time is rounded up to a microsecond,
  /// so a duration of zero or less times out at once,
  /// rather than meaning no timeout, as C's zero does.
  ///
  /// The corresponding C constant is `SO_RCVTIMEO`.
  @_alwaysEmitIntoClient
  public func setReceiveTimeout(_ timeout: Duration?) throws(Errno) {
    try _setTimeout(SocketOption.receiveTimeout.rawValue, timeout).get()
  }

  /// Returns how long a send waits for room before it fails
  /// with ``Errno/wouldBlock``, or `nil` if it waits indefinitely.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public func sendTimeout() throws(Errno) -> Duration? {
    try _timeout(SocketOption.sendTimeout.rawValue).get()
  }

  /// Sets how long a send waits for room before it fails
  /// with ``Errno/wouldBlock``,
  /// or `nil` to have it wait indefinitely, the default.
  ///
  /// A send that has sent some data returns its count when the time runs out.
  /// The time is rounded up to a microsecond,
  /// so a duration of zero or less times out at once,
  /// rather than meaning no timeout, as C's zero does.
  ///
  /// The corresponding C constant is `SO_SNDTIMEO`.
  @_alwaysEmitIntoClient
  public func setSendTimeout(_ timeout: Duration?) throws(Errno) {
    try _setTimeout(SocketOption.sendTimeout.rawValue, timeout).get()
  }

  @usableFromInline
  internal func _timeout(_ name: CInt) -> Result<Duration?, Errno> {
    _value(OptionLevel.socket.rawValue, name, timeval()).map { value in
      guard value.tv_sec != 0 || value.tv_usec != 0 else { return nil }
      return .seconds(Int64(value.tv_sec)) + .microseconds(Int64(value.tv_usec))
    }
  }

  @usableFromInline
  internal func _setTimeout(_ name: CInt, _ timeout: Duration?) -> Result<Void, Errno> {
    var value = timeval()
    if let timeout {
      if timeout <= .zero {
        // C's zero is no timeout; the shortest timeout is a microsecond.
        value.tv_usec = 1
      } else {
        // A positive duration's components are both nonnegative.
        let (seconds, attoseconds) = timeout.components
        var microseconds = attoseconds / 1_000_000_000_000
        if attoseconds % 1_000_000_000_000 > 0 { microseconds += 1 }
        value.tv_sec = .init(seconds + microseconds / 1_000_000)
        value.tv_usec = .init(microseconds % 1_000_000)
      }
    }
    return _setValue(OptionLevel.socket.rawValue, name, value)
  }

  /// Returns how long closing the socket waits for unsent data to be sent,
  /// or `nil` if closing returns at once and the system sends it afterward,
  /// the default.
  ///
  /// The corresponding C constant is `SO_LINGER`,
  /// or on Darwin `SO_LINGER_SEC`.
  /// The corresponding C type is `struct linger`.
  @_alwaysEmitIntoClient
  public func linger() throws(Errno) -> Duration? {
    try _linger().get()
  }

  /// Sets how long closing the socket waits for unsent data to be sent,
  /// or `nil` to have closing return at once and the system send it
  /// afterward, the default.
  ///
  /// When the time runs out, closing discards what's left.
  /// A time of zero discards it at once,
  /// and resets a TCP connection rather than closing it in order.
  /// The time is rounded up to a whole second.
  ///
  /// The corresponding C constant is `SO_LINGER`,
  /// or on Darwin `SO_LINGER_SEC`, whose time is in seconds,
  /// where `SO_LINGER`'s is in hundredths of a second.
  /// The corresponding C type is `struct linger`.
  @_alwaysEmitIntoClient
  public func setLinger(_ timeout: Duration?) throws(Errno) {
    try _setLinger(timeout).get()
  }

  @usableFromInline
  internal static var _lingerName: CInt {
    #if SYSTEM_PACKAGE_DARWIN
    SO_LINGER_SEC
    #else
    SO_LINGER
    #endif
  }

  @usableFromInline
  internal func _linger() -> Result<Duration?, Errno> {
    _value(OptionLevel.socket.rawValue, Self._lingerName, CInterop.Linger()).map { value in
      value.l_onoff == 0 ? nil : .seconds(Int64(value.l_linger))
    }
  }

  @usableFromInline
  internal func _setLinger(_ timeout: Duration?) -> Result<Void, Errno> {
    var value = CInterop.Linger()
    if let timeout {
      value.l_onoff = 1
      if timeout > .zero {
        // A positive duration's components are both nonnegative.
        let (seconds, attoseconds) = timeout.components
        value.l_linger = CInt(clamping: seconds + (attoseconds > 0 ? 1 : 0))
      }
    }
    return _setValue(OptionLevel.socket.rawValue, Self._lingerName, value)
  }

  /// Returns whether the socket receives the time each datagram arrived,
  /// which ``AncillaryMessageBuffer/Message/timestamp`` reads.
  ///
  /// The corresponding C constant is `SO_TIMESTAMP`.
  @_alwaysEmitIntoClient
  public func receivesTimestamps() throws(Errno) -> Bool {
    try _flag(OptionLevel.socket.rawValue, SocketOption.timestamp.rawValue).get()
  }

  /// Sets whether the socket receives the time each datagram arrived,
  /// as an ancillary message
  /// that ``AncillaryMessageBuffer/Message/timestamp`` reads.
  ///
  /// The corresponding C constant is `SO_TIMESTAMP`.
  @_alwaysEmitIntoClient
  public func setReceivesTimestamps(_ enabled: Bool) throws(Errno) {
    try _setFlag(OptionLevel.socket.rawValue, SocketOption.timestamp.rawValue, enabled).get()
  }
}

#endif // !os(WASI)
