/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Access rights

@available(System 199, *)
extension Win32 {
  /// The access rights to request for a handle.
  ///
  /// The generic rights map to a set of specific rights for the kind of
  /// object opened. `CreateFileW` adds ``readAttributes`` and ``synchronize``
  /// to every request, so an empty mask still allows querying metadata.
  ///
  /// Windows gives four specific rights a second name for directories. Each
  /// pair names one bit, so a mask holding ``readData`` also contains
  /// ``listDirectory``.
  ///
  /// The corresponding C type is `ACCESS_MASK`, as `CreateFileW`'s
  /// `dwDesiredAccess`.
  @frozen
  public struct AccessMask: OptionSet, Sendable, Hashable, Codable {
    /// The raw C access mask.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed access mask from a raw C access mask.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Read access: reading data, attributes, extended attributes, and the
    /// security descriptor.
    ///
    /// The corresponding C constant is `GENERIC_READ`.
    @_alwaysEmitIntoClient
    public static var genericRead: AccessMask { AccessMask(rawValue: 0x8000_0000) }

    /// Write access: writing and appending data, and writing attributes and
    /// extended attributes.
    ///
    /// The corresponding C constant is `GENERIC_WRITE`.
    @_alwaysEmitIntoClient
    public static var genericWrite: AccessMask { AccessMask(rawValue: 0x4000_0000) }

    /// Execute access.
    ///
    /// The corresponding C constant is `GENERIC_EXECUTE`.
    @_alwaysEmitIntoClient
    public static var genericExecute: AccessMask { AccessMask(rawValue: 0x2000_0000) }

    /// All possible access rights.
    ///
    /// The corresponding C constant is `GENERIC_ALL`.
    @_alwaysEmitIntoClient
    public static var genericAll: AccessMask { AccessMask(rawValue: 0x1000_0000) }

    /// Every right the access check finds the caller entitled to.
    ///
    /// This doesn't name a right. Like the generic rights, it never appears
    /// in a mask the system reports.
    ///
    /// The corresponding C constant is `MAXIMUM_ALLOWED`.
    @_alwaysEmitIntoClient
    public static var maximumAllowed: AccessMask { AccessMask(rawValue: 0x0200_0000) }

    /// The right to delete the object.
    ///
    /// The corresponding C constant is `DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: AccessMask { AccessMask(rawValue: 0x0001_0000) }

    /// The right to read the object's security descriptor, not including its
    /// system access control list.
    ///
    /// The corresponding C constant is `READ_CONTROL`.
    @_alwaysEmitIntoClient
    public static var readControl: AccessMask { AccessMask(rawValue: 0x0002_0000) }

    /// The right to change the object's discretionary access control list.
    ///
    /// The corresponding C constant is `WRITE_DAC`.
    @_alwaysEmitIntoClient
    public static var writeDAC: AccessMask { AccessMask(rawValue: 0x0004_0000) }

    /// The right to change the object's owner.
    ///
    /// The corresponding C constant is `WRITE_OWNER`.
    @_alwaysEmitIntoClient
    public static var writeOwner: AccessMask { AccessMask(rawValue: 0x0008_0000) }

    /// The right to wait on the object.
    ///
    /// The corresponding C constant is `SYNCHRONIZE`.
    @_alwaysEmitIntoClient
    public static var synchronize: AccessMask { AccessMask(rawValue: 0x0010_0000) }

    /// The right to read a file's data.
    ///
    /// The same bit as ``listDirectory``.
    ///
    /// The corresponding C constant is `FILE_READ_DATA`.
    @_alwaysEmitIntoClient
    public static var readData: AccessMask { AccessMask(rawValue: 0x1) }

    /// The right to list a directory's contents.
    ///
    /// The same bit as ``readData``.
    ///
    /// The corresponding C constant is `FILE_LIST_DIRECTORY`.
    @_alwaysEmitIntoClient
    public static var listDirectory: AccessMask { AccessMask(rawValue: 0x1) }

