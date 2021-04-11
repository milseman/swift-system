/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Only available on FreeBSD-derived systems
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

/// A generic means of notifying the user when a kernel event (`KEvent`) happens
/// or a condition holds, based on the results of small pieces of kernel code
/// termed filters.
///
/// This is represented as a special kind of `FileDescriptor`.
@frozen
public struct KQueueDescriptor: RawRepresentable, Hashable {
  /// The raw C kqueue file descriptor.
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  /// Creates a strongly-typed kqueue from a raw C kqueue file descriptor.
  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue }
}


extension KQueueDescriptor {
  /// The file descriptor for `self`.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor {
    FileDescriptor(rawValue: rawValue)
  }

  /// Treat `fd` as a kqueue descriptor, without checking with the operating
  /// system that it actually refers to a kqueue.
  @_alwaysEmitIntoClient
  public init(unchecked fd: FileDescriptor) {
    self.init(rawValue: fd.rawValue)
  }
}

extension KQueueDescriptor {
  /// Allocate a kqueue file descriptor.
  ///
  /// The corresponding C function is `kqueue`.
  @_alwaysEmitIntoClient
  public static func create(
    // TODO: Can this be interrupted?
    retryOnInterrupt: Bool = true
  ) throws -> KQueueDescriptor {
    try _create(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _create(
    retryOnInterrupt: Bool
  ) -> Result<KQueueDescriptor, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_kqueue()
    }.map { KQueueDescriptor(rawValue: $0) }
  }

  /// Close the underlying file descriptor
  ///
  /// This is equivalent to `fileDescriptor.close()`.
  @_alwaysEmitIntoClient
  public func close() throws {
    try fileDescriptor.close()
  }

  // TODO: Forward any other vaguely valid methods?



}

#endif
