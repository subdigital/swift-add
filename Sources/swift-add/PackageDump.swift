import Foundation

struct DumpPackageError: Error {
    let error: String
}

/// Provides strongly typed representation from the `swift package dump-package` command
struct PackageDump: Decodable {
    let name: String
    let products: [Product]

    struct Product: Decodable {
        let name: String
        let type: String

        enum CodingKeys: String, CodingKey {
            case name
            case type
        }

        struct DynamicKeys: CodingKey {
            var stringValue: String
            var intValue: Int?

            init?(intValue: Int) {
                self.intValue = intValue
                stringValue = String(intValue)
            }

            init?(stringValue: String) {
                self.stringValue = stringValue
            }
        }

        init(name: String, type: String) {
            self.name = name
            self.type = type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)

            let typeContainer = try container.nestedContainer(keyedBy: DynamicKeys.self, forKey: .type)
            type = typeContainer.allKeys.first!.stringValue
        }
    }
}

extension PackageDump {
    static func parse(packageContents: String) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let dumpData = try dumpPackage(packageContents: packageContents)
                let dump = try JSONDecoder().decode(PackageDump.self, from: dumpData)
                continuation.resume(returning: dump)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func dumpPackage(packageContents: String) throws -> Data {
        try withTempDirectory { dir in
            let packageFileURL = URL(fileURLWithPath: dir).appendingPathComponent("Package.swift")
            try packageContents.data(using: .utf8)!.write(to: packageFileURL)

            let pipeQueue = DispatchQueue(label: "pipe-read-queue")
            var stdOutData = Data()
            let stdOut = Pipe { handler in
                pipeQueue.async { stdOutData.append(handler.availableData) }
            }
            var stdErrData = Data()
            let stdErr = Pipe { handler in
                pipeQueue.async { stdErrData.append(handler.availableData) }
            }
            let process = createSwiftDumpPackageProcess(path: dir, stdOut: stdOut, stdErr: stdErr)

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // timeout after a bit
                if process.isRunning {
                    print("Timeout. Attempting to terminate process...")
                    process.terminate()
                }
            }

            try process.run()
            process.waitUntilExit()

            switch process.terminationStatus {
            case 0:
                if stdOutData.isEmpty {
                    let error = String(data: stdErrData, encoding: .utf8) ?? ""
                    fatalError(error)
                }
                return stdOutData
            default:
                let error = String(data: stdErrData, encoding: .utf8) ?? ""
                throw DumpPackageError(error: error)
            }
        }
    }

    private static func createSwiftDumpPackageProcess(path: String, stdOut: Pipe, stdErr: Pipe) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["package", "dump-package"]
        process.currentDirectoryPath = path
        process.standardOutput = stdOut
        process.standardError = stdErr
        return process
    }
}