    /// The right to write a file's data.
    ///
    /// The same bit as ``addFile``.
    ///
    /// The corresponding C constant is `FILE_WRITE_DATA`.
    @_alwaysEmitIntoClient
    public static var writeData: AccessMask { AccessMask(rawValue: 0x2) }

    /// The right to create a file in a directory.
    ///
    /// The same bit as ``writeData``.
    ///
    /// The corresponding C constant is `FILE_ADD_FILE`.
    @_alwaysEmitIntoClient
    public static var addFile: AccessMask { AccessMask(rawValue: 0x2) }

    /// The right to append data to a file.
    ///
    /// A handle with this right but not ``writeData`` writes every write at
    /// the end of the file. The same bit as ``addSubdirectory``.
    ///
    /// The corresponding C constant is `FILE_APPEND_DATA`.
    @_alwaysEmitIntoClient
    public static var appendData: AccessMask { AccessMask(rawValue: 0x4) }

    /// The right to create a subdirectory.
    ///
    /// The same bit as ``appendData``.
    ///
    /// The corresponding C constant is `FILE_ADD_SUBDIRECTORY`.
    @_alwaysEmitIntoClient
    public static var addSubdirectory: AccessMask { AccessMask(rawValue: 0x4) }

    /// The right to read extended attributes.
    ///
    /// The corresponding C constant is `FILE_READ_EA`.
    @_alwaysEmitIntoClient
    public static var readExtendedAttributes: AccessMask { AccessMask(rawValue: 0x8) }

    /// The right to write extended attributes.
    ///
    /// The corresponding C constant is `FILE_WRITE_EA`.
    @_alwaysEmitIntoClient
    public static var writeExtendedAttributes: AccessMask { AccessMask(rawValue: 0x10) }

    /// The right to execute a file.
    ///
    /// The same bit as ``traverse``.
    ///
    /// The corresponding C constant is `FILE_EXECUTE`.
    @_alwaysEmitIntoClient
    public static var execute: AccessMask { AccessMask(rawValue: 0x20) }

    /// The right to traverse a directory.
    ///
    /// The same bit as ``execute``.
    ///
    /// The corresponding C constant is `FILE_TRAVERSE`.
    @_alwaysEmitIntoClient
    public static var traverse: AccessMask { AccessMask(rawValue: 0x20) }

    /// The right to delete a directory and every file it contains,
    /// including read-only files.
    ///
    /// Meaningful only on a directory.
    ///
    /// The corresponding C constant is `FILE_DELETE_CHILD`.
    @_alwaysEmitIntoClient
    public static var deleteChild: AccessMask { AccessMask(rawValue: 0x40) }

    /// The right to read file attributes.
    ///
    /// The corresponding C constant is `FILE_READ_ATTRIBUTES`.
    @_alwaysEmitIntoClient
    public static var readAttributes: AccessMask { AccessMask(rawValue: 0x80) }

    /// The right to write file attributes.
    ///
    /// The corresponding C constant is `FILE_WRITE_ATTRIBUTES`.
    @_alwaysEmitIntoClient
    public static var writeAttributes: AccessMask { AccessMask(rawValue: 0x100) }
  }
}

// MARK: - Share mode

@available(System 199, *)
extension Win32 {
  /// How a file may be shared with other opens while a handle to it is
  /// open.
  ///
  /// An empty share mode requests exclusive access. Windows enforces share
  /// modes: an open whose access or share mode conflicts with another open
  /// of the file fails with ``Win32/Error/sharingViolation``.
  ///
  /// `CreateFileW` takes a share mode in its `dwShareMode` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ShareMode: OptionSet, Sendable, Hashable, Codable {
    /// The raw C share mode.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed share mode from a raw C share mode.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Other opens may read the file.
    ///
    /// The corresponding C constant is `FILE_SHARE_READ`.
    @_alwaysEmitIntoClient
    public static var read: ShareMode { ShareMode(rawValue: 0x1) }

    /// Other opens may write the file.
    ///
    /// The corresponding C constant is `FILE_SHARE_WRITE`.
    @_alwaysEmitIntoClient
    public static var write: ShareMode { ShareMode(rawValue: 0x2) }

