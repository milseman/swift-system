// Claim: an entry of NetworkInterface.Addresses can't outlive the list, so
// neither keeping it nor returning it compiles. Expected to fail, with
// lifetime-dependence errors on the marked lines.
import SystemPackage

@available(macOS 15, *)
func keep() throws {
  let addresses = try NetworkInterface.Addresses()
  var kept: [String] = []
  addresses.forEach { entry in
    kept.append(entry.name)  // Copying a value out is fine.
  }
  _ = kept
}

@available(macOS 15, *)
func escape(_ addresses: borrowing NetworkInterface.Addresses) -> NetworkInterface.Addresses.Entry? {
  var found: NetworkInterface.Addresses.Entry? = nil
  addresses.forEach { entry in
    found = entry  // error: the entry escapes the closure
  }
  return found  // error: and the list's borrow
}

@available(macOS 15, *)
func escapeSpan(_ addresses: borrowing NetworkInterface.Addresses) -> RawSpan? {
  var span: RawSpan? = nil
  addresses.forEach { entry in
    span = entry.address  // error: the span depends on the entry
  }
  return span
}
