import Foundation
import XCTest
@testable import FileViewerIpad

final class DocumentSearchIndexTests: XCTestCase {
    func testFindsCaseInsensitiveMatchesUsingUTF16Locations() {
        let text = "😀 Needle\nneedle"

        let ranges = DocumentSearchIndex.ranges(in: text, query: "NEEDLE")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0], NSRange(location: 3, length: 6))
        XCTAssertEqual(ranges[1], NSRange(location: 10, length: 6))
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "Needle")
    }

    func testWhitespaceOnlyQueryAndInvalidIndexAreSafe() {
        XCTAssertTrue(DocumentSearchIndex.ranges(in: "text", query: "  ").isEmpty)
        XCTAssertEqual(DocumentSearchIndex.clampedMatchIndex(-1, count: 3), 0)
        XCTAssertEqual(DocumentSearchIndex.clampedMatchIndex(8, count: 3), 2)
        XCTAssertEqual(DocumentSearchIndex.clampedMatchIndex(8, count: 0), 0)
    }

    func testSearchesMarkdownContentThroughLoadedDocument() {
        let content: LoadedDocumentContent = .markdown("First match\nSecond MATCH")

        let ranges = DocumentSearchIndex.ranges(in: content, query: "match")

        XCTAssertEqual(ranges.count, 2)
    }
}
