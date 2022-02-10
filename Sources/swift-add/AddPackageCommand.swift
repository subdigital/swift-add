import ArgumentParser
import Foundation
import PackageModel
import SwiftSyntax

struct InvalidPackageURL: Error { }
struct PackageNotFound: Error { }
struct MultipleProductsError: Error, LocalizedError {
    let packageInfo: PackageInfo
    init(packageInfo: PackageInfo) {
        self.packageInfo = packageInfo
    }

    var errorDescription: String? {
        """
        The package \(packageInfo.name) contains multiple products.
        Choose which one(s) to integrate into your target with the `-p` flag.

        Products in this package:
        - \(packageInfo.products.map(\.name).joined(separator: "\n- "))

        Example:

        swift add <package> -p \(packageInfo.products.first!.name)

        """
    }
}
struct InvalidProduct: Error, LocalizedError {
    let product: String
    let packageInfo: PackageInfo
    init(product: String, packageInfo: PackageInfo) {
        self.product = product
        self.packageInfo = packageInfo
    }

    var errorDescription: String? {
        """
        The product '\(product)' is not provided by the package \(packageInfo.name).

        Valid products:
        - \(packageInfo.products.map(\.name).joined(separator: "\n- "))
        """
    }
}

struct AddPackageCommand: AsyncParsableCommand {
    @Argument(help: "The package to add")
    var packageName: String

    @Option(help: "The branch to use")
    var branch: String = "main"

    @Option(name: .shortAndLong, help: "The product(s) to integrate into your main target")
    var products: [String] = []

    @Flag(help: "Prints out what would be added to Package.swift without modifying it.")
    var dryRun = false

    mutating func runAsync() async throws {
        packageName = packageName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let packageInfo = try await loadPackageInfo() {
            try validateSelectedProducts(packageInfo: packageInfo)
            try await addPackageToManifest(packageInfo)
            print("Added \(packageInfo.name) (\(packageInfo.version)) from \(packageInfo.url)")
        }
    }

    private mutating func validateSelectedProducts(packageInfo: PackageInfo) throws {
        if products.isEmpty {
            if packageInfo.products.count == 1 {
                // just assume first product
                products = [packageInfo.products.first!.name]
                return
            } else {
                throw MultipleProductsError(packageInfo: packageInfo)
            }
        }

        let packageProducts = packageInfo.products.map { $0.name.lowercased() }
        for product in products {
            guard packageProducts.contains(product.lowercased()) else {
                throw InvalidProduct(product: product, packageInfo: packageInfo)
            }
        }
    }

    private func addPackageToManifest(_ package: PackageInfo) async throws {
        // assume for now the current directory is where our Package.swift file is
        let packageURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Package.swift")
        let file = try SyntaxParser.parse(packageURL)
        let productInfos = package.products.filter { p in
            products.map { $0.lowercased() }.contains(p.name.lowercased())
        }
        let modified = PackageDependencyRewriter(packageToAdd: package, products: productInfos).visit(file)

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

