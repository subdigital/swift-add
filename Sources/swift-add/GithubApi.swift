import Foundation

struct TagRef: Decodable {
    let ref: String
    var tag: String? {
        ref.split(separator: "/").last
        .flatMap(String.init)
    }
}

enum GithubApi {
    static func fetchTags(repo: String) async throws -> [String] {
        let url = URL(string: "https://api.github.com/repos/\(repo)/git/refs/tags")!
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
        let http = response as! HTTPURLResponse
        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let tagRefs = try decoder.decode([TagRef].self, from: data)
            return tagRefs.compactMap(\.tag)
        default:
            print("HTTP \(http.statusCode) from \(url)")
        }
        return []
    }
}

