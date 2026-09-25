/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// STAND-IN, simulated configuration only. The `Win32` namespace and
// `Win32.Error` from draft SYS-0010, and the value types that SYS-0011 to
// SYS-0016 add to the namespace. On Windows these would come from System.
// Shapes follow the drafts, except that everything here is internal, so
// nothing is `@frozen` or `public`. The draft details the samples depend on
// are listed in Prototype/PlatformEnum/README.md.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The C `DWORD` type.
typealias DWORD = UInt32

/// The C `HANDLE` type, which is `void *`.
typealias HANDLE = UnsafeMutableRawPointer

/// A namespace for Win32 APIs on Windows (SYS-0010).
enum Win32 {}

// MARK: - Win32.Error (SYS-0010)

extension Win32 {
  /// A Windows system error code.
  ///
  /// This represents a value reported by `GetLastError`.
  struct Error: RawRepresentable, Swift.Error, Sendable, Hashable, Codable {
    /// The raw C error code.
    let rawValue: DWORD

    /// Creates a strongly-typed error from a raw C error code.
    init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Creates a strongly-typed error from a raw C error code.
    init(_ rawValue: DWORD) { self.rawValue = rawValue }

    static var success: Error { Error(0) }                      // ERROR_SUCCESS
    static var invalidFunction: Error { Error(1) }              // ERROR_INVALID_FUNCTION
    static var fileNotFound: Error { Error(2) }                 // ERROR_FILE_NOT_FOUND
    static var pathNotFound: Error { Error(3) }                 // ERROR_PATH_NOT_FOUND
    static var accessDenied: Error { Error(5) }                 // ERROR_ACCESS_DENIED
    static var invalidHandle: Error { Error(6) }                // ERROR_INVALID_HANDLE
    static var deviceNotReady: Error { Error(21) }              // ERROR_NOT_READY
    static var cyclicRedundancyCheck: Error { Error(23) }       // ERROR_CRC
    static var writeFault: Error { Error(29) }                  // ERROR_WRITE_FAULT
    static var sharingViolation: Error { Error(32) }            // ERROR_SHARING_VIOLATION
    static var lockViolation: Error { Error(33) }               // ERROR_LOCK_VIOLATION
    static var endOfFile: Error { Error(38) }                   // ERROR_HANDLE_EOF
    static var notSupported: Error { Error(50) }                // ERROR_NOT_SUPPORTED
    static var fileExists: Error { Error(80) }                  // ERROR_FILE_EXISTS
    static var invalidParameter: Error { Error(87) }            // ERROR_INVALID_PARAMETER
    static var brokenPipe: Error { Error(109) }                 // ERROR_BROKEN_PIPE
    static var diskFull: Error { Error(112) }                   // ERROR_DISK_FULL
    static var insufficientBuffer: Error { Error(122) }         // ERROR_INSUFFICIENT_BUFFER
    static var invalidName: Error { Error(123) }                // ERROR_INVALID_NAME
    static var negativeSeek: Error { Error(131) }               // ERROR_NEGATIVE_SEEK
    static var notLocked: Error { Error(158) }                  // ERROR_NOT_LOCKED
    static var badPathName: Error { Error(161) }                // ERROR_BAD_PATHNAME
    static var alreadyExists: Error { Error(183) }              // ERROR_ALREADY_EXISTS
    static var fileTooLarge: Error { Error(223) }               // ERROR_FILE_TOO_LARGE
    static var pipeBusy: Error { Error(231) }                   // ERROR_PIPE_BUSY
    static var noData: Error { Error(232) }                     // ERROR_NO_DATA
    static var pipeNotConnected: Error { Error(233) }           // ERROR_PIPE_NOT_CONNECTED
    static var moreData: Error { Error(234) }                   // ERROR_MORE_DATA
    static var notADirectory: Error { Error(267) }              // ERROR_DIRECTORY
    static var operationAborted: Error { Error(995) }           // ERROR_OPERATION_ABORTED
    static var ioPending: Error { Error(997) }                  // ERROR_IO_PENDING
    static var userMappedFile: Error { Error(1224) }            // ERROR_USER_MAPPED_FILE
    static var cannotResolveFileName: Error { Error(1921) }     // ERROR_CANT_RESOLVE_FILENAME

    /// A write that succeeded without transferring anything.
    /// System synthesizes this code; Windows never reports it.
    static var incompleteTransfer: Error { Error(0xA053_5901) }

