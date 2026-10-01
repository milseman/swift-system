/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

// Must import here to use C termios properties.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// Terminal I/O attributes.
///
/// This type represents the POSIX `termios` structure, providing type-safe access
/// to input modes, output modes, control modes, local modes, control characters,
/// and baud rates.
@frozen
@available(System 199, *)
public struct TerminalAttributes: RawRepresentable, Equatable, Hashable, Sendable {
  /// The raw C terminal attributes.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.Termios

  /// Creates strongly-typed terminal attributes from raw C terminal attributes.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.Termios) {
    self.rawValue = rawValue
  }

  /// Creates terminal attributes with every field zero.
  ///
  /// Zero isn't ``ControlCharacters/disabled`` on every platform,
  /// so on Darwin, applying these attributes makes byte 0
  /// every control character.
  /// To change a terminal's attributes, start from its current ones,
  /// which ``TerminalDescriptor/attributes()`` returns.
  @_alwaysEmitIntoClient
  public init() {
    self.rawValue = CInterop.Termios()
  }

  /// Input mode flags controlling input preprocessing.
  @_alwaysEmitIntoClient
  public var inputFlags: InputFlags {
    get { InputFlags(rawValue: rawValue.c_iflag) }
    set { rawValue.c_iflag = newValue.rawValue }
  }

  /// Output mode flags controlling output postprocessing.
  @_alwaysEmitIntoClient
  public var outputFlags: OutputFlags {
    get { OutputFlags(rawValue: rawValue.c_oflag) }
    set { rawValue.c_oflag = newValue.rawValue }
  }

  /// Control mode flags for hardware control settings.
  @_alwaysEmitIntoClient
  public var controlFlags: ControlFlags {
    get { ControlFlags(rawValue: rawValue.c_cflag) }
    set { rawValue.c_cflag = newValue.rawValue }
  }

  /// Local mode flags controlling terminal behavior.
  @_alwaysEmitIntoClient
  public var localFlags: LocalFlags {
    get { LocalFlags(rawValue: rawValue.c_lflag) }
    set { rawValue.c_lflag = newValue.rawValue }
  }

  /// Control characters for special input handling.
  @_alwaysEmitIntoClient
  public var controlCharacters: ControlCharacters {
    get {
      withUnsafePointer(to: rawValue.c_cc) { ptr in
        ptr.withMemoryRebound(to: ControlCharacters.self, capacity: 1) { $0.pointee }
      }
    }
    set {
      withUnsafeMutablePointer(to: &rawValue.c_cc) { ptr in
        ptr.withMemoryRebound(to: ControlCharacters.self, capacity: 1) { $0.pointee = newValue }
      }
    }
  }

  /// The input baud rate.
  ///
  /// Some C libraries on Linux keep a single rate for both directions,
  /// so setting this property can change ``outputSpeed`` too.
  /// Setting a rate that the C library doesn't support
  /// leaves the attributes unchanged.
  ///
  /// The corresponding C functions are `cfgetispeed` and `cfsetispeed`.
  @_alwaysEmitIntoClient
  public var inputSpeed: BaudRate {
    get {
      withUnsafePointer(to: rawValue) { ptr in
        BaudRate(rawValue: system_cfgetispeed(ptr))
      }
    }
    set {
      withUnsafeMutablePointer(to: &rawValue) { ptr in
        _ = system_cfsetispeed(ptr, newValue.rawValue)
      }
    }
  }

  /// The output baud rate.
  ///
  /// Applying attributes with an output rate of ``BaudRate/hangUp``
  /// hangs up the line.
  /// Setting a rate that the C library doesn't support
  /// leaves the attributes unchanged.
  ///
  /// The corresponding C functions are `cfgetospeed` and `cfsetospeed`.
  @_alwaysEmitIntoClient
  public var outputSpeed: BaudRate {
    get {
      withUnsafePointer(to: rawValue) { ptr in
        BaudRate(rawValue: system_cfgetospeed(ptr))
      }
    }
    set {
      withUnsafeMutablePointer(to: &rawValue) { ptr in
        _ = system_cfsetospeed(ptr, newValue.rawValue)
      }
    }
  }

  /// Sets both the input and the output baud rate.
  ///
  /// - Parameters:
  ///   - speed: The new rate.
  ///
  /// A rate that the C library doesn't support
  /// leaves the attributes unchanged.
  ///
  /// The corresponding C function is `cfsetspeed`.
  @_alwaysEmitIntoClient
  public mutating func setSpeed(_ speed: BaudRate) {
    withUnsafeMutablePointer(to: &rawValue) { ptr in
      _ = system_cfsetspeed(ptr, speed.rawValue)
    }
  }

  /// Configures these attributes for raw mode in place.
  ///
  /// In raw mode, input can be read a byte at a time, as soon as it arrives,
  /// and passes through unchanged: the terminal doesn't collect it into
  /// lines, echo it, or treat any character specially.
  /// Output passes through without postprocessing,
  /// and characters have 8 bits and no parity.
  /// Exactly which flags raw mode changes varies by platform.
  ///
  /// The corresponding C function is `cfmakeraw`.
  public mutating func makeRaw() {
    withUnsafeMutablePointer(to: &rawValue) { system_cfmakeraw($0) }
  }

  /// Returns a copy of these attributes configured for raw mode,
  /// as ``makeRaw()`` describes.
  ///
  /// The corresponding C function is `cfmakeraw`.
  @_alwaysEmitIntoClient
  public func raw() -> TerminalAttributes {
    var copy = self
    copy.makeRaw()
    return copy
  }

  // MARK: - Equatable & Hashable

  /// Returns whether two values have the same flags, control characters,
  /// and speeds, and on Linux, the same line discipline.
  ///
  /// Alignment padding in the C structure isn't compared.
  @_alwaysEmitIntoClient
  public static func == (lhs: TerminalAttributes, rhs: TerminalAttributes) -> Bool {
    #if os(Linux) || os(Android)
    guard lhs.rawValue.c_line == rhs.rawValue.c_line else { return false }
    #endif
    return lhs.inputFlags == rhs.inputFlags
      && lhs.outputFlags == rhs.outputFlags
      && lhs.controlFlags == rhs.controlFlags
      && lhs.localFlags == rhs.localFlags
      && lhs.controlCharacters == rhs.controlCharacters
      && lhs.inputSpeed == rhs.inputSpeed
      && lhs.outputSpeed == rhs.outputSpeed
  }

  /// Hashes the fields that `==` compares.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    #if os(Linux) || os(Android)
    hasher.combine(rawValue.c_line)
    #endif
    hasher.combine(inputFlags)
    hasher.combine(outputFlags)
    hasher.combine(controlFlags)
    hasher.combine(localFlags)
    hasher.combine(controlCharacters)
    hasher.combine(inputSpeed)
    hasher.combine(outputSpeed)
  }
}

