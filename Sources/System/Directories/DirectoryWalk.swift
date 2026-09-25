/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A recursive walk of a directory tree, built on openat, fdopendir and
// readdir rather than fts. Prototype/Directories/README.md compares the two
// and records why.

#if !os(Windows) && !os(WASI)

// Must import here to read dirent's members.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// A walk through the tree of files under a directory.
///
/// A walk visits every entry under its root directory, depth first.
/// It opens each directory relative to the directory that contains it,
/// and never follows a symbolic link,
/// so replacing a directory with a link while the walk reads the tree
/// can't lead the walk out of it.
/// A directory that the walk has opened stays open
/// even if it's moved elsewhere, and the walk reads it where it is.
///
///     var walk = try DirectoryWalk("Sources")
///     while let entry = try walk.next() {
///       print(entry.path)
///     }
///
/// A walk visits the root's entries, not the root itself.
/// By default, it visits a directory before its contents;
/// pass ``Order/postorder`` to visit it after them instead,
/// as removing a tree requires.
/// Either way, it visits each entry once.
///
/// A walk holds a descriptor for each directory
/// between the root and the entry it visits,
/// so it can't go deeper than the process's limit on open descriptors.
/// Beyond that, the entry for a directory it can't open has the error
/// ``Errno/tooManyOpenFiles``.
///
/// `DirectoryWalk` can't be copied.
/// Destroying a walk closes the directories it has open,
/// and ignores any error, as destroying a ``DirectoryStream`` does.
///
/// - Note: Only available on Unix-like platforms other than WASI.
@available(System 199, *)
public struct DirectoryWalk: ~Copyable {
  // The open directories from the root down. The walk reads the last one.
  internal var _levels: [_Level]

  // A directory that `next()` opened and returned in preorder, which the
  // next call descends into, unless `skipDescendants()` closes it first.
  internal var _pending: _Level?

  // The name that `next()` returned last, reused as DirectoryStream's is.
  internal var _name: SystemString

  internal let _order: Order

  internal init(_root dir: system_DIRPtr, path: FilePath, order: Order) {
    self._levels = [_Level(dir: dir, path: path, name: nil)]
    self._pending = nil
    self._name = SystemString()
    self._order = order
  }

  deinit {
    // As in DirectoryStream's deinit, errors from closing are dropped.
    _ = _closeAll()
  }
}

@available(System 199, *)
extension DirectoryWalk: @unchecked Sendable {
  // As with DirectoryStream: a walk can't be copied, so only one owner
  // can use its `DIR`s at a time.
}

/// An open directory in a walk.
internal struct _Level {
  // The C directory stream, which the walk owns.
  var dir: system_DIRPtr

  // The directory's path: the root's, or its parent's path and its name.
  var path: FilePath

  // The directory's name in its parent, for its postorder entry.
  // `nil` for the root, which the walk doesn't visit.
  var name: FilePath.Component?

  var fileDescriptor: CInt { system_dirfd(dir) }
}

// MARK: - Starting

@available(System 199, *)
extension DirectoryWalk {
  /// When a walk visits a directory, relative to its contents.
  @frozen
  public enum Order: Sendable, Hashable {
    /// Visit each directory before its contents.
    ///
    /// Only a preorder walk can skip a directory's contents,
    /// with ``DirectoryWalk/skipDescendants()``.
    case preorder

    /// Visit each directory after its contents,
    /// as removing a tree or adding up its sizes requires.
    case postorder
  }

  /// Opens a directory to walk the tree under it.
  ///
  /// - Parameters:
  ///   - root: The directory at the top of the tree.
  ///     If it's a symbolic link to a directory,
  ///     the walk starts at the directory it points to.
  ///   - order: When the walk visits a directory,
  ///     relative to its contents. The default is ``Order/preorder``.
  ///   - retryOnInterrupt: Whether to retry opening the root
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  ///
  /// Each entry's path starts with `root`.
  ///
  /// The corresponding C function is `opendir`.
  @_alwaysEmitIntoClient
  public init(
    _ root: FilePath,
    order: Order = .preorder,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    let stream = try DirectoryStream.open(root, retryOnInterrupt: retryOnInterrupt)
    self.init(stream, path: root, order: order)
  }

  /// Walks the tree under a directory stream's directory,
  /// taking ownership of the stream.
  ///
  /// - Parameters:
  ///   - root: A stream for the directory at the top of the tree.
  ///     The walk starts at the stream's position,
  ///     so it skips the entries the stream has already read.
  ///   - path: The path to start each entry's path with.
  ///     The default is an empty path, so each entry's path
  ///     is relative to the root.
  ///   - order: When the walk visits a directory,
  ///     relative to its contents. The default is ``Order/preorder``.
  ///
  /// To make sure the root isn't a symbolic link,
  /// open it with `.noFollow` and convert it:
  ///
  ///     let root = try FileDescriptor.open(
  ///       path, .readOnly, options: [.directory, .noFollow])
  ///     var walk = DirectoryWalk(try DirectoryStream(taking: root), path: path)
  @_alwaysEmitIntoClient
  public init(
    _ root: consuming DirectoryStream,
    path: FilePath = FilePath(),
    order: Order = .preorder
  ) {
    self.init(_stream: root, path: path, order: order)
  }

