// T2: @_rawLayout storage, as the standard library's Mutex uses, outside the standard library. Expected to fail without -enable-experimental-feature RawLayout ("the '@_rawLayout' attribute is experimental"). With it, it compiles in the release 6.2 compiler, and the address is stable across borrows, but the storage still moves: into the class field, and (at -Onone) before the deinit runs. Mutating through withUnsafePointer(to:) is also formally undefined; the standard library uses Builtin.addressOfRawLayout instead (T3).
// Run: swiftc -swift-version 6 -enable-experimental-feature RawLayout T2_rawlayout_withunsafepointer.swift -o /tmp/T2 && /tmp/T2
import Darwin

@_rawLayout(like: pthread_mutex_t)
struct RawMutex: ~Copyable {
  init() {
    let p = withUnsafePointer(to: self) {
      UnsafeMutablePointer(mutating: UnsafeRawPointer($0).assumingMemoryBound(to: pthread_mutex_t.self))
    }
    pthread_mutex_init(p, nil)
    print("initialized at", p)
  }
  borrowing func address() -> UnsafeMutablePointer<pthread_mutex_t> {
    withUnsafePointer(to: self) {
      UnsafeMutablePointer(mutating: UnsafeRawPointer($0).assumingMemoryBound(to: pthread_mutex_t.self))
    }
  }
  borrowing func lock() -> CInt { pthread_mutex_lock(address()) }
  borrowing func unlock() -> CInt { pthread_mutex_unlock(address()) }
  deinit {
    print("destroyed at  ", address())
    pthread_mutex_destroy(address())
  }
}

final class Holder: @unchecked Sendable {
  let m: RawMutex
  init(_ m: consuming RawMutex) { self.m = m }
}

@inline(never) func make() -> RawMutex { RawMutex() }

func main() {
  let local = make()
  print("local         ", local.address())
  print("local again   ", local.address())
  let holder = Holder(local)
  print("in class      ", holder.m.address())
  print("in class again", holder.m.address())
  print("lock", holder.m.lock(), "unlock", holder.m.unlock())
}
main()
