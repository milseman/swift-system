// V6c: misuse of a nonescapable value that depends on a noncopyable owner.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
  consuming func close() { discard self }
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

func useAfterClose(_ o: consuming Owned) -> Int32 {
  let b = o.borrowed
  o.close()          // owner consumed while `b` is still used below
  return b.raw
}

func escapeByReturn(_ o: borrowing Owned) -> Borrowed {
  return o.borrowed  // no @_lifetime on the function
}

func escapeLocalOwner() -> Int32 {
  let b: Borrowed
  do {
    let o = Owned(raw: 1)
    b = o.borrowed
  }                  // owner destroyed at end of scope
  return b.raw
}
