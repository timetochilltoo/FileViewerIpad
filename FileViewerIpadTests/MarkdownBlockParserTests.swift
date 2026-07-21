import XCTest
@testable import FileViewerIpad

final class MarkdownBlockParserTests: XCTestCase {
    func testParsesCommonReadingBlocks() {
        let markdown = """
        # Heading

        A **bold** paragraph.

        - Item
        - [x] Complete
        > Quoted

        ```swift
        let answer = 42
        ```
        """

        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(
            blocks,
            [
                .heading(level: 1, text: "Heading"),
                .paragraph("A **bold** paragraph."),
                .unorderedItem("Item"),
                .taskItem(isComplete: true, text: "Complete"),
                .quote("Quoted"),
                .code(language: "swift", text: "let answer = 42")
            ]
        )
    }

    func testParsesTableWithoutTreatingSeparatorAsContent() {
        let markdown = """
        | Name | Value |
        | --- | --- |
        | One | 1 |
        | Two | 2 |
        """

        XCTAssertEqual(
            MarkdownBlockParser.parse(markdown),
            [
                .table([
                    ["Name", "Value"],
                    ["One", "1"],
                    ["Two", "2"]
                ])
            ]
        )
    }
}
