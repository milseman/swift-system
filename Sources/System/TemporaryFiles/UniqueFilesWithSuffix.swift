/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Unique files whose templates keep a suffix after their X's, and, on
// Darwin, unique files relative to a directory: mkostemps and
// mkostempsat_np, next to UniqueFiles.swift's mkostemp.

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)

@available(System 199, *)
extension FilePath {
  /// Creates a file with a unique name, using this path as a template
  /// that ends in a suffix, and opens it for reading and writing.
  ///
  /// - Parameters:
  ///   - suffixLength: The number of bytes at the end of the path's last
  ///     component that follow its `X` characters and stay as they are,
  ///     such as 4 for `"report-XXXXXX.txt"`.
  ///   - options: Options for the new descriptor.
  ///     Only ``FileDescriptor/OpenOptions/closeOnExec`` and
  ///     ``FileDescriptor/OpenOptions/append`` apply everywhere;
  ///     others throw ``Errno/invalidArgument`` on some platforms.
  ///     The default is none.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file's path, and a descriptor open for reading
  ///   and writing it, which the caller must close.
  ///
  /// The component must have at least six `X` characters before the suffix;
  /// without them, this method throws ``Errno/invalidArgument``.
  /// See ``makeUniqueFile(options:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `mkostemps`.
  ///
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  ///   On Android before API level 23, passing options throws
  ///   ``Errno/noFunction``.
  @_alwaysEmitIntoClient
  public func makeUniqueFile(
    suffixLength: Int,
    options: FileDescriptor.OpenOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (path: FilePath, descriptor: FileDescriptor) {
    try _makeUniqueFile(
      suffixLength: suffixLength, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _makeUniqueFile(
    suffixLength: Int,
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<(path: FilePath, descriptor: FileDescriptor), Errno> {
    _withMutableCopy { template in
      _retryingTemplate(template, suffixLength: suffixLength, retryOnInterrupt: retryOnInterrupt) {
        let fd = system_mkostemps(template, CInt(suffixLength), options.rawValue)
        return fd == -1 ? nil : FileDescriptor(rawValue: fd)
      }.map { (FilePath(SystemString(platformString: template)), $0) }
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Creates a file with a unique name, using this path as a template
  /// resolved against a directory, and opens it for reading and writing.
  ///
  /// - Parameters:
  ///   - fd: The directory against which a relative path is resolved.
  ///   - suffixLength: The number of bytes at the end of the path's last
  ///     component that follow its `X` characters. The default is 0.
  ///   - options: Options for the new descriptor.
  ///     The default is none.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file's path, relative to `fd` as the template was,
  ///   and a descriptor open for reading and writing it,
  ///   which the caller must close.
  ///
  /// The file's permissions are ``FilePermissions/ownerReadWrite``,
  /// less the creation mask;
  /// to give it others, call ``FileDescriptor/setPermissions(_:retryOnInterrupt:)``
  /// on its descriptor before writing it.
  /// See ``makeUniqueFile(options:retryOnInterrupt:)``.
  ///
  /// The corresponding C function is `mkostempsat_np`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func makeUniqueFile(
    relativeTo fd: FileDescriptor,
    suffixLength: Int = 0,
    options: FileDescriptor.OpenOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (path: FilePath, descriptor: FileDescriptor) {
    try _makeUniqueFile(
      relativeTo: fd, suffixLength: suffixLength, options: options,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _makeUniqueFile(
    relativeTo fd: FileDescriptor,
    suffixLength: Int,
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<(path: FilePath, descriptor: FileDescriptor), Errno> {
    _withMutableCopy { template in
      _retryingTemplate(template, suffixLength: suffixLength, retryOnInterrupt: retryOnInterrupt) {
        let result = system_mkostempsat_np(fd.rawValue, template, CInt(suffixLength), options.rawValue)
        return result == -1 ? nil : FileDescriptor(rawValue: result)
      }.map { (FilePath(SystemString(platformString: template)), $0) }
    }
  }
  #endif
}

/// Calls `call`, which rewrites `template`'s X's, the six or more before its
/// last `suffixLength` bytes; see `_retryingTemplate(_:retryOnInterrupt:_:)`.
internal func _retryingTemplate<T>(
  _ template: UnsafeMutablePointer<CChar>,
  suffixLength: Int,
  retryOnInterrupt: Bool,
  _ call: () -> T?
) -> Result<T, Errno> {
  let length = system_strlen(template)
  guard suffixLength >= 0, suffixLength <= length - 6 else { return .failure(.invalidArgument) }
  let original = UnsafeBufferPointer(start: template, count: length + 1)
  let xs = original[..<(length - suffixLength)].suffix(6)
  guard xs.allSatisfy({ $0 == CChar(UInt8(ascii: "X")) }) else { return .failure(.invalidArgument) }
  return withUnsafeTemporaryAllocation(of: CChar.self, capacity: original.count) { saved in
    _ = saved.initialize(from: original)
    while true {
      if let value = call() { return .success(value) }
      let error = Errno.current
      guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
      _ = UnsafeMutableBufferPointer(start: template, count: saved.count).update(fromContentsOf: saved)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
