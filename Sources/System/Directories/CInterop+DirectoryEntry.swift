/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// C's directory entry, for code whose own API names it, such as an extension
// of it: a public name, and Swift-named accessors, which a client that
// doesn't import the C library can read under MemberImportVisibility.
// DirectoryStream and DirectoryWalk copy what they read into entries of
// their own.

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

@available(System 199, *)
extension CInterop {
  /// A directory's entry, as `readdir` returns it:
  /// a file's name in the directory, its type, and its inode number.
  ///
  /// ``DirectoryStream`` reads entries into ``DirectoryStream/Entry`` values,
  /// which own their names; this is the C structure,
  /// for code that has one from C, or whose own API names it.
  ///
  /// The corresponding C type is `struct dirent`.
  public typealias DirectoryEntry = dirent
}

@available(System 199, *)
extension CInterop.DirectoryEntry {
  /// The file's name in the directory,
  /// or `nil` if the entry has none, as a zero entry doesn't.
  ///
  /// A directory's `.` and `..` entries have those names.
  ///
  /// The corresponding C field is `d_name`.
  @_alwaysEmitIntoClient
  public var fileName: FilePath.Component? { _fileName }

  @usableFromInline
  internal var _fileName: FilePath.Component? {
    withUnsafePointer(to: self) { entry in
      FilePath.Component(platformString: _directoryEntryName(UnsafeMutablePointer(mutating: entry)))
    }
  }

  /// The file's type, or `nil` if the directory doesn't record it.
  ///
  /// See ``DirectoryStream/Entry/type``.
  ///
  /// The corresponding C field is `d_type`,
  /// which is `DT_UNKNOWN` when this property is `nil`.
  @_alwaysEmitIntoClient
  public var fileType: FileType? { FileType(directoryEntryType: d_type) }

  /// The file's inode number.
  ///
  /// The corresponding C field is `d_ino`
  /// (`d_fileno` on FreeBSD and OpenBSD).
  @_alwaysEmitIntoClient
  public var inode: Inode { _inode }

  @usableFromInline
  internal var _inode: Inode {
    withUnsafePointer(to: self) { Inode(_directoryEntryInode(UnsafeMutablePointer(mutating: $0))) }
  }
}

#endif // !os(Windows) && !os(WASI)
