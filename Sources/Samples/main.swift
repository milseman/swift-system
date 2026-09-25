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
      UDPEcho.self,
      UnixSocket.self,
      // Owned descriptor samples
      OwnedCat.self,
      OwnedCopy.self,
      OwnedRedirect.self,
      OwnedPoll.self,
      OwnedLines.self,
      OwnedPipe.self,
      // Terminal samples
      PasswordReader.self,
      TerminalSize.self,
      RawMode.self,
      Stty.self,
      JobControl.self,
      // File and process samples
      PIDFile.self,
      AtomicWrite.self,
      SetAttributes.self,
      Rename.self,
      FIFO.self,
      ID.self,
      Touch.self,
      SpanCopy.self,
      Links.self,
      Ln.self,
      Beneath.self,
      FDFlags.self,
      Access.self,
      Pushd.self,
      Locks.self,
      GetConf.self,
      ProcInfo.self,
      Sparse.self,
      MkdirP.self,
      ChmodH.self,
      WAL.self,
      FDPath.self,
      SignalIO.self,
      PipeAtomic.self,
      Extents.self,
      PlatformSamples.self,
    ])
}

disableBuffering()
SystemSamples.main()
