// V3e: consuming close that never uses `discard self` -> deinit also runs (second close). Expected to compile with no diagnostic, and to print: rawClose(3), deinit, rawClose(3).
struct CloseError: Error {}
func rawClose(_ fd: Int32) -> Int32 { print("rawClose(\(fd))"); return 0 }

struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit { print("deinit"); _ = rawClose(raw) }
  consuming func close() throws(CloseError) {
    if rawClose(raw) != 0 { throw CloseError() }
  }
}

@main struct Main {
  static func main() {
    let x = NC(raw: 3)
    try? x.close()
  }
}
