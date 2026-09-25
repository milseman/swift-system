// V16f: how catch patterns resolve when both error types exist, as they do on
// Windows: System's Errno has `~=(Errno, Error)` (Errno.swift), and SYS-0010
// gives Win32.Error the same operator. Both types name a `fileExists` code
// (and `brokenPipe`, `notSupported`, `fileTooLarge`, `noData`). Models of the
// two types, with the operators exactly as shipped and drafted.
//
// Expected, by flags (-D DISFAVOR_WIN32 and -D DISFAVOR_ERRNO mark the
// matching `~=` @_disfavoredOverload):
// - none: three errors, "ambiguous use of 'fileExists'", for the implicit
//   member patterns in `errnoTyped`, `win32Typed`, and `enumTyped`.
// - DISFAVOR_WIN32: compiles, but `win32Typed` prints "win32Typed: other":
//   `.fileExists` silently resolves to Errno.fileExists, through Errno's
//   operator, and never matches.
// - DISFAVOR_ERRNO: compiles, but `errnoTyped` and `enumTyped` print
//   "other": their patterns resolve to Win32.Error.fileExists.
// - both: compiles, and every function matches.
// Explicit spellings (`catch Errno.fileExists`, `catch Win32.Error.fileExists`)
// and the per-platform alias (`catch PlatformError.fileExists`) match with no
// flags. So, for SYS-0010: Win32.Error's operator and Errno's both need
// @_disfavoredOverload, or typed code on Windows must spell the type.
//   swiftc -swift-version 6 -D ALL V16f_error_patterns.swift -o /tmp/V16f && /tmp/V16f
//   swiftc -swift-version 6 -D ALL -D DISFAVOR_WIN32 V16f_error_patterns.swift -o /tmp/V16f && /tmp/V16f
//   swiftc -swift-version 6 -D ALL -D DISFAVOR_ERRNO V16f_error_patterns.swift -o /tmp/V16f && /tmp/V16f
//   swiftc -swift-version 6 -D ALL -D DISFAVOR_WIN32 -D DISFAVOR_ERRNO V16f_error_patterns.swift -o /tmp/V16f && /tmp/V16f
// Without -D ALL, only the explicit spellings compile, with no flags:
//   swiftc -swift-version 6 V16f_error_patterns.swift -o /tmp/V16f && /tmp/V16f

struct Errno: Error, Equatable {
  var rawValue: Int32
  static var fileExists: Errno { Errno(rawValue: 17) }
  #if DISFAVOR_ERRNO
  @_disfavoredOverload
  #endif
  static func ~= (lhs: Errno, rhs: any Error) -> Bool { (rhs as? Errno) == lhs }
}

enum Win32 {
  struct Error: Swift.Error, Equatable {
    var rawValue: UInt32
    static var fileExists: Error { Error(rawValue: 80) }
    static var sharingViolation: Error { Error(rawValue: 32) }
    #if DISFAVOR_WIN32
    @_disfavoredOverload
    #endif
    static func ~= (lhs: Error, rhs: any Swift.Error) -> Bool { (rhs as? Error) == lhs }
  }
}

/// An error enum with platform cases (the prototype's "E3").
enum PlatformErrorEnum: Error {
  case errno(Errno)
  case win32(Win32.Error)
}

/// The platform's own error type (the prototype's "E4"): Win32.Error on Windows.
typealias PlatformError = Win32.Error

func failErrno() throws(Errno) { throw .fileExists }
func failWin32() throws(Win32.Error) { throw .fileExists }
func failEnum() throws(PlatformErrorEnum) { throw .errno(.fileExists) }

#if ALL
func errnoTyped() {
  do { try failErrno() }
  catch .fileExists { print("errnoTyped: fileExists") }
  catch { print("errnoTyped: other") }
}

func win32Typed() {
  do { try failWin32() }
  catch .fileExists { print("win32Typed: fileExists") }
  catch { print("win32Typed: other") }
}

func enumTyped() {
  do { try failEnum() }
  catch .errno(.fileExists) { print("enumTyped: fileExists") }
  catch { print("enumTyped: other") }
}
#endif

func explicit() {
  do { try failErrno() }
  catch Errno.fileExists { print("explicit Errno: fileExists") }
  catch { print("explicit Errno: other") }

  do { try failWin32() }
  catch Win32.Error.fileExists { print("explicit Win32.Error: fileExists") }
  catch { print("explicit Win32.Error: other") }

  do { try failEnum() }
  catch .errno(Errno.fileExists) { print("explicit enum: fileExists") }
  catch { print("explicit enum: other") }

  do { try failWin32() }
  catch PlatformError.fileExists { print("alias: fileExists") }
  catch { print("alias: other") }
}

#if ALL
errnoTyped()
win32Typed()
enumTyped()
#endif
explicit()
