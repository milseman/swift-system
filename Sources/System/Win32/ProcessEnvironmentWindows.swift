/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import ucrt
import WinSDK

// ProcessEnvironment on Windows. ProcessEnvironment.swift declares it for
// the other platforms.

/// A namespace for the process's environment variables.
///
/// Each process has a list of environment variables,
/// `NAME=value` strings that it inherits from the process that created it,
/// and that the processes it creates inherit in turn.
/// Read one with ``value(of:)``, change them with ``set(_:to:overwrite:)``
/// and ``remove(_:)``, and list them with ``entries()``:
///
///     let profile = ProcessEnvironment.value(of: "USERPROFILE")
///     try ProcessEnvironment.set("LC_ALL", to: "C")
///
/// Windows compares names without regard to case,
/// so `value(of: "path")` reads `Path`.
///
/// A Windows process has two copies of its environment: the system's,
/// which `GetEnvironmentVariableW` reads and new processes inherit, and the
/// C runtime's, which `getenv` and `_wenviron` read. These methods read the
/// system's copy and change both, as `_wputenv_s` does, except that the C
/// runtime's copy can't hold a variable whose value is empty, so setting
/// one leaves the C runtime without it. A change made with
/// `SetEnvironmentVariableW` reaches only the system's copy.
///
/// - Important: The environment belongs to the whole process.
///   Windows locks each copy, so these calls are safe from any thread, but a
///   change reaches the two copies one after the other, and
///   ``set(_:to:overwrite:)`` checks for an existing variable before it
///   sets one, so another thread can change the environment in between.
///   Change the environment before starting other threads,
///   or pass a changed environment to a new process instead.
///
/// A name can't be empty, and can't contain `=` or a null character;
/// a value can't contain a null character.
@available(System 199, *)
public enum ProcessEnvironment {}

@available(System 199, *)
extension ProcessEnvironment {
  /// Returns the value of an environment variable.
  ///
  /// - Parameter name: The variable's name, such as `"USERPROFILE"`, in any
  ///   case.
  /// - Returns: A copy of the variable's value,
  ///   or `nil` if the process has no variable of that name,
  ///   or `name` isn't a valid name.
  ///
  /// The corresponding C function is `GetEnvironmentVariableW`.
  @_alwaysEmitIntoClient
  public static func value(of name: String) -> String? {
    _value(of: name)
  }

