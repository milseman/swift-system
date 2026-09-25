/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// kqueue exists on Darwin, FreeBSD, and OpenBSD.
#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)

// Must import here to use the C kevent type in @_alwaysEmitIntoClient APIs.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported Platform")
#endif

@available(System 199, *)
extension CInterop {
  /// The C `kevent` type, which describes an event
  /// that a kernel queue watches for or reports.
  public typealias KEvent = kevent
}

/// An event that a kernel queue watches for, or reports.
///
/// To start watching for an event, register it with a ``KernelQueue``.
/// Its ``identifier`` and ``filter`` name what to watch,
/// such as a file descriptor becoming readable,
/// and its ``flags`` say what to do with the registration,
/// such as adding it.
/// When the event happens, the queue reports it
/// with the same identifier, filter, and ``userData``,
/// and with ``data`` and ``filterFlags`` that describe what happened.
///
///     let readable = KernelEvent(pipe.readEnd.fileDescriptor, filter: .read, flags: .add)
///     try queue.register(readable)
///
/// The corresponding C type is `struct kevent`.
@frozen
@available(System 199, *)
public struct KernelEvent: RawRepresentable, @unchecked Sendable {
  // The user data is a value that the kernel passes back unchanged;
  // nothing here dereferences it, so it's safe to send.

  /// The raw C kernel event.
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.KEvent

  /// Creates a strongly-typed kernel event from a raw C kernel event.
  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.KEvent) { self.rawValue = rawValue }
}

@available(System 199, *)
extension KernelEvent {
  /// Creates a kernel event.
  ///
  /// - Parameters:
  ///   - identifier: The source of the event, which the filter interprets:
  ///     a file descriptor, a process ID, a signal number,
  ///     or a number that you choose for a timer or a user event.
  ///   - filter: The kind of event.
  ///   - flags: What to do with the registration, such as adding it,
  ///     and how to report the event, such as only once.
  ///     The default is none,
  ///     which changes nothing but the user data of a user event.
  ///   - filterFlags: Options for the filter,
  ///     such as which changes to a file to report.
  ///     The default is none.
  ///   - data: A value for the filter, such as a timer's period.
  ///     The default is `0`.
  ///   - userData: A value that the queue returns with the event.
  ///     The default is `nil`.
  @_alwaysEmitIntoClient
  public init(
    identifier: UInt,
    filter: Filter,
    flags: Flags = [],
    filterFlags: FilterFlags = [],
    data: Int = 0,
    userData: UnsafeMutableRawPointer? = nil
  ) {
    self.init(rawValue: CInterop.KEvent())
    self.identifier = identifier
    self.filter = filter
    self.flags = flags
    self.filterFlags = filterFlags
    self.data = data
    self.userData = userData
  }

  /// Creates a kernel event whose identifier is a file descriptor,
  /// as the read, write, and vnode filters take.
  ///
  /// The queue doesn't take ownership of the file descriptor.
  /// Closing the descriptor removes its events from every queue.
  ///
  /// See ``init(identifier:filter:flags:filterFlags:data:userData:)``
  /// for the other parameters.
  @_alwaysEmitIntoClient
  public init(
    _ fileDescriptor: FileDescriptor,
    filter: Filter,
    flags: Flags = [],
    filterFlags: FilterFlags = [],
    data: Int = 0,
    userData: UnsafeMutableRawPointer? = nil
  ) {
    self.init(
      identifier: UInt(bitPattern: Int(fileDescriptor.rawValue)),
      filter: filter, flags: flags, filterFlags: filterFlags,
      data: data, userData: userData)
  }

  /// The source of the event, which the filter interprets:
  /// a file descriptor, a process ID, a signal number,
  /// or a number that you choose for a timer or a user event.
  ///
  /// The corresponding C field is `ident`.
  @_alwaysEmitIntoClient
  public var identifier: UInt {
    get { rawValue.ident }
    set { rawValue.ident = newValue }
  }

