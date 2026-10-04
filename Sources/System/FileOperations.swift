/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

@available(System 0.0.1, *)
extension FileDescriptor {
  /// Opens or creates a file for reading or writing.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
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
    #if !os(Windows)
    return try path.withCString {
      try FileDescriptor.open(
        $0, mode, options: options, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }
    #else 
    return try path.withPlatformString {
      try FileDescriptor.open(
        $0, mode, options: options, permissions: permissions, retryOnInterrupt: retryOnInterrupt)
    }
    #endif
  }

  #if !os(Windows) 
  // On Darwin, `CInterop.PlatformChar` is less available than 
  // `FileDescriptor.open`, so we need to use `CChar` instead.
  
  /// Opens or creates a file for reading or writing.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
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
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    let oFlag = mode.rawValue | options.rawValue
    let descOrError: Result<CInt, Errno> = valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if let permissions = permissions {
        return system_open(path, oFlag, permissions.rawValue)
      }
      if options.contains(.create) {
        fatalError(
          "FileDescriptor.open: 'permissions' must not be nil when 'options' contains '.create'")
      }
      return system_open(path, oFlag)
    }
    return descOrError.map { FileDescriptor(rawValue: $0) }
  }
  #else
  /// Opens or creates a file for reading or writing.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A file descriptor for the open file
  ///
  /// The corresponding C function is `open`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CInterop.PlatformChar>,
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
    _ path: UnsafePointer<CInterop.PlatformChar>,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions,
    permissions: FilePermissions?,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    let oFlag = mode.rawValue | options.rawValue
    let descOrError: Result<CInt, Errno> = valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if let permissions = permissions {
        return system_open(path, oFlag, permissions.rawValue)
      }
      return system_open(path, oFlag)
    }
    return descOrError.map { FileDescriptor(rawValue: $0) }
  }
  #endif

  /// Deletes a file descriptor.
  ///
  /// Deletes the file descriptor from the per-process object reference table.
  /// If this is the last reference to the underlying object,
  /// the object will be deactivated.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public func close() throws(Errno) { try _close().get() }

  @usableFromInline
  internal func _close() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_close(self.rawValue) }
  }

  /// Repositions the offset for the given file descriptor.
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
    valueOrErrno(retryOnInterrupt: false) {
      Int64(system_lseek(self.rawValue, _COffT(offset), whence.rawValue))
    }
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
  /// The <doc://com.apple.documentation/documentation/swift/unsafemutablerawbufferpointer/count-95usp> property of `buffer`
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
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
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
  /// The <doc://com.apple.documentation/documentation/swift/unsafemutablerawbufferpointer/count-95usp> property of `buffer`
  /// determines the maximum number of bytes that are read into that buffer.
  ///
  /// Unlike ``read(into:retryOnInterrupt:)-(UnsafeMutableRawBufferPointer,_)``,
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
      system_pread(self.rawValue, buffer.baseAddress, buffer.count, _COffT(offset))
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
  /// Unlike ``write(_:retryOnInterrupt:)-(UnsafeRawBufferPointer,_)``,
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
      system_pwrite(self.rawValue, buffer.baseAddress, buffer.count, _COffT(offset))
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

  /// Writes the contents of a buffer at the current file offset.
  ///
  /// - Parameters:
  ///   - data: The region of memory that contains the data being written.
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
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func write(
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try data.withUnsafeBytes { bytes throws(Errno) -> Int in
      try _write(bytes, retryOnInterrupt: retryOnInterrupt).get()
    }
  }

  /// Writes the contents of a buffer at the specified offset.
  ///
  /// - Parameters:
  ///   - offset: The file offset where writing begins.
  ///   - data: The region of memory that contains the data being written.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The number of bytes that were written.
  ///
  /// Unlike ``write(_:retryOnInterrupt:)-(RawSpan,_)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pwrite`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func write(
    toAbsoluteOffset offset: Int64,
    _ data: RawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try data.withUnsafeBytes { bytes throws(Errno) -> Int in
      try _write(toAbsoluteOffset: offset, bytes, retryOnInterrupt: retryOnInterrupt).get()
    }
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  internal func _readIntoOutputBuffer(
    _ buffer: UnsafeMutableRawBufferPointer,
    initializedCount: inout Int,
    retryOnInterrupt: Bool
  ) -> Result<Int, Errno> {
    // Read into the uninitialized portion (starting at offset 'initializedCount')
    let uninitializedPortion = UnsafeMutableRawBufferPointer(
      start: buffer.baseAddress?.advanced(by: initializedCount),
      count: buffer.count - initializedCount
    )
    let result = _read(into: uninitializedPortion, retryOnInterrupt: retryOnInterrupt)
    if case .success(let bytesRead) = result {
      initializedCount += bytesRead  // Add to existing count, don't replace it!
    }
    return result
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
  /// After reading,
  /// this method increments the file's offset by the number of bytes read.
  /// To change the file's offset,
  /// call the ``seek(offset:from:)`` method.
  ///
  /// The corresponding C function is `read`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func read(
    into buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try buffer.withUnsafeMutableBytes { buf, count throws(Errno) -> Int in
      try _readIntoOutputBuffer(buf, initializedCount: &count, retryOnInterrupt: retryOnInterrupt).get()
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
  /// Unlike ``read(into:retryOnInterrupt:)-(OutputRawSpan,_)``,
  /// this method leaves the file's existing offset unchanged.
  ///
  /// The corresponding C function is `pread`.
  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  @_alwaysEmitIntoClient
  public func read(
    fromAbsoluteOffset offset: Int64,
    into buffer: inout OutputRawSpan,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Int {
    try buffer.withUnsafeMutableBytes { buf, count throws(Errno) -> Int in
      // Read into the uninitialized portion (starting at offset 'count')
      let uninitializedPortion = UnsafeMutableRawBufferPointer(
        start: buf.baseAddress?.advanced(by: count),
        count: buf.count - count
      )
      let bytesRead = try _read(
        fromAbsoluteOffset: offset, into: uninitializedPortion,
        retryOnInterrupt: retryOnInterrupt
      ).get()
      count += bytesRead  // Add to existing count, don't replace it!
      return bytesRead
    }
  }
}

#if !os(Windows)
@available(System 199, *)
extension FileDescriptor {
  /// Opens or creates a file for reading or writing,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A file descriptor for the open file
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `openat`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    relativeTo fd: FileDescriptor,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileDescriptor {
    try path.withPlatformString {
      FileDescriptor._open(
        $0, relativeTo: fd, mode, options: options, permissions: permissions,
        retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Opens or creates a file for reading or writing,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the file to open.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - mode: The read and write access to use.
  ///   - options: The behavior for opening the file.
  ///   - permissions: The file permissions to use for created files.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A file descriptor for the open file
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C function is `openat`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileDescriptor {
    try FileDescriptor._open(
      path, relativeTo: fd, mode, options: options, permissions: permissions,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions,
    permissions: FilePermissions?,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    let oFlag = mode.rawValue | options.rawValue
    let descOrError: Result<CInt, Errno> = valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if let permissions = permissions {
        return system_openat(fd.rawValue, path, oFlag, permissions.rawValue)
      }
      if options.contains(.create) {
        fatalError(
          "FileDescriptor.open: 'permissions' must not be nil when 'options' contains '.create'")
      }
      return system_openat(fd.rawValue, path, oFlag)
    }
    return descOrError.map { FileDescriptor(rawValue: $0) }
  }
}
#endif // !os(Windows)

#if !os(WASI)
@available(System 0.0.2, *)
extension FileDescriptor {
  /// Duplicates this file descriptor and returns the newly created copy.
  ///
  /// - Parameters:
  ///   - `target`: The desired target file descriptor, or `nil`, in which case
  ///      the copy is assigned to the file descriptor with the lowest raw value
  ///      that is not currently in use by the process.
  ///   - retryOnInterrupt: Whether to retry the duplicate operation
  ///      if it throws ``Errno/interrupted``. The default is `true`.
  ///      Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file descriptor.
  ///
  /// If the `target` descriptor is already in use, then it is first
  /// deallocated as if a close(2) call had been done first.
  ///
  /// File descriptors are merely references to some underlying system resource.
  /// The system does not distinguish between the original and the new file
  /// descriptor in any way. For example, read, write and seek operations on
  /// one of them also affect the logical file position in the other, and
  /// append mode, non-blocking I/O and asynchronous I/O options are shared
  /// between the references. If a separate pointer into the file is desired,
  /// a different object reference to the file must be obtained by issuing an
  /// additional call to `open`.
  ///
  /// However, each file descriptor maintains its own close-on-exec flag.
  ///
  /// The corresponding C functions are `dup` and `dup2`.
  @_alwaysEmitIntoClient
  @available(System 0.0.2, *)
  public func duplicate(
    as target: FileDescriptor? = nil,
    retryOnInterrupt: Bool = true
  ) throws -> FileDescriptor {
    try _duplicate(as: target, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Duplicate this file descriptor and return the newly created copy.
  ///
  /// - Parameters:
  ///   - target: The desired target file descriptor.
  ///   - options: The behavior for creating the target file descriptor.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///      if it throws ``Errno/interrupted``. The default is `true`.
  ///      Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file descriptor.
  ///
  /// If the `target` descriptor is the same as `self`, then EINVAL is thrown.
  /// If the `target` descriptor is already in use, then it is first
  /// deallocated as if a close(2) call had been done first.
  ///
  /// NOTE: This overload called with an empty option set is not necessarily
  /// equivalent to calling the overload with no options, because `dup3` with
  /// no set options is not required to behave identically to `dup2`.
  ///
  /// File descriptors are merely references to some underlying system resource.
  /// The system does not distinguish between the original and the new file
  /// descriptor in any way. For example, read, write and seek operations on
  /// one of them also affect the logical file position in the other, and
  /// append mode, non-blocking I/O and asynchronous I/O options are shared
  /// between the references. If a separate pointer into the file is desired,
  /// a different object reference to the file must be obtained by issuing an
  /// additional call to `open`.
  ///
  /// However, each file descriptor maintains its own close-on-exec and
  /// close-on-fork flags.
  ///
  /// The corresponding C function is `dup3`.
  @available(Windows, unavailable)
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @_alwaysEmitIntoClient
  @discardableResult
  public func duplicate(
    as target: FileDescriptor,
    options: DuplicateOptions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileDescriptor {
    let result = _duplicate(
      as: target, options: options.rawValue, retryOnInterrupt: retryOnInterrupt
    )
    return try result.get()
  }

  @available(System 0.0.2, *)
  @usableFromInline
  internal func _duplicate(
    as target: FileDescriptor?,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      if let target {
        system_dup2(self.rawValue, target.rawValue)
      } else {
        system_dup(self.rawValue)
      }
    }.map(FileDescriptor.init(rawValue:))
  }

  @available(Windows, unavailable)
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @usableFromInline
  internal func _duplicate(
    as target: FileDescriptor,
    options: Int32,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_dup3(self.rawValue, target.rawValue, options)
    }.map(FileDescriptor.init(rawValue:))
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "duplicate")
  public func dup() throws -> FileDescriptor {
    fatalError("Not implemented")
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "duplicate")
  public func dup2() throws -> FileDescriptor {
    fatalError("Not implemented")
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "duplicate")
  public func dup3() throws -> FileDescriptor {
    fatalError("Not implemented")
  }
}
#endif // !os(WASI)

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Duplicates this file descriptor as the lowest-numbered available
  /// descriptor that is greater than or equal to a minimum.
  ///
  /// - Parameters:
  ///   - minimum: The lowest descriptor that the copy can be assigned.
  ///     The default is `0`, which gives the lowest available descriptor.
  ///   - closeOnExec: Whether the copy has the
  ///     ``DescriptorFlags/closeOnExec`` flag set.
  /// - Returns: The new file descriptor.
  ///
  /// Unlike ``duplicate(as:retryOnInterrupt:)``,
  /// this method never closes a descriptor that is already in use.
  ///
  /// Setting `closeOnExec` here, rather than by calling
  /// ``setDescriptorFlags(_:)`` on the copy afterward,
  /// sets it atomically, so another thread's `exec` can't inherit
  /// the copy in between.
  ///
  /// The corresponding C function is `fcntl`, with the `F_DUPFD` command,
  /// or `F_DUPFD_CLOEXEC` if `closeOnExec` is `true`.
  @_alwaysEmitIntoClient
  public func duplicate(
    atLeast minimum: FileDescriptor = FileDescriptor(rawValue: 0),
    closeOnExec: Bool
  ) throws(Errno) -> FileDescriptor {
    try _duplicate(atLeast: minimum, closeOnExec: closeOnExec).get()
  }

  @usableFromInline
  internal func _duplicate(
    atLeast minimum: FileDescriptor,
    closeOnExec: Bool
  ) -> Result<FileDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(
        self.rawValue, closeOnExec ? _F_DUPFD_CLOEXEC : _F_DUPFD, minimum.rawValue)
    }.map(FileDescriptor.init(rawValue:))
  }
}
#endif // !os(Windows) && !os(WASI)

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Places an advisory lock on the whole open file
  /// that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - shared: Whether to place a shared lock, which several open files
  ///     can hold at once, rather than an exclusive lock, which only one can.
  ///     The default is `false`.
  ///   - nonBlocking: Whether to throw ``Errno/wouldBlock``
  ///     if another open file holds a conflicting lock,
  ///     rather than waiting for it to be released.
  ///     The default is `false`.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The lock is advisory:
  /// it only excludes others that also lock the file.
  /// It belongs to the open file, rather than to this file descriptor,
  /// so descriptors duplicated from this one share it.
  /// The lock is released by ``unlockWholeFile(retryOnInterrupt:)``,
  /// or when the last descriptor for the open file is closed.
  /// Locking a file that this open file has already locked
  /// converts the lock to the requested kind.
  ///
  /// These whole-file locks aren't the record locks that
  /// ``lock(_:byteRange:retryOnInterrupt:)`` places,
  /// which can cover part of a file.
  /// On Darwin the two kinds of lock conflict with each other;
  /// on Linux they're independent.
  /// This kind of lock is the one that the
  /// ``OpenOptions/sharedLock`` and ``OpenOptions/exclusiveLock``
  /// options place, where they're available.
  ///
  /// The corresponding C function is `flock`.
  /// The corresponding C constants are `LOCK_EX`, `LOCK_SH`, and `LOCK_NB`.
  @_alwaysEmitIntoClient
  public func lockWholeFile(
    shared: Bool = false,
    nonBlocking: Bool = false,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    let operation = (shared ? _LOCK_SH : _LOCK_EX) | (nonBlocking ? _LOCK_NB : 0)
    try _flock(operation, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Removes the advisory whole-file lock from the open file
  /// that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method removes the lock that
  /// ``lockWholeFile(shared:nonBlocking:retryOnInterrupt:)`` places.
  ///
  /// The corresponding C function is `flock`, with `LOCK_UN`.
  @_alwaysEmitIntoClient
  public func unlockWholeFile(retryOnInterrupt: Bool = true) throws(Errno) {
    try _flock(_LOCK_UN, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _flock(_ operation: CInt, retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_flock(self.rawValue, operation)
    }
  }
}
#endif // !os(Windows) && !os(WASI)

#if !os(WASI)
@available(System 1.1.0, *)
extension FileDescriptor {
  /// Creates a unidirectional data channel, which can be used for
  /// interprocess communication.
  ///
  /// - Returns: The pair of file descriptors.
  ///
  /// The corresponding C function is `pipe`.
  @_alwaysEmitIntoClient
  @available(System 1.1.0, *)
  public static func pipe(
  ) throws -> (readEnd: FileDescriptor, writeEnd: FileDescriptor) {
    try _pipe().get()
  }

  /// Creates a unidirectional data channel, which can be used for
  /// interprocess communication.
  ///
  /// NOTE: This overload called with an empty option set is not necessarily
  /// equivalent to calling the overload with no options. On Windows, the
  /// no-parameter `pipe()` overload enables the `.closeOnExec` behaviour,
  /// but this overload disables it when called with an empty option set.
  ///
  /// - Parameters:
  ///   - options: The behavior for creating the pipe.
  ///
  /// - Returns: The pair of file descriptors.
  ///
  /// The corresponding C function is `pipe2`.
  @_alwaysEmitIntoClient
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  public static func pipe(
    options: PipeOptions
  ) throws(Errno) -> (readEnd: FileDescriptor, writeEnd: FileDescriptor) {
    try _pipe(options: options.rawValue).get()
  }

  @available(System 1.1.0, *)
  @usableFromInline
  internal static func _pipe(
  ) -> Result<(readEnd: FileDescriptor, writeEnd: FileDescriptor), Errno> {
    var fds: (Int32, Int32) = (-1, -1)
    return withUnsafeMutablePointer(to: &fds) { pointer in
      pointer.withMemoryRebound(to: Int32.self, capacity: 2) { fds in
        valueOrErrno(retryOnInterrupt: false) {
          system_pipe(fds)
        }.map { _ in (.init(rawValue: fds[0]), .init(rawValue: fds[1])) }
      }
    }
  }

  @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @usableFromInline
  internal static func _pipe(
    options: Int32,
  ) -> Result<(readEnd: FileDescriptor, writeEnd: FileDescriptor), Errno> {
    var fds: (Int32, Int32) = (-1, -1)
    return withUnsafeMutablePointer(to: &fds) { pointer in
      pointer.withMemoryRebound(to: Int32.self, capacity: 2) { fds in
        valueOrErrno(retryOnInterrupt: false) {
          system_pipe2(fds, options)
        }.map { _ in (.init(rawValue: fds[0]), .init(rawValue: fds[1])) }
      }
    }
  }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "pipe")
  public static func pipe2() throws -> FileDescriptor {
    fatalError("Not implemented")
  }
}
#endif // !os(WASI)

@available(System 1.2.0, *)
extension FileDescriptor {
  /// Truncates or extends the file referenced by this file descriptor.
  ///
  /// - Parameters:
  ///   - newSize: The length in bytes to resize the file to.
  ///   - retryOnInterrupt: Whether to retry the write operation
  ///      if it throws ``Errno/interrupted``. The default is `true`.
  ///      Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The file referenced by this file descriptor will by truncated (or extended) to `newSize`.
  ///
  /// If the current size of the file exceeds `newSize`, any extra data is discarded. If the current
  /// size of the file is smaller than `newSize`, the file is extended and filled with zeros to the
  /// provided size.
  ///
  /// This function requires that the file has been opened for writing.
  ///
  /// - Note: This function does not modify the current offset for any open file descriptors
  /// associated with the file.
  ///
  /// The corresponding C function is `ftruncate`.
  @available(System 1.2.0, *)
  @_alwaysEmitIntoClient
  public func resize(
    to newSize: Int64,
    retryOnInterrupt: Bool = true
  ) throws {
    try _resize(
      to: newSize,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @available(System 1.2.0, *)
  @usableFromInline
  internal func _resize(
    to newSize: Int64,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_ftruncate(self.rawValue, _COffT(newSize))
    }
  }
}

#if !os(Windows)
@available(System 199, *)
extension FileDescriptor {
  /// Flushes modified data and metadata of the file referenced by this
  /// file descriptor to its storage device.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method blocks until the storage device reports
  /// that the transfer has completed.
  /// What that guarantees about durability varies by platform;
  /// for more information, see the `fsync(2)` man page.
  ///
  /// The corresponding C function is `fsync`.
  @_alwaysEmitIntoClient
  public func synchronize(retryOnInterrupt: Bool = true) throws(Errno) {
    try _synchronize(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _synchronize(retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fsync(self.rawValue)
    }
  }
}
#endif // !os(Windows)

#if !os(Windows) && !SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension FileDescriptor {
  /// Flushes modified data of the file referenced by this file descriptor
  /// to its storage device, along with only the metadata needed
  /// to retrieve that data.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Unlike ``synchronize(retryOnInterrupt:)``,
  /// this method doesn't flush metadata such as the modification time
  /// unless that metadata is needed to read the data back.
  ///
  /// The corresponding C function is `fdatasync`.
  /// - Note: Not available on Darwin.
  @_alwaysEmitIntoClient
  public func synchronizeData(retryOnInterrupt: Bool = true) throws(Errno) {
    try _synchronizeData(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _synchronizeData(retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fdatasync(self.rawValue)
    }
  }
}
#endif // !os(Windows) && !SYSTEM_PACKAGE_DARWIN

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Changes the permissions of the file referenced by this file descriptor.
  ///
  /// - Parameters:
  ///   - permissions: The new permissions for the file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `fchmod`.
  @_alwaysEmitIntoClient
  public func setPermissions(
    _ permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setPermissions(permissions, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setPermissions(
    _ permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchmod(self.rawValue, permissions.rawValue)
    }
  }
}
#endif // !os(Windows) && !os(WASI)

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Changes the owner and group of the file referenced by this file descriptor.
  ///
  /// - Parameters:
  ///   - user: The new owner of the file,
  ///     or `nil` to leave the owner unchanged.
  ///   - group: The new group of the file,
  ///     or `nil` to leave the group unchanged.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Changing the owner typically requires appropriate privileges.
  /// The owner of a file can change its group
  /// to any group that the owner is a member of.
  ///
  /// The corresponding C function is `fchown`.
  @_alwaysEmitIntoClient
  public func setOwner(
    user: UserID? = nil,
    group: GroupID? = nil,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setOwner(user: user, group: group, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setOwner(
    user: UserID?,
    group: GroupID?,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    // An ID of -1 leaves the corresponding value unchanged.
    let uid = user?.rawValue ?? CInterop.UserID(truncatingIfNeeded: -1)
    let gid = group?.rawValue ?? CInterop.GroupID(truncatingIfNeeded: -1)
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchown(self.rawValue, uid, gid)
    }
  }
}
#endif // !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension FileDescriptor {
  /// Replaces the flags of the file referenced by this file descriptor.
  ///
  /// - Parameters:
  ///   - flags: The new flags for the file.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method sets all of the file's flags at once.
  /// To change individual flags,
  /// start from the file's current flags, given by ``Stat/flags``.
  /// Some flags can only be changed by the superuser,
  /// and some can't be changed at all;
  /// see the documentation for each flag in ``FileFlags``.
  ///
  /// The corresponding C function is `fchflags`.
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public func setFileFlags(
    _ flags: FileFlags,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _setFileFlags(flags, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _setFileFlags(
    _ flags: FileFlags,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fchflags(self.rawValue, flags.rawValue)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Returns the flags of this file descriptor.
  ///
  /// - Returns: The file descriptor's flags,
  ///   such as ``DescriptorFlags/closeOnExec``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETFD` command.
  @_alwaysEmitIntoClient
  public func descriptorFlags() throws(Errno) -> DescriptorFlags {
    try _descriptorFlags().get()
  }

  @usableFromInline
  internal func _descriptorFlags() -> Result<DescriptorFlags, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_GETFD)
    }.map(DescriptorFlags.init(rawValue:))
  }

  /// Replaces the flags of this file descriptor.
  ///
  /// - Parameters:
  ///   - flags: The new flags for the file descriptor.
  ///
  /// This method sets all of the file descriptor's flags at once.
  /// To change one flag, start from the current flags:
  ///
  ///     try fd.setDescriptorFlags(fd.descriptorFlags().union(.closeOnExec))
  ///
  /// The corresponding C function is `fcntl`, with the `F_SETFD` command.
  @_alwaysEmitIntoClient
  public func setDescriptorFlags(_ flags: DescriptorFlags) throws(Errno) {
    try _setDescriptorFlags(flags).get()
  }

  @usableFromInline
  internal func _setDescriptorFlags(_ flags: DescriptorFlags) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_SETFD, flags.rawValue)
    }
  }
}
#endif // !os(Windows) && !os(WASI)

#if !os(Windows)
@available(System 199, *)
extension FileDescriptor {
  /// Returns the status flags of the open file that this file descriptor
  /// refers to.
  ///
  /// - Returns: The open file's status flags,
  ///   such as ``StatusFlags/nonBlocking``.
  ///
  /// All the file descriptors that refer to the same open file
  /// share its status flags.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETFL` command.
  /// The access mode, which that command also returns,
  /// is given by ``accessMode()``.
  @_alwaysEmitIntoClient
  public func statusFlags() throws(Errno) -> StatusFlags {
    try _statusFlags().get()
  }

  @usableFromInline
  internal func _statusFlags() -> Result<StatusFlags, Errno> {
    _fileStatus().map { StatusFlags(rawValue: $0 & ~_O_ACCMODE) }
  }

  /// Replaces the status flags of the open file that this file descriptor
  /// refers to.
  ///
  /// - Parameters:
  ///   - flags: The new status flags for the open file.
  ///
  /// This method sets all of the open file's status flags at once.
  /// To change one flag, start from the current flags:
  ///
  ///     try fd.setStatusFlags(fd.statusFlags().union(.nonBlocking))
  ///
  /// All the file descriptors that refer to the same open file
  /// share its status flags, so the change affects all of them,
  /// including descriptors in other processes.
  /// Not every flag can be changed after a file is opened;
  /// the system ignores changes it doesn't support.
  ///
  /// The corresponding C function is `fcntl`, with the `F_SETFL` command.
  @_alwaysEmitIntoClient
  public func setStatusFlags(_ flags: StatusFlags) throws(Errno) {
    try _setStatusFlags(flags).get()
  }

  @usableFromInline
  internal func _setStatusFlags(_ flags: StatusFlags) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_SETFL, flags.rawValue)
    }
  }

  /// Returns the read and write access that the open file that this
  /// file descriptor refers to was opened with.
  ///
  /// - Returns: The open file's access mode.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETFL` command.
  @_alwaysEmitIntoClient
  public func accessMode() throws(Errno) -> AccessMode {
    try _accessMode().get()
  }

  @usableFromInline
  internal func _accessMode() -> Result<AccessMode, Errno> {
    _fileStatus().map { AccessMode(rawValue: $0 & _O_ACCMODE) }
  }

  internal func _fileStatus() -> Result<CInt, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_GETFL)
    }
  }
}
#endif // !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension FileDescriptor {
  /// Flushes modified data and metadata of the file referenced by this
  /// file descriptor to its storage device,
  /// and asks the device to write its cache to permanent storage.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// ``synchronize(retryOnInterrupt:)`` can return
  /// while the data is still in the storage device's cache.
  /// This method waits until the device reports
  /// that the data is on permanent storage,
  /// which can take much longer.
  /// Some file systems don't support it, and throw an error.
  ///
  /// The corresponding C function is `fcntl`, with the `F_FULLFSYNC` command.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func synchronizeFully(retryOnInterrupt: Bool = true) throws(Errno) {
    try _synchronizeFully(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _synchronizeFully(retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fcntl(self.rawValue, _F_FULLFSYNC)
    }
  }

  /// Flushes modified data and metadata of the file referenced by this
  /// file descriptor to its storage device,
  /// and asks the device to write it to permanent storage
  /// before any data written later.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// This method orders writes without waiting for them
  /// to reach permanent storage,
  /// so it is cheaper than ``synchronizeFully(retryOnInterrupt:)``.
  /// Some file systems don't support it, and throw an error.
  ///
  /// The corresponding C function is `fcntl`, with the `F_BARRIERFSYNC` command.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func synchronizeWithBarrier(retryOnInterrupt: Bool = true) throws(Errno) {
    try _synchronizeWithBarrier(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _synchronizeWithBarrier(retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fcntl(self.rawValue, _F_BARRIERFSYNC)
    }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#if !os(Windows) && !os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Returns the process or process group that receives signals
  /// about the open file that this file descriptor refers to.
  ///
  /// - Returns: The process or process group that receives the signals,
  ///   with `isGroup` set for a process group,
  ///   or `nil` if no process receives them.
  ///
  /// The owner receives `SIGIO` when input or output becomes possible,
  /// if the open file's ``StatusFlags/async`` flag is set,
  /// and `SIGURG` when a socket receives out-of-band data.
  /// The owner belongs to the open file,
  /// so all the file descriptors that refer to it share one.
  ///
  /// On Darwin, not every kind of file has an owner:
  /// a regular file throws an error such as
  /// ``Errno/inappropriateIOCTLForDevice``.
  /// A terminal's owner is its foreground process group.
  /// A pipe reports its owner with the sign reversed,
  /// so this method reports a process that was set as the owner
  /// as a process group, and the reverse.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETOWN` command.
  @_alwaysEmitIntoClient
  public func signalOwner() throws(Errno) -> (id: ProcessID, isGroup: Bool)? {
    try _signalOwner().get()
  }

  @usableFromInline
  internal func _signalOwner() -> Result<(id: ProcessID, isGroup: Bool)?, Errno> {
    // A process group is reported as its negated ID, so for process group 1
    // only errno tells the result from a failure.
    system_errno = 0
    let owner = system_fcntl(self.rawValue, _F_GETOWN)
    if owner == -1 && system_errno != 0 { return .failure(.current) }
    if owner == 0 { return .success(nil) }
    if owner < 0 { return .success((id: ProcessID(rawValue: -owner), isGroup: true)) }
    return .success((id: ProcessID(rawValue: owner), isGroup: false))
  }

  /// Sets the process or process group that receives signals
  /// about the open file that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - id: The process or process group to receive the signals,
  ///     or `nil` so that no process receives them.
  ///   - isGroup: Whether `id` names a process group, rather than a process.
  ///     The default is `false`.
  ///
  /// The owner receives `SIGIO` when input or output becomes possible,
  /// if the open file's ``StatusFlags/async`` flag is set,
  /// and `SIGURG` when a socket receives out-of-band data.
  /// For more information, see ``signalOwner()``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_SETOWN` command.
  @_alwaysEmitIntoClient
  public func setSignalOwner(_ id: ProcessID?, isGroup: Bool = false) throws(Errno) {
    try _setSignalOwner(id, isGroup: isGroup).get()
  }

  @usableFromInline
  internal func _setSignalOwner(_ id: ProcessID?, isGroup: Bool) -> Result<(), Errno> {
    // A process group is passed as its negated ID, and no owner as 0.
    let owner = id.map { isGroup ? -$0.rawValue : $0.rawValue } ?? 0
    return nothingOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_SETOWN, owner)
    }
  }
}
#endif // !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension FileDescriptor {
  /// Turns data caching off or on
  /// for the open file that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - noCache: Whether to turn caching off.
  ///     Pass `false` to turn it back on.
  ///
  /// With caching off, reads and writes bypass the system's cache
  /// where they can,
  /// which suits data that won't be read again soon,
  /// such as a large file being copied.
  /// The setting belongs to the open file,
  /// so it applies to all the file descriptors that refer to it.
  /// A file descriptor that doesn't refer to a regular file
  /// throws an error such as ``Errno/badFileDescriptor``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_NOCACHE` command.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func setNoCache(_ noCache: Bool) throws(Errno) {
    try _setNoCache(noCache).get()
  }

  @usableFromInline
  internal func _setNoCache(_ noCache: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_NOCACHE, noCache ? 1 : 0)
    }
  }

  /// Returns whether writing to the pipe or socket
  /// that this file descriptor refers to only throws an error
  /// when nothing can read the data,
  /// rather than also raising `SIGPIPE`.
  ///
  /// - Returns: `true` if such a write only throws ``Errno/brokenPipe``,
  ///   or `false` if it also sends the process `SIGPIPE`,
  ///   which terminates the process unless it handles or ignores the signal.
  ///
  /// The setting belongs to the open file,
  /// so all the file descriptors that refer to it share it.
  /// For a socket, it's the same setting as the `SO_NOSIGPIPE` socket option.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETNOSIGPIPE` command.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func noSigPipe() throws(Errno) -> Bool {
    try _noSigPipe().get()
  }

  @usableFromInline
  internal func _noSigPipe() -> Result<Bool, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_GETNOSIGPIPE)
    }.map { $0 != 0 }
  }

  /// Sets whether writing to the pipe or socket
  /// that this file descriptor refers to only throws an error
  /// when nothing can read the data,
  /// rather than also raising `SIGPIPE`.
  ///
  /// - Parameters:
  ///   - noSigPipe: Whether such a write only throws ``Errno/brokenPipe``,
  ///     rather than also sending the process `SIGPIPE`,
  ///     which terminates the process unless it handles or ignores the signal.
  ///     Pass `false` to restore the default.
  ///
  /// The setting belongs to the open file,
  /// so it applies to all the file descriptors that refer to it.
  /// For a socket, it's the same setting as the `SO_NOSIGPIPE` socket option.
  ///
  /// The corresponding C function is `fcntl`, with the `F_SETNOSIGPIPE` command.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func setNoSigPipe(_ noSigPipe: Bool) throws(Errno) {
    try _setNoSigPipe(noSigPipe).get()
  }

  @usableFromInline
  internal func _setNoSigPipe(_ noSigPipe: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_SETNOSIGPIPE, noSigPipe ? 1 : 0)
    }
  }

  /// Returns the path of the file that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - resolvingFirmlinks: Whether to return the path that doesn't
  ///     pass through firmlinks,
  ///     such as `/System/Volumes/Data/Users/me` rather than `/Users/me`.
  ///     The default is `false`.
  /// - Returns: The file's absolute path.
  ///
  /// The path is the file's current one, which reflects any renames
  /// since the file was opened.
  /// If the file was removed, the path can be the one it had.
  /// A file descriptor that doesn't refer to a file system object,
  /// such as a pipe or a socket,
  /// throws an error such as ``Errno/badFileDescriptor``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETPATH` command,
  /// or `F_GETPATH_NOFIRMLINK` if `resolvingFirmlinks` is `true`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func path(resolvingFirmlinks: Bool = false) throws(Errno) -> FilePath {
    try _path(resolvingFirmlinks: resolvingFirmlinks).get()
  }

  @usableFromInline
  internal func _path(resolvingFirmlinks: Bool) -> Result<FilePath, Errno> {
    let command = resolvingFirmlinks ? _F_GETPATH_NOFIRMLINK : _F_GETPATH
    var result: Result<(), Errno> = .success(())
    // The command fills a buffer of MAXPATHLEN bytes with a null-terminated
    // path, without reporting its length.
    let chars = SystemString.Storage(
      unsafeUninitializedCapacity: _MAXPATHLEN
    ) { buffer, initializedCount in
      let length: Int? = buffer.withMemoryRebound(
        to: CInterop.PlatformChar.self
      ) { buffer in
        // The path is empty if the call writes nothing, as when mocked.
        buffer.baseAddress!.initialize(to: 0)
        result = nothingOrErrno(retryOnInterrupt: false) {
          system_fcntl(self.rawValue, command, UnsafeMutableRawPointer(buffer.baseAddress!))
        }
        guard case .success = result else { return nil }
        return system_platform_strlen(buffer.baseAddress!)
      }
      initializedCount = length.map { $0 + 1 } ?? 0
    }
    return result.map { FilePath(SystemString(nullTerminated: chars)) }
  }
}
#endif // SYSTEM_PACKAGE_DARWIN

