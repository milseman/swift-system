/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Directory streams: opendir, fdopendir, readdir, rewinddir, dirfd, and
// closedir. Prototype/Directories/README.md records the design decisions and
// the alternatives they rejected.

#if !os(Windows)

// Must import here to read dirent's members.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
// WASI's directory entries are CSystem's copies (see CSystemWASI.h).
import CSystem
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// An open directory, which reads the directory's entries one at a time.
///
/// A directory stream owns a descriptor for its directory, and closes it
/// exactly once: when you call `close()`, or at the end of the stream's
/// lifetime.
///
///     var stream = try DirectoryStream.open("/tmp")
///     while let entry = try stream.next() {
///       print(entry.name)
///     }
///     try stream.close()
///
/// `DirectoryStream` can't be copied.
/// A function that takes a `borrowing DirectoryStream` parameter
/// can reach the directory through ``fileDescriptor``,
/// but can't read entries, which requires `inout`,
/// and can't close the stream or keep it after returning.
///
/// Destroying a directory stream closes it and ignores any error,
/// as destroying an `OwnedFD` does.
/// To handle an error from closing, call `close()`.
///
/// The corresponding C type is `DIR`.
/// - Note: Only available on Unix-like platforms other than WASI.
@available(System 199, *)
public struct DirectoryStream: ~Copyable {
  // The C directory stream, which owns the descriptor. `nil` once
  // `close()` or a conversion has taken it, so that deinit leaves it alone.
  // (A stream can't `discard self`, since `_name` isn't trivially destroyed.)
  internal var _dir: system_DIRPtr?

  // The name that `next()` returned last. `next()` writes the next name here
  // in place, so reading an entry doesn't allocate, unless an entry that
  // `next()` returned before is still alive and sharing the storage.
  internal var _name: SystemString

  internal init(_dir dir: system_DIRPtr) {
    self._dir = dir
    self._name = SystemString()
  }

  deinit {
    // `deinit` can't throw, so an error from closing is dropped here, as it
    // is in OwnedFD's deinit, whose policy this follows. For a directory
    // opened for reading, the only error is EBADF, from a descriptor that
    // something closed behind the stream's back. Whether that should trap
    // instead is the open question in Prototype/CloseErrors.
    if let dir = _dir {
      _ = system_closedir(dir)
    }
  }
}

@available(System 199, *)
extension DirectoryStream: @unchecked Sendable {
  // A `DIR` isn't safe to use from two threads at once, but a stream can't
  // be copied, so only one owner can use it at a time. Moving it to another
  // thread is safe.
}

// MARK: - Opening

