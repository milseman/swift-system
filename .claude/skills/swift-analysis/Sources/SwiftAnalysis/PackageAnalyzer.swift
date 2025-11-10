import Foundation

public struct PackageAnalyzer {
    public init() {}

    public func analyzePackage(at path: String? = nil) throws -> PackageInfo {
        let workingDirectory = path ?? FileManager.default.currentDirectoryPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["package", "describe", "--type", "json"]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageAnalyzerError.commandFailed(errorMessage)
        }

        let jsonString = String(data: outputData, encoding: .utf8) ?? ""
        return PackageInfo(workingDirectory: workingDirectory, jsonOutput: jsonString)
    }
}

public struct PackageInfo {
    public let workingDirectory: String
    public let jsonOutput: String

    public init(workingDirectory: String, jsonOutput: String) {
        self.workingDirectory = workingDirectory
        self.jsonOutput = jsonOutput
    }
}

public enum PackageAnalyzerError: Error, CustomStringConvertible {
    case commandFailed(String)

    public var description: String {
        switch self {
        case .commandFailed(let message):
            return "swift package describe failed: \(message)"
        }
    }
}
