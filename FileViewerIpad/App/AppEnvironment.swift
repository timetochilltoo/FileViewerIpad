import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry
    let recentDocuments: any RecentDocumentStoring
    let openRequestRouter: OpenRequestRouter

    init(
        documentAccess: (any DocumentAccessServicing)? = nil,
        documentRegistry: DocumentAccessRegistry = DocumentAccessRegistry(),
        recentDocuments: (any RecentDocumentStoring)? = nil,
        openRequestRouter: OpenRequestRouter = OpenRequestRouter()
    ) {
        let bookmarkStore = UserDefaultsBookmarkStore()
        let recentStore = recentDocuments ?? UserDefaultsRecentDocumentStore()
        self.documentAccess = documentAccess
            ?? DocumentAccessService(
                bookmarks: bookmarkStore,
                recents: recentStore
            )
        self.documentRegistry = documentRegistry
        self.recentDocuments = recentStore
        self.openRequestRouter = openRequestRouter
    }
}
