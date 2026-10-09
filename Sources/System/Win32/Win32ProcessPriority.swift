/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// A process's priority class: the base from which Windows computes its
// threads' scheduling priorities, as POSIX's nice value is for a process's.

@available(System 199, *)
extension Win32 {
  /// A process's priority class, which, with each thread's priority within
  /// it, decides how Windows schedules the process's threads.
  ///
  /// `SetPriorityClass` takes one in its `dwPriorityClass` parameter, and
  /// `CreateProcessW` in its `dwCreationFlags`.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct PriorityClass: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C priority class.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed priority class from a raw C one.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Threads run only when the system is otherwise idle, as a screen
    /// saver's do.
    ///
    /// The corresponding C constant is `IDLE_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var idle: PriorityClass { PriorityClass(rawValue: 0x0000_0040) }

    /// Between ``idle`` and ``normal``.
    ///
    /// The corresponding C constant is `BELOW_NORMAL_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var belowNormal: PriorityClass { PriorityClass(rawValue: 0x0000_4000) }

    /// The priority class of a process with no special scheduling needs,
    /// and the default.
    ///
    /// The corresponding C constant is `NORMAL_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var normal: PriorityClass { PriorityClass(rawValue: 0x0000_0020) }

    /// Between ``normal`` and ``high``.
    ///
    /// The corresponding C constant is `ABOVE_NORMAL_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var aboveNormal: PriorityClass { PriorityClass(rawValue: 0x0000_8000) }

    /// For time-critical work, whose threads preempt those of the classes
    /// below.
    ///
    /// The corresponding C constant is `HIGH_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var high: PriorityClass { PriorityClass(rawValue: 0x0000_0080) }

    /// The highest class, whose threads preempt the system's own, such as
    /// those that handle input. Setting it needs the increase base priority
    /// privilege; without it, Windows sets ``high``.
    ///
    /// The corresponding C constant is `REALTIME_PRIORITY_CLASS`.
    @_alwaysEmitIntoClient
    public static var realtime: PriorityClass { PriorityClass(rawValue: 0x0000_0100) }
  }
}

@available(System 199, *)
extension Win32.ProcessHandle {
  /// The process's priority class.
  ///
  /// Needs ``Win32/ProcessAccess/queryLimitedInformation`` or
  /// ``Win32/ProcessAccess/queryInformation``.
  ///
  /// The corresponding C function is `GetPriorityClass`.
  @_alwaysEmitIntoClient
  public func priorityClass() throws(Win32.Error) -> Win32.PriorityClass {
    Win32.PriorityClass(rawValue: try Win32._priorityClass(_handle).get())
  }

  /// Sets the process's priority class.
  ///
  /// Needs ``Win32/ProcessAccess/setInformation``.
  ///
  /// The corresponding C function is `SetPriorityClass`.
  @_alwaysEmitIntoClient
  public func setPriorityClass(_ priorityClass: Win32.PriorityClass) throws(Win32.Error) {
    try Win32._setPriorityClass(_handle, priorityClass.rawValue).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _priorityClass(_ process: HANDLE) -> Result<DWORD, Win32.Error> {
    // 0 is no class, and reports a failure.
    let priorityClass = system_GetPriorityClass(process)
    guard priorityClass != 0 else { return .failure(Win32.Error(GetLastError())) }
    return .success(priorityClass)
  }

  @usableFromInline
  internal static func _setPriorityClass(
    _ process: HANDLE, _ priorityClass: DWORD
  ) -> Result<Void, Win32.Error> {
    guard system_SetPriorityClass(process, priorityClass) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
