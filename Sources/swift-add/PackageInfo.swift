import Foundation

struct PackageInfo {
    let name: String
    let url: URL
    let version: String
    let products: [ProductInfo]
}

enum ProductInfo {
    case library(String)

    var name: String {
        switch self {
        case .library(let name): return name
        }
    }
}
