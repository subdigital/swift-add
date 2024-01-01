import Foundation

protocol PackageSource {
    // construct?
    func assemblePackage() async throws -> PackageInfo
}

extension PackageSource {
    func fetchPackageManifest(url: URL) async throws -> PackageDump {
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        if http.statusCode != 200 {
            throw PackageNotFound()
        }

        let contents = String(data: data, encoding: .utf8)!
        return try await PackageDump.parse(packageContents: contents)
    }
}

