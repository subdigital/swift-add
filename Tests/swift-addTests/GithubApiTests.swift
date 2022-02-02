import XCTest
@testable import swift_add

final class GithubApiTests: XCTestCase {
    func testFetchesTags() async throws {
        let tags = try await GithubApi.fetchTags(repo: "johnsundell/files")
        XCTAssert(tags.contains("4.2.0"))
    }
}
