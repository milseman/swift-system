/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Accessors for the C structures that SystemPackage vends, so that a client
// that doesn't import the C library can read and build them: under
// MemberImportVisibility, a C structure's own fields and initializers need
// the module that declares them, while these are System's.
//
// Their names are Swift names, never the C fields', so that a file that
// imports both System and the C library sees no ambiguity. An initializer
// whose parameters all have defaults is also the structure's zero value:
// where the C library is imported, `T()` still picks C's zero initializer,
// which is the same value. SystemSockets has the socket structures'.

#if !os(Windows)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - timespec

@available(System 199, *)
extension CInterop {
  /// A time, in seconds and nanoseconds.
  ///
  /// The corresponding C type is `struct timespec`.
  public typealias TimeSpec = timespec
}

@available(System 199, *)
extension CInterop.TimeSpec {
  /// Creates a time from whole seconds and nanoseconds,
  /// by default zero.
  ///
  /// The corresponding C fields are `tv_sec` and `tv_nsec`.
  @_alwaysEmitIntoClient
  public init(seconds: Int = 0, nanoseconds: Int = 0) {
    self.init(tv_sec: .init(seconds), tv_nsec: .init(nanoseconds))
  }

  /// The whole seconds.
  ///
  /// The corresponding C field is `tv_sec`.
  @_alwaysEmitIntoClient
  public var seconds: Int {
    get { Int(tv_sec) }
    set { tv_sec = .init(newValue) }
  }

  /// The nanoseconds past the whole seconds, from 0 through 999,999,999
  /// in a normalized time.
  ///
  /// The corresponding C field is `tv_nsec`.
  @_alwaysEmitIntoClient
  public var nanoseconds: Int {
    get { Int(tv_nsec) }
    set { tv_nsec = .init(newValue) }
  }
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension CInterop.TimeSpec {
  /// Creates a normalized time from a duration, rounded down to a
  /// nanosecond, so that its nanoseconds are from 0 through 999,999,999
  /// even for a negative duration.
  ///
  /// The C library's own `timespec(_:)` gives a negative duration negative
  /// nanoseconds; this initializer has a label so as not to be confused
  /// with it.
  @_alwaysEmitIntoClient
  public init(duration: Duration) {
    var (seconds, attoseconds) = duration.components
    if attoseconds < 0 {
      seconds -= 1
      attoseconds += 1_000_000_000_000_000_000
    }
    self.init(seconds: Int(seconds), nanoseconds: Int(attoseconds / 1_000_000_000))
  }

  /// The time as a duration.
  @_alwaysEmitIntoClient
  public var duration: Duration {
    get { .seconds(seconds) + .nanoseconds(nanoseconds) }
    set { self = CInterop.TimeSpec(duration: newValue) }
  }
}

// MARK: - iovec

#if !os(WASI)
@available(System 199, *)
extension CInterop.IOVec {
  /// Creates a vector for a buffer, from its start and its length in bytes,
  /// by default an empty one.
  ///
  /// The corresponding C fields are `iov_base` and `iov_len`.
  @_alwaysEmitIntoClient
  public init(base: UnsafeMutableRawPointer? = nil, length: Int = 0) {
    self.init(iov_base: base, iov_len: length)
  }

  /// Creates a vector for a buffer.
  @_alwaysEmitIntoClient
  public init(_ buffer: UnsafeMutableRawBufferPointer) {
    self.init(base: buffer.baseAddress, length: buffer.count)
  }

  /// The buffer's start.
  ///
  /// The corresponding C field is `iov_base`.
  @_alwaysEmitIntoClient
  public var base: UnsafeMutableRawPointer? {
    get { iov_base }
    set { iov_base = newValue }
  }

