// V11c: the workaround for V11a: an Optional owner, emptied with `take()` in `defer`. Expected to compile. The close error can only be dropped, since `defer` can't throw.
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
  consuming func close() throws(CloseError) { discard self }
}
func work(_ o: borrowing Owned) throws(CloseError) {}

func deferClose() throws(CloseError) {
  var fd: Owned? = Owned(raw: 3)
  defer { try? fd.take()?.close() }
  switch fd {
  case .some(let o): try work(o)
  case .none: break
  }
}
