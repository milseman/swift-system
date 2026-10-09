/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if os(Windows)

import WinSDK

// MARK: - Creation flags

@available(System 199, *)
extension Win32 {
  /// How ``Win32/ProcessHandle/create(commandLine:application:environment:currentDirectory:standardInput:standardOutput:standardError:flags:)``
  /// creates a process.
  ///
  /// System adds `CREATE_UNICODE_ENVIRONMENT` and
  /// `EXTENDED_STARTUPINFO_PRESENT` itself, as its environment and standard
  /// handles need them.
  ///
  /// `CreateProcessW` takes these in its `dwCreationFlags` parameter.
  ///
  /// The corresponding C type is `DWORD`.
  @frozen
  public struct ProcessCreationFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// The process's first thread starts suspended, and runs once
    /// ``Win32/ThreadHandle/resume()`` resumes it.
    ///
    /// This lets the creator act on the process before any of its code
    /// runs, such as assigning it to a job.
    ///
    /// The corresponding C constant is `CREATE_SUSPENDED`.
    @_alwaysEmitIntoClient
    public static var suspended: ProcessCreationFlags { ProcessCreationFlags(rawValue: 0x0000_0004) }

    /// A console process doesn't share the caller's console, and has none
    /// until it creates or attaches to one.
    ///
    /// The corresponding C constant is `DETACHED_PROCESS`.
    @_alwaysEmitIntoClient
    public static var detached: ProcessCreationFlags { ProcessCreationFlags(rawValue: 0x0000_0008) }

    /// A console process gets a new console, rather than sharing the
    /// caller's.
    ///
    /// This flag can't be combined with ``detached``.
    ///
    /// The corresponding C constant is `CREATE_NEW_CONSOLE`.
    @_alwaysEmitIntoClient
    public static var newConsole: ProcessCreationFlags { ProcessCreationFlags(rawValue: 0x0000_0010) }

    /// The process is the root of a new process group, so a Ctrl+C in the
    /// console doesn't reach it, and a Ctrl+Break sent to the group does.
    ///
    /// The corresponding C constant is `CREATE_NEW_PROCESS_GROUP`.
    @_alwaysEmitIntoClient
    public static var newProcessGroup: ProcessCreationFlags {
      ProcessCreationFlags(rawValue: 0x0000_0200)
    }

    /// The process isn't in the caller's job, if the job allows breaking
    /// away.
    ///
    /// The corresponding C constant is `CREATE_BREAKAWAY_FROM_JOB`.
    @_alwaysEmitIntoClient
    public static var breakawayFromJob: ProcessCreationFlags {
      ProcessCreationFlags(rawValue: 0x0100_0000)
    }

    /// The process starts with the default error mode, rather than the
    /// caller's.
    ///
    /// The corresponding C constant is `CREATE_DEFAULT_ERROR_MODE`.
    @_alwaysEmitIntoClient
    public static var defaultErrorMode: ProcessCreationFlags {
      ProcessCreationFlags(rawValue: 0x0400_0000)
    }

    /// A console process runs with a console but no console window.
    ///
    /// The corresponding C constant is `CREATE_NO_WINDOW`.
    @_alwaysEmitIntoClient
    public static var noWindow: ProcessCreationFlags { ProcessCreationFlags(rawValue: 0x0800_0000) }
  }
}

// MARK: - Creating

@available(System 199, *)
extension Win32 {
  /// A process that ``Win32/ProcessHandle/create(commandLine:application:environment:currentDirectory:standardInput:standardOutput:standardError:flags:)``
  /// started, and its first thread.
  ///
  /// Both handles have every access right, and neither is inheritable.
  @frozen
  public struct CreatedProcess: ~Copyable, Sendable {
    /// The new process.
    public let process: Win32.ProcessHandle

    /// The process's first thread.
    ///
    /// A process created ``Win32/ProcessCreationFlags/suspended`` runs once
    /// ``Win32/ThreadHandle/resume()`` resumes this thread. Otherwise it's
    /// usually closed at once.
    public let thread: Win32.ThreadHandle

    /// The process's ID.
    public let processID: ProcessID

    /// The first thread's ID.
    public let threadID: Win32.ThreadID

    @_alwaysEmitIntoClient
    internal init(
      _process process: consuming Win32.ProcessHandle,
      thread: consuming Win32.ThreadHandle,
      processID: ProcessID,
      threadID: Win32.ThreadID
    ) {
      self.process = process
      self.thread = thread
      self.processID = processID
      self.threadID = threadID
    }
  }
}

