/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import XCTest
import Darwin

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
final class SystemControlTest: XCTestCase {
  #if ENABLE_MOCKING
  func testSyscalls() throws {
    let pid = ProcessID(42)
    // Each records the size of the buffer for the old value (-1 for none),
    // and the size of the new value.
    let syscallTestCases: Array<MockTestCase> = [
      MockTestCase(name: "sysctlbyname", .noInterrupt, "hw.ncpu", 4, 0) { _ in
        _ = try SystemControl.value(.processorCount)
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "hw.memsize", 8, 0) { _ in
        _ = try SystemControl.value(.memorySize)
      },

      MockTestCase(
        name: "sysctl", .noInterrupt, [CTL_KERN, KERN_PROC, KERN_PROC_PID, 42],
        MemoryLayout<kinfo_proc>.size, 0
      ) { _ in
        _ = try SystemControl.value(.process(pid))
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "hw.ncpu", 0, 0) { _ in
        _ = try SystemControl.valueSize(.processorCount)
      },

      MockTestCase(name: "sysctl", .noInterrupt, [CTL_HW, HW_NCPU], 16, 0) { _ in
        var buffer = [UInt8](repeating: 0, count: 16)
        _ = try buffer.withUnsafeMutableBytes {
          try SystemControl.value(SystemControl.Name<Int32>(identifier: [CTL_HW, HW_NCPU]), into: $0)
        }
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "kern.maxproc", -1, 4) { _ in
        try SystemControl.setValue(Int32(100), for: .maxProcesses)
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "kern.hostname", -1, 4) { _ in
        try SystemControl.setValue("host", for: .hostName)
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "a.list", -1, 12) { _ in
        try SystemControl.setValue([1, 2, 3] as [Int32], for: SystemControl.Name<[Int32]>("a.list"))
      },

      MockTestCase(name: "sysctlbyname", .noInterrupt, "a.raw", -1, 3) { _ in
        try [UInt8](repeating: 0, count: 3).withUnsafeBytes {
          try SystemControl.setValue(from: $0, for: SystemControl.Name<[UInt8]>("a.raw"))
        }
      },

      MockTestCase(name: "sysctlnametomib", .noInterrupt, "hw.ncpu", Int(CTL_MAXNAME)) { _ in
        _ = try SystemControl.Name<Int32>(resolving: "hw.ncpu")
      },
    ]
    for test in syscallTestCases { test.runAllTests() }

    // A variable of variable size is read twice: once for its size,
    // and once for its value.
    try MockingDriver.withMockingEnabled { mocking in
      XCTAssertEqual(try SystemControl.value(.osVersion), "")
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, ["kern.osversion", 0, 0])
      XCTAssertEqual(mocking.trace.dequeue()?.arguments, ["kern.osversion", 1, 0])
      XCTAssertTrue(mocking.trace.isEmpty)

      mocking.forceErrno = .always(errno: ENOENT)
      XCTAssertThrowsError(try SystemControl.value(.allProcesses)) {
        XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
      }
      XCTAssertEqual(
        mocking.trace.dequeue()?.arguments, [[CTL_KERN, KERN_PROC, KERN_PROC_ALL], 0, 0])
    }
  }
  #endif // ENABLE_MOCKING

  func testHardware() throws {
    let processors = try SystemControl.value(.processorCount)
    XCTAssertGreaterThan(processors, 0)
    XCTAssertEqual(Int(processors), try SystemConfig.value(.processorsConfigured))
    XCTAssertGreaterThan(try SystemControl.value(.activeProcessorCount), 0)
    let logical = try SystemControl.value(.logicalProcessorCount)
    XCTAssertGreaterThan(logical, 0)
    XCTAssertGreaterThanOrEqual(try SystemControl.value(.maxLogicalProcessorCount), logical)
    let physical = try SystemControl.value(.physicalProcessorCount)
    XCTAssertGreaterThan(physical, 0)
    XCTAssertLessThanOrEqual(physical, logical)
    XCTAssertGreaterThanOrEqual(try SystemControl.value(.maxPhysicalProcessorCount), physical)
    XCTAssertGreaterThan(try SystemControl.value(.processorPackageCount), 0)
    XCTAssertEqual(try SystemControl.value(.byteOrder), 1234)
    XCTAssertGreaterThan(try SystemControl.value(.cpuType), 0)
    XCTAssertEqual(try SystemControl.value(.is64BitCapable), 1)
    XCTAssertNotEqual(try SystemControl.value(.cpuFamily), 0)

    XCTAssertGreaterThan(try SystemControl.value(.memorySize), 1 << 30)
    XCTAssertEqual(Int(try SystemControl.value(.pageSize)), try SystemConfig.value(.pageSize))
    XCTAssertGreaterThan(try SystemControl.value(.cacheLineSize), 0)
    XCTAssertGreaterThan(try SystemControl.value(.level1DataCacheSize), 0)
    XCTAssertGreaterThan(try SystemControl.value(.level1InstructionCacheSize), 0)
    XCTAssertGreaterThan(try SystemControl.value(.level2CacheSize), 0)
    XCTAssertGreaterThan(try SystemControl.value(.timebaseFrequency), 0)

    #if arch(arm64)
    XCTAssertEqual(try SystemControl.value(.machine), "arm64")
    #endif
    XCTAssertFalse(try SystemControl.value(.model).isEmpty)
    XCTAssertFalse(try SystemControl.value(.cpuBrand).isEmpty)

    do {
      let translated = try SystemControl.value(.isTranslated)
      XCTAssertTrue([0, 1].contains(translated))
    } catch Errno.noSuchFileOrDirectory {
      // A Mac with an Intel processor can't translate.
    }
  }

  func testKernel() throws {
    var names = utsname()
    XCTAssertEqual(uname(&names), 0)
    func string<T>(_ field: T) -> String {
      withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    XCTAssertEqual(try SystemControl.value(.osType), "Darwin")
    XCTAssertEqual(try SystemControl.value(.osType), string(names.sysname))
    XCTAssertEqual(try SystemControl.value(.osRelease), string(names.release))
    XCTAssertEqual(try SystemControl.value(.kernelVersion), string(names.version))
    XCTAssertFalse(try SystemControl.value(.osVersion).isEmpty)
    XCTAssertTrue(try SystemControl.value(.osProductVersion).contains("."))
    XCTAssertEqual(try SystemControl.value(.kernelUUID).count, 36)
    XCTAssertEqual(try SystemControl.value(.bootSessionUUID).count, 36)
    XCTAssertEqual(try SystemControl.value(.hostName), string(names.nodename))

    XCTAssertGreaterThan(try SystemControl.value(.osRevision), 0)
    XCTAssertGreaterThan(try SystemControl.value(.maxFiles), 0)
    XCTAssertGreaterThan(try SystemControl.value(.maxFilesPerProcess), 0)
    XCTAssertGreaterThan(try SystemControl.value(.maxProcesses), 0)
    XCTAssertGreaterThan(try SystemControl.value(.maxProcessesPerUser), 0)
    XCTAssertEqual(
      Int(try SystemControl.value(.maxArgumentBytes)), try SystemConfig.value(.maxArgumentBytes))
    XCTAssertEqual(
      Int(try SystemControl.value(.maxSupplementaryGroups)),
      try SystemConfig.value(.maxSupplementaryGroups))
    XCTAssertGreaterThan(try SystemControl.value(.posixVersion), 0)
    XCTAssertGreaterThanOrEqual(try SystemControl.value(.securityLevel), -1)

    let boot = try SystemControl.value(.bootTime)
    XCTAssertGreaterThan(boot.tv_sec, 0)
    XCTAssertLessThanOrEqual(boot.tv_sec, time(nil))
    _ = try SystemControl.value(.sleepTime)
    _ = try SystemControl.value(.wakeTime)
    XCTAssertGreaterThan(try SystemControl.value(.clockRate).hz, 0)
    XCTAssertGreaterThan(try SystemControl.value(.loadAverage).fscale, 0)
    _ = try SystemControl.value(.swapUsage)
  }

  func testProcesses() throws {
    let current = try SystemControl.value(.process(.current))
    XCTAssertEqual(current.kp_proc.p_pid, getpid())
    XCTAssertEqual(current.kp_eproc.e_ppid, getppid())
    XCTAssertEqual(current.kp_eproc.e_pcred.p_ruid, getuid())
    XCTAssertEqual(current.kp_eproc.e_ucred.cr_uid, geteuid())

    // The Swift-named accessors, which a client that doesn't import
    // Darwin reads.
    XCTAssertEqual(current.processID, .current)
    XCTAssertEqual(current.parentProcessID, .parent)
    XCTAssertEqual(current.processGroupID.rawValue, getpgrp())
    XCTAssertEqual(current.realUserID, .real)
    XCTAssertEqual(current.effectiveUserID, .effective)
    XCTAssertEqual(current.savedUserID, .effective)
    XCTAssertEqual(current.realGroupID, .real)
    XCTAssertEqual(current.savedGroupID, .effective)
    XCTAssertFalse(current.isTraced)
    let program = String(CommandLine.arguments[0].split(separator: "/").last ?? "")
    XCTAssertFalse(current.commandName.isEmpty)
    XCTAssertTrue(program.hasPrefix(current.commandName), "\(current.commandName) \(program)")
    XCTAssertLessThanOrEqual(current.commandName.utf8.count, Int(MAXCOMLEN))
    // Nor is launchd, process 1.
    XCTAssertFalse(try SystemControl.value(.process(ProcessID(1))).isTraced)

    // The kernel returns no information, rather than an error, for a
    // process that doesn't exist.
    XCTAssertThrowsError(try SystemControl.value(.process(ProcessID(.max)))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }

    let all = try SystemControl.value(.allProcesses)
    XCTAssertTrue(all.contains { $0.kp_proc.p_pid == getpid() })
    XCTAssertTrue(all.contains { $0.kp_proc.p_pid == 1 })
    let mine = try SystemControl.value(.processes(ofUser: .effective))
    XCTAssertTrue(mine.contains { $0.kp_proc.p_pid == getpid() })
    XCTAssertTrue(mine.allSatisfy { $0.kp_eproc.e_ucred.cr_uid == geteuid() })
    let real = try SystemControl.value(.processes(ofRealUser: .real))
    XCTAssertTrue(real.contains { $0.kp_proc.p_pid == getpid() })
    let group = try SystemControl.value(.processes(inGroup: ProcessID(getpgrp())))
    XCTAssertTrue(group.contains { $0.kp_proc.p_pid == getpid() })

    // The arguments begin with their count, then the executable's path.
    let arguments = try SystemControl.value(.processArguments(.current))
    let count = arguments.withUnsafeBytes { $0.load(as: CInt.self) }
    XCTAssertEqual(Int(count), CommandLine.arguments.count)
    let path = arguments[MemoryLayout<CInt>.size...].prefix { $0 != 0 }
    XCTAssertFalse(path.isEmpty)
  }

  func testNames() throws {
    let byString = SystemControl.Name<Int32>("hw.ncpu")
    XCTAssertEqual(byString.string, "hw.ncpu")
    XCTAssertNil(byString.identifier)
    XCTAssertEqual("\(byString)", "hw.ncpu")

    let resolved = try SystemControl.Name<Int32>(resolving: "hw.ncpu")
    XCTAssertEqual(resolved.identifier, [CTL_HW, HW_NCPU])
    XCTAssertNil(resolved.string)
    XCTAssertEqual("\(resolved)", "[\(CTL_HW), \(HW_NCPU)]")
    XCTAssertEqual(try SystemControl.value(resolved), try SystemControl.value(byString))
    XCTAssertNotEqual(resolved, byString)

    XCTAssertThrowsError(try SystemControl.Name<Int32>(resolving: "no.such.name")) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<Int32>("no.such.name"))) {
      XCTAssertEqual($0 as? Errno, .noSuchFileOrDirectory)
    }
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<Int32>(identifier: []))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
  }

  func testSizes() throws {
    // A value of the wrong size throws, rather than being read in part.
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<Int64>("hw.ncpu"))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<Int16>("hw.ncpu"))) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }
    // The kernel narrows a 64-bit integer to 32 bits if it fits.
    XCTAssertEqual(
      Int64(try SystemControl.value(SystemControl.Name<Int32>("hw.pagesize"))),
      try SystemControl.value(.pageSize))
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<Int32>("hw.memsize"))) {
      XCTAssertEqual($0 as? Errno, .outOfRange)
    }
    XCTAssertThrowsError(try SystemControl.value(SystemControl.Name<[Int64]>("kern.ostype"))) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }

    XCTAssertEqual(try SystemControl.valueSize(.processorCount), 4)
    XCTAssertEqual(try SystemControl.valueSize(.osType), 7)
    var buffer = [UInt8](repeating: 0xFF, count: 16)
    let count = try buffer.withUnsafeMutableBytes { try SystemControl.value(.osType, into: $0) }
    XCTAssertEqual(count, 7)
    XCTAssertEqual(Array(buffer[..<count]), Array("Darwin\0".utf8))
    XCTAssertThrowsError(
      try buffer.withUnsafeMutableBytes { try SystemControl.value(.kernelVersion, into: $0) }
    ) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }
    XCTAssertThrowsError(
      try buffer.withUnsafeMutableBytes {
        try SystemControl.value(.allProcesses, into: $0)
      }
    ) {
      XCTAssertEqual($0 as? Errno, .noMemory)
    }

    // A string is read as bytes, too.
    let bytes = try SystemControl.value(SystemControl.Name<[UInt8]>("kern.ostype"))
    XCTAssertEqual(bytes, Array("Darwin\0".utf8))
  }

  func testSetValue() throws {
    guard geteuid() != 0 else { throw XCTSkip("The test runs with privileges") }
    let maxProcesses = try SystemControl.value(.maxProcesses)
    XCTAssertThrowsError(try SystemControl.setValue(maxProcesses, for: .maxProcesses)) {
      XCTAssertEqual($0 as? Errno, .notPermitted)
    }
    XCTAssertThrowsError(try SystemControl.setValue("host", for: .hostName)) {
      XCTAssertEqual($0 as? Errno, .notPermitted)
    }
    // A variable that can't change throws regardless of privileges.
    XCTAssertThrowsError(try SystemControl.setValue(Int32(1), for: .processorCount))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
