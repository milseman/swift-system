///*
// This source file is part of the Swift System open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift System project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//*/
//
//@_implementationOnly import SystemInternals
//
///// ...
//public struct ProcessID: RawRepresentable, Hashable, Codable {
//  /// The raw C process id.
//  @_alwaysEmitIntoClient
//  public let rawValue: CTypes.PID
//
//  /// Creates a strongly-typed process id from a raw C pid
//  @_alwaysEmitIntoClient
//  public init(rawValue: CTypes.PID) { self.rawValue = rawValue }
//
//}
//
//extension ProcessID {
//
//  // NOTE: While posix_spawn_x structs are already opaque types, as void * on
//  // Darwin (and I assume Linux), they are always handled indirectly. Thus our
//  // wrappers will effectively be UnsafeMutablePointer
//
//  // So.... you would normally malloc a void *, then posix_x_init it by pointer (void **)
//  //
//
//  // But, on Linux, it is defined as a struct in a header...
//  
//  // TODO: Should we have a const and non-const type? If we store a mutable
//  // pointer, will that mean we will be const-casting away? If we store immutable,
//  // can we use with a mutable API? How about const-ness means struct mutability...
//
//  /// ...
//  // TODO: associated methods
//  public struct _SpawnFileActions: RawRepresentable, Hashable {
//    /// ...
//    @_alwaysEmitIntoClient
//    public var rawValue: UnsafeMutableRawPointer
//    // TODO: Should this be the void *, or should this be a pointer to the void *?
//
//    @_alwaysEmitIntoClient
//    public let rawConstValue: UnsafeMutableRawPointer
//
//
//    /// ...
//    @_alwaysEmitIntoClient
//    public init(rawValue: UnsafeMutableRawPointer) { self.rawValue = rawValue }
//  }
//}
//
//extension ProcessID {
//  public struct SpawnAttributes {
//    public var flags: Flags
//
//    public var signalMask: SignalSet
//
//    public var signalDefault: SignalSet
//
//    // TODO: all optional, setting them will set the relevant flag at creation...
//    // processGroup: PID?
//}
//
////extension ProcessID.SpawnAttributes {
//  public struct Flags: OptionSet, Hashable, Codable {
//    public var rawValue: CTypes.Short
//
//    public init(rawValue: CTypes.Short) {
//      self.rawValue = rawValue
//    }
//  }
//
//  // Or, chaining API?
//  public func setFlags(_ flags: Flags) -> SpawnAttributes {
//    var ret = self
//    ret.flags = flags
//    return ret
//  }
//
//  public func setSignalMask(_ signalMask: SignalSet) -> SpawnAttributes {
//    var ret = self
//    ret.signalMask = signalMask
//    return ret
//  }
//
//  public func setSignalDefault(_ signalDefault: SignalSet) -> SpawnAttributes {
//    let rep = repeatElement(1, count: 10)
//    var ret = self
//    ret.signalDefault = signalDefault
//    return ret
//  }
//}
//}
//
//
//// TODO: even more declarative, don't need to separate out flags...
//
//
//// TODO: sigset_t
//
///*
//
// spawn_attr:
//
//   init(*)
//   destroy(*)
//
//   get/set:
//     short flags // OptionSet of 7-ish constants
//     const sigset_t * sigmask
//     const sigset_t * sigdefault
//     pid_t pgroup
//
//
//
//
//
//
//
//
//
// */
//
//extension ProcessID {
//
///*
//   public func posix_spawn(
//     _: UnsafeMutablePointer<pid_t>!,
//     _: UnsafePointer<Int8>!,
//     _: UnsafePointer<posix_spawn_file_actions_t?>!,
//     _: UnsafePointer<posix_spawnattr_t?>!,
//     _ __argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!,
//     _ __envp: UnsafePointer<UnsafeMutablePointer<Int8>?>!
//   ) -> Int32
//
//
//*/
//
//  @usableFromInline
//  internal static func _spawn(
//    from path: UnsafePointer<CChar>,
//    _ actions: ProcessID.SpawnFileActions,
//    _ attributes: ProcessID.SpawnAttributes,
//    arguments argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!,
//    environment env: UnsafePointer<UnsafeMutablePointer<Int8>?>!
//  ) -> Result<ProcessID, Errno> {
//    var pid: CTypes.PID
//
//    let ret = system_posix_spawn(&pid, path, actions.rawValue, attributes.rawValue, argv, env)
//    return valueOrErrorCode(pid, errorCode: ret)
//  }
//
//
//  public static func spawn(
//    from path: UnsafePointer<CChar>,
//    _ actions: ProcessID.SpawnFileActions,
//    _ attributes: ProcessID.SpawnAttributes,
//    arguments argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!,
//    environment env: UnsafePointer<UnsafeMutablePointer<Int8>?>!
//  ) throws -> ProcessID {
//    try _spawn(
//      from: path, actions, attributes, arguments: argv, environment: env
//    ).get()
//  }
//  public static func spawn(
//    from path: FilePath,
//    _ actions: ProcessID.SpawnFileActions,
//    _ attributes: ProcessID.SpawnAttributes,
//    arguments argv: [String],
//    environment env: [String]
//  ) throws -> ProcessID {
//    try path.withCString { path in
//      try argv._asArgList { argv in
//        try env._asArgList { env in
//          try spawn(from: path, actions, attributes, arguments: argv, environment: env)
//        }
//      }
//    }
//  }
//}
//
