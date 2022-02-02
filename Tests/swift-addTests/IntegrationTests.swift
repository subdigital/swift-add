import XCTest
import class Foundation.Bundle
@testable import swift_add

final class IntegrationTests: XCTestCase {

    struct Output {
        let stdOut: String?
        let stdErr: String?
        let exitCode: Int32

        var wasSuccessful: Bool {
            exitCode == 0
        }
    }

    func runCommand(args: String) throws -> Output {
        let executable = productsDirectory.appendingPathComponent("swift-add")

        let process = Process()
        process.executableURL = executable
        process.arguments = args.split(separator: " ").map(String.init)

        let out = PipeToString()
        let err = PipeToString()
        process.standardOutput = out.pipe
        process.standardError = err.pipe

        print("> \(process.executableURL!.lastPathComponent) \((process.arguments ?? []).joined(separator: " "))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            print("TIMEOUT. Terminating.")
            if process.isRunning {
                process.terminate()
            }
        }
        try process.run()
        process.waitUntilExit()

        return Output(stdOut: out.string, stdErr: err.string, exitCode: process.terminationStatus)
    }

    func testWithoutArgs_printsHelp() throws {
        let output = try runCommand(args: "")
        let stdErr = try XCTUnwrap(output.stdErr);
        XCTAssertContains(stdErr, "Missing expected argument '<package-name>'")
    }

    func testWithGithubPackage() throws {
        let output = try runCommand(args: "johnsundell/files")
        if output.wasSuccessful {
            XCTAssertEqual(
                output.stdOut!.trimmingCharacters(in: .whitespacesAndNewlines),
                "Added Files (4.2.0) from https://github.com/johnsundell/files")
        } else {
            let error = output.stdErr ?? "?"
            XCTFail("Command failed: \n\n\(error)\n\n")
        }
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }
}

func XCTAssertContains(_ input: String, _ substring: String, file: StaticString = #file, line: UInt = #line) {
    if !input.contains(substring) {
        XCTFail("Expected the string:\n\(input)\nto contain substring:\n\(substring)", file: file, line: line)
    }
}
