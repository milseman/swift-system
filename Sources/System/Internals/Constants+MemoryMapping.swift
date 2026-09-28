/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows) && !os(WASI)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

// MARK: - Protection

@_alwaysEmitIntoClient
internal var _PROT_READ: CInt { PROT_READ }

@_alwaysEmitIntoClient
internal var _PROT_WRITE: CInt { PROT_WRITE }

@_alwaysEmitIntoClient
internal var _PROT_EXEC: CInt { PROT_EXEC }

// MARK: - mmap flags

@_alwaysEmitIntoClient
internal var _MAP_SHARED: CInt { MAP_SHARED }

@_alwaysEmitIntoClient
internal var _MAP_PRIVATE: CInt { MAP_PRIVATE }

@_alwaysEmitIntoClient
internal var _MAP_ANON: CInt { MAP_ANON }

#if os(Linux) || os(Android)
@_alwaysEmitIntoClient
internal var _MAP_NORESERVE: CInt { MAP_NORESERVE }

@_alwaysEmitIntoClient
internal var _MAP_POPULATE: CInt { MAP_POPULATE }
#endif

// MARK: - msync flags

@_alwaysEmitIntoClient
internal var _MS_ASYNC: CInt { MS_ASYNC }

@_alwaysEmitIntoClient
internal var _MS_SYNC: CInt { MS_SYNC }

@_alwaysEmitIntoClient
internal var _MS_INVALIDATE: CInt { MS_INVALIDATE }

// MARK: - madvise advice

@_alwaysEmitIntoClient
internal var _MADV_NORMAL: CInt { MADV_NORMAL }

@_alwaysEmitIntoClient
internal var _MADV_RANDOM: CInt { MADV_RANDOM }

@_alwaysEmitIntoClient
internal var _MADV_SEQUENTIAL: CInt { MADV_SEQUENTIAL }

@_alwaysEmitIntoClient
internal var _MADV_WILLNEED: CInt { MADV_WILLNEED }

@_alwaysEmitIntoClient
internal var _MADV_DONTNEED: CInt { MADV_DONTNEED }

#if SYSTEM_PACKAGE_DARWIN || os(Linux) || os(Android) || os(FreeBSD)
@_alwaysEmitIntoClient
internal var _MADV_FREE: CInt { MADV_FREE }
#endif

#endif // !os(Windows) && !os(WASI)