    /// Other opens may delete or rename the file.
    ///
    /// The corresponding C constant is `FILE_SHARE_DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: ShareMode { ShareMode(rawValue: 0x4) }
  }
}

// MARK: - Creation disposition

@available(System 199, *)
extension Win32 {
  /// Whether an open creates, opens, or truncates a file.
  ///
  /// The dispositions are mutually exclusive, unlike POSIX `open`'s
  /// `O_CREAT`, `O_EXCL`, and `O_TRUNC` bits.
  ///
  /// `CreateFileW` takes one in its `dwCreationDisposition` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct CreationDisposition: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C creation disposition.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed creation disposition from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Creates a file, failing with ``Win32/Error/fileExists`` if it
    /// already exists.
    ///
    /// The corresponding C constant is `CREATE_NEW`.
    @_alwaysEmitIntoClient
    public static var createNew: CreationDisposition { CreationDisposition(rawValue: 1) }

    /// Creates a file, or overwrites it if it exists.
    ///
    /// Overwriting applies the open's attributes to the existing file.
    ///
    /// The corresponding C constant is `CREATE_ALWAYS`.
    @_alwaysEmitIntoClient
    public static var createAlways: CreationDisposition { CreationDisposition(rawValue: 2) }

    /// Opens a file, failing if it doesn't exist.
    ///
    /// The corresponding C constant is `OPEN_EXISTING`.
    @_alwaysEmitIntoClient
    public static var openExisting: CreationDisposition { CreationDisposition(rawValue: 3) }

    /// Opens a file, or creates it if it doesn't exist.
    ///
    /// The corresponding C constant is `OPEN_ALWAYS`.
    @_alwaysEmitIntoClient
    public static var openAlways: CreationDisposition { CreationDisposition(rawValue: 4) }

    /// Opens a file and truncates it to zero bytes, failing if it doesn't
    /// exist.
    ///
    /// The open must request ``Win32/AccessMask/genericWrite``.
    ///
    /// The corresponding C constant is `TRUNCATE_EXISTING`.
    @_alwaysEmitIntoClient
    public static var truncateExisting: CreationDisposition {
      CreationDisposition(rawValue: 5)
    }
  }
}

// MARK: - Handle flags

@available(System 199, *)
extension Win32 {
  /// Caching, semantic, and lifetime flags for a handle.
  ///
  /// These are properties of the handle, unlike ``Win32/FileAttributes``,
  /// which are properties of the file. `CreateFileW` takes both in one
  /// parameter.
  ///
  /// `CreateFileW` takes these in the `FILE_FLAG_*` part of its
  /// `dwFlagsAndAttributes` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct FileFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Opens a directory, and overrides file security checks for a process
    /// that has enabled `SE_BACKUP_NAME` or `SE_RESTORE_NAME`.
    ///
    /// ``Win32/DirectoryHandle/open(_:access:shareMode:flags:inheritable:)``
    /// applies this flag itself.
    ///
    /// The corresponding C constant is `FILE_FLAG_BACKUP_SEMANTICS`.
    @_alwaysEmitIntoClient
    public static var backupSemantics: FileFlags { FileFlags(rawValue: 0x0200_0000) }

    /// Bypasses the system cache.
    ///
    /// Reads and writes on the handle must use offsets and lengths that are
    /// multiples of the volume's sector size, and sector-aligned buffers,
    /// or they fail with ``Win32/Error/invalidParameter``.
    ///
    /// The corresponding C constant is `FILE_FLAG_NO_BUFFERING`.
    @_alwaysEmitIntoClient
    public static var noBuffering: FileFlags { FileFlags(rawValue: 0x2000_0000) }

    /// Writes through the system cache to the device.
    ///
    /// The corresponding C constant is `FILE_FLAG_WRITE_THROUGH`.
    @_alwaysEmitIntoClient
    public static var writeThrough: FileFlags { FileFlags(rawValue: 0x8000_0000) }

