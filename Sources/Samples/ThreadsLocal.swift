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

// Thread-specific storage, as NIO's ThreadSpecificVariable uses it to find
// the current thread's event loop: a key whose value differs on each
// thread, and which the system destroys when its thread finishes.
struct ThreadsLocal: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Give each thread its own value for a pthread key, destroyed when the thread finishes"
  )

  @Option(help: "The number of threads")
  var threads = 3

  // A static key lasts as long as the process, so it's never deleted.
  // Deleting a key leaks the values that other threads have for it.
  static let context = try! PThread.Key<RequestContext>()

  func run() throws {
    let log = Log()
    try ThreadsLocal.context.setValue(RequestContext("main", log))
    log.add("main sets its context")

    var ids: [PThread.ID] = []
    for number in 1...max(threads, 1) {
      let thread = try PThread {
        let before = ThreadsLocal.context.value()?.name ?? "none"
        try! ThreadsLocal.context.setValue(RequestContext("worker \(number)", log))
        let after = ThreadsLocal.context.value()?.name ?? "none"
        log.add("worker \(number) sees \(before), sets \(after), and finishes")
      }
      ids.append(thread.relinquish())
    }
    for id in ids {
      try PThread(taking: id).join()
    }

    log.add("main still sees \(ThreadsLocal.context.value()?.name ?? "none")")
    try ThreadsLocal.context.setValue(nil)
    for line in log.lines { print(line) }
  }
}

final class RequestContext: @unchecked Sendable {
  let name: String
  let log: Log

  init(_ name: String, _ log: Log) {
    self.name = name
    self.log = log
  }

  deinit {
    log.add("  \(name)'s context is destroyed")
  }
}

final class Log: @unchecked Sendable {
  private let mutex = try! PThread.Mutex()
  private var _lines: [String] = []

  func add(_ line: String) {
    try! mutex.withLock { _lines.append(line) }
  }

  var lines: [String] { try! mutex.withLock { _lines } }
}

#else

struct ThreadsLocal: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no pthreads"
  )

  func run() throws {
    complain("Error: threads-local needs pthreads, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI)
