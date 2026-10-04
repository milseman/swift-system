/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Anonymous pipes

@available(System 199, *)
extension Win32.FileHandle {
  /// The two ends of an anonymous pipe, owned.
  @frozen
  public struct Pipe: ~Copyable, Sendable {
    /// The end that reads what ``writeEnd`` writes.
    public var readEnd: Win32.FileHandle

    /// The end that writes what ``readEnd`` reads.
    public var writeEnd: Win32.FileHandle

    /// Creates a pipe from its two ends, taking ownership of both.
    @_alwaysEmitIntoClient
    public init(readEnd: consuming Win32.FileHandle, writeEnd: consuming Win32.FileHandle) {
      self.readEnd = readEnd
      self.writeEnd = writeEnd
    }
  }

  /// Creates an anonymous pipe: a one-way channel whose read end reads, in
  /// order, what its write end writes.
  ///
  /// - Parameter bufferSize: How many bytes the pipe holds before a write
  ///   waits for a read, as a suggestion, or `nil`, the default, for
  ///   Windows' default size.
  ///
  /// A read waits until the pipe holds data, and returns 0 once the pipe is
  /// empty and its write end has closed; a write to a pipe whose read end
  /// has closed throws ``Win32/Error/noData``.
  ///
  /// Neither end is inheritable: ``Win32/ProcessHandle/create(commandLine:application:environment:currentDirectory:standardInput:standardOutput:standardError:flags:)``
  /// gives a new process the ends it's passed, inheritable or not.
  ///
  /// An anonymous pipe doesn't support overlapped I/O. For a pipe with an
  /// overlapped end, create a named pipe with
  /// ``Win32/OverlappedFileHandle/createNamedPipe(_:direction:type:maximumInstances:firstInstance:acceptsRemoteClients:bufferSize:inheritable:securityDescriptor:)``.
  ///
  /// The corresponding C function is `CreatePipe`.
  @_alwaysEmitIntoClient
  public static func pipe(bufferSize: Int? = nil) throws(Win32.Error) -> Pipe {
    let ends = try Win32._createPipe(bufferSize: bufferSize).get()
    return Pipe(
      readEnd: Win32.FileHandle(_owning: ends.readEnd),
      writeEnd: Win32.FileHandle(_owning: ends.writeEnd))
  }
}

// MARK: - Named pipes

@available(System 199, *)
extension Win32 {
  /// Which way a named pipe's data flows.
  ///
  /// The corresponding C type is the `PIPE_ACCESS_*` part of
  /// `CreateNamedPipeW`'s `dwOpenMode`.
  @frozen
  public struct PipeDirection: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed direction from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// From clients to the server: the server's end reads, and a client's
    /// writes.
    ///
    /// The corresponding C constant is `PIPE_ACCESS_INBOUND`.
    @_alwaysEmitIntoClient
    public static var inbound: PipeDirection { PipeDirection(rawValue: 0x1) }

    /// From the server to clients: the server's end writes, and a client's
    /// reads.
    ///
    /// The corresponding C constant is `PIPE_ACCESS_OUTBOUND`.
    @_alwaysEmitIntoClient
    public static var outbound: PipeDirection { PipeDirection(rawValue: 0x2) }

    /// Both ways: each end reads what the other writes.
    ///
    /// The corresponding C constant is `PIPE_ACCESS_DUPLEX`.
    @_alwaysEmitIntoClient
    public static var duplex: PipeDirection { PipeDirection(rawValue: 0x3) }
  }

  /// Whether a pipe carries a stream of bytes or a series of messages.
  ///
  /// The corresponding C type is the `PIPE_TYPE_*` part of
  /// `CreateNamedPipeW`'s `dwPipeMode`.
  @frozen
  public struct PipeType: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C value.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates a strongly-typed type from a raw C value.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// A stream of bytes, as a POSIX pipe carries: a read returns what the
    /// pipe holds, up to the buffer's size, whatever writes put it there.
    ///
    /// The corresponding C constant is `PIPE_TYPE_BYTE`.
    @_alwaysEmitIntoClient
    public static var byteStream: PipeType { PipeType(rawValue: 0x0) }

    /// A series of messages, each the bytes of one write. An end that
    /// reads messages reads at most one each time; a buffer shorter than
    /// the message reads part of it, and the next read the rest.
    ///
    /// The corresponding C constant is `PIPE_TYPE_MESSAGE`.
    @_alwaysEmitIntoClient
    public static var message: PipeType { PipeType(rawValue: 0x4) }
  }
}