    /// Optimizes caching for sequential access.
    ///
    /// The corresponding C constant is `FILE_FLAG_SEQUENTIAL_SCAN`.
    @_alwaysEmitIntoClient
    public static var sequentialScan: FileFlags { FileFlags(rawValue: 0x0800_0000) }

    /// Optimizes caching for random access.
    ///
    /// The corresponding C constant is `FILE_FLAG_RANDOM_ACCESS`.
    @_alwaysEmitIntoClient
    public static var randomAccess: FileFlags { FileFlags(rawValue: 0x1000_0000) }

    /// Deletes the file once all of its handles are closed.
    ///
    /// Later opens of the file fail unless they share ``Win32/ShareMode/delete``.
    ///
    /// The corresponding C constant is `FILE_FLAG_DELETE_ON_CLOSE`.
    @_alwaysEmitIntoClient
    public static var deleteOnClose: FileFlags { FileFlags(rawValue: 0x0400_0000) }

    /// Opens a reparse point itself, such as a symbolic link, rather than
    /// its target.
    ///
    /// The corresponding C constant is `FILE_FLAG_OPEN_REPARSE_POINT`.
    @_alwaysEmitIntoClient
    public static var openReparsePoint: FileFlags { FileFlags(rawValue: 0x0020_0000) }

    /// Makes name lookups case-sensitive, where the file system supports
    /// it.
    ///
    /// The corresponding C constant is `FILE_FLAG_POSIX_SEMANTICS`.
    @_alwaysEmitIntoClient
    public static var posixSemantics: FileFlags { FileFlags(rawValue: 0x0100_0000) }

    /// Requests the file's data without recalling it from remote storage.
    ///
    /// The corresponding C constant is `FILE_FLAG_OPEN_NO_RECALL`.
    @_alwaysEmitIntoClient
    public static var openNoRecall: FileFlags { FileFlags(rawValue: 0x0010_0000) }

    /// Opens the file in the context of the caller's session.
    ///
    /// The corresponding C constant is `FILE_FLAG_SESSION_AWARE`.
    @_alwaysEmitIntoClient
    public static var sessionAware: FileFlags { FileFlags(rawValue: 0x0080_0000) }

    /// Overlapped handles are not supported.
    ///
    /// The synchronous I/O on ``Win32/FileHandle`` isn't memory-safe on an
    /// overlapped handle, so every open rejects this flag with
    /// ``Win32/Error/invalidParameter``, even when `FileFlags(rawValue:)`
    /// carries it.
    ///
    /// The corresponding C constant is `FILE_FLAG_OVERLAPPED`.
    @_alwaysEmitIntoClient
    @available(*, unavailable, message: "Overlapped handles are not supported")
    public static var overlapped: FileFlags { FileFlags(rawValue: _FILE_FLAG_OVERLAPPED) }
  }
}

// MARK: - File attributes

@available(System 199, *)
extension Win32 {
  /// A file's attributes: those to apply when a file is created, and those
  /// that queries such as ``Win32/FileHandle/information()`` report.
  ///
  /// Only some are meaningful at creation: ``normal``, ``readOnly``,
  /// ``hidden``, ``system``, ``archive``, ``temporary``, ``offline``, and
  /// ``encrypted``. The others, such as ``directory`` and
  /// ``reparsePoint``, describe a file that exists.
  ///
  /// `CreateFileW` takes these in the `FILE_ATTRIBUTE_*` part of its
  /// `dwFlagsAndAttributes` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct FileAttributes: OptionSet, Sendable, Hashable, Codable {
    /// The raw C attributes.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed attributes from raw C attributes.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// No other attributes.
    ///
    /// Valid only on its own. Requesting it has the same effect as
    /// requesting no attributes.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_NORMAL`.
    @_alwaysEmitIntoClient
    public static var normal: FileAttributes { FileAttributes(rawValue: 0x80) }

    /// The file is read-only.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_READONLY`.
    @_alwaysEmitIntoClient
    public static var readOnly: FileAttributes { FileAttributes(rawValue: 0x1) }

