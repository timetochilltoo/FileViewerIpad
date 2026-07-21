import XCTest

@MainActor
final class FileViewerIpadUITests: XCTestCase {
    @MainActor
    func testLaunchShowsEmptyWorkspace() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["No Document Open"].waitForExistence(timeout: 5))
    }

    func testInjectedMarkdownDocumentRenders() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-markdown")
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Phase 1 Test Document"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Open Document"].exists)
    }

    func testInjectedPDFDocumentRendersWithNavigation() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-pdf")
        app.launch()

        XCTAssertTrue(app.buttons["Next Page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Zoom In"].exists)
    }
}