    /// Whether System synthesized this error instead of Windows reporting it.
    ///
    /// The simulation's own codes, for errno values it doesn't map
    /// (`Win32Simulation.error(from:)`), count as synthesized too.
    var isSynthesized: Bool {
      rawValue & 0xFFFF_FF00 == 0xA053_5900 || Win32Simulation.isSimulatedCode(rawValue)
    }
  }
}

extension Win32.Error: CustomStringConvertible, CustomDebugStringConvertible {
  /// The system's message for this code.
  ///
  /// On Windows this comes from `FormatMessageW`. The stand-in uses a table
  /// of the English messages.
  var description: String {
    if let entry = Win32.Error._names[rawValue] { return entry.message }
    if Win32Simulation.isSimulatedCode(rawValue) {
      return Win32Simulation.describeSimulatedCode(rawValue)
    }
    return "Unknown error (0x\(String(rawValue, radix: 16)))"
  }

  /// The symbolic constant, with the decimal and hexadecimal value,
  /// such as `ERROR_SHARING_VIOLATION (32, 0x20)`.
  var debugDescription: String {
    let hex = "0x" + String(rawValue, radix: 16, uppercase: true)
    guard let entry = Win32.Error._names[rawValue] else { return "\(rawValue) (\(hex))" }
    return "\(entry.symbol) (\(rawValue), \(hex))"
  }

  fileprivate static let _names: [DWORD: (symbol: String, message: String)] = [
    0: ("ERROR_SUCCESS", "The operation completed successfully."),
    1: ("ERROR_INVALID_FUNCTION", "Incorrect function."),
    2: ("ERROR_FILE_NOT_FOUND", "The system cannot find the file specified."),
    3: ("ERROR_PATH_NOT_FOUND", "The system cannot find the path specified."),
    5: ("ERROR_ACCESS_DENIED", "Access is denied."),
    6: ("ERROR_INVALID_HANDLE", "The handle is invalid."),
    21: ("ERROR_NOT_READY", "The device is not ready."),
    23: ("ERROR_CRC", "Data error (cyclic redundancy check)."),
    29: ("ERROR_WRITE_FAULT", "The system cannot write to the specified device."),
    32: ("ERROR_SHARING_VIOLATION",
         "The process cannot access the file because it is being used by another process."),
    33: ("ERROR_LOCK_VIOLATION",
         "The process cannot access the file because another process has locked a portion of the file."),
    38: ("ERROR_HANDLE_EOF", "Reached the end of the file."),
    50: ("ERROR_NOT_SUPPORTED", "The request is not supported."),
    80: ("ERROR_FILE_EXISTS", "The file exists."),
    87: ("ERROR_INVALID_PARAMETER", "The parameter is incorrect."),
    109: ("ERROR_BROKEN_PIPE", "The pipe has been ended."),
    112: ("ERROR_DISK_FULL", "There is not enough space on the disk."),
    122: ("ERROR_INSUFFICIENT_BUFFER", "The data area passed to a system call is too small."),
    123: ("ERROR_INVALID_NAME", "The filename, directory name, or volume label syntax is incorrect."),
    131: ("ERROR_NEGATIVE_SEEK",
          "An attempt was made to move the file pointer before the beginning of the file."),
    158: ("ERROR_NOT_LOCKED", "The segment is already unlocked."),
    161: ("ERROR_BAD_PATHNAME", "The specified path is invalid."),
    183: ("ERROR_ALREADY_EXISTS", "Cannot create a file when that file already exists."),
    223: ("ERROR_FILE_TOO_LARGE", "The file size exceeds the limit allowed and cannot be saved."),
    231: ("ERROR_PIPE_BUSY", "All pipe instances are busy."),
    232: ("ERROR_NO_DATA", "The pipe is being closed."),
    233: ("ERROR_PIPE_NOT_CONNECTED", "No process is on the other end of the pipe."),
    234: ("ERROR_MORE_DATA", "More data is available."),
    259: ("STILL_ACTIVE", "No more data is available."),
    267: ("ERROR_DIRECTORY", "The directory name is invalid."),
    995: ("ERROR_OPERATION_ABORTED",
          "The I/O operation has been aborted because of either a thread exit or an application request."),
    997: ("ERROR_IO_PENDING", "Overlapped I/O operation is in progress."),
    1224: ("ERROR_USER_MAPPED_FILE",
           "The requested operation cannot be performed on a file with a user-mapped section open."),
    1921: ("ERROR_CANT_RESOLVE_FILENAME", "The name of the file cannot be resolved by the system."),
    10035: ("WSAEWOULDBLOCK", "A non-blocking socket operation could not be completed immediately."),
    10053: ("WSAECONNABORTED",
            "An established connection was aborted by the software in your host machine."),
    10054: ("WSAECONNRESET", "An existing connection was forcibly closed by the remote host."),
    10057: ("WSAENOTCONN",
            "A request to send or receive data was disallowed because the socket is not connected."),
    10058: ("WSAESHUTDOWN",
            "A request to send or receive data was disallowed because the socket had already been shut down."),
    0xA053_5901: ("incompleteTransfer", "The transfer ended before every byte was written."),
  ]
}

