import XCTest
import SwiftSyntax
@testable import swift_add

final class PackageDependencyRewriterTests: XCTestCase {
    let package = PackageInfo(name: "Files", url: URL(string: "https://github.com/johnsundell/Files.git")!, version: "0.4.1")
    let packageSwiftWithNoTargets = """
    import PackageDescription

    let package = Package(
        name: "DemoPackage",
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
        ]
    )
    """

    /*
      .target(name: "dummy"),
      .target(name: "dummy2", dependencies: []),
      .target(name: "dummy3", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    */

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
            ]),
        )
        """
    }

    func testAddsPackage() throws {
        let file = try SyntaxParser.parse(source: packageSwiftWithNoTargets)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
                .package(url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ]
        )
        """
        XCTAssertEqual(output, expected)
    }

    func testAddsDependencyToFirstTarget() throws {
        let packageSwift = packageSwiftWithTarget("""
                                                  .target(name: "dummy", dependencies: [
                                                              .product(name: "foo")
                                                          ]
                                                  """)
        let file = try SyntaxParser.parse(source: packageSwift)
        var output = ""
        PackageDependencyRewriter(packageToAdd: package).visit(file).write(to: &output)
        let expected = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
                .package(url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
            ],
            .targets: [
                .target(name: "dummy", dependencies: [
                    .product(name: "foo"),
                    .product(name: "Files", package: "Files")
                ]
            ]
        )
        """
        XCTAssertEqual(output, expected)
    }

}
