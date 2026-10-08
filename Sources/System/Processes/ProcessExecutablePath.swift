/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A process's executable on Linux and Android: its /proc/<pid>/exe link,
// the counterpart of macOS's proc_pidpath (LibProc/ProcessPaths.swift).

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
  /// - Note: Only available on macOS, Linux, and Android.
  @_alwaysEmitIntoClient
  public func executablePath() throws(Errno) -> FilePath {
    try FilePath("/proc/\(rawValue)/exe").readSymbolicLink()
  }
}

#endif // os(Linux) || os(Android)
