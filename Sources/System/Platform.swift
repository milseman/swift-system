/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

@_implementationOnly import SystemInternals

// Public typealiases that can't be reexported from SystemInternals

/// The C `mode_t` type.
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
// @available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public typealias CModeT =  UInt16
#else
public typealias CModeT =  UInt32
#endif


/// A namespace for typealiases for underlying C types
public enum CTypes {
  // Compatibility
  public typealias Mode = CModeT

  public typealias PID = Int32 // TODO: Linux?

  public typealias SigSet = UInt32 // TODO: Linux?

  public typealias Short = UInt16
}

