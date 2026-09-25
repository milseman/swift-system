// V16e: `#if` can wrap enum cases and switch cases, so an enum's cases can
// differ by platform and each platform's switches stay exhaustive. A
// platform-specific error code is matched in a `switch` inside a catch-all,
// because `#if` can't wrap catch clauses (V16e2).
// Expected: compiles with and without -D SIMULATE_PLATFORMS.
//   swiftc -swift-version 6 -typecheck V16e_if_config_cases.swift
//   swiftc -swift-version 6 -D SIMULATE_PLATFORMS -typecheck V16e_if_config_cases.swift

enum File {
  #if !os(Windows)
  case fd(Int32)
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case handle(UInt)
  #endif
}

func describe(_ file: File) -> String {
  switch file {
  #if !os(Windows)
  case .fd(let raw): return "fd \(raw)"
  #endif
  #if os(Windows) || SIMULATE_PLATFORMS
  case .handle(let raw): return "handle \(raw)"
  #endif
  }
}

struct Failure: Error, Equatable {
  var code: Int
  static var exists: Failure { Failure(code: 1) }
  static var sharingViolation: Failure { Failure(code: 2) }
}

func open() throws(Failure) { throw .exists }

func catchSwitch() {
  do { try open() }
  catch {
    switch error {
    case .exists: print("exists")
    #if os(Windows)
    case .sharingViolation: print("retry later")
    #endif
    default: print("other")
    }
  }
}
