// V6e: consume the owner after the dependent value's last use (variants).
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
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
func read(_ b: Borrowed) -> Int32 { b.raw }

// A: dependent value bound to a local `let`, last used before close.
func variantA(_ o: consuming Owned) -> Int32 {
  let b = o.borrowed
  let r = read(b)
  o.close()
  return r
}

// B: dependent value used only as a temporary.
func variantB(_ o: consuming Owned) -> Int32 {
  let r = read(o.borrowed)
  o.close()
  return r
}

// C: dependent value confined to an inner `do` scope.
func variantC(_ o: consuming Owned) -> Int32 {
  var r: Int32 = 0
  do {
    let b = o.borrowed
    r = read(b)
  }
  o.close()
  return r
}

// D: local `let` owner rather than a consuming parameter.
func variantD() -> Int32 {
  let o = Owned(raw: 1)
  let r = read(o.borrowed)
  o.close()
  return r
}
