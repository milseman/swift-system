/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

/// A namespace for the system's configurable limits and options.
///
/// Call ``value(_:)`` for a system-wide variable, such as the page size,
/// and one of the `value(_:for:)` methods
/// for a variable that can differ from file to file,
/// such as the maximum length of a file name.
///
/// A variable's value is `nil` if the system has no limit for it,
/// or, for an option, if the system doesn't support the option.
///
/// - Note: Only available on Unix-like platforms other than WASI.
@available(System 199, *)
public enum SystemConfig {}

// MARK: - sysconf

@available(System 199, *)
extension SystemConfig {
  /// The name of a configurable system-wide variable.
  ///
  /// To get a variable's value, call ``SystemConfig/value(_:)``.
  @frozen
  public struct Name: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C name.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed name from a raw C name.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
  }

  /// Returns the value of a configurable system-wide variable.
  ///
  /// - Parameters:
  ///   - name: The variable to return.
  /// - Returns: The variable's value,
  ///   or `nil` if the system has no limit for the variable,
  ///   or doesn't support the option that it names.
  ///
  /// If the system doesn't recognize `name`,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `sysconf`.
  @_alwaysEmitIntoClient
  public static func value(_ name: Name) throws(Errno) -> Int? {
    try _value(name).get()
  }

  @usableFromInline
  internal static func _value(_ name: Name) -> Result<Int?, Errno> {
    _valueOrNil { system_sysconf(name.rawValue) }
  }
}

