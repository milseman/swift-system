/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Querying and setting file information: the first two stages that SYS-0010's
// roadmap leaves to future proposals, for the information classes the
// adopters use.

// MARK: - Attributes that queries report

@available(System 199, *)
extension Win32.FileAttributes {
  /// The file is a directory.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_DIRECTORY`.
  @_alwaysEmitIntoClient
  public static var directory: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x10) }

  /// Reserved for the system.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_DEVICE`.
  @_alwaysEmitIntoClient
  public static var device: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x40) }

  /// The file is sparse: ranges of zeros take no storage.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_SPARSE_FILE`.
  @_alwaysEmitIntoClient
  public static var sparseFile: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x200) }

  /// The file is a reparse point, such as a symbolic link or a junction,
  /// whose ``Win32/ReparseTag`` says what a path that reaches it does.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_REPARSE_POINT`.
  @_alwaysEmitIntoClient
  public static var reparsePoint: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x400) }

  /// The file system compresses the file's data, or a directory's new
  /// files.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_COMPRESSED`.
  @_alwaysEmitIntoClient
  public static var compressed: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x800) }

  /// The content indexing service doesn't index the file.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_NOT_CONTENT_INDEXED`.
  @_alwaysEmitIntoClient
  public static var notContentIndexed: Win32.FileAttributes {
    Win32.FileAttributes(rawValue: 0x2000)
  }

  /// The file system checks the file's data for integrity, on ReFS.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_INTEGRITY_STREAM`.
  @_alwaysEmitIntoClient
  public static var integrityStream: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x8000) }

  /// The background integrity scanner doesn't read the file, on ReFS.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_NO_SCRUB_DATA`.
  @_alwaysEmitIntoClient
  public static var noScrubData: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x2_0000) }

  /// The file has no local data until it's opened, as a cloud provider's
  /// placeholder in a directory listing doesn't.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_RECALL_ON_OPEN`.
  @_alwaysEmitIntoClient
  public static var recallOnOpen: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x4_0000) }

  /// The user asked for the file to be kept locally.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_PINNED`.
  @_alwaysEmitIntoClient
  public static var pinned: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x8_0000) }

  /// The user asked for the file not to be kept locally.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_UNPINNED`.
  @_alwaysEmitIntoClient
  public static var unpinned: Win32.FileAttributes { Win32.FileAttributes(rawValue: 0x10_0000) }

  /// The file's data isn't all local: reading it can fetch it from remote
  /// storage, which can be slow.
  ///
  /// The corresponding C constant is `FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS`.
  @_alwaysEmitIntoClient
  public static var recallOnDataAccess: Win32.FileAttributes {
    Win32.FileAttributes(rawValue: 0x40_0000)
  }
}

// MARK: - The general information

