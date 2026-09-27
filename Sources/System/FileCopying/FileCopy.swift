/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Copying files: copyfile for paths and fcopyfile for file descriptors.
//
// These have no `retryOnInterrupt` parameter, unlike most of System's
// wrappers: an interrupted copy may have created and partly written the
// destination, so retrying it isn't the same as copying. An exclusive copy's
// retry would throw EEXIST, and a move's retry would find no source.

#if SYSTEM_PACKAGE_DARWIN

// MARK: - Copy options

@available(System 199, *)
extension FilePath {
  /// Options for copying a file: which of its contents to copy, and how.
  ///
  /// Include at least one of the options that name contents,
  /// such as ``data`` or ``all``;
  /// a copy without any copies nothing.
  ///
  /// Options that name a path, such as ``exclusive`` and ``recursive``,
  /// apply only to copying from one path to another,
  /// with ``FilePath/copy(to:options:)``;
  /// ``FileDescriptor/copy(to:options:)`` ignores them.
  ///
  /// The corresponding C type is `copyfile_flags_t`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct CopyOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates a strongly-typed `FilePath.CopyOptions` from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Copy the file's access control list.
    ///
    /// The corresponding C constant is `COPYFILE_ACL`.
    @_alwaysEmitIntoClient
    public static var accessControlList: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_ACL)
    }

    /// Copy the file's POSIX information,
    /// such as its permissions and modification time.
    ///
    /// The set-user-ID and set-group-ID bits aren't copied
    /// from or to a volume mounted with `MNT_NOSUID`,
    /// unless ``FilePath/CopyState/preservesSetIDBits`` is `true`.
    ///
    /// The corresponding C constant is `COPYFILE_STAT`.
    @_alwaysEmitIntoClient
    public static var stat: CopyOptions { CopyOptions(rawValue: _COPYFILE_STAT) }

    /// Copy the file's extended attributes.
    ///
    /// The corresponding C constant is `COPYFILE_XATTR`.
    @_alwaysEmitIntoClient
    public static var extendedAttributes: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_XATTR)
    }

    /// Copy the file's data.
    ///
    /// The corresponding C constant is `COPYFILE_DATA`.
    @_alwaysEmitIntoClient
    public static var data: CopyOptions { CopyOptions(rawValue: _COPYFILE_DATA) }

    /// Copy the file's POSIX information and access control list:
    /// ``stat`` and ``accessControlList``.
    ///
    /// The corresponding C constant is `COPYFILE_SECURITY`.
    @_alwaysEmitIntoClient
    public static var security: CopyOptions { CopyOptions(rawValue: _COPYFILE_SECURITY) }

    /// Copy all of the file's metadata:
    /// ``security`` and ``extendedAttributes``.
    ///
    /// The corresponding C constant is `COPYFILE_METADATA`.
    @_alwaysEmitIntoClient
    public static var metadata: CopyOptions { CopyOptions(rawValue: _COPYFILE_METADATA) }

    /// Copy the whole file: ``metadata`` and ``data``.
    ///
    /// The corresponding C constant is `COPYFILE_ALL`.
    @_alwaysEmitIntoClient
    public static var all: CopyOptions { CopyOptions(rawValue: _COPYFILE_ALL) }

    /// Copy a directory and everything in it.
    ///
    /// If the destination is a directory, the source is copied into it;
    /// if the source path also ends in a slash,
    /// the source directory's contents are copied into it instead,
    /// as `cp` does.
    /// Without this option, a copy to a directory throws
    /// ``Errno/isDirectory``.
    /// A recursive copy doesn't accept ``move``, ``unlinkDestination``,
    /// ``pack``, ``unpack``, or ``forceClone``,
    /// and throws ``Errno/invalidArgument`` for them.
    ///
    /// The corresponding C constant is `COPYFILE_RECURSIVE`.
    @_alwaysEmitIntoClient
    public static var recursive: CopyOptions { CopyOptions(rawValue: _COPYFILE_RECURSIVE) }

    /// Throw ``Errno/fileExists`` if a file exists at the destination.
    ///
    /// The corresponding C constant is `COPYFILE_EXCL`.
    @_alwaysEmitIntoClient
    public static var exclusive: CopyOptions { CopyOptions(rawValue: _COPYFILE_EXCL) }

    /// If the source is a symbolic link, copy the link itself.
    ///
    /// The corresponding C constant is `COPYFILE_NOFOLLOW_SRC`.
    @_alwaysEmitIntoClient
    public static var noFollowSource: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_NOFOLLOW_SRC)
    }

    /// If the destination is a symbolic link, replace the link itself.
    ///
    /// The corresponding C constant is `COPYFILE_NOFOLLOW_DST`.
    @_alwaysEmitIntoClient
    public static var noFollowDestination: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_NOFOLLOW_DST)
    }

    /// Don't follow a symbolic link at either path:
    /// ``noFollowSource`` and ``noFollowDestination``.
    ///
    /// The corresponding C constant is `COPYFILE_NOFOLLOW`.
    @_alwaysEmitIntoClient
    public static var noFollow: CopyOptions { CopyOptions(rawValue: _COPYFILE_NOFOLLOW) }

    /// Remove the source after copying it.
    ///
    /// A failure to remove the source isn't an error.
    ///
    /// The corresponding C constant is `COPYFILE_MOVE`.
    @_alwaysEmitIntoClient
    public static var move: CopyOptions { CopyOptions(rawValue: _COPYFILE_MOVE) }

    /// Remove the destination before copying.
    ///
    /// The corresponding C constant is `COPYFILE_UNLINK`.
    @_alwaysEmitIntoClient
    public static var unlinkDestination: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_UNLINK)
    }

    /// Serialize the file into an AppleDouble file at the destination.
    ///
    /// The corresponding C constant is `COPYFILE_PACK`.
    @_alwaysEmitIntoClient
    public static var pack: CopyOptions { CopyOptions(rawValue: _COPYFILE_PACK) }

    /// Restore a file from the AppleDouble file at the source.
    ///
    /// The destination gets the extended attributes,
    /// access control list, resource fork, and Finder information
    /// that the AppleDouble file holds,
    /// whichever contents the other options name.
    ///
    /// The corresponding C constant is `COPYFILE_UNPACK`.
    @_alwaysEmitIntoClient
    public static var unpack: CopyOptions { CopyOptions(rawValue: _COPYFILE_UNPACK) }

    /// Clone the file if the file system can, and copy it otherwise.
    ///
    /// This option implies
    /// ``exclusive``, ``stat``, ``extendedAttributes``, ``data``,
    /// and ``noFollowSource``.
    /// It doesn't clone a directory, which it copies instead,
    /// or clone an access control list unless the options include
    /// ``accessControlList``.
    /// A clone doesn't call a copy's progress handler,
    /// or copy the set-user-ID and set-group-ID bits.
    ///
    /// The corresponding C constant is `COPYFILE_CLONE`.
    @_alwaysEmitIntoClient
    public static var clone: CopyOptions { CopyOptions(rawValue: _COPYFILE_CLONE) }

    /// Clone the file, and throw an error if the file system can't.
    ///
    /// This option implies the same options as ``clone``.
    /// If the file system can't clone the file,
    /// the copy throws ``Errno/notSupported``,
    /// and it throws an error for a directory.
    ///
    /// The corresponding C constant is `COPYFILE_CLONE_FORCE`.
    @_alwaysEmitIntoClient
    public static var forceClone: CopyOptions { CopyOptions(rawValue: _COPYFILE_CLONE_FORCE) }

    /// If the source has quarantine information,
    /// mark the destination's so that a bundle runs where it is,
    /// rather than being translocated.
    ///
    /// The corresponding C constant is `COPYFILE_RUN_IN_PLACE`.
    @_alwaysEmitIntoClient
    public static var runInPlace: CopyOptions { CopyOptions(rawValue: _COPYFILE_RUN_IN_PLACE) }

    /// Copy the file's data sparsely, preserving its holes.
    ///
    /// Both file systems must support holes at least as large as their
    /// blocks, and the source must be sparse.
    /// If the data can't be copied sparsely,
    /// the copy copies it in full if the options include ``data``,
    /// and otherwise throws an error.
    ///
    /// The corresponding C constant is `COPYFILE_DATA_SPARSE`.
    @_alwaysEmitIntoClient
    public static var sparseData: CopyOptions { CopyOptions(rawValue: _COPYFILE_DATA_SPARSE) }

    /// Keep the destination's `UF_TRACKED` flag when copying metadata,
    /// whether or not the source has it.
    ///
    /// The corresponding C constant is `COPYFILE_PRESERVE_DST_TRACKED`.
    @_alwaysEmitIntoClient
    public static var preserveDestinationTracked: CopyOptions {
      CopyOptions(rawValue: _COPYFILE_PRESERVE_DST_TRACKED)
    }

    /// Log the copy's warnings and errors.
    ///
    /// The corresponding C constant is `COPYFILE_VERBOSE`.
    @_alwaysEmitIntoClient
    public static var verbose: CopyOptions { CopyOptions(rawValue: _COPYFILE_VERBOSE) }
  }
}

