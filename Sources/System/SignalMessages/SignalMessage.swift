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

#endif // !os(Windows) && !os(WASI)
