/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 */

// Only available on FreeBSD-derived systems
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

// TODO: There's `kevent`, `kevent64`, and `kevent_qos`. Provide wrappers
// for either the "best" one, or all of them.

/// A `KEvent` specifies the interesting conditions for a given `KQueue` to be
/// notified about.
///
/// The corresponding C struct is `kevent`.
@frozen
public struct KEvent: RawRepresentable {
  @_alwaysEmitIntoClient
  public var rawValue: CInterop.KEvent

  @_alwaysEmitIntoClient
  public init(rawValue: CInterop.KEvent) { self.rawValue = rawValue }

  @_alwaysEmitIntoClient
  public init(_ rawValue: CInterop.KEvent) { self.init(rawValue: rawValue) }
}

import Darwin
extension KEvent {
  /// Actions to perform on the event.
  @frozen
  public struct Flags: OptionSet, Hashable {
    @_alwaysEmitIntoClient
    public var rawValue: UInt16

    @_alwaysEmitIntoClient
    public init(rawValue: UInt16) { self.rawValue = rawValue }

    /// Add the event to the kqueue.  Re-adding an existing event will modify
    /// the parameters of the original event, and not result in a duplicate
    /// entry. Adding an event automatically enables it, unless overridden by
    /// the `disable` flag.
    ///
    /// The corresponding C constant is `EV_ADD`.
    @_alwaysEmitIntoClient
    public static var add: Flags { Flags(rawValue: UInt16(EV_ADD)) }

    /// Permit kevent,() kevent64() and kevent_qos() to return the event if it
    /// is triggered.
    ///
    /// The corresponding C constant is `EV_ENABLE`.
    @_alwaysEmitIntoClient
    public static var enable: Flags { Flags(rawValue: UInt16(EV_ENABLE)) }

    /// Disable the event so kevent,() kevent64() and kevent_qos() will not
    /// return it.  The filter itFlags is rawValue: not disabled.
    ///
    /// The corresponding C constant is `EV_DISABLE`.
    @_alwaysEmitIntoClient
    public static var disable: Flags { Flags(rawValue: UInt16(EV_DISABLE)) }

    /// Removes the event from the kqueue. Events which are attached to file
    /// descriptors are automatically deleted on the last close of the
    /// descriptor.
    ///
    /// The corresponding C constant is `EV_DELETE`.
    @_alwaysEmitIntoClient
    public static var delete: Flags { Flags(rawValue: UInt16(EV_DELETE)) }

    /// This flag is useful for making bulk changes to a kqueue without
    /// draining any pending events. When passed as input, it forces EV_ERROR
    /// to always be returned.  When a filter is successfully added, the data
    /// field will be zero.
    ///
    /// The corresponding C constant is `EV_RECEIPT`.
    @_alwaysEmitIntoClient
    public static var receipt: Flags { Flags(rawValue: UInt16(EV_RECEIPT)) }

    /// Causes the event to return only the first occurrence of the filter
    /// being triggered.  After the user retrieves the event from the kqueue,
    /// it is deleted.
    ///
    /// The corresponding C constant is `EV_ONESHOT`.
    @_alwaysEmitIntoClient
    public static var oneshot: Flags { Flags(rawValue: UInt16(EV_ONESHOT)) }

    /// After the event is retrieved by the user, its state is reset.  This is
    /// useful for filters which report state transitions instead of the
    /// current state.  Note that some filters may automatically set this flag
    /// internally.
    ///
    /// The corresponding C constant is `EV_CLEAR`.
    @_alwaysEmitIntoClient
    public static var clear: Flags { Flags(rawValue: UInt16(EV_CLEAR)) }

    /// Filters may set this flag to indicate filter-specific EOF condition.
    ///
    /// The corresponding C constant is `EV_EOF`.
    @_alwaysEmitIntoClient
    public static var eof: Flags { Flags(rawValue: UInt16(EV_EOF)) }


    /// Read filter on socket may set this flag to indicate the presence of out
    /// of band data on the descriptor.
    ///
    /// The corresponding C constant is `EV_OOBAND`.
    @_alwaysEmitIntoClient
    public static var outOfBand: Flags { Flags(rawValue: UInt16(EV_OOBAND)) }

    /// TODO: Err... this is what the man page has to say:
    ///
    /// If an error occurs while processing an element of the changelist and
    /// there is enough room in the eventlist, then the event will be placed in
    /// the eventlist with EV_ERROR set in flags and the system error in data.
    /// Otherwise, -1 will be returned, and errno will be set to indicate the
    /// error condition.  If the time limit expires, then kevent(), kevent64()
    /// and kevent_qos() return 0.
    ///
    /// The corresponding C constant is `EV_ERROR`.
    @_alwaysEmitIntoClient
    public static var error: Flags { Flags(rawValue: UInt16(EV_ERROR)) }

