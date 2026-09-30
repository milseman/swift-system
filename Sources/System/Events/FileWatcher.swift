/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned inotify instance, on the pattern of EventPoll.

// inotify exists on Linux and Android, whose C libraries' Swift modules all
// include <sys/inotify.h>.
#if os(Linux) || os(Android)

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

/// An inotify instance, which reports changes to the files and directories
/// that you add to it.
///
/// Add each file or directory to watch with ``add(_:events:)-(FilePath,_)``,
/// and read what happened to them with ``read(into:retryOnInterrupt:)``:
///
///     let watcher = try FileWatcher(options: .closeOnExec)
///     let logs = try watcher.add("/var/log", events: [.created, .deleted])
///     for event in try watcher.read() where event.watch == logs {
///       print(event.mask.contains(.created) ? "+" : "-", event.name ?? "")
///     }
///
/// A watched directory reports events for the files in it,
/// with each file's name, but not for the files in its subdirectories.
///
/// An instance owns its file descriptor,
/// and closes it at the end of its lifetime or when you call ``close()``,
/// as ``OwnedFD`` does; that removes its watches.
/// Its file descriptor is readable when it has events to report,
/// so ``EventPoll`` or ``FileDescriptor/poll(for:timeout:retryOnInterrupt:)``
/// can wait for them.
///
/// The corresponding C function is `inotify_init1`.
///
/// - Note: Only available on Linux and Android.
@frozen
@available(System 199, *)
public struct FileWatcher: ~Copyable, Sendable {
  @usableFromInline
  internal let _owner: OwnedFD

  /// Creates an inotify instance.
  ///
  /// - Parameter options: Options for the instance's file descriptor.
  ///   The default is none.
  ///
  /// The corresponding C function is `inotify_init1`.
  @_alwaysEmitIntoClient
  public init(options: Options = []) throws(Errno) {
    self._owner = OwnedFD(taking: try Self._create(options.rawValue).get())
  }

  @usableFromInline
  internal static func _create(_ flags: CInt) -> Result<FileDescriptor, Errno> {
    // inotify_init1 can't be interrupted.
    valueOrErrno(retryOnInterrupt: false) {
      system_inotify_init1(flags)
    }.map(FileDescriptor.init(rawValue:))
  }

  /// Takes ownership of a file descriptor that refers to an inotify instance.
  ///
  /// This initializer doesn't check that `descriptor` refers to an instance.
  /// The descriptor is closed at the end of the instance's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking descriptor: FileDescriptor) {
    self._owner = OwnedFD(taking: descriptor)
  }

  /// The instance's file descriptor, for operations that `FileWatcher`
  /// doesn't provide, such as adding it to an ``EventPoll``.
  ///
  /// The returned value is valid only while this instance is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of the descriptor, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var fileDescriptor: FileDescriptor { _owner.fileDescriptor }

  /// Closes the instance, which removes its watches.
  ///
  /// The file descriptor is not closed again,
  /// whether this method returns or throws.
  ///
  /// The corresponding C function is `close`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Errno) {
    try _owner.close()
  }

  /// Transfers ownership of the instance's file descriptor to the caller,
  /// without closing it.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> FileDescriptor {
    _owner.relinquish()
  }
}

@available(System 199, *)
extension FileWatcher {
  /// Options for an inotify instance's file descriptor.
  @frozen
  public struct Options: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Makes reading the instance throw
    /// ``Errno/resourceTemporarilyUnavailable`` when it has no events,
    /// rather than wait for one.
    ///
    /// The corresponding C constant is `IN_NONBLOCK`.
    @_alwaysEmitIntoClient
    public static var nonBlocking: Options { Options(rawValue: _IN_NONBLOCK) }

