/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

#if SYSTEM_PACKAGE_DARWIN

// Must import here to use the C types in @_alwaysEmitIntoClient APIs.
import Darwin

@available(System 199, *)
extension CInterop {
  /// The C `fstore_t` type, which describes a request to preallocate storage.
  public typealias FStore = fstore_t

  /// The C `fpunchhole_t` type, which describes a range to deallocate.
  public typealias FPunchhole = fpunchhole_t

  /// The C `radvisory` type, which describes a range to read ahead.
  public typealias RAdvisory = radvisory

  /// The C `log2phys` type, which describes where file data is on a device.
  public typealias Log2Phys = log2phys
}

@available(System 199, *)
extension FileDescriptor {
  /// A namespace for the types of the arguments to some `fcntl` commands.
  ///
  /// Pass these to the `control` methods of ``FileDescriptor``
  /// with the matching ``FileDescriptor/Command``.
  ///
  /// - Note: Only available on Darwin.
  @frozen
  public enum ControlTypes {}
}

// MARK: - Store

@available(System 199, *)
extension FileDescriptor.ControlTypes {
  /// A request to preallocate storage for a file.
  ///
  /// Pass this to the ``FileDescriptor/Command/preallocate`` command.
  /// The command reports how much storage it allocated
  /// in ``bytesAllocated``.
  ///
  /// The corresponding C type is `fstore_t`.
  @frozen
  public struct Store: RawRepresentable, Sendable {
    /// The raw C request.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.FStore

    /// Creates a strongly-typed request from a raw C request.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.FStore) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.ControlTypes.Store {
  /// Options for preallocating storage.
  @frozen
  public struct Flags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed flags value from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Indicates that the storage must be contiguous.
    ///
    /// The file system can ignore this option
    /// for a request that's very large.
    ///
    /// The corresponding C constant is `F_ALLOCATECONTIG`.
    @_alwaysEmitIntoClient
    public static var contiguous: Flags { Flags(rawValue: _F_ALLOCATECONTIG) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "contiguous")
    public static var F_ALLOCATECONTIG: Flags { contiguous }

    /// Indicates that the request allocates all of the storage or none of it.
    ///
    /// The corresponding C constant is `F_ALLOCATEALL`.
    @_alwaysEmitIntoClient
    public static var allOrNone: Flags { Flags(rawValue: _F_ALLOCATEALL) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "allOrNone")
    public static var F_ALLOCATEALL: Flags { allOrNone }

    /// Indicates that closing the file doesn't free the storage.
    ///
    /// The file system can ignore this option.
    ///
    /// The corresponding C constant is `F_ALLOCATEPERSIST`.
    @_alwaysEmitIntoClient
    public static var persistent: Flags { Flags(rawValue: _F_ALLOCATEPERSIST) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "persistent")
    public static var F_ALLOCATEPERSIST: Flags { persistent }
  }

