import XCTest
@testable import FileViewerIpad

final class WorkspaceModelTests: XCTestCase {
    @MainActor
    func testWorkspaceModelsDoNotShareTabsOrSelection() {
        let firstWorkspace = WorkspaceModel()
        let secondWorkspace = WorkspaceModel()
        let document = makeDocument(id: "document-a", name: "A.md", kind: .markdown)

        firstWorkspace.open(document)

        XCTAssertEqual(firstWorkspace.tabs.count, 1)
        XCTAssertNotNil(firstWorkspace.selectedTabID)
        XCTAssertTrue(secondWorkspace.tabs.isEmpty)
        XCTAssertNil(secondWorkspace.selectedTabID)
    }

    @MainActor
    func testOpeningSameIdentitySelectsExistingTab() throws {
        let workspace = WorkspaceModel()
        let document = makeDocument(id: "document-a", name: "A.pdf", kind: .pdf)

        let firstResult = workspace.open(document)
        let firstTabID = try XCTUnwrap(workspace.selectedTabID)
        let secondResult = workspace.open(document)

        XCTAssertEqual(firstResult, .opened(firstTabID))
        XCTAssertEqual(secondResult, .selectedExisting(firstTabID))
        XCTAssertEqual(workspace.tabs.count, 1)
    }

    private func makeDocument(
        id: String,
        name: String,
        kind: DocumentKind
    ) -> DocumentDescriptor {
        DocumentDescriptor(
            identity: DocumentIdentity(persistentID: id, displayName: name),
            kind: kind
        )
    }
}