// MARK: - SetAction

@available(System 199, *)
extension TerminalAttributes {
  /// Specifies when to apply terminal attribute changes.
  @frozen
  @available(System 199, *)
  public struct SetAction: RawRepresentable, Hashable, Sendable {
    /// The raw C action.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed action from a raw C action.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) {
      self.rawValue = rawValue
    }

    /// Apply changes immediately.
    ///
    /// The corresponding C constant is `TCSANOW`.
    @_alwaysEmitIntoClient
    public static var now: Self { Self(rawValue: _TCSANOW) }

    /// Apply changes after all pending output has been transmitted.
    ///
    /// The corresponding C constant is `TCSADRAIN`.
    @_alwaysEmitIntoClient
    public static var afterDrain: Self { Self(rawValue: _TCSADRAIN) }

    /// Apply changes after all pending output has been transmitted,
    /// and discard any unread input.
    ///
    /// Programs usually enter raw mode this way,
    /// so that input typed beforehand isn't read in the new mode.
    ///
    /// The corresponding C constant is `TCSAFLUSH`.
    @_alwaysEmitIntoClient
    public static var afterFlush: Self { Self(rawValue: _TCSAFLUSH) }

    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    /// Apply changes immediately,
    /// except to the hardware settings: the control flags and the speeds.
    ///
    /// `TCSASOFT` is a flag that modifies an action. This value combines it
    /// with `TCSANOW`, whose value is zero. To modify another action,
    /// combine their raw values:
    ///
    ///     let softDrain = TerminalAttributes.SetAction(
    ///       rawValue: TerminalAttributes.SetAction.afterDrain.rawValue
    ///         | TerminalAttributes.SetAction.soft.rawValue)
    ///
    /// The corresponding C constant is `TCSASOFT`.
    @_alwaysEmitIntoClient
    public static var soft: Self { Self(rawValue: _TCSASOFT) }
    #endif
  }
}

#endif // !os(Windows) && !os(WASI)
