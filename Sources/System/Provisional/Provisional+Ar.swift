/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Provisional: the archive format's header, <ar.h>: the `ar` format that
// static libraries use.
//
// System wraps <ar.h> provisionally. It's a file format, not an
// operating-system interface, and its lasting home is a library that reads
// archives and object files, as the Mach-O structures' is (see
// Provisional+MachO.swift, whose static libraries are archives). Until
// there's one, code that reads a static library's members, as swift-build
// does, can read their headers without importing the C library. The header
// is the C structure, with accessors that parse its fields, which are text,
// and the constants are statics of a namespace, ArchiveFile. Every
// platform's headers but Windows' declare it; glibc's, the BSDs' and WASI's
// Swift modules don't include it, so there CSystem's headers do.

#if !os(Windows)

// Must import here to read ar_hdr's fields in @_alwaysEmitIntoClient
// accessors.
#if SYSTEM_PACKAGE_DARWIN
import Darwin.ar
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import CSystem
import WASILibc
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// The header of a member of an archive: its name, modification time,
  /// owner, mode and size, as text, which the member's contents follow.
  ///
  /// The first member's header follows the archive's magic string,
  /// ``ArchiveFile/magic``,
  /// and each member starts at an even offset:
  /// the next header follows the contents, and a newline
  /// if their size is odd.
  ///
  /// The corresponding C type is `struct ar_hdr`.
  ///
  /// - Note: Provisional: archive headers may move to a library for object files.
  public typealias ArchiveHeader = ar_hdr
}

/// A namespace for the constants of the `ar` archive format,
/// which static libraries use: the magic string that an archive starts with,
/// and the parts of its members' headers.
///
///     guard bytes.starts(with: ArchiveFile.magic.utf8) else { return }
///     let header = UnsafeRawBufferPointer(rebasing: bytes[ArchiveFile.magicSize...])
///       .loadUnaligned(as: CInterop.ArchiveHeader.self)
///
/// - Note: Provisional: archive headers may move to a library for object files.
@available(System 199, *)
public enum ArchiveFile {}

@available(System 199, *)
extension ArchiveFile {
  /// The string that an archive starts with: `!<arch>` and a newline.
  ///
  /// The corresponding C constant is `ARMAG`.
  ///
  /// - Note: Provisional: archive headers may move to a library for object files.
  @_alwaysEmitIntoClient
  public static var magic: String { _ARMAG }

  /// The size of ``magic`` in bytes, 8,
  /// which is where the first member's header starts.
  ///
  /// The corresponding C constant is `SARMAG`.
  ///
  /// - Note: Provisional: archive headers may move to a library for object files.
  @_alwaysEmitIntoClient
  public static var magicSize: Int { Int(_SARMAG) }

  /// The two bytes that end each member's header:
  /// a backquote and a newline.
  ///
  /// The corresponding C constant is `ARFMAG`.
  ///
  /// - Note: Provisional: archive headers may move to a library for object files.
  @_alwaysEmitIntoClient
  public static var headerTrailer: String { _ARFMAG }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// What a header's name starts with when the member's name follows
  /// the header, as BSD's extended format has it:
  /// `#1/`, then the name's length in decimal.
  /// The header's size then counts the name too.
  ///
  /// The corresponding C constant is `AR_EFMT1`.
  ///
  /// - Note: Provisional: archive headers may move to a library for object files.
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static var extendedNamePrefix: String { _AR_EFMT1 }
  #endif
}

@available(System 199, *)
extension CInterop.ArchiveHeader {
  /// The member's name: the field's text, without the spaces after it.
  ///
  /// It's the name as the archive records it, such as `foo.o`,
  /// ``ArchiveFile/extendedNamePrefix`` and a length,
  /// where the member's name follows the header,
  /// or `foo.o/` or `/` and an offset, in GNU's format.
  ///
  /// The corresponding C field is `ar_name`.
  @_alwaysEmitIntoClient
  public var name: String { _archiveText(ar_name) }

  /// The member's modification time, in seconds since 1970,
  /// or `nil` if the field isn't a decimal number.
  ///
  /// The corresponding C field is `ar_date`.
  @_alwaysEmitIntoClient
  public var modificationTime: Int64? { _archiveNumber(ar_date, radix: 10) }

  /// The member's owner, or `nil` if the field isn't a decimal number.
  ///
  /// The corresponding C field is `ar_uid`.
  @_alwaysEmitIntoClient
  public var userID: UserID? {
    _archiveNumber(ar_uid, radix: 10)
      .flatMap { CInterop.UserID(exactly: $0) }.map { UserID(rawValue: $0) }
  }

  /// The member's group, or `nil` if the field isn't a decimal number.
  ///
  /// The corresponding C field is `ar_gid`.
  @_alwaysEmitIntoClient
  public var groupID: GroupID? {
    _archiveNumber(ar_gid, radix: 10)
      .flatMap { CInterop.GroupID(exactly: $0) }.map { GroupID(rawValue: $0) }
  }

  /// The member's mode, its type and permissions,
  /// or `nil` if the field isn't an octal number that fits in one.
  ///
  /// The corresponding C field is `ar_mode`.
  @_alwaysEmitIntoClient
  public var mode: FileMode? {
    _archiveNumber(ar_mode, radix: 8)
      .flatMap { CInterop.Mode(exactly: $0) }.map { FileMode(rawValue: $0) }
  }

  /// The size of what follows the header, in bytes:
  /// the member's contents, and with ``ArchiveFile/extendedNamePrefix``,
  /// its name before them.
  /// It's `nil` if the field isn't a decimal number.
  ///
  /// The corresponding C field is `ar_size`.
  @_alwaysEmitIntoClient
  public var size: Int64? { _archiveNumber(ar_size, radix: 10) }

  /// The two bytes that end the header,
  /// which are ``ArchiveFile/headerTrailer`` in a well-formed archive.
  ///
  /// The corresponding C field is `ar_fmag`.
  @_alwaysEmitIntoClient
  public var trailer: String {
    withUnsafeBytes(of: ar_fmag) { String(decoding: $0, as: UTF8.self) }
  }
}

/// An archive header's field as text, without the spaces that pad it.
@_alwaysEmitIntoClient
internal func _archiveText<Field>(_ field: Field) -> String {
  withUnsafeBytes(of: field) { bytes in
    var end = bytes.count
    while end > 0 && bytes[end - 1] == UInt8(ascii: " ") { end -= 1 }
    return String(decoding: bytes[..<end], as: UTF8.self)
  }
}

/// An archive header's numeric field: digits in `radix`, with spaces before
/// or after them, or `nil` if it's anything else. The widest field, the
/// time's 12 decimal digits, fits in an `Int64`, whatever the word size.
@_alwaysEmitIntoClient
internal func _archiveNumber<Field>(_ field: Field, radix: Int64) -> Int64? {
  withUnsafeBytes(of: field) { bytes in
    let space = UInt8(ascii: " ")
    var start = 0
    var end = bytes.count
    while start < end && bytes[start] == space { start += 1 }
    while end > start && bytes[end - 1] == space { end -= 1 }
    guard start < end else { return nil }
    var value: Int64 = 0
    for byte in bytes[start..<end] {
      let digit = Int64(byte) - Int64(UInt8(ascii: "0"))
      guard digit >= 0 && digit < radix else { return nil }
      let (shifted, overflow) = value.multipliedReportingOverflow(by: radix)
      let (sum, carry) = shifted.addingReportingOverflow(digit)
      guard !overflow && !carry else { return nil }
      value = sum
    }
    return value
  }
}

#endif // !os(Windows)
