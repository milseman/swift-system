/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SIMULATE_PLATFORMS

// SIMULATION MACHINERY, simulated configuration only, and part of no draft.
// The Win32 stand-ins (Win32FileHandle.swift, Win32Hypothetical.swift, and
// Win32Copyable.swift) implement their operations here, over Darwin's POSIX
// calls. It simulates the Windows behavior the samples depend on:
//
// - A HANDLE is a pointer-sized name. Here it encodes a descriptor number.
// - Share modes: an open that conflicts with another open of the same file,
//   in this process, fails with ERROR_SHARING_VIOLATION.
// - Byte-range locks are mandatory: in this process, a read or write through
//   another handle, or a write through the holder of a shared lock, fails
//   with ERROR_LOCK_VIOLATION. (Real Windows enforces this across processes.)
// - Positional reads and writes move the file pointer.
// - Seeking a pipe succeeds, reporting a position no transfer uses.
// - Writing to a closed pipe fails with ERROR_NO_DATA rather than raising
//   SIGPIPE.
// - Waiting for a process doesn't reap it: its exit code stays readable, and
//   TerminateProcess's exit code is the one the caller chose.
//
// Anything else follows Darwin: for example, text-mode translation, access
// masks narrower than read or write, and security descriptors are ignored.

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#else
#error("The simulated configuration builds only on Darwin")
#endif

enum Win32Simulation {
  // MARK: Handles

  /// The HANDLE for a descriptor: a nonzero multiple of 4, as real handles are.
  static func handle(for descriptor: CInt) -> HANDLE {
    UnsafeMutableRawPointer(bitPattern: (Int(descriptor) + 1) << 2)!
  }

  /// The descriptor a HANDLE names, or nil for `NULL` and `INVALID_HANDLE_VALUE`.
  static func descriptor(of handle: HANDLE?) -> CInt? {
    guard let handle else { return nil }
    let bits = Int(bitPattern: handle)
    guard bits != -1, bits > 0, bits & 3 == 0 else { return nil }
    return CInt(truncatingIfNeeded: (bits >> 2) - 1)
  }

  // MARK: Errors

  /// The Win32 error that Windows would report for a failure that Darwin
  /// reports as `errno`. Codes with no counterpart become simulated codes
  /// that carry the errno value.
  static func error(from errno: Errno) -> Win32.Error {
    // The cases spell out `Errno.`: with Win32.Error's `~=` in scope, an
    // implicit member such as `.fileExists` is ambiguous (V16f).
    switch errno {
    case Errno.noSuchFileOrDirectory: return .fileNotFound
    case Errno.notDirectory: return .pathNotFound
    case Errno.permissionDenied, Errno.notPermitted, Errno.isDirectory: return .accessDenied
    case Errno.fileExists: return .fileExists
    case Errno.badFileDescriptor: return .invalidHandle
    case Errno.invalidArgument: return .invalidParameter
    case Errno.noSpace: return .diskFull
    case Errno.brokenPipe: return .noData
    case Errno.fileTooLarge: return .fileTooLarge
    case Errno.resourceTemporarilyUnavailable: return .lockViolation
    case Errno.notSupported: return .notSupported
    case Errno.noSuchProcess: return .invalidParameter
    case Errno.connectionReset: return Win32.Error(10054)      // WSAECONNRESET
    case Errno.socketNotConnected: return Win32.Error(10057)   // WSAENOTCONN
    case Errno.socketShutdown: return Win32.Error(10058)       // WSAESHUTDOWN
    default: return Win32.Error(simulatedBase | DWORD(truncatingIfNeeded: errno.rawValue))
    }
  }

  static func error(from any: any Error) -> Win32.Error {
    if let win32 = any as? Win32.Error { return win32 }
    if let errno = any as? Errno { return error(from: errno) }
    return .invalidFunction
  }

  private static let simulatedBase: DWORD = 0xA053_5A00

  static func isSimulatedCode(_ code: DWORD) -> Bool { code & 0xFFFF_FF00 == simulatedBase }

  static func describeSimulatedCode(_ code: DWORD) -> String {
    let errno = Errno(rawValue: CInt(code & 0xFF))
    return "Simulated: Darwin reported \(errno) (errno \(errno.rawValue)), which the simulation doesn't map"
  }

  /// Runs a POSIX operation, reporting its failure as a Win32 error.
  ///
  /// The closure is untyped because FileDescriptor's older members, such as
  /// `open`, `close`, `seek`, and `resize`, still throw untyped errors.
  static func posix<R>(_ body: () throws -> R) throws(Win32.Error) -> R {
    do {
      return try body()
    } catch {
      throw Self.error(from: error)
    }
  }

