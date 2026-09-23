// Ports to OwnedFD as it was before the `fileDescriptor` accessor replaced
// withDescriptor(body:): forwarded read, write, and seek, and the closure for
// everything else. Each `HATCH` comment marks a use of withDescriptor.
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
  let file = try directory.withDescriptor { directory throws(Errno) in  // HATCH
    OwnedFD(taking: try FileDescriptor.open(
      temporary, relativeTo: directory, .writeOnly,
      options: [.create, .exclusiveCreate], permissions: .ownerReadWrite))
  }
  do {
    try file.writeAll(contents.utf8)
    try file.withDescriptor { fd throws(Errno) in  // HATCH
      try fd.setPermissions(permissions)
      if let group { try fd.setOwner(group: group) }
    }
    try flush(file)
    try file.close()
    try directory.withDescriptor { directory throws(Errno) in  // HATCH
      try temporary.rename(relativeTo: directory, to: name, relativeTo: directory)
    }
  } catch {
    try? directory.withDescriptor { directory throws(Errno) in  // HATCH
      try temporary.unlink(relativeTo: directory)
    }
    throw error
  }
  try flush(directory)
}

func flush(_ fd: borrowing OwnedFD) throws(Errno) {
  try fd.withDescriptor { fd throws(Errno) in  // HATCH
    #if SYSTEM_PACKAGE_DARWIN || canImport(Darwin)
    if (try? fd.synchronizeFully()) != nil { return }
    #endif
    try fd.synchronize()
  }
}

// From the PIDFile sample.
func createPIDFile(_ path: FilePath, recording process: ProcessID) throws(Errno) {
  let fd = try OwnedFD.open(
    path, .writeOnly, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
  try fd.withDescriptor { fd throws(Errno) in  // HATCH
    try fd.setPermissions([.ownerReadWrite, .groupRead, .otherRead])
  }
  try fd.writeAll("\(process.rawValue)\n".utf8)
  try fd.withDescriptor { fd throws(Errno) in try fd.synchronize() }  // HATCH
  try fd.close()
}

// From the SetAttributes sample.
func setAttributes(
  of fd: borrowing OwnedFD, permissions: FilePermissions?, user: UserID?, group: GroupID?
) throws(Errno) -> (before: Stat, after: Stat) {
  let before = try fd.withDescriptor { fd throws(Errno) in try fd.stat() }  // HATCH
  try fd.withDescriptor { fd throws(Errno) in  // HATCH
    if let permissions { try fd.setPermissions(permissions) }
    if user != nil || group != nil { try fd.setOwner(user: user, group: group) }
    #if canImport(Darwin)
    var flags = try fd.stat().flags
    flags.insert(.noDump)
    try fd.setFileFlags(flags)
    #endif
  }
  return (before, try fd.withDescriptor { fd throws(Errno) in try fd.stat() })  // HATCH
}

// From the OwnedRedirect sample: dup2. FileDescriptor.duplicate(as:) throws
// untyped errors, so this does too.
func redirect(_ target: borrowing OwnedFD, to source: borrowing OwnedFD) throws {
  try source.withDescriptor { source in  // HATCH
    try target.withDescriptor { target in  // HATCH
      _ = try source.duplicate(as: target)
    }
  }
}

// From the OwnedCopy sample.
func permissions(of fd: borrowing OwnedFD) throws(Errno) -> FilePermissions {
  try fd.withDescriptor { fd throws(Errno) in try fd.stat() }.permissions  // HATCH
}

// From the OwnedPoll sample.
func pollDescriptor(for fd: borrowing OwnedFD) -> pollfd {
  fd.withDescriptor { pollfd(fd: $0.rawValue, events: Int16(POLLIN), revents: 0) }  // HATCH
}

extension OwnedFD {
  // A client-side stand-in for withDescriptor(body:), which the
  // `fileDescriptor` accessor replaced.
  func withDescriptor<R: ~Copyable, E: Error>(
    body: (FileDescriptor) throws(E) -> R
  ) throws(E) -> R {
    try body(fileDescriptor)
  }
}
