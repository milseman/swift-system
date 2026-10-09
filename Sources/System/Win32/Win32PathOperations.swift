/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// Creating, removing, moving, copying and linking files by path, and
// deleting and renaming them by handle. Each path is resolved and
// canonicalized first, as `Win32.fullPath(of:extendedLengthPrefix:)` does,
// except a symbolic link's target, which the link stores as it's given.

// MARK: - Directories

@available(System 199, *)
extension Win32 {
  /// Creates a directory.
  ///
  /// - Parameters:
  ///   - path: The new directory's path. This creates one directory, so its
  ///     parent must exist.
  ///   - securityDescriptor: The security descriptor to give the directory,
  ///     or `nil` for the default one, whose access control lists come from
  ///     the parent directory. This descriptor is borrowed, not consumed.
  ///
  /// Throws ``Win32/Error/alreadyExists`` if a file or directory exists at
  /// `path`, and ``Win32/Error/pathNotFound`` if its parent doesn't exist.
  ///
  /// The corresponding C function is `CreateDirectoryW`, with a
  /// `SECURITY_ATTRIBUTES` that holds the security descriptor.
  @_alwaysEmitIntoClient
  public static func createDirectory(
    _ path: FilePath,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil
  ) throws(Win32.Error) {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    try _createDirectory(path, securityDescriptor: rawDescriptor).get()
  }

  /// Removes an empty directory.
  ///
  /// Throws ``Win32/Error/directoryNotEmpty`` if the directory has entries.
  /// A symbolic link or a junction to a directory is removed itself, not
  /// its target. Windows removes a directory that other handles have open
  /// when they close, if they share ``Win32/ShareMode/delete``, and throws
  /// ``Win32/Error/sharingViolation`` if one doesn't.
  ///
  /// The corresponding C function is `RemoveDirectoryW`.
  @_alwaysEmitIntoClient
  public static func removeDirectory(_ path: FilePath) throws(Win32.Error) {
    try _removeDirectory(path).get()
  }
}

// MARK: - Files

@available(System 199, *)
extension Win32 {
  /// Deletes a file.
  ///
  /// A symbolic link is deleted itself, not its target. A directory throws
  /// ``Win32/Error/accessDenied``, as a read-only file does; call
  /// ``removeDirectory(_:)`` for a directory, and clear
  /// ``Win32/FileAttributes/readOnly`` first for the file.
  ///
  /// Windows documents that a file that other handles have open, sharing
  /// ``Win32/ShareMode/delete``, is deleted when the last of them closes,
  /// and can't be opened meanwhile; one that a handle has open without
  /// sharing throws ``Win32/Error/sharingViolation``. To remove a file's
  /// name at once, as POSIX's `unlink` does, open it with
  /// ``Win32/AccessMask/delete`` and call
  /// ``Win32/FileHandle/setDisposition(_:)`` with
  /// ``Win32/DispositionFlags/posixSemantics``.
  ///
  /// The corresponding C function is `DeleteFileW`.
  @_alwaysEmitIntoClient
  public static func deleteFile(_ path: FilePath) throws(Win32.Error) {
    try _deleteFile(path).get()
  }

  /// Options for ``moveFile(_:to:flags:)``.
  ///
  /// `MoveFileExW` takes these in its `dwFlags` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct MoveFileFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Replaces a file at the destination, rather than failing.
    ///
    /// A directory at the destination isn't replaced.
    ///
    /// The corresponding C constant is `MOVEFILE_REPLACE_EXISTING`.
    @_alwaysEmitIntoClient
    public static var replaceExisting: MoveFileFlags { MoveFileFlags(rawValue: 0x1) }

    /// Moves a file to another volume by copying it and deleting the
    /// source, rather than failing.
    ///
    /// The corresponding C constant is `MOVEFILE_COPY_ALLOWED`.
    @_alwaysEmitIntoClient
    public static var copyAllowed: MoveFileFlags { MoveFileFlags(rawValue: 0x2) }

