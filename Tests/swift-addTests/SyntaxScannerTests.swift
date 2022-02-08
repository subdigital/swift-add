import XCTest
import SwiftSyntax
@testable import swift_add

final class SyntaxScannerTests: XCTestCase {
    let package = PackageInfo(name: "Files",
                              url: URL(string: "https://github.com/johnsundell/Files.git")!,
                              version: "0.4.1",
                              products: [.library("Files")])
    let packageSwift = """
    import PackageDescription

    let package = Package(
        name: "DemoPackage",
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.3"),
        ]
    )
    """

    func testScanForPatternReturnsNextToken() throws {
        let file = try SyntaxParser.parse(source: packageSwift)
        let scanner = SyntaxScanner(file: file)
        let pattern: [TokenKind] = [
            .letKeyword,
            .identifier("package"),
            .equal,
            .identifier("Package")
        ]
        let start = try XCTUnwrap(file.firstToken)
        let token = scanner.scanForPattern(start: start, pattern: pattern)
        let nextToken = try XCTUnwrap(token)
        XCTAssertEqual(nextToken.tokenKind, TokenKind.leftParen)
    }

    func testScanUntil() throws {
        let file = try SyntaxParser.parse(source: """
                                          func hello(x: Int, y: Bool) {
                                            let z = 5
                                          }
                                          """)
        let scanner = SyntaxScanner(file: file)
        let token = try XCTUnwrap(scanner.scanUntil(kind: .leftParen))
        XCTAssertEqual(token.tokenKind, .leftParen)
    }


    func testTokensInScopeReturnsScope() throws {
        let file = try SyntaxParser.parse(source: """
                                          func hello(x: Int, y: Bool) {
                                            let z = 5
                                          }
                                          """)
        let scanner = SyntaxScanner(file: file)
        let token = try XCTUnwrap(scanner.scanUntil(kind: .leftParen))
        let tokens = scanner.tokensInScope(token: token)
        XCTAssertEqual(tokens.map(\.tokenKind),
                       [
                           .identifier("x"), .colon, .identifier("Int"),
                           .comma,
                           .identifier("y"), .colon, .identifier("Bool"),
                       ]
        )
    }

    func testTokensInScopeReturnsNestedScopes() throws {
        let file = try SyntaxParser.parse(source: """
                                          let post = Post(title: "hi", permissions: (true, false), tags: ["food"])
                                          """)
        let scanner = SyntaxScanner(file: file)
        let token = try XCTUnwrap(scanner.scanUntil(kind: .leftParen))
        let tokens = scanner.tokensInScope(token: token)

        let expected: [TokenKind] = [
                           .identifier("title"), .colon, .stringQuote, .stringSegment("hi"), .stringQuote,
                           .comma,
                           .identifier("permissions"), .colon, .leftParen, .trueKeyword, .comma, .falseKeyword, .rightParen,
                           .comma,
                           .identifier("tags"), .colon, .leftSquareBracket, .stringQuote, .stringSegment("food"), .stringQuote, .rightSquareBracket
                       ]

        XCTAssertEqual(tokens.map(\.tokenKind), expected)
    }
}