#if os(Linux) || os(Android)
@available(System 199, *)
extension FileDescriptor {
  /// Returns the capacity of the pipe that this file descriptor refers to.
  ///
  /// - Returns: The number of bytes that the pipe can hold.
  ///
  /// A write to a full pipe blocks, or throws ``Errno/wouldBlock``
  /// if the pipe's ``StatusFlags/nonBlocking`` flag is set,
  /// until a read makes room.
  ///
  /// The corresponding C function is `fcntl`, with the `F_GETPIPE_SZ` command.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func pipeCapacity() throws(Errno) -> Int {
    try _pipeCapacity().get()
  }

  @usableFromInline
  internal func _pipeCapacity() -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_GETPIPE_SZ)
    }.map { Int($0) }
  }

  /// Sets the capacity of the pipe that this file descriptor refers to.
  ///
  /// - Parameters:
  ///   - minimum: The smallest capacity to set, in bytes.
  /// - Returns: The capacity that the system set,
  ///   which can be larger than `minimum`.
  ///
  /// The system rounds the capacity up,
  /// such as to the page size or to a power of two times the page size.
  /// Setting a capacity smaller than the data in the pipe
  /// throws ``Errno/resourceBusy``.
  /// Without privileges, setting a capacity larger than
  /// the one in `/proc/sys/fs/pipe-max-size`
  /// throws ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `fcntl`, with the `F_SETPIPE_SZ` command.
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  @discardableResult
  public func setPipeCapacity(atLeast minimum: Int) throws(Errno) -> Int {
    try _setPipeCapacity(atLeast: minimum).get()
  }

  @usableFromInline
  internal func _setPipeCapacity(atLeast minimum: Int) -> Result<Int, Errno> {
    // Too large a capacity fails with an error, rather than trapping.
    valueOrErrno(retryOnInterrupt: false) {
      system_fcntl(self.rawValue, _F_SETPIPE_SZ, CInt(clamping: minimum))
    }.map { Int($0) }
  }
}
#endif // os(Linux) || os(Android)

