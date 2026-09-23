// V11b: consuming a local `var` owner in `defer`. Expected to fail: "missing reinitialization of closure capture 'fd' after consume".
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
  consuming func close() throws(CloseError) { discard self }
}
func work(_ o: borrowing Owned) throws(CloseError) {}

func deferClose() throws(CloseError) {
  var fd = Owned(raw: 3)
  defer { try? fd.close() }
  fd.raw += 0
  try work(fd)
}
