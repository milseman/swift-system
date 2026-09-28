// Claim: a ZoneBuffer can't outlive the OwnedZone it's in. This function
// may return a buffer that depends on `other`, but returns one in a zone of
// its own, which ends with the call. Expected: fails to compile.

import SystemPackage
import MemoryPrototype

@available(System 199, *)
@_lifetime(borrow other)
func escapeTheZone(_ other: borrowing Memory.OwnedZone) throws -> Memory.ZoneBuffer<Int> {
  let arena = try Memory.OwnedZone()
  return try Memory.ZoneBuffer<Int>(capacity: 8, in: arena)
}