    /// Moves the file when the system next starts, rather than now.
    ///
    /// This needs an administrator's rights, and can't be combined with
    /// ``copyAllowed``.
    ///
    /// The corresponding C constant is `MOVEFILE_DELAY_UNTIL_REBOOT`.
    @_alwaysEmitIntoClient
    public static var delayUntilReboot: MoveFileFlags { MoveFileFlags(rawValue: 0x4) }

    /// Returns only once the move is on the device, which for a move
    /// between volumes means the copy and the deletion both are.
    ///
    /// The corresponding C constant is `MOVEFILE_WRITE_THROUGH`.
    @_alwaysEmitIntoClient
    public static var writeThrough: MoveFileFlags { MoveFileFlags(rawValue: 0x8) }

    /// Fails if the source is a link-tracking source that can't be
    /// tracked after the move, as on a FAT volume.
    ///
    /// The corresponding C constant is `MOVEFILE_FAIL_IF_NOT_TRACKABLE`.
    @_alwaysEmitIntoClient
    public static var failIfNotTrackable: MoveFileFlags { MoveFileFlags(rawValue: 0x20) }
  }

  /// Moves or renames a file or directory.
  ///
  /// - Parameters:
  ///   - source: The file or directory to move.
  ///   - destination: Its new path.
  ///   - flags: How to move it. With none, a file or directory at
  ///     `destination` throws ``Win32/Error/alreadyExists``, and a move to
  ///     another volume throws ``Win32/Error/notSameDevice``.
  ///
  /// A directory moves only within its volume.
  ///
  /// The corresponding C function is `MoveFileExW`.
  @_alwaysEmitIntoClient
  public static func moveFile(
    _ source: FilePath,
    to destination: FilePath,
    flags: Win32.MoveFileFlags = []
  ) throws(Win32.Error) {
    try _moveFile(source, to: destination, flags: flags.rawValue).get()
  }

  /// Options for ``copyFile(_:to:flags:)``.
  ///
  /// The corresponding C field is `COPYFILE2_EXTENDED_PARAMETERS.dwCopyFlags`.
  @frozen
  public struct CopyFileFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Fails with ``Win32/Error/fileExists`` if the destination exists,
    /// rather than replacing it.
    ///
    /// The corresponding C constant is `COPY_FILE_FAIL_IF_EXISTS`.
    @_alwaysEmitIntoClient
    public static var failIfExists: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_0001) }

    /// Records the copy's progress in the destination, so that a copy
    /// that's interrupted can restart where it stopped.
    ///
    /// The corresponding C constant is `COPY_FILE_RESTARTABLE`.
    @_alwaysEmitIntoClient
    public static var restartable: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_0002) }

    /// Opens the source for writing as well as reading.
    ///
    /// The corresponding C constant is `COPY_FILE_OPEN_SOURCE_FOR_WRITE`.
    @_alwaysEmitIntoClient
    public static var openSourceForWrite: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_0004) }

    /// Copies an encrypted file to a destination that can't be encrypted,
    /// decrypted, rather than failing.
    ///
    /// The corresponding C constant is `COPY_FILE_ALLOW_DECRYPTED_DESTINATION`.
    @_alwaysEmitIntoClient
    public static var allowDecryptedDestination: CopyFileFlags {
      CopyFileFlags(rawValue: 0x0000_0008)
    }

    /// Copies a directory itself, not its contents: its attributes and
    /// its streams.
    ///
    /// The corresponding C constant is `COPY_FILE_DIRECTORY`.
    @_alwaysEmitIntoClient
    public static var directory: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_0080) }

    /// Copies a symbolic link itself, as a link to the same target, rather
    /// than the file it points to.
    ///
    /// The corresponding C constant is `COPY_FILE_COPY_SYMLINK`.
    @_alwaysEmitIntoClient
    public static var copySymbolicLink: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_0800) }

    /// Copies without the system cache, which suits a large file.
    ///
    /// The corresponding C constant is `COPY_FILE_NO_BUFFERING`.
    @_alwaysEmitIntoClient
    public static var noBuffering: CopyFileFlags { CopyFileFlags(rawValue: 0x0000_1000) }

    /// Doesn't offload the copy to the storage, which some volumes can do
    /// without the data passing through the computer.
    ///
    /// The corresponding C constant is `COPY_FILE_NO_OFFLOAD`.
    @_alwaysEmitIntoClient
    public static var noOffload: CopyFileFlags { CopyFileFlags(rawValue: 0x0004_0000) }

    /// Copies a reparse point itself, rather than the file it points to.
    ///
    /// The corresponding C constant is `COPY_FILE_OPEN_AND_COPY_REPARSE_POINT`.
    @_alwaysEmitIntoClient
    public static var openAndCopyReparsePoint: CopyFileFlags {
      CopyFileFlags(rawValue: 0x0020_0000)
    }
  }

  /// Copies a file.
  ///
  /// - Parameters:
  ///   - source: The file to copy.
  ///   - destination: The copy's path.
  ///   - flags: How to copy it. With none, a file at `destination` is
  ///     replaced.
  ///
  /// The copy has the source's data, alternate streams and attributes,
  /// such as ``Win32/FileAttributes/readOnly``, and a security descriptor
  /// of its own, from its directory. A destination that's hidden or
  /// read-only isn't replaced, and throws ``Win32/Error/accessDenied``.
  ///
  /// The corresponding C function is `CopyFile2`, with
  /// `COPYFILE2_EXTENDED_PARAMETERS`.
  @_alwaysEmitIntoClient
  public static func copyFile(
    _ source: FilePath,
    to destination: FilePath,
    flags: Win32.CopyFileFlags = []
  ) throws(Win32.Error) {
    try _copyFile(source, to: destination, flags: flags.rawValue).get()
  }
}