@available(System 199, *)
extension FilePath.CopyOptions: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the options.
  @inline(never)
  public var description: String {
    // The combinations come first, so that they describe themselves.
    let descriptions: [(Element, StaticString)] = [
      (.all, ".all"),
      (.metadata, ".metadata"),
      (.security, ".security"),
      (.noFollow, ".noFollow"),
      (.accessControlList, ".accessControlList"),
      (.stat, ".stat"),
      (.extendedAttributes, ".extendedAttributes"),
      (.data, ".data"),
      (.recursive, ".recursive"),
      (.exclusive, ".exclusive"),
      (.noFollowSource, ".noFollowSource"),
      (.noFollowDestination, ".noFollowDestination"),
      (.move, ".move"),
      (.unlinkDestination, ".unlinkDestination"),
      (.pack, ".pack"),
      (.unpack, ".unpack"),
      (.clone, ".clone"),
      (.forceClone, ".forceClone"),
      (.runInPlace, ".runInPlace"),
      (.sparseData, ".sparseData"),
      (.preserveDestinationTracked, ".preserveDestinationTracked"),
      (.verbose, ".verbose"),
    ]
    return _buildDescription(descriptions)
  }

  /// A textual representation of the options, suitable for debugging.
  public var debugDescription: String { self.description }
}

