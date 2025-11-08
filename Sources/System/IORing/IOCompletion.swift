#if compiler(>=6.2) && $Lifetimes
#if os(Linux)

import CSystem

public extension IORing {
    /// The result of a completed I/O operation from an IORing.
    ///
    /// Completions contain information about the operation's success or failure,
    /// including the result code, user-provided context, and optional flags.
    struct Completion: ~Copyable {
        @inlinable init(rawValue inRawValue: io_uring_cqe) {
            rawValue = inRawValue
        }
        @usableFromInline let rawValue: io_uring_cqe
    }
}

public extension IORing.Completion {
    /// Flags providing additional information about a completion.
    struct Flags: OptionSet, Hashable, Codable {
        public let rawValue: UInt32

        @inlinable public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        ///`IORING_CQE_F_BUFFER` Indicates the buffer ID is stored in the upper 16 bits
        @inlinable public static var allocatedBuffer: Flags { Flags(rawValue: 1 << 0) }
        ///`IORING_CQE_F_MORE`  Indicates more completions will be generated from the request that generated this
        @inlinable public static var moreCompletions: Flags { Flags(rawValue: 1 << 1) }
        //`IORING_CQE_F_SOCK_NONEMPTY`, but currently unused
        //@inlinable public static var socketNotEmpty: Flags { Flags(rawValue: 1 << 2) }
        //`IORING_CQE_F_NOTIF`, but currently unused
        //@inlinable public static var isNotificationEvent: Flags { Flags(rawValue: 1 << 3) }
        //IORING_CQE_F_BUF_MORE  will eventually be  (1U << 4) if we add IOU_PBUF_RING_INC support
    }
}

public extension IORing.Completion {
    /// The user-defined context value that was provided when the operation was submitted.
    @inlinable var context: UInt64 {
        get {
            rawValue.user_data
        }
    }

    /// The user-defined context interpreted as an unsafe pointer.
    @inlinable var userPointer: UnsafeRawPointer? {
        get {
            UnsafeRawPointer(bitPattern: UInt(rawValue.user_data))
        }
    }

    /// The result of the I/O operation, as a signed 32-bit integer.
    ///
    /// For successful operations, this is typically the number of bytes transferred.
    /// For failed operations, this is a negated errno value.
    @inlinable var result: Int32 {
        get {
            rawValue.res
        }
    }

    /// Additional flags describing this completion.
    @inlinable var flags: IORing.Completion.Flags {
        get {
            Flags(rawValue: rawValue.flags & 0x0000FFFF)
        }
    }

    /// The buffer index if this completion used an allocated buffer from a buffer ring.
    ///
    /// Returns the buffer ID if the `allocatedBuffer` flag is set, otherwise nil.
    @inlinable var bufferIndex: UInt16? {
        get {
            if self.flags.contains(.allocatedBuffer) {
                return UInt16(rawValue.flags >> 16)
            } else {
                return nil
            }
        }
    }
}
#endif // os(Linux)
#endif // compiler(>=6.2) && $Lifetimes
