// swift-tools-version:5.5

import PackageDescription

// Download the lib_InternalSwiftSyntaxParser.dylib as a binary target
// which is a requirement of SwiftSyntax
let syntaxLib = (
    url: "https://github.com/ahoppen/swift-syntax/releases/download/ahoppen-0.50500.2/_InternalSwiftSyntaxParser.xcframework.zip",
    checksum: "f1326cfbaee9924ba925c33a3c85fd326cdc2771f68c23653b7cd8d520d0afd4"
)

let package = Package(
    name: "swift-add",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
        .package(name: "SwiftSyntax", url: "https://github.com/apple/swift-syntax.git", .exact("0.50500.0")),
        .package(
            name: "SwiftPM",
            url: "https://github.com/apple/swift-package-manager.git",
            branch: "release/5.5"),
    ],
    targets: [
        .executableTarget(
            name: "swift-add",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftPMDataModel-auto", package: "SwiftPM"),
                .product(name: "SwiftSyntax", package: "SwiftSyntax"),
                .target(name: "_InternalSwiftSyntaxParser"),
            ]),
        .binaryTarget(name: "_InternalSwiftSyntaxParser", url: syntaxLib.url, checksum: syntaxLib.checksum),
        .testTarget(
            name: "swift-addTests",
            dependencies: ["swift-add"],
            exclude: [
                "SamplePackage/"
            ],
            resources: [
                .copy("SamplePackage/Package.swift.starter")
            ])
    ]
)
