/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// What a volume supports: ATTR_VOL_CAPABILITIES's vol_capabilities_attr_t.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@available(System 199, *)
extension FilePath {
  /// What a volume's format and its file system's implementation support,
  /// such as case-sensitive names or cloning.
  ///
  /// A volume reports only some capabilities:
  /// ``validFormat`` and ``validInterfaces`` say which,
  /// and a capability outside them is unknown rather than unsupported.
  ///
  ///     let volume = try path.attributes([.volumeCapabilities])
  ///     if volume.volumeCapabilities?.interfaces.contains(.clone) == true { ... }
  ///
  /// The corresponding C type is `vol_capabilities_attr_t`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct VolumeCapabilities: Hashable, Sendable {
    /// The format's capabilities that the volume has.
    public var format: Format

    /// The implementation's capabilities that the volume has.
    public var interfaces: Interfaces

    /// The format's capabilities that the volume reports on.
    public var validFormat: Format

    /// The implementation's capabilities that the volume reports on.
    public var validInterfaces: Interfaces

    /// Creates capabilities.
    @_alwaysEmitIntoClient
    public init(
      format: Format, interfaces: Interfaces, validFormat: Format, validInterfaces: Interfaces
    ) {
      self.format = format
      self.interfaces = interfaces
      self.validFormat = validFormat
      self.validInterfaces = validInterfaces
    }

    /// Creates capabilities from the raw C structure.
    @_alwaysEmitIntoClient
    public init(_ capabilities: vol_capabilities_attr_t) {
      self.init(
        format: Format(rawValue: capabilities.capabilities.0),
        interfaces: Interfaces(rawValue: capabilities.capabilities.1),
        validFormat: Format(rawValue: capabilities.valid.0),
        validInterfaces: Interfaces(rawValue: capabilities.valid.1))
    }
  }
}

@available(System 199, *)
extension FilePath.VolumeCapabilities {
  /// Capabilities of a volume's format.
  ///
  /// Its bits are the `VOL_CAP_FMT_*` constants.
  ///
  /// The corresponding C field is `vol_capabilities_attr_t.capabilities`,
  /// at `VOL_CAPABILITIES_FORMAT`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Format: OptionSet, Sendable, Hashable {
    /// The raw C capabilities.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates strongly-typed capabilities from raw C capabilities.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The volume has object identifiers that persist across mounts.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_PERSISTENTOBJECTIDS`.
    @_alwaysEmitIntoClient
    public static var persistentObjectIDs: Format { Format(rawValue: _VOL_CAP_FMT_PERSISTENTOBJECTIDS) }

    /// The volume supports symbolic links.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_SYMBOLICLINKS`.
    @_alwaysEmitIntoClient
    public static var symbolicLinks: Format { Format(rawValue: _VOL_CAP_FMT_SYMBOLICLINKS) }

    /// The volume supports hard links.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_HARDLINKS`.
    @_alwaysEmitIntoClient
    public static var hardLinks: Format { Format(rawValue: _VOL_CAP_FMT_HARDLINKS) }

    /// The volume can be journaled.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_JOURNAL`.
    @_alwaysEmitIntoClient
    public static var journal: Format { Format(rawValue: _VOL_CAP_FMT_JOURNAL) }

    /// The volume is journaled.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_JOURNAL_ACTIVE`.
    @_alwaysEmitIntoClient
    public static var journalActive: Format { Format(rawValue: _VOL_CAP_FMT_JOURNAL_ACTIVE) }

    /// The volume doesn't store times for its root directory.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_NO_ROOT_TIMES`.
    @_alwaysEmitIntoClient
    public static var noRootTimes: Format { Format(rawValue: _VOL_CAP_FMT_NO_ROOT_TIMES) }

    /// The volume supports files with holes.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_SPARSE_FILES`.
    @_alwaysEmitIntoClient
    public static var sparseFiles: Format { Format(rawValue: _VOL_CAP_FMT_SPARSE_FILES) }

    /// The volume reads unwritten parts of files as zeros without storing them.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_ZERO_RUNS`.
    @_alwaysEmitIntoClient
    public static var zeroRuns: Format { Format(rawValue: _VOL_CAP_FMT_ZERO_RUNS) }

    /// The volume's names are case-sensitive.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_CASE_SENSITIVE`.
    @_alwaysEmitIntoClient
    public static var caseSensitive: Format { Format(rawValue: _VOL_CAP_FMT_CASE_SENSITIVE) }

