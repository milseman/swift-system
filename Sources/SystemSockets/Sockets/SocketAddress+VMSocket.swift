/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import SystemPackage

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif os(Linux) || os(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
#endif

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)

@available(System 199, *)
extension SocketDescriptor.Domain {
  /// Communication between a virtual machine and its host,
  /// through VM sockets.
  ///
  /// On Darwin the transport is in a virtual machine,
  /// which it connects to its host:
  /// on a Mac that isn't a virtual machine, creating such a socket fails
  /// with ``Errno/operationNotSupportedByDevice`` (`ENODEV`).
  /// On Linux a guest's transport connects it to its host,
  /// and a host's (`vhost_vsock`) to its guests;
  /// without one, creating such a socket fails
  /// with ``Errno/addressFamilyNotSupported`` (`EAFNOSUPPORT`).
  ///
  /// A socket address's ``SocketAddress/family`` is this domain
  /// for a VM socket address.
  ///
  /// The corresponding C constants are `PF_VSOCK` and `AF_VSOCK`,
  /// which have the same value.
  ///
  /// - Note: Only available on Darwin, Linux, and Android.
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
/// - Note: Only available on Darwin, Linux, and Android.
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

    // Linux declares the context IDs in <linux/vm_sockets.h>, which no C
    // library's Swift module includes; these are its values, which shims.c
    // checks against it.

    /// The hypervisor.
    ///
    /// The corresponding C constant is `VMADDR_CID_HYPERVISOR`.
    @_alwaysEmitIntoClient
    public static var hypervisor: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR))
      #else
      Self(rawValue: 0)
      #endif
    }

    /// Context ID 1, which Darwin reserves, and Linux uses for local
    /// communication, from Linux 5.6.
    ///
    /// The corresponding C constant is `VMADDR_CID_RESERVED`,
    /// or on Linux `VMADDR_CID_LOCAL`.
    @_alwaysEmitIntoClient
    public static var local: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(rawValue: UInt32(VMADDR_CID_RESERVED))
      #else
      Self(rawValue: 1)
      #endif
    }

    /// The host of the virtual machine that the socket is in.
    ///
    /// The corresponding C constant is `VMADDR_CID_HOST`.
    @_alwaysEmitIntoClient
    public static var host: Self {
      #if SYSTEM_PACKAGE_DARWIN
      Self(rawValue: UInt32(VMADDR_CID_HOST))
      #else
      Self(rawValue: 2)
      #endif
    }

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

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension CInterop {
  /// The corresponding C type is `struct sockaddr_vm`.
  public typealias SockAddrVM = sockaddr_vm
}
#else
@available(System 199, *)
extension CInterop {
  /// A VM socket address, as the system calls take it.
  ///
  /// This is a Swift structure with the C structure's layout,
  /// since Linux declares `struct sockaddr_vm`
  /// in `<linux/vm_sockets.h>`, which no C library's Swift module includes.
  /// Its fields have the C names;
  /// the accessors ``family``, ``port``, and ``contextID`` name them in Swift,
  /// and ``VMSocketAddress`` is the Swift type for these addresses.
  ///
  /// The corresponding C type is `struct sockaddr_vm`.
  @frozen
  public struct SockAddrVM {
    /// The address's family, ``SocketDescriptor/Domain/vsock``.
    ///
    /// The corresponding C field is `svm_family`.
    public var svm_family: sa_family_t

    /// Reserved, and zero.
    ///
    /// The corresponding C field is `svm_reserved1`.
    public var svm_reserved1: UInt16

    /// The port.
    ///
    /// The corresponding C field is `svm_port`.
    public var svm_port: UInt32

    /// The context ID.
    ///
    /// The corresponding C field is `svm_cid`.
    public var svm_cid: UInt32

    /// Flags for the address, from Linux 5.11; zero before it.
    ///
    /// The corresponding C field is `svm_flags`.
    public var svm_flags: UInt8

    /// Padding to the size of `struct sockaddr`, which must be zero.
    ///
    /// The corresponding C field is `svm_zero`.
    public var svm_zero: (UInt8, UInt8, UInt8)

    /// Creates an address whose fields are all zero.
    @_alwaysEmitIntoClient
    public init() {
      svm_family = 0
      svm_reserved1 = 0
      svm_port = 0
      svm_cid = 0
      svm_flags = 0
      svm_zero = (0, 0, 0)
    }
  }
}
#endif

@available(System 199, *)
extension SocketAddress {
  /// Creates a socket address from a VM socket address.
  public init(vsock address: VMSocketAddress) {
    var vm = CInterop.SockAddrVM()
    #if SYSTEM_PACKAGE_DARWIN
    vm.svm_len = UInt8(MemoryLayout<CInterop.SockAddrVM>.size)
    #endif
    vm.svm_family = sa_family_t(AF_VSOCK)
    vm.svm_port = address.port.rawValue
    vm.svm_cid = address.contextID.rawValue
    self = Swift.withUnsafeBytes(of: &vm) { SocketAddress($0) }
  }

  /// The address as a VM socket address, if it's one.
  public var vsock: VMSocketAddress? {
    guard family == .vsock, length >= MemoryLayout<CInterop.SockAddrVM>.size else { return nil }
    let vm = Swift.withUnsafeBytes(of: _storage) { $0.loadUnaligned(as: CInterop.SockAddrVM.self) }
    return VMSocketAddress(contextID: .init(rawValue: vm.svm_cid), port: .init(rawValue: vm.svm_port))
  }
}

#if SYSTEM_PACKAGE_DARWIN
@available(System 199, *)
extension SocketDescriptor {
  /// Returns the context ID of the machine that this VM socket is on:
  /// the virtual machine's, in a guest.
  ///
  /// On Linux, the call takes a descriptor for `/dev/vsock` instead:
  /// see `FileDescriptor.localContextID()`.
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
#else
@available(System 199, *)
extension FileDescriptor {
  /// Returns the context ID of this machine, through the VM sockets device:
  /// the virtual machine's, in a guest, or the host's, on a host.
  ///
  /// Call it on a descriptor for `/dev/vsock`:
  ///
  ///     let device = try FileDescriptor.open(
  ///       "/dev/vsock", .readOnly, options: .closeOnExec)
  ///     defer { try? device.close() }
  ///     let contextID = try device.localContextID()
  ///
  /// With no transport, the context ID is ``VMSocketAddress/ContextID/any``.
  /// Another descriptor throws
  /// ``Errno/inappropriateIOCTLForDevice`` (`ENOTTY`).
  /// On Darwin, the call takes a VM socket instead:
  /// see `SocketDescriptor.localContextID()`.
  ///
  /// The corresponding C constant is `IOCTL_VM_SOCKETS_GET_LOCAL_CID`.
  ///
  /// - Note: Only available on Linux and Android.
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
#endif

#endif // SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android)
