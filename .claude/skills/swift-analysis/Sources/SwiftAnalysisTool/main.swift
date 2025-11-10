import ArgumentParser
import Foundation
import SwiftAnalysis

@main
struct SwiftAnalysisTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Swift package analysis tools for Claude",
        subcommands: [AnalyzeDocs.self]
    )
}

struct AnalyzeDocs: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze documentation coverage and quality"
    )

    func run() throws {
        print("Hello from documentation analyzer!")

        // Print current working directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        print("Current working directory: \(currentDirectory)")

        // Use the library to analyze the package
        print("\nAttempting to run 'swift package describe --type json'...")

        let analyzer = PackageAnalyzer()
        do {
            let packageInfo = try analyzer.analyzePackage()
            print("✓ Successfully ran 'swift package describe'")
            print("Output preview (first 200 chars):")
            print(String(packageInfo.jsonOutput.prefix(200)))
        } catch {
            print("✗ Failed: \(error)")
        }
    }
}
