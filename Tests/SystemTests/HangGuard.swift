/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

/// How long a test waits for something that should happen at once, such as
/// a thread starting, a signal arriving, or data reaching a pipe, before it
/// fails instead of hanging.
///
/// The wait only guards against a hang: a busy machine can delay any step
/// for seconds, so no test may depend on how long one takes, and this is
/// long enough that only a hang reaches it. See Tests/TESTING.md.
internal let hangGuardSeconds = 300
