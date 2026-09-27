//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// Reading disk quotas with quotactl on Darwin. Other platforms' quotactl
// takes other commands and structs: Linux's names a block device and fills
// an if_dqblk, and FreeBSD's dqblk counts blocks rather than bytes.

#if SYSTEM_PACKAGE_DARWIN

// Must import here to use C dqblk properties in @_alwaysEmitIntoClient APIs.
import Darwin

// MARK: - DiskQuota

/// A Swift wrapper of the C `dqblk` struct: a user's or a group's disk quota
/// on a file system, and their use of it.
///
/// - Note: Only available on Darwin.
@frozen
@available(System 199, *)
public struct DiskQuota: RawRepresentable, Sendable {

  /// The raw C `dqblk` struct.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.DiskQuota

  /// Creates a Swift `DiskQuota` from the raw C struct.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.DiskQuota) { self.rawValue = rawValue }

  /// The number of bytes that can't be exceeded, or 0 for no limit.
  ///
  /// The corresponding C property is `dqb_bhardlimit`.
  @_alwaysEmitIntoClient
  public var hardByteLimit: UInt64 {
    get { rawValue.dqb_bhardlimit }
    set { rawValue.dqb_bhardlimit = newValue }
  }

  /// The number of bytes that can be exceeded only until `byteTimeLimit`, or
  /// 0 for no limit.
  ///
  /// The corresponding C property is `dqb_bsoftlimit`.
  @_alwaysEmitIntoClient
  public var softByteLimit: UInt64 {
    get { rawValue.dqb_bsoftlimit }
    set { rawValue.dqb_bsoftlimit = newValue }
  }

  /// The number of bytes in use.
  ///
  /// The corresponding C property is `dqb_curbytes`.
  @_alwaysEmitIntoClient
  public var bytesUsed: UInt64 {
    get { rawValue.dqb_curbytes }
    set { rawValue.dqb_curbytes = newValue }
  }

  /// One more than the number of inodes that can be in use, or 0 for no
  /// limit.
  ///
  /// The corresponding C property is `dqb_ihardlimit`.
  @_alwaysEmitIntoClient
  public var hardInodeLimit: UInt32 {
    get { rawValue.dqb_ihardlimit }
    set { rawValue.dqb_ihardlimit = newValue }
  }

  /// The number of inodes that can be exceeded only until `inodeTimeLimit`,
  /// or 0 for no limit.
  ///
  /// The corresponding C property is `dqb_isoftlimit`.
  @_alwaysEmitIntoClient
  public var softInodeLimit: UInt32 {
    get { rawValue.dqb_isoftlimit }
    set { rawValue.dqb_isoftlimit = newValue }
  }

  /// The number of inodes in use.
  ///
  /// The corresponding C property is `dqb_curinodes`.
  @_alwaysEmitIntoClient
  public var inodesUsed: UInt32 {
    get { rawValue.dqb_curinodes }
    set { rawValue.dqb_curinodes = newValue }
  }

  /// When the use of bytes over `softByteLimit` stops being allowed, in
  /// seconds since 1970, or 0 if the use isn't over it.
  ///
  /// The corresponding C property is `dqb_btime`.
  @_alwaysEmitIntoClient
  public var byteTimeLimit: UInt32 {
    get { rawValue.dqb_btime }
    set { rawValue.dqb_btime = newValue }
  }

  /// When the use of inodes over `softInodeLimit` stops being allowed, in
  /// seconds since 1970, or 0 if the use isn't over it.
  ///
  /// The corresponding C property is `dqb_itime`.
  @_alwaysEmitIntoClient
  public var inodeTimeLimit: UInt32 {
    get { rawValue.dqb_itime }
    set { rawValue.dqb_itime = newValue }
  }

  /// The user or group ID that the quota is for, or 0 for an empty entry.
  ///
  /// The corresponding C property is `dqb_id`.
  @_alwaysEmitIntoClient
  public var id: UInt32 {
    get { rawValue.dqb_id }
    set { rawValue.dqb_id = newValue }
  }
}

// MARK: - DiskQuota.Kind

@available(System 199, *)
extension DiskQuota {
  /// Whose use a quota limits: a user's or a group's.
  @frozen
  public struct Kind: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C quota type.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed `DiskQuota.Kind` from the raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// A user's quota.
    ///
    /// The corresponding C constant is `USRQUOTA`.
    @_alwaysEmitIntoClient
    public static var user: Kind { Kind(rawValue: _USRQUOTA) }

