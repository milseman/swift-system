/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

@frozen
public struct TimeSpec: RawRepresentable {
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.TimeSpec

  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.TimeSpec) { self.rawValue = rawValue }

  @_alwaysEmitIntoClient
  public static func seconds(_ n: Int) -> TimeSpec {
    fatalError()
  }

  @_alwaysEmitIntoClient
  public static func miliseconds(_ n: Int) -> TimeSpec {
    fatalError()
  }

  @_alwaysEmitIntoClient
  public static func nanoseconds(_ n: Int) -> TimeSpec {
    fatalError()
  }

  public var seconds: Int64 {  }

  public var nanoseconds: Int64 {  }

  public var milliseconds: Int64 { }

}


extension FileDescriptor {
  // TODO: OptionSet? Hashable? Kinda hard because opaque struct that's just
  // a bit vector

  /// A set of file descriptors, internally represented as a bit vector.
  ///
  /// The corresponding C type is `fd_set`.
  @frozen
  public struct DescriptorSet: RawRepresentable {
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.FDSet

    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.FDSet) { self.rawValue = rawValue }

    /// An empty descriptor set.
    @_alwaysEmitIntoClient
    public static var zero: DescriptorSet {
      var set = CInterop.FDSet()
      system_fd_zero(&set)
      return DescriptorSet(rawValue: set)
    }

    /// Add `fd` to the set.
    @_alwaysEmitIntoClient
    public mutating func insert(_ fd: FileDescriptor) {
      // TODO: consider a debug precondition, or an unsafe-unchecked variant
      let raw = fd.rawValue
      precondition(raw >= 0 && raw < _FD_SETSIZE)
      system_fd_insert(raw, &self.rawValue)
    }

    /// Remove `fd` from the set.
    @_alwaysEmitIntoClient
    public mutating func remove(_ fd: FileDescriptor) {
      // TODO: consider a debug precondition, or an unsafe-unchecked variant
      let raw = fd.rawValue
      precondition(raw >= 0 && raw < _FD_SETSIZE)
      system_fd_remove(raw, &self.rawValue)
    }

    /// Whether the set contains `fd`.
    @_alwaysEmitIntoClient
    public func contains(_ fd: FileDescriptor) -> Bool {
      // TODO: consider a debug precondition, or an unsafe-unchecked variant
      let raw = fd.rawValue
      precondition(raw >= 0 && raw < _FD_SETSIZE)
      return system_fd_cotains(raw, self.rawValue)
    }
  }
}

extension FileDescriptor {
  /// ...
  ///
  /// - `rawValueUpperbound` - one higher than the maximum position in a descriptor set to check
  /// - ``
  ///
  /// TODO: `rawValueUpperbound`... I'm hoping the kernel does the sane
  /// find-next-set-bit rather than literally iterate over all bits. Otherwise we may need to
  /// constrain this or else implement it ourseles on DescriptorSet.
  ///
  /// The corresponding C function is `select`.
  public static func select(
    rawValueUpperbound: Int = Int(_FD_SETSIZE),
    readDescriptors: inout DescriptorSet?,
    writeDescriptors: inout DescriptorSet?,
    errorDescriptors: inout DescriptorSet?

  ) throws -> Int {
    fatalError()
  }
}