  // MARK: Opening, and share modes

  private struct FileID: Hashable {
    var device: UInt64
    var inode: UInt64
  }

  private struct OpenRecord {
    var descriptor: CInt
    var access: Win32.AccessMask
    var share: Win32.ShareMode
  }

  nonisolated(unsafe) private static var opens: [FileID: [OpenRecord]] = [:]

  private static func fileID(of descriptor: CInt) throws(Win32.Error) -> FileID {
    let status = try posix { try FileDescriptor(rawValue: descriptor).stat() }
    return FileID(
      device: UInt64(truncatingIfNeeded: status.deviceID.rawValue),
      inode: UInt64(truncatingIfNeeded: status.inode.rawValue))
  }

  private static func conflicts(_ a: OpenRecord, _ b: OpenRecord) -> Bool {
    func denies(_ holder: OpenRecord, _ opener: OpenRecord) -> Bool {
      (opener.access.readsData && !holder.share.contains(.read))
        || (opener.access.writesData && !holder.share.contains(.write))
        || (opener.access.deletes && !holder.share.contains(.delete))
    }
    return denies(a, b) || denies(b, a)
  }

  /// Opens a file or directory as `CreateFileW` would.
  static func open(
    _ path: FilePath,
    access: Win32.AccessMask,
    shareMode: Win32.ShareMode,
    disposition: Win32.CreationDisposition,
    flags: Win32.FileFlags,
    inheritable: Bool,
    directory: Bool
  ) throws(Win32.Error) -> (descriptor: CInt, existed: Bool) {
    guard flags.rawValue & Win32.FileFlags._overlappedBit == 0 else { throw .invalidParameter }
    let mode: FileDescriptor.AccessMode
    switch (access.readsData, access.writesData) {
    case (_, true) where directory: throw .accessDenied
    case (true, true): mode = .readWrite
    case (false, true): mode = .writeOnly
    default: mode = .readOnly
    }
    var options: FileDescriptor.OpenOptions = inheritable ? [] : [.closeOnExec]
    if directory { options.insert(.directory) }

    var existed = false
    switch disposition {
    case .createNew: options.formUnion([.create, .exclusiveCreate])
    case .openExisting: break
    case .truncateExisting: options.insert(.truncate)
    case .openAlways, .createAlways:
      // CreateFileW reports whether the file existed atomically. The
      // simulation tries an exclusive create first, which leaves a window.
      do {
        let created = try FileDescriptor.open(
          path, mode, options: options.union([.create, .exclusiveCreate]),
          permissions: FilePermissions(rawValue: 0o666))
        return (try register(created.rawValue, access: access, share: shareMode), false)
      } catch Errno.fileExists {
        existed = true
        if disposition == .createAlways { options.insert(.truncate) }
      } catch {
        throw Self.error(from: error)
      }
    default: throw .invalidParameter
    }

    let descriptor: FileDescriptor
    do {
      descriptor = try FileDescriptor.open(
        path, mode, options: options, permissions: FilePermissions(rawValue: 0o666))
    } catch Errno.notDirectory where directory {
      throw .notADirectory
    } catch {
      throw Self.error(from: error)
    }
    if !directory {
      // Without FILE_FLAG_BACKUP_SEMANTICS, CreateFileW refuses a directory.
      let isDirectory = (try? descriptor.stat().type == .directory) ?? false
      if isDirectory {
        _ = try? descriptor.close()
        throw .accessDenied
      }
    }
    return (try register(descriptor.rawValue, access: access, share: shareMode), existed)
  }

  /// Records an open handle's access and share mode, failing with a sharing
  /// violation, and closing the descriptor, if it conflicts with another.
  static func register(
    _ descriptor: CInt, access: Win32.AccessMask, share: Win32.ShareMode
  ) throws(Win32.Error) -> CInt {
    let id = try fileID(of: descriptor)
    let record = OpenRecord(descriptor: descriptor, access: access, share: share)
    if opens[id, default: []].contains(where: { conflicts($0, record) }) {
      _ = try? FileDescriptor(rawValue: descriptor).close()
      throw .sharingViolation
    }
    opens[id, default: []].append(record)
    // Windows has no SIGPIPE; a write to a closed pipe just fails.
    _ = try? FileDescriptor(rawValue: descriptor).setNoSigPipe(true)
    return descriptor
  }

