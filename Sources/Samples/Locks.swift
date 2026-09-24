/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

struct Locks: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Lock byte ranges of a file through two opens of it in one process"
  )

  @Argument(help: "Where to make a scratch file, which is removed afterward")
  var directory: String

  func run() throws {
    let path = FilePath(directory).appending("locks-demo-\(ProcessID.current.rawValue)")
    let a = try FileDescriptor.open(
      path, .readWrite, options: [.create, .exclusiveCreate], permissions: .ownerReadWrite)
    defer { try? path.unlink() }
    let b = try FileDescriptor.open(path, .readWrite)
    defer { try? b.close() }

    // Each open makes a separate open file, which holds its own locks,
    // so A and B exclude each other although one process holds both.
    // Classic fcntl locks belong to the process, so they would never
    // conflict here, and closing either descriptor would drop them all.
    print("A and B are two opens of \(path)")
    try a.closeAfter {
      try attempt("A write-locks bytes 0..<100") {
        try a.lock(.write, byteRange: 0..<100)
      }
      try attempt("B write-locks bytes 100..<200") {
        try b.lock(.write, byteRange: 100..<200)
      }
      try attempt("B read-locks bytes 50..<150") {
        try b.lock(.read, byteRange: 50..<150)
      }
      print("B asks what's in the way: \(try blocker(of: .read, 50..<150, for: b))")
      // Locking bytes that the same open file has locked replaces the kind
      // of lock on them, atomically.
      try attempt("A changes its lock on bytes 0..<100 to a read lock") {
        try a.lock(.read, byteRange: 0..<100)
      }
      try attempt("B read-locks bytes 50..<150") {
        try b.lock(.read, byteRange: 50..<150)
      }
      try attempt("B write-locks bytes 50..<150") {
        try b.lock(.write, byteRange: 50..<150)
      }

      // A duplicate refers to the same open file, so it shares A's lock,
      // and closing it leaves the lock in place.
      try a.duplicate().close()
      print("A duplicates its descriptor and closes the copy")
      try attempt("B write-locks bytes 50..<150") {
        try b.lock(.write, byteRange: 50..<150)
      }
      #if SYSTEM_PACKAGE_DARWIN
      if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
        let clock = ContinuousClock()
        let start = clock.now
        let locked = try b.lock(.write, byteRange: 50..<150, timeout: .milliseconds(200))
        let waited = (clock.now - start).components
        let milliseconds = waited.seconds * 1000 + waited.attoseconds / 1_000_000_000_000_000
        print("B waits up to 200 ms to write-lock bytes 50..<150: "
          + "\(locked ? "locked" : "blocked") after \(milliseconds) ms")
      }
      #endif
    }
    print("A closes, which releases its locks")
    try attempt("B write-locks bytes 50..<150") {
      try b.lock(.write, byteRange: 50..<150)
    }

    // Whole-file locks are a separate kind of lock, placed by flock,
    // which report a lock in the way as an error, rather than as `false`.
    // On Darwin the two kinds of lock conflict; on Linux they're independent,
    // so there every one of C's and B's attempts below succeeds.
    let c = try FileDescriptor.open(path, .readWrite)
    try c.closeAfter {
      print("C is a third open, which locks the whole file with flock")
      tryWholeFile("C locks the whole file, while B holds its byte-range lock") {
        try c.lockWholeFile(nonBlocking: true)
      }
      try b.unlock()
      print("B unlocks all its bytes")
      tryWholeFile("C locks the whole file") {
        try c.lockWholeFile(nonBlocking: true)
      }
      try attempt("B read-locks bytes 0..<10, while C holds its whole-file lock") {
        try b.lock(.read, byteRange: 0..<10)
      }
    }
  }
}

/// Prints whether a lock was placed, or was blocked by another open file's lock.
private func attempt(_ action: String, _ body: () throws -> Bool) rethrows {
  print("\(action): \(try body() ? "locked" : "blocked")")
}

/// Describes the lock that would block one on a range of bytes,
/// as another open file holds it.
private func blocker(
  of kind: FileDescriptor.FileLock.Kind, _ range: Range<Int64>, for fd: FileDescriptor
) throws -> String {
  // The query replaces the description with that of a lock in the way.
  var lock = FileDescriptor.FileLock(
    kind: kind, start: range.lowerBound, length: Int64(range.count))
  try fd.control(.getOFDLock, &lock)
  guard lock.kind != .none else { return "nothing" }
  // A length of 0 means "to the end of the file".
  let bytes = lock.length == 0
    ? "\(lock.start)..." : "\(lock.start)..<\(lock.start + lock.length)"
  // An open file description lock belongs to no process,
  // so the query reports its process ID as -1.
  let owner = lock.processID.rawValue == -1
    ? "an open file (process ID -1)" : "process \(lock.processID.rawValue)"
  return "a \(lock.kind) lock on bytes \(bytes), owned by \(owner)"
}

/// Prints whether a whole-file lock was placed, or why not.
private func tryWholeFile(_ action: String, _ body: () throws -> Void) {
  do {
    try body()
    print("\(action): locked")
  } catch {
    print("\(action): \(error)")
  }
}

#else

struct Locks: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Unavailable: this platform has no open file description locks"
  )

  func run() throws {
    complain("Error: locks needs F_OFD_SETLK, which this platform doesn't have")
    throw ExitCode.failure
  }
}

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
