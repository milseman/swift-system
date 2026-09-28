/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if SYSTEM_PACKAGE_DARWIN

import Darwin

// MARK: - readpassphrase flags

@_alwaysEmitIntoClient
internal var _RPP_ECHO_ON: CInt { RPP_ECHO_ON }

@_alwaysEmitIntoClient
internal var _RPP_REQUIRE_TTY: CInt { RPP_REQUIRE_TTY }

@_alwaysEmitIntoClient
internal var _RPP_FORCELOWER: CInt { RPP_FORCELOWER }

@_alwaysEmitIntoClient
internal var _RPP_FORCEUPPER: CInt { RPP_FORCEUPPER }

@_alwaysEmitIntoClient
internal var _RPP_SEVENBIT: CInt { RPP_SEVENBIT }

@_alwaysEmitIntoClient
internal var _RPP_STDIN: CInt { RPP_STDIN }

#endif // SYSTEM_PACKAGE_DARWIN