  /// Forgets a handle's share mode and locks, as closing or relinquishing does.
  static func unregister(_ descriptor: CInt) {
    for id in opens.keys {
      opens[id]?.removeAll { $0.descriptor == descriptor }
      if opens[id]?.isEmpty == true { opens[id] = nil }
    }
    for id in locks.keys {
      locks[id]?.removeAll { $0.descriptor == descriptor }
      if locks[id]?.isEmpty == true { locks[id] = nil }
    }
  }

  private static func access(of descriptor: CInt) -> Win32.AccessMask? {
    for records in opens.values {
      if let record = records.first(where: { $0.descriptor == descriptor }) { return record.access }
    }
    return nil
  }

  /// `CloseHandle`.
  static func closeHandle(_ descriptor: CInt) throws(Win32.Error) {
    unregister(descriptor)
    try posix { try FileDescriptor(rawValue: descriptor).close() }
  }

  // MARK: Byte-range locks

  private struct LockRecord {
    var descriptor: CInt
    var range: Range<Int64>
    var mode: Win32.LockMode
  }

  nonisolated(unsafe) private static var locks: [FileID: [LockRecord]] = [:]

  /// Resolves a lock's byte range as SYS-0014 describes: against `0..<Int64.max`.
  static func lockRange(_ range: some RangeExpression<Int64>) throws(Win32.Error) -> Range<Int64> {
    let resolved = range.relative(to: LockableBytes())
    guard resolved.lowerBound >= 0 else { throw .invalidParameter }
    return resolved
  }

  /// Takes a lock, runs `body`, and releases the lock. Returns nil without
  /// running `body` if `wait` is false and a conflicting lock is held.
  static func withLock<R: ~Copyable, E: Error>(
    _ descriptor: CInt,
    range: Range<Int64>,
    mode: Win32.LockMode,
    wait: Bool,
    _ body: () throws(E) -> R
  ) throws(Win32.Error) -> Result<R, E>? {
    if range.isEmpty { return runCapturing(body) }
    let id = try fileID(of: descriptor)
    let conflict = locks[id, default: []].contains {
      $0.descriptor != descriptor && $0.range.overlaps(range)
        && ($0.mode == .exclusive || mode == .exclusive)
    }
    if conflict {
      // One thread waiting on a lock held in this process would deadlock.
      guard !wait else { fatalError("Simulated LockFileEx would wait forever on this thread") }
      return nil
    }
    // Take a real advisory lock too, so that other processes that lock
    // the file are excluded, where the descriptor's access mode allows it.
    let kind: FileDescriptor.FileLock.Kind = mode == .exclusive ? .write : .read
    let file = FileDescriptor(rawValue: descriptor)
    let advisory: Bool
    do {
      advisory = try file.lock(kind, byteRange: range, wait: wait)
    } catch Errno.badFileDescriptor {
      advisory = false
    } catch {
      throw Self.error(from: error)
    }
    if !advisory && !wait {
      if (try? file.lock(kind, byteRange: range)) == false { return nil }
    }
    locks[id, default: []].append(LockRecord(descriptor: descriptor, range: range, mode: mode))
    let result = runCapturing(body)
    locks[id]?.removeAll { $0.descriptor == descriptor && $0.range == range }
    if advisory {
      do {
        try file.unlock(byteRange: range)
      } catch {
        // SYS-0014: an unlock failure is thrown only if `body` succeeded.
        // (`if case .success = result` would consume the result: V16c.)
        if succeeded(result) { throw Self.error(from: error) }
      }
    }
    return result
  }

  private static func succeeded<R: ~Copyable, E: Error>(_ result: borrowing Result<R, E>) -> Bool {
    switch result {
    case .success: return true
    case .failure: return false
    }
  }

  private static func runCapturing<R: ~Copyable, E: Error>(
    _ body: () throws(E) -> R
  ) -> Result<R, E> {
    do {
      return .success(try body())
    } catch {
      return .failure(error)
    }
  }

  /// Fails with a lock violation if a lock denies this handle the range:
  /// another handle's exclusive lock, another handle's shared lock for a
  /// write, or this handle's own shared lock for a write.
  static func checkLocks(
    _ descriptor: CInt, range: Range<Int64>, writing: Bool
  ) throws(Win32.Error) {
    guard !locks.isEmpty, !range.isEmpty else { return }
    let id = try fileID(of: descriptor)
    for lock in locks[id, default: []] where lock.range.overlaps(range) {
      let mine = lock.descriptor == descriptor
      switch lock.mode {
      case .exclusive where !mine: throw .lockViolation
      case .shared where writing: throw .lockViolation
      default: continue
      }
    }
  }

