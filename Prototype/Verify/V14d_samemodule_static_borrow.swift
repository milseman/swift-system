// V14d: the control for V14c: borrowing a view of a static `let` in the same module. Expected to compile with -parse-as-library -enable-experimental-feature Lifetimes.
struct Owned: ~Copyable, Sendable {
  let raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
  var borrowed: Borrowed {
    @_lifetime(borrow self)
    borrowing get { Borrowed(self) }
  }
  static let standardInput = Owned(raw: 0)
}
struct Borrowed: ~Escapable {
  let raw: Int32
  @_lifetime(borrow owner)
  init(_ owner: borrowing Owned) { raw = owner.raw }
  func read() -> Int32 { raw }
}
func use(_ b: Borrowed) -> Int32 { b.read() }

func temporary() -> Int32 { Owned.standardInput.borrowed.read() }
func argument() -> Int32 { use(Owned.standardInput.borrowed) }
func local() -> Int32 { let b = Owned.standardInput.borrowed; return b.read() }
