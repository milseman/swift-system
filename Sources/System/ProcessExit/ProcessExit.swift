/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

#if !os(Windows)

@available(System 199, *)
extension ProcessID {
  /// Ends the calling process with a status,
  /// after running its exit handlers and flushing its C streams.
  ///
  /// - Parameter status: The process's exit status, from 0 through 255.
  ///   By convention, 0 means success, and other values failure;
  ///   C's `EXIT_SUCCESS` and `EXIT_FAILURE` are 0 and 1.
  ///   A parent that waits for the process with `waitpid`
  ///   gets only the status's low 8 bits,
  ///   though on Darwin `waitid` reports more of them.
  ///
  /// Ending the process this way runs the handlers
  /// that ``addExitHandler(_:)`` registered,
  /// in the reverse of the order they were registered in,
  /// then flushes and closes the C library's streams,
  /// such as the standard output that Swift's `print` writes to,
  /// and then ends the process, closing its descriptors.
  /// Returning from a program's `main` does the same.
  ///
  /// No Swift code runs after this call but the exit handlers:
  /// not the deinitializers of values still alive,
  /// nor any `defer` block.
  /// Other threads keep running until the process ends,
  /// so they can see the state that the exit handlers tear down.
  /// C leaves undefined a second call to `exit`,
  /// from an exit handler or from another thread,
  /// while one is running;
  /// ``exitImmediately(_:)`` is safe from anywhere.
  ///
  /// The corresponding C function is `exit`.
  @_alwaysEmitIntoClient
  public static func exit(_ status: CInt) -> Never {
    _exitProcess(status)
  }

  @usableFromInline
  internal static func _exitProcess(_ status: CInt) -> Never {
    system_exit(status)
  }

  /// Ends the calling process with a status at once,
  /// without running its exit handlers or flushing its C streams.
  ///
  /// - Parameter status: The process's exit status, from 0 through 255.
  ///   By convention, 0 means success, and other values failure.
  ///   See ``exit(_:)``.
  ///
  /// Unlike ``exit(_:)``, this method runs no code in the process:
  /// output that a C stream still holds is lost,
  /// which includes what Swift's `print` wrote to a standard output
  /// that's a pipe or a file, unless the stream was flushed.
  /// Otherwise the process ends as it does with `exit(_:)`:
  /// its descriptors close, its children get a new parent,
  /// and its parent can wait for it.
  ///
  /// It's safe to call from a signal handler,
  /// and in a child process that `fork` created
  /// in a process with other threads,
  /// where `exit(_:)` isn't.
  ///
  /// The corresponding C function is `_exit`.
  @_alwaysEmitIntoClient
  public static func exitImmediately(_ status: CInt) -> Never {
    _exitImmediately(status)
  }

  @usableFromInline
  internal static func _exitImmediately(_ status: CInt) -> Never {
    system__exit(status)
  }

  /// Registers a function to run when the calling process exits.
  ///
  /// - Parameter handler: The function to run.
  ///   It's a C function,
  ///   which a closure that captures nothing converts to,
  ///   as does a global function or a static method:
  ///
  ///       try ProcessID.addExitHandler {
  ///         Logger.shared.flush()
  ///       }
  ///
  /// The handlers run when the process calls ``exit(_:)``,
  /// or returns from its `main`,
  /// in the reverse of the order they were registered in,
  /// on the thread that ends the process,
  /// while other threads keep running.
  /// A handler registered twice runs twice.
  /// They don't run when the process calls ``exitImmediately(_:)``,
  /// when a signal ends it, or when it traps,
  /// as a failed precondition or `fatalError` does.
  /// A handler can't be unregistered.
  ///
  /// This method throws ``Errno/noMemory`` if the system can't record
  /// another handler. C reports only that the call failed.
  ///
  /// The corresponding C function is `atexit`.
  @_alwaysEmitIntoClient
  public static func addExitHandler(
    _ handler: @convention(c) () -> Void
  ) throws(Errno) {
    try _addExitHandler(handler).get()
  }

  @usableFromInline
  internal static func _addExitHandler(
    _ handler: @convention(c) () -> Void
  ) -> Result<Void, Errno> {
    system_atexit(handler) == 0 ? .success(()) : .failure(.noMemory)
  }
}

#endif // !os(Windows)
