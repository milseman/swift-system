/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt
import WinSDK

// The current working directory, the temporary directory, and the current
// executable's path on Windows. FilePathOperations.swift, UniqueFiles.swift
// and CurrentExecutable.swift declare them for the other platforms.

@available(System 199, *)
extension FilePath {
  /// Returns the current working directory of the calling process.
  ///
  /// - Returns: The absolute path of the current working directory.
  ///
  /// The current working directory belongs to the whole process,
  /// so another thread can change it at any time.
  ///
  /// The corresponding C function is `_wgetcwd`.
  @_alwaysEmitIntoClient
  public static func currentWorkingDirectory() throws(Errno) -> FilePath {
    try _currentWorkingDirectory().get()
  }

  @usableFromInline
  internal static func _currentWorkingDirectory() -> Result<FilePath, Errno> {
    // Grow the buffer while _wgetcwd reports that it's too small. No path
    // is longer than 32,767 characters, so the growth ends.
    var capacity = _win32MaxPath + 1
    while capacity <= 1 << 16 {
      let outcome = withUnsafeTemporaryAllocation(
        of: CInterop.PlatformChar.self, capacity: capacity
      ) { buffer -> Result<FilePath, Errno>? in
        guard system__wgetcwd(buffer.baseAddress!, CInt(buffer.count)) != nil else {
          let error = Errno.current
          return error == .outOfRange ? nil : .failure(error)
        }
        return .success(FilePath(platformString: buffer.baseAddress!))
      }
      if let outcome { return outcome }
      capacity *= 2
    }
    return .failure(.outOfRange)
  }

