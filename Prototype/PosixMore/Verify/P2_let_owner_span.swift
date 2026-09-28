// Claim (Swift 6.2): a `let` noncopyable owner can't be consumed after a span
// borrowed it, even once the span is gone; a `var` owner, or a borrowing
// helper, avoids it. Expected to fail only in letOwner().
import SystemPackage

@available(macOS 15, *)
func count(_ bytes: RawSpan) -> Int { bytes.byteCount }

@available(macOS 15, *)
func letOwner() throws {
  let mapping = try MemoryMapping(byteCount: 4096)
  _ = count(mapping.bytes)
  try mapping.unmap()  // error: cannot be consumed ... borrowed by a non-Escapable type
}

@available(macOS 15, *)
func varOwner() throws {
  var mapping = try MemoryMapping(byteCount: 4096)  // warning: never mutated
  _ = count(mapping.bytes)
  try mapping.unmap()
}

@available(macOS 15, *)
func helper(_ mapping: borrowing MemoryMapping) -> Int { count(mapping.bytes) }

@available(macOS 15, *)
func letOwnerThroughAHelper() throws {
  let mapping = try MemoryMapping(byteCount: 4096)
  _ = helper(mapping)
  try mapping.unmap()
}
