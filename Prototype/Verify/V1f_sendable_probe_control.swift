// V1f: control for V1e: the probe rejects a non-Sendable type; and the SDK System module's FileDescriptor. Expected to fail at `control` only: "type 'NotSendable' does not conform to the 'Sendable' protocol". `sdk` compiles: the SDK's System.swiftinterface declares `extension System.FileDescriptor : Swift.Sendable {}`.
import System
public final class NotSendable {}
func needsSendable(_: some Sendable) {}
func control() { needsSendable(NotSendable()) }
@available(macOS 11, *)
func sdk() { needsSendable(FileDescriptor.standardInput) }
