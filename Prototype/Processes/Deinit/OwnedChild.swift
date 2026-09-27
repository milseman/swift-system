// The owner under test: a model of ChildProcess, with real children, spawned
// with posix_spawn. Its deinit policy is chosen at compile time:
//
//   -D POLICY_KILL       kill the child with SIGKILL if it's still running,
//                        then reap it; skip a child that something else
//                        reaped (ChildProcess's deinit in the package; the
//                        structured choice, like a task group that cancels
//                        and awaits its children when its scope ends)
//   -D POLICY_WAIT       wait for the child to end, and reap it (PThread's
//                        join-on-deinit, for processes)
//   -D POLICY_TERMINATE  SIGTERM, a grace period of one second, then SIGKILL,
//                        then reap (swift-subprocess's default teardown;
//                        SwiftPM's Cancellator sends SIGINT, then SIGKILL)
//   -D POLICY_REAP       reap the child only if it has already ended, with
//                        WNOHANG, and otherwise leave it running, to become a
//                        zombie when it ends
//   -D POLICY_LEAK       nothing: the child runs on, and stays a zombie once
//                        it ends, until the process exits (Rust's
//                        std::process::Child; a forgotten pid_t in C)
//   -D POLICY_TRAP       trap whenever the deinit runs: the owner must be
//                        consumed by wait() or relinquish()

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// What happened to the children that owners started.
enum Ledger {
  nonisolated(unsafe) static var children: [pid_t] = []
  // Error numbers from waits and kills in a deinit, which can't throw.
  nonisolated(unsafe) static var droppedErrors: [CInt] = []
  nonisolated(unsafe) static var mutex: pthread_mutex_t = {
    var mutex = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
  }()

  static func record(_ body: () -> Void) {
    pthread_mutex_lock(&mutex)
    body()
    pthread_mutex_unlock(&mutex)
  }
}

struct OwnedChild: ~Copyable {
  let pid: pid_t

  /// Spawns `arguments`, with standard input from `input` if it's given.
  ///
  /// The child's other standard descriptors are /dev/null: a child that
  /// outlives its scenario would otherwise hold run.sh's pipe open, and the
  /// shell would wait for it.
  init(_ arguments: [String], input: CInt? = nil) {
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    if let input {
      posix_spawn_file_actions_adddup2(&actions, input, 0)
      posix_spawn_file_actions_addclose(&actions, input)
    } else {
      posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    }
    posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
    // As SpawnAttributes() does: nothing blocked, and every signal's default
    // action. A child otherwise inherits the spawning thread's mask, and
    // Swift concurrency's threads block SIGTERM (Verify/P1).
    var attributes: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    var none = sigset_t(), all = sigset_t()
    sigemptyset(&none)
    sigfillset(&all)
    posix_spawnattr_setsigmask(&attributes, &none)
    posix_spawnattr_setsigdefault(&attributes, &all)
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
    let argv = arguments.map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }
    var pid: pid_t = 0
    let result = posix_spawnp(&pid, argv[0], &actions, &attributes, argv, environ)
    precondition(result == 0, "posix_spawnp failed: \(result)")
    self.pid = pid
    Ledger.record { Ledger.children.append(pid) }
  }

  init(taking pid: pid_t) { self.pid = pid }

  consuming func wait() -> CInt {
    let pid = self.pid
    discard self
    return reap(pid) ?? -1
  }

  consuming func relinquish() -> pid_t {
    let pid = self.pid
    discard self
    return pid
  }

  deinit {
    #if POLICY_KILL
    // Check, without reaping, that the child is still ours.
    switch peek(pid) {
    case .reaped: Ledger.record { Ledger.droppedErrors.append(ECHILD) }
    case .running:
      kill(pid, SIGKILL)
      if reap(pid) == nil { Ledger.record { Ledger.droppedErrors.append(errno) } }
    case .zombie:
      if reap(pid) == nil { Ledger.record { Ledger.droppedErrors.append(errno) } }
    }
    #elseif POLICY_WAIT
    if reap(pid) == nil { Ledger.record { Ledger.droppedErrors.append(errno) } }
    #elseif POLICY_TERMINATE
    if case .running = peek(pid) {
      kill(pid, SIGTERM)
      let start = milliseconds()
      while case .running = peek(pid), milliseconds() - start < 1_000 { usleep(5_000) }
      if case .running = peek(pid) { kill(pid, SIGKILL) }
    }
    if reap(pid) == nil { Ledger.record { Ledger.droppedErrors.append(errno) } }
    #elseif POLICY_REAP
    var status: CInt = 0
    if waitpid(pid, &status, WNOHANG) == -1 {
      Ledger.record { Ledger.droppedErrors.append(errno) }
    }
    #elseif POLICY_LEAK
    _ = pid
    #elseif POLICY_TRAP
    fatalError("OwnedChild destroyed without wait() or relinquish()")
    #else
    #error("Choose a policy with -D POLICY_...")
    #endif
  }
}

enum ChildState: Equatable { case running, zombie, reaped }

/// Whether a child is running, a zombie, or reaped (or not a child).
func peek(_ pid: pid_t) -> ChildState {
  var info = siginfo_t()
  guard waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT) == 0 else {
    return .reaped
  }
  return childPID(info) == 0 ? .running : .zombie
}

/// Waits for and reaps a child, returning its wait status, or nil.
func reap(_ pid: pid_t) -> CInt? {
  var status: CInt = 0
  while waitpid(pid, &status, 0) == -1 {
    guard errno == EINTR else { return nil }
  }
  return status
}

func childPID(_ info: siginfo_t) -> pid_t {
  #if canImport(Darwin)
  return info.si_pid
  #else
  return info._sifields._sigchld.si_pid
  #endif
}

func milliseconds() -> Int {
  var now = timespec()
  clock_gettime(CLOCK_MONOTONIC, &now)
  return Int(now.tv_sec) * 1_000 + Int(now.tv_nsec) / 1_000_000
}
