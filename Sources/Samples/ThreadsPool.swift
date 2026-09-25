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

// A pool of named worker threads that take jobs from a queue, as NIO's
// NIOThreadPool does: a pthread mutex protects the queue, and a condition
// variable wakes one worker per job (signal), or all of them to shut down
// (broadcast).
struct ThreadsPool: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Run jobs on a pool of named threads, with a pthread mutex and condition variable"
  )

  @Option(help: "The number of worker threads")
  var workers = 4

  @Option(help: "The number of jobs")
  var jobs = 20

  func run() throws {
    let queue = try JobQueue()

    // NIO creates its threads with the main thread's quality of service.
    var attributes = PThread.Attributes()
    #if SYSTEM_PACKAGE_DARWIN
    attributes.qosClass = .main
    #endif

    // An Array can't hold noncopyable PThreads, so the pool keeps their
    // IDs, and each join below takes ownership again.
    var threads: [PThread.ID] = []
    for number in 1...max(workers, 1) {
      let thread = try PThread(attributes: attributes) {
        // Linux limits names to 15 bytes; Darwin to 63.
        try? PThread.setCurrentName("pool-\(number)")
        queue.work()
      }
      threads.append(thread.relinquish())
    }

    for job in 1...max(jobs, 1) {
      try queue.add(job)
    }
    try queue.shutDown()
    for id in threads {
      try PThread(taking: id).join()
    }

    print("\(queue.results.count) jobs on \(threads.count) threads:")
    let byThread = Dictionary(grouping: queue.results, by: \.thread)
    printTable(byThread.keys.sorted().map { name in
      let jobs = byThread[name]!.map(\.job).sorted()
      return [name, "\(jobs.count) jobs", jobs.map(String.init).joined(separator: " ")]
    })
  }
}

private final class JobQueue: @unchecked Sendable {
  struct Result {
    var job: Int
    var thread: String
  }

  let mutex: PThread.Mutex
  let workAvailable: PThread.Condition
  private var jobs: [Int] = []
  private var isShutDown = false
  private(set) var results: [Result] = []

  init() throws {
    // An error-checking mutex reports a relock or a stray unlock,
    // as NIO's lock does in debug builds.
    mutex = try PThread.Mutex(attributes: .init(kind: .errorChecking))
    workAvailable = try PThread.Condition()
  }

  func add(_ job: Int) throws {
    try mutex.withLock { jobs.append(job) }
    try workAvailable.signal()
  }

  func shutDown() throws {
    try mutex.withLock { isShutDown = true }
    try workAvailable.broadcast()
  }

  // Runs jobs until the queue is shut down and empty.
  func work() {
    let name = (try? PThread.ID.current.name()) ?? "?"
    while let job = try! next() {
      // The job's work would go here, outside the lock.
      usleep(1_000)
      try! mutex.withLock { results.append(Result(job: job, thread: name)) }
    }
  }

  private func next() throws -> Int? {
    try mutex.withLock {
      // Waits can end without a signal, so check the queue again each time.
      while jobs.isEmpty && !isShutDown {
        try workAvailable.wait(on: mutex)
      }
      return jobs.isEmpty ? nil : jobs.removeFirst()
    }
  }
}

#else

struct ThreadsPool: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no pthreads"
  )

  func run() throws {
    complain("Error: threads-pool needs pthreads, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // !os(Windows) && !os(WASI)