// MARK: - copyfile

@available(System 199, *)
extension FilePath {
  /// Copies the file at this path, or some of its contents, to another path.
  ///
  /// - Parameters:
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///
  /// If the destination can't be written,
  /// the copy makes it writable for the duration,
  /// and then restores its permissions unless the options include
  /// ``CopyOptions/stat``.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(to destination: FilePath, options: CopyOptions) throws(Errno) {
    try withPlatformString { source in
      destination.withPlatformString { destination in
        FilePath._copy(source, to: destination, options: options, state: nil, progress: nil)
      }
    }.get()
  }

  /// Copies the file at this path, or some of its contents, to another path,
  /// with a copy state that holds the copy's settings and results.
  ///
  /// - Parameters:
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///
  /// The copy throws an error for a setting that the system doesn't support,
  /// without copying anything.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(
    to destination: FilePath, options: CopyOptions, state: inout CopyState
  ) throws(Errno) {
    try withUnsafeMutablePointer(to: &state) { state in
      withPlatformString { source in
        destination.withPlatformString { destination in
          FilePath._copy(source, to: destination, options: options, state: state, progress: nil)
        }
      }
    }.get()
  }

  /// Copies the file at this path, or some of its contents, to another path,
  /// with a copy state that holds the copy's settings and results,
  /// and reports the copy's progress.
  ///
  /// - Parameters:
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///   - progress: A closure that the copy calls as it goes,
  ///     and that returns whether to continue.
  ///
  /// The copy calls `progress` as it copies each file of a recursive copy,
  /// and as it writes data and extended attributes;
  /// see ``CopyProgress``.
  /// To stop the copy, return ``CopyProgress/Action/quit``;
  /// the copy then throws ``Errno/canceled``,
  /// and leaves what it has copied in place.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`,
  /// with the `COPYFILE_STATE_STATUS_CB` state.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(
    to destination: FilePath,
    options: CopyOptions,
    state: inout CopyState,
    progress: (CopyProgress) -> CopyProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      withUnsafeMutablePointer(to: &state) { state in
        withPlatformString { source in
          destination.withPlatformString { destination in
            FilePath._copy(
              source, to: destination, options: options, state: state, progress: progress)
          }
        }
      }
    }.get()
  }

  /// Copies the file at the given path, or some of its contents,
  /// to another path.
  ///
  /// - Parameters:
  ///   - source: The file to copy.
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///
  /// If the destination can't be written,
  /// the copy makes it writable for the duration,
  /// and then restores its permissions unless the options include
  /// ``CopyOptions/stat``.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func copy(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CopyOptions
  ) throws(Errno) {
    try _copy(source, to: destination, options: options, state: nil, progress: nil).get()
  }

  /// Copies the file at the given path, or some of its contents,
  /// to another path,
  /// with a copy state that holds the copy's settings and results.
  ///
  /// - Parameters:
  ///   - source: The file to copy.
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///
  /// The copy throws an error for a setting that the system doesn't support,
  /// without copying anything.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func copy(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CopyOptions,
    state: inout CopyState
  ) throws(Errno) {
    try withUnsafeMutablePointer(to: &state) { state in
      _copy(source, to: destination, options: options, state: state, progress: nil)
    }.get()
  }

  /// Copies the file at the given path, or some of its contents,
  /// to another path,
  /// with a copy state that holds the copy's settings and results,
  /// and reports the copy's progress.
  ///
  /// - Parameters:
  ///   - source: The file to copy.
  ///   - destination: Where to copy the file.
  ///   - options: Which of the file's contents to copy, and how.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///   - progress: A closure that the copy calls as it goes,
  ///     and that returns whether to continue.
  ///
  /// The copy calls `progress` as it copies each file of a recursive copy,
  /// and as it writes data and extended attributes;
  /// see ``CopyProgress``.
  /// To stop the copy, return ``CopyProgress/Action/quit``;
  /// the copy then throws ``Errno/canceled``,
  /// and leaves what it has copied in place.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `copyfile`,
  /// with the `COPYFILE_STATE_STATUS_CB` state.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func copy(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CopyOptions,
    state: inout CopyState,
    progress: (CopyProgress) -> CopyProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      withUnsafeMutablePointer(to: &state) { state in
        _copy(source, to: destination, options: options, state: state, progress: progress)
      }
    }.get()
  }

  @usableFromInline
  internal static func _copy(
    _ source: UnsafePointer<CChar>,
    to destination: UnsafePointer<CChar>,
    options: CopyOptions,
    state: UnsafeMutablePointer<CopyState>?,
    progress: ((CopyProgress) -> CopyProgress.Action)?
  ) -> Result<(), Errno> {
    _withCopyState(state, progress: progress) { cState in
      system_copyfile(source, destination, cState, options.rawValue)
    }.map { _ in () }
  }
}