// MARK: - Links

@available(System 199, *)
extension Win32 {
  /// Options for ``createSymbolicLink(_:to:flags:)``.
  ///
  /// `CreateSymbolicLinkW` takes these in its `dwFlags` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct SymbolicLinkFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The link points to a directory.
    ///
    /// Windows links are of one kind or the other, and following a link of
    /// the wrong kind fails.
    ///
    /// The corresponding C constant is `SYMBOLIC_LINK_FLAG_DIRECTORY`.
    @_alwaysEmitIntoClient
    public static var directory: SymbolicLinkFlags { SymbolicLinkFlags(rawValue: 0x1) }

    /// Creates the link without the privilege it otherwise needs, where
    /// the system is in developer mode.
    ///
    /// The corresponding C constant is
    /// `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`.
    @_alwaysEmitIntoClient
    public static var allowUnprivilegedCreate: SymbolicLinkFlags {
      SymbolicLinkFlags(rawValue: 0x2)
    }
  }

  /// Creates a symbolic link.
  ///
  /// - Parameters:
  ///   - link: The new link's path.
  ///   - target: The path the link points to, which needn't exist. The link
  ///     stores it as it is, so a relative target is resolved against the
  ///     link's directory when the link is followed.
  ///   - flags: The link's kind, and how to create it.
  ///
  /// Creating a symbolic link needs `SeCreateSymbolicLinkPrivilege`, which
  /// administrators have, or ``SymbolicLinkFlags/allowUnprivilegedCreate``
  /// in developer mode; otherwise it throws
  /// ``Win32/Error/privilegeNotHeld``. Throws ``Win32/Error/alreadyExists``
  /// if something exists at `link`.
  ///
  /// The corresponding C function is `CreateSymbolicLinkW`.
  @_alwaysEmitIntoClient
  public static func createSymbolicLink(
    _ link: FilePath,
    to target: FilePath,
    flags: Win32.SymbolicLinkFlags = []
  ) throws(Win32.Error) {
    try _createSymbolicLink(link, to: target, flags: flags.rawValue).get()
  }

  /// Creates a hard link: another name for an existing file.
  ///
  /// - Parameters:
  ///   - link: The new name.
  ///   - existing: The file to name, which must be on the same volume, or
  ///     the call throws ``Win32/Error/notSameDevice``, and mustn't be a
  ///     directory, which throws ``Win32/Error/accessDenied``.
  ///
  /// Throws ``Win32/Error/alreadyExists`` if something exists at `link`.
  ///
  /// The corresponding C function is `CreateHardLinkW`.
  @_alwaysEmitIntoClient
  public static func createHardLink(
    _ link: FilePath,
    to existing: FilePath
  ) throws(Win32.Error) {
    try _createHardLink(link, to: existing).get()
  }
}

