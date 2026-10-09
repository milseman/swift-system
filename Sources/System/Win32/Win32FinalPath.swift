/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// How the volume component of a resolved path is spelled.
  @frozen
  public struct VolumeNameFormat: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C flag.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed volume name format from a raw C flag.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// A drive-letter path, such as `\\?\C:\dir\file`, or a UNC path such as
    /// `\\?\UNC\server\share\dir\file` for a file on a network share.
    ///
    /// The corresponding C constant is `VOLUME_NAME_DOS`.
    @_alwaysEmitIntoClient
    public static var dos: VolumeNameFormat { VolumeNameFormat(rawValue: 0x0) }

    /// A volume GUID path, such as `\\?\Volume{...}\dir\file`.
    ///
    /// Use this for a volume with no assigned drive letter. A file on a
    /// network share has no volume GUID, so passing this format to
    /// ``Win32/FileHandle/finalPath(volumeName:normalized:)`` throws
    /// ``Win32/Error/pathNotFound`` for such a file.
    ///
    /// The corresponding C constant is `VOLUME_NAME_GUID`.
    @_alwaysEmitIntoClient
    public static var guid: VolumeNameFormat { VolumeNameFormat(rawValue: 0x1) }

    /// An NT device path, such as `\Device\HarddiskVolume2\dir\file`.
    ///
    /// The corresponding C constant is `VOLUME_NAME_NT`.
    @_alwaysEmitIntoClient
    public static var nt: VolumeNameFormat { VolumeNameFormat(rawValue: 0x2) }

    /// A volume-relative path with no volume component, such as `\dir\file`.
    ///
    /// The corresponding C constant is `VOLUME_NAME_NONE`.
    @_alwaysEmitIntoClient
    public static var volumeRelative: VolumeNameFormat { VolumeNameFormat(rawValue: 0x4) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Returns the fully resolved path of the file this handle refers to.
  ///
  /// Unlike lexical canonicalization, this resolves symbolic links, directory
  /// junctions, and volume mount points. The path is returned as Windows
  /// reports it: a ``Win32/VolumeNameFormat/dos`` path always carries the
  /// `\\?\` prefix, since some paths are valid only in that form.
  ///
  /// - Parameters:
  ///   - volumeName: How to spell the volume component. The default,
  ///     ``Win32/VolumeNameFormat/dos``, throws
  ///     ``Win32/Error/pathNotFound`` for a volume with no drive letter; use
  ///     ``Win32/VolumeNameFormat/guid`` in that case.
  ///   - normalized: Whether to return the canonical name of each component
  ///     rather than the names supplied when the file was opened.
  ///
  /// Requires no access rights. Throws for a handle with no path, such as
  /// ``Win32/Error/badPathName`` for a pipe, ``Win32/Error/invalidParameter``
  /// for `NUL`, and ``Win32/Error/invalidFunction`` for a console or volume.
  ///
  /// The corresponding C function is `GetFinalPathNameByHandleW`, with
  /// `FILE_NAME_NORMALIZED` or `FILE_NAME_OPENED`, as the normalized
  /// parameter says.
  @_alwaysEmitIntoClient
  public func finalPath(
    volumeName: Win32.VolumeNameFormat = .dos,
    normalized: Bool = true
  ) throws(Win32.Error) -> FilePath {
    try Win32._finalPath(
      _handle, flags: Win32._finalPathFlags(volumeName, normalized: normalized)
    ).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// Returns the fully resolved path of the directory this handle refers to.
  ///
  /// Unlike lexical canonicalization, this resolves symbolic links, directory
  /// junctions, and volume mount points, which makes it the way to audit a
  /// junction or a mount point.
  ///
  /// See ``Win32/FileHandle/finalPath(volumeName:normalized:)``.
  ///
  /// The corresponding C function is `GetFinalPathNameByHandleW`, with
  /// `FILE_NAME_NORMALIZED` or `FILE_NAME_OPENED`, as the normalized
  /// parameter says.
  @_alwaysEmitIntoClient
  public func finalPath(
    volumeName: Win32.VolumeNameFormat = .dos,
    normalized: Bool = true
  ) throws(Win32.Error) -> FilePath {
    try Win32._finalPath(
      _handle, flags: Win32._finalPathFlags(volumeName, normalized: normalized)
    ).get()
  }
}

@available(System 199, *)
extension Win32 {
  /// The `dwFlags` for `GetFinalPathNameByHandleW`: `FILE_NAME_NORMALIZED`
  /// and `FILE_NAME_OPENED` are mutually exclusive, so they're a `Bool`
  /// rather than members of `VolumeNameFormat`.
  @_alwaysEmitIntoClient
  internal static func _finalPathFlags(
    _ volumeName: Win32.VolumeNameFormat, normalized: Bool
  ) -> DWORD {
    volumeName.rawValue | (normalized ? _FILE_NAME_NORMALIZED : _FILE_NAME_OPENED)
  }

  @usableFromInline
  internal static func _finalPath(
    _ handle: HANDLE, flags: DWORD
  ) -> Result<FilePath, Win32.Error> {
    var capacity = _win32MaxPath + 1
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<FilePath> in
        let length = system_GetFinalPathNameByHandleW(
          handle, buffer.baseAddress, DWORD(buffer.count), flags)
        guard length != 0 else { return .failure(Win32.Error(GetLastError())) }
        // A buffer that's too small gets the size needed, including the
        // terminator, rather than a failure.
        guard Int(length) < buffer.count else { return .retry(capacity: Int(length)) }
        return .success(FilePath(platformString: buffer.baseAddress!))
      }
      switch outcome {
      case .success(let path): return .success(path)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }
}

#endif // os(Windows)
