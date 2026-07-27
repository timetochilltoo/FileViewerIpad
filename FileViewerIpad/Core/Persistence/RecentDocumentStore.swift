import Foundation

actor UserDefaultsRecentDocumentStore: RecentDocumentStoring {
    private let defaults: UserDefaults
    private let storageKey = "recent-documents.v1"
    private let maximumCount: Int

    init(
        defaults: UserDefaults = .standard,
        maximumCount: Int = 20
    ) {
        self.defaults = defaults
        self.maximumCount = max(1, maximumCount)
    }

    init(
        suiteName: String,
        maximumCount: Int = 20
    ) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.maximumCount = max(1, maximumCount)
    }

    func recentDocuments() -> [RecentDocument] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(
                  [RecentDocument].self,
                  from: data
              ) else {
            return []
        }
        return Array(
            decoded
                .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
                .prefix(maximumCount)
        )
    }

    func record(_ document: RecentDocument) {
        var documents = recentDocuments()
        documents.removeAll { $0.identity == document.identity }
        documents.insert(document, at: 0)
        save(Array(documents.prefix(maximumCount)))
    }

    func remove(identity: DocumentIdentity) {
        var documents = recentDocuments()
        documents.removeAll { $0.identity == identity }
        save(documents)
    }

    private func save(_ documents: [RecentDocument]) {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
