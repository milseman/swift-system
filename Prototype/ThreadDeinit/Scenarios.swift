// Uses of an owned thread, each modeled on a test, a sample, or a pattern
// from an adopter. Each scenario runs in its own process (see run.sh), so a
// trap or a hang ends only that one. A scenario returns what it observed,
// and main.swift adds what the Ledger recorded.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct Scenario {
  var name: String
  var modeledOn: String
  var run: () throws -> [String]
}

struct Stop: Error {}

func allScenarios() -> [Scenario] { [
  Scenario(name: "explicit-join", modeledOn: "PThreadTests.joinWaitsForTheBody") {
    let done = Flag()
    let thread = OwnedThread { usleep(20_000); done.set() }
    thread.join()
    return done.isSet ? [] : ["work unfinished"]
  },
  Scenario(name: "explicit-detach", modeledOn: "PThreadTests.detach") {
    let done = Latch()
    let thread = OwnedThread { done.open() }
    thread.detach()
    return done.wait() ? [] : ["work unfinished"]
  },
  Scenario(name: "scope-exit", modeledOn: "an owner that goes out of scope") {
    let done = Flag()
    do {
      let thread = OwnedThread { usleep(50_000); done.set() }
      _ = thread
    }
    return done.isSet ? [] : ["unfinished at scope exit"]
  },
  Scenario(name: "error-exit", modeledOn: "PThreadTests.deinitJoinsWhenAnErrorEndsTheScope") {
    let done = Flag()
    func startAndThrow() throws {
      let thread = OwnedThread { usleep(50_000); done.set() }
      _ = thread
      throw Stop()
    }
    var observed: [String] = []
    do { try startAndThrow() } catch { observed.append("threw Stop") }
    if !done.isSet { observed.append("unfinished at scope exit") }
    return observed
  },
  Scenario(name: "own-thread", modeledOn: "PThreadTests.deinitOnItsOwnThreadDetaches") {
    let slot = Slot()
    let ready = Latch()
    let destroyed = Latch()
    let thread = OwnedThread {
      guard ready.wait(), let owner = slot.take() else { return }
      _ = consume owner
      destroyed.open()
    }
    slot.put(thread)
    ready.open()
    return destroyed.wait() ? [] : ["owner not destroyed"]
  },
  Scenario(name: "waits-for-its-owner", modeledOn: "a worker told to stop after its owner's scope") {
    // The thread waits for a signal that its owner's scope sends only after
    // the owner is destroyed.
    let stop = Latch()
    do {
      let thread = OwnedThread { stop.waitWithoutTimeout() }
      _ = thread
    }
    stop.open()
    return []
  },
  Scenario(name: "class-field", modeledOn: "an event loop's thread in a class, released on the main thread") {
    final class EventLoop {
      var thread: OwnedThread?
      init(_ thread: consuming OwnedThread) { self.thread = consume thread }
    }
    var loop: EventLoop? = EventLoop(OwnedThread { usleep(50_000) })
    _ = loop
    let start = milliseconds()
    loop = nil
    let blocked = milliseconds() - start
    return blocked >= 40 ? ["releasing the class blocked \(blocked) ms"] : []
  },
  Scenario(name: "loop-forgotten", modeledOn: "a loop that starts a thread per item and drops it") {
    let finished = Counter()
    let start = milliseconds()
    for _ in 0..<100 {
      let thread = OwnedThread { usleep(2_000); finished.add() }
      _ = thread
    }
    let elapsed = milliseconds() - start
    var observed = ["loop took \(elapsed) ms"]
    let unfinished = 100 - finished.value
    if unfinished > 0 { observed.append("\(unfinished) of 100 unfinished after the loop") }
    return observed
  },
  Scenario(name: "async-scope-exit", modeledOn: "an owner destroyed in an async function") {
    let done = Latch()
    let blocked = Counter()
    Task.detached {
      let start = milliseconds()
      do {
        let thread = OwnedThread { usleep(50_000) }
        _ = thread
      }
      blocked.add(milliseconds() - start)
      done.open()
    }
    guard done.wait() else { return ["task never finished"] }
    return blocked.value >= 40
      ? ["blocked a cooperative thread \(blocked.value) ms"] : []
  },
  Scenario(name: "joined-through-hatch", modeledOn: "C code that joins the thread by its ID") {
    let thread = OwnedThread {}
    if pthread_join(thread.thread, nil) == 0 { Ledger.record { Ledger.joined += 1 } }
    // On Darwin, joining again reports ESRCH. On Linux, it's undefined
    // behavior: the pthread_t can already name a new thread.
    _ = consume thread
    return []
  },
  Scenario(name: "relinquish-and-take", modeledOn: "PThreadTests.manyThreads") {
    let finished = Counter()
    var ids: [pthread_t] = []
    for _ in 0..<16 {
      ids.append(OwnedThread { finished.add() }.relinquish())
    }
    for id in ids {
      OwnedThread(taking: id).join()
    }
    return finished.value == 16 ? [] : ["work unfinished"]
  },

  // The scope-exit, error-exit, and class-field scenarios, rewritten to
  // satisfy POLICY_TRAP.
  Scenario(name: "must-join: scope-exit", modeledOn: "scope-exit") {
    let done = Flag()
    do {
      let thread = OwnedThread { usleep(50_000); done.set() }
      thread.join()                                  // +1 line
    }
    return done.isSet ? [] : ["unfinished at scope exit"]
  },
  Scenario(name: "must-join: error-exit", modeledOn: "error-exit") {
    let done = Flag()
    func startAndThrow() throws {
      let thread = OwnedThread { usleep(50_000); done.set() }
      do {                                           // +5 lines; `defer` can't
        throw Stop()                                 // consume `thread` (V11a)
      } catch {
        thread.join()
        throw error
      }
    }
    var observed: [String] = []
    do { try startAndThrow() } catch { observed.append("threw Stop") }
    if !done.isSet { observed.append("unfinished at scope exit") }
    return observed
  },
  Scenario(name: "must-join: class-field", modeledOn: "class-field") {
    final class EventLoop {
      var thread: OwnedThread?
      init(_ thread: consuming OwnedThread) { self.thread = consume thread }
      deinit { thread.take()?.join() }             // +1 line, and it blocks too
    }
    var loop: EventLoop? = EventLoop(OwnedThread { usleep(50_000) })
    _ = loop
    let start = milliseconds()
    loop = nil
    let blocked = milliseconds() - start
    return blocked >= 40 ? ["releasing the class blocked \(blocked) ms"] : []
  },
] }