  // MARK: I/O

  static func fileType(_ descriptor: CInt) throws(Win32.Error) -> Win32.FileType {
    let status = try posix { try FileDescriptor(rawValue: descriptor).stat() }
    switch status.type {
    case .regular, .directory, .symbolicLink: return .disk
    case .characterSpecial, .blockSpecial: return .character
    case .fifo, .socket: return .pipe
    default: return .unknown
    }
  }

  private static func seeks(_ descriptor: CInt) -> Bool {
    (try? fileType(descriptor)) == .disk
  }

  static func currentOffset(_ descriptor: CInt) throws(Win32.Error) -> Int64 {
    guard seeks(descriptor) else { return 0 }
    return try posix {
      try FileDescriptor(rawValue: descriptor).seek(offset: 0, from: .current)
    }
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  static func read(
    _ descriptor: CInt, fromAbsoluteOffset offset: Int64?, into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    if let offset, offset < 0 { throw .invalidParameter }
    guard access(of: descriptor)?.readsData ?? true else { throw .accessDenied }
    let file = FileDescriptor(rawValue: descriptor)
    // Not `try offset ?? currentOffset(descriptor)`: `??` rethrows, which
    // loses the thrown type.
    let start: Int64
    if let offset { start = offset } else { start = try currentOffset(descriptor) }
    try checkLocks(descriptor, range: start..<(start + Int64(span.freeCapacity)), writing: false)
    do {
      if let offset, seeks(descriptor) {
        let count = try file.read(fromAbsoluteOffset: offset, into: &span)
        // Windows: a read at an offset moves the file pointer past what it read.
        _ = try file.seek(offset: offset + Int64(count), from: .start)
        return count
      }
      return try file.read(into: &span)
    } catch {
      throw Self.error(from: error)
    }
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  static func readFully(
    _ descriptor: CInt, fromAbsoluteOffset offset: Int64?, into span: inout OutputRawSpan
  ) throws(Win32.Error) -> Int {
    let disk = seeks(descriptor)
    var total = 0
    var next = offset
    while span.freeCapacity > 0 {
      let count = try read(descriptor, fromAbsoluteOffset: next, into: &span)
      total += count
      if let current = next { next = current + Int64(count) }
      // A disk file comes up short only at its end; a pipe ends at zero.
      if count == 0 || (disk && span.freeCapacity > 0) { break }
    }
    return total
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  static func write(
    _ descriptor: CInt, _ span: RawSpan, toAbsoluteOffset offset: Int64?
  ) throws(Win32.Error) {
    if let offset, offset < 0 { throw .invalidParameter }
    guard access(of: descriptor)?.writesData ?? true else { throw .accessDenied }
    let file = FileDescriptor(rawValue: descriptor)
    let start: Int64
    if let offset { start = offset } else { start = try currentOffset(descriptor) }
    try checkLocks(descriptor, range: start..<(start + Int64(span.byteCount)), writing: true)
    do {
      if let offset, seeks(descriptor) {
        let count = try file.writeAll(toAbsoluteOffset: offset, span)
        // Windows: a write at an offset moves the file pointer past what it wrote.
        _ = try file.seek(offset: offset + Int64(count), from: .start)
      } else {
        // WriteFile on a synchronous handle takes the whole span; `write`
        // loops on the rare short write, as the draft's does.
        _ = try file.writeAll(span)
      }
    } catch {
      throw Self.error(from: error)
    }
  }

  @available(macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 2, *)
  static func append(_ descriptor: CInt, _ span: RawSpan) throws(Win32.Error) {
    guard span.byteCount <= Int(DWORD.max) else { throw .invalidParameter }
    guard access(of: descriptor)?.writesData ?? true else { throw .accessDenied }
    let file = FileDescriptor(rawValue: descriptor)
    // An OVERLAPPED offset of all ones appends atomically. So does a write
    // with O_APPEND set, which the simulation sets for this one write.
    try posix {
      let flags = try file.statusFlags()
      try file.setStatusFlags(flags.union(.append))
      defer { try? file.setStatusFlags(flags) }
      let count = try file.write(span)
      if count < span.byteCount { throw Errno.resourceTemporarilyUnavailable }
    }
  }

  static func seek(
    _ descriptor: CInt, offset: Int64, from origin: Win32.SeekOrigin
  ) throws(Win32.Error) -> Int64 {
    // Windows: seeking a pipe or console succeeds, and means nothing.
    guard seeks(descriptor) else { return 0 }
    let whence: FileDescriptor.SeekOrigin
    switch origin {
    case .start: whence = .start
    case .current: whence = .current
    case .end: whence = .end
    default: throw .invalidParameter
    }
    do {
      return try FileDescriptor(rawValue: descriptor).seek(offset: offset, from: whence)
    } catch Errno.invalidArgument {
      throw .negativeSeek
    } catch {
      throw Self.error(from: error)
    }
  }

  static func size(_ descriptor: CInt) throws(Win32.Error) -> Int64 {
    switch try fileType(descriptor) {
    case .pipe: return 0  // succeeds with an unspecified value
    case .character: throw .invalidFunction
    default:
      return try posix { try FileDescriptor(rawValue: descriptor).stat().size }
    }
  }

  static func flush(_ descriptor: CInt) throws(Win32.Error) {
    guard seeks(descriptor) else { return }
    guard access(of: descriptor)?.writesData ?? true else { throw .accessDenied }
    let file = FileDescriptor(rawValue: descriptor)
    // FlushFileBuffers also asks the device to commit its cache, which on
    // Darwin takes F_FULLFSYNC rather than fsync.
    try posix {
      #if SYSTEM_PACKAGE_DARWIN
      do { try file.synchronizeFully() } catch { try file.synchronize() }
      #else
      try file.synchronize()
      #endif
    }
  }

  static func resize(_ descriptor: CInt, to newSize: Int64) throws(Win32.Error) {
    guard newSize >= 0 else { throw .invalidParameter }
    guard access(of: descriptor)?.writesData ?? true else { throw .accessDenied }
    try posix { try FileDescriptor(rawValue: descriptor).resize(to: newSize) }
  }

  // MARK: Duplication and inheritance

  static func isInheritable(_ descriptor: CInt) throws(Win32.Error) -> Bool {
    try posix {
      !(try FileDescriptor(rawValue: descriptor).descriptorFlags().contains(.closeOnExec))
    }
  }

  static func setInheritable(_ descriptor: CInt, _ value: Bool) throws(Win32.Error) {
    try posix {
      try FileDescriptor(rawValue: descriptor).setDescriptorFlags(value ? [] : .closeOnExec)
    }
  }

  static func duplicate(_ descriptor: CInt, inheritable: Bool) throws(Win32.Error) -> CInt {
    let copy = try posix {
      try FileDescriptor(rawValue: descriptor).duplicate(closeOnExec: !inheritable)
    }
    // A duplicate shares the original's file object, so it takes the same
    // access and share mode, which can't conflict with the original.
    let original = opens.values.lazy.flatMap { $0 }.first { $0.descriptor == descriptor }
    let id = try fileID(of: copy.rawValue)
    opens[id, default: []].append(OpenRecord(
      descriptor: copy.rawValue, access: original?.access ?? .genericRead,
      share: original?.share ?? [.read, .write, .delete]))
    return copy.rawValue
  }

  // MARK: Paths and volumes

  static func finalPath(_ descriptor: CInt) throws(Win32.Error) -> FilePath {
    #if SYSTEM_PACKAGE_DARWIN
    // Windows would report a verbatim path, such as \\?\C:\dir\file.
    return try posix { try FileDescriptor(rawValue: descriptor).path() }
    #else
    throw .notSupported
    #endif
  }

  static func volumeInformation(_ descriptor: CInt) throws(Win32.Error) -> Win32.VolumeInformation {
    var info = statfs()
    guard fstatfs(descriptor, &info) == 0 else { throw error(from: Errno(rawValue: errno)) }
    func string<T>(_ tuple: T) -> String {
      withUnsafeBytes(of: tuple) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    var flags: Win32.FileSystemFlags = [.casePreservedNames, .unicodeOnDisk, .persistentACLs]
    if fpathconf(descriptor, _PC_CASE_SENSITIVE) == 1 { flags.insert(.caseSensitiveSearch) }
    if info.f_flags & UInt32(MNT_RDONLY) != 0 { flags.insert(.readOnlyVolume) }
    if fpathconf(descriptor, _PC_LINK_MAX) > 1 { flags.insert(.supportsHardLinks) }
    let mountPoint = string(info.f_mntonname)
    return Win32.VolumeInformation(
      name: mountPoint == "/" ? "" : String(mountPoint.split(separator: "/").last ?? ""),
      fileSystemName: string(info.f_fstypename).uppercased(),
      serialNumber: UInt32(bitPattern: info.f_fsid.val.0),
      maximumComponentLength: fpathconf(descriptor, _PC_NAME_MAX),
      flags: flags)
  }

  // MARK: Processes

  /// What the simulation knows about a process that a handle or a process
  /// descriptor refers to.
  private struct ProcessRecord {
    /// A kqueue watching for the process to exit, which a pidfd or a
    /// process handle would be on Linux or Windows.
    var queue: CInt
    /// The wait status, once the process has exited and been reaped.
    var status: CInt? = nil
    /// The exit code a simulated TerminateProcess asked for.
    var requestedExitCode: DWORD? = nil
  }

  nonisolated(unsafe) private static var processes: [pid_t: ProcessRecord] = [:]

  /// Opens a pollable reference to a process: a kqueue that becomes
  /// readable when it exits.
  static func watchProcess(_ id: ProcessID) throws(Errno) -> CInt {
    let queue = kqueue()
    guard queue >= 0 else { throw Errno(rawValue: errno) }
    var change = kevent(
      ident: UInt(id.rawValue), filter: Int16(EVFILT_PROC), flags: UInt16(EV_ADD | EV_ONESHOT),
      fflags: UInt32(NOTE_EXIT) | UInt32(NOTE_EXITSTATUS), data: 0, udata: nil)
    if kevent(queue, &change, 1, nil, 0, nil) != 0 {
      let failure = Errno(rawValue: errno)
      Darwin.close(queue)
      throw failure
    }
    if processes[id.rawValue] == nil {
      processes[id.rawValue] = ProcessRecord(queue: queue)
    }
    return queue
  }

  /// Waits until a watched process exits, or only checks if `block` is
  /// false, and returns its wait status. Reaps the process if it's a child,
  /// but remembers the status, so it can be asked for again.
  static func waitForExit(_ id: ProcessID, queue: CInt, block: Bool) throws(Errno) -> CInt? {
    if let status = processes[id.rawValue]?.status { return status }
    var event = kevent(ident: 0, filter: 0, flags: 0, fflags: 0, data: 0, udata: nil)
    var zero = timespec(tv_sec: 0, tv_nsec: 0)
    let count = block
      ? kevent(queue, nil, 0, &event, 1, nil)
      : kevent(queue, nil, 0, &event, 1, &zero)
    guard count >= 0 else { throw Errno(rawValue: errno) }
    guard count == 1 else { return nil }
    var status = CInt(truncatingIfNeeded: event.data)
    var reaped: CInt = 0
    if waitpid(id.rawValue, &reaped, 0) == id.rawValue { status = reaped }
    processes[id.rawValue, default: ProcessRecord(queue: queue)].status = status
    return status
  }

  /// A simulated TerminateProcess: SIGKILL, remembering the exit code.
  static func terminate(_ id: ProcessID, exitCode: DWORD) throws(Errno) {
    processes[id.rawValue]?.requestedExitCode = exitCode
    guard kill(id.rawValue, SIGKILL) == 0 else { throw Errno(rawValue: errno) }
  }

  /// A Windows exit code for a wait status: the code a process passed to
  /// exit, or the one a simulated TerminateProcess chose. A process that a
  /// signal ended, which Windows has no counterpart for, reports 128 plus
  /// the signal number, as a shell would.
  static func windowsExitCode(_ id: ProcessID, status: CInt) -> DWORD {
    if let requested = processes[id.rawValue]?.requestedExitCode { return requested }
    let signal = status & 0x7F
    if signal == 0 { return DWORD((status >> 8) & 0xFF) }
    return DWORD(128 + signal)
  }

  /// The process a queue from `watchProcess` watches.
  static func processID(watchedBy queue: CInt) -> ProcessID? {
    processes.first { $0.value.queue == queue }.map { ProcessID(rawValue: $0.key) }
  }

  static func forgetProcess(queue: CInt) {
    Darwin.close(queue)
  }
}

/// The byte offsets a lock range is resolved against: `0..<Int64.max`,
/// whose `index(after:)` saturates, as SYS-0014 describes.
private struct LockableBytes: Collection {
  var startIndex: Int64 { 0 }
  var endIndex: Int64 { .max }
  subscript(position: Int64) -> Int64 { position }
  func index(after i: Int64) -> Int64 { i == .max ? .max : i + 1 }
}

#endif // SIMULATE_PLATFORMS
