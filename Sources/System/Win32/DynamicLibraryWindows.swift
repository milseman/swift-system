/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: DynamicLibrary on Windows, an owned module handle from the
// loader, as DynamicLibrary.swift's is an owned handle from the dynamic
// linker elsewhere. Its deinit drops errors from freeing, as that one's does.

#if os(Windows)

import WinSDK

/// A library that the loader has loaded into the process,
/// or the program itself, whose exported symbols you can look up.
///
///     let library = try DynamicLibrary("zlib1.dll")
///     guard let address = library.address(of: "zlibVersion") else { return }
///     let zlibVersion = unsafeBitCast(
///       address, to: (@convention(c) () -> UnsafePointer<CChar>).self)
///     print(String(cString: zlibVersion()))
///
/// A library owns its module handle, a reference that keeps the module
/// loaded, and frees it at the end of its lifetime, ignoring any error, or
/// when you call ``close()``, which reports one. Windows unloads a module
/// when its last reference is freed, unless the process loaded it as it
/// started: keep the library alive for as long as you use an address you
/// looked up in it.
///
/// The corresponding C type is `HMODULE`.
@frozen
@available(System 199, *)
public struct DynamicLibrary: ~Copyable, @unchecked Sendable {
  @usableFromInline
  internal let _handle: HMODULE

  /// Takes ownership of a module handle that holds a reference, as one
  /// from `LoadLibraryW`, `LoadLibraryExW`, or `GetModuleHandleExW` does.
  ///
  /// The handle is freed at the end of the library's lifetime,
  /// so nothing else may free it. A handle from `GetModuleHandleW` holds no
  /// reference, so it isn't one to take.
  @_alwaysEmitIntoClient
  public init(taking handle: HMODULE) {
    self._handle = handle
  }

  deinit {
    // deinit can't throw, so an error from freeing is dropped here, as
    // DynamicLibrary's deinit drops one on the other platforms.
    _ = system_FreeLibrary(_handle)
  }
}

@available(System 199, *)
extension DynamicLibrary {
  /// Options for how the loader searches for a library and the libraries
  /// it depends on.
  ///
  /// With none, the loader searches as `LoadLibraryW` does: the program's
  /// directory, the system directories, the current directory, and the
  /// directories in `PATH`. The `search` options replace that order with
  /// the directories they name, which leaves out the current directory and
  /// `PATH`, where another user may be able to plant a library.
  ///
  /// The corresponding C parameter of `LoadLibraryExW` is `dwFlags`.
  @frozen
  public struct LoadOptions: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: DWORD

    /// Creates strongly-typed options from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: DWORD) { self.rawValue = rawValue }

    /// Searches for the library's dependencies in the library's own
    /// directory, rather than the program's, for an absolute path.
    ///
    /// It can't be combined with the `search` options.
    ///
    /// The corresponding C constant is `LOAD_WITH_ALTERED_SEARCH_PATH`.
    @_alwaysEmitIntoClient
    public static var alteredSearchPath: LoadOptions { LoadOptions(rawValue: 0x0000_0008) }

    /// Searches the library's own directory for its dependencies.
    ///
    /// The corresponding C constant is `LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`.
    @_alwaysEmitIntoClient
    public static var searchLibraryDirectory: LoadOptions { LoadOptions(rawValue: 0x0000_0100) }

    /// Searches the program's directory.
    ///
    /// The corresponding C constant is `LOAD_LIBRARY_SEARCH_APPLICATION_DIR`.
    @_alwaysEmitIntoClient
    public static var searchApplicationDirectory: LoadOptions {
      LoadOptions(rawValue: 0x0000_0200)
    }

    /// Searches the directories that `AddDllDirectory` added.
    ///
    /// The corresponding C constant is `LOAD_LIBRARY_SEARCH_USER_DIRS`.
    @_alwaysEmitIntoClient
    public static var searchUserDirectories: LoadOptions { LoadOptions(rawValue: 0x0000_0400) }

    /// Searches the system directory.
    ///
    /// The corresponding C constant is `LOAD_LIBRARY_SEARCH_SYSTEM32`.
    @_alwaysEmitIntoClient
    public static var searchSystemDirectory: LoadOptions { LoadOptions(rawValue: 0x0000_0800) }

    /// Searches the program's directory, the directories that
    /// `AddDllDirectory` added, and the system directory.
    ///
    /// The corresponding C constant is `LOAD_LIBRARY_SEARCH_DEFAULT_DIRS`.
    @_alwaysEmitIntoClient
    public static var searchDefaultDirectories: LoadOptions { LoadOptions(rawValue: 0x0000_1000) }
  }
}