@available(System 199, *)
extension Win32 {
  /// A file's attributes, times, size, link count, and index.
  ///
  /// The corresponding C type is `BY_HANDLE_FILE_INFORMATION`.
  @frozen
  public struct FileInformation: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: BY_HANDLE_FILE_INFORMATION

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: BY_HANDLE_FILE_INFORMATION) { self.rawValue = rawValue }

    /// The file's attributes.
    ///
    /// The corresponding C field is `dwFileAttributes`.
    @_alwaysEmitIntoClient
    public var attributes: Win32.FileAttributes {
      Win32.FileAttributes(rawValue: rawValue.dwFileAttributes)
    }

    /// When the file was created.
    ///
    /// The corresponding C field is `ftCreationTime`.
    @_alwaysEmitIntoClient
    public var creationTime: Win32.FileTime { Win32.FileTime(rawValue.ftCreationTime) }

    /// When the file was last read or written, as precisely as the file
    /// system keeps it: NTFS updates it lazily, and can be set not to.
    ///
    /// The corresponding C field is `ftLastAccessTime`.
    @_alwaysEmitIntoClient
    public var lastAccessTime: Win32.FileTime { Win32.FileTime(rawValue.ftLastAccessTime) }

    /// When the file was last written.
    ///
    /// The corresponding C field is `ftLastWriteTime`.
    @_alwaysEmitIntoClient
    public var lastWriteTime: Win32.FileTime { Win32.FileTime(rawValue.ftLastWriteTime) }

    /// The serial number of the volume that holds the file.
    ///
    /// The corresponding C field is `dwVolumeSerialNumber`.
    @_alwaysEmitIntoClient
    public var volumeSerialNumber: DWORD { rawValue.dwVolumeSerialNumber }

    /// The file's size, in bytes.
    ///
    /// The corresponding C fields are `nFileSizeHigh` and `nFileSizeLow`.
    @_alwaysEmitIntoClient
    public var size: Int64 {
      Int64(bitPattern: UInt64(rawValue.nFileSizeHigh) << 32 | UInt64(rawValue.nFileSizeLow))
    }

    /// The number of hard links to the file.
    ///
    /// The corresponding C field is `nNumberOfLinks`.
    @_alwaysEmitIntoClient
    public var linkCount: Int { Int(rawValue.nNumberOfLinks) }

    /// The file's index on its volume, which, with ``volumeSerialNumber``,
    /// identifies the file while it exists.
    ///
    /// A file system with 128-bit file IDs, such as ReFS, may not give
    /// each file a unique 64-bit index; use
    /// ``Win32/FileHandle/fileID()`` for those.
    ///
    /// The corresponding C fields are `nFileIndexHigh` and `nFileIndexLow`.
    @_alwaysEmitIntoClient
    public var fileIndex: UInt64 {
      UInt64(rawValue.nFileIndexHigh) << 32 | UInt64(rawValue.nFileIndexLow)
    }
  }
}

// MARK: - Basic information

@available(System 199, *)
extension Win32 {
  /// A file's four times and its attributes, the information that
  /// ``Win32/FileHandle/setTimes(creation:lastAccess:lastWrite:change:)``
  /// and ``Win32/FileHandle/setAttributes(_:)`` set.
  ///
  /// The corresponding C type is `FILE_BASIC_INFO`.
  @frozen
  public struct FileBasicInformation: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: FILE_BASIC_INFO

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: FILE_BASIC_INFO) { self.rawValue = rawValue }

    /// When the file was created.
    ///
    /// The corresponding C field is `CreationTime`.
    @_alwaysEmitIntoClient
    public var creationTime: Win32.FileTime {
      Win32.FileTime(rawValue: rawValue.CreationTime.QuadPart)
    }

    /// When the file was last read or written.
    ///
    /// The corresponding C field is `LastAccessTime`.
    @_alwaysEmitIntoClient
    public var lastAccessTime: Win32.FileTime {
      Win32.FileTime(rawValue: rawValue.LastAccessTime.QuadPart)
    }

    /// When the file was last written.
    ///
    /// The corresponding C field is `LastWriteTime`.
    @_alwaysEmitIntoClient
    public var lastWriteTime: Win32.FileTime {
      Win32.FileTime(rawValue: rawValue.LastWriteTime.QuadPart)
    }

    /// When the file's data or metadata last changed, as POSIX's `ctime`
    /// records.
    ///
    /// The corresponding C field is `ChangeTime`.
    @_alwaysEmitIntoClient
    public var changeTime: Win32.FileTime {
      Win32.FileTime(rawValue: rawValue.ChangeTime.QuadPart)
    }

    /// The file's attributes.
    ///
    /// The corresponding C field is `FileAttributes`.
    @_alwaysEmitIntoClient
    public var attributes: Win32.FileAttributes {
      Win32.FileAttributes(rawValue: rawValue.FileAttributes)
    }
  }
}

// MARK: - Standard information