@available(System 199, *)
extension DirectoryStream {
  /// Opens a directory stream for the directory at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to open.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A directory stream positioned at the directory's first entry.
  ///
  /// The stream's descriptor is closed on `exec`.
  ///
  /// The corresponding C function is `opendir`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DirectoryStream {
    try _open(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Opens a directory stream for the directory at the given path.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to open.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A directory stream positioned at the directory's first entry.
  ///
  /// The stream's descriptor is closed on `exec`.
  ///
  /// The corresponding C function is `opendir`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DirectoryStream {
    try _open(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _open(
    _ path: FilePath, retryOnInterrupt: Bool
  ) -> Result<DirectoryStream, Errno> {
    path.withPlatformString {
      _opendir($0, retryOnInterrupt: retryOnInterrupt)
    }._stream()
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CChar>, retryOnInterrupt: Bool
  ) -> Result<DirectoryStream, Errno> {
    _opendir(path, retryOnInterrupt: retryOnInterrupt)._stream()
  }

  internal static func _opendir(
    _ path: UnsafePointer<CInterop.PlatformChar>, retryOnInterrupt: Bool
  ) -> Result<system_DIRPtr, Errno> {
    _pointerOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_opendir(path)
    }
  }

  /// Opens a directory stream for the directory at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to open.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - options: Options to add to the ones the stream always has.
  ///     For example, pass `.noFollow` to throw ``Errno/notDirectory``
  ///     or ``Errno/tooManySymbolicLinkLevels`` if `path` names
  ///     a symbolic link, rather than opening the directory it points to.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A directory stream positioned at the directory's first entry.
  ///
  /// The stream always opens the directory read-only,
  /// with `.directory` and `.closeOnExec`, as `opendir` does.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C functions are `openat` and `fdopendir`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    relativeTo fd: FileDescriptor,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DirectoryStream {
    try _open(
      path, relativeTo: fd, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Opens a directory stream for the directory at the given path,
  /// resolving a relative path against a directory.
  ///
  /// - Parameters:
  ///   - path: The location of the directory to open.
  ///   - fd: The directory against which a relative `path` is resolved.
  ///   - options: Options to add to the ones the stream always has.
  ///     For example, pass `.noFollow` to throw ``Errno/notDirectory``
  ///     or ``Errno/tooManySymbolicLinkLevels`` if `path` names
  ///     a symbolic link, rather than opening the directory it points to.
  ///   - retryOnInterrupt: Whether to retry the open operation
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: A directory stream positioned at the directory's first entry.
  ///
  /// The stream always opens the directory read-only,
  /// with `.directory` and `.closeOnExec`, as `opendir` does.
  ///
  /// If `path` is absolute (starts with a forward slash), then `fd` is ignored.
  /// If `path` is relative, it is resolved against the directory given by `fd`.
  ///
  /// The corresponding C functions are `openat` and `fdopendir`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DirectoryStream {
    try _open(
      path, relativeTo: fd, options: options, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _open(
    _ path: FilePath,
    relativeTo fd: FileDescriptor,
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<DirectoryStream, Errno> {
    path.withPlatformString {
      _openDirectoryStream(
        $0, relativeTo: fd.rawValue, options: options.rawValue,
        retryOnInterrupt: retryOnInterrupt)
    }._stream()
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CChar>,
    relativeTo fd: FileDescriptor,
    options: FileDescriptor.OpenOptions,
    retryOnInterrupt: Bool
  ) -> Result<DirectoryStream, Errno> {
    _openDirectoryStream(
      path, relativeTo: fd.rawValue, options: options.rawValue,
      retryOnInterrupt: retryOnInterrupt
    )._stream()
  }

  /// Opens a directory stream for an open directory,
  /// taking ownership of its file descriptor.
  ///
  /// - Parameter descriptor: A file descriptor for a directory,
  ///   open for reading.
  ///
  /// If this initializer returns, the stream owns `descriptor`,
  /// so nothing else may close it.
  /// If it throws, the caller still owns `descriptor`.
  /// It throws ``Errno/notDirectory`` if `descriptor` isn't a directory.
  ///
  /// On Darwin, this also sets close-on-exec on the descriptor.
  ///
  /// The stream reads entries from the descriptor's current position.
  ///
  /// The corresponding C function is `fdopendir`.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) throws(Errno) {
    try self.init(_fdopendir: descriptor, closingOnFailure: false)
  }

  /// Opens a directory stream for an open directory,
  /// taking ownership of its file descriptor from its owner.
  ///
  /// - Parameter descriptor: The owner of a file descriptor for a directory,
  ///   open for reading.
  ///
  /// If this initializer throws, it closes the descriptor.
  /// To keep a descriptor that might not be a directory,
  /// check its type first:
  ///
  ///     if try Stat(file.fileDescriptor).type == .directory {
  ///       var stream = try DirectoryStream(file)
  ///       // ...
  ///     }
  ///
  /// On Darwin, this also sets close-on-exec on the descriptor.
  ///
  /// The stream reads entries from the descriptor's current position.
  ///
  /// The corresponding C function is `fdopendir`.
  @_alwaysEmitIntoClient
  public init(_ descriptor: consuming OwnedFD) throws(Errno) {
    try self.init(_fdopendir: descriptor.relinquish(), closingOnFailure: true)
  }

  // A throwing initializer to delegate to. In a noncopyable type with a
  // deinit and a stored property that isn't trivially destroyed, `self`
  // can't be assigned from a `try` (Prototype/Directories/Verify/D3).
  @usableFromInline
  internal init(
    _fdopendir descriptor: FileDescriptor, closingOnFailure: Bool
  ) throws(Errno) {
    // fdopendir can't be interrupted: it only checks the descriptor
    // and allocates.
    let result = _pointerOrErrno(retryOnInterrupt: false) {
      system_fdopendir(descriptor.rawValue)
    }
    if case .failure = result, closingOnFailure {
      _ = system_close(descriptor.rawValue)
    }
    self.init(_dir: try result.get())
  }
}

extension Result where Success == system_DIRPtr, Failure == Errno {
  @available(System 199, *)
  fileprivate func _stream() -> Result<DirectoryStream, Errno> {
    switch self {
    case .success(let dir): return .success(DirectoryStream(_dir: dir))
    case .failure(let error): return .failure(error)
    }
  }
}

// MARK: - Reading

@available(System 199, *)
extension DirectoryStream {
  /// Reads the next entry in the directory.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the read operation
  ///   if it throws ``Errno/interrupted``.
  ///   The default is `true`.
  ///   Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The next entry, or `nil` after the last one.
  ///
  /// Entries come in the order the file system stores them,
  /// and don't include the `.` and `..` entries.
  /// If the directory changes while the stream reads it,
  /// the stream might or might not return an entry
  /// that was added or removed since the stream opened.
  ///
  /// Each entry is a copy, so it stays valid after this method reads the
  /// next one. To read entries without allocating memory for their names,
  /// let each entry's name go before reading the next;
  /// then the stream reuses the name's storage.
  ///
  /// The corresponding C function is `readdir`, which returns `NULL` both
  /// after the last entry and on failure. This method returns `nil`
  /// only after the last entry, and throws on failure.
  @_alwaysEmitIntoClient
  public mutating func next(retryOnInterrupt: Bool = true) throws(Errno) -> Entry? {
    try _next(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal mutating func _next(retryOnInterrupt: Bool) -> Result<Entry?, Errno> {
    switch _readDirectoryEntry(_dir!, retryOnInterrupt: retryOnInterrupt) {
    case .failure(let error):
      return .failure(error)
    case .success(nil):
      return .success(nil)
    case .success(let entry?):
      return .success(Entry(_reading: entry, into: &_name))
    }
  }

  /// Returns the stream to the directory's first entry.
  ///
  /// After this method returns, the stream reflects the directory's
  /// current contents.
  ///
  /// The corresponding C function is `rewinddir`.
  @_alwaysEmitIntoClient
  public mutating func rewind() {
    _rewind()
  }

  @usableFromInline
  internal mutating func _rewind() {
    system_rewinddir(_dir!)
  }
}

// MARK: - The descriptor

@available(System 199, *)
extension DirectoryStream {
  /// The directory's file descriptor,
  /// for operations relative to the directory,
  /// such as opening or getting the status of one of its entries.
  ///
  /// The returned value refers to the same open directory,
  /// but it doesn't own it:
  /// it's valid only while this stream is alive.
  /// Don't close it, and don't keep it.
  /// Don't read from it or move its position, either;
  /// that confuses the stream.
  ///
  /// The corresponding C function is `dirfd`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor {
    FileDescriptor(rawValue: _fileDescriptor)
  }

  @usableFromInline
  internal var _fileDescriptor: CInt {
    system_dirfd(_dir!)
  }
}

// MARK: - Closing

@available(System 199, *)
extension DirectoryStream {
  /// Closes the directory stream and its file descriptor.
  ///
  /// The stream is not closed again, whether this method returns or throws.
  ///
  /// The corresponding C function is `closedir`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _close().get()
  }

  @usableFromInline
  internal consuming func _close() -> Result<(), Errno> {
    // `closedir` frees the stream and releases the descriptor even when it
    // fails, so it mustn't be retried.
    let dir = _takeDIR()
    return nothingOrErrno(retryOnInterrupt: false) { system_closedir(dir) }
  }

  /// Takes the C directory stream, so that deinit doesn't close it.
  internal consuming func _takeDIR() -> system_DIRPtr {
    let dir = _dir!
    _dir = nil
    return dir
  }
}

// MARK: - Entries

@available(System 199, *)
extension DirectoryStream {
  /// An entry in a directory: the name of a file in the directory,
  /// and what the directory records about the file.
  ///
  /// An entry holds copies of the values the stream read,
  /// so it doesn't change when the stream reads another entry, or closes.
  ///
  /// The corresponding C type is `struct dirent`.
  @frozen
  public struct Entry: Sendable, Hashable {
    /// The file's name in the directory.
    ///
    /// The corresponding C property is `d_name`.
    public var name: FilePath.Component

    /// The file's type, or `nil` if the directory doesn't record it.
    ///
    /// Some file systems don't record types in their directories.
    /// For an entry whose type is `nil`,
    /// get the file's status relative to the stream's directory instead:
    ///
    ///     let status = try Stat(
    ///       FilePath(root: nil, components: entry.name),
    ///       relativeTo: stream.fileDescriptor, flags: .symlinkNoFollow)
    ///
    /// A symbolic link's type is ``FileType/symbolicLink``,
    /// whatever it points to.
    ///
    /// The corresponding C property is `d_type`,
    /// which is `DT_UNKNOWN` when this property is `nil`.
    public var type: FileType?

    /// The file's inode number.
    ///
    /// The corresponding C property is `d_ino`
    /// (`d_fileno` on FreeBSD and OpenBSD).
    public var inode: Inode

    /// Copies an entry that `readdir` returned,
    /// writing its name into `storage`.
    internal init(
      _reading entry: UnsafeMutablePointer<system_dirent>,
      into storage: inout SystemString
    ) {
      storage._replaceContents(
        withPlatformString: _directoryEntryName(entry),
        length: _directoryEntryNameLength(entry))
      self.name = FilePath.Component(_directoryEntryName: storage)
      self.type = FileType(_directoryEntryType: entry.pointee.d_type)
      self.inode = Inode(_directoryEntryInode(entry))
    }
  }
}

#endif // !os(Windows)