    /// A group's quota.
    ///
    /// The corresponding C constant is `GRPQUOTA`.
    @_alwaysEmitIntoClient
    public static var group: Kind { Kind(rawValue: _GRPQUOTA) }
  }
}

// MARK: - quotactl

@available(System 199, *)
extension FilePath {
  /// Returns whether the file system containing the file at this path
  /// enforces quotas of the given kind.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``.
  ///
  /// The corresponding C function is `quotactl`, with `Q_QUOTASTAT`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func quotasEnabled(
    for kind: DiskQuota.Kind,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try withPlatformString {
      FilePath._quotasEnabled($0, for: kind, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns whether the file system containing the file at the given path
  /// enforces quotas of the given kind.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``.
  ///
  /// The corresponding C function is `quotactl`, with `Q_QUOTASTAT`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func quotasEnabled(
    _ path: UnsafePointer<CChar>,
    for kind: DiskQuota.Kind,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> Bool {
    try _quotasEnabled(path, for: kind, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _quotasEnabled(
    _ path: UnsafePointer<CChar>,
    for kind: DiskQuota.Kind,
    retryOnInterrupt: Bool
  ) -> Result<Bool, Errno> {
    var enabled: CInt = 0
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      // Q_QUOTASTAT ignores the ID.
      withUnsafeMutableBytes(of: &enabled) {
        system_quotactl(path, _quotaCommand(_Q_QUOTASTAT, kind), 0, $0.baseAddress!)
      }
    }.map { enabled != 0 }
  }

  /// Returns a user's disk quota on the file system containing the file at
  /// this path.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``. Only the superuser can get another user's quota.
  ///
  /// The corresponding C function is `quotactl`, with `Q_GETQUOTA` and
  /// `USRQUOTA`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func diskQuota(
    for user: UserID,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DiskQuota {
    try withPlatformString {
      FilePath._diskQuota(
        $0, for: .user, id: user.rawValue, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns a user's disk quota on the file system containing the file at
  /// the given path.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``. Only the superuser can get another user's quota.
  ///
  /// The corresponding C function is `quotactl`, with `Q_GETQUOTA` and
  /// `USRQUOTA`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func diskQuota(
    _ path: UnsafePointer<CChar>,
    for user: UserID,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DiskQuota {
    try _diskQuota(
      path, for: .user, id: user.rawValue, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  /// Returns a group's disk quota on the file system containing the file at
  /// this path.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``. Only the superuser can get the quota of a group
  /// the caller isn't in.
  ///
  /// The corresponding C function is `quotactl`, with `Q_GETQUOTA` and
  /// `GRPQUOTA`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func diskQuota(
    for group: GroupID,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DiskQuota {
    try withPlatformString {
      FilePath._diskQuota(
        $0, for: .group, id: group.rawValue, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Returns a group's disk quota on the file system containing the file at
  /// the given path.
  ///
  /// A file system that doesn't support quotas, such as APFS, throws
  /// ``Errno/notSupported``. Only the superuser can get the quota of a group
  /// the caller isn't in.
  ///
  /// The corresponding C function is `quotactl`, with `Q_GETQUOTA` and
  /// `GRPQUOTA`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static func diskQuota(
    _ path: UnsafePointer<CChar>,
    for group: GroupID,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> DiskQuota {
    try _diskQuota(
      path, for: .group, id: group.rawValue, retryOnInterrupt: retryOnInterrupt
    ).get()
  }

  @usableFromInline
  internal static func _diskQuota(
    _ path: UnsafePointer<CChar>,
    for kind: DiskQuota.Kind,
    id: UInt32,
    retryOnInterrupt: Bool
  ) -> Result<DiskQuota, Errno> {
    var quota = CInterop.DiskQuota()
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      // quotactl takes the ID as an int, so IDs past Int32.max go by their
      // bit pattern, as the kernel reads them.
      withUnsafeMutableBytes(of: &quota) {
        system_quotactl(
          path, _quotaCommand(_Q_GETQUOTA, kind), CInt(bitPattern: id),
          $0.baseAddress!)
      }
    }.map { DiskQuota(rawValue: quota) }
  }

  /// The command and quota type in one int, as the C macro `QCMD`, which
  /// Swift doesn't import, combines them.
  internal static func _quotaCommand(_ command: CInt, _ kind: DiskQuota.Kind) -> CInt {
    (command << _SUBCMDSHIFT) | (kind.rawValue & _SUBCMDMASK)
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
