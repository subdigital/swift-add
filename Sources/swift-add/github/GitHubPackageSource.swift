import Foundation

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
            versions: tags,
            products: .extract(from: packageDump)
        )
    }
}