@available(System 199, *)
extension DynamicLibrary {
  /// Loads the library at a path, or takes another reference to it
  /// if it's loaded already.
  ///
  /// - Parameters:
  ///   - path: The library's path, or a name without a directory, which the
  ///     loader looks for as `options` says. A name without an extension
  ///     gets `.dll`.
  ///   - options: How to search for the library and its dependencies.
  ///
  /// Throws ``Win32/Error/moduleNotFound`` if the loader can't find the
  /// library or a library it depends on.
  ///
  /// The corresponding C function is `LoadLibraryExW`.
  @_alwaysEmitIntoClient
  public init(_ path: FilePath, options: LoadOptions = []) throws(Win32.Error) {
    self.init(
      taking: try path.withPlatformString { DynamicLibrary._load($0, options: options) }.get())
  }

  /// Loads the library at a path, or takes another reference to it
  /// if it's loaded already.
  ///
  /// See ``init(_:options:)-(FilePath,_)``.
  ///
  /// The corresponding C function is `LoadLibraryExW`.
  @_alwaysEmitIntoClient
  public init(
    _ path: UnsafePointer<CInterop.PlatformChar>, options: LoadOptions = []
  ) throws(Win32.Error) {
    self.init(taking: try DynamicLibrary._load(path, options: options).get())
  }

  /// Takes a reference to a library that's loaded already, without
  /// loading one.
  ///
  /// - Parameter name: The library's name, such as `ntdll.dll`, or its
  ///   path. A name without an extension gets `.dll`.
  ///
  /// Throws ``Win32/Error/moduleNotFound`` if no such library is loaded.
  /// The reference keeps the library loaded until this value frees it.
  ///
  /// The corresponding C function is `GetModuleHandleExW`.
  @_alwaysEmitIntoClient
  public init(alreadyLoaded name: FilePath) throws(Win32.Error) {
    self.init(
      taking: try name.withPlatformString { DynamicLibrary._loadedModule($0) }.get())
  }

  /// Returns a reference to the program itself, through which a lookup
  /// searches the symbols that the program's executable exports.
  ///
  /// Unlike the other platforms' main program, a lookup here doesn't search
  /// the libraries the program loaded.
  ///
  /// The corresponding C function is `GetModuleHandleExW`, with a null
  /// module name.
  @_alwaysEmitIntoClient
  public static func mainProgram() throws(Win32.Error) -> DynamicLibrary {
    DynamicLibrary(taking: try _loadedModule(nil).get())
  }

  @usableFromInline
  internal static func _load(
    _ path: UnsafePointer<WCHAR>, options: LoadOptions
  ) -> Result<HMODULE, Win32.Error> {
    guard let module = system_LoadLibraryExW(path, nil, options.rawValue) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(module)
  }

  @usableFromInline
  internal static func _loadedModule(
    _ name: UnsafePointer<WCHAR>?
  ) -> Result<HMODULE, Win32.Error> {
    var module: HMODULE? = nil
    // No flags: the handle takes a reference, which FreeLibrary releases.
    guard system_GetModuleHandleExW(0, name, &module), let module else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(module)
  }

  /// Returns the address of a symbol that this library exports.
  ///
  /// - Parameter symbol: The symbol's name, as the library exports it,
  ///   such as a C function's name.
  /// - Returns: The symbol's address, or `nil` if the library doesn't
  ///   export it.
  ///
  /// A function's address has to be cast to its type
  /// with `unsafeBitCast(_:to:)` before you can call it,
  /// and nothing checks that the type is right.
  /// The address is valid only while the library stays loaded.
  ///
  /// The corresponding C function is `GetProcAddress`.
  @_alwaysEmitIntoClient
  public func address(of symbol: String) -> UnsafeMutableRawPointer? {
    symbol.withCString { _address(of: $0) }
  }

  /// Returns the address of a symbol that this library exports.
  ///
  /// - Parameter symbol: The symbol's name, as the library exports it.
  ///   Windows' export names are 8-bit strings.
  /// - Returns: The symbol's address, or `nil` if the library doesn't
  ///   export it.
  ///
  /// The corresponding C function is `GetProcAddress`.
  @_alwaysEmitIntoClient
  public func address(of symbol: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    _address(of: symbol)
  }

  @usableFromInline
  internal func _address(of symbol: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    unsafeBitCast(system_GetProcAddress(_handle, symbol), to: UnsafeMutableRawPointer?.self)
  }

  /// The module handle, for loader calls that `DynamicLibrary`
  /// doesn't provide.
  ///
  /// The handle is valid only while this library is alive:
  /// don't free it, and don't keep it.
  /// To take ownership of it, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var handle: HMODULE { _handle }

