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

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
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

@Suite("ProcessID")
private struct ProcessIDTests {

  @available(System 199, *)
  @Test func rawValue() {
    let pid = ProcessID(rawValue: 42)
    #expect(pid.rawValue == 42)
    #expect(ProcessID(42) == pid)
    #expect(ProcessID(rawValue: 43) != pid)
    #expect(Set([pid, ProcessID(42), ProcessID(43)]).count == 2)
  }

  #if !os(WASI)
  @available(System 199, *)
  @Test func current() {
    #expect(ProcessID.current.rawValue == getpid())
    #expect(ProcessID.current.rawValue > 0)
    #expect(ProcessID.current == ProcessID.current)
  }

  @available(System 199, *)
  @Test func parent() {
    #expect(ProcessID.parent.rawValue == getppid())
    #expect(ProcessID.parent != ProcessID.current)
  }
  #endif // !os(WASI)
}

#endif // !os(Windows)
