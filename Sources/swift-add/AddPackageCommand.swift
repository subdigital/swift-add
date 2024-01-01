import ArgumentParser
import Foundation
import PackageModel
import SwiftParser
import SwiftSyntax
import SwiftParser
import Rainbow

struct AddPackageCommand: AsyncParsableCommand {
    @Argument(help: "The package to add")
    var packageName: String

    @Option(help: "The branch to use")
    var branch: String = "main"

    @Option(name: .shortAndLong, help: "The product(s) to integrate into your main target. This can be inferred for packages that have only 1 target. To find out which targets and versions a package contains, run `swift add --info <package>`")
    var products: [String] = []

    @Option(name: .shortAndLong, help: "The version to include. Defaults to the latest version.")
    var version: String?

    @Flag(help: "Prints out what would be added to Package.swift without modifying it.")
    var dryRun = false

    @Flag(help: "info")
    var info = false

    mutating func runAsync() async throws {
        packageName = packageName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let packageInfo = try await loadPackageInfo() {
            if info {
                printPackageInfo(packageInfo)
                return
            }
            try validateSelectedProducts(packageInfo: packageInfo)
            let descriptor = try getPackageDescriptor(packageInfo: packageInfo)
            try await addPackageToManifest(packageInfo, descriptor: descriptor)
            print("Added \(packageInfo.name) (\(descriptor)) from \(packageInfo.url)")
        }
    }

    private func printPackageInfo(_ package: PackageInfo) {
        print("")
        print("    Name: ".lightBlack, package.name.lightBlue)
        print("     URL: ".lightBlack, package.url.absoluteString.white)
        print("Products: ".lightBlack, package.products.map({ $0.name }).joined(separator: ", "))
        print("Versions: ".lightBlack, package.versions.reversed().joined(separator: ", "))
        print("")
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

    private func getPackageDescriptor(packageInfo: PackageInfo) throws -> PackageDescriptor {
        if let version {
            // make sure it exists in the package info
            if !packageInfo.versions.contains(version) {
                throw InvalidVersion(version: version, packageInfo: packageInfo)
            }
            return .version(version)
        } else if let latestVersion = packageInfo.versions.last {
            return .version(latestVersion)
        } else {
            // leave at inferred git branch type
            return .inferredGitRepo(packageName: packageName, branch: branch)
        }
    }

    private func addPackageToManifest(_ package: PackageInfo, descriptor: PackageDescriptor) async throws {
        // assume for now the current directory is where our Package.swift file is
        let packageURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Package.swift")
        let fileContents = String(decoding: try Data(contentsOf: packageURL), as: UTF8.self)

        let sourceFile = Parser.parse(source: fileContents)
        let productInfos = package.products.filter { p in
            products.map { $0.lowercased() }.contains(p.name.lowercased())
        }
        let rewriter = PackageDependencyRewriter(packageToAdd: package, products: productInfos)
        let modified = rewriter.visit(sourceFile)

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

    private func fetchPackageFromGithub() async throws -> PackageInfo {
        let source = try await GithubPackageSource(shortRepo: packageName)
        return try await source.assemblePackage()
    }
}