@available(System 199, *)
extension Win32 {
  /// A file's sizes, link count, and whether it's a directory or about to
  /// be deleted.
  ///
  /// The corresponding C type is `FILE_STANDARD_INFO`.
  @frozen
  public struct FileStandardInformation: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: FILE_STANDARD_INFO

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: FILE_STANDARD_INFO) { self.rawValue = rawValue }

    /// The storage the file takes, in bytes: its size rounded up to whole
    /// clusters, less any sparse ranges.
    ///
    /// The corresponding C field is `AllocationSize`.
    @_alwaysEmitIntoClient
    public var allocationSize: Int64 { rawValue.AllocationSize.QuadPart }

    /// The file's size, in bytes.
    ///
    /// The corresponding C field is `EndOfFile`.
    @_alwaysEmitIntoClient
    public var size: Int64 { rawValue.EndOfFile.QuadPart }

    /// The number of hard links to the file.
    ///
    /// The corresponding C field is `NumberOfLinks`.
    @_alwaysEmitIntoClient
    public var linkCount: Int { Int(rawValue.NumberOfLinks) }

    /// Whether the file is to be deleted once its last handle closes.
    ///
    /// The corresponding C field is `DeletePending`.
    @_alwaysEmitIntoClient
    public var isDeletePending: Bool { rawValue.DeletePending != 0 }

    /// Whether the file is a directory.
    ///
    /// The corresponding C field is `Directory`.
    @_alwaysEmitIntoClient
    public var isDirectory: Bool { rawValue.Directory != 0 }
  }
}

// MARK: - File IDs

@available(System 199, *)
extension Win32 {
  /// A file's identity: its volume's serial number, and its 128-bit ID on
  /// that volume, which no other file there has while it exists.
  ///
  /// Two handles refer to the same file if their IDs are equal, whatever
  /// paths opened them.
  ///
  /// The corresponding C type is `FILE_ID_INFO`.
  @frozen
  public struct FileID: Sendable, Hashable, Codable {
    /// The serial number of the volume that holds the file.
    ///
    /// The corresponding C field is `VolumeSerialNumber`.
    public var volumeSerialNumber: UInt64

    /// The file's ID on its volume, the 16 bytes of `FileId` read as a
    /// little-endian number.
    ///
    /// The corresponding C field is `FileId`.
    public var identifier: UInt128

    /// Creates a file ID.
    @_alwaysEmitIntoClient
    public init(volumeSerialNumber: UInt64, identifier: UInt128) {
      self.volumeSerialNumber = volumeSerialNumber
      self.identifier = identifier
    }

    /// Creates a file ID from the C structure.
    @_alwaysEmitIntoClient
    public init(_ info: FILE_ID_INFO) {
      var identifier: UInt128 = 0
      withUnsafeBytes(of: info.FileId.Identifier) { bytes in
        for (index, byte) in bytes.enumerated() {
          identifier |= UInt128(byte) << (8 * index)
        }
      }
      self.init(volumeSerialNumber: info.VolumeSerialNumber, identifier: identifier)
    }
  }
}

// MARK: - Reparse tags

@available(System 199, *)
extension Win32 {
  /// The kind of a reparse point: what a path that reaches it does.
  ///
  /// Its values are the `IO_REPARSE_TAG_*` constants.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ReparseTag: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C tag.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed tag from a raw C tag.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// A symbolic link, to a file or a directory.
    ///
    /// The corresponding C constant is `IO_REPARSE_TAG_SYMLINK`.
    @_alwaysEmitIntoClient
    public static var symbolicLink: ReparseTag { ReparseTag(rawValue: 0xA000_000C) }

    /// A directory junction, or a volume mount point.
    ///
    /// The corresponding C constant is `IO_REPARSE_TAG_MOUNT_POINT`.
    @_alwaysEmitIntoClient
    public static var mountPoint: ReparseTag { ReparseTag(rawValue: 0xA000_0003) }

    /// An app execution alias, as the Microsoft Store's apps install in
    /// the user's `WindowsApps` directory.
    ///
    /// The corresponding C constant is `IO_REPARSE_TAG_APPEXECLINK`.
    @_alwaysEmitIntoClient
    public static var appExecutionLink: ReparseTag { ReparseTag(rawValue: 0x8000_001B) }

    /// A Unix domain socket's path.
    ///
    /// The corresponding C constant is `IO_REPARSE_TAG_AF_UNIX`.
    @_alwaysEmitIntoClient
    public static var unixDomainSocket: ReparseTag { ReparseTag(rawValue: 0x8000_0023) }

