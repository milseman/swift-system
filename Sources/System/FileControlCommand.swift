/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension FileDescriptor {
  /// A command for `fcntl` to perform on a file descriptor.
  ///
  /// To perform a command, pass it to one of the `control` methods
  /// of ``FileDescriptor``,
  /// along with the argument, if any, that the command takes.
  /// What a command's argument and result mean depends on the command;
  /// for more information, see the `fcntl(2)` man page.
  ///
  /// Most code doesn't need this type.
  /// The common commands have methods of their own,
  /// such as ``FileDescriptor/descriptorFlags()``
  /// for ``getDescriptorFlags``.
  @frozen
  public struct Command: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C command.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed command from a raw C command.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.Command {
  /// Duplicates the file descriptor as the lowest-numbered available descriptor
  /// that's greater than or equal to the argument.
  ///
  /// The ``FileDescriptor/duplicate(atLeast:closeOnExec:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_DUPFD`.
  @_alwaysEmitIntoClient
  public static var duplicate: Self { Self(rawValue: _F_DUPFD) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "duplicate")
  public static var F_DUPFD: Self { duplicate }

  /// Duplicates the file descriptor like ``duplicate``,
  /// and sets the ``FileDescriptor/DescriptorFlags/closeOnExec`` flag on the copy.
  ///
  /// The ``FileDescriptor/duplicate(atLeast:closeOnExec:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_DUPFD_CLOEXEC`.
  @_alwaysEmitIntoClient
  public static var duplicateCloseOnExec: Self { Self(rawValue: _F_DUPFD_CLOEXEC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "duplicateCloseOnExec")
  public static var F_DUPFD_CLOEXEC: Self { duplicateCloseOnExec }

  /// Returns the file descriptor's flags.
  ///
  /// The ``FileDescriptor/descriptorFlags()`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETFD`.
  @_alwaysEmitIntoClient
  public static var getDescriptorFlags: Self { Self(rawValue: _F_GETFD) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getDescriptorFlags")
  public static var F_GETFD: Self { getDescriptorFlags }

  /// Replaces the file descriptor's flags with the argument.
  ///
  /// The ``FileDescriptor/setDescriptorFlags(_:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_SETFD`.
  @_alwaysEmitIntoClient
  public static var setDescriptorFlags: Self { Self(rawValue: _F_SETFD) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setDescriptorFlags")
  public static var F_SETFD: Self { setDescriptorFlags }

  /// Returns the open file's status flags and access mode.
  ///
  /// The ``FileDescriptor/statusFlags()`` and ``FileDescriptor/accessMode()`` methods
  /// perform this command.
  ///
  /// The corresponding C constant is `F_GETFL`.
  @_alwaysEmitIntoClient
  public static var getStatusFlags: Self { Self(rawValue: _F_GETFL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getStatusFlags")
  public static var F_GETFL: Self { getStatusFlags }

  /// Replaces the open file's status flags with the argument.
  ///
  /// The ``FileDescriptor/setStatusFlags(_:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_SETFL`.
  @_alwaysEmitIntoClient
  public static var setStatusFlags: Self { Self(rawValue: _F_SETFL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setStatusFlags")
  public static var F_SETFL: Self { setStatusFlags }

  /// Returns the process, or the negated process group,
  /// that receives the open file's `SIGIO` and `SIGURG` signals.
  ///
  /// The ``FileDescriptor/signalOwner()`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETOWN`.
  @_alwaysEmitIntoClient
  public static var getSignalOwner: Self { Self(rawValue: _F_GETOWN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getSignalOwner")
  public static var F_GETOWN: Self { getSignalOwner }

  /// Sets the process, or the negated process group,
  /// that receives the open file's `SIGIO` and `SIGURG` signals.
  ///
  /// The ``FileDescriptor/setSignalOwner(_:isGroup:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_SETOWN`.
  @_alwaysEmitIntoClient
  public static var setSignalOwner: Self { Self(rawValue: _F_SETOWN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setSignalOwner")
  public static var F_SETOWN: Self { setSignalOwner }

  /// Replaces the ``FileDescriptor/FileLock`` argument with a description
  /// of a process-owned record lock that would block it,
  /// or sets its kind to ``FileDescriptor/FileLock/Kind/none`` if there's none.
  ///
  /// The corresponding C constant is `F_GETLK`.
  @_alwaysEmitIntoClient
  public static var getLock: Self { Self(rawValue: _F_GETLK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getLock")
  public static var F_GETLK: Self { getLock }

  /// Places or removes the process-owned record lock that
  /// the ``FileDescriptor/FileLock`` argument describes, without waiting.
  ///
  /// A process-owned lock is released when the process closes *any* descriptor
  /// for the file, including one it didn't lock through.
  /// Prefer the open file description locks of ``setOFDLock``, where available.
  ///
  /// The corresponding C constant is `F_SETLK`.
  @_alwaysEmitIntoClient
  public static var setLock: Self { Self(rawValue: _F_SETLK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setLock")
  public static var F_SETLK: Self { setLock }

  /// Places or removes the process-owned record lock that
  /// the ``FileDescriptor/FileLock`` argument describes,
  /// waiting for other locks to get out of the way.
  ///
  /// For more about these locks, see ``setLock``.
  ///
  /// The corresponding C constant is `F_SETLKW`.
  @_alwaysEmitIntoClient
  public static var setLockWait: Self { Self(rawValue: _F_SETLKW) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setLockWait")
  public static var F_SETLKW: Self { setLockWait }
}

// FreeBSD and OpenBSD have no open file description locks.
#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
@available(System 199, *)
extension FileDescriptor.Command {
  /// Replaces the ``FileDescriptor/FileLock`` argument with a description
  /// of a lock that would block it as an open file description lock,
  /// or sets its kind to ``FileDescriptor/FileLock/Kind/none`` if there's none.
  ///
  /// The corresponding C constant is `F_OFD_GETLK`.
  @_alwaysEmitIntoClient
  public static var getOFDLock: Self { Self(rawValue: _F_OFD_GETLK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getOFDLock")
  public static var F_OFD_GETLK: Self { getOFDLock }

  /// Places or removes the open file description lock that
  /// the ``FileDescriptor/FileLock`` argument describes, without waiting.
  ///
  /// The ``FileDescriptor/lock(_:byteRange:retryOnInterrupt:)`` and
  /// ``FileDescriptor/unlock(byteRange:retryOnInterrupt:)`` methods perform this command.
  ///
  /// The corresponding C constant is `F_OFD_SETLK`.
  @_alwaysEmitIntoClient
  public static var setOFDLock: Self { Self(rawValue: _F_OFD_SETLK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setOFDLock")
  public static var F_OFD_SETLK: Self { setOFDLock }

  /// Places or removes the open file description lock that
  /// the ``FileDescriptor/FileLock`` argument describes,
  /// waiting for other locks to get out of the way.
  ///
  /// The ``FileDescriptor/lock(_:byteRange:wait:retryOnInterrupt:)`` method
  /// performs this command.
  ///
  /// The corresponding C constant is `F_OFD_SETLKW`.
  @_alwaysEmitIntoClient
  public static var setOFDLockWait: Self { Self(rawValue: _F_OFD_SETLKW) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setOFDLockWait")
  public static var F_OFD_SETLKW: Self { setOFDLockWait }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension FileDescriptor.Command {
  /// Places or removes a process-owned record lock like ``setLockWait``,
  /// giving up after a timeout.
  ///
  /// The argument is a C `flocktimeout` structure.
  /// A zero timeout waits forever.
  ///
  /// The corresponding C constant is `F_SETLKWTIMEOUT`.
  @_alwaysEmitIntoClient
  public static var setLockWaitTimeout: Self { Self(rawValue: _F_SETLKWTIMEOUT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setLockWaitTimeout")
  public static var F_SETLKWTIMEOUT: Self { setLockWaitTimeout }

  /// Places or removes an open file description lock like ``setOFDLockWait``,
  /// giving up after a timeout.
  ///
  /// The argument is a C `flocktimeout` structure.
  /// A zero timeout waits forever.
  /// The ``FileDescriptor/lock(_:byteRange:timeout:retryOnInterrupt:)`` method
  /// performs this command, without that hazard.
  ///
  /// The corresponding C constant is `F_OFD_SETLKWTIMEOUT`.
  @_alwaysEmitIntoClient
  public static var setOFDLockWaitTimeout: Self { Self(rawValue: _F_OFD_SETLKWTIMEOUT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setOFDLockWaitTimeout")
  public static var F_OFD_SETLKWTIMEOUT: Self { setOFDLockWaitTimeout }

  /// Pushes the file's modified data from the cache to its storage device.
  ///
  /// The corresponding C constant is `F_FLUSH_DATA`.
  @_alwaysEmitIntoClient
  public static var flushData: Self { Self(rawValue: _F_FLUSH_DATA) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "flushData")
  public static var F_FLUSH_DATA: Self { flushData }

  /// Checks whether the file has modified data in the cache.
  /// It's used for regression testing.
  ///
  /// The corresponding C constant is `F_CHKCLEAN`.
  @_alwaysEmitIntoClient
  public static var checkClean: Self { Self(rawValue: _F_CHKCLEAN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "checkClean")
  public static var F_CHKCLEAN: Self { checkClean }

  /// Preallocates storage for the file, as the
  /// ``FileDescriptor/ControlTypes/Store`` argument describes.
  ///
  /// The corresponding C constant is `F_PREALLOCATE`.
  @_alwaysEmitIntoClient
  public static var preallocate: Self { Self(rawValue: _F_PREALLOCATE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "preallocate")
  public static var F_PREALLOCATE: Self { preallocate }

  /// Truncates or extends the file to the size that the argument points to,
  /// an `off_t`, without zeroing new space, which requires superuser privileges.
  ///
  /// The corresponding C constant is `F_SETSIZE`.
  @_alwaysEmitIntoClient
  public static var setSize: Self { Self(rawValue: _F_SETSIZE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setSize")
  public static var F_SETSIZE: Self { setSize }

  /// Starts reading the range of the file that the
  /// ``FileDescriptor/ControlTypes/ReadAdvisory`` argument describes
  /// into the cache, without waiting.
  ///
  /// The corresponding C constant is `F_RDADVISE`.
  @_alwaysEmitIntoClient
  public static var readAdvise: Self { Self(rawValue: _F_RDADVISE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "readAdvise")
  public static var F_RDADVISE: Self { readAdvise }

  /// Turns reading ahead off, for an argument of `0`, or on.
  ///
  /// The corresponding C constant is `F_RDAHEAD`.
  @_alwaysEmitIntoClient
  public static var readAhead: Self { Self(rawValue: _F_RDAHEAD) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "readAhead")
  public static var F_RDAHEAD: Self { readAhead }

  /// Turns data caching off, for a nonzero argument, or on, for `0`.
  ///
  /// The ``FileDescriptor/setNoCache(_:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_NOCACHE`.
  @_alwaysEmitIntoClient
  public static var noCache: Self { Self(rawValue: _F_NOCACHE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "noCache")
  public static var F_NOCACHE: Self { noCache }

  /// Replaces the ``FileDescriptor/ControlTypes/LogicalToPhysical`` argument
  /// with the location on the device of the file's current offset.
  ///
  /// The corresponding C constant is `F_LOG2PHYS`.
  @_alwaysEmitIntoClient
  public static var logicalToPhysical: Self { Self(rawValue: _F_LOG2PHYS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "logicalToPhysical")
  public static var F_LOG2PHYS: Self { logicalToPhysical }

  /// Copies the file's path into the argument,
  /// a buffer of at least `MAXPATHLEN` bytes.
  ///
  /// The ``FileDescriptor/path(resolvingFirmlinks:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETPATH`.
  @_alwaysEmitIntoClient
  public static var getPath: Self { Self(rawValue: _F_GETPATH) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getPath")
  public static var F_GETPATH: Self { getPath }

  /// Flushes the file to its storage device,
  /// and asks the device to write its cache to permanent storage.
  ///
  /// The ``FileDescriptor/synchronizeFully(retryOnInterrupt:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_FULLFSYNC`.
  @_alwaysEmitIntoClient
  public static var synchronizeFully: Self { Self(rawValue: _F_FULLFSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "synchronizeFully")
  public static var F_FULLFSYNC: Self { synchronizeFully }

  /// Finds which component of the path in the argument, if any, is a package.
  ///
  /// The corresponding C constant is `F_PATHPKG_CHECK`.
  @_alwaysEmitIntoClient
  public static var pathPackageCheck: Self { Self(rawValue: _F_PATHPKG_CHECK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "pathPackageCheck")
  public static var F_PATHPKG_CHECK: Self { pathPackageCheck }

  /// Suspends all operations on the file's file system,
  /// which requires superuser privileges.
  ///
  /// The corresponding C constant is `F_FREEZE_FS`.
  @_alwaysEmitIntoClient
  public static var freezeFileSystem: Self { Self(rawValue: _F_FREEZE_FS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "freezeFileSystem")
  public static var F_FREEZE_FS: Self { freezeFileSystem }

  /// Resumes the operations that ``freezeFileSystem`` suspended.
  ///
  /// The corresponding C constant is `F_THAW_FS`.
  @_alwaysEmitIntoClient
  public static var thawFileSystem: Self { Self(rawValue: _F_THAW_FS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "thawFileSystem")
  public static var F_THAW_FS: Self { thawFileSystem }

  /// Turns data caching off for every open of the file,
  /// for a nonzero argument, or on, for `0`.
  ///
  /// The corresponding C constant is `F_GLOBAL_NOCACHE`.
  @_alwaysEmitIntoClient
  public static var globalNoCache: Self { Self(rawValue: _F_GLOBAL_NOCACHE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "globalNoCache")
  public static var F_GLOBAL_NOCACHE: Self { globalNoCache }

  /// Adds detached code signatures to the file.
  ///
  /// The corresponding C constant is `F_ADDSIGS`.
  @_alwaysEmitIntoClient
  public static var addSignatures: Self { Self(rawValue: _F_ADDSIGS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addSignatures")
  public static var F_ADDSIGS: Self { addSignatures }

  /// Adds the code signature from the file itself.
  ///
  /// The corresponding C constant is `F_ADDFILESIGS`.
  @_alwaysEmitIntoClient
  public static var addFileSignatures: Self { Self(rawValue: _F_ADDFILESIGS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addFileSignatures")
  public static var F_ADDFILESIGS: Self { addFileSignatures }

  /// Allows writes to the file to be cached when ``noCache`` is on,
  /// for a nonzero argument, rather than written directly and synchronously.
  ///
  /// The corresponding C constant is `F_NODIRECT`.
  @_alwaysEmitIntoClient
  public static var noDirect: Self { Self(rawValue: _F_NODIRECT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "noDirect")
  public static var F_NODIRECT: Self { noDirect }

  /// Returns the file's data protection class.
  ///
  /// The corresponding C constant is `F_GETPROTECTIONCLASS`.
  @_alwaysEmitIntoClient
  public static var getProtectionClass: Self { Self(rawValue: _F_GETPROTECTIONCLASS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getProtectionClass")
  public static var F_GETPROTECTIONCLASS: Self { getProtectionClass }

  /// Sets the file's data protection class to the argument.
  ///
  /// The corresponding C constant is `F_SETPROTECTIONCLASS`.
  @_alwaysEmitIntoClient
  public static var setProtectionClass: Self { Self(rawValue: _F_SETPROTECTIONCLASS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setProtectionClass")
  public static var F_SETPROTECTIONCLASS: Self { setProtectionClass }

  /// Replaces the ``FileDescriptor/ControlTypes/LogicalToPhysical`` argument
  /// with the location on the device of the range of the file that it describes.
  ///
  /// The corresponding C constant is `F_LOG2PHYS_EXT`.
  @_alwaysEmitIntoClient
  public static var logicalToPhysicalExtended: Self { Self(rawValue: _F_LOG2PHYS_EXT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "logicalToPhysicalExtended")
  public static var F_LOG2PHYS_EXT: Self { logicalToPhysicalExtended }

  /// Finds a lock that would block the ``FileDescriptor/FileLock`` argument,
  /// like ``getLock``, considering only locks held by the process in its ``FileDescriptor/FileLock/processID``,
  /// and whole-file locks.
  ///
  /// The corresponding C constant is `F_GETLKPID`.
  @_alwaysEmitIntoClient
  public static var getLockForProcess: Self { Self(rawValue: _F_GETLKPID) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getLockForProcess")
  public static var F_GETLKPID: Self { getLockForProcess }

  /// Marks the file as the backing store for another file system.
  ///
  /// The corresponding C constant is `F_SETBACKINGSTORE`.
  @_alwaysEmitIntoClient
  public static var setBackingStore: Self { Self(rawValue: _F_SETBACKINGSTORE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setBackingStore")
  public static var F_SETBACKINGSTORE: Self { setBackingStore }

  /// Copies the file's path into the argument, like ``getPath``,
  /// failing in some cases specific to the media.
  ///
  /// The corresponding C constant is `F_GETPATH_MTMINFO`.
  @_alwaysEmitIntoClient
  public static var getPathMTMInfo: Self { Self(rawValue: _F_GETPATH_MTMINFO) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getPathMTMInfo")
  public static var F_GETPATH_MTMINFO: Self { getPathMTMInfo }

  /// Copies the file's code directory, with its hashes, into the argument.
  ///
  /// The corresponding C constant is `F_GETCODEDIR`.
  @_alwaysEmitIntoClient
  public static var getCodeDirectory: Self { Self(rawValue: _F_GETCODEDIR) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getCodeDirectory")
  public static var F_GETCODEDIR: Self { getCodeDirectory }

  /// Turns off `SIGPIPE` for writes to a pipe or socket without a reader,
  /// for a nonzero argument, or back on, for `0`.
  ///
  /// The ``FileDescriptor/setNoSigPipe(_:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_SETNOSIGPIPE`.
  @_alwaysEmitIntoClient
  public static var setNoSigPipe: Self { Self(rawValue: _F_SETNOSIGPIPE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setNoSigPipe")
  public static var F_SETNOSIGPIPE: Self { setNoSigPipe }

  /// Returns whether `SIGPIPE` is off for writes to a pipe or socket without a reader.
  ///
  /// The ``FileDescriptor/noSigPipe()`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETNOSIGPIPE`.
  @_alwaysEmitIntoClient
  public static var getNoSigPipe: Self { Self(rawValue: _F_GETNOSIGPIPE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getNoSigPipe")
  public static var F_GETNOSIGPIPE: Self { getNoSigPipe }

  /// Rewraps the file's encryption key.
  ///
  /// The corresponding C constant is `F_TRANSCODEKEY`.
  @_alwaysEmitIntoClient
  public static var transcodeKey: Self { Self(rawValue: _F_TRANSCODEKEY) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "transcodeKey")
  public static var F_TRANSCODEKEY: Self { transcodeKey }

  /// Marks the file as written by a single writer,
  /// which lets throttled writes be broken into smaller ones.
  ///
  /// The corresponding C constant is `F_SINGLE_WRITER`.
  @_alwaysEmitIntoClient
  public static var singleWriter: Self { Self(rawValue: _F_SINGLE_WRITER) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "singleWriter")
  public static var F_SINGLE_WRITER: Self { singleWriter }

  /// Returns the data protection version of the file's file system.
  ///
  /// The corresponding C constant is `F_GETPROTECTIONLEVEL`.
  @_alwaysEmitIntoClient
  public static var getProtectionLevel: Self { Self(rawValue: _F_GETPROTECTIONLEVEL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getProtectionLevel")
  public static var F_GETPROTECTIONLEVEL: Self { getProtectionLevel }

  /// Finds the detached code signatures for the file.
  ///
  /// The corresponding C constant is `F_FINDSIGS`.
  @_alwaysEmitIntoClient
  public static var findSignatures: Self { Self(rawValue: _F_FINDSIGS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "findSignatures")
  public static var F_FINDSIGS: Self { findSignatures }

  /// Adds the code signature from the file itself,
  /// only if Apple signed it. The dynamic linker uses it for the simulator.
  ///
  /// The corresponding C constant is `F_ADDFILESIGS_FOR_DYLD_SIM`.
  @_alwaysEmitIntoClient
  public static var addFileSignaturesForDYLDSimulator: Self { Self(rawValue: _F_ADDFILESIGS_FOR_DYLD_SIM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addFileSignaturesForDYLDSimulator")
  public static var F_ADDFILESIGS_FOR_DYLD_SIM: Self { addFileSignaturesForDYLDSimulator }

  /// Flushes the file to its storage device,
  /// and asks the device to write it to permanent storage before any data written later.
  ///
  /// The ``FileDescriptor/synchronizeWithBarrier(retryOnInterrupt:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_BARRIERFSYNC`.
  @_alwaysEmitIntoClient
  public static var synchronizeWithBarrier: Self { Self(rawValue: _F_BARRIERFSYNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "synchronizeWithBarrier")
  public static var F_BARRIERFSYNC: Self { synchronizeWithBarrier }

  /// Adds the code signature from the file itself,
  /// returning the end offset of the signature in the argument.
  ///
  /// The corresponding C constant is `F_ADDFILESIGS_RETURN`.
  @_alwaysEmitIntoClient
  public static var addFileSignaturesReturn: Self { Self(rawValue: _F_ADDFILESIGS_RETURN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addFileSignaturesReturn")
  public static var F_ADDFILESIGS_RETURN: Self { addFileSignaturesReturn }

  /// Checks whether library validation allows the calling process
  /// to map the file, a Mach-O image.
  ///
  /// The corresponding C constant is `F_CHECK_LV`.
  @_alwaysEmitIntoClient
  public static var checkLibraryValidation: Self { Self(rawValue: _F_CHECK_LV) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "checkLibraryValidation")
  public static var F_CHECK_LV: Self { checkLibraryValidation }

  /// Deallocates the range of the file that the
  /// ``FileDescriptor/ControlTypes/PunchHole`` argument describes,
  /// which then reads as zeros.
  ///
  /// The corresponding C constant is `F_PUNCHHOLE`.
  @_alwaysEmitIntoClient
  public static var punchHole: Self { Self(rawValue: _F_PUNCHHOLE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "punchHole")
  public static var F_PUNCHHOLE: Self { punchHole }

  /// Trims the unused storage of a file that's open.
  ///
  /// The corresponding C constant is `F_TRIM_ACTIVE_FILE`.
  @_alwaysEmitIntoClient
  public static var trimActiveFile: Self { Self(rawValue: _F_TRIM_ACTIVE_FILE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "trimActiveFile")
  public static var F_TRIM_ACTIVE_FILE: Self { trimActiveFile }

  /// Reads a range of a regular or compressed file into the cache.
  ///
  /// The corresponding C constant is `F_SPECULATIVE_READ`.
  @_alwaysEmitIntoClient
  public static var speculativeRead: Self { Self(rawValue: _F_SPECULATIVE_READ) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "speculativeRead")
  public static var F_SPECULATIVE_READ: Self { speculativeRead }

  /// Copies the file's path, resolving firmlinks, into the argument,
  /// a buffer of at least `MAXPATHLEN` bytes.
  ///
  /// The ``FileDescriptor/path(resolvingFirmlinks:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETPATH_NOFIRMLINK`.
  @_alwaysEmitIntoClient
  public static var getPathNoFirmlink: Self { Self(rawValue: _F_GETPATH_NOFIRMLINK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getPathNoFirmlink")
  public static var F_GETPATH_NOFIRMLINK: Self { getPathNoFirmlink }

  /// Adds the code signature from the file itself,
  /// returning information about it in the argument.
  ///
  /// The corresponding C constant is `F_ADDFILESIGS_INFO`.
  @_alwaysEmitIntoClient
  public static var addFileSignaturesInfo: Self { Self(rawValue: _F_ADDFILESIGS_INFO) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addFileSignaturesInfo")
  public static var F_ADDFILESIGS_INFO: Self { addFileSignaturesInfo }

  /// Adds a supplemental code signature from the file itself,
  /// for the file descriptor in the argument.
  ///
  /// The corresponding C constant is `F_ADDFILESUPPL`.
  @_alwaysEmitIntoClient
  public static var addFileSupplementalSignature: Self { Self(rawValue: _F_ADDFILESUPPL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "addFileSupplementalSignature")
  public static var F_ADDFILESUPPL: Self { addFileSupplementalSignature }

  /// Looks up information about the code signature
  /// attached to the file, or to a slice of it.
  ///
  /// The corresponding C constant is `F_GETSIGSINFO`.
  @_alwaysEmitIntoClient
  public static var getSignatureInfo: Self { Self(rawValue: _F_GETSIGSINFO) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getSignatureInfo")
  public static var F_GETSIGSINFO: Self { getSignatureInfo }
}
#endif // SYSTEM_PACKAGE_DARWIN

#if os(Linux) || os(Android)
@available(System 199, *)
extension FileDescriptor.Command {
  /// Returns the capacity of the pipe, in bytes.
  ///
  /// The ``FileDescriptor/pipeCapacity()`` method performs this command.
  ///
  /// The corresponding C constant is `F_GETPIPE_SZ`.
  @_alwaysEmitIntoClient
  public static var getPipeCapacity: Self { Self(rawValue: _F_GETPIPE_SZ) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "getPipeCapacity")
  public static var F_GETPIPE_SZ: Self { getPipeCapacity }

  /// Sets the capacity of the pipe to at least the argument, in bytes,
  /// and returns the capacity it sets.
  ///
  /// The ``FileDescriptor/setPipeCapacity(atLeast:)`` method performs this command.
  ///
  /// The corresponding C constant is `F_SETPIPE_SZ`.
  @_alwaysEmitIntoClient
  public static var setPipeCapacity: Self { Self(rawValue: _F_SETPIPE_SZ) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "setPipeCapacity")
  public static var F_SETPIPE_SZ: Self { setPipeCapacity }
}
#endif // os(Linux) || os(Android)

#endif // !os(Windows) && !os(WASI)
