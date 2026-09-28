// Claim: the hazard the handle leaves. A Buffer made with a Memory.Zone
// handle, rather than in an OwnedZone, can outlive the zone, which then
// frees its memory under it. Expected: compiles (so the hazard is real).

import SystemPackage
import MemoryPrototype

@available(System 199, *)
func outliveTheZone() throws -> Memory.Buffer<Int> {
  let arena = try Memory.OwnedZone()
  return try Memory.Buffer<Int>(capacity: 8, in: arena.zone)
}