extension Win32.Error {
  /// Lets a `catch` clause match a `Win32.Error` pattern against an untyped
  /// error, as `Errno`'s operator does.
  ///
  /// As drafted, this isn't `@_disfavoredOverload`. Together with `Errno`'s
  /// `~=`, it makes a typed `catch .fileExists` ambiguous (V16f), which is
  /// why the samples spell `catch Errno.fileExists` and
  /// `catch Win32.Error.fileExists`.
  static func ~= (_ lhs: Win32.Error, _ rhs: Swift.Error) -> Bool {
    guard let value = rhs as? Win32.Error else { return false }
    return lhs == value
  }
}

// MARK: - Errno(approximating:) (SYS-0010)

extension Errno {
  /// The closest POSIX equivalent of a Windows system error.
  ///
  /// This mapping is lossy. It approximates the C runtime's `_dosmaperr`
  /// behavior, which folds Windows' several thousand system error codes onto
  /// sixteen `Errno` values. Unrecognized codes become
  /// ``Errno/invalidArgument``. Prefer handling ``Win32/Error`` directly.
  init(approximating error: Win32.Error) {
    switch error.rawValue {
    case 1: self = .invalidArgument                      // ERROR_INVALID_FUNCTION
    case 2, 3, 15, 18, 53, 67, 161, 206: self = .noSuchFileOrDirectory
    case 4: self = .tooManyOpenFiles
    case 5, 65, 82, 83, 108, 158, 167: self = .permissionDenied
    case 6, 114: self = .badFileDescriptor
    case 8, 9, 10, 1816: self = .noMemory
    case 17: self = .improperLink                        // ERROR_NOT_SAME_DEVICE
    case 19...36: self = .permissionDenied               // write protect ... sharing buffer exceeded
    case 80, 183: self = .fileExists
    case 87: self = .invalidArgument
    case 89, 164, 215: self = .resourceTemporarilyUnavailable
    case 109: self = .brokenPipe
    case 112: self = .noSpace
    case 131: self = .invalidArgument                    // ERROR_NEGATIVE_SEEK
    case 132: self = .permissionDenied                   // ERROR_SEEK_ON_DEVICE
    case 145: self = .directoryNotEmpty
    case 188...202: self = .execFormatError
    default: self = .invalidArgument
    }
  }
}

// MARK: - Opening (SYS-0011)

extension Win32 {
  /// The access rights `CreateFileW` accepts in `dwDesiredAccess`.
  struct AccessMask: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var genericRead: AccessMask { AccessMask(rawValue: 0x8000_0000) }
    static var genericWrite: AccessMask { AccessMask(rawValue: 0x4000_0000) }
    static var genericExecute: AccessMask { AccessMask(rawValue: 0x2000_0000) }
    static var genericAll: AccessMask { AccessMask(rawValue: 0x1000_0000) }
    static var maximumAllowed: AccessMask { AccessMask(rawValue: 0x0200_0000) }

    static var delete: AccessMask { AccessMask(rawValue: 0x0001_0000) }
    static var readControl: AccessMask { AccessMask(rawValue: 0x0002_0000) }
    static var writeDAC: AccessMask { AccessMask(rawValue: 0x0004_0000) }
    static var writeOwner: AccessMask { AccessMask(rawValue: 0x0008_0000) }
    static var synchronize: AccessMask { AccessMask(rawValue: 0x0010_0000) }

