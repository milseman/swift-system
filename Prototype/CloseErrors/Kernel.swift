// A stand-in for the kernel's descriptor table, so that a scenario can make
// close(2) or write(2) fail on demand. Like Linux and Darwin, a close that
// reports an error still releases the descriptor, and `open` reuses the
// lowest free number.

enum Errno: Error, Equatable {
  case badFileDescriptor  // EBADF
  case ioError            // EIO
  case noSpace            // ENOSPC
}

enum Kernel {
  nonisolated(unsafe) static var open: Set<Int32> = []
  nonisolated(unsafe) static var contents: [Int32: String] = [:]
  nonisolated(unsafe) static var failNextClose: Errno? = nil
  nonisolated(unsafe) static var failNextWrite: Errno? = nil
  /// Whether debug-build checks run. A variable, so that the compiler
  /// doesn't flag the code after an unconditional trap as unreachable.
  nonisolated(unsafe) static var checksEnabled = true
  /// Close errors that no one reported, because they happened in a deinit.
  nonisolated(unsafe) static var droppedCloseErrors: [Errno] = []

  static func openDescriptor() -> Int32 {
    var fd: Int32 = 3
    while open.contains(fd) { fd += 1 }
    open.insert(fd)
    contents[fd] = ""
    return fd
  }

  /// Returns the error from closing `fd`, if any.
  static func close(_ fd: Int32) -> Errno? {
    guard open.remove(fd) != nil else { return .badFileDescriptor }
    if let error = failNextClose {
      failNextClose = nil
      return error
    }
    return nil
  }

  static func write(_ fd: Int32, _ text: String) throws(Errno) {
    guard open.contains(fd) else { throw .badFileDescriptor }
    if let error = failNextWrite {
      failNextWrite = nil
      throw error
    }
    contents[fd, default: ""] += text
  }
}
