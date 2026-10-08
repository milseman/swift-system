/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage
import WinSDK

// Winsock's extension functions, such as WSARecvMsg, which ws2_32 doesn't
// export: a socket's provider hands them out through
// WSAIoctl(SIO_GET_EXTENSION_FUNCTION_POINTER), keyed by GUID. SystemWinSocks
// looks each family of them up once per process, the first time one is
// needed, through a socket it opens for the purpose and closes, as Go's
// golang.org/x/sys/windows does; NIO looks them up on every call. Windows'
// own providers hand every socket the same functions. A socket of another
// provider, such as a layered one, might want its own, which a cache per
// socket, or per family, type and protocol as .NET keeps, would serve.

/// The message functions, looked up through a UDP socket.
internal struct _WinsockMessageFunctions {
  internal var receiveMessage: LPFN_WSARECVMSG
  internal var sendMessage: LPFN_WSASENDMSG
}

// A global's initializer runs once per process, whichever thread gets there
// first, so the first lookup's result, failure included, is every call's.
internal let _winsockMessageFunctions: Result<_WinsockMessageFunctions, Win32.Error> = {
  _withProbeSocket(af: 2, type: 2, protocol: 17) { probe in
    _extensionFunctionAddress(probe, _WSAID_WSARECVMSG).flatMap { receive in
      _extensionFunctionAddress(probe, _WSAID_WSASENDMSG).map { send in
        _WinsockMessageFunctions(
          receiveMessage: unsafeBitCast(receive, to: LPFN_WSARECVMSG.self),
          sendMessage: unsafeBitCast(send, to: LPFN_WSASENDMSG.self))
      }
    }
  }
}()

/// Calls `body` with a socket of the given kind, opened for looking up
/// extension functions and closed afterward, after starting Winsock.
internal func _withProbeSocket<R>(
  af: CInt, type: CInt, protocol: CInt,
  _ body: (SOCKET) -> Result<R, Win32.Error>
) -> Result<R, Win32.Error> {
  _startWinsock().flatMap {
    let probe = system_WSASocketW(af, type, `protocol`, _WSA_FLAG_NO_HANDLE_INHERIT)
    guard probe != _INVALID_SOCKET else { return .failure(_lastWinsockError()) }
    defer { _ = system_closesocket(probe) }
    return body(probe)
  }
}

/// The address of the extension function that `id` names, from the
/// provider of `socket`.
internal func _extensionFunctionAddress(
  _ socket: SOCKET, _ id: GUID
) -> Result<UnsafeRawPointer, Win32.Error> {
  var id = id
  var address: UnsafeRawPointer? = nil
  var returned: DWORD = 0
  let result = withUnsafeMutableBytes(of: &id) { id in
    withUnsafeMutableBytes(of: &address) { address in
      nothingOrWinsockError(retryOnInterrupt: false) {
        system_WSAIoctl(
          socket, _SIO_GET_EXTENSION_FUNCTION_POINTER,
          id.baseAddress, DWORD(id.count), address.baseAddress, DWORD(address.count), &returned)
      }
    }
  }
  return result.flatMap {
    // A provider that succeeds without a function hasn't got it.
    guard let address else { return .failure(.invalidFunction) }
    return .success(address)
  }
}

#endif // os(Windows)
