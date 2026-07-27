import Foundation
import Observation

enum WorkspaceOpenResult: Equatable {
    case opened(DocumentTab.ID)
    case selectedExisting(DocumentTab.ID)
    case activateExisting(DocumentLocation)
}

@MainActor
@Observable
final class WorkspaceModel {
    let id: WorkspaceID
    private(set) var tabs: [DocumentTab]
    var selectedTabID: DocumentTab.ID?
    private(set) var isOpeningDocument = false
    private(set) var presentedError: String?
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

    func refreshRecents(using store: any RecentDocumentStoring) async {
        recentDocuments = await store.recentDocuments()
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
    }

    func presentOpenError(_ error: Error) {
        guard !(error is CancellationError) else { return }
        presentedError = (error as? LocalizedError)?.errorDescription
            ?? "The document could not be opened."
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
}
