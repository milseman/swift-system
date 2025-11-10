import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - APIExtractor

class APIExtractor {
    let accessLevel: AccessLevel

    init(accessLevel: AccessLevel) {
        self.accessLevel = accessLevel
    }

    func extract(target: PackageTarget) throws -> [APIDeclaration] {
        var allDeclarations: [APIDeclaration] = []

        // Find all .swift files in target path
        let swiftFiles = try findSwiftFiles(in: target.path)

        for file in swiftFiles {
            let declarations = try extractFromFile(file)
            allDeclarations.append(contentsOf: declarations)
        }

        return allDeclarations
    }

    private func findSwiftFiles(in path: String) throws -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []

        let fullPath = URL(fileURLWithPath: path)

        guard let enumerator = fileManager.enumerator(
            at: fullPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL.path)
            }
        }

        return swiftFiles
    }

    private func extractFromFile(_ filePath: String) throws -> [APIDeclaration] {
        let contents = try String(contentsOfFile: filePath, encoding: .utf8)
        let sourceFile = Parser.parse(source: contents)

        let visitor = APIVisitor(filePath: filePath, accessLevel: accessLevel)
        visitor.walk(sourceFile)

        return visitor.declarations
    }
}

// MARK: - APIVisitor

class APIVisitor: SyntaxVisitor {
    let filePath: String
    let accessLevel: AccessLevel
    var declarations: [APIDeclaration] = []

    private lazy var converter: SourceLocationConverter = {
        let contents = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
        return SourceLocationConverter(fileName: filePath, tree: Parser.parse(source: contents))
    }()

    init(filePath: String, accessLevel: AccessLevel) {
        self.filePath = filePath
        self.accessLevel = accessLevel
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Visit Methods

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "function",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "struct",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "class",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "protocol",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "enum",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            let location = getSourceLocation(for: node)
            let documentation = extractDocComment(from: node.leadingTrivia)
            let signature = node.trimmedDescription

            declarations.append(APIDeclaration(
                name: node.name.text,
                kind: "typealias",
                accessLevel: extractAccessLevel(from: node.modifiers),
                signature: signature,
                documentation: documentation,
                location: location
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if shouldInclude(modifiers: node.modifiers) {
            // Extract variable names from bindings
            for binding in node.bindings {
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                    let location = getSourceLocation(for: node)
                    let documentation = extractDocComment(from: node.leadingTrivia)
                    let signature = node.trimmedDescription

                    declarations.append(APIDeclaration(
                        name: pattern.identifier.text,
                        kind: "property",
                        accessLevel: extractAccessLevel(from: node.modifiers),
                        signature: signature,
                        documentation: documentation,
                        location: location
                    ))
                }
            }
        }
        return .visitChildren
    }

    // MARK: - Helper Methods

    private func shouldInclude(modifiers: DeclModifierListSyntax?) -> Bool {
        let declAccessLevel = extractAccessLevel(from: modifiers)

        switch accessLevel {
        case .public:
            return declAccessLevel == "public"
        case .internal:
            return declAccessLevel == "public" || declAccessLevel == "internal"
        case .all:
            return true
        }
    }

    private func extractAccessLevel(from modifiers: DeclModifierListSyntax?) -> String {
        guard let modifiers = modifiers else {
            return "internal"
        }

        for modifier in modifiers {
            let name = modifier.name.text
            if name == "public" || name == "open" {
                return "public"
            } else if name == "private" || name == "fileprivate" {
                return "private"
            } else if name == "internal" {
                return "internal"
            }
        }

        return "internal"
    }

    private func extractDocComment(from trivia: Trivia?) -> String? {
        guard let trivia = trivia else {
            return nil
        }

        var docLines: [String] = []

        for piece in trivia {
            switch piece {
            case .docLineComment(let text):
                // Remove "///" prefix
                let cleaned = text.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^///", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                docLines.append(cleaned)
            case .docBlockComment(let text):
                // Remove "/**" and "*/" delimiters and leading asterisks
                let cleaned = text
                    .replacingOccurrences(of: "^/\\*\\*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\*/$", with: "", options: .regularExpression)
                    .split(separator: "\n")
                    .map { line in
                        line.trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "^\\*", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespaces)
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespaces)
                docLines.append(cleaned)
            default:
                continue
            }
        }

        if docLines.isEmpty {
            return nil
        }

        return docLines.joined(separator: "\n")
    }

    private func getSourceLocation(for node: some SyntaxProtocol) -> SourceLocation {
        let location = node.startLocation(converter: converter)
        return SourceLocation(
            file: filePath,
            line: location.line ?? 0,
            column: location.column ?? 0
        )
    }
}