  /// Frees the reference, which unloads the library
  /// if nothing else keeps it loaded.
  ///
  /// The reference isn't freed again, whether this method returns or
  /// throws.
  ///
  /// The corresponding C function is `FreeLibrary`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(Win32.Error) {
    let handle = _handle
    discard self
    try DynamicLibrary._free(handle).get()
  }

  @usableFromInline
  internal static func _free(_ handle: HMODULE) -> Result<(), Win32.Error> {
    guard system_FreeLibrary(handle) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  /// Transfers ownership of the reference to the caller, without freeing
  /// it.
  ///
  /// After this method returns, the caller is responsible for freeing the
  /// handle with `FreeLibrary`.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> HMODULE {
    let handle = _handle
    discard self
    return handle
  }
}


// MARK: - Search directories

@available(System 199, *)
extension DynamicLibrary {
  /// A directory that ``addSearchDirectory(_:)`` added to the process's
  /// library search.
  ///
  /// Pass it to ``removeSearchDirectory(_:)`` to take the directory out of
  /// the search again.
  ///
  /// The corresponding C type is `DLL_DIRECTORY_COOKIE`.
  @frozen
  public struct SearchDirectory: RawRepresentable, Hashable, @unchecked Sendable {
    /// The raw C cookie.
    @_alwaysEmitIntoClient
    public var rawValue: DLL_DIRECTORY_COOKIE

    /// Creates a strongly-typed search directory from a raw C cookie.
    @_alwaysEmitIntoClient
    public init(rawValue: DLL_DIRECTORY_COOKIE) { self.rawValue = rawValue }
  }

  /// Adds a directory to the ones the loader searches for a library loaded
  /// with ``LoadOptions/searchUserDirectories`` or
  /// ``LoadOptions/searchDefaultDirectories``.
  ///
  /// - Parameter path: The directory. A relative path is resolved against
  ///   the current directory, since the loader takes only an absolute one.
  /// - Returns: The directory's registration, for
  ///   ``removeSearchDirectory(_:)``.
  ///
  /// The directories belong to the process, so the change affects every
  /// thread's loads. The order in which the loader searches added
  /// directories isn't specified. A load with no `search` options, such as
  /// one with `LoadLibraryW`'s search, doesn't search them.
  ///
  /// The corresponding C function is `AddDllDirectory`.
  @_alwaysEmitIntoClient
  @discardableResult
  public static func addSearchDirectory(_ path: FilePath) throws(Win32.Error) -> SearchDirectory {
    SearchDirectory(rawValue: try _addSearchDirectory(path).get())
  }

  /// Removes a directory that ``addSearchDirectory(_:)`` added.
  ///
  /// Libraries already loaded from it stay loaded.
  ///
  /// The corresponding C function is `RemoveDllDirectory`.
  @_alwaysEmitIntoClient
  public static func removeSearchDirectory(_ directory: SearchDirectory) throws(Win32.Error) {
    try _removeSearchDirectory(directory.rawValue).get()
  }

  /// Sets the search that a load uses when it names no `search` options,
  /// for the rest of the process's life.
  ///
  /// - Parameter options: The `search` options that become the default,
  ///   such as ``LoadOptions/searchDefaultDirectories``, which leaves out
  ///   the current directory and `PATH`. Other options throw
  ///   ``Win32/Error/invalidParameter``.
  ///
  /// The change belongs to the process, and can't be undone except by
  /// setting another default, so it suits a program's start, before it
  /// loads anything. Microsoft recommends it to keep a program from loading
  /// a library planted in the current directory.
  ///
  /// The corresponding C function is `SetDefaultDllDirectories`.
  @_alwaysEmitIntoClient
  public static func setDefaultSearch(_ options: LoadOptions) throws(Win32.Error) {
    try _setDefaultSearch(options.rawValue).get()
  }

  @usableFromInline
  internal static func _addSearchDirectory(
    _ path: FilePath
  ) -> Result<DLL_DIRECTORY_COOKIE, Win32.Error> {
    // A full path, but without the \\?\ prefix, which the loader's search
    // doesn't document taking.
    _withCanonicalPath(path, prefix: .never) { path in
      guard let cookie = system_AddDllDirectory(path) else {
        return .failure(Win32.Error(GetLastError()))
      }
      return .success(cookie)
    }
  }

  @usableFromInline
  internal static func _removeSearchDirectory(
    _ cookie: DLL_DIRECTORY_COOKIE
  ) -> Result<Void, Win32.Error> {
    guard system_RemoveDllDirectory(cookie) else { return .failure(Win32.Error(GetLastError())) }
    return .success(())
  }

  @usableFromInline
  internal static func _setDefaultSearch(_ options: DWORD) -> Result<Void, Win32.Error> {
    guard system_SetDefaultDllDirectories(options) else {
      return .failure(Win32.Error(GetLastError()))
    }
    return .success(())
  }
}

#endif // os(Windows)
