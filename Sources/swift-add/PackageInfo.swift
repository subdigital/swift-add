import Foundation

struct PackageInfo {
    let name: String
    let url: URL
    let versions: [String]
    let products: [ProductInfo]
}

enum ProductInfo: Equatable {
    case library(String)
    case executable(String)

    var name: String {
        switch self {
        case .library(let name), .executable(let name): return name
        }
    }
}

extension Array where Element == ProductInfo {
    static func extract(from dump: PackageDump) -> Self {
        dump.products.map { product in
            switch product.type {
            case "library": return .library(product.name)
            case "executable": return .executable(product.name)
            default:
                fatalError("Unhandled product type: \(product.type)")
            }
        }
    }
}
