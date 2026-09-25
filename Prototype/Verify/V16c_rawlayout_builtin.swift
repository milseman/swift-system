// V16c: @_rawLayout with Builtin.addressOfRawLayout, as the standard library's _MutexHandle gets its address. Expected to compile only with -enable-experimental-feature RawLayout and -enable-experimental-feature BuiltinModule, which the release 6.2 compiler accepts. The value still moves when the class takes it, and at -Onone the deinit sees yet another address. Mutex tolerates moves because os_unfair_lock and a futex word are plain integers when unlocked; pthread_mutex_t isn't specified to be.
// Run: swiftc -swift-version 6 -enable-experimental-feature RawLayout -enable-experimental-feature BuiltinModule V16c_rawlayout_builtin.swift -o /tmp/V16c && /tmp/V16c
import Darwin
import Builtin

@_rawLayout(like: pthread_mutex_t)
struct RawMutex: ~Copyable {
  var address: UnsafeMutablePointer<pthread_mutex_t> {
    UnsafeMutablePointer(Builtin.addressOfRawLayout(self))
  }
  init() {
    pthread_mutex_init(address, nil)
    print("initialized at", address)
  }
  deinit {
    print("destroyed at  ", address)
    pthread_mutex_destroy(address)
  }
}

final class Holder: @unchecked Sendable {
  let m: RawMutex
  init(_ m: consuming RawMutex) { self.m = m }
}

@inline(never) func make() -> RawMutex { RawMutex() }

func main() {
  do {
    let local = make()
    print("local         ", local.address)
  }
  let local = make()
  print("local         ", local.address)
  let holder = Holder(local)
  print("in class      ", holder.m.address)
}
main()