// MARK: - COPYFILE_CHECK

@available(System 199, *)
extension FilePath {
  /// Returns which of the given contents of the file at this path
  /// a copy would copy, without copying anything.
  ///
  /// - Parameters:
  ///   - options: The contents to check for, such as ``CopyOptions/metadata``,
  ///     and how to find the file, such as ``CopyOptions/noFollowSource``.
  /// - Returns: The contents in `options` that the file has
  ///   and that a copy would copy:
  ///   ``CopyOptions/accessControlList`` and
  ///   ``CopyOptions/extendedAttributes``.
  ///
  /// A file's POSIX information and data are always there to copy,
  /// so the result doesn't include ``CopyOptions/stat`` or
  /// ``CopyOptions/data``.
  /// The check doesn't report an error for a file it can't read,
  /// including one that doesn't exist:
  /// it returns an empty set, as for a file with nothing more to copy.
  ///
  /// The corresponding C function is `copyfile`,
  /// with the `COPYFILE_CHECK` flag.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func contentsToCopy(options: CopyOptions) throws(Errno) -> CopyOptions {
    try withPlatformString { FilePath._contentsToCopy($0, options: options) }.get()
  }

  /// Returns which of the given contents of the file at the given path
  /// a copy would copy, without copying anything.
  ///
  /// - Parameters:
  ///   - path: The file to check.
  ///   - options: The contents to check for, such as ``CopyOptions/metadata``,
  ///     and how to find the file, such as ``CopyOptions/noFollowSource``.
  /// - Returns: The contents in `options` that the file has
  ///   and that a copy would copy:
  ///   ``CopyOptions/accessControlList`` and
  ///   ``CopyOptions/extendedAttributes``.
  ///
  /// A file's POSIX information and data are always there to copy,
  /// so the result doesn't include ``CopyOptions/stat`` or
  /// ``CopyOptions/data``.
  /// The check doesn't report an error for a file it can't read,
  /// including one that doesn't exist:
  /// it returns an empty set, as for a file with nothing more to copy.
  ///
  /// The corresponding C function is `copyfile`,
  /// with the `COPYFILE_CHECK` flag.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func contentsToCopy(
    _ path: UnsafePointer<CChar>, options: CopyOptions
  ) throws(Errno) -> CopyOptions {
    try _contentsToCopy(path, options: options).get()
  }

  @usableFromInline
  internal static func _contentsToCopy(
    _ path: UnsafePointer<CChar>, options: CopyOptions
  ) -> Result<CopyOptions, Errno> {
    // The check only reads the source, so there's no destination.
    let flags = options.rawValue | _COPYFILE_CHECK
    let result = system_copyfile(path, nil, nil, flags)
    guard result >= 0 else { return .failure(.current) }
    return .success(CopyOptions(rawValue: UInt32(result)))
  }
}

