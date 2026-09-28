/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI) && !os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// A POSIX semaphore.
  ///
  /// The corresponding C type is `sem_t`.
  ///
  /// - Note: Not available on Android.
  public typealias Semaphore = sem_t
}

/// A named POSIX semaphore, which processes share by opening its name.
///
/// A semaphore holds a count.
/// ``post()`` adds one to it,
/// and ``wait(retryOnInterrupt:)`` takes one away,
/// waiting until the count is above zero first;
/// Dispatch's `DispatchSemaphore` has the same operations,
/// named `signal()` and `wait()`, within one process.
///
/// A semaphore is a handle, as ``FileDescriptor`` is:
/// copying one doesn't copy the semaphore,
/// and ``close()`` closes it for every copy.
/// Closing it doesn't remove its name,
/// which lasts until ``remove(named:)`` or the system restarts.
///
///     let ready = try NamedSemaphore.open(
///       named: "/com.example.ready", options: .create, permissions: .ownerReadWrite)
///     defer { try? ready.close() }
///     try ready.wait()
///
/// Darwin has only named semaphores:
/// it has no `sem_init` and no `sem_getvalue`.
///
/// - Note: Not available on Android.
@frozen
@available(System 199, *)
public struct NamedSemaphore: RawRepresentable, Hashable, @unchecked Sendable {
  /// The C semaphore.
  @_alwaysEmitIntoClient
  public var rawValue: UnsafeMutablePointer<CInterop.Semaphore>

  /// Creates a semaphore from a C semaphore.
  @_alwaysEmitIntoClient
  public init(rawValue: UnsafeMutablePointer<CInterop.Semaphore>) { self.rawValue = rawValue }
}

@available(System 199, *)
extension NamedSemaphore {
  /// Options for opening a named semaphore.
  ///
  /// - Note: Not available on Android.
  @frozen
  public struct OpenOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed options value from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Creates the semaphore if it doesn't exist.
    ///
    /// The corresponding C constant is `O_CREAT`.
    @_alwaysEmitIntoClient
    public static var create: OpenOptions { OpenOptions(rawValue: _O_CREAT) }

    /// With ``create``, fails with ``Errno/fileExists``
    /// if the semaphore exists.
    ///
    /// The corresponding C constant is `O_EXCL`.
    @_alwaysEmitIntoClient
    public static var exclusiveCreate: OpenOptions { OpenOptions(rawValue: _O_EXCL) }
  }

  /// The largest count a semaphore can hold,
  /// which is 32,767 on Darwin.
  ///
  /// The corresponding C constant is `SEM_VALUE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxValue: Int { _SEM_VALUE_MAX }

  /// Opens a named semaphore, or creates one.
  ///
  /// - Parameters:
  ///   - name: The semaphore's name.
  ///     By convention it starts with a slash and has no other;
  ///     on Darwin it's at most 31 bytes long,
  ///     and a longer one throws ``Errno/fileNameTooLong``.
  ///   - options: Whether to create the semaphore.
  ///   - permissions: The permissions of a semaphore this call creates.
  ///     This value must not be `nil` when `options` contains `.create`;
  ///     passing `nil` in that case is a programmer error and traps at runtime.
  ///   - value: The count of a semaphore this call creates,
  ///     at most ``maxValue``. The default is `0`.
  /// - Returns: The semaphore.
  ///
  /// Opening a name that doesn't exist, without ``OpenOptions/create``,
  /// throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `sem_open`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public static func open(
    named name: String,
    options: OpenOptions = [],
    permissions: FilePermissions? = nil,
    value: UInt32 = 0
  ) throws(Errno) -> NamedSemaphore {
    try _open(named: name, options: options, permissions: permissions, value: value).get()
  }

  @usableFromInline
  internal static func _open(
    named name: String,
    options: OpenOptions,
    permissions: FilePermissions?,
    value: UInt32
  ) -> Result<NamedSemaphore, Errno> {
    if permissions == nil && options.contains(.create) {
      fatalError(
        "NamedSemaphore.open: 'permissions' must not be nil when 'options' contains '.create'")
    }
    return name.withCString { name in
      guard
        let semaphore = system_sem_open(
          name, options.rawValue, permissions?.rawValue ?? 0, CUnsignedInt(value))
      else {
        return .failure(.current)
      }
      return .success(NamedSemaphore(rawValue: semaphore))
    }
  }

  /// Closes the semaphore.
  ///
  /// The semaphore can't be used afterward.
  /// Its name stays until ``remove(named:)``.
  ///
  /// The corresponding C function is `sem_close`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public func close() throws(Errno) {
    try _close().get()
  }

  @usableFromInline
  internal func _close() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_sem_close(rawValue) }
  }

  /// Removes a named semaphore's name.
  ///
  /// - Parameter name: The semaphore's name.
  ///
  /// Processes that have the semaphore open go on using it;
  /// opening the name again creates another semaphore.
  /// A name that no semaphore has throws ``Errno/noSuchFileOrDirectory``.
  ///
  /// The corresponding C function is `sem_unlink`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public static func remove(named name: String) throws(Errno) {
    try _remove(named: name).get()
  }

  @usableFromInline
  internal static func _remove(named name: String) -> Result<(), Errno> {
    name.withCString { name in
      nothingOrErrno(retryOnInterrupt: false) { system_sem_unlink(name) }
    }
  }

  /// Takes one from the semaphore's count,
  /// waiting until the count is above zero first.
  ///
  /// - Parameter retryOnInterrupt: Whether to retry the wait
  ///   if it throws ``Errno/interrupted``.
  ///   The default is `true`.
  ///   Pass `false` to try only once and throw an error upon interruption.
  ///
  /// The corresponding C function is `sem_wait`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public func wait(retryOnInterrupt: Bool = true) throws(Errno) {
    try _wait(retryOnInterrupt: retryOnInterrupt).get()
  }

  @usableFromInline
  internal func _wait(retryOnInterrupt: Bool) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: retryOnInterrupt) { system_sem_wait(rawValue) }
  }

  /// Takes one from the semaphore's count if it's above zero,
  /// without waiting.
  ///
  /// - Returns: `true` if this call took one,
  ///   and `false` if the count was zero.
  ///
  /// The corresponding C function is `sem_trywait`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public func tryWait() throws(Errno) -> Bool {
    try _tryWait().get()
  }

  @usableFromInline
  internal func _tryWait() -> Result<Bool, Errno> {
    switch nothingOrErrno(retryOnInterrupt: false, { system_sem_trywait(rawValue) }) {
    case .success: return .success(true)
    case .failure(.resourceTemporarilyUnavailable): return .success(false)
    case .failure(let error): return .failure(error)
    }
  }

  /// Adds one to the semaphore's count,
  /// waking one of the threads that wait for it, if any.
  ///
  /// POSIX has a count at ``maxValue`` throw ``Errno/overflow``;
  /// Darwin doesn't check it.
  ///
  /// The corresponding C function is `sem_post`.
  ///
  /// - Note: Not available on Android.
  @_alwaysEmitIntoClient
  public func post() throws(Errno) {
    try _post().get()
  }

  @usableFromInline
  internal func _post() -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) { system_sem_post(rawValue) }
  }
}

#endif // !os(Windows) && !os(WASI) && !os(Android)
