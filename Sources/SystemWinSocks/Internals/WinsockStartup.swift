/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Winsock must be started, with WSAStartup, before a process's first socket.
// SystemWinSocks starts it once, when it first creates a socket, as Rust's
// standard library does, and never calls WSACleanup: Winsock counts its
// starts, so a process that started it elsewhere is unaffected, and cleanup
// matters only to code that unloads Winsock. A global's initializer runs
// once per process, on first use, whichever thread gets there first, so the
// result, failure included, is the first call's.
internal let _winsockStartup: CInt = {
  var data = WSADATA()
  // WSAStartup returns its error rather than setting WSAGetLastError's.
  return system_WSAStartup(_WINSOCK_VERSION, &data)
}()

/// Starts Winsock, if this is the first call, or returns its first result.
@available(System 199, *)
internal func _startWinsock() -> Result<Void, Win32.Error> {
  let result = _winsockStartup
  guard result == 0 else { return .failure(Win32.Error(rawValue: DWORD(bitPattern: result))) }
  return .success(())
}

#endif // os(Windows)
