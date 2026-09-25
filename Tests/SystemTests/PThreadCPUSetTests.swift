/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread.CPUSet and thread affinity. Each test changes
// the affinity only of a thread it creates.

#if os(Linux) || os(Android)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("PThread.CPUSet")
private struct PThreadCPUSetTests {
  @available(System 199, *)
  @Test func setOperations() {
    var set: PThread.CPUSet = [0, 3, 64]
    #expect(set.count == 3)
    #expect(set.contains(3))
    #expect(!set.contains(4))
    #expect(!set.contains(-1))
    #expect(!set.contains(PThread.CPUSet.capacity))
    #expect(Array(set) == [0, 3, 64])
    set.remove(3)
    set.remove(PThread.CPUSet.capacity + 1)
    #expect(Array(set) == [0, 64])
    #expect(!set.isEmpty)
    #expect(PThread.CPUSet().isEmpty)
    #expect(PThread.CPUSet([2, 1]) == [1, 2])
  }

  @available(System 199, *)
  @Test func currentAffinity() throws {
    let result = Locked<Result<(PThread.CPUSet, PThread.CPUSet), Errno>?>(nil)
    let thread = try PThread {
      result.withValue {
        $0 = Result { () throws(Errno) in
          let original = try PThread.currentAffinity()
          let first = PThread.CPUSet([original.first(where: { _ in true })!])
          try PThread.setCurrentAffinity(first)
          return (first, try PThread.currentAffinity())
        }
      }
    }
    try thread.join()
    let (requested, actual) = try #require(try result.value?.get())
    #expect(requested == actual)
  }

  @available(System 199, *)
  @Test func emptyAffinity() throws {
    let result = Locked<Errno?>(nil)
    let thread = try PThread {
      do throws(Errno) {
        try PThread.setCurrentAffinity([])
      } catch {
        result.withValue { $0 = error }
      }
    }
    try thread.join()
    #expect(result.value == .invalidArgument)
  }

  #if os(Linux)
  @available(System 199, *)
  @Test func affinityOfAnotherThread() throws {
    let release = Latch()
    let thread = try PThread { _ = release.wait() }
    defer { release.open() }
    let original = try thread.id.affinity()
    let first = PThread.CPUSet([original.first(where: { _ in true })!])
    try thread.id.setAffinity(first)
    #expect(try thread.id.affinity() == first)
  }
  #endif
}

#endif // os(Linux) || os(Android)