  @usableFromInline
  internal init(
    _stream root: consuming DirectoryStream, path: FilePath, order: Order
  ) {
    self.init(_root: root._takeDIR(), path: path, order: order)
  }
}

// MARK: - Walking

@available(System 199, *)
extension DirectoryWalk {
  /// An entry in a walk: a file under the root, and where it is.
  ///
  /// An entry holds copies of the values the walk read,
  /// so it doesn't change when the walk moves on.
  /// For operations relative to the directory that contains the entry,
  /// use ``DirectoryWalk/parentDirectory`` right after `next()`
  /// returns the entry.
  public struct Entry: Sendable, Hashable {
    /// The file's name in its directory.
    public var name: FilePath.Component

    /// The file's type.
    ///
    /// The walk uses the type the directory records,
    /// and gets the file's status to find the type
    /// if the directory doesn't record it.
    /// The type is `nil` only if that fails too, and then ``error`` says why.
    /// A symbolic link's type is ``FileType/symbolicLink``,
    /// whatever it points to.
    public var type: FileType?

    /// How deep the entry is: 1 for an entry in the root,
    /// 2 for an entry in one of the root's directories, and so on.
    public var depth: Int

    /// Why the walk couldn't visit this entry fully, if it couldn't.
    ///
    /// For a directory, this is the error from opening it,
    /// and the walk doesn't visit its contents.
    /// It can be ``Errno/permissionDenied``,
    /// or ``Errno/tooManyOpenFiles`` when the tree is too deep,
    /// or ``Errno/notDirectory`` or ``Errno/tooManySymbolicLinkLevels``
    /// if the directory was replaced by a symbolic link after the walk read
    /// its entry.
    /// For another entry, this is the error from getting the file's status
    /// to find its type, when its directory doesn't record the type.
    public var error: Errno?

    // The path of the directory that contains the entry.
    @usableFromInline
    internal var _parentPath: FilePath

    internal init(
      name: FilePath.Component, type: FileType?, depth: Int,
      error: Errno?, parentPath: FilePath
    ) {
      self.name = name
      self.type = type
      self.depth = depth
      self.error = error
      self._parentPath = parentPath
    }

    /// The file's path: the root's path,
    /// followed by the names of the directories down to the file,
    /// and the file's name.
    @_alwaysEmitIntoClient
    public var path: FilePath { _parentPath.appending(name) }
  }

