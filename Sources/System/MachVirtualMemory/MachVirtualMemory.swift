/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Darwin.Mach

@available(System 199, *)
extension Mach {
  /// The calling task's virtual memory, which the Mach kernel allocates
  /// in whole pages.
  ///
  ///     let region = try Mach.VirtualMemory.allocate(byteCount: 1 << 20)
  ///     defer { try? Mach.VirtualMemory.deallocate(region) }
  ///
  /// The kernel allocates and deallocates whole pages,
  /// of the size that ``SystemConfig/Name/pageSize`` reports,
  /// and new pages are filled with zeros.
  /// Copying whole pages can share them copy-on-write,
  /// so that a large copy costs little until one side changes it.
  ///
  /// Foundation's `Data` deallocates memory it's given with
  /// `.virtualMemory` as ``deallocate(_:)`` does.
  ///
  /// Each call acts on the calling task's memory;
  /// the corresponding C variable is `mach_task_self_`.
  /// The kernel takes a region's start and size as integers;
  /// the corresponding C types are `vm_address_t` and `vm_size_t`.
  public enum VirtualMemory {}
}

@available(System 199, *)
extension Mach.VirtualMemory {
  /// Allocates pages of memory filled with zeros,
  /// wherever the task's address space has room.
  ///
  /// - Parameter byteCount: The number of bytes to allocate,
  ///   which can't be negative.
  ///   The kernel allocates whole pages, rounding it up.
  ///   Zero allocates nothing, and returns an empty buffer.
  /// - Returns: The region: its start is a page boundary,
  ///   and its count is `byteCount`.
  ///
  /// Deallocate the region with ``deallocate(_:)``.
  /// If the address space has no room,
  /// this method throws ``Mach/KernelError/noSpace``.
  ///
  /// The corresponding C function is `vm_allocate`, with `VM_FLAGS_ANYWHERE`.
  @_alwaysEmitIntoClient
  public static func allocate(
    byteCount: Int
  ) throws(Mach.KernelError) -> UnsafeMutableRawBufferPointer {
    try _allocate(byteCount: byteCount).get()
  }

  @usableFromInline
  internal static func _allocate(
    byteCount: Int
  ) -> Result<UnsafeMutableRawBufferPointer, Mach.KernelError> {
    precondition(byteCount >= 0, "byteCount can't be negative")
    var address: vm_address_t = 0
    return Mach.KernelError._check(
      system_vm_allocate(&address, vm_size_t(byteCount), _VM_FLAGS_ANYWHERE)
    ).map {
      UnsafeMutableRawBufferPointer(
        start: UnsafeMutableRawPointer(bitPattern: address), count: byteCount)
    }
  }

  /// Deallocates pages: every page that a region touches.
  ///
  /// - Parameter region: The memory to deallocate,
  ///   usually a region that ``allocate(byteCount:)`` returned.
  ///
  /// The kernel deallocates whole pages,
  /// from the page that contains the region's start
  /// through the one that contains its end,
  /// so deallocating part of a page deallocates all of it.
  /// Pages that aren't allocated are skipped,
  /// so deallocating a region twice succeeds, and so does an empty region.
  /// Using the memory after deallocating it is undefined behavior.
  ///
  /// The corresponding C function is `vm_deallocate`.
  @_alwaysEmitIntoClient
  public static func deallocate(
    _ region: UnsafeMutableRawBufferPointer
  ) throws(Mach.KernelError) {
    try _deallocate(region).get()
  }

  @usableFromInline
  internal static func _deallocate(
    _ region: UnsafeMutableRawBufferPointer
  ) -> Result<(), Mach.KernelError> {
    Mach.KernelError._check(system_vm_deallocate(
      vm_address_t(UInt(bitPattern: region.baseAddress)), vm_size_t(region.count)))
  }

  /// Copies memory from one region of the task's memory to another.
  ///
  /// - Parameters:
  ///   - source: The memory to copy.
  ///   - destination: The start of the memory to copy it to,
  ///     which must be allocated and writable for `source.count` bytes.
  ///
  /// The regions can start anywhere and have any length,
  /// and they can overlap, as for `memmove`.
  /// The kernel can share whole pages that line up copy-on-write,
  /// which is what makes this cheaper than `memmove` for large,
  /// page-aligned regions.
  ///
  /// If either region isn't allocated,
  /// or the destination isn't writable,
  /// this method throws ``Mach/KernelError/invalidAddress``.
  ///
  /// The corresponding C function is `vm_copy`.
  @_alwaysEmitIntoClient
  public static func copy(
    from source: UnsafeRawBufferPointer, to destination: UnsafeMutableRawPointer
  ) throws(Mach.KernelError) {
    try _copy(from: source, to: destination).get()
  }

  @usableFromInline
  internal static func _copy(
    from source: UnsafeRawBufferPointer, to destination: UnsafeMutableRawPointer
  ) -> Result<(), Mach.KernelError> {
    Mach.KernelError._check(system_vm_copy(
      vm_address_t(UInt(bitPattern: source.baseAddress)), vm_size_t(source.count),
      vm_address_t(UInt(bitPattern: destination))))
  }
}

#endif // SYSTEM_PACKAGE_DARWIN
