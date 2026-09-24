// SKETCH, not API: the alternative to Sketch.swift's per-kind wrappers. One
// generic owner for every descriptor kind, over a protocol that captures the
// sub-types' conversion pattern: `fileDescriptor` and `init(unchecked:)`.
// It compiles (see check.sh), with the workarounds noted below. README.md
// explains why Sketch.swift's shape is preferred.

import SystemPackage
import SystemSockets

/// A descriptor kind that converts to and from FileDescriptor. SocketDescriptor
/// and TerminalDescriptor already have both members; FileDescriptor would
/// gain the identity versions.
protocol OwnableDescriptor: Sendable {
  var fileDescriptor: FileDescriptor { get }
  init(unchecked: FileDescriptor)
}

extension FileDescriptor: OwnableDescriptor {
  public var fileDescriptor: FileDescriptor { self }
  public init(unchecked fd: FileDescriptor) { self = fd }
}
@available(System 199, *)
extension SocketDescriptor: OwnableDescriptor {}
@available(System 199, *)
extension TerminalDescriptor: OwnableDescriptor {}

struct Owned<Descriptor: OwnableDescriptor>: ~Copyable, Sendable {
  // Workaround: a stored property of the generic type `Descriptor` makes
  // `discard self` fail, even with Descriptor: BitwiseCopyable ("can only
  // 'discard' type 'Owned<Descriptor>' if it contains trivially-destroyed
  // stored properties at this time"; V15a). Without `discard`, there's no
  // relinquish() and no consuming close(). So the owner stores the concrete
  // FileDescriptor, and rebuilds the kind's descriptor on each access.
  private let _fileDescriptor: FileDescriptor

  init(taking descriptor: Descriptor) { _fileDescriptor = descriptor.fileDescriptor }

  /// Converts between kinds without a check, as `init(unchecked:)` does for
  /// raw descriptors.
  init<Other>(unchecked other: consuming Owned<Other>) {
    _fileDescriptor = other.relinquish().fileDescriptor
  }

  deinit {
    // The same policy as OwnedFD's deinit: drop every error.
    _ = try? _fileDescriptor.close()
  }

  var descriptor: Descriptor { Descriptor(unchecked: _fileDescriptor) }
  var fileDescriptor: FileDescriptor { _fileDescriptor }

  consuming func relinquish() -> Descriptor {
    let descriptor = self.descriptor
    discard self
    return descriptor
  }

  consuming func close() throws {
    let fd = _fileDescriptor
    discard self
    try fd.close()
  }
}

// Kind-specific API goes in constrained extensions. A static stored property
// is allowed in one (V15b), so the standard streams still work.
extension Owned where Descriptor == FileDescriptor {
  static let standardInput = Owned(taking: .standardInput)
  static let standardOutput = Owned(taking: .standardOutput)
}

@available(System 199, *)
extension Owned where Descriptor == SocketDescriptor {
  static func open(
    _ domain: SocketDescriptor.Domain, _ type: SocketDescriptor.ConnectionType
  ) throws -> Owned {
    Owned(taking: try SocketDescriptor.open(domain, type))
  }
  func accept() throws -> Owned { Owned(taking: try descriptor.accept()) }
}

typealias OwnedFileDescriptor = Owned<FileDescriptor>
@available(System 199, *)
typealias OwnedSocketDescriptor = Owned<SocketDescriptor>

@available(System 199, *)
func genericUse() throws -> Int {
  let listener = try OwnedSocketDescriptor.open(.local, .stream)
  let asFile = OwnedFileDescriptor(unchecked: listener)
  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 1, alignment: 1)
  defer { buffer.deallocate() }
  _ = try asFile.fileDescriptor.stat()
  return try OwnedFileDescriptor.standardInput.descriptor.read(into: buffer)
}
