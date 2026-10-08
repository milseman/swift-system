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

// FileDescriptor.isTerminal where it's isatty, WASI included: what isn't a
// terminal. A pseudoterminal's tests are TerminalTests', which WASI lacks.
@Suite("Is a terminal")
private struct IsTerminalTests {
  @available(System 199, *)
  @Test func filesAndBadDescriptorsArent() throws {
    try withTemporaryFilePath(basename: "isTerminal") { directory in
      let fd = try FileDescriptor.open(
        directory.appending("file"), .writeOnly, options: .create, permissions: .ownerReadWrite)
      defer { try? fd.close() }
      #expect(!fd.isTerminal)
    }
    #expect(!FileDescriptor(rawValue: -1).isTerminal)
  }
}

#endif // !os(Windows)
