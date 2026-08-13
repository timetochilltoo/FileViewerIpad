import Foundation
import Observation

enum WorkspaceOpenResult: Equatable {
    case opened(DocumentTab.ID)
    case selectedExisting(DocumentTab.ID)
    case activateExisting(DocumentLocation)
}

struct WorkspaceSessionRestorationResult: Equatable, Sendable {
    let restoredTabIDs: [DocumentTab.ID]
    let skippedDocumentIdentities: [DocumentIdentity]
    let duplicateLocations: [DocumentLocation]
    let wasCancelled: Bool
}

@MainActor
@Observable
final class WorkspaceModel {
    let id: WorkspaceID
    private(set) var tabs: [DocumentTab]
    var selectedTabID: DocumentTab.ID?
    private(set) var isOpeningDocument = false
    private(set) var presentedError: String?
    private(set) var presentedErrorTitle = "Unable to Open Document"
    private(set) var recentDocuments: [RecentDocument] = []

    init(
        id: WorkspaceID = WorkspaceID(),
        tabs: [DocumentTab] = [],
        selectedTabID: DocumentTab.ID? = nil
    ) {
        self.id = id
        self.tabs = tabs
        self.selectedTabID = selectedTabID ?? tabs.first?.id
    }

    var selectedTab: DocumentTab? {
        guard let selectedTabID else { return nil }
        return tabs.first { $0.id == selectedTabID }
    }

    var selectedSearchQuery: String {
        get {
            selectedTab?.search.query ?? ""
        }
        set {
            updateSearchQuery(newValue)
        }
    }

    var searchStatusText: String? {
        guard let search = selectedTab?.search,
              !search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        guard search.matchCount > 0 else { return "No matches" }
        let index = DocumentSearchIndex.clampedMatchIndex(
            search.currentMatchIndex,
            count: search.matchCount
        )
        return "\(index + 1) of \(search.matchCount)"
    }

    @discardableResult
    func open(_ resolvedDocument: ResolvedDocument) -> WorkspaceOpenResult {
        if let existing = tabs.first(where: {
            $0.document.identity == resolvedDocument.descriptor.identity
        }) {
            selectedTabID = existing.id
            return .selectedExisting(existing.id)
        }

        let tab = DocumentTab(
            document: resolvedDocument.descriptor,
            content: resolvedDocument.content
        )
        tabs.append(tab)
        selectedTabID = tab.id
        return .opened(tab.id)
    }

    @discardableResult
    func openDocument(
        at url: URL,
        using accessService: any DocumentAccessServicing,
        registry: DocumentAccessRegistry
    ) async -> WorkspaceOpenResult? {
        isOpeningDocument = true
        presentedError = nil
        presentedErrorTitle = "Unable to Open Document"
        defer { isOpeningDocument = false }

        do {
            let resolvedDocument = try await accessService.resolveDocument(at: url)
            return await accept(resolvedDocument, registry: registry)
        } catch is CancellationError {
            return nil
        } catch {
            presentedError = (error as? LocalizedError)?.errorDescription
                ?? "The document could not be opened."
            return nil
        }
    }

    @discardableResult
    func openRecentDocument(
        _ recent: RecentDocument,
        using accessService: any DocumentAccessServicing,
        registry: DocumentAccessRegistry
    ) async -> WorkspaceOpenResult? {
        isOpeningDocument = true
        presentedError = nil
        presentedErrorTitle = "Unable to Open Document"
        defer { isOpeningDocument = false }

        do {
            let resolvedDocument = try await accessService.resolveDocument(for: recent)
            return await accept(resolvedDocument, registry: registry)
        } catch is CancellationError {
            return nil
        } catch {
            presentOpenError(error)
            return nil
        }
    }

    func restoreSession(
        _ session: WorkspaceSession,
        using accessService: any DocumentAccessServicing,
        registry: DocumentAccessRegistry,
        readingState: any ReadingStateStoring
    ) async -> WorkspaceSessionRestorationResult {
        guard session.schemaVersion == WorkspaceSession.currentSchemaVersion else {
            return WorkspaceSessionRestorationResult(
                restoredTabIDs: [],
                skippedDocumentIdentities: session.documents.map(\.identity),
                duplicateLocations: [],
                wasCancelled: false
            )
        }

        isOpeningDocument = true
        presentedError = nil
        presentedErrorTitle = "Unable to Open Document"
        defer { isOpeningDocument = false }

        var restoredTabIDs: [DocumentTab.ID] = []
        var skippedIdentities: [DocumentIdentity] = []
        var duplicateLocations: [DocumentLocation] = []
        var wasCancelled = false

        for document in session.documents {
            if Task.isCancelled {
                wasCancelled = true
                break
            }
            do {
                let resolvedDocument = try await accessService.resolveDocument(
                    for: document.recentDocument(restoredAt: session.updatedAt)
                )
                switch await accept(resolvedDocument, registry: registry) {
                case let .opened(tabID), let .selectedExisting(tabID):
                    await restoreReadingPosition(for: tabID, using: readingState)
                    restoredTabIDs.append(tabID)
                case let .activateExisting(location):
                    duplicateLocations.append(location)
                }
            } catch is CancellationError {
                wasCancelled = true
                break
            } catch {
                skippedIdentities.append(document.identity)
            }
        }

        if let selectedID = session.selectedDocumentPersistentID,
           let selectedTab = tabs.first(where: {
               $0.document.identity.persistentID == selectedID
           }) {
            selectedTabID = selectedTab.id
        } else if !restoredTabIDs.isEmpty {
            selectedTabID = restoredTabIDs.first
        }

        if !skippedIdentities.isEmpty {
            presentRestorationError(for: skippedIdentities)
        }

        return WorkspaceSessionRestorationResult(
            restoredTabIDs: restoredTabIDs,
            skippedDocumentIdentities: skippedIdentities,
            duplicateLocations: duplicateLocations,
            wasCancelled: wasCancelled
        )
    }

