// V3a: `consuming func close() throws(E)` alongside `deinit`, with `discard self` before the throwing call. Expected to compile and to print: closed 3, error -1, end of main. The deinit runs on neither path, and the failure reaches the caller as a CloseError.
struct CloseError: Error { var code: Int32 }

func rawClose(_ fd: Int32) -> Int32 { fd < 0 ? -1 : 0 } // stand-in for close(2)

struct NC: ~Copyable {
  var raw: Int32
  init(raw: Int32) { self.raw = raw }
  deinit {
    print("deinit \(raw)")
    _ = rawClose(raw)
  }
  consuming func close() throws(CloseError) {
    let fd = raw
    discard self
    if rawClose(fd) != 0 { throw CloseError(code: fd) }
  }
}

@main struct Main {
  static func main() {
    let good = NC(raw: 3)
    do { try good.close(); print("closed 3") } catch { print("error \(error.code)") }
    let bad = NC(raw: -1)
    do { try bad.close(); print("closed -1") } catch { print("error \(error.code)") }
    print("end of main")
  }
}
