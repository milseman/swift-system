/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

// WASI's synchronized I/O flags and compile-time limits, as wasi-libc's
// headers define them. CompileTimeLimitsTests and SmallGapsTests check the
// other platforms'; they're XCTest, which doesn't run under WasmKit.
@Suite("WASI's limits and flags")
private struct WASILimitsAndFlagsTests {
  @available(System 199, *)
  @Test func theSynchronizedIOFlagsAreWASIsFdflags() {
    // __WASI_FDFLAGS_DSYNC, _RSYNC and _SYNC: each its own bit.
    #expect(FileDescriptor.OpenOptions.dataSync.rawValue == 1 << 1)
    #expect(FileDescriptor.OpenOptions.readSync.rawValue == 1 << 3)
    #expect(FileDescriptor.OpenOptions.sync.rawValue == 1 << 4)
    #expect(FileDescriptor.StatusFlags.dataSync.rawValue == 1 << 1)
    #expect(FileDescriptor.StatusFlags.readSync.rawValue == 1 << 3)
    #expect(FileDescriptor.StatusFlags.sync.rawValue == 1 << 4)
  }

  @available(System 199, *)
  @Test func theLimitsAreWASILibcs() {
    #expect(SystemConfig.maxFileNameBytes == 255)
    #expect(SystemConfig.maxPathBytes == 4096)
    #expect(SystemConfig.maxSymbolicLinks == 20)
    #expect(SystemConfig.guaranteedArgumentBytes == 4096)
  }
}

#endif // os(WASI)
