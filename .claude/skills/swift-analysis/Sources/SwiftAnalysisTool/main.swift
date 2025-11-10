import ArgumentParser
import Foundation

struct ExtractAPI: ParsableCommand {
    @Option(help: "Target to analyze (default: all non-test targets)")
    var target: String?

    @Option(help: "Minimum access level to extract")
    var accessLevel: AccessLevel = .public

    @Option(help: "Output format")
    var format: OutputFormat = .json

    func run() throws {
        // Get package structure
        let packageStructure = try getPackageStructure()

        // Filter targets: use specified target or all non-test targets
        let targetsToAnalyze: [PackageTarget]
        if let targetName = target {
            guard let foundTarget = packageStructure.targets.first(where: { $0.name == targetName }) else {
                throw ValidationError("Target '\(targetName)' not found in package")
            }
            targetsToAnalyze = [foundTarget]
        } else {
            // Filter out test targets
            targetsToAnalyze = packageStructure.targets.filter { target in
                !target.type.contains("test") && !target.name.lowercased().contains("test")
            }
        }

        if targetsToAnalyze.isEmpty {
            throw ValidationError("No targets found to analyze")
        }

        // Extract API from each target
        let extractor = APIExtractor(accessLevel: accessLevel)
        var allDeclarations: [APIDeclaration] = []

        for target in targetsToAnalyze {
            let declarations = try extractor.extract(target: target)
            allDeclarations.append(contentsOf: declarations)
        }

        let result = APIExtractionResult(
            packageName: packageStructure.name,
            totalDeclarations: allDeclarations.count,
            declarations: allDeclarations
        )

        // Output based on format
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(result)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        case .markdown:
            print(result.toMarkdown())
        }
    }
}

// MARK: - Helper Functions

func getPackageStructure() throws -> PackageStructure {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["package", "describe", "--type", "json"]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw ValidationError("Failed to run 'swift package describe': \(errorMessage)")
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

    let decoder = JSONDecoder()
    return try decoder.decode(PackageStructure.self, from: outputData)
}

// Run the CLI
ExtractAPI.main()
