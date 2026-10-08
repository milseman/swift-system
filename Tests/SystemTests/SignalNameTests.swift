/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Signal.name: the C library's names for signals (sys_signame, glibc's
// sigabbrev_np). Nothing here sends a signal.

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("Signal names")
private struct SignalNameTests {
  @available(System 199, *)
  @Test func namesOfCommonSignals() {
    #expect(Signal.interrupt.name == "SIGINT")
    #expect(Signal.kill.name == "SIGKILL")
    #expect(Signal.terminate.name == "SIGTERM")
    #expect(Signal.segmentationViolation.name == "SIGSEGV")
    #expect(Signal.userDefined1.name == "SIGUSR1")
    #expect(Signal.windowSizeChange.name == "SIGWINCH")
    // Numbers that name no signal.
    #expect(Signal(rawValue: 0).name == nil)
    #expect(Signal(rawValue: 9999).name == nil)
    #expect(Signal(rawValue: -1).name == nil)
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  // The BSDs' table and description's agree.
  @available(System 199, *)
  @Test func theTableNamesWhatDescriptionNames() {
    for (signal, name) in Signal._names {
      #expect(signal.name == name.description)
    }
  }
  #endif

  #if os(Linux) && canImport(Glibc)
  // glibc names a signal that description gives as a number, and none of
  // the real-time signals, which start after SIGSYS's 31.
  @available(System 199, *)
  @Test func glibcNames() {
    #expect(Signal(rawValue: 16).name == "SIGSTKFLT")
    #expect(Signal(rawValue: 40).name == nil)
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
