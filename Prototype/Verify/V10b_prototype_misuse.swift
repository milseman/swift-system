// V10b: misuse diagnostics against the prototype module (client side).
import SystemPackage

func closeBorrowed(_ fd: borrowing OwnedFD) throws { try fd.close() }
func relinquishBorrowed(_ fd: borrowing OwnedFD) -> FileDescriptor { fd.relinquish() }
func closeStandardInput() throws { try OwnedFD.standardInput.close() }
func relinquishStandardOutput() -> FileDescriptor { OwnedFD.standardOutput.relinquish() }
func useAfterClose() throws {
  let fd = try OwnedFD.open("/dev/null", .readOnly)
  try fd.close()
  _ = try fd.seek(offset: 0, from: .start)
}
