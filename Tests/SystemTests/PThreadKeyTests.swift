/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: tests for PThread.Key. Each test creates keys of its own, and
// sets values only on threads it creates or on the thread it runs on, which
// it clears before returning.

#if !os(Windows) && !os(WASI)

import Testing

#if SYSTEM_PACKAGE
@testable import SystemPackage
#else
@testable import System
#endif

@Suite("PThread.Key")
private struct PThreadKeyTests {
  // A value that reports its destruction.
  @available(System 199, *)
  fileprivate final class Tracked: @unchecked Sendable {
    let name: String
    let destroyed: Locked<[String]>
    init(_ name: String, _ destroyed: Locked<[String]>) {
      self.name = name
      self.destroyed = destroyed
    }
    deinit {
      let name = self.name
      destroyed.withValue { $0.append(name) }
    }
  }

  @available(System 199, *)
  @Test func eachThreadHasItsOwnValue() throws {
    let key = try PThread.Key<Int>()
    #expect(key.value() == nil)
    try key.setValue(1)
    let seen = Locked<[Int?]>([])
    let thread = try PThread {
      seen.withValue { $0.append(key.value()) }
      try! key.setValue(2)
      seen.withValue { $0.append(key.value()) }
    }
    try thread.join()
    #expect(seen.value == [nil, 2])
    #expect(key.value() == 1)
    try key.setValue(nil)
    #expect(key.value() == nil)
  }

  @available(System 199, *)
  @Test func valueIsDestroyedWhenItsThreadFinishes() throws {
    let destroyed = Locked<[String]>([])
    let key = try PThread.Key<Tracked>()
    let thread = try PThread {
      try! key.setValue(Tracked("thread", destroyed))
    }
    try thread.join()
    #expect(destroyed.value == ["thread"])
  }

  @available(System 199, *)
  @Test func settingAValueDestroysThePreviousOne() throws {
    let destroyed = Locked<[String]>([])
    let key = try PThread.Key<Tracked>()
    try key.setValue(Tracked("first", destroyed))
    try key.setValue(Tracked("second", destroyed))
    #expect(destroyed.value == ["first"])
    #expect(key.value()?.name == "second")
    try key.setValue(nil)
    #expect(destroyed.value == ["first", "second"])
  }

  @available(System 199, *)
  @Test func destroyingTheKeyDestroysTheCallingThreadsValue() throws {
    let destroyed = Locked<[String]>([])
    do {
      let key = try PThread.Key<Tracked>()
      try key.setValue(Tracked("mine", destroyed))
    }
    #expect(destroyed.value == ["mine"])
  }

  @available(System 199, *)
  @Test func valueDestroyedAtThreadExitCanSetAnotherKey() throws {
    // POSIX runs destructors again, up to PTHREAD_DESTRUCTOR_ITERATIONS
    // times, for values that destructors set.
    let keys = ChainedKeys()
    let thread = try PThread {
      try! keys.first.setValue(SetsSecondKey(keys))
    }
    try thread.join()
    #expect(keys.destroyed.value == ["set during exit"])
  }

  @available(System 199, *)
  @Test func keysAreSendableWhenTheirValuesAre() {
    func requireSendable<T: Sendable & ~Copyable>(_: borrowing T) {}
    let key = try! PThread.Key<Int>()
    requireSendable(key)
  }
}

// Two keys, where destroying the first key's value sets the second key's.
@available(System 199, *)
private final class ChainedKeys: Sendable {
  let first = try! PThread.Key<SetsSecondKey>()
  let second = try! PThread.Key<PThreadKeyTests.Tracked>()
  let destroyed = Locked<[String]>([])
}

@available(System 199, *)
private final class SetsSecondKey: @unchecked Sendable {
  let keys: ChainedKeys
  init(_ keys: ChainedKeys) { self.keys = keys }
  deinit {
    try? keys.second.setValue(PThreadKeyTests.Tracked("set during exit", keys.destroyed))
  }
}

#endif // !os(Windows) && !os(WASI)
