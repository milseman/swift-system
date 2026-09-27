// Claim: Swift concurrency's threads block SIGTERM, so a child that
// posix_spawn starts from async code with the C defaults inherits a mask
// that blocks it, and SIGTERM doesn't end the child. From the main thread,
// it does. That's why SpawnAttributes() empties the child's signal mask.
//
// Checked with Swift 6.2 on macOS 26.3:
//     main thread (async main): thread blocks SIGTERM: false; child killed by 15
//     Task.detached: thread blocks SIGTERM: true; child exited 0
//     task group child: thread blocks SIGTERM: true; child exited 0
//
// swiftc -swift-version 6 -parse-as-library \
//   Prototype/Processes/Verify/P1_concurrency_threads_block_signals.swift -o /tmp/p1 && /tmp/p1

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

func spawnSelfTerminating(_ label: String) {
  var mask = sigset_t()
  pthread_sigmask(SIG_BLOCK, nil, &mask)
  let blocked = sigismember(&mask, SIGTERM) == 1
  var pid: pid_t = 0
  let strings: [String] = ["sh", "-c", "kill -TERM $$; exit 0"]
  let argv: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) } + [nil]
  defer { argv.forEach { free($0) } }
  // The C defaults: the child inherits this thread's mask.
  posix_spawn(&pid, "/bin/sh", nil, nil, argv, nil)
  var status: CInt = 0
  waitpid(pid, &status, 0)
  let outcome = status & 0x7f == 0 ? "exited \(status >> 8)" : "killed by \(status & 0x7f)"
  print("\(label): thread blocks SIGTERM: \(blocked); child \(outcome)")
}

@main struct Main {
  static func main() async {
    spawnSelfTerminating("main thread (async main)")
    await Task.detached { spawnSelfTerminating("Task.detached") }.value
    await withTaskGroup(of: Void.self) { group in
      group.addTask { spawnSelfTerminating("task group child") }
    }
  }
}
