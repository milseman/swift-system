// V6h: function returning a nonescapable value with no @_lifetime; is the dependence inferred and enforced?
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

func view(_ o: borrowing Owned) -> Borrowed { o.borrowed }   // no annotation


func caller(_ o: consuming Owned) -> Int32 {
  let b = view(o)
  o.close()
  return b.raw
}