@available(System 199, *)
extension Win32.ProcessHandle {
  /// Creates a process that runs a program.
  ///
  /// - Parameters:
  ///   - commandLine: The program's command line, as one string, which
  ///     Windows passes to the program unchanged. A C or Swift program splits
  ///     it into arguments by the C runtime's rules, so an argument that
  ///     contains a space, a tab, or a quotation mark must be quoted; System
  ///     doesn't quote. If `application` is `nil`, the command line's first
  ///     token names the program: Windows adds `.exe` to a name with no
  ///     extension, and searches for it in the calling program's directory,
  ///     the current directory, the system directories, and then the
  ///     calling process's `PATH`.
  ///   - application: The path of the program to run, which Windows doesn't
  ///     search for or add an extension to, or `nil` to take the program from
  ///     `commandLine`. By convention, `commandLine` still begins with the
  ///     program's name.
  ///   - environment: The program's environment, as `NAME=value` strings,
  ///     or `nil` for a copy of the calling process's. System sorts the
  ///     strings by name, ignoring case, as Windows requires of an
  ///     environment block, and keeps strings with the same name in order.
  ///   - currentDirectory: The program's current directory, or `nil` for the
  ///     calling process's. A relative path is resolved against the calling
  ///     process's. Unlike other paths, it doesn't get the `\\?\` prefix,
  ///     which Windows doesn't support for a current directory, so one
  ///     longer than `MAX_PATH` works only for a long-path-aware program.
  ///   - standardInput: The program's standard input, or `nil` for the
  ///     calling process's. The program receives a duplicate, so the handle
  ///     stays the caller's to close. The handle is borrowed, not consumed.
  ///   - standardOutput: The program's standard output, or `nil` for the
  ///     calling process's, as for `standardInput`.
  ///   - standardError: The program's standard error, or `nil` for the
  ///     calling process's, as for `standardInput`.
  ///   - flags: How to create the process.
  ///
  /// Pass a standard handle through a binding of optional type, which the
  /// call borrows:
  ///
  ///     let output: Win32.FileHandle? = try Win32.FileHandle.open(
  ///       "log.txt", access: .genericWrite, disposition: .createAlways)
  ///     let child = try Win32.ProcessHandle.create(
  ///       commandLine: "tool.exe --verbose", standardOutput: output)
  ///     try child.process.waitForExit()
  ///
  /// The program inherits its standard handles and no other handle, whether
  /// or not the handle is inheritable. If the calling process has no
  /// standard handles and passes none, the program's are Windows' default:
  /// a console program gets its console's.
  ///
  /// Throws ``Win32/Error/invalidParameter`` if `commandLine` or a string in
  /// `environment` contains a null character, or a string in `environment`
  /// is empty. Windows reports a program it can't find as
  /// ``Win32/Error/fileNotFound``.
  ///
  /// The corresponding C function is `CreateProcessW`, with
  /// `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`, `STARTUPINFOEXW` or `STARTUPINFOW`,
  /// `STARTF_USESTDHANDLES`, `CREATE_UNICODE_ENVIRONMENT`,
  /// `EXTENDED_STARTUPINFO_PRESENT`, `InitializeProcThreadAttributeList`,
  /// `UpdateProcThreadAttribute`, `DeleteProcThreadAttributeList`, and a
  /// `PROCESS_INFORMATION`, which this returns the parts of.
  @_alwaysEmitIntoClient
  public static func create(
    commandLine: String,
    application: FilePath? = nil,
    environment: [String]? = nil,
    currentDirectory: FilePath? = nil,
    standardInput: borrowing Win32.FileHandle? = nil,
    standardOutput: borrowing Win32.FileHandle? = nil,
    standardError: borrowing Win32.FileHandle? = nil,
    flags: Win32.ProcessCreationFlags = []
  ) throws(Win32.Error) -> Win32.CreatedProcess {
    let input: HANDLE?
    switch standardInput {
    case .some(let handle): input = handle._handle
    case .none: input = nil
    }
    let output: HANDLE?
    switch standardOutput {
    case .some(let handle): output = handle._handle
    case .none: output = nil
    }
    let error: HANDLE?
    switch standardError {
    case .some(let handle): error = handle._handle
    case .none: error = nil
    }
    let created = try Win32._createProcess(
      commandLine: commandLine,
      application: application,
      environment: environment,
      currentDirectory: currentDirectory,
      standardHandles: (input, output, error),
      flags: flags.rawValue
    ).get()
    return Win32.CreatedProcess(
      _process: Win32.ProcessHandle(_owning: created.process),
      thread: Win32.ThreadHandle(_owning: created.thread),
      processID: ProcessID(rawValue: created.processID),
      threadID: Win32.ThreadID(rawValue: created.threadID))
  }
}

