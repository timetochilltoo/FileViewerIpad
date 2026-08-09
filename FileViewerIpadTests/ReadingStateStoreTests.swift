import XCTest
@testable import FileViewerIpad

final class ReadingStateStoreTests: XCTestCase {
    func testSavesAndRestoresPositionsByDocumentIdentity() async throws {
        let suiteName = "ReadingStateStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsReadingStateStore(suiteName: suiteName)
        let markdownIdentity = DocumentIdentity(
            persistentID: "markdown-document",
            displayName: "Notes.md"
        )
        let pdfIdentity = DocumentIdentity(
            persistentID: "pdf-document",
            displayName: "Manual.pdf"
        )
        let markdownPosition = ReadingPosition.markdown(
            MarkdownReadingPosition(
                visibleUTF16Location: 128,
                fallbackScrollOffset: 42
            )
        )
        let pdfPosition = ReadingPosition.pdf(
            PDFReadingPosition(page: 4, scale: 1.25)
        )
        defer {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }

        await store.saveReadingPosition(markdownPosition, for: markdownIdentity)
        await store.saveReadingPosition(pdfPosition, for: pdfIdentity)

        let restoredMarkdown = await store.readingPosition(for: markdownIdentity)
        let restoredPDF = await store.readingPosition(for: pdfIdentity)
        XCTAssertEqual(
            restoredMarkdown,
            markdownPosition
        )
        XCTAssertEqual(
            restoredPDF,
            pdfPosition
        )
    }

    func testUnknownDocumentHasNoReadingPosition() async throws {
        let suiteName = "ReadingStateStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsReadingStateStore(suiteName: suiteName)
        defer {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }

        let identity = DocumentIdentity(
            persistentID: "unknown",
            displayName: "Unknown.md"
        )

        let position = await store.readingPosition(for: identity)
        XCTAssertNil(position)
    }
}
