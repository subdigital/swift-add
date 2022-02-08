import Foundation

struct TagRef: Decodable {
    let ref: String
    var tag: String? {
        ref.split(separator: "/").last
        .flatMap(String.init)
    }
}

struct Repo: Decodable {
    let name: String
    let fullName: String
    let url: URL
    let htmlUrl: URL
}

enum GithubApi {
    enum Errors: Swift.Error {
        case requestFailed
    }

    static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func fetchRepo(repo: String) async throws -> Repo {
        let data = try await get(path: "repos/\(repo)")
        return try jsonDecoder.decode(Repo.self, from: data)
    }

    static func fetchTags(repo: String) async throws -> [String] {
        let data = try await get(path: "repos/\(repo)/git/refs/tags")
        let tagRefs = try jsonDecoder.decode([TagRef].self, from: data)
        return tagRefs.compactMap(\.tag)
    }

    private static func get(path: String) async throws -> Data {
        let url = URL(string: "https://api.github.com/\(path)")!
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
        let http = response as! HTTPURLResponse
        switch http.statusCode {
        case 200:
            return data
        default:
            print("HTTP \(http.statusCode) from \(url)")
            throw Errors.requestFailed
        }
    }
}

