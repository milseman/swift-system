// V16j2: SE-0474's `yielding borrow` accessor doesn't parse in Swift 6.2,
// with or without -enable-experimental-feature CoroutineAccessors. An
// inactive `#if` block must parse too (V16e2), so code can't stage it for a
// newer compiler behind `#if hasFeature(CoroutineAccessors)`, which fails
// the same way. It can behind `#if compiler(>=6.3)`: checked with
// `compiler(>=99)`, whose inactive block isn't parsed.
// Expected: "consecutive statements on a line must be separated by ';'"
// for the accessor, with and without the feature.
//   swiftc -swift-version 6 -typecheck V16j2_yielding_borrow.swift
//   swiftc -swift-version 6 -enable-experimental-feature CoroutineAccessors -typecheck V16j2_yielding_borrow.swift
struct Handle: ~Copyable {
  let raw: Int32
  deinit {}
}

enum File: ~Copyable {
  case handle(Handle)

  var handle: Handle {
    yielding borrow {
      switch self {
      case .handle(let handle): yield handle
      }
    }
  }
}
