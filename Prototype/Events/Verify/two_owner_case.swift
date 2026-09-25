// Swift 6.2 (swiftlang-6.2.0.19.9): a borrowing switch over a noncopyable
// enum fails when a case carries two noncopyable payloads, with "copy of
// noncopyable typed value. This is a compiler bug". The same case with one
// payload, a struct that holds both, compiles. Expected to fail:
//
//   swiftc -emit-sil -o /dev/null -swift-version 6 two_owner_case.swift

struct Owner: ~Copyable {
  let raw: Int32
  deinit {}
  func use() -> Int32 { raw }
}

struct Pair: ~Copyable {
  var first: Owner
  var second: Owner
}

enum TwoPayloads: ~Copyable {
  case pair(Owner, Owner)

  func sum() -> Int32 {
    switch self {
    case .pair(let first, let second):  // error: copy of noncopyable typed value
      return first.use() + second.use()
    }
  }
}

enum OnePayload: ~Copyable {
  case pair(Pair)

  func sum() -> Int32 {
    switch self {
    case .pair(let pair):  // compiles
      return pair.first.use() + pair.second.use()
    }
  }
}
