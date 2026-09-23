// V1e: is FileDescriptor Sendable (implicitly or explicitly), and can a Sendable noncopyable type wrap it?
import SystemPackage
func needsSendable(_: some Sendable) {}
func probe() { needsSendable(FileDescriptor.standardInput) }

public struct WrapsFD: ~Copyable, Sendable {
  public var fd: FileDescriptor
  public init(fd: FileDescriptor) { self.fd = fd }
  deinit {}
}
