/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin

@available(System 199, *)
extension SocketDescriptor.Domain {
  /// Communication between a virtual machine and its host,
  /// through VM sockets.
  ///
  /// The transport is in a virtual machine, which it connects to its host:
  /// on a Mac that isn't a virtual machine, creating such a socket fails
  /// with ``Errno/operationNotSupportedByDevice`` (`ENODEV`).
  ///
  /// A socket address's ``SocketAddress/family`` is this domain
  /// for a VM socket address.
  ///
  /// The corresponding C constants are `PF_VSOCK` and `AF_VSOCK`,
  /// which have the same value.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public static var vsock: Self { Self(rawValue: PF_VSOCK) }
}

/// A VM socket address: a context ID, which names a virtual machine or
/// its host, and a port.
///
///     let host = VMSocketAddress(contextID: .host, port: 1024)
///     try socket.connect(to: SocketAddress(vsock: host))
///
/// The corresponding C type is `struct sockaddr_vm`.
///
/// - Note: Only available on Darwin.
@frozen
@available(System 199, *)
public struct VMSocketAddress: Hashable, Sendable, CustomStringConvertible {
  /// The context ID of the machine.
  ///
  /// The corresponding C field is `svm_cid`.
  public var contextID: ContextID

  /// The port.
  ///
  /// The corresponding C field is `svm_port`.
  public var port: Port

  /// Creates a VM socket address from a context ID and a port.
  @_alwaysEmitIntoClient
  public init(contextID: ContextID, port: Port) {
    self.contextID = contextID
    self.port = port
  }

  /// The address as `context ID:port`, with `-1` for the `any` values.
  public var description: String { "\(contextID):\(port)" }
}

@available(System 199, *)
extension VMSocketAddress {
  /// A context ID, which names a virtual machine or its host.
  @frozen
  public struct ContextID: RawRepresentable, Hashable, Sendable,
    ExpressibleByIntegerLiteral, CustomStringConvertible
  {
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    @_alwaysEmitIntoClient
    public init(integerLiteral value: UInt32) { self.init(rawValue: value) }

    /// Any context ID: to bind to, the local machine's.
    ///
    /// The corresponding C constant is `VMADDR_CID_ANY`.
    @_alwaysEmitIntoClient
    public static var any: Self { Self(rawValue: UInt32(bitPattern: -1)) }

    /// The hypervisor.
    ///
    /// The corresponding C constant is `VMADDR_CID_HYPERVISOR`.
    @_alwaysEmitIntoClient
    public static var hypervisor: Self { Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR)) }

    /// Context ID 1, which Darwin reserves, and Linux uses for local
    /// communication (`VMADDR_CID_LOCAL`).
    ///
    /// The corresponding C constant is `VMADDR_CID_RESERVED`.
    @_alwaysEmitIntoClient
    public static var local: Self { Self(rawValue: UInt32(VMADDR_CID_RESERVED)) }

    /// The host of the virtual machine that the socket is in.
    ///
    /// The corresponding C constant is `VMADDR_CID_HOST`.
    @_alwaysEmitIntoClient
    public static var host: Self { Self(rawValue: UInt32(VMADDR_CID_HOST)) }

    public var description: String { self == .any ? "-1" : rawValue.description }
  }

  /// A VM socket port.
  @frozen
  public struct Port: RawRepresentable, Hashable, Sendable,
    ExpressibleByIntegerLiteral, CustomStringConvertible
  {
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    @_alwaysEmitIntoClient
    public init(integerLiteral value: UInt32) { self.init(rawValue: value) }

    /// Any port: to bind to, one the system chooses.
    ///
    /// The corresponding C constant is `VMADDR_PORT_ANY`.
    @_alwaysEmitIntoClient
    public static var any: Self { Self(rawValue: UInt32(bitPattern: -1)) }

    public var description: String { self == .any ? "-1" : rawValue.description }
  }
}

@available(System 199, *)
extension CInterop {
  /// The corresponding C type is `struct sockaddr_vm`.
  public typealias SockAddrVM = sockaddr_vm
}

@available(System 199, *)
extension SocketAddress {
  /// Creates a socket address from a VM socket address.
  public init(vsock address: VMSocketAddress) {
    var vm = sockaddr_vm()
    vm.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
    vm.svm_family = sa_family_t(AF_VSOCK)
    vm.svm_port = address.port.rawValue
    vm.svm_cid = address.contextID.rawValue
    self = Swift.withUnsafeBytes(of: &vm) { SocketAddress($0) }
  }

  /// The address as a VM socket address, if it's one.
  public var vsock: VMSocketAddress? {
    guard family == .vsock, length >= MemoryLayout<sockaddr_vm>.size else { return nil }
    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: sockaddr_vm.self) }
    return VMSocketAddress(contextID: .init(rawValue: vm.svm_cid), port: .init(rawValue: vm.svm_port))
  }
}

@available(System 199, *)
extension SocketDescriptor {
  /// Returns the context ID of the machine that this VM socket is on:
  /// the virtual machine's, in a guest.
  ///
  /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
  ///
  /// - Note: Only available on Darwin.
  @_alwaysEmitIntoClient
  public func localContextID() throws(Errno) -> VMSocketAddress.ContextID {
    try _localContextID().get()
  }

  @usableFromInline
  internal func _localContextID() -> Result<VMSocketAddress.ContextID, Errno> {
    var contextID = VMSocketAddress.ContextID.any.rawValue
    return nothingOrErrno(retryOnInterrupt: false) {
      system_ioctl(self.rawValue, _IOCTL_VM_SOCKETS_GET_LOCAL_CID, &contextID)
    }.map { VMSocketAddress.ContextID(rawValue: contextID) }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
