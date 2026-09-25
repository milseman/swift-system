// Claim: without `discard`, a consuming close() can mark the owner closed by
// clearing an optional handle; the deinit still runs, and sees nothing to
// close. This is how DirectoryStream and DirectoryWalk close. Compiles and
// prints "closed 7", "deinit: nothing to close", "deinit closes 8".
struct Stream: ~Copyable {
  var handle: Int?
  var names: [CChar] = []
  init(_ handle: Int) { self.handle = handle }
  deinit {
    if let handle { print("deinit closes \(handle)") } else { print("deinit: nothing to close") }
  }
  consuming func close() {
    print("closed \(handle!)")
    handle = nil
  }
}

func run() {
  let first = Stream(7)
  first.close()
  _ = Stream(8)
}
run()
