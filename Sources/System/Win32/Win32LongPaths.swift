/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// The public form of the path canonicalization that the Win32 namespace
// applies to the paths it's given, `_withCanonicalPath` in Win32Open.swift.

// MARK: - Full paths

@available(System 199, *)
extension Win32 {
  /// When a full path gets the `\\?\` prefix, which makes it an
  /// extended-length path.
  ///
  /// Win32's path functions take a path of at most `MAX_PATH` (260)
  /// characters, terminator included, and `CreateDirectoryW` documents a
  /// limit of 248, which leaves room for an 8.3 file name. A path with the
  /// prefix can have up to 32,767 characters: Windows passes it to the file
  /// system without parsing it, so it must be a full path already. A
  /// long-path-aware process, which takes a registry setting and the
  /// program's manifest, can pass longer paths without it.
  @frozen
  public enum ExtendedLengthPrefix: Sendable, Hashable, Codable {
    /// Never: the full path as `GetFullPathNameW` resolves it.
    ///
    /// This is the form for a path that Windows doesn't support with the
    /// prefix, such as a process's current directory, and for display.
    case never

    /// When the path, with its terminator, reaches `CreateDirectoryW`'s
    /// limit of 248 characters, the lowest of the path functions', whether
    /// or not the process is long-path aware.
    case whenNeeded

    /// Always, as `\\?\C:\dir` or `\\?\UNC\server\share\dir`.
    ///
    /// The corresponding C constant is
    /// `PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH`.
    case always
  }
}

@available(System 199, *)
extension Win32 {
  /// Returns the full path of `path`, as Win32 path functions should
  /// receive it.
  ///
  /// This resolves a relative path against the current directory, and a
  /// drive-relative one, such as `D:file`, against that drive's, then
  /// normalizes it as Windows does a path before it opens one: separators
  /// become backslashes, `.` and `..` components are removed, and trailing
  /// dots and spaces are trimmed from the last component. It's lexical: the
  /// file needn't exist, and links aren't resolved, as
  /// ``FilePath/canonicalized()`` and
  /// ``Win32/FileHandle/finalPath(volumeName:normalized:)`` resolve them.
  ///
  /// - Parameters:
  ///   - path: The path to resolve.
  ///   - extendedLengthPrefix: When the result gets the `\\?\` prefix. The
  ///     default, ``Win32/ExtendedLengthPrefix/whenNeeded``, gives it to a
  ///     path too long for any of Win32's path functions without it.
  ///
  /// A path that begins with `\\?\` or `\\.\` is returned unchanged:
  /// Windows passes the first to the file system as it is, and the second
  /// names a device. A device name, such as `NUL` or `COM1`, resolves to a
  /// `\\.\` path, which doesn't get the prefix.
  ///
  /// System's Win32 API resolves the paths it's given this way, with the
  /// default rule, so a full path from this method suits that API and the
  /// Win32 functions System doesn't wrap, and resolving one again returns
  /// it unchanged. Since the current directory belongs to the process,
  /// another thread can change what a relative path resolves to.
  ///
  /// The corresponding C functions are `GetFullPathNameW`, and
  /// `PathAllocCanonicalize` unless `extendedLengthPrefix` is
  /// ``Win32/ExtendedLengthPrefix/never``.
  @_alwaysEmitIntoClient
  public static func fullPath(
    of path: FilePath,
    extendedLengthPrefix: Win32.ExtendedLengthPrefix = .whenNeeded
  ) throws(Win32.Error) -> FilePath {
    try _fullPath(path, prefix: extendedLengthPrefix).get()
  }

  /// Returns `path` without the `\\?\` prefix.
  ///
  /// `\\?\C:\dir` becomes `C:\dir`, and `\\?\UNC\server\share\dir` becomes
  /// `\\server\share\dir`. A path with no prefix, or one whose root can't
  /// be spelled without it, such as `\\?\Volume{...}\dir`, is returned
  /// unchanged.
  ///
  /// This is for showing a path that Windows reports with the prefix, such
  /// as a final path from
  /// ``Win32/FileHandle/finalPath(volumeName:normalized:)``. Windows stops
  /// passing the path verbatim once the prefix is gone, so a long result
  /// works with Win32 functions only in a long-path-aware process, and
  /// with System's Win32 API, which adds the prefix again.
  ///
  /// The corresponding C function is `PathCchStripPrefix`.
  @_alwaysEmitIntoClient
  public static func removingExtendedLengthPrefix(from path: FilePath) -> FilePath {
    _removingExtendedLengthPrefix(path)
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _fullPath(
    _ path: FilePath, prefix: Win32.ExtendedLengthPrefix
  ) -> Result<FilePath, Win32.Error> {
    _withCanonicalPath(path, prefix: prefix) { .success(FilePath(platformString: $0)) }
  }

  @usableFromInline
  internal static func _removingExtendedLengthPrefix(_ path: FilePath) -> FilePath {
    let count = path.length + 1
    let stripped = path.withPlatformString { string -> FilePath? in
      // PathCchStripPrefix works in place, on a buffer it's told the size
      // of, terminator included.
      withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: count) { buffer in
        _ = buffer.initialize(from: UnsafeBufferPointer(start: string, count: count))
        // S_FALSE for nothing removed, and a failure for a buffer longer
        // than PATHCCH_MAX_CCH, 32,768 characters.
        guard system_PathCchStripPrefix(buffer.baseAddress!, buffer.count) == _S_OK else {
          return nil
        }
        return FilePath(platformString: buffer.baseAddress!)
      }
    }
    return stripped ?? path
  }

  /// `path` without the `\\?\` prefix, unless it needs the prefix by
  /// ``ExtendedLengthPrefix/whenNeeded``'s rule.
  internal static func _removingUnneededExtendedLengthPrefix(_ path: FilePath) -> FilePath {
    let stripped = _removingExtendedLengthPrefix(path)
    return stripped.length + 1 >= _win32DirectoryMaxPath ? path : stripped
  }
}

#endif // os(Windows)