    /// Whether Microsoft issued the tag: bit 31.
    ///
    /// The corresponding C macro is `IsReparseTagMicrosoft`.
    @_alwaysEmitIntoClient
    public var isMicrosoft: Bool { rawValue & 0x8000_0000 != 0 }

    /// Whether the reparse point names another file or directory, as
    /// symbolic links and junctions do: bit 29.
    ///
    /// The corresponding C macro is `IsReparseTagNameSurrogate`.
    @_alwaysEmitIntoClient
    public var isNameSurrogate: Bool { rawValue & 0x2000_0000 != 0 }
  }

  /// A file's attributes and, if it's a reparse point, its tag.
  ///
  /// The corresponding C type is `FILE_ATTRIBUTE_TAG_INFO`.
  @frozen
  public struct FileAttributeTagInformation: RawRepresentable, Sendable {
    /// The raw C information.
    @_alwaysEmitIntoClient
    public var rawValue: FILE_ATTRIBUTE_TAG_INFO

    /// Creates strongly-typed information from raw C information.
    @_alwaysEmitIntoClient
    public init(rawValue: FILE_ATTRIBUTE_TAG_INFO) { self.rawValue = rawValue }

    /// The file's attributes.
    ///
    /// The corresponding C field is `FileAttributes`.
    @_alwaysEmitIntoClient
    public var attributes: Win32.FileAttributes {
      Win32.FileAttributes(rawValue: rawValue.FileAttributes)
    }

    /// The file's reparse tag, or `nil` if it isn't a reparse point.
    ///
    /// The corresponding C field is `ReparseTag`.
    @_alwaysEmitIntoClient
    public var reparseTag: Win32.ReparseTag? {
      attributes.contains(.reparsePoint) ? Win32.ReparseTag(rawValue: rawValue.ReparseTag) : nil
    }
  }
}

// MARK: - Queries and changes through handles

@available(System 199, *)
extension Win32.FileHandle {
  /// The file's attributes, times, size, link count, and index.
  ///
  /// Requires no access rights.
  ///
  /// The corresponding C function is `GetFileInformationByHandle`.
  @_alwaysEmitIntoClient
  public func information() throws(Win32.Error) -> Win32.FileInformation {
    Win32.FileInformation(rawValue: try Win32._information(_handle).get())
  }

