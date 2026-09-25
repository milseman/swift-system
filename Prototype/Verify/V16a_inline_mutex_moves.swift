// V16a: a pthread_mutex_t stored inline in a noncopyable struct doesn't stay at one address. Expected to compile and to print several addresses: where the init initialized it, where the local holds it, the temporary a borrowing method sees, the class field it moves into, and the copy the deinit destroys (a deinit's self is immutable, so it can't pass &raw). POSIX makes using a moved or copied mutex undefined behavior.
// Run: swiftc -swift-version 6 -Onone V16a_inline_mutex_moves.swift -o /tmp/V16a && /tmp/V16a (also -O)
import Darwin

struct InlineMutex: ~Copyable {
  var raw = pthread_mutex_t()
  init() {
    pthread_mutex_init(&raw, nil)
    withUnsafeMutablePointer(to: &raw) { print("initialized at", $0) }
  }
  mutating func lockedAddress() -> UnsafeMutablePointer<pthread_mutex_t> {
    withUnsafeMutablePointer(to: &raw) { $0 }
  }
  borrowing func borrowedAddress() -> UnsafePointer<pthread_mutex_t> {
    withUnsafePointer(to: raw) { $0 }
  }
  deinit {
    // self is immutable here, so this destroys a copy.
    var copy = raw
    withUnsafeMutablePointer(to: &copy) { print("destroyed at  ", $0) }
    pthread_mutex_destroy(&copy)
  }
}

final class Holder {
  var m: InlineMutex
  init(_ m: consuming InlineMutex) { self.m = m }
}

@inline(never) func make() -> InlineMutex { InlineMutex() }

func main() {
  var local = make()
  print("local         ", local.lockedAddress())
  print("borrowed      ", local.borrowedAddress())
  print("borrowed      ", local.borrowedAddress())
  let holder = Holder(local)
  print("in class      ", holder.m.lockedAddress())
}
main()
