/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// Information about a file system volume.
  ///
  /// `GetVolumeInformationByHandleW` reports these values through five
  /// separate out-parameters, not a C structure, so this is a structure of
  /// decoded values rather than a wrapper of a C type.
  @frozen
  public struct VolumeInformation: Sendable, Hashable, Codable {
    /// The volume label, such as "System Reserved" or a user-defined label
    /// like "My Backup Drive".
    ///
    /// A volume with no label reports the empty string.
    ///
    /// `GetVolumeInformationByHandleW` writes it to its `lpVolumeNameBuffer`
    /// parameter.
    public var name: String

    /// The name of the file system, such as `NTFS`, `ReFS`, `exFAT`, or
    /// `FAT32`.
    ///
    /// `GetVolumeInformationByHandleW` writes it to its
    /// `lpFileSystemNameBuffer` parameter.
    public var fileSystemName: String

    /// The volume serial number assigned when the volume was formatted.
    ///
    /// This is not a durable identifier. Reformatting changes it, and it's
    /// not guaranteed to be unique across machines. A network redirector may
    /// report 0.
    ///
    /// `GetVolumeInformationByHandleW` writes it to its
    /// `lpVolumeSerialNumber` parameter.
    public var serialNumber: UInt32

    /// The maximum length, in characters, of a single path component.
    ///
    /// `GetVolumeInformationByHandleW` writes it to its
    /// `lpMaximumComponentLength` parameter.
    public var maximumComponentLength: Int

    /// The features this file system supports.
    ///
    /// `GetVolumeInformationByHandleW` writes them to its `lpFileSystemFlags`
    /// parameter.
    public var flags: FileSystemFlags

    internal init(
      name: String,
      fileSystemName: String,
      serialNumber: UInt32,
      maximumComponentLength: Int,
      flags: FileSystemFlags
    ) {
      self.name = name
      self.fileSystemName = fileSystemName
      self.serialNumber = serialNumber
      self.maximumComponentLength = maximumComponentLength
      self.flags = flags
    }
  }

  /// Features a file system may support.
  ///
  /// The members cover every flag `WinNT.h` defines, in bit order. `rawValue`
  /// can carry any flag Windows adds later.
  ///
  /// `GetVolumeInformationByHandleW` writes them to its `lpFileSystemFlags`
  /// parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct FileSystemFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The volume supports case-sensitive file names.
    ///
    /// This reports the volume's support, not a directory's setting.
    /// Per-directory case sensitivity, which is what callers usually mean on
    /// modern Windows, is a separate setting; see
    /// ``supportsCaseSensitiveDirectories``.
    ///
    /// The corresponding C constant is `FILE_CASE_SENSITIVE_SEARCH`.
    @_alwaysEmitIntoClient
    public static var caseSensitiveSearch: FileSystemFlags { FileSystemFlags(rawValue: 0x1) }

    /// The volume preserves the case of file names.
    ///
    /// The corresponding C constant is `FILE_CASE_PRESERVED_NAMES`.
    @_alwaysEmitIntoClient
    public static var casePreservedNames: FileSystemFlags { FileSystemFlags(rawValue: 0x2) }

    /// The volume stores file names in Unicode.
    ///
    /// The corresponding C constant is `FILE_UNICODE_ON_DISK`.
    @_alwaysEmitIntoClient
    public static var unicodeOnDisk: FileSystemFlags { FileSystemFlags(rawValue: 0x4) }

    /// The volume preserves and enforces access control lists.
    ///
    /// The corresponding C constant is `FILE_PERSISTENT_ACLS`.
    @_alwaysEmitIntoClient
    public static var persistentACLs: FileSystemFlags { FileSystemFlags(rawValue: 0x8) }

    /// The volume supports file-based compression.
    ///
    /// The corresponding C constant is `FILE_FILE_COMPRESSION`.
    @_alwaysEmitIntoClient
    public static var fileCompression: FileSystemFlags { FileSystemFlags(rawValue: 0x10) }

    /// The volume supports disk quotas.
    ///
    /// The corresponding C constant is `FILE_VOLUME_QUOTAS`.
    @_alwaysEmitIntoClient
    public static var volumeQuotas: FileSystemFlags { FileSystemFlags(rawValue: 0x20) }

    /// The volume supports sparse files.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_SPARSE_FILES`.
    @_alwaysEmitIntoClient
    public static var supportsSparseFiles: FileSystemFlags { FileSystemFlags(rawValue: 0x40) }

    /// The volume supports reparse points, such as symbolic links and
    /// junctions.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_REPARSE_POINTS`.
    @_alwaysEmitIntoClient
    public static var supportsReparsePoints: FileSystemFlags { FileSystemFlags(rawValue: 0x80) }

    /// The volume supports remote storage.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_REMOTE_STORAGE`.
    @_alwaysEmitIntoClient
    public static var supportsRemoteStorage: FileSystemFlags {
      FileSystemFlags(rawValue: 0x100)
    }

    /// The volume returns cleanup result information.
    ///
    /// The corresponding C constant is `FILE_RETURNS_CLEANUP_RESULT_INFO`.
    @_alwaysEmitIntoClient
    public static var returnsCleanupResultInfo: FileSystemFlags {
      FileSystemFlags(rawValue: 0x200)
    }

    /// The volume supports POSIX-style delete and rename, which take effect
    /// while other handles to the file are open.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_POSIX_UNLINK_RENAME`.
    @_alwaysEmitIntoClient
    public static var supportsPOSIXUnlinkRename: FileSystemFlags {
      FileSystemFlags(rawValue: 0x400)
    }

    /// The volume supports BypassIO.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_BYPASS_IO`.
    @_alwaysEmitIntoClient
    public static var supportsBypassIO: FileSystemFlags { FileSystemFlags(rawValue: 0x800) }

    /// The volume supports stream snapshots.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_STREAM_SNAPSHOTS`.
    @_alwaysEmitIntoClient
    public static var supportsStreamSnapshots: FileSystemFlags {
      FileSystemFlags(rawValue: 0x1000)
    }

    /// The volume allows directories to be marked case-sensitive.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_CASE_SENSITIVE_DIRS`.
    @_alwaysEmitIntoClient
    public static var supportsCaseSensitiveDirectories: FileSystemFlags {
      FileSystemFlags(rawValue: 0x2000)
    }

    /// The volume is compressed.
    ///
    /// The corresponding C constant is `FILE_VOLUME_IS_COMPRESSED`.
    @_alwaysEmitIntoClient
    public static var volumeIsCompressed: FileSystemFlags { FileSystemFlags(rawValue: 0x8000) }

    /// The volume supports object identifiers.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_OBJECT_IDS`.
    @_alwaysEmitIntoClient
    public static var supportsObjectIDs: FileSystemFlags { FileSystemFlags(rawValue: 0x1_0000) }

    /// The volume supports the Encrypting File System.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_ENCRYPTION`.
    @_alwaysEmitIntoClient
    public static var supportsEncryption: FileSystemFlags { FileSystemFlags(rawValue: 0x2_0000) }

    /// The volume supports named streams.
    ///
    /// The corresponding C constant is `FILE_NAMED_STREAMS`.
    @_alwaysEmitIntoClient
    public static var namedStreams: FileSystemFlags { FileSystemFlags(rawValue: 0x4_0000) }

    /// The volume is read-only.
    ///
    /// The corresponding C constant is `FILE_READ_ONLY_VOLUME`.
    @_alwaysEmitIntoClient
    public static var readOnlyVolume: FileSystemFlags { FileSystemFlags(rawValue: 0x8_0000) }

    /// The volume can be written only once, sequentially.
    ///
    /// The corresponding C constant is `FILE_SEQUENTIAL_WRITE_ONCE`.
    @_alwaysEmitIntoClient
    public static var sequentialWriteOnce: FileSystemFlags {
      FileSystemFlags(rawValue: 0x10_0000)
    }

    /// The volume supports transactions.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_TRANSACTIONS`.
    @_alwaysEmitIntoClient
    public static var supportsTransactions: FileSystemFlags {
      FileSystemFlags(rawValue: 0x20_0000)
    }

    /// The volume supports hard links.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_HARD_LINKS`.
    @_alwaysEmitIntoClient
    public static var supportsHardLinks: FileSystemFlags { FileSystemFlags(rawValue: 0x40_0000) }

    /// The volume supports extended attributes.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_EXTENDED_ATTRIBUTES`.
    @_alwaysEmitIntoClient
    public static var supportsExtendedAttributes: FileSystemFlags {
      FileSystemFlags(rawValue: 0x80_0000)
    }

    /// The volume supports opening a file by its file identifier.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_OPEN_BY_FILE_ID`.
    @_alwaysEmitIntoClient
    public static var supportsOpenByFileID: FileSystemFlags {
      FileSystemFlags(rawValue: 0x100_0000)
    }

    /// The volume supports update sequence number journals.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_USN_JOURNAL`.
    @_alwaysEmitIntoClient
    public static var supportsUSNJournal: FileSystemFlags { FileSystemFlags(rawValue: 0x200_0000) }

    /// The volume supports integrity streams.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_INTEGRITY_STREAMS`.
    @_alwaysEmitIntoClient
    public static var supportsIntegrityStreams: FileSystemFlags {
      FileSystemFlags(rawValue: 0x400_0000)
    }

    /// The volume supports sharing logical clusters between files.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_BLOCK_REFCOUNTING`.
    @_alwaysEmitIntoClient
    public static var supportsBlockRefcounting: FileSystemFlags {
      FileSystemFlags(rawValue: 0x800_0000)
    }

    /// The volume tracks whether each cluster of a sparse file holds valid
    /// data.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_SPARSE_VDL`.
    @_alwaysEmitIntoClient
    public static var supportsSparseVDL: FileSystemFlags { FileSystemFlags(rawValue: 0x1000_0000) }

    /// The volume is a direct access (DAX) volume.
    ///
    /// The corresponding C constant is `FILE_DAX_VOLUME`.
    @_alwaysEmitIntoClient
    public static var daxVolume: FileSystemFlags { FileSystemFlags(rawValue: 0x2000_0000) }

    /// The volume supports ghosting.
    ///
    /// The corresponding C constant is `FILE_SUPPORTS_GHOSTING`.
    @_alwaysEmitIntoClient
    public static var supportsGhosting: FileSystemFlags { FileSystemFlags(rawValue: 0x4000_0000) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Returns information about the volume this file resides on.
  ///
  /// This requires no access rights. On a pipe, it reports the named-pipe
  /// file system, `NPFS`; on `NUL`, it throws
  /// ``Win32/Error/invalidFunction``.
  ///
  /// The corresponding C function is `GetVolumeInformationByHandleW`.
  @_alwaysEmitIntoClient
  public func volumeInformation() throws(Win32.Error) -> Win32.VolumeInformation {
    try Win32._volumeInformation(_handle).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// Returns information about the volume this directory resides on.
  ///
  /// This requires no access rights.
  ///
  /// The corresponding C function is `GetVolumeInformationByHandleW`.
  @_alwaysEmitIntoClient
  public func volumeInformation() throws(Win32.Error) -> Win32.VolumeInformation {
    try Win32._volumeInformation(_handle).get()
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _volumeInformation(
    _ handle: HANDLE
  ) -> Result<Win32.VolumeInformation, Win32.Error> {
    // GetVolumeInformationByHandleW bounds each name at MAX_PATH + 1
    // characters.
    let capacity = _win32MaxPath + 1
    return withUnsafeTemporaryAllocation(
      of: WCHAR.self, capacity: capacity
    ) { name -> Result<Win32.VolumeInformation, Win32.Error> in
      withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { fileSystemName -> Result<Win32.VolumeInformation, Win32.Error> in
        var serialNumber: DWORD = 0
        var maximumComponentLength: DWORD = 0
        var flags: DWORD = 0
        guard system_GetVolumeInformationByHandleW(
          handle, name.baseAddress, DWORD(capacity), &serialNumber,
          &maximumComponentLength, &flags, fileSystemName.baseAddress,
          DWORD(capacity)
        ) else {
          return .failure(Win32.Error(GetLastError()))
        }
        return .success(Win32.VolumeInformation(
          name: String(decodingCString: name.baseAddress!, as: UTF16.self),
          fileSystemName: String(
            decodingCString: fileSystemName.baseAddress!, as: UTF16.self),
          serialNumber: UInt32(serialNumber),
          maximumComponentLength: Int(maximumComponentLength),
          flags: Win32.FileSystemFlags(rawValue: flags)))
      }
    }
  }
}

#endif // os(Windows)