    /// Closes the instance's file descriptor
    /// when the process executes a new program.
    ///
    /// The corresponding C constant is `IN_CLOEXEC`.
    @_alwaysEmitIntoClient
    public static var closeOnExec: Options { Options(rawValue: _IN_CLOEXEC) }
  }

  /// A watch: a file or directory that an instance watches,
  /// which its events name.
  ///
  /// The corresponding C type is the watch descriptor
  /// that `inotify_add_watch` returns.
  @frozen
  public struct Watch: RawRepresentable, Hashable, Sendable {
    /// The raw watch descriptor.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a watch from a raw watch descriptor.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
  }

  /// The events that a watch reports, which ``add(_:events:)-(FilePath,_)``
  /// takes with options for the watch, and which an ``Event`` has
  /// with flags about it.
  @frozen
  public struct Mask: OptionSet, Hashable, Sendable {
    /// The raw C mask.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed mask from a raw C mask.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    // MARK: Events

    /// A file was read.
    ///
    /// The corresponding C constant is `IN_ACCESS`.
    @_alwaysEmitIntoClient
    public static var accessed: Mask { Mask(rawValue: _IN_ACCESS) }

    /// A file was written.
    ///
    /// The corresponding C constant is `IN_MODIFY`.
    @_alwaysEmitIntoClient
    public static var modified: Mask { Mask(rawValue: _IN_MODIFY) }

    /// A file's metadata changed,
    /// such as its permissions, owner, times, or links.
    ///
    /// The corresponding C constant is `IN_ATTRIB`.
    @_alwaysEmitIntoClient
    public static var attributesChanged: Mask { Mask(rawValue: _IN_ATTRIB) }

    /// A file that was open for writing was closed.
    ///
    /// The corresponding C constant is `IN_CLOSE_WRITE`.
    @_alwaysEmitIntoClient
    public static var closedAfterWriting: Mask { Mask(rawValue: _IN_CLOSE_WRITE) }

    /// A file that wasn't open for writing was closed.
    ///
    /// The corresponding C constant is `IN_CLOSE_NOWRITE`.
    @_alwaysEmitIntoClient
    public static var closedWithoutWriting: Mask { Mask(rawValue: _IN_CLOSE_NOWRITE) }

    /// A file was closed: ``closedAfterWriting`` and ``closedWithoutWriting``.
    ///
    /// The corresponding C constant is `IN_CLOSE`.
    @_alwaysEmitIntoClient
    public static var closed: Mask { [.closedAfterWriting, .closedWithoutWriting] }

    /// A file was opened.
    ///
    /// The corresponding C constant is `IN_OPEN`.
    @_alwaysEmitIntoClient
    public static var opened: Mask { Mask(rawValue: _IN_OPEN) }

    /// A file was moved out of a watched directory;
    /// its event's ``Event/cookie`` matches the ``movedTo`` event's.
    ///
    /// The corresponding C constant is `IN_MOVED_FROM`.
    @_alwaysEmitIntoClient
    public static var movedFrom: Mask { Mask(rawValue: _IN_MOVED_FROM) }

    /// A file was moved into a watched directory.
    ///
    /// The corresponding C constant is `IN_MOVED_TO`.
    @_alwaysEmitIntoClient
    public static var movedTo: Mask { Mask(rawValue: _IN_MOVED_TO) }

    /// A file was moved: ``movedFrom`` and ``movedTo``.
    ///
    /// The corresponding C constant is `IN_MOVE`.
    @_alwaysEmitIntoClient
    public static var moved: Mask { [.movedFrom, .movedTo] }

    /// A file or directory was created in a watched directory.
    ///
    /// The corresponding C constant is `IN_CREATE`.
    @_alwaysEmitIntoClient
    public static var created: Mask { Mask(rawValue: _IN_CREATE) }

    /// A file or directory was deleted from a watched directory.
    ///
    /// The corresponding C constant is `IN_DELETE`.
    @_alwaysEmitIntoClient
    public static var deleted: Mask { Mask(rawValue: _IN_DELETE) }

    /// The watched file or directory itself was deleted.
    ///
    /// The corresponding C constant is `IN_DELETE_SELF`.
    @_alwaysEmitIntoClient
    public static var deletedSelf: Mask { Mask(rawValue: _IN_DELETE_SELF) }

    /// The watched file or directory itself was moved.
    ///
    /// The corresponding C constant is `IN_MOVE_SELF`.
    @_alwaysEmitIntoClient
    public static var movedSelf: Mask { Mask(rawValue: _IN_MOVE_SELF) }

    /// Every event.
    ///
    /// The corresponding C constant is `IN_ALL_EVENTS`.
    @_alwaysEmitIntoClient
    public static var allEvents: Mask {
      [
        .accessed, .modified, .attributesChanged, .closed, .opened, .moved,
        .created, .deleted, .deletedSelf, .movedSelf,
      ]
    }

    // MARK: Flags that events have

    /// The file system that has the watched file or directory was unmounted,
    /// which removes the watch.
    ///
    /// The corresponding C constant is `IN_UNMOUNT`.
    @_alwaysEmitIntoClient
    public static var unmounted: Mask { Mask(rawValue: _IN_UNMOUNT) }

    /// The instance's queue of events overflowed, and events were lost.
    /// The event names no watch.
    ///
    /// The corresponding C constant is `IN_Q_OVERFLOW`.
    @_alwaysEmitIntoClient
    public static var queueOverflowed: Mask { Mask(rawValue: _IN_Q_OVERFLOW) }

    /// The watch was removed: by ``FileWatcher/remove(_:)``,
    /// or because its file or directory was deleted or unmounted.
    ///
    /// The corresponding C constant is `IN_IGNORED`.
    @_alwaysEmitIntoClient
    public static var ignored: Mask { Mask(rawValue: _IN_IGNORED) }

    /// The event is about a directory.
    ///
    /// The corresponding C constant is `IN_ISDIR`.
    @_alwaysEmitIntoClient
    public static var isDirectory: Mask { Mask(rawValue: _IN_ISDIR) }

    // MARK: Options for a watch

    /// Watches the path only if it's a directory,
    /// and throws ``Errno/notDirectory`` otherwise.
    ///
    /// The corresponding C constant is `IN_ONLYDIR`.
    @_alwaysEmitIntoClient
    public static var onlyDirectory: Mask { Mask(rawValue: _IN_ONLYDIR) }

    /// Watches a symbolic link at the path, not its target.
    ///
    /// The corresponding C constant is `IN_DONT_FOLLOW`.
    @_alwaysEmitIntoClient
    public static var noFollow: Mask { Mask(rawValue: _IN_DONT_FOLLOW) }

    /// Stops reporting events for a directory's files once they're unlinked,
    /// even while something holds them open.
    ///
    /// The corresponding C constant is `IN_EXCL_UNLINK`.
    @_alwaysEmitIntoClient
    public static var excludeUnlinked: Mask { Mask(rawValue: _IN_EXCL_UNLINK) }

    /// Adds the events to the path's watch, if the instance has one,
    /// rather than replacing its events.
    ///
    /// The corresponding C constant is `IN_MASK_ADD`.
    @_alwaysEmitIntoClient
    public static var addToExisting: Mask { Mask(rawValue: _IN_MASK_ADD) }

    /// Reports one event, then removes the watch.
    ///
    /// The corresponding C constant is `IN_ONESHOT`.
    @_alwaysEmitIntoClient
    public static var oneShot: Mask { Mask(rawValue: _IN_ONESHOT) }
  }

  /// A change to a watched file or directory.
  ///
  /// The corresponding C type is `struct inotify_event`.
  @frozen
  public struct Event: Hashable, Sendable {
    /// The watch that reports the event.
    ///
    /// The corresponding C field is `wd`.
    public var watch: Watch

    /// The event, and flags about it.
    ///
    /// The corresponding C field is `mask`.
    public var mask: Mask

    /// A number that the two halves of a move have in common,
    /// ``Mask/movedFrom`` and ``Mask/movedTo``, and other events don't.
    ///
    /// The corresponding C field is `cookie`.
    public var cookie: UInt32

    /// The name of the file in a watched directory that the event is about,
    /// or `nil` if it's about the watched file or directory itself.
    ///
    /// The corresponding C field is `name`.
    public var name: FilePath.Component?

    /// Creates an event from its parts.
    @_alwaysEmitIntoClient
    public init(watch: Watch, mask: Mask, cookie: UInt32 = 0, name: FilePath.Component? = nil) {
      self.watch = watch
      self.mask = mask
      self.cookie = cookie
      self.name = name
    }
  }
}

