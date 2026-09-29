/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// libproc is only in the macOS SDK.
#if os(macOS)

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class LibProcTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() throws {
    let pid = ProcessID(42)
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "proc_pidpath", .noInterrupt, 42, UInt32(4 * MAXPATHLEN)) { _ in
        _ = try pid.executablePath()
      },

      MockTestCase(name: "proc_name", .noInterrupt, 42, UInt32(2 * MAXCOMLEN + 1)) { _ in
        _ = try pid.name()
      },

      MockTestCase(
        name: "proc_pidinfo", .noInterrupt, 42, PROC_PIDTBSDINFO, 0, Wildcard(),
        CInt(MemoryLayout<proc_bsdinfo>.size)
      ) { _ in
        _ = try pid.bsdInfo()
      },

      MockTestCase(
        name: "proc_pidinfo", .noInterrupt, 42, PROC_PIDVNODEPATHINFO, 0, Wildcard(),
        CInt(MemoryLayout<proc_vnodepathinfo>.size)
      ) { _ in
        _ = try pid.currentDirectory()
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_ALL_PIDS), 0 as UInt32, CInt(4096)
      ) { _ in
        _ = try ProcessID.all()
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_PPID_ONLY), 42 as UInt32, CInt(4096)
      ) { _ in
        _ = try pid.children()
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_UID_ONLY), 501 as UInt32, CInt(4096)
      ) { _ in
        _ = try ProcessID.all(ofUser: UserID(501))
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_RUID_ONLY), 501 as UInt32, CInt(4096)
      ) { _ in
        _ = try ProcessID.all(ofRealUser: UserID(501))
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_PGRP_ONLY), 42 as UInt32, CInt(4096)
      ) { _ in
        _ = try ProcessID.all(inGroup: pid)
      },

      MockTestCase(
        name: "proc_listpids", .noInterrupt, UInt32(PROC_TTY_ONLY), 7 as UInt32, CInt(4096)
      ) { _ in
        _ = try ProcessID.all(onTerminal: DeviceID(7))
      },
    ]
    for test in syscallTestCases { test.runAllTests() }

    // A mocked proc_pidinfo fills every buffer, so only its failure is
    // checked for the list of descriptors, which grows a full buffer.
    try MockingDriver.withMockingEnabled { mocking in
      mocking.forceErrno = .always(errno: EPERM)
      XCTAssertThrowsError(try pid.openFileDescriptors()) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
      XCTAssertEqual(
        mocking.trace.dequeue()?.arguments.count, 5)
      XCTAssertTrue(mocking.trace.isEmpty)
    }
  }
  #endif // ENABLE_MOCKING

  func testPathAndName() throws {
    let path = try ProcessID.current.executablePath()
    XCTAssertTrue(path.isAbsolute)
    // The test runner's executable exists.
    XCTAssertEqual(try path.stat().type, .regular)
    XCTAssertEqual(path.lastComponent?.string.hasPrefix("xctest") ?? false
      || path.string.contains(".xctest"), true)

    let name = try ProcessID.current.name()
    XCTAssertFalse(name.isEmpty)
    XCTAssertLessThanOrEqual(name.utf8.count, 2 * Int(MAXCOMLEN))

    // Any user can read another process's path, but not its name.
    XCTAssertTrue(try ProcessID(1).executablePath().string.contains("launchd"))
    if geteuid() != 0 {
      XCTAssertThrowsError(try ProcessID(1).name()) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
    }

    let missing = ProcessID(.max)
    XCTAssertThrowsError(try missing.executablePath()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    XCTAssertThrowsError(try missing.name()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
  }

  func testDirectories() throws {
    let current = try ProcessID.current.currentDirectory()
    XCTAssertEqual(
      try current.stat().inode, try FilePath.currentWorkingDirectory().stat().inode)
    XCTAssertEqual(try ProcessID.current.rootDirectory(), "/")

    XCTAssertThrowsError(try ProcessID(.max).currentDirectory()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    if geteuid() != 0 {
      XCTAssertThrowsError(try ProcessID(1).rootDirectory()) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
    }
  }

  func testLists() throws {
    let all = try ProcessID.all()
    XCTAssertTrue(all.contains(.current))
    XCTAssertTrue(all.contains(ProcessID(1)))
    XCTAssertEqual(Set(all).count, all.count)

    XCTAssertTrue(try ProcessID.parent.children().contains(.current))
    XCTAssertEqual(try ProcessID.current.children(), [])
    XCTAssertTrue(try ProcessID.all(ofUser: .effective).contains(.current))
    XCTAssertTrue(try ProcessID.all(ofRealUser: .real).contains(.current))
    XCTAssertTrue(try ProcessID.all(inGroup: ProcessID(getpgrp())).contains(.current))
    // No process is in a group that doesn't exist.
    XCTAssertEqual(try ProcessID.all(inGroup: ProcessID(.max)), [])

    // The list agrees with sysctl's about the processes that live through
    // both calls, which are the only ones the test can know about: any
    // number of others can come and go in between.
    let child = try spawnWaitingChild()
    defer {
      try? child.sendSignal(.kill)
      _ = try? child.wait()
    }
    let listed = Set(try ProcessID.all())
    let fromKernel = Set(try SystemControl.value(.allProcesses).map {
      ProcessID(rawValue: $0.kp_proc.p_pid)
    })
    for id in [ProcessID.current, .parent, ProcessID(1), child] {
      XCTAssertTrue(listed.contains(id), "\(id)")
      XCTAssertTrue(fromKernel.contains(id), "\(id)")
    }
  }

  func testBSDInfo() throws {
    let info = try ProcessID.current.bsdInfo()
    XCTAssertEqual(info.id, .current)
    XCTAssertEqual(info.parent, .parent)
    XCTAssertEqual(info.processGroup, ProcessID(getpgrp()))
    XCTAssertEqual(info.effectiveUser, .effective)
    XCTAssertEqual(info.realUser, .real)
    XCTAssertEqual(info.effectiveGroup, .effective)
    XCTAssertEqual(info.realGroup, .real)
    // Nothing here changes the process's credentials after exec.
    XCTAssertEqual(info.savedUser, .effective)
    XCTAssertEqual(info.savedGroup, .effective)
    XCTAssertEqual(info.status, .running)
    XCTAssertTrue(info.flags.contains(.is64Bit))
    XCTAssertTrue(info.flags.contains(.execed))
    XCTAssertGreaterThanOrEqual(info.descriptorTableSize, 3)
    XCTAssertFalse(info.command.isEmpty)
    XCTAssertLessThanOrEqual(info.command.utf8.count, Int(MAXCOMLEN))
    XCTAssertTrue(try ProcessID.current.name().hasPrefix(info.command))
    XCTAssertEqual(info.nice, Int(getpriority(PRIO_PROCESS, 0)))
    XCTAssertGreaterThan(info.rawValue.pbi_start_tvsec, 0)

    // The saved user ID agrees with sysctl's, which Foundation reads.
    let kernel = try SystemControl.value(.process(.current))
    XCTAssertEqual(info.savedUser.rawValue, kernel.kp_eproc.e_pcred.p_svuid)

    // launchd has no controlling terminal.
    if geteuid() == 0 {
      XCTAssertNil(try ProcessID(1).bsdInfo().controllingTerminal)
    } else {
      XCTAssertThrowsError(try ProcessID(1).bsdInfo()) {
        XCTAssertEqual($0 as? Errno, .notPermitted)
      }
    }
    XCTAssertThrowsError(try ProcessID(.max).bsdInfo()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }

    XCTAssertEqual("\(ProcessID.BSDInfo.Status.zombie)", "zombie")
    XCTAssertEqual("\([ProcessID.BSDInfo.Flags.traced, .is64Bit] as ProcessID.BSDInfo.Flags)",
                   "[.traced, .is64Bit]")
  }

  func testOpenFileDescriptors() throws {
    // A pipe adds two descriptors of its own kind.
    let (reader, writer) = try FileDescriptor.pipe()
    defer {
      try? reader.close()
      try? writer.close()
    }
    let descriptors = try ProcessID.current.openFileDescriptors()
    XCTAssertEqual(descriptors.map(\.fileDescriptor.rawValue), descriptors.map(\.fileDescriptor.rawValue).sorted())
    XCTAssertEqual(descriptors.first { $0.fileDescriptor == reader }?.kind, .pipe)
    XCTAssertEqual(descriptors.first { $0.fileDescriptor == writer }?.kind, .pipe)
    XCTAssertGreaterThan(
      try ProcessID.current.bsdInfo().descriptorTableSize,
      Int(descriptors.map(\.fileDescriptor.rawValue).max() ?? 0))

    // Growing past the first buffer keeps every descriptor.
    var opened: [FileDescriptor] = []
    defer { for fd in opened { try? fd.close() } }
    for _ in 0..<100 { opened.append(try FileDescriptor.open("/dev/null", .readOnly)) }
    let more = try ProcessID.current.openFileDescriptors()
    XCTAssertTrue(opened.allSatisfy { fd in more.contains { $0.fileDescriptor == fd } })
    XCTAssertTrue(more.filter { opened.contains($0.fileDescriptor) }.allSatisfy { $0.kind == .vnode })

    XCTAssertThrowsError(try ProcessID(.max).openFileDescriptors()) {
      XCTAssertEqual($0 as? Errno, .noSuchProcess)
    }
    XCTAssertEqual("\(ProcessID.OpenFileDescriptor.Kind.kernelQueue)", "kernelQueue")
  }
}

#endif // os(macOS)