@available(System 199, *)
extension Win32.FileHandle {
  /// Creates an instance of a named pipe, and returns its server's end.
  ///
  /// - Parameters:
  ///   - name: The pipe's name: `\\.\pipe\`, then a name of up to 256
  ///     characters, which Windows compares without regard to case.
  ///   - direction: Which way data flows.
  ///   - type: Whether the pipe carries bytes or messages. The server's
  ///     end reads them as they're written; a client's end reads bytes
  ///     until ``setPipeMode(readMode:blocking:)`` changes it.
  ///   - maximumInstances: How many instances of the pipe can exist at
  ///     once, from 1 to 254, or `nil` for no limit. The first instance
  ///     sets it. The default is 1.
  ///   - firstInstance: Whether to fail with ``Win32/Error/accessDenied`` if
  ///     an instance of the pipe exists, so that a process that created the
  ///     name first can't serve this server's clients. Pass `false` for
  ///     another instance of a pipe this server created. The default is
  ///     `true`.
  ///   - acceptsRemoteClients: Whether clients on other computers can
  ///     connect, through the network. The default is `false`.
  ///   - bufferSize: How many bytes the pipe holds each way before a write
  ///     waits, as a suggestion: Windows rounds it. The default, 64 KiB, is
  ///     the size Rust's standard library and libuv ask for.
  ///   - inheritable: Whether child processes created with handle
  ///     inheritance enabled receive a copy of this handle.
  ///   - securityDescriptor: Who can open the pipe, or `nil` for Windows'
  ///     default: full control for the local system account, the
  ///     administrators and the creator, and reading for everyone.
  ///
  /// A client connects by opening the name with
  /// ``open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``.
  /// The server waits for one with ``waitForClient()``, unless it opened
  /// the client's end itself, as a process does for a child's standard
  /// handles.
  ///
  /// The corresponding C function is `CreateNamedPipeW`.
  @_alwaysEmitIntoClient
  public static func createNamedPipe(
    _ name: FilePath,
    direction: Win32.PipeDirection,
    type: Win32.PipeType = .byteStream,
    maximumInstances: Int? = 1,
    firstInstance: Bool = true,
    acceptsRemoteClients: Bool = false,
    bufferSize: Int = 65_536,
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil
  ) throws(Win32.Error) -> Win32.FileHandle {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    return Win32.FileHandle(_owning: try Win32._createNamedPipe(
      name, direction: direction.rawValue, type: type.rawValue,
      maximumInstances: maximumInstances, firstInstance: firstInstance,
      acceptsRemoteClients: acceptsRemoteClients, bufferSize: bufferSize,
      inheritable: inheritable, securityDescriptor: rawDescriptor, overlapped: false
    ).get())
  }

  /// Waits for a client to open this server's end of a named pipe.
  ///
  /// Returns at once if a client opened it since it was created or
  /// disconnected. Throws ``Win32/Error/noData`` if a client opened it and
  /// closed its end already; call ``disconnectClient()`` before waiting for
  /// another.
  ///
  /// The corresponding C function is `ConnectNamedPipe`.
  @_alwaysEmitIntoClient
  public func waitForClient() throws(Win32.Error) {
    try Win32._waitForClient(_handle).get()
  }

  /// Disconnects this server's end of a named pipe from its client, so that
  /// the instance can serve another.
  ///
  /// Data that the client hasn't read is discarded: call ``flush()`` first
  /// to wait until it has. The client's end stays open, and its reads and
  /// writes fail.
  ///
  /// The corresponding C function is `DisconnectNamedPipe`.
  @_alwaysEmitIntoClient
  public func disconnectClient() throws(Win32.Error) {
    try Win32._disconnectClient(_handle).get()
  }