  /// Changes the current working directory of the calling process.
  ///
  /// - Parameters:
  ///   - path: The new current working directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``, as on other platforms.
  ///     Windows doesn't interrupt it.
  ///
  /// The current working directory belongs to the whole process,
  /// so the change affects every thread's relative paths.
  /// The C runtime also records the directory as its drive's current
  /// directory, which a drive-relative path such as `D:file` resolves
  /// against. A path longer than `MAX_PATH` fails unless the process is
  /// long-path aware.
  ///
  /// The corresponding C function is `_wchdir`.
  @_alwaysEmitIntoClient
  public static func setCurrentWorkingDirectory(
    _ path: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try path.withPlatformString {
      FilePath._setCurrentWorkingDirectory($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Changes the current working directory of the calling process.
  ///
  /// - Parameters:
  ///   - path: The new current working directory.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``, as on other platforms.
  ///     Windows doesn't interrupt it.
  ///
  /// See ``setCurrentWorkingDirectory(_:retryOnInterrupt:)-(FilePath,_)``.
  ///
  /// The corresponding C function is `_wchdir`.
  @_alwaysEmitIntoClient
  public static func setCurrentWorkingDirectory(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setCurrentWorkingDirectory(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _setCurrentWorkingDirectory(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system__wchdir(path)
    }
  }
}

@available(System 199, *)
extension FilePath {
  /// Returns the directory where the calling process should put temporary
  /// files.
  ///
  /// This is the first of the directories that the `TMP`, `TEMP` and
  /// `USERPROFILE` environment variables name, or else the Windows
  /// directory, except for a process that runs as the SYSTEM account, whose
  /// temporary directory is the Windows directory's `SystemTemp`, which
  /// other accounts can't reach. Windows releases before Windows 11 and
  /// Windows Server 2022 have no `SystemTemp`, and choose among the others.
  /// If Windows can't say, which it doesn't document happening, this is the
  /// Windows directory, or the current directory.
  ///
  /// Other users can see the directory: create files there at names
  /// that no one can guess, rather than at names you choose.
  ///
  /// The corresponding C function is `GetTempPath2W`, or `GetTempPathW`
  /// where Windows lacks it.
  @_alwaysEmitIntoClient
  public static func temporaryDirectory() -> FilePath {
    _temporaryDirectory()
  }

  @usableFromInline
  internal static func _temporaryDirectory() -> FilePath {
    if case .success(let path) = Win32._temporaryPath() { return path }
    if case .success(let path) = Win32._sizedPath({ system_GetWindowsDirectoryW($0, $1) }) {
      return path
    }
    return "."
  }

  /// Returns the path of the process's main executable,
  /// as the loader recorded it.
  ///
  /// The path is the absolute path the process was created with, so it can
  /// use short (8.3) names or begin with `\\?\`, as the creator's did. If
  /// Windows can't say, which it doesn't document happening for the main
  /// executable, this is an empty path.
  ///
  /// The corresponding C function is `GetModuleFileNameW`, with a null
  /// module.
  @_alwaysEmitIntoClient
  public static func currentExecutable() -> FilePath {
    _currentExecutable()
  }

  @usableFromInline
  internal static func _currentExecutable() -> FilePath {
    var capacity = _win32MaxPath + 1
    while capacity <= 1 << 16 {
      // A path that doesn't fit is cut short, with the buffer's size as
      // its length.
      let path = withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: capacity) {
        buffer -> FilePath? in
        let length = Int(system_GetModuleFileNameW(nil, buffer.baseAddress!, DWORD(buffer.count)))
        guard length < buffer.count else { return nil }
        guard length > 0 else { return FilePath() }
        return FilePath(platformString: buffer.baseAddress!)
      }
      if let path { return path }
      capacity *= 2
    }
    return FilePath()
  }
}

// MARK: - Windows directories

@available(System 199, *)
extension Win32 {
  /// The path of the Windows directory, such as `C:\Windows`.
  ///
  /// Programs shouldn't create files there. On a server that shares one
  /// installation among users, this is a directory private to the user.
  ///
  /// The corresponding C function is `GetWindowsDirectoryW`.
  @_alwaysEmitIntoClient
  public static func windowsDirectory() throws(Win32.Error) -> FilePath {
    try _windowsDirectory().get()
  }

  /// The path of the system directory, such as `C:\Windows\System32`,
  /// which holds Windows' own programs and libraries.
  ///
  /// The corresponding C function is `GetSystemDirectoryW`.
  @_alwaysEmitIntoClient
  public static func systemDirectory() throws(Win32.Error) -> FilePath {
    try _systemDirectory().get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _windowsDirectory() -> Result<FilePath, Win32.Error> {
    _sizedPath { system_GetWindowsDirectoryW($0, $1) }
  }

  @usableFromInline
  internal static func _systemDirectory() -> Result<FilePath, Win32.Error> {
    _sizedPath { system_GetSystemDirectoryW($0, $1) }
  }

  /// The signature of `GetTempPath2W`, which kernel32.dll exports from
  /// Windows 11 and Windows Server 2022.
  internal typealias _GetTempPath2W = @convention(c) (
    DWORD, UnsafeMutablePointer<WCHAR>?
  ) -> DWORD

  internal static func _temporaryPath() -> Result<FilePath, Win32.Error> {
    // Looked up at run time, since linking it would keep System from
    // loading on earlier releases. kernel32 is loaded in every process.
    let kernel32 = "kernel32.dll".withCString(encodedAs: UTF16.self) { name in
      system_GetModuleHandleW(name)
    }
    if let kernel32,
      let getTempPath2W = unsafeBitCast(
        system_GetProcAddress(kernel32, "GetTempPath2W"), to: Optional<_GetTempPath2W>.self)
    {
      return _sizedPath { getTempPath2W($1, $0) }
    }
    return _sizedPath { system_GetTempPathW($1, $0) }
  }

  /// Calls a Win32 function that writes a path to a buffer, and returns
  /// the path's length without its terminator, or the size the path needs,
  /// with its terminator, if the buffer is too small, or 0 if it fails.
  internal static func _sizedPath(
    _ call: (UnsafeMutablePointer<WCHAR>, DWORD) -> DWORD
  ) -> Result<FilePath, Win32.Error> {
    var capacity = _win32MaxPath + 1
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<FilePath> in
        let length = call(buffer.baseAddress!, DWORD(buffer.count))
        guard length != 0 else { return .failure(Win32.Error(GetLastError())) }
        guard Int(length) < buffer.count else { return .retry(capacity: Int(length)) }
        return .success(FilePath(platformString: buffer.baseAddress!))
      }
      switch outcome {
      case .success(let path): return .success(path)
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = max(needed, capacity + 1)
      }
    }
  }
}

#endif // os(Windows)
