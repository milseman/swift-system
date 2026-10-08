/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// MARK: - mkostemp, mkdtemp

@available(System 199, *)
extension FilePath {
  /// Creates a file with a unique name, using this path as a template,
  /// and opens it for reading and writing.
  ///
  /// - Parameters:
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
  /// The path's last component must end in at least six `X` characters,
  /// which this method replaces to make a name that nothing in the directory
  /// has, and creates the file there, atomically;
  /// for a template without them, it throws ``Errno/invalidArgument``,
  /// on every platform:
  ///
  ///     let (path, fd) = try FilePath.temporaryDirectory()
  ///       .appending("report-XXXXXX")
  ///       .makeUniqueFile(options: .closeOnExec)
  ///
  /// The file's permissions are ``FilePermissions/ownerReadWrite``,
  /// less the creation mask.
  /// The file isn't removed when it's closed; remove it when you're done.
  ///
  /// The corresponding C function is `mkostemp`.
  @_alwaysEmitIntoClient
  public func makeUniqueFile(
    options: FileDescriptor.OpenOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> (path: FilePath, descriptor: FileDescriptor) {
    try _makeUniqueFile(options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _makeUniqueFile(
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<(path: FilePath, descriptor: FileDescriptor), Errno> {
    _withMutableCopy { template in
      FilePath._makeUniqueFile(
        template, options: options, retryOnInterrupt: retryOnInterrupt
      ).map { (FilePath(SystemString(platformString: template)), $0) }
    }
  }

  /// Creates a file with a unique name, using the given path as a template,
  /// and opens it for reading and writing.
  ///
  /// - Parameters:
  ///   - template: A path whose last component ends in at least six `X`
  ///     characters, which this method replaces, in place,
  ///     with the characters of the new file's name.
  ///   - options: Options for the new descriptor.
  ///     Only ``FileDescriptor/OpenOptions/closeOnExec`` and
  ///     ``FileDescriptor/OpenOptions/append`` apply everywhere;
  ///     others throw ``Errno/invalidArgument`` on some platforms.
  ///     The default is none.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A descriptor open for reading and writing the new file,
  ///   which the caller must close.
  ///
  /// The file's permissions are ``FilePermissions/ownerReadWrite``,
  /// less the creation mask.
  ///
  /// The corresponding C function is `mkostemp`.
  @_alwaysEmitIntoClient
  public static func makeUniqueFile(
    _ template: UnsafeMutablePointer<CChar>,
    options: FileDescriptor.OpenOptions = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileDescriptor {
    try _makeUniqueFile(template, options: options, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _makeUniqueFile(
    _ template: UnsafeMutablePointer<CChar>,
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<FileDescriptor, Errno> {
    _retryingTemplate(template, retryOnInterrupt: retryOnInterrupt) {
      let fd = system_mkostemp(template, options.rawValue)
      return fd == -1 ? nil : FileDescriptor(rawValue: fd)
    }
  }

  /// Creates a directory with a unique name, using this path as a template.
  ///
  /// - Parameters:
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The new directory's path.
  ///
  /// The path's last component must end in at least six `X` characters,
  /// which this method replaces to make a name that nothing in the directory
  /// has, and creates the directory there, atomically;
  /// for a template without them, it throws ``Errno/invalidArgument``,
  /// on every platform.
  /// The directory's permissions are ``FilePermissions/ownerReadWriteExecute``,
  /// less the creation mask.
  ///
  /// The corresponding C function is `mkdtemp`.
  @_alwaysEmitIntoClient
  public func makeUniqueDirectory(retryOnInterrupt: Bool = true) throws(Errno) -> FilePath {
    try _makeUniqueDirectory(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _makeUniqueDirectory(retryOnInterrupt: Bool) -> Result<FilePath, Errno> {
    _withMutableCopy { template in
      FilePath._makeUniqueDirectory(template, retryOnInterrupt: retryOnInterrupt)
        .map { FilePath(SystemString(platformString: template)) }
    }
  }

  /// Creates a directory with a unique name, using the given path as a template.
  ///
  /// - Parameters:
  ///   - template: A path whose last component ends in at least six `X`
  ///     characters, which this method replaces, in place,
  ///     with the characters of the new directory's name.
  ///   - retryOnInterrupt: Whether to retry the operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The directory's permissions are ``FilePermissions/ownerReadWriteExecute``,
  /// less the creation mask.
  ///
  /// The corresponding C function is `mkdtemp`.
  @_alwaysEmitIntoClient
  public static func makeUniqueDirectory(
    _ template: UnsafeMutablePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    try _makeUniqueDirectory(template, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _makeUniqueDirectory(
    _ template: UnsafeMutablePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<(), Errno> {
    _retryingTemplate(template, retryOnInterrupt: retryOnInterrupt) {
      system_mkdtemp(template) == nil ? nil : ()
    }
  }

  /// Calls `body` with a mutable, null-terminated copy of this path.
  internal func _withMutableCopy<R>(
    _ body: (UnsafeMutablePointer<CChar>) -> R
  ) -> R {
    withPlatformString { path in
      let count = system_strlen(path) + 1
      return withUnsafeTemporaryAllocation(of: CChar.self, capacity: count) { buffer in
        _ = buffer.initialize(from: UnsafeBufferPointer(start: path, count: count))
        return body(buffer.baseAddress!)
      }
    }
  }
}

/// Calls `call`, which rewrites `template` and returns `nil` for a failure
/// that sets errno, retrying on interruption if asked to.
///
/// A template must end in at least six X's, as POSIX says: Darwin's C
/// library accepts fewer, even none, which makes a name that's easy to guess,
/// so this checks first, and fails as glibc does.
/// Each retry starts from the original template, since a failed call can
/// leave its X's replaced.
internal func _retryingTemplate<T>(
  _ template: UnsafeMutablePointer<CChar>,
  retryOnInterrupt: Bool,
  _ call: () -> T?
) -> Result<T, Errno> {
  let original = UnsafeBufferPointer(start: template, count: system_strlen(template) + 1)
  guard original.dropLast().suffix(6).count == 6,
        original.dropLast().suffix(6).allSatisfy({ $0 == CChar(UInt8(ascii: "X")) })
  else { return .failure(.invalidArgument) }
  return withUnsafeTemporaryAllocation(of: CChar.self, capacity: original.count) { saved in
    _ = saved.initialize(from: original)
    while true {
      if let value = call() { return .success(value) }
      let error = Errno._current
      guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
      _ = UnsafeMutableBufferPointer(start: template, count: saved.count).update(fromContentsOf: saved)
    }
  }
}

// MARK: - The temporary directory

@available(System 199, *)
extension FilePath {
  /// Returns the directory where the calling process should put temporary
  /// files.
  ///
  /// This is the directory that the `TMPDIR` environment variable names;
  /// if it's unset or empty, it's the user's temporary directory on Darwin,
  /// which the system creates if it has to, `/data/local/tmp` on Android,
  /// and `/tmp` elsewhere.
  /// A program that runs with privileges it didn't start with,
  /// as a set-user-ID program does,
  /// ignores `TMPDIR`, since the user who ran it controls it.
  ///
  /// Other users can see the directory, and on some systems create files
  /// in it: create a file there with ``makeUniqueFile(options:retryOnInterrupt:)``
  /// or a directory with ``makeUniqueDirectory(retryOnInterrupt:)``,
  /// rather than at a name you choose.
  ///
  /// On Darwin, this reads ``SystemConfig/StringName/userTemporaryDirectory``,
  /// through `confstr`.
  @_alwaysEmitIntoClient
  public static func temporaryDirectory() -> FilePath {
    _temporaryDirectory()
  }

  @usableFromInline
  internal static func _temporaryDirectory() -> FilePath {
    if !system_isSecureExecution(), let value = system_getenv("TMPDIR"), value.pointee != 0 {
      return FilePath(SystemString(platformString: value))
    }
    #if SYSTEM_PACKAGE_DARWIN
    // The per-user directory is ASCII, so the string loses nothing.
    if case .success(let directory?) = SystemConfig._string(.userTemporaryDirectory),
       !directory.isEmpty {
      return FilePath(directory)
    }
    #endif
    #if os(Android)
    // Bionic's own temporary files go here; TMPDIR is rarely set.
    return "/data/local/tmp"
    #else
    return "/tmp"
    #endif
  }
}


#endif // !os(Windows) && !os(WASI)
