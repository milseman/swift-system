/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// Linux requires a namespace, and user. is the one a file's owner can set;
// Darwin takes any name, and so does FreeBSD, in its user namespace.
private let name = "user.system-tests.origin"

/// Makes a file in a scratch directory and calls `body` with its path,
/// unless the file system there doesn't support extended attributes.
@available(System 199, *)
private func withAttributedFile(_ body: (FilePath) throws -> Void) throws {
  try withTemporaryFilePath(basename: "xattr") { directory in
    let file = directory.appending("file")
    try FileDescriptor.open(file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      .close()
    do {
      try file.setExtendedAttribute("user.system-tests.probe", to: [0])
      try file.removeExtendedAttribute("user.system-tests.probe")
    } catch Errno.notSupported {
      return  // A file system without extended attributes, such as an old tmpfs.
    }
    try body(file)
  }
}

@Suite("Extended attributes")
private struct ExtendedAttributesTests {
  @available(System 199, *)
  @Test func setGetListAndRemove() throws {
    try withAttributedFile { file in
      #expect(try file.extendedAttribute(name) == nil)
      try file.setExtendedAttribute(name, to: [1, 2, 3])
      #expect(try file.extendedAttribute(name) == [1, 2, 3])
      #expect(try file.extendedAttributeNames().contains(name))

      // Empty and large values.
      try file.setExtendedAttribute(name, to: [])
      #expect(try file.extendedAttribute(name) == [])
      let large = (0..<3000).map { UInt8(truncatingIfNeeded: $0) }
      try file.setExtendedAttribute(name, to: large)
      #expect(try file.extendedAttribute(name) == large)

      try file.removeExtendedAttribute(name)
      #expect(try file.extendedAttribute(name) == nil)
      #expect(try !file.extendedAttributeNames().contains(name))
      #expect(throws: Errno.attributeNotFound) { try file.removeExtendedAttribute(name) }
    }
  }

  #if !os(FreeBSD)
  @available(System 199, *)
  @Test func createAndReplace() throws {
    try withAttributedFile { file in
      #expect(throws: Errno.attributeNotFound) {
        try file.setExtendedAttribute(name, to: [1], options: .replace)
      }
      try file.setExtendedAttribute(name, to: [1], options: .create)
      #expect(throws: Errno.fileExists) {
        try file.setExtendedAttribute(name, to: [2], options: .create)
      }
      try file.setExtendedAttribute(name, to: [3], options: .replace)
      #expect(try file.extendedAttribute(name) == [3])
    }
  }
  #else
  @available(System 199, *)
  @Test func freeBSDTakesNoOptions() throws {
    try withAttributedFile { file in
      #expect(throws: Errno.invalidArgument) {
        try file.setExtendedAttribute(name, to: [1], options: ExtendedAttributeOptions(rawValue: 1))
      }
      // A set creates the attribute, or replaces it.
      try file.setExtendedAttribute(name, to: [1])
      try file.setExtendedAttribute(name, to: [2])
      #expect(try file.extendedAttribute(name) == [2])
    }
  }
  #endif

  @available(System 199, *)
  @Test func listsOfNames() {
    #expect(_attributeNames(nullSeparated: Array("a\0bc\0".utf8)) == ["a", "bc"])
    #expect(_attributeNames(nullSeparated: []) == [])
    // FreeBSD's: a length byte, then the name.
    #expect(_attributeNames(lengthPrefixed: [1] + Array("a".utf8) + [2] + Array("bc".utf8)) == ["a", "bc"])
    #expect(_attributeNames(lengthPrefixed: []) == [])
    // A list cut short keeps what it has.
    #expect(_attributeNames(lengthPrefixed: [3] + Array("ab".utf8)) == ["ab"])
  }

  @available(System 199, *)
  @Test func throughADescriptor() throws {
    try withAttributedFile { file in
      let fd = try FileDescriptor.open(file, .readWrite)
      defer { try? fd.close() }
      try fd.setExtendedAttribute(name, to: "hello".utf8)
      #expect(try file.extendedAttribute(name) == Array("hello".utf8))
      #expect(try fd.extendedAttribute(name) == Array("hello".utf8))
      #expect(try fd.extendedAttributeNames().contains(name))
      try fd.removeExtendedAttribute(name)
      #expect(try fd.extendedAttribute(name) == nil)
    }
  }

  @available(System 199, *)
  @Test func sizesWithoutValues() throws {
    try withAttributedFile { file in
      #expect(try file.extendedAttributeSize(name) == nil)
      try file.setExtendedAttribute(name, to: [1, 2, 3])
      #expect(try file.extendedAttributeSize(name) == 3)
      try file.setExtendedAttribute(name, to: [])
      #expect(try file.extendedAttributeSize(name) == 0)
      let fd = try FileDescriptor.open(file, .readOnly)
      defer { try? fd.close() }
      try file.setExtendedAttribute(name, to: Array(repeating: 7, count: 3000))
      #expect(try fd.extendedAttributeSize(name) == 3000)
      try file.withPlatformString { path in
        let size = try FilePath.extendedAttributeSize(path, name)
        #expect(size == 3000)
      }
      let link = file.removingLastComponent().appending("link")
      try link.makeSymbolicLink(to: file)
      #expect(try link.extendedAttributeSize(name) == 3000)
      #expect(try link.extendedAttributeSize(name, followTargetSymlink: false) == nil)
      try fd.removeExtendedAttribute(name)
      #expect(try fd.extendedAttributeSize(name) == nil)
    }
  }

  @available(System 199, *)
  @Test func symbolicLinksAndCStrings() throws {
    try withAttributedFile { file in
      let link = file.removingLastComponent().appending("link")
      try link.makeSymbolicLink(to: file)
      // Through the link, the target's attributes; of the link, its own.
      try link.setExtendedAttribute(name, to: [7])
      #expect(try file.extendedAttribute(name) == [7])
      #expect(try link.extendedAttribute(name) == [7])
      #expect(try link.extendedAttribute(name, followTargetSymlink: false) == nil)
      #expect(try !link.extendedAttributeNames(followTargetSymlink: false).contains(name))

      try file.withPlatformString { path in
        #expect(try FilePath.extendedAttribute(path, name) == [7])
        try FilePath.setExtendedAttribute(path, name, to: [8])
        #expect(try FilePath.extendedAttributeNames(path).contains(name))
        try FilePath.removeExtendedAttribute(path, name)
      }
      #expect(try file.extendedAttribute(name) == nil)
    }
  }

  #if SYSTEM_PACKAGE_DARWIN
  @available(System 199, *)
  @Test func darwinsNames() {
    #expect(ExtendedAttributeName.finderInfo == "com.apple.FinderInfo")
    #expect(ExtendedAttributeName.resourceFork == "com.apple.ResourceFork")
  }
  #endif

  @available(System 199, *)
  @Test func aMissingFile() {
    #expect(throws: Errno.noSuchFileOrDirectory) {
      try FilePath("/nonexistent/file").extendedAttribute(name)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
