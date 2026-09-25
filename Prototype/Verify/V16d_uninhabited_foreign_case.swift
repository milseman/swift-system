// V16d: a switch may omit a case whose payload is uninhabited. So an enum
// could declare every platform's case on every platform, with the foreign
// platforms' payload types declared as caseless enums, and single-platform
// switches would still list only their own case. It doesn't remove `#if`
// from cross-platform code: an arm that uses a foreign payload needs that
// type's API, which a caseless stand-in doesn't have (`useForeign`).
// Expected: compiles, except `useForeign` with -D USE_FOREIGN: "value of type
// 'Win32.FileHandle' has no member 'setInheritable'".
//   swiftc -swift-version 6 -typecheck V16d_uninhabited_foreign_case.swift
//   swiftc -swift-version 6 -D USE_FOREIGN -typecheck V16d_uninhabited_foreign_case.swift

/// On a Unix build, Windows' handle type would exist only as a name.
enum Win32 {
  enum FileHandle {}
}

enum File {
  case fd(Int32)
  case handle(Win32.FileHandle)
}

/// Unix code lists only its own case: `.handle` can't hold a value.
func unixOnly(_ file: File) -> Int32 {
  switch file {
  case .fd(let raw): return raw
  }
}

#if USE_FOREIGN
/// Cross-platform code still can't use the foreign payload.
func useForeign(_ file: File) {
  switch file {
  case .fd: break
  case .handle(let handle): handle.setInheritable(false)
  }
}
#endif