    static var readData: AccessMask { AccessMask(rawValue: 0x1) }
    static var listDirectory: AccessMask { AccessMask(rawValue: 0x1) }
    static var writeData: AccessMask { AccessMask(rawValue: 0x2) }
    static var addFile: AccessMask { AccessMask(rawValue: 0x2) }
    static var appendData: AccessMask { AccessMask(rawValue: 0x4) }
    static var addSubdirectory: AccessMask { AccessMask(rawValue: 0x4) }
    static var readExtendedAttributes: AccessMask { AccessMask(rawValue: 0x8) }
    static var writeExtendedAttributes: AccessMask { AccessMask(rawValue: 0x10) }
    static var execute: AccessMask { AccessMask(rawValue: 0x20) }
    static var traverse: AccessMask { AccessMask(rawValue: 0x20) }
    static var deleteChild: AccessMask { AccessMask(rawValue: 0x40) }
    static var readAttributes: AccessMask { AccessMask(rawValue: 0x80) }
    static var writeAttributes: AccessMask { AccessMask(rawValue: 0x100) }

    /// Whether the mask grants reading data, directly or generically.
    var readsData: Bool {
      !isDisjoint(with: [.genericRead, .genericAll, .readData, .maximumAllowed])
    }

    /// Whether the mask grants writing or appending data.
    var writesData: Bool {
      !isDisjoint(with: [.genericWrite, .genericAll, .writeData, .appendData, .maximumAllowed])
    }

    /// Whether the mask grants deleting the file.
    var deletes: Bool { !isDisjoint(with: [.delete, .genericAll, .maximumAllowed]) }
  }

  /// How a file may be shared with other opens while a handle is alive.
  struct ShareMode: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var read: ShareMode { ShareMode(rawValue: 0x1) }    // FILE_SHARE_READ
    static var write: ShareMode { ShareMode(rawValue: 0x2) }   // FILE_SHARE_WRITE
    static var delete: ShareMode { ShareMode(rawValue: 0x4) }  // FILE_SHARE_DELETE
  }

  /// Whether to create, open, or truncate. The five choices are exclusive.
  struct CreationDisposition: RawRepresentable, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var createNew: CreationDisposition { CreationDisposition(rawValue: 1) }
    static var createAlways: CreationDisposition { CreationDisposition(rawValue: 2) }
    static var openExisting: CreationDisposition { CreationDisposition(rawValue: 3) }
    static var openAlways: CreationDisposition { CreationDisposition(rawValue: 4) }
    static var truncateExisting: CreationDisposition { CreationDisposition(rawValue: 5) }
  }

  /// Caching, semantic, and lifetime flags for a handle.
  struct FileFlags: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var writeThrough: FileFlags { FileFlags(rawValue: 0x8000_0000) }
    static var noBuffering: FileFlags { FileFlags(rawValue: 0x2000_0000) }
    static var randomAccess: FileFlags { FileFlags(rawValue: 0x1000_0000) }
    static var sequentialScan: FileFlags { FileFlags(rawValue: 0x0800_0000) }
    static var deleteOnClose: FileFlags { FileFlags(rawValue: 0x0400_0000) }
    static var backupSemantics: FileFlags { FileFlags(rawValue: 0x0200_0000) }
    static var posixSemantics: FileFlags { FileFlags(rawValue: 0x0100_0000) }
    static var sessionAware: FileFlags { FileFlags(rawValue: 0x0080_0000) }
    static var openReparsePoint: FileFlags { FileFlags(rawValue: 0x0020_0000) }
    static var openNoRecall: FileFlags { FileFlags(rawValue: 0x0010_0000) }

    @available(*, unavailable, message: "Overlapped handles are not supported")
    static var overlapped: FileFlags { FileFlags(rawValue: 0x4000_0000) }

    static var _overlappedBit: DWORD { 0x4000_0000 }
  }

  /// File attributes to apply when a file is created.
  struct FileAttributes: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var readOnly: FileAttributes { FileAttributes(rawValue: 0x1) }
    static var hidden: FileAttributes { FileAttributes(rawValue: 0x2) }
    static var system: FileAttributes { FileAttributes(rawValue: 0x4) }
    static var archive: FileAttributes { FileAttributes(rawValue: 0x20) }
    static var normal: FileAttributes { FileAttributes(rawValue: 0x80) }
    static var temporary: FileAttributes { FileAttributes(rawValue: 0x100) }
    static var offline: FileAttributes { FileAttributes(rawValue: 0x1000) }
    static var encrypted: FileAttributes { FileAttributes(rawValue: 0x4000) }
  }

  /// A Windows security descriptor, owned (SYS-0011).
  ///
  /// The stand-in only records the SDDL string; the simulation ignores it.
  struct SecurityDescriptor: ~Copyable, Sendable {
    let sddl: String

    /// Parses a Security Descriptor Definition Language string.
    init(sddl: String) throws(Win32.Error) {
      guard !sddl.isEmpty else { throw .invalidParameter }
      self.sddl = sddl
    }
  }
}