  /// Visits the next entry in the tree.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the operations
  ///   of the walk if they throw ``Errno/interrupted``.
  ///   The default is `true`.
  ///   Pass `false` to try each only once and throw an error upon interruption.
  /// - Returns: The next entry, or `nil` after the last one.
  ///
  /// The walk visits the entries of each directory
  /// in the order the file system stores them,
  /// and doesn't visit the `.` and `..` entries.
  ///
  /// If opening a directory fails, the walk still returns its entry,
  /// with the ``Entry/error``, and moves on.
  /// If reading a directory's entries fails, this method throws,
  /// and the walk leaves that directory,
  /// so calling this method again continues with the rest of the tree.
  ///
  /// Each entry's name is reused as ``DirectoryStream/next(retryOnInterrupt:)``
  /// reuses its entries' names, so letting each entry go before visiting the
  /// next saves allocating memory for the names of files.
  ///
  /// The corresponding C functions are `readdir`, and for each directory,
  /// `openat` and `fdopendir`.
  @_alwaysEmitIntoClient
  public mutating func next(retryOnInterrupt: Bool = true) throws(Errno) -> Entry? {
    try _next(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal mutating func _next(retryOnInterrupt: Bool) -> Result<Entry?, Errno> {
    // Descend into the directory the last entry opened, in preorder.
    if let pending = _pending.take() {
      _levels.append(pending)
    }
    while let level = _levels.last {
      switch _readDirectoryEntry(level.dir, retryOnInterrupt: retryOnInterrupt) {
      case .failure(let error):
        // Leave the directory, so that the next call carries on without it.
        _ = system_closedir(_levels.removeLast().dir)
        return .failure(error)

      case .success(nil):
        // Closing a directory opened for reading fails only with EBADF, from
        // a descriptor closed behind the walk's back. As in the deinit, the
        // walk drops that error.
        let finished = _levels.removeLast()
        _ = system_closedir(finished.dir)
        if _order == .postorder, let name = finished.name, let parent = _levels.last {
          return .success(Entry(
            name: name, type: .directory, depth: _levels.count,
            error: nil, parentPath: parent.path))
        }

      case .success(let raw?):
        if let entry = _visit(raw, in: level, retryOnInterrupt: retryOnInterrupt) {
          return .success(entry)
        }
        // A postorder walk opened a directory, and reads its contents
        // before returning its entry.
      }
    }
    return .success(nil)
  }

  /// Makes the entry for something `readdir` returned,
  /// opening it first if it's a directory.
  ///
  /// In a postorder walk, a directory that opens is descended into at once,
  /// and this returns `nil`, since its entry comes after its contents.
  internal mutating func _visit(
    _ raw: UnsafeMutablePointer<system_dirent>,
    in level: _Level,
    retryOnInterrupt: Bool
  ) -> Entry? {
    let depth = _levels.count
    var type = FileType(_directoryEntryType: raw.pointee.d_type)
    var error: Errno? = nil
    if type == nil {
      // The directory doesn't record the type, so get it from the file.
      switch _resolveType(
        _directoryEntryName(raw), in: level.fileDescriptor,
        retryOnInterrupt: retryOnInterrupt
      ) {
      case .success(let resolved): type = resolved
      case .failure(let failure): error = failure
      }
    }
    _name._replaceContents(
      withPlatformString: _directoryEntryName(raw),
      length: _directoryEntryNameLength(raw))
    let name = FilePath.Component(_directoryEntryName: _name)

    if type == .directory {
      // Open the directory relative to its parent, without following a
      // symbolic link, so that a directory replaced by a link since readdir
      // fails to open rather than leading out of the tree.
      let opened = name._withPlatformStringInPlace {
        _openDirectoryStream(
          $0, relativeTo: level.fileDescriptor, options: _O_NOFOLLOW,
          retryOnInterrupt: retryOnInterrupt)
      }
      switch opened {
      case .success(let dir):
        let child = _Level(dir: dir, path: level.path.appending(name), name: name)
        if _order == .postorder {
          _levels.append(child)
          return nil
        }
        _pending = child
      case .failure(let failure):
        error = failure
      }
    }
    return Entry(
      name: name, type: type, depth: depth, error: error, parentPath: level.path)
  }

  /// Skips the contents of the directory that `next()` returned last.
  ///
  /// After a preorder walk visits a directory,
  /// call this method before calling `next()` again
  /// to go on to the directory's next sibling instead of its contents.
  /// If the walk isn't about to visit the contents of a directory,
  /// such as after visiting a file, or in a postorder walk,
  /// this method does nothing.
  @_alwaysEmitIntoClient
  public mutating func skipDescendants() {
    _skipDescendants()
  }

  @usableFromInline
  internal mutating func _skipDescendants() {
    if let pending = _pending.take() {
      _ = system_closedir(pending.dir)
    }
  }

  /// The file descriptor of the directory that contains the entry
  /// that `next()` returned last,
  /// for operations relative to that directory,
  /// such as removing the entry or getting its status.
  ///
  ///     let name = FilePath(root: nil, components: entry.name)
  ///     let status = try name.stat(
  ///       relativeTo: walk.parentDirectory, flags: .symlinkNoFollow)
  ///
  /// The returned value doesn't own the directory:
  /// it's valid only until the walk moves on.
  /// Don't close it, and don't keep it.
  ///
  /// Before the first call to `next()`, this is the root.
  /// After `next()` returns `nil`, the walk has closed every directory,
  /// and accessing this property is a programming error.
  @_alwaysEmitIntoClient
  public var parentDirectory: FileDescriptor {
    FileDescriptor(rawValue: _parentDirectory)
  }

  @usableFromInline
  internal var _parentDirectory: CInt {
    guard let level = _levels.last else {
      preconditionFailure("DirectoryWalk.parentDirectory: the walk has ended")
    }
    return level.fileDescriptor
  }
}

/// Finds the type of a directory's entry from its status,
/// for a file system that doesn't record types in directories.
@available(System 199, *)
internal func _resolveType(
  _ name: UnsafePointer<CInterop.PlatformChar>,
  in fd: CInt,
  retryOnInterrupt: Bool
) -> Result<FileType, Errno> {
  Stat._fstatat(
    name, relativeTo: fd, flags: .symlinkNoFollow,
    retryOnInterrupt: retryOnInterrupt
  ).map { Stat(rawValue: $0).type }
}

// MARK: - Closing

@available(System 199, *)
extension DirectoryWalk {
  /// Closes the directories the walk has open.
  ///
  /// None of them is closed again, whether this method returns or throws.
  /// If closing any of them fails, this method closes the rest,
  /// then throws the first error.
  ///
  /// The corresponding C function is `closedir`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _close().get()
  }

  @usableFromInline
  internal consuming func _close() -> Result<(), Errno> {
    let result = _closeAll()
    // Forget the closed directories, so that deinit doesn't close them again.
    _pending = nil
    _levels = []
    return result
  }

  /// Closes every open directory, and returns the first error.
  internal func _closeAll() -> Result<(), Errno> {
    var result: Result<(), Errno> = .success(())
    for level in [_pending].compactMap({ $0 }) + _levels.reversed() {
      let closed = nothingOrErrno(retryOnInterrupt: false) {
        system_closedir(level.dir)
      }
      if case .success = result { result = closed }
    }
    return result
  }
}

#endif // !os(Windows) && !os(WASI)
