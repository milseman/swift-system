// V11a: consuming a local `let` owner in `defer`, as a must-close policy would need. Expected to fail: "noncopyable 'fd' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type".
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
  consuming func close() throws(CloseError) { discard self }
}
func work(_ o: borrowing Owned) throws(CloseError) {}

func deferClose() throws(CloseError) {
  let fd = Owned(raw: 3)
  defer { try? fd.close() }
  try work(fd)
}