  /// The position that a preallocation request's offset is relative to.
  @frozen
  public struct PositionMode: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C position mode.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed position mode from a raw C position mode.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Indicates that the storage is allocated
    /// after the storage the file already has,
    /// and the request's length is the number of bytes to add.
    /// The request's offset must be zero.
    ///
    /// The corresponding C constant is `F_PEOFPOSMODE`.
    @_alwaysEmitIntoClient
    public static var physicalEndOfFile: PositionMode {
      PositionMode(rawValue: _F_PEOFPOSMODE)
    }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "physicalEndOfFile")
    public static var F_PEOFPOSMODE: PositionMode { physicalEndOfFile }

    /// Indicates that the request's offset is a position on the volume.
    ///
    /// The corresponding C constant is `F_VOLPOSMODE`.
    @_alwaysEmitIntoClient
    public static var volume: PositionMode { PositionMode(rawValue: _F_VOLPOSMODE) }

    @_alwaysEmitIntoClient
    @available(*, unavailable, renamed: "volume")
    public static var F_VOLPOSMODE: PositionMode { volume }
  }

  /// Creates a request to preallocate storage.
  ///
  /// - Parameters:
  ///   - positionMode: The position that `offset` is relative to.
  ///   - offset: The start of the range to allocate.
  ///     The default is `0`.
  ///   - length: The number of bytes to allocate.
  ///   - flags: Options for the request.
  ///     The default is none.
  @_alwaysEmitIntoClient
  public init(
    positionMode: PositionMode,
    offset: Int64 = 0,
    length: Int64,
    flags: Flags = []
  ) {
    self.init(rawValue: CInterop.FStore())
    self.positionMode = positionMode
    self.offset = offset
    self.length = length
    self.flags = flags
  }

  /// Options for the request.
  ///
  /// The corresponding C field is `fst_flags`.
  @_alwaysEmitIntoClient
  public var flags: Flags {
    get { Flags(rawValue: rawValue.fst_flags) }
    set { rawValue.fst_flags = newValue.rawValue }
  }

  /// The position that ``offset`` is relative to.
  ///
  /// The corresponding C field is `fst_posmode`.
  @_alwaysEmitIntoClient
  public var positionMode: PositionMode {
    get { PositionMode(rawValue: rawValue.fst_posmode) }
    set { rawValue.fst_posmode = newValue.rawValue }
  }

  /// The start of the range to allocate.
  ///
  /// The corresponding C field is `fst_offset`.
  @_alwaysEmitIntoClient
  public var offset: Int64 {
    get { Int64(rawValue.fst_offset) }
    set { rawValue.fst_offset = .init(newValue) }
  }

  /// The number of bytes to allocate.
  ///
  /// The corresponding C field is `fst_length`.
  @_alwaysEmitIntoClient
  public var length: Int64 {
    get { Int64(rawValue.fst_length) }
    set { rawValue.fst_length = .init(newValue) }
  }

  /// The number of bytes that the command allocated.
  ///
  /// The corresponding C field is `fst_bytesalloc`.
  @_alwaysEmitIntoClient
  public var bytesAllocated: Int64 { Int64(rawValue.fst_bytesalloc) }
}

// MARK: - PunchHole

@available(System 199, *)
extension FileDescriptor.ControlTypes {
  /// A range of a file to deallocate.
  ///
  /// Pass this to the ``FileDescriptor/Command/punchHole`` command.
  /// Afterward, the range reads as zeros.
  /// Both the offset and the length must be multiples
  /// of the file system's block size.
  ///
  /// The corresponding C type is `fpunchhole_t`.
  @frozen
  public struct PunchHole: RawRepresentable, Sendable {
    /// The raw C range.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.FPunchhole

    /// Creates a strongly-typed range from a raw C range.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.FPunchhole) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.ControlTypes.PunchHole {
  /// Creates a range to deallocate.
  ///
  /// - Parameters:
  ///   - offset: The start of the range.
  ///   - length: The number of bytes in the range.
  @_alwaysEmitIntoClient
  public init(offset: Int64, length: Int64) {
    self.init(rawValue: CInterop.FPunchhole())
    self.offset = offset
    self.length = length
  }

  // The flags and reserved fields are unused, and must be zero.

  /// The start of the range.
  ///
  /// The corresponding C field is `fp_offset`.
  @_alwaysEmitIntoClient
  public var offset: Int64 {
    get { Int64(rawValue.fp_offset) }
    set { rawValue.fp_offset = .init(newValue) }
  }

  /// The number of bytes in the range.
  ///
  /// The corresponding C field is `fp_length`.
  @_alwaysEmitIntoClient
  public var length: Int64 {
    get { Int64(rawValue.fp_length) }
    set { rawValue.fp_length = .init(newValue) }
  }
}

// MARK: - ReadAdvisory

@available(System 199, *)
extension FileDescriptor.ControlTypes {
  /// A range of a file to read into the cache ahead of time.
  ///
  /// Pass this to the ``FileDescriptor/Command/readAdvise`` command.
  ///
  /// The corresponding C type is `struct radvisory`.
  @frozen
  public struct ReadAdvisory: RawRepresentable, Sendable {
    /// The raw C range.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.RAdvisory

