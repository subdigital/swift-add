import ArgumentParser
import Foundation
import PackageModel
import SwiftSyntax

struct InvalidPackageURL: Error { }
struct PackageNotFound: Error { }

struct AddPackageCommand: AsyncParsableCommand {
    @Argument(help: "The package to add")
    var packageName: String

    @Option(help: "The branch to use")
    var branch: String = "main"

    @Flag(help: "Prints out what would be added to Package.swift without modifying it.")
    var dryRun = false

    mutating func runAsync() async throws {
        packageName = packageName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let packageInfo = try await loadPackageInfo() {
            try await addPackageToManifest(packageInfo)
            print("Added \(packageInfo.name) (\(packageInfo.version)) from \(packageInfo.url)")
        }
    }

    private func addPackageToManifest(_ package: PackageInfo) async throws {
        // assume for now the current directory is where our Package.swift file is
        let packageURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Package.swift")
        let file = try SyntaxParser.parse(packageURL)
        let modified = PackageDependencyRewriter(packageToAdd: package).visit(file)

        var modifiedContents = ""
        modified.write(to: &modifiedContents)

        if dryRun {
            print(modifiedContents)
        } else {
            let data = modifiedContents.data(using: .utf8)!
            try data.write(to: packageURL, options: .atomicWrite)
        }
    }

    private func loadPackageInfo() async throws -> PackageInfo? {
        if packageName.contains("/") {
            return try await fetchPackageFromGithub()
        } else {
            fatalError("use a repo/project format for now")
        }
    }

    private func fetchPackageFromGithub(branch: String = "main") async throws -> PackageInfo {
        // look for Package.swift in the root of the repo
        // https://raw.githubusercontent.com/JohnSundell/Files/master/Package.swift
        guard let url = URL(string: "https://raw.githubusercontent.com/\(packageName)/\(branch)/Package.swift") else {
            throw InvalidPackageURL()
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        if http.statusCode != 200 {
            if branch == "main" {
                // try again with master branch
                return try await fetchPackageFromGithub(branch: "master")
            } else {
                throw PackageNotFound()
            }
        }

        let contents = String(data: data, encoding: .utf8)!
        async let dump = try PackageDump.parse(packageContents: contents)
        async let repo = try GithubApi.fetchRepo(repo: packageName)
        async let tags = try GithubApi.fetchTags(repo: packageName)
        let products: [ProductInfo] = try await dump.products.map { product in
            switch product.type {
            case "library": return .library(product.name)
            default:
                fatalError("Unhandled product type: \(product.type)")
            }
        }

        return try await PackageInfo(name: dump.name,
                           url: repo.htmlUrl,
                           version: tags.last!,
                           products: products)
    }
}