  /// The buffer's length in bytes.
  ///
  /// The corresponding C field is `iov_len`.
  @_alwaysEmitIntoClient
  public var length: Int {
    get { iov_len }
    set { iov_len = newValue }
  }
}
#endif // !os(WASI)

// MARK: - kevent

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension CInterop.KEvent {
  /// Creates an event from its fields, by default all zero.
  ///
  /// ``KernelEvent`` is the Swift type for kernel events;
  /// these accessors are for code that builds the C structures.
  @_alwaysEmitIntoClient
  public init(
    identifier: UInt = 0,
    eventFilter: KernelEvent.Filter = KernelEvent.Filter(rawValue: 0),
    eventFlags: KernelEvent.Flags = [],
    filterFlags: KernelEvent.FilterFlags = [],
    filterData: Int = 0,
    userData: UnsafeMutableRawPointer? = nil
  ) {
    var event = KernelEvent(rawValue: CInterop.KEvent())
    event.identifier = identifier
    event.filter = eventFilter
    event.flags = eventFlags
    event.filterFlags = filterFlags
    event.data = filterData
    event.userData = userData
    self = event.rawValue
  }

  /// The identifier of what the event is for, such as a descriptor
  /// or a process ID.
  ///
  /// The corresponding C field is `ident`.
  @_alwaysEmitIntoClient
  public var identifier: UInt {
    get { KernelEvent(rawValue: self).identifier }
    set { self._withEvent { $0.identifier = newValue } }
  }

  /// The filter.
  ///
  /// The corresponding C field is `filter`.
  @_alwaysEmitIntoClient
  public var eventFilter: KernelEvent.Filter {
    get { KernelEvent(rawValue: self).filter }
    set { self._withEvent { $0.filter = newValue } }
  }

  /// The flags.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var eventFlags: KernelEvent.Flags {
    get { KernelEvent(rawValue: self).flags }
    set { self._withEvent { $0.flags = newValue } }
  }

  /// The filter's flags.
  ///
  /// The corresponding C field is `fflags`.
  @_alwaysEmitIntoClient
  public var filterFlags: KernelEvent.FilterFlags {
    get { KernelEvent(rawValue: self).filterFlags }
    set { self._withEvent { $0.filterFlags = newValue } }
  }

  /// The filter's data.
  ///
  /// The corresponding C field is `data`.
  @_alwaysEmitIntoClient
  public var filterData: Int {
    get { KernelEvent(rawValue: self).data }
    set { self._withEvent { $0.data = newValue } }
  }

  /// The caller's data, which the event returns unchanged.
  ///
  /// The corresponding C field is `udata`.
  @_alwaysEmitIntoClient
  public var userData: UnsafeMutableRawPointer? {
    get { KernelEvent(rawValue: self).userData }
    set { self._withEvent { $0.userData = newValue } }
  }

