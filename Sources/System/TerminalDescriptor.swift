/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)
/// A terminal descriptor.
///
/// A `TerminalDescriptor` is a type-safe wrapper around a file descriptor
/// that refers to a terminal device, such as a pseudoterminal.
///
/// - Note: Only available on Unix-like platforms.
@frozen
public struct TerminalDescriptor: RawRepresentable, Hashable, Codable, Sendable {
  /// The raw C file handle.
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  /// Creates a strongly-typed terminal descriptor from a raw C file handle.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }
}

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
#endif
