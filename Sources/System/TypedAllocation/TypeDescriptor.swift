/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Darwin's typed allocation takes a malloc_type_id_t with each block, whose
// bits are the fields of the version 0 descriptor, malloc_type_descriptor_v0_t:
// a C union of the identifier with a hash and a summary of bitfields.
// TypeDescriptor is the identifier, with Swift-named properties that read
// and change the fields through the C union, so that neither the bits'
// positions nor the C names reach a client. The positions are fixed
// anyway: C compilers emit the identifiers as constants.

#if SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)

import Darwin

@available(System 199, *)
extension Memory {
  /// A description of the values that a block will hold,
  /// which Darwin's typed allocator uses to choose where the block goes.
  ///
  ///     // Bytes, with no pointers among them.
  ///     let bytes = Memory.TypeDescriptor(layout: .containsGenericData)
  ///     let buffer = try Memory.allocate(byteCount: 4096, type: bytes)
  ///     defer { Memory.free(buffer) }
  ///
  /// The typed allocator can keep blocks apart by what they hold:
  /// blocks of plain data away from blocks that hold pointers, for example,
  /// so that a use after free or an overflow of one block
  /// is harder to exploit through another.
  /// A C compiler that supports typed allocation
  /// describes the type of each `malloc` call it compiles;
  /// Swift code describes a block with this type
  /// and passes it to the allocation methods that take a `type:`,
  /// such as ``Memory/allocate(byteCount:type:)``.
  ///
  /// A descriptor is a `malloc_type_id_t`,
  /// whose bits are the fields of the version 0 descriptor.
  /// Its properties read and change those fields.
  ///
  /// The corresponding C types are `malloc_type_id_t`
  /// and `malloc_type_descriptor_v0_t`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @frozen
  public struct TypeDescriptor: RawRepresentable, Hashable, Sendable, Codable {
    /// The raw C type identifier.
    @_alwaysEmitIntoClient
    public var rawValue: UInt64

    /// Creates a strongly-typed descriptor from a raw C type identifier.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt64) { self.rawValue = rawValue }
  }
}

@available(System 199, *)
extension Memory.TypeDescriptor {
  /// Creates a descriptor of the values that a block will hold.
  ///
  /// - Parameters:
  ///   - layout: What the values contain.
  ///   - kind: The runtime that allocates the block.
  ///     The default is ``Kind/other``.
  ///   - callSiteFlags: What the call that allocates the block is like.
  ///     The default is none.
  ///   - typeHash: A hash of the values' type,
  ///     which tells it apart from other types with the same layout.
  ///     The default is zero.
  ///
  /// The descriptor's ``version`` is zero.
  @_alwaysEmitIntoClient
  public init(
    layout: Layout,
    kind: Kind = .other,
    callSiteFlags: CallSiteFlags = [],
    typeHash: UInt32 = 0
  ) {
    self.init(rawValue: 0)
    self.layout = layout
    self.kind = kind
    self.callSiteFlags = callSiteFlags
    self.typeHash = typeHash
  }

  // The identifier as the version 0 descriptor, whose fields are its bits.
  @_alwaysEmitIntoClient
  internal var _v0: malloc_type_descriptor_v0_t {
    get { malloc_type_descriptor_v0_t(type_id: rawValue) }
    set { rawValue = newValue.type_id }
  }

  /// The version of the descriptor's fields,
  /// which is zero for the fields that its other properties read.
  ///
  /// The corresponding C field is `summary.version`.
  @_alwaysEmitIntoClient
  public var version: Int { Int(_v0.summary.version) }

  /// What the values that the block holds contain.
  ///
  /// The corresponding C field is `summary.layout_semantics`.
  @_alwaysEmitIntoClient
  public var layout: Layout {
    get { Layout(rawValue: unsafeBitCast(_v0.summary.layout_semantics, to: UInt16.self)) }
    set {
      _v0.summary.layout_semantics = unsafeBitCast(
        newValue.rawValue, to: malloc_type_layout_semantics_v0_t.self)
    }
  }

  /// The runtime that allocates the block.
  ///
  /// The corresponding C field is `summary.type_kind`.
  @_alwaysEmitIntoClient
  public var kind: Kind {
    get { Kind(rawValue: _v0.summary.type_kind.rawValue) }
    set { _v0.summary.type_kind = malloc_type_kind_v0_t(rawValue: newValue.rawValue) }
  }

  /// What the call that allocates the block is like.
  ///
  /// The corresponding C field is `summary.callsite_flags`.
  @_alwaysEmitIntoClient
  public var callSiteFlags: CallSiteFlags {
    get { CallSiteFlags(rawValue: _v0.summary.callsite_flags.rawValue) }
    set { _v0.summary.callsite_flags = malloc_type_callsite_flags_v0_t(rawValue: newValue.rawValue) }
  }

