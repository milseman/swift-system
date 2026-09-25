// V16g: a borrowed multi-platform enum, a ~Escapable enum whose cases are
// borrowed views of the owned cases, in Swift 6.2.
// - Declaring it needs no experimental feature, but nothing can produce one
//   without `Lifetimes`. The view's implicit initializer fails with "an
//   implicit initializer cannot return a ~Escapable result"; with -D VENDING
//   and no feature, the errors are "'@_lifetime' attribute is only valid when
//   experimental feature Lifetimes is enabled", "an initializer cannot return
//   a ~Escapable result", and "a method cannot return a ~Escapable result".
// - With `Lifetimes` (-D VENDING), the owned enum vends it from a
//   `@_lifetime(borrow self)` getter, and temporaries work. But a `let` owner
//   can't be closed after it has been borrowed: "noncopyable 'file' cannot be
//   consumed when captured by an escaping closure or borrowed by a
//   non-Escapable type", the V6b error. A `var` owner compiles, with the
//   warning "variable 'file' was never mutated; consider changing to 'let'
//   constant" whose fix-it produces the error.
// - A ~Escapable enum over escapable payloads (-D ESCAPABLE_PAYLOAD) protects
//   nothing: `case .fd(let fd)` binds a copy that escapes. Expected: compiles.
//   swiftc -swift-version 6 -emit-sil -o /dev/null V16g_nonescapable_enum.swift
//   swiftc -swift-version 6 -D VENDING -emit-sil -o /dev/null V16g_nonescapable_enum.swift
//   swiftc -swift-version 6 -D VENDING -enable-experimental-feature Lifetimes -emit-sil -o /dev/null V16g_nonescapable_enum.swift
//   swiftc -swift-version 6 -D ESCAPABLE_PAYLOAD -emit-sil -o /dev/null V16g_nonescapable_enum.swift

struct Owner: ~Copyable {
  let raw: Int32
  deinit {}
  consuming func close() { discard self }
}

#if !ESCAPABLE_PAYLOAD
/// A borrowed view of an owner, as BorrowedFD or a borrowed Win32 handle would be.
struct View: ~Escapable {
  let raw: Int32
  #if VENDING
  @_lifetime(borrow owner)
  init(_ owner: borrowing Owner) { raw = owner.raw }
  #endif
}

/// The borrowed platform enum: each case is a view.
enum BorrowedFile: ~Escapable {
  case fd(View)
  case handle(View)
}

enum File: ~Copyable {
  case fd(Owner)
  case handle(Owner)

  #if VENDING
  var borrowed: BorrowedFile {
    @_lifetime(borrow self)
    get {
      switch self {
      case .fd(let owner): return .fd(View(owner))
      case .handle(let owner): return .handle(View(owner))
      }
    }
  }
  #endif

  consuming func close() {
    switch consume self {
    case .fd(let owner): owner.close()
    case .handle(let owner): owner.close()
    }
  }
}

func read(_ file: BorrowedFile) -> Int32 {
  switch file {
  case .fd(let view): return view.raw
  case .handle(let view): return view.raw
  }
}

#if VENDING
func temporary() -> Int32 {
  let file = File.fd(Owner(raw: 3))
  return read(file.borrowed)
}

func closeLetAfterBorrow() {
  let file = File.fd(Owner(raw: 3))
  _ = read(file.borrowed)
  file.close()
}

func closeVarAfterBorrow() {
  var file = File.fd(Owner(raw: 3))
  _ = read(file.borrowed)
  file.close()
}
#endif
#else
/// A ~Escapable enum over raw names: its payloads can be copied out.
enum BorrowedName: ~Escapable {
  case fd(Int32)
  case handle(UInt)
}

func escape(_ name: BorrowedName) -> Int32 {
  switch name {
  case .fd(let raw): return raw   // an escapable copy leaves the enum
  case .handle: return -1
  }
}
#endif
