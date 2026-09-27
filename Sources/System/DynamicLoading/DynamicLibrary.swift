/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// PROTOTYPE: an owned handle from the dynamic linker, on the pattern of
// OwnedFD, whose deinit drops errors from closing. Whether it should is
// OwnedFD's open question too; see Prototype/CloseErrors.

#if !os(Windows) && !os(WASI)

/// A library that the dynamic linker has loaded into the process,
/// or the program itself, whose symbols you can look up.
///
///     let library = try DynamicLibrary("/usr/lib/libz.1.dylib")
///     guard let address = library.address(of: "zlibVersion") else { return }
///     let zlibVersion = unsafeBitCast(
///       address, to: (@convention(c) () -> UnsafePointer<CChar>).self)
///     print(String(cString: zlibVersion()))
///
/// A library owns its handle, and closes it at the end of its lifetime,
/// ignoring any error, or when you call ``close()``, which reports one.
/// The system unloads a library when its last handle closes,
/// unless something else keeps it, such as another library that needs it:
/// keep the library alive for as long as you use an address you looked up in it.
///
/// The corresponding C type is the handle that `dlopen` returns.
@frozen
@available(System 199, *)
public struct DynamicLibrary: ~Copyable, @unchecked Sendable {
  @usableFromInline
  internal let _handle: UnsafeMutableRawPointer

  /// Takes ownership of a handle that `dlopen` returned.
  ///
  /// The handle is closed at the end of the library's lifetime,
  /// so nothing else may close it.
  @_alwaysEmitIntoClient
  public init(taking handle: UnsafeMutableRawPointer) {
    self._handle = handle
  }

  deinit {
    // deinit can't throw, so an error from closing is dropped here,
    // as OwnedFD's deinit drops one.
    _ = system_dlclose(_handle)
  }
}

@available(System 199, *)
extension DynamicLibrary {
  /// An error that the dynamic linker reports, with its description.
  @frozen
  public struct LoaderError: Error, Hashable, Sendable, CustomStringConvertible {
    /// The dynamic linker's description of the error,
    /// which usually names the library or the symbol.
    public var message: String

    /// Creates an error with the given description.
    @_alwaysEmitIntoClient
    public init(message: String) { self.message = message }

    /// The dynamic linker's description of the error.
    @_alwaysEmitIntoClient
    public var description: String { message }
  }

  /// Options for loading a library.
  @frozen
  public struct OpenOptions: OptionSet, Hashable, Sendable {
    /// The raw C options.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed set of options from raw C options.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }

    /// Resolves each function the library calls when it's first called.
    ///
    /// Loading then succeeds even if a function is missing,
    /// and calling it later crashes.
    ///
    /// The corresponding C constant is `RTLD_LAZY`.
    @_alwaysEmitIntoClient
    public static var lazy: OpenOptions { OpenOptions(rawValue: _RTLD_LAZY) }

    /// Resolves every symbol the library needs as it loads,
    /// failing if one is missing.
    ///
    /// The corresponding C constant is `RTLD_NOW`.
    @_alwaysEmitIntoClient
    public static var now: OpenOptions { OpenOptions(rawValue: _RTLD_NOW) }

    /// Makes the library's symbols available to libraries loaded later,
    /// and to lookups through ``DynamicLibrary/mainProgram(options:)``.
    ///
    /// The corresponding C constant is `RTLD_GLOBAL`.
    @_alwaysEmitIntoClient
    public static var global: OpenOptions { OpenOptions(rawValue: _RTLD_GLOBAL) }

    /// Keeps the library's symbols to lookups through its own handle.
    ///
    /// Linux uses this when neither `local` nor ``global`` is given,
    /// and Darwin uses ``global``.
    ///
    /// The corresponding C constant is `RTLD_LOCAL`.
    @_alwaysEmitIntoClient
    public static var local: OpenOptions { OpenOptions(rawValue: _RTLD_LOCAL) }

    #if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
    /// Fails, rather than loading the library, if it isn't loaded already.
    ///
    /// The corresponding C constant is `RTLD_NOLOAD`.
    /// - Note: Not available on OpenBSD.
    @_alwaysEmitIntoClient
    public static var noLoad: OpenOptions { OpenOptions(rawValue: _RTLD_NOLOAD) }

    /// Keeps the library loaded after its last handle closes.
    ///
    /// The corresponding C constant is `RTLD_NODELETE`.
    /// - Note: Not available on OpenBSD.
    @_alwaysEmitIntoClient
    public static var noDelete: OpenOptions { OpenOptions(rawValue: _RTLD_NODELETE) }
    #endif

    #if SYSTEM_PACKAGE_DARWIN
    /// Makes lookups through this handle search only this library,
    /// not the libraries it depends on.
    ///
    /// The corresponding C constant is `RTLD_FIRST`.
    /// - Note: Only available on Darwin.
    @_alwaysEmitIntoClient
    public static var first: OpenOptions { OpenOptions(rawValue: _RTLD_FIRST) }
    #endif
  }
}

