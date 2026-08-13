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

    @MainActor
    func testClosingWorkspaceReleasesAllDocumentIdentities() async throws {
        let workspace = WorkspaceModel()
        let registry = DocumentAccessRegistry()
        let first = makeDocument(
            id: "first",
            name: "First.md",
            kind: .markdown
        )
        let second = makeDocument(
            id: "second",
            name: "Second.pdf",
            kind: .pdf
        )

        _ = workspace.open(first)
        _ = workspace.open(second)
        _ = await registry.claim(
            first.descriptor.identity,
            at: DocumentLocation(
                workspaceID: workspace.id,
                tabID: workspace.tabs[0].id
            )
        )
        _ = await registry.claim(
            second.descriptor.identity,
            at: DocumentLocation(
                workspaceID: workspace.id,
                tabID: workspace.tabs[1].id
            )
        )

        await workspace.closeAllTabs(registry: registry)

        let firstLocation = await registry.location(for: first.descriptor.identity)
        let secondLocation = await registry.location(for: second.descriptor.identity)
        XCTAssertTrue(workspace.tabs.isEmpty)
        XCTAssertNil(workspace.selectedTabID)
        XCTAssertNil(firstLocation)
        XCTAssertNil(secondLocation)
    }

    @MainActor
    func testSearchCountsAndNavigatesMatchesPerSelectedTab() throws {
        let workspace = WorkspaceModel()
        let document = makeDocument(
            id: "searchable",
            name: "Searchable.md",
            kind: .markdown,
            content: .markdown("Needle one\n\nAnother NEEDLE")
        )
        workspace.open(document)

        workspace.updateSearchQuery("needle")

        XCTAssertEqual(workspace.selectedSearchQuery, "needle")
        XCTAssertEqual(workspace.searchStatusText, "1 of 2")
        workspace.nextSearchMatch()
        XCTAssertEqual(workspace.searchStatusText, "2 of 2")
        workspace.nextSearchMatch()
        XCTAssertEqual(workspace.searchStatusText, "1 of 2")
        workspace.previousSearchMatch()
        XCTAssertEqual(workspace.searchStatusText, "2 of 2")

        workspace.updateSearchQuery("missing")
        XCTAssertEqual(workspace.searchStatusText, "No matches")
        workspace.updateSearchQuery("")
        XCTAssertNil(workspace.searchStatusText)
    }

    @MainActor
    func testReadingPositionCanBeRestoredIntoOpenedTab() async throws {
        let suiteName = "WorkspaceModelTests.\(UUID().uuidString)"
        let store = UserDefaultsReadingStateStore(suiteName: suiteName)
        defer {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }
        let workspace = WorkspaceModel()
        let document = makeDocument(
            id: "restorable",
            name: "Restorable.pdf",
            kind: .pdf
        )
        guard case let .opened(tabID) = workspace.open(document) else {
            XCTFail("Expected the document to open in a new tab")
            return
        }
        let position = ReadingPosition.pdf(PDFReadingPosition(page: 3, scale: 1.5))

        await store.saveReadingPosition(position, for: document.descriptor.identity)
        await workspace.restoreReadingPosition(for: tabID, using: store)

        XCTAssertEqual(workspace.tabs.first?.readingPosition, position)
    }

    @MainActor
    func testRestoresSessionOrderSelectionAndReadingPosition() async throws {
        let suiteName = "WorkspaceModelTests.\(UUID().uuidString)"
        let readingStore = UserDefaultsReadingStateStore(suiteName: suiteName)
        let registry = DocumentAccessRegistry()
        let workspace = WorkspaceModel()
        let first = makeDocument(
            id: "first-session-document",
            name: "First.md",
            kind: .markdown
        )
        let second = makeDocument(
            id: "second-session-document",
            name: "Second.pdf",
            kind: .pdf
        )
        let restoredPosition = ReadingPosition.pdf(
            PDFReadingPosition(page: 4, scale: 1.5)
        )
        let session = WorkspaceSession(
            documents: [first, second].map {
                WorkspaceSessionDocument(descriptor: $0.descriptor)
            },
            selectedDocumentPersistentID: first.descriptor.identity.persistentID,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let accessService = RestorationDocumentAccessService(
            documents: [first, second]
        )
        defer {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }

        await readingStore.saveReadingPosition(
            restoredPosition,
            for: second.descriptor.identity
        )
        let result = await workspace.restoreSession(
            session,
            using: accessService,
            registry: registry,
            readingState: readingStore
        )

        XCTAssertEqual(result.restoredTabIDs.count, 2)
        XCTAssertTrue(result.skippedDocumentIdentities.isEmpty)
        XCTAssertFalse(result.wasCancelled)
        XCTAssertEqual(
            workspace.tabs.map(\.document.identity.persistentID),
            ["first-session-document", "second-session-document"]
        )
        XCTAssertEqual(
            workspace.selectedTab?.document.identity.persistentID,
            "first-session-document"
        )
        XCTAssertEqual(workspace.tabs[1].readingPosition, restoredPosition)
    }

    @MainActor
    func testSessionRestorationSkipsUnavailableDocumentAndExplainsRecovery() async {
        let workspace = WorkspaceModel()
        let registry = DocumentAccessRegistry()
        let available = makeDocument(
            id: "available",
            name: "Available.md",
            kind: .markdown
        )
        let missingIdentity = DocumentIdentity(
            persistentID: "missing",
            displayName: "Missing.md"
        )
        let session = WorkspaceSession(
            documents: [
                WorkspaceSessionDocument(descriptor: available.descriptor),
                WorkspaceSessionDocument(
                    identity: missingIdentity,
                    kind: .markdown
                )
            ],
            selectedDocumentPersistentID: missingIdentity.persistentID
        )
        let accessService = RestorationDocumentAccessService(
            documents: [available],
            unavailablePersistentIDs: [missingIdentity.persistentID]
        )

        let result = await workspace.restoreSession(
            session,
            using: accessService,
            registry: registry,
            readingState: InMemoryReadingStateStore()
        )

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(result.skippedDocumentIdentities, [missingIdentity])
        XCTAssertEqual(
            workspace.presentedErrorTitle,
            "Some Documents Were Not Restored"
        )
        XCTAssertTrue(workspace.presentedError?.contains("Missing.md") == true)
        XCTAssertTrue(workspace.presentedError?.contains("Open them again from Files") == true)
    }

    @MainActor
    func testSessionRestorationDoesNotDuplicateDocumentOwnedByAnotherScene() async throws {
        let firstWorkspace = WorkspaceModel()
        let restoringWorkspace = WorkspaceModel()
        let registry = DocumentAccessRegistry()
        let document = makeDocument(
            id: "owned-document",
            name: "Owned.md",
            kind: .markdown
        )
        let accessService = RestorationDocumentAccessService(documents: [document])
        _ = await firstWorkspace.openDocument(
            at: URL(fileURLWithPath: "/Owned.md"),
            using: accessService,
            registry: registry
        )
        let ownerTabID = try XCTUnwrap(firstWorkspace.selectedTabID)
        let session = WorkspaceSession(
            documents: [WorkspaceSessionDocument(descriptor: document.descriptor)],
            selectedDocumentPersistentID: document.descriptor.identity.persistentID
        )

        let result = await restoringWorkspace.restoreSession(
            session,
            using: accessService,
            registry: registry,
            readingState: InMemoryReadingStateStore()
        )

        XCTAssertTrue(restoringWorkspace.tabs.isEmpty)
        XCTAssertEqual(
            result.duplicateLocations,
            [
                DocumentLocation(
                    workspaceID: firstWorkspace.id,
                    tabID: ownerTabID
                )
            ]
        )
    }

    private func makeDocument(
        id: String,
        name: String,
        kind: DocumentKind
    ) -> ResolvedDocument {
        makeDocument(
            id: id,
            name: name,
            kind: kind,
            content: kind == .markdown ? .markdown("# Test") : .pdf(Data())
        )
    }

    private func makeDocument(
        id: String,
        name: String,
        kind: DocumentKind,
        content: LoadedDocumentContent
    ) -> ResolvedDocument {
        let descriptor = DocumentDescriptor(
            identity: DocumentIdentity(persistentID: id, displayName: name),
            kind: kind
        )
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

    func resolveDocument(for recent: RecentDocument) async throws -> ResolvedDocument {
        document
    }
}

private struct RestorationDocumentAccessService: DocumentAccessServicing {
    let documentsByPersistentID: [String: ResolvedDocument]
    let unavailablePersistentIDs: Set<String>

    init(
        documents: [ResolvedDocument],
        unavailablePersistentIDs: Set<String> = []
    ) {
        self.documentsByPersistentID = Dictionary(
            uniqueKeysWithValues: documents.map {
                ($0.descriptor.identity.persistentID, $0)
            }
        )
        self.unavailablePersistentIDs = unavailablePersistentIDs
    }

    func resolveDocument(at url: URL) async throws -> ResolvedDocument {
        guard let document = documentsByPersistentID.values.first else {
            throw DocumentAccessError.missingFile
        }
        return document
    }

    func resolveDocument(for recent: RecentDocument) async throws -> ResolvedDocument {
        guard !unavailablePersistentIDs.contains(recent.identity.persistentID),
              let document = documentsByPersistentID[
                  recent.identity.persistentID
              ] else {
            throw DocumentAccessError.staleBookmark
        }
        return document
    }
}

private actor InMemoryReadingStateStore: ReadingStateStoring {
    private var positions: [String: ReadingPosition] = [:]

    func readingPosition(for identity: DocumentIdentity) -> ReadingPosition? {
        positions[identity.persistentID]
    }

    func saveReadingPosition(
        _ position: ReadingPosition,
        for identity: DocumentIdentity
    ) {
        positions[identity.persistentID] = position
    }
}