// MARK: - File type (SYS-0012)

extension Win32 {
  /// The class of device a handle refers to.
  struct FileType: RawRepresentable, Sendable, Hashable, Codable, CustomStringConvertible {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }
    init(_ rawValue: DWORD) { self.rawValue = rawValue }

    static var disk: FileType { FileType(1) }       // FILE_TYPE_DISK
    static var character: FileType { FileType(2) }  // FILE_TYPE_CHAR
    static var pipe: FileType { FileType(3) }       // FILE_TYPE_PIPE
    static var unknown: FileType { FileType(0) }    // FILE_TYPE_UNKNOWN

    var description: String {
      switch self {
      case .disk: return "disk"
      case .character: return "character"
      case .pipe: return "pipe"
      case .unknown: return "unknown"
      default: return "FileType(\(rawValue))"
      }
    }
  }
}

// MARK: - Seeking (SYS-0013) and locking (SYS-0014)

extension Win32 {
  /// The reference point that a seek offset is measured from.
  struct SeekOrigin: RawRepresentable, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var start: SeekOrigin { SeekOrigin(rawValue: 0) }    // FILE_BEGIN
    static var current: SeekOrigin { SeekOrigin(rawValue: 1) }  // FILE_CURRENT
    static var end: SeekOrigin { SeekOrigin(rawValue: 2) }      // FILE_END
  }

  /// Whether a byte-range lock admits other holders.
  enum LockMode: Sendable, Hashable, Codable {
    /// A shared, or read, lock. It denies write access to the range for
    /// every process, including the one that took it.
    case shared
    /// An exclusive, or write, lock.
    case exclusive
  }
}

// MARK: - Volume information (SYS-0015) and final path (SYS-0016)

extension Win32 {
  /// Information about a file system volume.
  struct VolumeInformation: Sendable, Hashable, Codable {
    var name: String
    var fileSystemName: String
    var serialNumber: UInt32
    var maximumComponentLength: Int
    var flags: FileSystemFlags
  }

  /// Features a file system may support. A subset of the draft's members.
  struct FileSystemFlags: OptionSet, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var caseSensitiveSearch: FileSystemFlags { FileSystemFlags(rawValue: 0x1) }
    static var casePreservedNames: FileSystemFlags { FileSystemFlags(rawValue: 0x2) }
    static var unicodeOnDisk: FileSystemFlags { FileSystemFlags(rawValue: 0x4) }
    static var persistentACLs: FileSystemFlags { FileSystemFlags(rawValue: 0x8) }
    static var supportsSparseFiles: FileSystemFlags { FileSystemFlags(rawValue: 0x40) }
    static var supportsReparsePoints: FileSystemFlags { FileSystemFlags(rawValue: 0x80) }
    static var readOnlyVolume: FileSystemFlags { FileSystemFlags(rawValue: 0x8_0000) }
    static var supportsHardLinks: FileSystemFlags { FileSystemFlags(rawValue: 0x40_0000) }
    static var supportsExtendedAttributes: FileSystemFlags { FileSystemFlags(rawValue: 0x80_0000) }
  }

  /// How the volume component of a resolved path is spelled.
  struct VolumeNameFormat: RawRepresentable, Sendable, Hashable, Codable {
    var rawValue: DWORD
    init(rawValue: DWORD) { self.rawValue = rawValue }

    static var dos: VolumeNameFormat { VolumeNameFormat(rawValue: 0x0) }             // VOLUME_NAME_DOS
    static var guid: VolumeNameFormat { VolumeNameFormat(rawValue: 0x1) }            // VOLUME_NAME_GUID
    static var nt: VolumeNameFormat { VolumeNameFormat(rawValue: 0x2) }              // VOLUME_NAME_NT
    static var volumeRelative: VolumeNameFormat { VolumeNameFormat(rawValue: 0x4) }  // VOLUME_NAME_NONE
  }
}

#endif // SIMULATE_PLATFORMS