@available(System 199, *)
extension Win32 {
  @usableFromInline
  internal static func _createProcess(
    commandLine: String,
    application: FilePath?,
    environment: [String]?,
    currentDirectory: FilePath?,
    standardHandles: (HANDLE?, HANDLE?, HANDLE?),
    flags: DWORD
  ) -> Result<(process: HANDLE, thread: HANDLE, processID: DWORD, threadID: DWORD), Win32.Error> {
    // CreateProcessW can write to its command line, so it gets a copy.
    var command = Array(commandLine.utf16)
    guard !command.contains(0) else { return .failure(.invalidParameter) }
    command.append(0)
    var block: [WCHAR]? = nil
    if let environment {
      switch _environmentBlock(environment) {
      case .success(let built): block = built
      case .failure(let error): return .failure(error)
      }
    }
    let inherited: [HANDLE?]
    switch _inheritableStandardHandles(standardHandles) {
    case .success(let handles): inherited = handles
    case .failure(let error): return .failure(error)
    }
    defer {
      for case let handle? in inherited { _ = system_CloseHandle(handle) }
    }
    // Windows doesn't support the \\?\ prefix for a current directory, so
    // Rust's Command::current_dir removes it.
    return _withOptionalCanonicalPath(application) { application in
      _withOptionalCanonicalPath(currentDirectory, prefix: .never) { currentDirectory in
        _withStandardHandleList(inherited) { attributes in
          var startupInfo = STARTUPINFOEXW()
          var creationFlags = flags | _CREATE_UNICODE_ENVIRONMENT
          if let attributes {
            startupInfo.StartupInfo.cb = DWORD(MemoryLayout<STARTUPINFOEXW>.size)
            startupInfo.StartupInfo.dwFlags |= _STARTF_USESTDHANDLES
            startupInfo.StartupInfo.hStdInput = inherited[0]
            startupInfo.StartupInfo.hStdOutput = inherited[1]
            startupInfo.StartupInfo.hStdError = inherited[2]
            startupInfo.lpAttributeList = attributes
            creationFlags |= _EXTENDED_STARTUPINFO_PRESENT
          } else {
            startupInfo.StartupInfo.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)
          }
          var information = PROCESS_INFORMATION()
          let created = command.withUnsafeMutableBufferPointer { command in
            _withOptionalMutableBuffer(&block) { block in
              withUnsafeMutablePointer(to: &startupInfo) { startupInfo in
                system_CreateProcessW(
                  application, command.baseAddress, nil, nil, attributes != nil,
                  creationFlags, block, currentDirectory,
                  startupInfo.pointer(to: \.StartupInfo)!, &information)
              }
            }
          }
          // Captured at once: closing the duplicates can replace it.
          guard created else { return .failure(Win32.Error(GetLastError())) }
          return .success(
            (information.hProcess, information.hThread, information.dwProcessId,
             information.dwThreadId))
        }
      }
    }
  }

  /// A Unicode environment block of `entries`, sorted by name as Windows
  /// requires: each `NAME=value` string and its terminator, then one more
  /// terminator.
  internal static func _environmentBlock(_ entries: [String]) -> Result<[WCHAR], Win32.Error> {
    let units = entries.map { Array($0.utf16) }
    // An empty string would end the block early.
    guard units.allSatisfy({ !$0.isEmpty && !$0.contains(0) }) else {
      return .failure(.invalidParameter)
    }
    // A name ends at the first "=" after its first character, since the
    // variables that record each drive's current directory, such as
    // "=C:=C:\dir", have names that begin with one.
    let equals = WCHAR(UInt8(ascii: "="))
    let names = units.map { entry -> ArraySlice<WCHAR> in
      let end = entry.dropFirst().firstIndex(of: equals) ?? entry.endIndex
      return entry[..<end]
    }
    // Ties keep their order, so a sort by index breaks them.
    let order = units.indices.sorted { a, b in
      let comparison = _compareIgnoringCase(names[a], names[b])
      return comparison < 0 || (comparison == 0 && a < b)
    }
    var block: [WCHAR] = []
    block.reserveCapacity(units.reduce(1) { $0 + $1.count + 1 })
    for index in order {
      block.append(contentsOf: units[index])
      block.append(0)
    }
    // An empty block is two terminators.
    if order.isEmpty { block.append(0) }
    block.append(0)
    return .success(block)
  }

  /// Compares two strings as Windows orders environment variable names:
  /// ordinally, after converting each to uppercase with the system's table.
  internal static func _compareIgnoringCase(
    _ lhs: ArraySlice<WCHAR>, _ rhs: ArraySlice<WCHAR>
  ) -> Int {
    lhs.withUnsafeBufferPointer { lhs in
      rhs.withUnsafeBufferPointer { rhs in
        // CompareStringOrdinal accepts null pointers only with a count of
        // zero, and an empty slice may have no storage.
        let empty: [WCHAR] = [0]
        return empty.withUnsafeBufferPointer { empty in
          let result = system_CompareStringOrdinal(
            lhs.baseAddress ?? empty.baseAddress!, CInt(lhs.count),
            rhs.baseAddress ?? empty.baseAddress!, CInt(rhs.count), true)
          switch result {
          case _CSTR_LESS_THAN: return -1
          case _CSTR_GREATER_THAN: return 1
          default: return 0
          }
        }
      }
    }
  }

  /// Inheritable duplicates of the standard handles a new process gets: the
  /// given ones, and the calling process's where none is given. `nil` where
  /// there's neither.
  internal static func _inheritableStandardHandles(
    _ given: (HANDLE?, HANDLE?, HANDLE?)
  ) -> Result<[HANDLE?], Win32.Error> {
    let sources = [
      (given.0, _STD_INPUT_HANDLE), (given.1, _STD_OUTPUT_HANDLE), (given.2, _STD_ERROR_HANDLE),
    ]
    var duplicates: [HANDLE?] = []
    for (handle, standard) in sources {
      var source = handle
      if source == nil {
        // NULL for no handle; INVALID_HANDLE_VALUE if it can't be read.
        let own = system_GetStdHandle(standard)
        if own != INVALID_HANDLE_VALUE { source = own }
      }
      guard let source else {
        duplicates.append(nil)
        continue
      }
      switch _duplicateHandle(source, access: nil, inheritable: true) {
      case .success(let duplicate):
        duplicates.append(duplicate)
      case .failure(let error):
        for case let duplicate? in duplicates { _ = system_CloseHandle(duplicate) }
        return .failure(error)
      }
    }
    return .success(duplicates)
  }

  /// Calls `body` with an attribute list that limits a new process's
  /// inherited handles to `handles`, or with `nil` if there are none, in
  /// which case the process inherits nothing.
  internal static func _withStandardHandleList<Success>(
    _ handles: [HANDLE?],
    _ body: (LPPROC_THREAD_ATTRIBUTE_LIST?) -> Result<Success, Win32.Error>
  ) -> Result<Success, Win32.Error> {
    let listed = handles.compactMap { $0 }
    guard !listed.isEmpty else { return body(nil) }
    // The first call fails, reporting the size a list of one attribute
    // needs.
    var size: SIZE_T = 0
    _ = system_InitializeProcThreadAttributeList(nil, 1, 0, &size)
    guard size > 0 else { return .failure(Win32.Error(GetLastError())) }
    let storage = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size), alignment: MemoryLayout<UInt64>.alignment)
    defer { storage.deallocate() }
    let list = LPPROC_THREAD_ATTRIBUTE_LIST(storage)
    guard system_InitializeProcThreadAttributeList(list, 1, 0, &size) else {
      return .failure(Win32.Error(GetLastError()))
    }
    defer { system_DeleteProcThreadAttributeList(list) }
    // The list refers to the handles' storage until it's deleted.
    return withUnsafeTemporaryAllocation(of: HANDLE?.self, capacity: listed.count) { buffer in
      for (index, handle) in listed.enumerated() {
        buffer.initializeElement(at: index, to: handle)
      }
      defer { buffer.deinitialize() }
      guard system_UpdateProcThreadAttribute(
        list, 0, _PROC_THREAD_ATTRIBUTE_HANDLE_LIST, UnsafeMutableRawPointer(buffer.baseAddress!),
        SIZE_T(MemoryLayout<HANDLE>.stride * listed.count))
      else {
        return .failure(Win32.Error(GetLastError()))
      }
      return body(list)
    }
  }
}

/// Calls `body` with `path` as Win32 functions should receive it, or with
/// `nil`.
internal func _withOptionalCanonicalPath<Success>(
  _ path: FilePath?,
  prefix: Win32.ExtendedLengthPrefix = .whenNeeded,
  _ body: (UnsafePointer<WCHAR>?) -> Result<Success, Win32.Error>
) -> Result<Success, Win32.Error> {
  guard let path else { return body(nil) }
  return _withCanonicalPath(path, prefix: prefix) { body($0) }
}

/// Calls `body` with the storage of `buffer`, or with `nil`.
internal func _withOptionalMutableBuffer<R>(
  _ buffer: inout [WCHAR]?,
  _ body: (UnsafeMutableRawPointer?) -> R
) -> R {
  guard buffer != nil else { return body(nil) }
  return buffer!.withUnsafeMutableBytes { body($0.baseAddress) }
}

#endif // os(Windows)
