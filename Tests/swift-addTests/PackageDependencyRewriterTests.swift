import XCTest
import SwiftSyntax
import SwiftParser
import CustomDump
@testable import swift_add

final class PackageDependencyRewriterTests: XCTestCase {
    let package = PackageInfo(name: "Files", url: URL(string: "https://github.com/johnsundell/Files.git")!, versions: ["0.4.1"], products: [.library("Files")])
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
        let file = Parser.parse(source: packageSwiftWithNoTargets)
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
        XCTAssertNoDifference(expected, output)
    }

    func testInsertsDependenciesArrayIfNeeded() throws {
        let packageSwiftWithNoDeps = """
        import PackageDescription

        let package = Package(
            name: "DemoPackage"
        )
        """

       let file = Parser.parse(source: packageSwiftWithNoDeps)
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
       XCTAssertNoDifference(output, expected)
    }

    func testAddsDependencyToFirstTarget() throws {
        let packageSwift = packageSwiftWithTarget("""
                                                  .target(name: "dummy", dependencies: [
                                                              .product(name: "foo")
                                                          ])
                                                  """)
       let file = Parser.parse(source: packageSwift)
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
//        let file = try SyntaxParser.parse(source: packageSwift)
//        var output = ""
//        PackageDependencyRewriter(packageToAdd: package, products: [package.products.first!]).visit(file).write(to: &output)
//        let expected = """
//        import PackageDescription
//
//        let package = Package(
//            name: "DemoPackage",
//            dependencies: [
//                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
//                .package(name: "Files", url: "https://github.com/johnsundell/Files.git", from: "0.4.1")
//            ],
//            targets: [
//                .target(name: "dummy", dependencies: [
//                    .product(name: "Files", package: "Files")
//                ])
//            ])
//        """
//        XCTAssertEqual(output, expected)
        XCTFail()
    }

    func testDoesNotAddTheSamePackageDependencyTwice() throws {
//        let packageSwift = """
//            import PackageDescription
//
//            let package = Package(
//                name: "DemoPackage",
//                dependencies: [
//                    .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
//                ]
//            )
//            """
//        let file = try SyntaxParser.parse(source: packageSwift)
//        var output = ""
//        let samePackage = PackageInfo(name: "swift-argument-parser", url: URL(string: "https://github.com/apple/swift-argument-parser.git")!, version: "0.4.3", products: [])
//        PackageDependencyRewriter(packageToAdd: samePackage, products: []).visit(file).write(to: &output)
//        let expected = packageSwift
//        XCTAssertEqual(output, expected)
        XCTFail()
    }

    func testReusesPackageReferenceWhenAddingModuleFromSamePackage() throws {
        let packageSwift = """
            import PackageDescription

            let package = Package(
                name: "DemoPackage",
                dependencies: [
                    .package(name: "PKG", url: "https://example.com/pkg", from: "0.1"),
                ],
                targets: [
                    .target(name: "MyTarget", dependencies: [
                        .product(name: "Mod1", package: "PKG")
                    ])
                ]
            )
            """
//        let file = try SyntaxParser.parse(source: packageSwift)
//        var output = ""
//        let samePackage = PackageInfo(name: "PKG", url: URL(string: "https://example.com/pkg")!, version: "0.1", products: [
//            .library("Mod1"),
//            .library("Mod2"),
//        ])
//        PackageDependencyRewriter(packageToAdd: samePackage, products: [
//            .library("Mod2")
//        ]).visit(file).write(to: &output)
//
//        let expected = packageSwift
//        XCTAssertEqual(output, expected)
        XCTFail()
    }
}
