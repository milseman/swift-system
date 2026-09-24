// V11d: closing on the error path and the success path without `defer`, as a must-close policy needs. Expected to compile.
struct CloseError: Error {}
struct Owned: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {}
  consuming func close() throws(CloseError) { discard self }
}
func work(_ o: borrowing Owned) throws(CloseError) {}

func closeOnBothPaths() throws(CloseError) {
  let fd = Owned(raw: 3)
  do {
    try work(fd)
  } catch {
    try? fd.close()
    throw error
  }
  try fd.close()
}