    /// Disable event after reporting.
    ///
    /// TODO: This flag is not part of the man page
    ///
    /// The corresponding C constant is `EV_DISPATCH`.
    @_alwaysEmitIntoClient
    public static var dispatch: Flags { Flags(rawValue: UInt16(EV_DISPATCH)) }

    /// Unique kevent per `userData` value.
    ///
    /// Whether the `userData` value is considered as part of the
    /// `(identifier, filter, userData?)` tuple.
    ///
    /// The corresponding C constant is `EV_UDATA_SPECIFIC`.
    @_alwaysEmitIntoClient
    public static var userDataSpecific: Flags {
      Flags(rawValue: UInt16(EV_UDATA_SPECIFIC))
    }
  }

  /// Identifies the kernel filter used to process this event.
  public struct Filter: RawRepresentable, Hashable {
    @_alwaysEmitIntoClient
    public var rawValue: Int16

    @_alwaysEmitIntoClient
    public init(rawValue: Int16) { self.rawValue = rawValue }

    /// Takes a file descriptor as the identifier, and returns whenever there is
    /// data available to read.
    ///
    /// TODO: man page goes on a couple pages, should we include all ofthat?
    ///
    /// The corresponding C constant is `EVFILT_READ`.
    @_alwaysEmitIntoClient
    public static var read: Filter { Filter(rawValue: Int16(EVFILT_READ)) }

    /// Takes a descriptor as the identifier, and returns whenever one of the
    /// specified exceptional conditions has occurred on the descriptor.
    ///
    /// The corresponding C constant is `EVFILT_EXCEPT`.
    @_alwaysEmitIntoClient
    public static var except: Filter { Filter(rawValue: Int16(EVFILT_EXCEPT)) }

    /// Takes a file descriptor as the identifier, and returns whenever it is
    /// possible to write to the descriptor.
    ///
    /// The corresponding C constant is `EVFILT_WRITE`.
    @_alwaysEmitIntoClient
    public static var write: Filter { Filter(rawValue: Int16(EVFILT_WRITE)) }

    /// Attached to AIO requests.
    ///
    /// TODO: man page says this is unsupported.
    ///
    /// The corresponding C constant is `EVFILT_AIO`.
    @_alwaysEmitIntoClient
    public static var aio: Filter { Filter(rawValue: Int16(EVFILT_AIO)) }

    /// Takes a file descriptor as the identifier and the events to watch for in
    /// fflags, and returns when one or more of the requested events occurs on
    /// the descriptor.
    ///
    /// The corresponding C constant is `EVFILT_VNODE`.
    @_alwaysEmitIntoClient
    public static var vnode: Filter { Filter(rawValue: Int16(EVFILT_VNODE)) }

    /// Takes the process ID to monitor as the identifier and the events to
    /// watch for in fflags, and returns when the process performs one or more
    /// of the requested events.
    ///
    /// The corresponding C constant is `EVFILT_PROC`.
    @_alwaysEmitIntoClient
    public static var process: Filter { Filter(rawValue: Int16(EVFILT_PROC)) }

    /// Takes the signal number to monitor as the identifier and returns when
    /// the given signal is generated for the process.
    ///
    /// The corresponding C constant is `EVFILT_SIGNAL`.
    @_alwaysEmitIntoClient
    public static var signal: Filter { Filter(rawValue: Int16(EVFILT_SIGNAL)) }

    /// Takes the name of a mach port, or port set, in ident and waits until a
    /// message is enqueued on the port or port set.
    ///
    /// The corresponding C constant is `EVFILT_MACHPORT`.
    @_alwaysEmitIntoClient
    public static var machport: Filter {
      Filter(rawValue: Int16(EVFILT_MACHPORT))
    }

    /// Establishes an interval timer identified by ident where data specifies
    /// the timeout period (in milliseconds).
    ///
    /// The corresponding C constant is `EVFILT_TIMER`.
    @_alwaysEmitIntoClient
    public static var timer: Filter { Filter(rawValue: Int16(EVFILT_TIMER)) }

    /// Filesystem events.
    ///
    /// TODO: Not listed in man page
    ///
    /// The corresponding C constant is `EVFILT_FS`.
    @_alwaysEmitIntoClient
    public static var fileSystem: Filter { Filter(rawValue: Int16(EVFILT_FS)) }

    /// User events.
    ///
    /// TODO: not listed in man page.
    ///
    /// The corresponding C constant is `EVFILT_USER`.
    @_alwaysEmitIntoClient
    public static var user: Filter { Filter(rawValue: Int16(EVFILT_USER)) }

