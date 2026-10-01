/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// ProcessID on Windows, where a process ID is a DWORD rather than a pid_t.
// ProcessID.swift declares the type everywhere else.

@available(System 199, *)
extension CInterop {
  /// The C type of a process ID, which Windows spells `DWORD`.
  public typealias ProcessID = DWORD
}

/// A Swift wrapper of a Windows process ID, a `DWORD`.
///
/// An ID names a process from its creation until the last handle to it
/// closes, even after the process exits. After that, Windows can give the ID
/// to a new process, so to refer to one process, keep a
/// ``Win32/ProcessHandle`` open to it.
@frozen
@available(System 199, *)
public struct ProcessID: RawRepresentable, Sendable, Hashable, Codable {
  /// The raw C process ID.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.ProcessID

  /// Creates a strongly-typed `ProcessID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.ProcessID) { self.rawValue = rawValue }

  /// Creates a strongly-typed `ProcessID` from the raw C value.
  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.ProcessID) { self.rawValue = rawValue }
}

@available(System 199, *)
extension ProcessID {
  /// The process ID of the calling process.
  ///
  /// The corresponding C function is `GetCurrentProcessId`.
  @_alwaysEmitIntoClient
  public static var current: ProcessID { ProcessID(rawValue: _currentProcessID()) }

  @usableFromInline
  internal static func _currentProcessID() -> CInterop.ProcessID {
    system_GetCurrentProcessId()
  }
}

#endif // os(Windows)
