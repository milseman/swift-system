/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A unique file with permissions of the caller's choosing: mktemp makes the
// name, and open or openat creates the file with O_EXCL, trying another
// name if one appears there in the meantime, as mkstemp does inside. Unlike
// mkstemp's 0600 followed by fchmod, the permissions pass through the
// creation mask, as open's do.
//
// Only on Darwin for now: glibc's and OpenBSD's linkers warn at every link
// of a program that calls mktemp, so those platforms would want the name
// made another way, such as from getentropy.

#if SYSTEM_PACKAGE_DARWIN

import Darwin

@available(System 199, *)
extension FilePath {
  /// Creates a file with a unique name, using this path as a template,
  /// with the given permissions, and opens it for reading and writing.
  ///
  /// - Parameters:
  ///   - options: Options for the new descriptor,
  ///     such as ``FileDescriptor/OpenOptions/closeOnExec``.
  ///     The default is none.
  ///   - permissions: The new file's permissions,
  ///     less the creation mask, as when opening a file creates it.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file's path, and a descriptor open for reading
  ///   and writing it, which the caller must close.
  ///
  /// The path's last component must end in at least six `X` characters,
  /// which this method replaces to make a name that nothing in the directory
  /// has; for a template without them, it throws ``Errno/invalidArgument``.
  /// It creates the file only if nothing has the name,
  /// and tries another name if something does.
  ///
  ///     let (path, fd) = try FilePath.temporaryDirectory()
  ///       .appending("report-XXXXXX")
  ///       .makeUniqueFile(
  ///         options: .closeOnExec,
  ///         permissions: [.ownerReadWrite, .groupRead, .otherRead])
  ///
  /// Use this method rather than ``makeUniqueFile(options:retryOnInterrupt:)``
  /// for permissions other than ``FilePermissions/ownerReadWrite``:
  /// setting them afterward, with ``FileDescriptor/setPermissions(_:retryOnInterrupt:)``,
  /// doesn't apply the creation mask.
  ///
  /// The corresponding C functions are `mktemp`, which makes the name,
  /// and `open`, which creates the file.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func makeUniqueFile(
    options: FileDescriptor.OpenOptions = [],
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (path: FilePath, descriptor: FileDescriptor) {
    try _makeUniqueFile(
      relativeTo: nil, options: options, permissions: permissions,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Creates a file with a unique name, using this path as a template
  /// relative to a directory, with the given permissions,
  /// and opens it for reading and writing.
  ///
  /// - Parameters:
  ///   - directory: The directory that a relative template is relative to.
  ///   - options: Options for the new descriptor,
  ///     such as ``FileDescriptor/OpenOptions/closeOnExec``.
  ///     The default is none.
  ///   - permissions: The new file's permissions,
  ///     less the creation mask, as when opening a file creates it.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new file's path, as relative as the template,
  ///   and a descriptor open for reading and writing it,
  ///   which the caller must close.
  ///
  /// See ``makeUniqueFile(options:permissions:retryOnInterrupt:)``.
  ///
  /// The corresponding C functions are `mktemp`, which makes the name,
  /// and `openat`, which creates the file.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func makeUniqueFile(
    relativeTo directory: FileDescriptor,
    options: FileDescriptor.OpenOptions = [],
    permissions: FilePermissions,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (path: FilePath, descriptor: FileDescriptor) {
    try _makeUniqueFile(
      relativeTo: directory, options: options, permissions: permissions,
      retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal func _makeUniqueFile(
    relativeTo directory: FileDescriptor?,
    options: FileDescriptor.OpenOptions,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<(path: FilePath, descriptor: FileDescriptor), Errno> {
    _withMutableCopy { template in
      FilePath._makeUniqueFile(
        template, relativeTo: directory, options: options,
        permissions: permissions, retryOnInterrupt: retryOnInterrupt
      ).map { (FilePath(SystemString(platformString: template)), $0) }
    }
  }

  /// How many names to try before giving up, when each one is taken by
  /// the time the file is created: that takes another process creating
  /// files at the same names in the same directory.
  @usableFromInline
  internal static var _uniqueNameAttempts: Int { 100 }

  @usableFromInline
  internal static func _makeUniqueFile(
    _ template: UnsafeMutablePointer<CChar>,
    relativeTo directory: FileDescriptor?,
    options: FileDescriptor.OpenOptions,
    permissions: FilePermissions,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    let length = system_strlen(template)
    let original = UnsafeBufferPointer(start: template, count: length + 1)
    guard original.dropLast().suffix(6).count == 6,
          original.dropLast().suffix(6).allSatisfy({ $0 == CChar(UInt8(ascii: "X")) })
    else { return .failure(.invalidArgument) }
    // mktemp checks its name against the working directory. Relative to
    // another directory, it makes only the last component, whose check
    // there is harmless, and O_EXCL checks the name where the file goes.
    var name = template
    if directory != nil,
       let slash = original.lastIndex(of: CChar(UInt8(ascii: "/"))) {
      name = template + slash + 1
    }
    let flags = O_CREAT | O_EXCL | O_RDWR | options.rawValue
    return withUnsafeTemporaryAllocation(of: CChar.self, capacity: original.count) { saved in
      _ = saved.initialize(from: original)
      var attempts = 1
      while true {
        var fd: CInt = -1
        if system_mktemp(name) != nil {
          if let directory {
            fd = system_openat(directory.rawValue, template, flags, permissions.rawValue)
          } else {
            fd = system_open(template, flags, permissions.rawValue)
          }
        }
        if fd != -1 { return .success(FileDescriptor(rawValue: fd)) }
        let error = Errno.current
        if error == .fileExists && attempts < _uniqueNameAttempts {
          attempts += 1
        } else if !(error == .interrupted && retryOnInterrupt) {
          return .failure(error)
        }
        _ = UnsafeMutableBufferPointer(start: template, count: saved.count).update(fromContentsOf: saved)
      }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