// MARK: - Support

final class Flag: @unchecked Sendable {
  private var mutex = pthread_mutex_t()
  private var value = false
  init() { pthread_mutex_init(&mutex, nil) }
  func set() { pthread_mutex_lock(&mutex); value = true; pthread_mutex_unlock(&mutex) }
  var isSet: Bool {
    pthread_mutex_lock(&mutex); defer { pthread_mutex_unlock(&mutex) }
    return value
  }
}

final class Counter: @unchecked Sendable {
  private var mutex = pthread_mutex_t()
  private var count = 0
  init() { pthread_mutex_init(&mutex, nil) }
  func add(_ n: Int = 1) { pthread_mutex_lock(&mutex); count += n; pthread_mutex_unlock(&mutex) }
  var value: Int {
    pthread_mutex_lock(&mutex); defer { pthread_mutex_unlock(&mutex) }
    return count
  }
}

// Opens once; waits give up after two seconds, so that main.swift's alarm,
// not these, decides what a hang is.
final class Latch: @unchecked Sendable {
  private var mutex = pthread_mutex_t()
  private var condition = pthread_cond_t()
  private var isOpen = false
  init() { pthread_mutex_init(&mutex, nil); pthread_cond_init(&condition, nil) }
  func open() {
    pthread_mutex_lock(&mutex); isOpen = true; pthread_mutex_unlock(&mutex)
    pthread_cond_broadcast(&condition)
  }
  func wait() -> Bool {
    var now = timespec()
    clock_gettime(CLOCK_REALTIME, &now)
    var deadline = timespec(tv_sec: now.tv_sec + 2, tv_nsec: now.tv_nsec)
    pthread_mutex_lock(&mutex)
    defer { pthread_mutex_unlock(&mutex) }
    while !isOpen {
      if pthread_cond_timedwait(&condition, &mutex, &deadline) == ETIMEDOUT { return isOpen }
    }
    return true
  }
  func waitWithoutTimeout() {
    pthread_mutex_lock(&mutex)
    while !isOpen { pthread_cond_wait(&condition, &mutex) }
    pthread_mutex_unlock(&mutex)
  }
}

// Hands an owner from one thread to another.
final class Slot: @unchecked Sendable {
  private var mutex = pthread_mutex_t()
  private var thread: OwnedThread?
  init() { pthread_mutex_init(&mutex, nil) }
  func put(_ thread: consuming OwnedThread) {
    pthread_mutex_lock(&mutex); self.thread = consume thread; pthread_mutex_unlock(&mutex)
  }
  func take() -> OwnedThread? {
    pthread_mutex_lock(&mutex); defer { pthread_mutex_unlock(&mutex) }
    return thread.take()
  }
}

func milliseconds() -> Int {
  var now = timespec()
  clock_gettime(CLOCK_MONOTONIC, &now)
  return now.tv_sec * 1000 + now.tv_nsec / 1_000_000
}
