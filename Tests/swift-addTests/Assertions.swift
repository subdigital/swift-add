import XCTest

func XCTAssertContains(_ input: String, _ substring: String, file: StaticString = #file, line: UInt = #line) {
    if !input.contains(substring) {
        XCTFail("Expected the string:\n\(input)\nto contain substring:\n\(substring)", file: file, line: line)
    }
}