  @usableFromInline
  internal static func _value(of name: String) -> String? {
    guard _environmentNameIsValid(name) else { return nil }
    return name.withCString(encodedAs: UTF16.self) { name -> String? in
      var capacity = 1024
      while true {
        let outcome = withUnsafeTemporaryAllocation(
          of: WCHAR.self, capacity: capacity
        ) { buffer -> _Win32SizedResult<String?> in
          // A length of 0 is both an empty value and a failure, which
          // only the last error tells apart.
          SetLastError(0)
          let length = system_GetEnvironmentVariableW(
            name, buffer.baseAddress!, DWORD(buffer.count))
          guard length != 0 else {
            return .success(GetLastError() == 0 ? "" : nil)
          }
          guard Int(length) < buffer.count else { return .retry(capacity: Int(length)) }
          return .success(
            String(
              decoding: UnsafeBufferPointer(start: buffer.baseAddress, count: Int(length)),
              as: UTF16.self))
        }
        switch outcome {
        case .success(let value): return value
        case .failure: return nil
        case .retry(let needed): capacity = max(needed, capacity + 1)
        }
      }
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
  /// An empty `value` sets the variable to the empty string in the system's
  /// copy of the environment, and removes it from the C runtime's.
  ///
  /// The corresponding C functions are `_wputenv_s`, for the C runtime's
  /// copy, and `SetEnvironmentVariableW`, for the system's.
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
    guard _environmentNameIsValid(name), !value.utf16.contains(0) else {
      return .failure(.invalidArgument)
    }
    if !overwrite, _value(of: name) != nil { return .success(()) }
    return name.withCString(encodedAs: UTF16.self) { name in
      value.withCString(encodedAs: UTF16.self) { value in
        // The C runtime's copy first: _wputenv_s sets the system's copy
        // too, except that it removes a variable it's given an empty value
        // for, which the system's copy then gets back.
        let error = system__wputenv_s(name, value)
        guard error == 0 else { return .failure(Errno(rawValue: error)) }
        guard system_SetEnvironmentVariableW(name, value) else {
          return .failure(Errno(rawValue: _mapWindowsErrorToErrno(GetLastError())))
        }
        return .success(())
      }
    }
  }

  /// Removes an environment variable.
  ///
  /// - Parameter name: The variable's name, in any case.
  ///
  /// Removing a variable that the process doesn't have succeeds.
  /// If `name` is empty or contains `=` or a null character,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C functions are `_wputenv_s`, with an empty value,
  /// for the C runtime's copy, and `SetEnvironmentVariableW`, with a null
  /// value, for the system's.
  @_alwaysEmitIntoClient
  public static func remove(_ name: String) throws(Errno) {
    try _remove(name).get()
  }

  @usableFromInline
  internal static func _remove(_ name: String) -> Result<(), Errno> {
    guard _environmentNameIsValid(name) else { return .failure(.invalidArgument) }
    return name.withCString(encodedAs: UTF16.self) { name in
      let empty: [WCHAR] = [0]
      let error = empty.withUnsafeBufferPointer { system__wputenv_s(name, $0.baseAddress!) }
      guard error == 0 else { return .failure(Errno(rawValue: error)) }
      guard system_SetEnvironmentVariableW(name, nil) else {
        let code = GetLastError()
        guard code == _ERROR_ENVVAR_NOT_FOUND else {
          return .failure(Errno(rawValue: _mapWindowsErrorToErrno(code)))
        }
        return .success(())
      }
      return .success(())
    }
  }

  /// Returns a copy of every environment variable, in order.
  ///
  /// - Returns: The name and value of each variable,
  ///   in the order of the process's environment,
  ///   which Windows keeps sorted by name.
  ///
  /// The result includes the variables whose names begin with `=`, such as
  /// `=C:`, in which the command shell and the C runtime record each
  /// drive's current directory.
  ///
  /// The corresponding C functions are `GetEnvironmentStringsW` and
  /// `FreeEnvironmentStringsW`, which frees its block.
  @_alwaysEmitIntoClient
  public static func entries() -> [(name: String, value: String)] {
    _entries()
  }

  @usableFromInline
  internal static func _entries() -> [(name: String, value: String)] {
    _withEnvironmentBlock { block in
      var result: [(name: String, value: String)] = []
      var entry = block
      while entry.pointee != 0 {
        var length = 0
        while entry[length] != 0 { length += 1 }
        let units = UnsafeBufferPointer(start: entry, count: length)
        // A name ends at the first "=" after its first character, since
        // the per-drive directories' names, such as "=C:", begin with one.
        if let equals = units.dropFirst().firstIndex(of: WCHAR(UInt8(ascii: "="))) {
          result.append((
            String(decoding: units[..<equals], as: UTF16.self),
            String(decoding: units[(equals + 1)...], as: UTF16.self)))
        }
        entry += length + 1
      }
      return result
    }
  }

  /// Calls a closure with the process's environment,
  /// as the block of `NAME=value` strings that `CreateProcessW` takes.
  ///
  /// - Parameter body: A closure that takes the block: each string with its
  ///   terminator, and then one more terminator. The block is a copy, valid
  ///   only until `body` returns: don't keep it.
  /// - Returns: The value that `body` returns.
  ///
  /// This method reaches the environment's code units,
  /// including those that aren't valid UTF-16.
  ///
  /// The corresponding C functions are `GetEnvironmentStringsW` and
  /// `FreeEnvironmentStringsW`, which frees its block.
  @_alwaysEmitIntoClient
  public static func withUnsafeEntries<R>(
    _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> R
  ) rethrows -> R {
    try _withEnvironmentBlock(body)
  }
}

// A failure to copy the block, which Windows doesn't document, reads as an
// empty environment.
@usableFromInline
@available(System 199, *)
internal func _withEnvironmentBlock<R>(
  _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> R
) rethrows -> R {
  guard let block = system_GetEnvironmentStringsW() else {
    let empty: [WCHAR] = [0, 0]
    return try empty.withUnsafeBufferPointer { try body($0.baseAddress!) }
  }
  defer { _ = system_FreeEnvironmentStringsW(block) }
  return try body(block)
}

// The rule ProcessEnvironment.swift applies elsewhere: SetEnvironmentVariableW
// and _wputenv_s reject an empty name and one with "=", and a Swift string can
// also hold a null character, which would cut the C string short.
internal func _environmentNameIsValid(_ name: String) -> Bool {
  !name.isEmpty && !name.utf16.contains(where: { $0 == 0 || $0 == UInt16(UInt8(ascii: "=")) })
}

#endif // os(Windows)
