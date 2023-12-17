// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "swift-add",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(name: "SwiftSyntax", url: "https://github.com/apple/swift-syntax.git", .branch("main")),
        .package(
            name: "SwiftPM",
            url: "https://github.com/apple/swift-package-manager.git",
            branch: "release/5.7"),
    ],
    targets: [
        .executableTarget(
            name: "swift-add",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftPMDataModel-auto", package: "SwiftPM"),
                .product(name: "SwiftSyntax", package: "SwiftSyntax"),
                .product(name: "SwiftSyntaxParser", package: "SwiftSyntax"),
            ]),
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
