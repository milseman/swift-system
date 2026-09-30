/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Cloning a file's contents into another file, on Linux: the FICLONE ioctl,
// with which a file system that shares storage between files, such as Btrfs
// or XFS, gives one file another's data without copying it. Darwin's
// clonefile (FileClone.swift) makes a new file instead.

#if os(Linux) || os(Android)

@available(System 199, *)
extension FileDescriptor {
  /// Replaces this file's contents with another file's,
  /// sharing their storage rather than copying it.
  ///
  /// - Parameter source: The regular file whose contents to clone,
  ///   open for reading.
  ///
  /// This descriptor must be a regular file open for writing,
  /// without ``OpenOptions/append``, on the same mount as `source`:
  /// two mounts, even of one file system, throw ``Errno/improperLink``,
  /// as a pipe does.
  /// The file system must share storage between files, as Btrfs and XFS can;
  /// others, such as ext4 and tmpfs, throw ``Errno/notSupported``.
  /// Then copy the bytes instead,
  /// as ``sendFile(_:fromAbsoluteOffset:count:retryOnInterrupt:)`` can.
  ///
  /// The two files share storage until one of them changes it:
  /// a write to either doesn't change the other.
  ///
  /// On Darwin, `clonefile` makes a new file instead;
  /// see `clone(to:options:)`.
  ///
  /// The corresponding C constant is `FICLONE`, an `ioctl` request.
  ///
  /// - Note: Only available on Linux and Android.
  @_alwaysEmitIntoClient
  public func cloneContents(of source: FileDescriptor) throws(Errno) {
    try _cloneContents(of: source).get()
  }

  @usableFromInline
  internal func _cloneContents(of source: FileDescriptor) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_ficlone(self.rawValue, source.rawValue)
    }
  }
}

#endif // os(Linux) || os(Android)
