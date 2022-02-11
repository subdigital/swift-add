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

struct GithubPackageSource: PackageSource {
    let packageURL: URL
    let repo: Github.Repo

    init(shortRepo: String) async throws {
        self.repo = try await GithubApi.fetchRepo(repo: shortRepo)
        let branch = repo.defaultBranch

        // look for Package.swift in the root of the repo
        // https://raw.githubusercontent.com/JohnSundell/Files/master/Package.swift
        guard let url = URL(string: "https://raw.githubusercontent.com/\(shortRepo)/\(branch)/Package.swift") else {
            throw InvalidPackageURL()
        }
        packageURL = url
    }

    func assemblePackage() async throws -> PackageInfo {
        async let packageDump = try await fetchPackageManifest(url: packageURL)
        async let tags = try await GithubApi.fetchTags(repo: repo.fullName)
        return try await PackageInfo(
            name: packageDump.name,
            url: repo.htmlUrl,
            version: tags.last!,
            products: .extract(from: packageDump)
        )
    }
}
