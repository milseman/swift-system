/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

// Must import here to use the C termios initializer.
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

// MARK: - Terminal Operations

@available(System 199, *)
extension TerminalDescriptor {
  /// Returns the terminal's current attributes.
  ///
  /// - Returns: The terminal's flags, control characters, and speeds.
  ///
  /// The corresponding C function is `tcgetattr`.
  @_alwaysEmitIntoClient
  public func attributes() throws(Errno) -> TerminalAttributes {
    try _attributes().get()
  }

  @usableFromInline
  internal func _attributes() -> Result<TerminalAttributes, Errno> {
    var attrs = CInterop.Termios()
    let result = withUnsafeMutablePointer(to: &attrs) { attrsPtr in
      nothingOrErrno(retryOnInterrupt: false) {
        system_tcgetattr(rawValue, attrsPtr)
      }
    }
    return result.map { TerminalAttributes(rawValue: attrs) }
  }

  /// Changes the terminal's attributes.
  ///
  /// - Parameters:
  ///   - attributes: The new attributes.
  ///   - action: When to make the change: immediately,
  ///     after pending output is transmitted,
  ///     or after that, also discarding unread input.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method succeeds if the terminal makes any of the requested changes,
  /// and a terminal can ignore some settings: on Linux, for example,
  /// a pseudoterminal keeps 8-bit characters with no parity.
  /// To check which changes it made, call ``attributes()`` afterward.
  ///
  /// The corresponding C function is `tcsetattr`.
  @_alwaysEmitIntoClient
  public func setAttributes(
    _ attributes: TerminalAttributes,
    when action: TerminalAttributes.SetAction,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setAttributes(attributes, when: action, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setAttributes(
    _ attributes: TerminalAttributes,
    when action: TerminalAttributes.SetAction,
    retryOnInterrupt: Bool
  ) -> Result<Void, Errno> {
    var attrs = attributes.rawValue
    return withUnsafePointer(to: &attrs) { attrsPtr in
      nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_tcsetattr(rawValue, action.rawValue, attrsPtr)
      }
    }
  }

  /// Waits until all output written to the terminal has been transmitted.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// On Darwin, output to a pseudoterminal isn't transmitted
  /// until the controlling end reads it.
  ///
  /// The corresponding C function is `tcdrain`.
  @_alwaysEmitIntoClient
  public func drain(retryOnInterrupt: Bool = true) throws(Errno) {
    try _drain(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _drain(retryOnInterrupt: Bool) -> Result<Void, Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_tcdrain(rawValue)
    }
  }

  /// Discards data in the specified queue(s).
  ///
  /// - Parameters:
  ///   - queue: The data to discard: input that was received but not read,
  ///     output that was written but not transmitted, or both.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `tcflush`.
  @_alwaysEmitIntoClient
  public func flush(_ queue: Queue, retryOnInterrupt: Bool = true) throws(Errno) {
    try _flush(queue, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _flush(_ queue: Queue, retryOnInterrupt: Bool) -> Result<Void, Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_tcflush(rawValue, queue.rawValue)
    }
  }

  /// Suspends or resumes data transmission or reception.
  ///
  /// - Parameters:
  ///   - action: Whether to suspend or resume output,
  ///     or to transmit a STOP or START character.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `tcflow`.
  @_alwaysEmitIntoClient
  public func flow(_ action: FlowAction, retryOnInterrupt: Bool = true) throws(Errno) {
    try _flow(action, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _flow(_ action: FlowAction, retryOnInterrupt: Bool) -> Result<Void, Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_tcflow(rawValue, action.rawValue)
    }
  }

  /// Sends a break signal on the terminal.
  ///
  /// - Parameters:
  ///   - duration: The length of the break.
  ///     Zero sends a break of between 0.25 and 0.5 seconds;
  ///     the meaning of other values varies by platform.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `tcsendbreak`.
  @_alwaysEmitIntoClient
  public func sendBreak(duration: CInt = 0, retryOnInterrupt: Bool = true) throws(Errno) {
    try _sendBreak(duration: duration, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _sendBreak(duration: CInt, retryOnInterrupt: Bool) -> Result<Void, Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_tcsendbreak(rawValue, duration)
    }
  }

  /// Changes the terminal's attributes, calls a closure,
  /// and then restores the original attributes.
  ///
  /// - Parameters:
  ///   - action: When to make the change. The default, `.afterFlush`,
  ///     makes it after pending output is transmitted,
  ///     and discards unread input.
  ///   - retryOnInterrupt: Whether to retry making the change
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///   - modify: A closure that changes a copy of the current attributes.
  ///   - body: The closure to call with the changed attributes in effect.
  /// - Returns: The value that `body` returns.
  ///
  /// This method restores the original attributes immediately after `body`
  /// returns or throws. It ignores an error from restoring them.
  /// If reading or changing the attributes fails,
  /// or `modify` throws, `body` isn't called.
  ///
  /// The corresponding C functions are `tcgetattr` and `tcsetattr`.
  public func withAttributes<T>(
    appliedWhen action: TerminalAttributes.SetAction = .afterFlush,
    retryOnInterrupt: Bool = true,
    _ modify: (inout TerminalAttributes) throws -> Void,
    do body: () throws -> T
  ) throws -> T {
    let original = try attributes()
    var modified = original
    try modify(&modified)
    try setAttributes(modified, when: action, retryOnInterrupt: retryOnInterrupt)
    defer {
      _ = try? setAttributes(original, when: .now)
    }
    return try body()
  }

  /// Puts the terminal in raw mode, calls a closure,
  /// and then restores the original attributes.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the change to raw mode
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///   - body: The closure to call in raw mode.
  /// - Returns: The value that `body` returns.
  ///
  /// This method changes the attributes as
  /// ``TerminalAttributes/makeRaw()`` does, after pending output is
  /// transmitted, discarding unread input, and restores them as
  /// ``withAttributes(appliedWhen:retryOnInterrupt:_:do:)`` does.
  ///
  /// The corresponding C functions are `tcgetattr`, `cfmakeraw`,
  /// and `tcsetattr`.
  public func withRawMode<T>(retryOnInterrupt: Bool = true, do body: () throws -> T) throws -> T {
    try withAttributes(retryOnInterrupt: retryOnInterrupt, { $0.makeRaw() }, do: body)
  }
}

// MARK: - Supporting Types

@available(System 199, *)
extension TerminalDescriptor {
  /// Data that ``flush(_:retryOnInterrupt:)`` discards.
  @frozen
  @available(System 199, *)
  public struct Queue: RawRepresentable, Hashable, Sendable {
    /// The raw C queue selector.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed queue selector from a raw C queue selector.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) {
      self.rawValue = rawValue
    }

