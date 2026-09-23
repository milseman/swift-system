// V12c: vending the FileDescriptor from a temporary owner. Expected to compile with no diagnostic, both through the `fileDescriptor` accessor and through a withDescriptor(body:) closure. The temporary is destroyed at the end of the statement, which closes the descriptor, so both results name a closed (or reused) descriptor.
import SystemPackage

extension OwnedFD {
  // A client-side stand-in for withDescriptor(body:), which the
  // `fileDescriptor` accessor replaced.
  func withDescriptor<R: ~Copyable, E: Error>(
    body: (FileDescriptor) throws(E) -> R
  ) throws(E) -> R {
    try body(fileDescriptor)
  }
}

func throughAccessor() throws -> FileDescriptor {
  try OwnedFD.open("/dev/null", .readOnly).fileDescriptor
}

func throughClosure() throws -> FileDescriptor {
  try OwnedFD.open("/dev/null", .readOnly).withDescriptor { $0 }
}