  /// The identifier, as a file descriptor.
  ///
  /// Use this property for an event from a filter
  /// that identifies a file descriptor, such as ``Filter/read``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor {
    FileDescriptor(rawValue: CInt(truncatingIfNeeded: Int(bitPattern: identifier)))
  }

  /// The kind of event.
  ///
  /// The corresponding C field is `filter`.
  @_alwaysEmitIntoClient
  public var filter: Filter {
    get { Filter(rawValue: rawValue.filter) }
    set { rawValue.filter = newValue.rawValue }
  }

  /// What to do with the registration, and how to report the event,
  /// or, in a reported event, conditions that the queue found.
  ///
  /// The corresponding C field is `flags`.
  @_alwaysEmitIntoClient
  public var flags: Flags {
    get { Flags(rawValue: rawValue.flags) }
    set { rawValue.flags = newValue.rawValue }
  }

  /// Options for the filter,
  /// or, in a reported event, what the filter found.
  ///
  /// The corresponding C field is `fflags`.
  @_alwaysEmitIntoClient
  public var filterFlags: FilterFlags {
    get { FilterFlags(rawValue: rawValue.fflags) }
    set { rawValue.fflags = newValue.rawValue }
  }

  /// A value for the filter, such as a timer's period,
  /// or, in a reported event, a value from the filter,
  /// such as the number of bytes that are ready to read.
  ///
  /// The corresponding C field is `data`.
  @_alwaysEmitIntoClient
  public var data: Int {
    // FreeBSD and OpenBSD declare `data` as a 64-bit integer, which is
    // the size of Int on every platform where Swift runs on them.
    get { Int(truncatingIfNeeded: rawValue.data) }
    set { rawValue.data = .init(truncatingIfNeeded: newValue) }
  }

  /// A value that the queue returns unchanged with the event.
  ///
  /// The queue never dereferences this pointer,
  /// so it can hold any pointer-sized value, such as an index.
  ///
  /// The corresponding C field is `udata`.
  @_alwaysEmitIntoClient
  public var userData: UnsafeMutableRawPointer? {
    get { rawValue.udata }
    set { rawValue.udata = newValue }
  }

  /// The error from registering this event, if registering it failed.
  ///
  /// When a change that you pass to
  /// ``KernelQueue/registerAndPoll(_:into:timeout:retryOnInterrupt:)``
  /// fails, and the list of events has room,
  /// the queue reports the failure as an event with the ``Flags/error`` flag
  /// and the error number in ``data``, rather than throwing an error.
  /// The queue always reports a change with the ``Flags/receipt`` flag
  /// that way, with a `data` of zero if the change succeeded.
  ///
  /// This property is `nil` for an event without the `error` flag,
  /// and for the receipt of a change that succeeded.
  @_alwaysEmitIntoClient
  public var registrationError: Errno? {
    guard flags.contains(.error), data != 0 else { return nil }
    return Errno(rawValue: CInt(truncatingIfNeeded: data))
  }
}

@available(System 199, *)
extension KernelEvent: Hashable {
  /// Returns whether two kernel events have the same fields.
  @_alwaysEmitIntoClient
  public static func == (lhs: KernelEvent, rhs: KernelEvent) -> Bool {
    lhs.identifier == rhs.identifier
      && lhs.filter == rhs.filter
      && lhs.flags == rhs.flags
      && lhs.filterFlags == rhs.filterFlags
      && lhs.data == rhs.data
      && lhs.userData == rhs.userData
  }

  /// Hashes the kernel event's fields.
  @_alwaysEmitIntoClient
  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
    hasher.combine(filter)
    hasher.combine(flags)
    hasher.combine(filterFlags)
    hasher.combine(data)
    hasher.combine(userData)
  }
}

// MARK: - Flags

