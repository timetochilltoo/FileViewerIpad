import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry

    init(
        documentAccess: (any DocumentAccessServicing)? = nil,
        documentRegistry: DocumentAccessRegistry = DocumentAccessRegistry()
    ) {
        let bookmarkStore = UserDefaultsBookmarkStore()
        self.documentAccess = documentAccess
            ?? DocumentAccessService(bookmarks: bookmarkStore)
        self.documentRegistry = documentRegistry
    }
}
