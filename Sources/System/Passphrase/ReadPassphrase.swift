/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// readpassphrase: a prompt, and a line read with echo off, from the
// controlling terminal or, without one, from standard input. FreeBSD and
// OpenBSD have it too, through CSystem, since their module maps may not
// include <readpassphrase.h>. Linux's C libraries don't have it, so there
// System takes the same steps itself, but for readpassphrase's signal
// handling.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

@available(System 199, *)
extension TerminalDescriptor {
  /// Options for reading a passphrase.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
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
  /// On Linux and Android, whose C libraries have no `readpassphrase`,
  /// this method takes its steps itself, but catches no signals:
  /// a signal that interrupts the read throws ``Errno/interrupted``
  /// after the terminal is restored,
  /// and one that ends the process leaves the terminal's echo off,
  /// as glibc's `getpass` does.
  ///
  /// The corresponding C function is `readpassphrase`.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
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
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    let characters = start.assumingMemoryBound(to: CChar.self)
    return prompt.withCString { prompt in
      guard system_readpassphrase(prompt, characters, buffer.count, options.rawValue) != nil else {
        return .failure(.current)
      }
      return .success(system_strlen(characters))
    }
    #else
    _ = start
    // readpassphrase's descriptors: the controlling terminal, unless the
    // caller asks for standard input; without one, standard input and
    // standard error, unless the caller requires a terminal.
    var terminal: FileDescriptor? = nil
    if !options.contains(.standardInput) {
      terminal = try? FileDescriptor.open("/dev/tty", .readWrite, options: .closeOnExec)
    }
    if terminal == nil && options.contains(.requireTerminal) {
      return .failure(.inappropriateIOCTLForDevice)
    }
    defer { try? terminal?.close() }
    return _readPassphrase(
      prompt: prompt, into: buffer, options: options,
      input: terminal ?? .standardInput, output: terminal ?? .standardError,
      onTerminal: terminal != nil)
    #endif
  }

  #if os(Linux) || os(Android)
  /// Reads a passphrase as `readpassphrase` does, from `input`,
  /// prompting on `output`. Like `readpassphrase`, it turns echo off only
  /// on the terminal it opened (`onTerminal`), not on standard input.
  internal static func _readPassphrase(
    prompt: String,
    into buffer: UnsafeMutableRawBufferPointer,
    options: PassphraseOptions,
    input: FileDescriptor,
    output: FileDescriptor,
    onTerminal: Bool
  ) -> Result<Int, Errno> {
    // Echo off, unless the caller asks for it, discarding what was typed
    // ahead, as readpassphrase's TCSAFLUSH does; it ignores a failure to
    // set the attributes, and so does this.
    let terminal = TerminalDescriptor(unchecked: input)
    var original: TerminalAttributes? = nil
    var echoIsOff = false
    if onTerminal, let attributes = try? terminal.attributes() {
      original = attributes
      var quiet = attributes
      if !options.contains(.echo) {
        quiet.localFlags.remove([.echo, .echoNL])
      }
      echoIsOff = !quiet.localFlags.contains(.echo)
      _ = try? terminal.setAttributes(quiet, when: .afterFlush)
    }
    defer {
      if let original, !options.contains(.echo) {
        _ = try? terminal.setAttributes(original, when: .afterFlush)
      }
    }
    _ = try? output.writeAll(prompt.utf8)

    // A line, of which the buffer keeps what fits before its zero byte.
    func isUpper(_ c: UInt8) -> Bool { (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(c) }
    func isLower(_ c: UInt8) -> Bool { (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(c) }
    let end = buffer.count - 1
    var count = 0
    var byte: UInt8 = 0
    defer { Swift.withUnsafeMutableBytes(of: &byte) { Memory._secureZero($0) } }
    var failure: Errno? = nil
    reading: while true {
      switch Swift.withUnsafeMutableBytes(of: &byte, { input._read(into: $0, retryOnInterrupt: false) }) {
      case .failure(let error):
        failure = error
        break reading
      case .success(0):
        break reading
      case .success:
        if byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") { break reading }
        guard count < end else { continue reading }
        var character = byte
        if options.contains(.sevenBit) { character &= 0x7F }
        // readpassphrase's isalpha, tolower and toupper, in the C locale.
        if options.contains(.lowercase) && isUpper(character) { character += 0x20 }
        if options.contains(.uppercase) && isLower(character) { character -= 0x20 }
        buffer[count] = character
        count += 1
      }
    }
    buffer[count] = 0
    if echoIsOff { _ = try? output.writeAll("\n".utf8) }
    if let failure { return .failure(failure) }
    return .success(count)
  }
  #endif

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
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
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

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
