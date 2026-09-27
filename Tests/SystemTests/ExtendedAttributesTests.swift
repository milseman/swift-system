/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// Linux requires a namespace, and user. is the one a file's owner can set;
// Darwin takes any name.
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

  @available(System 199, *)
  @Test func aMissingFile() {
    #expect(throws: Errno.noSuchFileOrDirectory) {
      try FilePath("/nonexistent/file").extendedAttribute(name)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
