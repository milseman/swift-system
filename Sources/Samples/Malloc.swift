/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if !os(Windows) && !os(WASI)

struct Malloc: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "malloc",
    abstract: "Show how the C allocator rounds requests up, then fill and free a heap of blocks"
  )

  @Option(help: "How many blocks to allocate")
  var count: Int = 1000

  @Option(help: "The size of each block, in bytes")
  var size: Int = 100

  func run() throws {
    guard count >= 0, size >= 0 else {
      complain("The count and the size can't be negative")
      throw ExitCode.failure
    }
    try printSizes()
    try fillAndFree()
    try printAlignments()
    try clearAKey()
  }

  /// Each request gets a block of at least its size, rounded up to one
  /// of the allocator's size classes.
  private func printSizes() throws {
    #if !os(OpenBSD)
    print("Requests, and the blocks the allocator gives them:")
    #if SYSTEM_PACKAGE_DARWIN
    var rows = [["Request", "Block", "Good size"]]
    #else
    var rows = [["Request", "Block"]]
    #endif
    for request in Set([0, 1, 16, 17, 100, 1000, 4000, 100_000, size]).sorted() {
      let block = try Memory.allocate(byteCount: request)
      defer { Memory.free(block) }
      var row = ["\(request)", "\(Memory.usableSize(of: block))"]
      #if SYSTEM_PACKAGE_DARWIN
      // The size to ask for so that nothing is wasted.
      row.append("\(Memory.goodSize(for: request))")
      #endif
      rows.append(row)
    }
    printTable(rows)
    #endif
  }

  #if SYSTEM_PACKAGE_DARWIN
  /// Fills a zone of its own, whose statistics only this process's use of
  /// it changes, and destroys it with the blocks still in it.
  private func fillAndFree() throws {
    let zone = try Memory.Zone.create(name: "system-samples malloc")
    print("\nCreated the zone \"\(zone.name ?? "")\"")
    var blocks: [UnsafeMutableRawPointer] = []
    for _ in 0..<count { blocks.append(try zone.allocate(byteCount: size)) }
    report(zone.statistics(), "after allocating \(count) blocks of \(size) bytes")

    for block in stride(from: 0, to: blocks.count, by: 2).map({ blocks[$0] }) { zone.free(block) }
    report(zone.statistics(), "after freeing every other block")
    let released = zone.relievePressure()
    print("  Relieving memory pressure returned \(amount(Int64(released))) to the system")

    // The blocks left needn't be freed one by one.
    zone.destroy()
    print("  Destroyed the zone, and the \(count / 2) blocks left in it")
  }

  private func report(_ statistics: Memory.Zone.Statistics, _ when: String) {
    print("  \(statistics.blocksInUse) blocks, \(amount(Int64(statistics.bytesInUse))) in use, "
      + "\(amount(Int64(statistics.bytesReserved))) reserved, \(when)")
  }
  #elseif os(Linux) && canImport(Glibc)
  /// Fills glibc's heap, frees it, and returns the free memory.
  private func fillAndFree() throws {
    print("")
    var blocks: [UnsafeMutableRawPointer] = []
    report("before allocating")
    for _ in 0..<count { blocks.append(try Memory.allocate(byteCount: size)) }
    report("after allocating \(count) blocks of \(size) bytes")
    for block in blocks { Memory.free(block) }
    report("after freeing them")
    print(Memory.trim() ? "  Trimming returned memory to the system" : "  Trimming found nothing to return")
    report("after trimming")
  }

  private func report(_ when: String) {
    let statistics = Memory.allocatorStatistics()
    print("  \(amount(Int64(statistics.bytesInUse))) in use, "
      + "\(amount(Int64(statistics.freeBytes))) free, \(when)")
  }
  #else
  private func fillAndFree() throws {
    var blocks: [UnsafeMutableRawPointer] = []
    for _ in 0..<count { blocks.append(try Memory.allocate(byteCount: size)) }
    for block in blocks { Memory.free(block) }
    print("\nAllocated and freed \(count) blocks of \(size) bytes")
  }
  #endif

  /// A block at an address that's a multiple of an alignment,
  /// such as a cache line or a page.
  private func printAlignments() throws {
    let pageSize = try SystemConfig.value(.pageSize) ?? 4096
    print("\nAligned blocks:")
    var rows = [["Alignment", "Address"]]
    for alignment in [64, pageSize] {
      let block = try Memory.allocate(byteCount: size, alignment: alignment)
      defer { Memory.free(block) }
      rows.append(["\(alignment)", "0x" + String(UInt(bitPattern: Int(bitPattern: block)), radix: 16)])
    }
    printTable(rows)
  }

  /// Clearing a secret with stores that the compiler can't remove.
  private func clearAKey() throws {
    var key = try Entropy.bytes(count: 32)
    // ... use the key ...
    key.withUnsafeMutableBytes { Memory.secureZero($0) }
    print("\nCleared a 32-byte key: \(key.allSatisfy { $0 == 0 } ? "all zeros" : "not cleared")")
  }
}

#else
struct Malloc: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "malloc",
    abstract: "Unavailable: System has no C allocator API on Windows or WASI"
  )

  func run() throws {
    complain("malloc isn't available on this platform")
    throw ExitCode.failure
  }
}
#endif
