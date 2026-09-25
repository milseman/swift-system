/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

#if !os(Windows) && !os(WASI)

// What a thread knows about itself: its identifier, name, scheduling, and
// on Darwin its quality of service, or on Linux the processors it may run on.
// Each platform shows only what it has, rather than an emulation of what the
// other has: Darwin can name only the calling thread, and has no CPU sets;
// Linux has no quality-of-service classes or main-thread check.
struct ThreadsInfo: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show the calling thread's identity and scheduling, and a new thread's"
  )

  @Option(name: .customLong("stack-kib"), help: "The stack size of the new thread, in KiB")
  var stackKiB: Int?

  func run() throws {
    print("The calling thread:")
    printTable(try describe())

    var attributes = PThread.Attributes()
    attributes.stackSize = stackKiB.map { $0 * 1024 }
    #if SYSTEM_PACKAGE_DARWIN
    attributes.qosClass = .utility
    #endif
    let rows = Result<[[String]], Errno>?.none
    let result = Locked(rows)
    let thread = try PThread(attributes: attributes) {
      // The name is at most 15 bytes on Linux.
      try? PThread.setCurrentName("threads-info")
      result.set(Result { () throws(Errno) in try describe() })
    }
    let id = thread.id
    try thread.join()
    print("A new thread, \(id == .current ? "the same" : "not the calling one"):")
    printTable(try result.get()!.get())
  }
}

private func describe() throws(Errno) -> [[String]] {
  let id = PThread.ID.current
  var rows: [[String]] = []
  rows.append(["ID", "\(id.rawValue)"])
  #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
  let name = try id.name()
  rows.append(["name", name.isEmpty ? "(none)" : name])
  #endif
  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  rows.append(["main thread", PThread.isMainThread ? "yes" : "no"])
  #endif
  let scheduling = try id.scheduling()
  let range = try scheduling.policy.priorityRange()
  rows.append([
    "scheduling",
    "\(policyName(scheduling.policy)), priority \(scheduling.priority) of \(range)",
  ])
  #if SYSTEM_PACKAGE_DARWIN
  let (qosClass, relativePriority) = try id.qosClass()
  rows.append(["QoS class", "\(qosName(qosClass)), relative priority \(relativePriority)"])
  rows.append(["stack size", amount(Int64(pthread_get_stacksize_np(pthread_self())))])
  #endif
  #if os(Linux) || os(Android)
  let processors = try PThread.currentAffinity()
  rows.append(["may run on", processors.map(String.init).joined(separator: " ")])
  #endif
  return rows
}

private func policyName(_ policy: PThread.SchedulingPolicy) -> String {
  switch policy {
  case .other: return "other"
  case .fifo: return "FIFO"
  case .roundRobin: return "round robin"
  default: return "policy \(policy.rawValue)"
  }
}

#if SYSTEM_PACKAGE_DARWIN
private func qosName(_ qosClass: PThread.QoSClass) -> String {
  switch qosClass {
  case .userInteractive: return "user interactive"
  case .userInitiated: return "user initiated"
  case .default: return "default"
  case .utility: return "utility"
  case .background: return "background"
  case .unspecified: return "unspecified"
  default: return "class \(qosClass.rawValue.rawValue)"
  }
}
#endif

// A value set on one thread and read on another.
private final class Locked<Value>: @unchecked Sendable {
  private let mutex = try! PThread.Mutex()
  private var value: Value
  init(_ value: Value) { self.value = value }
  func set(_ newValue: Value) { try! mutex.withLock { value = newValue } }
  func get() -> Value { try! mutex.withLock { value } }
}

#else

struct ThreadsInfo: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no pthreads"
  )

  func run() throws {
    complain("Error: threads-info needs pthreads, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI)
