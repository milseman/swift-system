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
/// `fts` with `FTS_NOCHDIR` holds none, and opens each directory by its path,
/// so it goes deeper, but reports a directory whose path is `PATH_MAX` bytes
/// or longer as unreadable (`FTS_DNR`), which a walk reads.
/// A walk with ``Options/boundedDescriptors`` holds at most three
/// however deep the tree is, and gives up a little for it:
/// see that option.
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

  // With `.whenEntered`, the name of a directory in the current one that
  // `next()` returned in preorder without opening it, which the next call
  // opens and descends into, unless `skipDescendants()` forgets it first.
  internal var _entered: FilePath.Component?

  // The name that `next()` returned last, reused as DirectoryStream's is.
  internal var _name: SystemString

  internal let _order: Order

  internal let _opening: DirectoryOpening

  internal let _options: Options

  internal init(
    _root dir: system_DIRPtr, path: FilePath, order: Order, opening: DirectoryOpening,
    options: Options
  ) {
    self._levels = [_Level(handle: .stream(dir), path: path, name: nil)]
    self._pending = nil
    self._entered = nil
    self._name = SystemString()
    self._order = order
    self._opening = opening
    self._options = options
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

/// A directory in a walk, between the root and the entry it visits.
internal struct _Level {
  // How the walk holds the directory, which it owns.
  var handle: _Handle

  // The directory's path: the root's, or its parent's path and its name.
  var path: FilePath

  // The directory's name in its parent, for its postorder entry.
  // `nil` for the root, which the walk doesn't visit.
  var name: FilePath.Component?

  // With `.boundedDescriptors`, the directory's entries, which the walk
  // reads whole the first time it reads the directory (`nil` until then);
  // the next one to visit; and the error that stopped the reading, if one
  // did, which the walk throws after visiting the entries read before it.
  var entries: [_EntryRead]? = nil
  var nextEntry: Int = 0
  var readError: Errno? = nil

  // With `.boundedDescriptors`, the directory's device and inode, to check
  // that a directory the walk reopens is the one it read.
  var identity: _DirectoryIdentity? = nil

  var fileDescriptor: CInt { handle.fileDescriptor }

  // The directory's stream. A walk without `.boundedDescriptors` holds one
  // for each level.
  var stream: system_DIRPtr {
    guard case .stream(let dir) = handle else {
      preconditionFailure("DirectoryWalk: a level without its stream")
    }
    return dir
  }
}

/// How a walk holds a directory.
internal enum _Handle {
  // The stream the walk opened the directory with, and reads it through.
  case stream(system_DIRPtr)

  // With `.boundedDescriptors`: a descriptor for a directory the walk has
  // read whole, closed, and reopened.
  case descriptor(CInt)

  // With `.boundedDescriptors`: a directory the walk has read whole, and
  // closed when it went into one of its subdirectories.
  case closed

  // -1 for a closed directory, which any call fails with EBADF.
  var fileDescriptor: CInt {
    switch self {
    case .stream(let dir): return system_dirfd(dir)
    case .descriptor(let fd): return fd
    case .closed: return -1
    }
  }

  /// Closes the directory, if it's open.
  func close() -> Result<(), Errno> {
    switch self {
    case .stream(let dir):
      return nothingOrErrno(retryOnInterrupt: false) { system_closedir(dir) }
    case .descriptor(let fd):
      return nothingOrErrno(retryOnInterrupt: false) { system_close(fd) }
    case .closed:
      return .success(())
    }
  }
}

/// An entry of a directory that a walk has read whole: what `readdir`
/// returned, copied.
internal struct _EntryRead {
  var name: FilePath.Component
  var type: UInt8
}

/// A directory's device and inode.
internal struct _DirectoryIdentity: Equatable {
  var device: UInt64
  var inode: UInt64
}

// MARK: - Starting

@available(System 199, *)
extension DirectoryWalk {
  /// When a walk visits a directory, relative to its contents.
  @frozen
  public enum Order: Sendable, Hashable {
    /// Visit each directory before its contents.
    ///
    /// Only a walk that visits directories before their contents
    /// can skip a directory's contents,
    /// with ``DirectoryWalk/skipDescendants()``.
    case preorder

    /// Visit each directory after its contents,
    /// as removing a tree or adding up its sizes requires.
    case postorder

    /// Visit each directory twice: before its contents,
    /// and again after them,
    /// as copying a tree requires,
    /// to create each directory and then to set its metadata.
    ///
    /// The second visit's entry has ``Entry/isPostorderVisit``.
    /// A directory the walk can't open is visited once, with its error,
    /// and so is one whose contents ``DirectoryWalk/skipDescendants()`` skips;
    /// a walk that opens directories ``DirectoryOpening/whenEntered``
    /// visits one it can't open twice, the second time with the error.
    /// This is `fts`'s pair of visits, `FTS_D` and `FTS_DP`.
    case preorderAndPostorder
  }

  /// When a walk opens a directory to read its contents.
  @frozen
  public enum DirectoryOpening: Sendable, Hashable {
    /// When the walk reads the directory's entry,
    /// before it visits the directory.
    ///
    /// The entry of a directory that the walk can't open has the error.
    /// Darwin's `fdopendir` reads a directory's entries when it opens it,
    /// so the walk has a directory's contents before the caller handles
    /// the directory's entry.
    case whenRead

    /// When the walk goes into the directory,
    /// after it visits the directory before its contents,
    /// as `fts` does.
    ///
    /// The caller has handled the directory's first visit
    /// when the walk reads its contents,
    /// so copying a tree into itself sees what the copy has added.
    /// A directory that the walk can't open has a first visit
    /// without an error, and a second visit, as its postorder visit,
    /// with the error, in place of its contents:
    /// `fts`'s `FTS_D` and `FTS_DNR`.
    /// ``DirectoryWalk/skipDescendants()`` after the first visit
    /// keeps the walk from opening it at all.
    /// A ``Order/postorder`` walk opens a directory before its contents,
    /// as it reads the directory's entry, whichever the option.
    case whenEntered
  }

  /// Options for a walk.
  @frozen
  public struct Options: OptionSet, Sendable, Hashable {
    /// The options' bits, which are `DirectoryWalk`'s own, not a C type's.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a set of options from its bits.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Holds at most three descriptors, however deep the tree is.
    ///
    /// The walk reads each directory's entries whole
    /// the first time it reads the directory, as `fts` does,
    /// and closes the directory when it goes into one of its subdirectories,
    /// keeping only the root open.
    /// When it comes back to the directory, to visit the rest of its entries
    /// or a subdirectory's visit after its contents,
    /// it reopens the directory by name, starting from the root:
    /// each directory on the way relative to the one before,
    /// and none through a symbolic link.
    /// Then it checks the directory's device and inode,
    /// so that ``DirectoryWalk/parentDirectory``
    /// is always the directory whose entries the walk visits,
    /// and replacing a directory with a link still can't lead the walk
    /// out of the tree.
    ///
    /// What the walk gives up:
    /// - It follows names, not directories,
    ///   between a directory and its subdirectories.
    ///   If the directory has been moved or replaced when the walk comes back,
    ///   ``DirectoryWalk/next(retryOnInterrupt:)`` throws the error
    ///   from reopening it,
    ///   or ``Errno/noSuchFileOrDirectory`` if what it finds there now
    ///   is another directory, as `fts` does,
    ///   and leaves the directory, as when reading one fails.
    ///   Without this option, the walk reads a directory where it is.
    /// - A directory's entries are the ones it had
    ///   when the walk first read it,
    ///   and the walk keeps the entries of every directory
    ///   between the root and the entry it visits.
    /// - Coming back to a directory costs an `openat`
    ///   for each level between it and the root, and an `fstat`.
    ///
    /// Without this option, a walk holds a descriptor for each level.
    @_alwaysEmitIntoClient
    public static var boundedDescriptors: Options { Options(rawValue: 1 << 0) }
  }

  /// Opens a directory to walk the tree under it.
  ///
  /// - Parameters:
  ///   - root: The directory at the top of the tree.
  ///     If it's a symbolic link to a directory,
  ///     the walk starts at the directory it points to.
  ///   - order: When the walk visits a directory,
  ///     relative to its contents. The default is ``Order/preorder``.
  ///   - opening: When the walk opens a directory to read its contents.
  ///     The default is ``DirectoryOpening/whenRead``.
  ///   - options: Options for the walk. The default is none.
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
    opening: DirectoryOpening = .whenRead,
    options: Options = [],
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    let stream = try DirectoryStream.open(root, retryOnInterrupt: retryOnInterrupt)
    self.init(stream, path: root, order: order, opening: opening, options: options)
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
  ///   - opening: When the walk opens a directory to read its contents.
  ///     The default is ``DirectoryOpening/whenRead``.
  ///   - options: Options for the walk. The default is none.
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
    order: Order = .preorder,
    opening: DirectoryOpening = .whenRead,
    options: Options = []
  ) {
    self.init(_stream: root, path: path, order: order, opening: opening, options: options)
  }

  @usableFromInline
  internal init(
    _stream root: consuming DirectoryStream, path: FilePath, order: Order,
    opening: DirectoryOpening = .whenRead, options: Options = []
  ) {
    self.init(
      _root: root._takeDIR(), path: path, order: order, opening: opening,
      options: options)
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
    /// and the walk doesn't visit its contents;
    /// a walk that opens directories ``DirectoryOpening/whenEntered``
    /// reports it on the directory's second visit.
    /// It can be ``Errno/permissionDenied``,
    /// or ``Errno/tooManyOpenFiles`` when the tree is too deep
    /// for a walk without ``Options/boundedDescriptors``,
    /// or ``Errno/notDirectory`` or ``Errno/tooManySymbolicLinkLevels``
    /// if the directory was replaced by a symbolic link after the walk read
    /// its entry.
    /// For another entry, this is the error from getting the file's status
    /// to find its type, when its directory doesn't record the type.
    public var error: Errno?

    /// Whether this is a directory's visit after its contents:
    /// the only visit in a ``Order/postorder`` walk,
    /// and the second in a ``Order/preorderAndPostorder`` one.
    public var isPostorderVisit: Bool

    // The path of the directory that contains the entry.
    @usableFromInline
    internal var _parentPath: FilePath

    internal init(
      name: FilePath.Component, type: FileType?, depth: Int,
      error: Errno?, parentPath: FilePath, isPostorderVisit: Bool = false
    ) {
      self.name = name
      self.type = type
      self.depth = depth
      self.error = error
      self.isPostorderVisit = isPostorderVisit
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
  /// with the ``Entry/error``, and moves on;
  /// with ``DirectoryOpening/whenEntered``, it returns the directory's
  /// entry again, with the error.
  /// If reading a directory's entries fails, this method throws,
  /// and the walk leaves that directory,
  /// so calling this method again continues with the rest of the tree.
  /// With ``Options/boundedDescriptors``, so does failing to reopen
  /// a directory the walk comes back to.
  ///
  /// Each entry's name is reused as ``DirectoryStream/next(retryOnInterrupt:)``
  /// reuses its entries' names, so letting each entry go before visiting the
  /// next saves allocating memory for the names of files.
  ///
  /// The corresponding C functions are `readdir`, and for each directory,
  /// `openat` and `fdopendir`;
  /// with ``Options/boundedDescriptors``, `fstat` too,
  /// and `openat` and `fstat` again to reopen one.
  @_alwaysEmitIntoClient
  public mutating func next(retryOnInterrupt: Bool = true) throws(Errno) -> Entry? {
    try _next(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal mutating func _next(retryOnInterrupt: Bool) -> Result<Entry?, Errno> {
    // Descend into the directory the last entry opened, in preorder.
    if let pending = _pending.take() {
      _descend(into: pending)
    } else if let name = _entered.take(), let parent = _levels.last {
      // Or open the one it named, with `.whenEntered`. If that fails, the
      // directory's second visit has the error, in place of its contents.
      switch _openChild(name, in: parent, retryOnInterrupt: retryOnInterrupt) {
      case .success(let child):
        _descend(into: child)
      case .failure(let error):
        return .success(Entry(
          name: name, type: .directory, depth: _levels.count,
          error: error, parentPath: parent.path, isPostorderVisit: true))
      }
    }
    if _options.contains(.boundedDescriptors) {
      return _nextOfEntriesRead(retryOnInterrupt: retryOnInterrupt)
    }
    while let level = _levels.last {
      switch _readDirectoryEntry(level.stream, retryOnInterrupt: retryOnInterrupt) {
      case .failure(let error):
        // Leave the directory, so that the next call carries on without it.
        _ = _levels.removeLast().handle.close()
        return .failure(error)

      case .success(nil):
        // Closing a directory opened for reading fails only with EBADF, from
        // a descriptor closed behind the walk's back. As in the deinit, the
        // walk drops that error.
        let finished = _levels.removeLast()
        _ = finished.handle.close()
        if _order != .preorder, let name = finished.name, let parent = _levels.last {
          return .success(Entry(
            name: name, type: .directory, depth: _levels.count,
            error: nil, parentPath: parent.path, isPostorderVisit: true))
        }

      case .success(let raw?):
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
        if let entry = _visit(
          name, type: type, error: error, in: level,
          retryOnInterrupt: retryOnInterrupt
        ) {
          return .success(entry)
        }
        // A postorder walk opened a directory, and reads its contents
        // before returning its entry.
      }
    }
    return .success(nil)
  }

  /// `_next` for a walk with `.boundedDescriptors`, which visits the entries
  /// it has read, and reopens a directory it comes back to.
  internal mutating func _nextOfEntriesRead(
    retryOnInterrupt: Bool
  ) -> Result<Entry?, Errno> {
    while !_levels.isEmpty {
      let top = _levels.count - 1
      if _levels[top].entries == nil {
        // The walk has just opened the directory, or it's the root: read
        // it whole.
        (_levels[top].entries, _levels[top].readError) = _readWhole(
          _levels[top].stream, retryOnInterrupt: retryOnInterrupt)
      }
      let level = _levels[top]
      let entries = level.entries!
      guard level.nextEntry < entries.count else {
        // Leave the finished directory, which needs no descriptor to leave.
        let finished = _levels.removeLast()
        _ = finished.handle.close()
        if let error = finished.readError { return .failure(error) }
        if _order != .preorder, let name = finished.name, !_levels.isEmpty {
          // Its postorder visit's parentDirectory is its parent.
          if let error = _reopenTop(retryOnInterrupt: retryOnInterrupt) {
            return .failure(error)
          }
          return .success(Entry(
            name: name, type: .directory, depth: _levels.count,
            error: nil, parentPath: _levels[top - 1].path, isPostorderVisit: true))
        }
        continue
      }
      if let error = _reopenTop(retryOnInterrupt: retryOnInterrupt) {
        return .failure(error)
      }
      _levels[top].nextEntry += 1
      let read = entries[level.nextEntry]
      let fd = _levels[top].fileDescriptor
      var type = FileType(_directoryEntryType: read.type)
      var error: Errno? = nil
      if type == nil {
        // The directory doesn't record the type, so get it from the file.
        switch read.name._withPlatformStringInPlace({
          _resolveType($0, in: fd, retryOnInterrupt: retryOnInterrupt)
        }) {
        case .success(let resolved): type = resolved
        case .failure(let failure): error = failure
        }
      }
      if let entry = _visit(
        read.name, type: type, error: error, in: _levels[top],
        retryOnInterrupt: retryOnInterrupt
      ) {
        return .success(entry)
      }
    }
    return .success(nil)
  }

  /// Makes the entry for a directory's entry,
  /// opening it first if it's a directory.
  ///
  /// In a postorder walk, a directory that opens is descended into at once,
  /// and this returns `nil`, since its entry comes after its contents.
  internal mutating func _visit(
    _ name: FilePath.Component, type: FileType?, error: Errno?,
    in level: _Level,
    retryOnInterrupt: Bool
  ) -> Entry? {
    let depth = _levels.count
    var error = error
    if type == .directory {
      if _opening == .whenEntered && _order != .postorder {
        _entered = name
      } else {
        switch _openChild(name, in: level, retryOnInterrupt: retryOnInterrupt) {
        case .success(let child):
          if _order == .postorder {
            _descend(into: child)
            return nil
          }
          _pending = child
        case .failure(let failure):
          error = failure
        }
      }
    }
    return Entry(
      name: name, type: type, depth: depth, error: error, parentPath: level.path)
  }

  /// Opens a directory in `level` for the walk to read.
  internal func _openChild(
    _ name: FilePath.Component, in level: _Level, retryOnInterrupt: Bool
  ) -> Result<_Level, Errno> {
    // Open the directory relative to its parent, without following a
    // symbolic link, so that a directory replaced by a link since readdir
    // fails to open rather than leading out of the tree.
    let opened = name._withPlatformStringInPlace {
      _openDirectoryStream(
        $0, relativeTo: level.fileDescriptor, options: _O_NOFOLLOW,
        retryOnInterrupt: retryOnInterrupt)
    }
    return opened.flatMap { dir in
      var child = _Level(
        handle: .stream(dir), path: level.path.appending(name), name: name)
      if _options.contains(.boundedDescriptors) {
        switch _identity(of: system_dirfd(dir), retryOnInterrupt: retryOnInterrupt) {
        case .success(let identity):
          child.identity = identity
        case .failure(let error):
          _ = system_closedir(dir)
          return .failure(error)
        }
      }
      return .success(child)
    }
  }

  /// Goes into a directory that the walk has opened.
  ///
  /// With `.boundedDescriptors`, this closes the directory the walk leaves,
  /// unless it's the root, which the walk reopens the others from.
  internal mutating func _descend(into child: _Level) {
    if _options.contains(.boundedDescriptors) && _levels.count > 1 {
      let top = _levels.count - 1
      _ = _levels[top].handle.close()
      _levels[top].handle = .closed
    }
    _levels.append(child)
  }

  /// With `.boundedDescriptors`, reopens the directory the walk is in,
  /// if it closed it; if that fails, leaves the directory,
  /// as when reading one fails, and returns the error.
  internal mutating func _reopenTop(retryOnInterrupt: Bool) -> Errno? {
    let top = _levels.count - 1
    guard case .closed = _levels[top].handle else { return nil }
    switch _reopen(top, retryOnInterrupt: retryOnInterrupt) {
    case .success(let fd):
      _levels[top].handle = .descriptor(fd)
      return nil
    case .failure(let error):
      _levels.removeLast()
      return error
    }
  }

  /// Reopens a level that the walk closed, by the names of the directories
  /// from the root down to it: each relative to the one before, without
  /// following a symbolic link. Then checks that it's the directory the
  /// walk read.
  internal func _reopen(_ index: Int, retryOnInterrupt: Bool) -> Result<CInt, Errno> {
    precondition(index > 0, "DirectoryWalk: the root is never closed")
    let root = _levels[0].fileDescriptor
    var fd = root
    for level in _levels[1...index] {
      let opened = level.name!._withPlatformStringInPlace { name in
        valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
          system_openat(fd, name, _O_RDONLY | _O_DIRECTORY | _O_NOFOLLOW | _O_CLOEXEC)
        }
      }
      if fd != root { _ = system_close(fd) }
      switch opened {
      case .success(let next): fd = next
      case .failure(let error): return .failure(error)
      }
    }
    switch _identity(of: fd, retryOnInterrupt: retryOnInterrupt) {
    case .success(let identity) where identity == _levels[index].identity:
      return .success(fd)
    case .success:
      // Another directory has the name now, and its entries aren't the
      // ones the walk read. fts reports this as ENOENT too.
      _ = system_close(fd)
      return .failure(.noSuchFileOrDirectory)
    case .failure(let error):
      _ = system_close(fd)
      return .failure(error)
    }
  }

  /// Reads a directory's entries whole, and returns them with the error
  /// that stopped the reading, if one did.
  internal func _readWhole(
    _ dir: system_DIRPtr, retryOnInterrupt: Bool
  ) -> ([_EntryRead], Errno?) {
    var entries: [_EntryRead] = []
    while true {
      switch _readDirectoryEntry(dir, retryOnInterrupt: retryOnInterrupt) {
      case .failure(let error):
        return (entries, error)
      case .success(nil):
        return (entries, nil)
      case .success(let raw?):
        var name = SystemString()
        name._replaceContents(
          withPlatformString: _directoryEntryName(raw),
          length: _directoryEntryNameLength(raw))
        entries.append(_EntryRead(
          name: FilePath.Component(_directoryEntryName: name),
          type: raw.pointee.d_type))
      }
    }
  }

  /// A directory's device and inode, from its descriptor.
  internal func _identity(
    of fd: CInt, retryOnInterrupt: Bool
  ) -> Result<_DirectoryIdentity, Errno> {
    Stat._fstat(FileDescriptor(rawValue: fd), retryOnInterrupt: retryOnInterrupt).map {
      _DirectoryIdentity(
        device: UInt64(truncatingIfNeeded: $0.st_dev),
        inode: UInt64(truncatingIfNeeded: $0.st_ino))
    }
  }

  /// Skips the contents of the directory that `next()` returned last.
  ///
  /// After a preorder walk visits a directory,
  /// call this method before calling `next()` again
  /// to go on to the directory's next sibling instead of its contents.
  /// A ``Order/preorderAndPostorder`` walk then skips the directory's
  /// second visit too.
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
      _ = pending.handle.close()
    }
    _entered = nil
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
    _entered = nil
    _levels = []
    return result
  }

  /// Closes every open directory, and returns the first error.
  internal func _closeAll() -> Result<(), Errno> {
    var result: Result<(), Errno> = .success(())
    for level in [_pending].compactMap({ $0 }) + _levels.reversed() {
      let closed = level.handle.close()
      if case .success = result { result = closed }
    }
    return result
  }
}

#endif // !os(Windows) && !os(WASI)
