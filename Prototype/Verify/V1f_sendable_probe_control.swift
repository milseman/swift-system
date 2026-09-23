// V1f: control for V1e: the probe rejects a non-Sendable type; and the SDK System module's FileDescriptor.
import System
public final class NotSendable {}
func needsSendable(_: some Sendable) {}
func control() { needsSendable(NotSendable()) }
@available(macOS 11, *)
func sdk() { needsSendable(FileDescriptor.standardInput) }
