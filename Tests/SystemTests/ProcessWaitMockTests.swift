/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: decoding wait statuses, and the wait wrappers checked against
// the calls they make. ProcessWaitTests.swift waits for real children.

#if !os(Windows) && !os(WASI)

import XCTest

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

@available(System 199, *)
final class ExitStatusTests: XCTestCase {
  func testDecodingWaitStatuses() {
    XCTAssertEqual(ExitStatus(waitStatus: 3 << 8), .exited(3))
    XCTAssertEqual(ExitStatus(waitStatus: SIGKILL), .signaled(.kill, coreDumped: false))
    XCTAssertEqual(
      ExitStatus(waitStatus: SIGSEGV | 0x80), .signaled(.segmentationViolation, coreDumped: true))
    let stopped = (SIGSTOP << 8) | 0x7f
    XCTAssertNil(ExitStatus(waitStatus: stopped))
    XCTAssertEqual(ProcessStateChange(waitStatus: stopped), .stopped(.stop))
    #if SYSTEM_PACKAGE_DARWIN
    // Darwin encodes a continued process as one stopped by SIGCONT.
    let continued: CInt = (SIGCONT << 8) | 0x7f
    #elseif os(FreeBSD)
    let continued: CInt = SIGCONT
    #else
    // Linux, Android, and OpenBSD.
    let continued: CInt = 0xffff
    #endif
    XCTAssertEqual(ProcessStateChange(waitStatus: continued), .continued)
    XCTAssertEqual(ProcessStateChange(waitStatus: 7 << 8), .terminated(.exited(7)))
    XCTAssertEqual(ProcessStateChange.stopped(.terminalStop).description, "stopped by SIGTSTP")
  }
}

#if ENABLE_MOCKING
@available(System 199, *)
final class ProcessWaitMockTests: XCTestCase {
  func testWaits() {
    let child = ProcessID(rawValue: 4242)
    let cases: [MockTestCase] = [
      MockTestCase(name: "waitpid", .interruptable, 4242 as pid_t, 0 as CInt) {
        _ = try child.wait(retryOnInterrupt: $0)
      },
      MockTestCase(name: "waitpid", .noInterrupt, 4242 as pid_t, WNOHANG) { _ in
        _ = try child.tryWait()
      },
      MockTestCase(name: "waitpid", .interruptable, -1 as pid_t, 0 as CInt) {
        _ = try ProcessID.waitForAnyChild(retryOnInterrupt: $0)
      },
      MockTestCase(name: "waitpid", .noInterrupt, -1 as pid_t, WNOHANG) { _ in
        _ = try ProcessID.tryWaitForAnyChild()
      },
      MockTestCase(
        name: "waitid", .interruptable, _idTypeValue(P_PID), 4242, WEXITED | WNOWAIT
      ) {
        _ = try child.wait(for: [.exited, .keepWaitable], retryOnInterrupt: $0)
      },
      MockTestCase(name: "waitid", .interruptable, _idTypeValue(P_ALL), 0, WEXITED) {
        _ = try ProcessID.waitForAnyChild(for: .exited, retryOnInterrupt: $0)
      },
      MockTestCase(name: "waitid", .interruptable, _idTypeValue(P_PGID), 4242, WEXITED) {
        _ = try ProcessID.waitForAnyChild(
          inProcessGroup: child, for: .exited, retryOnInterrupt: $0)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
}
#endif // ENABLE_MOCKING

#endif // !os(Windows) && !os(WASI)
