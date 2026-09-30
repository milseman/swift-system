/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing
import XCTest

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// A process can't lower its nice value again without privilege, so these
// tests change only a child's: one they start, or an exit test's. The one
// that starts a child is an XCTest test (see ProcessTestSupport.swift).
@Suite("Process priority")
private struct ProcessPriorityTests {
  @available(System 199, *)
  @Test func readingPriorities() throws {
    let mine = try ProcessPriority.current(for: .process(.current))
    #if canImport(Glibc)
    // PRIO_PROCESS is a member of glibc's enum __priority_which, which
    // getpriority takes as an int.
    #expect(mine == Int(getpriority(__priority_which_t(PRIO_PROCESS.rawValue), 0)))
    #else
    #expect(mine == Int(getpriority(PRIO_PROCESS, 0)))
    #endif
    #expect((-20...20).contains(mine))
    // A group's and a user's are their most favored process's.
    #expect(try ProcessPriority.current(for: .processGroup(.currentProcessGroup)) <= mine)
    #expect(try ProcessPriority.current(for: .user(.effective)) <= mine)
  }

  @available(System 199, *)
  @Test func aProcessThatDoesntExist() throws {
    // Process IDs don't reach this high on Darwin or Linux.
    let missing = ProcessPriority.Target.process(ProcessID(rawValue: 99_999_999))
    #expect(throws: Errno.noSuchProcess) { try ProcessPriority.current(for: missing) }
    #expect(throws: Errno.noSuchProcess) { try ProcessPriority.setCurrent(1, for: missing) }
  }

  @available(System 199, *)
  @Test func adjustingTheCallersPriority() async {
    await #expect(processExitsWith: .success) {
      #if SYSTEM_PACKAGE_DARWIN
      let caller = ProcessPriority.Target.process(.current)
      #else
      // Linux's nice values are threads', and nice changes the calling
      // thread's. The process's ID names its main thread, and this body
      // runs on another; 0 names the calling thread.
      let caller = ProcessPriority.Target.process(ProcessID(rawValue: 0))
      #endif
      let before = try ProcessPriority.current(for: caller)
      let after = try ProcessPriority.adjust(by: 3)
      guard after == min(before + 3, 19),
        try ProcessPriority.current(for: caller) == after
      else { exit(1) }
      // A nice value past the limit clamps to it.
      guard try ProcessPriority.adjust(by: 1000) == 19 || getuid() == 0 else { exit(2) }
      guard getuid() != 0 else { exit(0) }
      do throws(Errno) {
        try ProcessPriority.adjust(by: -1)
        exit(3)
      } catch {
        exit(error == .notPermitted ? 0 : 4)
      }
    }
  }
}

#if !os(watchOS) && !os(tvOS) && !os(Android)
@available(System 199, *)
final class ProcessPriorityChildTests: XCTestCase {
  func testSettingAChildsPriority() throws {
    let child = try spawnWaitingChild()
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    // Raised, by less if the tests run niced near the limit.
    let before = try ProcessPriority.current(for: .process(child))
    let raised = min(before + 5, 19)
    try ProcessPriority.setCurrent(raised, for: .process(child))
    XCTAssertEqual(try ProcessPriority.current(for: .process(child)), raised)

    // Past the limit, the system clamps it.
    try ProcessPriority.setCurrent(1000, for: .process(child))
    XCTAssertTrue([19, 20].contains(try ProcessPriority.current(for: .process(child))))

    // Lowering it again takes privilege.
    if getuid() != 0 {
      XCTAssertThrowsError(try ProcessPriority.setCurrent(before, for: .process(child))) {
        XCTAssertEqual($0 as? Errno, .permissionDenied)
      }
    }
  }
}
#endif

#endif // !os(Windows) && !os(WASI)
