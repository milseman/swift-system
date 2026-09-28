/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Named semaphores' largest value: SEM_VALUE_MAX.

#if !os(Windows) && !os(WASI) && !os(Android)

#if SYSTEM_PACKAGE_DARWIN
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported Platform")
#endif

@_alwaysEmitIntoClient
internal var _SEM_VALUE_MAX: Int { Int(SEM_VALUE_MAX) }

#endif // !os(Windows) && !os(WASI) && !os(Android)
