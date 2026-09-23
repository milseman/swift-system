// V14b: a BorrowedFD over SystemPackage's OwnedFD, used as the OwnedCat sample uses `borrowing OwnedFD`. Needs -enable-experimental-feature Lifetimes. Expected: `cat` fails at `file.close()` with "noncopyable 'file' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type", which is OwnedCat's own pattern, explicit close after use. `catVar` compiles, but warns that `file` is never mutated and should be a `let`, which is the version that fails. `catStandardStreams` borrows the static lets, and compiles.
import SystemPackage

struct BorrowedFD: ~Escapable {
  // Private, so the copyable FileDescriptor can't escape; every operation
  // BorrowedFD offers has to be forwarded again.
  private let descriptor: FileDescriptor

  @_lifetime(borrow owner)
  init(_ owner: borrowing OwnedFD) { descriptor = owner.fileDescriptor }

  func read(into buffer: UnsafeMutableRawBufferPointer) throws(Errno) -> Int {
    do throws(any Error) { return try descriptor.read(into: buffer) } catch { throw error as! Errno }
  }
  func writeAll(_ buffer: UnsafeRawBufferPointer) throws(Errno) {
    do throws(any Error) { _ = try descriptor.writeAll(buffer) } catch { throw error as! Errno }
  }
}

extension OwnedFD {
  var borrowed: BorrowedFD {
    @_lifetime(borrow self)
    borrowing get { BorrowedFD(self) }
  }
}

func copyAll(from source: BorrowedFD, to destination: BorrowedFD) throws(Errno) {
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 1)
  defer { buffer.deallocate() }
  while true {
    let count = try source.read(into: buffer)
    if count == 0 { return }
    try destination.writeAll(UnsafeRawBufferPointer(rebasing: buffer[..<count]))
  }
}

func cat(_ path: FilePath) throws(Errno) {
  let file = try OwnedFD.open(path, .readOnly)
  try copyAll(from: file.borrowed, to: OwnedFD.standardOutput.borrowed)
  try file.close()
}

func catVar(_ path: FilePath) throws(Errno) {
  var file = try OwnedFD.open(path, .readOnly)
  try copyAll(from: file.borrowed, to: OwnedFD.standardOutput.borrowed)
  try file.close()
}

func catStandardStreams() throws(Errno) {
  try copyAll(from: OwnedFD.standardInput.borrowed, to: OwnedFD.standardOutput.borrowed)
}
