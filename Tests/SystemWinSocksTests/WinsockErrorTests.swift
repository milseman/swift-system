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

  // Win32.Error's debugDescription names each of Winsock's codes as the SDK
  // spells it.
  @available(System 199, *)
  @Test func codesHaveTheirSymbolicNames() {
    let names: [(String, CInt)] = [
      ("WSAEINTR", WinSDK.WSAEINTR),
      ("WSAEBADF", WinSDK.WSAEBADF),
      ("WSAEACCES", WinSDK.WSAEACCES),
      ("WSAEFAULT", WinSDK.WSAEFAULT),
      ("WSAEINVAL", WinSDK.WSAEINVAL),
      ("WSAEMFILE", WinSDK.WSAEMFILE),
      ("WSAEWOULDBLOCK", WinSDK.WSAEWOULDBLOCK),
      ("WSAEINPROGRESS", WinSDK.WSAEINPROGRESS),
      ("WSAEALREADY", WinSDK.WSAEALREADY),
      ("WSAENOTSOCK", WinSDK.WSAENOTSOCK),
      ("WSAEDESTADDRREQ", WinSDK.WSAEDESTADDRREQ),
      ("WSAEMSGSIZE", WinSDK.WSAEMSGSIZE),
      ("WSAEPROTOTYPE", WinSDK.WSAEPROTOTYPE),
      ("WSAENOPROTOOPT", WinSDK.WSAENOPROTOOPT),
      ("WSAEPROTONOSUPPORT", WinSDK.WSAEPROTONOSUPPORT),
      ("WSAESOCKTNOSUPPORT", WinSDK.WSAESOCKTNOSUPPORT),
      ("WSAEOPNOTSUPP", WinSDK.WSAEOPNOTSUPP),
      ("WSAEPFNOSUPPORT", WinSDK.WSAEPFNOSUPPORT),
      ("WSAEAFNOSUPPORT", WinSDK.WSAEAFNOSUPPORT),
      ("WSAEADDRINUSE", WinSDK.WSAEADDRINUSE),
      ("WSAEADDRNOTAVAIL", WinSDK.WSAEADDRNOTAVAIL),
      ("WSAENETDOWN", WinSDK.WSAENETDOWN),
      ("WSAENETUNREACH", WinSDK.WSAENETUNREACH),
      ("WSAENETRESET", WinSDK.WSAENETRESET),
      ("WSAECONNABORTED", WinSDK.WSAECONNABORTED),
      ("WSAECONNRESET", WinSDK.WSAECONNRESET),
      ("WSAENOBUFS", WinSDK.WSAENOBUFS),
      ("WSAEISCONN", WinSDK.WSAEISCONN),
      ("WSAENOTCONN", WinSDK.WSAENOTCONN),
      ("WSAESHUTDOWN", WinSDK.WSAESHUTDOWN),
      ("WSAETOOMANYREFS", WinSDK.WSAETOOMANYREFS),
      ("WSAETIMEDOUT", WinSDK.WSAETIMEDOUT),
      ("WSAECONNREFUSED", WinSDK.WSAECONNREFUSED),
      ("WSAELOOP", WinSDK.WSAELOOP),
      ("WSAENAMETOOLONG", WinSDK.WSAENAMETOOLONG),
      ("WSAEHOSTDOWN", WinSDK.WSAEHOSTDOWN),
      ("WSAEHOSTUNREACH", WinSDK.WSAEHOSTUNREACH),
      ("WSAENOTEMPTY", WinSDK.WSAENOTEMPTY),
      ("WSAEPROCLIM", WinSDK.WSAEPROCLIM),
      ("WSAEUSERS", WinSDK.WSAEUSERS),
      ("WSAEDQUOT", WinSDK.WSAEDQUOT),
      ("WSAESTALE", WinSDK.WSAESTALE),
      ("WSAEREMOTE", WinSDK.WSAEREMOTE),
      ("WSASYSNOTREADY", WinSDK.WSASYSNOTREADY),
      ("WSAVERNOTSUPPORTED", WinSDK.WSAVERNOTSUPPORTED),
      ("WSANOTINITIALISED", WinSDK.WSANOTINITIALISED),
      ("WSAEDISCON", WinSDK.WSAEDISCON),
      ("WSAENOMORE", WinSDK.WSAENOMORE),
      ("WSAECANCELLED", WinSDK.WSAECANCELLED),
      ("WSAEINVALIDPROCTABLE", WinSDK.WSAEINVALIDPROCTABLE),
      ("WSAEINVALIDPROVIDER", WinSDK.WSAEINVALIDPROVIDER),
      ("WSAEPROVIDERFAILEDINIT", WinSDK.WSAEPROVIDERFAILEDINIT),
      ("WSASYSCALLFAILURE", WinSDK.WSASYSCALLFAILURE),
      ("WSASERVICE_NOT_FOUND", WinSDK.WSASERVICE_NOT_FOUND),
      ("WSATYPE_NOT_FOUND", WinSDK.WSATYPE_NOT_FOUND),
      ("WSA_E_NO_MORE", WinSDK.WSA_E_NO_MORE),
      ("WSA_E_CANCELLED", WinSDK.WSA_E_CANCELLED),
      ("WSAEREFUSED", WinSDK.WSAEREFUSED),
      ("WSAHOST_NOT_FOUND", WinSDK.WSAHOST_NOT_FOUND),
      ("WSATRY_AGAIN", WinSDK.WSATRY_AGAIN),
      ("WSANO_RECOVERY", WinSDK.WSANO_RECOVERY),
      ("WSANO_DATA", WinSDK.WSANO_DATA),
    ]
    for (name, code) in names {
      let description = Win32.Error(rawValue: DWORD(code)).debugDescription
      #expect(description.hasPrefix("\(name) (\(code), 0x"), "\(description)")
    }
    #expect(Win32.Error.wouldBlock.debugDescription == "WSAEWOULDBLOCK (10035, 0x2733)")
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
