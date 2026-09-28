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

/// The scheduling priority of processes, which is their nice value.
///
/// A nice value runs from -20, the most favored,
/// to 19 on Linux or 20 on Darwin, the least favored; the default is 0.
/// A process can make itself or its user's other processes nicer,
/// which favors them less.
/// Lowering a nice value takes privilege.
///
///     // Run a batch job at a low priority.
///     try ProcessPriority.setCurrent(10, for: .process(.current))
///
/// A child process inherits its parent's nice value.
@available(System 199, *)
public enum ProcessPriority {}

@available(System 199, *)
extension ProcessPriority {
  /// The processes whose priority to get or set.
  @frozen
  public enum Target: Hashable, Sendable {
    /// A process.
    ///
    /// The corresponding C constant is `PRIO_PROCESS`.
    case process(ProcessID)

    /// Each process in a process group, which is named by its leader's ID.
    ///
    /// The corresponding C constant is `PRIO_PGRP`.
    case processGroup(ProcessID)

    /// Each of a user's processes.
    ///
    /// The corresponding C constant is `PRIO_USER`.
    case user(UserID)

    @usableFromInline
    internal var _which: CInt {
      switch self {
      case .process: return _PRIO_PROCESS
      case .processGroup: return _PRIO_PGRP
      case .user: return _PRIO_USER
      }
    }

    @usableFromInline
    internal var _who: id_t {
      switch self {
      case .process(let process), .processGroup(let process):
        return id_t(bitPattern: process.rawValue)
      case .user(let user):
        return id_t(user.rawValue)
      }
    }
  }

  /// Returns the nice value of a process, or of a group's or user's
  /// processes.
  ///
  /// - Parameter target: The processes whose nice value to get.
  /// - Returns: The nice value, or for a process group or a user,
  ///   the lowest nice value, the most favored, of its processes.
  ///
  /// If there's no such process, this method throws
  /// ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `getpriority`.
  @_alwaysEmitIntoClient
  public static func current(for target: Target) throws(Errno) -> Int {
    try _current(for: target).get()
  }

  @usableFromInline
  internal static func _current(for target: Target) -> Result<Int, Errno> {
    // -1 is a nice value, so only errno says whether the call failed.
    system_errno = 0
    let priority = system_getpriority(target._which, target._who)
    if priority == -1 && system_errno != 0 { return .failure(Errno.current) }
    return .success(Int(priority))
  }

  /// Sets the nice value of a process, or of each of a group's or user's
  /// processes.
  ///
  /// - Parameters:
  ///   - priority: The nice value, which the system limits
  ///     to the range it supports.
  ///   - target: The processes whose nice value to set.
  ///
  /// Lowering a nice value without privilege throws
  /// ``Errno/permissionDenied``,
  /// and setting another user's process's throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `setpriority`.
  @_alwaysEmitIntoClient
  public static func setCurrent(_ priority: Int, for target: Target) throws(Errno) {
    try _setCurrent(priority, for: target).get()
  }

  @usableFromInline
  internal static func _setCurrent(_ priority: Int, for target: Target) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_setpriority(target._which, target._who, CInt(clamping: priority))
    }
  }

  /// Adds to the calling process's nice value.
  ///
  /// - Parameter increment: The amount to add,
  ///   which is negative to lower the nice value and favor the process more.
  /// - Returns: The new nice value.
  ///
  /// The system limits the result to the range it supports;
  /// Darwin's limit for this call is 19, where
  /// ``setCurrent(_:for:)`` allows 20.
  /// Lowering the nice value without privilege throws
  /// ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `nice`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func adjust(by increment: Int) throws(Errno) -> Int {
    try _adjust(by: increment).get()
  }

  @usableFromInline
  internal static func _adjust(by increment: Int) -> Result<Int, Errno> {
    // -1 is a nice value, so only errno says whether the call failed.
    system_errno = 0
    let priority = system_nice(CInt(clamping: increment))
    if priority == -1 && system_errno != 0 { return .failure(Errno.current) }
    return .success(Int(priority))
  }
}

#endif // !os(Windows) && !os(WASI)
