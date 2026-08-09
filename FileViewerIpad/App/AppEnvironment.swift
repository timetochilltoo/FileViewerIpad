import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry
    let recentDocuments: any RecentDocumentStoring
    let readingState: any ReadingStateStoring
    let openRequestRouter: OpenRequestRouter
    let sceneCoordinator: WorkspaceSceneCoordinator

    init(
        documentAccess: (any DocumentAccessServicing)? = nil,
        documentRegistry: DocumentAccessRegistry = DocumentAccessRegistry(),
        recentDocuments: (any RecentDocumentStoring)? = nil,
        readingState: (any ReadingStateStoring)? = nil,
        openRequestRouter: OpenRequestRouter = OpenRequestRouter(),
        sceneCoordinator: WorkspaceSceneCoordinator = WorkspaceSceneCoordinator()
    ) {
        let bookmarkStore = UserDefaultsBookmarkStore()
        let recentStore = recentDocuments ?? UserDefaultsRecentDocumentStore()
        let positionStore = readingState ?? UserDefaultsReadingStateStore()
        self.documentAccess = documentAccess
            ?? DocumentAccessService(
                bookmarks: bookmarkStore,
                recents: recentStore
            )
        self.documentRegistry = documentRegistry
        self.recentDocuments = recentStore
        self.readingState = positionStore
        self.openRequestRouter = openRequestRouter
        self.sceneCoordinator = sceneCoordinator
    }
}
