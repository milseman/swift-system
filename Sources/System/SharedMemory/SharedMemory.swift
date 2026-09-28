/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && !os(Android)

@available(System 199, *)
extension FileDescriptor {
  /// Opens a shared memory object, which processes open by name
  /// and map to share memory.
  ///
  /// - Parameters:
  ///   - name: The object's name.
  ///     By convention it starts with a slash and has no other;
  ///     on Darwin it's at most 31 bytes long,
  ///     and a longer one throws ``Errno/fileNameTooLong``.
  ///   - mode: The access to open it with:
  ///     ``AccessMode/readOnly`` or ``AccessMode/readWrite``.
  ///   - options: ``OpenOptions/create``, to create the object
  ///     if it doesn't exist, and ``OpenOptions/exclusiveCreate``,
  ///     to fail with ``Errno/fileExists`` if it does.
  ///     Linux also takes ``OpenOptions/truncate``;
  ///     Darwin rejects it with ``Errno/invalidArgument``.
  ///     The descriptor is always ``OpenOptions/closeOnExec``.
  ///   - permissions: The permissions of an object this call creates.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
  /// - Returns: A file descriptor for the object.
  ///
  /// A new object is empty.
  /// Give it a size with ``resize(to:retryOnInterrupt:)``,
  /// which Darwin allows only once, and rounds up to a whole page,
  /// then map it with
  /// ``MemoryMapping/init(file:offset:byteCount:protection:options:)``.
  /// Darwin doesn't read or write an object through its descriptor:
  /// only mappings reach its memory.
  ///
  /// The object lasts until ``removeSharedMemory(named:)`` removes its name
  /// and the last descriptor and mapping of it are gone.
  ///
  /// The corresponding C function is `shm_open`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public static func openSharedMemory(
    named name: String,
    _ mode: AccessMode,
    options: OpenOptions = [],
    permissions: FilePermissions? = nil
  ) throws(Errno) -> FileDescriptor {
    try _openSharedMemory(named: name, mode, options: options, permissions: permissions).get()
  }

  @usableFromInline
  internal static func _openSharedMemory(
    named name: String,
    _ mode: AccessMode,
    options: OpenOptions,
    permissions: FilePermissions?
  ) -> Result<FileDescriptor, Errno> {
    if permissions == nil && options.contains(.create) {
      fatalError(
        "FileDescriptor.openSharedMemory: 'permissions' must not be nil when 'options' contains '.create'")
    }
    return name.withCString { name in
      valueOrErrno(retryOnInterrupt: false) {
        system_shm_open(name, mode.rawValue | options.rawValue, permissions?.rawValue ?? 0)
      }
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Removes a shared memory object's name.
  ///
  /// - Parameter name: The object's name.
  ///
  /// The object itself lasts until the last descriptor and mapping of it
  /// are gone; opening the name again creates another object.
  /// A name that no object has throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `shm_unlink`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public static func removeSharedMemory(named name: String) throws(Errno) {
    try _removeSharedMemory(named: name).get()
  }

  @usableFromInline
  internal static func _removeSharedMemory(named name: String) -> Result<(), Errno> {
    name.withCString { name in
      nothingOrErrno(retryOnInterrupt: false) { system_shm_unlink(name) }
    }
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
