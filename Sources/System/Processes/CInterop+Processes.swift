/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

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

@available(System 199, *)
extension CInterop {
  #if canImport(Glibc)
  // Named through Glibc's module: CSystem's headers declare sigset_t too,
  // and Swift attributes a C type to the module whose copy it loads first.
  // Unqualified, the name in a SystemPackage file that imports CSystem can
  // load CSystem's, and then a client can't see the type's initializer
  // without importing CSystem (Tests/MemberImportVisibility/SignalSetProbe).
  /// The C `sigset_t` type, a set of signals.
  public typealias SignalSet = Glibc.sigset_t
  #else
  /// The C `sigset_t` type, a set of signals.
  public typealias SignalSet = sigset_t
  #endif

  /// The C `struct sigaction` type, which describes a signal's action.
  public typealias SignalAction = sigaction

  /// The C `siginfo_t` type, which describes a signal's cause,
  /// or a child process's change of state.
  public typealias SignalInfo = siginfo_t

  /// The C `struct rlimit` type, a resource's soft and hard limits.
  public typealias ResourceLimit = rlimit

  /// The C `rlim_t` type, the value of a resource limit.
  public typealias ResourceLimitValue = rlim_t
}

#endif // !os(Windows) && !os(WASI)
