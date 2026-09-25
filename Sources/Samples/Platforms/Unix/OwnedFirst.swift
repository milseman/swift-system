/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// VARIANT, compiled in both configurations: a Unix side that mirrors the
// Win32 drafts' owned-first model. The owner is the full-power type. It
// hosts the operations itself, as Win32.FileHandle does, and its descriptor
// is an escape hatch, as `unsafeRawHandle` is. There's no vended
// FileDescriptor to call operations on.
//
// It stands for what OwnedFD would become. In System, it would host all of
// FileDescriptor's members (38, per Prototype/Forwarding's inventory), and
// the socket and terminal owners would host theirs. Only the members the
// samples use are here, each a one-line call to today's FileDescriptor.

import SystemPackage

/// A namespace for the owned-first Unix variant.
enum Unix {}

extension Unix {
  /// An open file descriptor, owned, which hosts the file operations.
  @safe
  struct FileHandle: ~Copyable, Sendable {
    private let descriptor: FileDescriptor

    /// Adopts a raw descriptor, taking ownership of it.
    @unsafe
    init(unsafelyAdopting descriptor: FileDescriptor) {
      self.descriptor = descriptor
    }

    /// The raw descriptor. Valid only while this value is alive.
    @unsafe
    var unsafeRawDescriptor: FileDescriptor { descriptor }

    /// Gives up ownership and returns the raw descriptor.
    @unsafe
    consuming func relinquish() -> FileDescriptor {
      let raw = descriptor
      discard self
      return raw
    }

    /// Closes the descriptor.
    ///
    /// The corresponding C function is `close`.
    consuming func close() throws(Errno) {
      let raw = descriptor
      discard self
      try typed { try raw.close() }
    }

    deinit {
      _ = try? descriptor.close()
    }
  }
}

extension Unix.FileHandle {
  /// Opens or creates a file.
  ///
  /// The corresponding C function is `open`.
  static func open(
    _ path: FilePath,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = [],
    permissions: FilePermissions? = nil
  ) throws(Errno) -> Unix.FileHandle {
    let raw = try typed {
      try FileDescriptor.open(path, mode, options: options, permissions: permissions)
    }
    return Unix.FileHandle(unsafelyAdopting: raw)
  }

  /// The corresponding C function is `fcntl`, with `F_GETFD`.
  func descriptorFlags() throws(Errno) -> FileDescriptor.DescriptorFlags {
    try descriptor.descriptorFlags()
  }

  /// The corresponding C function is `fcntl`, with `F_SETFD`.
  func setDescriptorFlags(_ flags: FileDescriptor.DescriptorFlags) throws(Errno) {
    try descriptor.setDescriptorFlags(flags)
  }

  /// The corresponding C function is `lseek`.
  @discardableResult
  func seek(offset: Int64, from whence: FileDescriptor.SeekOrigin) throws(Errno) -> Int64 {
    try typed { try descriptor.seek(offset: offset, from: whence) }
  }

  /// The corresponding C function is `fstat`.
  func stat() throws(Errno) -> Stat { try descriptor.stat() }

  /// The corresponding C function is `ftruncate`.
  func resize(to newSize: Int64) throws(Errno) { try typed { try descriptor.resize(to: newSize) } }

  /// The corresponding C function is `fsync`.
  func synchronize() throws(Errno) { try descriptor.synchronize() }
}

@available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
extension Unix.FileHandle {
  /// The corresponding C function is `read`.
  func read(into buffer: inout OutputRawSpan) throws(Errno) -> Int {
    try descriptor.read(into: &buffer)
  }

  /// The corresponding C function is `pread`.
  func read(fromAbsoluteOffset offset: Int64, into buffer: inout OutputRawSpan) throws(Errno) -> Int {
    try descriptor.read(fromAbsoluteOffset: offset, into: &buffer)
  }

  /// The corresponding C function is `write`, called until all is written.
  @discardableResult
  func writeAll(_ data: RawSpan) throws(Errno) -> Int { try descriptor.writeAll(data) }

  /// The corresponding C function is `pwrite`, called until all is written.
  @discardableResult
  func writeAll(toAbsoluteOffset offset: Int64, _ data: RawSpan) throws(Errno) -> Int {
    try descriptor.writeAll(toAbsoluteOffset: offset, data)
  }
}

/// Calls one of FileDescriptor's older members, which throw untyped errors
/// that are always Errno, from typed code.
private func typed<R>(_ body: () throws -> R) throws(Errno) -> R {
  do {
    return try body()
  } catch let error as Errno {
    throw error
  } catch {
    fatalError("FileDescriptor threw \(error), which isn't Errno")
  }
}
