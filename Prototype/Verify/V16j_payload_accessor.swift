// V16j: how a helper can hand out a noncopyable enum's payload without
// consuming the enum, as a one-case accessor for a platform's owner would
// (`platform library`'s helpers). In Swift 6.2:
// - A closure taking a `borrowing` payload compiles.
// - An underscored `_read` coroutine accessor that yields the payload
//   compiles, and so does using it inline.
// - A plain `get` can't return it: "'self' is borrowed and cannot be
//   consumed" (with -D GET).
// - SE-0474's `yielding borrow` spelling doesn't parse; see V16j2.
// A copyable payload, such as OwnedFD's vended FileDescriptor, needs none of
// this, which is why a Unix helper returns the descriptor and a Windows
// helper tends to return `unsafeRawHandle`.
// Expected: compiles and prints "7" twice; with -D GET, the error above.
//   swiftc -swift-version 6 V16j_payload_accessor.swift -o /tmp/V16j && /tmp/V16j
//   swiftc -swift-version 6 -D GET -emit-sil -o /dev/null V16j_payload_accessor.swift
struct Handle: ~Copyable {
  let raw: Int32
  func size() -> Int64 { Int64(raw) }
  deinit {}
}

enum File: ~Copyable {
  case fd(Int32)
  case handle(Handle)

  func withHandle<R>(_ body: (borrowing Handle) throws -> R) rethrows -> R {
    switch self {
    case .handle(let handle): return try body(handle)
    case .fd: fatalError("not a handle")
    }
  }

  var handle: Handle {
    _read {
      switch self {
      case .handle(let handle): yield handle
      case .fd: fatalError("not a handle")
      }
    }
  }

  #if GET
  var handleByGetter: Handle {
    switch self {
    case .handle(let handle): return handle
    case .fd: fatalError("not a handle")
    }
  }
  #endif
}

func sizes(_ file: borrowing File) -> (Int64, Int64) {
  (file.withHandle { $0.size() }, file.handle.size())
}

let (viaClosure, viaRead) = sizes(File.handle(Handle(raw: 7)))
print(viaClosure)
print(viaRead)
