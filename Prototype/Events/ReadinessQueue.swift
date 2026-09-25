// SKETCH, not API: a cross-platform readiness layer over System's event
// queues, as a multi-platform enum (Next/Vision.md, direction 4). Its cases
// wrap each platform's owner, so single-platform code never touches it.
// check.sh typechecks the kqueue half as a client of SystemPackage, and
// check-linux.sh typechecks the epoll half against its model of Linux.
// README.md says what it shows, and why System shouldn't ship it.

import SystemPackage

/// The readiness to watch a descriptor for.
struct Interest: OptionSet, Hashable, Sendable {
  var rawValue: UInt8
  static var read: Interest { Interest(rawValue: 1 << 0) }
  static var write: Interest { Interest(rawValue: 1 << 1) }
}

/// A descriptor's readiness, in terms that both kqueue and epoll can report.
struct Readiness: Hashable, Sendable {
  /// The value that the descriptor was registered with.
  var token: UInt32
  var interest: Interest
  /// kqueue's EV_EOF, or epoll's EPOLLRDHUP or EPOLLHUP.
  var endOfFile: Bool
  /// kqueue's socket error in fflags with EV_EOF, or epoll's EPOLLERR.
  var error: Bool
}

@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum ReadinessQueue: ~Copyable {
  #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
  /// One queue does it all: descriptors, the wake-up (a user event),
  /// and timeouts to the nanosecond.
  case kernelQueue(KernelQueue)
  #elseif os(Linux) || os(Android)
  /// epoll needs a second owner to wake it: an eventfd that it watches.
  /// The two are one struct, because in Swift 6.2 a case with two
  /// noncopyable payloads fails a borrowing switch with "copy of
  /// noncopyable typed value. This is a compiler bug".
  case eventPoll(EventPollSelector)
  #endif
  // No Windows case: IOCP reports completed I/O, not readiness, so it
  // can't implement these operations (README.md).

  /// The token that wake-ups report, which descriptors can't use.
  static var wakeUpToken: UInt32 { .max }

  init() throws(Errno) {
    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    let queue = try KernelQueue()
    try queue.register(KernelEvent(
      identifier: 0, filter: .user, flags: [.add, .clear],
      userData: Self.userData(Self.wakeUpToken)))
    self = .kernelQueue(queue)
    #elseif os(Linux) || os(Android)
    let epoll = try EventPoll(options: .closeOnExec)
    let wakeUp = try EventCounter(options: [.closeOnExec, .nonBlocking])
    try epoll.add(
      wakeUp.fileDescriptor, events: .readable,
      data: EventPoll.Event.Data(rawValue: UInt64(Self.wakeUpToken)))
    self = .eventPoll(EventPollSelector(epoll: epoll, wakeUp: wakeUp))
    #endif
  }

  /// Starts watching a descriptor.
  func register(_ fd: FileDescriptor, interest: Interest, token: UInt32) throws(Errno) {
    try reregister(fd, from: [], to: interest, token: token)
  }

  /// Changes what a descriptor is watched for. kqueue has a registration
  /// per filter rather than a mask per descriptor, so the caller must
  /// remember the previous interest, as NIO's selector does.
  func reregister(
    _ fd: FileDescriptor, from old: Interest, to new: Interest, token: UInt32
  ) throws(Errno) {
    switch self {
    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    case .kernelQueue(let queue):
      var changes: [KernelEvent] = []
      for (interest, filter) in [(Interest.read, KernelEvent.Filter.read), (.write, .write)]
      where old.contains(interest) != new.contains(interest) {
        changes.append(KernelEvent(
          fd, filter: filter, flags: new.contains(interest) ? .add : .delete,
          userData: Self.userData(token)))
      }
      for change in changes { try queue.register(change) }
    #elseif os(Linux) || os(Android)
    case .eventPoll(let selector):
      let data = EventPoll.Event.Data(rawValue: UInt64(token))
      if old.isEmpty {
        try selector.epoll.add(fd, events: Self.mask(new), data: data)
      } else if new.isEmpty {
        try selector.epoll.remove(fd)
      } else {
        try selector.epoll.modify(fd, events: Self.mask(new), data: data)
      }
    #endif
    }
  }

  /// Wakes a thread that's waiting, from any thread.
  func wakeUp() throws(Errno) {
    switch self {
    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    case .kernelQueue(let queue):
      try queue.register(KernelEvent(identifier: 0, filter: .user, filterFlags: .userTrigger))
    #elseif os(Linux) || os(Android)
    case .eventPoll(let selector):
      try selector.wakeUp.increment()
    #endif
    }
  }

  /// Waits for readiness, and calls `body` with each event.
  ///
  /// The platform's events have a different type, so they can't be
  /// written straight into a caller's OutputSpan<Readiness>: this waits
  /// into a buffer of its own, and translates. A wake-up has the
  /// `wakeUpToken`. On Linux, the timeout has millisecond precision.
  func wait(timeout: Duration?, _ body: (Readiness) throws -> Void) throws {
    switch self {
    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    case .kernelQueue(let queue):
      try withUnsafeTemporaryAllocation(of: KernelEvent.self, capacity: 64) { buffer in
        var events = OutputSpan(buffer: buffer, initializedCount: 0)
        try queue.poll(into: &events, timeout: timeout)
        let count = events.finalize(for: buffer)
        for event in buffer[..<count] {
          if let error = event.registrationError { throw error }
          // Each filter is its own event, so a descriptor that's readable
          // and writable is reported twice.
          try body(Readiness(
            token: UInt32(truncatingIfNeeded: UInt(bitPattern: event.userData)),
            interest: event.filter == .write ? .write : event.filter == .read ? .read : [],
            endOfFile: event.flags.contains(.endOfFile),
            error: event.flags.contains(.endOfFile) && event.filterFlags != []))
        }
      }
    #elseif os(Linux) || os(Android)
    case .eventPoll(let selector):
      try withUnsafeTemporaryAllocation(of: EventPoll.Event.self, capacity: 64) { buffer in
        var events = OutputSpan(buffer: buffer, initializedCount: 0)
        try selector.epoll.wait(into: &events, timeout: timeout)
        let count = events.finalize(for: buffer)
        for event in buffer[..<count] {
          let token = UInt32(truncatingIfNeeded: event.data.rawValue)
          if token == Self.wakeUpToken { _ = try? selector.wakeUp.read() }
          var interest: Interest = []
          if event.events.contains(.readable) { interest.insert(.read) }
          if event.events.contains(.writable) { interest.insert(.write) }
          try body(Readiness(
            token: token, interest: interest,
            endOfFile: !event.events.isDisjoint(with: [.readHangUp, .hangUp]),
            error: event.events.contains(.error)))
        }
      }
    #endif
    }
  }

  consuming func close() throws(Errno) {
    switch consume self {
    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    case .kernelQueue(let queue):
      try queue.close()
    #elseif os(Linux) || os(Android)
    case .eventPoll(let selector):
      try selector.close()
    #endif
    }
  }

  #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
  static func userData(_ token: UInt32) -> UnsafeMutableRawPointer? {
    UnsafeMutableRawPointer(bitPattern: UInt(token))
  }
  #elseif os(Linux) || os(Android)
  static func mask(_ interest: Interest) -> EventPoll.Event.Mask {
    var mask: EventPoll.Event.Mask = [.readHangUp]
    if interest.contains(.read) { mask.insert(.readable) }
    if interest.contains(.write) { mask.insert(.writable) }
    return mask
  }
  #endif
}

#if os(Linux) || os(Android)
/// An epoll instance, and the event counter that wakes it.
@available(System 199, *)
struct EventPollSelector: ~Copyable {
  var epoll: EventPoll
  var wakeUp: EventCounter

  /// Closes both, whether or not either fails, and throws the first error.
  consuming func close() throws(Errno) {
    let epoll = self.epoll
    let wakeUp = self.wakeUp
    var failure: Errno? = nil
    do throws(Errno) { try epoll.close() } catch { failure = error }
    do throws(Errno) { try wakeUp.close() } catch { failure = failure ?? error }
    if let failure { throw failure }
  }
}
#endif

/// Cross-platform code, which never mentions kqueue or epoll.
@available(System 199, *)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
func echoOnce(_ input: FileDescriptor) throws -> [Readiness] {
  let queue = try ReadinessQueue()
  try queue.register(input, interest: .read, token: 7)
  var seen: [Readiness] = []
  try queue.wait(timeout: .seconds(1)) { seen.append($0) }
  try queue.close()
  return seen
}
