/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

@available(System 199, *)
extension Signal {
  /// The C library's description of the signal,
  /// such as `"Terminated: 15"` for ``terminate`` on Darwin.
  ///
  /// ``description`` is the signal's C name, `SIGTERM`;
  /// this is the text that shells print for a child that a signal ended.
  /// It isn't localized, and differs between C libraries.
  ///
  /// The corresponding C function is `strsignal`.
  @_alwaysEmitIntoClient
  public var message: String { _message }

  @usableFromInline
  internal var _message: String {
    system_strsignal(rawValue).map { String(platformString: $0) } ?? "Unknown signal: \(rawValue)"
  }
}

@available(System 199, *)
extension Signal {
  /// The signal's name in the C library's table, such as `SIGINT`,
  /// or `nil` for a number that the table has no name for.
  ///
  /// The C library names every signal its system defines,
  /// so this names some that ``description`` gives as numbers,
  /// such as Linux's `SIGSTKFLT`. Real-time signals have no names.
  /// Where the C library has no table, on Musl and before glibc 2.32,
  /// this is the name ``description`` gives, if it gives one.
  ///
  /// The corresponding C global variable is `sys_signame`,
  /// on Darwin, the BSDs, and Android.
  /// On Linux, the corresponding C function is `sigabbrev_np`,
  /// from glibc 2.32.
  @_alwaysEmitIntoClient
  public var name: String? { _name }

  @usableFromInline
  internal var _name: String? {
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD) || os(Android)
    guard let name = system_sys_signame(rawValue) else { return nil }
    return "SIG" + String(platformString: name).uppercased()
    #else
    #if os(Linux) && canImport(Glibc)
    if let abbreviation = system_sigabbrev_np(rawValue) {
      return "SIG" + String(platformString: abbreviation)
    }
    if system_has_sigabbrev_np() { return nil }
    #endif
    return Signal._names.first { $0.0 == self }.map { $0.1.description }
    #endif
  }
}

#endif // !os(Windows) && !os(WASI)
