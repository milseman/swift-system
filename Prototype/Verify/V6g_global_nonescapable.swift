// V6g: a global of nonescapable type, alone.
struct Borrowed: ~Escapable {
  let raw: Int32
  @_lifetime(immortal)
  init(raw: Int32) { self.raw = raw }
}
nonisolated(unsafe) var globalBorrowed: Borrowed? = nil

struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  var borrowed: Borrowed {
    @_lifetime(borrow self)
    borrowing get { Borrowed(raw: raw) }
  }
}
func stash(_ o: borrowing Owned) { globalBorrowed = o.borrowed }
