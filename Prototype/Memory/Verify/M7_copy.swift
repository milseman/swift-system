// Claim: a buffer can't be copied, so two owners can't free it twice.
// Expected: fails to compile.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func copyTheBuffer() throws -> Int {
  let buffer = try Memory.Buffer<Int>(capacity: 8)
  let copy = buffer
  return buffer.count + copy.count
}