  /// The number of bytes a pipe holds for this end to read, which a read
  /// would return without waiting.
  ///
  /// Throws ``Win32/Error/brokenPipe`` once the pipe is empty and its other
  /// end has closed: the end of its data, where a read returns 0. Needs
  /// read access.
  ///
  /// The corresponding C function is `PeekNamedPipe`.
  @_alwaysEmitIntoClient
  public func bytesAvailable() throws(Win32.Error) -> Int {
    try Win32._bytesAvailable(_handle).get()
  }

  /// Sets how this end of a pipe reads, and whether its reads and writes
  /// wait.
  ///
  /// - Parameters:
  ///   - readMode: Whether reads return bytes or whole messages. Only an end
  ///     of a message pipe can read messages. The default is
  ///     ``Win32/PipeType/byteStream``.
  ///   - blocking: Whether a read waits for data, and a write for room.
  ///     With `false`, Windows' nonblocking mode, they return at once: a
  ///     read of an empty pipe fails, as POSIX's does with `O_NONBLOCK`, and
  ///     a write that doesn't fit writes nothing, which
  ///     ``write(_:toAbsoluteOffset:)`` reports as
  ///     ``Win32/Error/incompleteTransfer``. Microsoft supports nonblocking
  ///     mode for compatibility with LAN Manager 2.0, and recommends
  ///     overlapped I/O instead. The default is `true`.
  ///
  /// Needs write access, or, for an end that only reads,
  /// ``Win32/AccessMask/writeAttributes`` as well as read access.
  ///
  /// The corresponding C function is `SetNamedPipeHandleState`.
  @_alwaysEmitIntoClient
  public func setPipeMode(
    readMode: Win32.PipeType = .byteStream,
    blocking: Bool = true
  ) throws(Win32.Error) {
    try Win32._setPipeMode(_handle, readMode: readMode.rawValue, blocking: blocking).get()
  }
}

@available(System 199, *)
extension Win32.OverlappedFileHandle {
  /// Creates an instance of a named pipe, and returns its server's end, for
  /// overlapped I/O.
  ///
  /// The parameters and errors are those of
  /// ``Win32/FileHandle/createNamedPipe(_:direction:type:maximumInstances:firstInstance:acceptsRemoteClients:bufferSize:inheritable:securityDescriptor:)``,
  /// with `FILE_FLAG_OVERLAPPED` added to the pipe's mode. A client's end is
  /// overlapped only if it opens the pipe with ``open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:)``:
  /// give a child process an end opened with
  /// ``Win32/FileHandle/open(_:access:shareMode:disposition:attributes:flags:inheritable:securityDescriptor:templateFile:)``,
  /// since a program's synchronous reads and writes of an overlapped handle
  /// can report that they finished before they have.
  ///
  /// The corresponding C function is `CreateNamedPipeW`, with
  /// `FILE_FLAG_OVERLAPPED`.
  @_alwaysEmitIntoClient
  public static func createNamedPipe(
    _ name: FilePath,
    direction: Win32.PipeDirection,
    type: Win32.PipeType = .byteStream,
    maximumInstances: Int? = 1,
    firstInstance: Bool = true,
    acceptsRemoteClients: Bool = false,
    bufferSize: Int = 65_536,
    inheritable: Bool = false,
    securityDescriptor: borrowing Win32.SecurityDescriptor? = nil
  ) throws(Win32.Error) -> Win32.OverlappedFileHandle {
    let rawDescriptor: PSECURITY_DESCRIPTOR?
    switch securityDescriptor {
    case .some(let descriptor): rawDescriptor = descriptor._pointer
    case .none: rawDescriptor = nil
    }
    return Win32.OverlappedFileHandle(_owning: try Win32._createNamedPipe(
      name, direction: direction.rawValue, type: type.rawValue,
      maximumInstances: maximumInstances, firstInstance: firstInstance,
      acceptsRemoteClients: acceptsRemoteClients, bufferSize: bufferSize,
      inheritable: inheritable, securityDescriptor: rawDescriptor, overlapped: true
    ).get())
  }

