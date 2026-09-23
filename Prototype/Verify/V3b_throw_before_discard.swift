// V3b: throwing before `discard self` in a consuming method of a type with a deinit.
struct CloseError: Error {}
func rawClose(_ fd: Int32) -> Int32 { fd < 0 ? -1 : 0 }

struct NC: ~Copyable {
  var raw: Int32
  deinit { _ = rawClose(raw) }
  consuming func close() throws(CloseError) {
    if rawClose(raw) != 0 { throw CloseError() }
    discard self
  }
}