// MARK: - Deleting and renaming by handle

@available(System 199, *)
extension Win32 {
  /// Whether and how a file is deleted, for
  /// ``Win32/FileHandle/setDisposition(_:)``.
  ///
  /// The corresponding C field is `FILE_DISPOSITION_INFO_EX.Flags`.
  @frozen
  public struct DispositionFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Deletes the file. Without it, a file marked for deletion is
    /// unmarked.
    ///
    /// The corresponding C constant is `FILE_DISPOSITION_FLAG_DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: DispositionFlags { DispositionFlags(rawValue: 0x1) }

    /// Removes the file's name when this handle closes, even while other
    /// handles are open, as POSIX's `unlink` does: they keep working, and
    /// the name can be used for a new file at once.
    ///
    /// Without it, the name stays until the last handle closes, and opening
    /// it meanwhile fails with ``Win32/Error/accessDenied``.
    ///
    /// The corresponding C constant is `FILE_DISPOSITION_FLAG_POSIX_SEMANTICS`.
    @_alwaysEmitIntoClient
    public static var posixSemantics: DispositionFlags { DispositionFlags(rawValue: 0x2) }

    /// Deletes an executable image even while it's mapped, if no process
    /// runs it.
    ///
    /// The corresponding C constant is
    /// `FILE_DISPOSITION_FLAG_FORCE_IMAGE_SECTION_CHECK`.
    @_alwaysEmitIntoClient
    public static var forceImageSectionCheck: DispositionFlags {
      DispositionFlags(rawValue: 0x4)
    }

    /// Sets or clears the handle's delete-on-close state, as
    /// ``Win32/FileFlags/deleteOnClose`` sets it when it opens, rather than
    /// marking the file now.
    ///
    /// The corresponding C constant is `FILE_DISPOSITION_FLAG_ON_CLOSE`.
    @_alwaysEmitIntoClient
    public static var onClose: DispositionFlags { DispositionFlags(rawValue: 0x8) }

