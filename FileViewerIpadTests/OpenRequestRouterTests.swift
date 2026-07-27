import Foundation
import XCTest
@testable import FileViewerIpad

final class OpenRequestRouterTests: XCTestCase {
    func testSuppressesDuplicateDeliveryWithinWindow() async {
        let router = OpenRequestRouter(suppressionInterval: 2)
        let url = URL(fileURLWithPath: "/tmp/Document.md")
        let start = Date(timeIntervalSince1970: 1_000)

        let firstClaim = await router.claim(url, now: start)
        let duplicateClaim = await router.claim(
            url,
            now: start.addingTimeInterval(1)
        )
        let laterClaim = await router.claim(
            url,
            now: start.addingTimeInterval(3)
        )

        XCTAssertTrue(firstClaim)
        XCTAssertFalse(duplicateClaim)
        XCTAssertTrue(laterClaim)
    }
}