    /// The volume preserves the case of names.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_CASE_PRESERVING`.
    @_alwaysEmitIntoClient
    public static var casePreserving: Format { Format(rawValue: _VOL_CAP_FMT_CASE_PRESERVING) }

    /// The volume's `statfs` is fast enough to call often.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_FAST_STATFS`.
    @_alwaysEmitIntoClient
    public static var fastStatfs: Format { Format(rawValue: _VOL_CAP_FMT_FAST_STATFS) }

    /// The volume supports files of 2 TiB or more.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_2TB_FILESIZE`.
    @_alwaysEmitIntoClient
    public static var largeFiles: Format { Format(rawValue: _VOL_CAP_FMT_2TB_FILESIZE) }

    /// The volume supports opening a file while denying others read or write access.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_OPENDENYMODES`.
    @_alwaysEmitIntoClient
    public static var openDenyModes: Format { Format(rawValue: _VOL_CAP_FMT_OPENDENYMODES) }

    /// The volume supports the `UF_HIDDEN` flag.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_HIDDEN_FILES`.
    @_alwaysEmitIntoClient
    public static var hiddenFiles: Format { Format(rawValue: _VOL_CAP_FMT_HIDDEN_FILES) }

    /// The volume can find an object's path from its file identifier.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_PATH_FROM_ID`.
    @_alwaysEmitIntoClient
    public static var pathFromID: Format { Format(rawValue: _VOL_CAP_FMT_PATH_FROM_ID) }

    /// The volume doesn't report its size or free space.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_NO_VOLUME_SIZES`.
    @_alwaysEmitIntoClient
    public static var noVolumeSizes: Format { Format(rawValue: _VOL_CAP_FMT_NO_VOLUME_SIZES) }

    /// The volume supports transparent compression.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_DECMPFS_COMPRESSION`.
    @_alwaysEmitIntoClient
    public static var decmpfsCompression: Format { Format(rawValue: _VOL_CAP_FMT_DECMPFS_COMPRESSION) }

    /// The volume's object identifiers are 64 bits.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_64BIT_OBJECT_IDS`.
    @_alwaysEmitIntoClient
    public static var objectIDs64Bit: Format { Format(rawValue: _VOL_CAP_FMT_64BIT_OBJECT_IDS) }

    /// The volume supports hard links to directories.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_DIR_HARDLINKS`.
    @_alwaysEmitIntoClient
    public static var directoryHardLinks: Format { Format(rawValue: _VOL_CAP_FMT_DIR_HARDLINKS) }

    /// The volume supports document identifiers.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_DOCUMENT_ID`.
    @_alwaysEmitIntoClient
    public static var documentID: Format { Format(rawValue: _VOL_CAP_FMT_DOCUMENT_ID) }

    /// The volume counts each file's writes.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_WRITE_GENERATION_COUNT`.
    @_alwaysEmitIntoClient
    public static var writeGenerationCount: Format { Format(rawValue: _VOL_CAP_FMT_WRITE_GENERATION_COUNT) }

    /// The volume doesn't support the immutable flags.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_NO_IMMUTABLE_FILES`.
    @_alwaysEmitIntoClient
    public static var noImmutableFiles: Format { Format(rawValue: _VOL_CAP_FMT_NO_IMMUTABLE_FILES) }

    /// The volume doesn't support setting permissions.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_NO_PERMISSIONS`.
    @_alwaysEmitIntoClient
    public static var noPermissions: Format { Format(rawValue: _VOL_CAP_FMT_NO_PERMISSIONS) }

    /// The volume shares its space with other volumes.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_SHARED_SPACE`.
    @_alwaysEmitIntoClient
    public static var sharedSpace: Format { Format(rawValue: _VOL_CAP_FMT_SHARED_SPACE) }

    /// The volume is part of a volume group.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_VOL_GROUPS`.
    @_alwaysEmitIntoClient
    public static var volumeGroups: Format { Format(rawValue: _VOL_CAP_FMT_VOL_GROUPS) }

    /// The volume is sealed, so its contents can't change.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_SEALED`.
    @_alwaysEmitIntoClient
    public static var sealed: Format { Format(rawValue: _VOL_CAP_FMT_SEALED) }

