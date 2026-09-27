/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Listing processes: proc_listpids.
//
// proc_listpids fills as much of a buffer as fits and says nothing about
// the rest, so these grow the buffer until part of it is left over. It
// returns 0 both for an error and for an empty list, so these clear errno
// first.

// libproc is only in the macOS SDK.
#if os(macOS)

@available(System 199, *)
extension ProcessID {
  /// Returns the IDs of every process.
  ///
  /// The list includes the kernel's own task, whose ID is 0.
  /// Processes come and go,
  /// so the list can include some that have since exited.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_ALL_PIDS` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public static func all() throws(Errno) -> [ProcessID] {
    try _list(_PROC_ALL_PIDS, 0).get()
  }

  /// Returns the IDs of the processes in a process group.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_PGRP_ONLY` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public static func all(inGroup group: ProcessID) throws(Errno) -> [ProcessID] {
    try _list(_PROC_PGRP_ONLY, UInt32(bitPattern: group.rawValue)).get()
  }

  /// Returns the IDs of the processes whose controlling terminal
  /// is a given device.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_TTY_ONLY` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public static func all(onTerminal terminal: DeviceID) throws(Errno) -> [ProcessID] {
    try _list(_PROC_TTY_ONLY, UInt32(bitPattern: terminal.rawValue)).get()
  }

  /// Returns the IDs of the processes whose effective user
  /// is a given user.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_UID_ONLY` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public static func all(ofUser user: UserID) throws(Errno) -> [ProcessID] {
    try _list(_PROC_UID_ONLY, user.rawValue).get()
  }

  /// Returns the IDs of the processes whose real user is a given user.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_RUID_ONLY` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public static func all(ofRealUser user: UserID) throws(Errno) -> [ProcessID] {
    try _list(_PROC_RUID_ONLY, user.rawValue).get()
  }

  /// Returns the IDs of the process's children.
  ///
  /// The corresponding C function is `proc_listpids`,
  /// with the `PROC_PPID_ONLY` type.
  /// - Note: Only available on macOS.
  @_alwaysEmitIntoClient
  public func children() throws(Errno) -> [ProcessID] {
    try ProcessID._list(_PROC_PPID_ONLY, UInt32(bitPattern: rawValue)).get()
  }

  @usableFromInline
  internal static func _list(
    _ type: UInt32, _ typeinfo: UInt32
  ) -> Result<[ProcessID], Errno> {
    let stride = MemoryLayout<CInterop.ProcessID>.stride
    var capacity = 1024
    while true {
      var ids = [CInterop.ProcessID](repeating: 0, count: capacity)
      system_errno = 0
      let filled = ids.withUnsafeMutableBytes { buffer in
        Int(system_proc_listpids(type, typeinfo, buffer.baseAddress, CInt(buffer.count)))
      }
      if filled == 0 && system_errno != 0 { return .failure(.current) }
      let count = filled / stride
      // A full buffer may have left some out. No system has a million
      // processes, so growth stops there.
      guard count < capacity || capacity >= 1 << 20 else {
        capacity *= 2
        continue
      }
      return .success(ids[..<count].map { ProcessID(rawValue: $0) })
    }
  }
}

#endif // os(macOS)
