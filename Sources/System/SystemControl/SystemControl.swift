/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Reading and changing the kernel's state variables: sysctl, sysctlbyname,
// and sysctlnametomib.
//
// A variable's name carries the type of its value, so a read allocates the
// right buffer and checks the size that the kernel returns: reading a C int
// into a 64-bit integer throws, rather than leaving half of it unset.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

/// A namespace for reading and changing the kernel's state variables.
///
/// Each variable has a ``Name``, which also gives the type of its value,
/// and the common ones have names of their own:
///
///     let processors = try SystemControl.value(.logicalProcessorCount)  // Int32
///     let version = try SystemControl.value(.osVersion)                 // String
///
/// To read another variable, name it along with its value's type:
///
///     let wired = SystemControl.Name<UInt64>("vm.page_pageable_internal_count")
///     let count = try SystemControl.value(wired)
///
/// The corresponding C functions are `sysctlbyname` and `sysctl`.
/// - Note: Only available on Darwin.
@available(System 199, *)
public enum SystemControl {}

// MARK: - Names

@available(System 199, *)
extension SystemControl {
  /// The name of a kernel state variable, and the type of its value.
  ///
  /// A name is either a string, such as `hw.ncpu`,
  /// or an identifier: the sequence of integers that the system resolves
  /// the string to, which C calls a management information base (MIB).
  /// Reading a variable by identifier is faster than by string,
  /// and some variables, such as a process's information,
  /// only have identifiers.
  ///
  /// `Value` is the type of the variable's value:
  /// an integer or C structure of the value's exact size,
  /// such as `Int32` for a C `int`;
  /// `String` for a string;
  /// or an array for a variable that holds a list of values,
  /// such as `[UInt8]` for bytes.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public struct Name<Value>: Hashable, Sendable {
    // Exactly one of these is non-nil.
    @usableFromInline
    internal var _string: String?

    @usableFromInline
    internal var _identifier: [CInt]?

    /// Creates a name from its string form, such as `hw.ncpu`.
    ///
    /// The corresponding C function is `sysctlbyname`,
    /// which reads and writes a variable by string.
    @_alwaysEmitIntoClient
    public init(_ name: String) {
      self._string = name
      self._identifier = nil
    }

    /// Creates a name from its identifier.
    ///
    /// The corresponding C function is `sysctl`,
    /// which reads and writes a variable by identifier.
    @_alwaysEmitIntoClient
    public init(identifier: [CInt]) {
      self._string = nil
      self._identifier = identifier
    }

    /// Creates a name from the identifier that the system resolves
    /// a string to.
    ///
    /// - Parameter name: The string form of the name, such as `hw.ncpu`.
    ///
    /// A name with an identifier is faster to read,
    /// which suits a variable that's read often.
    /// If the system has no variable of that name,
    /// this initializer throws ``Errno/noSuchFileOrDirectory``.
    ///
    /// The corresponding C function is `sysctlnametomib`.
    @_alwaysEmitIntoClient
    public init(resolving name: String) throws(Errno) {
      self.init(identifier: try SystemControl._identifier(resolving: name).get())
    }

    /// The name's string form,
    /// or `nil` if the name was created from an identifier.
    @_alwaysEmitIntoClient
    public var string: String? { _string }

    /// The name's identifier,
    /// or `nil` if the name was created from a string.
    @_alwaysEmitIntoClient
    public var identifier: [CInt]? { _identifier }
  }

  @usableFromInline
  internal static func _identifier(resolving name: String) -> Result<[CInt], Errno> {
    var identifier = [CInt](repeating: 0, count: _CTL_MAXNAME)
    var count = identifier.count
    let result = identifier.withUnsafeMutableBufferPointer { identifier in
      name.withCString { system_sysctlnametomib($0, identifier.baseAddress!, &count) }
    }
    guard result == 0 else { return .failure(.current) }
    return .success(Array(identifier[..<count]))
  }
}

