// Ports to OwnedFD with a borrowing accessor that vends the FileDescriptor,
// plus the forwarded read, write, and seek it already has. Each `HATCH`
// comment marks a use of the accessor.
import SystemPackage
#if canImport(Darwin)
import Darwin
#endif

// From the AtomicWrite sample.
func atomicWrite(
  _ contents: String, named name: FilePath, in directory: borrowing OwnedFD,
  permissions: FilePermissions, group: GroupID?
) throws(Errno) {
  let temporary = FilePath(".\(name).tmp")
  let file = OwnedFD(taking: try FileDescriptor.open(
    temporary, relativeTo: directory.fileDescriptor, .writeOnly,  // HATCH
    options: [.create, .exclusiveCreate], permissions: .ownerReadWrite))
  do {
    try file.writeAll(contents.utf8)
    try file.fileDescriptor.setPermissions(permissions)  // HATCH
    if let group { try file.fileDescriptor.setOwner(group: group) }  // HATCH
    try flush(file)
    try file.close()
    try temporary.rename(
      relativeTo: directory.fileDescriptor, to: name, relativeTo: directory.fileDescriptor)  // HATCH
  } catch {
    try? temporary.unlink(relativeTo: directory.fileDescriptor)  // HATCH
    throw error
  }
  try flush(directory)
}

func flush(_ fd: borrowing OwnedFD) throws(Errno) {
  #if SYSTEM_PACKAGE_DARWIN || canImport(Darwin)
  if (try? fd.fileDescriptor.synchronizeFully()) != nil { return }  // HATCH
  #endif
  try fd.fileDescriptor.synchronize()  // HATCH
}

// From the PIDFile sample.
func createPIDFile(_ path: FilePath, recording process: ProcessID) throws(Errno) {
  let fd = try OwnedFD.open(
    path, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
  try fd.fileDescriptor.setPermissions([.ownerReadWrite, .groupRead, .otherRead])  // HATCH
  try fd.writeAll("\(process.rawValue)\n".utf8)
  try fd.fileDescriptor.synchronize()  // HATCH
  try fd.close()
}

// From the SetAttributes sample.
func setAttributes(
  of fd: borrowing OwnedFD, permissions: FilePermissions?, user: UserID?, group: GroupID?
) throws(Errno) -> (before: Stat, after: Stat) {
  let before = try fd.fileDescriptor.stat()  // HATCH
  if let permissions { try fd.fileDescriptor.setPermissions(permissions) }  // HATCH
  if user != nil || group != nil { try fd.fileDescriptor.setOwner(user: user, group: group) }  // HATCH
  #if canImport(Darwin)
  var flags = try fd.fileDescriptor.stat().flags  // HATCH
  flags.insert(.noDump)
  try fd.fileDescriptor.setFileFlags(flags)  // HATCH
  #endif
  return (before, try fd.fileDescriptor.stat())  // HATCH
}

// From the OwnedRedirect sample: dup2. FileDescriptor.duplicate(as:) throws
// untyped errors, so this does too.
func redirect(_ target: borrowing OwnedFD, to source: borrowing OwnedFD) throws {
  _ = try source.fileDescriptor.duplicate(as: target.fileDescriptor)  // HATCH
}

// From the OwnedCopy sample.
func permissions(of fd: borrowing OwnedFD) throws(Errno) -> FilePermissions {
  try fd.fileDescriptor.stat().permissions  // HATCH
}

// From the OwnedPoll sample.
func pollDescriptor(for fd: borrowing OwnedFD) -> pollfd {
  pollfd(fd: fd.fileDescriptor.rawValue, events: Int16(POLLIN), revents: 0)  // HATCH
}