    /// The file is hidden from ordinary directory listings.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_HIDDEN`.
    @_alwaysEmitIntoClient
    public static var hidden: FileAttributes { FileAttributes(rawValue: 0x2) }

    /// The operating system uses the file.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_SYSTEM`.
    @_alwaysEmitIntoClient
    public static var system: FileAttributes { FileAttributes(rawValue: 0x4) }

    /// The file is marked for backup or removal.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_ARCHIVE`.
    @_alwaysEmitIntoClient
    public static var archive: FileAttributes { FileAttributes(rawValue: 0x20) }

    /// The file is temporary, so the system avoids writing its data to the
    /// device while enough cache memory is available.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_TEMPORARY`.
    @_alwaysEmitIntoClient
    public static var temporary: FileAttributes { FileAttributes(rawValue: 0x100) }

    /// The file's data isn't immediately available: it has been moved to
    /// offline storage.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_OFFLINE`.
    @_alwaysEmitIntoClient
    public static var offline: FileAttributes { FileAttributes(rawValue: 0x1000) }

    /// The file is encrypted.
    ///
    /// The corresponding C constant is `FILE_ATTRIBUTE_ENCRYPTED`.
    @_alwaysEmitIntoClient
    public static var encrypted: FileAttributes { FileAttributes(rawValue: 0x4000) }
  }
}

// MARK: - Opening

