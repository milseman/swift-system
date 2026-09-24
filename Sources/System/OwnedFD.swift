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
/// Destroying an `OwnedFD` closes its file descriptor and ignores any error.
/// To handle an error from closing, call `close()`.
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
    // `deinit` can't throw, so an error from closing is dropped here.
    // Whether some errors, such as EBADF, should trap instead is an open
    // question; see Prototype/CloseErrors.
    _ = _descriptor._close()
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
  /// To take ownership of the file descriptor, call `relinquish()`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _descriptor }
}

#if !os(WASI)
// Pipes.
extension OwnedFD {
  /// Both ends of a pipe, each owned by an `OwnedFD`.
  ///
  /// A tuple can't hold noncopyable values,
  /// so where `FileDescriptor.pipe()` returns a tuple,
  /// `OwnedFD.pipe()` returns this structure, with the same member names.
  /// Destroying a `Pipe` closes both ends.
  /// To take the ends apart, consume each one:
  ///
  ///     let pipe = try OwnedFD.pipe()
  ///     let readEnd = pipe.readEnd
  ///     try send(message, andClose: pipe.writeEnd)
  ///
  /// `Pipe` has no deinitializer of its own, and is frozen,
  /// so code outside this module can consume its ends separately.
  /// Once one end is consumed, a closure can't capture the pipe
  /// to use the other end, so take both ends apart first
  /// if a closure needs one of them.
  @frozen
  public struct Pipe: ~Copyable, Sendable {
    /// The end of the pipe that reads data written to `writeEnd`.
    public var readEnd: OwnedFD

    /// The end of the pipe that writes data for `readEnd` to read.
    public var writeEnd: OwnedFD

    /// Creates a pipe from its two ends, taking ownership of both.
    @_alwaysEmitIntoClient
    public init(readEnd: consuming OwnedFD, writeEnd: consuming OwnedFD) {
      self.readEnd = readEnd
      self.writeEnd = writeEnd
    }
  }

  /// Creates a unidirectional data channel.
  ///
  /// See `FileDescriptor.pipe()`.
  ///
  /// The corresponding C function is `pipe`.
  @_alwaysEmitIntoClient
  public static func pipe() throws(Errno) -> Pipe {
    let ends = try FileDescriptor._pipe().get()
    return Pipe(
      readEnd: OwnedFD(taking: ends.readEnd), writeEnd: OwnedFD(taking: ends.writeEnd))
  }

  /// Creates a unidirectional data channel with the given options,
  /// such as closing both ends on `exec`, atomically.
  ///
  /// See `FileDescriptor.pipe(options:)`.
  ///
  /// The corresponding C function is `pipe2`.
  @_alwaysEmitIntoClient
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  public static func pipe(options: FileDescriptor.PipeOptions) throws(Errno) -> Pipe {
    let ends = try FileDescriptor._pipe(options: options.rawValue).get()
    return Pipe(
      readEnd: OwnedFD(taking: ends.readEnd), writeEnd: OwnedFD(taking: ends.writeEnd))
  }
}
#endif // !os(WASI)

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
