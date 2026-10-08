/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import SystemPackage

// Winsock's codes are Windows system error codes (Winsock numbers its BSD
// codes as Berkeley's errno plus 10000), so SystemWinSocks reports them as
// Win32.Error. Each is named as Errno names the POSIX code it stands for, so
// that a typed catch reads the same on both: `catch .wouldBlock`. In an
// untyped catch, spell the type, `catch Win32.Error.wouldBlock`, since Errno
// has a code of the same name.
//
// The codes are spelled as literals, as Win32.Error's are: they're fixed
// ABI. WinsockErrorTests checks each one against the SDK.
@available(System 199, *)
extension Win32.Error {
  /// A blocking call was interrupted.
  ///
  /// Winsock 2 reports it only for a call that Winsock 1.1's
  /// `WSACancelBlockingCall` canceled, so System's calls, which retry it when
  /// `retryOnInterrupt` is true, as on POSIX, rarely see it.
  ///
  /// The corresponding C constant is `WSAEINTR`.
  @_alwaysEmitIntoClient
  public static var interrupted: Win32.Error { Win32.Error(rawValue: 10004) }

  /// The file handle isn't valid.
  ///
  /// The corresponding C constant is `WSAEBADF`.
  @_alwaysEmitIntoClient
  public static var badFileDescriptor: Win32.Error { Win32.Error(rawValue: 10009) }

  /// Permission denied: such as sending a broadcast without
  /// ``SocketDescriptor/SocketOption/broadcast``, or binding an address that
  /// another socket holds exclusively.
  ///
  /// The corresponding C constant is `WSAEACCES`.
  @_alwaysEmitIntoClient
  public static var permissionDenied: Win32.Error { Win32.Error(rawValue: 10013) }

  /// A pointer argument isn't valid, or a length is too small, such as an
  /// address buffer shorter than the address.
  ///
  /// The corresponding C constant is `WSAEFAULT`.
  @_alwaysEmitIntoClient
  public static var badAddress: Win32.Error { Win32.Error(rawValue: 10014) }

  /// An argument isn't valid, or the socket isn't in a state that allows the
  /// call, such as accepting on a socket that isn't listening.
  ///
  /// The corresponding C constant is `WSAEINVAL`.
  @_alwaysEmitIntoClient
  public static var invalidArgument: Win32.Error { Win32.Error(rawValue: 10022) }

  /// Too many open sockets.
  ///
  /// The corresponding C constant is `WSAEMFILE`.
  @_alwaysEmitIntoClient
  public static var tooManyOpenFiles: Win32.Error { Win32.Error(rawValue: 10024) }

  /// The operation would block a nonblocking socket.
  ///
  /// Retry it later, when polling reports the socket ready. A nonblocking
  /// connect reports this, where POSIX reports `EINPROGRESS`
  /// (``Errno/nowInProgress``).
  ///
  /// The corresponding C constant is `WSAEWOULDBLOCK`.
  @_alwaysEmitIntoClient
  public static var wouldBlock: Win32.Error { Win32.Error(rawValue: 10035) }

  /// A blocking operation is in progress.
  ///
  /// Winsock 1.1 allowed one blocking call per thread at a time. A
  /// nonblocking connect reports ``wouldBlock`` instead, unlike POSIX's.
  ///
  /// The corresponding C constant is `WSAEINPROGRESS`.
  @_alwaysEmitIntoClient
  public static var nowInProgress: Win32.Error { Win32.Error(rawValue: 10036) }

  /// An operation is already in progress on the nonblocking socket, such as
  /// a second connect while the first is pending.
  ///
  /// The corresponding C constant is `WSAEALREADY`.
  @_alwaysEmitIntoClient
  public static var alreadyInProcess: Win32.Error { Win32.Error(rawValue: 10037) }

  /// The handle isn't a socket.
  ///
  /// The corresponding C constant is `WSAENOTSOCK`.
  @_alwaysEmitIntoClient
  public static var notSocket: Win32.Error { Win32.Error(rawValue: 10038) }

  /// A destination address is required.
  ///
  /// The corresponding C constant is `WSAEDESTADDRREQ`.
  @_alwaysEmitIntoClient
  public static var addressRequired: Win32.Error { Win32.Error(rawValue: 10039) }

