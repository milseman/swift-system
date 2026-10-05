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

// Must import here to call dlopen in @_alwaysEmitIntoClient code.
#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

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
    ///
    /// The corresponding C function is `dlerror`, which returns it.
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

    #if os(Linux) && canImport(Glibc)
    /// Makes the library, and the libraries it depends on,
    /// use their own symbols before any of the same names already loaded.
    ///
    /// Libraries that bundle their own copy of a common library,
    /// such as the Swift runtime or LLVM, load this way
    /// to keep calling their copy.
    ///
    /// The corresponding C constant is `RTLD_DEEPBIND`.
    /// - Note: Only available on Linux with glibc.
    @_alwaysEmitIntoClient
    public static var deepBind: OpenOptions { OpenOptions(rawValue: _RTLD_DEEPBIND) }
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
  /// The dynamic linker resolves some paths against the image
  /// that calls `dlopen`:
  /// on Darwin, `@loader_path` is that image's directory,
  /// and `@rpath`, as a name without a `/` does, searches its run paths
  /// and then the program's;
  /// with glibc, `$ORIGIN` is that image's directory,
  /// and a name without a `/` searches its run paths.
  /// This initializer is emitted into your code, call and all,
  /// so the image is the program or library that calls it,
  /// even when System is a library of its own.
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
  /// As with ``init(_:options:)-(FilePath,_)``, the call to `dlopen`
  /// is emitted into your code, so the dynamic linker resolves
  /// `@loader_path`, `@rpath`, and `$ORIGIN` against the image
  /// that calls this initializer.
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

  // Emitted into the client, and calling dlopen itself, which has no
  // system_ wrapper, so that dlopen runs in the caller's image, which the
  // dynamic linker resolves @loader_path, @rpath and $ORIGIN against. The
  // error comes from System's image, which is fine: dlerror's is the
  // calling thread's.
  @_alwaysEmitIntoClient
  internal static func _open(
    _ path: UnsafePointer<CChar>?, options: OpenOptions
  ) -> Result<UnsafeMutableRawPointer, LoaderError> {
    guard let handle = dlopen(path, options.rawValue) else {
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

@available(System 199, *)
extension DynamicLibrary {
  /// Returns the calling thread's pending dynamic loader error,
  /// and clears it.
  ///
  /// - Returns: The error of the last loader call on this thread
  ///   that failed since the error was last taken,
  ///   or `nil` if there's none.
  ///
  /// `DynamicLibrary`'s initializers and ``close()`` throw their errors,
  /// taking them as this method does.
  /// This is for a call that fails without throwing,
  /// such as ``address(of:)-(String)`` returning `nil`,
  /// which clears the pending error first:
  ///
  ///     guard let address = library.address(of: "entry") else {
  ///       print(DynamicLibrary.takePendingError()?.message ?? "not found")
  ///       return
  ///     }
  ///
  /// It's also for the loader calls that C code makes.
  ///
  /// The corresponding C function is `dlerror`.
  @_alwaysEmitIntoClient
  public static func takePendingError() -> LoaderError? {
    _takePendingError()
  }

  @usableFromInline
  internal static func _takePendingError() -> LoaderError? {
    system_dlerror().map { LoaderError(message: String(platformString: $0)) }
  }
}

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
@available(System 199, *)
extension DynamicLibrary {
  /// Where an address is among the loaded libraries:
  /// the library that contains it, and the nearest symbol at or below it.
  ///
  /// The corresponding C type is `Dl_info`.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  public struct SymbolInfo: Hashable {
    /// The path of the library, or of the program, that contains the address,
    /// as the dynamic loader loaded it.
    ///
    /// The corresponding C field is `dli_fname`.
    public var libraryPath: FilePath

    /// The address the library is loaded at.
    ///
    /// The corresponding C field is `dli_fbase`.
    public var libraryAddress: UnsafeRawPointer?

    /// The name of the nearest symbol at or below the address,
    /// or `nil` if the loader has none.
    ///
    /// The corresponding C field is `dli_sname`.
    public var symbolName: String?

    /// The address of that symbol, or `nil` if the loader has none.
    ///
    /// The corresponding C field is `dli_saddr`.
    public var symbolAddress: UnsafeRawPointer?

    /// Creates information about an address from its parts.
    public init(
      libraryPath: FilePath, libraryAddress: UnsafeRawPointer?,
      symbolName: String?, symbolAddress: UnsafeRawPointer?
    ) {
      self.libraryPath = libraryPath
      self.libraryAddress = libraryAddress
      self.symbolName = symbolName
      self.symbolAddress = symbolAddress
    }
  }

  /// Returns the loaded library that contains an address,
  /// and the nearest symbol at or below it,
  /// or `nil` if no loaded library contains the address.
  ///
  /// - Parameter address: An address, such as a function's.
  ///
  /// To find the library that contains the calling code,
  /// pass the address of one of its functions.
  ///
  /// On Linux the loader finds only exported symbols,
  /// and for an address in a statically linked program,
  /// such as one built with Musl, it finds no library.
  ///
  /// The corresponding C function is `dladdr`.
  /// - Note: Only available on Darwin, Linux, Android, FreeBSD, and OpenBSD.
  @_alwaysEmitIntoClient
  public static func symbolInfo(containing address: UnsafeRawPointer) -> SymbolInfo? {
    _symbolInfo(containing: address)
  }

  @usableFromInline
  internal static func _symbolInfo(containing address: UnsafeRawPointer) -> SymbolInfo? {
    guard let info = system_dladdr(address) else { return nil }
    return SymbolInfo(
      libraryPath: FilePath(platformString: info.path),
      libraryAddress: info.base,
      symbolName: info.symbol.map { String(platformString: $0) },
      symbolAddress: info.symbolAddress)
  }
}
#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)

/// The calling thread's last dynamic linking error.
@available(System 199, *)
@usableFromInline
internal func _loaderError() -> DynamicLibrary.LoaderError {
  DynamicLibrary.LoaderError(
    message: system_dlerror().map { String(platformString: $0) } ?? "unknown dynamic linker error")
}

#endif // !os(Windows) && !os(WASI)
