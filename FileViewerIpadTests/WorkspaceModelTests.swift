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

    @MainActor
    func testDuplicateAcrossWorkspacesReturnsExistingLocation() async throws {
        let firstWorkspace = WorkspaceModel()
        let secondWorkspace = WorkspaceModel()
        let registry = DocumentAccessRegistry()
        let document = makeDocument(id: "shared", name: "Shared.md", kind: .markdown)
        let accessService = StubDocumentAccessService(document: document)

        let firstResult = await firstWorkspace.openDocument(
            at: URL(fileURLWithPath: "/Shared.md"),
            using: accessService,
            registry: registry
        )
        let firstTabID = try XCTUnwrap(firstWorkspace.selectedTabID)
        let secondResult = await secondWorkspace.openDocument(
            at: URL(fileURLWithPath: "/Shared.md"),
            using: accessService,
            registry: registry
        )

        XCTAssertEqual(firstResult, .opened(firstTabID))
        XCTAssertEqual(
            secondResult,
            .activateExisting(
                DocumentLocation(
                    workspaceID: firstWorkspace.id,
                    tabID: firstTabID
                )
            )
        )
        XCTAssertTrue(secondWorkspace.tabs.isEmpty)
    }

    @MainActor
    func testClosingTabReleasesDocumentIdentity() async throws {
        let workspace = WorkspaceModel()
        let registry = DocumentAccessRegistry()
        let document = makeDocument(id: "closable", name: "Closable.md", kind: .markdown)
        let accessService = StubDocumentAccessService(document: document)

        _ = await workspace.openDocument(
            at: URL(fileURLWithPath: "/Closable.md"),
            using: accessService,
            registry: registry
        )
        let tabID = try XCTUnwrap(workspace.selectedTabID)

        await workspace.closeTab(tabID, registry: registry)

        XCTAssertTrue(workspace.tabs.isEmpty)
        XCTAssertNil(workspace.selectedTabID)
        let location = await registry.location(for: document.descriptor.identity)
        XCTAssertNil(location)
    }

    private func makeDocument(
        id: String,
        name: String,
        kind: DocumentKind
    ) -> ResolvedDocument {
        let descriptor = DocumentDescriptor(
            identity: DocumentIdentity(persistentID: id, displayName: name),
            kind: kind
        )
        let content: LoadedDocumentContent = switch kind {
        case .markdown:
            .markdown("# Test")
        case .pdf:
            .pdf(Data())
        }
        return ResolvedDocument(
            descriptor: descriptor,
            content: content
        )
    }
}

private struct StubDocumentAccessService: DocumentAccessServicing {
    let document: ResolvedDocument

    func resolveDocument(at url: URL) async throws -> ResolvedDocument {
        document
    }
}
