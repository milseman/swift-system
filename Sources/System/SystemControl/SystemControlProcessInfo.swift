/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The kernel's information about a process, which SystemControl's process
// names read, with Swift-named accessors for what callers read from it: a
// client that doesn't import Darwin can't reach the C structure's nested
// fields under MemberImportVisibility.

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@available(System 199, *)
extension CInterop {
  /// The kernel's information about a process,
  /// as ``SystemControl/Name/process(_:)`` reads it.
  ///
  /// The corresponding C type is `struct kinfo_proc`.
  ///
  /// - Note: Only available on Darwin.
  public typealias KernelProcessInfo = kinfo_proc
}

@available(System 199, *)
extension CInterop.KernelProcessInfo {
  /// The process's ID.
  ///
  /// The corresponding C field is `p_pid`, of `kp_proc`.
  @_alwaysEmitIntoClient
  public var processID: ProcessID { ProcessID(rawValue: kp_proc.p_pid) }

  /// The ID of the process's parent.
  ///
  /// The corresponding C field is `e_ppid`, of `kp_eproc`.
  @_alwaysEmitIntoClient
  public var parentProcessID: ProcessID { ProcessID(rawValue: kp_eproc.e_ppid) }

  /// The ID of the process's process group.
  ///
  /// The corresponding C field is `e_pgid`, of `kp_eproc`.
  @_alwaysEmitIntoClient
  public var processGroupID: ProcessID { ProcessID(rawValue: kp_eproc.e_pgid) }

  /// The process's real user.
  ///
  /// The corresponding C field is `p_ruid`, of `kp_eproc.e_pcred`.
  @_alwaysEmitIntoClient
  public var realUserID: UserID { UserID(rawValue: kp_eproc.e_pcred.p_ruid) }

  /// The process's effective user.
  ///
  /// The corresponding C field is `cr_uid`, of `kp_eproc.e_ucred`.
  @_alwaysEmitIntoClient
  public var effectiveUserID: UserID { UserID(rawValue: kp_eproc.e_ucred.cr_uid) }

  /// The process's saved set-user ID:
  /// the effective user it had when it started its program,
  /// which it can switch back to.
  ///
  /// Darwin has no call that returns it, as `getresuid` does elsewhere.
  ///
  /// The corresponding C field is `p_svuid`, of `kp_eproc.e_pcred`.
  @_alwaysEmitIntoClient
  public var savedUserID: UserID { UserID(rawValue: kp_eproc.e_pcred.p_svuid) }

  /// The process's real group.
  ///
  /// The corresponding C field is `p_rgid`, of `kp_eproc.e_pcred`.
  @_alwaysEmitIntoClient
  public var realGroupID: GroupID { GroupID(rawValue: kp_eproc.e_pcred.p_rgid) }

  /// The process's saved set-group ID.
  ///
  /// The corresponding C field is `p_svgid`, of `kp_eproc.e_pcred`.
  @_alwaysEmitIntoClient
  public var savedGroupID: GroupID { GroupID(rawValue: kp_eproc.e_pcred.p_svgid) }

  /// Whether a debugger is tracing the process.
  ///
  /// The corresponding C constant is `P_TRACED`, in `kp_proc.p_flag`.
  @_alwaysEmitIntoClient
  public var isTraced: Bool { (kp_proc.p_flag & P_TRACED) != 0 }

  /// The name of the process's program, as the kernel keeps it:
  /// its file name, cut to the first 16 bytes.
  ///
  /// The corresponding C field is `p_comm`, of `kp_proc`.
  @_alwaysEmitIntoClient
  public var commandName: String {
    withUnsafeBytes(of: kp_proc.p_comm) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
