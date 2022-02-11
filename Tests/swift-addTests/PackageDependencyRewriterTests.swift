import XCTest
import SwiftSyntax
@testable import swift_add

final class PackageDependencyRewriterTests: XCTestCase {
    let package = PackageInfo(name: "Files", url: URL(string: "https://github.com/johnsundell/Files.git")!, version: "0.4.1", products: [.library("Files")])
    let packageSwiftWithNoTargets = """
    import PackageDescription

    let package = Package(
        name: "DemoPackage",
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
        ]
    )
    """

    func packageSwiftWithTarget(_ targetString: String) -> String {
        """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
            ],
            targets: [
                \(targetString)
            ])
        """
    }

    func testAddsPackage() throws {
        let file = try SyntaxParser.parse(source: packageSwiftWithNoTargets)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package, products: [package.products.first!]).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
                .package(name: "Files", url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ]
        )
        """
        XCTAssertEqual(output, expected)
    }

    func testInsertsDependenciesArrayIfNeeded() throws {
        let packageSwiftWithNoDeps = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage"
        )
        """
        let file = try SyntaxParser.parse(source: packageSwiftWithNoDeps)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package, products: [package.products.first!]).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(name: "Files", url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ]
        )
        """
        XCTAssertEqual(output, expected)
    }

    func testAddsDependencyToFirstTarget() throws {
        let packageSwift = packageSwiftWithTarget("""
                                                  .target(name: "dummy", dependencies: [
                                                              .product(name: "foo")
                                                          ])
                                                  """)
        let file = try SyntaxParser.parse(source: packageSwift)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package, products: [package.products.first!]).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
                .package(name: "Files", url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ],
            targets: [
                .target(name: "dummy", dependencies: [
                    .product(name: "foo"),
                    .product(name: "Files", package: "Files")
                ])
            ])
        """
        XCTAssertEqual(output, expected)
    }

    func testAddsDependencyToFirstTargetWithInlineEmptyArray() throws {
        let packageSwift = packageSwiftWithTarget("""
                                                  .target(name: "dummy", dependencies: [])
                                                  """)
        let file = try SyntaxParser.parse(source: packageSwift)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package, products: [package.products.first!]).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
                .package(name: "Files", url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ],
            targets: [
                .target(name: "dummy", dependencies: [
                    .product(name: "Files", package: "Files")
                ])
            ])
        """
        XCTAssertEqual(output, expected)
    }

}