  /// The number of bytes a pipe holds for this end to read, which a read
  /// would finish with at once.
  ///
  /// This doesn't wait, or take an `OVERLAPPED`. Throws
  /// ``Win32/Error/brokenPipe`` once the pipe is empty and its other end
  /// has closed. Needs read access.
  ///
  /// The corresponding C function is `PeekNamedPipe`.
  @_alwaysEmitIntoClient
  public func bytesAvailable() throws(Win32.Error) -> Int {
    try Win32._bytesAvailable(_handle).get()
  }
}

// MARK: - Internals

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createPipe(
    bufferSize: Int?
  ) -> Result<(readEnd: HANDLE, writeEnd: HANDLE), Win32.Error> {
    guard let size = DWORD(exactly: bufferSize ?? 0) else { return .failure(.invalidParameter) }
    var readEnd: HANDLE? = nil
    var writeEnd: HANDLE? = nil
    guard system_CreatePipe(&readEnd, &writeEnd, size), let readEnd, let writeEnd else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success((readEnd, writeEnd))
  }

  @usableFromInline
  internal static func _createNamedPipe(
    _ name: FilePath,
    direction: DWORD,
    type: DWORD,
    maximumInstances: Int?,
    firstInstance: Bool,
    acceptsRemoteClients: Bool,
    bufferSize: Int,
    inheritable: Bool,
    securityDescriptor: PSECURITY_DESCRIPTOR?,
    overlapped: Bool
  ) -> Result<HANDLE, Win32.Error> {
    let instances: DWORD
    if let maximumInstances {
      // PIPE_UNLIMITED_INSTANCES, 255, is the only value past 254.
      guard (1...254).contains(maximumInstances) else { return .failure(.invalidParameter) }
      instances = DWORD(maximumInstances)
    } else {
      instances = _PIPE_UNLIMITED_INSTANCES
    }
    guard let size = DWORD(exactly: bufferSize) else { return .failure(.invalidParameter) }
    var openMode = direction
    if firstInstance { openMode |= _FILE_FLAG_FIRST_PIPE_INSTANCE }
    if overlapped { openMode |= _FILE_FLAG_OVERLAPPED }
    // The server's end reads as the pipe is written, and waits.
    var pipeMode = type
    if type == Win32.PipeType.message.rawValue { pipeMode |= _PIPE_READMODE_MESSAGE }
    if !acceptsRemoteClients { pipeMode |= _PIPE_REJECT_REMOTE_CLIENTS }
    return name.withPlatformString { name in
      var securityAttributes = SECURITY_ATTRIBUTES(
        nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
        lpSecurityDescriptor: securityDescriptor,
        bInheritHandle: WindowsBool(inheritable))
      // The default time-out, 0, is 50 milliseconds, for a client's
      // WaitNamedPipeW.
      let handle = system_CreateNamedPipeW(
        name, openMode, pipeMode, instances, size, size, 0, &securityAttributes)
      guard let handle, handle != INVALID_HANDLE_VALUE else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(handle)
    }
  }

  @usableFromInline
  internal static func _waitForClient(_ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_ConnectNamedPipe(handle) else {
      // A client that opened the pipe before the wait is connected too.
      let error = GetLastError()
      return error == _ERROR_PIPE_CONNECTED ? .success(()) : .failure(Win32.Error(error))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _disconnectClient(_ handle: HANDLE) -> Result<Void, Win32.Error> {
    guard system_DisconnectNamedPipe(handle) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }

  @usableFromInline
  internal static func _bytesAvailable(_ handle: HANDLE) -> Result<Int, Win32.Error> {
    var available: DWORD = 0
    guard system_PeekNamedPipe(handle, &available) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(Int(available))
  }

  @usableFromInline
  internal static func _setPipeMode(
    _ handle: HANDLE, readMode: DWORD, blocking: Bool
  ) -> Result<Void, Win32.Error> {
    var mode = readMode == Win32.PipeType.message.rawValue ? _PIPE_READMODE_MESSAGE : 0
    if !blocking { mode |= _PIPE_NOWAIT }
    guard system_SetNamedPipeHandleState(handle, &mode) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
