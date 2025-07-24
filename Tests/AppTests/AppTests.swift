@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    func testApplicationStartup() async throws {
        let app = try await Application.make(.testing)
        XCTAssertEqual(app.environment, .testing)
        try await app.asyncShutdown()
    }
}
