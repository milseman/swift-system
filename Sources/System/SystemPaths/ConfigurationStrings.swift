/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Configurable system strings: confstr, the string counterpart of sysconf,
// which SystemConfig wraps.

// Bionic has no confstr.
#if !os(Windows) && !os(WASI) && !os(Android)

// MARK: - confstr

@available(System 199, *)
extension SystemConfig {
  /// The name of a configurable system string.
  ///
  /// To get a string's value, call ``SystemConfig/string(_:)``.
  @frozen
  public struct StringName: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C name.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed name from a raw C name.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
  }

  /// Returns the value of a configurable system string.
  ///
  /// - Parameters:
  ///   - name: The string to return.
  /// - Returns: The string's value,
  ///   or `nil` if the system has no value for it.
  ///
  /// If the system doesn't recognize `name`,
  /// this method throws ``Errno/invalidArgument``.
  /// Bytes that aren't valid UTF-8 are repaired,
  /// as `String(decoding:as:)` does.
  ///
  /// The corresponding C function is `confstr`.
  /// - Note: Only available on Unix-like platforms other than WASI and Android.
  @_alwaysEmitIntoClient
  public static func string(_ name: StringName) throws(Errno) -> String? {
    try _string(name).get()
  }

  // confstr returns the size that the value needs, including its null
  // terminator, or 0 both for an error, which sets errno, and for a name
  // without a value, which leaves it alone.
  @usableFromInline
  internal static func _string(_ name: StringName) -> Result<String?, Errno> {
    // The first call, with no room, reads the size.
    var buffer: [CInterop.PlatformChar] = []
    while true {
      system_errno = 0
      let needed = buffer.withUnsafeMutableBufferPointer {
        system_confstr(name.rawValue, $0.baseAddress, $0.count)
      }
      guard needed > 0 else {
        return system_errno == 0 ? .success(nil) : .failure(.current)
      }
      if needed <= buffer.count {
        let value = buffer[..<(needed - 1)].map { UInt8(bitPattern: $0) }
        return .success(String(decoding: value, as: UTF8.self))
      }
      // A value that has grown since its size was read is truncated,
      // so read it again.
      buffer = Array(repeating: 0, count: needed)
    }
  }
}

@available(System 199, *)
extension SystemConfig.StringName {
  /// A value for the `PATH` environment variable
  /// that finds all of the system's standard utilities.
  ///
  /// The corresponding C constant is `_CS_PATH`.
  @_alwaysEmitIntoClient
  public static var defaultSearchPath: Self { Self(rawValue: __CS_PATH) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "defaultSearchPath")
  public static var _CS_PATH: Self { defaultSearchPath }

  #if SYSTEM_PACKAGE_DARWIN
  /// The path of the user's private directory,
  /// which holds the user's temporary and cache directories,
  /// with a trailing slash.
  ///
  /// Reading the path creates the directory if it doesn't exist.
  ///
  /// The corresponding C constant is `_CS_DARWIN_USER_DIR`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var userDirectory: Self { Self(rawValue: __CS_DARWIN_USER_DIR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userDirectory")
  public static var _CS_DARWIN_USER_DIR: Self { userDirectory }

  /// The path of the user's temporary directory, with a trailing slash.
  ///
  /// Reading the path creates the directory if it doesn't exist.
  ///
  /// The corresponding C constant is `_CS_DARWIN_USER_TEMP_DIR`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var userTemporaryDirectory: Self {
    Self(rawValue: __CS_DARWIN_USER_TEMP_DIR)
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userTemporaryDirectory")
  public static var _CS_DARWIN_USER_TEMP_DIR: Self { userTemporaryDirectory }

  /// The path of the user's cache directory, with a trailing slash.
  ///
  /// Reading the path creates the directory if it doesn't exist.
  ///
  /// The corresponding C constant is `_CS_DARWIN_USER_CACHE_DIR`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var userCacheDirectory: Self { Self(rawValue: __CS_DARWIN_USER_CACHE_DIR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userCacheDirectory")
  public static var _CS_DARWIN_USER_CACHE_DIR: Self { userCacheDirectory }
  #endif // SYSTEM_PACKAGE_DARWIN

  #if os(Linux) && canImport(Glibc)
  /// The name and version of the GNU C library that the process runs with,
  /// such as `"glibc 2.39"`.
  ///
  /// It's the version at run time, which can be newer
  /// than the one the program was built with.
  /// `gnu_get_libc_version` returns the same version, without the name.
  ///
  /// The corresponding C constant is `_CS_GNU_LIBC_VERSION`.
  /// - Note: Only available on Linux with glibc.
  @_alwaysEmitIntoClient
  public static var gnuLibraryVersion: Self { Self(rawValue: __CS_GNU_LIBC_VERSION) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "gnuLibraryVersion")
  public static var _CS_GNU_LIBC_VERSION: Self { gnuLibraryVersion }
  #endif // os(Linux) && canImport(Glibc)
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