@available(System 199, *)
extension KernelEvent {
  /// What to do with a kernel event's registration,
  /// and how to report the event.
  ///
  /// A reported event can also include flags that describe
  /// conditions the queue found, such as ``endOfFile``.
  @frozen
  public struct Flags: OptionSet, Hashable, Sendable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: UInt16

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt16) { self.rawValue = rawValue }

    /// Adds the event to the queue,
    /// or updates it if the queue already has an event
    /// with the same identifier and filter.
    ///
    /// Adding an event also enables it, unless you include ``disable``.
    ///
    /// The corresponding C constant is `EV_ADD`.
    @_alwaysEmitIntoClient
    public static var add: Flags { Flags(rawValue: _EV_ADD) }

    /// Removes the event from the queue.
    ///
    /// Closing a file descriptor removes its events from every queue,
    /// so they don't need to be deleted.
    ///
    /// The corresponding C constant is `EV_DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: Flags { Flags(rawValue: _EV_DELETE) }

    /// Lets the queue report the event.
    ///
    /// The corresponding C constant is `EV_ENABLE`.
    @_alwaysEmitIntoClient
    public static var enable: Flags { Flags(rawValue: _EV_ENABLE) }

    /// Stops the queue from reporting the event, without removing it.
    ///
    /// The corresponding C constant is `EV_DISABLE`.
    @_alwaysEmitIntoClient
    public static var disable: Flags { Flags(rawValue: _EV_DISABLE) }

    /// Removes the event after the queue reports it once.
    ///
    /// The corresponding C constant is `EV_ONESHOT`.
    @_alwaysEmitIntoClient
    public static var oneShot: Flags { Flags(rawValue: _EV_ONESHOT) }

    /// Resets the event's state after the queue reports it,
    /// so that the queue reports it again only when it happens again.
    ///
    /// Use this flag with filters that report changes, rather than states.
    /// Some filters, such as ``Filter/timer``, set it themselves.
    ///
    /// The corresponding C constant is `EV_CLEAR`.
    @_alwaysEmitIntoClient
    public static var clear: Flags { Flags(rawValue: _EV_CLEAR) }

    /// Reports the result of registering the event,
    /// rather than any pending events.
    ///
    /// With this flag, registering an event always places it in the list of
    /// reported events, with the ``error`` flag, and with a ``KernelEvent/data``
    /// of zero if registering it succeeded,
    /// or an error number if it failed.
    /// Use it to apply a batch of changes and learn the result of each.
    ///
    /// The corresponding C constant is `EV_RECEIPT`.
    @_alwaysEmitIntoClient
    public static var receipt: Flags { Flags(rawValue: _EV_RECEIPT) }

    /// Disables the event after the queue reports it,
    /// until you enable it again.
    ///
    /// The corresponding C constant is `EV_DISPATCH`.
    @_alwaysEmitIntoClient
    public static var dispatch: Flags { Flags(rawValue: _EV_DISPATCH) }

    #if SYSTEM_PACKAGE_DARWIN
    /// Makes the user data part of the event's identity,
    /// so that a queue can hold several events with the same identifier
    /// and filter, and different user data.
    ///
    /// The corresponding C constant is `EV_UDATA_SPECIFIC`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var userDataSpecific: Flags { Flags(rawValue: _EV_UDATA_SPECIFIC) }
    #endif

    /// In a reported event, indicates an end-of-file condition,
    /// such as a pipe's last writer closing it.
    ///
    /// For a socket, the event's ``KernelEvent/filterFlags``
    /// hold the socket's error number, if it has one.
    ///
    /// The corresponding C constant is `EV_EOF`.
    @_alwaysEmitIntoClient
    public static var endOfFile: Flags { Flags(rawValue: _EV_EOF) }

    /// In a reported event, indicates the result of registering it:
    /// see ``KernelEvent/registrationError``.
    ///
    /// The corresponding C constant is `EV_ERROR`.
    @_alwaysEmitIntoClient
    public static var error: Flags { Flags(rawValue: _EV_ERROR) }

    #if SYSTEM_PACKAGE_DARWIN
    /// In an event that the read filter reports for a socket,
    /// indicates that the socket has out-of-band data.
    ///
    /// The corresponding C constant is `EV_OOBAND`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var outOfBand: Flags { Flags(rawValue: _EV_OOBAND) }
    #endif
  }
}

// MARK: - Filters

@available(System 199, *)
extension KernelEvent {
  /// A kind of kernel event, and the code in the kernel that detects it.
  @frozen
  public struct Filter: RawRepresentable, Hashable, Sendable {
    /// The raw C filter.
    @_alwaysEmitIntoClient
    public var rawValue: Int16

    /// Creates a strongly-typed filter from a raw C filter.
    @_alwaysEmitIntoClient
    public init(rawValue: Int16) { self.rawValue = rawValue }

    /// Reports when a file descriptor has data to read.
    ///
    /// The identifier is a file descriptor.
    /// A reported event's ``KernelEvent/data`` is the number of bytes
    /// available to read, or, for a listening socket,
    /// the number of connections waiting to be accepted.
    /// The event includes ``Flags/endOfFile``
    /// when the writing end of a pipe or socket closes.
    ///
    /// The corresponding C constant is `EVFILT_READ`.
    @_alwaysEmitIntoClient
    public static var read: Filter { Filter(rawValue: _EVFILT_READ) }

