// SKETCH, not API: owned forms of the descriptor sub-types, and future
// noncopyable owners, built on OwnedFD. check.sh typechecks this file as a
// client of SystemPackage and SystemSockets, which is where the types would
// actually live: OwnedSocket in SystemSockets, the others in SystemPackage.
// The pattern for each owned kind:
//
// - It holds an OwnedFD and has no deinit of its own, so it inherits
//   OwnedFD's close policy (drop I/O errors, trap on EBADF).
// - It vends its kind's raw descriptor and the FileDescriptor, and forwards
//   nothing.
// - It converts to OwnedFD without a check, and from OwnedFD with
//   `init(unchecked:)`, or with a check done on the vended descriptor first.
// - Factories that return a new descriptor return it owned.

import SystemPackage
import SystemSockets
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Sockets: a sub-type with a raw type and its own operations

/// A socket that is closed exactly once. The owned form of SocketDescriptor.
@available(System 199, *)
struct OwnedSocket: ~Copyable, Sendable {
  // Internal rather than private, so that OwnedFD.init(_:) can take it.
  // In SystemSockets it would be internal there too.
  var _owner: OwnedFD

  /// Takes ownership of a descriptor that refers to a socket, without
  /// checking. To check first, convert its `fileDescriptor` with the
  /// throwing `SocketDescriptor.init(_:)` (see `adoptIfSocket` below).
  init(unchecked owner: consuming OwnedFD) { _owner = owner }

  /// Takes ownership of a socket descriptor.
  init(taking socket: SocketDescriptor) {
    _owner = OwnedFD(taking: socket.fileDescriptor)
  }

  /// The socket, for socket operations: bind, listen, send, options, ...
  var socketDescriptor: SocketDescriptor {
    SocketDescriptor(unchecked: _owner.fileDescriptor)
  }

  /// The socket as a file descriptor, for operations like stat or fcntl.
  var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  consuming func close() throws(Errno) { try _owner.close() }
  consuming func relinquish() -> SocketDescriptor {
    SocketDescriptor(unchecked: _owner.relinquish())
  }

  // Factories return owned sockets. SocketDescriptor's still throw untyped
  // errors, so these do too.
  static func open(
    _ domain: SocketDescriptor.Domain, _ type: SocketDescriptor.ConnectionType
  ) throws -> OwnedSocket {
    OwnedSocket(taking: try SocketDescriptor.open(domain, type))
  }

  func accept() throws -> OwnedSocket {
    OwnedSocket(taking: try socketDescriptor.accept())
  }

  /// Both ends of a connected socket pair. Like OwnedFD.Pipe, it has no
  /// deinit, and in SystemSockets it would be public and @frozen, so that
  /// clients could consume its ends separately (V13b).
  struct Pair: ~Copyable, Sendable {
    var first: OwnedSocket
    var second: OwnedSocket
  }

  static func pair(
    _ domain: SocketDescriptor.Domain, _ type: SocketDescriptor.ConnectionType
  ) throws -> Pair {
    let (first, second) = try SocketDescriptor.pair(domain, type)
    return Pair(first: OwnedSocket(taking: first), second: OwnedSocket(taking: second))
  }
}

@available(System 199, *)
extension OwnedFD {
  /// Every socket is a file descriptor, so this conversion always succeeds.
  init(_ socket: consuming OwnedSocket) { self = socket._owner }
}

// MARK: - Checked conversion from OwnedFD

// An error can't carry a noncopyable value, so a checked conversion that
// consumes its argument can't give it back on failure. Two ways around that:

/// 1. Check the vended descriptor first, then convert without a check. This
///    needs no new API: the checked conversion is the existing one on raw
///    descriptors.
@available(System 199, *)
func adoptIfSocket(_ received: consuming OwnedFD) throws(Errno) -> OwnedSocket {
  _ = try SocketDescriptor(received.fileDescriptor)  // throws ENOTSOCK; `received` closes
  return OwnedSocket(unchecked: received)
}

/// 2. A one-step conversion that returns the original on failure.
enum Narrowing<Narrowed: ~Copyable, Original: ~Copyable>: ~Copyable {
  case narrowed(Narrowed)
  case notNarrowed(Original, Errno)
}

@available(System 199, *)
extension OwnedSocket {
  static func narrowing(_ owner: consuming OwnedFD) -> Narrowing<OwnedSocket, OwnedFD> {
    do {
      _ = try SocketDescriptor(owner.fileDescriptor)
    } catch {
      return .notNarrowed(owner, error)
    }
    return .narrowed(OwnedSocket(unchecked: owner))
  }
}

@available(System 199, *)
func receivedDescriptor(_ owner: consuming OwnedFD) -> String {
  switch OwnedSocket.narrowing(owner) {
  case .narrowed(let socket):
    return "a socket, \(socket.socketDescriptor.rawValue)"
  case .notNarrowed(let owner, let error):
    return "not a socket (\(error)); still own \(owner.fileDescriptor.rawValue)"
  }
}

// MARK: - Terminals: no owned type

// Terminals are usually the standard streams, which OwnedFD's static lets
// represent without closing them, and TerminalDescriptor's operations work on
// a raw name. So a terminal needs no owned type: convert the vended
// descriptor, which works for standard input, a hard requirement.
@available(System 199, *)
func terminalWidth() throws(Errno) -> UInt16? {
  guard let terminal = OwnedFD.standardOutput.fileDescriptor.asTerminal else { return nil }
  return try terminal.windowSize().columns
}