    /// Input that the terminal has received but that hasn't been read.
    ///
    /// The corresponding C constant is `TCIFLUSH`.
    @_alwaysEmitIntoClient
    public static var input: Self { Self(rawValue: _TCIFLUSH) }

    /// Output that has been written but not yet transmitted.
    ///
    /// The corresponding C constant is `TCOFLUSH`.
    @_alwaysEmitIntoClient
    public static var output: Self { Self(rawValue: _TCOFLUSH) }

    /// Both unread input and untransmitted output.
    ///
    /// The corresponding C constant is `TCIOFLUSH`.
    @_alwaysEmitIntoClient
    public static var both: Self { Self(rawValue: _TCIOFLUSH) }
  }

  /// Actions for ``flow(_:retryOnInterrupt:)``.
  @frozen
  @available(System 199, *)
  public struct FlowAction: RawRepresentable, Hashable, Sendable {
    /// The raw C flow control action.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed flow control action
    /// from a raw C flow control action.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) {
      self.rawValue = rawValue
    }

    /// Suspends output.
    ///
    /// The corresponding C constant is `TCOOFF`.
    @_alwaysEmitIntoClient
    public static var suspendOutput: Self { Self(rawValue: _TCOOFF) }

    /// Resumes suspended output.
    ///
    /// The corresponding C constant is `TCOON`.
    @_alwaysEmitIntoClient
    public static var resumeOutput: Self { Self(rawValue: _TCOON) }

    /// Transmits a STOP character,
    /// which asks the device to stop sending input.
    ///
    /// On Darwin, the terminal transmits the character
    /// only if ``InputFlags/startStopInput`` is set.
    ///
    /// The corresponding C constant is `TCIOFF`.
    @_alwaysEmitIntoClient
    public static var sendStop: Self { Self(rawValue: _TCIOFF) }

    /// Transmits a START character,
    /// which asks the device to resume sending input.
    ///
    /// On Darwin, the terminal transmits the character
    /// only if ``InputFlags/startStopInput`` is set.
    ///
    /// The corresponding C constant is `TCION`.
    @_alwaysEmitIntoClient
    public static var sendStart: Self { Self(rawValue: _TCION) }
  }
}

#endif // !os(Windows) && !os(WASI)
