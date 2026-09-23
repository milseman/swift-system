// V12d: `@dynamicMemberLookup` over `KeyPath<FileDescriptor, T>` on a noncopyable owner, as a way to reach FileDescriptor's API without forwarding. Expected: the properties compile; the method call fails ("dynamic key path member lookup cannot refer to instance method 'stat(retryOnInterrupt:)'").
import SystemPackage

@dynamicMemberLookup
struct Owner: ~Copyable {
  let descriptor: FileDescriptor
  deinit {}
  subscript<T>(dynamicMember keyPath: KeyPath<FileDescriptor, T>) -> T {
    descriptor[keyPath: keyPath]
  }
}

func properties(_ owner: borrowing Owner) -> (CInt, Bool) {
  (owner.rawValue, owner.isTerminal)
}

func method(_ owner: borrowing Owner) throws -> Stat {
  try owner.stat()
}
