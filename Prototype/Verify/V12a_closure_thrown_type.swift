// V12a: a withDescriptor closure that calls a `throws(Errno)` method, inside a `throws(Errno)` function. Expected to fail without FullTypedThrows: the closure is inferred to throw `any Error` ("thrown expression type 'any Error' cannot be converted to error type 'Errno'"). `annotated` compiles.
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

func inferred(_ fd: borrowing OwnedFD) throws(Errno) -> Stat {
  try fd.withDescriptor { try $0.stat() }
}

func annotated(_ fd: borrowing OwnedFD) throws(Errno) -> Stat {
  try fd.withDescriptor { fd throws(Errno) in try fd.stat() }
}