    /// Reports when writing to a file descriptor won't block.
    ///
    /// The identifier is a file descriptor.
    /// A reported event's ``KernelEvent/data`` is the space left
    /// in the write buffer, for a pipe or socket.
    ///
    /// The corresponding C constant is `EVFILT_WRITE`.
    @_alwaysEmitIntoClient
    public static var write: Filter { Filter(rawValue: _EVFILT_WRITE) }

    #if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
    /// Reports exceptional conditions on a file descriptor,
    /// such as a socket's out-of-band data.
    ///
    /// The identifier is a file descriptor,
    /// and the ``KernelEvent/filterFlags`` say which conditions to report.
    ///
    /// The corresponding C constant is `EVFILT_EXCEPT`.
    ///
    /// - Note: Only available on Darwin and OpenBSD.
    @_alwaysEmitIntoClient
    public static var exceptional: Filter { Filter(rawValue: _EVFILT_EXCEPT) }
    #endif

    /// Reports changes to a file, such as a write or a rename.
    ///
    /// The identifier is a file descriptor,
    /// and the ``KernelEvent/filterFlags`` say which changes to report,
    /// such as ``FilterFlags/vnodeWrite``.
    /// A reported event's filter flags are the changes that happened.
    ///
    /// The corresponding C constant is `EVFILT_VNODE`.
    @_alwaysEmitIntoClient
    public static var vnode: Filter { Filter(rawValue: _EVFILT_VNODE) }

    /// Reports what a process does, such as exiting.
    ///
    /// The identifier is a process ID,
    /// and the ``KernelEvent/filterFlags`` say what to report,
    /// such as ``FilterFlags/processExit``.
    ///
    /// The corresponding C constant is `EVFILT_PROC`.
    @_alwaysEmitIntoClient
    public static var process: Filter { Filter(rawValue: _EVFILT_PROC) }

    #if os(FreeBSD)
    /// Reports what the process that a process descriptor refers to does,
    /// such as exiting.
    ///
    /// The identifier is a process descriptor, from `pdfork`.
    ///
    /// The corresponding C constant is `EVFILT_PROCDESC`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var processDescriptor: Filter { Filter(rawValue: _EVFILT_PROCDESC) }
    #endif

    /// Reports when the process receives a signal,
    /// even one that the process ignores.
    ///
    /// The identifier is the signal number.
    /// A reported event's ``KernelEvent/data`` is the number of times
    /// the signal arrived since the last report.
    /// This filter doesn't change how the process handles the signal.
    ///
    /// The corresponding C constant is `EVFILT_SIGNAL`.
    @_alwaysEmitIntoClient
    public static var signal: Filter { Filter(rawValue: _EVFILT_SIGNAL) }

    /// Reports when a timer expires.
    ///
    /// The identifier is a number that you choose,
    /// and the ``KernelEvent/data`` is the timer's period,
    /// in milliseconds unless the filter flags give another unit.
    /// The timer repeats unless you include ``Flags/oneShot``.
    /// A reported event's data is the number of times the timer expired
    /// since the last report.
    ///
    /// The corresponding C constant is `EVFILT_TIMER`.
    @_alwaysEmitIntoClient
    public static var timer: Filter { Filter(rawValue: _EVFILT_TIMER) }

    /// Reports when you trigger an event yourself,
    /// such as to wake a thread that's waiting on the queue.
    ///
    /// The identifier is a number that you choose.
    /// To trigger the event, register it again
    /// with ``FilterFlags/userTrigger``.
    ///
    /// The corresponding C constant is `EVFILT_USER`.
    @_alwaysEmitIntoClient
    public static var user: Filter { Filter(rawValue: _EVFILT_USER) }

    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    /// Reports changes to the set of mounted file systems.
    ///
    /// The corresponding C constant is `EVFILT_FS`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var fileSystem: Filter { Filter(rawValue: _EVFILT_FS) }
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    /// Reports when a Mach port, or a port set, has a message.
    ///
    /// The identifier is the name of the port or port set.
    ///
    /// The corresponding C constant is `EVFILT_MACHPORT`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var machPort: Filter { Filter(rawValue: _EVFILT_MACHPORT) }
    #endif
  }
}