@available(System 199, *)
extension Win32.FileHandle {
  /// Opens or creates a file, device, or pipe.
  ///
  /// - Parameters:
  ///   - path: The path to open.
  ///   - access: The requested access rights. An empty set requests neither
  ///     read nor write access, which allows for querying metadata where a
  ///     read open could be denied.
  ///   - shareMode: How the file may be shared with other opens while this
  ///     handle is alive. The default is `[.read, .write, .delete]`, matching
  ///     POSIX `open` behavior. Pass `[]` for exclusive access, which is what
  ///     `CreateFileW` does for a `dwShareMode` of 0.
  ///   - disposition: Whether to create, open, or truncate. `.truncateExisting`
  ///     and `.createAlways` fail with ``Win32/Error/userMappedFile`` while a
  ///     view of the file is mapped.
  ///   - attributes: File attributes to apply when the file is created, or
  ///     when `.createAlways` overwrites an existing one. Otherwise ignored.
  ///     The default `[]` requests no attributes, as does `.normal`, which is
  ///     valid only on its own.
  ///     Overwriting a `.hidden` or `.system` file fails with `.accessDenied`
  ///     unless `attributes` matches those bits.
  ///   - flags: Caching, semantic, and lifetime flags for this handle.
  ///   - inheritable: Whether child processes created with handle inheritance
  ///     enabled receive a copy of this handle. Applies whether the file is
  ///     created or opened.
  ///   - securityDescriptor: The security descriptor to apply when the file
  ///     is created. Ignored when an existing file is opened. This descriptor
  ///     is borrowed, not consumed.
  ///   - templateFile: A handle whose attributes and extended attributes are
  ///     applied to a newly created file. Must have been opened with
  ///     ``Win32/AccessMask/genericRead``. Ignored when an existing file is
  ///     opened. This handle is borrowed, not consumed.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `flags` contains
  /// `FILE_FLAG_OVERLAPPED`, which ``Win32/FileHandle`` does not support.
  ///
  /// Unless `path` begins with `\\?\` or `\\.\`, it's resolved against the
  /// current directory and canonicalized first, and gets the `\\?\` prefix
  /// if it's long enough to need one, as
  /// ``Win32/fullPath(of:extendedLengthPrefix:)`` does.
  ///
  /// The corresponding C function is `CreateFileW`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    disposition: Win32.CreationDisposition = .openExisting,
    attributes: Win32.FileAttributes = [],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil,
    templateFile: borrowing Win32.FileHandle? = nil
  ) throws(Win32.Error) -> Win32.FileHandle {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    let rawTemplate: HANDLE?
    switch templateFile {
    case .some(let template): rawTemplate = template._handle
    case .none: rawTemplate = nil
    }
    let opened = try Win32._createFile(
      path,
      access: access.rawValue,
      shareMode: shareMode.rawValue,
      disposition: disposition.rawValue,
      flagsAndAttributes: attributes.rawValue | flags.rawValue,
      inheritable: inheritable,
      securityDescriptor: rawDescriptor,
      templateFile: rawTemplate
    ).get()
    return Win32.FileHandle(_owning: opened.handle)
  }

  /// The result of ``openOrCreate(_:access:shareMode:overwriteExisting:attributes:flags:inheritable:securityDescriptor:templateFile:)``.
  @frozen
  public struct OpenOrCreateResult: ~Copyable, Sendable {
    /// The open handle.
    public let handle: Win32.FileHandle

    /// Whether the file already existed.
    public let existed: Bool

    @_alwaysEmitIntoClient
    internal init(_handle handle: consuming Win32.FileHandle, existed: Bool) {
      self.handle = handle
      self.existed = existed
    }
  }

  /// Opens a file, creating it if it does not exist, and reports whether it
  /// already existed.
  ///
  /// - Parameters:
  ///   - overwriteExisting: Whether to overwrite the contents of a file that
  ///     already exists. `false` corresponds to `OPEN_ALWAYS`, and `true` to
  ///     `CREATE_ALWAYS`. `CREATE_ALWAYS` also applies `attributes` to an
  ///     existing file, and fails with ``Win32/Error/userMappedFile`` while a
  ///     view of the file is mapped.
  ///
  /// All other parameters and errors behave as they do on
  /// ``open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``.
  ///
  /// The corresponding C function is `CreateFileW`.
  @_alwaysEmitIntoClient
  public static func openOrCreate(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    overwriteExisting: Bool = false,
    attributes: Win32.FileAttributes = [],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil,
    templateFile: borrowing Win32.FileHandle? = nil
  ) throws(Win32.Error) -> OpenOrCreateResult {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    let rawTemplate: HANDLE?
    switch templateFile {
    case .some(let template): rawTemplate = template._handle
    case .none: rawTemplate = nil
    }
    let disposition: Win32.CreationDisposition =
      overwriteExisting ? .createAlways : .openAlways
    let opened = try Win32._createFile(
      path,
      access: access.rawValue,
      shareMode: shareMode.rawValue,
      disposition: disposition.rawValue,
      flagsAndAttributes: attributes.rawValue | flags.rawValue,
      inheritable: inheritable,
      securityDescriptor: rawDescriptor,
      templateFile: rawTemplate
    ).get()
    // On success, CreateFileW sets the last error to ERROR_ALREADY_EXISTS or
    // ERROR_SUCCESS, so a stale code can't read as "existed".
    return OpenOrCreateResult(
      _handle: Win32.FileHandle(_owning: opened.handle),
      existed: opened.lastError == Win32.Error.alreadyExists.rawValue)
  }
}

@available(System 199, *)
extension Win32.DirectoryHandle {
  /// Opens a directory.
  ///
  /// `FILE_FLAG_BACKUP_SEMANTICS` is added to `flags` automatically. Without
  /// that flag, `CreateFileW` fails on a directory.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `flags` contains
  /// `FILE_FLAG_OVERLAPPED`, which ``Win32/DirectoryHandle`` does not support.
  ///
  /// Throws ``Win32/Error/notADirectory`` if `path` is not a directory,
  /// after closing the handle it opened.
  ///
  /// The corresponding C function is `CreateFileW`.
  @_alwaysEmitIntoClient
  public static func open(
    _ path: FilePath,
    access: Win32.AccessMask = .listDirectory,
    shareMode: Win32.ShareMode = [.read, .write, .delete],
    flags: Win32.FileFlags = [],
    inheritable: Bool = false
  ) throws(Win32.Error) -> Win32.DirectoryHandle {
    let handle = try Win32._openDirectory(
      path,
      access: access.rawValue,
      shareMode: shareMode.rawValue,
      flags: flags.rawValue,
      inheritable: inheritable
    ).get()
    return Win32.DirectoryHandle(_owning: handle)
  }
}

