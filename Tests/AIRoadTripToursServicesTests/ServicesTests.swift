import Testing
@testable import AIRoadTripToursServices

@Suite("Services Module", .tags(.small))
struct ServicesTests {
    @Test("Services module exists")
    func testModuleExists() async throws {
        // Placeholder test for services module
        #expect(true)
    }
}

extension Tag {
    @Tag static var small: Self
}
