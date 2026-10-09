/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// SystemSockets on a Windows host: Package.swift builds the module from this
// directory alone there, since the module's other files wrap POSIX's sockets
// and #error on Windows, whose sockets SystemWinSocks wraps. The module is
// empty then, and its product stays declared, so that an adopter's
// dependency on it with a condition that leaves Windows out still resolves
// on a Windows host. Elsewhere this file is part of the module, and declares
// nothing.
