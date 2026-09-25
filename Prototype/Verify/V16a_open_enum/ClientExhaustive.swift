// V16a client, written as code built against SwiftPM's SystemPackage would be:
// switches list every case and have no `@unknown default`.
// Expected: compiles against /tmp/V16a/plain. Against /tmp/V16a/evolving, in the
// Swift 6 language mode, three errors (a warning in Swift 5 mode):
// "switch covers known cases, but 'Name' may have additional unknown values"
// (and the same for 'File', twice). `FrozenName` is fine either way. So "open"
// exists only in the library-evolution build: code that compiles warning-free
// against the package fails to compile against the SDK's module.
//   swiftc -swift-version 6 -emit-sil -o /dev/null -I /tmp/V16a/plain ClientExhaustive.swift
//   swiftc -swift-version 6 -emit-sil -o /dev/null -I /tmp/V16a/evolving ClientExhaustive.swift
import Lib

func name(_ n: Name) -> Int32 {
  switch n {
  case .fd(let raw): return raw
  }
}

func frozen(_ n: FrozenName) -> Int32 {
  switch n {
  case .fd(let raw): return raw
  }
}

func borrowed(_ file: borrowing File) -> Int32 {
  switch file {
  case .fd(let owner): return owner.read()
  }
}

func consumed(_ file: consuming File) -> Owner {
  switch consume file {
  case .fd(let owner): return owner
  }
}
