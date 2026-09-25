// V16b: a noncopyable platform enum supports the switches its common subset
// and its users need, in Swift 6.2 with no experimental feature:
// - a borrowing switch over a `borrowing` parameter, over `self` in a
//   non-consuming method, and over a static let (standard input)
// - a consuming switch (`switch consume self`) that moves each payload out,
//   as `close()` and `relinquish()` need
// - extracting one payload. With `default: return nil`, extraction destroys
//   the owner in every other case, so a failable `as` accessor closes what it
//   doesn't return. A result enum that hands back the original (the Sketch's
//   `Narrowing`) doesn't.
// Expected: compiles, and prints, in order: "fd 3 / handle 4 / fd 0",
// "closed 4" (the handle, destroyed by the failable accessor) before
// "not an fd", "narrowed fd 5" and "closed 5" (the extracted owner ends with
// its arm), "kept handle 6" and "closed 6", then "closed 3" at the end of main.
//   swiftc -swift-version 6 -parse-as-library V16b_noncopyable_enum_switches.swift -o /tmp/V16b && /tmp/V16b
struct Owner: ~Copyable, Sendable {
  let raw: Int32
  init(raw: Int32) { self.raw = raw }
  borrowing func read() -> Int32 { raw }
  consuming func close() {
    print("closed \(raw)")
    discard self
  }
  deinit { print("closed \(raw)") }
}

enum File: ~Copyable, Sendable {
  case fd(Owner)
  case handle(Owner)

  static let standardInput = File.fd(Owner(raw: 0))

  /// A common-subset operation: a borrowing switch over `self`.
  func describe() -> String {
    switch self {
    case .fd(let owner): return "fd \(owner.read())"
    case .handle(let owner): return "handle \(owner.read())"
    }
  }

  /// Closing: a consuming switch.
  consuming func close() {
    switch consume self {
    case .fd(let owner): owner.close()
    case .handle(let owner): owner.close()
    }
  }

  /// A failable accessor: the other case's owner is destroyed.
  consuming func asFD() -> Owner? {
    switch consume self {
    case .fd(let owner): return owner
    default: return nil
    }
  }

  /// A one-step narrowing that returns the original when it doesn't match.
  consuming func narrowToFD() -> Narrowing<Owner, File> {
    switch consume self {
    case .fd(let owner): return .narrowed(owner)
    case .handle(let owner): return .notNarrowed(.handle(owner))
    }
  }
}

enum Narrowing<Narrowed: ~Copyable, Original: ~Copyable>: ~Copyable {
  case narrowed(Narrowed)
  case notNarrowed(Original)
}
extension Narrowing: Copyable where Narrowed: Copyable, Original: Copyable {}

/// A borrowing switch over a parameter.
func describeBorrowed(_ file: borrowing File) -> String {
  switch file {
  case .fd(let owner): return "fd \(owner.read())"
  case .handle(let owner): return "handle \(owner.read())"
  }
}

@main struct Main {
  static func main() {
    let three = File.fd(Owner(raw: 3))
    let four = File.handle(Owner(raw: 4))
    print("\(describeBorrowed(three)) / \(four.describe()) / \(File.standardInput.describe())")
    if four.asFD() == nil { print("not an fd") }  // prints "closed 4" first
    switch File.fd(Owner(raw: 5)).narrowToFD() {
    case .narrowed(let owner): print("narrowed fd \(owner.read())")
    case .notNarrowed(let file): print("kept \(file.describe())")
    }
    switch File.handle(Owner(raw: 6)).narrowToFD() {
    case .narrowed(let owner): print("narrowed fd \(owner.read())")
    case .notNarrowed(let file):
      print("kept \(file.describe())")
      file.close()
    }
    _ = three
  }
}