// An opened terminal, such as /dev/tty, is an OwnedFD whose vended descriptor
// converts the same way.
@available(System 199, *)
func controllingTerminalRows() throws(Errno) -> UInt16? {
  let tty = try OwnedFD.open("/dev/tty", .readWrite)
  return try tty.fileDescriptor.asTerminal?.windowSize().rows
}

// MARK: - Future owners with no raw type: kqueue (and, on Linux, epoll, pidfd)

#if canImport(Darwin)
/// A kernel event queue that is closed exactly once.
///
/// A kqueue shares none of FileDescriptor's operations except close, so it
/// has no raw twin and forwards nothing. Its name is the FileDescriptor it
/// vends, to register it with poll(2) or another kqueue.
struct KernelQueue: ~Copyable, Sendable {
  private var owner: OwnedFD

  init() throws(Errno) {
    let raw = kqueue()
    guard raw >= 0 else { throw Errno(rawValue: errno) }
    owner = OwnedFD(taking: FileDescriptor(rawValue: raw))
  }

  var fileDescriptor: FileDescriptor { owner.fileDescriptor }
  consuming func close() throws(Errno) { try owner.close() }
  consuming func relinquish() -> FileDescriptor { owner.relinquish() }

  /// Watches `descriptor` for readability. The queue doesn't own it, and
  /// drops the registration when it's closed.
  func watchForReading(_ descriptor: FileDescriptor) throws(Errno) {
    var change = kevent(
      ident: UInt(descriptor.rawValue), filter: Int16(EVFILT_READ),
      flags: UInt16(EV_ADD), fflags: 0, data: 0, udata: nil)
    guard kevent(owner.fileDescriptor.rawValue, &change, 1, nil, 0, nil) >= 0 else {
      throw Errno(rawValue: errno)
    }
  }

  /// Waits up to `timeout` for events, and returns how many arrived.
  func wait(into events: UnsafeMutableBufferPointer<kevent>, timeout: timespec) throws(Errno) -> Int {
    var timeout = timeout
    let count = kevent(
      owner.fileDescriptor.rawValue, nil, 0, events.baseAddress, Int32(events.count), &timeout)
    guard count >= 0 else { throw Errno(rawValue: errno) }
    return Int(count)
  }
}

func readablePipes() throws(Errno) -> Int {
  let queue = try KernelQueue()
  let pipe = try OwnedFD.pipe()
  try queue.watchForReading(pipe.readEnd.fileDescriptor)
  try pipe.writeEnd.writeAll("x".utf8)
  // `[kevent](...)` would name Darwin's kevent function, not the struct.
  let empty = kevent(ident: 0, filter: 0, flags: 0, fflags: 0, data: 0, udata: nil)
  var events: [kevent] = Array(repeating: empty, count: 4)
  return try events.withUnsafeMutableBufferPointer { buffer throws(Errno) in
    try queue.wait(into: buffer, timeout: timespec(tv_sec: 0, tv_nsec: 0))
  }
}
#endif

#if os(Linux)
// Not typechecked on macOS; the same shape as KernelQueue.

/// An epoll instance that is closed exactly once.
struct EventPoll: ~Copyable, Sendable {
  private var owner: OwnedFD
  init(closeOnExec: Bool = true) throws(Errno) {
    let raw = epoll_create1(closeOnExec ? Int32(EPOLL_CLOEXEC) : 0)
    guard raw >= 0 else { throw Errno(rawValue: errno) }
    owner = OwnedFD(taking: FileDescriptor(rawValue: raw))
  }
  var fileDescriptor: FileDescriptor { owner.fileDescriptor }
  consuming func close() throws(Errno) { try owner.close() }
  // add(_:events:), modify, remove, and wait(into:timeout:) take and return
  // raw FileDescriptor names; the instance never owns what it watches.
}

/// A process descriptor (pidfd) that is closed exactly once. Owning it is an
/// obligation to close the descriptor, not to reap the process; reaping is
/// the separate "responsibility" role for processes (Next/Vision.md,
/// direction 3).
struct ProcessDescriptor: ~Copyable, Sendable {
  private var owner: OwnedFD
  let processID: ProcessID
  // init(_ process: ProcessID) throws(Errno) wraps pidfd_open;
  // sendSignal(_:) wraps pidfd_send_signal; wait() wraps waitid(P_PIDFD).
  var fileDescriptor: FileDescriptor { owner.fileDescriptor }
  consuming func close() throws(Errno) { try owner.close() }
}
#endif

// MARK: - The multi-platform enum's owned cases wrap these types

/// Next/Vision.md, direction 4: an open enum whose owned cases wrap the
/// platform's owned types. Common operations switch over it; anything else
/// reaches into a case. (On Windows, a case would wrap an owned HANDLE.)
@available(System 199, *)
enum OwnedDescriptor: ~Copyable {
  case file(OwnedFD)
  case socket(OwnedSocket)

  var fileDescriptor: FileDescriptor {
    switch self {
    case .file(let owner): return owner.fileDescriptor
    case .socket(let socket): return socket.fileDescriptor
    }
  }

  consuming func close() throws(Errno) {
    switch consume self {
    case .file(let owner): try owner.close()
    case .socket(let socket): try socket.close()
    }
  }
}
