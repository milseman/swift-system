/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A process's executable on Linux and Android, its /proc/<pid>/exe link,
// and on FreeBSD, sysctl's KERN_PROC_PATHNAME: the counterparts of macOS's
// proc_pidpath (LibProc/ProcessPaths.swift).

#if os(Linux) || os(Android)

@available(System 199, *)
extension ProcessID {
  /// Returns the path of the process's executable.
  ///
  /// The path is the one the kernel resolved when the process started,
  /// read from the process's `exe` link in `/proc`.
  /// If the file has since been removed, Linux adds ` (deleted)` to it.
  /// Reading the path of another user's process
  /// needs the right to trace it;
  /// otherwise, this method throws ``Errno/permissionDenied``.
  /// If there's no such process, or `/proc` isn't mounted,
  /// it throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `readlink`, of the process's link in /proc.
  ///
  /// - Note: Only available on macOS, Linux, Android, and FreeBSD.
  @_alwaysEmitIntoClient
  public func executablePath() throws(Errno) -> FilePath {
    try FilePath("/proc/\(rawValue)/exe").readSymbolicLink()
  }
}

#elseif os(FreeBSD)

import CSystem

@available(System 199, *)
extension ProcessID {
  /// Returns the path of the process's executable.
  ///
  /// The path is the one the kernel resolved when the process started.
  /// If there's no such process, this method throws
  /// ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `sysctl`, with `KERN_PROC_PATHNAME`.
  ///
  /// - Note: Only available on macOS, Linux, Android, and FreeBSD.
  @_alwaysEmitIntoClient
  public func executablePath() throws(Errno) -> FilePath {
    try _executablePath().get()
  }

  @usableFromInline
  internal func _executablePath() -> Result<FilePath, Errno> {
    while true {
      // The first call gives the size, terminator included; the path can
      // change before the second, which then fails with ENOMEM.
      var size = 0
      guard csystem_kern_proc_pathname(rawValue, nil, &size) == 0 else {
        return .failure(.current)
      }
      var buffer = [CChar](repeating: 0, count: size + 1)
      var count = buffer.count
      let result = buffer.withUnsafeMutableBufferPointer {
        csystem_kern_proc_pathname(rawValue, $0.baseAddress, &count)
      }
      if result == 0 {
        return .success(buffer.withUnsafeBufferPointer {
          FilePath(SystemString(platformString: $0.baseAddress!))
        })
      }
      let error = Errno.current
      guard error == .noMemory else { return .failure(error) }
    }
  }
}

#endif // os(Linux) || os(Android) || os(FreeBSD)
