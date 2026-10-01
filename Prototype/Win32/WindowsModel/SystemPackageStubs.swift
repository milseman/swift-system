// Stand-ins for the SystemPackage declarations that Sources/System/Win32 and
// its Windows tests use, as those declarations are on Windows, for
// Prototype/Win32/check-windows.sh. The harness can't build SystemPackage
// for Windows, so it builds the Win32 files with these instead.
//
// Each declaration marked `// mirrors: <file>` must have the same signature
// as the real one; check-windows.sh checks it, with whitespace collapsed.
// The bodies are placeholders: the harness compiles, it doesn't run.

import WinSDK

public enum CInterop {
  public typealias PlatformChar = UInt16 // mirrors: Sources/System/Internals/CInterop.swift
  public typealias PlatformUnicodeEncoding = UTF16 // mirrors: Sources/System/Internals/CInterop.swift
  public typealias Mode = CInt
}

public typealias CModeT = CInt // mirrors: Sources/System/Internals/CInterop.swift

// MARK: - FilePath

public struct FilePath: Hashable, Sendable {
  internal var _storage: [CInterop.PlatformChar]

  public init() { // mirrors: Sources/System/FilePath/FilePath.swift
    _storage = [0]
  }

  public init(_ string: String) {
    _storage = Array(string.utf16) + [0]
  }

  public init(platformString: UnsafePointer<CInterop.PlatformChar>) { // mirrors: Sources/System/FilePath/FilePathString.swift
    var storage: [CInterop.PlatformChar] = []
    var p = platformString
    while p.pointee != 0 { storage.append(p.pointee); p += 1 }
    _storage = storage + [0]
  }

  public func withPlatformString<Result>( // mirrors: Sources/System/FilePath/FilePathString.swift
    _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> Result
  ) rethrows -> Result {
    try _storage.withUnsafeBufferPointer { try body($0.baseAddress!) }
  }

  public var string: String {
    String(decoding: _storage.dropLast(), as: UTF16.self)
  }

  public var isAbsolute: Bool { // mirrors: Sources/System/FilePath/FilePathSyntax.swift
    _storage.count > 3
  }

  public var isEmpty: Bool { _storage.count == 1 } // mirrors: Sources/System/FilePath/FilePathSyntax.swift

  public __consuming func appending(_ other: __owned String) -> FilePath { // mirrors: Sources/System/FilePath/FilePathSyntax.swift
    FilePath(string + "\\" + other)
  }

  public struct Component: Hashable, Sendable {
    public init?(_ string: String) {}
  }
}

extension FilePath: ExpressibleByStringLiteral {
  public init(stringLiteral: String) { self.init(stringLiteral) }
}

extension FilePath.Component: ExpressibleByStringLiteral {
  public init(stringLiteral: String) { self.init(stringLiteral)! }
}

extension FilePath: CustomStringConvertible {
  public var description: String { string }
}

extension String {
  public init(platformString: UnsafePointer<CInterop.PlatformChar>) { // mirrors: Sources/System/PlatformString.swift
    self = FilePath(platformString: platformString).string
  }
}

internal func withTemporaryFilePath<R>( // mirrors: Sources/System/FilePath/FilePathTemp.swift
  basename: FilePath.Component,
  _ body: (FilePath) throws -> R
) throws -> R {
  try body(FilePath("C:\\Temp"))
}

// MARK: - Errno

@frozen
public struct Errno: RawRepresentable, Error, Hashable, Codable { // mirrors: Sources/System/Errno.swift
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue } // mirrors: Sources/System/Errno.swift

  // The members that share a name with a Win32.Error code, as the ~=
  // resolution depends on them, and the ones the Win32 files throw.
  @_alwaysEmitIntoClient
  public static var noSuchFileOrDirectory: Errno { .init(rawValue: 2) }
  @_alwaysEmitIntoClient
  public static var badFileDescriptor: Errno { .init(rawValue: 9) }
  @_alwaysEmitIntoClient
  public static var permissionDenied: Errno { .init(rawValue: 13) }
  @_alwaysEmitIntoClient
  public static var fileExists: Errno { .init(rawValue: 17) }
  @_alwaysEmitIntoClient
  public static var invalidArgument: Errno { .init(rawValue: 22) }
  @_alwaysEmitIntoClient
  public static var fileTooLarge: Errno { .init(rawValue: 27) }
  @_alwaysEmitIntoClient
  public static var noSpace: Errno { .init(rawValue: 28) }
  @_alwaysEmitIntoClient
  public static var brokenPipe: Errno { .init(rawValue: 32) }
  @_alwaysEmitIntoClient
  public static var outOfRange: Errno { .init(rawValue: 34) }
  @_alwaysEmitIntoClient
  public static var noData: Errno { .init(rawValue: 120) }
  @_alwaysEmitIntoClient
  public static var notSupported: Errno { .init(rawValue: 129) }

  @_alwaysEmitIntoClient
  public static var current: Errno { // mirrors: Sources/System/Errno.swift
    get { Errno(rawValue: 0) }
    set {}
  }
}

