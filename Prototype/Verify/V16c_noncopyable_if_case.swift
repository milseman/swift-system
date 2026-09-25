// V16c: `if case` and `guard case` consume a noncopyable enum in Swift 6.2,
// even with no binding, so neither works on a `borrowing` parameter or on a
// static let. Only `switch` borrows. On a local `let`, `if case` compiles and
// consumes the local.
// Expected: four errors. For the two parameters, "'file' is borrowed and
// cannot be consumed". For the two static lets, "'unknown' is borrowed and
// cannot be consumed": the diagnostic doesn't name `standardInput`.
// `onLocal` compiles.
//   swiftc -swift-version 6 -emit-sil -o /dev/null V16c_noncopyable_if_case.swift
struct Owner: ~Copyable, Sendable {
  let raw: Int32
  borrowing func read() -> Int32 { raw }
  deinit {}
}

enum File: ~Copyable, Sendable {
  case fd(Owner)
  case handle(Owner)
  static let standardInput = File.fd(Owner(raw: 0))
}

func ifCase(_ file: borrowing File) -> Int32? {
  if case .fd(let owner) = file { return owner.read() }
  return nil
}

func guardCaseNoBinding(_ file: borrowing File) -> Bool {
  guard case .fd = file else { return false }
  return true
}

func ifCaseStatic() -> Int32? {
  if case .fd(let owner) = File.standardInput { return owner.read() }
  return nil
}

func guardCaseStatic() -> Bool {
  guard case .fd = File.standardInput else { return false }
  return true
}

func onLocal() -> Int32? {
  let file = File.fd(Owner(raw: 3))
  if case .fd(let owner) = file { return owner.read() }
  return nil
}