    /// The volume can map the clones of files.
    ///
    /// The corresponding C constant is `VOL_CAP_FMT_CLONE_MAPPING`.
    @_alwaysEmitIntoClient
    public static var cloneMapping: Format { Format(rawValue: _VOL_CAP_FMT_CLONE_MAPPING) }
  }

  /// Capabilities of a volume's file system implementation.
  ///
  /// Its bits are the `VOL_CAP_INT_*` constants.
  ///
  /// The corresponding C field is `vol_capabilities_attr_t.capabilities`,
  /// at `VOL_CAPABILITIES_INTERFACES`.
  /// - Note: Only available on Darwin.
  @frozen
  public struct Interfaces: OptionSet, Sendable, Hashable {
    /// The raw C capabilities.
    @_alwaysEmitIntoClient
    public let rawValue: UInt32

    /// Creates strongly-typed capabilities from raw C capabilities.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The volume supports `searchfs`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_SEARCHFS`.
    @_alwaysEmitIntoClient
    public static var searchfs: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_SEARCHFS) }

    /// The volume supports `getattrlist` and `setattrlist`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_ATTRLIST`.
    @_alwaysEmitIntoClient
    public static var attributeLists: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_ATTRLIST) }

    /// The volume can be exported over NFS.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_NFSEXPORT`.
    @_alwaysEmitIntoClient
    public static var nfsExport: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_NFSEXPORT) }

    /// The volume supports `getdirentriesattr`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_READDIRATTR`.
    @_alwaysEmitIntoClient
    public static var readDirectoryAttributes: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_READDIRATTR) }

    /// The volume supports `exchangedata`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_EXCHANGEDATA`.
    @_alwaysEmitIntoClient
    public static var exchangeData: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_EXCHANGEDATA) }

    /// The volume supports the `copyfile` system call.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_COPYFILE`.
    @_alwaysEmitIntoClient
    public static var copyFile: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_COPYFILE) }

    /// The volume supports `F_PREALLOCATE`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_ALLOCATE`.
    @_alwaysEmitIntoClient
    public static var allocate: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_ALLOCATE) }

    /// The volume can be renamed by setting its `ATTR_VOL_NAME`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_VOL_RENAME`.
    @_alwaysEmitIntoClient
    public static var volumeRename: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_VOL_RENAME) }

    /// The volume supports advisory locks, as `fcntl` sets.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_ADVLOCK`.
    @_alwaysEmitIntoClient
    public static var advisoryLocks: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_ADVLOCK) }

    /// The volume supports whole-file locks, as `flock` sets.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_FLOCK`.
    @_alwaysEmitIntoClient
    public static var fileLocks: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_FLOCK) }

    /// The volume supports access control lists.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_EXTENDED_SECURITY`.
    @_alwaysEmitIntoClient
    public static var extendedSecurity: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_EXTENDED_SECURITY) }

    /// The volume supports `ATTR_CMN_USERACCESS`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_USERACCESS`.
    @_alwaysEmitIntoClient
    public static var userAccess: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_USERACCESS) }

    /// The volume supports mandatory locks.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_MANLOCK`.
    @_alwaysEmitIntoClient
    public static var mandatoryLocks: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_MANLOCK) }

    /// The volume supports named streams.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_NAMEDSTREAMS`.
    @_alwaysEmitIntoClient
    public static var namedStreams: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_NAMEDSTREAMS) }

    /// The volume supports extended attributes.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_EXTENDED_ATTR`.
    @_alwaysEmitIntoClient
    public static var extendedAttributes: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_EXTENDED_ATTR) }

    /// The volume supports `clonefile`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_CLONE`.
    @_alwaysEmitIntoClient
    public static var clone: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_CLONE) }

    /// The volume supports snapshots.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_SNAPSHOT`.
    @_alwaysEmitIntoClient
    public static var snapshot: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_SNAPSHOT) }

    /// The volume supports renaming with `RENAME_SWAP`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_RENAME_SWAP`.
    @_alwaysEmitIntoClient
    public static var renameSwap: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_RENAME_SWAP) }

    /// The volume supports renaming with `RENAME_EXCL`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_RENAME_EXCL`.
    @_alwaysEmitIntoClient
    public static var renameExclusive: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_RENAME_EXCL) }

    /// The volume can fail a rename of an open file.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_RENAME_OPENFAIL`.
    @_alwaysEmitIntoClient
    public static var renameOpenFail: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_RENAME_OPENFAIL) }

    /// The volume supports renaming with `RENAME_SECLUDE`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_RENAME_SECLUDE`.
    @_alwaysEmitIntoClient
    public static var renameSeclude: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_RENAME_SECLUDE) }

    /// The volume supports attribution tags.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_ATTRIBUTION_TAG`.
    @_alwaysEmitIntoClient
    public static var attributionTag: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_ATTRIBUTION_TAG) }

    /// The volume supports `F_PUNCHHOLE`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_PUNCHHOLE`.
    @_alwaysEmitIntoClient
    public static var punchHole: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_PUNCHHOLE) }

    #if canImport(Darwin, _version: 346)
    /// The volume supports `F_BARRIERFSYNC`.
    ///
    /// The corresponding C constant is `VOL_CAP_INT_BARRIERFSYNC`.
    /// - Note: Only available when building with the macOS 26 SDK or later.
    @_alwaysEmitIntoClient
    public static var barrierFsync: Interfaces { Interfaces(rawValue: _VOL_CAP_INT_BARRIERFSYNC) }
    #endif
  }
}

