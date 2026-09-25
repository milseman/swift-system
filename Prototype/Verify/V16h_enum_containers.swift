// V16h: where an owned platform enum can be stored in Swift 6.2. It can't be
// an Array element or a Dictionary value, so a table of open files keyed by
// name, a poll loop's usual shape, holds raw names instead, or uses a
// fixed-size InlineArray of optionals (V9a), where take() empties a slot.
// Expected: compiles, and prints "took fd 3", "closed 3", "end of table",
// "closed 4". With -D ARRAY: "type 'File' does not conform to protocol
// 'Copyable'" for the Array and the Dictionary, and "referencing subscript
// 'subscript(_:)' on 'Dictionary' requires that 'File' conform to 'Copyable'".
//   swiftc -swift-version 6 -parse-as-library V16h_enum_containers.swift -o /tmp/V16h && /tmp/V16h
//   swiftc -swift-version 6 -parse-as-library -D ARRAY -typecheck V16h_enum_containers.swift
struct Owner: ~Copyable {
  let raw: Int32
  deinit { print("closed \(raw)") }
}

enum File: ~Copyable {
  case fd(Owner)
  case handle(Owner)
}

#if ARRAY
func array() {
  var open: [File] = []
  open.append(.fd(Owner(raw: 3)))
  var byName: [String: File] = [:]
  byName["log"] = .fd(Owner(raw: 4))
}
#endif

@available(macOS 26, *)
func table() {
  var slots: InlineArray<2, File?> = [.fd(Owner(raw: 3)), .handle(Owner(raw: 4))]
  // take() moves one owner out and leaves nil behind.
  if let file = slots[0].take() {
    switch file {
    case .fd(let owner): print("took fd \(owner.raw)")
    case .handle(let owner): print("took handle \(owner.raw)")
    }
  }
  print("end of table")
}

@main struct Main {
  static func main() {
    if #available(macOS 26, *) { table() }
  }
}
