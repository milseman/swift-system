/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The resources that the calling process, or its children, have used:
// getrusage. Its result is the C structure, with the accessors in
// CInterop+Accessors.swift.

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
extension ProcessID {
  /// The processes whose resource usage ``resourceUsage(of:)`` reports.
  @frozen
  public struct ResourceUsageScope: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a scope from its raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// The calling process, with all of its threads.
    ///
    /// The corresponding C constant is `RUSAGE_SELF`.
    @_alwaysEmitIntoClient
    public static var current: Self { Self(rawValue: _RUSAGE_SELF) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "current")
    public static var RUSAGE_SELF: Self { current }

    /// The calling process's children that have ended
    /// and that it has waited for,
    /// with the descendants that they waited for in turn.
    ///
    /// The corresponding C constant is `RUSAGE_CHILDREN`.
    @_alwaysEmitIntoClient
    public static var children: Self { Self(rawValue: _RUSAGE_CHILDREN) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "children")
    public static var RUSAGE_CHILDREN: Self { children }
  }

  /// Returns the resources, such as processor time and memory,
  /// that the calling process or its waited-for children have used.
  ///
  ///     let usage = try ProcessID.resourceUsage(of: .current)
  ///     print("at most \(usage.maxResidentSetSize) bytes in memory")
  ///
  /// The corresponding C function is `getrusage`.
  @_alwaysEmitIntoClient
  public static func resourceUsage(
    of scope: ResourceUsageScope = .current
  ) throws(Errno) -> CInterop.ResourceUsage {
    try _resourceUsage(of: scope).get()
  }

  @usableFromInline
  internal static func _resourceUsage(
    of scope: ResourceUsageScope
  ) -> Result<CInterop.ResourceUsage, Errno> {
    var usage = CInterop.ResourceUsage()
    return nothingOrErrno(retryOnInterrupt: false) {
      system_getrusage(scope.rawValue, &usage)
    }.map { usage }
  }
}

#endif // !os(Windows) && !os(WASI)
