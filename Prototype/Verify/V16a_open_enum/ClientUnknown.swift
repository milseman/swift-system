// V16a client, written for an open enum: every switch over a non-frozen enum
// ends with `@unknown default`, including a borrowing switch over the
// library's static let (standard input) and a consuming switch.
// Expected: compiles against both /tmp/V16a/plain and /tmp/V16a/evolving with
// no warnings. `@unknown default` on the non-evolving build, where it can never
// run, draws no "default will never be executed" warning, so writing it always
// is the portable spelling.
//   swiftc -swift-version 6 -parse-as-library -emit-sil -o /dev/null -I /tmp/V16a/plain ClientUnknown.swift
//   swiftc -swift-version 6 -parse-as-library -emit-sil -o /dev/null -I /tmp/V16a/evolving ClientUnknown.swift
//
// Run it against a library that adds a case after the client was compiled:
//   cd /tmp/V16a && swiftc -swift-version 6 -emit-library -enable-library-evolution \
//     -emit-module -module-name Lib -o libLib.dylib -emit-module-path evolving/Lib.swiftmodule $OLDPWD/Lib.swift
//   swiftc -swift-version 6 -parse-as-library -I evolving -L . -lLib -Xlinker -rpath -Xlinker . \
//     -o client $OLDPWD/ClientUnknown.swift && ./client
//   swiftc -swift-version 6 -D V2 -emit-library -enable-library-evolution \
//     -module-name Lib -o libLib.dylib $OLDPWD/Lib.swift && ./client
// Expected: the first run prints "fd 5", "extracted 5", and "closed 5". After
// the library is rebuilt with -D V2, the same binary prints "unknown
// representation" for 5, then "closed 5" before "nothing extracted": the
// consuming switch's `@unknown default` destroys the new case's owner. An open
// owned enum hands old code values it can't name, and a consuming switch can
// only drop them, which for an owner means closing them.
import Lib

func name(_ n: Name) -> Int32 {
  switch n {
  case .fd(let raw): return raw
  @unknown default: return -1
  }
}

func frozen(_ n: FrozenName) -> Int32 {
  switch n {
  case .fd(let raw): return raw
  @unknown default: return -1
  }
}

func borrowed(_ file: borrowing File) -> String {
  switch file {
  case .fd(let owner): return "fd \(owner.read())"
  @unknown default: return "unknown representation"
  }
}

func standardInput() -> String {
  switch File.standardInput {
  case .fd(let owner): return "standard input is fd \(owner.read())"
  @unknown default: return "standard input has an unknown representation"
  }
}

func consumed(_ file: consuming File) -> Owner? {
  switch consume file {
  case .fd(let owner): return owner
  @unknown default: return nil  // the unknown case's owner is destroyed here
  }
}

@main struct Main {
  static func main() {
    print(standardInput())
    let file = File.open(5)
    print(borrowed(file))
    if let owner = consumed(file) {
      print("extracted \(owner.read())")
    } else {
      print("nothing extracted")
    }
  }
}
