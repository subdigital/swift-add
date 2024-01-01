import Foundation

struct InvalidVersion: Error, LocalizedError {
    let version: String
    let packageInfo: PackageInfo
    init(version: String, packageInfo: PackageInfo) {
        self.version = version
        self.packageInfo = packageInfo
    }

    var errorDescription: String? {
        """
        The version '\(version)' is not provided by the package \(packageInfo.name).

        Valid versions:
        - \(packageInfo.versions.joined(separator: "\n- "))
        """
    }
}
