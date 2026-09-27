/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

// CSystem on Linux, in case its headers declare utsname's members.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import CSystem
import Glibc
#elseif canImport(Musl)
import CSystem
import Musl
#elseif canImport(Android)
import CSystem
import Android
#else
#error("Unsupported Platform")
#endif

/// The name, release, and version of the running operating system,
/// the kind of hardware it runs on, and its name on the network.
///
///     let system = try SystemIdentity.current()
///     print(system.systemName, system.release, system.machine)
///     // Prints "Darwin 25.3.0 arm64"
///
/// The corresponding C type is `struct utsname`.
@frozen
@available(System 199, *)
public struct SystemIdentity: Hashable, Sendable {
  /// The operating system's name, such as `"Darwin"` or `"Linux"`.
  ///
  /// The corresponding C field is `sysname`.
  public var systemName: String

  /// The system's name on the network, which is usually its host name.
  ///
  /// The corresponding C field is `nodename`.
  public var nodeName: String

  /// The operating system's release, such as `"25.3.0"` or `"6.8.0-45-generic"`.
  ///
  /// The corresponding C field is `release`.
  public var release: String

  /// The operating system's version: its build, in a form that differs
  /// from system to system.
  ///
  /// The corresponding C field is `version`.
  public var version: String

  /// The kind of hardware the system runs on, such as `"arm64"` or `"x86_64"`.
  ///
  /// The corresponding C field is `machine`.
  public var machine: String

  /// Creates a system identity from its fields.
  @_alwaysEmitIntoClient
  public init(
    systemName: String, nodeName: String, release: String,
    version: String, machine: String
  ) {
    self.systemName = systemName
    self.nodeName = nodeName
    self.release = release
    self.version = version
    self.machine = machine
  }
}

@available(System 199, *)
extension SystemIdentity {
  /// Returns the running system's identity.
  ///
  /// The corresponding C function is `uname`.
  @_alwaysEmitIntoClient
  public static func current() throws(Errno) -> SystemIdentity {
    try _current().get()
  }

  @usableFromInline
  internal static func _current() -> Result<SystemIdentity, Errno> {
    var names = utsname()
    return nothingOrErrno(retryOnInterrupt: false) {
      system_uname(&names)
    }.map { _ in
      SystemIdentity(
        systemName: _fixedString(names.sysname),
        nodeName: _fixedString(names.nodename),
        release: _fixedString(names.release),
        version: _fixedString(names.version),
        machine: _fixedString(names.machine))
    }
  }

  /// Returns the system's host name.
  ///
  /// The host name is the one the system gives itself,
  /// not one that a name server has for it,
  /// and usually doesn't include a domain.
  /// It's the same as ``nodeName``.
  ///
  /// The corresponding C function is `gethostname`.
  /// On Android, where not every API level has `gethostname`,
  /// it's `uname`'s `nodename`, which `gethostname` returns.
  @_alwaysEmitIntoClient
  public static func hostName() throws(Errno) -> String {
    try _hostName().get()
  }

  @usableFromInline
  internal static func _hostName() -> Result<String, Errno> {
    #if os(Android)
    return _current().map(\.nodeName)
    #else
    // Room for the longest host name that Darwin and FreeBSD allow, 255
    // bytes, which is more than Linux's 64, and a terminator.
    return _withCharacterBuffer(capacity: 256) { buffer in
      nothingOrErrno(retryOnInterrupt: false) {
        system_gethostname(buffer.baseAddress!, buffer.count)
      }
    }
    #endif
  }

  /// Returns the name that the user of the calling process's session
  /// logged in as.
  ///
  /// The login name belongs to the session, not to the process:
  /// it can differ from the name of the process's user,
  /// which ``UserEntry`` looks up.
  /// A process that no login started, such as a daemon,
  /// can have no login name,
  /// and then this method throws, with an error that differs by platform,
  /// such as ``Errno/noSuchAddressOrDevice``.
  ///
  /// The corresponding C function is `getlogin_r`,
  /// and on Android, which has it only from API level 28, `getlogin`.
  @_alwaysEmitIntoClient
  public static func loginName() throws(Errno) -> String {
    try _loginName().get()
  }

  @usableFromInline
  internal static func _loginName() -> Result<String, Errno> {
    #if os(Android)
    guard let name = system_getlogin() else { return .failure(.current) }
    return .success(String(platformString: name))
    #else
    // Darwin's and Linux's limits are 255 bytes and a terminator.
    var capacity = 256
    while true {
      let result = _withCharacterBuffer(capacity: capacity) { buffer in
        nothingOrReturnedErrno(retryOnInterrupt: false) {
          system_getlogin_r(buffer.baseAddress!, buffer.count)
        }
      }
      guard case .failure(.outOfRange) = result, capacity < 1 << 16 else { return result }
      capacity *= 2
    }
    #endif
  }
}

/// Calls `body` with a zeroed buffer of `capacity` characters,
/// and returns what it wrote there, up to the first null character.
@available(System 199, *)
private func _withCharacterBuffer(
  capacity: Int, _ body: (UnsafeMutableBufferPointer<CChar>) -> Result<(), Errno>
) -> Result<String, Errno> {
  withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity) { buffer in
    buffer.initialize(repeating: 0)
    // Leave the last character zero, in case the call fills the buffer
    // without a terminator, as gethostname can when it truncates.
    let result = body(UnsafeMutableBufferPointer(rebasing: buffer.dropLast()))
    return result.map { String(platformString: buffer.baseAddress!) }
  }
}

/// A string from a fixed-size C character array,
/// up to its first null character or its end.
internal func _fixedString<T>(_ characters: T) -> String {
  withUnsafeBytes(of: characters) { bytes in
    String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
  }
}

#endif // !os(Windows) && !os(WASI)
