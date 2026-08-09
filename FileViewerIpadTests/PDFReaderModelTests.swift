import PDFKit
import UIKit
import XCTest
@testable import FileViewerIpad

final class PDFReaderModelTests: XCTestCase {
    @MainActor
    func testPageNavigationRejectsOutOfRangeIndexes() throws {
        let model = try XCTUnwrap(PDFReaderModel(data: makePDFData()))
        let pdfView = PDFView()
        pdfView.document = model.document
        model.attach(pdfView)

        model.goToPage(at: -1)
        model.goToPage(at: model.pageCount)

        XCTAssertEqual(model.pageCount, 2)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertNil(model.thumbnail(at: -1))
        XCTAssertNotNil(model.thumbnail(at: 0))
    }

    @MainActor
    func testExtractsPDFOutlineDestination() throws {
        let document = try XCTUnwrap(PDFDocument(data: makePDFData()))
        let destinationPage = try XCTUnwrap(document.page(at: 1))
        let root = PDFOutline()
        let chapter = PDFOutline()
        chapter.label = "Second Chapter"
        chapter.destination = PDFDestination(page: destinationPage, at: .zero)
        root.insertChild(chapter, at: 0)
        document.outlineRoot = root
        let data = try XCTUnwrap(document.dataRepresentation())

        let model = try XCTUnwrap(PDFReaderModel(data: data))

        XCTAssertEqual(
            model.outlineEntries,
            [
                PDFOutlineEntry(
                    id: "root.0",
                    depth: 0,
                    title: "Second Chapter",
                    pageIndex: 1
                )
            ]
        )
    }

    @MainActor
    func testSearchHighlightsAllMatchesAndNavigatesToRequestedMatch() throws {
        let model = try XCTUnwrap(PDFReaderModel(data: makeSearchablePDFData()))
        let pdfView = PDFView()
        pdfView.document = model.document
        model.attach(pdfView)

        let state = SearchState(
            query: "needle",
            currentMatchIndex: 1,
            matchCount: 2,
            navigationRequestID: UUID()
        )
        model.applySearch(state)

        XCTAssertEqual(pdfView.highlightedSelections?.count, 2)
        XCTAssertNotNil(pdfView.currentPage)
    }

    private func makePDFData() -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 300, height: 400)
        )
        return renderer.pdfData { context in
            for page in 1...2 {
                context.beginPage()
                "Page \(page)".draw(at: CGPoint(x: 24, y: 24))
            }
        }
    }

    private func makeSearchablePDFData() -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 300, height: 400)
        )
        return renderer.pdfData { context in
            context.beginPage()
            "First needle".draw(at: CGPoint(x: 24, y: 24))
            context.beginPage()
            "Second needle".draw(at: CGPoint(x: 24, y: 24))
        }
    }
}