@available(System 199, *)
extension SystemConfig.Name {
  /// The maximum number of bytes of arguments and environment
  /// that a new process image can receive, as through `execve`.
  ///
  /// The corresponding C constant is `_SC_ARG_MAX`.
  @_alwaysEmitIntoClient
  public static var maxArgumentBytes: Self { Self(rawValue: __SC_ARG_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxArgumentBytes")
  public static var _SC_ARG_MAX: Self { maxArgumentBytes }

  /// The maximum number of processes that a user can have at once.
  ///
  /// The corresponding C constant is `_SC_CHILD_MAX`.
  @_alwaysEmitIntoClient
  public static var maxUserProcesses: Self { Self(rawValue: __SC_CHILD_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxUserProcesses")
  public static var _SC_CHILD_MAX: Self { maxUserProcesses }

  /// The number of clock ticks per second,
  /// the unit of the process times that `times` reports.
  ///
  /// The corresponding C constant is `_SC_CLK_TCK`.
  @_alwaysEmitIntoClient
  public static var clockTicksPerSecond: Self { Self(rawValue: __SC_CLK_TCK) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "clockTicksPerSecond")
  public static var _SC_CLK_TCK: Self { clockTicksPerSecond }

  /// The maximum number of buffers that a vectored read or write can use,
  /// as with `readv`, `writev`, `sendmsg`, or `recvmsg`.
  ///
  /// The corresponding C constant is `_SC_IOV_MAX`.
  @_alwaysEmitIntoClient
  public static var maxIOVectors: Self { Self(rawValue: __SC_IOV_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxIOVectors")
  public static var _SC_IOV_MAX: Self { maxIOVectors }

  /// The maximum number of supplementary groups that a process can belong to.
  ///
  /// The corresponding C constant is `_SC_NGROUPS_MAX`.
  @_alwaysEmitIntoClient
  public static var maxSupplementaryGroups: Self { Self(rawValue: __SC_NGROUPS_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxSupplementaryGroups")
  public static var _SC_NGROUPS_MAX: Self { maxSupplementaryGroups }

  /// The number of processors that the system has.
  ///
  /// The corresponding C constant is `_SC_NPROCESSORS_CONF`.
  @_alwaysEmitIntoClient
  public static var processorsConfigured: Self { Self(rawValue: __SC_NPROCESSORS_CONF) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "processorsConfigured")
  public static var _SC_NPROCESSORS_CONF: Self { processorsConfigured }

  /// The number of processors that are available to run processes.
  ///
  /// The corresponding C constant is `_SC_NPROCESSORS_ONLN`.
  @_alwaysEmitIntoClient
  public static var processorsOnline: Self { Self(rawValue: __SC_NPROCESSORS_ONLN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "processorsOnline")
  public static var _SC_NPROCESSORS_ONLN: Self { processorsOnline }

  /// The maximum number of files that a process can have open at once.
  ///
  /// The corresponding C constant is `_SC_OPEN_MAX`.
  @_alwaysEmitIntoClient
  public static var maxOpenFiles: Self { Self(rawValue: __SC_OPEN_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxOpenFiles")
  public static var _SC_OPEN_MAX: Self { maxOpenFiles }

  /// The size of a page of memory, in bytes.
  ///
  /// The corresponding C constant is `_SC_PAGESIZE`.
  @_alwaysEmitIntoClient
  public static var pageSize: Self { Self(rawValue: __SC_PAGESIZE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "pageSize")
  public static var _SC_PAGESIZE: Self { pageSize }

  /// The maximum number of standard I/O streams that a process can have open at once.
  ///
  /// The corresponding C constant is `_SC_STREAM_MAX`.
  @_alwaysEmitIntoClient
  public static var maxStreams: Self { Self(rawValue: __SC_STREAM_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxStreams")
  public static var _SC_STREAM_MAX: Self { maxStreams }

  /// The maximum number of bytes in the name of a time zone.
  ///
  /// The corresponding C constant is `_SC_TZNAME_MAX`.
  @_alwaysEmitIntoClient
  public static var maxTimeZoneNameBytes: Self { Self(rawValue: __SC_TZNAME_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxTimeZoneNameBytes")
  public static var _SC_TZNAME_MAX: Self { maxTimeZoneNameBytes }

  /// The version of POSIX job control that the system supports,
  /// if it supports job control.
  ///
  /// The corresponding C constant is `_SC_JOB_CONTROL`.
  @_alwaysEmitIntoClient
  public static var jobControl: Self { Self(rawValue: __SC_JOB_CONTROL) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "jobControl")
  public static var _SC_JOB_CONTROL: Self { jobControl }

  /// A positive value if each process has a saved set-user-ID and set-group-ID.
  ///
  /// The corresponding C constant is `_SC_SAVED_IDS`.
  @_alwaysEmitIntoClient
  public static var savedIDs: Self { Self(rawValue: __SC_SAVED_IDS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "savedIDs")
  public static var _SC_SAVED_IDS: Self { savedIDs }

  /// The version of POSIX that the system conforms to, such as `200809`.
  ///
  /// The corresponding C constant is `_SC_VERSION`.
  @_alwaysEmitIntoClient
  public static var posixVersion: Self { Self(rawValue: __SC_VERSION) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "posixVersion")
  public static var _SC_VERSION: Self { posixVersion }

  /// The maximum `ibase` and `obase` values in the `bc` utility.
  ///
  /// The corresponding C constant is `_SC_BC_BASE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxBCBase: Self { Self(rawValue: __SC_BC_BASE_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxBCBase")
  public static var _SC_BC_BASE_MAX: Self { maxBCBase }

  /// The maximum number of elements in an array in the `bc` utility.
  ///
  /// The corresponding C constant is `_SC_BC_DIM_MAX`.
  @_alwaysEmitIntoClient
  public static var maxBCArrayElements: Self { Self(rawValue: __SC_BC_DIM_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxBCArrayElements")
  public static var _SC_BC_DIM_MAX: Self { maxBCArrayElements }

  /// The maximum `scale` value in the `bc` utility.
  ///
  /// The corresponding C constant is `_SC_BC_SCALE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxBCScale: Self { Self(rawValue: __SC_BC_SCALE_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxBCScale")
  public static var _SC_BC_SCALE_MAX: Self { maxBCScale }

  /// The maximum number of bytes in a string in the `bc` utility.
  ///
  /// The corresponding C constant is `_SC_BC_STRING_MAX`.
  @_alwaysEmitIntoClient
  public static var maxBCStringBytes: Self { Self(rawValue: __SC_BC_STRING_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxBCStringBytes")
  public static var _SC_BC_STRING_MAX: Self { maxBCStringBytes }

  /// The maximum number of weights that a locale can assign to
  /// an entry of its collation order.
  ///
  /// The corresponding C constant is `_SC_COLL_WEIGHTS_MAX`.
  @_alwaysEmitIntoClient
  public static var maxCollationWeights: Self { Self(rawValue: __SC_COLL_WEIGHTS_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxCollationWeights")
  public static var _SC_COLL_WEIGHTS_MAX: Self { maxCollationWeights }

  /// The maximum number of expressions that the `expr` utility
  /// can nest in parentheses.
  ///
  /// The corresponding C constant is `_SC_EXPR_NEST_MAX`.
  @_alwaysEmitIntoClient
  public static var maxNestedExpressions: Self { Self(rawValue: __SC_EXPR_NEST_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxNestedExpressions")
  public static var _SC_EXPR_NEST_MAX: Self { maxNestedExpressions }

  /// The maximum number of bytes in an input line
  /// that a text processing utility reads.
  ///
  /// The corresponding C constant is `_SC_LINE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxLineBytes: Self { Self(rawValue: __SC_LINE_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxLineBytes")
  public static var _SC_LINE_MAX: Self { maxLineBytes }

  /// The maximum number of repetitions of a regular expression
  /// in an interval such as `\{m,n\}`.
  ///
  /// The corresponding C constant is `_SC_RE_DUP_MAX`.
  @_alwaysEmitIntoClient
  public static var maxRegexRepetitions: Self { Self(rawValue: __SC_RE_DUP_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxRegexRepetitions")
  public static var _SC_RE_DUP_MAX: Self { maxRegexRepetitions }

  /// The version of the POSIX shell and utilities that the system conforms to.
  ///
  /// The corresponding C constant is `_SC_2_VERSION`.
  @_alwaysEmitIntoClient
  public static var posix2Version: Self { Self(rawValue: __SC_2_VERSION) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "posix2Version")
  public static var _SC_2_VERSION: Self { posix2Version }

  /// The version of the POSIX C-language bindings option that the system supports,
  /// if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_C_BIND`.
  @_alwaysEmitIntoClient
  public static var cBindings: Self { Self(rawValue: __SC_2_C_BIND) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "cBindings")
  public static var _SC_2_C_BIND: Self { cBindings }

  /// The version of the POSIX C-language development utilities option
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_C_DEV`.
  @_alwaysEmitIntoClient
  public static var cDevelopment: Self { Self(rawValue: __SC_2_C_DEV) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "cDevelopment")
  public static var _SC_2_C_DEV: Self { cDevelopment }

  /// A positive value if the system supports a terminal type
  /// capable of everything that the POSIX utilities require.
  ///
  /// The corresponding C constant is `_SC_2_CHAR_TERM`.
  @_alwaysEmitIntoClient
  public static var characterTerminal: Self { Self(rawValue: __SC_2_CHAR_TERM) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "characterTerminal")
  public static var _SC_2_CHAR_TERM: Self { characterTerminal }

  /// The version of the POSIX FORTRAN development utilities option
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_FORT_DEV`.
  @_alwaysEmitIntoClient
  public static var fortranDevelopment: Self { Self(rawValue: __SC_2_FORT_DEV) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "fortranDevelopment")
  public static var _SC_2_FORT_DEV: Self { fortranDevelopment }

  /// The version of the POSIX FORTRAN runtime utilities option
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_FORT_RUN`.
  @_alwaysEmitIntoClient
  public static var fortranRuntime: Self { Self(rawValue: __SC_2_FORT_RUN) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "fortranRuntime")
  public static var _SC_2_FORT_RUN: Self { fortranRuntime }

  /// The version of the POSIX option to create locales
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_LOCALEDEF`.
  @_alwaysEmitIntoClient
  public static var localeDefinition: Self { Self(rawValue: __SC_2_LOCALEDEF) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "localeDefinition")
  public static var _SC_2_LOCALEDEF: Self { localeDefinition }

  /// The version of the POSIX software development utilities option
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_SW_DEV`.
  @_alwaysEmitIntoClient
  public static var softwareDevelopment: Self { Self(rawValue: __SC_2_SW_DEV) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "softwareDevelopment")
  public static var _SC_2_SW_DEV: Self { softwareDevelopment }

  /// The version of the POSIX user portability utilities option
  /// that the system supports, if it supports the option.
  ///
  /// The corresponding C constant is `_SC_2_UPE`.
  @_alwaysEmitIntoClient
  public static var userPortability: Self { Self(rawValue: __SC_2_UPE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "userPortability")
  public static var _SC_2_UPE: Self { userPortability }

  /// The number of pages of physical memory.
  ///
  /// To get the size of physical memory, multiply this by ``pageSize``.
  ///
  /// The corresponding C constant is `_SC_PHYS_PAGES`.
  @_alwaysEmitIntoClient
  public static var physicalMemoryPages: Self { Self(rawValue: __SC_PHYS_PAGES) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "physicalMemoryPages")
  public static var _SC_PHYS_PAGES: Self { physicalMemoryPages }

  /// A suggested size, in bytes, for the buffer that
  /// the reentrant functions to look up a user, such as `getpwuid_r`, fill.
  ///
  /// The corresponding C constant is `_SC_GETPW_R_SIZE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxUserEntryBufferBytes: Self { Self(rawValue: __SC_GETPW_R_SIZE_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxUserEntryBufferBytes")
  public static var _SC_GETPW_R_SIZE_MAX: Self { maxUserEntryBufferBytes }

  /// A suggested size, in bytes, for the buffer that
  /// the reentrant functions to look up a group, such as `getgrgid_r`, fill.
  ///
  /// The corresponding C constant is `_SC_GETGR_R_SIZE_MAX`.
  @_alwaysEmitIntoClient
  public static var maxGroupEntryBufferBytes: Self { Self(rawValue: __SC_GETGR_R_SIZE_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxGroupEntryBufferBytes")
  public static var _SC_GETGR_R_SIZE_MAX: Self { maxGroupEntryBufferBytes }

  /// The maximum number of bytes in a host name,
  /// not counting the null terminator.
  ///
  /// The corresponding C constant is `_SC_HOST_NAME_MAX`.
  @_alwaysEmitIntoClient
  public static var maxHostNameBytes: Self { Self(rawValue: __SC_HOST_NAME_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxHostNameBytes")
  public static var _SC_HOST_NAME_MAX: Self { maxHostNameBytes }
}

// MARK: - pathconf and fpathconf

@available(System 199, *)
extension SystemConfig {
  /// The name of a configurable variable that can differ from file to file.
  ///
  /// To get a variable's value, call one of the `value(_:for:)` methods
  /// of ``SystemConfig``.
  /// Some variables only apply to some kinds of files:
  /// for example, only a directory has a maximum file name length,
  /// which applies to the files in it,
  /// and only a terminal has a maximum input line length.
  /// Getting a variable that doesn't apply to a file
  /// throws ``Errno/invalidArgument``.
  @frozen
  public struct PathName: RawRepresentable, Sendable, Hashable, Codable {
    /// The raw C name.
    @_alwaysEmitIntoClient
    public var rawValue: CInt

    /// Creates a strongly-typed name from a raw C name.
    @_alwaysEmitIntoClient
    public init(rawValue: CInt) { self.rawValue = rawValue }
  }

  /// Returns the value of a configurable variable for a file or directory.
  ///
  /// - Parameters:
  ///   - name: The variable to return.
  ///   - path: The location of the file or directory.
  /// - Returns: The variable's value,
  ///   or `nil` if the system has no limit for the variable,
  ///   or doesn't support the option that it names.
  ///
  /// If the system doesn't recognize `name`,
  /// or the variable doesn't apply to the file,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `pathconf`.
  @_alwaysEmitIntoClient
  public static func value(_ name: PathName, for path: FilePath) throws(Errno) -> Int? {
    try path.withPlatformString { _value(name, for: $0) }.get()
  }

  /// Returns the value of a configurable variable for a file or directory.
  ///
  /// - Parameters:
  ///   - name: The variable to return.
  ///   - path: The location of the file or directory.
  /// - Returns: The variable's value,
  ///   or `nil` if the system has no limit for the variable,
  ///   or doesn't support the option that it names.
  ///
  /// If the system doesn't recognize `name`,
  /// or the variable doesn't apply to the file,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `pathconf`.
  @_alwaysEmitIntoClient
  public static func value(
    _ name: PathName, for path: UnsafePointer<CChar>
  ) throws(Errno) -> Int? {
    try _value(name, for: path).get()
  }

  /// Returns the value of a configurable variable
  /// for the file that a file descriptor refers to.
  ///
  /// - Parameters:
  ///   - name: The variable to return.
  ///   - fd: The file descriptor.
  /// - Returns: The variable's value,
  ///   or `nil` if the system has no limit for the variable,
  ///   or doesn't support the option that it names.
  ///
  /// If the system doesn't recognize `name`,
  /// or the variable doesn't apply to the file,
  /// this method throws ``Errno/invalidArgument``.
  ///
  /// The corresponding C function is `fpathconf`.
  @_alwaysEmitIntoClient
  public static func value(
    _ name: PathName, for fd: FileDescriptor
  ) throws(Errno) -> Int? {
    try _value(name, for: fd).get()
  }

  @usableFromInline
  internal static func _value(
    _ name: PathName, for path: UnsafePointer<CChar>
  ) -> Result<Int?, Errno> {
    _valueOrNil { system_pathconf(path, name.rawValue) }
  }

  @usableFromInline
  internal static func _value(
    _ name: PathName, for fd: FileDescriptor
  ) -> Result<Int?, Errno> {
    _valueOrNil { system_fpathconf(fd.rawValue, name.rawValue) }
  }
}

@available(System 199, *)
extension SystemConfig.PathName {
  /// The maximum number of hard links to a file.
  ///
  /// The corresponding C constant is `_PC_LINK_MAX`.
  @_alwaysEmitIntoClient
  public static var maxLinks: Self { Self(rawValue: __PC_LINK_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxLinks")
  public static var _PC_LINK_MAX: Self { maxLinks }

  /// The maximum number of bytes in a terminal's canonical input line.
  ///
  /// Only a terminal has this value.
  ///
  /// The corresponding C constant is `_PC_MAX_CANON`.
  @_alwaysEmitIntoClient
  public static var maxTerminalCanonicalLineBytes: Self { Self(rawValue: __PC_MAX_CANON) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxTerminalCanonicalLineBytes")
  public static var _PC_MAX_CANON: Self { maxTerminalCanonicalLineBytes }

  /// The number of bytes of input that a terminal can queue.
  ///
  /// Only a terminal has this value.
  ///
  /// The corresponding C constant is `_PC_MAX_INPUT`.
  @_alwaysEmitIntoClient
  public static var maxTerminalInputBytes: Self { Self(rawValue: __PC_MAX_INPUT) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxTerminalInputBytes")
  public static var _PC_MAX_INPUT: Self { maxTerminalInputBytes }

  /// The maximum number of bytes in a file name in a directory,
  /// not counting the null terminator.
  ///
  /// The corresponding C constant is `_PC_NAME_MAX`.
  @_alwaysEmitIntoClient
  public static var maxFileNameBytes: Self { Self(rawValue: __PC_NAME_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxFileNameBytes")
  public static var _PC_NAME_MAX: Self { maxFileNameBytes }

  /// The maximum number of bytes in a relative path from a directory,
  /// counting the null terminator.
  ///
  /// The corresponding C constant is `_PC_PATH_MAX`.
  @_alwaysEmitIntoClient
  public static var maxPathBytes: Self { Self(rawValue: __PC_PATH_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxPathBytes")
  public static var _PC_PATH_MAX: Self { maxPathBytes }

  /// The maximum number of bytes that a write to a pipe or FIFO
  /// writes all at once, without interleaving the data of other writes.
  ///
  /// The corresponding C constant is `_PC_PIPE_BUF`.
  @_alwaysEmitIntoClient
  public static var maxAtomicPipeWriteBytes: Self { Self(rawValue: __PC_PIPE_BUF) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxAtomicPipeWriteBytes")
  public static var _PC_PIPE_BUF: Self { maxAtomicPipeWriteBytes }

  /// A value other than `0` if changing the owner of a file
  /// in a directory requires privileges,
  /// and changing its group only allows groups that the process belongs to.
  ///
  /// The corresponding C constant is `_PC_CHOWN_RESTRICTED`.
  @_alwaysEmitIntoClient
  public static var chownRestricted: Self { Self(rawValue: __PC_CHOWN_RESTRICTED) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "chownRestricted")
  public static var _PC_CHOWN_RESTRICTED: Self { chownRestricted }

  /// A value other than `0` if using a file name longer than ``maxFileNameBytes``
  /// in a directory is an error, rather than truncating the name.
  ///
  /// The corresponding C constant is `_PC_NO_TRUNC`.
  @_alwaysEmitIntoClient
  public static var noTruncation: Self { Self(rawValue: __PC_NO_TRUNC) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "noTruncation")
  public static var _PC_NO_TRUNC: Self { noTruncation }

  /// The value that disables a terminal's special character, if it has one.
  ///
  /// Only a terminal has this value.
  ///
  /// The corresponding C constant is `_PC_VDISABLE`.
  @_alwaysEmitIntoClient
  public static var terminalDisableCharacter: Self { Self(rawValue: __PC_VDISABLE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "terminalDisableCharacter")
  public static var _PC_VDISABLE: Self { terminalDisableCharacter }

  /// The number of bits in the largest size that a file
  /// in a directory can have, as a signed integer.
  ///
  /// The corresponding C constant is `_PC_FILESIZEBITS`.
  @_alwaysEmitIntoClient
  public static var fileSizeBits: Self { Self(rawValue: __PC_FILESIZEBITS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "fileSizeBits")
  public static var _PC_FILESIZEBITS: Self { fileSizeBits }

  /// The maximum number of bytes that a symbolic link
  /// in a directory can contain.
  ///
  /// The corresponding C constant is `_PC_SYMLINK_MAX`.
  @_alwaysEmitIntoClient
  public static var maxSymbolicLinkBytes: Self { Self(rawValue: __PC_SYMLINK_MAX) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "maxSymbolicLinkBytes")
  public static var _PC_SYMLINK_MAX: Self { maxSymbolicLinkBytes }

#if SYSTEM_PACKAGE_DARWIN
  /// The number of bits in the largest size
  /// that a file's extended attribute can have, as an unsigned integer.
  ///
  /// The corresponding C constant is `_PC_XATTR_SIZE_BITS`.
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var extendedAttributeSizeBits: Self { Self(rawValue: __PC_XATTR_SIZE_BITS) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "extendedAttributeSizeBits")
  public static var _PC_XATTR_SIZE_BITS: Self { extendedAttributeSizeBits }
#endif

#if SYSTEM_PACKAGE_DARWIN || os(FreeBSD)
  /// The smallest hole that the file's file system reports, in bytes,
  /// or `1` if it reports holes without a minimum size.
  ///
  /// The offsets of holes are multiples of this size.
  /// A file system that doesn't report holes doesn't have this value.
  ///
  /// The corresponding C constant is `_PC_MIN_HOLE_SIZE`.
  /// - Note: Only available on Darwin and FreeBSD.
  @_alwaysEmitIntoClient
  public static var minimumHoleSize: Self { Self(rawValue: __PC_MIN_HOLE_SIZE) }

  @_alwaysEmitIntoClient
  @available(*, unavailable, renamed: "minimumHoleSize")
  public static var _PC_MIN_HOLE_SIZE: Self { minimumHoleSize }
#endif
}

// These functions return -1 both for an error, which sets errno,
// and for a variable without a limit, which leaves it alone.
internal func _valueOrNil(_ body: () -> Int) -> Result<Int?, Errno> {
  system_errno = 0
  let value = body()
  guard value == -1 else { return .success(value) }
  return system_errno == 0 ? .success(nil) : .failure(.current)
}

#endif // !os(Windows) && !os(WASI)
