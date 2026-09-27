/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: resource limits and credentials. These are XCTest tests, which
// run one at a time in a process of their own, since they change the
// process's limits. They never lower a hard limit, which an unprivileged
// process can't raise again.

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
final class ResourceLimitTests: XCTestCase {
  func testReadingALimit() throws {
    let limit = try ResourceLimit.current(for: .openFiles)
    XCTAssertLessThanOrEqual(limit.soft, limit.hard)
    XCTAssertEqual(ResourceLimit(rawValue: limit.rawValue), limit)
    var raw = rlimit()
    XCTAssertEqual(getrlimit(numericCast(_RLIMIT_NOFILE), &raw), 0)
    XCTAssertEqual(limit.soft.rawValue, raw.rlim_cur)
    XCTAssertEqual(limit.hard.rawValue, raw.rlim_max)
  }

  func testChangingTheSoftLimit() throws {
    let original = try ResourceLimit.current(for: .openFiles)
    guard original.soft != .unlimited, original.soft.rawValue > 64 else {
      throw XCTSkip("The soft limit is \(original.soft)")
    }
    defer { try? ResourceLimit.setCurrent(original, for: .openFiles) }
    var lowered = original
    lowered.soft = ResourceLimit.Value(rawValue: original.soft.rawValue - 1)
    try ResourceLimit.setCurrent(lowered, for: .openFiles)
    XCTAssertEqual(try ResourceLimit.current(for: .openFiles), lowered)
    try ResourceLimit.setCurrent(original, for: .openFiles)
    XCTAssertEqual(try ResourceLimit.current(for: .openFiles), original)
  }

  func testASoftLimitAboveTheHardLimitIsInvalid() throws {
    let original = try ResourceLimit.current(for: .openFiles)
    guard original.soft != .unlimited, original.soft.rawValue > 1 else {
      throw XCTSkip("The soft limit is \(original.soft)")
    }
    let invalid = ResourceLimit(
      soft: original.soft, hard: ResourceLimit.Value(rawValue: original.soft.rawValue - 1))
    XCTAssertThrowsError(try ResourceLimit.setCurrent(invalid, for: .openFiles)) {
      XCTAssertEqual($0 as? Errno, .invalidArgument)
    }
    XCTAssertEqual(try ResourceLimit.current(for: .openFiles), original)
  }

  func testValues() {
    let value: ResourceLimit.Value = 1024
    XCTAssertEqual(value.rawValue, 1024)
    XCTAssertLessThan(value, .unlimited)
    XCTAssertEqual(value.description, "1024")
    XCTAssertEqual(ResourceLimit.Value.unlimited.description, "unlimited")
    XCTAssertEqual(
      ResourceLimit(soft: 256, hard: .unlimited).description, "soft 256, hard unlimited")
    XCTAssertNotEqual(ResourceLimit.Resource.openFiles, .coreFileSize)
  }

  func testEveryResourceCanBeRead() throws {
    var resources: [ResourceLimit.Resource] = [
      .cpuTime, .fileSize, .dataSize, .stackSize, .coreFileSize, .residentSetSize,
      .processes, .openFiles, .lockedMemory, .addressSpace,
    ]
    #if os(Linux) || os(Android)
    resources += [
      .fileLocks, .pendingSignals, .messageQueueBytes, .niceCeiling, .realTimePriority,
      .realTimeCPUTime,
    ]
    #endif
    for resource in resources {
      let limit = try ResourceLimit.current(for: resource)
      XCTAssertLessThanOrEqual(limit.soft, limit.hard, "\(resource)")
    }
  }
}

@available(System 199, *)
final class CredentialTests: XCTestCase {
  // Setting the IDs a process already has changes nothing, with or
  // without privilege.
  func testSettingTheCurrentIDs() throws {
    try UserID.set(UserID.real)
    try UserID.setEffective(UserID.effective)
    try UserID.set(real: nil, effective: nil)
    try GroupID.set(GroupID.real)
    try GroupID.setEffective(GroupID.effective)
    try GroupID.set(real: nil, effective: nil)
    XCTAssertEqual(UserID.real.rawValue, getuid())
    XCTAssertEqual(GroupID.real.rawValue, getgid())
  }

  func testSettingSupplementaryGroupsTakesPrivilege() throws {
    let groups = try GroupID.supplementary()
    do {
      try GroupID.setSupplementary(groups)
      XCTAssertEqual(Set(try GroupID.supplementary()), Set(groups))
    } catch Errno.notPermitted {
      XCTAssertNotEqual(geteuid(), 0)
    } catch Errno.invalidArgument {
      // More groups than setgroups takes, as Darwin reports for users
      // in more than 16.
    }
  }

  #if ENABLE_MOCKING
  func testCredentialCalls() {
    let user = UserID(rawValue: 501)
    let group = GroupID(rawValue: 20)
    let cases: [MockTestCase] = [
      MockTestCase(name: "setuid", .noInterrupt, 501 as uid_t) { _ in try UserID.set(user) },
      MockTestCase(name: "seteuid", .noInterrupt, 501 as uid_t) { _ in
        try UserID.setEffective(user)
      },
      MockTestCase(name: "setreuid", .noInterrupt, uid_t.max, 501 as uid_t) { _ in
        try UserID.set(real: nil, effective: user)
      },
      MockTestCase(name: "setgid", .noInterrupt, 20 as gid_t) { _ in try GroupID.set(group) },
      MockTestCase(name: "setegid", .noInterrupt, 20 as gid_t) { _ in
        try GroupID.setEffective(group)
      },
      MockTestCase(name: "setregid", .noInterrupt, 20 as gid_t, gid_t.max) { _ in
        try GroupID.set(real: group, effective: nil)
      },
      MockTestCase(name: "setgroups", .noInterrupt, 2, [20, 12] as [gid_t]) { _ in
        try GroupID.setSupplementary([group, GroupID(rawValue: 12)])
      },
      MockTestCase(name: "initgroups", .noInterrupt, "nobody", 20 as gid_t) { _ in
        try GroupID.setSupplementary(forUser: "nobody", including: group)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }

  func testResourceLimitCalls() {
    let cases: [MockTestCase] = [
      MockTestCase(name: "getrlimit", .noInterrupt, _RLIMIT_NOFILE) { _ in
        _ = try ResourceLimit.current(for: .openFiles)
      },
      MockTestCase(
        name: "setrlimit", .noInterrupt, _RLIMIT_CORE, 0 as UInt64, UInt64(_RLIM_INFINITY)
      ) { _ in
        try ResourceLimit.setCurrent(
          ResourceLimit(soft: 0, hard: .unlimited), for: .coreFileSize)
      },
    ]
    cases.forEach { $0.runAllTests() }
  }
  #endif
}

#endif // !os(Windows) && !os(WASI)