extension Errno {
  @_alwaysEmitIntoClient
  @_disfavoredOverload
  public static func ~=(_ lhs: Errno, _ rhs: Error) -> Bool { // mirrors: Sources/System/Errno.swift
    guard let value = rhs as? Errno else { return false }
    return lhs == value
  }
}

// MARK: - FileDescriptor

@frozen
public struct FileDescriptor: RawRepresentable, Hashable, Codable { // mirrors: Sources/System/FileDescriptor.swift
  @_alwaysEmitIntoClient
  public let rawValue: CInt

  @_alwaysEmitIntoClient
  public init(rawValue: CInt) { self.rawValue = rawValue } // mirrors: Sources/System/FileDescriptor.swift

  @frozen
  public struct AccessMode: RawRepresentable, Sendable, Hashable, Codable { // mirrors: Sources/System/FileDescriptor.swift
    @_alwaysEmitIntoClient
    public var rawValue: CInt
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
    @_alwaysEmitIntoClient
    public static var readOnly: AccessMode { AccessMode(rawValue: 0) }
    @_alwaysEmitIntoClient
    public static var writeOnly: AccessMode { AccessMode(rawValue: 1) }
    @_alwaysEmitIntoClient
    public static var readWrite: AccessMode { AccessMode(rawValue: 2) }
  }

  @frozen
  public struct OpenOptions: OptionSet, Sendable, Hashable, Codable { // mirrors: Sources/System/FileDescriptor.swift
    @_alwaysEmitIntoClient
    public var rawValue: CInt
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
    @_alwaysEmitIntoClient
    public static var create: OpenOptions { OpenOptions(rawValue: 0x100) }
    @_alwaysEmitIntoClient
    public static var truncate: OpenOptions { OpenOptions(rawValue: 0x200) }
  }

  @frozen
  public enum SeekOrigin: Sendable {
    case start, current, end
  }

  @_alwaysEmitIntoClient
  public static func open( // mirrors: Sources/System/FileOperations.swift
    _ path: FilePath,
    _ mode: FileDescriptor.AccessMode,
    options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
    permissions: FilePermissions? = nil,
    retryOnInterrupt: Bool = true
  ) throws -> FileDescriptor {
    FileDescriptor(rawValue: 3)
  }

  @_alwaysEmitIntoClient
  public func close() throws {} // mirrors: Sources/System/FileOperations.swift

  @_alwaysEmitIntoClient
  public func read( // mirrors: Sources/System/FileOperations.swift
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int { 0 }

  @_alwaysEmitIntoClient
  public func write( // mirrors: Sources/System/FileOperations.swift
    _ buffer: UnsafeRawBufferPointer,
    retryOnInterrupt: Bool = true
  ) throws -> Int { 0 }

  @_alwaysEmitIntoClient
  @discardableResult
  public func seek( // mirrors: Sources/System/FileOperations.swift
    offset: Int64, from whence: FileDescriptor.SeekOrigin
  ) throws -> Int64 { 0 }
}

@frozen
public struct FilePermissions: OptionSet, Sendable, Hashable, Codable { // mirrors: Sources/System/FilePermissions.swift
  @_alwaysEmitIntoClient
  public let rawValue: CModeT
  @_alwaysEmitIntoClient
  public init(rawValue: CModeT) { self.rawValue = rawValue } // mirrors: Sources/System/FilePermissions.swift
  @_alwaysEmitIntoClient
  public static var ownerReadWrite: FilePermissions { [.init(rawValue: 0o600)] }
}

// MARK: - Internals

internal func _mapWindowsErrorToErrno(_ errorCode: DWORD) -> CInt { 22 } // mirrors: Sources/System/Internals/WindowsSyscallAdapters.swift

internal func system_close(_ fd: Int32) -> Int32 { 0 } // mirrors: Sources/System/Internals/Syscalls.swift

internal func nothingOrErrno<I: FixedWidthInteger>( // mirrors: Sources/System/Util.swift
  retryOnInterrupt: Bool, _ f: () -> I
) -> Result<(), Errno> {
  .success(())
}

internal var mockingEnabled: Bool { false } // mirrors: Sources/System/Internals/Mocking.swift

internal func _mock( // mirrors: Sources/System/Internals/Mocking.swift
  name: String = #function, path: UnsafePointer<CInterop.PlatformChar>? = nil, _ args: AnyHashable...
) -> CInt { 0 }

internal func _mockInt( // mirrors: Sources/System/Internals/Mocking.swift
  name: String = #function, path: UnsafePointer<CInterop.PlatformChar>? = nil, _ args: AnyHashable...
) -> Int { 0 }

internal struct Trace {
  internal struct Entry {
    internal var name: String
    internal var arguments: [AnyHashable]
  }
  internal mutating func dequeue() -> Entry? { nil }
}

internal class MockingDriver {
  internal var trace = Trace()
  internal static func withMockingEnabled( // mirrors: Sources/System/Internals/Mocking.swift
    _ f: (MockingDriver) throws -> ()
  ) rethrows {
    try f(MockingDriver())
  }
}