@available(System 199, *)
extension DynamicLibrary {
  /// Loads the library at a path, or opens another handle to it
  /// if it's loaded already.
  ///
  /// - Parameters:
  ///   - path: The library's path, or a name without a `/`,
  ///     which the dynamic linker looks for in its search path.
  ///   - options: Options for loading the library.
  ///     The default, `[.now, .local]`, fails if the library needs
  ///     a symbol that's missing, and keeps its symbols to this handle,
  ///     on every platform.
  ///
  /// The corresponding C function is `dlopen`.
  @_alwaysEmitIntoClient
  public init(_ path: FilePath, options: OpenOptions = [.now, .local]) throws(LoaderError) {
    self.init(
      taking: try path.withPlatformString { DynamicLibrary._open($0, options: options) }.get())
  }

  /// Loads the library at a path, or opens another handle to it
  /// if it's loaded already.
  ///
  /// - Parameters:
  ///   - path: The library's path, or a name without a `/`,
  ///     which the dynamic linker looks for in its search path.
  ///   - options: Options for loading the library.
  ///     The default, `[.now, .local]`, fails if the library needs
  ///     a symbol that's missing, and keeps its symbols to this handle,
  ///     on every platform.
  ///
  /// The corresponding C function is `dlopen`.
  @_alwaysEmitIntoClient
  public init(
    _ path: UnsafePointer<CChar>, options: OpenOptions = [.now, .local]
  ) throws(LoaderError) {
    self.init(taking: try DynamicLibrary._open(path, options: options).get())
  }

  /// Returns a handle to the program itself,
  /// through which a lookup searches the program,
  /// the libraries that it loaded as it started,
  /// and those loaded later with ``OpenOptions/global``.
  ///
  /// - Parameter options: Options for the handle. The default is `.now`.
  ///
  /// The corresponding C function is `dlopen`, with a null path.
  @_alwaysEmitIntoClient
  public static func mainProgram(options: OpenOptions = .now) throws(LoaderError) -> DynamicLibrary {
    DynamicLibrary(taking: try _open(nil, options: options).get())
  }

  @usableFromInline
  internal static func _open(
    _ path: UnsafePointer<CChar>?, options: OpenOptions
  ) -> Result<UnsafeMutableRawPointer, LoaderError> {
    guard let handle = system_dlopen(path, options.rawValue) else {
      return .failure(_loaderError())
    }
    return .success(handle)
  }

  /// Returns the address of a symbol that this library defines,
  /// or one of the libraries it depends on.
  ///
  /// - Parameter symbol: The symbol's name, as the linker knows it,
  ///   such as a C function's name.
  /// - Returns: The symbol's address, or `nil` if no library that
  ///   this handle searches defines it.
  ///
  /// A function's address has to be cast to its type
  /// with `unsafeBitCast(_:to:)` before you can call it,
  /// and nothing checks that the type is right.
  /// The address is valid only while the library stays loaded.
  ///
  /// The corresponding C function is `dlsym`.
  @_alwaysEmitIntoClient
  public func address(of symbol: String) -> UnsafeMutableRawPointer? {
    symbol.withCString { _address(of: $0) }
  }

  /// Returns the address of a symbol that this library defines,
  /// or one of the libraries it depends on.
  ///
  /// - Parameter symbol: The symbol's name, as the linker knows it.
  /// - Returns: The symbol's address, or `nil` if no library that
  ///   this handle searches defines it.
  ///
  /// The corresponding C function is `dlsym`.
  @_alwaysEmitIntoClient
  public func address(of symbol: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    _address(of: symbol)
  }

  @usableFromInline
  internal func _address(of symbol: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    // Clear any earlier error, which dlsym leaves alone when it succeeds, so
    // that a caller who gets nil can tell a failure with dlerror.
    _ = system_dlerror()
    return system_dlsym(_handle, symbol)
  }

  /// The handle, for dynamic linker calls that `DynamicLibrary`
  /// doesn't provide.
  ///
  /// The handle is valid only while this library is alive:
  /// don't close it, and don't keep it.
  /// To take ownership of it, call ``relinquish()``.
  @_alwaysEmitIntoClient
  public var handle: UnsafeMutableRawPointer { _handle }

  /// Closes the handle, which unloads the library
  /// if nothing else keeps it loaded.
  ///
  /// The handle isn't closed again, whether this method returns or throws.
  ///
  /// The corresponding C function is `dlclose`.
  @_alwaysEmitIntoClient
  public consuming func close() throws(LoaderError) {
    let handle = _handle
    discard self
    try DynamicLibrary._close(handle).get()
  }

  @usableFromInline
  internal static func _close(_ handle: UnsafeMutableRawPointer) -> Result<(), LoaderError> {
    system_dlclose(handle) == 0 ? .success(()) : .failure(_loaderError())
  }

  /// Transfers ownership of the handle to the caller, without closing it.
  ///
  /// After this method returns, the caller is responsible for closing
  /// the handle with `dlclose`.
  @_alwaysEmitIntoClient
  public consuming func relinquish() -> UnsafeMutableRawPointer {
    let handle = _handle
    discard self
    return handle
  }
}

/// The calling thread's last dynamic linking error.
@available(System 199, *)
internal func _loaderError() -> DynamicLibrary.LoaderError {
  DynamicLibrary.LoaderError(
    message: system_dlerror().map { String(platformString: $0) } ?? "unknown dynamic linker error")
}

#endif // !os(Windows) && !os(WASI)