  /// The file's times and attributes.
  ///
  /// Requires no access rights.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func basicInformation() throws(Win32.Error) -> Win32.FileBasicInformation {
    Win32.FileBasicInformation(rawValue: try Win32._basicInformation(_handle).get())
  }

  /// The file's sizes, link count, and whether it's a directory or about to
  /// be deleted.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileStandardInfo`.
  @_alwaysEmitIntoClient
  public func standardInformation() throws(Win32.Error) -> Win32.FileStandardInformation {
    Win32.FileStandardInformation(rawValue: try Win32._standardInformation(_handle).get())
  }

  /// The file's identity on its volume.
  ///
  /// Throws ``Win32/Error/invalidParameter`` on a file system that has no
  /// 128-bit IDs, such as FAT.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileIdInfo`.
  @_alwaysEmitIntoClient
  public func fileID() throws(Win32.Error) -> Win32.FileID {
    Win32.FileID(try Win32._fileIDInformation(_handle).get())
  }

  /// The file's attributes and, if it's a reparse point, its tag.
  ///
  /// To see a reparse point itself, rather than the file it leads to, open
  /// it with ``Win32/FileFlags/openReparsePoint``.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileAttributeTagInfo`.
  @_alwaysEmitIntoClient
  public func attributeTagInformation() throws(Win32.Error) -> Win32.FileAttributeTagInformation {
    Win32.FileAttributeTagInformation(rawValue: try Win32._attributeTagInformation(_handle).get())
  }

  /// Sets some of the file's times.
  ///
  /// - Parameters:
  ///   - creation: When the file was created, or `nil` to leave it.
  ///   - lastAccess: When the file was last read or written, or `nil`.
  ///   - lastWrite: When the file was last written, or `nil`.
  ///   - change: When the file last changed, or `nil`.
  ///
  /// Needs ``Win32/AccessMask/writeAttributes``. A time is the count since
  /// 1601, and a count of zero means "leave it", so the start of 1601 can't
  /// be set.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func setTimes(
    creation: Win32.FileTime? = nil,
    lastAccess: Win32.FileTime? = nil,
    lastWrite: Win32.FileTime? = nil,
    change: Win32.FileTime? = nil
  ) throws(Win32.Error) {
    try Win32._setBasicInformation(
      _handle, creation: creation, lastAccess: lastAccess, lastWrite: lastWrite,
      change: change, attributes: nil
    ).get()
  }

  /// Sets the file's attributes.
  ///
  /// Needs ``Win32/AccessMask/writeAttributes``. An empty set clears every
  /// attribute that can be cleared, as ``Win32/FileAttributes/normal``
  /// does.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func setAttributes(_ attributes: Win32.FileAttributes) throws(Win32.Error) {
    try Win32._setBasicInformation(
      _handle, creation: nil, lastAccess: nil, lastWrite: nil, change: nil,
      attributes: attributes
    ).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// The directory's attributes, times, link count, and index.
  ///
  /// See ``Win32/FileHandle/information()``.
  ///
  /// The corresponding C function is `GetFileInformationByHandle`.
  @_alwaysEmitIntoClient
  public func information() throws(Win32.Error) -> Win32.FileInformation {
    Win32.FileInformation(rawValue: try Win32._information(_handle).get())
  }

  /// The directory's times and attributes.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func basicInformation() throws(Win32.Error) -> Win32.FileBasicInformation {
    Win32.FileBasicInformation(rawValue: try Win32._basicInformation(_handle).get())
  }

  /// The directory's identity on its volume.
  ///
  /// See ``Win32/FileHandle/fileID()``.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileIdInfo`.
  @_alwaysEmitIntoClient
  public func fileID() throws(Win32.Error) -> Win32.FileID {
    Win32.FileID(try Win32._fileIDInformation(_handle).get())
  }

  /// The directory's attributes and, if it's a reparse point, such as a
  /// junction, its tag.
  ///
  /// See ``Win32/FileHandle/attributeTagInformation()``.
  ///
  /// The corresponding C function is `GetFileInformationByHandleEx`, with
  /// `FileAttributeTagInfo`.
  @_alwaysEmitIntoClient
  public func attributeTagInformation() throws(Win32.Error) -> Win32.FileAttributeTagInformation {
    Win32.FileAttributeTagInformation(rawValue: try Win32._attributeTagInformation(_handle).get())
  }

  /// Sets some of the directory's times.
  ///
  /// See ``Win32/FileHandle/setTimes(creation:lastAccess:lastWrite:change:)``.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func setTimes(
    creation: Win32.FileTime? = nil,
    lastAccess: Win32.FileTime? = nil,
    lastWrite: Win32.FileTime? = nil,
    change: Win32.FileTime? = nil
  ) throws(Win32.Error) {
    try Win32._setBasicInformation(
      _handle, creation: creation, lastAccess: lastAccess, lastWrite: lastWrite,
      change: change, attributes: nil
    ).get()
  }

  /// Sets the directory's attributes.
  ///
  /// See ``Win32/FileHandle/setAttributes(_:)``.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileBasicInfo`.
  @_alwaysEmitIntoClient
  public func setAttributes(_ attributes: Win32.FileAttributes) throws(Win32.Error) {
    try Win32._setBasicInformation(
      _handle, creation: nil, lastAccess: nil, lastWrite: nil, change: nil,
      attributes: attributes
    ).get()
  }
}

// MARK: - Queries and changes by path

@available(System 199, *)
extension Win32 {
  /// A file's attributes, times, and size, as its directory records them.
  ///
  /// The corresponding C type is `WIN32_FILE_ATTRIBUTE_DATA`.
  @frozen
  public struct FileAttributeData: RawRepresentable, Sendable {
    /// The raw C data.
    @_alwaysEmitIntoClient
    public var rawValue: WIN32_FILE_ATTRIBUTE_DATA

