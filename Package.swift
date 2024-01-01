// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "swift-add",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(name: "SwiftSyntax", url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(
            name: "SwiftPM",
            url: "https://github.com/apple/swift-package-manager.git",
            branch: "release/5.9"),
        .package(name: "Rainbow", url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
        .package(name: "Difference", url: "https://github.com/krzysztofzablocki/Difference.git", from: "1.0.2"),
        .package(name: "CustomDump", url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.1.2")
    ],
    targets: [
        .executableTarget(
            name: "swift-add",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftPMDataModel-auto", package: "SwiftPM"),
                .product(name: "SwiftParser", package: "SwiftSyntax"),
                .product(name: "SwiftSyntax", package: "SwiftSyntax"),
                .product(name: "SwiftSyntaxBuilder", package: "SwiftSyntax"),
                .product(name: "Rainbow", package: "Rainbow"),
            ]),
        .testTarget(
            name: "swift-addTests",
            dependencies: [
                "swift-add",
                "Difference",
                "CustomDump"
            ],
            exclude: [
                "SamplePackage/"
            ],
            resources: [
                .copy("SamplePackage/Package.swift.starter")
            ]
        )
    ]
)
