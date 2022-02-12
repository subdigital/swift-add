import Foundation

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
