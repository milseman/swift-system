/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

@_implementationOnly import SystemInternals

// @available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
extension FileDescriptor {
  /// Opens or creates a file for reading or writing.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A file descriptor for the open file
  ///
  /// The corresponding C function is `open`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws -> FileDescriptor {
    try path.withCString {
      try FileDescriptor.open(
        $0, mode, options: options, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }
  }

  /// Opens or creates a file for reading or writing.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A file descriptor for the open file
  ///
  /// The corresponding C function is `open`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CChar>,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws -> FileDescriptor {
    try FileDescriptor._open(
      path, mode, options: options, permissions: permissions, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CChar>,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions,
    permissions: FilePermissions?,
    retryOnInterrupt: Bool = true
  ) -> Result<FileDescriptor, Errno> {
    let oFlag = mode.rawValue | options.rawValue
    let descOrError: Result<CInt, Errno> = valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if let permissions = permissions {
        return system_open(path, oFlag, permissions.rawValue)
      }
      precondition(!options.contains(.create),
        "Create must be given permissions")
      return system_open(path, oFlag)
    }
    return descOrError.map { FileDescriptor(rawValue: $0) }
  }

  /// Deletes a file descriptor.
  ///
  /// Deletes the file descriptor from the per-process object reference table.
  /// If this is the last reference to the underlying object,
  /// the object will be deactivated.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public func close() throws { try _close().get() }

  @usableFromInline
  internal func _close() -> Result<(), Errno> {
    nothingOrErrno(system_close(self.rawValue))
  }

  /// Reposition the offset for the given file descriptor.
  ///
  /// - Parameters:
  ///   - offset: The new offset for the file descriptor.
  ///   - whence: The origin of the new offset.
  /// - Returns: The file's offset location,
  ///   in bytes from the beginning of the file.
  ///
  /// The corresponding C function is `lseek`.
  @_alwaysEmitIntoClient
  @discardableResult
  public func seek(
    offset: Int64, from whence: FileDescriptor.SeekOrigin
  ) throws -> Int64 {
    try _seek(offset: offset, from: whence).get()
  }

  @usableFromInline
  internal func _seek(
    offset: Int64, from whence: FileDescriptor.SeekOrigin
  ) -> Result<Int64, Errno> {
    let newOffset = system_lseek(
          self.rawValue, _CTypes.Off(offset), whence.rawValue)
    return valueOrErrno(Int64(newOffset))
  }


  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "seek")
  public func lseek(
    offset: Int64, from whence: FileDescriptor.SeekOrigin
  ) throws -> Int64 {
    try seek(offset: offset, from: whence)
  }

  /// Reads bytes at the current file offset into a buffer.
  ///
  /// - Parameters:
  ///   - buffer: The region of memory to read into.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read.
  ///
  /// The <doc://com.apple.documentation/documentation/swift/unsafemutablerawbufferpointer/3019191-count> property of `buffer`
  /// determines the maximum number of bytes that are read into that buffer.
  ///
  /// After reading,
  /// this method increments the file's offset by the number of bytes read.
  /// To change the file's offset,
  /// call the ``seek(offset:from:)`` method.
  ///
  /// The corresponding C function is `read`.
  @_alwaysEmitIntoClient
  public func read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _read(into: buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_read(self.rawValue, buffer.baseAddress, buffer.count)
    }
  }

  /// Reads bytes at the specified offset into a buffer.
  ///
  /// - Parameters:
  ///   - offset: The file offset where reading begins.
  ///   - buffer: The region of memory to read into.
  ///   - retryOnInterrupt: Whether to retry the read operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were read.
  ///
  /// The <doc://com.apple.documentation/documentation/swift/unsafemutablerawbufferpointer/3019191-count> property of `buffer`
  /// determines the maximum number of bytes that are read into that buffer.
  ///
  /// Unlike <doc:System/FileDescriptor/read(into:retryOnInterrupt:)>,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pread`.
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64,
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _read(
      fromAbsoluteOffset: offset,
      into: buffer,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _read(
    fromAbsoluteOffset offset: Int64,
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_pread(
        self.rawValue, buffer.baseAddress, buffer.count, _CTypes.Off(offset))
    }
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "read")
  public func pread(
    fromAbsoluteOffset offset: Int64,
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try read(
      fromAbsoluteOffset: offset,
      into: buffer,
      retryOnInterrupt: retryOnInterrupt)
  }

  /// Writes the contents of a buffer at the current file offset.
  ///
  /// - Parameters:
  ///   - buffer: The region of memory that contains the data being written.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written.
  ///
  /// After writing,
  /// this method increments the file's offset by the number of bytes written.
  /// To change the file's offset,
  /// call the ``seek(offset:from:)`` method.
  ///
  /// The corresponding C function is `write`.
  @_alwaysEmitIntoClient
  public func write(
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _write(buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _write(
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_write(self.rawValue, buffer.baseAddress, buffer.count)
    }
  }

  /// Writes the contents of a buffer at the specified offset.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - buffer: The region of memory that contains the data being written.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written.
  ///
  /// Unlike ``write(_:retryOnInterrupt:)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwrite`.
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try _write(toAbsoluteOffset: offset, buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _write(
    toAbsoluteOffset offset: Int64,
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_pwrite(
        self.rawValue, buffer.baseAddress, buffer.count, _CTypes.Off(offset))
    }
  }


  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "write")
  public func pwrite(
    toAbsoluteOffset offset: Int64,
    into buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int {
    try write(
      toAbsoluteOffset: offset,
      buffer,
      retryOnInterrupt: retryOnInterrupt)
  }
}
