// V6b: a nonescapable value that depends on a borrow of a noncopyable owner. Valid uses only.
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit \(raw)") }
  consuming func close() { let r = raw; discard self; print("close \(r)") }
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

enum AnyBorrowed: ~Escapable {
  case fd(Borrowed)
}

func read(_ b: Borrowed) -> Int32 { b.raw }

@main struct Main {
  static func main() {
    let o = Owned(raw: 4)
    let b = o.borrowed
    print("read", read(b))
    let e = AnyBorrowed.fd(o.borrowed)
    switch e { case .fd(let x): print("enum", x.raw) }
    o.close()
    print("end of main")
  }
}