  /// The message is too long: a datagram larger than the protocol allows,
  /// or larger than the buffer it's received into.
  ///
  /// A receive that throws this has filled the buffer with the start of the
  /// datagram and discarded the rest, where POSIX returns the truncated
  /// count.
  ///
  /// The corresponding C constant is `WSAEMSGSIZE`.
  @_alwaysEmitIntoClient
  public static var messageTooLong: Win32.Error { Win32.Error(rawValue: 10040) }

  /// The protocol doesn't support the socket's type.
  ///
  /// The corresponding C constant is `WSAEPROTOTYPE`.
  @_alwaysEmitIntoClient
  public static var protocolWrongTypeForSocket: Win32.Error { Win32.Error(rawValue: 10041) }

  /// The option, or its level, isn't known or supported.
  ///
  /// The corresponding C constant is `WSAENOPROTOOPT`.
  @_alwaysEmitIntoClient
  public static var protocolNotAvailable: Win32.Error { Win32.Error(rawValue: 10042) }

  /// The protocol isn't supported, or isn't configured.
  ///
  /// The corresponding C constant is `WSAEPROTONOSUPPORT`.
  @_alwaysEmitIntoClient
  public static var protocolNotSupported: Win32.Error { Win32.Error(rawValue: 10043) }

  /// The socket type isn't supported in the address family.
  ///
  /// The corresponding C constant is `WSAESOCKTNOSUPPORT`.
  @_alwaysEmitIntoClient
  public static var socketTypeNotSupported: Win32.Error { Win32.Error(rawValue: 10044) }

  /// The operation isn't supported on the socket, such as listening on a
  /// datagram socket.
  ///
  /// The corresponding C constant is `WSAEOPNOTSUPP`.
  @_alwaysEmitIntoClient
  public static var notSupportedOnSocket: Win32.Error { Win32.Error(rawValue: 10045) }

  /// The protocol family isn't supported, or isn't configured.
  ///
  /// The corresponding C constant is `WSAEPFNOSUPPORT`.
  @_alwaysEmitIntoClient
  public static var protocolFamilyNotSupported: Win32.Error { Win32.Error(rawValue: 10046) }

  /// The protocol doesn't support the address family.
  ///
  /// The corresponding C constant is `WSAEAFNOSUPPORT`.
  @_alwaysEmitIntoClient
  public static var addressFamilyNotSupported: Win32.Error { Win32.Error(rawValue: 10047) }

  /// The address is in use.
  ///
  /// The corresponding C constant is `WSAEADDRINUSE`.
  @_alwaysEmitIntoClient
  public static var addressInUse: Win32.Error { Win32.Error(rawValue: 10048) }

  /// The address isn't valid in its context, such as an address that isn't
  /// this host's to bind, or a port of 0 to connect to.
  ///
  /// The corresponding C constant is `WSAEADDRNOTAVAIL`.
  @_alwaysEmitIntoClient
  public static var addressNotAvailable: Win32.Error { Win32.Error(rawValue: 10049) }

  /// The network is down.
  ///
  /// The corresponding C constant is `WSAENETDOWN`.
  @_alwaysEmitIntoClient
  public static var networkDown: Win32.Error { Win32.Error(rawValue: 10050) }

  /// The network is unreachable.
  ///
  /// The corresponding C constant is `WSAENETUNREACH`.
  @_alwaysEmitIntoClient
  public static var networkUnreachable: Win32.Error { Win32.Error(rawValue: 10051) }

  /// The network dropped the connection on reset, such as when a keepalive
  /// probe got no answer.
  ///
  /// The corresponding C constant is `WSAENETRESET`.
  @_alwaysEmitIntoClient
  public static var networkReset: Win32.Error { Win32.Error(rawValue: 10052) }

  /// This host aborted the connection, such as for a time-out.
  ///
  /// The corresponding C constant is `WSAECONNABORTED`.
  @_alwaysEmitIntoClient
  public static var connectionAbort: Win32.Error { Win32.Error(rawValue: 10053) }

