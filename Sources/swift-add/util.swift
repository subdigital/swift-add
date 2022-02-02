import Foundation

func withTempDirectory<T>(_ block: @escaping (String) throws -> T) throws -> T {
    let id = UUID().uuidString
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("swift-add-\(id)").path
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: dir) }
    do {
        let result = try block(dir)
        return result
    } catch {
        throw error
    }
}
