/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)

/// The system's load average: how many threads were running
/// or ready to run, on average, over the last 1, 5, and 15 minutes.
///
///     let load = try LoadAverage.current()
///     let cores = try SystemConfig.value(.processorsOnline) ?? 1
///     if load.oneMinute > Double(cores) { print("busy") }
///
/// Compare a load with the number of processors:
/// a load of 4 keeps four processors busy,
/// and on two of them, half the work waits.
/// Linux counts threads waiting for disk I/O in the load too.
///
/// - Note: Only available on Darwin, Linux, FreeBSD, and OpenBSD.
@frozen
@available(System 199, *)
public struct LoadAverage: Hashable, Sendable {
  /// The average over the last minute.
  public var oneMinute: Double

  /// The average over the last 5 minutes.
  public var fiveMinutes: Double

  /// The average over the last 15 minutes.
  public var fifteenMinutes: Double

  /// Creates a load average from its three averages.
  @_alwaysEmitIntoClient
  public init(oneMinute: Double, fiveMinutes: Double, fifteenMinutes: Double) {
    self.oneMinute = oneMinute
    self.fiveMinutes = fiveMinutes
    self.fifteenMinutes = fifteenMinutes
  }
}

@available(System 199, *)
extension LoadAverage {
  /// Returns the system's load average now.
  ///
  /// The system recomputes its averages every few seconds,
  /// so calls close together can return the same values.
  /// If the system can't report them, such as on Linux without `/proc`,
  /// this method throws the error that stopped it,
  /// or ``Errno/ioError`` if the C library reports none.
  ///
  /// The corresponding C function is `getloadavg`.
  @_alwaysEmitIntoClient
  public static func current() throws(Errno) -> LoadAverage {
    try _current().get()
  }

  @usableFromInline
  internal static func _current() -> Result<LoadAverage, Errno> {
    var samples: (Double, Double, Double) = (0, 0, 0)
    system_errno = 0
    let count = withUnsafeMutableBytes(of: &samples) {
      system_getloadavg($0.baseAddress!.assumingMemoryBound(to: Double.self), 3)
    }
    // getloadavg returns how many averages it stored, or -1 when it can't
    // read them, with errno from the call that failed, if any.
    guard count == 3 else {
      return .failure(count < 0 && system_errno != 0 ? .current : .ioError)
    }
    return .success(
      LoadAverage(oneMinute: samples.0, fiveMinutes: samples.1, fifteenMinutes: samples.2))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(FreeBSD) || os(OpenBSD)
