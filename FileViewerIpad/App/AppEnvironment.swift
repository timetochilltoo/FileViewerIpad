import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry
    let recentDocuments: any RecentDocumentStoring
    let readingState: any ReadingStateStoring
    let sceneSessions: any SceneSessionStoring
    let openRequestRouter: OpenRequestRouter
    let sceneCoordinator: WorkspaceSceneCoordinator

    init(
        documentAccess: (any DocumentAccessServicing)? = nil,
        documentRegistry: DocumentAccessRegistry = DocumentAccessRegistry(),
        recentDocuments: (any RecentDocumentStoring)? = nil,
        readingState: (any ReadingStateStoring)? = nil,
        sceneSessions: (any SceneSessionStoring)? = nil,
        openRequestRouter: OpenRequestRouter = OpenRequestRouter(),
        sceneCoordinator: WorkspaceSceneCoordinator = WorkspaceSceneCoordinator()
    ) {
        let suiteName = Self.persistenceSuiteName()
        Self.resetPersistenceIfNeeded(suiteName: suiteName)

        let bookmarkStore: UserDefaultsBookmarkStore
        let recentStore: any RecentDocumentStoring
        let positionStore: any ReadingStateStoring
        let sessionStore: any SceneSessionStoring

        if let suiteName {
            bookmarkStore = UserDefaultsBookmarkStore(suiteName: suiteName)
            recentStore = recentDocuments
                ?? UserDefaultsRecentDocumentStore(suiteName: suiteName)
            positionStore = readingState
                ?? UserDefaultsReadingStateStore(suiteName: suiteName)
            sessionStore = sceneSessions
                ?? UserDefaultsSceneSessionStore(suiteName: suiteName)
        } else {
            bookmarkStore = UserDefaultsBookmarkStore()
            recentStore = recentDocuments ?? UserDefaultsRecentDocumentStore()
            positionStore = readingState ?? UserDefaultsReadingStateStore()
            sessionStore = sceneSessions ?? UserDefaultsSceneSessionStore()
        }

        self.documentAccess = documentAccess
            ?? DocumentAccessService(
                bookmarks: bookmarkStore,
                recents: recentStore
            )
        self.documentRegistry = documentRegistry
        self.recentDocuments = recentStore
        self.readingState = positionStore
        self.sceneSessions = sessionStore
        self.openRequestRouter = openRequestRouter
        self.sceneCoordinator = sceneCoordinator
    }

    private static func persistenceSuiteName() -> String? {
#if DEBUG
        if let suiteName = ProcessInfo.processInfo.environment[
            "FILEVIEWER_UI_TEST_SUITE"
        ], suiteName.hasPrefix("FileViewerIpadUITests.") {
            return suiteName
        }
#endif
        return nil
    }

    private static func resetPersistenceIfNeeded(suiteName: String?) {
#if DEBUG
        guard let suiteName else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-test-session-seed")
            || arguments.contains("--ui-test-session-stale") else {
            return
        }
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(forName: suiteName)
#endif
    }
}
