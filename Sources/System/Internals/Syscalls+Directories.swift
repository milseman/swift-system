/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The directory stream calls that Syscalls.swift doesn't already wrap, and
// the internals that `DirectoryStream` and `DirectoryWalk` share. The rest,
// fdopendir, readdir, rewinddir and closedir, are in Syscalls.swift, where
// the temporary-directory helpers use them.
//
// None of the directory stream wrappers has a mock hook. They return
// pointers, or can't fail, so the mocking driver can't stand in for them,
// as with readdir. The directory API has real-call tests instead.

#if !os(Windows) && !os(WASI)

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

internal func system_opendir(
  _ path: UnsafePointer<CInterop.PlatformChar>
) -> system_DIRPtr? {
  opendir(path)
}

internal func system_dirfd(_ dir: system_DIRPtr) -> CInt {
  dirfd(dir)
}

// The d_type values. They're here rather than in Constants.swift, which
// another lane owns.
internal var _DT_UNKNOWN: CInt { CInt(DT_UNKNOWN) }
internal var _DT_FIFO: CInt { CInt(DT_FIFO) }
internal var _DT_CHR: CInt { CInt(DT_CHR) }
internal var _DT_DIR: CInt { CInt(DT_DIR) }
internal var _DT_BLK: CInt { CInt(DT_BLK) }
internal var _DT_REG: CInt { CInt(DT_REG) }
internal var _DT_LNK: CInt { CInt(DT_LNK) }
internal var _DT_SOCK: CInt { CInt(DT_SOCK) }
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
internal var _DT_WHT: CInt { CInt(DT_WHT) }
#endif

/// Calls a function that returns `NULL` and sets `errno` on failure,
/// such as `opendir`, and retries it on `EINTR` if asked to.
internal func _pointerOrErrno<Pointer>(
  retryOnInterrupt: Bool, _ f: () -> Pointer?
) -> Result<Pointer, Errno> {
  while true {
    if let pointer = f() { return .success(pointer) }
    let error = Errno(rawValue: system_errno)
    guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
  }
}

/// Opens a directory stream for a directory relative to another,
/// with `openat` and then `fdopendir`, closing the descriptor
/// if `fdopendir` fails.
///
/// C has no `opendirat`. The stream always has `O_RDONLY`, `O_DIRECTORY`,
/// and `O_CLOEXEC`, as `opendir` does, and `options` adds to them.
internal func _openDirectoryStream(
  _ path: UnsafePointer<CInterop.PlatformChar>,
  relativeTo fd: CInt,
  options: CInt,
  retryOnInterrupt: Bool
) -> Result<system_DIRPtr, Errno> {
  let flags = _O_RDONLY | _O_DIRECTORY | _O_CLOEXEC | options
  let opened = valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
    system_openat(fd, path, flags)
  }
  switch opened {
  case .failure(let error):
    return .failure(error)
  case .success(let descriptor):
    guard let dir = system_fdopendir(descriptor) else {
      let error = Errno(rawValue: system_errno)
      _ = system_close(descriptor)
      return .failure(error)
    }
    return .success(dir)
  }
}

/// Reads the next entry from a directory stream, skipping `.` and `..`,
/// and returns `nil` at the end.
///
/// `readdir` returns `NULL` both at the end and on failure, and sets `errno`
/// only on failure, so `errno` is cleared before each call. Retrying on
/// `EINTR` is safe: a failed `readdir` hasn't consumed an entry.
internal func _readDirectoryEntry(
  _ dir: system_DIRPtr, retryOnInterrupt: Bool
) -> Result<UnsafeMutablePointer<system_dirent>?, Errno> {
  while true {
    system_errno = 0
    guard let entry = system_readdir(dir) else {
      let error = system_errno
      if error == 0 { return .success(nil) }
      if retryOnInterrupt && error == Errno.interrupted.rawValue { continue }
      return .failure(Errno(rawValue: error))
    }
    let name = _directoryEntryName(entry)
    // Skip `.` and `..`, and an empty name, which no file system should
    // return, but which a FilePath.Component can't hold.
    if name[0] == 0 { continue }
    if name[0] == 0x2E && (name[1] == 0 || (name[1] == 0x2E && name[2] == 0)) {
      continue
    }
    return .success(entry)
  }
}

