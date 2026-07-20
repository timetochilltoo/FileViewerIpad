import XCTest

final class FileViewerIpadUITests: XCTestCase {
    @MainActor
    func testLaunchShowsEmptyWorkspace() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["No Document Open"].waitForExistence(timeout: 5))
    }
}