// MARK: - fcopyfile

@available(System 199, *)
extension FileDescriptor {
  /// Copies the contents of the file that this descriptor refers to,
  /// or some of them, to the file that another descriptor refers to.
  ///
  /// - Parameters:
  ///   - destination: A file descriptor open for writing to the destination.
  ///   - options: Which of the file's contents to copy, and how.
  ///     Options that name a path don't apply.
  ///
  /// The copy reads and writes from each descriptor's current offset,
  /// and leaves the offsets wherever the copy ends,
  /// so the destination can end up a different size than the source.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `fcopyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(
    to destination: FileDescriptor, options: FilePath.CopyOptions
  ) throws(Errno) {
    try _copy(to: destination, options: options, state: nil, progress: nil).get()
  }

  /// Copies the contents of the file that this descriptor refers to,
  /// or some of them, to the file that another descriptor refers to,
  /// with a copy state that holds the copy's settings and results.
  ///
  /// - Parameters:
  ///   - destination: A file descriptor open for writing to the destination.
  ///   - options: Which of the file's contents to copy, and how.
  ///     Options that name a path don't apply.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///
  /// The copy reads and writes from each descriptor's current offset,
  /// and leaves the offsets wherever the copy ends,
  /// so the destination can end up a different size than the source.
  /// It throws an error for a setting that the system doesn't support,
  /// without copying anything.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `fcopyfile`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(
    to destination: FileDescriptor,
    options: FilePath.CopyOptions,
    state: inout FilePath.CopyState
  ) throws(Errno) {
    try withUnsafeMutablePointer(to: &state) { state in
      _copy(to: destination, options: options, state: state, progress: nil)
    }.get()
  }

  /// Copies the contents of the file that this descriptor refers to,
  /// or some of them, to the file that another descriptor refers to,
  /// with a copy state that holds the copy's settings and results,
  /// and reports the copy's progress.
  ///
  /// - Parameters:
  ///   - destination: A file descriptor open for writing to the destination.
  ///   - options: Which of the file's contents to copy, and how.
  ///     Options that name a path don't apply.
  ///   - state: The copy's settings, which the copy applies,
  ///     and its results, which the copy updates.
  ///   - progress: A closure that the copy calls as it writes
  ///     data and extended attributes,
  ///     and that returns whether to continue.
  ///
  /// The copy reads and writes from each descriptor's current offset,
  /// and leaves the offsets wherever the copy ends,
  /// so the destination can end up a different size than the source.
  /// To stop the copy, return ``FilePath/CopyProgress/Action/quit``
  /// from `progress`;
  /// the copy then throws ``Errno/canceled``.
  /// The progress that the copy reports has no paths.
  ///
  /// This method doesn't retry if it's interrupted,
  /// because the interrupted copy may have written part of the destination;
  /// it throws ``Errno/interrupted`` instead.
  ///
  /// The corresponding C function is `fcopyfile`,
  /// with the `COPYFILE_STATE_STATUS_CB` state.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func copy(
    to destination: FileDescriptor,
    options: FilePath.CopyOptions,
    state: inout FilePath.CopyState,
    progress: (FilePath.CopyProgress) -> FilePath.CopyProgress.Action
  ) throws(Errno) {
    try withoutActuallyEscaping(progress) { progress in
      withUnsafeMutablePointer(to: &state) { state in
        _copy(to: destination, options: options, state: state, progress: progress)
      }
    }.get()
  }

  @usableFromInline
  internal func _copy(
    to destination: FileDescriptor,
    options: FilePath.CopyOptions,
    state: UnsafeMutablePointer<FilePath.CopyState>?,
    progress: ((FilePath.CopyProgress) -> FilePath.CopyProgress.Action)?
  ) -> Result<(), Errno> {
    _withCopyState(state, progress: progress) { cState in
      system_fcopyfile(self.rawValue, destination.rawValue, cState, options.rawValue)
    }.map { _ in () }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