// MARK: - Filter flags

@available(System 199, *)
extension KernelEvent {
  /// Options for a kernel event's filter,
  /// or what the filter found.
  ///
  /// Each filter has its own flags, which this type combines:
  /// their names start with the filter's, as ``vnodeWrite`` does,
  /// except for the read and write filters' ``lowWatermark``.
  /// Flags for different filters can have the same value,
  /// so use only the flags for the event's filter.
  @frozen
  public struct FilterFlags: OptionSet, Hashable, Sendable {
    /// The raw C filter flags.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed set of filter flags from raw C filter flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    // MARK: Read, write, and exceptional conditions

    /// Reports the event only when at least as many bytes as
    /// the event's ``KernelEvent/data`` are ready,
    /// rather than the socket's usual low-water mark.
    ///
    /// The corresponding C constant is `NOTE_LOWAT`.
    @_alwaysEmitIntoClient
    public static var lowWatermark: Self { Self(rawValue: _NOTE_LOWAT) }

    #if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
    /// For the exceptional filter, reports a socket's out-of-band data.
    ///
    /// The corresponding C constant is `NOTE_OOB`.
    ///
    /// - Note: Only available on Darwin and OpenBSD.
    @_alwaysEmitIntoClient
    public static var outOfBand: Self { Self(rawValue: _NOTE_OOB) }
    #endif

    // MARK: Vnode

    /// The file was unlinked.
    ///
    /// The corresponding C constant is `NOTE_DELETE`.
    @_alwaysEmitIntoClient
    public static var vnodeDelete: Self { Self(rawValue: _NOTE_DELETE) }

    /// The file was written to.
    ///
    /// The corresponding C constant is `NOTE_WRITE`.
    @_alwaysEmitIntoClient
    public static var vnodeWrite: Self { Self(rawValue: _NOTE_WRITE) }

    /// The file grew.
    ///
    /// The corresponding C constant is `NOTE_EXTEND`.
    @_alwaysEmitIntoClient
    public static var vnodeExtend: Self { Self(rawValue: _NOTE_EXTEND) }

    /// The file's attributes changed.
    ///
    /// The corresponding C constant is `NOTE_ATTRIB`.
    @_alwaysEmitIntoClient
    public static var vnodeAttributes: Self { Self(rawValue: _NOTE_ATTRIB) }

    /// The file's link count changed.
    ///
    /// The corresponding C constant is `NOTE_LINK`.
    @_alwaysEmitIntoClient
    public static var vnodeLink: Self { Self(rawValue: _NOTE_LINK) }

    /// The file was renamed.
    ///
    /// The corresponding C constant is `NOTE_RENAME`.
    @_alwaysEmitIntoClient
    public static var vnodeRename: Self { Self(rawValue: _NOTE_RENAME) }

    /// Access to the file was revoked,
    /// or its file system was unmounted.
    ///
    /// The corresponding C constant is `NOTE_REVOKE`.
    @_alwaysEmitIntoClient
    public static var vnodeRevoke: Self { Self(rawValue: _NOTE_REVOKE) }

    #if SYSTEM_PACKAGE_DARWIN
    /// The file was unlocked, by `flock` or by closing it.
    ///
    /// The corresponding C constant is `NOTE_FUNLOCK`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var vnodeUnlock: Self { Self(rawValue: _NOTE_FUNLOCK) }
    #endif

    // MARK: Process

    /// The process exited.
    ///
    /// The corresponding C constant is `NOTE_EXIT`.
    @_alwaysEmitIntoClient
    public static var processExit: Self { Self(rawValue: _NOTE_EXIT) }

    /// The process created a child process.
    ///
    /// The corresponding C constant is `NOTE_FORK`.
    @_alwaysEmitIntoClient
    public static var processFork: Self { Self(rawValue: _NOTE_FORK) }

    /// The process executed a new program.
    ///
    /// The corresponding C constant is `NOTE_EXEC`.
    @_alwaysEmitIntoClient
    public static var processExec: Self { Self(rawValue: _NOTE_EXEC) }

    #if SYSTEM_PACKAGE_DARWIN
    /// The process received a signal.
    ///
    /// The corresponding C constant is `NOTE_SIGNAL`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var processSignal: Self { Self(rawValue: _NOTE_SIGNAL) }