// MARK: - Watching files and directories

@available(System 199, *)
extension FileWatcher {
  /// Starts watching a file or directory, or changes the events of the
  /// instance's watch of it.
  ///
  /// - Parameters:
  ///   - path: The file or directory to watch.
  ///   - events: The events to report, and options for the watch.
  /// - Returns: The watch, which the path's events name.
  ///   Adding a path that the instance already watches returns its watch,
  ///   with `events` replacing its events,
  ///   or adding to them with ``Mask/addToExisting``.
  ///
  /// Watching needs permission to read the file or directory.
  ///
  /// The corresponding C function is `inotify_add_watch`.
  @_alwaysEmitIntoClient
  public func add(_ path: FilePath, events: Mask) throws(Errno) -> Watch {
    try path.withPlatformString {
      FileWatcher._add(fileDescriptor, $0, events: events)
    }.get()
  }

  /// Starts watching a file or directory, or changes the events of the
  /// instance's watch of it.
  ///
  /// See ``add(_:events:)-(FilePath,_)``.
  ///
  /// The corresponding C function is `inotify_add_watch`.
  @_alwaysEmitIntoClient
  public func add(_ path: UnsafePointer<CChar>, events: Mask) throws(Errno) -> Watch {
    try FileWatcher._add(fileDescriptor, path, events: events).get()
  }

  @usableFromInline
  internal static func _add(
    _ fd: FileDescriptor, _ path: UnsafePointer<CChar>, events: Mask
  ) -> Result<Watch, Errno> {
    valueOrErrno(retryOnInterrupt: false) {
      system_inotify_add_watch(fd.rawValue, path, events.rawValue)
    }.map(Watch.init(rawValue:))
  }

