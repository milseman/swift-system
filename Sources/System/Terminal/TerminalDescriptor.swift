/*
 This source file is part of the Swift System open source project

 Copyright (c) 2024 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

/// A file descriptor referring to a terminal device.
///
/// `TerminalDescriptor` wraps a `FileDescriptor` and provides terminal-specific
/// operations defined by POSIX. Use the throwing initializer to verify that a
/// file descriptor refers to a terminal, ``FileDescriptor/asTerminal`` to get
/// `nil` instead of an error, or the `unchecked` initializer when you know the
/// descriptor refers to a terminal.
///
/// ```swift
/// // Checked conversion
/// if let terminal = FileDescriptor.standardInput.asTerminal {
///     var attrs = try terminal.attributes()
///     attrs.localFlags.remove(.echo)
///     try terminal.setAttributes(attrs, when: .now)
/// }
///
/// // Unchecked (use when you know it's a terminal)
/// let terminal = TerminalDescriptor(unchecked: .standardInput)
/// ```
///
/// - Note: Only available on Unix-like platforms.
@frozen
@available(System 199, *)
public struct TerminalDescriptor: RawRepresentable, Hashable, Codable, Sendable {
  /// The raw C file handle.
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  /// Creates a strongly-typed terminal descriptor from a raw C file handle.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }
}

@available(System 199, *)
extension TerminalDescriptor {
  /// The file descriptor for this terminal.
  ///
  /// Terminals are file descriptors and can be used with
  /// file descriptor operations like `read`, `write`, and `close`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor {
    FileDescriptor(rawValue: rawValue)
  }

  /// Creates a terminal descriptor from a file descriptor without verification.
  ///
  /// This initializer does not verify that the file descriptor actually
  /// refers to a terminal. Use with caution.
  @_alwaysEmitIntoClient
  public init(unchecked fd: FileDescriptor) {
    self.init(rawValue: fd.rawValue)
  }

  /// Creates a terminal descriptor from a file descriptor,
  /// verifying that the file descriptor refers to a terminal.
  ///
  /// If `fd` is open but doesn't refer to a terminal,
  /// this initializer throws ``Errno/inappropriateIOCTLForDevice`` (`ENOTTY`).
  /// If `fd` isn't open, it throws ``Errno/badFileDescriptor`` (`EBADF`).
  ///
  /// The corresponding C function is `isatty`.
  @_alwaysEmitIntoClient
  public init(_ fd: FileDescriptor) throws(Errno) {
    try Self._verify(fd).get()
    self.init(unchecked: fd)
  }

  @usableFromInline
  internal static func _verify(_ fd: FileDescriptor) -> Result<(), Errno> {
    // POSIX allows isatty to return 0 without setting errno.
    system_errno = 0
    guard system_isatty(fd.rawValue) == 0 else { return .success(()) }
    return .failure(system_errno == 0 ? .inappropriateIOCTLForDevice : .current)
  }
}

// MARK: - FileDescriptor conveniences

@available(System 199, *)
extension FileDescriptor {
  /// Returns whether this file descriptor refers to a terminal device.
  ///
  /// The corresponding C function is `isatty`.
  @_alwaysEmitIntoClient
  public var isTerminal: Bool {
    asTerminal != nil
  }

  /// Returns this file descriptor as a terminal descriptor, or `nil` if
  /// it does not refer to a terminal device.
  ///
  /// To learn why a file descriptor isn't a terminal, use
  /// ``TerminalDescriptor/init(_:)``, which throws the error instead.
  ///
  /// The corresponding C function is `isatty`.
  @_alwaysEmitIntoClient
  public var asTerminal: TerminalDescriptor? {
    try? TerminalDescriptor(self)
  }
}

#endif