    /// Creates strongly-typed data from raw C data.
    @_alwaysEmitIntoClient
    public init(rawValue: WIN32_FILE_ATTRIBUTE_DATA) { self.rawValue = rawValue }

    /// The file's attributes.
    ///
    /// The corresponding C field is `dwFileAttributes`.
    @_alwaysEmitIntoClient
    public var attributes: Win32.FileAttributes {
      Win32.FileAttributes(rawValue: rawValue.dwFileAttributes)
    }

    /// When the file was created.
    ///
    /// The corresponding C field is `ftCreationTime`.
    @_alwaysEmitIntoClient
    public var creationTime: Win32.FileTime { Win32.FileTime(rawValue.ftCreationTime) }

    /// When the file was last read or written.
    ///
    /// The corresponding C field is `ftLastAccessTime`.
    @_alwaysEmitIntoClient
    public var lastAccessTime: Win32.FileTime { Win32.FileTime(rawValue.ftLastAccessTime) }

    /// When the file was last written.
    ///
    /// The corresponding C field is `ftLastWriteTime`.
    @_alwaysEmitIntoClient
    public var lastWriteTime: Win32.FileTime { Win32.FileTime(rawValue.ftLastWriteTime) }

    /// The file's size, in bytes.
    ///
    /// The corresponding C fields are `nFileSizeHigh` and `nFileSizeLow`.
    @_alwaysEmitIntoClient
    public var size: Int64 {
      Int64(bitPattern: UInt64(rawValue.nFileSizeHigh) << 32 | UInt64(rawValue.nFileSizeLow))
    }
  }

  /// Returns a file's attributes, without opening it.
  ///
  /// A symbolic link or a junction at `path` reports its own attributes,
  /// with ``FileAttributes/reparsePoint``, rather than its target's.
  /// Throws ``Error/fileNotFound`` or ``Error/pathNotFound`` if there's no
  /// file at `path`. Like ``FileHandle/open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``,
  /// this resolves and canonicalizes `path` first.
  ///
  /// The corresponding C function is `GetFileAttributesW`, with
  /// `INVALID_FILE_ATTRIBUTES` as its failure, which this throws as the last
  /// error.
  @_alwaysEmitIntoClient
  public static func fileAttributes(of path: FilePath) throws(Win32.Error) -> FileAttributes {
    FileAttributes(rawValue: try _fileAttributes(path).get())
  }

  /// Returns a file's attributes, times, and size, without opening it.
  ///
  /// A symbolic link or a junction at `path` reports its own, rather than
  /// its target's. Throws ``Error/fileNotFound`` or ``Error/pathNotFound``
  /// if there's no file at `path`.
  ///
  /// The corresponding C function is `GetFileAttributesExW`, with
  /// `GetFileExInfoStandard`.
  @_alwaysEmitIntoClient
  public static func fileAttributeData(of path: FilePath) throws(Win32.Error) -> FileAttributeData {
    FileAttributeData(rawValue: try _fileAttributeData(path).get())
  }