  /// Stops watching, and reports ``Mask/ignored`` for the watch.
  ///
  /// A watch that the instance doesn't have throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `inotify_rm_watch`.
  @_alwaysEmitIntoClient
  public func remove(_ watch: Watch) throws(Errno) {
    try FileWatcher._remove(fileDescriptor, watch).get()
  }

  @usableFromInline
  internal static func _remove(_ fd: FileDescriptor, _ watch: Watch) -> Result<(), Errno> {
    nothingOrErrno(retryOnInterrupt: false) {
      system_inotify_rm_watch(fd.rawValue, watch.rawValue)
    }
  }
}

// MARK: - Reading events

@available(System 199, *)
extension FileWatcher {
  /// The fewest bytes that a buffer for ``read(into:retryOnInterrupt:)``
  /// needs, to hold any one event: an event's header,
  /// and the longest name with its zero byte.
  @_alwaysEmitIntoClient
  public static var minimumReadByteCount: Int {
    MemoryLayout<inotify_event>.size + Int(_NAME_MAX) + 1
  }

  /// Reads the events that the instance has into a buffer,
  /// waiting for one unless the instance is ``Options/nonBlocking``.
  ///
  /// - Parameters:
  ///   - buffer: The buffer to read into,
  ///     at least ``minimumReadByteCount`` bytes
  ///     to be sure of holding any event;
  ///     one too small for the next event throws ``Errno/invalidArgument``.
  ///   - retryOnInterrupt: Whether to retry the read
  ///     if it throws ``Errno/interrupted``.
  ///     The default is `true`.
  ///     Pass `false` to try only once and throw an error upon interruption.
  /// - Returns: The events that fit, in the order they happened.
  ///
  /// A nonblocking instance with no events
  /// throws ``Errno/resourceTemporarilyUnavailable``.
  ///
  /// The corresponding C function is `read`.
  @_alwaysEmitIntoClient
  public func read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws(Errno) -> [Event] {
    try _read(into: buffer, retryOnInterrupt: retryOnInterrupt).get()
  }

  /// Reads the events that the instance has,
  /// waiting for one unless the instance is ``Options/nonBlocking``.
  ///
  /// This method reads into a buffer of its own,
  /// as ``read(into:retryOnInterrupt:)`` describes,
  /// which holds at least one event,
  /// and returns the events that fit.
  ///
  /// The corresponding C function is `read`.
  @_alwaysEmitIntoClient
  public func read(retryOnInterrupt: Bool = true) throws(Errno) -> [Event] {
    try withUnsafeTemporaryAllocation(
      byteCount: Swift.max(4096, Self.minimumReadByteCount),
      alignment: MemoryLayout<inotify_event>.alignment
    ) { buffer in
      _read(into: buffer, retryOnInterrupt: retryOnInterrupt)
    }.get()
  }

  @usableFromInline
  internal func _read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool
  ) -> Result<[Event], Errno> {
    fileDescriptor._read(into: buffer, retryOnInterrupt: retryOnInterrupt).map { count in
      FileWatcher._events(in: UnsafeRawBufferPointer(rebasing: buffer[..<count]))
    }
  }

  /// The events in the bytes that a read returned: each a header,
  /// then `len` bytes of name, padded with zeros.
  @usableFromInline
  internal static func _events(in bytes: UnsafeRawBufferPointer) -> [Event] {
    let headerSize = MemoryLayout<inotify_event>.size
    var events: [Event] = []
    var offset = 0
    while offset + headerSize <= bytes.count {
      let header = bytes.loadUnaligned(fromByteOffset: offset, as: inotify_event.self)
      let nameLength = Int(header.len)
      let nameStart = offset + headerSize
      guard nameStart + nameLength <= bytes.count else { break }
      var name: FilePath.Component? = nil
      if nameLength > 0 {
        // The name ends at its first zero byte, within the padding.
        let nameBytes = UnsafeRawBufferPointer(rebasing: bytes[nameStart..<(nameStart + nameLength)])
        let end = nameBytes.firstIndex(of: 0) ?? nameBytes.endIndex
        let chars = Array(nameBytes[..<end].map { CInterop.PlatformChar(bitPattern: $0) }) + [0]
        name = FilePath.Component(platformString: chars)
      }
      events.append(Event(
        watch: Watch(rawValue: header.wd), mask: Mask(rawValue: header.mask),
        cookie: header.cookie, name: name))
      offset = nameStart + nameLength
    }
    return events
  }
}

#endif // os(Linux) || os(Android)