    /// Together with ``processExit``, reports the exit status of a child
    /// process in the event's ``KernelEvent/data``.
    ///
    /// The corresponding C constant is `NOTE_EXITSTATUS`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var processExitStatus: Self { Self(rawValue: _NOTE_EXITSTATUS) }
    #endif

    #if os(FreeBSD) || os(OpenBSD)
    /// Follows the process's children, registering the same events for each.
    ///
    /// The corresponding C constant is `NOTE_TRACK`.
    ///
    /// - Note: Only available on FreeBSD and OpenBSD.
    @_alwaysEmitIntoClient
    public static var processTrack: Self { Self(rawValue: _NOTE_TRACK) }
    #endif

    // MARK: Timer

    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    /// The timer's ``KernelEvent/data`` is in seconds.
    ///
    /// The corresponding C constant is `NOTE_SECONDS`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerSeconds: Self { Self(rawValue: _NOTE_SECONDS) }

    /// The timer's ``KernelEvent/data`` is in microseconds.
    ///
    /// The corresponding C constant is `NOTE_USECONDS`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerMicroseconds: Self { Self(rawValue: _NOTE_USECONDS) }

    /// The timer's ``KernelEvent/data`` is in nanoseconds.
    ///
    /// The corresponding C constant is `NOTE_NSECONDS`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerNanoseconds: Self { Self(rawValue: _NOTE_NSECONDS) }
    #endif

    #if os(FreeBSD)
    /// The timer's ``KernelEvent/data`` is in milliseconds, the default.
    ///
    /// The corresponding C constant is `NOTE_MSECONDS`.
    ///
    /// - Note: Only available on FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerMilliseconds: Self { Self(rawValue: _NOTE_MSECONDS) }

    /// The timer's ``KernelEvent/data`` is an absolute time,
    /// rather than a period.
    ///
    /// The corresponding C constant is `NOTE_ABSTIME`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerAbsolute: Self { Self(rawValue: _NOTE_ABSTIME) }
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    /// The timer's ``KernelEvent/data`` is an absolute time,
    /// rather than a period, and the timer expires once.
    ///
    /// The time is in the timer's unit,
    /// since the epoch that `gettimeofday` measures from,
    /// or, with ``timerMachTime``, in the terms of `mach_absolute_time`.
    ///
    /// The corresponding C constant is `NOTE_ABSOLUTE`.
    ///
    /// - Note: Only available on Darwin and FreeBSD.
    @_alwaysEmitIntoClient
    public static var timerAbsolute: Self { Self(rawValue: _NOTE_ABSOLUTE) }

    /// The timer's ``KernelEvent/data`` is in Mach absolute time units.
    ///
    /// The corresponding C constant is `NOTE_MACHTIME`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var timerMachTime: Self { Self(rawValue: _NOTE_MACHTIME) }

    /// Holds the timer closer to its deadline,
    /// rather than saving power by coalescing it with other timers.
    ///
    /// The corresponding C constant is `NOTE_CRITICAL`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var timerCritical: Self { Self(rawValue: _NOTE_CRITICAL) }

    /// Saves more power by coalescing the timer with other timers.
    ///
    /// The corresponding C constant is `NOTE_BACKGROUND`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var timerBackground: Self { Self(rawValue: _NOTE_BACKGROUND) }

    /// Uses a leeway for coalescing the timer that the event specifies.
    ///
    /// `kevent` has nowhere to put the leeway: it takes one only through
    /// `kevent64` and `kevent_qos`, which System doesn't wrap yet.
    ///
    /// The corresponding C constant is `NOTE_LEEWAY`.
    ///
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var timerLeeway: Self { Self(rawValue: _NOTE_LEEWAY) }
    #endif

    // MARK: User

    /// Triggers the user event, so that the queue reports it.
    ///
    /// The corresponding C constant is `NOTE_TRIGGER`.
    @_alwaysEmitIntoClient
    public static var userTrigger: Self { Self(rawValue: _NOTE_TRIGGER) }

    /// Leaves the user event's stored flags unchanged.
    ///
    /// This value is zero, the same as an empty set.
    ///
    /// The corresponding C constant is `NOTE_FFNOP`.
    @_alwaysEmitIntoClient
    public static var userNoOperation: Self { Self(rawValue: _NOTE_FFNOP) }

