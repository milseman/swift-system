/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: the multi-platform directory enum. Not API. See Platform.swift.

import SystemPackage

extension Platform {
  /// An open directory, closed exactly once.
  ///
  /// A separate enum from `Platform.File`, because Windows has a separate
  /// type: SYS-0011's `DirectoryHandle` has no read or write surface, since
  /// `ReadFile` and `WriteFile` fail on it. One enum for both would bring
  /// back that runtime failure. Unix has no separate type, so both enums'
  /// Unix cases hold an OwnedFD.
  ///
  /// Its common subset is only opening and closing. What directories do
  /// differs by platform: Unix opens files relative to one (`openat`) and
  /// makes a rename durable by syncing it, and Windows enumerates and
  /// watches through its handle, in API the drafts leave for later.
  enum Directory: ~Copyable, Sendable {
    #if !os(Windows)
    /// A directory's file descriptor, on Unix.
    case fd(OwnedFD)
    #endif

    #if os(Windows) || SIMULATE_PLATFORMS
    /// A directory handle, on Windows.
    case handle(Win32.DirectoryHandle)
    #endif
  }
}

extension Platform.Directory {
  /// Opens a directory. Child processes don't inherit it.
  ///
  /// - Unix: `open`, with `O_DIRECTORY` and `O_CLOEXEC`.
  /// - Windows: `CreateFileW`, with `FILE_FLAG_BACKUP_SEMANTICS`, which is
  ///   what lets it open a directory.
  /// Either fails if `path` isn't a directory: `notDirectory` on Unix,
  /// `notADirectory` (ERROR_DIRECTORY) on Windows.
  static func open(_ path: FilePath) throws(Platform.Error) -> Platform.Directory {
    #if SIMULATE_PLATFORMS
    if Simulation.platform == .windows {
      return .handle(try Win32.DirectoryHandle.open(path))
    }
    #endif
    #if os(Windows)
    return .handle(try Win32.DirectoryHandle.open(path))
    #else
    return .fd(try OwnedFD.open(path, .readOnly, options: [.directory, .closeOnExec]))
    #endif
  }

  /// Closes the directory, reporting any error.
  consuming func close() throws(Platform.Error) {
    switch consume self {
    #if !os(Windows)
    case .fd(let owner):
      try owner.close()
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      try handle.close()
    #endif
    }
  }

  /// The case and its raw value, for display.
  var summary: String {
    switch self {
    #if !os(Windows)
    case .fd(let owner):
      return ".fd(\(owner.fileDescriptor.rawValue))"
    #endif
    #if os(Windows) || SIMULATE_PLATFORMS
    case .handle(let handle):
      return ".handle(0x\(String(UInt(bitPattern: handle.unsafeRawHandle), radix: 16)))"
    #endif
    }
  }
}
