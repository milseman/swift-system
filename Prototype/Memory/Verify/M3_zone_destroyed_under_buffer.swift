// Claim: an OwnedZone can't be destroyed while a ZoneBuffer in it is
// alive. Expected: fails to compile.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func destroyUnderTheBuffer() throws {
  let arena = try Memory.OwnedZone()
  var numbers = try Memory.ZoneBuffer<Int>(capacity: 8, in: arena)
  arena.destroy()
  try numbers.append(1)
}
