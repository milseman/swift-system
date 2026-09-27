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

// FileSystemType on Linux and Android, where StatFS wraps statvfs, which has
// no f_type: statfs and fstatfs, which report it, and the magic numbers of
// <linux/magic.h>.

#if os(Linux) || os(Android)

// MARK: - Initializers

@available(System 199, *)
extension FileSystemType {
  /// Creates a `FileSystemType` for the file system containing the file at
  /// `path`.
  ///
  /// The corresponding C function is `statfs()`, and this is the `f_type`
  /// field it reports.
  /// - Note: Only available on Linux and Android. On Darwin and FreeBSD,
  ///   `StatFS.type` reports it.
  @_alwaysEmitIntoClient
  public init(
    _ path: FilePath,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    self = try path.withPlatformString {
      Self._statfs($0, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  /// Creates a `FileSystemType` for the file system containing the file at
  /// the null-terminated `UnsafePointer<CChar>` path.
  ///
  /// The corresponding C function is `statfs()`, and this is the `f_type`
  /// field it reports.
  /// - Note: Only available on Linux and Android. On Darwin and FreeBSD,
  ///   `StatFS.type` reports it.
  @_alwaysEmitIntoClient
  public init(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    self = try Self._statfs(path, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _statfs(
    _ path: UnsafePointer<CChar>,
    retryOnInterrupt: Bool
  ) -> Result<FileSystemType, Errno> {
    var type: CUnsignedLong = 0
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_statfs(path, &type)
    }.map { FileSystemType(rawValue: UInt32(truncatingIfNeeded: type)) }
  }

  /// Creates a `FileSystemType` for the file system containing the file that
  /// `fd` refers to.
  ///
  /// The corresponding C function is `fstatfs()`, and this is the `f_type`
  /// field it reports.
  /// - Note: Only available on Linux and Android. On Darwin and FreeBSD,
  ///   `StatFS.type` reports it.
  @_alwaysEmitIntoClient
  public init(
    _ fd: FileDescriptor,
    retryOnInterrupt: Bool = true
  ) throws(Errno) {
    self = try Self._fstatfs(fd, retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal static func _fstatfs(
    _ fd: FileDescriptor,
    retryOnInterrupt: Bool
  ) -> Result<FileSystemType, Errno> {
    var type: CUnsignedLong = 0
    return nothingOrErrno(retryOnInterrupt: retryOnInterrupt) {
      system_fstatfs(fd.rawValue, &type)
    }.map { FileSystemType(rawValue: UInt32(truncatingIfNeeded: type)) }
  }
}

// MARK: - Magic Numbers

@available(System 199, *)
extension FileSystemType {
  // MARK: Memory and kernel file systems

  /// The tmpfs file system, which keeps its files in memory and swap. `/dev/shm`
  /// and `/run` are usually tmpfs, and so is `/sys/fs/cgroup` with control
  /// groups version 1.
  ///
  /// The corresponding C constant is `TMPFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var tmpfs: FileSystemType { FileSystemType(rawValue: _TMPFS_MAGIC) }

  /// The ramfs file system, which keeps its files in memory, with no size limit
  /// and no swap.
  ///
  /// The corresponding C constant is `RAMFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var ramfs: FileSystemType { FileSystemType(rawValue: _RAMFS_MAGIC) }

  /// The proc file system, mounted at `/proc`, through which the kernel reports
  /// on processes and on itself.
  ///
  /// The corresponding C constant is `PROC_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var proc: FileSystemType { FileSystemType(rawValue: _PROC_SUPER_MAGIC) }

  /// The sysfs file system, mounted at `/sys`, through which the kernel
  /// describes devices and drivers.
  ///
  /// The corresponding C constant is `SYSFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var sysfs: FileSystemType { FileSystemType(rawValue: _SYSFS_MAGIC) }

  /// The devpts file system of pseudoterminals, mounted at `/dev/pts`.
  ///
  /// The corresponding C constant is `DEVPTS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var devpts: FileSystemType { FileSystemType(rawValue: _DEVPTS_SUPER_MAGIC) }

  /// A hierarchy of control groups version 1, mounted under `/sys/fs/cgroup`.
  ///
  /// The corresponding C constant is `CGROUP_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var cgroup: FileSystemType { FileSystemType(rawValue: _CGROUP_SUPER_MAGIC) }

  /// The hierarchy of control groups version 2, usually mounted at
  /// `/sys/fs/cgroup`.
  ///
  /// The corresponding C constant is `CGROUP2_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var cgroup2: FileSystemType { FileSystemType(rawValue: _CGROUP2_SUPER_MAGIC) }

  /// The debugfs file system, usually mounted at `/sys/kernel/debug`.
  ///
  /// The corresponding C constant is `DEBUGFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var debugfs: FileSystemType { FileSystemType(rawValue: _DEBUGFS_MAGIC) }

  /// The tracefs file system of kernel tracing, usually mounted at
  /// `/sys/kernel/tracing`.
  ///
  /// The corresponding C constant is `TRACEFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var tracefs: FileSystemType { FileSystemType(rawValue: _TRACEFS_MAGIC) }

  /// The securityfs file system of Linux security modules, usually mounted at
  /// `/sys/kernel/security`.
  ///
  /// The corresponding C constant is `SECURITYFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var securityfs: FileSystemType { FileSystemType(rawValue: _SECURITYFS_MAGIC) }

  /// The bpf file system, which pins BPF programs and maps, usually mounted at
  /// `/sys/fs/bpf`.
  ///
  /// The corresponding C constant is `BPF_FS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var bpf: FileSystemType { FileSystemType(rawValue: _BPF_FS_MAGIC) }

  /// The nsfs file system of namespaces, whose files the links in
  /// `/proc/<pid>/ns` refer to.
  ///
  /// The corresponding C constant is `NSFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var nsfs: FileSystemType { FileSystemType(rawValue: _NSFS_MAGIC) }

  /// The efivarfs file system of UEFI variables, usually mounted at
  /// `/sys/firmware/efi/efivars`.
  ///
  /// The corresponding C constant is `EFIVARFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var efivarfs: FileSystemType { FileSystemType(rawValue: _EFIVARFS_MAGIC) }

  /// The hugetlbfs file system, whose files huge pages back.
  ///
  /// The corresponding C constant is `HUGETLBFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var hugetlbfs: FileSystemType { FileSystemType(rawValue: _HUGETLBFS_MAGIC) }

  /// The mqueue file system of POSIX message queues, usually mounted at
  /// `/dev/mqueue`.
  ///
  /// The corresponding C constant is `MQUEUE_MAGIC`.
  @_alwaysEmitIntoClient
  public static var mqueue: FileSystemType { FileSystemType(rawValue: _MQUEUE_MAGIC) }

  /// The autofs file system, which mounts file systems on demand.
  ///
  /// Getting the type of a path under an autofs mount point can trigger the
  /// mount, and then reports the type of the file system mounted there.
  ///
  /// The corresponding C constant is `AUTOFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var autofs: FileSystemType { FileSystemType(rawValue: _AUTOFS_SUPER_MAGIC) }

  // MARK: Stacked and user space file systems

  /// A file system in user space, through FUSE.
  ///
  /// The corresponding C constant is `FUSE_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var fuse: FileSystemType { FileSystemType(rawValue: _FUSE_SUPER_MAGIC) }

  /// The overlay file system, which combines directories into one, as
  /// containers' root file systems do.
  ///
  /// The corresponding C constant is `OVERLAYFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var overlay: FileSystemType { FileSystemType(rawValue: _OVERLAYFS_SUPER_MAGIC) }

  // MARK: Storage file systems

  /// The ext2 file system.
  ///
  /// ext2, ext3, and ext4 all report this value, so `ext2`, `ext3`, and
  /// `ext4` are equal.
  ///
  /// The corresponding C constant is `EXT2_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var ext2: FileSystemType { FileSystemType(rawValue: _EXT2_SUPER_MAGIC) }

  /// The ext3 file system.
  ///
  /// ext2, ext3, and ext4 all report this value, so `ext2`, `ext3`, and
  /// `ext4` are equal.
  ///
  /// The corresponding C constant is `EXT3_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var ext3: FileSystemType { FileSystemType(rawValue: _EXT3_SUPER_MAGIC) }

  /// The ext4 file system.
  ///
  /// ext2, ext3, and ext4 all report this value, so `ext2`, `ext3`, and
  /// `ext4` are equal.
  ///
  /// The corresponding C constant is `EXT4_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var ext4: FileSystemType { FileSystemType(rawValue: _EXT4_SUPER_MAGIC) }

  /// The Btrfs file system.
  ///
  /// The corresponding C constant is `BTRFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var btrfs: FileSystemType { FileSystemType(rawValue: _BTRFS_SUPER_MAGIC) }

  /// The XFS file system.
  ///
  /// The corresponding C constant is `XFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var xfs: FileSystemType { FileSystemType(rawValue: _XFS_SUPER_MAGIC) }

  /// The F2FS file system, designed for flash storage.
  ///
  /// The corresponding C constant is `F2FS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var f2fs: FileSystemType { FileSystemType(rawValue: _F2FS_SUPER_MAGIC) }

  /// The EROFS file system, which is compressed and read-only.
  ///
  /// The corresponding C constant is `EROFS_SUPER_MAGIC_V1`.
  @_alwaysEmitIntoClient
  public static var erofs: FileSystemType { FileSystemType(rawValue: _EROFS_SUPER_MAGIC_V1) }

  /// The SquashFS file system, which is compressed and read-only.
  ///
  /// The corresponding C constant is `SQUASHFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var squashfs: FileSystemType { FileSystemType(rawValue: _SQUASHFS_MAGIC) }

  /// A FAT file system, through either the msdos or the vfat driver.
  ///
  /// The corresponding C constant is `MSDOS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var msdos: FileSystemType { FileSystemType(rawValue: _MSDOS_SUPER_MAGIC) }

  /// The ISO 9660 file system of optical discs.
  ///
  /// The corresponding C constant is `ISOFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var iso9660: FileSystemType { FileSystemType(rawValue: _ISOFS_SUPER_MAGIC) }

  // MARK: Network file systems

  /// The NFS network file system.
  ///
  /// The corresponding C constant is `NFS_SUPER_MAGIC`.
  @_alwaysEmitIntoClient
  public static var nfs: FileSystemType { FileSystemType(rawValue: _NFS_SUPER_MAGIC) }

  /// A file system shared over the 9P protocol, as virtual machines share
  /// their host's files.
  ///
  /// The corresponding C constant is `V9FS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var v9fs: FileSystemType { FileSystemType(rawValue: _V9FS_MAGIC) }

  // MARK: Descriptors' file systems

  /// The file system that pipes belong to, which `FileDescriptor.fileSystemType()`
  /// reports for either end of a pipe.
  ///
  /// The corresponding C constant is `PIPEFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var pipefs: FileSystemType { FileSystemType(rawValue: _PIPEFS_MAGIC) }

  /// The file system that sockets belong to, which
  /// `FileDescriptor.fileSystemType()` reports for a socket.
  ///
  /// The corresponding C constant is `SOCKFS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var sockfs: FileSystemType { FileSystemType(rawValue: _SOCKFS_MAGIC) }

  /// The file system of descriptors that have no file of their own, such as
  /// those of epoll, eventfd, signalfd, and timerfd.
  ///
  /// The corresponding C constant is `ANON_INODE_FS_MAGIC`.
  @_alwaysEmitIntoClient
  public static var anonymousInode: FileSystemType { FileSystemType(rawValue: _ANON_INODE_FS_MAGIC) }
}

// MARK: - FileDescriptor and FilePath Extensions

@available(System 199, *)
extension FileDescriptor {
  /// Returns the type of the file system containing the file that this
  /// `FileDescriptor` refers to.
  ///
  /// The corresponding C function is `fstatfs()`, and this is the `f_type`
  /// field it reports.
  /// - Note: Only available on Linux and Android. On Darwin and FreeBSD,
  ///   `StatFS.type` reports it.
  @_alwaysEmitIntoClient
  public func fileSystemType(
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileSystemType {
    try FileSystemType(self, retryOnInterrupt: retryOnInterrupt)
  }
}

@available(System 199, *)
extension FilePath {
  /// Returns the type of the file system containing the file at this
  /// `FilePath`.
  ///
  /// The corresponding C function is `statfs()`, and this is the `f_type`
  /// field it reports.
  /// - Note: Only available on Linux and Android. On Darwin and FreeBSD,
  ///   `StatFS.type` reports it.
  @_alwaysEmitIntoClient
  public func fileSystemType(
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> FileSystemType {
    try FileSystemType(self, retryOnInterrupt: retryOnInterrupt)
  }
}

#endif // os(Linux) || os(Android)
