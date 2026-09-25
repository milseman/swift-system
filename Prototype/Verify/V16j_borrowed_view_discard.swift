// V16j: a scoped API can lend a non-owning noncopyable view of memory that other code owns, and end the view with `discard self` on both the normal and the throwing path, so its deinit never runs. Expected to compile and print "42" and "caught E()", with no "deinit" line: a non-throwing body needs no `try`, the result can be noncopyable, and `rethrows` allows the catch-and-rethrow. With -D ESCAPE, the body can't keep the view ("implicit conversion to 'Owner?' is consuming"). PThread.Mutex.withUnsafeMutex(at:_:) and its Condition and ReadWriteLock counterparts use this for C-owned objects.
// Run: swiftc -swift-version 6 V16j_borrowed_view_discard.swift -o /tmp/V16j && /tmp/V16j
struct Owner: ~Copyable {
  let address: UnsafeMutableRawPointer
  let owns: Bool
  init(_borrowing address: UnsafeMutableRawPointer) { self.address = address; owns = false }
  consuming func _forget() { discard self }
  deinit { print("deinit, owns:", owns) }
  borrowing func peek() -> Int { address.load(as: Int.self) }

  static func withBorrowed<R: ~Copyable>(
    at address: UnsafeMutableRawPointer,
    _ body: (borrowing Owner) throws -> R
  ) rethrows -> R {
    let owner = Owner(_borrowing: address)
    do {
      let result = try body(owner)
      owner._forget()
      return result
    } catch {
      owner._forget()
      throw error
    }
  }
}

struct E: Error {}
let p = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
p.storeBytes(of: 42, as: Int.self)
print(Owner.withBorrowed(at: p) { $0.peek() })
do { try Owner.withBorrowed(at: p) { _ in throw E() } } catch { print("caught", error) }

#if ESCAPE
var stash: Owner? = nil
Owner.withBorrowed(at: p) { stash = $0 }
#endif
