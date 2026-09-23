//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !os(Windows) && !os(WASI)

import Testing

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

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Identifiers")
private struct IdentifiersTests {

  @available(System 199, *)
  @Test func userIDs() {
    #expect(UserID.real.rawValue == getuid())
    #expect(UserID.effective.rawValue == geteuid())
  }

  @available(System 199, *)
  @Test func groupIDs() {
    #expect(GroupID.real.rawValue == getgid())
    #expect(GroupID.effective.rawValue == getegid())
  }

  @available(System 199, *)
  @Test func newFilesUseEffectiveUserID() throws {
    try withTemporaryFilePath(basename: "Identifiers_newFiles") { path in
      let file = path.appending("file")
      let fd = try FileDescriptor.open(
        file, .writeOnly, options: .create, permissions: .ownerReadWrite)
      try fd.close()
      #expect(try file.stat().userID == UserID.effective)
    }
  }
}

#endif // !os(Windows) && !os(WASI)