@available(System 199, *)
extension FilePath.VolumeCapabilities.Format: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the capabilities.
  @inline(never)
  public var description: String {
    let descriptions: [(Element, StaticString)] = [
      (.persistentObjectIDs, ".persistentObjectIDs"),
      (.symbolicLinks, ".symbolicLinks"),
      (.hardLinks, ".hardLinks"),
      (.journal, ".journal"),
      (.journalActive, ".journalActive"),
      (.noRootTimes, ".noRootTimes"),
      (.sparseFiles, ".sparseFiles"),
      (.zeroRuns, ".zeroRuns"),
      (.caseSensitive, ".caseSensitive"),
      (.casePreserving, ".casePreserving"),
      (.fastStatfs, ".fastStatfs"),
      (.largeFiles, ".largeFiles"),
      (.openDenyModes, ".openDenyModes"),
      (.hiddenFiles, ".hiddenFiles"),
      (.pathFromID, ".pathFromID"),
      (.noVolumeSizes, ".noVolumeSizes"),
      (.decmpfsCompression, ".decmpfsCompression"),
      (.objectIDs64Bit, ".objectIDs64Bit"),
      (.directoryHardLinks, ".directoryHardLinks"),
      (.documentID, ".documentID"),
      (.writeGenerationCount, ".writeGenerationCount"),
      (.noImmutableFiles, ".noImmutableFiles"),
      (.noPermissions, ".noPermissions"),
      (.sharedSpace, ".sharedSpace"),
      (.volumeGroups, ".volumeGroups"),
      (.sealed, ".sealed"),
      (.cloneMapping, ".cloneMapping"),
    ]
    return _buildDescription(descriptions)
  }

  /// A textual representation of the capabilities, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension FilePath.VolumeCapabilities.Interfaces: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the capabilities.
  @inline(never)
  public var description: String {
    let descriptions: [(Element, StaticString)] = [
      (.searchfs, ".searchfs"),
      (.attributeLists, ".attributeLists"),
      (.nfsExport, ".nfsExport"),
      (.readDirectoryAttributes, ".readDirectoryAttributes"),
      (.exchangeData, ".exchangeData"),
      (.copyFile, ".copyFile"),
      (.allocate, ".allocate"),
      (.volumeRename, ".volumeRename"),
      (.advisoryLocks, ".advisoryLocks"),
      (.fileLocks, ".fileLocks"),
      (.extendedSecurity, ".extendedSecurity"),
      (.userAccess, ".userAccess"),
      (.mandatoryLocks, ".mandatoryLocks"),
      (.namedStreams, ".namedStreams"),
      (.extendedAttributes, ".extendedAttributes"),
      (.clone, ".clone"),
      (.snapshot, ".snapshot"),
      (.renameSwap, ".renameSwap"),
      (.renameExclusive, ".renameExclusive"),
      (.renameOpenFail, ".renameOpenFail"),
      (.renameSeclude, ".renameSeclude"),
      (.attributionTag, ".attributionTag"),
      (.punchHole, ".punchHole"),
    ]
    #if canImport(Darwin, _version: 346)
    let all = descriptions + [(.barrierFsync, ".barrierFsync")]
    #else
    let all = descriptions
    #endif
    return _buildDescription(all)
  }

  /// A textual representation of the capabilities, suitable for debugging.
  public var debugDescription: String { self.description }
}

#endif // SYSTEM_PACKAGE_DARWIN