    func refreshRecents(using store: any RecentDocumentStoring) async {
        recentDocuments = await store.recentDocuments()
    }

    func updateSearchQuery(_ query: String) {
        guard let index = selectedTabIndex else { return }
        let count = DocumentSearchIndex.ranges(
            in: tabs[index].content,
            query: query
        ).count
        tabs[index].search.query = query
        tabs[index].search.currentMatchIndex = 0
        tabs[index].search.matchCount = count
        tabs[index].search.navigationRequestID = UUID()
    }

    func previousSearchMatch() {
        guard let index = selectedTabIndex,
              tabs[index].search.matchCount > 0 else { return }
        let count = tabs[index].search.matchCount
        tabs[index].search.currentMatchIndex =
            (tabs[index].search.currentMatchIndex - 1 + count) % count
        tabs[index].search.navigationRequestID = UUID()
    }

    func nextSearchMatch() {
        guard let index = selectedTabIndex,
              tabs[index].search.matchCount > 0 else { return }
        let count = tabs[index].search.matchCount
        tabs[index].search.currentMatchIndex =
            (tabs[index].search.currentMatchIndex + 1) % count
        tabs[index].search.navigationRequestID = UUID()
    }

    func restoreReadingPosition(
        for tabID: DocumentTab.ID,
        using store: any ReadingStateStoring
    ) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let position = try? await store.readingPosition(
                  for: tabs[index].document.identity
              ) else {
            return
        }
        tabs[index].readingPosition = position
    }

    func updateReadingPosition(
        _ position: ReadingPosition,
        for tabID: DocumentTab.ID,
        using store: any ReadingStateStoring
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        tabs[index].readingPosition = position
        let identity = tabs[index].document.identity
        Task {
            try? await store.saveReadingPosition(position, for: identity)
        }
    }

    func removeRecent(
        _ identity: DocumentIdentity,
        using store: any RecentDocumentStoring
    ) async {
        await store.remove(identity: identity)
        await refreshRecents(using: store)
    }

    func dismissError() {
        presentedError = nil
        presentedErrorTitle = "Unable to Open Document"
    }

    func presentOpenError(_ error: Error) {
        guard !(error is CancellationError) else { return }
        presentedErrorTitle = "Unable to Open Document"
        presentedError = (error as? LocalizedError)?.errorDescription
            ?? "The document could not be opened."
    }

    func sessionSnapshot(updatedAt: Date = Date()) -> WorkspaceSession? {
        guard !tabs.isEmpty else { return nil }
        return WorkspaceSession(
            documents: tabs.map {
                WorkspaceSessionDocument(descriptor: $0.document)
            },
            selectedDocumentPersistentID: selectedTab?
                .document.identity.persistentID,
            updatedAt: updatedAt
        )
    }

    func selectTab(_ id: DocumentTab.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    func closeTab(
        _ id: DocumentTab.ID,
        registry: DocumentAccessRegistry
    ) async {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let removedTab = tabs.remove(at: index)
        await registry.release(
            removedTab.document.identity,
            from: DocumentLocation(workspaceID: self.id, tabID: removedTab.id)
        )

        guard selectedTabID == id else { return }
        if tabs.indices.contains(index) {
            selectedTabID = tabs[index].id
        } else {
            selectedTabID = tabs.last?.id
        }
    }

    func closeAllTabs(registry: DocumentAccessRegistry) async {
        let removedTabs = tabs
        tabs.removeAll()
        selectedTabID = nil

        for tab in removedTabs {
            await registry.release(
                tab.document.identity,
                from: DocumentLocation(workspaceID: id, tabID: tab.id)
            )
        }
    }

    private func accept(
        _ resolvedDocument: ResolvedDocument,
        registry: DocumentAccessRegistry
    ) async -> WorkspaceOpenResult {
        if let existing = tabs.first(where: {
            $0.document.identity == resolvedDocument.descriptor.identity
        }) {
            selectedTabID = existing.id
            return .selectedExisting(existing.id)
        }

        let tab = DocumentTab(
            document: resolvedDocument.descriptor,
            content: resolvedDocument.content
        )
        let location = DocumentLocation(workspaceID: id, tabID: tab.id)

        switch await registry.claim(
            resolvedDocument.descriptor.identity,
            at: location
        ) {
        case .claimed:
            tabs.append(tab)
            selectedTabID = tab.id
            return .opened(tab.id)
        case let .activateExisting(existingLocation):
            return .activateExisting(existingLocation)
        }
    }

    private var selectedTabIndex: Int? {
        guard let selectedTabID else { return nil }
        return tabs.firstIndex { $0.id == selectedTabID }
    }

    private func presentRestorationError(
        for identities: [DocumentIdentity]
    ) {
        let visibleNames = identities.prefix(3).map {
            "“\($0.displayName)”"
        }
        let remainingCount = identities.count - visibleNames.count
        let remainingText = remainingCount > 0
            ? " and \(remainingCount) more"
            : ""

        presentedErrorTitle = "Some Documents Were Not Restored"
        presentedError = "FileViewer could not restore "
            + visibleNames.joined(separator: ", ")
            + remainingText
            + ". Open them again from Files."
    }
}
