import Foundation

/// Creates a temporary directory, yielding the name of the directory to the provided block. Once the
/// block terminates, the directory is removed.
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