  @_alwaysEmitIntoClient
  internal mutating func _withEvent(_ body: (inout KernelEvent) -> Void) {
    var event = KernelEvent(rawValue: self)
    body(&event)
    self = event.rawValue
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

// MARK: - stat

@available(System 199, *)
extension CInterop.Stat {
  /// Creates file status from its fields, by default all zero.
  ///
  /// ``Stat`` is the Swift type for file status,
  /// with the same accessors;
  /// these are for code that builds the C structures,
  /// such as tests of code that reads them.
  @_alwaysEmitIntoClient
  public init(
    deviceID: DeviceID = DeviceID(rawValue: 0),
    inode: Inode = Inode(rawValue: 0),
    mode: FileMode = FileMode(rawValue: 0),
    linkCount: Int = 0,
    userID: UserID = UserID(rawValue: 0),
    groupID: GroupID = GroupID(rawValue: 0),
    specialDeviceID: DeviceID = DeviceID(rawValue: 0),
    size: Int64 = 0,
    preferredIOBlockSize: Int = 0,
    blocksAllocated: Int64 = 0
  ) {
    var status = Stat(rawValue: CInterop.Stat())
    status.deviceID = deviceID
    status.inode = inode
    status.mode = mode
    status.linkCount = linkCount
    status.userID = userID
    status.groupID = groupID
    status.specialDeviceID = specialDeviceID
    status.size = size
    status.preferredIOBlockSize = preferredIOBlockSize
    status.blocksAllocated = blocksAllocated
    self = status.rawValue
  }

  @_alwaysEmitIntoClient
  internal mutating func _withStatus(_ body: (inout Stat) -> Void) {
    var status = Stat(rawValue: self)
    body(&status)
    self = status.rawValue
  }

  /// The ID of the device that holds the file.
  ///
  /// The corresponding C field is `st_dev`.
  @_alwaysEmitIntoClient
  public var deviceID: DeviceID {
    get { Stat(rawValue: self).deviceID }
    set { _withStatus { $0.deviceID = newValue } }
  }

  /// The file's inode number.
  ///
  /// The corresponding C field is `st_ino`.
  @_alwaysEmitIntoClient
  public var inode: Inode {
    get { Stat(rawValue: self).inode }
    set { _withStatus { $0.inode = newValue } }
  }

  /// The file's type and permissions.
  ///
  /// The corresponding C field is `st_mode`.
  @_alwaysEmitIntoClient
  public var mode: FileMode {
    get { Stat(rawValue: self).mode }
    set { _withStatus { $0.mode = newValue } }
  }

  /// The number of hard links to the file.
  ///
  /// The corresponding C field is `st_nlink`.
  @_alwaysEmitIntoClient
  public var linkCount: Int {
    get { Stat(rawValue: self).linkCount }
    set { _withStatus { $0.linkCount = newValue } }
  }

  /// The ID of the file's owner.
  ///
  /// The corresponding C field is `st_uid`.
  @_alwaysEmitIntoClient
  public var userID: UserID {
    get { Stat(rawValue: self).userID }
    set { _withStatus { $0.userID = newValue } }
  }

  /// The ID of the file's group.
  ///
  /// The corresponding C field is `st_gid`.
  @_alwaysEmitIntoClient
  public var groupID: GroupID {
    get { Stat(rawValue: self).groupID }
    set { _withStatus { $0.groupID = newValue } }
  }

  /// The device ID of a device special file.
  ///
  /// The corresponding C field is `st_rdev`.
  @_alwaysEmitIntoClient
  public var specialDeviceID: DeviceID {
    get { Stat(rawValue: self).specialDeviceID }
    set { _withStatus { $0.specialDeviceID = newValue } }
  }

  /// The file's size in bytes.
  ///
  /// The corresponding C field is `st_size`.
  @_alwaysEmitIntoClient
  public var size: Int64 {
    get { Stat(rawValue: self).size }
    set { _withStatus { $0.size = newValue } }
  }

  /// The block size the file system prefers for I/O.
  ///
  /// The corresponding C field is `st_blksize`.
  @_alwaysEmitIntoClient
  public var preferredIOBlockSize: Int {
    get { Stat(rawValue: self).preferredIOBlockSize }
    set { _withStatus { $0.preferredIOBlockSize = newValue } }
  }

  /// The number of 512-byte blocks allocated to the file.
  ///
  /// The corresponding C field is `st_blocks`.
  @_alwaysEmitIntoClient
  public var blocksAllocated: Int64 {
    get { Stat(rawValue: self).blocksAllocated }
    set { _withStatus { $0.blocksAllocated = newValue } }
  }

  /// The time the file was last accessed.
  ///
  /// The corresponding C field is `st_atim`, or on Darwin `st_atimespec`.
  @_alwaysEmitIntoClient
  public var accessTime: CInterop.TimeSpec {
    get { Stat(rawValue: self).st_atim }
    set { _withStatus { $0.st_atim = newValue } }
  }

  /// The time the file's contents were last modified.
  ///
  /// The corresponding C field is `st_mtim`, or on Darwin `st_mtimespec`.
  @_alwaysEmitIntoClient
  public var modificationTime: CInterop.TimeSpec {
    get { Stat(rawValue: self).st_mtim }
    set { _withStatus { $0.st_mtim = newValue } }
  }

  /// The time the file's status last changed.
  ///
  /// The corresponding C field is `st_ctim`, or on Darwin `st_ctimespec`.
  @_alwaysEmitIntoClient
  public var statusChangeTime: CInterop.TimeSpec {
    get { Stat(rawValue: self).st_ctim }
    set { _withStatus { $0.st_ctim = newValue } }
  }

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  /// The time the file was created.
  ///
  /// The corresponding C field is `st_birthtim`, or on Darwin
  /// `st_birthtimespec`.
  ///
  /// - Note: Only available on Darwin and FreeBSD.
  @_alwaysEmitIntoClient
  public var creationTime: CInterop.TimeSpec {
    get { Stat(rawValue: self).st_birthtim }
    set { _withStatus { $0.st_birthtim = newValue } }
  }
  #endif

  #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
  /// The file's flags.
  ///
  /// The corresponding C field is `st_flags`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var flags: FileFlags {
    get { Stat(rawValue: self).flags }
    set { _withStatus { $0.flags = newValue } }
  }

  /// The file's generation number.
  ///
  /// The corresponding C field is `st_gen`.
  ///
  /// - Note: Only available on Darwin, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public var generationNumber: UInt64 {
    get { Stat(rawValue: self).generationNumber }
    set { _withStatus { $0.generationNumber = newValue } }
  }
  #endif
}

#endif // !os(Windows)