    /// Deletes a read-only file, rather than failing with
    /// ``Win32/Error/accessDenied``.
    ///
    /// The corresponding C constant is
    /// `FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE`.
    @_alwaysEmitIntoClient
    public static var ignoreReadOnlyAttribute: DispositionFlags {
      DispositionFlags(rawValue: 0x10)
    }
  }

  /// How ``Win32/FileHandle/rename(to:flags:)`` renames a file.
  ///
  /// They're the flags of a rename with `FileRenameInfoEx`.
  ///
  /// The corresponding C field is `FILE_RENAME_INFO.Flags`.
  @frozen
  public struct RenameFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Replaces a file at the destination, rather than failing.
    ///
    /// The corresponding C constant is `FILE_RENAME_FLAG_REPLACE_IF_EXISTS`.
    @_alwaysEmitIntoClient
    public static var replaceIfExists: RenameFlags { RenameFlags(rawValue: 0x1) }

    /// With ``replaceIfExists``, replaces the destination even while other
    /// handles have it open, as POSIX's `rename` does: they keep working
    /// on the replaced file, and the name opens the renamed one.
    ///
    /// The corresponding C constant is `FILE_RENAME_FLAG_POSIX_SEMANTICS`.
    @_alwaysEmitIntoClient
    public static var posixSemantics: RenameFlags { RenameFlags(rawValue: 0x2) }

    /// Keeps the file's pin state for cloud files in its new directory,
    /// rather than inheriting the directory's.
    ///
    /// The corresponding C constant is
    /// `FILE_RENAME_FLAG_SUPPRESS_PIN_STATE_INHERITANCE`.
    @_alwaysEmitIntoClient
    public static var suppressPinStateInheritance: RenameFlags { RenameFlags(rawValue: 0x4) }

    /// With ``replaceIfExists``, replaces a read-only destination, rather
    /// than failing with ``Win32/Error/accessDenied``.
    ///
    /// The corresponding C constant is
    /// `FILE_RENAME_FLAG_IGNORE_READONLY_ATTRIBUTE`.
    @_alwaysEmitIntoClient
    public static var ignoreReadOnlyAttribute: RenameFlags { RenameFlags(rawValue: 0x40) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Sets whether the file is deleted, and how.
  ///
  /// - Parameter flags: `[.delete, .posixSemantics]` removes the file's
  ///   name when this handle closes, as POSIX's `unlink` does; `[.delete]`
  ///   deletes the file when its last handle closes; `[]` unmarks a file
  ///   marked for deletion.
  ///
  /// Needs ``Win32/AccessMask/delete``. File systems without
  /// `FILE_DISPOSITION_INFO_EX`, such as FAT, throw
  /// ``Win32/Error/invalidParameter`` or ``Win32/Error/notSupported``.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileDispositionInfoEx` and a `FILE_DISPOSITION_INFO_EX`.
  @_alwaysEmitIntoClient
  public func setDisposition(_ flags: Win32.DispositionFlags) throws(Win32.Error) {
    try Win32._setDisposition(_handle, flags.rawValue).get()
  }

  /// Renames or moves the file within its volume.
  ///
  /// - Parameters:
  ///   - destination: The file's new path, which must be on the same
  ///     volume, or the call throws ``Win32/Error/notSameDevice``.
  ///   - flags: How to rename it. With none, a file at `destination`
  ///     throws ``Win32/Error/alreadyExists``; `[.replaceIfExists,
  ///     .posixSemantics]` replaces it as POSIX's `rename` does.
  ///
  /// Needs ``Win32/AccessMask/delete``. This handle stays open on the
  /// renamed file.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileRenameInfoEx` and a `FILE_RENAME_INFO`.
  @_alwaysEmitIntoClient
  public func rename(
    to destination: FilePath,
    flags: Win32.RenameFlags = []
  ) throws(Win32.Error) {
    try Win32._rename(_handle, to: destination, flags: flags.rawValue).get()
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// Sets whether the directory is deleted, and how.
  ///
  /// The directory must be empty when it's deleted. See
  /// ``Win32/FileHandle/setDisposition(_:)``.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileDispositionInfoEx` and a `FILE_DISPOSITION_INFO_EX`.
  @_alwaysEmitIntoClient
  public func setDisposition(_ flags: Win32.DispositionFlags) throws(Win32.Error) {
    try Win32._setDisposition(_handle, flags.rawValue).get()
  }

  /// Renames or moves the directory within its volume.
  ///
  /// See ``Win32/FileHandle/rename(to:flags:)``. A directory at
  /// `destination` isn't replaced.
  ///
  /// The corresponding C function is `SetFileInformationByHandle`, with
  /// `FileRenameInfoEx` and a `FILE_RENAME_INFO`.
  @_alwaysEmitIntoClient
  public func rename(
    to destination: FilePath,
    flags: Win32.RenameFlags = []
  ) throws(Win32.Error) {
    try Win32._rename(_handle, to: destination, flags: flags.rawValue).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createDirectory(
    _ path: FilePath, securityDescriptor: PSECURITY_DESCRIPTOR?
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(path) { path in
      var securityAttributes = SECURITY_ATTRIBUTES(
        nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
        lpSecurityDescriptor: securityDescriptor,
        bInheritHandle: false)
      guard system_CreateDirectoryW(path, &securityAttributes) else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(())
    }
  }

  @usableFromInline
  internal static func _removeDirectory(_ path: FilePath) -> Result<Void, Win32.Error> {
    _withCanonicalPath(path) { path in
      guard system_RemoveDirectoryW(path) else { return .failure(Win32.Error(GetLastError())) }
      return .success(())
    }
  }

  @usableFromInline
  internal static func _deleteFile(_ path: FilePath) -> Result<Void, Win32.Error> {
    _withCanonicalPath(path) { path in
      guard system_DeleteFileW(path) else { return .failure(Win32.Error(GetLastError())) }
      return .success(())
    }
  }

  @usableFromInline
  internal static func _moveFile(
    _ source: FilePath, to destination: FilePath, flags: DWORD
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(source) { source in
      _withCanonicalPath(destination) { destination in
        guard system_MoveFileExW(source, destination, flags) else {
          return .failure(Win32.Error(GetLastError()))
        }
        return .success(())
      }
    }
  }

  @usableFromInline
  internal static func _copyFile(
    _ source: FilePath, to destination: FilePath, flags: DWORD
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(source) { source in
      _withCanonicalPath(destination) { destination in
        var parameters = COPYFILE2_EXTENDED_PARAMETERS()
        parameters.dwSize = DWORD(MemoryLayout<COPYFILE2_EXTENDED_PARAMETERS>.size)
        parameters.dwCopyFlags = flags
        let result = system_CopyFile2(source, destination, &parameters)
        guard result >= 0 else { return .failure(Win32.Error(_win32Error(fromHRESULT: result))) }
        return .success(())
      }
    }
  }

  @usableFromInline
  internal static func _createSymbolicLink(
    _ link: FilePath, to target: FilePath, flags: DWORD
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(link) { link in
      target.withPlatformString { target in
        // A BOOLEAN, not a BOOL.
        guard system_CreateSymbolicLinkW(link, target, flags) != 0 else {
          return .failure(Win32.Error(GetLastError()))
        }
        return .success(())
      }
    }
  }

  @usableFromInline
  internal static func _createHardLink(
    _ link: FilePath, to existing: FilePath
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(link) { link in
      _withCanonicalPath(existing) { existing in
        guard system_CreateHardLinkW(link, existing) else {
          return .failure(Win32.Error(GetLastError()))
        }
        return .success(())
      }
    }
  }

  @usableFromInline
  internal static func _setDisposition(_ handle: HANDLE, _ flags: DWORD) -> Result<Void, Win32.Error> {
    var information = FILE_DISPOSITION_INFO_EX()
    information.Flags = flags
    guard system_SetFileInformationByHandle(
      handle, FileDispositionInfoEx, &information,
      DWORD(MemoryLayout<FILE_DISPOSITION_INFO_EX>.size))
    else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _rename(
    _ handle: HANDLE, to destination: FilePath, flags: DWORD
  ) -> Result<Void, Win32.Error> {
    _withCanonicalPath(destination) { name in
      var length = 0
      while name[length] != 0 { length += 1 }
      // FILE_RENAME_INFO ends with the name, its terminator included,
      // though FileNameLength doesn't count the terminator.
      let nameOffset = MemoryLayout<FILE_RENAME_INFO>.offset(of: \.FileName)!
      let nameBytes = length * MemoryLayout<WCHAR>.stride
      let size = max(
        nameOffset + nameBytes + MemoryLayout<WCHAR>.stride, MemoryLayout<FILE_RENAME_INFO>.size)
      var header = FILE_RENAME_INFO()
      header.Flags = flags
      header.RootDirectory = nil
      header.FileNameLength = DWORD(nameBytes)
      return withUnsafeTemporaryAllocation(
        byteCount: size, alignment: MemoryLayout<FILE_RENAME_INFO>.alignment
      ) { buffer in
        let base = buffer.baseAddress!
        base.initializeMemory(as: UInt8.self, repeating: 0, count: size)
        withUnsafeBytes(of: &header) { header in
          base.copyMemory(from: header.baseAddress!, byteCount: nameOffset)
        }
        (base + nameOffset).copyMemory(from: name, byteCount: nameBytes + MemoryLayout<WCHAR>.stride)
        guard system_SetFileInformationByHandle(handle, FileRenameInfoEx, base, DWORD(size)) else {
          return .failure(Win32.Error(GetLastError()))
        }
        return .success(())
      }
    }
  }
}

#endif // os(Windows)
