import XCTest
@testable import swift_add

final class PackageInfoTests: XCTestCase {
    func testExtractsProductsFromPackageDump() throws {
        let dump = PackageDump(name: "TestPackage", products: [
            .init(name: "TestLibrary", type: "library"),
            .init(name: "TestExecutable", type: "executable"),
        ])

        var products = [ProductInfo].extract(from: dump)
        XCTAssertEqual(products.count, 2)

        XCTAssertEqual(products.removeFirst(), .library("TestLibrary"))
        XCTAssertEqual(products.removeFirst(), .executable("TestExecutable"))
    }
}