  /// The peer reset the connection.
  ///
  /// A datagram socket reports this for a datagram it sent that drew an
  /// ICMP port-unreachable reply, on its next receive.
  ///
  /// The corresponding C constant is `WSAECONNRESET`.
  @_alwaysEmitIntoClient
  public static var connectionReset: Win32.Error { Win32.Error(rawValue: 10054) }

  /// No buffer space is available, or the socket's queue is full.
  ///
  /// The corresponding C constant is `WSAENOBUFS`.
  @_alwaysEmitIntoClient
  public static var noBufferSpace: Win32.Error { Win32.Error(rawValue: 10055) }

  /// The socket is already connected.
  ///
  /// The corresponding C constant is `WSAEISCONN`.
  @_alwaysEmitIntoClient
  public static var socketIsConnected: Win32.Error { Win32.Error(rawValue: 10056) }

  /// The socket isn't connected.
  ///
  /// The corresponding C constant is `WSAENOTCONN`.
  @_alwaysEmitIntoClient
  public static var socketNotConnected: Win32.Error { Win32.Error(rawValue: 10057) }

  /// The socket was shut down in the direction of the operation.
  ///
  /// The corresponding C constant is `WSAESHUTDOWN`.
  @_alwaysEmitIntoClient
  public static var socketShutdown: Win32.Error { Win32.Error(rawValue: 10058) }

  /// Too many references to a kernel object.
  ///
  /// The corresponding C constant is `WSAETOOMANYREFS`.
  @_alwaysEmitIntoClient
  public static var tooManyReferences: Win32.Error { Win32.Error(rawValue: 10059) }

  /// The operation timed out: a connect that got no answer, or a send or
  /// receive past ``SocketDescriptor/setSendTimeout(_:)`` or
  /// ``SocketDescriptor/setReceiveTimeout(_:)``'s time.
  ///
  /// A send or receive that timed out leaves the socket in an indeterminate
  /// state, which Winsock says shouldn't be used further. POSIX reports its
  /// time-outs as `EWOULDBLOCK` instead.
  ///
  /// The corresponding C constant is `WSAETIMEDOUT`.
  @_alwaysEmitIntoClient
  public static var timedOut: Win32.Error { Win32.Error(rawValue: 10060) }

  /// The peer refused the connection: nothing listens at the address.
  ///
  /// The corresponding C constant is `WSAECONNREFUSED`.
  @_alwaysEmitIntoClient
  public static var connectionRefused: Win32.Error { Win32.Error(rawValue: 10061) }

  /// The host is down.
  ///
  /// The corresponding C constant is `WSAEHOSTDOWN`.
  @_alwaysEmitIntoClient
  public static var hostIsDown: Win32.Error { Win32.Error(rawValue: 10064) }

  /// No route to the host.
  ///
  /// The corresponding C constant is `WSAEHOSTUNREACH`.
  @_alwaysEmitIntoClient
  public static var noRouteToHost: Win32.Error { Win32.Error(rawValue: 10065) }

  /// Too many processes are using Winsock.
  ///
  /// The corresponding C constant is `WSAEPROCLIM`.
  @_alwaysEmitIntoClient
  public static var tooManyProcesses: Win32.Error { Win32.Error(rawValue: 10067) }

  /// The network subsystem isn't ready, a failure to start Winsock.
  ///
  /// The corresponding C constant is `WSASYSNOTREADY`.
  @_alwaysEmitIntoClient
  public static var networkSubsystemNotReady: Win32.Error { Win32.Error(rawValue: 10091) }

  /// The Winsock version requested isn't supported, a failure to start
  /// Winsock.
  ///
  /// The corresponding C constant is `WSAVERNOTSUPPORTED`.
  @_alwaysEmitIntoClient
  public static var winsockVersionNotSupported: Win32.Error { Win32.Error(rawValue: 10092) }

  /// Winsock hasn't been started in this process.
  ///
  /// System starts it before it first creates a socket, so this appears
  /// only for a call on a socket that System didn't create, before anything
  /// in the process started Winsock.
  ///
  /// The corresponding C constant is `WSANOTINITIALISED`.
  @_alwaysEmitIntoClient
  public static var winsockNotStarted: Win32.Error { Win32.Error(rawValue: 10093) }
}

#endif // os(Windows)
