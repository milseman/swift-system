/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// TODO: Does this pattern emerge elsewhere? Common protocol or design?
// Can't do union and intersection, only insert/delete/isMember/empty/fill

public struct Signal: RawRepresentable, Hashable {
  public var rawValue: CInt
  public init(rawValue: CInt) { self.rawValue = rawValue }

}

// Consider public `withUnsafePointer` on these kinds of types that were originally
// treated indirectly (PID.Attributes, etc., as well) for gentler System adoption.

public struct SignalSet: Hashable, Codable {
  internal var pointee: CTypes.SigSet

  internal init(pointee: CTypes.SigSet) { self.pointee = pointee }

  // Only to be used prior to producing an empty or full set
  fileprivate init(uninitialized: ()) {
    self.pointee = 0
  }
}

extension SignalSet {
  internal func withUnsafePointer<T>(
    _ f: (UnsafePointer<CTypes.SigSet>) throws -> T
  ) rethrows -> T {
    try Swift.withUnsafePointer(to: self.pointee) { try f($0) }
  }
  internal mutating func withUnsafeMutablePointer<T>(
    _ f: (UnsafeMutablePointer<CTypes.SigSet>) throws -> T
  ) rethrows -> T {
    try Swift.withUnsafeMutablePointer(to: &self.pointee) { try f($0) }
  }
}

// TODO: Set literal syntax

@_implementationOnly import SystemInternals
// TODO: all constants...
extension Signal {
  private init(_ rawValue: CInt) { self.init(rawValue: rawValue) }

  public static var kill: Signal { fatalError() }// Signal(SIGKILL) }
  public static var stop: Signal { fatalError() }// Signal(SIGSTOP) }

#if os(Linux)
  public static var unused: Singal { Signal(SIGUNUSED) }
#endif

}

extension SignalSet {
  // sigaddset
  public mutating func insert(_ sig: Signal) {
    _ = withUnsafeMutablePointer { system_sigaddset($0, sig.rawValue) }
  }
  public mutating func remove(_ sig: Signal) {
    _ = withUnsafeMutablePointer { system_sigdelset($0, sig.rawValue) }
  }

  public func contains(_ sig: Signal) -> Bool {
    1 == withUnsafePointer { system_sigismember($0, sig.rawValue) }
  }

  public static var empty: SignalSet {
    var ret = SignalSet(uninitialized: ())
    _ = ret.withUnsafeMutablePointer { system_sigemptyset($0) }
    return ret
  }

  public static var full: SignalSet {
    var ret = SignalSet(uninitialized: ())
    _ = ret.withUnsafeMutablePointer { system_sigfillset($0) }
    return ret
  }
}

extension SignalSet: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Signal...) {
    self = SignalSet.empty
    elements.forEach { self.insert($0) }
  }

  public typealias ArrayLiteralElement = Signal
}

extension SignalSet {
  // TODO: Proper name for this concept
  public static var defaultForSPM: SignalSet {
#if os(macOS)
    var ret = SignalSet.full
    ret.remove(.kill)
    ret.remove(.stop)
#else
    var ret = SignalSet.empty
    for i in 1 ..< Signal.unused.rawValue {
      let sig = Signal(rawValue: i)
      guard sig != .kill && sig != .stop else { continue }
      ret.insert(sig)
    }
#endif
    return ret
  }

}
