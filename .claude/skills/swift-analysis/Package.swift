// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAnalysis",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftAnalysis"
        ),
        .executableTarget(
            name: "SwiftAnalysisTool",
            dependencies: [
                "SwiftAnalysis",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
