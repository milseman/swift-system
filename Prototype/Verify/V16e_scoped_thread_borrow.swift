// V16e: a scoped thread, one that the scope joins before returning, can borrow a closure-scoped mutex, because its body doesn't escape. Expected to compile and print 100000. This is the only way V16d's scoped mutex reaches another thread, so a scoped-mutex design would also need a scoped-thread API. Note that nothing here checks Sendable: withoutActuallyEscaping hands pthread_create a closure that isn't @Sendable.
// Run: swiftc -swift-version 6 V16e_scoped_thread_borrow.swift -o /tmp/V16e && /tmp/V16e
import Darwin

struct ScopedMutex: ~Copyable, @unchecked Sendable {
  let address: UnsafeMutablePointer<pthread_mutex_t>
  borrowing func lock() { pthread_mutex_lock(address) }
  borrowing func unlock() { pthread_mutex_unlock(address) }
}

func withMutex<R>(_ body: (borrowing ScopedMutex) throws -> R) rethrows -> R {
  var raw = pthread_mutex_t()
  return try withUnsafeMutablePointer(to: &raw) { p in
    pthread_mutex_init(p, nil)
    defer { pthread_mutex_destroy(p) }
    return try body(ScopedMutex(address: p))
  }
}

final class Box: @unchecked Sendable { var value = 0 }
final class Start { let body: () -> Void; init(_ b: @escaping () -> Void) { body = b } }

// Runs `body` on a new thread and joins it before returning.
func onThreadAndJoin(_ body: () -> Void) {
  withoutActuallyEscaping(body) { escapable in
    let start = Unmanaged.passRetained(Start(escapable)).toOpaque()
    var t: pthread_t? = nil
    pthread_create(&t, nil, { raw in
      Unmanaged<Start>.fromOpaque(raw).takeRetainedValue().body()
      return nil
    }, start)
    pthread_join(t!, nil)
  }
}

func increment(_ m: borrowing ScopedMutex, _ box: Box) {
  onThreadAndJoin {
    for _ in 0..<100_000 { m.lock(); box.value += 1; m.unlock() }
  }
}

let box = Box()
withMutex { m in
  increment(m, box)
}
print(box.value)
