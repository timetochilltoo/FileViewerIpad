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
}
