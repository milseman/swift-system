// The owner under test. Its deinit policy is chosen at compile time:
//
//   -D POLICY_DROP        drop every close error (OwnedFD's deinit, IORing,
//                         Rust's OwnedFd in release builds)
//   -D POLICY_TRAP        trap on any close error (Mach.Port)
//   -D POLICY_MUST_CLOSE  trap whenever deinit runs: the owner must be
//                         consumed by close() or relinquish() (a debug-mode
//                         check; release builds would only close)
//   -D POLICY_EBADF       drop I/O errors, trap on EBADF, which means something
//                         other than the owner closed the descriptor (Rust's
//                         OwnedFd in debug builds; swift-subprocess's
//                         _safelyClose in all builds; README.md's
//                         recommendation, which wasn't adopted)
//
// The must-close trap stands for a debug-build check; the others would trap
// in every build.

struct OwnedFD: ~Copyable {
  let raw: Int32

  init(taking raw: Int32) { self.raw = raw }

  static func open() -> OwnedFD { OwnedFD(taking: Kernel.openDescriptor()) }

  consuming func close() throws(Errno) {
    let raw = self.raw
    discard self
    if let error = Kernel.close(raw) { throw error }
  }

  consuming func relinquish() -> Int32 {
    let raw = self.raw
    discard self
    return raw
  }

  /// The descriptor, not owned, as OwnedFD's `fileDescriptor` vends it.
  var fileDescriptor: Int32 { raw }

  func write(_ text: String) throws(Errno) { try Kernel.write(raw, text) }

  deinit {
    let error = Kernel.close(raw)
    #if POLICY_DROP
    if let error { Kernel.droppedCloseErrors.append(error) }
    #elseif POLICY_TRAP
    if let error { fatalError("close(\(raw)) in deinit failed: \(error)") }
    #elseif POLICY_MUST_CLOSE
    _ = error
    if Kernel.checksEnabled {
      fatalError("OwnedFD \(raw) was destroyed without close() or relinquish()")
    }
    #elseif POLICY_EBADF
    if error == .badFileDescriptor {
      fatalError("OwnedFD \(raw) was already closed by something other than its owner")
    }
    if let error { Kernel.droppedCloseErrors.append(error) }
    #else
    #error("Pass -D POLICY_DROP, POLICY_TRAP, POLICY_MUST_CLOSE, or POLICY_EBADF")
    #endif
  }
}

/// Both ends of a pipe, as in the OwnedPoll sample. No deinit, so a
/// consuming method can take the fields apart.
struct Pipe: ~Copyable {
  var readEnd: OwnedFD
  var writeEnd: OwnedFD
  init() {
    readEnd = .open()
    writeEnd = .open()
  }
}
