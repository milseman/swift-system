//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows)
/// A Swift wrapper of the C `pid_t` type.
@frozen
public struct ProcessID: RawRepresentable, Sendable, Hashable, Codable {

  /// The raw C `pid_t`.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.ProcessID

  /// Creates a strongly-typed `ProcessID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.ProcessID) { self.rawValue = rawValue }

  /// Creates a strongly-typed `ProcessID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.ProcessID) { self.rawValue = rawValue }
}

#if !os(WASI)
extension ProcessID {
  /// The process ID of the calling process.
  ///
  /// The corresponding C function is `getpid()`.
  @_alwaysEmitIntoClient
  public static var current: ProcessID { ProcessID(rawValue: _getpid()) }

  /// The process ID of the parent of the calling process.
  ///
  /// The corresponding C function is `getppid()`.
  @_alwaysEmitIntoClient
  public static var parent: ProcessID { ProcessID(rawValue: _getppid()) }

  @usableFromInline
  internal static func _getpid() -> CInterop.ProcessID {
    system_getpid()
  }

  @usableFromInline
  internal static func _getppid() -> CInterop.ProcessID {
    system_getppid()
  }
}
#endif // !os(WASI)
#endif // !os(Windows)
