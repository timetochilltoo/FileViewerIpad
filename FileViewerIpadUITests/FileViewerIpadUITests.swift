import XCTest

@MainActor
final class FileViewerIpadUITests: XCTestCase {
    func testLaunchShowsEmptyWorkspace() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["No Document Open"].waitForExistence(timeout: 5))
    }

    func testInjectedMarkdownDocumentRenders() {
        let app = makeApp(arguments: ["--ui-test-markdown"])
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Phase 1 Test Document"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Open Document"].exists)

        let windowActions = app.buttons["window-actions"]
        XCTAssertTrue(windowActions.exists)
        windowActions.tap()
        XCTAssertTrue(app.buttons["New Window"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Open in New Window"].exists)
    }

    func testInjectedPDFDocumentRendersWithNavigation() {
        let app = makeApp(arguments: ["--ui-test-pdf"])
        app.launch()

        XCTAssertTrue(app.buttons["Next Page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Zoom In"].exists)
        let navigatorButton = app.buttons["PDF Navigator"]
        XCTAssertTrue(navigatorButton.exists)

        navigatorButton.tap()

        XCTAssertTrue(app.staticTexts["Page 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Outline"].exists)
    }

    func testMarkdownSearchNavigatesCaseInsensitiveMatches() {
        let app = makeApp(arguments: ["--ui-test-markdown"])
        app.launch()

        let searchField = searchField(in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("needle")

        let status = app.staticTexts["search-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("1 of 2"))
        app.buttons["search-next"].tap()
        XCTAssertTrue(waitForLabel("2 of 2", on: status))
        app.buttons["search-previous"].tap()
        XCTAssertTrue(waitForLabel("1 of 2", on: status))
    }

    func testPDFSearchClearsWithoutMovingFromSecondPage() {
        let app = makeApp(arguments: ["--ui-test-pdf"])
        app.launch()

        app.buttons["Next Page"].tap()
        let pageIndicator = app.staticTexts["pdf-page-indicator"]
        XCTAssertTrue(waitForLabelContaining("2", on: pageIndicator))

        let searchField = searchField(in: app)
        searchField.tap()
        searchField.typeText("token")
        XCTAssertTrue(
            app.staticTexts["search-status"].waitForExistence(timeout: 5)
        )
        searchField.buttons["Clear text"].tap()

        XCTAssertTrue(waitForLabelContaining("2", on: pageIndicator))
    }

    func testCompactAccessibilityLayoutKeepsPrimaryPDFControlsReachable() {
        let app = makeApp(
            arguments: [
                "--ui-test-pdf",
                "--ui-test-compact-layout",
                "--ui-test-accessibility-text"
            ]
        )
        app.launch()

        XCTAssertTrue(app.buttons["Page Actions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Previous Page"].isHittable)
        XCTAssertTrue(app.buttons["Next Page"].isHittable)
        XCTAssertTrue(app.buttons["Page Actions"].isHittable)
        XCTAssertTrue(app.buttons["Zoom Actions"].isHittable)
        XCTAssertTrue(app.buttons["PDF Navigator"].isHittable)
        let compactSearch = app.buttons["compact-search"]
        XCTAssertTrue(compactSearch.isHittable)
        compactSearch.tap()
        let compactSearchField = app.textFields["compact-search-field"]
        XCTAssertTrue(compactSearchField.waitForExistence(timeout: 5))
        XCTAssertTrue(compactSearchField.isHittable)
    }

    func testLandscapePDFLayoutKeepsReaderActionsReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer {
            XCUIDevice.shared.orientation = .portrait
        }
        let app = makeApp(arguments: ["--ui-test-pdf"])
        app.launch()

        XCTAssertTrue(app.buttons["Next Page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next Page"].isHittable)
        XCTAssertTrue(app.buttons["Zoom In"].isHittable)
        XCTAssertTrue(app.buttons["PDF Navigator"].isHittable)
        XCTAssertTrue(app.searchFields["Search document"].isHittable)
    }

    func testSceneSessionRestoresAfterRelaunch() {
        let suiteName = makeSuiteName()
        let app = makeApp(
            arguments: ["--ui-test-session-seed"],
            suiteName: suiteName
        )
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Restored Session Document"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.staticTexts["session-persisted"]
                .waitForExistence(timeout: 5)
        )

        app.terminate()
        app.launchArguments = ["--ui-test-session-restore"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Restored Session Document"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["SessionRestoration.md"].exists)
    }

    func testStaleSessionDocumentIsSkippedWithRecoveryMessage() {
        let app = makeApp(arguments: ["--ui-test-session-stale"])
        app.launch()

        let alert = app.alerts["Some Documents Were Not Restored"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        let recoveryMessage = alert.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "MissingSession.md")
        ).firstMatch
        XCTAssertTrue(recoveryMessage.exists)
        XCTAssertTrue(
            recoveryMessage.label.contains("Open them again from Files.")
        )

        alert.buttons["OK"].tap()
        XCTAssertTrue(
            app.staticTexts["No Document Open"].waitForExistence(timeout: 5)
        )
    }

    private func makeApp(
        arguments: [String] = [],
        suiteName: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["FILEVIEWER_UI_TEST_SUITE"] =
            suiteName ?? makeSuiteName()
        return app
    }

    private func makeSuiteName() -> String {
        "FileViewerIpadUITests.\(UUID().uuidString)"
    }

    private func searchField(in app: XCUIApplication) -> XCUIElement {
        app.searchFields["Search document"]
    }

    private func waitForLabel(
        _ expectedLabel: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label CONTAINS %@",
                expectedLabel
            ),
            object: element
        )
        return XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        ) == .completed
    }

    private func waitForLabelContaining(
        _ value: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        waitForLabel(value, on: element, timeout: timeout)
    }
}
