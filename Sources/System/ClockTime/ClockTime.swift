/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

@available(System 199, *)
extension CInterop {
  /// A calendar time: whole seconds since the Unix epoch.
  ///
  /// The corresponding C type is `time_t`.
  public typealias Time = time_t
}

@available(System 199, *)
extension ClockID {
  /// Returns the clock's current time, as C gives it.
  ///
  /// - Returns: The time since the clock's epoch,
  ///   in seconds and nanoseconds.
  ///
  /// This is ``currentTime()``'s reading, without its `Duration`,
  /// which needs macOS 13, iOS 16, watchOS 9, or tvOS 16:
  /// on earlier releases, ``realtime``'s is the time of day
  /// that `gettimeofday` gives, to a microsecond.
  ///
  /// The corresponding C function is `clock_gettime`.
  @_alwaysEmitIntoClient
  public func currentTimeSpec() throws(Errno) -> CInterop.TimeSpec {
    try _currentTimeSpec().get()
  }

  @usableFromInline
  internal func _currentTimeSpec() -> Result<CInterop.TimeSpec, Errno> {
    var time = timespec()
    // clock_gettime can't be interrupted.
    return nothingOrErrno(retryOnInterrupt: false) {
      system_clock_gettime(rawValue, &time)
    }.map { time }
  }
}

#endif // !os(Windows) && !os(WASI)
