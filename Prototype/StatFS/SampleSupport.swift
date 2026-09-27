/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// Stand-ins for the helpers of Sources/Samples/Util.swift that the statfs
// sample calls, for check-linux.sh: Util.swift imports SystemSockets, which
// the check doesn't build.

func printTable(_ rows: [[String]]) {}

func complain(_ message: String) {}