  /// A hash of the values' type,
  /// which tells it apart from other types with the same layout,
  /// such as types with the same fields in a different order.
  ///
  /// A C compiler hashes the type's layout,
  /// or, when it can't tell the type, the call's file, line, and column.
  ///
  /// The corresponding C field is `hash`.
  @_alwaysEmitIntoClient
  public var typeHash: UInt32 {
    get { _v0.hash }
    set { _v0.hash = newValue }
  }
}

// MARK: - Fields

@available(System 199, *)
extension Memory.TypeDescriptor {
  /// What the values that a block holds contain:
  /// data, and pointers of which kinds.
  ///
  /// The values contain what their fields contain,
  /// and their fields' fields, and so on.
  ///
  /// The corresponding C type is `malloc_type_layout_semantics_v0_t`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @frozen
  public struct Layout: OptionSet, Sendable, Hashable, Codable {
    /// The raw C layout,
    /// whose bits are those of `malloc_type_layout_semantics_v0_t`.
    @_alwaysEmitIntoClient
    public var rawValue: UInt16

    /// Creates a strongly-typed layout from a raw C layout.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt16) { self.rawValue = rawValue }

    /// A pointer to data: to memory that holds no pointers.
    ///
    /// The corresponding C field is `contains_data_pointer`.
    @_alwaysEmitIntoClient
    public static var containsDataPointer: Layout { Layout(rawValue: 1 << 0) }

    /// A pointer to a structure or a union.
    ///
    /// The corresponding C field is `contains_struct_pointer`.
    @_alwaysEmitIntoClient
    public static var containsStructPointer: Layout { Layout(rawValue: 1 << 1) }

    /// A `const` pointer.
    ///
    /// The corresponding C field is `contains_immutable_pointer`.
    @_alwaysEmitIntoClient
    public static var containsImmutablePointer: Layout { Layout(rawValue: 1 << 2) }

    /// A pointer to something other than data, a structure, or a union.
    ///
    /// The corresponding C field is `contains_anonymous_pointer`.
    @_alwaysEmitIntoClient
    public static var containsAnonymousPointer: Layout { Layout(rawValue: 1 << 3) }

    /// The values are reference counted.
    ///
    /// The corresponding C field is `is_reference_counted`.
    @_alwaysEmitIntoClient
    public static var isReferenceCounted: Layout { Layout(rawValue: 1 << 4) }

    /// Data: anything that isn't a pointer.
    ///
    /// The corresponding C field is `contains_generic_data`.
    @_alwaysEmitIntoClient
    public static var containsGenericData: Layout { Layout(rawValue: 1 << 8) }
  }

  /// The runtime that allocates a block.
  ///
  /// The corresponding C type is `malloc_type_kind_v0_t`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @frozen
  public struct Kind: RawRepresentable, Hashable, Sendable, Codable {
    /// The raw C kind.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed kind from a raw C kind.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// No runtime's, as most calls to `malloc` are.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_KIND_V0_OTHER`.
    @_alwaysEmitIntoClient
    public static var other: Kind { Kind(rawValue: _MALLOC_TYPE_KIND_V0_OTHER) }

    /// The Objective-C runtime's.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_KIND_V0_OBJC`.
    @_alwaysEmitIntoClient
    public static var objectiveC: Kind { Kind(rawValue: _MALLOC_TYPE_KIND_V0_OBJC) }

    /// The Swift runtime's.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_KIND_V0_SWIFT`.
    @_alwaysEmitIntoClient
    public static var swift: Kind { Kind(rawValue: _MALLOC_TYPE_KIND_V0_SWIFT) }

    /// The C++ runtime's `operator new`.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_KIND_V0_CXX`.
    @_alwaysEmitIntoClient
    public static var cPlusPlus: Kind { Kind(rawValue: _MALLOC_TYPE_KIND_V0_CXX) }
  }

  /// What the call that allocates a block is like.
  ///
  /// The corresponding C type is `malloc_type_callsite_flags_v0_t`.
  /// - Note: Only available on Darwin, in 64-bit processes.
  @frozen
  public struct CallSiteFlags: OptionSet, Sendable, Hashable, Codable {
    /// The raw C flags.
    @_alwaysEmitIntoClient
    public var rawValue: UInt32

    /// Creates a strongly-typed set of flags from raw C flags.
    @_alwaysEmitIntoClient
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The call allocates a size that's fixed where it's made.
    ///
    /// C compilers currently set it in every call that they turn into a typed allocation.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_CALLSITE_FLAGS_V0_FIXED_SIZE`.
    @_alwaysEmitIntoClient
    public static var fixedSize: CallSiteFlags {
      CallSiteFlags(rawValue: _MALLOC_TYPE_CALLSITE_FLAGS_V0_FIXED_SIZE)
    }

    /// The call allocates an array, as `calloc` and C++'s `new[]` do.
    ///
    /// The corresponding C constant is `MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY`.
    @_alwaysEmitIntoClient
    public static var array: CallSiteFlags {
      CallSiteFlags(rawValue: _MALLOC_TYPE_CALLSITE_FLAGS_V0_ARRAY)
    }
  }
}

#endif // SYSTEM_PACKAGE_DARWIN && _pointerBitWidth(_64)
