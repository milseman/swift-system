import Foundation
import ArgumentParser

// MARK: - Package Structure Models

struct PackageStructure: Codable {
    let name: String
    let targets: [PackageTarget]
}

struct PackageTarget: Codable {
    let name: String
    let path: String
    let type: String
}

// MARK: - CLI Enums

enum AccessLevel: String, ExpressibleByArgument, CaseIterable {
    case `public`
    case `internal`
    case all
}

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case json
    case markdown
}

// MARK: - API Extraction Models

struct APIExtractionResult: Codable {
    let packageName: String
    let totalDeclarations: Int
    let declarations: [APIDeclaration]

    func toMarkdown() -> String {
        var output = "# API Reference: \(packageName)\n\n"
        output += "Total public declarations: \(totalDeclarations)\n\n"

        // Group by file
        let grouped = Dictionary(grouping: declarations) { $0.location.file }

        for (file, decls) in grouped.sorted(by: { $0.key < $1.key }) {
            output += "## \(file)\n\n"
            for decl in decls.sorted(by: { $0.location.line < $1.location.line }) {
                output += "### \(decl.name) (\(decl.kind))\n\n"
                output += "**Location:** `\(file):\(decl.location.line)`\n\n"
                output += "**Access:** `\(decl.accessLevel)`\n\n"
                if let doc = decl.documentation {
                    output += "**Documentation:**\n\n\(doc)\n\n"
                }
                output += "**Signature:**\n\n```swift\n\(decl.signature)\n```\n\n"
                output += "---\n\n"
            }
        }

        return output
    }
}

struct APIDeclaration: Codable {
    let name: String
    let kind: String  // function, struct, class, protocol, enum, property, typealias
    let accessLevel: String
    let signature: String
    let documentation: String?
    let location: SourceLocation
}

struct SourceLocation: Codable {
    let file: String
    let line: Int
    let column: Int
}
