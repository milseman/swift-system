/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// If `errorCode` is zero, returns `value` as success.
// If `errorCode` is non-zero, it is interpreted as an Errno and returned as failure.
internal func valueOrErrorCode<T>(
  _ value: T, errorCode: CInt
) -> Result<T, Errno> {
  if errorCode == 0 { return .success(value) }
  return .failure(Errno(rawValue: errorCode))
}

// Results in errno if i == -1
// @available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
internal func valueOrErrno<I: FixedWidthInteger>(
  _ i: I
) -> Result<I, Errno> {
  i == -1 ? .failure(Errno.current) : .success(i)
}

// @available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
internal func nothingOrErrno<I: FixedWidthInteger>(
  _ i: I
) -> Result<(), Errno> {
  valueOrErrno(i).map { _ in () }
}

// @available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
internal func valueOrErrno<I: FixedWidthInteger>(
  retryOnInterrupt: Bool, _ f: () -> I
) -> Result<I, Errno> {
  repeat {
    switch valueOrErrno(f()) {
    case .success(let r): return .success(r)
    case .failure(let err):
      guard retryOnInterrupt && err == .interrupted else { return .failure(err) }
      break
    }
  } while true
}

// Run a precondition for debug client builds
internal func _debugPrecondition(
  _ condition: @autoclosure () -> Bool, _ message: StaticString = StaticString(),
  file: StaticString = #file, line: UInt = #line
) {
  // Only check in debug mode.
  if _slowPath(_isDebugAssertConfiguration()) { precondition(condition()) }
}

extension OpaquePointer {
  internal var _isNULL: Bool { OpaquePointer(bitPattern: Int(bitPattern: self)) == nil }
}

extension Sequence {
  // Tries to recast contiguous pointer if available, otherwise allocates memory.
  internal func _withRawBufferPointer<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    guard let result = try self.withContiguousStorageIfAvailable({
      try body(UnsafeRawBufferPointer($0))
    }) else {
      return try Array(self).withUnsafeBytes(body)
    }
    return result
  }
}

extension OptionSet {
  // Helper method for building up a comma-separated list of options
  //
  // Taking an array of descriptions reduces code size vs
  // a series of calls due to avoiding register copies. Make sure
  // to pass an array literal and not an array built up from a series of
  // append calls, else that will massively bloat code size. This takes
  // StaticStrings because otherwise we get a warning about getting evicted
  // from the shared cache.
  @inline(never)
  internal func _buildDescription(
    _ descriptions: [(Element, StaticString)]
  ) -> String {
    var copy = self
    var result = "["

    for (option, name) in descriptions {
      if _slowPath(copy.contains(option)) {
        result += name.description
        copy.remove(option)
        if !copy.isEmpty { result += ", " }
      }
    }

    if _slowPath(!copy.isEmpty) {
      result += "\(Self.self)(rawValue: \(copy.rawValue))"
    }
    result += "]"
    return result
  }
}

extension UnsafePointer where Pointee == UInt8 {
  internal var _asCChar: UnsafePointer<CChar> {
    UnsafeRawPointer(self).assumingMemoryBound(to: CChar.self)
  }
}
extension UnsafePointer where Pointee == CChar {
  internal var _asUInt8: UnsafePointer<UInt8> {
    UnsafeRawPointer(self).assumingMemoryBound(to: UInt8.self)
  }
}
extension UnsafeBufferPointer where Element == UInt8 {
  internal var _asCChar: UnsafeBufferPointer<CChar> {
    let base = baseAddress?._asCChar
    return UnsafeBufferPointer<CChar>(start: base, count: self.count)
  }
}
extension UnsafeBufferPointer where Element == CChar {
  internal var _asUInt8: UnsafeBufferPointer<UInt8> {
    let base = baseAddress?._asUInt8
    return UnsafeBufferPointer<UInt8>(start: base, count: self.count)
  }
}

extension Array where Element == String {
  internal func _asArgList<R>(
      _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> R
  ) rethrows -> R {
      let argvlength = self.reduce(0) { $0 + $1.utf8.count + 1 }
      let argvBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: argvlength)
      defer { argvBuffer.deallocate() }
      var target = argvBuffer.baseAddress!
      var argv: [UnsafeMutablePointer<CChar>?] = []
      argv.reserveCapacity(self.count + 1)
      for var argument in self {
          argument.withUTF8 { source in
              source.withMemoryRebound(to: CChar.self) { source in
                  precondition(target + source.count <= argvBuffer.baseAddress! + argvBuffer.count)
                  target.initialize(from: source.baseAddress!, count: source.count)
                  (target + source.count).pointee = 0
                  argv.append(target)
                  target += source.count + 1
              }
          }
      }
      argv.append(nil)
      return try argv.withUnsafeBufferPointer { argv in
          return try body(argv.baseAddress!)
      }
  }
}
