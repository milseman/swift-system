/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

import Testing

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
// tests change only a child's: one they start, or an exit test's.
@Suite("Process priority")
private struct ProcessPriorityTests {
  @available(System 199, *)
  @Test func readingPriorities() throws {
    let mine = try ProcessPriority.current(for: .process(.current))
    #expect(mine == Int(getpriority(PRIO_PROCESS, 0)))
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

  #if !os(watchOS) && !os(tvOS) && !os(Android)
  @available(System 199, *)
  @Test func settingAChildsPriority() throws {
    let child = try ProcessID.spawn("/bin/sleep", arguments: ["sleep", "30"])
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    let before = try ProcessPriority.current(for: .process(child))
    try ProcessPriority.setCurrent(before + 5, for: .process(child))
    #expect(try ProcessPriority.current(for: .process(child)) == before + 5)

    // Past the limit, the system clamps it.
    try ProcessPriority.setCurrent(1000, for: .process(child))
    #expect([19, 20].contains(try ProcessPriority.current(for: .process(child))))

    // Lowering it again takes privilege.
    if getuid() != 0 {
      #expect(throws: Errno.permissionDenied) {
        try ProcessPriority.setCurrent(before, for: .process(child))
      }
    }
  }
  #endif

  @available(System 199, *)
  @Test func adjustingTheCallersPriority() async {
    await #expect(processExitsWith: .success) {
      let before = try ProcessPriority.current(for: .process(.current))
      let after = try ProcessPriority.adjust(by: 3)
      guard after == min(before + 3, 19),
        try ProcessPriority.current(for: .process(.current)) == after
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

#endif // !os(Windows) && !os(WASI)
