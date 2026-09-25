// V16i: Swift 6.2 (swiftlang-6.2.0.19.9) crashes in IRGen, in
// FixedTypeInfo::deallocateStack (signal 11), compiling a function that
// catches with a pattern, the idiom System's errors are designed for
// (`catch Errno.fileExists`, `catch Win32.Error.sharingViolation`), and then
// uses a noncopyable owner in either of two ways:
// - INTERP: a `try` on the owner inside a string interpolation. Any
//   noncopyable type, even without a deinit.
// - RETURNS_OWNER: a throwing call on an owner with a deinit, such as
//   OwnedFD or Win32.FileHandle, that returns another owner, such as
//   `duplicate()`.
// No loop or closure is involved, unlike the earlier crash with the same
// signature (a `catch Errno.x` whose body passes `closeAfter` a closure).
// `catch let error as E where error == .busy` crashes too; a catch-all
// doesn't. Workarounds: hoist the `try` out of the interpolation, or move
// the pattern catch into a helper function, as `platform windows-only` does.
// Expected: compiles without flags; each flag alone crashes the compiler.
//   swiftc -swift-version 6 -emit-ir -o /dev/null V16i_pattern_catch_irgen_crash.swift
//   swiftc -swift-version 6 -D INTERP -emit-ir -o /dev/null V16i_pattern_catch_irgen_crash.swift
//   swiftc -swift-version 6 -D RETURNS_OWNER -emit-ir -o /dev/null V16i_pattern_catch_irgen_crash.swift

struct Failure: Error, Equatable {
  var code: Int32
  static var busy: Failure { Failure(code: 32) }
  static func ~= (lhs: Failure, rhs: any Error) -> Bool { (rhs as? Failure) == lhs }
  static func check() throws(Failure) {}
}

struct Owner: ~Copyable {
  let raw: Int32
  func size() throws(Failure) -> Int64 { 0 }
  borrowing func duplicate() throws(Failure) -> Owner { Owner(raw: raw) }
  consuming func close() throws(Failure) { discard self }
  deinit {}
}

func interpolate() throws {
  let owner = Owner(raw: 3)
  do { try Failure.check() } catch Failure.busy { print("busy") }
  #if INTERP
  print("size \(try owner.size())")
  #else
  let size = try owner.size()
  print("size \(size)")
  #endif
  try owner.close()
}

func returnsOwner() throws {
  let owner = Owner(raw: 3)
  do { try Failure.check() } catch Failure.busy { print("busy") }
  #if RETURNS_OWNER
  let copy = try owner.duplicate()
  try copy.close()
  #endif
  try owner.close()
}
