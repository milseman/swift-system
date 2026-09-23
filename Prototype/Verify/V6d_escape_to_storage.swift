// V6d: storing a nonescapable value in a global, a class property, or an escaping closure.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  var borrowed: Borrowed {
    @_lifetime(borrow self)
    borrowing get { Borrowed(self) }
  }
}
struct Borrowed: ~Escapable {
  let raw: Int32
  @_lifetime(borrow owner)
  init(_ owner: borrowing Owned) { self.raw = owner.raw }
}

nonisolated(unsafe) var globalBorrowed: Borrowed? = nil

final class Keeper {
  var kept: Borrowed? = nil
}

func escapeClosure(_ o: borrowing Owned) -> () -> Int32 {
  let b = o.borrowed
  return { b.raw }
}
