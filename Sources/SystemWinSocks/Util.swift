/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Utility functions for Winsock calls, after SystemSockets' Util.swift.

/// The thread's last Winsock error, which must be read on the statement after
/// the failing call, before anything else can change it.
@available(System 199, *)
internal func _lastWinsockError() -> Win32.Error {
  Win32.Error(rawValue: DWORD(bitPattern: system_WSAGetLastError()))
}

// Results in the last Winsock error if `f` returns SOCKET_ERROR, and calls
// it again if that's WSAEINTR and `retryOnInterrupt` is true.
@available(System 199, *)
internal func valueOrWinsockError(
  retryOnInterrupt: Bool, _ f: () -> CInt
) -> Result<CInt, Win32.Error> {
  repeat {
    let result = f()
    guard result == _SOCKET_ERROR else { return .success(result) }
    let error = _lastWinsockError()
    guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
  } while true
}

@available(System 199, *)
internal func nothingOrWinsockError(
  retryOnInterrupt: Bool, _ f: () -> CInt
) -> Result<(), Win32.Error> {
  valueOrWinsockError(retryOnInterrupt: retryOnInterrupt, f).map { _ in () }
}

// The same, for calls that return a socket, or INVALID_SOCKET on failure.
@available(System 199, *)
internal func socketOrWinsockError(
  retryOnInterrupt: Bool, _ f: () -> SOCKET
) -> Result<SOCKET, Win32.Error> {
  repeat {
    let result = f()
    guard result == _INVALID_SOCKET else { return .success(result) }
    let error = _lastWinsockError()
    guard retryOnInterrupt && error == .interrupted else { return .failure(error) }
  } while true
}

extension OptionSet {
  @inline(never)
  internal func _buildDescription(
    _ descriptions: [(Element, StaticString)]
  ) -> String {
    var copy = self
    var result = "["

    for (option, name) in descriptions {
      if _slowPath(copy.contains(option)) {
        result += name.description
        copy.remove(option)
        if !copy.isEmpty { result += ", " }
      }
    }

    if _slowPath(!copy.isEmpty) {
      result += "\(Self.self)(rawValue: \(copy.rawValue))"
    }
    result += "]"
    return result
  }
}

#endif // os(Windows)