    /// Virtual memory events.
    ///
    /// TODO: not listed in man page.
    ///
    /// The corresponding C constant is `EVFILT_VM`.
    @_alwaysEmitIntoClient
    public static var virtualMemory: Filter {
      Filter(rawValue: Int16(EVFILT_VM))
    }
  }

  /// Filter-specific flags.
  @frozen
  public struct FilterFlags: OptionSet, Hashable {
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The unlink() system call was called on the file referenced by the
    /// descriptor.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_DELETE`.
    @_alwaysEmitIntoClient
    public static var deleted: Self { Self(rawValue: UInt32(NOTE_DELETE)) }

    /// A write occurred on the file referenced by the descriptor.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_WRITE`.
    @_alwaysEmitIntoClient
    public static var written: Self { Self(rawValue: UInt32(NOTE_WRITE)) }

    /// The file referenced by the descriptor was extended.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_EXTEND`.
    @_alwaysEmitIntoClient
    public static var extended: Self { Self(rawValue: UInt32(NOTE_EXTEND)) }

    /// The file referenced by the descriptor had its attributes changed.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_ATTRIB`.
    @_alwaysEmitIntoClient
    public static var attributesChanged: Self {
      Self(rawValue: UInt32(NOTE_ATTRIB))
    }

    ///   The link count on the file changed.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_LINK`.
    @_alwaysEmitIntoClient
    public static var linked: Self { Self(rawValue: UInt32(NOTE_LINK)) }

    /// The file referenced by the descriptor was renamed.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_RENAME`.
    @_alwaysEmitIntoClient
    public static var renamed: Self { Self(rawValue: UInt32(NOTE_RENAME)) }

    /// Access to the file was revoked via revoke(2) or the underlying fileystem
    /// was unmounted.
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_REVOKE`.
    @_alwaysEmitIntoClient
    public static var revoked: Self { Self(rawValue: UInt32(NOTE_REVOKE)) }

    /// The file was unlocked by calling flock(2) or close(2)
    ///
    /// NOTE: This should be used with the `Filter.vnode`.
    ///
    /// The corresponding C constant is `NOTE_FUNLOCK`.
    @_alwaysEmitIntoClient
    public static var unlocked: Self { Self(rawValue: UInt32(NOTE_FUNLOCK)) }

    /// The process has exited.
    ///
    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    ///
    /// The corresponding C constant is `NOTE_EXIT`.
    @_alwaysEmitIntoClient
    public static var exited: Self { Self(rawValue: NOTE_EXIT) }

    /// The process has exited and its exit status is in filter specific data.
    /// Valid only on child processes and to be used along with NOTE_EXIT.
    ///
    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    ///
    /// The corresponding C constant is `NOTE_EXITSTATUS`.
    @_alwaysEmitIntoClient
    public static var exitedWithStatus: Self {
      Self(rawValue: UInt32(NOTE_EXITSTATUS))
    }

    /// The process created a child process via fork(2) or similar call.
    ///
    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    ///
    /// The corresponding C constant is `NOTE_FORK`.
    @_alwaysEmitIntoClient
    public static var forked: Self { Self(rawValue: UInt32(NOTE_FORK)) }

    /// The process executed a new process via execve(2) or similar call.
    ///
    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    ///
    /// The corresponding C constant is `NOTE_EXEC`.
    @_alwaysEmitIntoClient
    public static var execed: Self { Self(rawValue: UInt32(NOTE_EXEC)) }

    /// The process was sent a signal. Status can be checked via waitpid(2) or
    /// similar call.
    ///
    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    ///
    /// The corresponding C constant is `NOTE_SIGNAL`.
    @_alwaysEmitIntoClient
    public static var signaled: Self { Self(rawValue: UInt32(NOTE_SIGNAL)) }

    //    /// The process was reaped by the parent via wait(2) or similar call.
    //    /// Deprecated, use NOTE_EXIT.
    //    ///
    //    /// NOTE: This sould be used with the `EVFILT_PROC` filter.
    //    ///
    //    /// The corresponding C constant is `NOTE_REAP`.
    //    @_alwaysEmitIntoClient
    //    public static var reaped: Self { Self(rawValue: NOTE_REAP) }

    /// Data is in seconds.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_SECONDS`.
    @_alwaysEmitIntoClient
    public static var seconds: Self { Self(rawValue: UInt32(NOTE_SECONDS)) }

    /// Dsta is in microseconds.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_USECONDS`.
    @_alwaysEmitIntoClient
    public static var microseconds: Self {
      Self(rawValue: UInt32(NOTE_USECONDS))
    }

    /// Dta is in nanoseconds.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_NSECONDS`.
    @_alwaysEmitIntoClient
    public static var nanoseconds: Self {
      Self(rawValue: UInt32(NOTE_NSECONDS))
    }