@available(System 199, *)
extension Win32 {
  /// Opens a file with `CreateFileW`. For a handle with synchronous I/O,
  /// the default, it rejects `FILE_FLAG_OVERLAPPED`; for an overlapped one,
  /// it adds the flag.
  @usableFromInline
  internal static func _createFile(
    _ path: FilePath,
    access: DWORD,
    shareMode: DWORD,
    disposition: DWORD,
    flagsAndAttributes: DWORD,
    inheritable: Bool,
    securityDescriptor: PSECURITY_DESCRIPTOR?,
    templateFile: HANDLE?,
    overlapped: Bool = false
  ) -> Result<(handle: HANDLE, lastError: DWORD), Win32.Error> {
    var flagsAndAttributes = flagsAndAttributes
    if overlapped {
      flagsAndAttributes |= _FILE_FLAG_OVERLAPPED
    } else {
      // Checked on the combined value, so the bit can't arrive through
      // FileAttributes(rawValue:) either.
      guard flagsAndAttributes & _FILE_FLAG_OVERLAPPED == 0 else {
        return .failure(.invalidParameter)
      }
    }
    return _withCanonicalPath(path) { path in
      var securityAttributes = SECURITY_ATTRIBUTES(
        nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
        lpSecurityDescriptor: securityDescriptor,
        bInheritHandle: WindowsBool(inheritable))
      let handle = system_CreateFileW(
        path, access, shareMode, &securityAttributes, disposition,
        flagsAndAttributes, templateFile)
      // Captured at once: the next Win32 call on this thread replaces it.
      let lastError = GetLastError()
      guard let handle, handle != INVALID_HANDLE_VALUE else {
        return .failure(Win32.Error(lastError))
      }
      return .success((handle, lastError))
    }
  }

  @usableFromInline
  internal static func _openDirectory(
    _ path: FilePath,
    access: DWORD,
    shareMode: DWORD,
    flags: DWORD,
    inheritable: Bool
  ) -> Result<HANDLE, Win32.Error> {
    let handle: HANDLE
    switch _createFile(
      path,
      access: access,
      shareMode: shareMode,
      disposition: Win32.CreationDisposition.openExisting.rawValue,
      flagsAndAttributes: flags | Win32.FileFlags.backupSemantics.rawValue,
      inheritable: inheritable,
      securityDescriptor: nil,
      templateFile: nil
    ) {
    case .success(let opened): handle = opened.handle
    case .failure(let error): return .failure(error)
    }
    // FILE_FLAG_BACKUP_SEMANTICS lets CreateFileW open a directory, but
    // doesn't require one. FileStandardInfo needs no access rights.
    var info = FILE_STANDARD_INFO()
    guard system_GetFileInformationByHandleEx(
      handle, FileStandardInfo, &info, DWORD(MemoryLayout<FILE_STANDARD_INFO>.size)
    ) else {
      let error = Win32.Error(GetLastError())
      _ = system_CloseHandle(handle)
      return .failure(error)
    }
    guard info.Directory != 0 else {
      _ = system_CloseHandle(handle)
      return .failure(.notADirectory)
    }
    return .success(handle)
  }
}

// MARK: - Path canonicalization

/// The result of a Win32 call that reports a buffer too small by returning
/// the size it needs.
internal enum _Win32SizedResult<Success> {
  case success(Success)
  case failure(Win32.Error)
  case retry(capacity: Int)
}