    /// Creates a strongly-typed range from a raw C range.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.RAdvisory) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.ControlTypes.ReadAdvisory {
  /// Creates a range to read ahead.
  ///
  /// - Parameters:
  ///   - offset: The start of the range.
  ///   - count: The number of bytes in the range.
  @_alwaysEmitIntoClient
  public init(offset: Int64, count: Int) {
    self.init(rawValue: CInterop.RAdvisory())
    self.offset = offset
    self.count = count
  }

  /// The start of the range.
  ///
  /// The corresponding C field is `ra_offset`.
  @_alwaysEmitIntoClient
  public var offset: Int64 {
    get { Int64(rawValue.ra_offset) }
    set { rawValue.ra_offset = .init(newValue) }
  }

  /// The number of bytes in the range.
  ///
  /// The corresponding C field is `ra_count`.
  @_alwaysEmitIntoClient
  public var count: Int {
    get { Int(rawValue.ra_count) }
    set { rawValue.ra_count = CInt(newValue) }
  }
}

// MARK: - LogicalToPhysical

@available(System 199, *)
extension FileDescriptor.ControlTypes {
  /// The location of file data on a storage device.
  ///
  /// Pass this to the ``FileDescriptor/Command/logicalToPhysical`` command,
  /// which reports where the file's current offset is on the device,
  /// or to ``FileDescriptor/Command/logicalToPhysicalExtended``,
  /// which reports where a given range of the file is.
  /// The device offset is `-1` if no storage backs that part of the file.
  ///
  /// The corresponding C type is `struct log2phys`.
  @frozen
  public struct LogicalToPhysical: RawRepresentable, Sendable {
    /// The raw C location.
    @_alwaysEmitIntoClient
    public var rawValue: CInterop.Log2Phys

    /// Creates a strongly-typed location from a raw C location.
    @_alwaysEmitIntoClient
    public init(rawValue: CInterop.Log2Phys) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension FileDescriptor.ControlTypes.LogicalToPhysical {
  /// Creates a location.
  ///
  /// - Parameters:
  ///   - contiguousBytes: For ``FileDescriptor/Command/logicalToPhysicalExtended``,
  ///     the number of bytes to look up.
  ///     The default is `0`.
  ///   - deviceOffset: For ``FileDescriptor/Command/logicalToPhysicalExtended``,
  ///     the offset in the file to look up.
  ///     The default is `0`.
  ///
  /// ``FileDescriptor/Command/logicalToPhysical`` ignores both values.
  @_alwaysEmitIntoClient
  public init(contiguousBytes: Int64 = 0, deviceOffset: Int64 = 0) {
    self.init(rawValue: CInterop.Log2Phys())
    self.contiguousBytes = contiguousBytes
    self.deviceOffset = deviceOffset
  }

  // The flags field is unused, and must be zero.

  /// The number of contiguous bytes at the location.
  ///
  /// For ``FileDescriptor/Command/logicalToPhysicalExtended``,
  /// set this to the number of bytes to look up;
  /// the command replaces it with the number of bytes that are contiguous
  /// on the device.
  ///
  /// The corresponding C field is `l2p_contigbytes`.
  @_alwaysEmitIntoClient
  public var contiguousBytes: Int64 {
    get { Int64(rawValue.l2p_contigbytes) }
    set { rawValue.l2p_contigbytes = .init(newValue) }
  }

  /// The offset on the device, in bytes.
  ///
  /// For ``FileDescriptor/Command/logicalToPhysicalExtended``,
  /// set this to the offset in the file to look up;
  /// the command replaces it with the offset on the device.
  ///
  /// The corresponding C field is `l2p_devoffset`.
  @_alwaysEmitIntoClient
  public var deviceOffset: Int64 {
    get { Int64(rawValue.l2p_devoffset) }
    set { rawValue.l2p_devoffset = .init(newValue) }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
