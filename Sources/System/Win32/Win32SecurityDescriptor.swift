/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

@available(System 199, *)
extension Win32 {
  /// A Windows security descriptor.
  ///
  /// This type owns its storage and releases it with `LocalFree`.
  ///
  /// Pass a descriptor to ``Win32/FileHandle/open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``
  /// through a binding of optional type, which the open borrows:
  ///
  ///     let descriptor: Win32.SecurityDescriptor? =
  ///       try .init(sddl: "D:P(A;;GA;;;SY)(A;;GA;;;BA)")
  ///     let file = try Win32.FileHandle.open(
  ///       path, access: .genericWrite, disposition: .createNew,
  ///       securityDescriptor: descriptor)
  ///
  /// The corresponding C type is `PSECURITY_DESCRIPTOR`.
  @frozen @safe
  public struct SecurityDescriptor: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _pointer: PSECURITY_DESCRIPTOR

    /// Parses a Security Descriptor Definition Language string.
    ///
    /// The corresponding C function is
    /// `ConvertStringSecurityDescriptorToSecurityDescriptorW` with
    /// `SDDL_REVISION_1`.
    @_alwaysEmitIntoClient
    public init(sddl: String) throws(Win32.Error) {
      self._pointer = try Win32.SecurityDescriptor._parse(sddl).get()
    }

    /// Adopts a descriptor allocated with `LocalAlloc`, taking ownership.
    ///
    /// Returns `nil` if `raw` is `NULL`.
    @_alwaysEmitIntoClient
    @unsafe
    public init?(unsafelyAdopting raw: PSECURITY_DESCRIPTOR?) {
      guard let raw else { return nil }
      self._pointer = raw
    }

    /// The raw C pointer. Valid only while this value is alive.
    @_alwaysEmitIntoClient
    @unsafe
    public var unsafeRawPointer: PSECURITY_DESCRIPTOR { _pointer }

    /// Gives up ownership and returns the raw pointer.
    ///
    /// The caller becomes responsible for releasing it with `LocalFree`.
    @_alwaysEmitIntoClient
    @unsafe
    public consuming func relinquish() -> PSECURITY_DESCRIPTOR {
      let pointer = _pointer
      discard self
      return pointer
    }

    deinit {
      _ = system_LocalFree(_pointer)
    }
  }
}

@available(System 199, *)
extension Win32.SecurityDescriptor {
  @usableFromInline
  internal static func _parse(_ sddl: String) -> Result<PSECURITY_DESCRIPTOR, Win32.Error> {
    sddl.withCString(encodedAs: UTF16.self) { sddl in
      var descriptor: PSECURITY_DESCRIPTOR? = nil
      guard system_ConvertStringSecurityDescriptorToSecurityDescriptorW(
        sddl, _SDDL_REVISION_1, &descriptor, nil
      ), let descriptor else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(descriptor)
    }
  }
}

#endif // os(Windows)
