/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// readpassphrase: a prompt, and a line read with echo off, from the
// controlling terminal or, without one, from standard input. FreeBSD and
// OpenBSD have it too; their module maps are unchecked, so it's Darwin's
// here for now.

#if SYSTEM_PACKAGE_DARWIN

import Darwin

@available(System 199, *)
extension TerminalDescriptor {
  /// Options for reading a passphrase.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct PassphraseOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Leaves echo on, so that the user sees what they type.
    ///
    /// The corresponding C constant is `RPP_ECHO_ON`.
    @_alwaysEmitIntoClient
    public static var echo: PassphraseOptions { PassphraseOptions(rawValue: _RPP_ECHO_ON) }

    /// Throws ``Errno/inappropriateIOCTLForDevice``
    /// when the process has no controlling terminal,
    /// rather than reading standard input.
    ///
    /// The corresponding C constant is `RPP_REQUIRE_TTY`.
    @_alwaysEmitIntoClient
    public static var requireTerminal: PassphraseOptions {
      PassphraseOptions(rawValue: _RPP_REQUIRE_TTY)
    }

    /// Converts the passphrase's letters to lowercase.
    ///
    /// The corresponding C constant is `RPP_FORCELOWER`.
    @_alwaysEmitIntoClient
    public static var lowercase: PassphraseOptions { PassphraseOptions(rawValue: _RPP_FORCELOWER) }

    /// Converts the passphrase's letters to uppercase.
    ///
    /// The corresponding C constant is `RPP_FORCEUPPER`.
    @_alwaysEmitIntoClient
    public static var uppercase: PassphraseOptions { PassphraseOptions(rawValue: _RPP_FORCEUPPER) }

    /// Clears the high bit of each of the passphrase's bytes.
    ///
    /// The corresponding C constant is `RPP_SEVENBIT`.
    @_alwaysEmitIntoClient
    public static var sevenBit: PassphraseOptions { PassphraseOptions(rawValue: _RPP_SEVENBIT) }

    /// Reads standard input, rather than the controlling terminal,
    /// and prompts on standard error, without turning echo off.
    ///
    /// The corresponding C constant is `RPP_STDIN`.
    @_alwaysEmitIntoClient
    public static var standardInput: PassphraseOptions { PassphraseOptions(rawValue: _RPP_STDIN) }
  }

  /// Prompts for a passphrase on the controlling terminal,
  /// and reads it with echo off into a buffer.
  ///
  /// - Parameters:
  ///   - prompt: The prompt, such as `"Password: "`.
  ///   - buffer: The buffer to read into, which gets the passphrase
  ///     and a zero byte after it. The passphrase keeps at most
  ///     `buffer.count - 1` bytes; the rest of the line is discarded.
  ///   - options: How to read the passphrase. The default is none.
  /// - Returns: The number of bytes in the passphrase,
  ///   not counting the zero byte.
  ///
  /// The newline that ends the passphrase isn't kept.
  /// Without a controlling terminal, this method prompts on standard error
  /// and reads standard input, whose echo it doesn't turn off,
  /// unless `options` includes ``PassphraseOptions/requireTerminal``.
  /// An empty buffer throws ``Errno/invalidArgument``.
  ///
  /// Clear the passphrase as soon as you're done with it,
  /// with ``Memory/secureZero(_:)-(UnsafeMutableRawBufferPointer)``,
  /// so that it doesn't stay in memory:
  ///
  ///     let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: 1)
  ///     defer {
  ///       Memory.secureZero(buffer)
  ///       buffer.deallocate()
  ///     }
  ///     let count = try TerminalDescriptor.readPassphrase(prompt: "Password: ", into: buffer)
  ///
  /// A signal that `readpassphrase` catches, such as `SIGINT`,
  /// restores the terminal before the signal's handler runs,
  /// or before its default action ends the process.
  /// If the handler returns, this method throws ``Errno/interrupted``
  /// rather than prompting again, since the user sent the signal to stop.
  /// After a signal that stops the process, such as `SIGTSTP`,
  /// it prompts again when the process continues.
  ///
  /// The corresponding C function is `readpassphrase`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func readPassphrase(
    prompt: String,
    into buffer: UnsafeMutableRawBufferPointer,
    options: PassphraseOptions = []
  ) throws(Errno) -> Int {
    try _readPassphrase(prompt: prompt, into: buffer, options: options).get()
  }

  @usableFromInline
  internal static func _readPassphrase(
    prompt: String,
    into buffer: UnsafeMutableRawBufferPointer,
    options: PassphraseOptions
  ) -> Result<Int, Errno> {
    guard let start = buffer.baseAddress, buffer.count > 0 else {
      return .failure(.invalidArgument)
    }
    let characters = start.assumingMemoryBound(to: CChar.self)
    return prompt.withCString { prompt in
      guard system_readpassphrase(prompt, characters, buffer.count, options.rawValue) != nil else {
        return .failure(.current)
      }
      return .success(system_strlen(characters))
    }
  }

  /// Prompts for a passphrase on the controlling terminal,
  /// and reads it with echo off.
  ///
  /// - Parameters:
  ///   - prompt: The prompt, such as `"Password: "`.
  ///   - maxByteCount: The most bytes of the passphrase to keep,
  ///     which can't be negative; the rest of the line is discarded.
  ///     The default is 1024.
  ///   - options: How to read the passphrase. The default is none.
  /// - Returns: The passphrase, with any invalid UTF-8 repaired.
  ///
  /// This method clears its own copy of the passphrase before it returns,
  /// but a string can't be cleared. To keep the passphrase only in memory
  /// that you clear, use ``readPassphrase(prompt:into:options:)``,
  /// which describes the rest of this method's behavior.
  ///
  /// The corresponding C function is `readpassphrase`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func readPassphrase(
    prompt: String,
    maxByteCount: Int = 1024,
    options: PassphraseOptions = []
  ) throws(Errno) -> String {
    try _readPassphrase(prompt: prompt, maxByteCount: maxByteCount, options: options).get()
  }

  @usableFromInline
  internal static func _readPassphrase(
    prompt: String,
    maxByteCount: Int,
    options: PassphraseOptions
  ) -> Result<String, Errno> {
    precondition(maxByteCount >= 0, "maxByteCount can't be negative")
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: maxByteCount + 1, alignment: 1)
    defer {
      Memory._secureZero(buffer)
      buffer.deallocate()
    }
    return _readPassphrase(prompt: prompt, into: buffer, options: options).map { count in
      String(decoding: UnsafeRawBufferPointer(rebasing: buffer[..<count]), as: UTF8.self)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
