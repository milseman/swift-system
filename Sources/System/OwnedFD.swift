/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: exploring a noncopyable file descriptor that guarantees closure.
// Not API. See `Sources/Samples/Owned*.swift` for uses.

/// A file descriptor that is closed exactly once,
/// at the end of its lifetime or by an explicit call to `close()`.
///
/// `OwnedFD` can't be copied.
/// A function that takes a `borrowing OwnedFD` parameter
/// can read, write, and seek,
/// and can reach other operations through ``fileDescriptor``,
/// but can't close the `OwnedFD` or keep it after returning.
///
/// Destroying an `OwnedFD` closes its file descriptor and ignores any error,
/// as `closeAfter(_:)` does when its closure throws.
/// To handle an error from closing, call `close()`.
///
/// One error from closing isn't ignored:
/// destroying an `OwnedFD` traps if its file descriptor was already closed
/// (`EBADF`), because that means something other than its owner closed it.
@frozen
public struct OwnedFD: ~Copyable, Sendable {
  @usableFromInline
  internal let _descriptor: FileDescriptor

  /// Takes ownership of an open file descriptor.
  ///
  /// The file descriptor is closed at the end of the `OwnedFD` instance's
  /// lifetime, so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._descriptor = descriptor
  }

  deinit {
    // `deinit` can't throw, so an error from closing is dropped, as it is
    // when the owner is destroyed while an error propagates. Neither Linux
    // nor Darwin leaves the descriptor open after a failed close, so there's
    // nothing to retry. EBADF is the exception: it means the descriptor was
    // closed behind the owner's back, and if its number had been reused, this
    // close would have closed an unrelated file. Like Mach.Port's deinit,
    // this traps in every build: a debug-only check would follow this
    // module's build configuration, so it would never fire in a release
    // build of the library. See Prototype/CloseErrors for the alternatives.
    if case .failure(.badFileDescriptor) = _descriptor._close() {
      preconditionFailure(
        "OwnedFD: file descriptor \(_descriptor.rawValue) was already closed, "
          + "by something other than its owner")
    }
  }
}

// Standard file descriptors.
extension OwnedFD {
  /// The standard input file descriptor, with a numeric value of 0.
  ///
  /// Static stored properties are never destroyed and can't be consumed,
  /// so this value never closes standard input.
  public static let standardInput = OwnedFD(taking: .standardInput)

  /// The standard output file descriptor, with a numeric value of 1.
  public static let standardOutput = OwnedFD(taking: .standardOutput)

  /// The standard error file descriptor, with a numeric value of 2.
  public static let standardError = OwnedFD(taking: .standardError)
}

// Ownership.
extension OwnedFD {
  /// Opens or creates a file for reading or writing.
  ///
  /// See `FileDescriptor.open(_:_:options:permissions:retryOnInterrupt:)`.
  ///
  /// The corresponding C function is `open`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> OwnedFD {
    #if !os(Windows)
    let result = path.withCString {
      FileDescriptor._open(
        $0, mode, options: options, permissions: permissions,
        retryOnInterrupt: retryOnInterrupt)
    }
    #else
    let result = path.withPlatformString {
      FileDescriptor._open(
        $0, mode, options: options, permissions: permissions,
        retryOnInterrupt: retryOnInterrupt)
    }
    #endif
    return OwnedFD(taking: try result.get())
  }

  /// Closes the file descriptor.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    let descriptor = _descriptor
    discard self
    try descriptor._close().get()
  }

  /// Transfers ownership of the file descriptor to the caller
  /// without closing it.
  ///
  /// After this method returns, the caller is responsible for closing
  /// the returned file descriptor.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    let descriptor = _descriptor
    discard self
    return descriptor
  }

  /// The file descriptor, for operations that `OwnedFD` doesn't provide.
  ///
  /// The returned value refers to the same open file,
  /// but it doesn't own it:
  /// it's valid only while this `OwnedFD` instance is alive.
  /// Don't close it, and don't keep it,
  /// even from a temporary instance such as the result of `open`.
  /// If something closes it, the instance's own close fails with `EBADF`,
  /// which traps if the instance is destroyed rather than closed explicitly.
  /// To take ownership of the file descriptor, call `relinquish()`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _descriptor }
}