#if os(Linux) || os(Android) || os(FreeBSD) || os(WASI)
@available(System 199, *)
extension FileDescriptor {
  /// Allocates storage for a range of the file referenced by this
  /// file descriptor.
  ///
  /// - Parameters:
  ///   - offset: The file offset where the range begins.
  ///   - length: The length of the range, in bytes.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// After this method returns,
  /// writes within the range don't fail for lack of storage.
  /// If the range extends past the end of the file,
  /// the file is extended to cover it;
  /// the new bytes read as zeros.
  /// This method doesn't change the file's existing contents
  /// or its offset.
  ///
  /// The file must be open for writing.
  /// Some file systems don't support preallocation,
  /// and throw an error such as ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `posix_fallocate`.
  /// - Note: Only available on Linux, Android, FreeBSD, and WASI.
  @_alwaysEmitIntoClient
  public func allocateSpace(
    offset: Int64,
    length: Int64,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _allocateSpace(
      offset: offset, length: length, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _allocateSpace(
    offset: Int64,
    length: Int64,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: retryOnInterrupt) {
      system_posix_fallocate(self.rawValue, _COffT(offset), _COffT(length))
    }
  }

  /// Tells the system how you expect to access a range of the file
  /// referenced by this file descriptor.
  ///
  /// - Parameters:
  ///   - advice: How you expect to access the data.
  ///   - offset: The file offset where the range begins.
  ///     The default is `0`.
  ///   - length: The length of the range, in bytes,
  ///     or `0` for a range that extends to the end of the file.
  ///     The default is `0`.
  ///
  /// The system can use the advice to optimize caching and read-ahead,
  /// or ignore it; it doesn't change the file's contents.
  ///
  /// The corresponding C function is `posix_fadvise`.
  /// - Note: Only available on Linux, Android, FreeBSD, and WASI.
  @_alwaysEmitIntoClient
  public func advise(
    _ advice: Advice,
    offset: Int64 = 0,
    length: Int64 = 0
  ) throws(Errno) {
    try _advise(advice, offset: offset, length: length).get()
  }

  @usableFromInline
  internal func _advise(
    _ advice: Advice,
    offset: Int64,
    length: Int64
  ) -> Result<(), Errno> {
    nothingOrReturnedErrno(retryOnInterrupt: false) {
      system_posix_fadvise(
        self.rawValue, _COffT(offset), _COffT(length), advice.rawValue)
    }
  }
}
#endif // os(Linux) || os(Android) || os(FreeBSD) || os(WASI)

#if !os(WASI) // WASI has no umask
extension FilePermissions {
  /// The file creation permission mask (aka "umask").
  ///
  /// Permissions set in this mask will be cleared by functions that create
  /// files or directories.  Note that this mask is process-wide, and that
  /// *getting* it is not thread safe.
  internal static var creationMask: FilePermissions {
    get {
      let oldMask = _umask(0o22)
      _ = _umask(oldMask)
      return FilePermissions(rawValue: oldMask)
    }
    set {
      _ = _umask(newValue.rawValue)
    }
  }

  /// Change the file creation permission mask, run some code, then
  /// restore it to its original value.
  ///
  /// - Parameters:
  ///   - permissions: The new permission mask.
  ///
  /// This is more efficient than reading `creationMask` and restoring it
  /// afterwards, because of the way reading the creation mask works.
  internal static func withCreationMask<R>(
    _ permissions: FilePermissions,
    body: () throws -> R
  ) rethrows -> R {
    let oldMask = _umask(permissions.rawValue)
    defer {
      _ = _umask(oldMask)
    }
    return try body()
  }

  internal static func _umask(_ mode: CModeT) -> CModeT {
    return system_umask(mode)
  }
}
#endif // !os(WASI)
