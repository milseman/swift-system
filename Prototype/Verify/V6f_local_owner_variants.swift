// V6f: local owner variants: `var` owner, and `let` owner with the dependent value in an inner scope.
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

// E: local `var` owner, temporary dependent value.
func variantE() -> Int32 {
  var o = Owned(raw: 1)
  o.raw += 0
  let r = read(o.borrowed)
  o.close()
  return r
}

// F: local `let` owner, dependent value in an inner scope.
func variantF() -> Int32 {
  let o = Owned(raw: 1)
  var r: Int32 = 0
  do { r = read(o.borrowed) }
  o.close()
  return r
}

// G: local `let` owner, borrowed through a `borrowing` helper instead of a nonescapable value.
func helper(_ o: borrowing Owned) -> Int32 { o.raw }
func variantG() -> Int32 {
  let o = Owned(raw: 1)
  let r = helper(o)
  o.close()
  return r
}
