// The owner under test: a model of PThread, with real threads. Its deinit
// policy is chosen at compile time:
//
//   -D POLICY_JOIN    join, or detach when destroyed on its own thread, which
//                     can't wait for itself (PThread's deinit in the package;
//                     C++20's std::jthread, without its stop request)
//   -D POLICY_DETACH  detach (Rust's std::thread::JoinHandle)
//   -D POLICY_TRAP    trap whenever deinit runs: the owner must be consumed
//                     by join() or detach() (C++'s std::thread, which calls
//                     std::terminate; NIOThread's deinit asserts this in
//                     debug builds)
//   -D POLICY_LEAK    neither: the thread is never joined, and its resources
//                     stay allocated until the process exits (a forgotten
//                     pthread_t in C; NIOThread in release builds)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// What happened to the threads that owners started.
enum Ledger {
  nonisolated(unsafe) static var mutex: pthread_mutex_t = {
    var mutex = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
  }()
  nonisolated(unsafe) static var started = 0
  nonisolated(unsafe) static var joined = 0
  nonisolated(unsafe) static var detached = 0
  // Error numbers from joins and detaches in a deinit, which can't throw.
  nonisolated(unsafe) static var droppedErrors: [CInt] = []

  static func record(_ body: () -> Void) {
    pthread_mutex_lock(&mutex)
    body()
    pthread_mutex_unlock(&mutex)
  }

  static var unreleased: Int {
    var count = 0
    record { count = started - joined - detached }
    return count
  }
}

final class Start {
  let body: () -> Void
  init(_ body: @escaping () -> Void) { self.body = body }
}

struct OwnedThread: ~Copyable {
  let thread: pthread_t

  init(_ body: @escaping () -> Void) {
    let context = Unmanaged.passRetained(Start(body)).toOpaque()
    #if canImport(Darwin)
    var thread: pthread_t? = nil
    #else
    var thread = pthread_t()
    #endif
    let result = pthread_create(&thread, nil, { context in
      Unmanaged<Start>.fromOpaque((context as UnsafeMutableRawPointer?)!)
        .takeRetainedValue().body()
      return nil
    }, context)
    precondition(result == 0, "pthread_create failed: \(result)")
    #if canImport(Darwin)
    self.thread = thread!
    #else
    self.thread = thread
    #endif
    Ledger.record { Ledger.started += 1 }
  }

  init(taking thread: pthread_t) { self.thread = thread }

  consuming func join() {
    let thread = self.thread
    discard self
    let result = pthread_join(thread, nil)
    precondition(result == 0, "pthread_join failed: \(result)")
    Ledger.record { Ledger.joined += 1 }
  }

  consuming func detach() {
    let thread = self.thread
    discard self
    let result = pthread_detach(thread)
    precondition(result == 0, "pthread_detach failed: \(result)")
    Ledger.record { Ledger.detached += 1 }
  }

  consuming func relinquish() -> pthread_t {
    let thread = self.thread
    discard self
    return thread
  }

  deinit {
    #if POLICY_JOIN
    if pthread_equal(thread, pthread_self()) != 0 {
      let result = pthread_detach(thread)
      Ledger.record { if result == 0 { Ledger.detached += 1 } else { Ledger.droppedErrors.append(result) } }
    } else {
      let result = pthread_join(thread, nil)
      Ledger.record { if result == 0 { Ledger.joined += 1 } else { Ledger.droppedErrors.append(result) } }
    }
    #elseif POLICY_DETACH
    let result = pthread_detach(thread)
    Ledger.record { if result == 0 { Ledger.detached += 1 } else { Ledger.droppedErrors.append(result) } }
    #elseif POLICY_TRAP
    fatalError("OwnedThread destroyed without join() or detach()")
    #elseif POLICY_LEAK
    #else
    #error("Choose a policy with -D POLICY_JOIN, POLICY_DETACH, POLICY_TRAP, or POLICY_LEAK")
    #endif
  }
}