// Forwarded I/O. Each method calls the `FileDescriptor` method of the same
// name; see that method for documentation. OwnedFD forwards reading, writing,
// and seeking, which borrowing code does most, and throws Errno even where the
// FileDescriptor method doesn't yet. Everything else goes through
// `fileDescriptor`, so that new FileDescriptor API needs no OwnedFD change.
// See Prototype/Forwarding for the costs of forwarding the rest.
extension OwnedFD {
  /// Repositions the offset for the file descriptor.
  ///
  /// The corresponding C function is `lseek`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func seek(
    offset: Int64, from whence: FileDescriptor.SeekOrigin
  ) throws(Errno) -> Int64 {
    try _descriptor._seek(offset: offset, from: whence).get()
  }

  /// Reads bytes at the current file offset into a buffer.
  ///
  /// The corresponding C function is `read`.
  @_alwaysEmitIntoClient
  public func read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor._read(into: buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Reads bytes at the specified offset into a buffer.
  ///
  /// The corresponding C function is `pread`.
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64,
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor._read(
      fromAbsoluteOffset: offset, into: buffer, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Writes the contents of a buffer at the current file offset.
  ///
  /// The corresponding C function is `write`.
  @_alwaysEmitIntoClient
  public func write(
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor._write(buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Writes the contents of a buffer at the specified offset.
  ///
  /// The corresponding C function is `pwrite`.
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor._write(
      toAbsoluteOffset: offset, buffer, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Writes a sequence of bytes to the current offset
  /// and then updates the offset.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll<S: Sequence>(
    _ sequence: S
  ) throws(Errno) -> Int where S.Element == UInt8 {
    try _descriptor._writeAll(sequence).get()
  }

  /// Writes a sequence of bytes to the given offset.
  @_alwaysEmitIntoClient
  @discardableResult
  public func writeAll<S: Sequence>(
    toAbsoluteOffset offset: Int64, _ sequence: S
  ) throws(Errno) -> Int where S.Element == UInt8 {
    try _descriptor._writeAll(toAbsoluteOffset: offset, sequence).get()
  }

  /// Writes the contents of a buffer at the current file offset.
  ///
  /// The corresponding C function is `write`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func write(
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.write(data, retryOnInterrupt: retryOnInterrupt)
  }

  /// Writes the contents of a buffer at the specified offset.
  ///
  /// The corresponding C function is `pwrite`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.write(
      toAbsoluteOffset: offset, data, retryOnInterrupt: retryOnInterrupt)
  }

  /// Writes the entire contents of a buffer, retrying on partial writes.
  ///
  /// The corresponding C function is `write`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func writeAll(
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.writeAll(data, retryOnInterrupt: retryOnInterrupt)
  }

  /// Writes the entire contents of a buffer at the specified offset,
  /// retrying on partial writes.
  ///
  /// The corresponding C function is `pwrite`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func writeAll(
    toAbsoluteOffset offset: Int64,
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.writeAll(
      toAbsoluteOffset: offset, data, retryOnInterrupt: retryOnInterrupt)
  }

  /// Reads bytes at the current file offset into a buffer.
  ///
  /// The corresponding C function is `read`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func read(
    into buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.read(into: &buffer, retryOnInterrupt: retryOnInterrupt)
  }

  /// Reads bytes at the specified offset into a buffer.
  ///
  /// The corresponding C function is `pread`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64,
    into buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.read(
      fromAbsoluteOffset: offset, into: &buffer, retryOnInterrupt: retryOnInterrupt)
  }

  /// Reads bytes into a buffer, retrying until it is full.
  ///
  /// The corresponding C function is `read`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  @discardableResult
  public func read(
    filling buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.read(filling: &buffer, retryOnInterrupt: retryOnInterrupt)
  }

  /// Reads bytes at the specified offset into a buffer,
  /// retrying until it is full.
  ///
  /// The corresponding C function is `pread`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  @discardableResult
  public func read(
    fromAbsoluteOffset offset: Int64,
    filling buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try _descriptor.read(
      fromAbsoluteOffset: offset, filling: &buffer, retryOnInterrupt: retryOnInterrupt)
  }
}
