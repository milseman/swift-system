// V16d: a closure-scoped mutex lives on the stack of withMutex, so its address is stable, but it can't leave the closure. Expected to compile and run as written. With -D ESCAPE, a thread body (an escaping closure) can't capture it: Swift 6.2 crashes in the move checker ("Assertion failed: (srcAddr->getType() == destAddr->getType())", MoveOnlyChecker) instead of printing the diagnostic, and a named function's borrowing parameter gets "'m' cannot be captured by an escaping closure since it is a borrowed parameter" (-D ESCAPE_PARAM). With -D STORE, it can't be stored ("implicit conversion to 'ScopedMutex?' is consuming").
// Check: swiftc -emit-sil -o /dev/null -swift-version 6 [-D ESCAPE | -D ESCAPE_PARAM | -D STORE] V16d_scoped_mutex.swift
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

func spawn(_ body: @escaping @Sendable () -> Void) { body() }  // stands in for pthread_create

func scoped() {
  withMutex { m in
    m.lock(); m.unlock()
    print(m.address)
  }
}

#if ESCAPE
func escapes() {
  withMutex { m in
    spawn { m.lock(); m.unlock() }
  }
}
#endif

#if ESCAPE_PARAM
func escapesParameter(_ m: borrowing ScopedMutex) {
  spawn { m.lock(); m.unlock() }
}
#endif

#if STORE
final class Holder { var m: ScopedMutex? = nil }
func stores(_ holder: Holder) {
  withMutex { m in
    holder.m = m
  }
}
#endif

scoped()
