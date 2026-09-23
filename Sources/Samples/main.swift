/*
 This source file is part of the Swift System open source project

 Copyright (c) 2021 - 2025 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser

struct SystemSamples: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "system-samples",
    abstract: "A collection of little programs exercising some System features.",
    subcommands: [
      // Socket samples
      Resolve.self,
      ReverseResolve.self,
      Connect.self,
      Listen.self,
      SocketPair.self,
      // Owned descriptor samples
      OwnedCat.self,
      OwnedCopy.self,
      OwnedRedirect.self,
      OwnedPoll.self,
      OwnedLines.self,
      // Terminal samples
      PasswordReader.self,
      TerminalSize.self,
      RawMode.self,
      // File and process samples
      PIDFile.self,
      AtomicWrite.self,
      SetAttributes.self,
      Rename.self,
    ])
}

disableBuffering()
SystemSamples.main()
