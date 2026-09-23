// V6i: a function with two borrowing noncopyable parameters returning a nonescapable value, no annotation.
struct Owned: ~Copyable {
  var raw: Int32
  deinit {}
}
struct Borrowed: ~Escapable {
  let raw: Int32
  @_lifetime(borrow owner)
  init(_ owner: borrowing Owned) { self.raw = owner.raw }
}
func twoCandidates(_ o: borrowing Owned, _ p: borrowing Owned) -> Borrowed { Borrowed(o) }
