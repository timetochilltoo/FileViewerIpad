import Foundation
import Observation

enum WorkspaceOpenResult: Equatable {
    case opened(DocumentTab.ID)
    case selectedExisting(DocumentTab.ID)
}

@MainActor
@Observable
final class WorkspaceModel {
    let id: WorkspaceID
    private(set) var tabs: [DocumentTab]
    var selectedTabID: DocumentTab.ID?

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
    func open(_ document: DocumentDescriptor) -> WorkspaceOpenResult {
        if let existing = tabs.first(where: { $0.document.identity == document.identity }) {
            selectedTabID = existing.id
            return .selectedExisting(existing.id)
        }

        let tab = DocumentTab(document: document)
        tabs.append(tab)
        selectedTabID = tab.id
        return .opened(tab.id)
    }

    func selectTab(_ id: DocumentTab.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }
}

