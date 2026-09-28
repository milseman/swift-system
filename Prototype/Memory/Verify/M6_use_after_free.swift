// Claim: a buffer can't be used after free() or relinquish() consumed it.
// Expected: fails to compile.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func useAfterFree() throws -> Int {
  let buffer = try Memory.Buffer<Int>(capacity: 8)
  buffer.free()
  return buffer.count
}
