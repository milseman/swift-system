/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Darwin
import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@available(System 199, *)
private let pageSize = (try? SystemConfig.value(.pageSize)).flatMap { $0 } ?? 4096

// Each test creates zones of its own, and these tests run one at a time:
// none can destroy a zone while another reads every zone's statistics, as
// malloc_zone_statistics does without the lock that malloc_destroy_zone
// takes, and no zone is created where one was just destroyed.
//
// A zone's statistics don't count its blocks exactly: about one new zone in
// 250 is a ProbGuard zone, whose statistics are all zero. So the tests ask
// which zone holds a block instead.
@Suite("Memory zones", .serialized)
private struct MemoryZoneTests {
  @available(System 199, *)
  @Test func theDefaultZoneAllocatesMemorysBlocks() throws {
    let zone = Memory.Zone.default
    #expect(zone.name == "DefaultMallocZone")
    let block = try Memory.allocate(byteCount: 16)
    defer { Memory.free(block) }
    #expect(Memory.Zone(containing: block) == zone)
  }

  @available(System 199, *)
  @Test func aZoneAllocatesAndFreesItsOwnBlocks() throws {
    let zone = try Memory.Zone.create()
    defer { zone.destroy() }
    #expect(zone != .default)
    #expect(zone.name == nil)

    let block = try zone.allocate(byteCount: 1000)
    let zeroed = try zone.allocateZeroed(count: 10, stride: 100)
    #expect(UnsafeRawBufferPointer(start: zeroed, count: 1000).allSatisfy { $0 == 0 })
    let aligned = try zone.allocate(byteCount: 10, alignment: 256)
    #expect(Int(bitPattern: aligned) % 256 == 0)
    let page = try zone.allocatePageAligned(byteCount: 100)
    #expect(Int(bitPattern: page) % pageSize == 0)
    #expect(UnsafeRawBufferPointer(start: page, count: 100).allSatisfy { $0 == 0 })
    let blocks: [UnsafeMutableRawPointer] = [block, zeroed, aligned, page]
    #expect(blocks.allSatisfy { Memory.Zone(containing: $0) == zone })

    let inUse = zone.statistics()
    #expect(inUse.bytesReserved >= inUse.bytesInUse)

    // The zone's own free, and Memory.free, which finds the zone. Then no
    // zone holds the small blocks, whose memory the zone keeps. (A
    // page-aligned block's memory can go back to the system, and to
    // another thread.)
    zone.free(block)
    zone.free(zeroed)
    Memory.free(aligned)
    Memory.free(page)
    zone.free(nil)
    #expect(blocks.dropLast().allSatisfy { Memory.Zone(containing: $0) == nil })
  }

  @available(System 199, *)
  @Test func reallocateStaysInTheZone() throws {
    let zone = try Memory.Zone.create()
    defer { zone.destroy() }
    var block = try zone.reallocate(nil, byteCount: 8)
    block.storeBytes(of: 42, as: Int.self)
    block = try zone.reallocate(block, byteCount: 100_000)
    #expect(block.load(as: Int.self) == 42)
    #expect(Memory.Zone(containing: block) == zone)
    // Memory.reallocate finds the zone too.
    block = try Memory.reallocate(block, byteCount: 16)
    #expect(Memory.Zone(containing: block) == zone)
    #expect(throws: Errno.noMemory) { try zone.reallocate(block, byteCount: .max) }
    #expect(block.load(as: Int.self) == 42)
    zone.free(block)
  }

  @available(System 199, *)
  @Test func aZoneReportsFailures() throws {
    let zone = try Memory.Zone.create()
    defer { zone.destroy() }
    #expect(throws: Errno.noMemory) { try zone.allocate(byteCount: .max) }
    #expect(throws: Errno.noMemory) { try zone.allocateZeroed(count: .max, stride: 2) }
    #expect(throws: Errno.invalidArgument) { try zone.allocate(byteCount: 8, alignment: 24) }
  }

  @available(System 199, *)
  @Test func reallocateFreeingOnFailureFreesTheBlock() throws {
    // No other test allocates in this zone, so the block's memory stays
    // the zone's once it's free.
    let zone = try Memory.Zone.create(name: "reallocf test")
    defer { zone.destroy() }
    var block = try zone.allocate(byteCount: 64)
    block = try Memory.reallocateFreeingOnFailure(block, byteCount: 128)
    #expect(Memory.Zone(containing: block) == zone)
    #expect(throws: Errno.noMemory) {
      try Memory.reallocateFreeingOnFailure(block, byteCount: .max)
    }
    #expect(Memory.Zone(containing: block) == nil)
  }

  @available(System 199, *)
  @Test func destroyingAZoneFreesItsBlocks() throws {
    let zone = try Memory.Zone.create(name: "destroyed")
    var blocks: [UnsafeMutableRawPointer] = []
    for _ in 0..<100 { blocks.append(try zone.allocate(byteCount: 1000)) }
    #expect(blocks.allSatisfy { Memory.Zone(containing: $0) == zone })
    let block = try #require(blocks.last)
    zone.destroy()
    // The zone is gone, so it doesn't claim its old block. Asking about an
    // address reads only the zones' records, not the memory there.
    #expect(Memory.Zone(containing: block) != zone)
  }

  @available(System 199, *)
  @Test func zonesHaveNames() throws {
    let zone = try Memory.Zone.create(name: "cache")
    defer { zone.destroy() }
    #expect(zone.name == "cache")
    zone.setName("renamed")
    #expect(zone.name == "renamed")
    zone.setName(nil)
    #expect(zone.name == nil)
  }

  @available(System 199, *)
  @Test func memoryThatNoZoneAllocatedHasNoZone() {
    var local = 0
    withUnsafeBytes(of: &local) { #expect(Memory.Zone(containing: $0.baseAddress!) == nil) }
  }

  @available(System 199, *)
  @Test func pressureRelief() throws {
    let zone = try Memory.Zone.create()
    defer { zone.destroy() }
    var blocks: [UnsafeMutableRawPointer] = []
    for _ in 0..<1000 { blocks.append(try zone.allocate(byteCount: 4096)) }
    for block in blocks { zone.free(block) }
    #expect(zone.relievePressure() >= 0)
    #expect(zone.relievePressure(goal: 4096) >= 0)
    // Relieving every zone takes the lock that destroying one does.
    #expect(Memory.Zone.relievePressureInAllZones(goal: 1) >= 0)
  }

  /// In a process of its own: reading every zone's statistics crashes if
  /// another thread destroys a zone meanwhile, which a test outside this
  /// suite could do.
  @available(System 199, *)
  @Test func statisticsForAllZones() async {
    await #expect(processExitsWith: .success) {
      let all = Memory.Zone.statisticsForAllZones()
      if all.blocksInUse <= 0 { exit(1) }
      if all.bytesReserved < all.bytesInUse { exit(2) }
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
