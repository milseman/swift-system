// Uses of an owned child, each modeled on a test, a sample, or a pattern
// from an adopter. Each scenario runs in its own process (see run.sh), so a
// trap or a hang ends only that one. A scenario returns what it observed,
// and main.swift adds what happened to the children the owners started.

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

/// A descriptor that's closed at the end of its owner's lifetime,
/// as OwnedFD's is.
struct OwnedDescriptor: ~Copyable {
  let fd: CInt
  deinit { close(fd) }
}

/// The two ends of a pipe, as OwnedFD.Pipe holds them.
func pipeEnds() -> (read: CInt, write: CInt) {
  var fds: [CInt] = [0, 0]
  precondition(pipe(&fds) == 0)
  return (fds[0], fds[1])
}

/// What a scope's end left: how long it blocked, and the child's state.
func afterScope(_ pid: pid_t, blocked: Int) -> [String] {
  var observed: [String] = []
  if blocked >= 40 { observed.append("scope exit blocked \(blocked) ms") }
  switch peek(pid) {
  case .running: observed.append("running after scope exit")
  case .zombie: observed.append("zombie after scope exit")
  case .reaped: break
  }
  return observed
}

func allScenarios() -> [Scenario] { [
  Scenario(name: "explicit-wait", modeledOn: "ChildProcessTests.testSpawnAndWait") {
    let child = OwnedChild(["sh", "-c", "exit 4"])
    let status = child.wait()
    return (status >> 8) & 0xff == 4 ? [] : ["status \(status)"]
  },
  Scenario(name: "scope-exit", modeledOn: "ChildProcessTests.testDestroyingARunningChild...") {
    var pid: pid_t = 0
    let start = milliseconds()
    do {
      let child = OwnedChild(["sleep", "30"])
      pid = child.pid
    }
    return afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "ended-then-dropped", modeledOn: "ChildProcessTests.testDestroyingAnEndedChild...") {
    var pid: pid_t = 0
    do {
      let child = OwnedChild(["sh", "-c", "exit 0"])
      pid = child.pid
      while peek(pid) == .running { usleep(1_000) }
    }
    return afterScope(pid, blocked: 0)
  },
  Scenario(name: "error-exit", modeledOn: "ChildProcessTests.testDestroyingAChild...WhenAnErrorEnds...") {
    var pid: pid_t = 0
    let start = milliseconds()
    func startAndThrow() throws {
      let child = OwnedChild(["sleep", "30"])
      pid = child.pid
      throw Stop()
    }
    var observed: [String] = []
    do { try startAndThrow() } catch { observed.append("threw Stop") }
    return observed + afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "stdin-from-owner", modeledOn: "process-run's pipes: cat reads a pipe the parent owns") {
    // The pipe's write end is declared first, so it's destroyed after the
    // child: cat sees the end of its input only when it's closed.
    var pid: pid_t = 0
    let start = milliseconds()
    do {
      let (readEnd, writeEnd) = pipeEnds()
      let input = OwnedDescriptor(fd: writeEnd)
      let child = OwnedChild(["cat"], input: readEnd)
      close(readEnd)
      pid = child.pid
      _ = input
    }
    return afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "work-in-progress", modeledOn: "a child that finishes its work after its owner's scope") {
    let path = "/tmp/child-deinit-\(getpid())"
    unlink(path)
    defer { unlink(path) }
    do {
      let child = OwnedChild(["sh", "-c", "sleep 0.1; echo done > \(path)"])
      _ = child
    }
    usleep(400_000)
    return access(path, F_OK) == 0 ? [] : ["work unfinished"]
  },
  Scenario(name: "ignores-SIGTERM", modeledOn: "a child that traps SIGTERM, which teardown must escalate") {
    var pid: pid_t = 0
    let start = milliseconds()
    do {
      let child = OwnedChild(["sh", "-c", "trap '' TERM; sleep 30"])
      pid = child.pid
      usleep(100_000)
    }
    return afterScope(pid, blocked: milliseconds() - start - 100)
  },
  Scenario(name: "loop-forgotten", modeledOn: "a loop that starts a child per item and drops it") {
    let start = milliseconds()
    var pids: [pid_t] = []
    for _ in 0..<20 {
      let child = OwnedChild(["sh", "-c", "sleep 0.05"])
      pids.append(child.pid)
    }
    let elapsed = milliseconds() - start
    usleep(300_000)
    let zombies = pids.filter { peek($0) == .zombie }.count
    var observed = ["loop took \(elapsed) ms"]
    if zombies > 0 { observed.append("\(zombies) of 20 zombies after the loop") }
    return observed
  },
  Scenario(name: "class-field", modeledOn: "a process manager's child in a class, released") {
    final class Manager {
      var child: OwnedChild?
      init(_ child: consuming OwnedChild) { self.child = consume child }
    }
    var manager: Manager? = Manager(OwnedChild(["sleep", "0.3"]))
    let pid = manager?.child?.pid ?? 0
    let start = milliseconds()
    manager = nil
    return afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "async-scope-exit", modeledOn: "an owner destroyed in an async function") {
    let done = Latch()
    let blocked = Box()
    Task.detached {
      let start = milliseconds()
      do {
        let child = OwnedChild(["sleep", "0.3"])
        blocked.pid = child.pid
      }
      blocked.value = milliseconds() - start
      done.open()
    }
    guard done.wait() else { return ["task never finished"] }
    var observed = afterScope(blocked.pid, blocked: 0)
    if blocked.value >= 40 {
      observed.insert("blocked a cooperative thread \(blocked.value) ms", at: 0)
    }
    return observed
  },
  Scenario(name: "reaped-through-hatch", modeledOn: "a SIGCHLD handler that reaps any child") {
    let child = OwnedChild(["sh", "-c", "exit 0"])
    // waitpid(-1) reaps every child, including one an owner holds, and its
    // ID can then name another process.
    var status: CInt = 0
    while waitpid(-1, &status, 0) != child.pid {}
    _ = consume child
    return []
  },
  Scenario(name: "SIGCHLD-ignored", modeledOn: "a process that ignores SIGCHLD, so children never become zombies") {
    signal(SIGCHLD, SIG_IGN)
    defer { signal(SIGCHLD, SIG_DFL) }
    var pid: pid_t = 0
    let start = milliseconds()
    do {
      let child = OwnedChild(["sleep", "0.3"])
      pid = child.pid
    }
    return afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "relinquish-and-reap", modeledOn: "process-pipeline, which keeps IDs") {
    var pids: [pid_t] = []
    for status in 0..<4 {
      pids.append(OwnedChild(["sh", "-c", "exit \(status)"]).relinquish())
    }
    let statuses = pids.map { OwnedChild(taking: $0).wait() >> 8 }
    return statuses == [0, 1, 2, 3] ? [] : ["statuses \(statuses)"]
  },

  // The scope-exit, error-exit, and class-field scenarios, rewritten to
  // satisfy POLICY_TRAP: every owner is waited for explicitly.
  Scenario(name: "must-wait: scope-exit", modeledOn: "scope-exit") {
    var pid: pid_t = 0
    let start = milliseconds()
    do {
      let child = OwnedChild(["sleep", "30"])
      pid = child.pid
      kill(pid, SIGKILL)                             // +2 lines, to end the
      _ = child.wait()                               // child and reap it
    }
    return afterScope(pid, blocked: milliseconds() - start)
  },
  Scenario(name: "must-wait: error-exit", modeledOn: "error-exit") {
    var pid: pid_t = 0
    func startAndThrow() throws {
      let child = OwnedChild(["sleep", "30"])
      pid = child.pid
      do {                                           // +6 lines; `defer` can't
        throw Stop()                                 // consume `child` (V11a)
      } catch {
        kill(child.pid, SIGKILL)
        _ = child.wait()
        throw error
      }
    }
    var observed: [String] = []
    do { try startAndThrow() } catch { observed.append("threw Stop") }
    return observed + afterScope(pid, blocked: 0)
  },
  Scenario(name: "must-wait: class-field", modeledOn: "class-field") {
    final class Manager {
      var child: OwnedChild?
      init(_ child: consuming OwnedChild) { self.child = consume child }
      deinit { _ = child.take()?.wait() }           // +1 line, and it blocks
    }
    var manager: Manager? = Manager(OwnedChild(["sleep", "0.3"]))
    let pid = manager?.child?.pid ?? 0
    let start = milliseconds()
    manager = nil
    return afterScope(pid, blocked: milliseconds() - start)
  },
] }

// MARK: - Support

final class Box: @unchecked Sendable {
  var value = 0
  var pid: pid_t = 0
}

final class Latch: @unchecked Sendable {
  private var mutex = pthread_mutex_t()
  private var condition = pthread_cond_t()
  private var isOpen = false
  init() {
    pthread_mutex_init(&mutex, nil)
    pthread_cond_init(&condition, nil)
  }
  func open() {
    pthread_mutex_lock(&mutex)
    isOpen = true
    pthread_cond_broadcast(&condition)
    pthread_mutex_unlock(&mutex)
  }
  // Returns whether it opened within four seconds.
  func wait() -> Bool {
    pthread_mutex_lock(&mutex)
    defer { pthread_mutex_unlock(&mutex) }
    let deadline = milliseconds() + 4_000
    while !isOpen && milliseconds() < deadline {
      pthread_mutex_unlock(&mutex)
      usleep(1_000)
      pthread_mutex_lock(&mutex)
    }
    return isOpen
  }
}
