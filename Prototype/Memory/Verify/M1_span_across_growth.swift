// Claim: a buffer's span can't be used after the buffer grows, which can
// move it (realloc). Expected: fails to compile.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func spanAcrossGrowth() throws -> Int {
  var buffer = try Memory.Buffer<Int>(capacity: 1)
  try buffer.append(1)
  let span = buffer.span
  try buffer.append(2)  // May move the elements.
  return span[0]
}
