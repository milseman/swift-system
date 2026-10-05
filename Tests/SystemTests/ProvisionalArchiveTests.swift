/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// This file imports no C library: it reads archive headers as a client that
// imports only System does, through their accessors. On glibc, the BSDs and
// WASI, the structure is CSystem's, whose fields a client can't name.

/// A header field: its text, padded with spaces to its width.
private func field(_ text: String, _ width: Int) -> [UInt8] {
  precondition(text.utf8.count <= width)
  return Array(text.utf8) + [UInt8](repeating: UInt8(ascii: " "), count: width - text.utf8.count)
}

/// A member's header, as `ar` writes one.
private func header(
  name: String, date: String = "0", uid: String = "0", gid: String = "0",
  mode: String = "100644", size: String, trailer: String = "`\n"
) -> [UInt8] {
  field(name, 16) + field(date, 12) + field(uid, 6) + field(gid, 6) + field(mode, 8)
    + field(size, 10) + Array(trailer.utf8)
}

@available(System 199, *)
private func archiveHeader(_ bytes: [UInt8]) -> CInterop.ArchiveHeader {
  precondition(bytes.count == MemoryLayout<CInterop.ArchiveHeader>.size)
  return bytes.withUnsafeBytes { $0.loadUnaligned(as: CInterop.ArchiveHeader.self) }
}

@Suite("Provisional archive headers")
private struct ProvisionalArchiveTests {
  @available(System 199, *)
  @Test func theFormatsConstants() {
    #expect(MemoryLayout<CInterop.ArchiveHeader>.size == 60)
    #expect(ArchiveFile.magic == "!<arch>\n")
    #expect(ArchiveFile.magicSize == 8)
    #expect(ArchiveFile.magic.utf8.count == ArchiveFile.magicSize)
    #expect(ArchiveFile.headerTrailer == "`\n")
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
    #expect(ArchiveFile.extendedNamePrefix == "#1/")
    #endif
  }

  /// An archive of one member, built in memory: its magic string, then
  /// the member's header and contents.
  @available(System 199, *)
  @Test func aMemberHeaderLaidOverAnArchive() throws {
    let contents = Array("hello\n".utf8)
    let archive = Array(ArchiveFile.magic.utf8)
      + header(
        name: "hello.txt/", date: "1700000000", uid: "501", gid: "20", mode: "100644",
        size: "\(contents.count)")
      + contents
    #expect(archive.starts(with: ArchiveFile.magic.utf8))
    let (member, data) = try archive.withUnsafeBytes { raw in
      let header = raw.loadUnaligned(
        fromByteOffset: ArchiveFile.magicSize, as: CInterop.ArchiveHeader.self)
      let start = ArchiveFile.magicSize + MemoryLayout<CInterop.ArchiveHeader>.size
      let size = try #require(header.size)
      return (header, Array(raw[start..<(start + Int(size))]))
    }
    #expect(member.name == "hello.txt/")
    #expect(member.modificationTime == 1_700_000_000)
    #expect(member.userID == UserID(rawValue: 501))
    #expect(member.groupID == GroupID(rawValue: 20))
    #expect(member.mode == FileMode(rawValue: 0o100644))
    #expect(member.mode?.type == .regular)
    #expect(member.mode?.permissions == [.ownerReadWrite, .groupRead, .otherRead])
    #expect(member.size == Int64(contents.count))
    #expect(member.trailer == ArchiveFile.headerTrailer)
    #expect(data == contents)
  }

  /// GNU's symbol table and long-name table members, whose names are `/`
  /// and `//`, and whose other fields can be empty.
  @available(System 199, *)
  @Test func gnuTableMembers() {
    let symbols = archiveHeader(header(name: "/", size: "42"))
    #expect(symbols.name == "/")
    #expect(symbols.size == 42)
    let names = archiveHeader(
      header(name: "//", date: "", uid: "", gid: "", mode: "", size: "18"))
    #expect(names.name == "//")
    #expect(names.modificationTime == nil && names.userID == nil && names.groupID == nil)
    #expect(names.mode == nil)
    #expect(names.size == 18)
    let reference = archiveHeader(header(name: "/18", size: "7"))
    #expect(reference.name == "/18")
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// BSD's extended format: the name follows the header, and the header's
  /// size counts it.
  @available(System 199, *)
  @Test func bsdExtendedNames() throws {
    let name = Array("a_long_member_name.o".utf8)
    let header = archiveHeader(header(name: "#1/\(name.count)", size: "\(name.count + 100)"))
    #expect(header.name.hasPrefix(ArchiveFile.extendedNamePrefix))
    let length = try #require(Int(header.name.dropFirst(ArchiveFile.extendedNamePrefix.count)))
    #expect(length == name.count)
    #expect(header.size.map { $0 - Int64(length) } == 100)
  }
  #endif

  /// A field that isn't a number, or doesn't fit, is nil; spaces around a
  /// number are padding.
  @available(System 199, *)
  @Test func fieldsThatArentNumbers() {
    let odd = archiveHeader(header(
      name: "x", date: "12a", uid: "-1", gid: "+2", mode: "999", size: " 42 "))
    #expect(odd.modificationTime == nil)
    #expect(odd.userID == nil)
    #expect(odd.groupID == nil)
    #expect(odd.mode == nil)  // 9 isn't an octal digit
    #expect(odd.size == 42)
    // The widest fields fit, whatever the word size: 12 decimal digits of
    // time, 10 of size.
    let wide = archiveHeader(header(name: "x", date: "999999999999", size: "9999999999"))
    #expect(wide.modificationTime == 999_999_999_999)
    #expect(wide.size == 9_999_999_999)
    // An octal mode beyond the C type's range, where mode_t has 16 bits.
    let big = archiveHeader(header(name: "x", mode: "77777777", size: "0"))
    if MemoryLayout<CInterop.Mode>.size < 4 {
      #expect(big.mode == nil)
    } else {
      #expect(big.mode.map { UInt64($0.rawValue) } == 0o77777777)
    }
    let broken = archiveHeader(header(name: "x", size: "0", trailer: "\n\n"))
    #expect(broken.trailer == "\n\n")
    #expect(broken.trailer != ArchiveFile.headerTrailer)
  }

  /// A name keeps everything but the spaces after it.
  @available(System 199, *)
  @Test func namesKeepWhatTheyHave() {
    #expect(archiveHeader(header(name: "a b", size: "0")).name == "a b")
    #expect(archiveHeader(header(name: "sixteen_chars_ok", size: "0")).name == "sixteen_chars_ok")
    #expect(archiveHeader(header(name: "", size: "0")).name == "")
  }
}

#endif // !os(Windows)