    /// Data is in Mach absolute time units.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_MACHTIME`.
    @_alwaysEmitIntoClient
    public static var machtime: Self { Self(rawValue: UInt32(NOTE_MACHTIME)) }

    /// Data is expressed in terms of gettimeofday(3).
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// TODO: man page says it establishes a EV_ONESHOT timer.
    ///
    /// The corresponding C constant is `NOTE_MACHTIME`.
    @_alwaysEmitIntoClient
    public static var absolute: Self { Self(rawValue: UInt32(NOTE_ABSOLUTE)) }

    /// Override default power-saving techniques to more strictly respect the
    /// leeway value.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_CRITICAL`.
    @_alwaysEmitIntoClient
    public static var critical: Self { Self(rawValue: UInt32(NOTE_CRITICAL)) }

    /// Apply more power-saving techniques to coalesce this timer with other
    /// timers.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_BACKGROUND`.
    @_alwaysEmitIntoClient
    public static var background: Self {
      Self(rawValue: UInt32(NOTE_BACKGROUND))
    }

    /// ext[1] holds user-supplied slop in deadline for timer coalescing.
    ///
    /// NOTE: This sould be used with the `EVFILT_TIMER` filter.
    ///
    /// The corresponding C constant is `NOTE_LEEWAY`.
    @_alwaysEmitIntoClient
    public static var leeway: Self { Self(rawValue: UInt32(NOTE_LEEWAY)) }
  }
  
}

// TODO: Since filter dictates what disjoint set of flags are supported, I'm
// tempted to have a more declarative API. For now, let's definitely surface
// KEvent as-is without unsafe bits.

extension KEvent {
  /// Value used to identify the source of the event.  The exact
  /// interpretation is determined by the attached filter, but often is a file
  /// descriptor.
  ///
  /// The corresponding C struct field is `ident`.
  @_alwaysEmitIntoClient
  public var identifier: UInt {
    get { rawValue.ident }
    set { rawValue.ident = newValue }
  }

  /// Identifies the kernel filter used to process this event.
  ///
  /// The corresponding C struct field is `filter`.
  @_alwaysEmitIntoClient
  public var filter: Filter {
    get { Filter(rawValue: rawValue.filter) }
    set { rawValue.filter = newValue.rawValue }
  }

  /// Actions to perform on the event.
  ///
  /// The corresponding C struct field is `flags`.
  @_alwaysEmitIntoClient
  public var flags: Flags {
    get { Flags(rawValue: rawValue.flags) }
    set { rawValue.flags = newValue.rawValue }
  }

  /// Filter-specific flags.
  ///
  /// The corresponding C struct field is `fflags`.
  @_alwaysEmitIntoClient
  public var filterFlags: FilterFlags {
    get { FilterFlags(rawValue: rawValue.fflags) }
    set { rawValue.fflags = newValue.rawValue }
  }

  /// Filter-specific data value.
  ///
  /// The corresponding C struct field is `data`.
  @_alwaysEmitIntoClient
  public var data: Int {
    get { rawValue.data }
    set { rawValue.data = newValue }
  }

  /// Opaque user-defined value passed through the kernel unchanged. It can
  /// optionally be part of the uniquing decision of the kevent system.
  ///
  /// The corresponding C struct field is `udata`.
  @_alwaysEmitIntoClient
  public var userdata: UnsafeMutableRawPointer? {
    get { rawValue.udata }
    set { rawValue.udata = newValue }
  }

}

extension KEvent {
  // TODO: These are only for the 64 and qos variants, but might as well define
  // them now. We might want to provide a general `KEvent` struct with variants,
  // but I'm not sure the best interface to provide.
  //
  // We might also want to just provide this as raw-as-possible and spend our
  // design budget on a File-Reactor/Proactor abstraction over kqueue/epoll.

  /// Flags for the `kevent64` and `kevent_qos` system calls
  @frozen
  public struct SystemCallFlags: RawRepresentable {
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// No flag value.
    ///
    /// The corresponding C constant is `KEVENT_FLAG_NONE`.
    @_alwaysEmitIntoClient
    public static var none: Self { Self(rawValue: UInt32(KEVENT_FLAG_NONE)) }
    
    /// Immediate timeout.
    ///
    /// The corresponding C constant is `KEVENT_FLAG_IMMEDIATE`.
    @_alwaysEmitIntoClient
    public static var immediate: Self {
      Self(rawValue: UInt32(KEVENT_FLAG_IMMEDIATE))
    }

    /// Output events only include change errors.
    ///
    /// The corresponding C constant is `KEVENT_FLAG_ERROR_EVENTS`.
    @_alwaysEmitIntoClient
    public static var error_events: Self {
      Self(rawValue: UInt32(KEVENT_FLAG_ERROR_EVENTS))
    }

  }
}

#endif

