/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Scenarios for the deinit policies (Sources/Allocator.swift), which run.sh
// runs once per policy, each in a process of its own, so that a trap ends
// only its scenario. `--list` prints each scenario's name and what it's
// modeled on; a name runs it and prints its outcome.

import SystemPackage
import MemoryPrototype
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct Failure: Error {}

@available(System 199, *)
func dropOnAnError() throws {
  var buffer = try Memory.Buffer<UInt8>(capacity: 16)
  try buffer.append(1)
  throw Failure()
}

@available(System 199, *)
let scenarios: [(name: String, modeledOn: String, run: () throws -> String)] = [
  ("explicit-free", "a buffer ended with free()", {
    let buffer = try Memory.Buffer<UInt8>(capacity: 16)
    buffer.free()
    return "ok"
  }),
  ("end-of-scope", "a buffer that goes out of scope, as most do", {
    var buffer = try Memory.Buffer<UInt8>(capacity: 16)
    try buffer.append(1)
    return "ok"
  }),
  ("error-path", "a buffer dropped by an error that ends its scope", {
    do { try dropOnAnError() } catch { return "threw" }
    return "ok"
  }),
  ("relinquished", "ownership handed to C, which frees", {
    let buffer = try Memory.Buffer<UInt8>(capacity: 16)
    let (start, _, _) = buffer.relinquish()
    Memory.freeFunction(start)
    return "ok"
  }),
  ("adopted", "a strdup result adopted with init(unsafeTaking:)", {
    let copy = strdup("from C")!
    let adopted = Memory.Buffer(unsafeTaking: copy, count: 7, capacity: 7)
    return adopted.count == 7 ? "ok" : "wrong count"
  }),
  ("pool", "an IOVectorPool dropped with its owner", {
    let pool = try IOVectorPool(limit: 4)
    return pool.capacity == 4 ? "ok" : "wrong capacity"
  }),
  // A double free, which is undefined behavior: these return "undetected"
  // only if nothing trapped.
  ("freed-twice-small", "a strdup result adopted, and freed by C too", {
    let copy = strdup("from C")!
    let adopted = Memory.Buffer(unsafeTaking: copy, count: 7, capacity: 7)
    free(copy)
    _ = consume adopted
    return "undetected"
  }),
  ("freed-twice-large", "the same, for a 200 KB block", {
    let raw = malloc(200_000)!
    let adopted = Memory.Buffer(
      unsafeTaking: raw.assumingMemoryBound(to: UInt8.self), count: 0, capacity: 200_000)
    free(raw)
    _ = consume adopted
    return "undetected"
  }),
]

if #available(System 199, *) {
  let arguments = CommandLine.arguments.dropFirst()
  if arguments.first == "--list" {
    for scenario in scenarios { print("\(scenario.name)\t\(scenario.modeledOn)") }
  } else if let name = arguments.first, let scenario = scenarios.first(where: { $0.name == name }) {
    do { print(try scenario.run()) } catch { print("threw \(error)") }
  } else {
    print("usage: policies --list | <scenario>")
    exit(2)
  }
}
