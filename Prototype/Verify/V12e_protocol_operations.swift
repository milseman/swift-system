// V12e: operations shared through a protocol that noncopyable owners conform to, as Rust's AsFd does. Expected to compile. Next/Vision.md rules out protocols for methods; this checks only that the language allows it, and each operation is still written once more in the protocol extension.
import SystemPackage

protocol DescriptorOwner: ~Copyable {
  var descriptor: FileDescriptor { get }
}

extension DescriptorOwner where Self: ~Copyable {
  func stat() throws(Errno) -> Stat { try descriptor.stat() }
  func synchronize() throws(Errno) { try descriptor.synchronize() }
}

struct Owner: ~Copyable, DescriptorOwner {
  let descriptor: FileDescriptor
  deinit {}
}

func use(_ owner: borrowing Owner) throws(Errno) -> Stat {
  try owner.synchronize()
  return try owner.stat()
}
