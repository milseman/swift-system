// Uses of an owner, each modeled on a sample or test in the package. Each
// scenario runs in its own process (see run.sh), so a trap ends only that one.

struct Scenario {
  var name: String
  var modeledOn: String
  var run: () throws(Errno) -> Void
}

func allScenarios() -> [Scenario] { [
  Scenario(name: "explicit-close", modeledOn: "OwnedCat, OwnedRedirect") { () throws(Errno) in
    let fd = OwnedFD.open()
    try fd.write("abc")
    try fd.close()
  },
  Scenario(name: "explicit-close-fails", modeledOn: "close() on NFS: EIO") { () throws(Errno) in
    Kernel.failNextClose = .ioError
    let fd = OwnedFD.open()
    try fd.write("abc")
    try fd.close()
  },
  Scenario(name: "scope-exit", modeledOn: "OwnedCopy's input file") { () throws(Errno) in
    let fd = OwnedFD.open()
    try fd.write("abc")
  },
  Scenario(name: "scope-exit-close-fails", modeledOn: "a forgotten close() on NFS") { () throws(Errno) in
    Kernel.failNextClose = .ioError
    let fd = OwnedFD.open()
    try fd.write("abc")
  },
  Scenario(name: "body-throws", modeledOn: "any throwing call before close()") { () throws(Errno) in
    Kernel.failNextWrite = .noSpace
    let fd = OwnedFD.open()
    try fd.write("abc")
    try fd.close()
  },
  Scenario(name: "body-throws-close-fails", modeledOn: "testThrowingScopeDropsCloseError") { () throws(Errno) in
    Kernel.failNextWrite = .noSpace
    Kernel.failNextClose = .ioError
    let fd = OwnedFD.open()
    try fd.write("abc")
    try fd.close()
  },
  Scenario(name: "closed-through-hatch", modeledOn: "V10a, testClosingThroughWithDescriptorLeavesOwnerStale") { () throws(Errno) in
    let fd = OwnedFD.open()
    fd.withDescriptor { _ = Kernel.close($0) }
  },
  Scenario(name: "closed-through-hatch-reused", modeledOn: "V10a, with the number reused") { () throws(Errno) in
    let culprit = OwnedFD.open()
    culprit.withDescriptor { _ = Kernel.close($0) }
    let victim = OwnedFD.open()   // reuses the number
    _ = consume culprit           // closes the victim's descriptor
    try victim.write("abc")
    try victim.close()
  },
  Scenario(name: "adopted-twice", modeledOn: "V10a adoptTwice") { () throws(Errno) in
    let raw = Kernel.openDescriptor()
    let first = OwnedFD(taking: raw)
    let second = OwnedFD(taking: raw)
    try first.close()
    _ = consume second
  },
  Scenario(name: "reassign", modeledOn: "testReassignmentClosesPreviousDescriptor") { () throws(Errno) in
    var fd = OwnedFD.open()
    try fd.write("1")
    fd = OwnedFD.open()
    try fd.write("2")
    try fd.close()
  },
  Scenario(name: "optional-set-to-nil", modeledOn: "testOptionalSetToNilCloses") { () throws(Errno) in
    var fd: OwnedFD? = OwnedFD.open()
    switch fd {
    case .some(let owned): try owned.write("abc")
    case .none: break
    }
    fd = nil
  },
  Scenario(name: "consuming-parameter", modeledOn: "testConsumingParameterClosesInCallee") { () throws(Errno) in
    func send(_ text: String, andDestroy fd: consuming OwnedFD) throws(Errno) {
      try fd.write(text)
    }
    try send("abc", andDestroy: OwnedFD.open())
  },
  Scenario(name: "loop-continue", modeledOn: "OwnedCat's loop, skipping one file") { () throws(Errno) in
    for i in 0..<3 {
      let fd = OwnedFD.open()
      if i == 1 { continue }
      try fd.close()
    }
  },
  Scenario(name: "inline-array-table", modeledOn: "OwnedPoll") { () throws(Errno) in
    guard #available(macOS 26, *) else { return }
    let pipes = InlineArray<3, Pipe> { _ in Pipe() }
    try send("first", through: pipes[0])  // not pipes[0].writeEnd (V9d)
  },
  Scenario(name: "relinquish", modeledOn: "OwnedLines (fdopen)") { () throws(Errno) in
    let fd = OwnedFD.open()
    let raw = fd.relinquish()
    _ = Kernel.close(raw)  // the new owner, fclose, closes it
  },

  // The scope-exit, body-throws, reassign, optional-set-to-nil, and
  // inline-array-table scenarios, rewritten to satisfy POLICY_MUST_CLOSE.
  Scenario(name: "must-close: scope-exit", modeledOn: "scope-exit") { () throws(Errno) in
    let fd = OwnedFD.open()
    try fd.write("abc")
    try fd.close()                        // +1 line
  },
  Scenario(name: "must-close: body-throws", modeledOn: "body-throws-close-fails") { () throws(Errno) in
    Kernel.failNextWrite = .noSpace
    Kernel.failNextClose = .ioError
    let fd = OwnedFD.open()
    do throws(Errno) {                    // +5 lines; `defer` can't consume
      try fd.write("abc")                 // `fd` (V11a)
    } catch {
      try? fd.close()
      throw error
    }
    try fd.close()
  },
  Scenario(name: "must-close: reassign", modeledOn: "reassign") { () throws(Errno) in
    var fd = OwnedFD.open()
    try fd.write("1")
    try fd.close()                        // +1 line
    fd = OwnedFD.open()
    try fd.write("2")
    try fd.close()
  },
  Scenario(name: "must-close: optional-set-to-nil", modeledOn: "optional-set-to-nil") { () throws(Errno) in
    var fd: OwnedFD? = OwnedFD.open()
    switch fd {
    case .some(let owned): try owned.write("abc")
    case .none: break
    }
    if let owned = fd.take() {            // replaces `fd = nil`, +2 lines
      try owned.close()
    }
  },
  Scenario(name: "must-close: inline-array-table", modeledOn: "inline-array-table") { () throws(Errno) in
    guard #available(macOS 26, *) else { return }
    // An InlineArray element can't be consumed, so each slot is Optional,
    // and every slot is emptied before the table is destroyed.
    var pipes = InlineArray<3, Pipe?> { _ in Pipe() }
    switch pipes[0] {
    case .some(let pipe): try pipe.writeEnd.write("first")
    case .none: break
    }
    var firstError: Errno? = nil
    for i in pipes.indices {
      if let pipe = pipes[i].take() {
        do throws(Errno) { try pipe.close() } catch { firstError = firstError ?? error }
      }
    }
    if let firstError { throw firstError }
  },
] }

func send(_ text: String, through pipe: borrowing Pipe) throws(Errno) {
  try pipe.writeEnd.write(text)
}

extension Pipe {
  /// Closes both ends, reporting the first error; used only by the
  /// must-close rewrite of the table.
  consuming func close() throws(Errno) {
    var firstError: Errno? = nil
    do { try readEnd.close() } catch { firstError = error }
    do { try writeEnd.close() } catch { firstError = firstError ?? error }
    if let firstError { throw firstError }
  }
}
