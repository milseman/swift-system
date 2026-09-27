/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The path of the process's main executable: _NSGetExecutablePath.
//
// The process's arguments, which _NSGetArgv and _NSGetArgc hold, are
// already the standard library's `CommandLine.arguments` and
// `CommandLine.unsafeArgv`, which read those on Darwin; its environment,
// which _NSGetEnviron holds, is ProcessEnvironment's.

#if SYSTEM_PACKAGE_DARWIN

@available(System 199, *)
extension FilePath {
  /// Returns the path of the process's main executable,
  /// as the dynamic loader recorded it.
  ///
  /// The path is the one the process was executed with, made absolute,
  /// so it can include symbolic links and `..` components:
  /// running `../bin/tool`, where `tool` is a symbolic link,
  /// gives a path that ends in `/../bin/tool`.
  /// To get the path of the file itself, resolve this one,
  /// or, on macOS, call ``ProcessID/executablePath()``
  /// for ``ProcessID/current``.
  ///
  /// The corresponding C function is `_NSGetExecutablePath`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func currentExecutable() -> FilePath {
    _currentExecutable()
  }

  @usableFromInline
  internal static func _currentExecutable() -> FilePath {
    // The first call, with no room, reads the size, including the null.
    var size: UInt32 = 0
    _ = system__NSGetExecutablePath(nil, &size)
    while true {
      var buffer = [CChar](repeating: 0, count: Int(size) + 1)
      var capacity = UInt32(buffer.count)
      let result = buffer.withUnsafeMutableBufferPointer {
        system__NSGetExecutablePath($0.baseAddress, &capacity)
      }
      if result == 0 { return FilePath(platformString: buffer) }
      size = capacity
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