    /// Combines the flags in ``userFlagsMask`` with the user event's
    /// stored flags, with a bitwise AND.
    ///
    /// The corresponding C constant is `NOTE_FFAND`.
    @_alwaysEmitIntoClient
    public static var userAnd: Self { Self(rawValue: _NOTE_FFAND) }

    /// Combines the flags in ``userFlagsMask`` with the user event's
    /// stored flags, with a bitwise OR.
    ///
    /// The corresponding C constant is `NOTE_FFOR`.
    @_alwaysEmitIntoClient
    public static var userOr: Self { Self(rawValue: _NOTE_FFOR) }

    /// Replaces the user event's stored flags
    /// with the flags in ``userFlagsMask``.
    ///
    /// The corresponding C constant is `NOTE_FFCOPY`.
    @_alwaysEmitIntoClient
    public static var userCopy: Self { Self(rawValue: _NOTE_FFCOPY) }

    /// The bits that say how to combine a user event's flags:
    /// ``userAnd``, ``userOr``, or ``userCopy``.
    ///
    /// The corresponding C constant is `NOTE_FFCTRLMASK`.
    @_alwaysEmitIntoClient
    public static var userControlMask: Self { Self(rawValue: _NOTE_FFCTRLMASK) }

    /// The 24 bits that a user event stores, for any use.
    ///
    /// The corresponding C constant is `NOTE_FFLAGSMASK`.
    @_alwaysEmitIntoClient
    public static var userFlagsMask: Self { Self(rawValue: _NOTE_FFLAGSMASK) }
  }
}

// MARK: - Descriptions

@available(System 199, *)
extension KernelEvent: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the kernel event.
  @inline(never)
  public var description: String {
    let userData = self.userData.map { "\($0)" } ?? "nil"
    return "KernelEvent(identifier: \(identifier), filter: \(filter), "
      + "flags: \(flags), filterFlags: 0x\(String(filterFlags.rawValue, radix: 16)), "
      + "data: \(data), userData: \(userData))"
  }

  /// A textual representation of the kernel event, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension KernelEvent.Flags: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the flags.
  @inline(never)
  public var description: String {
    #if SYSTEM_PACKAGE_DARWIN
    let descriptions: [(Element, StaticString)] = [
      (.add, ".add"),
      (.delete, ".delete"),
      (.enable, ".enable"),
      (.disable, ".disable"),
      (.oneShot, ".oneShot"),
      (.clear, ".clear"),
      (.receipt, ".receipt"),
      (.dispatch, ".dispatch"),
      (.userDataSpecific, ".userDataSpecific"),
      (.endOfFile, ".endOfFile"),
      (.error, ".error"),
      (.outOfBand, ".outOfBand"),
    ]
    #else
    let descriptions: [(Element, StaticString)] = [
      (.add, ".add"),
      (.delete, ".delete"),
      (.enable, ".enable"),
      (.disable, ".disable"),
      (.oneShot, ".oneShot"),
      (.clear, ".clear"),
      (.receipt, ".receipt"),
      (.dispatch, ".dispatch"),
      (.endOfFile, ".endOfFile"),
      (.error, ".error"),
    ]
    #endif
    return _buildDescription(descriptions)
  }

  /// A textual representation of the flags, suitable for debugging.
  public var debugDescription: String { self.description }
}

@available(System 199, *)
extension KernelEvent.Filter: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the filter.
  @inline(never)
  public var description: String {
    switch self {
    case .read: return "read"
    case .write: return "write"
    case .vnode: return "vnode"
    case .process: return "process"
    case .signal: return "signal"
    case .timer: return "timer"
    case .user: return "user"
    #if SYSTEM_PACKAGE_DARWIN || os(OpenBSD)
    case .exceptional: return "exceptional"
    #endif
    #if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
    case .fileSystem: return "fileSystem"
    #endif
    #if SYSTEM_PACKAGE_DARWIN
    case .machPort: return "machPort"
    #endif
    #if os(FreeBSD)
    case .processDescriptor: return "processDescriptor"
    #endif
    default: return "\(Self.self)(rawValue: \(self.rawValue))"
    }
  }

  /// A textual representation of the filter, suitable for debugging.
  public var debugDescription: String { self.description }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(FreeBSD) || os(OpenBSD)