  /// Sets a file's attributes, without opening it.
  ///
  /// An empty set clears every attribute that can be cleared, as
  /// ``FileAttributes/normal`` does. Attributes such as
  /// ``FileAttributes/directory`` and ``FileAttributes/reparsePoint``
  /// describe the file, and setting them changes nothing.
  ///
  /// The corresponding C function is `SetFileAttributesW`.
  @_alwaysEmitIntoClient
  public static func setFileAttributes(
    _ attributes: FileAttributes, of path: FilePath
  ) throws(Win32.Error) {
    try _setFileAttributes(path, attributes.isEmpty ? FileAttributes.normal.rawValue : attributes.rawValue).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _information(
    _ handle: HANDLE
  ) -> Result<BY_HANDLE_FILE_INFORMATION, Win32.Error> {
    var information = BY_HANDLE_FILE_INFORMATION()
    guard system_GetFileInformationByHandle(handle, &information) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(information)
  }

  /// Queries one information class into a value of its C type.
  internal static func _informationByHandle<Information>(
    _ handle: HANDLE, _ informationClass: FILE_INFO_BY_HANDLE_CLASS, as _: Information.Type
  ) -> Result<Information, Win32.Error> {
    withUnsafeTemporaryAllocation(of: Information.self, capacity: 1) { buffer in
      guard system_GetFileInformationByHandleEx(
        handle, informationClass, UnsafeMutableRawPointer(buffer.baseAddress!),
        DWORD(MemoryLayout<Information>.size))
      else {
        return .failure(Win32.Error(GetLastError()))
      }
      // The call initialized it.
      return .success(buffer.baseAddress!.move())
    }
  }

  @usableFromInline
  internal static func _basicInformation(_ handle: HANDLE) -> Result<FILE_BASIC_INFO, Win32.Error> {
    _informationByHandle(handle, FileBasicInfo, as: FILE_BASIC_INFO.self)
  }

  @usableFromInline
  internal static func _standardInformation(
    _ handle: HANDLE
  ) -> Result<FILE_STANDARD_INFO, Win32.Error> {
    _informationByHandle(handle, FileStandardInfo, as: FILE_STANDARD_INFO.self)
  }

  @usableFromInline
  internal static func _fileIDInformation(_ handle: HANDLE) -> Result<FILE_ID_INFO, Win32.Error> {
    _informationByHandle(handle, FileIdInfo, as: FILE_ID_INFO.self)
  }

  @usableFromInline
  internal static func _attributeTagInformation(
    _ handle: HANDLE
  ) -> Result<FILE_ATTRIBUTE_TAG_INFO, Win32.Error> {
    _informationByHandle(handle, FileAttributeTagInfo, as: FILE_ATTRIBUTE_TAG_INFO.self)
  }

  @usableFromInline
  internal static func _setBasicInformation(
    _ handle: HANDLE,
    creation: Win32.FileTime?,
    lastAccess: Win32.FileTime?,
    lastWrite: Win32.FileTime?,
    change: Win32.FileTime?,
    attributes: Win32.FileAttributes?
  ) -> Result<Void, Win32.Error> {
    // A zero time or zero attributes leaves the file's alone; empty
    // attributes are FILE_ATTRIBUTE_NORMAL, which clears them.
    var information = FILE_BASIC_INFO()
    information.CreationTime.QuadPart = creation?.rawValue ?? 0
    information.LastAccessTime.QuadPart = lastAccess?.rawValue ?? 0
    information.LastWriteTime.QuadPart = lastWrite?.rawValue ?? 0
    information.ChangeTime.QuadPart = change?.rawValue ?? 0
    if let attributes {
      information.FileAttributes =
        attributes.isEmpty ? Win32.FileAttributes.normal.rawValue : attributes.rawValue
    }
    guard system_SetFileInformationByHandle(
      handle, FileBasicInfo, &information, DWORD(MemoryLayout<FILE_BASIC_INFO>.size))
    else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _fileAttributes(_ path: FilePath) -> Result<DWORD, Win32.Error> {
    _withCanonicalPath(path) { path in
      let attributes = system_GetFileAttributesW(path)
      guard attributes != INVALID_FILE_ATTRIBUTES else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(attributes)
    }
  }

  @usableFromInline
  internal static func _fileAttributeData(
    _ path: FilePath
  ) -> Result<WIN32_FILE_ATTRIBUTE_DATA, Win32.Error> {
    _withCanonicalPath(path) { path in
      var data = WIN32_FILE_ATTRIBUTE_DATA()
      guard system_GetFileAttributesExW(path, GetFileExInfoStandard, &data) else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(data)
    }
  }

  @usableFromInline
  internal static func _setFileAttributes(
    _ path: FilePath, _ attributes: DWORD
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(path) { path in
      guard system_SetFileAttributesW(path, attributes) else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(())
    }
  }
}

#endif // os(Windows)
