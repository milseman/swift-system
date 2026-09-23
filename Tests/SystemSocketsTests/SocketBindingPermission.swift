/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

import Testing

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

extension Trait where Self == ConditionTrait {
  /// Skips a test when this process isn't permitted to bind a socket.
  ///
  /// A sandbox can deny `bind` for every address, loopback included,
  /// and then a test that binds a socket fails with `EPERM`.
  /// For example, Apple Claude Code runs a shell command in such a sandbox
  /// unless the command line matches its tool allowlist,
  /// so `swift test` passes when run directly
  /// but fails when a script runs it.
  static var requiresSocketBinding: Self {
    .enabled(
      if: socketBindingIsPermitted,
      "This process isn't permitted to bind a socket, as in a sandbox that denies network-bind")
  }
}

/// Whether this process can bind an IPv4 socket to the loopback address.
///
/// The probe calls the C functions directly,
/// so a bug in `SocketDescriptor.bind(to:)` can't skip the tests that check it.
/// Only a permission error counts as a denial;
/// after any other failure the tests still run, and report it.
private let socketBindingIsPermitted: Bool = {
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  guard fd >= 0 else { return true }
  defer { close(fd) }

  var address = sockaddr_in()
  #if SYSTEM_PACKAGE_DARWIN
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  #endif
  address.sin_family = sa_family_t(AF_INET)
  address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
  let result = withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  return result == 0 || (errno != EPERM && errno != EACCES)
}()

#endif
