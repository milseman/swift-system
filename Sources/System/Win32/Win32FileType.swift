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
  /// The class of device a handle refers to.
  ///
  /// The class decides how I/O behaves: on a ``disk`` file, a read comes up
  /// short only at the end of the file, and the size and position are
  /// meaningful. On a ``character`` device or a ``pipe``, a read returns
  /// whatever has arrived, and a seek can succeed while reporting a position
  /// that no transfer advances.
  @frozen
  public struct FileType: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed file type from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Creates a strongly-typed file type from a raw C value.
    @_alwaysEmitIntoClient
    public init(_ rawValue: DWORD) { self.rawValue = rawValue }

    /// A file or directory on a volume, local or remote.
    ///
    /// The corresponding C constant is `FILE_TYPE_DISK`.
    @_alwaysEmitIntoClient
    public static var disk: FileType { FileType(rawValue: 0x1) }

    /// A character device, such as a console, a printer, or `NUL`.
    ///
    /// The corresponding C constant is `FILE_TYPE_CHAR`.
    @_alwaysEmitIntoClient
    public static var character: FileType { FileType(rawValue: 0x2) }

    /// A named pipe, an anonymous pipe, or a socket.
    ///
    /// Because a socket reports this type too, it doesn't imply that the
    /// named-pipe functions, such as `PeekNamedPipe`, work on the handle.
    ///
    /// The corresponding C constant is `FILE_TYPE_PIPE`.
    @_alwaysEmitIntoClient
    public static var pipe: FileType { FileType(rawValue: 0x3) }

    /// A device that Windows does not classify.
    ///
    /// This is a result, not a failure: a usable handle can report it, such
    /// as one to the mount manager (`\\.\MountPointManager`).
    ///
    /// The corresponding C constant is `FILE_TYPE_UNKNOWN`.
    @_alwaysEmitIntoClient
    public static var unknown: FileType { FileType(rawValue: 0x0) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// The type of device this handle refers to.
  ///
  /// This requires no access rights, so a handle opened with an empty
  /// ``Win32/AccessMask`` is still classified. A device that Windows doesn't
  /// classify returns ``Win32/FileType/unknown``; this throws only if
  /// `GetFileType` reports an error.
  ///
  /// The corresponding C function is `GetFileType`.
  @_alwaysEmitIntoClient
  public func fileType() throws(Win32.Error) -> Win32.FileType {
    try Win32._fileType(_handle).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _fileType(_ handle: HANDLE) -> Result<Win32.FileType, Win32.Error> {
    // FILE_TYPE_UNKNOWN is both a result and the failure value, so only the
    // last error tells them apart.
    SetLastError(Win32.Error.success.rawValue)
    let type = system_GetFileType(handle)
    if type == _FILE_TYPE_UNKNOWN {
      let error = Win32.Error(GetLastError())
      guard error == .success else { return .failure(error) }
    }
    return .success(Win32.FileType(rawValue: type))
  }
}

#endif // os(Windows)
