// V10a: what `withDescriptor` does not prevent (client of the prototype module). Expected to compile.
import SystemPackage

func leakCopy(_ owned: borrowing OwnedFD) -> FileDescriptor {
  owned.withDescriptor { $0 }                 // a copy of the FileDescriptor escapes
}

func closeThroughHatch(_ owned: borrowing OwnedFD) throws {
  try owned.withDescriptor { try $0.close() } // closes; the owner's deinit closes again later
}

func closeStandardInputThroughHatch() throws {
  try OwnedFD.standardInput.withDescriptor { try $0.close() }
}

func adoptTwice(_ fd: FileDescriptor) {
  let a = OwnedFD(fd)                         // two owners of one descriptor
  let b = OwnedFD(fd)
  _ = a; _ = b
}