@available(System 199, *)
extension SystemControl.Name: CustomStringConvertible, CustomDebugStringConvertible {
  /// The name's string form, or its identifier's integers.
  public var description: String {
    _string ?? "\(_identifier ?? [])"
  }

  /// A textual representation of the name, suitable for debugging.
  public var debugDescription: String { "SystemControl.Name(\(description))" }
}

// MARK: - Reading

@available(System 199, *)
extension SystemControl {
  /// Returns the value of a kernel state variable
  /// that holds a single value of a fixed size.
  ///
  /// - Parameter name: The variable, whose value is a `Value`.
  /// - Returns: The variable's value.
  ///
  /// If the system has no such variable,
  /// this method throws ``Errno/noSuchFileOrDirectory``.
  /// If the variable's value is larger than a `Value`,
  /// it throws ``Errno/noMemory``,
  /// except that the kernel narrows a 64-bit integer
  /// to a 32-bit `Value` that can hold it,
  /// and throws ``Errno/outOfRange`` for one that can't.
  /// If the value is smaller than a `Value`,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value<Value: BitwiseCopyable>(
    _ name: Name<Value>
  ) throws(Errno) -> Value {
    try _fixedValue(name).get()
  }

  /// Returns the value of a kernel state variable that holds a string.
  ///
  /// - Parameter name: The variable, whose value is a string.
  /// - Returns: The variable's value, without its null terminator.
  ///
  /// Bytes that aren't valid UTF-8 are repaired,
  /// as `String(decoding:as:)` does.
  /// If the system has no such variable,
  /// this method throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value(_ name: Name<String>) throws(Errno) -> String {
    try _stringValue(name).get()
  }

  /// Returns the values of a kernel state variable
  /// that holds a list of values.
  ///
  /// - Parameter name: The variable, whose value is a list of `Element`.
  /// - Returns: The variable's values.
  ///
  /// The number of values can change from one read to the next,
  /// as a variable that lists processes can;
  /// this method grows its buffer until the values fit.
  /// If the system has no such variable,
  /// this method throws ``Errno/noSuchFileOrDirectory``.
  /// If the variable's size isn't a multiple of an `Element`'s,
  /// it throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value<Element: BitwiseCopyable>(
    _ name: Name<[Element]>
  ) throws(Errno) -> [Element] {
    try _arrayValue(name).get()
  }

  /// Returns a process's information from the kernel.
  ///
  /// - Parameter name: The variable, such as
  ///   ``Name/process(_:)``, whose value is a `kinfo_proc`.
  /// - Returns: The variable's value.
  ///
  /// This method exists because the C `kinfo_proc` structure,
  /// which holds a union of pointers,
  /// doesn't conform to `BitwiseCopyable`.
  ///
  /// The corresponding C function is `sysctl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value(_ name: Name<kinfo_proc>) throws(Errno) -> kinfo_proc {
    try _fixedValue(name).get()
  }

  /// Returns information about a list of processes from the kernel.
  ///
  /// - Parameter name: The variable, such as ``Name/allProcesses``,
  ///   whose value is a list of `kinfo_proc`.
  /// - Returns: The variable's values.
  ///
  /// The number of processes can change from one read to the next;
  /// this method grows its buffer until they fit.
  ///
  /// The corresponding C function is `sysctl`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value(_ name: Name<[kinfo_proc]>) throws(Errno) -> [kinfo_proc] {
    try _arrayValue(name).get()
  }

  /// Returns the size in bytes of a kernel state variable's value.
  ///
  /// - Parameter name: The variable.
  /// - Returns: The number of bytes in the variable's value.
  ///
  /// For a variable whose size changes often, such as a list of processes,
  /// the system can round the size up,
  /// so that it's large enough to read the value soon after.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier,
  /// with no buffer for the value.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func valueSize<Value>(_ name: Name<Value>) throws(Errno) -> Int {
    try _valueSize(name).get()
  }

  /// Reads a kernel state variable's value into a buffer.
  ///
  /// - Parameters:
  ///   - name: The variable.
  ///   - buffer: The buffer to read the value into.
  /// - Returns: The number of bytes read into the buffer.
  ///
  /// This method ignores the name's `Value` type;
  /// the value's bytes are read as they are.
  /// If the value doesn't fit in the buffer,
  /// this method throws ``Errno/noMemory``,
  /// except that the kernel narrows a 64-bit integer
  /// to a 4-byte buffer if the value fits in 32 bits,
  /// and throws ``Errno/outOfRange`` if it doesn't.
  /// To size the buffer, call ``valueSize(_:)``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func value<Value>(
    _ name: Name<Value>, into buffer: UnsafeMutableRawBufferPointer
  ) throws(Errno) -> Int {
    try _value(name, into: buffer).get()
  }

  @usableFromInline
  internal static func _valueSize<Value>(_ name: Name<Value>) -> Result<Int, Errno> {
    var length = 0
    guard name._control(nil, &length, nil, 0) == 0 else { return .failure(.current) }
    return .success(length)
  }

  @usableFromInline
  internal static func _value<Value>(
    _ name: Name<Value>, into buffer: UnsafeMutableRawBufferPointer
  ) -> Result<Int, Errno> {
    var length = buffer.count
    guard name._control(buffer.baseAddress, &length, nil, 0) == 0 else {
      return .failure(.current)
    }
    return .success(length)
  }

  // `Value` must be trivial, which the public API checks by requiring
  // BitwiseCopyable, except for kinfo_proc, which is trivial without it.
  @usableFromInline
  internal static func _fixedValue<Value>(_ name: Name<Value>) -> Result<Value, Errno> {
    let size = MemoryLayout<Value>.size
    return withUnsafeTemporaryAllocation(
      byteCount: Swift.max(size, 1), alignment: MemoryLayout<Value>.alignment
    ) { buffer in
      var length = size
      guard name._control(buffer.baseAddress, &length, nil, 0) == 0 else {
        return .failure(.current)
      }
      guard length == size else { return .failure(.invalidArgument) }
      return .success(buffer.baseAddress!.load(as: Value.self))
    }
  }

  @usableFromInline
  internal static func _stringValue(_ name: Name<String>) -> Result<String, Errno> {
    _bytes(name, stride: 1).map { bytes in
      let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
      return String(decoding: bytes[..<end], as: UTF8.self)
    }
  }

  // `Element` must be trivial, as for `_fixedValue`.
  @usableFromInline
  internal static func _arrayValue<Element>(
    _ name: Name<[Element]>
  ) -> Result<[Element], Errno> {
    let stride = MemoryLayout<Element>.stride
    return _bytes(name, stride: stride).map { bytes in
      bytes.withUnsafeBytes { bytes in
        Array(unsafeUninitializedCapacity: bytes.count / stride) { buffer, count in
          UnsafeMutableRawBufferPointer(buffer).copyMemory(from: bytes)
          count = bytes.count / stride
        }
      }
    }
  }

  // Reads a value whose size can change, growing the buffer until it fits.
  // Fails with EINVAL if the size isn't a multiple of `stride`.
  private static func _bytes<Value>(
    _ name: Name<Value>, stride: Int
  ) -> Result<[UInt8], Errno> {
    while true {
      var length = 0
      guard name._control(nil, &length, nil, 0) == 0 else { return .failure(.current) }
      var bytes = [UInt8](repeating: 0, count: Swift.max(length, 1))
      length = bytes.count
      let result = bytes.withUnsafeMutableBytes { buffer in
        name._control(buffer.baseAddress, &length, nil, 0)
      }
      if result != 0 {
        let error = Errno.current
        // The value grew since its size was read.
        if error == .noMemory { continue }
        return .failure(error)
      }
      guard length % stride == 0 else { return .failure(.invalidArgument) }
      bytes.removeLast(bytes.count - length)
      return .success(bytes)
    }
  }
}

