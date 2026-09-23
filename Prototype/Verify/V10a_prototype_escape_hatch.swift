// V10a: what the `fileDescriptor` accessor does not prevent (client of the prototype module). Expected to compile. The same held for withDescriptor(body:), which the accessor replaced. Closing the vended descriptor now makes the owner's deinit trap (see Tests/SystemTests/OwnedFDDeinitTests.swift), unless the number is reused first.
import SystemPackage

func leakCopy(_ owned: borrowing OwnedFD) -> FileDescriptor {
  owned.fileDescriptor                        // a copy of the FileDescriptor escapes
}

func closeThroughHatch(_ owned: borrowing OwnedFD) throws {
  try owned.fileDescriptor.close()            // closes; the owner's deinit closes again later
}

func closeStandardInputThroughHatch() throws {
  try OwnedFD.standardInput.fileDescriptor.close()
}

func adoptTwice(_ fd: FileDescriptor) {
  let a = OwnedFD(taking: fd)                 // two owners of one descriptor
  let b = OwnedFD(taking: fd)
  _ = a; _ = b
}
