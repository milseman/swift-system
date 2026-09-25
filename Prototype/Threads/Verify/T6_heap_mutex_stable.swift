// T6: a noncopyable owner of heap storage keeps the pthread_mutex_t at one address through every move: from the init, into a local, into a class field, and into the deinit. Two threads lock it through a shared class. Expected to compile and print one address five times and "count 200000", at -Onone and -O. This is the design PThread.Mutex, Condition, and ReadWriteLock use.
// Run: swiftc -swift-version 6 T6_heap_mutex_stable.swift -o /tmp/T6 && /tmp/T6
import Darwin

struct HeapMutex: ~Copyable, @unchecked Sendable {
  let address: UnsafeMutablePointer<pthread_mutex_t>
  init() {
    address = .allocate(capacity: 1)
    pthread_mutex_init(address, nil)
    print("initialized at", address)
  }
  borrowing func lock() -> CInt { pthread_mutex_lock(address) }
  borrowing func unlock() -> CInt { pthread_mutex_unlock(address) }
  deinit {
    print("destroyed at  ", address)
    pthread_mutex_destroy(address)
    address.deallocate()
  }
}

final class Holder: Sendable {
  let m: HeapMutex
  init(_ m: consuming HeapMutex) { self.m = m }
}

final class Counter: @unchecked Sendable { var n = 0 }
final class Context { let holder: Holder; let counter: Counter; init(_ h: Holder, _ c: Counter) { holder = h; counter = c } }

@inline(never) func make() -> HeapMutex { HeapMutex() }

func main() {
  let local = make()
  print("local         ", local.address)
  let holder = Holder(local)
  print("in class      ", holder.m.address)
  let counter = Counter()
  let threads = (0..<2).map { _ in
    var t: pthread_t? = nil
    let context = Unmanaged.passRetained(Context(holder, counter)).toOpaque()
    pthread_create(&t, nil, { raw in
      let c = Unmanaged<Context>.fromOpaque(raw).takeRetainedValue()
      for _ in 0..<100_000 { _ = c.holder.m.lock(); c.counter.n += 1; _ = c.holder.m.unlock() }
      return nil
    }, context)
    return t!
  }
  for t in threads { pthread_join(t, nil) }
  print("count", counter.n)
}
main()
