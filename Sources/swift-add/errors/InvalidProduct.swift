import Foundation

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