// MARK: - Writing

@available(System 199, *)
extension SystemControl {
  /// Sets the value of a kernel state variable
  /// that holds a single value of a fixed size.
  ///
  /// - Parameters:
  ///   - newValue: The variable's new value.
  ///   - name: The variable, whose value is a `Value`.
  ///
  /// Most variables can't be changed,
  /// and most of those that can require privileges;
  /// otherwise, this method throws an error such as ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func setValue<Value: BitwiseCopyable>(
    _ newValue: Value, for name: Name<Value>
  ) throws(Errno) {
    try withUnsafeBytes(of: newValue) { _setValue(from: $0, for: name) }.get()
  }

  /// Sets the value of a kernel state variable that holds a string.
  ///
  /// - Parameters:
  ///   - newValue: The variable's new value.
  ///   - name: The variable, whose value is a string.
  ///
  /// Most variables can't be changed,
  /// and most of those that can require privileges;
  /// otherwise, this method throws an error such as ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func setValue(_ newValue: String, for name: Name<String>) throws(Errno) {
    var newValue = newValue
    try newValue.withUTF8 { _setValue(from: UnsafeRawBufferPointer($0), for: name) }.get()
  }

  /// Sets the values of a kernel state variable that holds a list of values.
  ///
  /// - Parameters:
  ///   - newValue: The variable's new values.
  ///   - name: The variable, whose value is a list of `Element`.
  ///
  /// Most variables can't be changed,
  /// and most of those that can require privileges;
  /// otherwise, this method throws an error such as ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func setValue<Element: BitwiseCopyable>(
    _ newValue: [Element], for name: Name<[Element]>
  ) throws(Errno) {
    try newValue.withUnsafeBytes { _setValue(from: $0, for: name) }.get()
  }

  /// Sets a kernel state variable's value from a buffer.
  ///
  /// - Parameters:
  ///   - buffer: The bytes of the variable's new value.
  ///   - name: The variable.
  ///
  /// This method ignores the name's `Value` type;
  /// the buffer's bytes are written as they are.
  /// Most variables can't be changed,
  /// and most of those that can require privileges;
  /// otherwise, this method throws an error such as ``Errno/notPermitted``.
  ///
  /// The corresponding C function is `sysctlbyname`,
  /// or `sysctl` for a name with an identifier.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func setValue<Value>(
    from buffer: UnsafeRawBufferPointer, for name: Name<Value>
  ) throws(Errno) {
    try _setValue(from: buffer, for: name).get()
  }

  @usableFromInline
  internal static func _setValue<Value>(
    from buffer: UnsafeRawBufferPointer, for name: Name<Value>
  ) -> Result<(), Errno> {
    // The kernel reads a new value of any size from a non-null pointer.
    var empty: UInt8 = 0
    return withUnsafeMutablePointer(to: &empty) { empty in
      name._control(nil, nil, buffer.baseAddress ?? UnsafeRawPointer(empty), buffer.count) == 0
        ? .success(()) : .failure(.current)
    }
  }
}

// MARK: - Calling sysctl

@available(System 199, *)
extension SystemControl.Name {
  // Calls sysctl for a name with an identifier, and sysctlbyname otherwise.
  internal func _control(
    _ old: UnsafeMutableRawPointer?,
    _ oldLength: UnsafeMutablePointer<Int>?,
    _ new: UnsafeRawPointer?,
    _ newLength: Int
  ) -> CInt {
    let new = UnsafeMutableRawPointer(mutating: new)
    guard var identifier = _identifier else {
      return _string!.withCString {
        system_sysctlbyname($0, old, oldLength, new, newLength)
      }
    }
    guard !identifier.isEmpty else {
      system_errno = _EINVAL
      return -1
    }
    return identifier.withUnsafeMutableBufferPointer {
      system_sysctl($0.baseAddress!, CUnsignedInt($0.count), old, oldLength, new, newLength)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
