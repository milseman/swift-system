/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

/// A namespace for the process's environment variables.
///
/// Each process has a list of environment variables,
/// `NAME=value` strings that it inherits from the process that started it,
/// and that the programs it starts inherit in turn.
/// Read one with ``value(of:)``, change them with ``set(_:to:overwrite:)``
/// and ``remove(_:)``, and list them with ``entries()``:
///
///     let home = ProcessEnvironment.value(of: "HOME") ?? "/"
///     try ProcessEnvironment.set("LC_ALL", to: "C")
///
/// - Important: The environment belongs to the whole process,
///   and C gives it no lock:
///   changing it while another thread reads it,
///   whether through these methods or through C calls such as `getenv`
///   in any library, is a data race.
///   These methods copy what they read, so their results stay valid,
///   but they can't make the copy atomic.
///   Change the environment before starting other threads,
///   or pass a changed environment to a new process instead.
///
/// A name can't be empty, and can't contain `=` or a null character;
/// a value can't contain a null character.
/// Values that aren't valid UTF-8 are repaired when they're read as strings;
/// ``withUnsafeEntries(_:)`` reaches the bytes.
@available(System 199, *)
public enum ProcessEnvironment {}

@available(System 199, *)
extension ProcessEnvironment {
  /// Returns the value of an environment variable.
  ///
  /// - Parameter name: The variable's name, such as `"HOME"`.
  /// - Returns: A copy of the variable's value,
  ///   or `nil` if the process has no variable of that name,
  ///   or `name` isn't a valid name.
  ///
  /// The corresponding C function is `getenv`.
  @_alwaysEmitIntoClient
  public static func value(of name: String) -> String? {
    _value(of: name)
  }

  @usableFromInline
  internal static func _value(of name: String) -> String? {
    guard _environmentNameIsValid(name) else { return nil }
    return name.withCString { name in
      system_getenv(name).map { String(platformString: $0) }
    }
  }

  /// Sets an environment variable.
  ///
  /// - Parameters:
  ///   - name: The variable's name, such as `"LC_ALL"`.
  ///   - value: The variable's new value.
  ///   - overwrite: Whether to replace the variable's value
  ///     if the process already has a variable of that name.
  ///     The default is `true`.
  ///     Pass `false` to leave an existing variable unchanged.
  ///
  /// If `name` is empty or contains `=` or a null character,
  /// or `value` contains a null character,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `setenv`.
  @_alwaysEmitIntoClient
  public static func set(
    _ name: String, to value: String, overwrite: Bool = true
  ) throws(Errno) {
    try _set(name, to: value, overwrite: overwrite).get()
  }

  @usableFromInline
  internal static func _set(
    _ name: String, to value: String, overwrite: Bool
  ) -> Result<(), Errno> {
    guard _environmentNameIsValid(name), !value.utf8.contains(0) else {
      return .failure(.invalidArgument)
    }
    return name.withCString { name in
      value.withCString { value in
        nothingOrErrno(retryOnInterrupt: false) {
          system_setenv(name, value, overwrite ? 1 : 0)
        }
      }
    }
  }

  /// Removes an environment variable.
  ///
  /// - Parameter name: The variable's name.
  ///
  /// Removing a variable that the process doesn't have succeeds.
  /// If `name` is empty or contains `=` or a null character,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `unsetenv`.
  @_alwaysEmitIntoClient
  public static func remove(_ name: String) throws(Errno) {
    try _remove(name).get()
  }

  @usableFromInline
  internal static func _remove(_ name: String) -> Result<(), Errno> {
    guard _environmentNameIsValid(name) else { return .failure(.invalidArgument) }
    return name.withCString { name in
      nothingOrErrno(retryOnInterrupt: false) { system_unsetenv(name) }
    }
  }

  /// Returns a copy of every environment variable, in order.
  ///
  /// - Returns: The name and value of each variable,
  ///   in the order of the process's environment.
  ///
  /// The environment can hold more than one variable with the same name,
  /// if the process was started with them;
  /// ``value(of:)`` returns the first one's value.
  /// An entry without an `=` isn't a variable, and isn't in the result.
  ///
  /// The corresponding C variable is `environ`.
  @_alwaysEmitIntoClient
  public static func entries() -> [(name: String, value: String)] {
    _entries()
  }

  @usableFromInline
  internal static func _entries() -> [(name: String, value: String)] {
    _withEnvironmentEntries { entries in
      var result: [(name: String, value: String)] = []
      var entry = entries
      while let pointer = entry.pointee {
        // Split the bytes, not a String: a String splits only between
        // characters, and "=" can start one, such as "=" and a combining mark.
        var length = 0
        while pointer[length] != 0 { length += 1 }
        let bytes = UnsafeRawBufferPointer(start: pointer, count: length)
        if let equals = bytes.firstIndex(of: UInt8(ascii: "=")) {
          result.append((
            String(decoding: bytes[..<equals], as: UTF8.self),
            String(decoding: bytes[(equals + 1)...], as: UTF8.self)))
        }
        entry += 1
      }
      return result
    }
  }

  /// Calls a closure with the process's environment,
  /// as the null-terminated array of `NAME=value` C strings
  /// that `posix_spawn` and `execve` take.
  ///
  /// - Parameter body: A closure that takes the environment.
  ///   The array and its strings are valid only until
  ///   the environment next changes:
  ///   don't keep them, and don't change the environment inside `body`.
  /// - Returns: The value that `body` returns.
  ///
  /// This method reaches the environment's bytes,
  /// including entries that aren't valid UTF-8,
  /// and entries without an `=`.
  ///
  /// The corresponding C variable is `environ`.
  @_alwaysEmitIntoClient
  public static func withUnsafeEntries<R>(
    _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> R
  ) rethrows -> R {
    try _withEnvironmentEntries(body)
  }
}

// An empty environ array is valid: glibc's clearenv sets environ to NULL.
@usableFromInline
@available(System 199, *)
internal func _withEnvironmentEntries<R>(
  _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> R
) rethrows -> R {
  guard let entries = system_environ() else {
    let none: UnsafeMutablePointer<CChar>? = nil
    return try withUnsafePointer(to: none) { try body($0) }
  }
  return try body(entries)
}

// setenv rejects an empty name and one with "=", but a Swift string can also
// hold a null character, which would cut the C string short.
internal func _environmentNameIsValid(_ name: String) -> Bool {
  !name.isEmpty && !name.utf8.contains(where: { $0 == 0 || $0 == UInt8(ascii: "=") })
}

#endif // !os(Windows) && !os(WASI)
