/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// A process's open file descriptors: proc_pidinfo's PROC_PIDLISTFDS.

// libproc is only in the macOS SDK.
#if os(macOS)

// Must import here to use the C types in @_alwaysEmitIntoClient APIs.
import Darwin

@available(System 199, *)
extension ProcessID {
  /// A file descriptor that a process has open, and what it refers to.
  ///
  /// To get a process's file descriptors,
  /// call ``ProcessID/openFileDescriptors()``.
  ///
  /// The corresponding C type is `struct proc_fdinfo`.
  /// - Note: Only available on macOS.
  @frozen
  public struct OpenFileDescriptor: Hashable, Sendable {
    /// The file descriptor, which is a number in the process's
    /// descriptor table, rather than in this one's
    /// unless the process is this one.
    public var fileDescriptor: FileDescriptor

    /// What the file descriptor refers to.
    public var kind: Kind

    /// Creates an open file descriptor's description.
    @_alwaysEmitIntoClient
    public init(fileDescriptor: FileDescriptor, kind: Kind) {
      self.fileDescriptor = fileDescriptor
      self.kind = kind
    }
  }

  /// Returns the file descriptors that the process has open,
  /// in order.
  ///
  /// Getting the descriptors of a process that belongs to another user
  /// requires privileges;
  /// otherwise, this method throws ``Errno/notPermitted``.
  /// If there's no such process,
  /// this method throws ``Errno/noSuchProcess``.
  ///
  /// The corresponding C function is `proc_pidinfo`,
  /// with the `PROC_PIDLISTFDS` flavor.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func openFileDescriptors() throws(Errno) -> [OpenFileDescriptor] {
    try _openFileDescriptors().get()
  }

  // Grows the buffer until part of it is left over, since the call fills
  // what fits and says nothing about the rest. No process has a million
  // descriptors, so growth stops there.
  @usableFromInline
  internal func _openFileDescriptors() -> Result<[OpenFileDescriptor], Errno> {
    let stride = MemoryLayout<proc_fdinfo>.stride
    var capacity = 64
    while true {
      var entries = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
      // proc_pidinfo returns the number of bytes it fills, which is 0 both
      // for an error and for a process with no descriptors open.
      system_errno = 0
      let filled = entries.withUnsafeMutableBytes { buffer in
        Int(
          system_proc_pidinfo(
            rawValue, _PROC_PIDLISTFDS, 0, buffer.baseAddress!, CInt(buffer.count)))
      }
      if filled == 0 && system_errno != 0 { return .failure(.current) }
      let count = filled / stride
      guard count < capacity || capacity >= 1 << 20 else {
        capacity *= 2
        continue
      }
      return .success(entries[..<count].map {
        OpenFileDescriptor(
          fileDescriptor: FileDescriptor(rawValue: $0.proc_fd),
          kind: OpenFileDescriptor.Kind(rawValue: $0.proc_fdtype))
      })
    }
  }
}

@available(System 199, *)
extension ProcessID.OpenFileDescriptor {
  /// What an open file descriptor refers to.
  ///
  /// The corresponding C type is the `PROX_FDTYPE_*` values.
  /// - Note: Only available on macOS.
  @frozen
  public struct Kind: RawRepresentable, Hashable, Sendable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed kind from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// An AppleTalk socket, which the system no longer supports.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_ATALK`.
    @_alwaysEmitIntoClient
    public static var appleTalk: Kind { Kind(rawValue: _PROX_FDTYPE_ATALK) }

    /// A file, directory, or device: a vnode.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_VNODE`.
    @_alwaysEmitIntoClient
    public static var vnode: Kind { Kind(rawValue: _PROX_FDTYPE_VNODE) }

    /// A socket.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_SOCKET`.
    @_alwaysEmitIntoClient
    public static var socket: Kind { Kind(rawValue: _PROX_FDTYPE_SOCKET) }

    /// A POSIX shared memory object, from `shm_open`.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_PSHM`.
    @_alwaysEmitIntoClient
    public static var sharedMemory: Kind { Kind(rawValue: _PROX_FDTYPE_PSHM) }

    /// A POSIX semaphore, from `sem_open`.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_PSEM`.
    @_alwaysEmitIntoClient
    public static var semaphore: Kind { Kind(rawValue: _PROX_FDTYPE_PSEM) }

    /// A kernel event queue, from `kqueue`.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_KQUEUE`.
    @_alwaysEmitIntoClient
    public static var kernelQueue: Kind { Kind(rawValue: _PROX_FDTYPE_KQUEUE) }

    /// A pipe.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_PIPE`.
    @_alwaysEmitIntoClient
    public static var pipe: Kind { Kind(rawValue: _PROX_FDTYPE_PIPE) }

    /// A file system events device clone.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_FSEVENTS`.
    @_alwaysEmitIntoClient
    public static var fileSystemEvents: Kind { Kind(rawValue: _PROX_FDTYPE_FSEVENTS) }

    /// A network policy descriptor.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_NETPOLICY`.
    @_alwaysEmitIntoClient
    public static var networkPolicy: Kind { Kind(rawValue: _PROX_FDTYPE_NETPOLICY) }

    /// A Skywalk channel.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_CHANNEL`.
    @_alwaysEmitIntoClient
    public static var channel: Kind { Kind(rawValue: _PROX_FDTYPE_CHANNEL) }

    /// A Skywalk nexus.
    ///
    /// The corresponding C constant is `PROX_FDTYPE_NEXUS`.
    @_alwaysEmitIntoClient
    public static var nexus: Kind { Kind(rawValue: _PROX_FDTYPE_NEXUS) }
  }
}

@available(System 199, *)
extension ProcessID.OpenFileDescriptor.Kind: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the kind.
  @inline(never)
  public var description: String {
    switch self {
    case .appleTalk: return "appleTalk"
    case .vnode: return "vnode"
    case .socket: return "socket"
    case .sharedMemory: return "sharedMemory"
    case .semaphore: return "semaphore"
    case .kernelQueue: return "kernelQueue"
    case .pipe: return "pipe"
    case .fileSystemEvents: return "fileSystemEvents"
    case .networkPolicy: return "networkPolicy"
    case .channel: return "channel"
    case .nexus: return "nexus"
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the kind, suitable for debugging.
  public var debugDescription: String { self.description }
}

#endif // os(macOS)