/// The entry's name, a null-terminated C string within the entry.
///
/// This reads `d_name` through its offset rather than by value: a record is
/// only as long as its name, often shorter than `sizeof(struct dirent)`,
/// so copying the whole structure can read past the end of the stream's
/// buffer.
internal func _directoryEntryName(
  _ entry: UnsafeMutablePointer<system_dirent>
) -> UnsafePointer<CInterop.PlatformChar> {
  let offset = MemoryLayout<system_dirent>.offset(of: \.d_name)!
  return UnsafeRawPointer(entry).advanced(by: offset)
    .assumingMemoryBound(to: CInterop.PlatformChar.self)
}

/// The length of the entry's name, not counting its null terminator.
internal func _directoryEntryNameLength(
  _ entry: UnsafeMutablePointer<system_dirent>
) -> Int {
  #if SYSTEM_PACKAGE_DARWIN
  return Int(entry.pointee.d_namlen)
  #else
  return system_platform_strlen(_directoryEntryName(entry))
  #endif
}

/// The entry's inode number.
internal func _directoryEntryInode(
  _ entry: UnsafeMutablePointer<system_dirent>
) -> ino_t {
  #if os(FreeBSD) || os(OpenBSD)
  return entry.pointee.d_fileno
  #else
  return entry.pointee.d_ino
  #endif
}

extension SystemString {
  /// Replaces the contents with a copy of a null-terminated platform string
  /// of `length` characters.
  ///
  /// If nothing else shares the storage, this writes in place and allocates
  /// nothing once the storage is long enough; otherwise it allocates new
  /// storage, and whatever shares the old storage keeps its contents.
  internal mutating func _replaceContents(
    withPlatformString platformString: UnsafePointer<CInterop.PlatformChar>,
    length: Int
  ) {
    nullTerminatedStorage.removeAll(keepingCapacity: true)
    platformString.withMemoryRebound(to: SystemChar.self, capacity: length + 1) {
      nullTerminatedStorage.append(
        contentsOf: UnsafeBufferPointer(start: $0, count: length + 1))
    }
  }
}

extension FilePath.Component {
  /// A component whose storage is exactly `name`, which must hold a single
  /// component, such as a directory entry's name: not empty, not `.` or `..`,
  /// and without a separator.
  ///
  /// The component shares `name`'s storage rather than copying it.
  internal init(_directoryEntryName name: SystemString) {
    let path = FilePath(_directoryEntryName: name)
    self.init(path, path._storage.startIndex..<path._storage.endIndex)
  }

  /// Calls `body` with the component as a null-terminated platform string,
  /// without copying it when it ends where its storage does, as a directory
  /// entry's name does.
  ///
  /// `withPlatformString(_:)` always copies (see its FIXME in
  /// SystemString.swift).
  internal func _withPlatformStringInPlace<Result>(
    _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> Result
  ) rethrows -> Result {
    guard _range.lowerBound == _path._storage.startIndex,
          _range.upperBound == _path._storage.endIndex
    else {
      return try withPlatformString(body)
    }
    return try _path._storage.withPlatformString(body)
  }
}

extension FilePath {
  /// A relative path of one component, whose storage is `name`.
  ///
  /// This skips `init(_:)`'s separator normalization,
  /// which a directory entry's name doesn't need.
  internal init(_directoryEntryName name: SystemString) {
    self._storage = name
    _invariantCheck()
  }
}

@available(System 1.7.0, *)
extension FileType {
  /// The file type that a directory entry's `d_type` names,
  /// or `nil` for `DT_UNKNOWN` or a type that `FileType` can't represent.
  internal init?(_directoryEntryType type: UInt8) {
    switch CInt(type) {
    case _DT_REG: self = .regular
    case _DT_DIR: self = .directory
    case _DT_LNK: self = .symbolicLink
    case _DT_FIFO: self = .fifo
    case _DT_SOCK: self = .socket
    case _DT_CHR: self = .characterSpecial
    case _DT_BLK: self = .blockSpecial
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    case _DT_WHT: self = .whiteout
    #endif
    default: return nil
    }
  }
}

#endif // !os(Windows) && !os(WASI)
