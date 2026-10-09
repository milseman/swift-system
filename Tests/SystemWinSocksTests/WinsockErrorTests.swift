/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import Testing
import WinSDK

@testable import SystemWinSocks
import SystemPackage

@Suite("Winsock errors")
private struct WinsockErrorTests {
  @available(System 199, *)
  @Test func codesMatchTheSDK() {
    let codes: [(Win32.Error, CInt)] = [
      (.interrupted, WinSDK.WSAEINTR),
      (.badFileDescriptor, WinSDK.WSAEBADF),
      (.permissionDenied, WinSDK.WSAEACCES),
      (.badAddress, WinSDK.WSAEFAULT),
      (.invalidArgument, WinSDK.WSAEINVAL),
      (.tooManyOpenFiles, WinSDK.WSAEMFILE),
      (.wouldBlock, WinSDK.WSAEWOULDBLOCK),
      (.nowInProgress, WinSDK.WSAEINPROGRESS),
      (.alreadyInProcess, WinSDK.WSAEALREADY),
      (.notSocket, WinSDK.WSAENOTSOCK),
      (.addressRequired, WinSDK.WSAEDESTADDRREQ),
      (.messageTooLong, WinSDK.WSAEMSGSIZE),
      (.protocolWrongTypeForSocket, WinSDK.WSAEPROTOTYPE),
      (.protocolNotAvailable, WinSDK.WSAENOPROTOOPT),
      (.protocolNotSupported, WinSDK.WSAEPROTONOSUPPORT),
      (.socketTypeNotSupported, WinSDK.WSAESOCKTNOSUPPORT),
      (.notSupportedOnSocket, WinSDK.WSAEOPNOTSUPP),
      (.protocolFamilyNotSupported, WinSDK.WSAEPFNOSUPPORT),
      (.addressFamilyNotSupported, WinSDK.WSAEAFNOSUPPORT),
      (.addressInUse, WinSDK.WSAEADDRINUSE),
      (.addressNotAvailable, WinSDK.WSAEADDRNOTAVAIL),
      (.networkDown, WinSDK.WSAENETDOWN),
      (.networkUnreachable, WinSDK.WSAENETUNREACH),
      (.networkReset, WinSDK.WSAENETRESET),
      (.connectionAbort, WinSDK.WSAECONNABORTED),
      (.connectionReset, WinSDK.WSAECONNRESET),
      (.noBufferSpace, WinSDK.WSAENOBUFS),
      (.socketIsConnected, WinSDK.WSAEISCONN),
      (.socketNotConnected, WinSDK.WSAENOTCONN),
      (.socketShutdown, WinSDK.WSAESHUTDOWN),
      (.tooManyReferences, WinSDK.WSAETOOMANYREFS),
      (.timedOut, WinSDK.WSAETIMEDOUT),
      (.connectionRefused, WinSDK.WSAECONNREFUSED),
      (.hostIsDown, WinSDK.WSAEHOSTDOWN),
      (.noRouteToHost, WinSDK.WSAEHOSTUNREACH),
      (.tooManyProcesses, WinSDK.WSAEPROCLIM),
      (.networkSubsystemNotReady, WinSDK.WSASYSNOTREADY),
      (.winsockVersionNotSupported, WinSDK.WSAVERNOTSUPPORTED),
      (.winsockNotStarted, WinSDK.WSANOTINITIALISED),
    ]
    for (error, code) in codes {
      #expect(error.rawValue == DWORD(code))
    }
  }

  // FormatMessageW describes Winsock's codes, as it does the rest of the
  // system's.
  @available(System 199, *)
  @Test func codesHaveSystemMessages() {
    let description = Win32.Error.wouldBlock.description
    #expect(!description.isEmpty)
    #expect(!description.hasPrefix("Unknown error"))
  }

  @available(System 199, *)
  @Test func startupSucceeds() throws {
    try _startWinsock().get()
    #expect(_winsockStartup == 0)
  }
}

#endif // os(Windows)