/// Calls `body` with `path` as Win32 functions should receive it.
///
/// Like the `FileDescriptor` adapters, this resolves the path against the
/// current directory and collapses dot segments with `GetFullPathNameW`, then
/// canonicalizes it with `PathAllocCanonicalize`, except that a resolved path
/// beginning with `\\.\` isn't canonicalized. Unlike the adapters, it passes
/// a path that begins with `\\?\` or `\\.\` through untouched: `\\?\` means
/// "pass this path through verbatim". `prefix` says when the result gets the
/// `\\?\` prefix: by default, at `CreateDirectoryW`'s limit, the lowest of
/// the path functions', whether or not the process is long-path aware, where
/// the adapters' `PATHCCH_ALLOW_LONG_PATHS` adds it only past `MAX_PATH`, and
/// only in a process that isn't.
internal func _withCanonicalPath<Success>(
  _ path: FilePath,
  prefix: Win32.ExtendedLengthPrefix = .whenNeeded,
  _ body: (UnsafePointer<WCHAR>) -> Result<Success, Win32.Error>
) -> Result<Success, Win32.Error> {
  path.withPlatformString { path -> Result<Success, Win32.Error> in
    if _isVerbatimOrDevicePath(path) { return body(path) }
    var capacity = _win32MaxPath + 1
    while true {
      let outcome = withUnsafeTemporaryAllocation(
        of: WCHAR.self, capacity: capacity
      ) { buffer -> _Win32SizedResult<Result<Success, Win32.Error>> in
        let length = system_GetFullPathNameW(
          path, DWORD(buffer.count), buffer.baseAddress, nil)
        guard length != 0 else { return .failure(Win32.Error(GetLastError())) }
        // A buffer that's too small gets the size needed, including the
        // terminator. The current directory can change between calls, so
        // this may take more than one retry.
        guard Int(length) < buffer.count else { return .retry(capacity: Int(length)) }
        let fullPath = UnsafePointer(buffer.baseAddress!)
        // A DOS device name, such as NUL, resolves to a \\.\ path, which
        // PathAllocCanonicalize would mangle.
        if _isVerbatimOrDevicePath(fullPath) { return .success(body(fullPath)) }
        let flags: ULONG
        switch prefix {
        case .never:
          return .success(body(fullPath))
        case .whenNeeded:
          // The length doesn't count the terminator, and the limit does.
          flags = Int(length) + 1 >= _win32DirectoryMaxPath
            ? _PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH : _PATHCCH_ALLOW_LONG_PATHS
        case .always:
          flags = _PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH
        }
        return .success(_withCanonicalizedPath(fullPath, flags: flags, body))
      }
      switch outcome {
      case .success(let result): return result
      case .failure(let error): return .failure(error)
      case .retry(let needed): capacity = needed
      }
    }
  }
}

/// Whether `path` begins with `\\?\` or `\\.\`.
internal func _isVerbatimOrDevicePath(_ path: UnsafePointer<WCHAR>) -> Bool {
  let backslash = WCHAR(UInt8(ascii: "\\"))
  // Each comparison reads an element only if the one before it wasn't the
  // terminator.
  return path[0] == backslash && path[1] == backslash
    && (path[2] == WCHAR(UInt8(ascii: "?")) || path[2] == WCHAR(UInt8(ascii: ".")))
    && path[3] == backslash
}

internal func _withCanonicalizedPath<Success>(
  _ fullPath: UnsafePointer<WCHAR>,
  flags: ULONG,
  _ body: (UnsafePointer<WCHAR>) -> Result<Success, Win32.Error>
) -> Result<Success, Win32.Error> {
  var canonical: PWSTR? = nil
  let result = system_PathAllocCanonicalize(fullPath, flags, &canonical)
  defer {
    if let canonical { _ = system_LocalFree(canonical) }
  }
  guard result >= 0, let canonical else {
    return .failure(Win32.Error(_win32Error(fromHRESULT: result)))
  }
  return body(canonical)
}

/// The Win32 error code in a failed `HRESULT`.
///
/// An `HRESULT` in `FACILITY_WIN32` carries a Win32 error code in its low
/// 16 bits. Any other failure is returned as it is: its severity bit is set,
/// and Windows treats such a code as an `HRESULT` wherever it expects a
/// system error code.
internal func _win32Error(fromHRESULT result: HRESULT) -> DWORD {
  Win32.HResult(rawValue: result).win32Error?.rawValue ?? DWORD(bitPattern: result)
}

#endif // os(Windows)
